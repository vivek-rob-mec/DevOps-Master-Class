# Module 14 — GitOps with Argo CD

## Lesson 5: Production Git Repository Design, Environment Promotion & CI → GitOps Flow

We have reached one of the most important architecture lessons in the entire Argo CD module.

So far, our flow was:

```text
Public example Git repo
        │
        ▼
      Argo CD
        │
        ▼
    Kubernetes
```

That taught us reconciliation.

But a production organization normally needs something closer to:

```text
                 APPLICATION SOURCE

Developer
    │
    ▼
Source Repository
    │
    ▼
CI
    │
    ├── unit tests
    ├── SAST
    ├── dependency scan
    ├── build
    ├── container scan
    └── push image
              │
              ▼
             ECR
              │
              │ immutable artifact
              ▼
        GITOPS CONFIG REPOSITORY
              │
       ┌──────┼───────┐
       ▼      ▼       ▼
      DEV   STAGING   PROD
       │      │        │
       ▼      ▼        ▼
     Argo   Argo      Argo
       │      │        │
       ▼      ▼        ▼
 Kubernetes environments
```

Argo CD's current best-practice and CI-automation documentation **strongly recommends separating application source code from the Git repository containing Kubernetes deployment configuration**. Reasons include cleaner audit history, independent access control, avoiding CI loops, and allowing configuration changes independently of application-source changes. ([Argo CD][1])

---

# 14.445 First mental model: we now have two products

A developer usually thinks there is one thing:

```text
Todo Application
```

But in a mature delivery system there are really two independently versioned things:

```text
APPLICATION CODE
```

and:

```text
DEPLOYMENT DESIRED STATE
```

Example:

```text
Todo Source Repository

commit:
3ab621f
```

produces:

```text
Container Artifact

todo-api:3ab621f
```

Then another repository says:

```text
Production should run:

todo-api:3ab621f
```

Those are different lifecycle objects.

---

# 14.446 Source repository vs GitOps repository

## Application source repository

Contains:

```text
todo-api/
│
├── src/
├── tests/
├── package.json
├── Dockerfile
├── Jenkinsfile
└── README.md
```

Its concern is:

> **How do we build the application?**

---

## GitOps repository

Contains something like:

```text
todo-gitops/
│
├── apps/
│
├── environments/
└── argocd/
```

Its concern is:

> **What should Kubernetes currently run?**

Permanent distinction:

```text
SOURCE REPO
=
how software is produced


GITOPS REPO
=
what software version
should be deployed
```

---

# 14.447 Why separate them?

Let's examine the production reasons one by one.

---

# 14.448 Reason 1 — different permissions

Developers may be allowed to merge:

```text
application code
```

but not directly change:

```text
production deployment policy.
```

Example:

```text
APP REPOSITORY

Developer write permission
        │
        ▼
merge application feature
```

But:

```text
PRODUCTION CONFIG REPOSITORY

Developer
   │
   ▼
Pull Request
   │
   ▼
SRE / Platform approval
   │
   ▼
merge
```

This gives separation of duties.

Argo CD explicitly calls out separate repository access controls as one of the benefits of splitting application code and deployment configuration. ([Argo CD][1])

---

# 14.449 Reason 2 — cleaner deployment audit trail

Imagine one repository contains:

```text
100 source-code commits

17 unit-test changes

12 documentation updates

5 dependency bumps

1 production deployment change
```

Finding:

> "Which commit deployed version 42 to production?"

can be noisy.

With a config repository:

```text
commit 94a1bc

prod:
todo-api
v41 → v42
```

The Git history is primarily a **deployment history**.

Argo CD's best-practice guidance specifically notes cleaner audit history as an advantage of separate deployment configuration. ([Argo CD][1])

---

# 14.450 Reason 3 — no unnecessary application rebuild

Suppose we change:

```yaml
resources:
  requests:
    memory: 256Mi
```

to:

```yaml
resources:
  requests:
    memory: 512Mi
```

Did application source code change?

```text
NO.
```

Should CI rebuild the Node.js application?

```text
NO.
```

Config repo:

```text
memory 256Mi → 512Mi
        │
        ▼
Argo CD
        │
        ▼
Kubernetes
```

No application rebuild required.

---

# 14.451 Reason 4 — avoid CI trigger loops

Imagine application source repo contains deployment manifests.

CI performs:

```text
code commit
   │
   ▼
pipeline
   │
   ▼
build image
   │
   ▼
modify deployment.yaml
   │
   ▼
commit to SAME repository
```

But that new commit triggers:

```text
pipeline again
```

which may modify:

```text
deployment.yaml again
```

You can handle this technically, but separating deployment configuration produces a much cleaner control flow. Argo CD's official best-practice documentation explicitly identifies avoiding CI loops as a reason to separate repositories. ([Argo CD][1])

---

# 14.452 Production repository architecture

For our Todo system:

```text
Git Organization
│
├── todo-app
│   │
│   ├── frontend/
│   ├── backend/
│   ├── tests/
│   ├── Dockerfile
│   └── Jenkinsfile
│
└── todo-gitops
    │
    ├── applications/
    ├── environments/
    ├── policies/
    └── argocd/
```

Now responsibilities are clear.

---

# 14.453 Full production release path

Let's trace one real release.

Developer commits:

```text
commit:
f73ca19
```

CI runs:

```text
Lint             ✓
Unit tests       ✓
Integration      ✓
SAST             ✓
Dependency scan  ✓
Docker build     ✓
Image scan       ✓
```

Then pushes:

```text
ECR

todo-api:f73ca19
```

Then config repo PR:

```diff
- tag: 813cc71
+ tag: f73ca19
```

Merge.

Argo:

```text
Git desired:
f73ca19

Live:
813cc71
```

Therefore:

```text
OutOfSync
      │
      ▼
Auto Sync
      │
      ▼
Kubernetes rollout
```

---

# 14.454 CI should build once

This is fundamental.

Bad model:

```text
Dev deployment
     │
     ▼
build image A


Staging deployment
     │
     ▼
build image B


Prod deployment
     │
     ▼
build image C
```

Even if all three builds use the same source commit:

```text
A
B
C
```

are separate build events.

Potential differences:

```text
dependency repository state

base image

timestamps

build tool versions

package registry

build environment
```

So what you tested isn't necessarily exactly what you later deployed.

---

# 14.455 Better model — build once, promote many

```text
Source commit

f73ca19
    │
    ▼
CI BUILD ONCE
    │
    ▼
Image digest

sha256:abc123...
    │
    ├──────────► DEV
    │
    ├──────────► STAGING
    │
    └──────────► PROD
```

The environment changes.

The artifact does not.

Permanent rule:

> **Promotion should usually change the desired deployment reference, not rebuild the application.**

---

# 14.456 Artifact identity

Weak:

```yaml
image: company/todo-api:latest
```

Stronger:

```yaml
image: company/todo-api:f73ca19
```

Strongest deterministic reference:

```yaml
image: company/todo-api@sha256:...
```

Why?

Because:

```text
latest
```

is mutable.

A commit-derived tag can be operationally immutable if your registry policies enforce it.

A digest identifies exact image content.

---

# 14.457 Git commit → image → GitOps commit

The chain should be reconstructable.

```text
APPLICATION SOURCE

f73ca19
     │
     ▼
CI
     │
     ▼
IMAGE

todo-api:f73ca19

digest:
sha256:abc...
     │
     ▼
GITOPS COMMIT

91bd2ee

prod image:
f73ca19
     │
     ▼
ARGO
     │
     ▼
POD
```

During incident response you can navigate backward.

---

# 14.458 Production forensic chain

Running Pod:

```text
todo-api:f73ca19
```

Ask:

```text
Which config deployed it?
```

GitOps commit:

```text
91bd2ee
```

Ask:

```text
Who approved it?
```

Pull Request:

```text
PR #382
```

Ask:

```text
Which source produced it?
```

Application commit:

```text
f73ca19
```

Ask:

```text
Which CI build created it?
```

Jenkins:

```text
Build #914
```

That is excellent traceability.

---

# 14.459 Environment promotion

Suppose:

```text
DEV
todo-api:f73ca19


STAGING
todo-api:813cc71


PROD
todo-api:52ac814
```

Developer is not "moving a container" between clusters.

The container already exists in ECR.

Promotion means:

```text
change desired configuration
for the next environment
```

---

# 14.460 Dev promotion

CI builds:

```text
f73ca19
```

Dev Git configuration becomes:

```yaml
image:
  tag: f73ca19
```

Argo Dev:

```text
Old:
813cc71

New desired:
f73ca19
```

Auto sync.

---

# 14.461 Staging promotion

After Dev verification:

```diff
staging:

- tag: 813cc71
+ tag: f73ca19
```

Merge.

Now staging uses **the exact same image**.

---

# 14.462 Production promotion

After staging verification:

```diff
prod:

- tag: 52ac814
+ tag: f73ca19
```

Production PR requires:

```text
Platform approval
+
application owner approval
```

depending on organization policy.

After merge:

```text
Argo Prod
→ deploys exact same image
```

---

# 14.463 Promotion mental model

Never forget:

```text
BUILD

source
 ↓
artifact


PROMOTION

artifact reference
 ↓
environment desired state
```

Do not confuse:

```text
promotion
```

with:

```text
rebuild.
```

---

# 14.464 The three major repository topology questions

When designing GitOps, ask:

```text
1.
Application source and config:
same repo or separate?


2.
Multiple applications:
monorepo or many repos?


3.
Environments:
branches, directories,
or separate repos?
```

These are three different design decisions.

Do not mix them together.

---

# 14.465 Monorepo vs polyrepo

Let's separate this carefully.

## GitOps monorepo

```text
company-gitops/
│
├── payments/
├── orders/
├── analytics/
├── todo/
└── platform/
```

Many applications.

One configuration repository.

---

# 14.466 Monorepo advantages

```text
central visibility

easier global policy changes

one repository to discover

atomic cross-app configuration changes

simpler bootstrap

consistent directory standards
```

Example:

```text
company-wide ingress annotation
```

may be changed consistently in one PR.

---

# 14.467 Monorepo disadvantages

```text
large blast radius

repository permissions become difficult

many teams touching same repo

CI validation can become expensive

merge contention

one bad repository-level permission
affects many applications
```

And the repo can eventually become huge.

---

# 14.468 Polyrepo GitOps

Alternative:

```text
payments-gitops

orders-gitops

analytics-gitops

todo-gitops
```

Each application/team/domain has its own repository.

---

# 14.469 Polyrepo advantages

```text
strong team isolation

simpler permissions

smaller blast radius

independent repository lifecycle

clear ownership
```

---

# 14.470 Polyrepo disadvantages

```text
more repositories

more bootstrap configuration

harder global changes

discoverability problems

standards can drift
```

If you have:

```text
700 services
```

you may end up with:

```text
700 GitOps repositories.
```

That is not automatically better.

---

# 14.471 Which should we choose?

There is no universal answer.

A good guideline:

```text
small / medium team
+
shared platform ownership
→ GitOps monorepo can work very well
```

while:

```text
many independent teams
+
different access boundaries
+
different compliance requirements
→ multiple config repositories
can be cleaner
```

Architecture follows:

```text
ownership
+
security boundary
+
lifecycle
```

not ideology.

---

# 14.472 GitOps repo example for our course

We'll use a structure conceptually like:

```text
todo-gitops/
│
├── apps/
│   │
│   ├── todo-backend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ...
│   │
│   └── todo-frontend/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── ...
│
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── argocd/
    ├── applications/
    └── projects/
```

Later Helm and Kustomize will refine this structure.

---

# 14.473 Environment topology options

Three common patterns:

```text
A.
branch-per-environment


B.
directory-per-environment


C.
repo-per-environment
```

Let's understand all three.

---

# 14.474 Branch-per-environment

Example:

```text
dev branch

staging branch

production branch
```

Flow:

```text
dev
 │
 ▼
merge/cherry-pick
 │
 ▼
staging
 │
 ▼
merge
 │
 ▼
prod
```

Argo Applications:

```yaml
Dev:
  targetRevision: dev

Stage:
  targetRevision: staging

Prod:
  targetRevision: production
```

---

# 14.475 Branch-per-environment strengths

```text
clear environment branch

branch protection per environment

familiar promotion model
```

Production branch can be more protected than Dev.

---

# 14.476 Branch-per-environment problems

The branches begin diverging.

Example:

```text
dev:
commit A B C D E


stage:
commit A B C


prod:
commit A B
```

Now an urgent production fix:

```text
commit X
```

lands in production.

But Dev doesn't have it.

Soon:

```text
dev branch
and
prod branch
```

are different histories requiring merges/cherry-picks.

This can become painful.

---

# 14.477 Configuration drift between branches

You may eventually have:

```text
dev branch:
new NetworkPolicy


stage branch:
old NetworkPolicy


prod branch:
manual hotfix
```

Promotion becomes Git branch-management work rather than simply changing an artifact reference.

This is why many teams prefer:

```text
one branch
+
environment directories.
```

---

# 14.478 Directory-per-environment

Example:

```text
main
│
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
```

All environments live in one Git history.

Argo:

```text
Dev Application
path:
environments/dev


Stage Application
path:
environments/staging


Prod Application
path:
environments/prod
```

---

# 14.479 Why directory-per-environment is attractive

Compare:

```diff
environments/dev/version.yaml

tag: f73ca19


environments/staging/version.yaml

tag: 813cc71


environments/prod/version.yaml

tag: 52ac814
```

A single:

```text
git diff
```

can show environment differences.

No long-lived branches must be reconciled.

---

# 14.480 Promotion becomes a small diff

Dev passes.

Production promotion:

```diff
 environments/prod/version.yaml

- tag: 52ac814
+ tag: f73ca19
```

Very clear.

This is the model we'll generally favor during our course.

---

# 14.481 Repo-per-environment

Another architecture:

```text
todo-dev-config

todo-stage-config

todo-prod-config
```

This gives extremely strong separation.

For example:

```text
production repo

write access:
Production Platform Team only
```

while:

```text
dev repo

write access:
Developers
```

---

# 14.482 When repo-per-environment makes sense

Possibly when:

```text
strict compliance boundary

separate teams

separate Git organizations

different credentials

air-gapped environments

strong audit segregation
```

But operational overhead is much higher.

For most ordinary application teams it may be excessive.

---

# 14.483 Our preferred teaching architecture

For our Todo production project:

```text
APPLICATION REPO

Todo-App-DevOps
```

and:

```text
GITOPS REPO

Todo-App-GitOps
```

Inside GitOps:

```text
main branch

environments/
├── dev/
├── staging/
└── prod/
```

Then later Kustomize will give us:

```text
base/
+
overlays/
```

but don't jump ahead yet.

---

# 14.484 Argo Application mapping

Conceptually:

```text
Todo Dev Application
       │
       ▼
Git repo:
Todo-App-GitOps

branch:
main

path:
environments/dev
```

Staging:

```text
path:
environments/staging
```

Prod:

```text
path:
environments/prod
```

Same repository.

Same branch.

Different desired-state paths.

---

# 14.485 Application source example

Dev:

```yaml
source:
  repoURL: <gitops-repository>
  targetRevision: main
  path: environments/dev
```

Production:

```yaml
source:
  repoURL: <gitops-repository>
  targetRevision: main
  path: environments/prod
```

The `Application` source model allows applications to track different repository paths and revisions, which is what makes these environment structures practical. ([Argo CD][2])

---

# 14.486 Environment configuration should contain differences, not copies

Bad:

```text
dev/deployment.yaml
stage/deployment.yaml
prod/deployment.yaml
```

Three files contain:

```text
300 identical lines
```

plus:

```text
3 different values.
```

Soon:

```text
Dev security fix
```

doesn't get copied to:

```text
Prod.
```

This is configuration duplication.

Later Kustomize/Helm will solve this.

---

# 14.487 Desired structural goal

We want:

```text
COMMON CONFIG
     │
     ▼
BASE
```

and:

```text
ENVIRONMENT DIFFERENCES
     │
     ▼
Dev / Stage / Prod
```

Example differences:

```text
replicas

resource sizing

domain

HPA limits

feature configuration

environment name

image version
```

Common things:

```text
Service name

container port

labels

health probes

security context
```

---

# 14.488 Preview of Kustomize structure

Later:

```text
todo-gitops/
│
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
│
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

Argo CD natively recognizes Kustomize sources, and its documentation supports configuring an Application to render a Kustomize path. ([Argo CD][3])

But Lesson 7 will teach it properly.

---

# 14.489 Promotion should not copy arbitrary YAML

A mature promotion operation should ideally look like:

```text
Artifact:
f73ca19
```

Then update only:

```text
environment's desired artifact reference.
```

Not:

```text
copy dev directory
over production directory.
```

Because Dev and Prod intentionally differ in other ways.

---

# 14.490 Environment differences

Example:

## Dev

```text
replicas:
1

CPU:
100m

domain:
todo-dev.example.com
```

## Staging

```text
replicas:
2

CPU:
250m

domain:
todo-stage.example.com
```

## Prod

```text
replicas:
5

CPU:
500m

domain:
todo.example.com
```

But all three may run:

```text
image:
todo-api:f73ca19
```

The artifact is promoted.

Environment configuration remains environment-specific.

---

# 14.491 Never promote configuration blindly

Bad:

```text
cp -r dev/* prod/
```

Now production accidentally gets:

```text
replicas = 1

dev hostname

debug mode

low resource limit
```

Promotion should answer:

> **Which immutable artifact should this existing environment configuration run?**

---

# 14.492 Promotion stages

A production flow:

```text
Application Commit
       │
       ▼
CI
       │
       ▼
Artifact
       │
       ▼
DEV promotion
       │
       ▼
Dev tests
       │
       ▼
STAGING promotion
       │
       ▼
Integration tests
       │
       ▼
PROD promotion PR
       │
       ▼
Approval
       │
       ▼
Argo Prod
```

---

# 14.493 Don't rebuild at the promotion boundary

Suppose:

```text
Dev test result:
PASS
```

for:

```text
sha256:1111
```

If production deployment rebuilds:

```text
sha256:2222
```

then:

```text
you have never actually
tested production artifact 2222
```

even if both had the same source commit label.

This is why artifact immutability matters.

---

# 14.494 CI responsibilities

Our future Jenkins pipeline should primarily own:

```text
Checkout source

Lint

Unit test

Integration test

SAST

Dependency scan

Build

Container scan

Push immutable artifact

Generate provenance/metadata

Initiate promotion
```

Not:

```text
kubectl apply production
```

---

# 14.495 Argo CD responsibilities

Argo owns:

```text
Observe Git desired state

Render manifests

Diff

Sync

Self-heal

Prune

Report health
```

Permanent rule:

```text
CI
=
produce


GitOps repo
=
declare


Argo
=
reconcile


Kubernetes
=
run
```

---

# 14.496 CI → GitOps integration strategy #1

After creating the artifact, CI directly modifies Dev configuration.

Example conceptual pipeline:

```bash
git clone <gitops-repository>

cd environments/dev

# update image reference

git add .
git commit -m "Deploy todo-api f73ca19 to dev"
git push
```

Argo's CI-automation guide specifically describes this general model: CI can clone the config repository, modify the Kubernetes configuration—such as a Kustomize image reference or plain manifest—and push the change, leaving Argo CD to synchronize it. ([Argo CD][4])

---

# 14.497 Direct CI commit — advantages

For Dev:

```text
fast

simple

fully automated
```

Flow:

```text
CI success
   │
   ▼
modify dev desired state
   │
   ▼
push
   │
   ▼
Argo
```

This is often reasonable for lower environments.

---

# 14.498 Direct CI commit — risk

If the same CI identity can write:

```text
prod/
```

then compromise of the application pipeline could alter production desired state.

Better permissions:

```text
CI Bot
│
├── environments/dev       write
├── environments/staging   PR/create
└── environments/prod      no direct merge
```

Production requires stronger separation.

---

# 14.499 CI → GitOps strategy #2 — pull request

A stronger production model:

```text
CI
 │
 ▼
create GitOps branch
 │
 ▼
update prod image
 │
 ▼
open Pull Request
 │
 ▼
CODEOWNERS review
 │
 ▼
merge
 │
 ▼
Argo
```

Now CI proposes production desired state.

Humans/policy decide whether it becomes authoritative.

---

# 14.500 Why PR-based promotion is powerful

The deployment PR can contain only:

```diff
- image: todo-api@sha256:old
+ image: todo-api@sha256:new
```

Reviewers see exactly what production promotion means.

No 3,000-line Jenkins deployment log required to understand the intended version change.

---

# 14.501 CODEOWNERS

For GitHub-hosted repositories, a `CODEOWNERS` file can automatically request reviews from designated users/teams. Protected branch rules can require Code Owner reviews before merging. ([GitHub Docs][5])

Example concept:

```text
# CODEOWNERS

/environments/dev/       @developers
/environments/staging/   @qa-team @platform
/environments/prod/      @platform @sre-team
/argocd/                  @platform
```

Now the repository itself reflects operational ownership.

---

# 14.502 Branch protection

For production `main`, you might require:

```text
Pull Request

required status checks

approving reviews

Code Owner review

no direct force pushes

restricted administrators
```

GitHub's protected-branch controls support required approvals, status checks, and optional Code Owner review requirements. ([GitHub Docs][6])

Git becomes part of your deployment authorization system.

---

# 14.503 Never give every developer unrestricted GitOps write access

Imagine:

```text
Developer
```

can directly push:

```yaml
kind: ClusterRole
```

to a production GitOps repository.

Argo has auto-sync.

Then:

```text
Git write permission
      │
      ▼
potential Kubernetes
deployment permission
```

Git authorization becomes indirectly equivalent to deployment authorization.

---

# 14.504 Git is now privileged infrastructure

Traditional security review checks:

```text
Kubernetes RBAC
```

But GitOps requires checking:

```text
Who can push?

Who can merge?

Who can approve?

Who controls CODEOWNERS?

Who controls CI bot tokens?

Who controls repository settings?

Who can change Argo Application sources?
```

Because these identities can potentially alter desired production state.

---

# 14.505 Source repository permission ≠ production deployment permission

Ideal:

```text
Developer
    │
    ▼
application repository
    │
    ▼
merge source
```

That does not automatically imply:

```text
Developer
    │
    ▼
production GitOps repo
    │
    ▼
merge desired-state changes
```

These are different privileges.

---

# 14.506 CI bot privilege

CI should need:

```text
ECR push permission
```

and perhaps:

```text
GitOps Dev write permission
```

or:

```text
GitOps PR creation permission
```

It should not need:

```text
EKS cluster-admin
```

for the normal GitOps deployment path.

Argo CD's automated-sync documentation highlights precisely this benefit: CI can make the config change without direct access to Argo CD's deployment API. ([Argo CD][4])

---

# 14.507 Production bot model

Concept:

```text
Jenkins
   │
   ├── ECR Push
   │
   └── GitOps PR Bot
           │
           ▼
       Pull Request
           │
           ▼
      Human Approval
           │
           ▼
          main
           │
           ▼
         Argo
```

This is much safer than:

```text
Jenkins
   │
   ├── AWS Admin
   └── Kubernetes cluster-admin
```

---

# 14.508 Our Todo pipeline evolution

Earlier our deployment pipelines were more like:

```text
Jenkins
   │
   ▼
SSH / PM2 / remote deployment
```

or Kubernetes-style:

```text
Jenkins
   │
   ▼
kubectl
```

Now we're evolving toward:

```text
Jenkins
   │
   ├── test
   ├── scan
   ├── image build
   ├── ECR push
   └── GitOps promotion
             │
             ▼
           Argo CD
             │
             ▼
          Kubernetes
```

That separation will make a strong production architecture later.

---

# 14.509 Example production GitOps repository

Let's design it.

```text
todo-gitops/
│
├── README.md
│
├── CODEOWNERS
│
│
├── applications/
│   ├── todo-backend/
│   └── todo-frontend/
│
├── environments/
│   │
│   ├── dev/
│   │   ├── backend/
│   │   └── frontend/
│   │
│   ├── staging/
│   │   ├── backend/
│   │   └── frontend/
│   │
│   └── prod/
│       ├── backend/
│       └── frontend/
│
└── argocd/
    ├── projects/
    └── applications/
```

This is conceptual.

Lessons 6–7 will determine whether those environment paths use:

```text
Helm
```

or:

```text
Kustomize.
```

---

# 14.510 Environment ownership

Possible ownership map:

```text
Dev
│
└── Developers


Staging
│
├── Developers
└── QA


Production
│
├── Platform
├── SRE
└── Application owner


Argo Configuration
│
└── Platform
```

Then CODEOWNERS mirrors this.

---

# 14.511 Never let environment names become policy assumptions

Do not rely only on:

```text
folder name = prod
```

for security.

Use multiple controls:

```text
Git permissions

CODEOWNERS

AppProject

destination namespace

destination cluster

Kubernetes RBAC

admission policies
```

A malicious or accidental path name should not be enough to bypass production policy.

---

# 14.512 Production AppProject mapping

Later:

```text
Todo Dev Project
```

might allow:

```text
destination:
dev cluster
todo-dev namespace
```

while:

```text
Todo Prod Project
```

allows:

```text
destination:
prod cluster
todo-prod namespace
```

Argo CD Projects provide repository, destination, and Kubernetes-resource restrictions and are specifically designed for logical/multi-team application grouping. ([Argo CD][7])

Git path and Argo policy then reinforce one another.

---

# 14.513 Environment = desired-state instance

Think:

```text
Todo API
```

is an application.

But:

```text
Todo API Dev

Todo API Staging

Todo API Prod
```

are three **deployment instances**.

Each can have:

```text
different namespace

different cluster

different configuration

different artifact version
```

Argo may represent them as separate Applications.

---

# 14.514 Example Argo Applications

```text
todo-backend-dev

todo-backend-staging

todo-backend-prod
```

Each points to its environment configuration.

Later ApplicationSet can generate these rather than writing three nearly identical Application objects manually.

---

# 14.515 Branch tracking vs commit pinning

Argo supports several source revision strategies.

Example:

```yaml
targetRevision: main
```

means the Application follows movement of that branch.

Whereas:

```yaml
targetRevision: a94bf62...
```

pins the Application to one Git commit.

Current Argo CD documentation describes commit pinning as the most restrictive tracking strategy and notes it is commonly useful when tightly controlling production environments. ([Argo CD][8])

---

# 14.516 But don't confuse Git commit pinning with image pinning

Two independent references exist.

```text
ARGO APPLICATION REVISION

Which Git configuration?


CONTAINER IMAGE REFERENCE

Which container artifact?
```

Example:

```text
Argo source:
Git commit 91bd2ee


Deployment manifest:
todo-api@sha256:abc123
```

Both contribute to reproducibility.

---

# 14.517 Production model A — track `main`

Argo Prod:

```yaml
targetRevision: main
path: environments/prod
```

Git:

```text
main branch
```

is strongly protected.

Production promotion:

```text
PR
 ↓
merge
 ↓
Argo sees new main
 ↓
deploy
```

This is simple and powerful.

---

# 14.518 Production model B — pin Git commits

Another model:

```text
Prod Application
       │
       ▼
specific config commit
```

Promotion updates which Git revision Argo tracks.

More controlled, but more operationally complex.

Use this when the additional immutability/approval semantics justify it.

Argo CD's tracking documentation explicitly supports commit-SHA pinning. ([Argo CD][8])

---

# 14.519 Don't use arbitrary mutable remote dependencies

Imagine your GitOps commit says:

```text
use external config:
branch main
```

Tomorrow that external branch changes.

Your GitOps commit didn't.

But rendered desired state changes.

Then:

```text
same Git commit
≠
same desired Kubernetes manifests
```

Argo's best-practice guidance recommends immutable revisions for remote dependencies when reproducibility matters. ([Argo CD][1])

---

# 14.520 GitOps reproducibility equation

Strong reproducibility requires thinking about:

```text
Git config revision

+

Helm chart version

+

Kustomize remote bases

+

container image digest

+

external configuration inputs
```

Any mutable dependency can make:

```text
same Git revision
```

produce:

```text
different output.
```

---

# 14.521 Promotion via image tag

Simplified Dev:

```yaml
image:
  repository: todo-api
  tag: f73ca19
```

Promotion:

```diff
- tag: 52ac814
+ tag: f73ca19
```

Simple.

---

# 14.522 Promotion via digest

More deterministic:

```yaml
image:
  repository: todo-api
  digest: sha256:abc123...
```

Production change:

```diff
- digest: sha256:old...
+ digest: sha256:abc123...
```

Now the exact bytes are explicit.

---

# 14.523 Why semantic versions are still useful

You may want:

```text
v2.3.7
```

for humans.

You can maintain:

```text
semantic tag:
v2.3.7
```

and record:

```text
digest:
sha256:abc...
```

The tag communicates:

```text
release identity.
```

The digest proves:

```text
artifact identity.
```

---

# 14.524 Do not use mutable `latest`

Architecture:

```text
Git:
latest
```

Yesterday:

```text
latest → digest A
```

Today CI pushes:

```text
latest → digest B
```

Git did not change.

Desired configuration text didn't change.

But what runtime image means may have changed.

That's bad GitOps traceability.

---

# 14.525 Promotion metadata

A deployment PR can carry:

```text
Application:
todo-backend

Source commit:
f73ca19

Image digest:
sha256:abc123

CI build:
#914

Current prod:
52ac814

Requested prod:
f73ca19

Security scan:
PASS

Dev:
PASS

Staging:
PASS
```

This turns production promotion into a readable release record.

---

# 14.526 Release PR as change record

Instead of a separate human manually writing:

```text
Change ticket:

Deploy version f73ca19
```

the PR can already contain:

```text
diff

approvals

CI checks

discussion

timestamp

owner
```

Organizations may still require external ITSM/change-ticket integration, but Git can become the technical deployment record.

---

# 14.527 Dev automation

For Dev we can be aggressive:

```text
Source merge
   │
   ▼
CI
   │
   ▼
Image
   │
   ▼
automatic GitOps Dev update
   │
   ▼
Argo Auto-Sync
```

Minimal human involvement.

---

# 14.528 Production automation

Production may instead use:

```text
Validated staging artifact
       │
       ▼
automated PR creation
       │
       ▼
human/policy approval
       │
       ▼
merge
       │
       ▼
Argo auto-sync
```

Notice:

```text
deployment execution
```

is still automatic.

But:

```text
desired-state authorization
```

has a human gate.

---

# 14.529 GitOps approval boundary

This distinction is excellent:

```text
WHO may approve
the desired state?
```

vs:

```text
WHO performs
the deployment?
```

In our architecture:

```text
Reviewers
=
authorize


Argo
=
execute.
```

That separates change authority from deployment mechanics.

---

# 14.530 Manual Argo sync is not the only approval mechanism

Some teams think:

```text
Production safety
=
turn auto-sync off.
```

But you can achieve safe approval through:

```text
protected Git branch

required reviews

CODEOWNERS

policy checks

signed workflows

sync windows
```

and still let Argo automatically reconcile **after approved Git merge**.

That often creates a cleaner control model.

---

# 14.531 Git approval vs Argo manual sync

Model A:

```text
Git PR approved
      │
      ▼
merge
      │
      ▼
Argo manual sync approval
```

Two gates.

Model B:

```text
Git PR approved
      │
      ▼
merge
      │
      ▼
Argo auto-sync
```

One authoritative gate.

Neither is universally correct.

Avoid duplicate approvals that provide no additional risk reduction.

---

# 14.532 Environment promotion should be monotonic conceptually

Ideally:

```text
Dev tested artifact
        │
        ▼
Stage tested same artifact
        │
        ▼
Prod
```

Not:

```text
Prod gets random version
that never existed
in Staging.
```

You can enforce this in CI/promotion tooling later.

---

# 14.533 Promotion validation

Before opening Prod PR, automation can verify:

```text
image digest exists

artifact passed scans

artifact deployed to staging

staging tests passed

version is newer/approved

no unresolved vulnerability exception

required release ticket exists
```

Now GitOps promotion becomes policy-aware.

---

# 14.534 Rollback model

Production:

```text
f73ca19
```

causes errors.

Git history:

```text
Commit A
prod = 52ac814

Commit B
prod = f73ca19
```

Rollback:

```text
git revert Commit B
```

Desired state returns:

```text
prod = 52ac814
```

Argo:

```text
detects Git change
    │
    ▼
rolls workload back
```

---

# 14.535 Rollback record

The Git history now shows:

```text
Commit B:
promote f73ca19

Commit C:
revert f73ca19 due to production errors
```

Better than:

```text
some engineer executed
kubectl set image
```

without Git history.

---

# 14.536 Rollback caveat

Remember from Lesson 4:

```text
Git revert
```

doesn't reverse:

```text
database schema changes

external API side effects

messages already processed

customer data modifications
```

So application releases should support:

```text
backward-compatible migrations

expand-contract patterns

feature flags

safe rollback designs.
```

GitOps improves configuration rollback.

It does not magically make state reversible.

---

# 14.537 Hotfix workflow

Production bug.

Do not:

```text
kubectl edit
```

and forget about Git.

Preferred:

```text
hotfix source commit
       │
       ▼
CI
       │
       ▼
new artifact
       │
       ▼
accelerated GitOps promotion PR
       │
       ▼
approved
       │
       ▼
Argo
```

You can shorten approval time without abandoning the control model.

---

# 14.538 Emergency live fix

Sometimes Git/platform connectivity is itself broken.

Then break-glass may require:

```text
temporarily pause reconciliation

apply live fix

restore service

record emergency action

update Git to match required desired state

resume Argo

verify convergence
```

The essential final step:

```text
LIVE
and
GIT
must be reconciled again.
```

Otherwise the next sync can undo the incident fix.

---

# 14.539 Repository ownership must match application ownership

Suppose:

```text
Payments team
```

owns:

```text
payments service.
```

Then they should have appropriate control over:

```text
payments application configuration
```

but not necessarily:

```text
cluster-wide ingress controller

cert-manager

Argo RBAC

production NetworkPolicies
```

Platform components should have separate ownership.

---

# 14.540 Application repo vs platform repo

A mature organization might have:

```text
workloads-gitops/
```

and:

```text
platform-gitops/
```

Platform GitOps:

```text
Ingress controller

cert-manager

External Secrets

Prometheus

policy engine

Argo configuration
```

Workload GitOps:

```text
Payments

Orders

Todo

Frontend services
```

This helps separate privileges and lifecycles.

---

# 14.541 Control-plane GitOps is higher blast radius

Changing:

```text
todo Deployment
```

might affect one service.

Changing:

```text
Ingress controller
```

might affect the whole cluster.

Changing:

```text
Argo AppProject
```

could change deployment permissions.

Therefore Git repositories/paths should have review controls proportional to blast radius.

Same rule we learned for Terraform.

---

# 14.542 GitOps hierarchy

Think:

```text
Tier 1

Argo / cluster bootstrap
security policy
Ingress
DNS
Secrets operators
```

High blast radius.

```text
Tier 2

shared platform services
```

Medium-high blast radius.

```text
Tier 3

individual application deployment
```

Smaller blast radius.

Not every Git change deserves the same approval policy.

---

# 14.543 Argo Application definitions in Git

Soon our config repo should also contain:

```text
argocd/
│
├── projects/
│   └── todo-project.yaml
│
└── applications/
    ├── todo-dev.yaml
    ├── todo-stage.yaml
    └── todo-prod.yaml
```

Then instead of:

```bash
kubectl apply -f todo-prod.yaml
```

manually forever, we'll bootstrap these declarations through Git.

---

# 14.544 Bootstrapping hierarchy

Eventually:

```text
Bootstrap Application
       │
       ▼
Git
       │
       ▼
ApplicationSet / Applications
       │
       ▼
Workload Applications
       │
       ▼
Kubernetes resources
```

Argo's current cluster-bootstrap documentation recommends ApplicationSet for many common multi-application/multi-cluster bootstrap scenarios. ([Argo CD][9])

We'll reach that later.

---

# 14.545 ApplicationSet and repo structure

Imagine Git:

```text
environments/
├── dev/
├── stage/
└── prod/
```

ApplicationSet can later discover/generate:

```text
todo-dev

todo-stage

todo-prod
```

from patterns rather than maintaining each Application manually.

That is why repository structure isn't cosmetic.

It becomes machine-readable platform metadata.

---

# 14.546 Naming convention

Use consistent names.

Example:

```text
<application>-<environment>
```

such as:

```text
todo-backend-dev

todo-backend-stage

todo-backend-prod
```

Namespaces:

```text
todo-dev

todo-stage

todo-prod
```

Or team/environment:

```text
payments-prod
```

Consistency helps automation.

---

# 14.547 Git directory naming should carry stable meaning

Good:

```text
environments/prod
```

Bad:

```text
environments/new-prod-final-v2
```

Good platform structures survive:

```text
years

teams

automation

ApplicationSet generation

auditing.
```

---

# 14.548 Do not encode everything in filenames

Bad:

```text
todo-backend-prod-ap-south-1-blue-pci-v2.yaml
```

Directory hierarchy often communicates structure more clearly:

```text
clusters/
└── prod-mumbai/
    └── todo-backend/
```

or:

```text
environments/
└── prod/
    └── todo-backend/
```

Choose a hierarchy that reflects your operational model.

---

# 14.549 Cluster-centric repo layout

At multi-cluster scale:

```text
clusters/
│
├── dev-mumbai/
│   ├── platform/
│   └── applications/
│
├── prod-mumbai/
│   ├── platform/
│   └── applications/
│
└── prod-singapore/
    ├── platform/
    └── applications/
```

Useful when:

```text
cluster
```

is the primary operational boundary.

---

# 14.550 Application-centric layout

Alternative:

```text
apps/
│
├── todo/
│   ├── dev/
│   ├── staging/
│   └── prod/
│
├── payments/
│   ├── dev/
│   └── prod/
```

Useful when:

```text
application ownership
```

is the primary perspective.

---

# 14.551 Environment-centric layout

Alternative:

```text
environments/
│
├── dev/
│   ├── todo/
│   └── payments/
│
├── staging/
│   ├── todo/
│   └── payments/
│
└── prod/
    ├── todo/
    └── payments/
```

Useful when:

```text
environment/platform team
```

owns environment changes.

---

# 14.552 Which hierarchy is correct?

There is no single universal directory layout.

Ask:

```text
What is our main ownership boundary?


application?

cluster?

environment?

business unit?
```

Then design paths around that.

The important part is consistency and machine-readability.

---

# 14.553 For our course

We'll favor:

```text
base application configuration

+
environment overlays
```

because it will naturally teach:

```text
Kustomize
```

and later:

```text
ApplicationSet.
```

Conceptually:

```text
todo-gitops/
│
├── apps/
│   ├── backend/
│   └── frontend/
│
└── environments/
    ├── dev/
    ├── stage/
    └── prod/
```

We'll refine that in Lesson 7.

---

# 14.554 GitOps repository README

Production repositories deserve documentation.

Example:

```text
README.md
```

should explain:

```text
directory model

ownership

promotion procedure

rollback procedure

emergency process

image-tag policy

branch protection expectations

Argo Applications

local manifest validation
```

Otherwise future engineers reverse-engineer the platform from folders.

---

# 14.555 Repository validation pipeline

The GitOps repo needs CI too.

Important:

```text
GitOps repository
does not build application binaries.
```

But it should validate configuration.

Potential pipeline:

```text
Pull Request
     │
     ▼
YAML validation
     │
     ▼
render manifests
     │
     ▼
Kubernetes schema validation
     │
     ▼
policy checks
     │
     ▼
security checks
     │
     ▼
PR approval
```

---

# 14.556 GitOps repo CI ≠ application CI

Application CI:

```text
compile
test
build image
scan image
```

GitOps CI:

```text
render
validate
policy-test
review desired-state diff
```

Different pipelines.

---

# 14.557 Desired-state validation

Before merge, detect:

```text
invalid YAML

invalid Kubernetes APIs

missing values

duplicate resource names

forbidden privileged containers

missing resource limits

invalid image references

wrong namespace

dangerous Service type

unapproved ingress
```

Do this before Argo discovers the error in production.

---

# 14.558 Fail left

Bad:

```text
merge
  │
  ▼
Argo
  │
  ▼
Sync Failed
```

Better:

```text
PR
 │
 ▼
validation fails
 │
 X
merge blocked
```

The earlier an error is detected, the cheaper it is.

---

# 14.559 Config repo should never contain plaintext secrets

Bad:

```yaml
kind: Secret

data:
  mongodb-password: ...
```

even if base64 encoded.

Base64:

```text
≠ encryption.
```

We'll dedicate an entire lesson to:

```text
External Secrets

Sealed Secrets

AWS Secrets Manager

Vault
```

For now:

# never commit normal production secret material as plaintext/base64.

---

# 14.560 GitOps secret architecture preview

Instead of:

```text
Git
  │
  └── actual database password
```

we want something like:

```text
Git

ExternalSecret
      │
      ▼
External Secrets Operator
      │
      ▼
AWS Secrets Manager
      │
      ▼
Kubernetes Secret
```

Git stores:

```text
reference/instruction
```

not:

```text
secret value.
```

---

# 14.561 ConfigMap is different

Non-secret configuration may safely live in Git:

```yaml
LOG_LEVEL: info
ENVIRONMENT: prod
API_TIMEOUT: "5"
```

Benefits:

```text
versioned

reviewable

auditable
```

But do not accidentally move credentials into ConfigMaps.

---

# 14.562 Environment configuration example

Dev:

```yaml
environment: dev
logLevel: debug
```

Prod:

```yaml
environment: prod
logLevel: info
```

Those are desired-state differences.

Git is an excellent place to record them.

---

# 14.563 App source should not know deployment secrets

Source code:

```javascript
process.env.MONGODB_URL
```

It should not contain:

```text
mongodb://username:password@prod-database
```

Deployment environment injects configuration.

GitOps controls the reference/integration.

Secret system holds actual sensitive value.

---

# 14.564 GitOps promotion should be deterministic

Suppose CI says:

```text
Deploy build 914.
```

But GitOps script searches:

```text
latest successful image
```

at runtime.

That's ambiguous.

Better:

```text
Build 914
produced digest:
sha256:abc123
```

Then promotion explicitly writes:

```text
sha256:abc123
```

No discovery ambiguity later.

---

# 14.565 Promotion shouldn't depend on "current latest"

Imagine:

```text
Build 914:
good

Build 915:
bad
```

Prod approval is for:

```text
914.
```

But promotion script says:

```text
deploy latest
```

Now 915 reaches production.

Explicit immutable artifact selection prevents this.

---

# 14.566 CI output contract

The CI pipeline should produce metadata:

```text
IMAGE_REPOSITORY

IMAGE_TAG

IMAGE_DIGEST

SOURCE_COMMIT

BUILD_ID

SCAN_RESULT
```

Example:

```text
repository:
123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend

tag:
f73ca19

digest:
sha256:abc123...

source:
f73ca19

build:
914
```

Promotion tooling consumes this contract.

---

# 14.567 CI should not edit YAML with fragile `sed` forever

Beginner pipeline:

```bash
sed -i \
  "s/tag:.*/tag: $IMAGE_TAG/" \
  values.yaml
```

It may work.

But production configuration automation should prefer configuration-aware tools where possible:

```text
Kustomize commands

Helm values tooling

YAML-aware tools

purpose-built promotion automation
```

because blind text replacement can modify unintended text.

Argo's CI automation documentation illustrates Kustomize-aware image updates as one supported pattern. ([Argo CD][4])

---

# 14.568 Example Kustomize promotion preview

Later:

```bash
kustomize edit set image \
  todo-api=123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-api:f73ca19
```

Then:

```bash
git diff
```

shows the exact desired-state change.

We'll learn this properly in Lesson 7.

---

# 14.569 GitOps commit messages

Don't use:

```text
update
```

Better:

```text
Deploy todo-backend f73ca19 to dev
```

Production:

```text
Promote todo-backend f73ca19 to production
```

Rollback:

```text
Rollback todo-backend to 52ac814 after INC-482
```

Git history becomes operations history.

---

# 14.570 Promotion commit should identify environment

Good:

```text
Promote payments-api v2.7.4 to prod
```

Not:

```text
update image
```

At 3 AM during an incident, clarity matters.

---

# 14.571 Don't mix unrelated promotions in one PR unnecessarily

Bad production PR:

```text
Todo v42

Payments v80

cert-manager upgrade

NetworkPolicy refactor

Prometheus upgrade
```

If deployment breaks:

```text
which change caused it?
```

Prefer coherent change units.

---

# 14.572 Atomic multi-service changes can still be useful

Sometimes:

```text
frontend v2

backend v2
```

must deploy together because of compatibility.

Then one GitOps PR may intentionally change both.

The key is:

```text
coherent lifecycle.
```

Not:

```text
one file per PR no matter what.
```

---

# 14.573 API compatibility reduces deployment coupling

Better architecture:

```text
Backend v2
supports Frontend v1 + v2
```

Then:

```text
backend promotion
```

and:

```text
frontend promotion
```

can be independent.

GitOps encourages thinking explicitly about deployment units and compatibility.

---

# 14.574 Pull request preview

Imagine production PR:

```diff
 environments/prod/todo-backend/image.yaml

- tag: 52ac814
+ tag: f73ca19
```

Reviewer sees:

```text
One application
One environment
One artifact change
```

This is excellent release clarity.

---

# 14.575 PR checks

The GitOps PR could require:

```text
Manifest render          ✓
Kubernetes schema        ✓
Security policy          ✓
Image exists             ✓
Image scan               ✓
Dev promotion            ✓
Stage promotion          ✓
CODEOWNERS approval      ✓
```

Only then merge.

---

# 14.576 Production deployment starts with merge

Under auto-sync:

```text
Merge
  │
  ▼
Git main changed
  │
  ▼
Argo repository refresh
  │
  ▼
OutOfSync
  │
  ▼
Auto-sync
```

So:

```text
merge button
```

is effectively a controlled deployment trigger.

Treat it accordingly.

---

# 14.577 GitOps change window

Combine Lesson 4:

```text
Production PR merged
        │
        ▼
Argo wants to sync
        │
        ▼
AppProject Sync Window
        │
   ┌────┴────┐
   ▼         ▼
Allowed     Denied
   │          │
   ▼          ▼
Deploy       Wait
```

Now Git authorization and deployment scheduling are separate controls.

---

# 14.578 Environment promotion architecture

Final model:

```text
                        SOURCE CODE
                            │
                            ▼
                           CI
                            │
                  ┌─────────┼─────────┐
                  ▼         ▼         ▼
                Test       Scan      Build
                                      │
                                      ▼
                                     ECR
                                      │
                                immutable image
                                      │
                                      ▼
                              DEV CONFIG UPDATE
                                      │
                                      ▼
                                   Argo Dev
                                      │
                                      ▼
                                  Dev Tests
                                      │
                                      ▼
                             STAGING CONFIG PR
                                      │
                                      ▼
                                 Argo Stage
                                      │
                                      ▼
                               Stage Validation
                                      │
                                      ▼
                              PRODUCTION PR
                                      │
                                CODEOWNERS
                                      │
                                      ▼
                                    Merge
                                      │
                                      ▼
                                Argo Prod
```

That's our production GitOps promotion pipeline.

---

# 14.579 CI failure scenario

Code:

```text
f73ca19
```

Tests fail.

What happens?

```text
CI
 X
```

No approved artifact.

No config change.

No Argo deployment.

Production continues running:

```text
old artifact.
```

Correct.

---

# 14.580 Image scan failure

Artifact builds.

Vulnerability gate fails.

Do not update:

```text
environments/dev
```

or at minimum do not promote further according to your policy.

GitOps desired state should reflect artifacts that passed required release controls.

---

# 14.581 Config validation failure

Application CI passes.

Artifact is good.

But GitOps PR contains:

```yaml
resources:
  requests:
    cpu: pineapple
```

Config validation fails.

Therefore:

```text
artifact valid

desired deployment config invalid
```

Two different pipelines caught two different failure domains.

---

# 14.582 Argo sync failure

GitOps PR passed validation.

Argo attempts deployment.

Admission webhook rejects resource.

Now:

```text
Application CI       ✓

GitOps CI            ✓

Git desired state    ✓

Argo Sync            ✕
```

Investigate:

```text
runtime/admission difference.
```

That's why production still needs Argo monitoring.

---

# 14.583 Application health failure

Argo successfully syncs.

Pods crash.

Now:

```text
Build       ✓
GitOps PR   ✓
Sync        ✓
Health      ✕
```

Use our:

```text
G-R-D-S-H-A
```

troubleshooting model.

---

# 14.584 Production promotion metrics

A mature platform could track:

```text
Build success rate

Dev promotion success rate

Stage promotion success rate

Production deployment frequency

Lead time from artifact → prod

Failed sync rate

Rollback frequency

Change failure rate

Time OutOfSync
```

These become DevOps/SRE delivery metrics.

---

# 14.585 Promotion latency

Suppose:

```text
build completed:
10:00
```

Dev deployed:

```text
10:03
```

Stage:

```text
10:20
```

Production:

```text
14:30
```

You can measure:

```text
artifact-to-prod lead time.
```

Git provides excellent timestamps for promotion analysis.

---

# 14.586 GitOps repo itself needs backup/recovery

If:

```text
production desired state
```

lives in Git, then Git is Tier-0/Tier-1 control-plane infrastructure.

Consider:

```text
repository backup

provider availability

organization recovery

access-key recovery

branch-protection recovery

mirror strategy where appropriate
```

A lost GitOps repository is a control-plane disaster, even though currently running Pods may continue.

---

# 14.587 Git outage scenario

Git becomes unavailable.

Existing Pods:

```text
continue.
```

Argo:

```text
cannot fetch desired-state changes.
```

Potential implications:

```text
no new deployments

reconciliation may degrade

manifest refresh errors
```

Git availability is a CD SLO dependency.

---

# 14.588 Argo outage scenario

Git available.

Argo down.

Existing workloads:

```text
continue.
```

But:

```text
promotion does not reconcile

drift correction stops
```

Git history remains intact.

---

# 14.589 CI outage scenario

CI down.

No new artifacts.

Existing Git desired state remains.

Argo continues reconciling the already-declared state.

This separation of:

```text
CI

Git

Argo

Kubernetes
```

reduces failure coupling.

---

# 14.590 Git compromise scenario

Attacker compromises a production config token.

Changes:

```yaml
image: malicious-image
```

If they can merge directly:

```text
Git
 ↓
Argo
 ↓
Production
```

Git compromise becomes cluster deployment compromise.

Therefore:

```text
no uncontrolled production tokens

protected branch

least privilege

CODEOWNERS

audit

MFA
```

are mandatory engineering concerns.

---

# 14.591 CI compromise scenario

If CI can only:

```text
push ECR
+
open GitOps PR
```

but cannot:

```text
merge production
```

then compromise is serious—but production still has an approval boundary.

Compare with CI having:

```text
cluster-admin.
```

The GitOps architecture reduces direct blast radius.

---

# 14.592 Don't allow CI to rewrite CODEOWNERS

If a bot can change:

```text
CODEOWNERS
```

and then use that change to remove required reviewers, you may undermine the protection model.

Repository governance files themselves deserve protected ownership.

GitHub's CODEOWNERS protections depend on repository/branch-protection configuration, so ownership of those files and protected branches matters. ([GitHub Docs][5])

---

# 14.593 Never store deployment credentials in Git

Git should contain:

```text
desired state.
```

Not:

```text
Argo password

EKS token

AWS secret key

Git private key

database password
```

Credentials belong in dedicated secret-management/integration mechanisms.

---

# 14.594 Private Git repositories

Later our Argo instance will need authorization to read:

```text
private GitOps repository.
```

Argo's declarative setup stores repository configuration/credentials using appropriately labeled Kubernetes Secrets and supports repository credential mechanisms depending on the Git transport/provider. ([Argo CD][2])

We'll configure that securely later.

---

# 14.595 Argo should preferably have read access to Git

Think about responsibility:

```text
Argo
=
reads desired state.
```

Does Argo need:

```text
write access
```

to your GitOps repository for normal reconciliation?

Usually:

```text
NO.
```

A read-only Git credential greatly limits blast radius.

Promotion/CI automation uses separate write credentials.

---

# 14.596 Separation of Git identities

Ideal:

```text
Argo Credential
=
READ


CI Dev Promotion Credential
=
WRITE DEV


Promotion Bot
=
CREATE PR


Humans
=
REVIEW / MERGE
```

Do not give one Git PAT:

```text
everything everywhere.
```

Least privilege applies to Git too.

---

# 14.597 Repository source trust

AppProject can restrict:

```text
which Git repositories
applications may use.
```

This prevents a team from creating:

```yaml
repoURL: attacker.example/repository
```

and convincing privileged Argo to deploy from it.

Projects explicitly support source-repository restrictions. ([Argo CD][7])

---

# 14.598 Production source allowlist

Example concept:

```text
TodoProject

Allowed source:

company/todo-gitops
```

Not:

```text
*
```

Then even if someone modifies an Application:

```text
repoURL
```

Argo Project policy restricts where it can source desired state.

---

# 14.599 Production destination allowlist

Similarly:

```text
TodoDevProject

allowed:
todo-dev namespace
```

and:

```text
TodoProdProject

allowed:
todo-prod namespace
```

not:

```text
kube-system

argocd

all namespaces.
```

AppProjects provide these destination controls. ([Argo CD][7])

---

# 14.600 Git path doesn't replace AppProject

Even if:

```text
environments/dev/
```

is supposed to be Dev, you still want:

```text
AppProject:
can only deploy to Dev
```

Defense in depth:

```text
Repo Path

+
Git Review

+
Argo Project

+
Kubernetes RBAC
```

---

# 14.601 Repo design anti-pattern #1

```text
source code
+
Kubernetes config
+
production secrets
+
Terraform
+
Argo config
+
database migrations
+
everything company-wide
```

inside one giant repository.

Technically possible.

Operationally often produces:

```text
confusing ownership
massive CI
broad permissions
high blast radius.
```

Group things by coherent lifecycle.

---

# 14.602 Anti-pattern #2 — environment branches with unmanaged divergence

```text
dev
staging
prod
```

but nobody routinely reconciles them.

Six months later:

```text
Prod
has security fix Dev lacks.

Dev
has NetworkPolicy Prod lacks.

Stage
has random hotfix.
```

Your branch model became config drift in Git itself.

---

# 14.603 Anti-pattern #3 — mutable image tags

```yaml
image: todo:latest
```

destroys deterministic promotion.

---

# 14.604 Anti-pattern #4 — CI directly edits production main

```text
Jenkins
   │
   ▼
git push main
   │
   ▼
Argo Prod
```

with no review.

This may be acceptable for specific highly automated environments, but it must be an intentional risk decision—not an accidental pipeline shortcut.

---

# 14.605 Anti-pattern #5 — rebuild for production

```text
Stage tested digest A

Prod rebuilt digest B
```

Defeats artifact promotion integrity.

---

# 14.606 Anti-pattern #6 — source and desired state are coupled to runtime imperative commands

Example:

```text
Git contains desired YAML

BUT

Jenkins still runs:
kubectl patch...
helm upgrade...
kubectl scale...
```

Now two deployment authorities exist.

A real GitOps transition requires eliminating unnecessary imperative deployment paths.

---

# 14.607 Anti-pattern #7 — every environment contains full copies

```text
10 services
×
3 environments
×
1000 lines YAML
```

= 30,000 duplicated lines.

Future Helm/Kustomize lessons will reduce this.

---

# 14.608 Anti-pattern #8 — one config repo for unrelated security domains

Suppose:

```text
external vendor
```

needs write access to one app.

Do not make that require write access to:

```text
all company production manifests.
```

Repository architecture should support your security boundaries.

---

# 14.609 Anti-pattern #9 — no ownership information

Production directory:

```text
/environments/prod/payments
```

Nobody knows:

```text
who approves?

who owns service?

who gets paged?

who can rollback?
```

CODEOWNERS and repository documentation can make this explicit.

---

# 14.610 Anti-pattern #10 — promotion updates more than artifact

Suppose promotion bot changes:

```text
image version

replicas

CPU

Ingress

NetworkPolicy
```

all automatically.

That isn't simply artifact promotion anymore.

Separate:

```text
release promotion
```

from:

```text
configuration changes
```

unless the combined change is intentional.

---

# 14.611 Configuration change lifecycle

Example:

```text
Prod CPU:
500m → 1 CPU
```

This should have its own PR:

```text
Increase todo-backend CPU
for sustained load
```

It isn't necessarily tied to a new application artifact.

---

# 14.612 Artifact promotion lifecycle

Separate PR:

```text
todo-backend
f73ca19 → c52e918
```

Now:

```text
application release
```

and:

```text
platform sizing change
```

have separate audit history.

---

# 14.613 Feature flags

Some product changes should not require:

```text
new image
```

if feature flags are externalized.

But carefully determine whether flags belong in:

```text
Git configuration

dedicated feature flag platform

external config service.
```

Rapidly changing runtime feature flags may not always belong in GitOps if they require second-by-second operational changes.

GitOps is not a mandate to put every possible knob in Git.

---

# 14.614 Repository granularity mental model

Ask:

```text
Who owns the change?

How often does it change?

How risky is the change?

Who must approve it?

Does it deploy together?

Does it need separate access?
```

Those answers determine:

```text
repo

directory

Application

AppProject

state ownership.
```

---

# 14.615 Our production GitOps contract

For this course, we'll adopt:

```text
Source Repo
=
application development


ECR
=
immutable artifact storage


GitOps Repo
=
environment desired state


Jenkins
=
artifact creation
and promotion initiation


Argo CD
=
desired/live reconciliation


Kubernetes
=
runtime
```

That contract should be crystal clear.

---

# 14.616 Practical repository creation exercise

Conceptually, when you create your own repo, initialize something like:

```bash
mkdir -p todo-gitops
cd todo-gitops

mkdir -p \
  applications/todo-backend \
  applications/todo-frontend \
  environments/dev \
  environments/staging \
  environments/prod \
  argocd/applications \
  argocd/projects
```

Then:

```bash
touch README.md
touch CODEOWNERS
```

We will populate the actual Kubernetes configuration in upcoming lessons.

---

# 14.617 Basic README concept

```text
# Todo GitOps

This repository defines the desired Kubernetes state
for Todo application environments.

Environment paths:

- environments/dev
- environments/staging
- environments/prod

Application source repository:
Todo-App-DevOps

Production changes:
Pull request + required review

Artifact policy:
Immutable image tags/digests only
```

Simple but valuable.

---

# 14.618 CODEOWNERS concept

```text
# Application configs

/environments/dev/       @todo-developers
/environments/staging/   @todo-team @qa-team
/environments/prod/      @platform-team @sre-team

# Argo control plane

/argocd/                  @platform-team
```

On GitHub, CODEOWNERS can automatically request relevant reviews, and protected branches can be configured to require those reviews before merge. ([GitHub Docs][5])

---

# 14.619 GitOps repository CI concept

Later:

```text
GitOps PR
   │
   ▼
yamllint
   │
   ▼
render
   │
   ▼
schema validation
   │
   ▼
policy validation
   │
   ▼
security checks
   │
   ▼
approval
```

Not:

```text
docker build.
```

That's application-source CI.

---

# 14.620 CI-generated Dev promotion

Future Jenkins logic:

```text
Build image:
f73ca19
       │
       ▼
clone GitOps repo
       │
       ▼
update Dev image
       │
       ▼
commit
       │
       ▼
push
       │
       ▼
Argo Dev
```

Argo CD's official CI-automation flow explicitly supports this model of CI updating the desired manifest repository and relying on Argo auto-sync rather than directly calling Kubernetes. ([Argo CD][4])

---

# 14.621 Production promotion bot

Future automation:

```text
Stage tests
    │
    ▼
PASS
    │
    ▼
Bot creates branch

promote/todo-f73ca19
    │
    ▼
modify prod desired state
    │
    ▼
open PR
```

Bot stops.

Humans/policy approve.

This is a very clean privilege boundary.

---

# 14.622 Production deployment without CI Kubernetes credentials

Important architecture:

```text
Jenkins
   │
   ▼
Git
```

does not require:

```text
Jenkins
   │
   ▼
Kubernetes API.
```

Argo has the deployment authority.

This is one of the major operational benefits called out in Argo's automated-sync/CI integration guidance. ([Argo CD][4])

---

# 14.623 GitOps repository promotion flow

```text
                    ECR

             todo:f73ca19
                    │
                    ▼

              CONFIG REPO
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼

      DEV         STAGING       PROD

 f73ca19       f73ca19       52ac814
       │            │            │
       ▼            ▼            │
     Argo          Argo          │
       │            │            │
       ▼            ▼            │
     PASS          PASS           │
                                  ▼
                           Promotion PR
                                  │
                                  ▼
                              f73ca19
                                  │
                                  ▼
                               Argo Prod
```

One artifact.

Three desired-state references.

---

# 14.624 Promotion is a state transition

Think:

```text
Artifact lifecycle

BUILT
   ↓
DEV_APPROVED
   ↓
STAGE_APPROVED
   ↓
PROD_APPROVED
```

Git history can represent those transitions.

Later platform tooling could automate this state machine.

---

# 14.625 Deployment frequency becomes independent from build frequency

You might build:

```text
30 commits/day.
```

But production may promote:

```text
3 releases/day.
```

GitOps config history clearly shows:

```text
which artifacts crossed
the production boundary.
```

This separation is operationally valuable.

---

# 14.626 Candidate artifacts vs deployed artifacts

ECR may contain:

```text
100 images.
```

Git production configuration references:

```text
one image.
```

Not every built artifact becomes a release.

GitOps tells us:

```text
what has actually been selected
for an environment.
```

---

# 14.627 Garbage collection

Container registry may eventually remove:

```text
unreferenced old images.
```

But before cleanup ensure rollback requirements.

If Git history says:

```text
rollback to digest abc
```

but registry lifecycle already deleted digest abc:

```text
rollback fails.
```

Artifact retention should align with deployment/rollback policy.

---

# 14.628 Production image retention

Example policy concept:

```text
Keep:
current production

previous N production versions

active staging

recent builds

incident/legal holds
```

Not simply:

```text
delete everything older than seven days
```

without considering rollback.

---

# 14.629 Git history alone isn't enough for rollback

Git can say:

```text
previous image:
sha256:abc
```

but ECR must still contain:

```text
sha256:abc.
```

Rollback requires:

```text
desired-state history
+
artifact availability.
```

---

# 14.630 Production deployment integrity chain

For strong delivery security:

```text
Source Commit
     │
     ▼
CI Identity
     │
     ▼
Artifact
     │
     ▼
Digest / signature
     │
     ▼
GitOps PR
     │
     ▼
Approval
     │
     ▼
Argo
     │
     ▼
Admission Policy
     │
     ▼
Runtime
```

Later DevSecOps/GitOps integration can verify image signatures and provenance.

---

# 14.631 GitOps promotion is not necessarily Git branching

Important:

```text
promotion
```

is a business/technical concept.

You can implement it with:

```text
directory update

branch merge

repository PR

Application revision update
```

Don't confuse:

```text
promotion
```

with one Git mechanism.

---

# 14.632 Directory model gives clear promotion diffs

Example:

```text
main
│
├── dev/version
│      f73ca19
│
├── staging/version
│      f73ca19
│
└── prod/version
       52ac814
```

Production promotion:

```diff
prod/version

- 52ac814
+ f73ca19
```

Simple.

---

# 14.633 GitOps desired state should be human-reviewable

Avoid generating configuration so opaque that a reviewer cannot tell:

```text
what production will change.
```

Even when using templating, your CI should provide rendered output/diffs.

The human review boundary must remain meaningful.

---

# 14.634 Template complexity trap

Bad architecture:

```text
one 4,000-line Helm values inheritance system
+
12 layers
+
remote templates
```

where nobody can predict output.

GitOps requires declarative configuration.

It also benefits from **understandable** configuration.

---

# 14.635 Kustomize vs Helm preview

Kustomize:

```text
base
+
patches/overlays
```

Helm:

```text
template
+
values
```

Both can solve environment differences.

Argo supports both natively.

We'll dedicate:

```text
Lesson 6 → Helm

Lesson 7 → Kustomize
```

then compare them.

---

# 14.636 Production promotion interview question

### What does "promote an artifact" mean in GitOps?

Strong answer:

> **CI builds an immutable artifact once and stores it in a registry. Promotion changes the desired configuration for a subsequent environment to reference that same artifact, usually through a Git change or PR. Argo CD then reconciles that environment to the promoted artifact. The artifact should not normally be rebuilt for each environment.**

---

# 14.637 Interview — Why separate app source and deployment config?

Strong answer:

> **Because they have different lifecycles, permissions, audit histories, and CI behavior. The source repository produces application artifacts, while the GitOps repository records environment-specific desired deployment state. Argo CD itself recommends using a separate manifest/configuration repository in many cases.** ([Argo CD][1])

---

# 14.638 Interview — monorepo or polyrepo?

Good answer:

> It depends on ownership and security boundaries. A GitOps monorepo simplifies discovery and global changes but has a larger permission and blast-radius surface. Multiple GitOps repositories improve team isolation and independent lifecycles but increase repository-management overhead. I choose the boundary based on ownership, access control, lifecycle, and compliance rather than treating either pattern as universally correct.

---

# 14.639 Interview — branch per environment or directory per environment?

Strong answer:

> Both work. Branch-per-environment gives strong branch-level separation but can create long-lived branch divergence and difficult promotions. Directory-per-environment keeps all environment desired states in one Git history and usually makes environment diffs and promotion PRs straightforward. For many teams I prefer a protected main branch with environment directories unless stronger repository/branch isolation is required.

---

# 14.640 Interview — Why avoid `latest`?

```text
Git doesn't change

but artifact behind latest can.
```

That breaks strong desired-state reproducibility.

Use:

```text
immutable tag
or
digest.
```

---

# 14.641 Interview — Why build once?

Strong answer:

> Because the artifact tested in Dev/Staging should ideally be exactly the artifact deployed to Production. Rebuilding introduces the possibility that dependency resolution, base images, build environment, timestamps, or other external inputs produce a different artifact.

---

# 14.642 Interview — should CI have production kubeconfig?

In a well-designed Argo CD GitOps flow:

```text
normally not required.
```

CI can:

```text
build image

push image

update Git desired state
```

while Argo holds Kubernetes deployment authority. Argo's CI integration guidance explicitly supports this separation. ([Argo CD][4])

---

# 14.643 Interview — how do you control production deployment approval with auto-sync?

Answer:

```text
protected production Git path/branch

required PR

CODEOWNERS

required checks

optional Sync Windows

then Argo auto-sync
after approved merge.
```

GitHub protected branches can require approvals/status checks and Code Owner reviews. ([GitHub Docs][5])

---

# 14.644 Interview — why can't Argo simply write the new image to Git?

You *can* build systems that write Git automatically.

But for normal Argo CD reconciliation:

```text
Argo
=
consumer of desired state.
```

Keeping it read-only separates:

```text
desired-state creation
```

from:

```text
desired-state execution.
```

Promotion tools/CI can own Git writes.

---

# 14.645 Interview — what happens if GitOps repo is unavailable?

Existing Kubernetes workloads generally continue operating because Git/Argo are control-plane components, not the application request data path.

However:

```text
new desired-state changes

fresh rendering

normal reconciliation
```

can be affected.

Therefore Git availability/recovery is part of your deployment control-plane architecture.

---

# 14.646 Interview — GitOps rollback

Answer:

```text
revert desired-state change
       │
       ▼
Git returns to
previous artifact/config
       │
       ▼
Argo reconciles
```

But mention:

> Application/database side effects may require additional rollback or roll-forward procedures.

That's a senior-level answer.

---

# 14.647 Production repository safety checklist

Before calling your GitOps repository production-ready:

```text
□ Separate application and config ownership understood

□ Production branch protected

□ Direct push restricted

□ CODEOWNERS configured

□ Required reviews configured

□ CI validation configured

□ Secrets excluded

□ Immutable image references

□ Clear Dev/Stage/Prod model

□ Promotion process documented

□ Rollback process documented

□ Emergency process documented

□ Argo read credentials least-privileged

□ CI Git credentials least-privileged

□ AppProject source restrictions

□ AppProject destination restrictions

□ Repository backup/recovery considered
```

---

# 14.648 GitOps promotion safety checklist

Every production promotion should answer:

```text
WHAT artifact?

WHO built it?

FROM which source commit?

WHAT image digest?

DID Dev pass?

DID Stage pass?

DID scans pass?

WHO approved production?

WHAT will Git change?

CAN we rollback?

IS previous artifact retained?
```

If those answers are easy, your deployment platform is mature.

---

# 14.649 Complete Todo production architecture

```text
                      DEVELOPER
                          │
                          ▼
                 Todo-App-DevOps
                    Source Repo
                          │
                          ▼
                       Jenkins
                          │
           ┌──────────────┼───────────────┐
           ▼              ▼               ▼
         Tests          Security         Build
                                         │
                                         ▼
                                        ECR
                                         │
                            todo-api:f73ca19
                                         │
                                         ▼
                               Todo-App-GitOps
                                         │
                   ┌─────────────────────┼─────────────────────┐
                   ▼                     ▼                     ▼

                  DEV                 STAGING                 PROD

              f73ca19                f73ca19                52ac814
                   │                     │                     │
                   ▼                     ▼                     │
               Argo Dev              Argo Stage               │
                   │                     │                     │
                   ▼                     ▼                     │
                 Tests                Tests                   │
                                           ┌───────────────────┘
                                           ▼
                                     Promotion PR
                                           │
                                     CODEOWNERS
                                           │
                                           ▼
                                         Merge
                                           │
                                           ▼
                                      Prod = f73ca19
                                           │
                                           ▼
                                        Argo Prod
                                           │
                                           ▼
                                      Kubernetes
```

This is the production GitOps delivery model we will continue building.

---

# 14.650 Never-forget Lesson 5 rules

```text
1.
Application source
and deployment desired state
are different lifecycle objects.


2.
Separate source/config repositories
often improve permissions and auditability.


3.
CI produces artifacts.


4.
GitOps declares deployment selection.


5.
Argo reconciles deployment.


6.
Build once.


7.
Promote the same artifact.


8.
Do not rebuild separately
for Production.


9.
Use immutable tags or digests.


10.
Avoid latest.


11.
Promotion is a desired-state change.


12.
Dev, Stage and Prod can run
different versions.


13.
Production promotion should be
a small reviewable diff.


14.
Monorepo vs polyrepo depends
on ownership and security.


15.
Branch-per-environment can
create long-lived divergence.


16.
Directory-per-environment gives
simple environment comparison.


17.
Repo-per-environment gives stronger
separation but more overhead.


18.
Git write access becomes
deployment authority.


19.
Production branch protection matters.


20.
CODEOWNERS creates
ownership-aware reviews.


21.
CI does not need routine
production Kubernetes credentials.


22.
Argo should normally need
read access to Git, not write.


23.
GitOps repo deserves its own CI.


24.
GitOps CI renders/validates config;
application CI builds software.


25.
Do not commit plaintext secrets.


26.
Keep release changes separate
from unrelated configuration changes.


27.
Git revert can drive deployment rollback.


28.
Artifact retention must support rollback.


29.
Git itself is production
control-plane infrastructure.


30.
Repository structure should mirror
ownership and operational boundaries.
```

---

# 14.651 Lesson 5 final mental model

```text
                  APPLICATION SOURCE

                        CODE
                         │
                         ▼
                         CI
                         │
                    BUILD ONCE
                         │
                         ▼
                  IMMUTABLE IMAGE
                         │
                         ▼
                    REGISTRY/ECR
                         │
                         ▼

                   GITOPS REPOSITORY

                  DECLARED DEPLOYMENT
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼

       DEV             STAGING           PROD

        │                │                │
        ▼                ▼                ▼
      Argo             Argo             Argo
        │                │                │
        ▼                ▼                ▼

                  KUBERNETES RUNTIME
```

And the permanent sentence:

> **CI builds once. Git selects what runs where. Argo reconciles that selection.**

---

# ✅ Module 14 — Lesson 5 Complete

You now understand:

```text
✓ Application repo vs GitOps repo

✓ Why Argo recommends separation

✓ Source ownership vs deployment ownership

✓ Monorepo

✓ Polyrepo

✓ Branch-per-environment

✓ Directory-per-environment

✓ Repo-per-environment

✓ Dev/Stage/Prod design

✓ Build once / promote many

✓ Immutable image tags

✓ Image digests

✓ Source → image → config traceability

✓ CI → GitOps workflow

✓ PR-based promotion

✓ CODEOWNERS

✓ protected branches

✓ CI bot permissions

✓ Argo Git permissions

✓ GitOps repository CI

✓ release promotion

✓ rollback

✓ hotfixes

✓ emergency reconciliation

✓ Git control-plane security

✓ production Todo GitOps architecture
```

# Next — Module 14, Lesson 6

## Helm + Argo CD — Production Helm GitOps Deep Dive

Next we'll solve the first major configuration-reuse problem.

Instead of maintaining repeated manifests:

```text
deployment-dev.yaml

deployment-stage.yaml

deployment-prod.yaml
```

we'll build:

```text
                    HELM CHART
                        │
                templates/
                        │
              ┌─────────┼─────────┐
              ▼         ▼         ▼

         values-dev  values-stage  values-prod
              │         │            │
              ▼         ▼            ▼

             DEV      STAGING        PROD
```

We'll go deeply into:

```text
Chart.yaml

templates/

values.yaml

values-dev.yaml

values-prod.yaml

Helm rendering

Argo's repo-server Helm behavior

value precedence

parameters

releaseName

chart from Git vs Helm repository

OCI Helm charts

private Helm repositories

immutable chart versions

image promotion

multi-source Helm values

CRDs

hooks

Helm vs Argo lifecycle

why Argo uses Helm mainly as a template renderer

production repository patterns

common Helm/Argo OutOfSync problems

troubleshooting rendered manifests
```

and we'll convert our Todo application into a reusable **Helm-based GitOps deployment model**.

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/?utm_source=chatgpt.com "Best Practices - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/?utm_source=chatgpt.com "Kustomize - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/?utm_source=chatgpt.com "Automation from CI Pipelines - Argo CD - Read the Docs"
[5]: https://docs.github.com/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners?utm_source=chatgpt.com "About code owners"
[6]: https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches?utm_source=chatgpt.com "About protected branches"
[7]: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/?utm_source=chatgpt.com "Projects - Argo CD - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/latest/user-guide/tracking_strategies/?utm_source=chatgpt.com "Tracking and Deployment Strategies - Argo CD - Read the Docs"
[9]: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/?utm_source=chatgpt.com "Cluster Bootstrapping - Declarative GitOps CD for Kubernetes"
