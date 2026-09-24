# Module 14 — GitOps with Argo CD

## Lesson 3: `Application` CRD — First Real GitOps Deployment & Drift Lab

In Lesson 1 we learned:

```text
Git desired state
      │
      ▼
Argo CD
      │
      ▼
Kubernetes live state
```

In Lesson 2 we installed the **Argo CD control plane**.

Now we finally connect the two.

Our lab:

```text
Official Git Repository
        │
        ▼
Argo Application
        │
        ▼
repo-server
        │
        ▼
desired manifests
        │
        ▼
application-controller
        │
        ▼
Kubernetes
        │
        ▼
guestbook application
```

Then we will deliberately do:

```text
Git:
replicas = 1

Cluster:
replicas = 3
```

and watch:

```text
Synced
   ↓
manual change
   ↓
OutOfSync
   ↓
Diff
   ↓
Manual Sync
   ↓
Synced
```

That is our first genuine **GitOps reconciliation experiment**.

---

# 14.235 Prerequisites

Before continuing, verify:

```bash
kubectl get pods -n argocd
```

and:

```bash
argocd version
```

You want Argo CD's control plane available and your CLI authenticated.

Also check:

```bash
argocd app list
```

It may currently show no applications.

That's fine.

---

# 14.236 What exactly is an `Application`?

An Argo CD `Application` is a Kubernetes custom resource representing **one deployed application instance in an environment**.

Its two essential relationships are:

```text
SOURCE
=
where desired state comes from


DESTINATION
=
where desired state should exist
```

Argo's current declarative specification defines an Application primarily through a source repository/revision/path and a destination cluster/namespace. ([Argo CD][1])

Think:

```text
Application
│
├── Source
│     ├── Repository
│     ├── Revision
│     └── Path
│
├── Destination
│     ├── Cluster
│     └── Namespace
│
└── Sync behavior
```

---

# 14.237 The first `Application`

Create a working directory:

```bash
mkdir -p ~/argocd-labs/lesson-3
cd ~/argocd-labs/lesson-3
```

Now create:

```bash
nano guestbook-application.yaml
```

Paste:

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
    syncOptions:
      - CreateNamespace=true
```

This follows Argo CD's official minimal guestbook Application pattern, with `CreateNamespace=true` added so the target namespace can be created automatically during synchronization. ([Argo CD][1])

---

# 14.238 Read the YAML as English

Don't think of this as YAML yet.

Read:

```text
Create an Argo CD Application

named:
guestbook

managed by:
Argo CD in namespace argocd

using project:
default

desired state comes from:
argoproj/argocd-example-apps

revision:
HEAD

directory:
guestbook

deploy into:
this Kubernetes cluster

namespace:
guestbook
```

That is essentially the whole Application.

---

# 14.239 `apiVersion`

```yaml
apiVersion: argoproj.io/v1alpha1
```

This tells Kubernetes:

```text
This resource belongs to
Argo project's API group.
```

When we installed Argo CD, its CRDs taught Kubernetes about resources such as:

```text
Application
ApplicationSet
AppProject
```

Without that CRD:

```yaml
kind: Application
```

would not be recognized.

---

# 14.240 `kind`

```yaml
kind: Application
```

This is not:

```text
apps/v1 Deployment
```

It is:

```text
Argo CD Application CR
```

The Application Controller watches these resources and reconciles the desired state they describe.

---

# 14.241 `metadata.name`

```yaml
metadata:
  name: guestbook
```

This becomes the Argo application name:

```text
guestbook
```

So later:

```bash
argocd app get guestbook
```

works.

Application names identify applications within the Argo CD installation. ([Argo CD][1])

---

# 14.242 Why `metadata.namespace: argocd`?

```yaml
metadata:
  namespace: argocd
```

This tells Kubernetes where the **Application object itself** lives.

Important distinction:

```text
Application CR
lives in:
argocd


Business workload
lives in:
guestbook
```

By default, Application and AppProject resources belong in the Argo CD control-plane namespace, typically `argocd`; Argo CD can be configured to support Applications in other namespaces, but that is an explicitly enabled multi-tenancy feature. ([Argo CD][1])

So do not confuse:

```yaml
metadata:
  namespace: argocd
```

with:

```yaml
destination:
  namespace: guestbook
```

They mean completely different things.

---

# 14.243 Two namespaces

Permanent mental model:

```text
metadata.namespace
=
where the Argo Application CR exists


destination.namespace
=
where the application's
namespaced Kubernetes resources go
```

Diagram:

```text
argocd namespace

Application/guestbook
        │
        │ controls
        ▼

guestbook namespace

Deployment
Service
Pods
```

---

# 14.244 `spec.project`

```yaml
project: default
```

Every Argo Application belongs to an:

# `AppProject`

For now:

```text
default
```

keeps the lab simple.

But there is an important production warning.

The automatically created `default` project is initially highly permissive: it allows all repositories, destination clusters/namespaces, and resource kinds. Argo recommends dedicated Projects with explicit source, destination, and resource restrictions for real multi-team environments. ([Argo CD][2])

So:

```text
LAB
→ default


PRODUCTION
→ dedicated AppProject
```

We'll build those later.

---

# 14.245 Think of `AppProject` as a security boundary

Preview:

```text
Application
=
WHAT should deploy?


AppProject
=
WHAT IS IT ALLOWED TO DO?
```

For example:

```text
Payments Project

allowed Git:
payments-config

allowed cluster:
production

allowed namespace:
payments-prod
```

This becomes essential when one Argo CD serves many teams.

---

# 14.246 `source.repoURL`

```yaml
source:
  repoURL: https://github.com/argoproj/argocd-example-apps.git
```

This answers:

> Where is the desired configuration?

Flow:

```text
Git repository
     │
     ▼
repo-server
     │
     ▼
desired manifests
```

Because this repository is public, we don't need credentials for today's exercise.

Private repository authentication comes later.

---

# 14.247 `targetRevision`

```yaml
targetRevision: HEAD
```

This answers:

> Which repository revision should Argo track?

A revision can conceptually be:

```text
branch

tag

commit
```

Argo's Application specification supports a revision such as a branch/tag/commit as part of its source declaration. ([Argo CD][1])

For the official learning example:

```text
HEAD
```

is convenient.

For carefully controlled production deployments, we'll later discuss explicit environment branches/tags and immutable revisions.

---

# 14.248 `path`

```yaml
path: guestbook
```

This means:

```text
repository root
│
└── guestbook/
```

is the desired-state directory.

The official example currently contains plain Kubernetes manifests in that path. Argo automatically detects a directory of plain manifest files; explicit `directory:` configuration isn't necessary unless additional directory options are needed. ([Argo CD][3])

---

# 14.249 Source mental formula

Memorize:

```text
SOURCE

repoURL
+
targetRevision
+
path
```

Example:

```text
repo:
argocd-example-apps

revision:
HEAD

path:
guestbook
```

Together they answer:

> **Exactly where should Argo obtain desired state?**

---

# 14.250 `destination.server`

```yaml
destination:
  server: https://kubernetes.default.svc
```

This means:

# the same Kubernetes cluster in which Argo CD is running.

For an in-cluster destination, Argo's official documentation uses:

```text
https://kubernetes.default.svc
```

External target clusters require separate registration/credentials. ([Argo CD][4])

Architecture:

```text
Argo CD
  │
  ▼
kubernetes.default.svc
  │
  ▼
same API server
```

---

# 14.251 `destination.namespace`

```yaml
namespace: guestbook
```

This specifies the default target namespace for namespaced resources that don't already declare their own namespace. ([Argo CD][5])

Think:

```text
Deployment
Service
ConfigMap
Secret

        │
        ▼

guestbook namespace
```

assuming those manifests do not override their namespace individually.

---

# 14.252 `CreateNamespace=true`

We currently do **not** have:

```text
guestbook namespace
```

Check:

```bash
kubectl get namespace guestbook
```

Likely:

```text
NotFound
```

Our Application contains:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

Argo documents this sync option as ensuring the destination namespace exists during synchronization. ([Argo CD][5])

So we don't need:

```bash
kubectl create namespace guestbook
```

manually.

---

# 14.253 Important: we did NOT enable automated sync

Notice our YAML does not contain:

```yaml
automated:
```

Therefore:

```text
Argo may detect differences
```

but we still decide when:

```text
SYNC
```

happens.

This is intentional.

We want to learn:

```text
DETECTION
≠
RECONCILIATION AUTHORIZATION
```

Argo's automated sync is an explicit policy; when configured, Argo can automatically synchronize upon detected desired/live differences. ([Argo CD][6])

---

# 14.254 Apply the Application resource

Run:

```bash
kubectl apply -f guestbook-application.yaml
```

Expected concept:

```text
application.argoproj.io/guestbook created
```

Now verify:

```bash
kubectl get application -n argocd
```

or shorthand if available:

```bash
kubectl get applications -n argocd
```

---

# 14.255 What just happened?

You did **not** directly deploy:

```text
Deployment

Service
```

You created:

```text
Application
```

which says:

```text
Argo,

manage that Git path
as this Kubernetes application.
```

The controller now has a new reconciliation object.

---

# 14.256 Inspect through Argo CLI

Run:

```bash
argocd app get guestbook
```

You should see information such as:

```text
Name

Project

Server

Namespace

Repo

Target

Path

Sync Status

Health Status
```

Argo's CLI exposes commands such as `app get`, `app resources`, `app manifests`, `app diff`, `app sync`, `app history`, and `app wait` for examining the application lifecycle. ([Argo CD][7])

---

# 14.257 Force a refresh when learning

If status seems stale:

```bash
argocd app get guestbook --refresh
```

Current Argo CLI supports `--refresh` specifically to refresh application data while retrieving it. ([Argo CD][8])

This is useful during labs because otherwise normal reconciliation/cache intervals may mean changes aren't displayed immediately.

---

# 14.258 Initial state

Because we've chosen manual sync, a common initial status is approximately:

```text
Sync Status:
OutOfSync

Health Status:
Missing
```

Why?

Git declares resources:

```text
Deployment
Service
```

but live Kubernetes does not yet contain them.

Conceptually:

```text
Desired resources
=
2


Live resources
=
0


Desired != Live
```

Therefore:

```text
OUT OF SYNC
```

---

# 14.259 `OutOfSync` is not automatically an error

This is crucial.

```text
OutOfSync
```

means:

> Desired and live states differ.

It does **not** necessarily mean:

```text
Argo is broken.
```

Before the first manual deployment:

```text
OutOfSync
```

is exactly what we expect.

---

# 14.260 Inspect desired manifests before sync

Run:

```bash
argocd app manifests guestbook
```

This lets you see what Argo believes Git will render into Kubernetes objects.

This is extremely useful for troubleshooting:

```text
Git files
     │
     ▼
Argo rendering
     │
     ▼
desired manifests
```

---

# 14.261 Inspect the current official deployment

The official guestbook example currently defines:

```text
Deployment:
guestbook-ui

replicas:
1
```

and uses the `guestbook-ui` application image. ([GitHub][9])

That `replicas: 1` value is going to be important in our drift experiment.

---

# 14.262 Perform our first GitOps sync

Run:

```bash
argocd app sync guestbook
```

Now watch:

```bash
argocd app get guestbook
```

or:

```bash
argocd app wait guestbook --sync --health
```

Argo provides `app sync` for synchronization and `app wait` for waiting on application state. ([Argo CD][7])

---

# 14.263 What `sync` means

The controller now does:

```text
Git
 │
 ▼
Desired Deployment
Desired Service
 │
 ▼
Compare with Kubernetes
 │
 ▼
missing
 │
 ▼
Create resources
```

This is different from:

```bash
kubectl apply -f guestbook/
```

because Argo remains responsible for continuously comparing that application afterward.

---

# 14.264 Verify namespace creation

Run:

```bash
kubectl get namespace guestbook
```

You should now see:

```text
guestbook   Active
```

This occurred because we configured:

```yaml
CreateNamespace=true
```

rather than creating the namespace manually. ([Argo CD][5])

---

# 14.265 Inspect deployed resources

Run:

```bash
kubectl get all -n guestbook
```

Then:

```bash
kubectl get deployment -n guestbook
```

And:

```bash
kubectl get pods -n guestbook -o wide
```

You should see the workload corresponding to the guestbook manifests from the official example repository. ([GitHub][9])

---

# 14.266 Inspect from Argo's perspective

Run:

```bash
argocd app resources guestbook
```

This is important.

`kubectl` answers:

```text
What resources exist
in Kubernetes?
```

Argo answers:

```text
What resources belong
to this GitOps Application?
```

Two related but different views.

---

# 14.267 Application resource tree

Try:

```bash
argocd app get guestbook --output tree
```

Current CLI supports tree output for visualizing an application's resource hierarchy. ([Argo CD][8])

Conceptually:

```text
guestbook
│
├── Deployment
│    └── ReplicaSet
│         └── Pod
│
└── Service
```

This becomes very useful with larger systems.

---

# 14.268 Expected good state

Eventually:

```text
Sync:
Synced


Health:
Healthy
```

Remember Lesson 1:

```text
SYNCED
=
live configuration matches desired state


HEALTHY
=
managed Kubernetes resources
are operationally healthy
```

They are separate dimensions.

---

# 14.269 Verify actual replica count

Run:

```bash
kubectl get deployment \
  guestbook-ui \
  -n guestbook
```

You should see:

```text
READY
1/1
```

and:

```bash
kubectl get deployment guestbook-ui \
  -n guestbook \
  -o jsonpath='{.spec.replicas}{"\n"}'
```

Expected:

```text
1
```

because the current official Git manifest declares one replica. ([GitHub][9])

---

# 14.270 First GitOps drift experiment

Now intentionally break declarative consistency.

Run:

```bash
kubectl scale deployment \
  guestbook-ui \
  --replicas=3 \
  -n guestbook
```

Verify:

```bash
kubectl get deployment guestbook-ui -n guestbook
```

You should see the desired live replica count becoming:

```text
3
```

---

# 14.271 What have we done?

We bypassed Git.

Desired state:

```text
Git
replicas = 1
```

Live state:

```text
Kubernetes
replicas = 3
```

Therefore:

```text
1 != 3
```

We have intentionally created:

# DRIFT.

---

# 14.272 Ask Argo to refresh

Run:

```bash
argocd app get guestbook --refresh
```

You should now see:

```text
Sync Status:
OutOfSync
```

because the live object differs from Git.

The `--refresh` option explicitly refreshes application data before displaying it. ([Argo CD][8])

---

# 14.273 What should happen to the three replicas?

This is the important question.

Because we did **not** enable:

```yaml
automated:
```

and did **not** enable:

```yaml
selfHeal: true
```

Argo should detect:

```text
OutOfSync
```

but not immediately force:

```text
3 → 1
```

Current Argo docs state that live-cluster changes do not trigger automated self-healing by default; `selfHeal` must be explicitly enabled for that behavior. ([Argo CD][6])

So this lesson demonstrates:

```text
OBSERVE

without automatically:

CORRECT
```

---

# 14.274 Detection vs correction

Permanent distinction:

```text
DRIFT DETECTION

"Something differs."


RECONCILIATION ACTION

"Correct it."
```

Today:

```text
Detection   ✓
Automatic correction   ✕
```

Lesson 4:

```text
Detection   ✓
Automatic correction   ✓
```

---

# 14.275 Inspect the exact diff

Run:

```bash
argocd app diff guestbook
```

Argo's `app diff` compares target/desired state against live state; its CLI currently returns exit code `1` when a difference is found, `0` when none exists, and `2` for general errors. ([Argo CD][10])

You should see something corresponding to:

```diff
 spec:
-  replicas: 1
+  replicas: 3
```

depending on diff orientation/output formatting.

The important point is:

```text
Argo knows
exactly which field drifted.
```

---

# 14.276 Why `argocd app diff` is powerful

Imagine 100 manifest fields.

Instead of asking:

```text
"Why does Argo say OutOfSync?"
```

use:

```bash
argocd app diff guestbook
```

You move from:

```text
guessing
```

to:

```text
desired vs live evidence.
```

This will become one of our standard production troubleshooting commands.

---

# 14.277 Kubernetes confirms the live state

Run:

```bash
kubectl get deployment guestbook-ui \
  -n guestbook \
  -o yaml
```

Look for:

```yaml
spec:
  replicas: 3
```

Meanwhile Git's official manifest declares:

```yaml
replicas: 1
```

([GitHub][9])

So now we have proven:

```text
Git Desired
=
1


Kubernetes Live
=
3


Argo
=
OutOfSync
```

---

# 14.278 First manual reconciliation

Now tell Argo:

```bash
argocd app sync guestbook
```

Then:

```bash
argocd app wait guestbook --sync --health
```

Finally:

```bash
kubectl get deployment guestbook-ui -n guestbook
```

Expected:

```text
replicas:
1
```

Argo has reapplied the desired state from Git.

---

# 14.279 What just happened?

You changed:

```text
Kubernetes directly
```

Argo detected drift.

Then you authorized:

```text
SYNC
```

Argo restored:

```text
Git state
```

Flow:

```text
Git = 1
     │
     ▼
Live = 3
     │
     ▼
OutOfSync
     │
     ▼
Manual Sync
     │
     ▼
Live = 1
     │
     ▼
Synced
```

That is GitOps reconciliation in practice.

---

# 14.280 Re-run the diff

Now:

```bash
argocd app diff guestbook
```

If everything matches, there should be no desired/live difference.

Conceptually:

```text
Git = 1

Cluster = 1

Difference = 0

Synced
```

---

# 14.281 This is different from Kubernetes self-healing

Suppose one Pod dies.

Kubernetes Deployment Controller handles:

```text
desired Pod replicas
versus
running Pods.
```

Argo does not need to recreate the Pod directly.

Hierarchy:

```text
GIT

Deployment replicas = 1
       │
       ▼
ARGO

Kubernetes Deployment
spec.replicas = 1
       │
       ▼
DEPLOYMENT CONTROLLER

running Pods = 1
```

Two controllers.

Two layers.

---

# 14.282 Argo manages declarative Kubernetes objects

Argo says:

```text
Deployment object should look like this.
```

Kubernetes says:

```text
Deployment says one replica,
therefore I'll ensure one Pod exists.
```

Do not confuse these control loops.

---

# 14.283 Inspect the Application CR itself

Run:

```bash
kubectl get application guestbook \
  -n argocd \
  -o yaml
```

Now you'll see two broad areas:

```text
spec
```

and:

```text
status
```

---

# 14.284 `spec` vs `status`

This is pure Kubernetes thinking.

```text
SPEC
=
what we want


STATUS
=
what controller currently observes
```

For the Argo Application:

```text
spec.source
spec.destination
spec.syncPolicy
```

describe intent.

Argo populates operational state under the Application's status/control-plane view.

---

# 14.285 Application source

Look for:

```yaml
spec:
  source:
```

This answers:

```text
WHERE
does desired state originate?
```

For us:

```text
repo
+
HEAD
+
guestbook path
```

---

# 14.286 Application destination

Look for:

```yaml
destination:
```

This answers:

```text
WHERE
should resources run?
```

For us:

```text
same cluster
+
guestbook namespace
```

---

# 14.287 Application project

Look for:

```yaml
project: default
```

This answers:

```text
UNDER WHICH ARGO SECURITY /
ORGANIZATIONAL POLICY
does this Application operate?
```

We'll replace `default` with dedicated Projects later because the default Project starts permissively. ([Argo CD][2])

---

# 14.288 Application sync policy

Current:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

Notice there is no:

```yaml
automated:
```

Therefore:

```text
manual synchronization
```

is our current operating model.

---

# 14.289 Manual sync model

```text
Git change
   │
   ▼
Argo detects
   │
   ▼
OUT OF SYNC
   │
   ▼
human/API says SYNC
   │
   ▼
reconcile
```

This is excellent while learning because you can observe every stage.

---

# 14.290 Automated sync model — preview

Next lesson we will evolve to:

```yaml
syncPolicy:
  automated:
    enabled: true
```

Then:

```text
Git difference
   │
   ▼
Argo detects
   │
   ▼
Argo automatically syncs
```

Current Argo CD supports explicit `automated.enabled` behavior in the Application sync policy. ([Argo CD][6])

---

# 14.291 Self-heal — preview

Then:

```yaml
automated:
  enabled: true
  selfHeal: true
```

means a live-only drift can trigger automatic reconciliation. ([Argo CD][6])

Our replica experiment would then behave:

```text
kubectl scale 1 → 3
       │
       ▼
Argo detects
       │
       ▼
Argo self-heals
       │
       ▼
3 → 1
```

without your manual:

```bash
argocd app sync
```

---

# 14.292 Prune — preview

Later:

```yaml
automated:
  prune: true
```

allows Argo to automatically remove resources that disappear from desired Git state.

Automatic pruning is disabled by default as a safety mechanism. ([Argo CD][6])

So remember:

```text
AUTO SYNC
≠
SELF HEAL
≠
PRUNE
```

Three related but different behaviors.

---

# 14.293 `CreateNamespace` is a sync option, not auto-sync

This is a subtle distinction.

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

does not mean:

```text
automatically synchronize app.
```

It means:

> When a synchronization occurs, make sure this destination namespace exists.

The sync-options specification puts these controls under `spec.syncPolicy.syncOptions`. ([Argo CD][11])

---

# 14.294 Source tool auto-detection

Our repository contains plain Kubernetes manifests.

So Argo treats it as a:

```text
Directory application
```

Later source paths may contain:

```text
Chart.yaml
```

→ Helm.

Or:

```text
kustomization.yaml
```

→ Kustomize.

For plain manifests, Argo can automatically detect directory content without an explicit `directory` block. ([Argo CD][3])

---

# 14.295 The repo server's role in our lab

When Argo sees:

```yaml
repoURL: ...
targetRevision: HEAD
path: guestbook
```

the repo server effectively performs:

```text
fetch repo
    │
    ▼
resolve revision
    │
    ▼
open path
    │
    ▼
generate manifests
```

Then the application controller compares those generated manifests with live Kubernetes resources.

That's Lesson 2 architecture becoming real.

---

# 14.296 The controller's role in our drift lab

When you changed replicas:

```text
kubectl
   │
   ▼
Deployment = 3
```

the application controller observed:

```text
Desired Deployment = 1

Live Deployment = 3
```

and reported:

```text
OutOfSync
```

When you issued:

```bash
argocd app sync guestbook
```

the controller reconciled the difference.

---

# 14.297 Argo UI exercise

Open:

```text
https://localhost:8080
```

assuming Lesson 2's port-forward is running.

Open:

```text
guestbook
```

You should see a resource graph similar to:

```text
Application
    │
    ├── Deployment
    │      │
    │      └── ReplicaSet
    │             │
    │             └── Pod
    │
    └── Service
```

Now repeat the scale experiment:

```bash
kubectl scale deployment \
  guestbook-ui \
  --replicas=3 \
  -n guestbook
```

Then use CLI refresh or UI refresh and observe:

```text
OutOfSync
```

visually.

---

# 14.298 UI is helpful — but don't become UI-dependent

You need to know all three views:

```text
Argo UI
```

for visual understanding.

```bash
argocd
```

for GitOps/application operations.

```bash
kubectl
```

for underlying Kubernetes diagnosis.

A production engineer needs all three.

---

# 14.299 The three views

Example:

```text
Argo UI:
Application OutOfSync


Argo CLI:
exact diff


kubectl:
live Deployment value
```

Together:

```text
Desired
+
controller view
+
live reality
```

gives strong troubleshooting evidence.

---

# 14.300 Essential commands from this lesson

Memorize these:

```bash
argocd app list
```

What Applications exist?

```bash
argocd app get guestbook
```

What is its state?

```bash
argocd app get guestbook --refresh
```

Refresh state.

```bash
argocd app manifests guestbook
```

What does Argo want to deploy?

```bash
argocd app resources guestbook
```

What resources belong to it?

```bash
argocd app diff guestbook
```

What's different?

```bash
argocd app sync guestbook
```

Reconcile.

```bash
argocd app wait guestbook --sync --health
```

Wait for good state.

These command families are part of the current Argo CLI. ([Argo CD][8])

---

# 14.301 Kubernetes equivalent commands

Keep these beside them:

```bash
kubectl get applications -n argocd
```

```bash
kubectl get application guestbook \
  -n argocd -o yaml
```

```bash
kubectl get all -n guestbook
```

```bash
kubectl describe deployment \
  guestbook-ui \
  -n guestbook
```

```bash
kubectl logs \
  deployment/guestbook-ui \
  -n guestbook
```

Argo manages Kubernetes.

It doesn't replace Kubernetes troubleshooting.

---

# 14.302 `Application` CR vs deployed objects

Never confuse:

```text
Application/guestbook
```

with:

```text
Deployment/guestbook-ui
```

The first is:

```text
GitOps management object
```

The second is:

```text
application workload object
```

Architecture:

```text
Application CR
      │
      ▼
manages
      │
      ▼
Deployment
Service
...
```

---

# 14.303 Application isn't the business application process

Argo's term:

```text
Application
```

means:

> a logical collection of Kubernetes resources managed as a GitOps unit.

It could represent:

```text
microservice

monitoring stack

Ingress controller

cert-manager

platform component
```

not only something end users call an "application."

---

# 14.304 One Application can manage many Kubernetes resources

Example later:

```text
payments-api Application
│
├── Deployment
├── Service
├── ConfigMap
├── ServiceAccount
├── HPA
├── NetworkPolicy
├── PodDisruptionBudget
└── Ingress
```

They share one:

```text
desired-state source
+
destination
+
sync lifecycle.
```

---

# 14.305 One Application should usually represent one coherent lifecycle

Bad:

```text
Application/company-everything
│
├── Payments
├── Orders
├── Kafka
├── Prometheus
├── cert-manager
└── unrelated Sandbox app
```

Then one sync boundary contains unrelated systems.

Better:

```text
coherent operational units
```

with ApplicationSet/App-of-Apps managing collections when needed.

Argo's multi-source guidance similarly warns against using one Application as a generic grouping mechanism for many unrelated applications. ([Argo CD][12])

---

# 14.306 Default Project is dangerous in production

Today:

```yaml
project: default
```

is fine.

But remember its default behavior:

```text
Source repos:
*

Destinations:
*

Cluster resources:
*
```

([Argo CD][2])

That means it is not our final enterprise security architecture.

Later:

```text
Payments Project
```

might allow only:

```text
Repo:
payments-gitops


Destination:
payments namespaces


Cluster:
approved Prod cluster


Resources:
approved kinds
```

---

# 14.307 Another important AppProject warning

Argo's declarative documentation warns that a Project capable of deploying into the Argo CD control-plane namespace effectively has admin-level implications and access to such Projects should be tightly restricted. ([Argo CD][1])

Why?

Imagine Git can deploy into:

```text
argocd namespace
```

and modify:

```text
Argo configuration
credentials
Applications
Projects
```

That can become privilege escalation.

We'll handle this in our RBAC lesson.

---

# 14.308 Production source revision

Today:

```yaml
targetRevision: HEAD
```

is intentionally simple.

Production strategies may use:

```text
environment branch

release tag

immutable Git SHA
```

depending on promotion design.

Never blindly conclude:

```text
HEAD is production best practice.
```

Our learning repo is different from our eventual production GitOps repository.

---

# 14.309 First troubleshooting scenario — `InvalidSpecError`

If Argo says:

```text
InvalidSpecError
```

check:

```text
repoURL

targetRevision

path

project

destination server

destination namespace
```

The Application source and destination are the central pieces Argo requires to know what and where to reconcile. ([Argo CD][1])

---

# 14.310 Repository path error

Suppose:

```yaml
path: guestrooms
```

instead of:

```yaml
path: guestbook
```

Argo cannot generate the intended manifests.

Troubleshooting path:

```text
Application
   │
   ▼
source
   │
   ▼
repoURL
   │
   ▼
revision
   │
   ▼
path
```

Use:

```bash
argocd app get guestbook
```

and controller/repo-server logs if required.

---

# 14.311 Repository server troubleshooting

If Argo reports manifest-generation/repository errors:

```bash
kubectl logs \
  deployment/argocd-repo-server \
  -n argocd
```

Think:

```text
Can repo-server reach Git?

Can DNS resolve Git?

Does repo exist?

Do credentials work?

Does revision exist?

Does path exist?

Can rendering succeed?
```

Use our Lesson 1 troubleshooting order:

```text
G
Git

R
Render
```

first.

---

# 14.312 Application controller troubleshooting

If desired manifests render correctly but sync/reconciliation behaves unexpectedly, inspect:

```bash
kubectl logs \
  statefulset/argocd-application-controller \
  -n argocd
```

depending on the installed workload representation.

First verify:

```bash
kubectl get deployment,statefulset -n argocd
```

Don't memorize controller workload type without checking your installation.

---

# 14.313 Sync permission failure

Suppose Argo says something like:

```text
forbidden
```

when creating an object.

Think:

```text
Git good           ✓

Rendering good     ✓

Diff good          ✓

Kubernetes API
authorization      ✕
```

Now investigate:

```text
Argo ServiceAccount

ClusterRole

RoleBinding

AppProject policy
```

That is a **sync authorization** failure.

---

# 14.314 `ImagePullBackOff`

Suppose:

```text
Sync:
Synced

Health:
Degraded
```

and:

```bash
kubectl get pods -n guestbook
```

shows:

```text
ImagePullBackOff
```

Then GitOps may be functioning perfectly.

The desired Deployment exists exactly as declared.

The issue is now:

```text
runtime image retrieval.
```

Check:

```bash
kubectl describe pod <pod> -n guestbook
```

---

# 14.315 This proves the G-R-D-S-H-A model

Remember Lesson 1:

```text
G
Git


R
Render


D
Diff


S
Sync


H
Health


A
Application
```

Examples:

```text
wrong repo
→ G


Helm error
→ R


OutOfSync
→ D


Forbidden
→ S


CrashLoopBackOff
→ H


HTTP 500
→ A
```

This prevents random troubleshooting.

---

# 14.316 `Synced` is not enough

After:

```bash
argocd app sync guestbook
```

do not only verify:

```text
Synced
```

Also check:

```text
Healthy
```

Then Kubernetes:

```bash
kubectl get pods -n guestbook
```

And finally application connectivity if relevant.

Production rule:

```text
SYNC SUCCESS
≠
SERVICE SUCCESS.
```

---

# 14.317 Optional local application access

Once the Service is available, inspect:

```bash
kubectl get svc -n guestbook
```

You can locally expose an appropriate Service with:

```bash
kubectl port-forward \
  svc/guestbook-ui \
  -n guestbook \
  8081:80
```

if that Service exists in the example version you pulled.

Then use:

```text
http://localhost:8081
```

This is only a local test path—not our production ingress architecture.

---

# 14.318 If port-forward says Service not found

Don't guess.

Run:

```bash
kubectl get svc -n guestbook
```

Use the actual Service name returned.

This is a general DevOps habit:

```text
discover actual state
before constructing commands.
```

---

# 14.319 Application deletion behavior — important preview

Deleting:

```text
Application
```

and deleting:

```text
managed application resources
```

are separate lifecycle questions.

Argo's declarative documentation notes that a cascading resource deletion requires the Argo resources finalizer; without that finalizer, deleting the Application itself does not automatically delete the resources it manages. ([Argo CD][1])

We'll study cascade/non-cascade deletion carefully before using it in production.

---

# 14.320 Why finalizers exist

Kubernetes finalizer mental model:

```text
Delete requested
      │
      ▼
perform required cleanup
      │
      ▼
remove finalizer
      │
      ▼
object actually disappears
```

Argo can use a finalizer so application deletion coordinates deletion of managed resources.

Do not casually experiment with cascading production deletion.

---

# 14.321 Do NOT delete today's guestbook yet

Keep:

```text
Application/guestbook
```

because Lesson 4 will use it to teach:

```text
Automated Sync

Self-Heal

Prune

AllowEmpty

Sync Options

production safety
```

We'll deliberately mutate it again.

---

# 14.322 First real production lesson

What did we actually prove?

Not simply:

```text
Argo can deploy YAML.
```

We proved:

```text
Git
is declared desired state

Argo
tracks that declaration

Kubernetes
contains live state

manual changes
create measurable drift

Argo
can show exact difference

sync
restores declared state
```

That's GitOps.

---

# 14.323 The difference from Jenkins push CD

Old model:

```text
Jenkins
   │
   ▼
kubectl apply
   │
   ▼
Deployment complete
```

Today's model:

```text
Git
  │
  ▼
Argo Application
  │
  ▼
continuous comparison
  │
  ▼
Kubernetes
```

The fundamental improvement isn't merely:

```text
different deployment tool.
```

It's:

```text
continuous desired/live relationship.
```

---

# 14.324 First GitOps invariant

After today, remember:

> **The cluster is not where we decide what production should be.**

The cluster tells us:

```text
what exists now.
```

Git tells Argo:

```text
what should exist.
```

Argo connects them.

---

# 14.325 Second GitOps invariant

Manual `kubectl` changes are not automatically the new truth.

If:

```text
Git = 1

kubectl = 3
```

we don't say:

```text
"Production is now officially 3."
```

We say:

```text
"Live state has drifted
from declared state."
```

If three is actually desired, then the persistent GitOps fix is:

```text
update Git to 3.
```

---

# 14.326 Third GitOps invariant

Never fight the reconciler without understanding its policy.

Today Argo did not self-heal automatically.

Next lesson it will.

Soon this:

```bash
kubectl scale ...
```

may appear to "work" for a few seconds and then be reverted.

That is not Argo malfunctioning.

That is the controller enforcing its ownership contract.

---

# 14.327 Application CR mental formula

Memorize:

```text
APPLICATION

=
PROJECT

+

SOURCE
(repo + revision + path)

+

DESTINATION
(cluster + namespace)

+

SYNC POLICY
```

That's the foundation.

---

# 14.328 First Application interview question

### What is an Argo CD Application?

Strong answer:

> **An Argo CD Application is a Kubernetes custom resource that links a desired-state source—typically a Git repository, revision, and path—to a destination Kubernetes cluster and namespace. Argo's Application Controller compares the generated desired resources with live cluster resources and manages their synchronization according to the application's policy.** ([Argo CD][1])

---

# 14.329 Interview — `metadata.namespace` vs `destination.namespace`

```text
metadata.namespace
=
where Application CR exists


destination.namespace
=
where namespaced workload
resources should deploy
```

This is a very common beginner confusion.

---

# 14.330 Interview — `repoURL`, `targetRevision`, `path`

```text
repoURL
=
which repository?


targetRevision
=
which branch/tag/commit?


path
=
which directory/config within it?
```

Together:

```text
desired-state location.
```

---

# 14.331 Interview — What is the destination server for in-cluster deployment?

```text
https://kubernetes.default.svc
```

is the standard in-cluster Kubernetes API destination used when Argo deploys to the cluster in which it is running. ([Argo CD][4])

---

# 14.332 Interview — What is `CreateNamespace=true`?

It is a synchronization option that tells Argo CD to ensure the configured destination namespace exists when syncing the Application. ([Argo CD][5])

It does **not** mean:

```text
enable auto-sync.
```

---

# 14.333 Interview — What does `OutOfSync` mean?

```text
Desired manifests
!=
live Kubernetes resources
```

It does not automatically mean:

```text
application outage.
```

A manually scaled but fully functioning Deployment may be:

```text
OutOfSync
+
Healthy
```

---

# 14.334 Interview — How do you determine why an app is OutOfSync?

Use:

```bash
argocd app diff <APP>
```

to compare target/desired and live states. ([Argo CD][10])

Then verify live Kubernetes with:

```bash
kubectl get ...
```

---

# 14.335 Interview — manual sync vs automated sync

```text
MANUAL

Argo detects drift
↓
operator triggers sync


AUTOMATED

Argo detects applicable drift
↓
controller triggers synchronization
according to policy
```

Automated synchronization is explicitly configured on the Application. ([Argo CD][6])

---

# 14.336 Interview trap — `default` AppProject is safe production isolation

Wrong.

The default project is initially permissive across source repositories, destinations, and resource kinds. Argo recommends creating dedicated constrained Projects for stronger isolation. ([Argo CD][2])

---

# 14.337 Interview trap — destination namespace is where Application CR lives

Wrong.

```text
Application CR
→ argocd


Managed resources
→ guestbook
```

Different namespaces.

---

# 14.338 Interview trap — OutOfSync means unhealthy

Wrong.

Possible:

```text
OutOfSync + Healthy
```

Example:

```text
Git replicas = 1

Live replicas = 3

all Pods healthy.
```

Configuration drift exists even though the service works.

---

# 14.339 Interview trap — Synced means app is healthy

Wrong.

Possible:

```text
Synced + Degraded
```

Example:

```text
Git image reference
matches Deployment

but Pods:
ImagePullBackOff.
```

Configuration matches.

Runtime fails.

---

# 14.340 Interview trap — `syncPolicy` means auto-sync

Wrong.

Our Application contains:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

but still requires manual synchronization because no automated policy is enabled.

---

# 14.341 Interview trap — manual kubectl change modifies Git

Wrong.

Flow is not:

```text
kubectl
→ Argo
→ Git
```

Argo CD normally reconciles:

```text
Git
→ cluster
```

It does not automatically commit your live manual changes back into Git.

---

# 14.342 Never-forget commands

```text
CREATE
kubectl apply -f guestbook-application.yaml


LIST
argocd app list


INSPECT
argocd app get guestbook


REFRESH
argocd app get guestbook --refresh


MANIFESTS
argocd app manifests guestbook


RESOURCES
argocd app resources guestbook


DIFF
argocd app diff guestbook


SYNC
argocd app sync guestbook


WAIT
argocd app wait guestbook --sync --health
```

Current Argo CLI exposes these application lifecycle operations. ([Argo CD][8])

---

# 14.343 Never-forget field map

```text
apiVersion
=
which API?


kind
=
Application


metadata.name
=
Argo app name


metadata.namespace
=
where Argo Application CR lives


project
=
Argo governance/security boundary


repoURL
=
where desired state comes from


targetRevision
=
which Git revision


path
=
where inside repository


destination.server
=
which Kubernetes cluster


destination.namespace
=
which workload namespace


syncPolicy
=
how reconciliation behaves
```

---

# 14.344 Complete Lesson 3 packet/control flow

```text
                  APPLICATION CR
                       │
                       ▼
                Application Controller
                       │
             ┌─────────┴─────────┐
             │                   │
             ▼                   ▼
         Repo Server        Kubernetes API
             │                   │
             ▼                   ▼
            Git              Live Resources
             │                   │
             └────────┬──────────┘
                      ▼
                    DIFF
                      │
               desired == live?
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
           YES                  NO
            │                   │
            ▼                   ▼
         SYNCED             OUT OF SYNC
                                │
                          Manual Sync today
                                │
                                ▼
                            Kubernetes
                                │
                                ▼
                              SYNCED
```

---

# 14.345 Lesson 3 practical checkpoint

You should now be able to reproduce this from memory:

```bash
kubectl apply -f guestbook-application.yaml
```

```bash
argocd app get guestbook
```

```bash
argocd app sync guestbook
```

```bash
kubectl scale deployment \
  guestbook-ui \
  --replicas=3 \
  -n guestbook
```

```bash
argocd app get guestbook --refresh
```

```bash
argocd app diff guestbook
```

```bash
argocd app sync guestbook
```

Then explain:

```text
Why did it become OutOfSync?

Why didn't Argo immediately revert it?

Why did sync change 3 → 1?

Where did 1 come from?
```

Answers:

```text
Because Git != live.

Because auto/self-heal was not enabled.

Because sync reconciled live state.

Because Git is declaring replicas=1.
```

The official guestbook example currently declares that one-replica Deployment. ([GitHub][9])

---

# ✅ Module 14 — Lesson 3 Complete

You now understand:

```text
✓ Application CRD

✓ Application object vs workload

✓ metadata.name

✓ metadata.namespace

✓ AppProject

✓ default project

✓ source

✓ repoURL

✓ targetRevision

✓ path

✓ destination

✓ in-cluster server

✓ destination namespace

✓ CreateNamespace

✓ manual sync

✓ desired manifests

✓ live resources

✓ OutOfSync

✓ Synced

✓ Health vs Sync

✓ app manifests

✓ app resources

✓ app diff

✓ app sync

✓ app wait

✓ deliberate drift

✓ manual reconciliation

✓ source rendering

✓ Application Controller flow

✓ first real GitOps deployment
```

# Next — Module 14, Lesson 4

## Automated Sync, Self-Heal, Prune & Production Sync Safety

We're going to modify the same `guestbook` Application into:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: true
    selfHeal: true
```

but we will **not** simply turn those options on.

We'll separately prove what each does:

```text
Experiment 1

Git revision changes
      │
      ▼
AUTO-SYNC


Experiment 2

kubectl replicas 1 → 5
      │
      ▼
SELF-HEAL
      │
      ▼
5 → 1 automatically


Experiment 3

resource removed from desired state
      │
      ▼
PRUNE
      │
      ▼
live resource deleted
```

Then we'll cover the dangerous pieces: **`allowEmpty`, prune propagation, `PruneLast`, `ApplyOutOfSyncOnly`, retry/backoff, sync windows, accidental mass deletion, emergency suspension, and why production auto-sync is safe only when Git review and ownership are designed properly.**

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.3.346 Professional Mastery Workbook

This workbook expands **`Application` CRD — First Real GitOps Deployment & Drift Lab** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 111 lesson-specific anchors.
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

### Concept card 1 - Prerequisites

- Lesson anchor: Before continuing, verify: kubectl get pods -n argocd and: argocd version You want Argo CD's control plane available and your CLI authenticated. Also check: argocd app list It may currently show no applications. That's fine.
- Beginner explanation: Restate **Prerequisites** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prerequisites** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Prerequisites**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Prerequisites**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prerequisites** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - What exactly is an `Application`?

- Lesson anchor: An Argo CD Application is a Kubernetes custom resource representing one deployed application instance in an environment. Its two essential relationships are: SOURCE = where desired state comes from DESTINATION = where desired state should exist
- Beginner explanation: Restate **What exactly is an `Application`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What exactly is an `Application`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **What exactly is an `Application`?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **What exactly is an `Application`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What exactly is an `Application`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - The first `Application`

- Lesson anchor: Create a working directory: mkdir -p ~/argocd-labs/lesson-3 cd ~/argocd-labs/lesson-3 Now create: nano guestbook-application.yaml Paste: apiVersion: argoproj.io/v1alpha1 kind: Application metadata: name: guestbook namespace: argocd
- Beginner explanation: Restate **The first `Application`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The first `Application`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **The first `Application`**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **The first `Application`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The first `Application`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Read the YAML as English

- Lesson anchor: Don't think of this as YAML yet. Read: Create an Argo CD Application named: guestbook managed by: Argo CD in namespace argocd using project: default desired state comes from: argoproj/argocd-example-apps revision: HEAD directory:
- Beginner explanation: Restate **Read the YAML as English** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Read the YAML as English** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Read the YAML as English**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Read the YAML as English**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Read the YAML as English** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - `apiVersion`

- Lesson anchor: apiVersion: argoproj.io/v1alpha1 This tells Kubernetes: This resource belongs to Argo project's API group. When we installed Argo CD, its CRDs taught Kubernetes about resources such as: Application ApplicationSet AppProject
- Beginner explanation: Restate **`apiVersion`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`apiVersion`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **`apiVersion`**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **`apiVersion`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`apiVersion`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - `kind`

- Lesson anchor: kind: Application This is not: apps/v1 Deployment It is: Argo CD Application CR The Application Controller watches these resources and reconciles the desired state they describe. ---
- Beginner explanation: Restate **`kind`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`kind`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`kind`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`kind`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`kind`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - `metadata.name`

- Lesson anchor: metadata: name: guestbook This becomes the Argo application name: guestbook So later: argocd app get guestbook works. Application names identify applications within the Argo CD installation. ([Argo CD][1]) ---
- Beginner explanation: Restate **`metadata.name`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`metadata.name`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **`metadata.name`**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **`metadata.name`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`metadata.name`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Why `metadata.namespace: argocd`?

- Lesson anchor: metadata: namespace: argocd This tells Kubernetes where the Application object itself lives. Important distinction: Application CR lives in: argocd Business workload lives in: guestbook By default, Application and AppProject resources belong in the Argo CD...
- Beginner explanation: Restate **Why `metadata.namespace: argocd`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why `metadata.namespace: argocd`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Why `metadata.namespace: argocd`?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Why `metadata.namespace: argocd`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why `metadata.namespace: argocd`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Two namespaces

- Lesson anchor: Permanent mental model: metadata.namespace = where the Argo Application CR exists destination.namespace = where the application's namespaced Kubernetes resources go Diagram: argocd namespace Application/guestbook │ │ controls
- Beginner explanation: Restate **Two namespaces** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Two namespaces** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Two namespaces**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Two namespaces**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Two namespaces** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - `spec.project`

- Lesson anchor: project: default Every Argo Application belongs to an: For now: default keeps the lab simple. But there is an important production warning. The automatically created default project is initially highly permissive: it allows all repositories, destination clu...
- Beginner explanation: Restate **`spec.project`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`spec.project`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **`spec.project`**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **`spec.project`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`spec.project`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Think of `AppProject` as a security boundary

- Lesson anchor: Preview: Application = WHAT should deploy? AppProject = WHAT IS IT ALLOWED TO DO? For example: Payments Project allowed Git: payments-config allowed cluster: production allowed namespace: payments-prod This becomes essential when one Argo CD serves many teams.
- Beginner explanation: Restate **Think of `AppProject` as a security boundary** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Think of `AppProject` as a security boundary** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Think of `AppProject` as a security boundary**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Think of `AppProject` as a security boundary**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Think of `AppProject` as a security boundary** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - `source.repoURL`

- Lesson anchor: source: repoURL: https://github.com/argoproj/argocd-example-apps.git This answers: Where is the desired configuration? Flow: Git repository │ ▼ repo-server │ ▼ desired manifests Because this repository is public, we don't need credentials for today's exercise.
- Beginner explanation: Restate **`source.repoURL`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`source.repoURL`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`source.repoURL`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`source.repoURL`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`source.repoURL`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - `targetRevision`

- Lesson anchor: targetRevision: HEAD This answers: Which repository revision should Argo track? A revision can conceptually be: branch tag commit Argo's Application specification supports a revision such as a branch/tag/commit as part of its source declaration. ([Argo CD][1])
- Beginner explanation: Restate **`targetRevision`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`targetRevision`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **`targetRevision`**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **`targetRevision`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`targetRevision`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - `path`

- Lesson anchor: path: guestbook This means: repository root │ └── guestbook/ is the desired-state directory. The official example currently contains plain Kubernetes manifests in that path. Argo automatically detects a directory of plain manifest files; explicit directory:...
- Beginner explanation: Restate **`path`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`path`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`path`**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`path`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`path`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Source mental formula

- Lesson anchor: Memorize: SOURCE repoURL + targetRevision + path Example: repo: argocd-example-apps revision: HEAD path: guestbook Together they answer: Exactly where should Argo obtain desired state? ---
- Beginner explanation: Restate **Source mental formula** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Source mental formula** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Source mental formula**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Source mental formula**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Source mental formula** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - `destination.server`

- Lesson anchor: destination: server: https://kubernetes.default.svc This means: For an in-cluster destination, Argo's official documentation uses: https://kubernetes.default.svc External target clusters require separate registration/credentials. ([Argo CD][4])
- Beginner explanation: Restate **`destination.server`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`destination.server`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **`destination.server`**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **`destination.server`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`destination.server`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - `destination.namespace`

- Lesson anchor: namespace: guestbook This specifies the default target namespace for namespaced resources that don't already declare their own namespace. ([Argo CD][5]) Think: Deployment Service ConfigMap Secret │ ▼ guestbook namespace assuming those manifests do not overr...
- Beginner explanation: Restate **`destination.namespace`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`destination.namespace`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **`destination.namespace`**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **`destination.namespace`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`destination.namespace`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - `CreateNamespace=true`

- Lesson anchor: We currently do not have: guestbook namespace Check: kubectl get namespace guestbook Likely: NotFound Our Application contains: syncPolicy: syncOptions: Argo documents this sync option as ensuring the destination namespace exists during synchronization. ([A...
- Beginner explanation: Restate **`CreateNamespace=true`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`CreateNamespace=true`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`CreateNamespace=true`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`CreateNamespace=true`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`CreateNamespace=true`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Important: we did NOT enable automated sync

- Lesson anchor: Notice our YAML does not contain: automated: Therefore: Argo may detect differences but we still decide when: SYNC happens. This is intentional. We want to learn: DETECTION ≠ RECONCILIATION AUTHORIZATION Argo's automated sync is an explicit policy; when con...
- Beginner explanation: Restate **Important: we did NOT enable automated sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important: we did NOT enable automated sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Important: we did NOT enable automated sync**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Important: we did NOT enable automated sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important: we did NOT enable automated sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Apply the Application resource

- Lesson anchor: Run: kubectl apply -f guestbook-application.yaml Expected concept: application.argoproj.io/guestbook created Now verify: kubectl get application -n argocd or shorthand if available: kubectl get applications -n argocd ---
- Beginner explanation: Restate **Apply the Application resource** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Apply the Application resource** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Apply the Application resource**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Apply the Application resource**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Apply the Application resource** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - What just happened?

- Lesson anchor: You did not directly deploy: Deployment Service You created: Application which says: Argo, manage that Git path as this Kubernetes application. The controller now has a new reconciliation object. ---
- Beginner explanation: Restate **What just happened?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What just happened?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **What just happened?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **What just happened?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What just happened?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Inspect through Argo CLI

- Lesson anchor: Run: argocd app get guestbook You should see information such as: Name Project Server Namespace Repo Target Path Sync Status Health Status Argo's CLI exposes commands such as app get, app resources, app manifests, app diff, app sync, app history, and app wa...
- Beginner explanation: Restate **Inspect through Argo CLI** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect through Argo CLI** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Inspect through Argo CLI**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Inspect through Argo CLI**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect through Argo CLI** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Force a refresh when learning

- Lesson anchor: If status seems stale: argocd app get guestbook --refresh Current Argo CLI supports --refresh specifically to refresh application data while retrieving it. ([Argo CD][8]) This is useful during labs because otherwise normal reconciliation/cache intervals may...
- Beginner explanation: Restate **Force a refresh when learning** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Force a refresh when learning** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Force a refresh when learning**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Force a refresh when learning**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Force a refresh when learning** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Initial state

- Lesson anchor: Because we've chosen manual sync, a common initial status is approximately: Sync Status: OutOfSync Health Status: Missing Why? Git declares resources: Deployment Service but live Kubernetes does not yet contain them. Conceptually:
- Beginner explanation: Restate **Initial state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Initial state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Initial state**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Initial state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Initial state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - `OutOfSync` is not automatically an error

- Lesson anchor: This is crucial. OutOfSync means: Desired and live states differ. It does not necessarily mean: Argo is broken. Before the first manual deployment: OutOfSync is exactly what we expect. ---
- Beginner explanation: Restate **`OutOfSync` is not automatically an error** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`OutOfSync` is not automatically an error** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **`OutOfSync` is not automatically an error**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **`OutOfSync` is not automatically an error**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`OutOfSync` is not automatically an error** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Inspect desired manifests before sync

- Lesson anchor: Run: argocd app manifests guestbook This lets you see what Argo believes Git will render into Kubernetes objects. This is extremely useful for troubleshooting: Git files │ ▼ Argo rendering │ ▼ desired manifests ---
- Beginner explanation: Restate **Inspect desired manifests before sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect desired manifests before sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Inspect desired manifests before sync**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Inspect desired manifests before sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect desired manifests before sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Inspect the current official deployment

- Lesson anchor: The official guestbook example currently defines: Deployment: guestbook-ui replicas: 1 and uses the guestbook-ui application image. ([GitHub][9]) That replicas: 1 value is going to be important in our drift experiment. ---
- Beginner explanation: Restate **Inspect the current official deployment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect the current official deployment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Inspect the current official deployment**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Inspect the current official deployment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect the current official deployment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Perform our first GitOps sync

- Lesson anchor: Run: argocd app sync guestbook Now watch: argocd app get guestbook or: argocd app wait guestbook --sync --health Argo provides app sync for synchronization and app wait for waiting on application state. ([Argo CD][7]) ---
- Beginner explanation: Restate **Perform our first GitOps sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Perform our first GitOps sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Perform our first GitOps sync**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Perform our first GitOps sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Perform our first GitOps sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - What `sync` means

- Lesson anchor: The controller now does: Git │ ▼ Desired Deployment Desired Service │ ▼ Compare with Kubernetes │ ▼ missing │ ▼ Create resources This is different from: kubectl apply -f guestbook/ because Argo remains responsible for continuously comparing that application...
- Beginner explanation: Restate **What `sync` means** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What `sync` means** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **What `sync` means**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **What `sync` means**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What `sync` means** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Verify namespace creation

- Lesson anchor: Run: kubectl get namespace guestbook You should now see: guestbook   Active This occurred because we configured: CreateNamespace=true rather than creating the namespace manually. ([Argo CD][5]) ---
- Beginner explanation: Restate **Verify namespace creation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Verify namespace creation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Verify namespace creation**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Verify namespace creation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Verify namespace creation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Inspect deployed resources

- Lesson anchor: Run: kubectl get all -n guestbook Then: kubectl get deployment -n guestbook And: kubectl get pods -n guestbook -o wide You should see the workload corresponding to the guestbook manifests from the official example repository. ([GitHub][9])
- Beginner explanation: Restate **Inspect deployed resources** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect deployed resources** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Inspect deployed resources**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Inspect deployed resources**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect deployed resources** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Inspect from Argo's perspective

- Lesson anchor: Run: argocd app resources guestbook This is important. kubectl answers: What resources exist in Kubernetes? Argo answers: What resources belong to this GitOps Application? Two related but different views. ---
- Beginner explanation: Restate **Inspect from Argo's perspective** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect from Argo's perspective** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Inspect from Argo's perspective**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Inspect from Argo's perspective**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect from Argo's perspective** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Application resource tree

- Lesson anchor: Try: argocd app get guestbook --output tree Current CLI supports tree output for visualizing an application's resource hierarchy. ([Argo CD][8]) Conceptually: guestbook │ ├── Deployment │    └── ReplicaSet │         └── Pod
- Beginner explanation: Restate **Application resource tree** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application resource tree** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Application resource tree**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Application resource tree**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application resource tree** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Expected good state

- Lesson anchor: Eventually: Sync: Synced Health: Healthy Remember Lesson 1: SYNCED = live configuration matches desired state HEALTHY = managed Kubernetes resources are operationally healthy They are separate dimensions. ---
- Beginner explanation: Restate **Expected good state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Expected good state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Expected good state**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Expected good state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Expected good state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Verify actual replica count

- Lesson anchor: Run: kubectl get deployment \ guestbook-ui \ -n guestbook You should see: READY 1/1 and: kubectl get deployment guestbook-ui \ -n guestbook \ -o jsonpath='{.spec.replicas}{"\n"}' Expected: 1 because the current official Git manifest declares one replica. ([...
- Beginner explanation: Restate **Verify actual replica count** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Verify actual replica count** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Verify actual replica count**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Verify actual replica count**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Verify actual replica count** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - First GitOps drift experiment

- Lesson anchor: Now intentionally break declarative consistency. Run: kubectl scale deployment \ guestbook-ui \ --replicas=3 \ -n guestbook Verify: kubectl get deployment guestbook-ui -n guestbook You should see the desired live replica count becoming:
- Beginner explanation: Restate **First GitOps drift experiment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First GitOps drift experiment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **First GitOps drift experiment**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **First GitOps drift experiment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First GitOps drift experiment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - What have we done?

- Lesson anchor: We bypassed Git. Desired state: Git replicas = 1 Live state: Kubernetes replicas = 3 Therefore: 1 != 3 We have intentionally created: ---
- Beginner explanation: Restate **What have we done?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What have we done?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **What have we done?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **What have we done?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What have we done?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Ask Argo to refresh

- Lesson anchor: Run: argocd app get guestbook --refresh You should now see: Sync Status: OutOfSync because the live object differs from Git. The --refresh option explicitly refreshes application data before displaying it. ([Argo CD][8])
- Beginner explanation: Restate **Ask Argo to refresh** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Ask Argo to refresh** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Ask Argo to refresh**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Ask Argo to refresh**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Ask Argo to refresh** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - What should happen to the three replicas?

- Lesson anchor: This is the important question. Because we did not enable: automated: and did not enable: selfHeal: true Argo should detect: OutOfSync but not immediately force: 3 → 1 Current Argo docs state that live-cluster changes do not trigger automated self-healing b...
- Beginner explanation: Restate **What should happen to the three replicas?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What should happen to the three replicas?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **What should happen to the three replicas?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **What should happen to the three replicas?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What should happen to the three replicas?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Detection vs correction

- Lesson anchor: Permanent distinction: DRIFT DETECTION "Something differs." RECONCILIATION ACTION "Correct it." Today: Detection   ✓ Automatic correction   ✕ Lesson 4: Detection   ✓ Automatic correction   ✓ ---
- Beginner explanation: Restate **Detection vs correction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Detection vs correction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Detection vs correction**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Detection vs correction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Detection vs correction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Inspect the exact diff

- Lesson anchor: Run: argocd app diff guestbook Argo's app diff compares target/desired state against live state; its CLI currently returns exit code 1 when a difference is found, 0 when none exists, and 2 for general errors. ([Argo CD][10])
- Beginner explanation: Restate **Inspect the exact diff** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect the exact diff** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Inspect the exact diff**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Inspect the exact diff**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect the exact diff** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Why `argocd app diff` is powerful

- Lesson anchor: Imagine 100 manifest fields. Instead of asking: "Why does Argo say OutOfSync?" use: argocd app diff guestbook You move from: guessing to: desired vs live evidence. This will become one of our standard production troubleshooting commands.
- Beginner explanation: Restate **Why `argocd app diff` is powerful** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why `argocd app diff` is powerful** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Why `argocd app diff` is powerful**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Why `argocd app diff` is powerful**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why `argocd app diff` is powerful** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Kubernetes confirms the live state

- Lesson anchor: Run: kubectl get deployment guestbook-ui \ -n guestbook \ -o yaml Look for: spec: replicas: 3 Meanwhile Git's official manifest declares: replicas: 1 ([GitHub][9]) So now we have proven: Git Desired = 1 Kubernetes Live =
- Beginner explanation: Restate **Kubernetes confirms the live state** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes confirms the live state** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Kubernetes confirms the live state**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Kubernetes confirms the live state**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Kubernetes confirms the live state** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - First manual reconciliation

- Lesson anchor: Now tell Argo: argocd app sync guestbook Then: argocd app wait guestbook --sync --health Finally: kubectl get deployment guestbook-ui -n guestbook Expected: replicas: 1 Argo has reapplied the desired state from Git. ---
- Beginner explanation: Restate **First manual reconciliation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First manual reconciliation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **First manual reconciliation**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **First manual reconciliation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First manual reconciliation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - What just happened?

- Lesson anchor: You changed: Kubernetes directly Argo detected drift. Then you authorized: SYNC Argo restored: Git state Flow: Git = 1 │ ▼ Live = 3 │ ▼ OutOfSync │ ▼ Manual Sync │ ▼ Live = 1 │ ▼ Synced That is GitOps reconciliation in practice.
- Beginner explanation: Restate **What just happened?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What just happened?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **What just happened?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **What just happened?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What just happened?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Re-run the diff

- Lesson anchor: Now: argocd app diff guestbook If everything matches, there should be no desired/live difference. Conceptually: Git = 1 Cluster = 1 Difference = 0 Synced ---
- Beginner explanation: Restate **Re-run the diff** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Re-run the diff** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Re-run the diff**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Re-run the diff**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Re-run the diff** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - This is different from Kubernetes self-healing

- Lesson anchor: Suppose one Pod dies. Kubernetes Deployment Controller handles: desired Pod replicas versus running Pods. Argo does not need to recreate the Pod directly. Hierarchy: GIT Deployment replicas = 1 │ ▼ ARGO Kubernetes Deployment
- Beginner explanation: Restate **This is different from Kubernetes self-healing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **This is different from Kubernetes self-healing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **This is different from Kubernetes self-healing**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **This is different from Kubernetes self-healing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **This is different from Kubernetes self-healing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Argo manages declarative Kubernetes objects

- Lesson anchor: Argo says: Deployment object should look like this. Kubernetes says: Deployment says one replica, therefore I'll ensure one Pod exists. Do not confuse these control loops. ---
- Beginner explanation: Restate **Argo manages declarative Kubernetes objects** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo manages declarative Kubernetes objects** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Argo manages declarative Kubernetes objects**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Argo manages declarative Kubernetes objects**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo manages declarative Kubernetes objects** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Inspect the Application CR itself

- Lesson anchor: Run: kubectl get application guestbook \ -n argocd \ -o yaml Now you'll see two broad areas: spec and: status ---
- Beginner explanation: Restate **Inspect the Application CR itself** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Inspect the Application CR itself** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Inspect the Application CR itself**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Inspect the Application CR itself**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Inspect the Application CR itself** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - `spec` vs `status`

- Lesson anchor: This is pure Kubernetes thinking. SPEC = what we want STATUS = what controller currently observes For the Argo Application: spec.source spec.destination spec.syncPolicy describe intent. Argo populates operational state under the Application's status/control...
- Beginner explanation: Restate **`spec` vs `status`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`spec` vs `status`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`spec` vs `status`**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`spec` vs `status`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`spec` vs `status`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Application source

- Lesson anchor: Look for: spec: source: This answers: WHERE does desired state originate? For us: repo + HEAD + guestbook path ---
- Beginner explanation: Restate **Application source** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application source** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Application source**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Application source**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application source** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Application destination

- Lesson anchor: Look for: destination: This answers: WHERE should resources run? For us: same cluster + guestbook namespace ---
- Beginner explanation: Restate **Application destination** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application destination** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Application destination**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Application destination**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application destination** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - Application project

- Lesson anchor: Look for: project: default This answers: UNDER WHICH ARGO SECURITY / ORGANIZATIONAL POLICY does this Application operate? We'll replace default with dedicated Projects later because the default Project starts permissively. ([Argo CD][2])
- Beginner explanation: Restate **Application project** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application project** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Application project**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Application project**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application project** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Application sync policy

- Lesson anchor: Current: syncPolicy: syncOptions: Notice there is no: automated: Therefore: manual synchronization is our current operating model. ---
- Beginner explanation: Restate **Application sync policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application sync policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Application sync policy**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Application sync policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application sync policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Manual sync model

- Lesson anchor: Git change │ ▼ Argo detects │ ▼ OUT OF SYNC │ ▼ human/API says SYNC │ ▼ reconcile This is excellent while learning because you can observe every stage. ---
- Beginner explanation: Restate **Manual sync model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Manual sync model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Manual sync model**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Manual sync model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Manual sync model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Automated sync model — preview

- Lesson anchor: Next lesson we will evolve to: syncPolicy: automated: enabled: true Then: Git difference │ ▼ Argo detects │ ▼ Argo automatically syncs Current Argo CD supports explicit automated.enabled behavior in the Application sync policy. ([Argo CD][6])
- Beginner explanation: Restate **Automated sync model — preview** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Automated sync model — preview** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Automated sync model — preview**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Automated sync model — preview**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Automated sync model — preview** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Self-heal — preview

- Lesson anchor: Then: automated: enabled: true selfHeal: true means a live-only drift can trigger automatic reconciliation. ([Argo CD][6]) Our replica experiment would then behave: kubectl scale 1 → 3 │ ▼ Argo detects │ ▼ Argo self-heals
- Beginner explanation: Restate **Self-heal — preview** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Self-heal — preview** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Self-heal — preview**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Self-heal — preview**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Self-heal — preview** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Prune — preview

- Lesson anchor: Later: automated: prune: true allows Argo to automatically remove resources that disappear from desired Git state. Automatic pruning is disabled by default as a safety mechanism. ([Argo CD][6]) So remember: AUTO SYNC ≠ SELF HEAL
- Beginner explanation: Restate **Prune — preview** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Prune — preview** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Prune — preview**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Prune — preview**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Prune — preview** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - `CreateNamespace` is a sync option, not auto-sync

- Lesson anchor: This is a subtle distinction. syncPolicy: syncOptions: does not mean: automatically synchronize app. It means: When a synchronization occurs, make sure this destination namespace exists. The sync-options specification puts these controls under spec.syncPoli...
- Beginner explanation: Restate **`CreateNamespace` is a sync option, not auto-sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`CreateNamespace` is a sync option, not auto-sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **`CreateNamespace` is a sync option, not auto-sync**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **`CreateNamespace` is a sync option, not auto-sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`CreateNamespace` is a sync option, not auto-sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Source tool auto-detection

- Lesson anchor: Our repository contains plain Kubernetes manifests. So Argo treats it as a: Directory application Later source paths may contain: Chart.yaml → Helm. Or: kustomization.yaml → Kustomize. For plain manifests, Argo can automatically detect directory content wit...
- Beginner explanation: Restate **Source tool auto-detection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Source tool auto-detection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Source tool auto-detection**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Source tool auto-detection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Source tool auto-detection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - The repo server's role in our lab

- Lesson anchor: When Argo sees: repoURL: ... targetRevision: HEAD path: guestbook the repo server effectively performs: fetch repo │ ▼ resolve revision │ ▼ open path │ ▼ generate manifests Then the application controller compares those generated manifests with live Kuberne...
- Beginner explanation: Restate **The repo server's role in our lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The repo server's role in our lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **The repo server's role in our lab**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **The repo server's role in our lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The repo server's role in our lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 62 - The controller's role in our drift lab

- Lesson anchor: When you changed replicas: kubectl │ ▼ Deployment = 3 the application controller observed: Desired Deployment = 1 Live Deployment = 3 and reported: OutOfSync When you issued: argocd app sync guestbook the controller reconciled the difference.
- Beginner explanation: Restate **The controller's role in our drift lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The controller's role in our drift lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **The controller's role in our drift lab**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **The controller's role in our drift lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The controller's role in our drift lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 63 - Argo UI exercise

- Lesson anchor: Open: https://localhost:8080 assuming Lesson 2's port-forward is running. Open: guestbook You should see a resource graph similar to: Application │ ├── Deployment │      │ │      └── ReplicaSet │             │ │             └── Pod
- Beginner explanation: Restate **Argo UI exercise** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo UI exercise** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Argo UI exercise**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Argo UI exercise**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo UI exercise** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 64 - UI is helpful — but don't become UI-dependent

- Lesson anchor: You need to know all three views: Argo UI for visual understanding. argocd for GitOps/application operations. kubectl for underlying Kubernetes diagnosis. A production engineer needs all three. ---
- Beginner explanation: Restate **UI is helpful — but don't become UI-dependent** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **UI is helpful — but don't become UI-dependent** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **UI is helpful — but don't become UI-dependent**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **UI is helpful — but don't become UI-dependent**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **UI is helpful — but don't become UI-dependent** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 65 - The three views

- Lesson anchor: Example: Argo UI: Application OutOfSync Argo CLI: exact diff kubectl: live Deployment value Together: Desired + controller view + live reality gives strong troubleshooting evidence. ---
- Beginner explanation: Restate **The three views** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The three views** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **The three views**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **The three views**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The three views** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 66 - Essential commands from this lesson

- Lesson anchor: Memorize these: argocd app list What Applications exist? argocd app get guestbook What is its state? argocd app get guestbook --refresh Refresh state. argocd app manifests guestbook What does Argo want to deploy? argocd app resources guestbook
- Beginner explanation: Restate **Essential commands from this lesson** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Essential commands from this lesson** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Essential commands from this lesson**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Essential commands from this lesson**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Essential commands from this lesson** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 67 - Kubernetes equivalent commands

- Lesson anchor: Keep these beside them: kubectl get applications -n argocd kubectl get application guestbook \ -n argocd -o yaml kubectl get all -n guestbook kubectl describe deployment \ guestbook-ui \ -n guestbook kubectl logs \ deployment/guestbook-ui \
- Beginner explanation: Restate **Kubernetes equivalent commands** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes equivalent commands** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Kubernetes equivalent commands**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Kubernetes equivalent commands**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Kubernetes equivalent commands** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 68 - `Application` CR vs deployed objects

- Lesson anchor: Never confuse: Application/guestbook with: Deployment/guestbook-ui The first is: GitOps management object The second is: application workload object Architecture: Application CR │ ▼ manages │ ▼ Deployment Service ... ---
- Beginner explanation: Restate **`Application` CR vs deployed objects** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`Application` CR vs deployed objects** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`Application` CR vs deployed objects**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`Application` CR vs deployed objects**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`Application` CR vs deployed objects** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 69 - Application isn't the business application process

- Lesson anchor: Argo's term: Application means: a logical collection of Kubernetes resources managed as a GitOps unit. It could represent: microservice monitoring stack Ingress controller cert-manager platform component not only something end users call an "application."
- Beginner explanation: Restate **Application isn't the business application process** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application isn't the business application process** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Application isn't the business application process**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Application isn't the business application process**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application isn't the business application process** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 70 - One Application can manage many Kubernetes resources

- Lesson anchor: Example later: payments-api Application │ ├── Deployment ├── Service ├── ConfigMap ├── ServiceAccount ├── HPA ├── NetworkPolicy ├── PodDisruptionBudget └── Ingress They share one: desired-state source + destination + sync lifecycle.
- Beginner explanation: Restate **One Application can manage many Kubernetes resources** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **One Application can manage many Kubernetes resources** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **One Application can manage many Kubernetes resources**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **One Application can manage many Kubernetes resources**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **One Application can manage many Kubernetes resources** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 71 - One Application should usually represent one coherent lifecycle

- Lesson anchor: Bad: Application/company-everything │ ├── Payments ├── Orders ├── Kafka ├── Prometheus ├── cert-manager └── unrelated Sandbox app Then one sync boundary contains unrelated systems. Better: coherent operational units with ApplicationSet/App-of-Apps managing...
- Beginner explanation: Restate **One Application should usually represent one coherent lifecycle** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **One Application should usually represent one coherent lifecycle** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **One Application should usually represent one coherent lifecycle**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **One Application should usually represent one coherent lifecycle**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **One Application should usually represent one coherent lifecycle** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 72 - Default Project is dangerous in production

- Lesson anchor: Today: project: default is fine. But remember its default behavior: Source repos:  Destinations:  Cluster resources:  ([Argo CD][2]) That means it is not our final enterprise security architecture. Later: Payments Project
- Beginner explanation: Restate **Default Project is dangerous in production** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Default Project is dangerous in production** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Default Project is dangerous in production**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Default Project is dangerous in production**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Default Project is dangerous in production** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 73 - Another important AppProject warning

- Lesson anchor: Argo's declarative documentation warns that a Project capable of deploying into the Argo CD control-plane namespace effectively has admin-level implications and access to such Projects should be tightly restricted. ([Argo CD][1])
- Beginner explanation: Restate **Another important AppProject warning** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Another important AppProject warning** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Another important AppProject warning**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Another important AppProject warning**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Another important AppProject warning** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 74 - Production source revision

- Lesson anchor: Today: targetRevision: HEAD is intentionally simple. Production strategies may use: environment branch release tag immutable Git SHA depending on promotion design. Never blindly conclude: HEAD is production best practice.
- Beginner explanation: Restate **Production source revision** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production source revision** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Production source revision**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Production source revision**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production source revision** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 75 - First troubleshooting scenario — `InvalidSpecError`

- Lesson anchor: If Argo says: InvalidSpecError check: repoURL targetRevision path project destination server destination namespace The Application source and destination are the central pieces Argo requires to know what and where to reconcile. ([Argo CD][1])
- Beginner explanation: Restate **First troubleshooting scenario — `InvalidSpecError`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First troubleshooting scenario — `InvalidSpecError`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **First troubleshooting scenario — `InvalidSpecError`**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **First troubleshooting scenario — `InvalidSpecError`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First troubleshooting scenario — `InvalidSpecError`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 76 - Repository path error

- Lesson anchor: Suppose: path: guestrooms instead of: path: guestbook Argo cannot generate the intended manifests. Troubleshooting path: Application │ ▼ source │ ▼ repoURL │ ▼ revision │ ▼ path Use: argocd app get guestbook and controller/repo-server logs if required.
- Beginner explanation: Restate **Repository path error** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Repository path error** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Repository path error**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Repository path error**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Repository path error** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 77 - Repository server troubleshooting

- Lesson anchor: If Argo reports manifest-generation/repository errors: kubectl logs \ deployment/argocd-repo-server \ -n argocd Think: Can repo-server reach Git? Can DNS resolve Git? Does repo exist? Do credentials work? Does revision exist?
- Beginner explanation: Restate **Repository server troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Repository server troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Repository server troubleshooting**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Repository server troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Repository server troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 78 - Application controller troubleshooting

- Lesson anchor: If desired manifests render correctly but sync/reconciliation behaves unexpectedly, inspect: kubectl logs \ statefulset/argocd-application-controller \ -n argocd depending on the installed workload representation. First verify:
- Beginner explanation: Restate **Application controller troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application controller troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Application controller troubleshooting**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Application controller troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application controller troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 79 - Sync permission failure

- Lesson anchor: Suppose Argo says something like: forbidden when creating an object. Think: Git good           ✓ Rendering good     ✓ Diff good          ✓ Kubernetes API authorization      ✕ Now investigate: Argo ServiceAccount ClusterRole
- Beginner explanation: Restate **Sync permission failure** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync permission failure** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Sync permission failure**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Sync permission failure**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync permission failure** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 80 - `ImagePullBackOff`

- Lesson anchor: Suppose: Sync: Synced Health: Degraded and: kubectl get pods -n guestbook shows: ImagePullBackOff Then GitOps may be functioning perfectly. The desired Deployment exists exactly as declared. The issue is now: runtime image retrieval.
- Beginner explanation: Restate **`ImagePullBackOff`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`ImagePullBackOff`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`ImagePullBackOff`**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`ImagePullBackOff`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`ImagePullBackOff`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 81 - This proves the G-R-D-S-H-A model

- Lesson anchor: Remember Lesson 1: G Git R Render D Diff S Sync H Health A Application Examples: wrong repo → G Helm error → R OutOfSync → D Forbidden → S CrashLoopBackOff → H HTTP 500 → A This prevents random troubleshooting. ---
- Beginner explanation: Restate **This proves the G-R-D-S-H-A model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **This proves the G-R-D-S-H-A model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **This proves the G-R-D-S-H-A model**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **This proves the G-R-D-S-H-A model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **This proves the G-R-D-S-H-A model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 82 - `Synced` is not enough

- Lesson anchor: After: argocd app sync guestbook do not only verify: Synced Also check: Healthy Then Kubernetes: kubectl get pods -n guestbook And finally application connectivity if relevant. Production rule: SYNC SUCCESS ≠ SERVICE SUCCESS.
- Beginner explanation: Restate **`Synced` is not enough** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`Synced` is not enough** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **`Synced` is not enough**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **`Synced` is not enough**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`Synced` is not enough** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 83 - Optional local application access

- Lesson anchor: Once the Service is available, inspect: kubectl get svc -n guestbook You can locally expose an appropriate Service with: kubectl port-forward \ svc/guestbook-ui \ -n guestbook \ 8081:80 if that Service exists in the example version you pulled.
- Beginner explanation: Restate **Optional local application access** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Optional local application access** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Optional local application access**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Optional local application access**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Optional local application access** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 84 - If port-forward says Service not found

- Lesson anchor: Don't guess. Run: kubectl get svc -n guestbook Use the actual Service name returned. This is a general DevOps habit: discover actual state before constructing commands. ---
- Beginner explanation: Restate **If port-forward says Service not found** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **If port-forward says Service not found** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **If port-forward says Service not found**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **If port-forward says Service not found**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **If port-forward says Service not found** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 85 - Application deletion behavior — important preview

- Lesson anchor: Deleting: Application and deleting: managed application resources are separate lifecycle questions. Argo's declarative documentation notes that a cascading resource deletion requires the Argo resources finalizer; without that finalizer, deleting the Applica...
- Beginner explanation: Restate **Application deletion behavior — important preview** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application deletion behavior — important preview** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Application deletion behavior — important preview**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Application deletion behavior — important preview**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application deletion behavior — important preview** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 86 - Why finalizers exist

- Lesson anchor: Kubernetes finalizer mental model: Delete requested │ ▼ perform required cleanup │ ▼ remove finalizer │ ▼ object actually disappears Argo can use a finalizer so application deletion coordinates deletion of managed resources.
- Beginner explanation: Restate **Why finalizers exist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why finalizers exist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Why finalizers exist**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Why finalizers exist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why finalizers exist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 87 - Do NOT delete today's guestbook yet

- Lesson anchor: Keep: Application/guestbook because Lesson 4 will use it to teach: Automated Sync Self-Heal Prune AllowEmpty Sync Options production safety We'll deliberately mutate it again. ---
- Beginner explanation: Restate **Do NOT delete today's guestbook yet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Do NOT delete today's guestbook yet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Do NOT delete today's guestbook yet**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Do NOT delete today's guestbook yet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Do NOT delete today's guestbook yet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 88 - First real production lesson

- Lesson anchor: What did we actually prove? Not simply: Argo can deploy YAML. We proved: Git is declared desired state Argo tracks that declaration Kubernetes contains live state manual changes create measurable drift Argo can show exact difference
- Beginner explanation: Restate **First real production lesson** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First real production lesson** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **First real production lesson**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **First real production lesson**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First real production lesson** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 89 - The difference from Jenkins push CD

- Lesson anchor: Old model: Jenkins │ ▼ kubectl apply │ ▼ Deployment complete Today's model: Git │ ▼ Argo Application │ ▼ continuous comparison │ ▼ Kubernetes The fundamental improvement isn't merely: different deployment tool. It's: continuous desired/live relationship.
- Beginner explanation: Restate **The difference from Jenkins push CD** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The difference from Jenkins push CD** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **The difference from Jenkins push CD**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **The difference from Jenkins push CD**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The difference from Jenkins push CD** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 90 - First GitOps invariant

- Lesson anchor: After today, remember: The cluster is not where we decide what production should be. The cluster tells us: what exists now. Git tells Argo: what should exist. Argo connects them. ---
- Beginner explanation: Restate **First GitOps invariant** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First GitOps invariant** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **First GitOps invariant**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **First GitOps invariant**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First GitOps invariant** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 91 - Second GitOps invariant

- Lesson anchor: Manual kubectl changes are not automatically the new truth. If: Git = 1 kubectl = 3 we don't say: "Production is now officially 3." We say: "Live state has drifted from declared state." If three is actually desired, then the persistent GitOps fix is:
- Beginner explanation: Restate **Second GitOps invariant** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Second GitOps invariant** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Second GitOps invariant**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Second GitOps invariant**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Second GitOps invariant** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 92 - Third GitOps invariant

- Lesson anchor: Never fight the reconciler without understanding its policy. Today Argo did not self-heal automatically. Next lesson it will. Soon this: kubectl scale ... may appear to "work" for a few seconds and then be reverted. That is not Argo malfunctioning.
- Beginner explanation: Restate **Third GitOps invariant** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Third GitOps invariant** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Third GitOps invariant**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Third GitOps invariant**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Third GitOps invariant** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 93 - Application CR mental formula

- Lesson anchor: Memorize: APPLICATION = PROJECT + SOURCE (repo + revision + path) + DESTINATION (cluster + namespace) + SYNC POLICY That's the foundation. ---
- Beginner explanation: Restate **Application CR mental formula** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application CR mental formula** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Application CR mental formula**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Application CR mental formula**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application CR mental formula** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 94 - First Application interview question

- Lesson anchor: Strong answer: An Argo CD Application is a Kubernetes custom resource that links a desired-state source—typically a Git repository, revision, and path—to a destination Kubernetes cluster and namespace. Argo's Application Controller compares the generated de...
- Beginner explanation: Restate **First Application interview question** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **First Application interview question** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **First Application interview question**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **First Application interview question**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **First Application interview question** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 95 - Interview — `metadata.namespace` vs `destination.namespace`

- Lesson anchor: metadata.namespace = where Application CR exists destination.namespace = where namespaced workload resources should deploy This is a very common beginner confusion. ---
- Beginner explanation: Restate **Interview — `metadata.namespace` vs `destination.namespace`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — `metadata.namespace` vs `destination.namespace`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — `metadata.namespace` vs `destination.namespace`**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — `metadata.namespace` vs `destination.namespace`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — `metadata.namespace` vs `destination.namespace`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 96 - Interview — `repoURL`, `targetRevision`, `path`

- Lesson anchor: repoURL = which repository? targetRevision = which branch/tag/commit? path = which directory/config within it? Together: desired-state location. ---
- Beginner explanation: Restate **Interview — `repoURL`, `targetRevision`, `path`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — `repoURL`, `targetRevision`, `path`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — `repoURL`, `targetRevision`, `path`**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — `repoURL`, `targetRevision`, `path`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — `repoURL`, `targetRevision`, `path`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 97 - Interview — What is the destination server for in-cluster deployment?

- Lesson anchor: https://kubernetes.default.svc is the standard in-cluster Kubernetes API destination used when Argo deploys to the cluster in which it is running. ([Argo CD][4]) ---
- Beginner explanation: Restate **Interview — What is the destination server for in-cluster deployment?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What is the destination server for in-cluster deployment?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — What is the destination server for in-cluster deployment?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — What is the destination server for in-cluster deployment?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What is the destination server for in-cluster deployment?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 98 - Interview — What is `CreateNamespace=true`?

- Lesson anchor: It is a synchronization option that tells Argo CD to ensure the configured destination namespace exists when syncing the Application. ([Argo CD][5]) It does not mean: enable auto-sync. ---
- Beginner explanation: Restate **Interview — What is `CreateNamespace=true`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What is `CreateNamespace=true`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — What is `CreateNamespace=true`?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — What is `CreateNamespace=true`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What is `CreateNamespace=true`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 99 - Interview — What does `OutOfSync` mean?

- Lesson anchor: Desired manifests != live Kubernetes resources It does not automatically mean: application outage. A manually scaled but fully functioning Deployment may be: OutOfSync + Healthy ---
- Beginner explanation: Restate **Interview — What does `OutOfSync` mean?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What does `OutOfSync` mean?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — What does `OutOfSync` mean?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — What does `OutOfSync` mean?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What does `OutOfSync` mean?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 100 - Interview — How do you determine why an app is OutOfSync?

- Lesson anchor: Use: argocd app diff <APP to compare target/desired and live states. ([Argo CD][10]) Then verify live Kubernetes with: kubectl get ... ---
- Beginner explanation: Restate **Interview — How do you determine why an app is OutOfSync?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — How do you determine why an app is OutOfSync?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — How do you determine why an app is OutOfSync?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — How do you determine why an app is OutOfSync?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — How do you determine why an app is OutOfSync?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 101 - Interview — manual sync vs automated sync

- Lesson anchor: MANUAL Argo detects drift ↓ operator triggers sync AUTOMATED Argo detects applicable drift ↓ controller triggers synchronization according to policy Automated synchronization is explicitly configured on the Application. ([Argo CD][6])
- Beginner explanation: Restate **Interview — manual sync vs automated sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — manual sync vs automated sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — manual sync vs automated sync**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — manual sync vs automated sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — manual sync vs automated sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 102 - Interview trap — `default` AppProject is safe production isolation

- Lesson anchor: Wrong. The default project is initially permissive across source repositories, destinations, and resource kinds. Argo recommends creating dedicated constrained Projects for stronger isolation. ([Argo CD][2]) ---
- Beginner explanation: Restate **Interview trap — `default` AppProject is safe production isolation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — `default` AppProject is safe production isolation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview trap — `default` AppProject is safe production isolation**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview trap — `default` AppProject is safe production isolation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — `default` AppProject is safe production isolation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 103 - Interview trap — destination namespace is where Application CR lives

- Lesson anchor: Wrong. Application CR → argocd Managed resources → guestbook Different namespaces. ---
- Beginner explanation: Restate **Interview trap — destination namespace is where Application CR lives** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — destination namespace is where Application CR lives** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview trap — destination namespace is where Application CR lives**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview trap — destination namespace is where Application CR lives**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — destination namespace is where Application CR lives** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 104 - Interview trap — OutOfSync means unhealthy

- Lesson anchor: Wrong. Possible: OutOfSync + Healthy Example: Git replicas = 1 Live replicas = 3 all Pods healthy. Configuration drift exists even though the service works. ---
- Beginner explanation: Restate **Interview trap — OutOfSync means unhealthy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — OutOfSync means unhealthy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview trap — OutOfSync means unhealthy**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview trap — OutOfSync means unhealthy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — OutOfSync means unhealthy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 105 - Interview trap — Synced means app is healthy

- Lesson anchor: Wrong. Possible: Synced + Degraded Example: Git image reference matches Deployment but Pods: ImagePullBackOff. Configuration matches. Runtime fails. ---
- Beginner explanation: Restate **Interview trap — Synced means app is healthy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — Synced means app is healthy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview trap — Synced means app is healthy**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview trap — Synced means app is healthy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — Synced means app is healthy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 106 - Interview trap — `syncPolicy` means auto-sync

- Lesson anchor: Wrong. Our Application contains: syncPolicy: syncOptions: but still requires manual synchronization because no automated policy is enabled. ---
- Beginner explanation: Restate **Interview trap — `syncPolicy` means auto-sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — `syncPolicy` means auto-sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview trap — `syncPolicy` means auto-sync**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview trap — `syncPolicy` means auto-sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — `syncPolicy` means auto-sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 107 - Interview trap — manual kubectl change modifies Git

- Lesson anchor: Wrong. Flow is not: kubectl → Argo → Git Argo CD normally reconciles: Git → cluster It does not automatically commit your live manual changes back into Git. ---
- Beginner explanation: Restate **Interview trap — manual kubectl change modifies Git** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview trap — manual kubectl change modifies Git** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview trap — manual kubectl change modifies Git**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview trap — manual kubectl change modifies Git**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview trap — manual kubectl change modifies Git** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 108 - Never-forget commands

- Lesson anchor: CREATE kubectl apply -f guestbook-application.yaml LIST argocd app list INSPECT argocd app get guestbook REFRESH argocd app get guestbook --refresh MANIFESTS argocd app manifests guestbook RESOURCES argocd app resources guestbook
- Beginner explanation: Restate **Never-forget commands** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget commands** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Never-forget commands**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Never-forget commands**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget commands** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 109 - Never-forget field map

- Lesson anchor: apiVersion = which API? kind = Application metadata.name = Argo app name metadata.namespace = where Argo Application CR lives project = Argo governance/security boundary repoURL = where desired state comes from targetRevision
- Beginner explanation: Restate **Never-forget field map** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget field map** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Never-forget field map**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Never-forget field map**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget field map** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 110 - Complete Lesson 3 packet/control flow

- Lesson anchor: APPLICATION CR │ ▼ Application Controller │ ┌─────────┴─────────┐ │                   │ ▼                   ▼ Repo Server        Kubernetes API │                   │ ▼                   ▼ Git              Live Resources │                   │
- Beginner explanation: Restate **Complete Lesson 3 packet/control flow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Complete Lesson 3 packet/control flow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Complete Lesson 3 packet/control flow**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Complete Lesson 3 packet/control flow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Complete Lesson 3 packet/control flow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 111 - Lesson 3 practical checkpoint

- Lesson anchor: You should now be able to reproduce this from memory: kubectl apply -f guestbook-application.yaml argocd app get guestbook argocd app sync guestbook kubectl scale deployment \ guestbook-ui \ --replicas=3 \ -n guestbook argocd app get guestbook --refresh
- Beginner explanation: Restate **Lesson 3 practical checkpoint** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lesson 3 practical checkpoint** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Lesson 3 practical checkpoint**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Lesson 3 practical checkpoint**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lesson 3 practical checkpoint** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Prerequisites x capacity

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Prerequisites** while a change involving **Read the YAML as English** places **capacity** at risk.
- Plain-language question: What problem does **Prerequisites** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before continuing, verify: kubectl get pods -n argocd and: argocd version You want Argo CD's control plane available and your CLI authenticated. Also check: argocd app list It may currently show no applications. That's fine.
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
- Interview prompt: Defend **Prerequisites** against an alternative while protecting capacity under this scenario.
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

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/ "Declarative Setup - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/?utm_source=chatgpt.com "Projects - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/directory/?utm_source=chatgpt.com "Directory - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/getting_started/ "Getting Started - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/latest/user-guide/application-specification/ "Application Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ "Automated Sync Policy - Argo CD - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app/?utm_source=chatgpt.com "argocd app Command Reference - Argo CD - Read the Docs"
[8]: https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_app_get/?utm_source=chatgpt.com "argocd app get Command Reference - Argo CD - Read the Docs"
[9]: https://github.com/argoproj/argocd-example-apps/blob/master/guestbook/guestbook-ui-deployment.yaml?utm_source=chatgpt.com "guestbook-ui-deployment.yaml - argocd-example-apps"
[10]: https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_app_diff/?utm_source=chatgpt.com "argocd app diff Command Reference - Argo CD - Read the Docs"
[11]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/?utm_source=chatgpt.com "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
[12]: https://argo-cd.readthedocs.io/en/latest/user-guide/multiple_sources/?utm_source=chatgpt.com "Multiple Sources for an Application - Argo CD - Read the Docs"
