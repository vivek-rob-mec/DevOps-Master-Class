# Module 14 — GitOps with Argo CD

## Lesson 14.15 — ApplicationSet: Managing Many Applications, Environments & Clusters

Until now, our mental model has mainly been:

```text
One Argo CD Application
        │
        ▼
One workload/environment
```

For example:

```text
todo-dev
todo-staging
todo-production
```

We could manually create three `Application` objects.

But now imagine:

```text
100 microservices
      ×
3 environments
      ×
5 Kubernetes clusters
      =
1,500 possible deployment targets
```

Writing and maintaining hundreds of almost-identical `Application` manifests would become painful.

This is exactly the problem **ApplicationSet** solves. The ApplicationSet controller generates and manages Argo CD `Application` resources from a template plus one or more **generators**. It is bundled with Argo CD and is specifically designed for multi-cluster, monorepo, and large-scale Application automation. ([Argo CD][1])

---

# 1. First mental model

An ordinary Application says:

```text
Deploy THIS application
from THIS repository
to THIS cluster/namespace.
```

ApplicationSet says:

> **Use these rules to manufacture many Applications for me.**

Think:

```text
                  ApplicationSet
                        │
                 ┌──────┴──────┐
                 │             │
             Generator      Template
                 │             │
                 │             │
      "What values exist?"   "How should each
                 │            Application look?"
                 └──────┬──────┘
                        ▼

                  Application 1
                  Application 2
                  Application 3
                  Application 4
                       ...
```

Generators create parameter sets, and those parameters are rendered into the ApplicationSet template to produce actual Argo CD Applications. ([Argo CD][2])

---

# 2. Application vs ApplicationSet

This distinction must become automatic.

## Application

```yaml
kind: Application
```

represents:

```text
One deployment definition
```

Example:

```text
todo-production
      │
      ▼
todo manifests
      │
      ▼
production cluster
```

---

## ApplicationSet

```yaml
kind: ApplicationSet
```

represents:

```text
Rules for generating
multiple Applications
```

Example:

```text
                 todo ApplicationSet

                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼

         todo-dev   todo-stage   todo-prod

            │          │          │
            ▼          ▼          ▼

          Dev K8s   Stage K8s   Prod K8s
```

The ApplicationSet controller automatically creates and manages the generated `Application` resources. ([Argo CD][3])

---

# 3. ApplicationSet does NOT replace Application

A common beginner misunderstanding is:

```text
ApplicationSet replaces Application
```

No.

The real hierarchy is:

```text
ApplicationSet
      │
      │ generates
      ▼
Application
      │
      │ manages
      ▼
Kubernetes resources

Deployment
Service
ConfigMap
Ingress
...
```

So:

```text
ApplicationSet
    ↓
Application
    ↓
Kubernetes
```

### Never forget

```text
ApplicationSet manages Applications.

Application manages Kubernetes resources.
```

---

# 4. Basic ApplicationSet structure

At minimum you'll repeatedly see:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: todo-environments
  namespace: argocd

spec:

  generators:
    ...

  template:

    metadata:
      name: ...

    spec:

      project: ...

      source:
        ...

      destination:
        ...
```

Think:

```text
spec.generators
      │
      └── Produce DATA

spec.template
      │
      └── Produce APPLICATION
```

---

# 5. Current ApplicationSet generators

Current Argo CD documentation lists nine generator families: **List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request, Cluster Decision Resource, and Plugin**. ([Argo CD][2])

For our production course, the most important ones first are:

```text
List
Cluster
Git Directory
Git File
Matrix
Merge
```

We'll later understand when the others matter.

---

# 6. Generator mental model

Think of generators like:

```text
                    GENERATOR
                        │
                        ▼
                  Parameter Sets

        ┌───────────────┼───────────────┐
        ▼               ▼               ▼

   env=dev          env=stage        env=prod
   cluster=A        cluster=B        cluster=C
```

Template:

```text
name: todo-{{env}}
cluster: {{cluster}}
```

Generated:

```text
todo-dev
todo-stage
todo-prod
```

This is essentially:

```text
DATA
 +
TEMPLATE
 =
APPLICATIONS
```

---

# 7. Start with the List Generator

The **List generator** is the easiest ApplicationSet generator to understand.

It takes a literal list of key/value data and creates one parameter set per element. Argo CD specifically recommends starting with List and Cluster generators when learning ApplicationSets. ([Argo CD][2])

Suppose we have:

```text
Development
Staging
Production
```

Instead of creating:

```text
todo-dev.yaml
todo-staging.yaml
todo-production.yaml
```

we define the environments once.

---

# 8. Simple List Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: todo-environments
  namespace: argocd

spec:

  goTemplate: true
  goTemplateOptions:
    - missingkey=error

  generators:

    - list:

        elements:

          - env: dev
            namespace: todo-dev

          - env: staging
            namespace: todo-staging

          - env: production
            namespace: todo-production

  template:

    metadata:

      name: 'todo-{{ .env }}'

    spec:

      project: todo-team

      source:

        repoURL: https://github.com/company/todo-gitops.git

        targetRevision: main

        path: 'apps/todo/{{ .env }}'

      destination:

        server: https://kubernetes.default.svc

        namespace: '{{ .namespace }}'
```

The List generator accepts arbitrary string key/value element data which can then be referenced from the template. ([Argo CD][4])

---

# 9. What happens internally?

Generator produces:

```text
Parameter Set 1

env=dev
namespace=todo-dev
```

Then:

```text
Parameter Set 2

env=staging
namespace=todo-staging
```

Then:

```text
Parameter Set 3

env=production
namespace=todo-production
```

The template says:

```yaml
name: 'todo-{{ .env }}'
```

Therefore ApplicationSet produces:

```text
todo-dev
todo-staging
todo-production
```

---

# 10. Generated architecture

```text
                  todo-environments
                  ApplicationSet

                       │
                       │ generator
                       ▼

               ┌───────┼────────┐
               │       │        │

               ▼       ▼        ▼

           todo-dev todo-staging todo-production

               │       │        │
               ▼       ▼        ▼

            App CR   App CR    App CR

               │       │        │
               ▼       ▼        ▼

           todo-dev  staging  production
           namespace namespace namespace
```

One source manifest has produced three Argo CD Applications.

---

# 11. Why `goTemplate: true`?

You'll see:

```yaml
goTemplate: true
```

Current ApplicationSet supports Go `text/template` rendering and recommends the `missingkey=error` option so missing template variables cause an explicit error rather than silently producing unexpected output. Sprig functions are also available, with a few exceptions. ([Argo CD][5])

Use:

```yaml
goTemplateOptions:
  - missingkey=error
```

Production reason:

Suppose you accidentally type:

```yaml
name: 'todo-{{ .environmnt }}'
```

instead of:

```yaml
name: 'todo-{{ .environment }}'
```

Without strict handling, template mistakes can be harder to detect.

With:

```text
missingkey=error
```

you prefer:

```text
FAIL CLEARLY
```

over:

```text
generate something strange
```

---

# 12. Never-forget rule for templates

Prefer:

```yaml
goTemplate: true

goTemplateOptions:
  - missingkey=error
```

for production-oriented ApplicationSets unless you have a reason not to.

---

# 13. Apply our first ApplicationSet

Save:

```text
todo-applicationset.yaml
```

Apply:

```bash
kubectl apply \
  -n argocd \
  -f todo-applicationset.yaml
```

Check:

```bash
kubectl get applicationset \
  -n argocd
```

Then:

```bash
kubectl get applications \
  -n argocd
```

You should conceptually see:

```text
todo-dev
todo-staging
todo-production
```

The controller reconciles the ApplicationSet CR into corresponding Application CRs. ([Argo CD][3])

---

# 14. Inspect ownership

Run:

```bash
kubectl get application todo-dev \
  -n argocd \
  -o yaml
```

You'll notice the Application isn't something you independently own anymore.

Conceptually:

```text
ApplicationSet
      │
      └──── owns/manages ────► Application
```

This creates another important operational rule:

> **Don't manually fight a generated Application.**

---

# 15. Why editing generated Applications is dangerous

Suppose ApplicationSet says:

```yaml
targetRevision: main
```

but you manually change generated:

```text
todo-production
```

to:

```yaml
targetRevision: emergency-fix
```

You may think:

```text
Done ✅
```

But ApplicationSet reconciliation can see:

```text
Generated Application
        !=
ApplicationSet template
```

and restore the Application to what the ApplicationSet declares.

The ApplicationSet controller is responsible for keeping its generated Applications aligned with the declared ApplicationSet. ([Argo CD][6])

Same GitOps principle again:

```text
Don't modify generated output.

Modify the source declaration.
```

---

# 16. Important ApplicationSet + auto-sync trap

This connects directly to Lesson 14.12.

For standalone Application:

```text
Want auto-sync off temporarily?

Change Application.
```

But for an Application generated by an ApplicationSet, directly changing:

```text
Application.spec.syncPolicy
```

may simply be reconciled by ApplicationSet.

Argo CD specifically documents this distinction for temporarily toggling auto-sync on Applications managed by ApplicationSets. ([Argo CD][7])

### Never forget

```text
Standalone Application
      ↓
edit Application


Generated Application
      ↓
edit ApplicationSet/source policy
```

---

# 17. List Generator with cluster data

List isn't limited to environments.

We could define:

```yaml
elements:

  - cluster: dev
    url: https://1.2.3.4

  - cluster: staging
    url: https://2.3.4.5

  - cluster: production
    url: https://3.4.5.6
```

Template:

```yaml
metadata:

  name: 'todo-{{ .cluster }}'

spec:

  destination:

    server: '{{ .url }}'
```

Then:

```text
List Generator
     │
     ├── dev cluster
     ├── staging cluster
     └── prod cluster
```

Simple and explicit.

But what happens when you have **50 clusters**?

Maintaining a literal list becomes less attractive.

That's where the next generator becomes powerful.

---

# 18. Cluster Generator

Argo CD already knows about registered Kubernetes clusters.

Think:

```text
Argo CD

Settings
   │
   ▼
Clusters

├── dev-eks
├── staging-eks
├── prod-mumbai
├── prod-singapore
└── prod-london
```

Why duplicate those clusters manually inside an ApplicationSet?

Use the:

```text
Cluster Generator
```

The Cluster generator derives parameters from clusters registered in Argo CD and can automatically react as matching clusters are added or removed. ([Argo CD][2])

---

# 19. Basic Cluster Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:

  name: todo-multicluster
  namespace: argocd

spec:

  goTemplate: true

  goTemplateOptions:

    - missingkey=error

  generators:

    - clusters: {}

  template:

    metadata:

      name: 'todo-{{ .nameNormalized }}'

    spec:

      project: todo-team

      source:

        repoURL: https://github.com/company/todo-gitops.git

        targetRevision: main

        path: apps/todo

      destination:

        server: '{{ .server }}'

        namespace: todo
```

Now every matching registered cluster can produce an Application. The Cluster generator exposes parameters such as cluster name and API server address for use in the template. ([Argo CD][8])

---

# 20. Imagine Argo knows three clusters

```text
dev-mumbai
staging-mumbai
prod-mumbai
```

Generator output becomes approximately:

```text
name=dev-mumbai
server=https://...


name=staging-mumbai
server=https://...


name=prod-mumbai
server=https://...
```

Template generates:

```text
todo-dev-mumbai
todo-staging-mumbai
todo-prod-mumbai
```

---

# 21. The big advantage

Later, the platform team adds:

```text
prod-singapore
```

to Argo CD.

You don't necessarily need to manually create:

```text
todo-prod-singapore Application
```

If the new cluster matches the generator criteria:

```text
New cluster registered
        │
        ▼
Cluster Generator sees it
        │
        ▼
Parameter generated
        │
        ▼
New Application generated
        │
        ▼
Workload deployed
```

That's powerful multi-cluster automation. ([Argo CD][2])

---

# 22. But deploying to EVERY cluster is usually dangerous

This:

```yaml
- clusters: {}
```

can mean:

```text
all clusters visible to generator
```

For a learning lab:

```text
okay
```

For production:

```text
usually too broad
```

Instead use:

```text
cluster labels
+
selectors
```

---

# 23. Label your clusters

Imagine cluster metadata:

```text
dev-mumbai

environment=dev
region=ap-south-1
team=todo
```

Another:

```text
prod-mumbai

environment=production
region=ap-south-1
team=todo
```

Then select only production:

```yaml
generators:

  - clusters:

      selector:

        matchLabels:

          environment: production
```

Cluster generators support Kubernetes-style label selectors, including `matchLabels` and `matchExpressions`. ([Argo CD][9])

Architecture:

```text
All Registered Clusters

       │
       ▼

environment=production ?

    ┌──┴──┐
    │     │
   YES    NO
    │      X
    ▼

Generate Application
```

---

# 24. Production example

Suppose:

```text
Cluster                Labels
────────────────────────────────────────

dev-mumbai             env=dev
stage-mumbai           env=staging
prod-mumbai            env=production
prod-singapore         env=production
prod-frankfurt         env=production
```

Generator:

```yaml
- clusters:

    selector:

      matchLabels:

        env: production
```

Generated:

```text
todo-prod-mumbai
todo-prod-singapore
todo-prod-frankfurt
```

Not:

```text
todo-dev-mumbai
todo-stage-mumbai
```

---

# 25. Cluster labels become platform metadata

This is a major Platform Engineering idea.

Labels can communicate:

```text
environment
region
cloud
business-unit
team
cluster-type
compliance-zone
tier
```

Example:

```text
environment=production
region=ap-south-1
cloud=aws
pci=true
```

ApplicationSet can then dynamically determine deployment targets.

Instead of hardcoding:

```text
Cluster A
Cluster B
Cluster C
```

you describe:

```text
Deploy to:

all production AWS clusters
in ap-south-1
belonging to team todo
```

That's declarative fleet management.

---

# 26. Important local-cluster detail

The Cluster generator can include both the local Argo CD cluster and remote registered clusters. The default local cluster behaves slightly differently around Secret-based label selection because it may not initially have the same cluster Secret representation as registered remote clusters. ([Argo CD][9])

Don't memorize the UI workaround yet.

Remember the concept:

```text
Cluster Selector
     │
     ▼
Understand how local cluster
is represented before relying
on Secret labels.
```

---

# 27. Now the Git Generator

This is where ApplicationSet becomes extremely useful with GitOps repositories.

The Git generator has two important subtypes:

```text
Git Directory Generator
Git File Generator
```

The directory form derives parameters from repository directory structure; the file form derives them from YAML/JSON file contents. ([Argo CD][10])

---

# 28. Git Directory Generator

Imagine our GitOps repository:

```text
gitops-repo/

apps/

├── checkout/
│   ├── deployment.yaml
│   └── service.yaml
│
├── payment/
│   ├── deployment.yaml
│   └── service.yaml
│
├── recommendation/
│   ├── deployment.yaml
│   └── service.yaml
│
└── todo/
    ├── deployment.yaml
    └── service.yaml
```

Normally we'd create:

```text
checkout Application
payment Application
recommendation Application
todo Application
```

manually.

Instead:

```text
Directory exists
      │
      ▼
Git Generator discovers directory
      │
      ▼
Application generated
```

---

# 29. Git Directory ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:

  name: microservices
  namespace: argocd

spec:

  goTemplate: true

  goTemplateOptions:

    - missingkey=error

  generators:

    - git:

        repoURL: https://github.com/company/gitops-repo.git

        revision: main

        directories:

          - path: apps/*

  template:

    metadata:

      name: '{{ .path.basename }}'

    spec:

      project: applications

      source:

        repoURL: https://github.com/company/gitops-repo.git

        targetRevision: main

        path: '{{ .path.path }}'

      destination:

        server: https://kubernetes.default.svc

        namespace: '{{ .path.basename }}'
```

The Git directory generator generates parameters from matching directory paths, including path-related values that can be used in Application templates. ([Argo CD][10])

---

# 30. Repository changes become Application lifecycle

Today Git contains:

```text
apps/

checkout/
payment/
todo/
```

ApplicationSet generates:

```text
checkout
payment
todo
```

Tomorrow someone adds:

```text
apps/inventory/
```

Then conceptually:

```text
Git commit
   │
   ▼
ApplicationSet detects inventory/
   │
   ▼
inventory Application generated
   │
   ▼
Argo CD deploys inventory
```

That gives teams a powerful onboarding model.

---

# 31. This is often called self-service onboarding

Imagine platform team says:

```text
To onboard a new microservice:

1. Create apps/<service-name>
2. Add valid deployment manifests
3. Submit PR
```

Once merged:

```text
ApplicationSet discovers folder
        │
        ▼
Application generated
        │
        ▼
Deployment managed by Argo CD
```

No platform engineer manually clicks:

```text
NEW APP
```

for every microservice.

That is the beginning of a developer platform.

---

# 32. But Git generator creates a security issue

This is extremely important.

Suppose developers can control:

```text
apps/*
```

and the ApplicationSet dynamically templates:

```yaml
project: '{{ something_from_git }}'
```

A malicious or accidental change might attempt to generate Applications into an overly privileged Argo CD project.

Argo CD explicitly warns that when Git generators are used with templated project fields, the Git source becomes security-sensitive and administrator approval should control changes capable of selecting privileged projects. ([Argo CD][11])

### Never forget

```text
ApplicationSet
can create Applications

Applications can deploy workloads

therefore

permission to control ApplicationSet input
can become deployment privilege
```

---

# 33. Git Directory include/exclude

Suppose repository:

```text
apps/

├── todo/
├── payment/
├── experimental/
└── archived/
```

You may not want:

```text
experimental
archived
```

ApplicationSets support include/exclude matching for Git directory discovery. ([Argo CD][10])

Conceptually:

```yaml
directories:

  - path: apps/*

  - path: apps/experimental
    exclude: true

  - path: apps/archived
    exclude: true
```

Result:

```text
todo     ✅
payment  ✅

experimental ❌
archived     ❌
```

---

# 34. Git File Generator

Directory structure is useful.

But sometimes we want **metadata**, not just directory names.

Imagine:

```text
clusters/

├── dev.yaml
├── staging.yaml
└── production.yaml
```

`dev.yaml`:

```yaml
cluster:

  name: dev-mumbai

  server: https://dev.example.internal

environment: dev

namespace: todo-dev
```

`production.yaml`:

```yaml
cluster:

  name: prod-mumbai

  server: https://prod.example.internal

environment: production

namespace: todo-production
```

Git File generator can parse matching YAML/JSON files and expose their contents as template parameters. ([Argo CD][10])

---

# 35. Git File Generator ApplicationSet

Conceptually:

```yaml
generators:

  - git:

      repoURL: https://github.com/company/gitops-repo.git

      revision: main

      files:

        - path: clusters/*.yaml
```

Then template:

```yaml
metadata:

  name: 'todo-{{ .environment }}'

spec:

  destination:

    server: '{{ .cluster.server }}'

    namespace: '{{ .namespace }}'
```

Now Git becomes a **deployment inventory database**.

---

# 36. Directory vs File Generator

Remember this distinction:

```text
Git Directory Generator
=
Directory existence/structure
drives Applications


Git File Generator
=
YAML/JSON configuration contents
drive Applications
```

Example:

```text
apps/payment/
      │
      ▼
Directory generator
      │
      ▼
payment Application
```

versus:

```text
clusters/prod.yaml

environment: production
region: ap-south-1
cluster: prod-mumbai

      │
      ▼
File generator
      │
      ▼
parameters
```

---

# 37. How quickly does Git Generator notice changes?

Current stable documentation says the Git generator polls repositories by default every **3 minutes**, configurable globally or per ApplicationSet with `requeueAfterSeconds`. ApplicationSet also supports Git-provider webhooks to reduce polling delay, and the `argocd.argoproj.io/application-set-refresh` annotation can force a refresh. ([Argo CD][10])

So don't assume:

```text
git push
     ↓
0.0001 seconds
     ↓
Application generated
```

There may be reconciliation/cache timing.

---

# 38. Manual refresh during troubleshooting

If you're testing:

```bash
kubectl annotate applicationset \
  microservices \
  -n argocd \
  argocd.argoproj.io/application-set-refresh=true
```

the refresh annotation can force the generator to resolve Git references again, and the controller removes the annotation after processing it. ([Argo CD][10])

Useful when you're thinking:

```text
"My folder exists.

Why hasn't my Application appeared?"
```

---

# 39. ApplicationSet troubleshooting chain

For Git-generated Applications:

```text
Git directory/file exists?
       │
       ▼

Pattern matches?
       │
       ▼

ApplicationSet sees revision?
       │
       ▼

Generator produces parameters?
       │
       ▼

Template renders?
       │
       ▼

AppProject allows generated app?
       │
       ▼

Application created?
       │
       ▼

Application sync succeeds?
       │
       ▼

Kubernetes healthy?
```

Don't jump directly to:

```text
restart Argo CD
```

---

# 40. Now we reach Matrix Generator

This is a major one.

Imagine:

```text
Applications:

todo
payment
inventory
```

and environments:

```text
dev
staging
production
```

We want:

```text
todo-dev
todo-staging
todo-production

payment-dev
payment-staging
payment-production

inventory-dev
inventory-staging
inventory-production
```

That's:

```text
3 apps × 3 environments
=
9 Applications
```

**Matrix Generator** produces combinations from two child generators—the Cartesian product of their generated parameter sets. ([Argo CD][12])

---

# 41. Matrix mental model

Generator A:

```text
todo
payment
inventory
```

Generator B:

```text
dev
staging
prod
```

Matrix:

```text
                 DEV       STAGING       PROD

TODO          todo-dev   todo-stage    todo-prod

PAYMENT       pay-dev    pay-stage     pay-prod

INVENTORY     inv-dev    inv-stage     inv-prod
```

Think:

```text
EVERY A
   ×
EVERY B
```

---

# 42. Matrix ApplicationSet

We can combine two List generators conceptually:

```yaml
generators:

  - matrix:

      generators:

        - list:

            elements:

              - app: todo
              - app: payment
              - app: inventory

        - list:

            elements:

              - env: dev
              - env: staging
              - env: production
```

Template:

```yaml
metadata:

  name: '{{ .app }}-{{ .env }}'
```

Generated:

```text
todo-dev
todo-staging
todo-production
payment-dev
...
```

Matrix explicitly combines parameters from two child generators into all possible combinations. ([Argo CD][12])

---

# 43. More realistic Matrix use

A much better real-world combination is:

```text
Git Generator
    │
    └── discovers applications

Cluster Generator
    │
    └── discovers deployment clusters
```

Matrix:

```text
Applications
      ×
Clusters
      =
Deploy each app
to each matching cluster
```

Architecture:

```text
           Git Generator

          todo
          payment
          inventory
               │
               │
               ▼

              MATRIX

               ▲
               │
               │

          Cluster Generator

          prod-mumbai
          prod-singapore
```

Generated:

```text
todo-prod-mumbai
todo-prod-singapore

payment-prod-mumbai
payment-prod-singapore

inventory-prod-mumbai
inventory-prod-singapore
```

That is serious multi-cluster automation.

---

# 44. But Matrix can create an explosion

Suppose:

```text
100 applications
×
30 clusters
```

Matrix produces:

```text
3,000 Applications
```

So before using Matrix ask:

```text
Do we actually want every combination?
```

If not:

```text
FILTER FIRST
```

Example:

```text
Cluster generator
   ↓
only team=payments

Git generator
   ↓
only payment apps

Matrix
```

Better than blindly multiplying everything.

---

# 45. Never-forget Matrix rule

```text
MATRIX
=
COMBINE EVERYTHING
```

If you need:

```text
base values
+
specific overrides
```

that's not really a Matrix problem.

That's where **Merge Generator** comes in.

---

# 46. Merge Generator

Suppose every cluster gets:

```text
redis=false
kafka=true
```

but staging should have:

```text
kafka=false
```

and production should additionally have:

```text
redis=true
```

We do **not** want a Cartesian product.

We want:

```text
Base settings
      +
matching overrides
```

The Merge generator starts with parameters from the first/base generator and overlays matching parameter sets from later generators using configured merge keys. Later matching generators can override earlier values. ([Argo CD][13])

---

# 47. Merge mental model

Base:

```text
DEV:
replicas=1
monitoring=true

STAGING:
replicas=1
monitoring=true

PROD:
replicas=1
monitoring=true
```

Overrides:

```text
PROD:
replicas=5
```

Merge result:

```text
DEV:
replicas=1
monitoring=true


STAGING:
replicas=1
monitoring=true


PROD:
replicas=5
monitoring=true
```

Think:

```text
BASE
 +
MATCHED OVERRIDE
 =
FINAL PARAMETERS
```

---

# 48. Matrix vs Merge

This is an important interview distinction.

## Matrix

```text
A × B
```

Creates combinations.

Example:

```text
3 apps
×
3 environments
=
9 Applications
```

---

## Merge

```text
Base parameters
+
matching override parameters
```

Does not create every combination.

Example:

```text
All clusters:
redis=false

Production:
redis=true
```

### Never forget

```text
MATRIX
=
multiply


MERGE
=
override
```

---

# 49. ApplicationSet and Helm

ApplicationSet doesn't care whether the generated Application deploys:

```text
plain YAML
Helm
Kustomize
Jsonnet
```

The generated object is still a normal Argo CD `Application`, and its template fields correspond to Application source/destination configuration. ([Argo CD][8])

Example:

```yaml
template:

  spec:

    source:

      repoURL: https://github.com/company/charts.git

      chart: todo

      targetRevision: 2.4.0

      helm:

        valueFiles:

          - 'values-{{ .env }}.yaml'
```

This creates an elegant pattern:

```text
One Helm chart
      │
      ├── values-dev.yaml
      ├── values-staging.yaml
      └── values-production.yaml
```

ApplicationSet chooses the correct values dynamically.

---

# 50. Example environment architecture

```text
                   ApplicationSet

                        │
                        ▼

          List Generator: environments

          dev
          staging
          production

                        │
                        ▼

                Application Template

                        │
          ┌─────────────┼─────────────┐

          ▼             ▼             ▼

      todo-dev     todo-staging   todo-production

          │             │             │

          ▼             ▼             ▼

     values-dev    values-stage    values-prod

          │             │             │

          └─────────────┼─────────────┘
                        ▼

                    Helm Chart
```

This removes large amounts of duplicated Argo Application YAML.

---

# 51. Production Git repository pattern

A scalable repository might look like:

```text
gitops-repo/

├── apps/
│
│   ├── todo/
│   │   ├── base/
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── production/
│   │
│   ├── payment/
│   │   ├── base/
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── production/
│   │
│   └── inventory/
│
├── clusters/
│
│   ├── dev-mumbai.yaml
│   ├── stage-mumbai.yaml
│   └── prod-mumbai.yaml
│
└── argocd/
    │
    ├── projects/
    ├── applicationsets/
    └── rbac/
```

Then:

```text
Git Generators
      │
      ▼
Discover apps/config

Cluster Generator
      │
      ▼
Discover clusters

Matrix/Merge
      │
      ▼
Generate correct Applications
```

---

# 52. ApplicationSet deletion is dangerous

Now we reach one of the most important production sections.

Suppose ApplicationSet manages:

```text
100 Applications
```

Then someone deletes:

```bash
kubectl delete applicationset production-apps \
  -n argocd
```

You need to understand:

```text
What happens to generated Applications?

What happens to their Kubernetes resources?
```

This is not something to discover experimentally in production.

ApplicationSet exposes policies controlling whether generated Applications may be created, updated, or deleted, and separate settings influence whether child workload resources are preserved when Applications are removed. ([Argo CD][6])

---

# 53. `applicationsSync` policies

ApplicationSet supports policies such as:

```text
sync
create-only
create-update
create-delete
```

Their purpose is to limit what kinds of modifications the ApplicationSet controller may make to generated Applications. ([Argo CD][6])

---

# 54. `sync`

Conceptually:

```yaml
syncPolicy:

  applicationsSync: sync
```

means ApplicationSet may:

```text
CREATE ✅
UPDATE ✅
DELETE ✅
```

This is the normal full reconciliation mode. ([Argo CD][14])

---

# 55. `create-only`

```yaml
applicationsSync: create-only
```

means:

```text
CREATE Applications ✅

UPDATE Applications ❌

DELETE Applications ❌
```

This may be useful where you want ApplicationSet only for initial generation without ongoing modification/deletion behavior. ([Argo CD][14])

---

# 56. `create-update`

```yaml
applicationsSync: create-update
```

means:

```text
CREATE ✅
UPDATE ✅
DELETE ❌
```

This is interesting for production safety.

Suppose Git directory:

```text
apps/payment/
```

is accidentally deleted.

ApplicationSet notices:

```text
payment no longer generated
```

Under unrestricted sync behavior, that could lead toward child Application deletion.

With:

```text
create-update
```

ApplicationSet is prevented from deleting Applications as a result of normal generator reconciliation. ([Argo CD][6])

---

# 57. `create-delete`

```yaml
applicationsSync: create-delete
```

means:

```text
CREATE ✅
DELETE ✅
UPDATE ❌
```

This is less common for ordinary workload fleets but exists as a distinct control. ([Argo CD][14])

---

# 58. Safety memory trick

```text
sync
=
C U D


create-only
=
C


create-update
=
C U


create-delete
=
C D
```

Where:

```text
C = Create
U = Update
D = Delete
```

---

# 59. Important deletion nuance

Don't think:

```text
applicationsSync: create-update

means:

Deleting the entire ApplicationSet
can NEVER delete Applications
```

Argo CD explicitly documents that preventing deletions caused by normal ApplicationSet reconciliation is not identical to protecting Applications from owner-reference/cascading deletion when the entire ApplicationSet object itself is deleted. Additional finalizer/deletion handling is required for that case. ([Argo CD][6])

This is an advanced but critical distinction.

---

# 60. Two different deletion scenarios

## Scenario A

Git generator output changes:

```text
Yesterday:

todo
payment
inventory


Today:

todo
inventory
```

So:

```text
payment
```

falls out of the generated set.

That's:

```text
generator reconciliation deletion
```

---

## Scenario B

Someone executes:

```bash
kubectl delete applicationset production-apps
```

That's:

```text
parent ApplicationSet deletion
```

Those are different lifecycle events.

Do not assume one protection automatically covers both.

---

# 61. `preserveResourcesOnDeletion`

ApplicationSet also provides:

```yaml
syncPolicy:

  preserveResourcesOnDeletion: true
```

to prevent an Application's managed Kubernetes resources from being deleted when the parent generated Application is deleted. ([Argo CD][15])

Conceptually:

```text
Application deleted
       │
       ▼

Should its Deployment,
Service, etc. disappear?

       │
       ├── normal cascade
       │
       └── preserveResourcesOnDeletion=true
                    │
                    ▼
              keep workloads
```

Use carefully.

---

# 62. Why preserve resources?

Imagine accidental ApplicationSet deletion.

Without protection:

```text
ApplicationSet
    DELETE
      │
      ▼
Applications
    DELETE
      │
      ▼
Workloads
    DELETE
```

Potential outage.

With appropriate preservation strategy:

```text
ApplicationSet removed accidentally
      │
      ▼
Applications/workload lifecycle
protected according to policy
```

This can provide recovery time.

But be careful:

```text
orphaned production resources
```

also create operational complexity.

Safety controls must come with a documented recovery process.

---

# 63. Production anti-pattern

Don't create your first production ApplicationSet like:

```text
500 production apps
      │
      ▼
fully automatic deletion
      │
      ▼
nobody has tested deletion behavior
```

Before production:

```text
Test:

directory removed
cluster removed
ApplicationSet removed
project changed
repo unavailable
template error
```

in a non-production environment.

---

# 64. ApplicationSet RBAC is powerful

Remember Lesson 14.13:

```text
Who may create ApplicationSets?
```

is a security question.

Argo CD's RBAC treats:

```text
applicationsets
```

as an Application-specific resource. Granting `create` on ApplicationSets effectively lets that user create Applications indirectly through an ApplicationSet. ([Argo CD][16])

So don't think:

```text
"They can't create Applications,
only ApplicationSets.

That's safer."
```

No.

An ApplicationSet is an **Application factory**.

---

# 65. Security model

```text
User
 │
 ▼
Can create ApplicationSet?
 │
 YES
 ▼
ApplicationSet
 │
 ▼
Can generate Applications
 │
 ▼
Applications
 │
 ▼
Can deploy Kubernetes resources
```

Therefore:

```text
ApplicationSet creation permission
=
significant deployment capability
```

---

# 66. Go template useful functions

Since we enabled:

```yaml
goTemplate: true
```

we can do more than simple variable substitution.

For example:

```yaml
name: '{{ .cluster | normalize }}-todo'
```

or default-like/template-processing patterns using supported Sprig/template functions.

ApplicationSet exposes Go templating with Sprig functions except specifically excluded functions such as environment-related ones documented by Argo CD. ([Argo CD][5])

Don't go crazy.

Prefer templates that remain understandable.

---

# 67. Bad template

```yaml
name: '{{ ((((some incredibly complicated function pipeline)))) }}'
```

Technically clever.

Operationally horrible.

Platform engineer at 03:00:

```text
"What on earth generated this Application name?"
```

Better:

```yaml
name: '{{ .app }}-{{ .environment }}'
```

Simple GitOps is easier to debug.

---

# 68. Generated Application labels

This becomes very useful.

Template:

```yaml
metadata:

  name: '{{ .app }}-{{ .env }}'

  labels:

    app: '{{ .app }}'

    environment: '{{ .env }}'

    team: '{{ .team }}'
```

Then Applications contain metadata like:

```text
todo-production

app=todo
environment=production
team=platform
```

Why is this useful?

Because labels help with:

```text
searching
filtering
RBAC patterns
progressive deployments
operational organization
```

And we'll use them shortly for Progressive Syncs.

---

# 69. ApplicationSet does not mean everything should deploy simultaneously

Imagine ApplicationSet generates:

```text
todo-dev
todo-staging
todo-production
```

You update the template image version.

The default mental model historically is:

```text
update generated Applications
together
```

But production often wants:

```text
DEV first
      ↓
wait healthy
      ↓
STAGING
      ↓
wait healthy
      ↓
PRODUCTION
```

This is where **Progressive Syncs** enter.

---

# 70. Progressive Syncs — current status

As of the current Argo CD documentation, ApplicationSet Progressive Syncs are a **Beta feature since v3.3.0**. They must be explicitly enabled, and because they are not a fully stable feature, production adoption should account for possible edge cases and upgrade compatibility. ([Argo CD][17])

This is important because older tutorials may call them:

```text
Alpha
Experimental
```

while current documentation now identifies them as:

```text
Beta since v3.3.0
```

---

# 71. Progressive Sync mental model

Without progressive control:

```text
ApplicationSet changed
       │
       ├── DEV update
       ├── STAGE update
       └── PROD update
```

With RollingSync:

```text
ApplicationSet changed
       │
       ▼
DEV
       │
       ▼
Healthy?
       │
      YES
       ▼
STAGING
       │
       ▼
Healthy?
       │
      YES
       ▼
PRODUCTION
```

The RollingSync strategy groups generated Applications using labels and waits for Applications in a step to become Healthy before progressing. ([Argo CD][17])

---

# 72. Default strategy: AllAtOnce

Current Progressive Sync documentation describes:

```text
AllAtOnce
```

as the default creation/update strategy.

That means generated Applications are updated together when ApplicationSet changes. ([Argo CD][17])

Conceptually:

```text
           New release v5

                │
       ┌────────┼────────┐
       ▼        ▼        ▼

      DEV     STAGING    PROD

       ↓        ↓        ↓

      v5       v5        v5
```

For some workloads:

```text
fine
```

For sensitive production:

```text
maybe not
```

---

# 73. RollingSync

ApplicationSet Progressive Syncs currently support:

```yaml
strategy:

  type: RollingSync
```

with sequential steps defined using labels and match expressions. Each group's Applications must become Healthy before moving to the next group, and `maxUpdate` can limit parallel updates within a group. ([Argo CD][17])

Example:

```yaml
strategy:

  type: RollingSync

  rollingSync:

    steps:

      - matchExpressions:

          - key: environment

            operator: In

            values:

              - dev


      - matchExpressions:

          - key: environment

            operator: In

            values:

              - staging


      - matchExpressions:

          - key: environment

            operator: In

            values:

              - production

        maxUpdate: 1
```

---

# 74. Deployment flow

```text
Release v6
     │
     ▼

Step 1
environment=dev
     │
     ▼
deploy
     │
     ▼
Healthy?
     │
    YES
     ▼

Step 2
environment=staging
     │
     ▼
deploy
     │
     ▼
Healthy?
     │
    YES
     ▼

Step 3
environment=production
     │
     ▼
maxUpdate=1
     │
     ▼
deploy production carefully
```

That's Application-level progressive delivery.

---

# 75. Important: RollingSync and auto-sync

Current Argo CD documentation notes that RollingSync disables automated sync on the generated Applications and drives synchronization itself through Application operations; RollingSync-triggered operations still respect controls such as Sync Windows. ([Argo CD][17])

This is important.

Don't assume:

```text
Application auto-sync
+
RollingSync
=
both independently driving deployment
```

RollingSync becomes the orchestrator for the generated Applications.

---

# 76. Progressive Sync vs Sync Wave

Very important distinction.

## Sync Wave

From Lesson 14.11:

```text
Orders resources
WITHIN one Application.
```

Example:

```text
Application: todo-production

Wave -10 → Config
Wave 0   → Backend
Wave 10  → Frontend
```

---

## Progressive Sync

```text
Orders multiple Applications
generated by ApplicationSet.
```

Example:

```text
todo-dev
   ↓
todo-staging
   ↓
todo-production
```

### Memory trick

```text
SYNC WAVE
=
resource ordering
inside ONE Application


PROGRESSIVE SYNC
=
Application ordering
inside an ApplicationSet fleet
```

---

# 77. Progressive Sync vs Argo Rollouts

Another important distinction.

Progressive Sync controls:

```text
Application A
   ↓
Application B
   ↓
Application C
```

It is not itself a replacement for:

```text
canary rollout
blue/green
traffic shifting
10% → 25% → 50% → 100%
```

The current documentation says ApplicationSet Progressive Syncs interact with Application health and do not provide direct rollout-controller integration. ([Argo CD][17])

We'll study **Argo Rollouts** separately later.

---

# 78. Think in three different levels

This distinction is powerful:

```text
LEVEL 1
ApplicationSet Progressive Sync

DEV Application
   ↓
STAGE Application
   ↓
PROD Application


LEVEL 2
Argo CD Sync Waves

Config
   ↓
Backend
   ↓
Frontend


LEVEL 3
Argo Rollouts

5% traffic
   ↓
25%
   ↓
50%
   ↓
100%
```

Different layers solving different ordering problems.

---

# 79. Production architecture

Now let's assemble everything we've learned in Module 14.

```text
                         Developer

                             │
                             ▼

                           Git

                             │
                             ▼

                      GitOps Repository

                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼

         Apps           Environments        Clusters
      directories       config files       metadata

           │                 │                 │
           └─────────────────┼─────────────────┘
                             ▼

                       ApplicationSet
                             │
                       Generators
                             │
        ┌────────────────────┼─────────────────────┐
        │                    │                     │

       Git                Cluster               Matrix/
    Generator            Generator               Merge

        │                    │                     │
        └────────────────────┼─────────────────────┘
                             ▼

                    Generated Applications

                             │
            ┌────────────────┼─────────────────┐
            ▼                ▼                 ▼

          DEV             STAGING             PROD

            │                │                 │
            └──────── Progressive Sync ────────┘

                             │
                             ▼

                         Application

                             │
                             ▼

                       Sync Phases/Waves

                             │
                             ▼

                         Kubernetes
```

That's a proper GitOps platform architecture.

---

# 80. Hands-on production lab — Part 1

Let's create a small fleet.

Repository:

```text
gitops-repo/

apps/

├── todo/
│   └── manifests/
│
├── payment/
│   └── manifests/
│
└── inventory/
    └── manifests/
```

We'll generate three Applications.

ApplicationSet:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:

  name: platform-services
  namespace: argocd

spec:

  goTemplate: true

  goTemplateOptions:

    - missingkey=error

  generators:

    - git:

        repoURL: https://github.com/company/gitops-repo.git

        revision: main

        directories:

          - path: apps/*

  template:

    metadata:

      name: '{{ .path.basename }}'

      labels:

        managed-by: applicationset

    spec:

      project: applications

      source:

        repoURL: https://github.com/company/gitops-repo.git

        targetRevision: main

        path: '{{ .path.path }}/manifests'

      destination:

        server: https://kubernetes.default.svc

        namespace: '{{ .path.basename }}'

      syncPolicy:

        automated:

          enabled: true

          prune: true

          selfHeal: true

        syncOptions:

          - CreateNamespace=true
```

The Git directory generator and Application template combination follows the documented ApplicationSet model. ([Argo CD][10])

---

# 81. Apply

```bash
kubectl apply \
  -n argocd \
  -f platform-services-appset.yaml
```

Check:

```bash
kubectl get applicationsets \
  -n argocd
```

Then:

```bash
kubectl get applications \
  -n argocd
```

Expected conceptually:

```text
inventory
payment
todo
```

---

# 82. Verify relation

```bash
kubectl describe applicationset \
  platform-services \
  -n argocd
```

Then:

```bash
argocd app list
```

Then:

```bash
argocd app get todo
```

Check:

```text
Project
Source
Destination
Sync Status
Health Status
```

---

# 83. Hands-on Part 2 — onboarding a new service

Create:

```text
apps/catalog/
```

with valid manifests.

Then:

```bash
git add apps/catalog

git commit \
  -m "onboard catalog service"

git push origin main
```

ApplicationSet Git Generator eventually detects the matching directory and creates the new generated Application according to its template. ([Argo CD][10])

Conceptually:

```text
Git:

apps/catalog/
      │
      ▼

Git Generator
      │
      ▼

path.basename=catalog
      │
      ▼

Template
      │
      ▼

Application:
catalog
```

That is self-service service onboarding.

---

# 84. Hands-on Part 3 — inspect failures

If `catalog` does not appear:

```bash
kubectl get applicationset \
  platform-services \
  -n argocd \
  -o yaml
```

Check controller logs:

```bash
kubectl logs \
  -n argocd \
  deployment/argocd-applicationset-controller
```

Then verify:

```text
repoURL correct?
revision exists?
path pattern matches?
repository credentials valid?
Go template variable valid?
AppProject permits project/source/destination?
```

You now have a deterministic debugging path.

---

# 85. Common error — invalid template variable

You write:

```yaml
name: '{{ .applicationName }}'
```

but generator does not provide:

```text
applicationName
```

With:

```yaml
goTemplateOptions:
  - missingkey=error
```

generation should fail clearly rather than silently using missing data. ([Argo CD][5])

This is one reason I want you using strict template options.

---

# 86. Common error — duplicate generated names

Suppose:

```text
apps/backend/
services/backend/
```

both generate:

```text
backend
```

using:

```yaml
name: '{{ .path.basename }}'
```

Now you have a naming collision.

Better:

```yaml
name: '{{ .path.basename }}-{{ .env }}'
```

or include another uniqueness dimension:

```text
team
cluster
region
environment
```

Your generated Application name must make sense at fleet scale.

---

# 87. Common error — every cluster gets everything

Generator:

```yaml
- clusters: {}
```

Template:

```text
production monitoring stack
```

Then:

```text
DEV cluster      gets it
STAGE cluster    gets it
PROD cluster     gets it
TEST cluster     gets it
```

because you forgot selectors.

Fix:

```yaml
selector:

  matchLabels:

    monitoring: enabled
```

### Never forget

```text
Dynamic discovery
without filtering
=
dynamic blast radius
```

---

# 88. Common error — Matrix explosion

You intended:

```text
5 apps
on
2 production clusters
```

but your Git generator matched:

```text
100 directories
```

and Cluster generator matched:

```text
30 clusters
```

Matrix:

```text
100 × 30
=
3,000 Applications
```

Always estimate:

```text
generator A count
×
generator B count
=
expected output
```

before applying.

---

# 89. Common error — manually editing generated Application

Operator:

```bash
kubectl edit application todo-production \
  -n argocd
```

changes:

```yaml
targetRevision: emergency
```

Then ApplicationSet reconciles it.

Operator:

```text
"Why did Argo undo me?"
```

Because:

```text
ApplicationSet
is source of truth
for generated Application definition.
```

Same lesson as self-healing, one level higher.

---

# 90. GitOps now has multiple reconciliation layers

This is important.

```text
ApplicationSet desired state
          │
          ▼
Application object

Application desired state
          │
          ▼
Kubernetes objects

Kubernetes controller desired state
          │
          ▼
Pods/runtime
```

So:

```text
ApplicationSet Controller
      reconciles Applications

Application Controller
      reconciles workload resources

Kubernetes Controllers
      reconcile runtime resources
```

Understanding **which controller owns which layer** is essential for troubleshooting.

---

# 91. Controller ownership troubleshooting

Suppose someone asks:

> Why does this value keep changing?

Ask:

```text
Which layer owns it?
```

Possible answers:

```text
ApplicationSet
      ↓
Application spec


Argo CD Application
      ↓
Deployment manifests


HPA
      ↓
Deployment replicas


Deployment Controller
      ↓
ReplicaSets/Pods
```

Do not fight controllers.

Modify the correct source of truth.

---

# 92. App-of-Apps vs ApplicationSet

You will hear both patterns.

Argo CD also supports the **App of Apps** pattern, where one parent Application manages manifests that create other Argo CD Applications. ([Argo CD][18])

Conceptually:

```text
App of Apps

Parent Application
     │
     ▼
Application YAML files
     │
     ▼
Child Applications
```

ApplicationSet:

```text
Generator
   +
Template
     │
     ▼
Generated Applications
```

---

# 93. Which should you prefer?

A useful mental model:

```text
App of Apps

good when:
you explicitly want Application manifests
stored as individual Git resources


ApplicationSet

good when:
many Applications follow a repeatable pattern
and should be generated from data/discovery
```

You will also see organizations use both.

Example:

```text
Bootstrap Application
        │
        ▼
Argo CD platform configs
        │
        ├── AppProjects
        ├── ApplicationSets
        └── platform Applications
```

---

# 94. ApplicationSet as a platform primitive

Once you understand this, you can build something like:

```text
Developer creates:

services/new-api/config.yaml
```

Containing:

```yaml
name: new-api
team: payments
environment: dev
repository: ...
```

ApplicationSet:

```text
reads config
      │
      ▼
generates Application
      │
      ▼
deploys service
```

Then platform team has created:

```text
Golden Path
```

for developers.

Developer doesn't need to understand every Argo CD object.

They provide approved metadata.

Platform automation does the rest.

This concept will return strongly in:

```text
Module 18 — Platform Engineering
```

---

# 95. Interview questions

### Q1. What is ApplicationSet?

An ApplicationSet is an Argo CD CRD/controller mechanism that uses generators and templates to automatically create and manage multiple Argo CD `Application` resources, especially useful for multi-cluster, monorepo, and fleet-style deployments. ([Argo CD][1])

---

### Q2. Does ApplicationSet directly deploy Deployments and Services?

No.

```text
ApplicationSet
    ↓
generates Applications

Applications
    ↓
manage Kubernetes resources
```

---

### Q3. What does the List Generator do?

Generates parameter sets from an explicitly defined list of arbitrary string key/value elements. ([Argo CD][4])

---

### Q4. What does the Cluster Generator do?

Generates Applications based on clusters known to Argo CD, optionally selecting them using metadata such as labels. ([Argo CD][2])

---

### Q5. What does the Git Directory Generator do?

Discovers matching directories in a Git repository and turns directory/path metadata into template parameters. ([Argo CD][10])

---

### Q6. Git File Generator?

Reads matching YAML/JSON files in Git and exposes their data as template parameters. ([Argo CD][10])

---

### Q7. Matrix Generator?

Combines the outputs of two child generators into every possible combination. ([Argo CD][12])

Memory:

```text
MATRIX = MULTIPLY
```

---

### Q8. Merge Generator?

Combines parameter sets that share configured merge keys so later matching values can override base-generator values. ([Argo CD][13])

Memory:

```text
MERGE = OVERRIDE
```

---

### Q9. Why use `goTemplateOptions: ["missingkey=error"]`?

To make missing Go template values fail explicitly instead of silently rendering an unintended result. ([Argo CD][5])

---

### Q10. Why shouldn't you manually edit generated Applications?

Because the ApplicationSet controller manages them from its generator/template desired state and can reconcile manual differences. ([Argo CD][6])

---

### Q11. What does `applicationsSync: create-update` do?

Allows ApplicationSet to create and update generated Applications while preventing normal reconciliation-driven Application deletion. ([Argo CD][6])

---

### Q12. What is `preserveResourcesOnDeletion`?

An ApplicationSet sync policy option used to prevent child resources managed by a generated Application from being deleted when that Application is deleted. ([Argo CD][15])

---

### Q13. What are Progressive Syncs?

A currently Beta ApplicationSet capability for controlling the order in which generated Applications are created/updated; `RollingSync` can group Applications by labels and wait for health before progressing. ([Argo CD][17])

---

### Q14. Progressive Sync vs Sync Wave?

```text
Progressive Sync
=
order Applications


Sync Wave
=
order resources
inside an Application
```

---

# 96. Never-forget generator map

Memorize this:

```text
                   ApplicationSet
                         │
                         ▼
                     GENERATORS

        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼

       LIST           CLUSTER            GIT

   static values    Argo clusters    Git structure/data

                                        │
                                  ┌─────┴─────┐
                                  ▼           ▼

                             DIRECTORY       FILE


                    COMBINATION GENERATORS

                       ┌───────┴───────┐
                       ▼               ▼

                     MATRIX           MERGE

                   Multiply          Override
```

---

# 97. The most important memory trick

```text
LIST
=
I tell Argo the values.


CLUSTER
=
Argo discovers clusters.


GIT DIRECTORY
=
folders generate Applications.


GIT FILE
=
config files generate Applications.


MATRIX
=
A × B.


MERGE
=
base + override.


APPLICATIONSET
=
Application factory.
```

---

# 98. Complete GitOps hierarchy

You can now understand a much larger architecture:

```text
                       Git

                        │
                        ▼

                  ApplicationSet
                        │
                        │ generates
                        ▼

                    Application
                        │
                        │ reconciles
                        ▼

                Kubernetes Resources
                        │
                        ▼

             Deployment / StatefulSet
                        │
                        │ reconciles
                        ▼

                   ReplicaSets
                        │
                        ▼

                       Pods
```

And each layer has a controller:

```text
ApplicationSet Controller
           │
           ▼
Application Controller
           │
           ▼
Kubernetes Controllers
```

This is a very strong mental model.

---

# 99. Production design checklist

Before using ApplicationSet in production, ask:

```text
1. What generator is driving Applications?

2. How many Applications will it produce?

3. How are clusters filtered?

4. How are Application names guaranteed unique?

5. Who controls the generator input?

6. Which AppProject will generated apps use?

7. Can generated apps target production?

8. What happens if generator input disappears?

9. Can ApplicationSet delete Applications?

10. Can deleting an Application delete workload resources?

11. Have deletion scenarios been tested?

12. Do we need AllAtOnce or RollingSync?

13. Are Application labels sufficient for fleet management?

14. Who has RBAC permission to create/change ApplicationSets?

15. What is our rollback/recovery procedure?
```

Those questions turn ApplicationSet from:

```text
"cool YAML automation"
```

into:

```text
production platform engineering
```

---

# 100. Lesson 14.15 complete

Our Module 14 progress now becomes:

```text
Module 14 — GitOps with Argo CD

14.1  GitOps Mental Model                         ✅
14.2  Argo CD Architecture                        ✅
14.3  Installation                                ✅
14.4  Applications                                ✅
14.5  Automated Reconciliation                    ✅
14.6  Repository Structure                        ✅
14.7  Helm + Argo CD                              ✅
14.8  Kustomize + Argo CD                         ✅
14.9  Production Repository Patterns              ✅
14.10 Advanced Application Management             ✅
14.11 Hooks, Phases & Sync Waves                  ✅
14.12 Drift, Self-Healing & Sync Policies         ✅
14.13 AppProject, RBAC & Multi-Team Security      ✅
14.14 Sync Windows & Deployment Governance        ✅
14.15 ApplicationSet & Multi-Cluster Automation   ✅
```

## Next — Lesson 14.16

### **Argo CD Multi-Cluster GitOps Architecture & Cluster Bootstrapping**

This takes ApplicationSet into a real enterprise AWS/EKS architecture:

```text
                         GitOps Repo

                              │
                              ▼

                         Central Argo CD

                              │
                    ApplicationSets
                              │

              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼

          EKS DEV         EKS STAGING      EKS PROD
        ap-south-1        ap-south-1      ap-south-1

              │               │               │
              ▼               ▼               ▼

        AppProject        AppProject       Restricted
          rules             rules          production

              │               │               │
              ▼               ▼               ▼

       Applications       Applications     Applications

              │               │               │
              ▼               ▼               ▼

         Kubernetes       Kubernetes       Kubernetes
```

Then we'll go deeper into **centralized vs per-cluster Argo CD, registering remote clusters, cluster credentials and trust boundaries, hub-and-spoke GitOps, EKS architecture, cluster labels, ApplicationSet Cluster Generator, bootstrap patterns, platform add-ons, workload separation, failure scenarios, disaster recovery, and how enterprises decide whether one Argo CD should manage 5 clusters or 500 clusters.**

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/?utm_source=chatgpt.com "Introduction to ApplicationSet controller - Argo CD"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/ "Generators - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/application-set/?utm_source=chatgpt.com "Generating Applications with ApplicationSet - Argo CD"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-List/?utm_source=chatgpt.com "List Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/GoTemplate/?utm_source=chatgpt.com "Go Template - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/?utm_source=chatgpt.com "Controlling Resource Modification - Argo CD - Read the Docs"
[7]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/?utm_source=chatgpt.com "Automated Sync Policy - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Template/?utm_source=chatgpt.com "Templates - Argo CD - Declarative GitOps CD for Kubernetes"
[9]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/ "Cluster Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[10]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/ "Git Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[11]: https://argo-cd.readthedocs.io/en/release-2.7/operator-manual/applicationset/Generators-Git/?utm_source=chatgpt.com "Git Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[12]: https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Generators-Matrix/?utm_source=chatgpt.com "Matrix Generator - Declarative GitOps CD for Kubernetes"
[13]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/ "Merge Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[14]: https://argo-cd.readthedocs.io/en/release-2.10/operator-manual/applicationset/Controlling-Resource-Modification/?utm_source=chatgpt.com "Controlling Resource Modification - Argo CD"
[15]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/applicationset-specification/?utm_source=chatgpt.com "ApplicationSet Specification Reference - Argo CD"
[16]: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/?utm_source=chatgpt.com "RBAC Configuration - Declarative GitOps CD for Kubernetes"
[17]: https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Progressive-Syncs/ "Progressive Syncs - Argo CD - Declarative GitOps CD for Kubernetes"
[18]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
