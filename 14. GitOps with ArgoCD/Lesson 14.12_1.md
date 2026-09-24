# Module 14 — GitOps with Argo CD

## Lesson 14.12 — Automated Sync, Self-Healing, Pruning, Drift & Production-Safe Sync Policies

In Lesson 14.11 we learned:

```text
HOOKS  → lifecycle actions
PHASES → WHEN
WAVES  → ORDER
```

Now we answer a more dangerous production question:

> **What should Argo CD do when the Kubernetes cluster no longer matches Git?**

This is the heart of real GitOps operations.

---

# 1. The core GitOps equation

Always keep this model in mind:

```text
             Git Repository
             DESIRED STATE
                   │
                   │ compare
                   ▼
              ┌─────────┐
              │ Argo CD │
              └────┬────┘
                   │
                   │ reconcile
                   ▼
             Kubernetes
              LIVE STATE
```

For example, Git says:

```yaml
replicas: 2
```

but somebody executes:

```bash
kubectl scale deployment todo-backend \
  --replicas=7 \
  -n todo-production
```

Now:

```text
Git                     Kubernetes
────                    ──────────

replicas: 2             replicas: 7

        \                 /
         \               /
          └──── DRIFT ───┘
```

Argo CD continuously compares desired state with live state and can automatically synchronize when they differ. ([Argo CD][1])

---

# 2. What is configuration drift?

**Drift** means:

```text
Desired state != Live state
```

Examples:

```text
Git                        Cluster

replicas: 2                replicas: 5
image: v2                  image: v1
memory: 512Mi              memory: 1Gi
service: ClusterIP         service: NodePort
```

Drift can happen because someone uses:

```bash
kubectl edit
kubectl patch
kubectl scale
kubectl apply
helm upgrade
```

or because another controller changes part of the object.

Argo CD may report an application as `OutOfSync` when a controller, mutating webhook, manual change, or another mechanism changes the live object away from the desired manifest. ([Argo CD][2])

---

# 3. Detecting drift vs fixing drift

These are two separate things.

Suppose:

```text
Git:
replicas = 2

Cluster:
replicas = 7
```

Argo CD can detect:

```text
Application
    │
    ▼
OutOfSync
```

But detecting drift does **not automatically mean Argo CD will repair it**.

That's where:

```text
selfHeal
```

enters.

---

# 4. Automated synchronization

Basic automated sync:

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
```

This means that when Git changes and the application becomes `OutOfSync`, Argo CD can perform the synchronization automatically instead of requiring someone to press **Sync** or execute `argocd app sync`. ([Argo CD][1])

Architecture:

```text
Developer
   │
   ▼
Git Commit
   │
   ▼
Argo CD detects new desired state
   │
   ▼
Application OutOfSync
   │
   ▼
Automatic Sync
   │
   ▼
Kubernetes updated
```

That eliminates:

```text
CI
 │
 └── kubectl apply
```

and gives us:

```text
CI
 │
 └── update Git

Argo CD
 │
 └── deploy
```

---

# 5. Automated sync does not automatically mean self-healing

This distinction is extremely important.

Consider:

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
```

Now somebody manually changes Kubernetes.

```bash
kubectl scale deployment todo-backend \
  --replicas=5 \
  -n todo-production
```

Git has not changed.

By default, a live-cluster-only change does not trigger automated synchronization. `selfHeal: true` enables automatic synchronization for that form of drift. ([Argo CD][1])

So:

```text
AUTO SYNC
     ≠
SELF HEAL
```

---

# 6. Self-healing

Enable:

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
      selfHeal: true
```

Now:

```text
Git
replicas = 2
     │
     │
     ▼

Admin manually changes cluster
replicas = 5
     │
     ▼

Argo CD detects drift
     │
     ▼

selfHeal = true
     │
     ▼

Argo CD reconciles
     │
     ▼

replicas = 2 again
```

`selfHeal` is explicitly intended to reconcile live-cluster drift against the desired state. ([Argo CD][1])

### Never-forget rule

```text
Git wins.
```

In a strict GitOps model:

```text
Want 5 replicas?

DON'T:

kubectl scale ... --replicas=5

DO:

Git:
replicas: 5

commit
push

Argo CD:
reconcile
```

---

# 7. Production incident scenario

Imagine 03:00 AM.

CPU is high.

Engineer panics and runs:

```bash
kubectl scale deployment checkout-api \
  --replicas=20
```

But Git says:

```yaml
replicas: 4
```

With self-healing enabled:

```text
03:00:00
Engineer → replicas 20

03:00:xx
Argo CD detects drift

03:00:xx
Argo CD → replicas 4
```

Engineer:

```text
"Why does Kubernetes keep changing it back?!"
```

Argo CD:

```text
Because Git says 4.
```

This is a classic real-world GitOps problem.

The correct emergency process should therefore account for the fact that Git remains the source of truth.

---

# 8. The next dangerous option: PRUNE

Suppose Git contains:

```text
deployment.yaml
service.yaml
configmap.yaml
```

Cluster therefore contains:

```text
Deployment
Service
ConfigMap
```

Now you remove:

```text
configmap.yaml
```

from Git.

What should happen to the existing ConfigMap?

There are two possible philosophies:

```text
Option A
Git deletion doesn't delete Kubernetes object.

Option B
Git deletion means Kubernetes object should disappear too.
```

Option B is called:

# Pruning

---

# 9. Automatic pruning

Configure:

```yaml
spec:
  syncPolicy:

    automated:
      enabled: true
      prune: true
```

Then:

```text
Git

deployment.yaml
service.yaml
configmap.yaml
       │
       ▼

Cluster

Deployment
Service
ConfigMap


Later Git:

deployment.yaml
service.yaml

ConfigMap removed
       │
       ▼

Argo CD detects extraneous resource
       │
       ▼

prune = true
       │
       ▼

ConfigMap deleted
```

Automatic sync does **not** enable pruning by default; pruning must be explicitly enabled. ([Argo CD][1])

And that is a deliberate safety feature.

---

# 10. Why prune can be dangerous

Imagine Git accidentally receives:

```bash
rm -rf production/*
git add .
git commit -m "oops"
git push
```

Without proper protections:

```text
Git resources removed
        │
        ▼
Argo CD
        │
        ▼
Prune
        │
        ▼
Kubernetes resources deleted
```

This is why production GitOps requires:

```text
Branch protection
+
Pull requests
+
Reviews
+
RBAC
+
Prune safeguards
+
Backup/recovery strategy
```

—not just:

```text
automated:
  prune: true
```

---

# 11. allowEmpty

There is an additional protection.

Suppose pruning is enabled and Git suddenly contains **zero application resources**.

Argo CD protects automated pruning from emptying an application unless `allowEmpty` is enabled. ([Argo CD][1])

Example:

```yaml
automated:

  enabled: true

  prune: true

  allowEmpty: false
```

Think:

```text
prune
     =
"You may delete resources removed from Git."

allowEmpty
     =
"You may even delete EVERYTHING."
```

### Production memory trick

```text
prune=true
       ↓
Deletion enabled

allowEmpty=true
       ↓
Total deletion potentially allowed
```

Therefore I'd generally begin production applications with:

```yaml
allowEmpty: false
```

unless the application's lifecycle specifically requires empty desired state.

---

# 12. Our production baseline

Now we can construct:

```yaml
spec:

  syncPolicy:

    automated:

      enabled: true

      prune: true

      selfHeal: true

      allowEmpty: false
```

Meaning:

```text
enabled
   │
   └── Deploy Git changes automatically

prune
   │
   └── Delete managed resources removed from Git

selfHeal
   │
   └── Repair live-cluster drift

allowEmpty
   │
   └── Do NOT automatically permit app to become empty
```

These options are independently represented in the current Application specification. ([Argo CD][3])

---

# 13. Hands-on drift experiment

Assume:

```text
todo-production
```

has:

```yaml
replicas: 2
```

Verify:

```bash
kubectl get deployment todo-backend \
  -n todo-production
```

Expected:

```text
NAME           READY   UP-TO-DATE   AVAILABLE
todo-backend   2/2     2            2
```

Now intentionally create drift:

```bash
kubectl scale deployment todo-backend \
  --replicas=5 \
  -n todo-production
```

Check:

```bash
kubectl get deployment todo-backend \
  -n todo-production
```

Initially you may see:

```text
todo-backend   5/5
```

Now:

```bash
argocd app get todo-production
```

The deployment's live state differs from Git.

With self-healing enabled, Argo CD will reconcile that difference automatically. ([Argo CD][1])

Eventually:

```bash
kubectl get deployment todo-backend \
  -n todo-production
```

returns toward:

```text
2/2
```

because:

```text
Git > manual cluster modification
```

---

# 14. Very important distinction

Suppose Kubernetes says:

```text
replicas: 5
```

and Argo CD changes it back to:

```text
replicas: 2
```

That is **reconciliation**.

It is not:

```text
application rollback
```

Think:

```text
ROLLBACK
=
change desired application revision

SELF HEAL
=
restore live state to current desired revision
```

They solve different problems.

---

# 15. Resource-level prune protection

Maybe automatic pruning is enabled application-wide:

```yaml
automated:
  prune: true
```

but one object is extremely sensitive.

For example:

```text
PersistentVolumeClaim
```

or perhaps a critical namespace/resource.

You can mark a resource:

```yaml
metadata:

  annotations:

    argocd.argoproj.io/sync-options: Prune=false
```

Argo CD supports `Prune=false` at the resource level even when application-level pruning exists. ([Argo CD][4])

Architecture:

```text
Application

auto prune = true

       │
       ├── Deployment
       │      DELETE if removed
       │
       ├── Service
       │      DELETE if removed
       │
       └── Critical Resource
                │
                └── Prune=false

                    KEEP
```

---

# 16. Prune with human approval

An even better option for some critical resources is:

```yaml
metadata:

  annotations:

    argocd.argoproj.io/sync-options: Prune=confirm
```

Now:

```text
Git removes resource
      │
      ▼
Argo CD identifies prune
      │
      ▼

DELETE immediately?

      NO

      │
      ▼

Wait for approval
```

Argo CD supports `Prune=confirm`, including confirmation through the UI, CLI, or a deletion-approved annotation. ([Argo CD][4])

Excellent candidate:

```yaml
apiVersion: v1
kind: Namespace

metadata:

  name: production

  annotations:

    argocd.argoproj.io/sync-options: Prune=confirm
```

---

# 17. PruneLast

Now connect this to **sync waves** from Lesson 14.11.

Suppose release v2 replaces:

```text
Old Service
```

with:

```text
New Service
```

You don't necessarily want Argo CD to remove obsolete resources too early.

Use:

```yaml
syncPolicy:

  syncOptions:

    - PruneLast=true
```

With `PruneLast=true`, pruning happens as a final implicit wave after other resources have been deployed, become healthy, and prior waves complete successfully. ([Argo CD][4])

Mental model:

```text
Wave -10
Config

     ↓

Wave 0
New Backend

     ↓

Wave 10
New Service

     ↓

Wait for Healthy

     ↓

FINAL WAVE
Prune obsolete resources
```

This is often much safer than:

```text
delete old first
deploy new later
```

---

# 18. PRUNE vs DELETE — important distinction

You will see both:

```text
Prune=false
Delete=false
```

They are **not the same**.

### Prune

Think:

```text
Resource disappeared from desired Git state
```

Should Argo CD remove that cluster resource?

```yaml
Prune=false
```

can prevent that pruning.

### Delete

Think:

```text
The entire Argo CD Application itself is being deleted
```

Should this resource be cleaned up as part of application deletion?

```yaml
Delete=false
```

can preserve it.

Argo CD documents `Delete=false` specifically for resources that should survive application deletion, with PVCs given as an example. ([Argo CD][4])

### Never forget

```text
PRUNE
=
Git no longer wants this resource.

DELETE
=
Application itself is being deleted.
```

---

# 19. Example protecting persistent data

```yaml
apiVersion: v1
kind: PersistentVolumeClaim

metadata:

  name: mongodb-data

  annotations:

    argocd.argoproj.io/sync-options: Delete=false,Prune=false

spec:

  accessModes:
    - ReadWriteOnce

  resources:

    requests:

      storage: 20Gi
```

Conceptually:

```text
Application lifecycle
        │
        ▼

Deployment removed → maybe okay

Service removed → maybe okay

PVC removed?
        │
        ▼
STOP AND THINK
```

You should never treat data-bearing resources exactly like stateless Pods.

---

# 20. CreateNamespace=true

You may currently create a Namespace YAML manually:

```yaml
kind: Namespace
metadata:
  name: todo-production
```

Argo CD can alternatively create the destination namespace.

```yaml
spec:

  destination:

    namespace: todo-production

  syncPolicy:

    syncOptions:

      - CreateNamespace=true
```

When this option is enabled, Argo CD can create the namespace defined by `spec.destination.namespace` if it doesn't exist. ([Argo CD][4])

This is useful for:

```text
dev
qa
staging
production
```

Application provisioning.

---

# 21. Server-Side Apply

Now we reach an advanced Kubernetes concept.

Traditional:

```text
kubectl apply
```

is client-side apply.

Argo CD normally uses standard `kubectl apply` behavior and the `kubectl.kubernetes.io/last-applied-configuration` annotation. ([Argo CD][4])

With:

```yaml
syncOptions:

  - ServerSideApply=true
```

Argo CD uses Kubernetes Server-Side Apply. Current Argo CD documentation lists uses including very large resources, partially managed resources, and more explicit field-management semantics. ([Argo CD][4])

Conceptually:

```text
CLIENT-SIDE APPLY

kubectl/Argo
      │
calculate/apply state
      │
      ▼
API Server
```

versus:

```text
SERVER-SIDE APPLY

Argo CD
   │
   ▼
API Server
   │
   ├── determine field ownership
   ├── merge
   ├── detect conflicts
   └── persist managed fields
```

---

# 22. Why field ownership matters

Imagine one Deployment:

```yaml
spec:
  replicas: 3
```

But multiple systems interact with it:

```text
Argo CD
   │
   ├── image
   ├── environment
   └── resource limits


HPA
   │
   └── replicas


Operator
   │
   └── injected configuration
```

Kubernetes Server-Side Apply tracks field management information through `managedFields`.

You can inspect it:

```bash
kubectl get deployment todo-backend \
  -n todo-production \
  -o yaml
```

Look for:

```yaml
metadata:

  managedFields:
```

This becomes highly important when multiple controllers legitimately manage different pieces of the same resource.

---

# 23. But be careful with ServerSideApply

Don't think:

```text
ServerSideApply=true

=
better always
```

No.

Use it intentionally.

Argo CD's current implementation applies SSA with conflict-forcing semantics, and it also supports client-side-apply migration for existing resources. ([Argo CD][4])

The correct mental model is:

```text
Understand:

Who owns which fields?

before enabling:

ServerSideApply=true
```

---

# 24. Replace=true is MUCH more dangerous

There is another option:

```yaml
syncOptions:

  - Replace=true
```

This is not the same as SSA.

Argo CD can use:

```text
kubectl replace
```

or:

```text
kubectl create
```

instead of normal apply semantics. Argo CD explicitly warns that this can recreate resources and cause outages. ([Argo CD][4])

Memory:

```text
ServerSideApply
        ≠
Replace
```

and:

```text
Replace=true
      │
      ▼
⚠ potentially destructive
```

Do not add it simply because you saw it in somebody's production YAML.

---

# 25. Force=true is even more explicit

Argo CD also supports cases where a resource is deliberately:

```text
DELETE
  +
CREATE
```

using force/replace behavior.

For example, special Jobs may need recreation.

But Argo CD warns that delete/create is destructive and can cause an outage. ([Argo CD][4])

Think:

```text
Normal Apply
   ↓
Patch existing object

Replace
   ↓
Potential recreation

Force + Replace
   ↓
DELETE + CREATE
```

Production danger increases as you move downward.

---

# 26. IgnoreDifferences

Now here's a very common production problem.

Git says:

```yaml
replicas: 2
```

but you are using:

```text
HorizontalPodAutoscaler
```

The HPA legitimately changes replicas:

```text
2
↓
5
↓
8
↓
3
```

If Argo CD continually treats that field as unwanted drift, you may have controllers fighting.

We can tell Argo CD:

> Ignore this specific field when comparing desired vs live.

Example:

```yaml
spec:

  ignoreDifferences:

    - group: apps

      kind: Deployment

      jsonPointers:

        - /spec/replicas
```

Argo CD supports ignore rules based on JSON pointers, JQ expressions, and managed-field managers. ([Argo CD][2])

---

# 27. Architecture with HPA

Without thoughtful ownership:

```text
                  Deployment

                  replicas
                     ▲
                     │

              ┌──────┴──────┐
              │             │
              │             │

            Argo CD         HPA

          wants 2           wants 7

              │             │
              └──────┬──────┘
                     │

                Controller Fight
```

Better:

```text
Argo CD owns:

image
config
resources
service
etc.

HPA owns:

replica scaling
```

Then:

```text
ignoreDifferences:
  /spec/replicas
```

can be appropriate.

---

# 28. Important trap with ignoreDifferences

You might assume:

```text
ignoreDifferences
=
Argo CD never touches this field
```

Not necessarily.

By default, `ignoreDifferences` affects **diff calculation**; during sync, desired state can still be applied as-is. To make sync itself respect those ignored fields, Argo CD provides:

```yaml
RespectIgnoreDifferences=true
```

([Argo CD][4])

So:

```yaml
spec:

  ignoreDifferences:

    - group: apps

      kind: Deployment

      jsonPointers:

        - /spec/replicas

  syncPolicy:

    syncOptions:

      - RespectIgnoreDifferences=true
```

### Memory trick

```text
ignoreDifferences
      =
Don't complain about this difference.

RespectIgnoreDifferences
      =
Also respect that exclusion during sync.
```

That distinction is advanced and very interview-worthy.

---

# 29. FailOnSharedResource

Imagine:

```text
Argo Application A
      │
      └── ConfigMap global-config


Argo Application B
      │
      └── SAME ConfigMap global-config
```

Which application owns it?

Bad architecture.

You can enable:

```yaml
syncOptions:

  - FailOnSharedResource=true
```

Then Argo CD can fail the synchronization when it discovers that the resource is already managed by another Application. ([Argo CD][4])

Production rule:

```text
One resource
     ↓
One clear owner
```

not:

```text
App A ──┐
        ├── same resource
App B ──┘
```

---

# 30. ApplyOutOfSyncOnly

Imagine your Argo CD Application contains:

```text
5,000 Kubernetes resources
```

but only:

```text
2 resources
```

changed.

By default a sync can apply every resource. Argo CD provides:

```yaml
syncOptions:

  - ApplyOutOfSyncOnly=true
```

to synchronize only resources that are `OutOfSync`, reducing unnecessary work on large applications. Hooks still run with this option, unlike selective sync. ([Argo CD][4])

Think:

```text
Normal Sync

5000 resources
      │
      ▼
apply many/all


ApplyOutOfSyncOnly

5000 resources
      │
      ├── 4998 unchanged
      │
      └── 2 changed
               │
               ▼
             apply
```

Useful at scale.

---

# 31. SkipDryRunOnMissingResource

Suppose you work with operators and CRDs.

Example:

```text
External Secrets Operator
Prometheus Operator
Gatekeeper
Crossplane
Service Mesh operators
```

Sometimes the Custom Resource exists in Git while its CRD is not yet known during validation.

Argo CD supports:

```yaml
syncOptions:

  - SkipDryRunOnMissingResource=true
```

for scenarios where the corresponding resource type is not yet available at dry-run time. If the CRD is included in the same sync, Argo CD can automatically account for that situation; the explicit option is useful for other CRD-creation patterns. ([Argo CD][4])

This will become especially useful later when we cover:

```text
Crossplane
Operators
Platform Engineering
```

---

# 32. Production-grade Application manifest

Let's combine the major pieces:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:

  name: todo-production
  namespace: argocd

spec:

  project: production

  source:

    repoURL: https://github.com/company/gitops-repo.git

    targetRevision: main

    path: apps/todo/production

  destination:

    server: https://kubernetes.default.svc

    namespace: todo-production

  syncPolicy:

    automated:

      enabled: true

      prune: true

      selfHeal: true

      allowEmpty: false

    syncOptions:

      - CreateNamespace=true

      - PruneLast=true

      - ServerSideApply=true

      - FailOnSharedResource=true

      - RespectIgnoreDifferences=true

  ignoreDifferences:

    - group: apps

      kind: Deployment

      name: todo-backend

      namespace: todo-production

      jsonPointers:

        - /spec/replicas
```

All of those switches exist in current Argo CD application/sync configuration; however, **this YAML is a teaching example, not a rule that every production application should enable every option**. The correct settings depend on resource ownership, application architecture, controllers such as HPA, and your deletion policy. ([Argo CD][3])

---

# 33. What this manifest means

Let's translate it into English:

```text
enabled=true

"If Git changes, deploy automatically."
```

```text
prune=true

"If an Argo-managed resource disappears from Git,
it may be removed from Kubernetes."
```

```text
selfHeal=true

"If somebody changes the live cluster,
restore the desired Git state."
```

```text
allowEmpty=false

"Do not casually allow automated pruning
to reduce the whole app to zero resources."
```

```text
CreateNamespace=true

"Create my destination namespace when necessary."
```

```text
PruneLast=true

"Remove obsolete resources after the new
deployment has completed successfully."
```

```text
ServerSideApply=true

"Use Kubernetes server-side apply semantics."
```

```text
FailOnSharedResource=true

"Don't quietly fight another Argo Application
for ownership."
```

```text
RespectIgnoreDifferences=true

"Fields we've intentionally excluded from
Argo CD ownership shouldn't be overwritten
during ordinary synchronization."
```

---

# 34. Production drift lab

Now let's test all this practically.

Git:

```yaml
replicas: 2
```

Push:

```bash
git add .
git commit -m "configure production GitOps policy"
git push origin main
```

Check:

```bash
argocd app get todo-production
```

Then:

```bash
kubectl get deployment todo-backend \
  -n todo-production
```

---

## Test 1 — manual image drift

Run:

```bash
kubectl set image deployment/todo-backend \
  backend=nginx:1.27 \
  -n todo-production
```

Now inspect:

```bash
argocd app diff todo-production
```

Then:

```bash
kubectl get deployment todo-backend \
  -n todo-production \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

With self-heal and the image managed by Git:

```text
manual nginx:1.27
       │
       ▼
OutOfSync
       │
       ▼
Argo reconciliation
       │
       ▼
Git-defined image restored
```

---

# 35. Test 2 — replica drift intentionally ignored

Suppose Git:

```yaml
replicas: 2
```

but `/spec/replicas` is intentionally ignored.

Run:

```bash
kubectl scale deployment todo-backend \
  --replicas=5 \
  -n todo-production
```

If your ignore configuration and sync ownership are set correctly:

```text
Git
replicas 2

HPA / external controller
replicas 5

Argo CD
    │
    └── does not fight ownership
        of the ignored field
```

This demonstrates an important production principle:

> **Not every live difference is bad drift.**

Some differences are **intentional controller ownership**.

Argo CD's diff customization exists exactly for cases where live resources are legitimately modified after submission. ([Argo CD][2])

---

# 36. Good drift vs bad drift

### Bad drift

Someone executes:

```bash
kubectl set image deployment/api api=evil:v1
```

Git says:

```text
api:v4.8
```

Argo should restore:

```text
api:v4.8
```

---

### Legitimate difference

HPA changes:

```text
replicas 2 → 8
```

because CPU is high.

We may intentionally let HPA own this field.

---

Therefore:

```text
DRIFT
  │
  ├── Unauthorized/unwanted difference
  │        ↓
  │     SELF HEAL
  │
  └── Intentional controller-managed difference
           ↓
      IGNORE / ownership strategy
```

That is the mature GitOps mental model.

---

# 37. A production anti-pattern

Do **not** do this:

```text
Argo CD
   │
   └── manages replicas


HPA
   │
   └── manages replicas


Human
   │
   └── kubectl scale replicas
```

Three actors all owning:

```text
spec.replicas
```

Then everybody wonders why the number keeps changing.

Instead:

```text
FIELD OWNERSHIP

Image            → Argo CD
Environment      → Argo CD
Resources        → Argo CD
Replicas         → HPA
Status           → Kubernetes controller
Secrets values   → appropriate secret system
```

Clear ownership prevents controller fights.

---

# 38. Another production safety layer

Let's mark a namespace:

```yaml
apiVersion: v1
kind: Namespace

metadata:

  name: production

  annotations:

    argocd.argoproj.io/sync-options: Prune=confirm,Delete=confirm
```

Argo CD supports confirmation controls separately for prune operations and application-deletion cleanup. ([Argo CD][4])

Now accidental Git removal does not simply mean:

```text
production namespace
        ↓
      BOOM
        ↓
      deleted
```

Instead:

```text
destructive operation
        ↓
requires deliberate approval
```

Much better.

---

# 39. Argo CD automated sync retry

Another production feature:

```yaml
syncPolicy:

  retry:

    limit: 5

    backoff:

      duration: 5s

      factor: 2

      maxDuration: 3m
```

Argo CD supports automatic sync retries with exponential backoff. ([Argo CD][1])

Conceptually:

```text
Sync failed
    │
    ▼
wait 5s
    │
retry
    │
    ▼
wait 10s
    │
retry
    │
    ▼
wait 20s
    │
...
```

This is much better than hammering Kubernetes continuously.

---

# 40. Incident troubleshooting flow

If you discover:

```text
Argo CD keeps undoing my changes
```

don't immediately disable Argo CD.

Check:

```bash
argocd app get todo-production
```

Then:

```bash
argocd app diff todo-production
```

Check the Deployment:

```bash
kubectl get deployment todo-backend \
  -n todo-production \
  -o yaml
```

Then ask:

```text
1. What does Git say?

2. What does Kubernetes say?

3. Which field differs?

4. Who should own that field?

5. Is selfHeal enabled?

6. Is ignoreDifferences configured?

7. Is RespectIgnoreDifferences enabled?

8. Is another controller changing it?

9. Is another Argo Application managing it?
```

That workflow will solve a huge percentage of GitOps drift problems.

---

# 41. Important production rule about rollback

Argo CD's current automated-sync documentation notes that a rollback cannot be performed against an Application while automated sync is enabled. ([Argo CD][1])

In a strong GitOps process, the normal recovery path is often:

```text
Bad release v5
      │
      ▼
Revert Git commit
      │
      ▼
Desired state becomes v4
      │
      ▼
Argo CD detects change
      │
      ▼
Deploy v4
```

Example:

```bash
git log --oneline
```

Suppose:

```text
abc555 deploy v5
abc444 deploy v4
```

Then:

```bash
git revert abc555
git push
```

Flow:

```text
Git revert
   ↓
Argo CD
   ↓
Reconciliation
   ↓
previous desired state
```

Notice:

```text
Even rollback becomes Git-driven.
```

---

# 42. Interview questions

### Q1. What does `selfHeal` do?

It allows Argo CD automated sync to reconcile live-cluster drift back toward Git-defined desired state. ([Argo CD][1])

---

### Q2. Does automated sync automatically enable pruning?

No. Automatic pruning is separately enabled with:

```yaml
prune: true
```

([Argo CD][1])

---

### Q3. What does `allowEmpty` do?

It allows automated pruning to leave an application with no target resources. ([Argo CD][1])

---

### Q4. Difference between `Prune=false` and `Delete=false`?

```text
Prune=false
→ protect against removal because resource
  disappeared from desired state.

Delete=false
→ retain resource when Application is deleted.
```

([Argo CD][4])

---

### Q5. What does `PruneLast=true` do?

Runs pruning as a final implicit wave after other resources successfully deploy and become healthy. ([Argo CD][4])

---

### Q6. Why use `ignoreDifferences`?

To prevent legitimate controller-generated differences from making Argo CD continuously consider a resource incorrectly divergent. ([Argo CD][2])

---

### Q7. What is `RespectIgnoreDifferences=true`?

It extends your ignore-difference configuration into the sync stage instead of using it only for comparison. ([Argo CD][4])

---

### Q8. Why use `FailOnSharedResource=true`?

To fail synchronization when the Application encounters a resource already managed by another Argo CD Application. ([Argo CD][4])

---

### Q9. What is Server-Side Apply?

Kubernetes API-server-based apply semantics with managed field ownership rather than traditional client-side last-applied-state handling. Argo CD can enable it with:

```yaml
ServerSideApply=true
```

([Argo CD][4])

---

# 43. Never-forget memory map

Memorize this:

```text
                    GIT
                Desired State
                     │
                     ▼
                 Argo CD
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼

      Git changed           Cluster changed
          │                     │
          ▼                     ▼
     AUTO SYNC              SELF HEAL
          │                     │
          └──────────┬──────────┘
                     ▼
                Kubernetes


Resource removed from Git
          │
          ▼
        PRUNE


Don't allow whole app empty
          │
          ▼
     allowEmpty=false


Critical resource
          │
          ▼
     Prune=confirm


Delete obsolete things LAST
          │
          ▼
     PruneLast=true


HPA/controller owns a field
          │
          ▼
   ignoreDifferences
          +
RespectIgnoreDifferences


Multiple Argo Apps fight
over one resource
          │
          ▼
FailOnSharedResource


Need Kubernetes field ownership
          │
          ▼
ServerSideApply
```

---

# 44. The five lines you must never forget

```text
AUTO SYNC
=
Git change → cluster deployment


SELF HEAL
=
Cluster drift → restore desired state


PRUNE
=
Removed from Git → remove from cluster


IGNORE DIFFERENCE
=
This difference is intentional


GIT
=
Source of truth
```

---

# 45. Where we are in Module 14

```text
Module 14 — GitOps with Argo CD

14.1  GitOps Mental Model                    ✅
14.2  Argo CD Architecture                   ✅
14.3  Installation                           ✅
14.4  Applications                           ✅
14.5  Automated Reconciliation               ✅
14.6  Repository Structure                   ✅
14.7  Helm + Argo CD                         ✅
14.8  Kustomize + Argo CD                    ✅
14.9  Production Repository Patterns         ✅
14.10 Advanced Application Management        ✅
14.11 Hooks, Phases & Sync Waves             ✅
14.12 Sync Policies, Drift & Self-Healing    ✅ ← completed

NEXT
   │
   ▼
14.13 — Argo CD AppProject, RBAC &
         Multi-Team Production Security
```

And **Lesson 14.13** is a very important enterprise lesson.

We'll move from:

```text
"Argo CD can deploy applications."
```

to:

```text
"Who is actually allowed to deploy WHAT,
to WHICH cluster,
into WHICH namespace,
from WHICH Git repository?"
```

We'll build the model:

```text
                        Argo CD

                           │

                ┌──────────┴──────────┐
                │                     │

            Team A                Team B

          Developers             Platform
                │                     │
                ▼                     ▼

           AppProject A          AppProject B
                │                     │
        ┌───────┴──────┐       ┌─────┴─────────┐
        ▼              ▼       ▼               ▼

    dev/staging     limited   shared infra   production

        │
        ▼

Allowed Git repos
Allowed clusters
Allowed namespaces
Allowed resource kinds
RBAC roles
OIDC groups
Production restrictions
```

That is where Argo CD starts looking like a **real multi-team enterprise deployment platform**, rather than simply a Kubernetes deployment tool.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.12.46 Professional Mastery Workbook

This workbook expands **Automated Sync, Self-Healing, Pruning, Drift & Production-Safe Sync Policies** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 45 lesson-specific anchors.
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

### Concept card 1 - The core GitOps equation

- Lesson anchor: Always keep this model in mind: Git Repository DESIRED STATE │ │ compare ▼ ┌─────────┐ │ Argo CD │ └────┬────┘ │ │ reconcile ▼ Kubernetes LIVE STATE For example, Git says: replicas: 2 but somebody executes: kubectl scale deployment todo-backend \
- Beginner explanation: Restate **The core GitOps equation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The core GitOps equation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **The core GitOps equation**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **The core GitOps equation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The core GitOps equation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - What is configuration drift?

- Lesson anchor: Drift means: Desired state != Live state Examples: Git                        Cluster replicas: 2                replicas: 5 image: v2                  image: v1 memory: 512Mi              memory: 1Gi service: ClusterIP         service: NodePort
- Beginner explanation: Restate **What is configuration drift?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What is configuration drift?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **What is configuration drift?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **What is configuration drift?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What is configuration drift?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Detecting drift vs fixing drift

- Lesson anchor: These are two separate things. Suppose: Git: replicas = 2 Cluster: replicas = 7 Argo CD can detect: Application │ ▼ OutOfSync But detecting drift does not automatically mean Argo CD will repair it. That's where: selfHeal
- Beginner explanation: Restate **Detecting drift vs fixing drift** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Detecting drift vs fixing drift** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Detecting drift vs fixing drift**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Detecting drift vs fixing drift**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Detecting drift vs fixing drift** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Automated synchronization

- Lesson anchor: Basic automated sync: spec: syncPolicy: automated: enabled: true This means that when Git changes and the application becomes OutOfSync, Argo CD can perform the synchronization automatically instead of requiring someone to press Sync or execute argocd app s...
- Beginner explanation: Restate **Automated synchronization** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Automated synchronization** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Automated synchronization**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Automated synchronization**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Automated synchronization** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Automated sync does not automatically mean self-healing

- Lesson anchor: This distinction is extremely important. Consider: spec: syncPolicy: automated: enabled: true Now somebody manually changes Kubernetes. kubectl scale deployment todo-backend \ --replicas=5 \ -n todo-production Git has not changed.
- Beginner explanation: Restate **Automated sync does not automatically mean self-healing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Automated sync does not automatically mean self-healing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Automated sync does not automatically mean self-healing**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Automated sync does not automatically mean self-healing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Automated sync does not automatically mean self-healing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Self-healing

- Lesson anchor: Enable: spec: syncPolicy: automated: enabled: true selfHeal: true Now: Git replicas = 2 │ │ ▼ Admin manually changes cluster replicas = 5 │ ▼ Argo CD detects drift │ ▼ selfHeal = true │ ▼ Argo CD reconciles │ ▼ replicas = 2 again
- Beginner explanation: Restate **Self-healing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Self-healing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Self-healing**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Self-healing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Self-healing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Production incident scenario

- Lesson anchor: Imagine 03:00 AM. CPU is high. Engineer panics and runs: kubectl scale deployment checkout-api \ --replicas=20 But Git says: replicas: 4 With self-healing enabled: 03:00:00 Engineer → replicas 20 03:00:xx Argo CD detects drift
- Beginner explanation: Restate **Production incident scenario** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production incident scenario** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Production incident scenario**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Production incident scenario**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production incident scenario** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - The next dangerous option: PRUNE

- Lesson anchor: Suppose Git contains: deployment.yaml service.yaml configmap.yaml Cluster therefore contains: Deployment Service ConfigMap Now you remove: configmap.yaml from Git. What should happen to the existing ConfigMap? There are two possible philosophies:
- Beginner explanation: Restate **The next dangerous option: PRUNE** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The next dangerous option: PRUNE** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **The next dangerous option: PRUNE**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **The next dangerous option: PRUNE**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The next dangerous option: PRUNE** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Automatic pruning

- Lesson anchor: Configure: spec: syncPolicy: automated: enabled: true prune: true Then: Git deployment.yaml service.yaml configmap.yaml │ ▼ Cluster Deployment Service ConfigMap Later Git: deployment.yaml service.yaml ConfigMap removed │
- Beginner explanation: Restate **Automatic pruning** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Automatic pruning** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Automatic pruning**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Automatic pruning**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Automatic pruning** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Why prune can be dangerous

- Lesson anchor: Imagine Git accidentally receives: rm -rf production/ git add . git commit -m "oops" git push Without proper protections: Git resources removed │ ▼ Argo CD │ ▼ Prune │ ▼ Kubernetes resources deleted This is why production GitOps requires:
- Beginner explanation: Restate **Why prune can be dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why prune can be dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Why prune can be dangerous**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Why prune can be dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why prune can be dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - allowEmpty

- Lesson anchor: There is an additional protection. Suppose pruning is enabled and Git suddenly contains zero application resources. Argo CD protects automated pruning from emptying an application unless allowEmpty is enabled. ([Argo CD][1])
- Beginner explanation: Restate **allowEmpty** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **allowEmpty** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **allowEmpty**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **allowEmpty**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **allowEmpty** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Our production baseline

- Lesson anchor: Now we can construct: spec: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false Meaning: enabled │ └── Deploy Git changes automatically prune │ └── Delete managed resources removed from Git selfHeal
- Beginner explanation: Restate **Our production baseline** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Our production baseline** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Our production baseline**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Our production baseline**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Our production baseline** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Hands-on drift experiment

- Lesson anchor: Assume: todo-production has: replicas: 2 Verify: kubectl get deployment todo-backend \ -n todo-production Expected: NAME           READY   UP-TO-DATE   AVAILABLE todo-backend   2/2     2            2 Now intentionally create drift:
- Beginner explanation: Restate **Hands-on drift experiment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hands-on drift experiment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Hands-on drift experiment**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Hands-on drift experiment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hands-on drift experiment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Very important distinction

- Lesson anchor: Suppose Kubernetes says: replicas: 5 and Argo CD changes it back to: replicas: 2 That is reconciliation. It is not: application rollback Think: ROLLBACK = change desired application revision SELF HEAL = restore live state to current desired revision
- Beginner explanation: Restate **Very important distinction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Very important distinction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Very important distinction**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Very important distinction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Very important distinction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Resource-level prune protection

- Lesson anchor: Maybe automatic pruning is enabled application-wide: automated: prune: true but one object is extremely sensitive. For example: PersistentVolumeClaim or perhaps a critical namespace/resource. You can mark a resource: metadata:
- Beginner explanation: Restate **Resource-level prune protection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Resource-level prune protection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Resource-level prune protection**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Resource-level prune protection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Resource-level prune protection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Prune with human approval

- Lesson anchor: An even better option for some critical resources is: metadata: annotations: argocd.argoproj.io/sync-options: Prune=confirm Now: Git removes resource │ ▼ Argo CD identifies prune │ ▼ DELETE immediately? NO │ ▼ Wait for approval
- Beginner explanation: Restate **Prune with human approval** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune with human approval** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Prune with human approval**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Prune with human approval**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune with human approval** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - PruneLast

- Lesson anchor: Now connect this to sync waves from Lesson 14.11. Suppose release v2 replaces: Old Service with: New Service You don't necessarily want Argo CD to remove obsolete resources too early. Use: syncPolicy: syncOptions: With PruneLast=true, pruning happens as a f...
- Beginner explanation: Restate **PruneLast** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PruneLast** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **PruneLast**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **PruneLast**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PruneLast** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - PRUNE vs DELETE — important distinction

- Lesson anchor: You will see both: Prune=false Delete=false They are not the same. Think: Resource disappeared from desired Git state Should Argo CD remove that cluster resource? Prune=false can prevent that pruning. Think: The entire Argo CD Application itself is being de...
- Beginner explanation: Restate **PRUNE vs DELETE — important distinction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PRUNE vs DELETE — important distinction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **PRUNE vs DELETE — important distinction**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **PRUNE vs DELETE — important distinction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PRUNE vs DELETE — important distinction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Example protecting persistent data

- Lesson anchor: apiVersion: v1 kind: PersistentVolumeClaim metadata: name: mongodb-data annotations: argocd.argoproj.io/sync-options: Delete=false,Prune=false spec: accessModes: resources: requests: storage: 20Gi Conceptually: Application lifecycle
- Beginner explanation: Restate **Example protecting persistent data** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example protecting persistent data** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Example protecting persistent data**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Example protecting persistent data**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example protecting persistent data** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - CreateNamespace=true

- Lesson anchor: You may currently create a Namespace YAML manually: kind: Namespace metadata: name: todo-production Argo CD can alternatively create the destination namespace. spec: destination: namespace: todo-production syncPolicy: syncOptions:
- Beginner explanation: Restate **CreateNamespace=true** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CreateNamespace=true** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **CreateNamespace=true**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **CreateNamespace=true**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CreateNamespace=true** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Server-Side Apply

- Lesson anchor: Now we reach an advanced Kubernetes concept. Traditional: kubectl apply is client-side apply. Argo CD normally uses standard kubectl apply behavior and the kubectl.kubernetes.io/last-applied-configuration annotation. ([Argo CD][4])
- Beginner explanation: Restate **Server-Side Apply** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Server-Side Apply** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Server-Side Apply**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Server-Side Apply**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Server-Side Apply** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Why field ownership matters

- Lesson anchor: Imagine one Deployment: spec: replicas: 3 But multiple systems interact with it: Argo CD │ ├── image ├── environment └── resource limits HPA │ └── replicas Operator │ └── injected configuration Kubernetes Server-Side Apply tracks field management informatio...
- Beginner explanation: Restate **Why field ownership matters** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why field ownership matters** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Why field ownership matters**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Why field ownership matters**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why field ownership matters** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - But be careful with ServerSideApply

- Lesson anchor: Don't think: ServerSideApply=true = better always No. Use it intentionally. Argo CD's current implementation applies SSA with conflict-forcing semantics, and it also supports client-side-apply migration for existing resources. ([Argo CD][4])
- Beginner explanation: Restate **But be careful with ServerSideApply** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **But be careful with ServerSideApply** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **But be careful with ServerSideApply**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **But be careful with ServerSideApply**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **But be careful with ServerSideApply** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Replace=true is MUCH more dangerous

- Lesson anchor: There is another option: syncOptions: This is not the same as SSA. Argo CD can use: kubectl replace or: kubectl create instead of normal apply semantics. Argo CD explicitly warns that this can recreate resources and cause outages. ([Argo CD][4])
- Beginner explanation: Restate **Replace=true is MUCH more dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Replace=true is MUCH more dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Replace=true is MUCH more dangerous**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Replace=true is MUCH more dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Replace=true is MUCH more dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Force=true is even more explicit

- Lesson anchor: Argo CD also supports cases where a resource is deliberately: DELETE + CREATE using force/replace behavior. For example, special Jobs may need recreation. But Argo CD warns that delete/create is destructive and can cause an outage. ([Argo CD][4])
- Beginner explanation: Restate **Force=true is even more explicit** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Force=true is even more explicit** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Force=true is even more explicit**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Force=true is even more explicit**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Force=true is even more explicit** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - IgnoreDifferences

- Lesson anchor: Now here's a very common production problem. Git says: replicas: 2 but you are using: HorizontalPodAutoscaler The HPA legitimately changes replicas: 2 ↓ 5 ↓ 8 ↓ 3 If Argo CD continually treats that field as unwanted drift, you may have controllers fighting.
- Beginner explanation: Restate **IgnoreDifferences** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **IgnoreDifferences** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **IgnoreDifferences**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **IgnoreDifferences**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **IgnoreDifferences** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Architecture with HPA

- Lesson anchor: Without thoughtful ownership: Deployment replicas ▲ │ ┌──────┴──────┐ │             │ │             │ Argo CD         HPA wants 2           wants 7 │             │ └──────┬──────┘ │ Controller Fight Better: Argo CD owns:
- Beginner explanation: Restate **Architecture with HPA** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Architecture with HPA** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Architecture with HPA**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Architecture with HPA**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Architecture with HPA** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Important trap with ignoreDifferences

- Lesson anchor: You might assume: ignoreDifferences = Argo CD never touches this field Not necessarily. By default, ignoreDifferences affects diff calculation; during sync, desired state can still be applied as-is. To make sync itself respect those ignored fields, Argo CD...
- Beginner explanation: Restate **Important trap with ignoreDifferences** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important trap with ignoreDifferences** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Important trap with ignoreDifferences**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Important trap with ignoreDifferences**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important trap with ignoreDifferences** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - FailOnSharedResource

- Lesson anchor: Imagine: Argo Application A │ └── ConfigMap global-config Argo Application B │ └── SAME ConfigMap global-config Which application owns it? Bad architecture. You can enable: syncOptions: Then Argo CD can fail the synchronization when it discovers that the re...
- Beginner explanation: Restate **FailOnSharedResource** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **FailOnSharedResource** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **FailOnSharedResource**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **FailOnSharedResource**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **FailOnSharedResource** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - ApplyOutOfSyncOnly

- Lesson anchor: Imagine your Argo CD Application contains: 5,000 Kubernetes resources but only: 2 resources changed. By default a sync can apply every resource. Argo CD provides: syncOptions: to synchronize only resources that are OutOfSync, reducing unnecessary work on la...
- Beginner explanation: Restate **ApplyOutOfSyncOnly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **ApplyOutOfSyncOnly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **ApplyOutOfSyncOnly**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **ApplyOutOfSyncOnly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **ApplyOutOfSyncOnly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - SkipDryRunOnMissingResource

- Lesson anchor: Suppose you work with operators and CRDs. Example: External Secrets Operator Prometheus Operator Gatekeeper Crossplane Service Mesh operators Sometimes the Custom Resource exists in Git while its CRD is not yet known during validation.
- Beginner explanation: Restate **SkipDryRunOnMissingResource** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SkipDryRunOnMissingResource** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **SkipDryRunOnMissingResource**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **SkipDryRunOnMissingResource**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SkipDryRunOnMissingResource** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Production-grade Application manifest

- Lesson anchor: Let's combine the major pieces: apiVersion: argoproj.io/v1alpha1 kind: Application metadata: name: todo-production namespace: argocd spec: project: production source: repoURL: https://github.com/company/gitops-repo.git targetRevision: main
- Beginner explanation: Restate **Production-grade Application manifest** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production-grade Application manifest** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Production-grade Application manifest**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Production-grade Application manifest**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production-grade Application manifest** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - What this manifest means

- Lesson anchor: Let's translate it into English: enabled=true "If Git changes, deploy automatically." prune=true "If an Argo-managed resource disappears from Git, it may be removed from Kubernetes." selfHeal=true "If somebody changes the live cluster,
- Beginner explanation: Restate **What this manifest means** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What this manifest means** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **What this manifest means**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **What this manifest means**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What this manifest means** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Production drift lab

- Lesson anchor: Now let's test all this practically. Git: replicas: 2 Push: git add . git commit -m "configure production GitOps policy" git push origin main Check: argocd app get todo-production Then: kubectl get deployment todo-backend \
- Beginner explanation: Restate **Production drift lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production drift lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Production drift lab**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Production drift lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production drift lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Test 2 — replica drift intentionally ignored

- Lesson anchor: Suppose Git: replicas: 2 but /spec/replicas is intentionally ignored. Run: kubectl scale deployment todo-backend \ --replicas=5 \ -n todo-production If your ignore configuration and sync ownership are set correctly: Git replicas 2
- Beginner explanation: Restate **Test 2 — replica drift intentionally ignored** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Test 2 — replica drift intentionally ignored** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Test 2 — replica drift intentionally ignored**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Test 2 — replica drift intentionally ignored**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Test 2 — replica drift intentionally ignored** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Good drift vs bad drift

- Lesson anchor: Someone executes: kubectl set image deployment/api api=evil:v1 Git says: api:v4.8 Argo should restore: api:v4.8 --- HPA changes: replicas 2 → 8 because CPU is high. We may intentionally let HPA own this field. --- Therefore:
- Beginner explanation: Restate **Good drift vs bad drift** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Good drift vs bad drift** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Good drift vs bad drift**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Good drift vs bad drift**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Good drift vs bad drift** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - A production anti-pattern

- Lesson anchor: Do not do this: Argo CD │ └── manages replicas HPA │ └── manages replicas Human │ └── kubectl scale replicas Three actors all owning: spec.replicas Then everybody wonders why the number keeps changing. Instead: FIELD OWNERSHIP
- Beginner explanation: Restate **A production anti-pattern** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **A production anti-pattern** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **A production anti-pattern**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **A production anti-pattern**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **A production anti-pattern** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Another production safety layer

- Lesson anchor: Let's mark a namespace: apiVersion: v1 kind: Namespace metadata: name: production annotations: argocd.argoproj.io/sync-options: Prune=confirm,Delete=confirm Argo CD supports confirmation controls separately for prune operations and application-deletion clea...
- Beginner explanation: Restate **Another production safety layer** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Another production safety layer** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Another production safety layer**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Another production safety layer**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Another production safety layer** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Argo CD automated sync retry

- Lesson anchor: Another production feature: syncPolicy: retry: limit: 5 backoff: duration: 5s factor: 2 maxDuration: 3m Argo CD supports automatic sync retries with exponential backoff. ([Argo CD][1]) Conceptually: Sync failed │ ▼ wait 5s
- Beginner explanation: Restate **Argo CD automated sync retry** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo CD automated sync retry** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Argo CD automated sync retry**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Argo CD automated sync retry**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo CD automated sync retry** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Incident troubleshooting flow

- Lesson anchor: If you discover: Argo CD keeps undoing my changes don't immediately disable Argo CD. Check: argocd app get todo-production Then: argocd app diff todo-production Check the Deployment: kubectl get deployment todo-backend \
- Beginner explanation: Restate **Incident troubleshooting flow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Incident troubleshooting flow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Incident troubleshooting flow**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Incident troubleshooting flow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Incident troubleshooting flow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Important production rule about rollback

- Lesson anchor: Argo CD's current automated-sync documentation notes that a rollback cannot be performed against an Application while automated sync is enabled. ([Argo CD][1]) In a strong GitOps process, the normal recovery path is often:
- Beginner explanation: Restate **Important production rule about rollback** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important production rule about rollback** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Important production rule about rollback**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Important production rule about rollback**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important production rule about rollback** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Interview questions

- Lesson anchor: It allows Argo CD automated sync to reconcile live-cluster drift back toward Git-defined desired state. ([Argo CD][1]) --- No. Automatic pruning is separately enabled with: prune: true ([Argo CD][1]) --- It allows automated pruning to leave an application w...
- Beginner explanation: Restate **Interview questions** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview questions** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview questions**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview questions**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview questions** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Never-forget memory map

- Lesson anchor: Memorize this: GIT Desired State │ ▼ Argo CD │ ┌──────────┴──────────┐ │                     │ ▼                     ▼ Git changed           Cluster changed │                     │ ▼                     ▼ AUTO SYNC              SELF HEAL
- Beginner explanation: Restate **Never-forget memory map** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget memory map** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Never-forget memory map**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Never-forget memory map**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget memory map** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - The five lines you must never forget

- Lesson anchor: AUTO SYNC = Git change → cluster deployment SELF HEAL = Cluster drift → restore desired state PRUNE = Removed from Git → remove from cluster IGNORE DIFFERENCE = This difference is intentional GIT = Source of truth ---
- Beginner explanation: Restate **The five lines you must never forget** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The five lines you must never forget** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **The five lines you must never forget**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **The five lines you must never forget**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The five lines you must never forget** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Where we are in Module 14

- Lesson anchor: Module 14 — GitOps with Argo CD 14.1  GitOps Mental Model                    ✅ 14.2  Argo CD Architecture                   ✅ 14.3  Installation                           ✅ 14.4  Applications                           ✅ 14.5  Automated Reconciliation...
- Beginner explanation: Restate **Where we are in Module 14** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Where we are in Module 14** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Where we are in Module 14**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Where we are in Module 14**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Where we are in Module 14** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - The core GitOps equation x change management

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **The core GitOps equation** while a change involving **Automated synchronization** places **change management** at risk.
- Plain-language question: What problem does **The core GitOps equation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Always keep this model in mind: Git Repository DESIRED STATE │ │ compare ▼ ┌─────────┐ │ Argo CD │ └────┬────┘ │ │ reconcile ▼ Kubernetes LIVE STATE For example, Git says: replicas: 2 but somebody executes: kubectl scale deployment todo-backend \
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
- Interview prompt: Defend **The core GitOps equation** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - What is configuration drift? x dependency failure

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **What is configuration drift?** while a change involving **allowEmpty** places **dependency failure** at risk.
- Plain-language question: What problem does **What is configuration drift?** solve here, and who notices first when it fails?
- Lesson evidence anchor: Drift means: Desired state != Live state Examples: Git                        Cluster replicas: 2                replicas: 5 image: v2                  image: v1 memory: 512Mi              memory: 1Gi service: ClusterIP         service: NodePort
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
- Interview prompt: Defend **What is configuration drift?** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Detecting drift vs fixing drift x developer experience

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Detecting drift vs fixing drift** while a change involving **PRUNE vs DELETE — important distinction** places **developer experience** at risk.
- Plain-language question: What problem does **Detecting drift vs fixing drift** solve here, and who notices first when it fails?
- Lesson evidence anchor: These are two separate things. Suppose: Git: replicas = 2 Cluster: replicas = 7 Argo CD can detect: Application │ ▼ OutOfSync But detecting drift does not automatically mean Argo CD will repair it. That's where: selfHeal
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
- Interview prompt: Defend **Detecting drift vs fixing drift** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Automated synchronization x availability

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Automated synchronization** while a change involving **Force=true is even more explicit** places **availability** at risk.
- Plain-language question: What problem does **Automated synchronization** solve here, and who notices first when it fails?
- Lesson evidence anchor: Basic automated sync: spec: syncPolicy: automated: enabled: true This means that when Git changes and the application becomes OutOfSync, Argo CD can perform the synchronization automatically instead of requiring someone to press Sync or execute argocd app s...
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
- Interview prompt: Defend **Automated synchronization** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Automated sync does not automatically mean self-healing x security

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Automated sync does not automatically mean self-healing** while a change involving **Production-grade Application manifest** places **security** at risk.
- Plain-language question: What problem does **Automated sync does not automatically mean self-healing** solve here, and who notices first when it fails?
- Lesson evidence anchor: This distinction is extremely important. Consider: spec: syncPolicy: automated: enabled: true Now somebody manually changes Kubernetes. kubectl scale deployment todo-backend \ --replicas=5 \ -n todo-production Git has not changed.
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
- Interview prompt: Defend **Automated sync does not automatically mean self-healing** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Self-healing x delivery safety

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Self-healing** while a change involving **Argo CD automated sync retry** places **delivery safety** at risk.
- Plain-language question: What problem does **Self-healing** solve here, and who notices first when it fails?
- Lesson evidence anchor: Enable: spec: syncPolicy: automated: enabled: true selfHeal: true Now: Git replicas = 2 │ │ ▼ Admin manually changes cluster replicas = 5 │ ▼ Argo CD detects drift │ ▼ selfHeal = true │ ▼ Argo CD reconciles │ ▼ replicas = 2 again
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
- Interview prompt: Defend **Self-healing** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Production incident scenario x multi-tenancy

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Production incident scenario** while a change involving **The core GitOps equation** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Production incident scenario** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine 03:00 AM. CPU is high. Engineer panics and runs: kubectl scale deployment checkout-api \ --replicas=20 But Git says: replicas: 4 With self-healing enabled: 03:00:00 Engineer → replicas 20 03:00:xx Argo CD detects drift
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
- Interview prompt: Defend **Production incident scenario** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - The next dangerous option: PRUNE x observability

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **The next dangerous option: PRUNE** while a change involving **Automatic pruning** places **observability** at risk.
- Plain-language question: What problem does **The next dangerous option: PRUNE** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose Git contains: deployment.yaml service.yaml configmap.yaml Cluster therefore contains: Deployment Service ConfigMap Now you remove: configmap.yaml from Git. What should happen to the existing ConfigMap? There are two possible philosophies:
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
- Interview prompt: Defend **The next dangerous option: PRUNE** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Automatic pruning x regional resilience

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Automatic pruning** while a change involving **Resource-level prune protection** places **regional resilience** at risk.
- Plain-language question: What problem does **Automatic pruning** solve here, and who notices first when it fails?
- Lesson evidence anchor: Configure: spec: syncPolicy: automated: enabled: true prune: true Then: Git deployment.yaml service.yaml configmap.yaml │ ▼ Cluster Deployment Service ConfigMap Later Git: deployment.yaml service.yaml ConfigMap removed │
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
- Interview prompt: Defend **Automatic pruning** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Why prune can be dangerous x business value

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Why prune can be dangerous** while a change involving **Why field ownership matters** places **business value** at risk.
- Plain-language question: What problem does **Why prune can be dangerous** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine Git accidentally receives: rm -rf production/ git add . git commit -m "oops" git push Without proper protections: Git resources removed │ ▼ Argo CD │ ▼ Prune │ ▼ Kubernetes resources deleted This is why production GitOps requires:
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
- Interview prompt: Defend **Why prune can be dangerous** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - allowEmpty x latency

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **allowEmpty** while a change involving **FailOnSharedResource** places **latency** at risk.
- Plain-language question: What problem does **allowEmpty** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is an additional protection. Suppose pruning is enabled and Git suddenly contains zero application resources. Argo CD protects automated pruning from emptying an application unless allowEmpty is enabled. ([Argo CD][1])
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
- Interview prompt: Defend **allowEmpty** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Our production baseline x privacy

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Our production baseline** while a change involving **Good drift vs bad drift** places **privacy** at risk.
- Plain-language question: What problem does **Our production baseline** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now we can construct: spec: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false Meaning: enabled │ └── Deploy Git changes automatically prune │ └── Delete managed resources removed from Git selfHeal
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
- Interview prompt: Defend **Our production baseline** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Hands-on drift experiment x operability

- Learning level: Certification review.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Hands-on drift experiment** while a change involving **Never-forget memory map** places **operability** at risk.
- Plain-language question: What problem does **Hands-on drift experiment** solve here, and who notices first when it fails?
- Lesson evidence anchor: Assume: todo-production has: replicas: 2 Verify: kubectl get deployment todo-backend \ -n todo-production Expected: NAME           READY   UP-TO-DATE   AVAILABLE todo-backend   2/2     2            2 Now intentionally create drift:
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
- Interview prompt: Defend **Hands-on drift experiment** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Very important distinction x data integrity

- Learning level: Interview defense.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Very important distinction** while a change involving **Automated sync does not automatically mean self-healing** places **data integrity** at risk.
- Plain-language question: What problem does **Very important distinction** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose Kubernetes says: replicas: 5 and Argo CD changes it back to: replicas: 2 That is reconciliation. It is not: application rollback Think: ROLLBACK = change desired application revision SELF HEAL = restore live state to current desired revision
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
- Interview prompt: Defend **Very important distinction** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Resource-level prune protection x automation safety

- Learning level: Beginner.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Resource-level prune protection** while a change involving **Our production baseline** places **automation safety** at risk.
- Plain-language question: What problem does **Resource-level prune protection** solve here, and who notices first when it fails?
- Lesson evidence anchor: Maybe automatic pruning is enabled application-wide: automated: prune: true but one object is extremely sensitive. For example: PersistentVolumeClaim or perhaps a critical namespace/resource. You can mark a resource: metadata:
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
- Interview prompt: Defend **Resource-level prune protection** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Prune with human approval x governance

- Learning level: Intermediate.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Prune with human approval** while a change involving **Example protecting persistent data** places **governance** at risk.
- Plain-language question: What problem does **Prune with human approval** solve here, and who notices first when it fails?
- Lesson evidence anchor: An even better option for some critical resources is: metadata: annotations: argocd.argoproj.io/sync-options: Prune=confirm Now: Git removes resource │ ▼ Argo CD identifies prune │ ▼ DELETE immediately? NO │ ▼ Wait for approval
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
- Interview prompt: Defend **Prune with human approval** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - PruneLast x correctness

- Learning level: Expert.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **PruneLast** while a change involving **IgnoreDifferences** places **correctness** at risk.
- Plain-language question: What problem does **PruneLast** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now connect this to sync waves from Lesson 14.11. Suppose release v2 replaces: Old Service with: New Service You don't necessarily want Argo CD to remove obsolete resources too early. Use: syncPolicy: syncOptions: With PruneLast=true, pruning happens as a f...
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
- Interview prompt: Defend **PruneLast** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - PRUNE vs DELETE — important distinction x capacity

- Learning level: Professional.
- Environment: an isolated CI environment.
- Scenario: The team must apply **PRUNE vs DELETE — important distinction** while a change involving **What this manifest means** places **capacity** at risk.
- Plain-language question: What problem does **PRUNE vs DELETE — important distinction** solve here, and who notices first when it fails?
- Lesson evidence anchor: You will see both: Prune=false Delete=false They are not the same. Think: Resource disappeared from desired Git state Should Argo CD remove that cluster resource? Prune=false can prevent that pruning. Think: The entire Argo CD Application itself is being de...
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
- Interview prompt: Defend **PRUNE vs DELETE — important distinction** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Example protecting persistent data x cost efficiency

- Learning level: Industry-ready.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Example protecting persistent data** while a change involving **Incident troubleshooting flow** places **cost efficiency** at risk.
- Plain-language question: What problem does **Example protecting persistent data** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: v1 kind: PersistentVolumeClaim metadata: name: mongodb-data annotations: argocd.argoproj.io/sync-options: Delete=false,Prune=false spec: accessModes: resources: requests: storage: 20Gi Conceptually: Application lifecycle
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
- Interview prompt: Defend **Example protecting persistent data** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - CreateNamespace=true x recovery

- Learning level: Certification review.
- Environment: an isolated CI environment.
- Scenario: The team must apply **CreateNamespace=true** while a change involving **What is configuration drift?** places **recovery** at risk.
- Plain-language question: What problem does **CreateNamespace=true** solve here, and who notices first when it fails?
- Lesson evidence anchor: You may currently create a Namespace YAML manually: kind: Namespace metadata: name: todo-production Argo CD can alternatively create the destination namespace. spec: destination: namespace: todo-production syncPolicy: syncOptions:
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
- Interview prompt: Defend **CreateNamespace=true** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Server-Side Apply x change management

- Learning level: Interview defense.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Server-Side Apply** while a change involving **Automatic pruning** places **change management** at risk.
- Plain-language question: What problem does **Server-Side Apply** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now we reach an advanced Kubernetes concept. Traditional: kubectl apply is client-side apply. Argo CD normally uses standard kubectl apply behavior and the kubectl.kubernetes.io/last-applied-configuration annotation. ([Argo CD][4])
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
- Interview prompt: Defend **Server-Side Apply** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Why field ownership matters x dependency failure

- Learning level: Beginner.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Why field ownership matters** while a change involving **Prune with human approval** places **dependency failure** at risk.
- Plain-language question: What problem does **Why field ownership matters** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine one Deployment: spec: replicas: 3 But multiple systems interact with it: Argo CD │ ├── image ├── environment └── resource limits HPA │ └── replicas Operator │ └── injected configuration Kubernetes Server-Side Apply tracks field management informatio...
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
- Interview prompt: Defend **Why field ownership matters** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - But be careful with ServerSideApply x developer experience

- Learning level: Intermediate.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **But be careful with ServerSideApply** while a change involving **Replace=true is MUCH more dangerous** places **developer experience** at risk.
- Plain-language question: What problem does **But be careful with ServerSideApply** solve here, and who notices first when it fails?
- Lesson evidence anchor: Don't think: ServerSideApply=true = better always No. Use it intentionally. Argo CD's current implementation applies SSA with conflict-forcing semantics, and it also supports client-side-apply migration for existing resources. ([Argo CD][4])
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
- Interview prompt: Defend **But be careful with ServerSideApply** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Replace=true is MUCH more dangerous x availability

- Learning level: Expert.
- Environment: an isolated CI environment.
- Scenario: The team must apply **Replace=true is MUCH more dangerous** while a change involving **ApplyOutOfSyncOnly** places **availability** at risk.
- Plain-language question: What problem does **Replace=true is MUCH more dangerous** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is another option: syncOptions: This is not the same as SSA. Argo CD can use: kubectl replace or: kubectl create instead of normal apply semantics. Argo CD explicitly warns that this can recreate resources and cause outages. ([Argo CD][4])
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
- Interview prompt: Defend **Replace=true is MUCH more dangerous** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Force=true is even more explicit x security

- Learning level: Professional.
- Environment: a dependency brownout exercise.
- Scenario: The team must apply **Force=true is even more explicit** while a change involving **A production anti-pattern** places **security** at risk.
- Plain-language question: What problem does **Force=true is even more explicit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD also supports cases where a resource is deliberately: DELETE + CREATE using force/replace behavior. For example, special Jobs may need recreation. But Argo CD warns that delete/create is destructive and can cause an outage. ([Argo CD][4])
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
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
- Interview prompt: Defend **Force=true is even more explicit** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - IgnoreDifferences x delivery safety

- Learning level: Industry-ready.
- Environment: an isolated CI environment.
- Scenario: The team must apply **IgnoreDifferences** while a change involving **The five lines you must never forget** places **delivery safety** at risk.
- Plain-language question: What problem does **IgnoreDifferences** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now here's a very common production problem. Git says: replicas: 2 but you are using: HorizontalPodAutoscaler The HPA legitimately changes replicas: 2 ↓ 5 ↓ 8 ↓ 3 If Argo CD continually treats that field as unwanted drift, you may have controllers fighting.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
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
- Interview prompt: Defend **IgnoreDifferences** against an alternative while protecting delivery safety under this scenario.
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

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ "Automated Sync Policy - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/ "Diff Customization - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/application-specification/ "Application Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/ "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
