# Module 14 — GitOps with Argo CD

## Lesson 4: Automated Sync, Self-Heal, Prune & Production Sync Safety

In Lesson 3 our application worked like this:

```text
Git
 │
 ▼
Argo detects difference
 │
 ▼
OutOfSync
 │
 ▼
HUMAN:
argocd app sync
 │
 ▼
Kubernetes reconciled
```

Now we're going to remove that human step.

But first, permanently separate these three controls:

```text
AUTO-SYNC
=
desired state changed
→ automatically reconcile


SELF-HEAL
=
live cluster changed
→ automatically restore Git state


PRUNE
=
resource removed from desired state
→ automatically delete live resource
```

They are related, but **they are not the same feature**. Argo CD deliberately keeps pruning and live-state self-healing separately configurable. ([Argo CD][1])

---

# 14.346 Our starting state

Make sure Lesson 3's application still exists:

```bash
argocd app get guestbook
```

Then:

```bash
kubectl get deployment guestbook-ui -n guestbook
```

You want approximately:

```text
READY
1/1
```

Check the desired replica count:

```bash
kubectl get deployment guestbook-ui \
  -n guestbook \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

Expected:

```text
1
```

And ideally:

```text
Sync Status:   Synced
Health Status: Healthy
```

---

# 14.347 The automated-sync configuration

A modern explicit configuration is:

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
```

Argo CD also accepts:

```yaml
automated: {}
```

as enabled. Current versions expose `automated.enabled` explicitly; `enabled: false` disables automated synchronization even if `prune`, `selfHeal`, or `allowEmpty` fields are present. A `null`/omitted `enabled` under an existing automated block is treated as enabled. ([argo-cd.readthedocs.io][1])

For learning, I prefer:

```yaml
enabled: true
```

because the intent is obvious.

---

# 14.348 Enable auto-sync — but NOT self-heal or prune yet

Patch our current Application:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": true,
          "prune": false,
          "selfHeal": false,
          "allowEmpty": false
        },
        "syncOptions": [
          "CreateNamespace=true"
        ]
      }
    }
  }'
```

Now:

```bash
argocd app get guestbook
```

You should see approximately:

```text
Sync Policy:
Automated
```

At this point:

```text
Auto-sync      ✓
Self-heal      ✕
Prune          ✕
Allow empty    ✕
```

---

# 14.349 What does auto-sync actually remove?

Old flow:

```text
Git change
   │
   ▼
OutOfSync
   │
   ▼
Operator
   │
   ▼
argocd app sync
```

New flow:

```text
Desired state changes
   │
   ▼
Argo detects OutOfSync
   │
   ▼
AUTO-SYNC
   │
   ▼
Kubernetes reconciliation
```

This is why CI doesn't need to invoke:

```bash
argocd app sync
```

for normal auto-sync deployments. A pipeline can update the tracked Git repository, and Argo CD performs synchronization itself. ([Argo CD][1])

---

# 14.350 How auto-sync behaves internally

Conceptually:

```text
Application Controller
        │
        ▼
Desired Revision A
        │
        ▼
Live State A
        │
        ▼
Synced
```

Later:

```text
Desired Revision B
        │
        ▼
Live State A
        │
        ▼
OutOfSync
        │
        ▼
Auto-Sync
        │
        ▼
Live State B
```

Argo CD only auto-syncs an application when it is `OutOfSync`. It also tracks synchronization by Git revision plus application parameters rather than repeatedly performing the same successful sync indefinitely. ([argo-cd.readthedocs.io][1])

---

# 14.351 Practical auto-sync experiment without owning Git yet

We don't own the official example repository, so we cannot make a genuine Git commit there.

Instead, we can safely prove the **automatic reconciliation mechanism** by temporarily changing which directory our Application tracks.

Current:

```text
argocd-example-apps
       │
       ▼
guestbook/
```

The official example repository also contains:

```text
kustomize-guestbook/
```

whose Kustomize configuration prefixes generated resource names with `kustomize-`. ([GitHub][2])

So temporarily change:

```text
guestbook
```

to:

```text
kustomize-guestbook
```

---

# 14.352 Trigger automated synchronization

Run:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "source": {
        "path": "kustomize-guestbook"
      }
    }
  }'
```

Do **not** run:

```bash
argocd app sync guestbook
```

That's the whole experiment.

Watch:

```bash
argocd app get guestbook --refresh
```

and:

```bash
kubectl get deployment,service -n guestbook
```

You should eventually see resources corresponding to:

```text
kustomize-guestbook-ui
```

created automatically.

---

# 14.353 What proved auto-sync?

You only changed:

```text
Application desired source
```

You did **not** manually sync.

Yet:

```text
desired configuration changed
        │
        ▼
Argo detected OutOfSync
        │
        ▼
auto-sync
        │
        ▼
new resources created
```

That's automated reconciliation.

In Lesson 5 we'll own the configuration repository ourselves, so the trigger will become the real production path:

```text
git commit
   │
   ▼
git push
   │
   ▼
Argo detects new revision
   │
   ▼
auto-sync
```

---

# 14.354 But look carefully — something interesting happened

Run:

```bash
kubectl get deployment,service -n guestbook
```

You may now have:

```text
guestbook-ui

and

kustomize-guestbook-ui
```

Why?

Because:

```text
Auto-sync = true
```

but:

```text
Prune = false
```

Argo created the newly desired resources.

But it was **not authorized to automatically delete resources that disappeared from desired state**.

Automated pruning is intentionally disabled by default as a safety mechanism. ([argo-cd.readthedocs.io][1])

This is a perfect demonstration of:

```text
AUTO-SYNC
≠
PRUNE
```

---

# 14.355 Restore the original Git path

Run:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "source": {
        "path": "guestbook"
      }
    }
  }'
```

Again:

```text
do NOT manually sync.
```

Auto-sync will reconcile toward the original `guestbook` desired resources.

But:

```text
kustomize-guestbook-ui
```

may remain because:

```text
prune = false.
```

Now we have created the perfect lab condition for pruning.

---

# 14.356 Prune mental model

Suppose Git yesterday contained:

```text
Deployment
Service
ConfigMap
```

Today Git contains:

```text
Deployment
Service
```

Then:

```text
ConfigMap

exists live

but no longer exists
in desired state.
```

That's an:

```text
EXTRANEOUS RESOURCE
```

Pruning means:

```text
Desired says
resource should not exist

        ↓

Argo deletes it
```

---

# 14.357 Enable automatic pruning

Patch:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": true,
          "prune": true,
          "selfHeal": false,
          "allowEmpty": false
        },
        "syncOptions": [
          "CreateNamespace=true"
        ]
      }
    }
  }'
```

Current state:

```text
Auto-sync      ✓
Prune          ✓
Self-heal      ✕
Allow empty    ✕
```

Automatic pruning is enabled with `automated.prune: true`. ([Argo CD][1])

---

# 14.358 Watch pruning happen

Run:

```bash
argocd app get guestbook --refresh
```

Then:

```bash
kubectl get deployment,service -n guestbook
```

The temporary Kustomize resources that were previously managed by this Application but are no longer desired should disappear as Argo reconciles the application with pruning enabled.

Eventually we want only the original guestbook resources again.

Concept:

```text
Git:
guestbook-ui

Live:
guestbook-ui
kustomize-guestbook-ui
         │
         ▼
        PRUNE
         │
         ▼
Live:
guestbook-ui
```

---

# 14.359 This is powerful — and dangerous

Imagine a bad production commit accidentally deletes:

```text
payments/
```

from the GitOps repository.

Without prune:

```text
Argo:
OutOfSync

resources remain.
```

With prune:

```text
Argo:
Git says they should not exist.

Delete.
```

Therefore:

# **Auto-prune turns Git deletion into infrastructure deletion.**

That's why branch protection and code review are production controls, not optional Git hygiene.

---

# 14.360 Prune does not mean delete everything blindly

Argo provides resource-level protection.

For a resource:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
```

Argo skips pruning that object. Resource-level `Prune=false` overrides application-level pruning behavior for that resource. ([Argo CD][3])

Use this deliberately, not everywhere.

---

# 14.361 `Prune=confirm`

For critical objects, Argo supports:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=confirm
```

Then Argo requires explicit approval before pruning that resource. ([Argo CD][3])

This can be useful for resources such as:

```text
Namespace

important PVC-related objects

critical shared infrastructure
```

where accidental deletion deserves an additional human check.

---

# 14.362 Production deletion-defense layers

A strong production pattern can look like:

```text
Git PR approval
      │
      ▼
auto-prune
      │
      ▼
critical object?
      │
      ├── No
      │    ▼
      │   prune
      │
      └── Yes
           ▼
       Prune=confirm
           │
           ▼
      manual approval
```

This gives automation without treating all resources as equally disposable.

---

# 14.363 `allowEmpty`

Now imagine the Git path renders:

```text
0 resources.
```

With:

```text
auto-sync = true
prune     = true
```

a naïve system could conclude:

```text
Git wants nothing.

Delete everything.
```

That is scary.

Argo CD therefore protects auto-pruned Applications from becoming completely empty by default. To explicitly allow an automated prune to zero desired resources, you must set:

```yaml
allowEmpty: true
```

alongside pruning. ([argo-cd.readthedocs.io][1])

---

# 14.364 Never-forget `allowEmpty`

```text
allowEmpty = false

"No desired resources?
Do NOT automatically wipe
the application to zero."
```

versus:

```text
allowEmpty = true

"Zero resources is a
valid desired state."
```

For normal production applications, I'd generally keep:

```yaml
allowEmpty: false
```

unless an intentionally empty application lifecycle is part of the design.

---

# 14.365 Current policy so far

We have:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: true
    selfHeal: false
    allowEmpty: false

  syncOptions:
    - CreateNamespace=true
```

Now we'll demonstrate the feature most people associate with GitOps:

# self-healing.

---

# 14.366 First prove that auto-sync is NOT self-heal

Make sure the app is fully converged:

```bash
argocd app get guestbook --refresh
```

You want:

```text
Synced
Healthy
```

Then:

```bash
kubectl scale deployment \
  guestbook-ui \
  --replicas=3 \
  -n guestbook
```

Check:

```bash
kubectl get deployment guestbook-ui -n guestbook
```

Now:

```text
Live = 3

Git = 1
```

Refresh:

```bash
argocd app get guestbook --refresh
```

You should see:

```text
OutOfSync
```

---

# 14.367 Why doesn't plain auto-sync necessarily fix this?

Because no new desired Git revision/application parameter combination needs deploying.

The live cluster drifted **after** the desired revision was already successfully synchronized.

Current Argo CD semantics only automatically resynchronize the same successful commit/parameters in response to live-state drift when `selfHeal` is enabled. ([argo-cd.readthedocs.io][1])

So:

```text
AUTO-SYNC

primarily:
desired state changed
        ↓
reconcile


SELF-HEAL

live state changed
        ↓
reconcile
```

---

# 14.368 Enable self-healing

Run:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": true,
          "prune": true,
          "selfHeal": true,
          "allowEmpty": false
        },
        "syncOptions": [
          "CreateNamespace=true"
        ]
      }
    }
  }'
```

Now:

```text
Auto-sync      ✓
Prune          ✓
Self-heal      ✓
Allow empty    ✕
```

Self-heal instructs Argo CD to automatically synchronize when live cluster state deviates from Git. ([Argo CD][1])

---

# 14.369 Watch self-heal

Use:

```bash
watch -n 1 \
  kubectl get deployment guestbook-ui -n guestbook
```

You should observe:

```text
3
↓
1
```

after Argo detects and reconciles the drift.

Current Argo CD uses a default self-heal retry timeout of **5 seconds after the drift is detected**, though overall visible timing also depends on reconciliation/refresh timing. ([argo-cd.readthedocs.io][1])

Press:

```text
Ctrl+C
```

to stop `watch`.

---

# 14.370 Repeat the experiment

Run:

```bash
kubectl scale deployment \
  guestbook-ui \
  --replicas=10 \
  -n guestbook
```

Then:

```bash
watch -n 1 \
  kubectl get deployment guestbook-ui -n guestbook
```

You should see something conceptually like:

```text
DESIRED   CURRENT

10        ...
```

and then Argo restores the Kubernetes Deployment spec to:

```text
1
```

because Git still declares one replica.

This is real:

# continuous reconciliation.

---

# 14.371 Why engineers sometimes think Argo is "fighting them"

Incident engineer:

```bash
kubectl scale payment-api --replicas=0
```

Argo:

```text
Git says replicas = 10.
```

Self-heal:

```text
0 → 10
```

Engineer:

> Why does Kubernetes keep bringing it back?!

Not Kubernetes alone.

You are fighting:

```text
Argo CD desired-state controller.
```

---

# 14.372 The correct emergency thought process

When self-heal is active:

```text
Live emergency change
       │
       ▼
Argo sees drift
       │
       ▼
Argo reverses change
```

So emergency procedures must consider the reconciler.

Options include:

```text
1. Make an emergency Git change.

2. Temporarily disable automated sync.

3. Perform controlled break-glass change.

4. Update Git to reflect the final desired state.

5. Re-enable reconciliation.
```

Do not repeatedly fight the controller with `kubectl`.

---

# 14.373 Temporarily pause a standalone Application

For this standalone Application:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": false,
          "prune": true,
          "selfHeal": true,
          "allowEmpty": false
        }
      }
    }
  }'
```

With:

```yaml
enabled: false
```

Argo skips automated synchronization even though the other automated-policy fields remain configured. ([argo-cd.readthedocs.io][1])

Think:

```text
configuration retained

but

automation paused.
```

---

# 14.374 ApplicationSet warning

Later, when an Application is generated by:

```text
ApplicationSet
```

manually changing the generated child's:

```yaml
spec.syncPolicy.automated
```

is not the proper way to disable auto-sync—the ApplicationSet controller owns that Application spec and can restore it. Argo's current docs explicitly distinguish standalone Applications from ApplicationSet-managed ones for auto-sync toggling. ([argo-cd.readthedocs.io][1])

This becomes extremely important later.

---

# 14.375 Re-enable our lab

Run:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": true,
          "prune": true,
          "selfHeal": true,
          "allowEmpty": false
        },
        "syncOptions": [
          "CreateNamespace=true"
        ]
      }
    }
  }'
```

Return to:

```text
AUTO      ✓
PRUNE     ✓
HEAL      ✓
EMPTY     ✕
```

---

# 14.376 Full production-style automated policy

A useful baseline looks like:

```yaml
spec:
  syncPolicy:

    automated:
      enabled: true
      prune: true
      selfHeal: true
      allowEmpty: false

    syncOptions:
      - CreateNamespace=true
```

But don't interpret this as:

> “Every production application should blindly use these exact settings.”

The appropriate pruning, self-heal, and approval model depends on the application's ownership and failure consequences.

---

# 14.377 `PruneLast=true`

Now imagine one deployment changes architecture.

Old:

```text
Service A
Deployment A
```

New:

```text
Service B
Deployment B
```

You may want new resources to deploy and become healthy before obsolete resources are pruned.

Argo supports:

```yaml
syncOptions:
  - PruneLast=true
```

With this option, pruning occurs as an implicit final sync wave, after other resources have deployed and become healthy and previous sync waves have completed. ([Argo CD][3])

Mental shortcut:

```text
DEPLOY NEW
   ↓
HEALTHY
   ↓
THEN PRUNE OLD
```

---

# 14.378 Add `PruneLast`

Our lab could become:

```yaml
syncPolicy:

  automated:
    enabled: true
    prune: true
    selfHeal: true
    allowEmpty: false

  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
```

That is often a safer deletion ordering model than pruning old resources as early as possible.

---

# 14.379 Prune propagation policy

Kubernetes deletion has garbage-collection semantics.

Argo lets you choose:

```text
foreground

background

orphan
```

through:

```yaml
syncOptions:
  - PrunePropagationPolicy=foreground
```

`foreground` is the current default for Argo pruning. ([Argo CD][3])

---

# 14.380 Simplified deletion propagation

## Foreground

```text
Parent deletion requested

wait for dependent resources
        ↓
delete dependents
        ↓
parent disappears
```

## Background

```text
Parent disappears
        ↓
Kubernetes cleans dependents
in background
```

## Orphan

```text
Delete parent

leave dependents behind.
```

Do not change this merely because another mode sounds faster.

Understand object ownership first.

---

# 14.381 `ApplyOutOfSyncOnly=true`

By default, during a synchronization Argo applies all application objects.

At very large scale:

```text
Application
=
5,000 resources
```

but maybe only:

```text
3 resources
```

actually differ.

Argo supports:

```yaml
syncOptions:
  - ApplyOutOfSyncOnly=true
```

so it applies only resources that are currently `OutOfSync`, reducing work against the Kubernetes API for very large Applications. Sync hooks still run and the operation remains in application history. ([Argo CD][3])

---

# 14.382 When should you care about `ApplyOutOfSyncOnly`?

Probably not for our:

```text
2-resource guestbook.
```

But imagine a platform Application containing:

```text
CRDs
Namespaces
RBAC
NetworkPolicies
Deployments
Services
ConfigMaps
PrometheusRules
...
```

across thousands of resources.

Then:

```text
apply everything
```

on every sync can create unnecessary API load.

Use `ApplyOutOfSyncOnly` primarily as a **scale/performance control**, not as a GitOps requirement.

---

# 14.383 `FailOnSharedResource=true`

Another production-grade option:

```yaml
syncOptions:
  - FailOnSharedResource=true
```

By default, Argo may encounter resources already managed by another Application. With this option, synchronization fails when a resource is already associated with another Application. ([Argo CD][3])

This helps enforce:

> **One Kubernetes resource → one authoritative Argo Application owner.**

Remember our Terraform rule?

```text
One resource
→ one authoritative state owner
```

GitOps has the same principle.

---

# 14.384 Why shared resource ownership is dangerous

Imagine:

```text
Application A
       │
       ▼
ConfigMap/common-config


Application B
       │
       ▼
same ConfigMap/common-config
```

A sync from A writes:

```text
VALUE=A
```

A sync from B writes:

```text
VALUE=B
```

Next A:

```text
VALUE=A
```

You created controller warfare.

A production GitOps design should minimize ambiguous ownership.

---

# 14.385 `RespectIgnoreDifferences=true`

Remember our HPA example.

Suppose:

```text
Git
Deployment replicas = 3
```

but:

```text
HPA
owns replicas dynamically.
```

You may configure:

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

By default, `ignoreDifferences` affects diff calculation, but the full desired manifest can still be applied during sync. `RespectIgnoreDifferences=true` tells Argo to also honor those exclusions during synchronization for already existing resources. ([Argo CD][3])

Example:

```yaml
syncOptions:
  - RespectIgnoreDifferences=true
```

---

# 14.386 Field ownership rule

This is one of the strongest rules in the entire module:

```text
Argo owns image tag.

HPA owns replica count.

cert-manager owns generated certificate state.

Operator owns operator-generated fields.
```

Do not make every controller fight for every field.

GitOps becomes reliable when ownership is explicit.

---

# 14.387 `ServerSideApply=true`

Argo also supports:

```yaml
syncOptions:
  - ServerSideApply=true
```

Current behavior uses Kubernetes server-side apply with conflict handling instead of the default client-side apply model. Argo highlights use cases including very large resources and resources that are only partially managed by Argo. ([Argo CD][3])

This will matter more when we manage:

```text
large CRDs

shared/partially managed objects

complex Kubernetes platform resources.
```

---

# 14.388 Server-side apply does NOT mean "always turn it on"

Understand:

```text
field ownership
```

before changing apply strategy.

Server-side apply introduces explicit Kubernetes field managers and conflict semantics.

That's powerful.

It's also different from:

```text
ordinary client-side apply.
```

We'll study it more when we manage platform components.

---

# 14.389 `Replace=true` — use cautiously

Argo supports:

```yaml
syncOptions:
  - Replace=true
```

which uses replace/create semantics rather than normal apply behavior.

Argo's own documentation warns this can be destructive and may recreate resources, potentially causing application outages. ([Argo CD][3])

Therefore:

```text
Replace=true
```

is **not**:

```text
"better apply."
```

It's a specialized tool.

---

# 14.390 `Force=true` — even more caution

For resources such as Jobs that intentionally need delete/recreate behavior, Argo can use:

```text
Force=true
+
Replace=true
```

But this explicitly uses destructive delete/create behavior and can cause outages if misused. ([Argo CD][3])

Do not put:

```yaml
Force=true
```

on production Deployments because it sounds decisive.

---

# 14.391 Sync retry

Deployments fail transiently.

Examples:

```text
temporary API issue

webhook unavailable

CRD not ready

temporary cloud integration issue
```

Argo CD supports retry configuration with exponential backoff. ([Argo CD][1])

Example:

```yaml
spec:
  syncPolicy:

    retry:
      limit: 5

      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Meaning:

```text
failure
  │
  ▼
wait
  │
  ▼
retry
  │
  ▼
longer wait
  │
  ▼
retry
```

until the configured retry limit/backoff cap is reached.

---

# 14.392 Exponential backoff

With:

```yaml
duration: 5s
factor: 2
```

the conceptual waits become:

```text
5s

10s

20s

40s

...
```

until:

```text
maxDuration
```

caps the interval.

Why?

Because repeatedly hammering:

```text
failing Kubernetes API

failing admission webhook

failing dependency
```

every millisecond makes incidents worse.

---

# 14.393 `retry.refresh: true`

Imagine:

```text
Revision A
      │
      ▼
deployment fails
      │
      ▼
Argo begins retrying
```

Then you fix Git:

```text
Revision B
```

With:

```yaml
retry:
  refresh: true
```

Argo can refresh to the newer revision during retry processing instead of continuing to focus only on the stale failing desired revision. ([Argo CD][1])

Example:

```yaml
retry:
  limit: 5
  refresh: true

  backoff:
    duration: 5s
    factor: 2
    maxDuration: 3m
```

---

# 14.394 Production-friendly policy example

A sophisticated Application might eventually look like:

```yaml
spec:

  syncPolicy:

    automated:
      enabled: true
      prune: true
      selfHeal: true
      allowEmpty: false

    retry:
      limit: 5
      refresh: true

      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
      - ApplyOutOfSyncOnly=true
      - FailOnSharedResource=true
```

But every option needs a reason.

Never create:

```text
cargo-cult Argo YAML.
```

---

# 14.395 Automated sync timing

Argo's normal reconciliation polling defaults to:

```text
120 seconds
+
up to 60 seconds jitter
```

so repository polling alone can take up to roughly three minutes to detect a change. Webhooks can reduce repository-change detection latency. ([argo-cd.readthedocs.io][1])

Therefore:

```text
git push
```

does not mathematically mean:

```text
pod changed 1 ms later.
```

Pipeline:

```text
Git push
   │
   ▼
Argo detects
   │
   ▼
render
   │
   ▼
diff
   │
   ▼
sync
   │
   ▼
Kubernetes rollout
```

Each stage contributes latency.

---

# 14.396 Important auto-sync retry semantic

Current Argo semantics include another subtle rule:

If automatic synchronization failed for a particular Git SHA and application parameters, Argo does not simply perform endless same-revision auto-sync retries by itself; explicit retry configuration is what gives you controlled retry/backoff behavior. ([Argo CD][1])

This prevents uncontrolled:

```text
fail
retry
fail
retry
fail
retry
∞
```

unless you explicitly configure the retry policy.

---

# 14.397 Auto-sync and rollback

Current Argo documentation has an important limitation:

> **Rollback cannot be performed against an Application while automated sync is enabled.** ([argo-cd.readthedocs.io][1])

Why does that make conceptual sense?

Imagine:

```text
Git says revision 42
```

You manually roll live state back to:

```text
revision 41
```

Auto-sync says:

```text
But Git still says 42.
```

The reconciler would immediately try to move forward again.

---

# 14.398 GitOps rollback pattern

Prefer:

```text
Bad Git commit
      │
      ▼
revert commit
      │
      ▼
Git desired state returns
to previous version
      │
      ▼
Argo reconciles
```

rather than:

```text
Live rollback
while Git still demands
the broken version.
```

For special Argo rollback operations, disable auto-sync first and understand stateful dependencies such as database migrations.

---

# 14.399 Sync Windows

Now imagine:

```text
auto-sync = true
```

but company policy says:

> Production deployments are prohibited during financial month-end processing.

We need a time-based governance layer.

Argo provides:

# **Sync Windows**

These are configured on an `AppProject` and can define `allow` or `deny` periods matching applications, namespaces, or destination clusters. They affect automated and manual sync behavior, with optional manual overrides. ([Argo CD][4])

---

# 14.400 Sync Window mental model

```text
Git merged
   │
   ▼
Application OutOfSync
   │
   ▼
Auto-sync wants to deploy
   │
   ▼
SYNC WINDOW
   │
   ├── allowed
   │      ↓
   │    deploy
   │
   └── denied
          ↓
        wait
```

This separates:

```text
desired-state approval
```

from:

```text
deployment-time approval.
```

---

# 14.401 Example AppProject window

Conceptual example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: production
  namespace: argocd

spec:

  syncWindows:

    - kind: deny
      schedule: '0 0 * * 6'
      duration: 48h
      timeZone: Asia/Kolkata

      applications:
        - '*-prod'

      manualSync: true
```

Interpretation:

```text
From Saturday 00:00
for 48 hours

automatic production syncs blocked

but authorized manual sync
can be permitted.
```

Argo sync windows support cron schedules, durations, timezone configuration, application/namespace/cluster selectors, and manual-sync override controls. ([Argo CD][4])

---

# 14.402 Allow vs deny windows

Rules:

```text
No matching windows
→ sync allowed
```

If matching `allow` windows exist:

```text
sync only while an allow window
is active.
```

If a matching `deny` window is active:

```text
sync denied.
```

If allow and deny overlap:

```text
DENY wins.
```

That's current Argo behavior. ([Argo CD][4])

---

# 14.403 Sync overrun

Current Argo CD also supports:

```text
syncOverrun
```

for windows.

Example:

```text
Allowed window ends at 22:00.

Deployment started at 21:59.

Deployment takes 10 minutes.
```

Without suitable overrun semantics:

```text
window transition
can prevent continuation.
```

With `syncOverrun` configured appropriately:

```text
already running synchronization
may finish.
```

Argo supports this for both allow and deny-window transition scenarios. ([Argo CD][4])

This matters for long-running migrations or large platform deployments.

---

# 14.404 How to inspect window state

Run:

```bash
argocd app get <APP>
```

Argo can show:

```text
SyncWindow
Assigned Windows
```

And:

```bash
argocd proj windows list <PROJECT>
```

lists configured windows and their current status. ([Argo CD][4])

We will use this when we build production `AppProject` objects.

---

# 14.405 Production change-control architecture

Now our deployment control plane can become:

```text
Developer
    │
    ▼
Config PR
    │
    ▼
Code owners / approval
    │
    ▼
Merge
    │
    ▼
Argo detects revision
    │
    ▼
Sync Window
    │
    ▼
Auto-Sync
    │
    ▼
Kubernetes
```

Notice:

```text
AUTO-SYNC
```

does not mean:

```text
NO GOVERNANCE.
```

Automation and governance can coexist.

---

# 14.406 Why auto-sync can actually strengthen governance

Traditional:

```text
Production deployment
=
engineer with kubectl credentials
```

GitOps:

```text
Production deployment
=
approved desired-state change
+
controlled reconciler
```

You can remove routine Kubernetes deployment credentials from:

```text
CI
developers
many operators
```

while keeping change history in Git.

That was one of the main reasons for introducing the pull model in Lesson 1.

---

# 14.407 But Git becomes extremely privileged

With:

```text
auto-sync
+
selfHeal
+
prune
```

Git effectively says:

```text
CREATE THIS

CHANGE THIS

DELETE THIS

RESTORE THIS
```

to the cluster.

Therefore protect:

```text
production branch

CODEOWNERS

merge permissions

MFA

repository tokens

CI write permissions

deployment-config automation
```

like production infrastructure.

---

# 14.408 The most dangerous GitOps combination

Technically:

```yaml
automated:
  enabled: true
  prune: true
  selfHeal: true
  allowEmpty: true
```

is powerful.

Now imagine buggy automation accidentally renders:

```text
zero resources.
```

If all other conditions allow it:

```text
Argo may treat empty
as valid desired state.
```

That's why `allowEmpty` exists as an explicit additional opt-in and is false by default. ([argo-cd.readthedocs.io][1])

---

# 14.409 Safer production deletion model

A stronger pattern might be:

```text
automated:
  enabled: true
  prune: true
  selfHeal: true
  allowEmpty: false
```

plus:

```text
PruneLast=true
```

and for selected critical resources:

```text
Prune=confirm
```

plus:

```text
Git PR review
```

plus optional:

```text
Sync Windows
```

This creates several independent deletion safeguards.

---

# 14.410 Development vs production examples

## Dev

A reasonable aggressive GitOps posture may be:

```text
Auto-sync      ✓
Self-heal      ✓
Prune          ✓
AllowEmpty     usually ✕
```

because:

```text
speed
+
drift correction
```

matter highly.

---

# 14.411 Production

Possible production model:

```text
Auto-sync        ✓
Self-heal        ✓
Prune            ✓
AllowEmpty       ✕
PruneLast        ✓
critical prune   confirm
PR approval      ✓
Sync Windows     where needed
```

But regulated/change-controlled organizations might intentionally use:

```text
approved Git merge
+
manual sync
```

for selected workloads.

GitOps does not require every organization to make every production deployment fully automatic.

---

# 14.412 Self-heal and emergency operations

Consider production database overload.

Engineer wants:

```text
payment-api replicas:
20 → 5
```

as an emergency mitigation.

With self-heal:

```text
kubectl scale 20 → 5
       │
       ▼
Argo
       │
       ▼
5 → 20
```

Correct operational choices:

```text
Emergency Git PR:

20 → 5

or

temporarily suspend automation
under break-glass procedure.
```

The incident runbook must explicitly mention GitOps reconciliation.

---

# 14.413 Self-heal is not application healing

Very important distinction.

Argo self-heal means:

```text
Kubernetes configuration drift
→ restore declared configuration
```

It does **not** mean:

```text
HTTP API failing
→ Argo diagnoses business logic
and repairs application.
```

Example:

```text
Git correct

Deployment correct

Pods running

API returning HTTP 500
```

Argo may say:

```text
Synced
Healthy
```

while business functionality is broken.

That's where observability/SRE takes over.

---

# 14.414 Prune is not garbage collection of everything

Argo only prunes resources it associates with the Application's management scope/tracking; it doesn't scan Kubernetes and randomly delete every object absent from your repository.

Current Argo resource tracking defaults to the `argocd.argoproj.io/tracking-id` annotation, with alternative annotation+label or label tracking modes available. ([Argo CD][5])

So:

```text
Argo App A
```

doesn't automatically own:

```text
every object
in destination namespace.
```

Ownership tracking matters.

---

# 14.415 Resource tracking

A current default tracking annotation resembles:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/tracking-id: >-
      guestbook:apps/Deployment:guestbook/guestbook-ui
```

The tracking ID encodes the Application and the resource identity; Argo currently uses annotation tracking by default. ([Argo CD][5])

Inspect yours:

```bash
kubectl get deployment guestbook-ui \
  -n guestbook \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}{"\n"}'
```

This is how the controller knows:

```text
"This object belongs
to Application guestbook."
```

---

# 14.416 Production ownership rule

Never forget:

```text
Git path
        │
        ▼
Application
        │
        ▼
tracked Kubernetes resources
```

Ownership should be deliberate.

Avoid:

```text
Application A
and
Application B

both believing they own
the same Kubernetes object.
```

That's one reason `FailOnSharedResource=true` exists. ([Argo CD][3])

---

# 14.417 Current final lab policy

Let's leave `guestbook` configured as:

```yaml
syncPolicy:

  automated:
    enabled: true
    prune: true
    selfHeal: true
    allowEmpty: false

  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
```

Patch it:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "syncPolicy": {
        "automated": {
          "enabled": true,
          "prune": true,
          "selfHeal": true,
          "allowEmpty": false
        },
        "syncOptions": [
          "CreateNamespace=true",
          "PruneLast=true"
        ]
      }
    }
  }'
```

---

# 14.418 Important: update your local YAML too

Remember:

```text
kubectl patch
```

changed the **live Application resource**.

But your local:

```text
guestbook-application.yaml
```

from Lesson 3 may still contain the old policy.

If you later run:

```bash
kubectl apply -f guestbook-application.yaml
```

you could overwrite the live configuration.

So update the file to:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: guestbook
  namespace: argocd

spec:

  project: default

  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook

  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook

  syncPolicy:

    automated:
      enabled: true
      prune: true
      selfHeal: true
      allowEmpty: false

    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
```

This keeps our local declaration consistent with live Argo configuration.

---

# 14.419 Notice the irony

We just learned GitOps—

yet our:

```text
Application CR
```

still lives in:

```text
a local file
```

and we manually use:

```bash
kubectl apply
```

That's temporary.

Soon we'll place Argo Application definitions themselves into Git.

Then:

```text
Git
  │
  ▼
Argo manages Applications
  │
  ▼
Applications manage workloads
```

That leads to:

```text
App-of-Apps

ApplicationSet

cluster bootstrapping.
```

---

# 14.420 Troubleshooting auto-sync

Application stays:

```text
OutOfSync
```

even though automation is configured.

Check:

```bash
argocd app get guestbook
```

Then:

```bash
kubectl get application guestbook \
  -n argocd \
  -o yaml
```

Verify:

```yaml
syncPolicy:
  automated:
    enabled: true
```

Then investigate:

```text
sync window?

previous sync failure?

manifest generation error?

Kubernetes permission?

resource conflict?

health/wave dependency?
```

Auto-sync cannot repair a fundamentally invalid deployment definition.

---

# 14.421 Troubleshooting self-heal

You manually change:

```text
1 → 3
```

but it remains `3`.

Check:

```text
1. Is application auto-sync enabled?

2. selfHeal true?

3. Is Argo actually tracking that field?

4. ignoreDifferences configured?

5. Is another controller the field owner?

6. Application controller healthy?

7. Is app refresh/reconciliation happening?
```

Then:

```bash
argocd app diff guestbook
```

If Argo doesn't consider the field a meaningful diff, self-heal won't behave as you expected.

---

# 14.422 Troubleshooting prune

Git resource removed.

Live resource remains.

Check:

```text
automated.prune true?

resource tracked by this Application?

Prune=false annotation?

Prune=confirm waiting?

sync window blocking?

application actually OutOfSync?

pruning scheduled PruneLast?
```

Then:

```bash
argocd app get guestbook
```

and:

```bash
argocd app resources guestbook
```

---

# 14.423 Troubleshooting auto-prune "dangerously wants to delete everything"

Stop and ask:

```text
Did repo fetch fail?

Did manifest generation return empty?

Wrong path?

Wrong branch?

Kustomize problem?

Helm values issue?

Automation changed source path?

Is allowEmpty enabled?
```

Do not immediately click:

```text
SYNC / PRUNE
```

on a production application when an unexpected mass deletion appears.

Unexpected deletion plans deserve investigation.

---

# 14.424 GitOps version of `terraform plan`

Terraform gives:

```text
Plan:

+ create
~ update
- destroy
```

Argo gives:

```text
Desired
vs
Live
```

through:

```bash
argocd app diff
```

These are not identical systems, but the operating habit should be similar:

> **Understand destructive changes before executing them.**

---

# 14.425 Auto-sync does not remove need for diff review

Even with auto-sync:

```text
runtime Argo diff
```

is useful for debugging.

Before merge, CI should also render/test desired configuration.

Eventually our GitOps PR pipeline will do:

```text
helm template

kustomize build

schema validation

policy checks

diff-like review
```

before Argo receives the change.

That's safer than relying only on Argo after merge.

---

# 14.426 Never-forget auto-sync matrix

| Desired state changed? | Live changed? | Auto | SelfHeal | Result                           |
| ---------------------- | ------------- | ---: | -------: | -------------------------------- |
| Yes                    | No            |    ✕ |      any | OutOfSync, wait                  |
| Yes                    | No            |    ✓ |        ✕ | Auto-sync                        |
| Yes                    | No            |    ✓ |        ✓ | Auto-sync                        |
| No                     | Yes           |    ✓ |        ✕ | Detect drift; no live-drift heal |
| No                     | Yes           |    ✓ |        ✓ | Self-heal                        |
| Resource removed       | —             |    ✓ |      any | Delete only if prune enabled     |

Current Argo semantics distinguish ordinary auto-sync, self-heal, and automatic pruning along these lines. ([argo-cd.readthedocs.io][1])

---

# 14.427 Never-forget deletion matrix

```text
prune=false
=
removed from Git
does not automatically delete live resource


prune=true
=
removed from Git
can be automatically deleted


Prune=false annotation
=
protect particular resource


Prune=confirm
=
require deletion approval


PruneLast=true
=
delete after other sync work succeeds


allowEmpty=false
=
protect application from
automated prune to zero


allowEmpty=true
=
zero desired resources
may be valid
```

([Argo CD][1])

---

# 14.428 Interview — What is automated sync?

Strong answer:

> **Automated sync allows Argo CD to automatically reconcile an Application when its desired manifests differ from live cluster state in a way that requires synchronization, removing the need for CI or an operator to explicitly invoke the Argo CD sync API for each desired-state revision.** ([Argo CD][1])

---

# 14.429 Interview — Auto-sync vs self-heal

```text
AUTO-SYNC
=
desired configuration changed


SELF-HEAL
=
live configuration changed
```

That's the cleanest answer.

---

# 14.430 Interview — What is prune?

> **Pruning removes application resources that Argo tracks but which are no longer present in the desired state. Automatic pruning must be explicitly enabled; it is disabled by default for safety.** ([argo-cd.readthedocs.io][1])

---

# 14.431 Interview — Why `allowEmpty`?

> It provides an additional protection against an automated prune accidentally reducing an Application to zero desired resources. `allowEmpty: true` explicitly declares that an empty desired application is valid. ([argo-cd.readthedocs.io][1])

---

# 14.432 Interview — `PruneLast`

```text
other resources
deploy
    ↓
become healthy
    ↓
other waves complete
    ↓
PRUNE OLD RESOURCES
```

That's exactly what `PruneLast=true` is for. ([Argo CD][3])

---

# 14.433 Interview — `ApplyOutOfSyncOnly`

> **It reduces sync work for large Applications by applying only resources currently considered OutOfSync rather than reapplying every Application object; hooks can still run and the sync remains recorded.** ([Argo CD][3])

---

# 14.434 Interview — What are Sync Windows?

> **Sync Windows are AppProject-level allow or deny schedules controlling when matching Applications may synchronize. They can match by Application, destination namespace, or cluster, affect automated and manual syncs, and can optionally permit manual override or running-sync overrun behavior.** ([Argo CD][4])

---

# 14.435 Interview trap — auto-sync implies self-heal

Wrong.

You can have:

```text
auto-sync = true

selfHeal = false
```

and live-only drift will not get the same automatic healing behavior. ([argo-cd.readthedocs.io][1])

---

# 14.436 Interview trap — auto-sync implies prune

Wrong.

Automatic pruning is separately enabled and defaults off. ([argo-cd.readthedocs.io][1])

---

# 14.437 Interview trap — prune means entire namespace is Argo-owned

Wrong.

Argo tracks resources belonging to an Application; current default tracking uses an Argo tracking annotation. ([Argo CD][5])

A random unrelated resource in the same namespace is not automatically equivalent to an Argo-managed resource.

---

# 14.438 Interview trap — `allowEmpty=true` is safer

No.

It removes a safety barrier.

It should only be enabled when:

```text
zero resources
```

is intentionally a valid desired state.

---

# 14.439 Interview trap — `Replace=true` is an optimization

Wrong.

It changes application semantics from normal apply toward replace/create and can cause recreation/outage. Argo explicitly warns that it may be destructive. ([Argo CD][3])

---

# 14.440 Interview trap — Force sync is harmless

Wrong.

`Force=true` can drive delete/create behavior and is intentionally destructive. ([Argo CD][3])

---

# 14.441 Interview trap — auto-sync removes approvals

Wrong.

You can have:

```text
PR approval

CODEOWNERS

policy checks

Sync Windows

auto-sync
```

at the same time.

Automation governs **execution**.

Approval governs **authorization of desired state**.

---

# 14.442 Production safety hierarchy

Think:

```text
Git access
    │
    ▼
Pull Request
    │
    ▼
CODEOWNERS
    │
    ▼
CI validation
    │
    ▼
Merge
    │
    ▼
Sync Window
    │
    ▼
Argo Auto-Sync
    │
    ▼
Prune controls
    │
    ▼
Kubernetes RBAC
    │
    ▼
Admission Policy
    │
    ▼
Runtime
```

GitOps production safety comes from layers—not one checkbox.

---

# 14.443 Complete Lesson 4 controller model

```text
                      GIT
                  Desired State
                       │
                       ▼
                Application Controller
                       │
                  compare live
                       │
            ┌──────────┴──────────┐
            │                     │
            ▼                     ▼
         Synced               OutOfSync
                                  │
                      ┌───────────┼───────────┐
                      │           │           │
                      ▼           ▼           ▼
                 Git changed  Live drift  Resource gone
                      │           │           │
                      ▼           ▼           ▼
                  Auto-Sync    Self-Heal      Prune
                      │           │           │
                      └───────────┼───────────┘
                                  ▼
                          Kubernetes API
                                  │
                                  ▼
                              Converged
```

That diagram is the heart of Lesson 4.

---

# 14.444 Never-forget Lesson 4 rules

```text
1.
Auto-sync, self-heal and prune
are separate controls.


2.
Auto-sync removes the need for
manual sync on desired-state changes.


3.
Self-heal corrects live-only drift.


4.
Prune deletes resources removed
from desired state.


5.
Prune is off by default.


6.
Self-heal is off by default.


7.
allowEmpty is an extra
mass-deletion safety boundary.


8.
Keep allowEmpty false unless
empty is intentionally valid.


9.
Prune=confirm protects
critical deletions.


10.
Prune=false protects
specific resources.


11.
PruneLast performs deletions
after other resources are healthy.


12.
ApplyOutOfSyncOnly is primarily
a scalability optimization.


13.
FailOnSharedResource helps enforce
one Application owner.


14.
RespectIgnoreDifferences matters
when other controllers own fields.


15.
ServerSideApply changes
field-management semantics.


16.
Replace and Force can be destructive.


17.
Retry/backoff handles
transient sync failures.


18.
Sync Windows provide
time-based deployment governance.


19.
Deny windows override
overlapping allow windows.


20.
Git review remains critical
even with full automation.


21.
Don't fight self-heal with kubectl.


22.
Emergency procedures must
account for the reconciler.


23.
Auto-sync-enabled apps cannot use
normal Argo rollback directly;
desired-state rollback is usually Git-based.


24.
One Kubernetes resource should have
one authoritative GitOps owner.


25.
Automation makes Git
part of the production control plane.
```

---

# ✅ Module 14 — Lesson 4 Complete

You now understand and have a practical model for:

```text
✓ Automated sync

✓ explicit automated.enabled

✓ desired-state-triggered reconciliation

✓ live-state drift

✓ selfHeal

✓ automatic pruning

✓ allowEmpty

✓ Prune=false

✓ Prune=confirm

✓ PruneLast

✓ prune propagation

✓ ApplyOutOfSyncOnly

✓ FailOnSharedResource

✓ RespectIgnoreDifferences

✓ ServerSideApply

✓ Replace

✓ Force

✓ retries

✓ exponential backoff

✓ retry refresh

✓ reconciliation timing

✓ auto-sync rollback limitation

✓ Sync Windows

✓ manual sync overrides

✓ sync overrun

✓ production deletion safety

✓ GitOps emergency operations

✓ Argo resource tracking
```

# Next — Module 14, Lesson 5

## Production Git Repository Design & Environment Promotion

Now we stop depending on the public Argo example repository and design **our own real GitOps repository**.

We'll build:

```text
APPLICATION SOURCE REPO
        │
        ▼
Jenkins CI
        │
        ├── test
        ├── scan
        ├── Docker build
        └── ECR push
                │
                ▼
          immutable image
                │
                ▼
          GITOPS REPO
                │
        ┌───────┼────────┐
        ▼       ▼        ▼
       dev    staging    prod
        │       │        │
        ▼       ▼        ▼
      Argo    Argo      Argo
```

Then we'll compare **monorepo vs polyrepo, branch-per-environment vs directory-per-environment, app source vs config repo, base/overlay structure, image promotion, build-once/promote-many, production PR approvals, repository permissions, CODEOWNERS, rollback, and a production layout for your Todo application**.

This is where the course transitions from an Argo demonstration into a genuine production GitOps workflow.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.4.445 Professional Mastery Workbook

This workbook expands **Automated Sync, Self-Heal, Prune & Production Sync Safety** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 99 lesson-specific anchors.
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

### Concept card 1 - Our starting state

- Lesson anchor: Make sure Lesson 3's application still exists: argocd app get guestbook Then: kubectl get deployment guestbook-ui -n guestbook You want approximately: READY 1/1 Check the desired replica count: kubectl get deployment guestbook-ui \
- Beginner explanation: Restate **Our starting state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Our starting state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Our starting state**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Our starting state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Our starting state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - The automated-sync configuration

- Lesson anchor: A modern explicit configuration is: spec: syncPolicy: automated: enabled: true Argo CD also accepts: automated: {} as enabled. Current versions expose automated.enabled explicitly; enabled: false disables automated synchronization even if prune, selfHeal, o...
- Beginner explanation: Restate **The automated-sync configuration** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The automated-sync configuration** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **The automated-sync configuration**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **The automated-sync configuration**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The automated-sync configuration** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Enable auto-sync — but NOT self-heal or prune yet

- Lesson anchor: Patch our current Application: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "syncPolicy": { "automated": { "enabled": true, "prune": false, "selfHeal": false, "allowEmpty": false }, "syncOptions": [
- Beginner explanation: Restate **Enable auto-sync — but NOT self-heal or prune yet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Enable auto-sync — but NOT self-heal or prune yet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Enable auto-sync — but NOT self-heal or prune yet**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Enable auto-sync — but NOT self-heal or prune yet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Enable auto-sync — but NOT self-heal or prune yet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - What does auto-sync actually remove?

- Lesson anchor: Old flow: Git change │ ▼ OutOfSync │ ▼ Operator │ ▼ argocd app sync New flow: Desired state changes │ ▼ Argo detects OutOfSync │ ▼ AUTO-SYNC │ ▼ Kubernetes reconciliation This is why CI doesn't need to invoke: argocd app sync
- Beginner explanation: Restate **What does auto-sync actually remove?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What does auto-sync actually remove?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **What does auto-sync actually remove?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **What does auto-sync actually remove?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What does auto-sync actually remove?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - How auto-sync behaves internally

- Lesson anchor: Conceptually: Application Controller │ ▼ Desired Revision A │ ▼ Live State A │ ▼ Synced Later: Desired Revision B │ ▼ Live State A │ ▼ OutOfSync │ ▼ Auto-Sync │ ▼ Live State B Argo CD only auto-syncs an application when it is OutOfSync. It also tracks synch...
- Beginner explanation: Restate **How auto-sync behaves internally** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **How auto-sync behaves internally** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **How auto-sync behaves internally**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **How auto-sync behaves internally**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **How auto-sync behaves internally** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Practical auto-sync experiment without owning Git yet

- Lesson anchor: We don't own the official example repository, so we cannot make a genuine Git commit there. Instead, we can safely prove the automatic reconciliation mechanism by temporarily changing which directory our Application tracks.
- Beginner explanation: Restate **Practical auto-sync experiment without owning Git yet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Practical auto-sync experiment without owning Git yet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Practical auto-sync experiment without owning Git yet**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Practical auto-sync experiment without owning Git yet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Practical auto-sync experiment without owning Git yet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Trigger automated synchronization

- Lesson anchor: Run: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "source": { "path": "kustomize-guestbook" } } }' Do not run: argocd app sync guestbook That's the whole experiment. Watch: argocd app get guestbook --refresh
- Beginner explanation: Restate **Trigger automated synchronization** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Trigger automated synchronization** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Trigger automated synchronization**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Trigger automated synchronization**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Trigger automated synchronization** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - What proved auto-sync?

- Lesson anchor: You only changed: Application desired source You did not manually sync. Yet: desired configuration changed │ ▼ Argo detected OutOfSync │ ▼ auto-sync │ ▼ new resources created That's automated reconciliation. In Lesson 5 we'll own the configuration repositor...
- Beginner explanation: Restate **What proved auto-sync?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What proved auto-sync?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **What proved auto-sync?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **What proved auto-sync?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What proved auto-sync?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - But look carefully — something interesting happened

- Lesson anchor: Run: kubectl get deployment,service -n guestbook You may now have: guestbook-ui and kustomize-guestbook-ui Why? Because: Auto-sync = true but: Prune = false Argo created the newly desired resources. But it was not authorized to automatically delete resource...
- Beginner explanation: Restate **But look carefully — something interesting happened** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **But look carefully — something interesting happened** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **But look carefully — something interesting happened**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **But look carefully — something interesting happened**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **But look carefully — something interesting happened** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Restore the original Git path

- Lesson anchor: Run: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "source": { "path": "guestbook" } } }' Again: do NOT manually sync. Auto-sync will reconcile toward the original guestbook desired resources.
- Beginner explanation: Restate **Restore the original Git path** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Restore the original Git path** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Restore the original Git path**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Restore the original Git path**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Restore the original Git path** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Prune mental model

- Lesson anchor: Suppose Git yesterday contained: Deployment Service ConfigMap Today Git contains: Deployment Service Then: ConfigMap exists live but no longer exists in desired state. That's an: EXTRANEOUS RESOURCE Pruning means: Desired says
- Beginner explanation: Restate **Prune mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Prune mental model**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Prune mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Enable automatic pruning

- Lesson anchor: Patch: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "syncPolicy": { "automated": { "enabled": true, "prune": true, "selfHeal": false, "allowEmpty": false }, "syncOptions": [ "CreateNamespace=true"
- Beginner explanation: Restate **Enable automatic pruning** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Enable automatic pruning** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Enable automatic pruning**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Enable automatic pruning**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Enable automatic pruning** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Watch pruning happen

- Lesson anchor: Run: argocd app get guestbook --refresh Then: kubectl get deployment,service -n guestbook The temporary Kustomize resources that were previously managed by this Application but are no longer desired should disappear as Argo reconciles the application with p...
- Beginner explanation: Restate **Watch pruning happen** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Watch pruning happen** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Watch pruning happen**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Watch pruning happen**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Watch pruning happen** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - This is powerful — and dangerous

- Lesson anchor: Imagine a bad production commit accidentally deletes: payments/ from the GitOps repository. Without prune: Argo: OutOfSync resources remain. With prune: Argo: Git says they should not exist. Delete. Therefore: That's why branch protection and code review ar...
- Beginner explanation: Restate **This is powerful — and dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **This is powerful — and dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **This is powerful — and dangerous**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **This is powerful — and dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **This is powerful — and dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Prune does not mean delete everything blindly

- Lesson anchor: Argo provides resource-level protection. For a resource: metadata: annotations: argocd.argoproj.io/sync-options: Prune=false Argo skips pruning that object. Resource-level Prune=false overrides application-level pruning behavior for that resource. ([Argo CD...
- Beginner explanation: Restate **Prune does not mean delete everything blindly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune does not mean delete everything blindly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Prune does not mean delete everything blindly**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Prune does not mean delete everything blindly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune does not mean delete everything blindly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - `Prune=confirm`

- Lesson anchor: For critical objects, Argo supports: metadata: annotations: argocd.argoproj.io/sync-options: Prune=confirm Then Argo requires explicit approval before pruning that resource. ([Argo CD][3]) This can be useful for resources such as:
- Beginner explanation: Restate **`Prune=confirm`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`Prune=confirm`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **`Prune=confirm`**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **`Prune=confirm`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`Prune=confirm`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Production deletion-defense layers

- Lesson anchor: A strong production pattern can look like: Git PR approval │ ▼ auto-prune │ ▼ critical object? │ ├── No │    ▼ │   prune │ └── Yes ▼ Prune=confirm │ ▼ manual approval This gives automation without treating all resources as equally disposable.
- Beginner explanation: Restate **Production deletion-defense layers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production deletion-defense layers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Production deletion-defense layers**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Production deletion-defense layers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production deletion-defense layers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - `allowEmpty`

- Lesson anchor: Now imagine the Git path renders: 0 resources. With: auto-sync = true prune     = true a naïve system could conclude: Git wants nothing. Delete everything. That is scary. Argo CD therefore protects auto-pruned Applications from becoming completely empty by...
- Beginner explanation: Restate **`allowEmpty`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`allowEmpty`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`allowEmpty`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`allowEmpty`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`allowEmpty`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Never-forget `allowEmpty`

- Lesson anchor: allowEmpty = false "No desired resources? Do NOT automatically wipe the application to zero." versus: allowEmpty = true "Zero resources is a valid desired state." For normal production applications, I'd generally keep: allowEmpty: false
- Beginner explanation: Restate **Never-forget `allowEmpty`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget `allowEmpty`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Never-forget `allowEmpty`**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Never-forget `allowEmpty`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget `allowEmpty`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Current policy so far

- Lesson anchor: We have: syncPolicy: automated: enabled: true prune: true selfHeal: false allowEmpty: false syncOptions: Now we'll demonstrate the feature most people associate with GitOps: ---
- Beginner explanation: Restate **Current policy so far** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Current policy so far** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Current policy so far**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Current policy so far**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Current policy so far** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - First prove that auto-sync is NOT self-heal

- Lesson anchor: Make sure the app is fully converged: argocd app get guestbook --refresh You want: Synced Healthy Then: kubectl scale deployment \ guestbook-ui \ --replicas=3 \ -n guestbook Check: kubectl get deployment guestbook-ui -n guestbook
- Beginner explanation: Restate **First prove that auto-sync is NOT self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First prove that auto-sync is NOT self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **First prove that auto-sync is NOT self-heal**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **First prove that auto-sync is NOT self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First prove that auto-sync is NOT self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Why doesn't plain auto-sync necessarily fix this?

- Lesson anchor: Because no new desired Git revision/application parameter combination needs deploying. The live cluster drifted after the desired revision was already successfully synchronized. Current Argo CD semantics only automatically resynchronize the same successful...
- Beginner explanation: Restate **Why doesn't plain auto-sync necessarily fix this?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why doesn't plain auto-sync necessarily fix this?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Why doesn't plain auto-sync necessarily fix this?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Why doesn't plain auto-sync necessarily fix this?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why doesn't plain auto-sync necessarily fix this?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Enable self-healing

- Lesson anchor: Run: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "syncPolicy": { "automated": { "enabled": true, "prune": true, "selfHeal": true, "allowEmpty": false }, "syncOptions": [ "CreateNamespace=true"
- Beginner explanation: Restate **Enable self-healing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Enable self-healing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Enable self-healing**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Enable self-healing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Enable self-healing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Watch self-heal

- Lesson anchor: Use: watch -n 1 \ kubectl get deployment guestbook-ui -n guestbook You should observe: 3 ↓ 1 after Argo detects and reconciles the drift. Current Argo CD uses a default self-heal retry timeout of 5 seconds after the drift is detected, though overall visible...
- Beginner explanation: Restate **Watch self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Watch self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Watch self-heal**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Watch self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Watch self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Repeat the experiment

- Lesson anchor: Run: kubectl scale deployment \ guestbook-ui \ --replicas=10 \ -n guestbook Then: watch -n 1 \ kubectl get deployment guestbook-ui -n guestbook You should see something conceptually like: DESIRED   CURRENT 10        ... and then Argo restores the Kubernetes...
- Beginner explanation: Restate **Repeat the experiment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Repeat the experiment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Repeat the experiment**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Repeat the experiment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Repeat the experiment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Why engineers sometimes think Argo is "fighting them"

- Lesson anchor: Incident engineer: kubectl scale payment-api --replicas=0 Argo: Git says replicas = 10. Self-heal: 0 → 10 Engineer: Why does Kubernetes keep bringing it back?! Not Kubernetes alone. You are fighting: Argo CD desired-state controller.
- Beginner explanation: Restate **Why engineers sometimes think Argo is "fighting them"** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why engineers sometimes think Argo is "fighting them"** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Why engineers sometimes think Argo is "fighting them"**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Why engineers sometimes think Argo is "fighting them"**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why engineers sometimes think Argo is "fighting them"** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - The correct emergency thought process

- Lesson anchor: When self-heal is active: Live emergency change │ ▼ Argo sees drift │ ▼ Argo reverses change So emergency procedures must consider the reconciler. Options include: Do not repeatedly fight the controller with kubectl. ---
- Beginner explanation: Restate **The correct emergency thought process** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The correct emergency thought process** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **The correct emergency thought process**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **The correct emergency thought process**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The correct emergency thought process** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Temporarily pause a standalone Application

- Lesson anchor: For this standalone Application: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "syncPolicy": { "automated": { "enabled": false, "prune": true, "selfHeal": true, "allowEmpty": false } } }
- Beginner explanation: Restate **Temporarily pause a standalone Application** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Temporarily pause a standalone Application** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Temporarily pause a standalone Application**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Temporarily pause a standalone Application**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Temporarily pause a standalone Application** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - ApplicationSet warning

- Lesson anchor: Later, when an Application is generated by: ApplicationSet manually changing the generated child's: spec.syncPolicy.automated is not the proper way to disable auto-sync—the ApplicationSet controller owns that Application spec and can restore it. Argo's curr...
- Beginner explanation: Restate **ApplicationSet warning** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **ApplicationSet warning** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **ApplicationSet warning**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **ApplicationSet warning**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **ApplicationSet warning** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Re-enable our lab

- Lesson anchor: Run: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "syncPolicy": { "automated": { "enabled": true, "prune": true, "selfHeal": true, "allowEmpty": false }, "syncOptions": [ "CreateNamespace=true"
- Beginner explanation: Restate **Re-enable our lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Re-enable our lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Re-enable our lab**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Re-enable our lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Re-enable our lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Full production-style automated policy

- Lesson anchor: A useful baseline looks like: spec: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false syncOptions: But don't interpret this as: “Every production application should blindly use these exact settings.”
- Beginner explanation: Restate **Full production-style automated policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Full production-style automated policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Full production-style automated policy**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Full production-style automated policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Full production-style automated policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - `PruneLast=true`

- Lesson anchor: Now imagine one deployment changes architecture. Old: Service A Deployment A New: Service B Deployment B You may want new resources to deploy and become healthy before obsolete resources are pruned. Argo supports: syncOptions:
- Beginner explanation: Restate **`PruneLast=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`PruneLast=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`PruneLast=true`**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`PruneLast=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`PruneLast=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Add `PruneLast`

- Lesson anchor: Our lab could become: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false syncOptions: That is often a safer deletion ordering model than pruning old resources as early as possible. ---
- Beginner explanation: Restate **Add `PruneLast`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Add `PruneLast`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Add `PruneLast`**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Add `PruneLast`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Add `PruneLast`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Prune propagation policy

- Lesson anchor: Kubernetes deletion has garbage-collection semantics. Argo lets you choose: foreground background orphan through: syncOptions: foreground is the current default for Argo pruning. ([Argo CD][3]) ---
- Beginner explanation: Restate **Prune propagation policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune propagation policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Prune propagation policy**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Prune propagation policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune propagation policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Simplified deletion propagation

- Lesson anchor: Parent deletion requested wait for dependent resources ↓ delete dependents ↓ parent disappears Parent disappears ↓ Kubernetes cleans dependents in background Delete parent leave dependents behind. Do not change this merely because another mode sounds faster.
- Beginner explanation: Restate **Simplified deletion propagation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Simplified deletion propagation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Simplified deletion propagation**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Simplified deletion propagation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Simplified deletion propagation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - `ApplyOutOfSyncOnly=true`

- Lesson anchor: By default, during a synchronization Argo applies all application objects. At very large scale: Application = 5,000 resources but maybe only: 3 resources actually differ. Argo supports: syncOptions: so it applies only resources that are currently OutOfSync,...
- Beginner explanation: Restate **`ApplyOutOfSyncOnly=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`ApplyOutOfSyncOnly=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`ApplyOutOfSyncOnly=true`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`ApplyOutOfSyncOnly=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`ApplyOutOfSyncOnly=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - When should you care about `ApplyOutOfSyncOnly`?

- Lesson anchor: Probably not for our: 2-resource guestbook. But imagine a platform Application containing: CRDs Namespaces RBAC NetworkPolicies Deployments Services ConfigMaps PrometheusRules ... across thousands of resources. Then: apply everything
- Beginner explanation: Restate **When should you care about `ApplyOutOfSyncOnly`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **When should you care about `ApplyOutOfSyncOnly`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **When should you care about `ApplyOutOfSyncOnly`?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **When should you care about `ApplyOutOfSyncOnly`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **When should you care about `ApplyOutOfSyncOnly`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - `FailOnSharedResource=true`

- Lesson anchor: Another production-grade option: syncOptions: By default, Argo may encounter resources already managed by another Application. With this option, synchronization fails when a resource is already associated with another Application. ([Argo CD][3])
- Beginner explanation: Restate **`FailOnSharedResource=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`FailOnSharedResource=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`FailOnSharedResource=true`**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`FailOnSharedResource=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`FailOnSharedResource=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Why shared resource ownership is dangerous

- Lesson anchor: Imagine: Application A │ ▼ ConfigMap/common-config Application B │ ▼ same ConfigMap/common-config A sync from A writes: VALUE=A A sync from B writes: VALUE=B Next A: VALUE=A You created controller warfare. A production GitOps design should minimize ambiguou...
- Beginner explanation: Restate **Why shared resource ownership is dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why shared resource ownership is dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Why shared resource ownership is dangerous**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Why shared resource ownership is dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why shared resource ownership is dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - `RespectIgnoreDifferences=true`

- Lesson anchor: Remember our HPA example. Suppose: Git Deployment replicas = 3 but: HPA owns replicas dynamically. You may configure: ignoreDifferences: kind: Deployment jsonPointers: By default, ignoreDifferences affects diff calculation, but the full desired manifest can...
- Beginner explanation: Restate **`RespectIgnoreDifferences=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`RespectIgnoreDifferences=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **`RespectIgnoreDifferences=true`**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **`RespectIgnoreDifferences=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`RespectIgnoreDifferences=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Field ownership rule

- Lesson anchor: This is one of the strongest rules in the entire module: Argo owns image tag. HPA owns replica count. cert-manager owns generated certificate state. Operator owns operator-generated fields. Do not make every controller fight for every field.
- Beginner explanation: Restate **Field ownership rule** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Field ownership rule** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Field ownership rule**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Field ownership rule**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Field ownership rule** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - `ServerSideApply=true`

- Lesson anchor: Argo also supports: syncOptions: Current behavior uses Kubernetes server-side apply with conflict handling instead of the default client-side apply model. Argo highlights use cases including very large resources and resources that are only partially managed...
- Beginner explanation: Restate **`ServerSideApply=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`ServerSideApply=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`ServerSideApply=true`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`ServerSideApply=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`ServerSideApply=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Server-side apply does NOT mean "always turn it on"

- Lesson anchor: Understand: field ownership before changing apply strategy. Server-side apply introduces explicit Kubernetes field managers and conflict semantics. That's powerful. It's also different from: ordinary client-side apply. We'll study it more when we manage pla...
- Beginner explanation: Restate **Server-side apply does NOT mean "always turn it on"** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Server-side apply does NOT mean "always turn it on"** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Server-side apply does NOT mean "always turn it on"**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Server-side apply does NOT mean "always turn it on"**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Server-side apply does NOT mean "always turn it on"** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - `Replace=true` — use cautiously

- Lesson anchor: Argo supports: syncOptions: which uses replace/create semantics rather than normal apply behavior. Argo's own documentation warns this can be destructive and may recreate resources, potentially causing application outages. ([Argo CD][3])
- Beginner explanation: Restate **`Replace=true` — use cautiously** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`Replace=true` — use cautiously** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`Replace=true` — use cautiously**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`Replace=true` — use cautiously**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`Replace=true` — use cautiously** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - `Force=true` — even more caution

- Lesson anchor: For resources such as Jobs that intentionally need delete/recreate behavior, Argo can use: Force=true + Replace=true But this explicitly uses destructive delete/create behavior and can cause outages if misused. ([Argo CD][3])
- Beginner explanation: Restate **`Force=true` — even more caution** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`Force=true` — even more caution** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **`Force=true` — even more caution**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **`Force=true` — even more caution**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`Force=true` — even more caution** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Sync retry

- Lesson anchor: Deployments fail transiently. Examples: temporary API issue webhook unavailable CRD not ready temporary cloud integration issue Argo CD supports retry configuration with exponential backoff. ([Argo CD][1]) Example: spec:
- Beginner explanation: Restate **Sync retry** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync retry** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Sync retry**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Sync retry**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync retry** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Exponential backoff

- Lesson anchor: With: duration: 5s factor: 2 the conceptual waits become: 5s 10s 20s 40s ... until: maxDuration caps the interval. Why? Because repeatedly hammering: failing Kubernetes API failing admission webhook failing dependency every millisecond makes incidents worse.
- Beginner explanation: Restate **Exponential backoff** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Exponential backoff** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Exponential backoff**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Exponential backoff**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Exponential backoff** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - `retry.refresh: true`

- Lesson anchor: Imagine: Revision A │ ▼ deployment fails │ ▼ Argo begins retrying Then you fix Git: Revision B With: retry: refresh: true Argo can refresh to the newer revision during retry processing instead of continuing to focus only on the stale failing desired revisio...
- Beginner explanation: Restate **`retry.refresh: true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`retry.refresh: true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`retry.refresh: true`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`retry.refresh: true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`retry.refresh: true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Production-friendly policy example

- Lesson anchor: A sophisticated Application might eventually look like: spec: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false retry: limit: 5 refresh: true backoff: duration: 5s factor: 2 maxDuration: 3m
- Beginner explanation: Restate **Production-friendly policy example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production-friendly policy example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Production-friendly policy example**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Production-friendly policy example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production-friendly policy example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Automated sync timing

- Lesson anchor: Argo's normal reconciliation polling defaults to: 120 seconds + up to 60 seconds jitter so repository polling alone can take up to roughly three minutes to detect a change. Webhooks can reduce repository-change detection latency. ([argo-cd.readthedocs.io][1])
- Beginner explanation: Restate **Automated sync timing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Automated sync timing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Automated sync timing**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Automated sync timing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Automated sync timing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Important auto-sync retry semantic

- Lesson anchor: Current Argo semantics include another subtle rule: If automatic synchronization failed for a particular Git SHA and application parameters, Argo does not simply perform endless same-revision auto-sync retries by itself; explicit retry configuration is what...
- Beginner explanation: Restate **Important auto-sync retry semantic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important auto-sync retry semantic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Important auto-sync retry semantic**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Important auto-sync retry semantic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important auto-sync retry semantic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Auto-sync and rollback

- Lesson anchor: Current Argo documentation has an important limitation: Rollback cannot be performed against an Application while automated sync is enabled. ([argo-cd.readthedocs.io][1]) Why does that make conceptual sense? Imagine: Git says revision 42
- Beginner explanation: Restate **Auto-sync and rollback** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Auto-sync and rollback** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Auto-sync and rollback**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Auto-sync and rollback**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Auto-sync and rollback** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - GitOps rollback pattern

- Lesson anchor: Prefer: Bad Git commit │ ▼ revert commit │ ▼ Git desired state returns to previous version │ ▼ Argo reconciles rather than: Live rollback while Git still demands the broken version. For special Argo rollback operations, disable auto-sync first and understan...
- Beginner explanation: Restate **GitOps rollback pattern** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitOps rollback pattern** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **GitOps rollback pattern**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **GitOps rollback pattern**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitOps rollback pattern** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Sync Windows

- Lesson anchor: Now imagine: auto-sync = true but company policy says: Production deployments are prohibited during financial month-end processing. We need a time-based governance layer. Argo provides: These are configured on an AppProject and can define allow or deny peri...
- Beginner explanation: Restate **Sync Windows** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync Windows** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Sync Windows**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Sync Windows**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync Windows** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Sync Window mental model

- Lesson anchor: Git merged │ ▼ Application OutOfSync │ ▼ Auto-sync wants to deploy │ ▼ SYNC WINDOW │ ├── allowed │      ↓ │    deploy │ └── denied ↓ wait This separates: desired-state approval from: deployment-time approval. ---
- Beginner explanation: Restate **Sync Window mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync Window mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Sync Window mental model**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Sync Window mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync Window mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Example AppProject window

- Lesson anchor: Conceptual example: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: production namespace: argocd spec: syncWindows: schedule: '0 0   6' duration: 48h timeZone: Asia/Kolkata applications: manualSync: true
- Beginner explanation: Restate **Example AppProject window** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example AppProject window** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Example AppProject window**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Example AppProject window**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example AppProject window** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Allow vs deny windows

- Lesson anchor: Rules: No matching windows → sync allowed If matching allow windows exist: sync only while an allow window is active. If a matching deny window is active: sync denied. If allow and deny overlap: DENY wins. That's current Argo behavior. ([Argo CD][4])
- Beginner explanation: Restate **Allow vs deny windows** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Allow vs deny windows** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Allow vs deny windows**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Allow vs deny windows**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Allow vs deny windows** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Sync overrun

- Lesson anchor: Current Argo CD also supports: syncOverrun for windows. Example: Allowed window ends at 22:00. Deployment started at 21:59. Deployment takes 10 minutes. Without suitable overrun semantics: window transition can prevent continuation.
- Beginner explanation: Restate **Sync overrun** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync overrun** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Sync overrun**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Sync overrun**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync overrun** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - How to inspect window state

- Lesson anchor: Run: argocd app get <APP Argo can show: SyncWindow Assigned Windows And: argocd proj windows list <PROJECT lists configured windows and their current status. ([Argo CD][4]) We will use this when we build production AppProject objects.
- Beginner explanation: Restate **How to inspect window state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **How to inspect window state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **How to inspect window state**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **How to inspect window state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **How to inspect window state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Production change-control architecture

- Lesson anchor: Now our deployment control plane can become: Developer │ ▼ Config PR │ ▼ Code owners / approval │ ▼ Merge │ ▼ Argo detects revision │ ▼ Sync Window │ ▼ Auto-Sync │ ▼ Kubernetes Notice: AUTO-SYNC does not mean: NO GOVERNANCE.
- Beginner explanation: Restate **Production change-control architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production change-control architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production change-control architecture**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production change-control architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production change-control architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - Why auto-sync can actually strengthen governance

- Lesson anchor: Traditional: Production deployment = engineer with kubectl credentials GitOps: Production deployment = approved desired-state change + controlled reconciler You can remove routine Kubernetes deployment credentials from: CI
- Beginner explanation: Restate **Why auto-sync can actually strengthen governance** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why auto-sync can actually strengthen governance** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Why auto-sync can actually strengthen governance**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Why auto-sync can actually strengthen governance**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why auto-sync can actually strengthen governance** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 62 - But Git becomes extremely privileged

- Lesson anchor: With: auto-sync + selfHeal + prune Git effectively says: CREATE THIS CHANGE THIS DELETE THIS RESTORE THIS to the cluster. Therefore protect: production branch CODEOWNERS merge permissions MFA repository tokens CI write permissions
- Beginner explanation: Restate **But Git becomes extremely privileged** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **But Git becomes extremely privileged** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **But Git becomes extremely privileged**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **But Git becomes extremely privileged**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **But Git becomes extremely privileged** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 63 - The most dangerous GitOps combination

- Lesson anchor: Technically: automated: enabled: true prune: true selfHeal: true allowEmpty: true is powerful. Now imagine buggy automation accidentally renders: zero resources. If all other conditions allow it: Argo may treat empty as valid desired state.
- Beginner explanation: Restate **The most dangerous GitOps combination** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The most dangerous GitOps combination** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **The most dangerous GitOps combination**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **The most dangerous GitOps combination**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The most dangerous GitOps combination** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 64 - Safer production deletion model

- Lesson anchor: A stronger pattern might be: automated: enabled: true prune: true selfHeal: true allowEmpty: false plus: PruneLast=true and for selected critical resources: Prune=confirm plus: Git PR review plus optional: Sync Windows This creates several independent delet...
- Beginner explanation: Restate **Safer production deletion model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Safer production deletion model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Safer production deletion model**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Safer production deletion model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Safer production deletion model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 65 - Development vs production examples

- Lesson anchor: A reasonable aggressive GitOps posture may be: Auto-sync      ✓ Self-heal      ✓ Prune          ✓ AllowEmpty     usually ✕ because: speed + drift correction matter highly. ---
- Beginner explanation: Restate **Development vs production examples** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Development vs production examples** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Development vs production examples**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Development vs production examples**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Development vs production examples** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 66 - Production

- Lesson anchor: Possible production model: Auto-sync        ✓ Self-heal        ✓ Prune            ✓ AllowEmpty       ✕ PruneLast        ✓ critical prune   confirm PR approval      ✓ Sync Windows     where needed But regulated/change-controlled organizations might intention...
- Beginner explanation: Restate **Production** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 67 - Self-heal and emergency operations

- Lesson anchor: Consider production database overload. Engineer wants: payment-api replicas: 20 → 5 as an emergency mitigation. With self-heal: kubectl scale 20 → 5 │ ▼ Argo │ ▼ 5 → 20 Correct operational choices: Emergency Git PR: 20 → 5
- Beginner explanation: Restate **Self-heal and emergency operations** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Self-heal and emergency operations** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Self-heal and emergency operations**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Self-heal and emergency operations**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Self-heal and emergency operations** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 68 - Self-heal is not application healing

- Lesson anchor: Very important distinction. Argo self-heal means: Kubernetes configuration drift → restore declared configuration It does not mean: HTTP API failing → Argo diagnoses business logic and repairs application. Example: Git correct
- Beginner explanation: Restate **Self-heal is not application healing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Self-heal is not application healing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Self-heal is not application healing**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Self-heal is not application healing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Self-heal is not application healing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 69 - Prune is not garbage collection of everything

- Lesson anchor: Argo only prunes resources it associates with the Application's management scope/tracking; it doesn't scan Kubernetes and randomly delete every object absent from your repository. Current Argo resource tracking defaults to the argocd.argoproj.io/tracking-id...
- Beginner explanation: Restate **Prune is not garbage collection of everything** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune is not garbage collection of everything** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Prune is not garbage collection of everything**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Prune is not garbage collection of everything**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune is not garbage collection of everything** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 70 - Resource tracking

- Lesson anchor: A current default tracking annotation resembles: metadata: annotations: argocd.argoproj.io/tracking-id: - guestbook:apps/Deployment:guestbook/guestbook-ui The tracking ID encodes the Application and the resource identity; Argo currently uses annotation trac...
- Beginner explanation: Restate **Resource tracking** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Resource tracking** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Resource tracking**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Resource tracking**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Resource tracking** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 71 - Production ownership rule

- Lesson anchor: Never forget: Git path │ ▼ Application │ ▼ tracked Kubernetes resources Ownership should be deliberate. Avoid: Application A and Application B both believing they own the same Kubernetes object. That's one reason FailOnSharedResource=true exists. ([Argo CD]...
- Beginner explanation: Restate **Production ownership rule** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production ownership rule** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Production ownership rule**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Production ownership rule**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production ownership rule** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 72 - Current final lab policy

- Lesson anchor: Let's leave guestbook configured as: syncPolicy: automated: enabled: true prune: true selfHeal: true allowEmpty: false syncOptions: Patch it: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": {
- Beginner explanation: Restate **Current final lab policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Current final lab policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Current final lab policy**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Current final lab policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Current final lab policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 73 - Important: update your local YAML too

- Lesson anchor: Remember: kubectl patch changed the live Application resource. But your local: guestbook-application.yaml from Lesson 3 may still contain the old policy. If you later run: kubectl apply -f guestbook-application.yaml you could overwrite the live configuration.
- Beginner explanation: Restate **Important: update your local YAML too** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important: update your local YAML too** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Important: update your local YAML too**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Important: update your local YAML too**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important: update your local YAML too** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 74 - Notice the irony

- Lesson anchor: We just learned GitOps— yet our: Application CR still lives in: a local file and we manually use: kubectl apply That's temporary. Soon we'll place Argo Application definitions themselves into Git. Then: Git │ ▼ Argo manages Applications
- Beginner explanation: Restate **Notice the irony** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Notice the irony** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Notice the irony**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Notice the irony**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Notice the irony** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 75 - Troubleshooting auto-sync

- Lesson anchor: Application stays: OutOfSync even though automation is configured. Check: argocd app get guestbook Then: kubectl get application guestbook \ -n argocd \ -o yaml Verify: syncPolicy: automated: enabled: true Then investigate:
- Beginner explanation: Restate **Troubleshooting auto-sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting auto-sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Troubleshooting auto-sync**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Troubleshooting auto-sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting auto-sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 76 - Troubleshooting self-heal

- Lesson anchor: You manually change: 1 → 3 but it remains 3. Check: Then: argocd app diff guestbook If Argo doesn't consider the field a meaningful diff, self-heal won't behave as you expected. ---
- Beginner explanation: Restate **Troubleshooting self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Troubleshooting self-heal**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Troubleshooting self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 77 - Troubleshooting prune

- Lesson anchor: Git resource removed. Live resource remains. Check: automated.prune true? resource tracked by this Application? Prune=false annotation? Prune=confirm waiting? sync window blocking? application actually OutOfSync? pruning scheduled PruneLast?
- Beginner explanation: Restate **Troubleshooting prune** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting prune** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Troubleshooting prune**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Troubleshooting prune**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting prune** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 78 - Troubleshooting auto-prune "dangerously wants to delete everything"

- Lesson anchor: Stop and ask: Did repo fetch fail? Did manifest generation return empty? Wrong path? Wrong branch? Kustomize problem? Helm values issue? Automation changed source path? Is allowEmpty enabled? Do not immediately click: SYNC / PRUNE
- Beginner explanation: Restate **Troubleshooting auto-prune "dangerously wants to delete everything"** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting auto-prune "dangerously wants to delete everything"** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Troubleshooting auto-prune "dangerously wants to delete everything"**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Troubleshooting auto-prune "dangerously wants to delete everything"**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting auto-prune "dangerously wants to delete everything"** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 79 - GitOps version of `terraform plan`

- Lesson anchor: Terraform gives: Plan: + create ~ update Argo gives: Desired vs Live through: argocd app diff These are not identical systems, but the operating habit should be similar: Understand destructive changes before executing them.
- Beginner explanation: Restate **GitOps version of `terraform plan`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitOps version of `terraform plan`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **GitOps version of `terraform plan`**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **GitOps version of `terraform plan`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitOps version of `terraform plan`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 80 - Auto-sync does not remove need for diff review

- Lesson anchor: Even with auto-sync: runtime Argo diff is useful for debugging. Before merge, CI should also render/test desired configuration. Eventually our GitOps PR pipeline will do: helm template kustomize build schema validation policy checks
- Beginner explanation: Restate **Auto-sync does not remove need for diff review** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Auto-sync does not remove need for diff review** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Auto-sync does not remove need for diff review**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Auto-sync does not remove need for diff review**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Auto-sync does not remove need for diff review** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 81 - Never-forget auto-sync matrix

- Lesson anchor: Current Argo semantics distinguish ordinary auto-sync, self-heal, and automatic pruning along these lines. ([argo-cd.readthedocs.io][1]) ---
- Beginner explanation: Restate **Never-forget auto-sync matrix** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget auto-sync matrix** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Never-forget auto-sync matrix**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Never-forget auto-sync matrix**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget auto-sync matrix** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 82 - Never-forget deletion matrix

- Lesson anchor: prune=false = removed from Git does not automatically delete live resource prune=true = removed from Git can be automatically deleted Prune=false annotation = protect particular resource Prune=confirm = require deletion approval
- Beginner explanation: Restate **Never-forget deletion matrix** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget deletion matrix** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Never-forget deletion matrix**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Never-forget deletion matrix**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget deletion matrix** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 83 - Interview — What is automated sync?

- Lesson anchor: Strong answer: Automated sync allows Argo CD to automatically reconcile an Application when its desired manifests differ from live cluster state in a way that requires synchronization, removing the need for CI or an operator to explicitly invoke the Argo CD...
- Beginner explanation: Restate **Interview — What is automated sync?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What is automated sync?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — What is automated sync?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — What is automated sync?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What is automated sync?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 84 - Interview — Auto-sync vs self-heal

- Lesson anchor: AUTO-SYNC = desired configuration changed SELF-HEAL = live configuration changed That's the cleanest answer. ---
- Beginner explanation: Restate **Interview — Auto-sync vs self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Auto-sync vs self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — Auto-sync vs self-heal**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — Auto-sync vs self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Auto-sync vs self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 85 - Interview — What is prune?

- Lesson anchor: Pruning removes application resources that Argo tracks but which are no longer present in the desired state. Automatic pruning must be explicitly enabled; it is disabled by default for safety. ([argo-cd.readthedocs.io][1])
- Beginner explanation: Restate **Interview — What is prune?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What is prune?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — What is prune?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — What is prune?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What is prune?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 86 - Interview — Why `allowEmpty`?

- Lesson anchor: It provides an additional protection against an automated prune accidentally reducing an Application to zero desired resources. allowEmpty: true explicitly declares that an empty desired application is valid. ([argo-cd.readthedocs.io][1])
- Beginner explanation: Restate **Interview — Why `allowEmpty`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Why `allowEmpty`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Why `allowEmpty`?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Why `allowEmpty`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Why `allowEmpty`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 87 - Interview — `PruneLast`

- Lesson anchor: other resources deploy ↓ become healthy ↓ other waves complete ↓ PRUNE OLD RESOURCES That's exactly what PruneLast=true is for. ([Argo CD][3]) ---
- Beginner explanation: Restate **Interview — `PruneLast`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — `PruneLast`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — `PruneLast`**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — `PruneLast`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — `PruneLast`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 88 - Interview — `ApplyOutOfSyncOnly`

- Lesson anchor: It reduces sync work for large Applications by applying only resources currently considered OutOfSync rather than reapplying every Application object; hooks can still run and the sync remains recorded. ([Argo CD][3]) ---
- Beginner explanation: Restate **Interview — `ApplyOutOfSyncOnly`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — `ApplyOutOfSyncOnly`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — `ApplyOutOfSyncOnly`**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — `ApplyOutOfSyncOnly`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — `ApplyOutOfSyncOnly`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 89 - Interview — What are Sync Windows?

- Lesson anchor: Sync Windows are AppProject-level allow or deny schedules controlling when matching Applications may synchronize. They can match by Application, destination namespace, or cluster, affect automated and manual syncs, and can optionally permit manual override...
- Beginner explanation: Restate **Interview — What are Sync Windows?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What are Sync Windows?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — What are Sync Windows?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — What are Sync Windows?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What are Sync Windows?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 90 - Interview trap — auto-sync implies self-heal

- Lesson anchor: Wrong. You can have: auto-sync = true selfHeal = false and live-only drift will not get the same automatic healing behavior. ([argo-cd.readthedocs.io][1]) ---
- Beginner explanation: Restate **Interview trap — auto-sync implies self-heal** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — auto-sync implies self-heal** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview trap — auto-sync implies self-heal**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview trap — auto-sync implies self-heal**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — auto-sync implies self-heal** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 91 - Interview trap — auto-sync implies prune

- Lesson anchor: Wrong. Automatic pruning is separately enabled and defaults off. ([argo-cd.readthedocs.io][1]) ---
- Beginner explanation: Restate **Interview trap — auto-sync implies prune** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — auto-sync implies prune** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview trap — auto-sync implies prune**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview trap — auto-sync implies prune**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — auto-sync implies prune** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 92 - Interview trap — prune means entire namespace is Argo-owned

- Lesson anchor: Wrong. Argo tracks resources belonging to an Application; current default tracking uses an Argo tracking annotation. ([Argo CD][5]) A random unrelated resource in the same namespace is not automatically equivalent to an Argo-managed resource.
- Beginner explanation: Restate **Interview trap — prune means entire namespace is Argo-owned** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — prune means entire namespace is Argo-owned** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview trap — prune means entire namespace is Argo-owned**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview trap — prune means entire namespace is Argo-owned**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — prune means entire namespace is Argo-owned** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 93 - Interview trap — `allowEmpty=true` is safer

- Lesson anchor: No. It removes a safety barrier. It should only be enabled when: zero resources is intentionally a valid desired state. ---
- Beginner explanation: Restate **Interview trap — `allowEmpty=true` is safer** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — `allowEmpty=true` is safer** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview trap — `allowEmpty=true` is safer**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview trap — `allowEmpty=true` is safer**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — `allowEmpty=true` is safer** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 94 - Interview trap — `Replace=true` is an optimization

- Lesson anchor: Wrong. It changes application semantics from normal apply toward replace/create and can cause recreation/outage. Argo explicitly warns that it may be destructive. ([Argo CD][3]) ---
- Beginner explanation: Restate **Interview trap — `Replace=true` is an optimization** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — `Replace=true` is an optimization** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview trap — `Replace=true` is an optimization**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview trap — `Replace=true` is an optimization**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — `Replace=true` is an optimization** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 95 - Interview trap — Force sync is harmless

- Lesson anchor: Wrong. Force=true can drive delete/create behavior and is intentionally destructive. ([Argo CD][3]) ---
- Beginner explanation: Restate **Interview trap — Force sync is harmless** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — Force sync is harmless** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview trap — Force sync is harmless**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview trap — Force sync is harmless**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — Force sync is harmless** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 96 - Interview trap — auto-sync removes approvals

- Lesson anchor: Wrong. You can have: PR approval CODEOWNERS policy checks Sync Windows auto-sync at the same time. Automation governs execution. Approval governs authorization of desired state. ---
- Beginner explanation: Restate **Interview trap — auto-sync removes approvals** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — auto-sync removes approvals** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview trap — auto-sync removes approvals**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview trap — auto-sync removes approvals**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — auto-sync removes approvals** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 97 - Production safety hierarchy

- Lesson anchor: Think: Git access │ ▼ Pull Request │ ▼ CODEOWNERS │ ▼ CI validation │ ▼ Merge │ ▼ Sync Window │ ▼ Argo Auto-Sync │ ▼ Prune controls │ ▼ Kubernetes RBAC │ ▼ Admission Policy │ ▼ Runtime GitOps production safety comes from layers—not one checkbox.
- Beginner explanation: Restate **Production safety hierarchy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production safety hierarchy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Production safety hierarchy**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Production safety hierarchy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production safety hierarchy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 98 - Complete Lesson 4 controller model

- Lesson anchor: GIT Desired State │ ▼ Application Controller │ compare live │ ┌──────────┴──────────┐ │                     │ ▼                     ▼ Synced               OutOfSync │ ┌───────────┼───────────┐ │           │           │ ▼           ▼           ▼
- Beginner explanation: Restate **Complete Lesson 4 controller model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Complete Lesson 4 controller model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Complete Lesson 4 controller model**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Complete Lesson 4 controller model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Complete Lesson 4 controller model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 99 - Never-forget Lesson 4 rules

- Lesson anchor: 1. Auto-sync, self-heal and prune are separate controls. 2. Auto-sync removes the need for manual sync on desired-state changes. 3. Self-heal corrects live-only drift. 4. Prune deletes resources removed from desired state.
- Beginner explanation: Restate **Never-forget Lesson 4 rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget Lesson 4 rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Never-forget Lesson 4 rules**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Never-forget Lesson 4 rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget Lesson 4 rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Our starting state x security

- Learning level: Beginner.
- Environment: a security and audit review.
- Scenario: The team must apply **Our starting state** while a change involving **What does auto-sync actually remove?** places **security** at risk.
- Plain-language question: What problem does **Our starting state** solve here, and who notices first when it fails?
- Lesson evidence anchor: Make sure Lesson 3's application still exists: argocd app get guestbook Then: kubectl get deployment guestbook-ui -n guestbook You want approximately: READY 1/1 Check the desired replica count: kubectl get deployment guestbook-ui \
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
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
- Interview prompt: Defend **Our starting state** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 1.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ "Automated Sync Policy - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://github.com/argoproj/argocd-example-apps/blob/master/kustomize-guestbook/kustomization.yaml?utm_source=chatgpt.com "kustomization.yaml - argoproj/argocd-example-apps"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/ "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync_windows/ "Sync Windows - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/latest/user-guide/resource_tracking/?utm_source=chatgpt.com "Resource Tracking - Declarative GitOps CD for Kubernetes"
