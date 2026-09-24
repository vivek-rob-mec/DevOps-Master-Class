# Module 14 — GitOps with Argo CD

## Lesson 1: GitOps Mental Model, Reconciliation, Drift & Argo CD Architecture

We now move from:

```text
Module 13
AWS Production Architecture
        │
        ▼
accounts
networks
security
governance
infrastructure
```

into:

```text
Module 14
GitOps with Argo CD
        │
        ▼
How do we safely deliver
applications and Kubernetes configuration
into those production environments?
```

This module is going to connect directly with everything we already know about:

```text
Git
CI/CD
Docker
Kubernetes
Terraform
AWS
IAM
DevSecOps
Observability
SRE
```

Argo CD is officially described as a **declarative GitOps continuous-delivery tool for Kubernetes**. Its central model is that application configuration is declarative and version-controlled, while Argo CD compares the desired state with the live Kubernetes state and can reconcile differences. ([Argo CD][1])

---

# Module 14 Roadmap

We will build this module progressively:

```text
Lesson 1
GitOps Mental Model
Desired State
Reconciliation
Drift
Push vs Pull                     ← NOW


Lesson 2
Argo CD Installation
Components
Namespace
CLI
UI
First Login


Lesson 3
Argo CD Application CRD
Source
Destination
Project
Sync
Health


Lesson 4
Manual Sync
Auto Sync
Prune
Self-Heal
Sync Options


Lesson 5
Git Repository Design
Application Repo
Config Repo
Environment Promotion


Lesson 6
Helm + Argo CD
Values
Chart versioning
Production patterns


Lesson 7
Kustomize + Argo CD
Base
Overlays
Dev/QA/Prod


Lesson 8
AppProject
RBAC
SSO
Multi-team isolation


Lesson 9
ApplicationSet
Multi-cluster
Multi-environment generation


Lesson 10
App-of-Apps
Cluster Bootstrapping
Platform GitOps


Lesson 11
Secrets
External Secrets
Sealed Secrets
Vault
AWS Secrets Manager
GitOps security


Lesson 12
Sync Waves
Hooks
Ordering
Database migrations


Lesson 13
Argo Rollouts
Blue/Green
Canary
Progressive Delivery


Lesson 14
Multi-cluster GitOps
EKS production architecture


Lesson 15
Argo CD HA
Backup
DR
Scaling
Security hardening


Lesson 16
Observability
Metrics
Notifications
Troubleshooting


Lesson 17
CI + Argo CD
Jenkins/GitHub/GitLab
Image promotion


Lesson 18
Production GitOps Capstone


Lesson 19
Incident scenarios
Interview mastery
Never-forget revision
```

We will not rush installation.

First you need to understand **why GitOps exists**.

---

# 14.1 Start with the problem

Imagine our application deployment today:

```text
Developer
   │
   ▼
Git Push
   │
   ▼
Jenkins
   │
   ├── Test
   ├── Build Docker Image
   ├── Push ECR
   │
   ▼
kubectl apply
   │
   ▼
Kubernetes
```

Something like:

```bash
kubectl apply -f deployment.yaml
```

or:

```bash
helm upgrade \
  todo-app ./chart \
  --namespace production
```

This works.

But there's a hidden architectural problem.

The CI server needs:

```text
Kubernetes API access
+
deployment credentials
+
network connectivity
+
production authorization
```

Therefore:

```text
Jenkins compromise
       │
       ▼
potential production cluster access
```

And there is another problem.

Suppose somebody runs:

```bash
kubectl edit deployment todo-app
```

and changes:

```yaml
replicas: 3
```

to:

```yaml
replicas: 20
```

Git still says:

```text
replicas = 3
```

Cluster says:

```text
replicas = 20
```

Which one is correct?

---

# 14.2 This is the GitOps problem

We need one authoritative desired state.

For example:

```text
Git Repository

deployment.yaml
│
├── image: todo:v42
├── replicas: 3
├── CPU: 500m
└── memory: 512Mi
```

Git says:

> **This is what production should look like.**

The Kubernetes cluster says:

> **This is what production currently looks like.**

GitOps continuously compares the two.

```text
       DESIRED STATE
            Git
             │
             ▼
        ┌──────────┐
        │ Compare  │
        └────┬─────┘
             │
             ▼
         LIVE STATE
         Kubernetes
```

If they differ:

```text
Desired != Live
```

we have:

# **DRIFT**

---

# 14.3 Desired State

You've already seen desired-state systems.

Terraform:

```hcl
resource "aws_instance" "web" {
  instance_type = "t3.micro"
}
```

means:

```text
I want an EC2 instance
with this configuration.
```

Kubernetes:

```yaml
spec:
  replicas: 3
```

means:

```text
I want three replicas.
```

GitOps adds:

```text
Store that desired declaration
in a version-controlled,
auditable source.
```

OpenGitOps defines a GitOps-managed system as declarative, versioned and immutable, automatically pulled by software agents, and continuously reconciled. ([OpenGitOps][2])

---

# 14.4 Desired state vs actual state

Let's make this extremely clear.

Git:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-api
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: company/todo-api:v12
```

That's:

```text
DESIRED STATE
```

Kubernetes currently:

```text
Replicas:

desired = 3
running = 3

Image:
v12
```

That's:

```text
LIVE / ACTUAL STATE
```

Therefore:

```text
DESIRED
=
LIVE
```

Application is:

```text
Synced
```

---

# 14.5 Now introduce drift

Someone executes:

```bash
kubectl scale deployment todo-api \
  --replicas=5
```

Cluster:

```text
replicas = 5
```

Git:

```text
replicas = 3
```

Now:

```text
Git              Kubernetes

replicas 3       replicas 5
    │                │
    └───── != ───────┘
```

This difference is:

# DRIFT

---

# 14.6 Drift can happen for many reasons

Not only humans.

```text
Manual kubectl change

Hotfix

Admission controller

Kubernetes controller

HPA

Operator

Helm changes

Misconfigured automation

API defaulting

Another deployment system
```

can change live Kubernetes state.

This becomes important later because not **every** difference should necessarily be treated as harmful drift.

---

# 14.7 Reconciliation

Now we reach the most important word in this entire module.

# **RECONCILIATION**

Think:

```text
Desired State
     │
     ▼
Compare
     │
     ▼
Actual State
     │
     ▼
Difference?
     │
     ├── No
     │    ↓
     │   Do nothing
     │
     └── Yes
          ↓
        Correct
```

This loop keeps repeating.

---

# 14.8 Controller mental model

You've already learned this from Kubernetes.

Suppose:

```yaml
replicas: 3
```

but:

```text
Pods running = 2
```

Deployment controller says:

```text
Desired = 3

Actual = 2

Difference = 1

Create one pod.
```

Then:

```text
Desired = 3

Actual = 3

Done.
```

But not permanently done.

The controller continues watching.

---

# 14.9 Why continuously?

Suppose ten minutes later one pod dies.

```text
Actual = 2
```

Again:

```text
Desired 3
Actual 2
       │
       ▼
controller
       │
       ▼
create another
```

This is the fundamental Kubernetes operator/controller pattern:

# **Observe → Compare → Reconcile**

GitOps extends the same thinking one level higher.

---

# 14.10 Kubernetes controller vs GitOps controller

Kubernetes:

```text
Kubernetes API desired state

       ↓

Kubernetes controllers

       ↓

cluster reality
```

GitOps:

```text
Git desired state

       ↓

Argo CD

       ↓

Kubernetes API desired state

       ↓

Kubernetes controllers

       ↓

Pods / Services / workloads
```

Very important.

Argo CD doesn't replace:

```text
Deployment controller

StatefulSet controller

Scheduler

kubelet
```

It sits **above** them.

---

# 14.11 Full reconciliation hierarchy

Example:

Git says:

```yaml
replicas: 3
```

Flow:

```text
GIT

replicas = 3
    │
    ▼
ARGO CD

"Does Kubernetes object say 3?"
    │
    ▼
KUBERNETES API

replicas = 3
    │
    ▼
DEPLOYMENT CONTROLLER

"Are 3 replicas actually running?"
    │
    ▼
REPLICASET
    │
    ▼
PODS
```

Two control loops exist.

```text
Git → Kubernetes desired state

Kubernetes desired state → runtime
```

That distinction is extremely important.

---

# 14.12 GitOps is not simply "put YAML in Git"

Suppose you have:

```text
deployment.yaml
```

stored in Git.

Then every Friday Vivek manually runs:

```bash
git pull

kubectl apply -f deployment.yaml
```

Is Git involved?

Yes.

Is this mature GitOps?

Not really.

One of the core OpenGitOps principles is that software agents **automatically pull** desired-state declarations and continuously reconcile them. ([OpenGitOps][2])

The crucial part is:

```text
AUTOMATED RECONCILIATION
```

---

# 14.13 Four GitOps principles

The OpenGitOps project summarizes GitOps around four principles. ([OpenGitOps][2])

## 1. Declarative

Describe:

```text
WHAT you want
```

rather than a sequence of imperative steps.

Example:

```yaml
replicas: 3
```

instead of:

```bash
create pod
create another pod
create third pod
```

---

# 14.14 Principle 2 — Versioned and immutable

Desired state has history.

```text
Git

commit a1
todo:v41

commit b2
todo:v42

commit c3
todo:v43
```

You can answer:

```text
Who changed production?

When?

Why?

Which pull request?

What exactly changed?
```

This is a huge operational advantage.

---

# 14.15 Principle 3 — Pulled automatically

This one changes CI/CD architecture.

Traditional:

```text
Jenkins
   │
   │ PUSH deployment
   ▼
Kubernetes API
```

GitOps:

```text
Jenkins
   │
   ▼
Git
   ▲
   │ PULL
Argo CD
   │
   ▼
Kubernetes
```

The deployment agent lives near/in the target environment and **pulls** desired configuration.

OpenGitOps explicitly identifies automatic pulling as a GitOps principle. ([OpenGitOps][2])

---

# 14.16 Principle 4 — Continuously reconciled

Not:

```text
deploy once
and forget.
```

Instead:

```text
Desired
   │
   ▼
Actual
   │
   ▼
compare
   │
   ▼
repeat
```

OpenGitOps defines continuously reconciled systems as software agents continuously observing actual state and attempting to apply the desired state. ([OpenGitOps][2])

---

# 14.17 GitOps formula

Never forget:

```text
GITOPS

=
DECLARATIVE

+

VERSIONED

+

PULLED AUTOMATICALLY

+

CONTINUOUSLY RECONCILED
```

Not:

```text
GitOps = Argo CD
```

Argo CD is an implementation/tool for applying GitOps practices to Kubernetes.

---

# 14.18 Git is the control interface

Traditional operations:

```bash
kubectl edit

kubectl apply

helm upgrade
```

GitOps production model:

```text
Edit Git
   │
   ▼
Pull Request
   │
   ▼
Review
   │
   ▼
Merge
   │
   ▼
Argo CD sees desired-state change
   │
   ▼
Kubernetes
```

Meaning:

> Production change begins with a Git change.

---

# 14.19 Git becomes an audit trail

Example:

```diff
- image: registry/todo-api:v41
+ image: registry/todo-api:v42
```

Pull request:

```text
PR #182

Upgrade todo-api
v41 → v42

Approved by:
SRE
Platform
```

Later an incident happens.

You can trace:

```text
incident
   │
   ▼
running version
   │
   ▼
Git commit
   │
   ▼
PR
   │
   ▼
developer/change reason
```

That's much cleaner than:

```text
"Someone ran kubectl around 2 AM."
```

---

# 14.20 GitOps does NOT mean Git stores container images

Git should hold something like:

```yaml
image:
  repository: 123456789.dkr.ecr.ap-south-1.amazonaws.com/todo-api
  tag: "a61c92f"
```

Container registry stores:

```text
actual image layers
```

Git stores:

```text
desired image reference.
```

Architecture:

```text
SOURCE REPO
    │
    ▼
CI
    │
    ├── Build
    │
    └── Push
         │
         ▼
        ECR

CI / promotion process
         │
         ▼
 CONFIG REPO
 image: todo:a61c92f
         │
         ▼
       Argo CD
```

---

# 14.21 CI and CD become separated

This is a core GitOps architecture.

## CI responsibility

```text
Code
 │
 ▼
Build
 │
 ▼
Test
 │
 ▼
Security Scan
 │
 ▼
Create Artifact
 │
 ▼
Push image
```

Output:

```text
todo-api:a61c92f
```

---

# 14.22 CD responsibility

```text
Git config says:

todo-api:a61c92f
        │
        ▼
Argo CD
        │
        ▼
Kubernetes
```

So:

```text
CI
=
produce artifact


GitOps CD
=
declare + reconcile
artifact deployment
```

This separation is one of the biggest architectural changes compared with a Jenkins pipeline that directly runs `kubectl`.

---

# 14.23 Traditional push CD

Example Jenkins:

```groovy
stage('Deploy') {
    sh '''
      aws eks update-kubeconfig ...
      kubectl apply -f k8s/
    '''
}
```

Jenkins requires:

```text
AWS credentials

EKS access

Kubernetes RBAC

network path to Kubernetes API
```

The pipeline pushes desired state.

---

# 14.24 GitOps pull CD

With Argo CD:

```text
Jenkins

build image
   │
   ▼
ECR

update Git config
   │
   ▼
Git repository
   ▲
   │
Argo CD watches/pulls
   │
   ▼
EKS
```

Argo CD's automated-sync documentation explicitly notes that a CI pipeline does not need direct access to the Argo CD API server to deploy; the pipeline can commit the desired manifest change and Argo CD handles synchronization. ([Argo CD][3])

---

# 14.25 Production security benefit

Traditional:

```text
CI SYSTEM
    │
    ▼
production Kubernetes credential
```

GitOps:

```text
CI SYSTEM
    │
    ▼
Git permission

Argo CD
    │
    ▼
Kubernetes permission
```

Now you can separate:

```text
BUILD AUTHORITY
```

from:

```text
DEPLOYMENT AUTHORITY.
```

That is a strong security boundary.

---

# 14.26 But Git compromise now matters enormously

Do not conclude:

```text
GitOps = automatically secure.
```

If an attacker can merge:

```yaml
image: attacker/malware:latest
```

into your production config repository and Argo CD automatically reconciles it:

```text
Git compromise
     │
     ▼
desired state changed
     │
     ▼
Argo CD
     │
     ▼
production changed
```

Therefore GitOps requires strong:

```text
branch protection

CODEOWNERS

PR reviews

MFA

repository permissions

signed/provenance-aware workflows where required
```

Git becomes part of the production control plane.

---

# 14.27 Source code repo vs deployment config repo

A mature architecture often separates:

```text
APP SOURCE REPOSITORY
```

from:

```text
GITOPS CONFIGURATION REPOSITORY
```

Argo CD's own best-practice guidance recommends separate Git repositories for application source and deployment configuration in many cases, citing separation of access, cleaner audit history, independent configuration changes, and avoidance of CI trigger loops. ([Argo CD][4])

---

# 14.28 Example repository model

Application repository:

```text
todo-api/
│
├── src/
├── tests/
├── Dockerfile
├── package.json
└── Jenkinsfile
```

Deployment repository:

```text
gitops-config/
│
└── todo-api/
    ├── base/
    │   ├── deployment.yaml
    │   └── service.yaml
    │
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

Now ownership can differ.

---

# 14.29 Source repo ownership

Developers may have permission:

```text
todo-api source
      │
      ▼
merge code
```

But production config might require:

```text
Platform/SRE approval.
```

Architecture:

```text
Developer
  │
  ▼
App Repo
  │
  ▼
CI
  │
  ▼
Image
  │
  ▼
Config Repo PR
  │
  ▼
SRE Approval
  │
  ▼
Argo CD
```

This is separation of duties.

---

# 14.30 A complete GitOps release

Developer changes:

```javascript
console.log("new feature");
```

Commit:

```text
f613abc
```

CI:

```text
npm test                 ✓
security scan            ✓
docker build             ✓
push ECR                 ✓
```

Artifact:

```text
todo-api:f613abc
```

Then GitOps configuration changes:

```diff
- image: todo-api:872ce12
+ image: todo-api:f613abc
```

Merge.

Argo CD notices:

```text
Desired Git
=
f613abc

Live cluster
=
872ce12
```

Status:

```text
OUT OF SYNC
```

Argo applies the desired state.

Kubernetes performs rollout.

Eventually:

```text
Desired
=
Live
```

Status:

```text
SYNCED
```

---

# 14.31 Synced does not necessarily mean healthy

This distinction is essential.

Suppose Git specifies:

```yaml
image: todo-api:v42
```

Kubernetes contains:

```text
Deployment image = todo-api:v42
```

Therefore configuration may be:

```text
Synced
```

But containers crash:

```text
CrashLoopBackOff
```

Then operational health is bad.

Argo CD provides resource health assessment for standard Kubernetes resources independently of desired/live-state comparison. ([Argo CD][5])

---

# 14.32 Sync vs Health

Permanent mental model:

```text
SYNC STATUS
=
Does Kubernetes match Git?


HEALTH STATUS
=
Is Kubernetes resource
operationally healthy?
```

Possible:

```text
Synced + Healthy
```

Excellent.

Possible:

```text
Synced + Degraded
```

Git matches cluster, but application is broken.

Possible:

```text
OutOfSync + Healthy
```

Application currently works, but live state doesn't match declared desired state.

This distinction will become one of your most-used troubleshooting tools.

---

# 14.33 Example: Synced but unhealthy

Git:

```yaml
image: todo:v99
```

Cluster:

```text
Deployment uses todo:v99
```

Therefore:

```text
SYNCED
```

But:

```text
ImagePullBackOff
```

because image doesn't exist.

Therefore:

```text
NOT HEALTHY.
```

GitOps cannot make a bad image good.

---

# 14.34 Example: OutOfSync but healthy

Git:

```yaml
replicas: 3
```

Cluster manually changed:

```text
replicas: 4
```

All four pods work.

Therefore:

```text
Operationally healthy
```

but:

```text
Git != Cluster

OUT OF SYNC
```

---

# 14.35 Argo CD's basic architecture

At the core are three important components:

```text
                   USERS / CI / API
                          │
                          ▼
                    ARGO CD API
                       SERVER
                          │
             ┌────────────┴─────────────┐
             ▼                          ▼

       REPOSITORY SERVER         APPLICATION CONTROLLER
             │                          │
             ▼                          ▼
            Git                    Kubernetes API
```

The official Argo CD architecture describes the **repo server** as the internal service responsible for obtaining/caching repositories and generating Kubernetes manifests, while the **application controller** continuously compares live application state with desired target state and detects `OutOfSync` applications. ([Argo CD][6])

---

# 14.36 Repository Server

The repo server answers:

> **What does Git say this application should look like?**

Inputs can include:

```text
Repository URL

Revision

Path

Helm configuration

Kustomize configuration
```

The official architecture says the repository server generates and returns Kubernetes manifests based on repository URL, revision, application path, and tool-specific configuration. ([Argo CD][6])

Concept:

```text
Git Repository
      │
      ▼
Repo Server
      │
      ▼
Rendered Kubernetes Manifests
```

---

# 14.37 Why "rendered manifests"?

Suppose Git contains plain YAML:

```text
deployment.yaml
service.yaml
```

Easy.

But Git could contain:

```text
Helm Chart
```

or:

```text
Kustomize overlays
```

Argo CD must transform those into:

```yaml
apiVersion: apps/v1
kind: Deployment
...
```

before comparing them with Kubernetes.

---

# 14.38 Application Controller

This is the heart of Argo CD.

Its job:

```text
Get desired state
      │
      ▼
Get live state
      │
      ▼
Compare
      │
      ▼
OutOfSync?
      │
      ▼
optionally reconcile
```

The official architecture describes it as a Kubernetes controller that continuously monitors running applications, compares live state against the desired target state, detects `OutOfSync`, and can take corrective action. ([Argo CD][6])

Permanent memory:

```text
ARGO CD APPLICATION CONTROLLER
=
GitOps reconciliation engine
```

---

# 14.39 API Server

This handles user-facing/API interactions such as:

```text
UI

CLI

API

authentication

application operations
```

But this is important:

> The API server is not the fundamental thing making GitOps work.

The reconciliation loop is.

You could remove the pretty UI mentally and still understand GitOps:

```text
Git
 ↓
Controller
 ↓
Kubernetes
```

---

# 14.40 Argo CD Application

Argo CD introduces a Kubernetes custom resource:

```text
kind: Application
```

Conceptually, the Application answers four questions:

```text
WHAT?
Which Git repo?


WHICH VERSION?
Branch/tag/commit?


WHERE IN REPO?
Path/chart?


WHERE DEPLOY?
Cluster + namespace?
```

Argo CD applications themselves can be defined declaratively using Kubernetes manifests. ([Argo CD][7])

---

# 14.41 Simplified Application

Later we'll study every field, but look at the mental model:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: todo-api
  namespace: argocd

spec:
  source:
    repoURL: https://git.example.com/platform/gitops.git
    targetRevision: main
    path: apps/todo/prod

  destination:
    server: https://kubernetes.default.svc
    namespace: todo-prod
```

Read it as English:

```text
Argo CD,

for application "todo-api",

read desired state from:

gitops.git
main
apps/todo/prod

and reconcile it into:

this Kubernetes cluster
todo-prod namespace.
```

That's essentially an Argo CD Application.

---

# 14.42 Source and Destination

Permanent shortcut:

```text
SOURCE
=
where desired state comes from


DESTINATION
=
where desired state goes
```

Therefore:

```text
SOURCE
Git


DESTINATION
Kubernetes cluster + namespace
```

---

# 14.43 `targetRevision`

This identifies what revision Argo CD tracks.

Conceptually:

```text
main

release-v2

v1.4.2

commit SHA
```

Argo CD can track branches, tags, or be pinned to particular manifest revisions. ([Argo CD][1])

But production implications differ significantly.

---

# 14.44 Tracking `main`

Example:

```yaml
targetRevision: main
```

Means:

```text
new commit merged to main
        │
        ▼
desired state changes
        │
        ▼
Argo sees change
```

Good for:

```text
continuous deployment
```

but Git branch protection becomes extremely important.

---

# 14.45 Pinning commits

Example concept:

```yaml
targetRevision: a31f92e
```

Now desired state is tied to an immutable commit.

Advantages:

```text
deterministic

auditable

reproducible
```

Argo CD's best-practice documentation also recommends pinning remote manifest dependencies to immutable tags/commit SHAs where appropriate to prevent their meaning changing unexpectedly. ([Argo CD][4])

---

# 14.46 Why immutable references matter

Imagine:

```text
Git commit A
```

contains:

```yaml
resources:
  - some-upstream-repo//base
```

but the remote reference points to:

```text
HEAD
```

Tomorrow upstream changes.

Your own Git commit did not change.

But rendered manifests changed.

That violates the mental expectation:

```text
same commit
=
same desired state.
```

Argo CD explicitly warns about this and recommends immutable references such as commit SHAs/tags for remote bases. ([Argo CD][4])

---

# 14.47 Manual synchronization

Git changes:

```text
v41 → v42
```

Argo detects:

```text
OUT OF SYNC
```

But with manual sync policy it doesn't immediately deploy.

Human/operator runs:

```text
SYNC
```

Concept:

```text
Git change
   │
   ▼
OutOfSync
   │
   ▼
Approval
   │
   ▼
Sync
```

This is useful while learning and can also be used intentionally in controlled environments.

---

# 14.48 Automated synchronization

With auto-sync:

```text
Git changes
    │
    ▼
Argo detects difference
    │
    ▼
reconciliation runs
```

Argo CD supports automated sync specifically for this desired-vs-live reconciliation model. ([Argo CD][3])

This gives you actual continuous delivery.

---

# 14.49 Auto-sync does not automatically mean auto-delete everything

Important safety detail.

Suppose Git contains:

```text
Deployment
Service
ConfigMap
```

Then someone removes:

```text
Service
```

from Git.

Does Argo automatically delete the live Service just because automatic sync is enabled?

By default, automatic pruning is **not** enabled. It has to be explicitly configured. ([Argo CD][3])

So:

```text
AUTO SYNC
≠
AUTO PRUNE
```

We'll study this deeply later.

---

# 14.50 Prune

Mental model:

```text
Resource exists
in Kubernetes

but no longer exists
in Git
```

If prune enabled:

```text
Git says:
Resource should not exist.

Argo:
delete it.
```

Permanent shortcut:

```text
PRUNE
=
delete resources
that disappeared from desired state.
```

---

# 14.51 Self-Heal

Suppose Git remains:

```text
replicas: 3
```

Someone manually changes the cluster:

```text
replicas: 5
```

No new Git commit occurred.

Self-heal means Argo can correct the live-state deviation and restore what Git declares. Argo CD exposes this separately under automated sync policy. ([Argo CD][3])

Concept:

```text
Git = 3

Cluster = 5
    │
    ▼
drift
    │
    ▼
selfHeal
    │
    ▼
Cluster = 3
```

---

# 14.52 Auto-sync vs self-heal

This distinction is subtle and important.

### Auto-sync

```text
Git changed
     │
     ▼
deploy new desired state
```

### Self-heal

```text
Git did NOT change

cluster changed
     │
     ▼
restore Git state
```

Later we'll examine the exact automated-sync semantics in detail.

---

# 14.53 Why self-healing is powerful

Production incident:

```text
Engineer:

kubectl edit deployment
replicas: 1
```

Argo notices:

```text
Git = 5
Live = 1
```

and can restore:

```text
Live = 5
```

This reduces configuration drift.

---

# 14.54 Why self-healing can surprise engineers

Imagine emergency incident response:

```bash
kubectl scale deployment \
  payment-api \
  --replicas=0
```

Engineer expects:

```text
service stopped.
```

But Git still says:

```text
replicas: 5
```

Argo self-heal says:

```text
"No. Desired state is 5."
```

and restores them.

Engineer:

```text
WHY ARE THE PODS COMING BACK?!
```

Because GitOps did exactly what you told it to do.

---

# 14.55 GitOps changes incident response

In GitOps systems, production operators must think:

```text
Don't fight the reconciler.
```

If you need production to become:

```text
replicas = 0
```

the safest persistent change is usually:

```text
change desired state
```

rather than repeatedly editing live state.

---

# 14.56 A GitOps controller is like a thermostat

Great never-forget analogy.

You set thermostat:

```text
Desired = 22°C
```

Room becomes:

```text
Actual = 25°C
```

Thermostat:

```text
25 != 22
```

activates cooling.

Eventually:

```text
22 = 22
```

Now imagine someone manually heats the room.

Thermostat doesn't say:

> “A human changed it, so I surrender.”

It reconciles again.

Argo CD behaves conceptually the same way:

```text
Git = thermostat setting

Cluster = room temperature

Argo CD = controller
```

---

# 14.57 GitOps is not a one-time pipeline

Traditional pipeline often thinks:

```text
START
 ↓
BUILD
 ↓
TEST
 ↓
DEPLOY
 ↓
DONE
```

GitOps thinks:

```text
Desired State
     │
     ▼
Reconcile
     │
     ▼
Observe
     │
     ▼
Reconcile
     │
     ▼
Observe
     │
     └─────────────∞
```

There isn't really a permanent:

```text
DONE.
```

There's:

```text
currently converged.
```

This is distributed-systems/controller thinking.

---

# 14.58 Convergence

Another useful term.

Suppose:

```text
Desired != Actual
```

Controller applies changes.

Over time:

```text
Actual
   ↓
moves toward
   ↓
Desired
```

That process is:

# convergence.

Once:

```text
Desired = Actual
```

the system has converged.

---

# 14.59 GitOps is eventual reconciliation

Changes do not necessarily appear in the cluster the same nanosecond a Git commit occurs.

Argo CD detects repository changes through reconciliation and can also use webhooks to speed detection. Current default repository polling is based on a reconciliation interval of 120 seconds plus up to 60 seconds of jitter, so polling alone can take roughly up to three minutes to observe a change. ([Argo CD][8])

Don't memorize:

```text
Git commit
=
instant deployment.
```

Think:

```text
Git commit
→ detection
→ comparison
→ reconciliation
→ Kubernetes rollout.
```

---

# 14.60 Webhook vs polling

Basic polling:

```text
Argo
 │
 ├── check Git
 │
 ├── wait
 │
 ├── check Git
 │
 └── repeat
```

Webhook:

```text
Git provider
    │
    ▼
"Repository changed!"
    │
    ▼
Argo refreshes
```

We'll configure this later.

---

# 14.61 Desired state is not always raw YAML

Argo CD can work with declarative configuration generated through tools such as:

```text
Plain Kubernetes manifests

Helm

Kustomize
```

and its repository server produces rendered Kubernetes manifests before comparison/deployment. ([Argo CD][6])

So GitOps desired state might be:

```text
Helm values
```

rather than 5,000 raw YAML files.

---

# 14.62 Helm example

Git:

```yaml
replicaCount: 3

image:
  repository: todo-api
  tag: v42
```

Repo server:

```text
Helm values
     │
     ▼
helm rendering
     │
     ▼
Deployment
Service
Ingress
ConfigMap
```

Argo compares the rendered result with Kubernetes.

---

# 14.63 Kustomize example

Git:

```text
base/
  deployment.yaml

overlays/
  prod/
    kustomization.yaml
```

Argo:

```text
Kustomize
   │
   ▼
render prod overlay
   │
   ▼
compare/apply
```

Official Argo CD Kustomize integration renders manifests automatically when the configured application path contains a `kustomization.yaml`. ([Argo CD][9])

We'll spend a dedicated lesson on this.

---

# 14.64 What is source of truth?

People often say:

```text
Git is source of truth.
```

That's useful, but be precise.

Git is the:

```text
source of declared desired state
```

while:

```text
Kubernetes
```

remains the source for:

```text
actual runtime state.
```

Argo continuously compares:

```text
DECLARED DESIRED STATE
          vs
LIVE RUNTIME CONFIGURATION
```

---

# 14.65 Don't put runtime state into Git blindly

For example:

```text
pod IP

node name

container restart count

current HPA replica count

Lease objects
```

are runtime/controller-generated information.

GitOps doesn't mean:

```text
commit every bit
of Kubernetes state
to Git.
```

Git describes the state you intend to control.

---

# 14.66 Ownership is crucial

Suppose Git declares:

```yaml
replicas: 3
```

but HPA is configured to dynamically change replicas.

Now two controllers think they own the same field.

```text
Git / Argo
   │
   └── replicas


HPA
   │
   └── replicas
```

Potential conflict:

```text
Argo: 3!

HPA: 8!

Argo: 3!

HPA: 8!
```

Not good.

---

# 14.67 Controller ownership principle

Permanent rule:

# **One field should have one authoritative controller.**

If HPA controls replicas:

```text
HPA
=
owner of replica count
```

Argo CD's best-practice documentation specifically recommends not declaring `spec.replicas` in Git when you intend the Horizontal Pod Autoscaler to control replica count. ([Argo CD][4])

This is much deeper than an Argo-specific trick.

It is a distributed control-plane design principle.

---

# 14.68 Ignore Differences

Sometimes live state legitimately differs because another controller owns some field.

Argo CD supports diff customization to ignore specific JSON paths, JQ-selected fields, or fields managed by particular Kubernetes field managers. ([Argo CD][10])

Example concept:

```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
      - /spec/replicas
```

Meaning:

```text
Don't treat replicas
as meaningful drift
for this comparison.
```

We'll use this carefully later.

---

# 14.69 Don't use IgnoreDifferences as a garbage bin

Bad:

```text
Difference?
   │
   ▼
ignore it
```

Eventually:

```text
Git says one thing
cluster says ten other things
Argo says everything fine
```

You have destroyed GitOps credibility.

Use it only for fields whose ownership is deliberately assigned elsewhere.

---

# 14.70 GitOps anti-pattern — UI override

Argo allows parameter overrides.

Example:

```text
Git says image=v1

Argo UI override says image=v2
```

Now source of truth becomes:

```text
Git
+
Argo internal override
```

Argo CD's own documentation notes that many consider parameter overrides an anti-pattern for GitOps and recommends them mainly as a convenience for development/test scenarios rather than production. ([Argo CD][11])

Permanent rule:

```text
PRODUCTION DESIRED STATE
should be reconstructable
from version-controlled configuration.
```

---

# 14.71 The "kubectl edit" anti-pattern

Production team says:

> “Need urgent change.”

Engineer:

```bash
kubectl edit deployment
```

It fixes production.

But Git remains unchanged.

Now:

```text
Git != Production
```

Two problems:

```text
1. Argo may revert it.

2. Future Git deployment may overwrite it.
```

The proper pattern is generally:

```text
emergency Git change
     │
     ▼
fast review
     │
     ▼
merge
     │
     ▼
reconciliation
```

with a documented break-glass route if GitOps itself is unavailable.

---

# 14.72 Git revert as rollback

Suppose commit:

```text
A
v41
```

then:

```text
B
v42
```

causes failure.

Traditional rollback might execute:

```bash
kubectl set image ...
```

GitOps rollback model can be:

```text
revert commit B
      │
      ▼
Git desired state returns to v41
      │
      ▼
Argo reconciles
      │
      ▼
Kubernetes rolls back
```

Very clean audit trail.

---

# 14.73 But rollback isn't always simple

Suppose deployment v42 executed:

```text
database migration
```

that removed a column.

Reverting image:

```text
v42 → v41
```

may not restore DB compatibility.

Therefore:

```text
Git rollback
≠
business/system rollback
```

GitOps doesn't eliminate stateful deployment complexity.

We'll handle migrations, hooks, and sync waves later.

---

# 14.74 GitOps improves recovery

Imagine Kubernetes cluster accidentally loses:

```text
Deployments

Services

Ingresses
```

but Git repository still contains desired configuration.

A GitOps-managed cluster can reconstruct a large amount of application configuration from Git.

This changes disaster-recovery thinking:

```text
Git
=
declarative recovery source
```

for the resources Git actually owns.

But Git is not your database backup.

Never confuse:

```text
Kubernetes configuration recovery
```

with:

```text
application data recovery.
```

---

# 14.75 GitOps and immutable infrastructure

GitOps works well with immutable artifacts.

Prefer:

```text
image:
  todo-api:a6f23bc
```

over:

```text
image:
  todo-api:latest
```

Why?

Because:

```text
todo-api:latest
```

can point to different image content without Git changing.

Then:

```text
same Git commit
```

doesn't necessarily mean:

```text
same runtime artifact.
```

A commit-derived tag or immutable digest gives much stronger deployment traceability.

---

# 14.76 Ideal artifact flow

```text
SOURCE COMMIT

a61c92f
   │
   ▼
CI BUILD
   │
   ▼
IMAGE

todo-api:a61c92f
   │
   ▼
CONFIG COMMIT

image:
todo-api:a61c92f
   │
   ▼
ARGO CD
   │
   ▼
KUBERNETES
```

Now you can answer:

> Which source code produced this running pod?

Very easily.

---

# 14.77 GitOps deployment chain

Full traceability:

```text
Pod
 │
 ▼
Image digest
 │
 ▼
Image tag
 │
 ▼
Source commit
 │
 ▼
CI build
 │
 ▼
Config repository commit
 │
 ▼
Pull Request
 │
 ▼
Approver
```

This is excellent for:

```text
incident response

compliance

audit

rollback

debugging.
```

---

# 14.78 Push vs pull — security comparison

## Push

```text
CI
 │
 ▼
Cluster
```

Requires:

```text
CI → cluster connectivity
CI → Kubernetes credentials
```

## Pull

```text
CI
 │
 ▼
Git
 ▲
 │
Argo
 │
 ▼
Cluster
```

CI does not necessarily require direct deployment access to the Argo CD API or Kubernetes cluster for auto-sync workflows. ([Argo CD][3])

---

# 14.79 Pull does not mean no outbound access

Argo still needs connectivity to things such as:

```text
Git repository

Kubernetes API

possibly Helm repositories

authentication endpoints
```

So network architecture remains important.

For private EKS:

```text
Argo CD
inside appropriate network
```

must be able to reach required sources.

---

# 14.80 Argo CD typically lives in Kubernetes

Conceptually:

```text
Kubernetes Cluster
│
├── argocd namespace
│   │
│   ├── Argo CD components
│   └── controllers/services
│
└── application namespaces
```

Argo CD itself is Kubernetes-native and its Applications/Projects/settings can be represented declaratively as Kubernetes resources. ([Argo CD][7])

We'll install it into our environment in the next lesson.

---

# 14.81 One Argo CD managing same cluster

Simplest architecture:

```text
Kubernetes Cluster

├── Argo CD
│
└── Applications
```

Argo manages:

```text
the cluster it runs in.
```

This is often where learning starts.

---

# 14.82 One Argo CD managing multiple clusters

Later:

```text
             Argo CD
                │
      ┌─────────┼─────────┐
      ▼         ▼         ▼

    DEV       STAGING    PROD
   Cluster    Cluster    Cluster
```

Argo CD supports deployment to target Kubernetes environments, and we'll later design multi-cluster permissions and failure domains carefully. ([Argo CD][1])

---

# 14.83 Multi-cluster question

Should one central Argo CD manage:

```text
all clusters
in the company?
```

Maybe.

Benefits:

```text
central visibility
standardization
less duplication
```

Risks:

```text
larger control-plane blast radius

powerful credentials

central outage

team isolation concerns
```

Alternative:

```text
one Argo per environment

one per region

one per business domain
```

There is no universal answer.

We'll design these models later.

---

# 14.84 Argo CD is not CI

Do not expect Argo CD to replace:

```text
Jenkins

GitHub Actions

GitLab CI
```

for:

```text
compile code

unit test

build image

run SAST

push image
```

Argo CD is fundamentally:

# Continuous Delivery for Kubernetes.

Officially, Argo CD positions itself as a declarative GitOps CD tool for Kubernetes. ([Argo CD][1])

---

# 14.85 CI + Argo CD

Ideal architecture:

```text
              APPLICATION REPO

                    │
                    ▼
                Jenkins
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
       Test        Scan        Build
                               Image
                                │
                                ▼
                               ECR

                                │
                     update image reference
                                │
                                ▼
                       GITOPS CONFIG REPO
                                │
                                ▼
                             Argo CD
                                │
                                ▼
                             Kubernetes
```

That's the architecture we'll eventually implement.

---

# 14.86 CI should produce, GitOps should reconcile

Permanent sentence:

> **CI produces immutable artifacts; GitOps declares which artifact should run; Argo CD reconciles Kubernetes to that declaration.**

Memorize that.

---

# 14.87 CI failure

Suppose tests fail.

```text
Code
 ↓
CI
 X
```

No new artifact.

No GitOps change.

Production remains:

```text
old known version.
```

Excellent.

---

# 14.88 Deployment failure

CI succeeds:

```text
image v42 ✓
```

Config updates:

```text
v41 → v42
```

Argo syncs.

Pods fail.

Now:

```text
CI status
=
SUCCESS


Argo Sync
=
possibly SYNCED


Application health
=
DEGRADED
```

This illustrates why:

```text
CI success
≠
deployment success
≠
application health.
```

Three different layers.

---

# 14.89 The three success signals

Always distinguish:

```text
BUILD STATUS
    │
    ▼
Did CI create valid artifact?


SYNC STATUS
    │
    ▼
Does cluster configuration
match desired state?


HEALTH STATUS
    │
    ▼
Are Kubernetes resources healthy?
```

This is one of the most valuable mental models in this entire module.

---

# 14.90 GitOps and environment promotion

A common production model:

```text
DEV
  │
  ▼
STAGING
  │
  ▼
PROD
```

But don't think Argo literally "moves containers" between them.

Artifact remains:

```text
todo-api:a61c92f
```

What changes is desired configuration:

```text
Dev:
a61c92f

Staging:
a61c92f

Prod:
old version
```

Then after approval:

```text
Prod:
a61c92f
```

---

# 14.91 Promotion means configuration change

Permanent mental model:

```text
PROMOTE ARTIFACT

does not mean

rebuild artifact.
```

Better:

```text
Build once

promote same immutable image
through environments.
```

Example:

```text
CI BUILD

sha256:abc123
       │
       ├── Dev
       ├── Staging
       └── Prod
```

The same artifact should ideally be promoted, not rebuilt separately for each environment.

---

# 14.92 Why?

If:

```text
Dev build = A

Prod build = B
```

even if both came from the "same source":

```text
you didn't test
the exact thing
you deployed.
```

Build once, promote immutable artifact.

---

# 14.93 GitOps environment repository example

```text
gitops/
│
├── apps/
│   └── todo-api/
│       └── base/
│
└── environments/
    ├── dev/
    │   └── todo-api/
    │
    ├── staging/
    │   └── todo-api/
    │
    └── prod/
        └── todo-api/
```

Different environments can pin different artifact revisions.

Later we'll compare:

```text
directory-per-environment

branch-per-environment

repo-per-environment
```

and discuss trade-offs.

---

# 14.94 Git branch is not automatically an environment

Some teams use:

```text
dev branch
staging branch
prod branch
```

Others use:

```text
one main branch

directories:
dev/
stage/
prod/
```

Neither is automatically correct.

Important requirements:

```text
clear promotion

auditable differences

branch protection

low merge complexity

easy rollback
```

We'll design this later.

---

# 14.95 GitOps and Infrastructure as Code

Terraform:

```text
AWS infrastructure
```

Argo CD:

```text
Kubernetes desired state
```

Typical architecture:

```text
Terraform
   │
   ▼
EKS
VPC
IAM
Node groups
   │
   ▼
Kubernetes cluster exists
   │
   ▼
Argo CD
   │
   ▼
Kubernetes applications/platform components
```

Don't necessarily make Argo CD own:

```text
VPC

EKS control plane

RDS
```

just because "everything should be GitOps."

Use the right declarative engine for the right control plane.

---

# 14.96 Terraform vs Argo CD

Permanent distinction:

```text
TERRAFORM
=
cloud infrastructure reconciliation
through Terraform state


ARGO CD
=
Kubernetes application/config
reconciliation against Git
```

There is overlap at edges, but clear ownership reduces conflicts.

---

# 14.97 Control plane conflict example

Terraform owns:

```text
Kubernetes namespace todo
```

Argo also owns:

```text
Namespace todo
```

Then:

```text
two systems
believe they own
same resource.
```

Bad.

Permanent rule from our Terraform governance lesson:

> **One resource should have one authoritative lifecycle owner.**

The same rule applies to GitOps.

---

# 14.98 Kubernetes platform components

Argo CD may eventually manage Kubernetes-native platform components such as:

```text
Ingress controller

ExternalDNS

cert-manager

External Secrets Operator

Prometheus stack

Loki

OpenTelemetry Collector

policy controllers
```

But bootstrapping must be designed carefully:

```text
Who installs Argo itself?

Then who manages Argo?
```

We'll cover:

```text
bootstrap
App-of-Apps
ApplicationSet
```

later.

---

# 14.99 GitOps bootstrap paradox

Same kind of problem we saw with Terraform state.

Question:

> If Argo CD manages everything through Git, who installs Argo CD?

Initial bootstrap may require:

```text
Terraform

Helm

kubectl

cluster add-on tooling
```

Then Argo CD can potentially begin managing much of its own configuration.

This is called:

```text
bootstrapping
```

and we'll build it properly.

---

# 14.100 Argo CD is itself declarative

Argo CD `Application`, `AppProject`, and many settings can be represented as Kubernetes manifests rather than configured only through the UI/CLI. ([Argo CD][7])

This lets you eventually reach:

```text
Git
 │
 ▼
Argo configuration
 │
 ▼
Argo
 │
 ▼
other applications
```

---

# 14.101 GitOps and auditability

Traditional:

```text
kubectl apply
```

tells Kubernetes:

```text
change configuration.
```

But the command itself does not inherently contain:

```text
approval record

review discussion

business reason
```

Git PR does.

Example:

```text
PR-142

Reason:
Fix production memory leak

Change:
todo-api:v41 → v42

Reviewer:
Platform

Ticket:
INC-724
```

Now operational history becomes richer.

---

# 14.102 Git history is not the only audit trail

Remember:

```text
Git
=
desired-state history


Kubernetes audit logs
=
Kubernetes API actions


CloudTrail
=
AWS API actions
```

For a production EKS incident you may need all three.

```text
Git
+
Argo audit/events
+
Kubernetes audit
+
CloudTrail
```

different layers tell different parts of the story.

---

# 14.103 GitOps and policy gates

Before desired state reaches Git `main`, CI can validate:

```text
YAML syntax

Helm template

Kustomize build

Kubernetes schema

Kyverno policies

OPA policies

security checks

image signatures

container vulnerabilities
```

Then:

```text
approved state
```

is allowed to merge.

Git becomes a **policy checkpoint**.

---

# 14.104 GitOps does not eliminate DevSecOps

Instead it creates another place to enforce it.

```text
CODE
 │
 ▼
CI security gates
 │
 ▼
ARTIFACT
 │
 ▼
GitOps config PR
 │
 ▼
policy gates
 │
 ▼
Argo
 │
 ▼
Admission policy
 │
 ▼
Kubernetes
```

Defense in depth.

---

# 14.105 Argo CD also needs least privilege

Don't give Argo:

```text
cluster-admin
```

everywhere simply because it is convenient.

Later we'll design:

```text
AppProjects

destination restrictions

resource allow/deny lists

RBAC

cluster credentials

namespace boundaries
```

because Argo can be a very privileged control plane.

---

# 14.106 GitOps blast radius

If one Argo instance controls:

```text
Dev

QA

Prod

Security platform

Ingress

Monitoring
```

a bad Argo change can affect many systems.

Therefore Argo's architecture needs the same thinking we used for AWS:

```text
ownership

blast radius

separation

least privilege

DR
```

---

# 14.107 Application vs Project

Preview only.

```text
Application
=
what to deploy
and where


AppProject
=
what an application/team
is allowed to use
```

Later:

```text
Project Payments

allowed repositories:
payments repos

allowed destination:
payments namespace

allowed clusters:
production

allowed resource kinds:
...
```

This is how multi-team Argo becomes governable.

---

# 14.108 ApplicationSet

Preview:

Suppose:

```text
20 clusters
×
30 applications
```

You don't want to hand-create:

```text
600 Application YAML files.
```

ApplicationSet generates Argo CD `Application` resources from patterns/data.

We'll study:

```text
Git generators

cluster generators

matrix generators

pull-request generators
```

later.

---

# 14.109 App-of-Apps

Preview:

One parent Application references:

```text
many child Applications
```

Concept:

```text
Platform Root App
│
├── ingress-controller
├── cert-manager
├── external-secrets
├── monitoring
└── business-apps
```

Argo CD documents this kind of cluster-bootstrapping pattern, with automated sync/prune being possible for child applications. ([Argo CD][12])

We'll compare it with ApplicationSet instead of blindly using it everywhere.

---

# 14.110 Argo Rollouts

Argo CD answers:

```text
What should Kubernetes deploy?
```

Argo Rollouts can help answer:

```text
How should a new version
progressively receive traffic?
```

Preview:

```text
v1
95%

v2
5%

     ↓

v1
50%

v2
50%

     ↓

v2
100%
```

That's:

```text
progressive delivery.
```

Later we'll implement:

```text
Canary

Blue/Green
```

---

# 14.111 Argo CD vs Argo Rollouts

Never confuse them.

```text
ARGO CD
=
GitOps continuous delivery
and reconciliation


ARGO ROLLOUTS
=
advanced progressive
deployment strategies
```

They can work together.

---

# 14.112 GitOps troubleshooting mindset

When application isn't right, split the path:

```text
1. GIT

Is desired configuration correct?


2. RENDER

Did Helm/Kustomize generate
what you expected?


3. ARGO DIFF

Desired vs live?


4. SYNC

Did reconciliation succeed?


5. KUBERNETES

Were objects accepted?


6. HEALTH

Did controllers create
healthy resources?


7. APPLICATION

Does the application
actually serve traffic?
```

This will become our core troubleshooting framework.

---

# 14.113 Example failure — Git wrong

Git:

```yaml
image: todo-api:v9999
```

Image doesn't exist.

Argo:

```text
correctly deploys v9999
```

Kubernetes:

```text
ImagePullBackOff
```

Root cause:

```text
DESIRED STATE WRONG
```

Not:

```text
Argo bug.
```

---

# 14.114 Example failure — rendering wrong

Helm:

```yaml
service:
  port: 8080
```

template accidentally produces:

```yaml
targetPort: 9090
```

Git source looks plausible.

Rendered manifest is wrong.

Therefore troubleshoot:

```text
SOURCE
→ RENDERED MANIFEST
```

before blaming Kubernetes.

---

# 14.115 Example failure — sync denied

Git valid.

Rendered manifest valid.

Argo tries:

```text
create ClusterRole
```

but Argo lacks permission.

Result:

```text
SYNC FAILED
```

Root area:

```text
Argo RBAC /
Kubernetes authorization
```

---

# 14.116 Example failure — synced but health degraded

Deployment created successfully.

Pods:

```text
CrashLoopBackOff.
```

Argo:

```text
Synced

Degraded
```

Root area:

```text
application/runtime
```

Now check:

```bash
kubectl describe pod

kubectl logs
```

not Git sync first.

---

# 14.117 GitOps troubleshooting shortcut

Remember:

# **G-R-D-S-H-A**

```text
G
GIT


R
RENDER


D
DIFF


S
SYNC


H
HEALTH


A
APPLICATION
```

We'll use this repeatedly.

---

# 14.118 GitOps changes "who deploys?"

Old:

```text
Developer
or
Jenkins

deploys production.
```

New mental model:

```text
Human
changes desired state.


Git
records desired state.


Argo
performs reconciliation.


Kubernetes
runs workload.
```

This separation matters.

---

# 14.119 GitOps change path

```text
HUMAN INTENT
      │
      ▼
Pull Request
      │
      ▼
Git Commit
      │
      ▼
Desired State
      │
      ▼
Argo Reconciliation
      │
      ▼
Kubernetes Desired State
      │
      ▼
Kubernetes Controllers
      │
      ▼
Runtime
```

That is the complete control path.

---

# 14.120 Why GitOps is powerful during incident review

You can ask:

```text
What did we WANT production to be?
→ Git


What did Kubernetes HAVE?
→ cluster/audit/state


Did Argo see drift?
→ Argo


Did deployment converge?
→ sync


Was workload working?
→ health/observability
```

These layers provide much better forensic reasoning.

---

# 14.121 GitOps and observability

Argo tells you about:

```text
deployment/configuration state
```

Prometheus tells you:

```text
application/system metrics
```

Loki tells you:

```text
logs
```

Tempo tells you:

```text
traces
```

Do not treat:

```text
Argo = Healthy
```

as equivalent to:

```text
application SLO healthy.
```

A Deployment may be Healthy while:

```text
95th percentile latency
=
8 seconds
```

Observability remains necessary.

---

# 14.122 Deployment health vs business health

Argo might say:

```text
Deployment Healthy
```

because:

```text
desired replicas = ready replicas
```

But business service could still fail because:

```text
database unavailable

wrong feature flag

third-party API down

bad business logic
```

Therefore:

```text
Kubernetes health
≠
business health.
```

We'll later connect Argo Rollouts with Prometheus analysis for progressive delivery.

---

# 14.123 GitOps and disaster recovery

Suppose cluster disappears.

Terraform restores:

```text
EKS infrastructure
```

Then bootstrap restores:

```text
Argo CD
```

Argo reads:

```text
Git
```

and restores:

```text
platform components

application manifests
```

while:

```text
database backups/replication
```

restore stateful data.

Architecture:

```text
Terraform
=
cluster infrastructure recovery


GitOps
=
Kubernetes desired-state recovery


Backup/replication
=
application data recovery
```

Three different recovery layers.

---

# 14.124 Git repository becomes Tier-0 infrastructure

If Git contains:

```text
all production desired state
```

then Git availability, access control, and recovery matter enormously.

Ask:

```text
What if Git is unavailable?

What if repository is deleted?

What if credentials are compromised?

What if bad commit reaches main?

What if Git provider Region fails?
```

Production GitOps architecture includes Git itself in DR/security planning.

---

# 14.125 GitOps does not mean "automatic everything"

You can still use:

```text
manual promotion

manual sync

approval gates

sync windows

change freezes
```

while following GitOps principles.

The key requirement is that the authoritative desired state remains declarative/versioned and reconciliation is controlled through the GitOps system—not that every production change must happen instantly after every commit.

---

# 14.126 Production model examples

### Development

```text
merge
 ↓
auto-sync
 ↓
self-heal
 ↓
prune
```

### Production

Possible design:

```text
approved config PR
 ↓
merge
 ↓
automated sync
```

or:

```text
approved config PR
 ↓
merge
 ↓
manual synchronization/change window
```

depending on company risk model.

GitOps doesn't eliminate governance.

---

# 14.127 Self-heal production trade-off

Benefits:

```text
drift automatically repaired

manual changes disappear

Git remains authoritative
```

Risk:

```text
incident responder
makes temporary cluster fix

Argo reverts it
```

Therefore operations teams must understand the reconciler.

A production GitOps runbook needs:

```text
normal change path

emergency change path

temporary pause procedure

resume/reconciliation procedure.
```

---

# 14.128 Prune production trade-off

Benefits:

```text
Git deletion
=
resource deletion

no orphaned resources
```

Risk:

Bad Git change:

```text
delete manifests accidentally
```

plus:

```text
auto-prune
```

could remove live resources.

Therefore:

```text
Git review
```

is a production safety boundary.

---

# 14.129 GitOps is automation with consequences

This is the same principle we saw with:

```text
Terraform

SCP

AFT

autoscaling
```

Automation gives:

```text
speed
consistency
repeatability
```

but increases the blast radius of:

```text
bad input.
```

Therefore stronger automation requires stronger:

```text
validation
review
policy
observability.
```

---

# 14.130 Argo CD mental model — one picture

```text
                      DEVELOPER

                         │
                    code change
                         │
                         ▼
                    APPLICATION
                    SOURCE REPO
                         │
                         ▼
                         CI
                 test / scan / build
                         │
                         ▼
                       IMAGE
                         │
                         ▼
                        ECR

                         │
               update desired version
                         │
                         ▼
                 GITOPS CONFIG REPO

                    DESIRED STATE
                         │
                         ▼
                    ┌─────────┐
                    │ ARGO CD │
                    └────┬────┘
                         │
                   reconciliation
                         │
                         ▼
                  KUBERNETES API
                         │
                         ▼
                KUBERNETES CONTROLLERS
                         │
                         ▼
                       PODS

             ┌───────────┴───────────┐

        Git Desired               Live State

             └──── compare ─────────┘
```

If you understand this diagram, you understand the foundation of Argo CD.

---

# 14.131 GitOps vs traditional deployment table

| Traditional CD                   | GitOps                                            |
| -------------------------------- | ------------------------------------------------- |
| Pipeline pushes to cluster       | Agent pulls/reconciles desired state              |
| CI often has cluster credentials | CI can stop at Git/config promotion               |
| Manual changes can persist       | Drift can be detected/corrected                   |
| Deployment event-centric         | Continuous reconciliation-centric                 |
| Pipeline definition is central   | Desired state in Git is central                   |
| Rollback often executes commands | Rollback can revert desired state                 |
| Audit depends on pipeline/tools  | Git history provides strong desired-state history |

Argo CD's automated-sync design explicitly supports the model where CI changes the tracked configuration repository rather than directly invoking deployment APIs. ([Argo CD][3])

---

# 14.132 GitOps vs CI/CD

Never say:

```text
GitOps replaces CI/CD.
```

Better:

```text
CI/CD
=
larger software-delivery discipline


GitOps
=
a deployment/operations model
for declaratively managing desired state
through version control
and reconciliation.
```

Argo CD becomes the:

```text
CD / reconciliation
```

part of the pipeline.

---

# 14.133 GitOps vs Kubernetes

Never say:

```text
Kubernetes automatically means GitOps.
```

Kubernetes provides:

```text
declarative API
+
controllers
```

GitOps adds:

```text
version-controlled desired state
+
automatic pulling
+
continuous reconciliation
```

at another layer.

---

# 14.134 GitOps vs Terraform

Never say:

```text
Terraform = GitOps
```

Simply storing Terraform in Git isn't automatically the same controller-based pull/reconciliation model defined by OpenGitOps.

Terraform is declarative IaC and can participate in Git-based workflows, but its typical execution model differs from an in-cluster GitOps reconciler such as Argo CD.

---

# 14.135 Argo CD status mental model

When we install Argo, four questions should always be in your head:

```text
1.
What does Git say?


2.
What does Kubernetes say?


3.
Are they synchronized?


4.
Is the resulting workload healthy?
```

If you ask those four questions, Argo's UI becomes much easier to understand.

---

# 14.136 First interview question — What is GitOps?

Strong answer:

> **GitOps is an operating model in which a system's desired state is expressed declaratively, stored in a versioned and immutable form, automatically pulled by software agents, and continuously reconciled against the actual system state.**

Those four properties align directly with the OpenGitOps principles. ([OpenGitOps][2])

---

# 14.137 Interview — What is Argo CD?

Strong answer:

> **Argo CD is a declarative GitOps continuous-delivery tool for Kubernetes. It obtains desired application configuration from a source repository, compares that desired state with live Kubernetes resources, reports differences such as `OutOfSync`, and can reconcile the cluster manually or automatically.** ([Argo CD][1])

---

# 14.138 Interview — CI vs Argo CD

Answer:

```text
CI
=
build/test/scan/package artifact


Argo CD
=
reconcile declared Kubernetes
deployment state.
```

A common production workflow is:

```text
CI builds image
→ pushes registry
→ changes deployment config in Git
→ Argo deploys.
```

---

# 14.139 Interview — Push vs Pull deployment

Strong answer:

> **In a push model, the CI/CD system has credentials and connectivity to push changes directly to the deployment target. In a GitOps pull model, a controller such as Argo CD runs with deployment authority, pulls or observes desired state from the repository, and reconciles the target cluster. This can remove the need for CI itself to hold direct cluster deployment credentials.** ([Argo CD][3])

---

# 14.140 Interview — What is drift?

```text
DRIFT
=
desired state
does not match
live state.
```

Example:

```text
Git:
replicas=3


Cluster:
replicas=5
```

---

# 14.141 Interview — What is reconciliation?

```text
Observe desired

Observe actual

Compare

Correct differences

Repeat
```

Argo's application controller continuously performs this desired/live-state comparison. ([Argo CD][6])

---

# 14.142 Interview — Synced vs Healthy

```text
SYNCED
=
live configuration matches desired configuration


HEALTHY
=
Kubernetes resources satisfy
Argo's health assessment
```

These are independent dimensions. ([Argo CD][5])

---

# 14.143 Interview — Auto-sync vs Self-Heal

```text
AUTO-SYNC

Git changes
→ apply desired change


SELF-HEAL

live cluster changes
without Git changing
→ restore desired Git state
```

Both are settings within Argo CD's automated-sync behavior. ([Argo CD][3])

---

# 14.144 Interview — What is prune?

```text
Git no longer declares resource
       │
       ▼
Argo removes live resource
```

when pruning is enabled.

Automatic pruning is intentionally separate and is not enabled merely by turning on automatic sync. ([Argo CD][3])

---

# 14.145 Interview — Why separate application and config repos?

Good reasons include:

```text
separate access control

cleaner deployment audit history

configuration-only changes

multiple source repositories
feeding one deployment

avoiding CI trigger loops
```

These align with Argo CD's official best-practice recommendations. ([Argo CD][4])

---

# 14.146 Interview — Why not use `latest`?

Because:

```text
Git may not change

while image behind latest changes.
```

Then:

```text
same Git state
≠
same artifact.
```

Prefer immutable:

```text
commit-based tag
```

or:

```text
digest
```

for stronger reproducibility.

---

# 14.147 Interview — HPA keeps making app OutOfSync

Ask:

> Who owns `spec.replicas`?

If HPA owns it, don't make Argo constantly fight HPA.

Argo CD specifically recommends omitting `replicas` from Git when HPA manages scaling, or deliberately configuring appropriate diff behavior. ([Argo CD][4])

---

# 14.148 Interview trap — Git contains YAML, therefore GitOps

Wrong.

Git storage alone isn't enough.

OpenGitOps includes:

```text
Declarative

Versioned/Immutable

Automatically Pulled

Continuously Reconciled
```

as the defining principles. ([OpenGitOps][2])

---

# 14.149 Interview trap — Argo replaces Jenkins

Wrong.

Use:

```text
Jenkins
→ CI


Argo CD
→ GitOps CD
```

They complement each other very well.

---

# 14.150 Interview trap — Synced means application is working

Wrong.

Possible:

```text
Synced
+
Degraded
```

because configuration can match Git while pods are unhealthy.

---

# 14.151 Interview trap — Auto-sync automatically deletes removed resources

Wrong.

Automatic pruning has to be enabled separately. ([Argo CD][3])

---

# 14.152 Interview trap — manual kubectl change is permanent

Not necessarily.

If Argo is configured to self-heal and Git says something else:

```text
manual change
→ drift
→ reconciliation
→ Git value restored.
```

---

# 14.153 Interview trap — GitOps means no emergency changes

Wrong.

Production systems still require:

```text
break-glass procedures.
```

But after emergency intervention, you must reconcile:

```text
live reality

and

declared desired state.
```

Otherwise your next GitOps run may undo the emergency fix.

---

# 14.154 Interview trap — Git is runtime state

Wrong.

Git stores:

```text
desired state.
```

Cluster stores:

```text
live state.
```

Argo compares them.

---

# 14.155 Interview trap — Argo replaces Kubernetes controllers

Wrong.

Hierarchy:

```text
Git
 ↓
Argo
 ↓
Kubernetes desired objects
 ↓
Kubernetes controllers
 ↓
runtime
```

Both reconciliation layers remain necessary.

---

# 14.156 Interview trap — ignore every Argo diff

Wrong.

A diff may represent:

```text
unauthorized manual change

misconfiguration

real production drift.
```

Ignore differences only when field ownership is intentionally delegated to another controller or the difference is otherwise understood. Argo CD provides fine-grained diff-customization capabilities specifically for those cases. ([Argo CD][10])

---

# 14.157 Production architecture example

Let's use our Todo application later.

Architecture:

```text
                       DEVELOPER
                           │
                           ▼
                     Todo-App Repo
                           │
                           ▼
                        Jenkins
                           │
             ┌─────────────┼──────────────┐
             ▼             ▼              ▼
           Tests          Scan         Build image
                                          │
                                          ▼
                                         ECR

                                          │
                                 image=a61c92f
                                          │
                                          ▼
                                  GitOps Config Repo
                                          │
                               Pull Request / approval
                                          │
                                          ▼
                                        main
                                          │
                                          ▼
                                       Argo CD
                                          │
                                          ▼
                                  EKS Production
                                          │
                                   Deployment
                                          │
                                          ▼
                                      Todo Pods
```

This eventually gives us a very strong resume architecture:

```text
Jenkins CI
+
ECR
+
Argo CD GitOps CD
+
EKS
+
Helm/Kustomize
+
Prometheus/Grafana
+
progressive delivery
```

---

# 14.158 Production promotion example

CI builds:

```text
todo-api:7e18cb2
```

Dev config:

```yaml
tag: 7e18cb2
```

Argo Dev:

```text
SYNC
```

Tests pass.

Promotion PR:

```diff
prod:

- tag: 19fc552
+ tag: 7e18cb2
```

Production approver merges.

Argo Prod:

```text
OutOfSync
   │
   ▼
Sync
   │
   ▼
rollout
```

No rebuild.

Same artifact.

---

# 14.159 GitOps security chain

Production deployment authority now looks like:

```text
Developer
    │
    ▼
Git PR permissions
    │
    ▼
Branch protection
    │
    ▼
Approved desired state
    │
    ▼
Argo AppProject / RBAC
    │
    ▼
Kubernetes RBAC
    │
    ▼
Admission policies
    │
    ▼
Kubernetes
```

Multiple security layers.

---

# 14.160 Failure domains

Suppose:

```text
CI down.
```

Existing applications keep running.

Argo can continue reconciling existing desired configuration.

Suppose:

```text
Argo down.
```

Existing Kubernetes workloads normally keep running.

But:

```text
new Git changes won't reconcile
drift won't self-heal
```

Suppose:

```text
Git down.
```

Existing workloads keep running, but Argo cannot fetch fresh desired state.

This separation is useful operationally.

---

# 14.161 GitOps does not put Argo in request path

User traffic:

```text
Client
  │
  ▼
ALB / Ingress
  │
  ▼
Service
  │
  ▼
Pod
```

Not:

```text
Client
 ↓
Argo CD
 ↓
Application
```

Argo is:

```text
management/control plane
```

not application data plane.

Therefore an Argo outage should not directly route customer HTTP requests.

---

# 14.162 This matters for HA

You don't necessarily need:

```text
Argo available every millisecond
```

for existing user traffic.

But you do care about:

```text
deployment availability

drift repair

incident response

platform recovery.
```

Its availability requirements should be based on control-plane SLOs.

---

# 14.163 A useful GitOps SLO

Later we can measure:

```text
reconciliation latency

sync success rate

time OutOfSync

failed sync count

application health

Git fetch errors
```

This turns Argo itself into an operated production platform.

---

# 14.164 GitOps smells

If you see:

```text
Argo installed
+
all developers still run kubectl apply
```

GitOps isn't really authoritative.

If:

```text
Git says v1
+
Argo override says v2
+
Helm manual install says v3
```

no clear desired-state authority exists.

If:

```text
every incident requires disabling Argo
```

the operating model isn't mature.

---

# 14.165 Production GitOps maturity

### Level 0

```text
kubectl apply manually
```

### Level 1

```text
Jenkins pushes kubectl
```

### Level 2

```text
Argo reads Git
manual sync
```

### Level 3

```text
Argo auto-sync
controlled promotion
```

### Level 4

```text
self-heal
pruning
policy checks
RBAC
multi-environment
```

### Level 5

```text
multi-cluster
progressive delivery
observability
DR
platform self-service
```

That's approximately where our module is headed.

---

# 14.166 First hands-on mental exercise

Imagine Git:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
```

Cluster:

```text
replicas: 5
```

Questions:

### Is there drift?

```text
YES
```

### Is it necessarily unhealthy?

```text
NO.
```

### Is it OutOfSync?

Conceptually:

```text
YES
```

if Argo owns/compares that field.

### What happens with self-heal?

```text
5 → 3
```

### What if HPA should own replicas?

Then Git/Argo should not fight HPA; configure ownership appropriately. ([Argo CD][4])

---

# 14.167 Second exercise

Git:

```yaml
image: todo:v42
```

Cluster:

```text
image: todo:v42

Pods:
CrashLoopBackOff
```

Question:

### Synced?

```text
YES
```

### Healthy?

```text
NO
```

### Root direction?

```text
runtime/application
```

not necessarily Git drift.

---

# 14.168 Third exercise

Git:

```text
Deployment
Service
```

Cluster:

```text
Deployment
Service
Old ConfigMap
```

Old ConfigMap no longer exists in Git.

Without prune:

```text
resource may remain.
```

With appropriate pruning enabled:

```text
Argo can remove it.
```

Automatic pruning is a separately enabled behavior. ([Argo CD][3])

---

# 14.169 Fourth exercise

Developer changes:

```text
production Deployment
```

directly using:

```bash
kubectl edit
```

Argo self-heal enabled.

What happens?

```text
live state differs
     │
     ▼
Argo detects drift
     │
     ▼
Git state restored
```

Unless the difference is deliberately ignored/owned elsewhere.

---

# 14.170 Fifth exercise

Jenkins has:

```text
Git permission

ECR permission
```

but:

```text
NO Kubernetes credential.
```

Can production deployment still happen?

With GitOps architecture:

```text
YES.
```

Jenkins changes the deployment config; Argo performs the cluster reconciliation. Argo's official automated-sync documentation explicitly identifies this as a benefit of the model. ([Argo CD][3])

---

# 14.171 Never-forget GitOps principles

```text
1.
Desired state must be declarative.


2.
Desired state should be
versioned and auditable.


3.
Agent pulls desired state.


4.
Agent continuously reconciles.


5.
Git is desired state,
cluster is live state.


6.
Desired != Live
=
drift.


7.
Reconciliation moves actual
toward desired.


8.
Argo sits above Kubernetes
controllers.


9.
CI builds artifacts.


10.
Argo CD performs GitOps CD.


11.
Push:
CI → cluster.


12.
Pull:
Argo → Git
then Argo → cluster.


13.
Synced does not mean Healthy.


14.
Healthy does not necessarily
mean Synced.


15.
Auto-sync and self-heal
are different concepts.


16.
Prune controls deletion of
resources removed from Git.


17.
Manual cluster changes may
be reverted.


18.
Don't let multiple controllers
own the same field.


19.
Use immutable artifact references.


20.
Build once and promote
the same artifact.


21.
Separate application source
and deployment configuration
when it improves ownership/audit.


22.
Git becomes a production
control-plane component.


23.
GitOps still needs
security and review.


24.
Argo is not in
customer traffic path.


25.
One resource should have
one authoritative lifecycle owner.
```

---

# 14.172 Lesson 1 final mental model

```text
                       SOURCE CODE
                           │
                           ▼
                           CI
                           │
                     test / build
                           │
                           ▼
                     IMAGE REGISTRY
                           │
                           ▼
                    GITOPS CONFIG

                     DESIRED STATE
                           │
                           ▼
                         ARGO CD
                           │
               ┌───────────┴────────────┐
               │                        │
               ▼                        ▼
        Read Desired State        Read Live State
               │                        │
               └───────────┬────────────┘
                           ▼
                         DIFF
                           │
                  Desired == Live?
                           │
                ┌──────────┴──────────┐
                │                     │
               YES                    NO
                │                     │
                ▼                     ▼
             SYNCED               OUT OF SYNC
                                      │
                                      ▼
                                  RECONCILE
                                      │
                                      ▼
                                KUBERNETES API
                                      │
                                      ▼
                           Kubernetes Controllers
                                      │
                                      ▼
                                    PODS
```

This is the foundation for everything else in Module 14.

---

# ✅ Module 14 — Lesson 1 Complete

You now understand:

```text
✓ What GitOps actually means

✓ Why GitOps exists

✓ Desired state

✓ Live state

✓ Drift

✓ Reconciliation

✓ Convergence

✓ Controller loops

✓ Kubernetes vs GitOps reconciliation

✓ OpenGitOps principles

✓ Push vs pull CD

✓ CI vs CD

✓ Source repo vs config repo

✓ Immutable artifact promotion

✓ Argo CD purpose

✓ Application Controller

✓ Repository Server

✓ Application mental model

✓ Source vs destination

✓ Sync status

✓ Health status

✓ Manual sync

✓ Automatic sync

✓ Self-heal

✓ Prune

✓ Controller ownership

✓ HPA conflict

✓ Ignore differences concept

✓ Git rollback

✓ GitOps DR

✓ GitOps security

✓ GitOps troubleshooting framework
```

# Next — Module 14, Lesson 2

## Argo CD Installation & Internal Architecture — Hands-On

Next we'll move to your Kubernetes environment and build Argo CD for real.

We'll cover:

```text
Pre-install cluster checks
        │
        ▼
Argo CD namespace
        │
        ▼
CRDs
        │
        ▼
argocd-server
        │
        ▼
repo-server
        │
        ▼
application-controller
        │
        ▼
ApplicationSet controller
        │
        ▼
Redis/caching role
        │
        ▼
Service exposure
        │
        ▼
Initial admin credentials
        │
        ▼
Argo CLI
        │
        ▼
UI login
        │
        ▼
first health checks
```

Then we will inspect the installation with commands such as:

```bash
kubectl get pods -n argocd

kubectl get svc -n argocd

kubectl get crd | grep argoproj

kubectl get applications -n argocd
```

and instead of merely seeing pods called `argocd-repo-server` or `argocd-application-controller`, you'll already know **why each one exists**.

[1]: https://argo-cd.readthedocs.io/?utm_source=chatgpt.com "Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://opengitops.dev/?utm_source=chatgpt.com "OpenGitOps: Home"
[3]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/?utm_source=chatgpt.com "Automated Sync Policy - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/?utm_source=chatgpt.com "Best Practices - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/health/?utm_source=chatgpt.com "Resource Health - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/?utm_source=chatgpt.com "Architectural Overview - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/faq/?utm_source=chatgpt.com "FAQ - Argo CD - Declarative GitOps CD for Kubernetes"
[9]: https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/?utm_source=chatgpt.com "Kustomize - Argo CD - Declarative GitOps CD for Kubernetes"
[10]: https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/?utm_source=chatgpt.com "Diff Customization - Declarative GitOps CD for Kubernetes"
[11]: https://argo-cd.readthedocs.io/en/stable/user-guide/parameters/?utm_source=chatgpt.com "Parameter Overrides - Declarative GitOps CD for Kubernetes"
[12]: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/?utm_source=chatgpt.com "Cluster Bootstrapping - Declarative GitOps CD for Kubernetes"
