# Module 14 — GitOps with Argo CD

## Lesson 14.13 — AppProject, RBAC, Multi-Team Security & Production Access Control

In the previous lessons, we made Argo CD capable of:

```text
Git change
   ↓
Auto Sync
   ↓
Kubernetes

Cluster drift
   ↓
Self Heal
   ↓
Git state restored

Resource removed from Git
   ↓
Prune
```

That creates a powerful deployment system.

But power creates another question:

> **Who is allowed to use that power?**

Imagine a company with:

```text
                    COMPANY

                       │
              ┌────────┼────────┐
              │        │        │
              ▼        ▼        ▼

          Team A     Team B   Platform

           Todo      Payment    Infra
            App        App

              │        │        │
              └────────┼────────┘
                       ▼

                     Argo CD

                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼

            DEV     STAGING     PROD
```

Without proper controls, Team A could potentially deploy into Team B's namespace or production infrastructure.

We need boundaries.

Argo CD provides two major mechanisms:

```text
AppProject
     +
RBAC
```

An `AppProject` controls **what applications are permitted to do**, including which source repositories they may use, which clusters/namespaces they may target, which Kubernetes resource kinds they may deploy, and project-specific roles. ([Argo CD][1])

---

# 1. First mental model: Application vs AppProject

Until now, we mostly thought about:

```yaml
kind: Application
```

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: todo-production

spec:
  source:
    repoURL: ...
    path: ...

  destination:
    namespace: todo-production
```

An Application answers:

```text
WHAT should be deployed?

FROM where?

TO where?
```

An `AppProject` asks:

```text
ARE YOU ALLOWED
to do that?
```

So:

```text
Application
     │
     │ asks
     ▼
AppProject
     │
     │ checks policy
     ▼
Allowed / Denied
```

---

# 2. Think of AppProject as a security boundary

Suppose Team Todo owns:

```text
Git repository:

company/todo-gitops
```

and may deploy only into:

```text
todo-dev
todo-staging
todo-production
```

They should **not** deploy into:

```text
payment-production
kube-system
argocd
monitoring
```

So we create:

```text
AppProject: todo-team
```

Conceptually:

```text
                 AppProject: todo-team

        ┌────────────────────────────────┐
        │                                │
        │ Allowed Git Repository         │
        │                                │
        │ company/todo-gitops            │
        │                                │
        ├────────────────────────────────┤
        │                                │
        │ Allowed Namespaces             │
        │                                │
        │ todo-dev                       │
        │ todo-staging                   │
        │ todo-production                │
        │                                │
        ├────────────────────────────────┤
        │                                │
        │ Allowed Resources              │
        │                                │
        │ Deployment                     │
        │ Service                        │
        │ ConfigMap                      │
        │ Secret                         │
        │ HPA                            │
        │ Ingress                        │
        │                                │
        └────────────────────────────────┘
```

Everything else:

```text
DENIED
```

That's much closer to enterprise GitOps.

---

# 3. Every Argo CD Application belongs to a project

Application:

```yaml
spec:

  project: todo-team
```

Now:

```text
todo-production Application
          │
          ▼
     AppProject
       todo-team
          │
          ▼
      Security rules
```

If you don't specify a project, Argo CD uses:

```text
default
```

And this brings us to an important security concern.

---

# 4. The default AppProject is very permissive

By default, Argo CD creates:

```text
AppProject:
default
```

Its initial permissions are essentially broad:

```yaml
sourceRepos:
  - '*'

destinations:
  - namespace: '*'
    server: '*'

clusterResourceWhitelist:
  - group: '*'
    kind: '*'
```

Meaning roughly:

```text
Any repository
      +
Any destination
      +
Any resource kind
```

Argo CD's documentation explicitly recommends creating dedicated projects with explicit permissions rather than relying on the permissive default project for real multi-team usage. The `default` project can be restricted, although it cannot simply be deleted. ([Argo CD][1])

### Production rule

```text
LAB:

default project
    ✅ acceptable initially


PRODUCTION:

dedicated AppProjects
    ✅

permissive default project
    ❌ bad security boundary
```

---

# 5. Four major AppProject controls

Remember:

```text
               AppProject

                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼

     SOURCES    DESTINATIONS   RESOURCES
        │           │           │
        ▼           ▼           ▼

   Which Git     Which       What Kubernetes
   repositories  clusters    objects
                 namespaces

                    │
                    ▼

                   RBAC
                    │
                    ▼

               Who can do what
```

The memory trick:

```text
SOURCE
WHERE
WHAT
WHO
```

---

# 6. Restricting Git repositories

Suppose the Todo team owns:

```text
https://github.com/company/todo-gitops.git
```

Project:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:

  name: todo-team
  namespace: argocd

spec:

  sourceRepos:

    - https://github.com/company/todo-gitops.git
```

Now an Application using:

```yaml
repoURL: https://github.com/company/todo-gitops.git
```

is allowed.

But:

```yaml
repoURL: https://github.com/random-attacker/repo.git
```

should not satisfy the project's allowed source.

Argo CD AppProjects explicitly restrict the trusted source repositories applications may use. They also support allow/deny patterns for repositories. ([Argo CD][1])

---

# 7. Why repository restriction is security-critical

Imagine someone changes an Application to:

```yaml
source:

  repoURL: https://github.com/my-personal/repo.git

  path: production
```

Their repository contains:

```yaml
apiVersion: apps/v1
kind: DaemonSet
...
```

or some privileged workload.

If the project simply says:

```yaml
sourceRepos:
  - '*'
```

you've expanded the trust boundary enormously.

Better:

```text
Application
      │
      ▼
Repo requested:
company/todo-gitops
      │
      ▼
AppProject
      │
      ├── trusted? YES
      │
      ▼
continue
```

Instead of:

```text
ANY GIT REPOSITORY
        │
        ▼
       TRUST
```

---

# 8. Repository wildcard patterns

Maybe the company has:

```text
company/todo-gitops
company/payment-gitops
company/customer-gitops
```

A platform-level project could deliberately allow something like:

```yaml
sourceRepos:

  - 'https://github.com/company/*'
```

Argo CD also allows deny patterns using `!`. A repository is valid only when it matches an allow rule **and** does not match a deny rule. ([Argo CD][1])

Conceptually:

```yaml
sourceRepos:

  - '*'

  - '!https://github.com/untrusted/**'
```

But in production, explicit allow lists are usually much easier to reason about:

```text
Allow exactly what is required
```

rather than:

```text
Allow everything
except things we remembered to block
```

---

# 9. Restricting destinations

Next question:

> Where may this application deploy?

Suppose Todo can deploy only into:

```text
todo-dev
todo-staging
todo-production
```

on our current cluster.

```yaml
spec:

  destinations:

    - server: https://kubernetes.default.svc
      namespace: todo-dev

    - server: https://kubernetes.default.svc
      namespace: todo-staging

    - server: https://kubernetes.default.svc
      namespace: todo-production
```

Now:

```text
todo-production
       ✅

payment-production
       ❌

kube-system
       ❌
```

AppProject destinations can constrain both **clusters and namespaces**, with wildcard and negation patterns available where appropriate. ([Argo CD][1])

---

# 10. Wildcard namespace pattern

Instead of listing:

```text
todo-dev
todo-staging
todo-production
```

you could deliberately use:

```yaml
destinations:

  - server: https://kubernetes.default.svc

    namespace: todo-*
```

Then:

```text
todo-dev             ✅
todo-staging         ✅
todo-production      ✅
todo-performance     ✅

payment-production   ❌
```

This is useful for environments following a strong namespace naming convention.

---

# 11. Multi-cluster architecture

Now imagine production is separate.

```text
                 Argo CD

                    │
          ┌─────────┴─────────┐
          │                   │
          ▼                   ▼

      Non-Prod EKS         Prod EKS

          │                   │
     dev/staging              │
                              ▼
                         production
```

Then projects can become environment boundaries.

For example:

```text
todo-nonprod

Allowed:
dev cluster
staging cluster

Denied:
production cluster
```

and:

```text
todo-prod

Allowed:
production cluster

Source:
production Git repo/path

RBAC:
restricted
```

This is much safer than one project:

```text
everything
    │
    ▼
all clusters
all namespaces
```

---

# 12. Restricting Kubernetes resource kinds

This is where AppProjects become particularly powerful.

Imagine developers should be able to create:

```text
Deployment
Service
ConfigMap
Secret
Ingress
HPA
```

but should **not** create:

```text
ClusterRole
ClusterRoleBinding
CRD
Namespace outside their boundary
```

AppProject provides controls including:

```text
clusterResourceWhitelist
clusterResourceBlacklist

namespaceResourceWhitelist
namespaceResourceBlacklist
```

Argo CD distinguishes namespace-scoped and cluster-scoped resource restrictions; its project tooling/documentation specifically supports allow/deny controls for them. ([Argo CD][2])

---

# 13. Namespace-scoped vs cluster-scoped resources

Remember your Kubernetes fundamentals.

### Namespace-scoped examples

```text
Deployment
Service
ConfigMap
Secret
Pod
StatefulSet
Job
CronJob
Ingress
HPA
NetworkPolicy
```

They live inside:

```text
namespace
```

Example:

```bash
kubectl get deployment -n todo-production
```

---

### Cluster-scoped examples

```text
Namespace
Node
ClusterRole
ClusterRoleBinding
CustomResourceDefinition
PersistentVolume
```

They exist at cluster scope.

Example:

```bash
kubectl get clusterrole
```

No:

```text
-n namespace
```

required.

---

# 14. Why cluster-scoped resources are more sensitive

Suppose Team Todo can deploy a:

```text
ClusterRole
```

with:

```yaml
verbs:
  - '*'

resources:
  - '*'
```

and then create:

```text
ClusterRoleBinding
```

That can become a serious privilege escalation path.

Therefore:

```text
Application Team

should normally get:

namespaced resources
      │
      ▼
their namespace

NOT

unrestricted cluster resources
```

---

# 15. Example cluster resource whitelist

Suppose we only want to let the project create Namespaces matching its convention.

```yaml
clusterResourceWhitelist:

  - group: ''
    kind: Namespace
    name: 'todo-*'
```

Current AppProject specifications support resource-name restrictions for cluster-scoped resources, including wildcard patterns such as namespace names beginning with a team prefix. ([Argo CD][1])

So:

```text
todo-dev
    ✅

todo-production
    ✅

payment-production
    ❌

kube-system
    ❌
```

---

# 16. Example namespace resource blacklist

Maybe your platform team manages:

```text
ResourceQuota
LimitRange
NetworkPolicy
```

Application teams must not overwrite them.

Then:

```yaml
namespaceResourceBlacklist:

  - group: ''
    kind: ResourceQuota

  - group: ''
    kind: LimitRange

  - group: networking.k8s.io
    kind: NetworkPolicy
```

Architecture:

```text
                todo-production namespace

                         │
          ┌──────────────┴─────────────┐
          │                            │

     Application Team            Platform Team

     Deployment                  ResourceQuota
     Service                     LimitRange
     ConfigMap                   NetworkPolicy
     HPA
```

Clear ownership.

---

# 17. Build our production AppProject

Let's create:

```text
gitops/
└── argocd/
    └── projects/
        └── todo-team.yaml
```

Content:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:

  name: todo-team
  namespace: argocd

  finalizers:

    - resources-finalizer.argocd.argoproj.io

spec:

  description: Todo application team project

  sourceRepos:

    - https://github.com/company/todo-gitops.git

  destinations:

    - server: https://kubernetes.default.svc
      namespace: todo-dev

    - server: https://kubernetes.default.svc
      namespace: todo-staging

    - server: https://kubernetes.default.svc
      namespace: todo-production

  clusterResourceWhitelist:

    - group: ''
      kind: Namespace
      name: 'todo-*'

  clusterResourceBlacklist:

    - group: ''
      kind: Namespace
      name: 'kube-*'

  namespaceResourceBlacklist:

    - group: ''
      kind: ResourceQuota

    - group: ''
      kind: LimitRange
```

This is already far safer than:

```yaml
sourceRepos:
  - '*'

destinations:
  - namespace: '*'
    server: '*'
```

The resource/project structure above uses supported current AppProject controls. ([Argo CD][2])

---

# 18. Assign our Application to this project

Previously:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:

  name: todo-production
  namespace: argocd

spec:

  project: default
```

Change:

```yaml
project: todo-team
```

So:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:

  name: todo-production
  namespace: argocd

spec:

  project: todo-team

  source:

    repoURL: https://github.com/company/todo-gitops.git

    targetRevision: main

    path: apps/todo/production

  destination:

    server: https://kubernetes.default.svc

    namespace: todo-production
```

Flow:

```text
Application
     │
     ▼
project: todo-team
     │
     ▼
Check repository
     │
     ├── allowed
     ▼
Check cluster
     │
     ├── allowed
     ▼
Check namespace
     │
     ├── allowed
     ▼
Check resource types
     │
     ├── allowed
     ▼

DEPLOY
```

---

# 19. Now intentionally violate it

Change:

```yaml
destination:

  namespace: payment-production
```

But AppProject permits only:

```text
todo-dev
todo-staging
todo-production
```

Now the request violates the project's destination policy.

Conceptually:

```text
Application
    │
    ▼
payment-production
    │
    ▼
AppProject todo-team
    │
    ▼
Destination permitted?

       NO
       │
       X

Deployment blocked
```

That's exactly the boundary we want. ([Argo CD][1])

---

# 20. CRITICAL SECURITY RULE — never casually allow application projects into `argocd`

This is one of the most important points in this entire lesson.

Suppose you give Team Todo:

```yaml
destinations:

  - namespace: '*'
    server: '*'
```

That includes:

```text
argocd
```

where Argo CD itself lives.

Argo CD explicitly warns that an AppProject capable of deploying into the namespace where Argo CD is installed effectively grants applications in that project **admin-level power**. Push access to repositories used by such a project and Argo CD access to it must therefore be tightly restricted. ([Argo CD][3])

Why?

Because that repository could potentially alter:

```text
Argo CD configuration
RBAC ConfigMaps
Secrets
Applications
AppProjects
Argo CD workloads
```

Conceptually:

```text
Developer controls Git
        │
        ▼
Git controls manifests
        │
        ▼
Project allows deployment
into argocd namespace
        │
        ▼
Developer may influence
Argo CD itself
        │
        ▼
PRIVILEGE ESCALATION
```

### Never forget

```text
Application workload project
        │
        X
should NOT casually deploy
into
        │
        ▼
argocd namespace
```

---

# 21. AppProject answers "what can the Application do?"

Now we need:

> What can the **human user** do?

For that, Argo CD has its own RBAC layer.

Do not confuse:

```text
Kubernetes RBAC

with

Argo CD RBAC
```

---

# 22. Kubernetes RBAC vs Argo CD RBAC

## Kubernetes RBAC

Answers:

```text
Can this Kubernetes identity:

get Pods?
delete Secrets?
create Deployments?
update ClusterRoles?
```

Objects:

```text
Role
ClusterRole
RoleBinding
ClusterRoleBinding
```

---

## Argo CD RBAC

Answers:

```text
Can Vivek:

view this Argo Application?
sync production?
delete this Application?
see logs?
exec into application resources?
create ApplicationSets?
manage repositories?
```

Argo CD maintains authorization rules for its own resources and supports both global RBAC and project roles. ([Argo CD][4])

Mental model:

```text
USER
  │
  ▼
Argo CD RBAC
  │
  │ permission to trigger operation
  ▼
Argo CD
  │
  ▼
Kubernetes credentials/RBAC
  │
  ▼
Kubernetes API
```

Two different authorization layers.

---

# 23. Built-in Argo CD roles

Argo CD currently includes two built-in roles:

```text
role:readonly
role:admin
```

`role:readonly` provides read-only access, while `role:admin` provides unrestricted access. ([Argo CD][4])

Do not solve every access problem with:

```text
role:admin
```

That destroys least privilege.

---

# 24. Global Argo CD RBAC

Global RBAC configuration commonly lives in:

```text
argocd-rbac-cm
```

A simplified example:

```yaml
apiVersion: v1
kind: ConfigMap

metadata:

  name: argocd-rbac-cm
  namespace: argocd

data:

  policy.default: role:readonly

  policy.csv: |

    p, role:developer, applications, get, */*, allow

    p, role:developer, applications, sync, todo-team/*, allow

    g, todo-developers, role:developer
```

Argo CD's RBAC syntax is based on Casbin-style policy and group rules. ([Argo CD][4])

---

# 25. Understand `p` and `g`

This looks strange at first:

```text
p
g
```

But it's simple.

### `p`

Means:

```text
POLICY
```

General syntax:

```text
p,
subject,
resource,
action,
object,
effect
```

For example:

```text
p,
role:developer,
applications,
get,
todo-team/*,
allow
```

Meaning:

```text
role:developer

may

GET

Applications

inside todo-team

ALLOW
```

Argo CD defines this policy shape as:

```text
p, <role/user/group>, <resource>, <action>, <object>, <allow|deny>
```

([Argo CD][4])

---

# 26. `g` means role/group mapping

Example:

```text
g, todo-developers, role:developer
```

Meaning:

```text
todo-developers
      │
      ▼
belongs to
      │
      ▼
role:developer
```

So if your identity provider says:

```text
Vivek
  │
  └── member of:
      todo-developers
```

then Argo CD can map:

```text
todo-developers
       ↓
role:developer
       ↓
permissions
```

Argo CD can use identity information from configured SSO/OIDC claims such as groups or roles for these mappings. ([Argo CD][4])

---

# 27. Production SSO architecture

Enterprise architecture might look like:

```text
                Employee

                   │
                   ▼

          Corporate Identity
               Provider

      Entra ID / Okta / Keycloak
                  etc.

                   │
                  OIDC
                   │
                   ▼

                Argo CD

                   │
            groups claim
                   │
       ┌───────────┼────────────┐
       ▼           ▼            ▼

 Developers    SRE Team    Platform Admins

      │           │             │
      ▼           ▼             ▼

 Developer     Operator       Admin
   role          role          role
```

Then permissions come from group membership rather than creating dozens of independent Argo CD users.

---

# 28. Example enterprise roles

Let's design:

```text
todo-viewers
todo-developers
todo-operators
platform-admins
```

Desired permissions:

```text
Viewers
  → view applications

Developers
  → view applications
  → view logs
  → sync dev

Operators
  → view
  → logs
  → sync production

Platform Admins
  → manage Argo CD platform
```

Notice:

```text
Developer
   ≠
Production administrator
```

---

# 29. Project roles

Instead of defining every permission globally, AppProjects themselves can contain roles.

Example:

```yaml
spec:

  roles:

    - name: developer

      description: Todo team developer access

      groups:

        - todo-developers

      policies:

        - p, proj:todo-team:developer, applications, get, todo-team/*, allow
```

Argo CD project roles can bind policies to OIDC groups, and those policies are scoped around applications associated with the project. ([Argo CD][2])

Mental model:

```text
OIDC group
todo-developers
      │
      ▼
Project role
developer
      │
      ▼
Project
todo-team
      │
      ▼
Applications
todo-team/*
```

Very clean.

---

# 30. Add sync permission

Suppose developers may sync Todo applications:

```yaml
roles:

  - name: developer

    groups:

      - todo-developers

    policies:

      - p, proj:todo-team:developer, applications, get, todo-team/*, allow

      - p, proj:todo-team:developer, applications, sync, todo-team/*, allow
```

Now:

```text
Developer
   │
   ├── View Application ✅
   │
   └── Sync Application ✅
```

But we haven't given:

```text
delete
update project
manage clusters
manage repositories
```

Least privilege.

---

# 31. Separate production operator role

We could use:

```yaml
- name: production-operator

  groups:

    - sre-team

  policies:

    - p, proj:todo-team:production-operator, applications, get, todo-team/*, allow

    - p, proj:todo-team:production-operator, applications, sync, todo-team/todo-production, allow
```

Notice the difference:

```text
todo-team/*
```

versus:

```text
todo-team/todo-production
```

The second targets one particular Application.

Application-scoped Argo CD policies normally use:

```text
<project>/<application>
```

as their object pattern. ([Argo CD][4])

---

# 32. Read-only role

```yaml
- name: viewer

  groups:

    - todo-viewers

  policies:

    - p, proj:todo-team:viewer, applications, get, todo-team/*, allow
```

Now QA, auditors or support engineers can inspect applications without receiving deployment permission.

```text
Viewer

GET     ✅

SYNC    ❌

DELETE  ❌
```

---

# 33. Logs permission is separate

Argo CD's RBAC model contains a separate:

```text
logs
```

resource.

So you can design:

```text
Developer

View app   ✅
Logs       ✅
Sync       maybe
Exec       ❌
```

For example:

```text
p, role:developer, logs, get, todo-team/*, allow
```

Argo CD currently models `logs` and `exec` as separate RBAC resource types, allowing you to control them independently from basic application viewing. ([Argo CD][4])

---

# 34. `exec` should be treated carefully

Argo CD can also provide terminal execution into application resources.

RBAC resource:

```text
exec
```

Granting execution capability is materially more powerful than just:

```text
view application
```

or:

```text
view logs
```

Production approach:

```text
Developer

Application view ✅
Logs             ✅
Exec production  ❌ by default
```

because:

```text
exec
  │
  ▼
container shell
  │
  ▼
runtime access
```

Treat it as privileged operational access. Argo CD explicitly exposes `exec` as its own controlled RBAC resource. ([Argo CD][4])

---

# 35. An especially dangerous permission: `override`

Remember the entire GitOps philosophy:

```text
Git
 =
source of truth
```

Argo CD has an:

```text
override
```

permission.

This can permit synchronization using arbitrary manifests or revisions rather than strictly using what the Application currently defines.

That can temporarily bypass the normal desired-source model.

Current Argo CD documentation explicitly warns that `override` can allow users to substantially change or delete deployed resources and recommends restricting the privilege to users who genuinely need it. Newer Argo CD versions also provide a setting to require override privilege when syncing arbitrary revisions. ([Argo CD][4])

### Never casually grant

```text
override
```

to:

```text
every developer
```

---

# 36. Production security architecture

Let's assemble what we've learned:

```text
                        Corporate Identity Provider

                                  │
                                 OIDC
                                  │
                                  ▼

                               Argo CD

                                  │

              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼

       todo-developers         sre-team        platform-admins

              │                   │                   │
              ▼                   ▼                   ▼

        Project Role        Project Role         Global Admin
         developer         prod-operator

              │                   │
              └─────────┬─────────┘
                        ▼

                 AppProject
                  todo-team

                        │

           ┌────────────┼─────────────┐

           ▼            ▼             ▼

      Source Repos   Destinations   Resources

           │            │             │

           ▼            ▼             ▼

      todo-gitops    todo-*       Deployments
                                 Services
                                 ConfigMaps
                                 etc.

                        │
                        ▼

                  Kubernetes
```

This is much closer to the way a proper internal deployment platform is governed.

---

# 37. Full production example

Let's combine it.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:

  name: todo-team
  namespace: argocd

  finalizers:

    - resources-finalizer.argocd.argoproj.io

spec:

  description: GitOps boundary for Todo application team

  sourceRepos:

    - https://github.com/company/todo-gitops.git

  destinations:

    - server: https://kubernetes.default.svc
      namespace: todo-dev

    - server: https://kubernetes.default.svc
      namespace: todo-staging

    - server: https://kubernetes.default.svc
      namespace: todo-production

  clusterResourceWhitelist:

    - group: ''
      kind: Namespace
      name: todo-*

  clusterResourceBlacklist:

    - group: ''
      kind: Namespace
      name: kube-*

  namespaceResourceBlacklist:

    - group: ''
      kind: ResourceQuota

    - group: ''
      kind: LimitRange

  orphanedResources:

    warn: true

  roles:

    - name: viewer

      description: Read Todo Argo applications

      groups:

        - todo-viewers

      policies:

        - p, proj:todo-team:viewer, applications, get, todo-team/*, allow


    - name: developer

      description: Todo development team

      groups:

        - todo-developers

      policies:

        - p, proj:todo-team:developer, applications, get, todo-team/*, allow

        - p, proj:todo-team:developer, applications, sync, todo-team/todo-dev, allow

        - p, proj:todo-team:developer, applications, sync, todo-team/todo-staging, allow


    - name: production-operator

      description: SRE production deployment access

      groups:

        - sre-team

      policies:

        - p, proj:todo-team:production-operator, applications, get, todo-team/*, allow

        - p, proj:todo-team:production-operator, applications, sync, todo-team/todo-production, allow
```

This uses current AppProject role, repository, destination and resource-boundary capabilities. ([Argo CD][2])

---

# 38. Notice the developer cannot sync production

Developer:

```text
todo-dev       ✅

todo-staging   ✅

todo-production
               ❌
```

SRE:

```text
todo-production
       ✅
```

So production deployment becomes:

```text
Developer
   │
   ▼
PR / Git change
   │
   ▼
GitOps repo
   │
   ▼
Production approval process
   │
   ▼
SRE / automated approved workflow
   │
   ▼
Argo CD
```

Instead of:

```text
everyone
   │
   ▼
production
```

---

# 39. Authentication vs authorization

Another interview favourite.

## Authentication

Answers:

> Who are you?

```text
Username/password
OIDC
SSO
Corporate IdP
```

Example:

```text
User:
Vivek

Group:
todo-developers
```

---

## Authorization

Answers:

> What are you allowed to do?

```text
Can sync dev?
Can sync prod?
Can delete application?
Can view logs?
```

Argo CD uses authentication information from configured identities and then evaluates RBAC policies for authorization. ([Argo CD][4])

Memory:

```text
AUTHN
=
Who are you?


AUTHZ
=
What can you do?
```

---

# 40. Be careful with `policy.default`

You may encounter:

```yaml
policy.default: role:readonly
```

or another role.

Important subtlety:

All authenticated users receive whatever permissions are granted through `policy.default`, and Argo CD warns that these default permissions cannot simply be negated later with a normal deny rule. Its documentation recommends giving the default authenticated role only minimal privileges and layering explicit permissions on top. ([Argo CD][4])

Bad mindset:

```text
default = broad access

then we'll add deny rules later
```

Better:

```text
default
    │
    ▼
minimal access

then
    │
    ▼
explicitly grant what's needed
```

Classic least privilege.

---

# 41. Production access tiers

A practical model:

```text
LEVEL 0
Unauthenticated

No access


LEVEL 1
Viewer

Application status
Health
Sync state


LEVEL 2
Developer

View
Logs
Sync non-production


LEVEL 3
SRE / Operator

View
Logs
Production sync
Operational actions


LEVEL 4
Platform Engineer

Projects
Repositories
Clusters
ApplicationSets


LEVEL 5
Argo CD Administrator

Full platform administration
```

Not every company will use exactly these roles, but the principle matters:

```text
Privilege increases
        ↑

Business risk increases
        ↑

Controls should increase
        ↑
```

---

# 42. Another enterprise pattern — project per team

Imagine:

```text
Company

├── customer-team
├── payment-team
├── recommendation-team
└── platform-team
```

Create:

```text
AppProject
customer

AppProject
payment

AppProject
recommendation

AppProject
platform
```

Then:

```text
Customer Project

Repo:
customer-gitops

Namespace:
customer-*

Groups:
customer-developers


Payment Project

Repo:
payment-gitops

Namespace:
payment-*

Groups:
payment-developers
```

Result:

```text
Customer team
      │
      X
cannot accidentally deploy
      │
      ▼
payment-production
```

That's **multi-tenancy**.

---

# 43. Project per environment

Another model:

```text
todo-nonprod
todo-production
```

Then:

```text
todo-nonprod

cluster:
development

permissions:
developers
```

and:

```text
todo-production

cluster:
production

permissions:
SRE + automation
```

This creates a stronger boundary.

---

# 44. Team + environment combined

At larger organizations you may see:

```text
customer-nonprod
customer-prod

payment-nonprod
payment-prod

analytics-nonprod
analytics-prod
```

Conceptually:

```text
                Argo CD

                   │
       ┌───────────┴───────────┐
       │                       │

     NonProd                  Prod

       │                       │

 ┌─────┼─────┐           ┌─────┼─────┐

Customer Payment           Customer Payment
```

This increases administrative complexity but makes trust boundaries much clearer.

---

# 45. Another advanced feature — Applications in team namespaces

Normally Argo CD Applications live in:

```text
argocd
```

Current Argo CD can also be configured to manage `Application` objects residing in approved namespaces outside the control-plane namespace.

Security requires **both**:

```text
Argo CD global allowed Application namespaces
```

and:

```text
AppProject.spec.sourceNamespaces
```

to permit the relationship. Argo CD explicitly warns that misconfiguring this feature can introduce security issues. ([Argo CD][5])

For example:

```yaml
spec:

  sourceNamespaces:

    - todo-team
```

Then application teams could potentially manage Application CRs from:

```text
todo-team
```

rather than getting write access to:

```text
argocd
```

This is useful for advanced multi-tenant platform engineering.

---

# 46. Why giving developers Kubernetes write access to `argocd` is dangerous

This one is easy to underestimate.

If someone can freely create/update Argo CD `Application` or `AppProject` resources directly inside the Argo CD control-plane namespace, that person should effectively be treated as highly privileged.

Argo CD's applications-in-any-namespace documentation explicitly notes that Kubernetes users with write access to the Argo CD control-plane namespace—particularly for declarative Application management—must be considered Argo CD administrators. ([Argo CD][5])

So:

```text
kubectl access to argocd namespace
              │
              ▼
      not ordinary developer access
```

---

# 47. Hands-on lab

Create:

```bash
mkdir -p argocd-security
cd argocd-security
```

Create:

```text
todo-project.yaml
```

with your AppProject.

Apply:

```bash
kubectl apply \
  -n argocd \
  -f todo-project.yaml
```

Verify:

```bash
kubectl get appproject \
  -n argocd
```

Expected:

```text
NAME
default
todo-team
```

---

# 48. Inspect the project

```bash
kubectl get appproject todo-team \
  -n argocd \
  -o yaml
```

or:

```bash
argocd proj get todo-team
```

Look for:

```text
SOURCE REPOSITORIES
DESTINATIONS
RESOURCE PERMISSIONS
ROLES
```

---

# 49. Assign an Application

```bash
argocd app set todo-production \
  --project todo-team
```

Argo CD supports changing an application's project when the acting user has access to the target project. ([Argo CD][1])

Check:

```bash
argocd app get todo-production
```

Look for:

```text
Project:
todo-team
```

---

# 50. Test destination protection

Temporarily point a test Application to:

```text
payment-production
```

The project should reject the invalid destination.

That proves:

```text
Security boundary
     actually works
```

Never assume security configuration works because the YAML looks right.

Test it.

---

# 51. Test repository protection

Try a test Application using:

```text
https://github.com/some-other/repo.git
```

while the project permits only:

```text
company/todo-gitops.git
```

Expected:

```text
repository not permitted
```

Again:

```text
Policy written
   ≠
Policy verified
```

---

# 52. Test resource restriction

Add something your project does not permit.

For example, if cluster resources are tightly restricted, try a test:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole

metadata:

  name: todo-danger-test

rules:

  - apiGroups:
      - '*'

    resources:
      - '*'

    verbs:
      - '*'
```

Argo CD should not be allowed to deploy a forbidden cluster-scoped resource under that project's restrictions.

After testing, delete the test manifest from Git.

---

# 53. Validate RBAC policies before relying on them

Argo CD provides commands for validating/testing RBAC configuration; its RBAC documentation specifically includes validation and permission-testing workflows. ([Argo CD][4])

Conceptually, don't do:

```text
edit RBAC
   ↓
hope
   ↓
production
```

Do:

```text
edit RBAC
   ↓
validate
   ↓
test expected allow
   ↓
test expected deny
   ↓
production
```

---

# 54. Security test matrix

Whenever you build Argo RBAC, mentally test:

| Actor          | Dev Sync | Prod Sync |  Logs |       Exec | Admin |
| -------------- | -------: | --------: | ----: | ---------: | ----: |
| Viewer         |        ❌ |         ❌ | maybe |          ❌ |     ❌ |
| Developer      |        ✅ |         ❌ |     ✅ |          ❌ |     ❌ |
| SRE            |        ✅ |         ✅ |     ✅ | controlled |     ❌ |
| Platform Admin |        ✅ |         ✅ |     ✅ |          ✅ |     ✅ |

And then test both:

```text
Expected ALLOW
```

and:

```text
Expected DENY
```

A security policy is incomplete until you've tested the deny paths.

---

# 55. Production anti-pattern #1

```yaml
sourceRepos:
  - '*'

destinations:
  - namespace: '*'
    server: '*'

clusterResourceWhitelist:
  - group: '*'
    kind: '*'
```

for every team.

That's effectively:

```text
"Here is Argo CD.

Good luck."
```

Not a real security model.

---

# 56. Production anti-pattern #2

Everyone:

```text
role:admin
```

Why bother having RBAC then?

Instead:

```text
Default:
minimum

Developer:
required permissions

SRE:
operational permissions

Platform:
administrative permissions
```

---

# 57. Production anti-pattern #3

Allowing a workload team:

```text
clusterResourceWhitelist:
  - group: '*'
    kind: '*'
```

without understanding why.

Ask:

```text
Does this application REALLY need:

ClusterRole?
CRD?
Namespace?
ClusterRoleBinding?
```

If not:

```text
don't grant it.
```

---

# 58. Production anti-pattern #4

Developer can modify:

```text
GitOps repository
```

and that repository may deploy into:

```text
argocd namespace
```

Remember:

```text
Git write permission

can become

cluster/platform privilege
```

depending on what Argo CD trusts and where it can deploy.

That's why Git repository permissions are part of your **production security architecture**, not merely source-control housekeeping. Argo CD explicitly warns about this when a project can target its own control-plane namespace. ([Argo CD][3])

---

# 59. Production anti-pattern #5

One identity:

```text
shared-admin@example.com
```

used by:

```text
10 engineers
```

Then:

```text
Who deployed this?
```

Answer:

```text
¯\_(ツ)_/¯
```

Enterprise systems should prefer individual identities and group-based authorization so activities can be tied back to accountable users and roles.

---

# 60. Security troubleshooting mental model

Suppose Argo CD says:

```text
permission denied
```

Work through:

```text
WHO?
 │
 ▼
Which authenticated user/group?


ROLE?
 │
 ▼
Which Argo CD role?


POLICY?
 │
 ▼
Does that role permit this action?


PROJECT?
 │
 ▼
Does the Application belong to the expected AppProject?


SOURCE?
 │
 ▼
Is repo allowed?


DESTINATION?
 │
 ▼
Is cluster allowed?
Is namespace allowed?


RESOURCE?
 │
 ▼
Is Kubernetes resource kind permitted?


KUBERNETES?
 │
 ▼
Does Argo CD itself have required cluster permission?
```

This prevents random debugging.

---

# 61. Debug scenario

User says:

```text
"I can see todo-production,
but Sync button gives permission denied."
```

Think:

```text
applications,get
       ✅

applications,sync
       ❌
```

Seeing an application and syncing it are separate Argo RBAC actions. ([Argo CD][4])

---

# 62. Another scenario

User can sync:

```text
todo-dev
```

but not:

```text
todo-production
```

Check:

```text
object pattern
```

Maybe policy says:

```text
todo-team/todo-dev
```

not:

```text
todo-team/*
```

That is good intentional RBAC.

---

# 63. Another scenario

RBAC says user can sync production.

But Argo CD still refuses:

```text
application destination is not permitted
```

Why?

Because:

```text
RBAC
   │
   └── says USER may sync

AppProject
   │
   └── says APPLICATION may not target destination
```

Both controls matter.

This is an excellent interview concept.

---

# 64. User permissions and application permissions are different

Think carefully:

```text
                Request to Sync

                      │

          ┌───────────┴───────────┐

          ▼                       ▼

       USER                     APPLICATION

     allowed?                    allowed?

        │                          │
        ▼                          ▼

     Argo RBAC                 AppProject

        │                          │

        └────────────┬─────────────┘
                     ▼

                  DEPLOY
```

You need:

```text
User authorized
       AND
Application allowed
```

---

# 65. Least privilege principle

Everything we've learned boils down to:

```text
Give:

only the permissions required

to:

only the identities that need them

for:

only the applications they own

from:

only trusted repositories

to:

only approved clusters/namespaces

using:

only necessary resource types
```

That is **least privilege** applied to GitOps.

---

# 66. Interview question — What is AppProject?

**Answer:**

An Argo CD `AppProject` creates a logical and security boundary around Applications, allowing administrators to constrain trusted source repositories, destination clusters/namespaces, resource types, and project-level application roles. ([Argo CD][1])

---

# 67. What does `sourceRepos` do?

Controls which repositories Applications in the project may use as sources. ([Argo CD][1])

---

# 68. What does `destinations` do?

Controls allowed:

```text
clusters
+
namespaces
```

for Applications within the project. ([Argo CD][1])

---

# 69. What are project roles?

Roles defined within an AppProject that can grant application-related permissions and map those permissions to groups such as OIDC groups. ([Argo CD][2])

---

# 70. Difference between Argo RBAC and AppProject?

Use this interview answer:

```text
Argo RBAC

controls what a USER
may do inside Argo CD.


AppProject

controls what APPLICATIONS
within that project may deploy,
from where,
and to where.
```

---

# 71. Difference between Argo CD RBAC and Kubernetes RBAC?

```text
Argo CD RBAC

User → Argo operations


Kubernetes RBAC

Identity → Kubernetes API operations
```

Example:

```text
Argo:
Can Alice press Sync?

Kubernetes:
Can Argo CD create the Deployment?
```

---

# 72. Why is allowing deployment into `argocd` dangerous?

Because Applications capable of modifying the Argo CD control-plane namespace can potentially affect Argo CD's own configuration and privileges; the official documentation therefore treats such projects as admin-level and recommends tightly restricting both project access and repository push permissions. ([Argo CD][3])

---

# 73. What is the default AppProject?

An automatically created project used when no explicit project is specified. Its initial configuration is intentionally permissive, so production environments should generally create dedicated restricted projects. ([Argo CD][6])

---

# 74. Never-forget architecture

Memorize this:

```text
                         USER

                          │
                          ▼

                       Identity
                       Provider

                          │
                          ▼

                     Argo CD RBAC
                          │
                          │
                 "Can YOU do this?"
                          │
                          ▼

                     Application
                          │
                          ▼

                     AppProject
                          │
                          │
           "Can THIS APP do this?"
                          │

          ┌───────────────┼───────────────┐

          ▼               ▼               ▼

       SOURCE         DESTINATION       RESOURCE

     Git repo           Cluster          Kind
                        Namespace

          │               │               │

          └───────────────┼───────────────┘
                          │
                          ▼

                       Argo CD
                          │
                          ▼

                   Kubernetes RBAC
                          │
                          │
               "Can ARGO do this?"
                          │
                          ▼

                    Kubernetes API
```

That diagram is extremely important.

---

# 75. Five security questions to never forget

For every production GitOps deployment ask:

```text
1. WHO
   is deploying?

2. FROM WHERE
   is the desired state coming?

3. TO WHERE
   can it deploy?

4. WHAT
   Kubernetes resources may it create?

5. WHO OWNS
   permission to change these rules?
```

If you can answer all five clearly, your GitOps architecture is becoming mature.

---

# 76. Short memory trick

```text
RBAC
=
WHO


sourceRepos
=
FROM WHERE


destinations
=
TO WHERE


resource whitelist/blacklist
=
WHAT


AppProject
=
BOUNDARY
```

And:

```text
Application
asks:

"I want to deploy this."


AppProject
asks:

"Are you allowed?"


RBAC
asks:

"Is this person allowed?"


Kubernetes RBAC
asks:

"Is Argo allowed?"
```

---

# 77. Where we are in Module 14

```text
Module 14 — GitOps with Argo CD

14.1  GitOps Mental Model                       ✅
14.2  Argo CD Architecture                      ✅
14.3  Installation                              ✅
14.4  Applications                              ✅
14.5  Automated Reconciliation                  ✅
14.6  Repository Structure                      ✅
14.7  Helm + Argo CD                            ✅
14.8  Kustomize + Argo CD                       ✅
14.9  Production Repository Patterns            ✅
14.10 Advanced Application Management           ✅
14.11 Hooks, Phases & Sync Waves                ✅
14.12 Sync, Prune, Drift & Self-Healing         ✅
14.13 AppProject, RBAC & Security               ✅ ← completed

NEXT
   │
   ▼
14.14 — Sync Windows, Change Control &
         Production Deployment Governance
```

In **Lesson 14.14**, we'll solve another enterprise problem:

```text
Developers have permission
        │
        ▼
Application is valid
        │
        ▼
Git contains approved change
        │
        ▼

BUT...

Should production be deployable
at 2 PM on Friday?
```

We'll build:

```text
                  Production

                      │
             ┌────────┴────────┐

             ▼                 ▼

        ALLOW WINDOW        DENY WINDOW

      Mon–Thu daytime       Friday evening
      Maintenance slot      Month-end close
      Approved change       Incident freeze

                      │
                      ▼

                 Argo CD

                      │
                      ▼

            Sync allowed/blocked
```

We'll cover **allow/deny Sync Windows, manual sync exceptions, deployment freezes, scheduled releases, change-management integration, emergency deployments, production governance, and troubleshooting why an application says sync is blocked**.

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/ "Projects - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/latest/operator-manual/project-specification/ "Project Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/ "RBAC Configuration - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/latest/operator-manual/app-any-namespace/ "Applications in any namespace - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/?utm_source=chatgpt.com "Projects - Argo CD - Declarative GitOps CD for Kubernetes"
