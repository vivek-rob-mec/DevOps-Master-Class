# Module 14 — GitOps with Argo CD

## Lesson 9: ApplicationSet — Multi-Environment & Multi-Cluster Application Generation

Until now, we have been creating individual Argo CD `Application` objects:

```text
todo-backend-dev.yaml

todo-backend-staging.yaml

todo-backend-prod.yaml
```

That works for three Applications.

But imagine:

```text
100 microservices
×
3 environments
×
4 regional clusters

=
1,200 Applications
```

Maintaining 1,200 nearly identical `Application` manifests manually would be a configuration-management failure.

ApplicationSet solves this.

The core architecture is:

```text
                  ApplicationSet
                        │
                        ▼
                   Generator
                        │
              produces parameters
                        │
                        ▼
                    Template
                        │
                        ▼
             Generated Applications
                │       │       │
                ▼       ▼       ▼
               Dev    Stage    Prod
                │       │       │
                ▼       ▼       ▼
             Argo Application Controller
                        │
                        ▼
                    Kubernetes
```

An ApplicationSet is therefore not a replacement for an Argo `Application`. It is a **higher-level controller that generates and manages Application resources**. Current Argo CD supports generators including List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request, Cluster Decision Resource, and Plugin. ([Argo CD][1])

---

# 14.1071 Application vs ApplicationSet

Keep this distinction permanent:

```text
Application
=
manages Kubernetes resources


ApplicationSet
=
manages Application resources
```

Hierarchy:

```text
ApplicationSet
     │
     ▼
Application
     │
     ▼
Deployment
Service
ConfigMap
HPA
...
```

So we now have **two reconciliation loops**:

```text
ApplicationSet Controller
        │
        ▼
Application objects
```

and:

```text
Application Controller
        │
        ▼
Kubernetes objects
```

That distinction becomes critical during debugging and deletion.

---

# 14.1072 The DRY problem

Without ApplicationSet:

```yaml
kind: Application
metadata:
  name: todo-dev
```

then:

```yaml
kind: Application
metadata:
  name: todo-staging
```

then:

```yaml
kind: Application
metadata:
  name: todo-prod
```

Most fields repeat:

```text
repoURL
targetRevision
syncPolicy
project pattern
application structure
```

Only a few fields change:

```text
name

path

cluster

namespace

environment
```

That's exactly the type of repetition ApplicationSet is designed to eliminate.

---

# 14.1073 ApplicationSet formula

Memorize:

```text
APPLICATIONSET

=

GENERATOR
+
TEMPLATE
```

Generator answers:

> What instances should exist?

Template answers:

> What should each generated Application look like?

Example:

```text
Generator:

dev
staging
prod
```

Template:

```text
name:
todo-{{environment}}

path:
overlays/{{environment}}

namespace:
todo-{{environment}}
```

Result:

```text
todo-dev

todo-staging

todo-prod
```

---

# 14.1074 Our first ApplicationSet — List Generator

Let's start with the easiest generator.

Create:

```bash
mkdir -p ~/argocd-labs/lesson-9
cd ~/argocd-labs/lesson-9
```

Then:

```bash
nano todo-list-appset.yaml
```

Use:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: todo-backend
  namespace: argocd

spec:

  goTemplate: true
  goTemplateOptions:
    - missingkey=error

  generators:

    - list:

        elements:

          - environment: dev
            namespace: todo-dev
            path: apps/todo-backend/overlays/dev

          - environment: staging
            namespace: todo-staging
            path: apps/todo-backend/overlays/staging

          - environment: prod
            namespace: todo-prod
            path: apps/todo-backend/overlays/prod

  template:

    metadata:
      name: 'todo-backend-{{.environment}}'

      labels:
        application: todo-backend
        environment: '{{.environment}}'

    spec:

      project: todo-{{.environment}}

      source:

        repoURL: https://git.example.com/company/todo-gitops.git

        targetRevision: main

        path: '{{.path}}'

      destination:

        server: https://kubernetes.default.svc

        namespace: '{{.namespace}}'

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

The List generator accepts arbitrary string key/value pairs and passes them into the ApplicationSet template. It does not itself register clusters in Argo CD; destination clusters still need to be known to Argo where applicable. ([Argo CD][2])

---

# 14.1075 Read the generator first

Ignore the template momentarily.

We have:

```yaml
elements:

  - environment: dev
    namespace: todo-dev

  - environment: staging
    namespace: todo-staging

  - environment: prod
    namespace: todo-prod
```

Think:

```text
Generator output row #1

environment=dev
namespace=todo-dev
```

Then:

```text
Generator output row #2

environment=staging
namespace=todo-staging
```

Then:

```text
Generator output row #3

environment=prod
namespace=todo-prod
```

Three parameter sets means:

```text
3 generated Applications.
```

---

# 14.1076 Template expansion

ApplicationSet takes:

```text
environment=dev
```

and evaluates:

```yaml
name: 'todo-backend-{{.environment}}'
```

giving:

```text
todo-backend-dev
```

Then:

```yaml
namespace: '{{.namespace}}'
```

becomes:

```text
todo-dev
```

Then it repeats for staging and prod.

Result:

```text
todo-backend-dev
todo-backend-staging
todo-backend-prod
```

That's Application generation.

---

# 14.1077 Go templating

For new ApplicationSets, we'll explicitly use:

```yaml
goTemplate: true

goTemplateOptions:
  - missingkey=error
```

Current Argo CD supports Go Text Template plus Sprig functions and recommends `missingkey=error` so referencing an undefined parameter produces an error instead of silently becoming an incorrect value. ([Argo CD][3])

Example typo:

```yaml
name: '{{.enviroment}}'
```

instead of:

```yaml
name: '{{.environment}}'
```

With:

```text
missingkey=error
```

we want:

```text
FAIL
```

not:

```text
generate strange Application name
and continue.
```

That's fail-left behavior.

---

# 14.1078 Go template dot syntax

Notice:

```text
{{.environment}}
```

not:

```text
{{environment}}
```

With Go templating enabled, generator parameters are referenced through the Go-template object using the leading dot. Git-generator path variables likewise become structured objects such as:

```text
{{.path.path}}

{{.path.basename}}

{{.path.basenameNormalized}}
```

rather than the older fast-template syntax. ([Argo CD][3])

---

# 14.1079 Go templating has limitations

ApplicationSet Go templates operate **per string field**.

They cannot directly template:

```text
boolean fields
```

or:

```text
entire object fields.
```

For example, this doesn't work as expected:

```yaml
helm:
  useCredentials: '{{.useCredentials}}'
```

because `useCredentials` is a boolean.

Likewise:

```yaml
syncPolicy: '{{.syncPolicy}}'
```

cannot turn a string into an entire object. Current Argo documentation explicitly calls out these limitations. ([Argo CD][3])

---

# 14.1080 Why that's important

ApplicationSet is not meant to become:

```text
generic arbitrary YAML generator
```

where every single Application field is dynamically serialized.

Prefer:

```text
stable Application structure

+

a few clearly templated values.
```

For example:

```text
name
path
namespace
cluster
project
revision
labels
```

That keeps generated Applications understandable.

---

# 14.1081 Preview before creating

Before creating an ApplicationSet that may eventually generate hundreds of Applications, preview it.

Current Argo CD supports:

```bash
argocd appset create \
  --dry-run \
  ./todo-list-appset.yaml \
  -o json
```

and the dry-run output can be inspected to see which Applications would be managed. ([Argo CD][4])

For names only:

```bash
argocd appset create \
  --dry-run \
  ./todo-list-appset.yaml \
  -o json \
  | jq -r '.status.resources[].name'
```

Expected conceptually:

```text
todo-backend-dev
todo-backend-staging
todo-backend-prod
```

---

# 14.1082 Production rule

Before applying:

```text
ApplicationSet generating 3 apps
```

dry-run is helpful.

Before applying:

```text
ApplicationSet generating 900 apps
```

dry-run is essential engineering discipline.

ApplicationSet has a large **multiplication factor**.

One typo can propagate everywhere.

---

# 14.1083 Create the ApplicationSet

Once the real Git repository/Projects exist:

```bash
kubectl apply -f todo-list-appset.yaml
```

Then:

```bash
kubectl get applicationsets -n argocd
```

And:

```bash
kubectl get applications -n argocd
```

Conceptually:

```text
APPLICATIONSET

todo-backend
```

generates:

```text
APPLICATIONS

todo-backend-dev
todo-backend-staging
todo-backend-prod
```

---

# 14.1084 Inspect ownership

Run conceptually:

```bash
kubectl get application \
  todo-backend-dev \
  -n argocd \
  -o yaml
```

ApplicationSet-generated Applications carry an ownership relationship back to the ApplicationSet. Current Argo CD uses owner references so generated `Application` lifecycle can follow the parent ApplicationSet. ([Argo CD][5])

Hierarchy:

```text
ApplicationSet/todo-backend
            │
            ├── Application/todo-backend-dev
            ├── Application/todo-backend-staging
            └── Application/todo-backend-prod
```

---

# 14.1085 Generated Application is not normally hand-owned

Suppose you manually edit:

```bash
kubectl edit application todo-backend-dev -n argocd
```

and change:

```text
path:
dev

→

path:
prod
```

ApplicationSet's next reconciliation compares the generated desired Application with the actual child and can restore it.

Therefore:

```text
ApplicationSet-managed Application
=
generated child
```

not:

```text
manually maintained independent Application.
```

---

# 14.1086 This is the same controller principle again

You wouldn't normally manually edit:

```text
ReplicaSet
```

owned by:

```text
Deployment
```

because Deployment reconciles it.

Similarly:

```text
ApplicationSet
```

owns:

```text
Application
```

which then owns/reconciles:

```text
workload resources.
```

Hierarchy:

```text
ApplicationSet controller
       │
       ▼
Application
       │
       ▼
Application controller
       │
       ▼
Deployment
       │
       ▼
Deployment controller
       │
       ▼
ReplicaSet
       │
       ▼
Pod
```

Controller upon controller upon controller.

That's Kubernetes-style architecture at scale.

---

# 14.1087 ApplicationSet sync policy vs Application sync policy

This terminology causes confusion.

You may see:

```yaml
spec:
  syncPolicy:
    applicationsSync: create-update
```

on the **ApplicationSet**.

And also:

```yaml
template:
  spec:
    syncPolicy:
      automated:
        ...
```

inside the generated **Application template**.

These control completely different relationships.

---

# 14.1088 ApplicationSet-level policy

This:

```yaml
spec:

  syncPolicy:

    applicationsSync: create-update
```

means:

> How may the ApplicationSet controller modify its generated `Application` resources?

Current policies include:

```text
sync

create-only

create-update

create-delete
```

with `sync` allowing create/update/delete and being the normal default controller behavior. ([Argo CD][4])

---

# 14.1089 Application-level policy

This:

```yaml
template:

  spec:

    syncPolicy:

      automated:
        enabled: true
        prune: true
        selfHeal: true
```

means:

> How may each generated Application reconcile its Kubernetes workload?

Therefore:

```text
ApplicationSet syncPolicy
=
ApplicationSet → Applications


Application syncPolicy
=
Application → Kubernetes resources
```

Never confuse those two.

---

# 14.1090 List Generator use cases

List is excellent when you have a small controlled inventory:

```text
Dev

Staging

Prod
```

or:

```text
Mumbai

Singapore
```

or:

```text
Cluster A

Cluster B

Cluster C
```

and you want explicit parameters.

Strength:

```text
simple
predictable
easy to review
```

Weakness:

```text
someone must maintain the list.
```

When inventory should be discovered automatically, other generators become more useful.

---

# 14.1091 Git Directory Generator

Now consider our Git repository:

```text
apps/
└── todo-backend/
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

Why manually write:

```yaml
elements:
  - dev
  - staging
  - prod
```

if Git already contains that inventory?

The Git Directory generator can discover matching directories and generate parameters from each matching path. Adding another matching directory can therefore result in another generated Application. ([Argo CD][6])

---

# 14.1092 Git Directory ApplicationSet

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: todo-backend
  namespace: argocd

spec:

  goTemplate: true
  goTemplateOptions:
    - missingkey=error

  generators:

    - git:

        repoURL: https://git.example.com/company/todo-gitops.git

        revision: main

        directories:

          - path: apps/todo-backend/overlays/*

  template:

    metadata:

      name: 'todo-backend-{{.path.basenameNormalized}}'

      labels:
        application: todo-backend
        environment: '{{.path.basename}}'

    spec:

      project: 'todo-{{.path.basename}}'

      source:

        repoURL: https://git.example.com/company/todo-gitops.git

        targetRevision: main

        path: '{{.path.path}}'

      destination:

        server: https://kubernetes.default.svc

        namespace: 'todo-{{.path.basename}}'
```

For matching paths, the Git Directory generator exposes values including the full path, path segments, basename, and normalized basename. ([Argo CD][6])

---

# 14.1093 What does the wildcard discover?

Repository:

```text
apps/todo-backend/overlays/
│
├── dev/
├── staging/
└── prod/
```

Pattern:

```text
apps/todo-backend/overlays/*
```

generates parameter sets roughly like:

```text
path.path =
apps/todo-backend/overlays/dev

path.basename =
dev
```

Then:

```text
staging
```

then:

```text
prod.
```

Current Git Directory generator exposes exactly those structured path values when Go templating is used. ([Argo CD][6])

---

# 14.1094 `basenameNormalized`

Suppose a directory name is:

```text
qa_team
```

A Kubernetes resource name cannot freely use every arbitrary character.

ApplicationSet offers:

```text
.path.basenameNormalized
```

which normalizes unsupported characters for resource naming. The Cluster generator similarly provides `nameNormalized` for cluster names. ([Argo CD][6])

So for metadata names, prefer:

```yaml
name: '{{.path.basenameNormalized}}-todo'
```

rather than assuming raw directory names are always Kubernetes-safe.

---

# 14.1095 Git-driven environment creation

Now something powerful happens.

Engineer creates:

```text
apps/todo-backend/overlays/qa/
```

and commits it.

Git Directory generator discovers:

```text
qa
```

ApplicationSet can create:

```text
todo-backend-qa
```

automatically.

Flow:

```text
Git directory added
       │
       ▼
ApplicationSet detects path
       │
       ▼
generates Application
       │
       ▼
Application reconciles overlay
       │
       ▼
QA workload appears
```

Current Git generator documentation specifically supports this directory-discovery model. ([Argo CD][6])

---

# 14.1096 This turns repository layout into platform API

Remember Lesson 7:

```text
repository structure
should be machine-readable.
```

Now we see why.

A path such as:

```text
apps/todo-backend/overlays/prod
```

is no longer just organization.

It becomes:

```text
declarative inventory
```

consumed by ApplicationSet.

Git directory structure becomes part of your internal platform contract.

---

# 14.1097 Excluding directories

Suppose:

```text
overlays/
├── dev/
├── staging/
├── prod/
└── experimental/
```

but experimental should not be generated.

Git Directory generator supports explicit exclusions. ([Argo CD][6])

Concept:

```yaml
directories:

  - path: apps/todo-backend/overlays/*

  - path: apps/todo-backend/overlays/experimental
    exclude: true
```

This is preferable to relying on engineers remembering:

```text
"Don't create that one manually."
```

---

# 14.1098 Git File Generator

Directory names can only carry so much metadata.

Suppose each environment needs:

```text
environment

cluster

namespace

project

region

tier

wave

compliance
```

Rather than encode everything in a directory name, create configuration files.

Example:

```text
environments/
├── dev/
│   └── config.yaml
├── staging/
│   └── config.yaml
└── prod/
    └── config.yaml
```

The Git File generator reads matching JSON/YAML files and exposes their contents as template parameters. ([Argo CD][6])

---

# 14.1099 Example environment metadata file

```yaml
environment: prod

namespace: todo-prod

project: todo-prod

region: ap-south-1

cluster:
  name: prod-mumbai

deployment:
  path: apps/todo-backend/overlays/prod
```

Now ApplicationSet can consume:

```text
.environment

.namespace

.project

.region

.cluster.name

.deployment.path
```

This is significantly more expressive than only using the folder name.

---

# 14.1100 Git File ApplicationSet

Conceptually:

```yaml
spec:

  goTemplate: true

  goTemplateOptions:
    - missingkey=error

  generators:

    - git:

        repoURL: https://git.example.com/company/todo-gitops.git

        revision: main

        files:
          - path: environments/*/config.yaml

  template:

    metadata:
      name: 'todo-backend-{{.environment}}'

    spec:

      project: '{{.project}}'

      source:

        repoURL: https://git.example.com/company/todo-gitops.git

        targetRevision: main

        path: '{{.deployment.path}}'

      destination:

        name: '{{.cluster.name}}'

        namespace: '{{.namespace}}'
```

The Git File generator also exposes metadata about the matching file itself, including directory path, path segments, filename, and normalized variants. ([Argo CD][6])

---

# 14.1101 Directory vs File Generator

Use this mental rule:

```text
DIRECTORY GENERATOR

directory existence itself
=
inventory
```

whereas:

```text
FILE GENERATOR

structured file contents
=
inventory + metadata
```

Directory generator is simpler.

File generator is more expressive.

---

# 14.1102 Production platform pattern

For a larger organization:

```text
clusters/
│
├── prod-mumbai/
│   └── config.yaml
│
├── prod-singapore/
│   └── config.yaml
│
└── dev-mumbai/
    └── config.yaml
```

Each config file might say:

```yaml
clusterName: prod-mumbai
environment: prod
region: ap-south-1
tier: production
compliance: pci
wave: "2"
```

Now Git becomes:

```text
cluster metadata catalog
```

and ApplicationSet generates cluster-specific Applications.

---

# 14.1103 Cluster Generator

Now suppose clusters are already registered with Argo CD.

Example:

```text
dev-mumbai

staging-mumbai

prod-mumbai

prod-singapore
```

Why maintain a second manual cluster inventory in ApplicationSet?

The Cluster generator discovers clusters registered with Argo CD and derives parameters from Argo CD's cluster metadata. Current parameters include:

```text
name

nameNormalized

server

project

cluster Secret labels

cluster Secret annotations
```

for registered clusters. ([Argo CD][7])

---

# 14.1104 Simplest Cluster Generator

```yaml
generators:

  - clusters: {}
```

means:

```text
generate parameter set
for Argo CD clusters
that match.
```

Template:

```yaml
metadata:
  name: 'todo-{{.nameNormalized}}'

spec:

  destination:
    server: '{{.server}}'
```

Now adding an appropriate cluster registration can result in another generated Application. ([Argo CD][7])

---

# 14.1105 Cluster registration still matters

ApplicationSet does **not** magically discover every EKS cluster in AWS.

Cluster generator operates on:

```text
clusters known to Argo CD.
```

Current Argo cluster registrations are represented through Argo's cluster configuration, with remote cluster information stored in labeled Secrets in the Argo namespace. ([Argo CD][7])

Think:

```text
AWS Account
contains 30 EKS clusters

but

Argo knows 8

→ Cluster Generator works with
the Argo-managed cluster inventory.
```

---

# 14.1106 Cluster labels become powerful metadata

Imagine cluster registration labels:

```text
environment=prod

region=ap-south-1

workload-tier=regulated
```

Cluster generator can select:

```yaml
clusters:

  selector:

    matchLabels:
      environment: prod
```

Then only Production clusters are targeted. Cluster generator supports both label matching and set-based expressions against cluster metadata. ([Argo CD][7])

---

# 14.1107 Example cluster topology

Argo knows:

```text
dev-mumbai
environment=dev


stage-mumbai
environment=staging


prod-mumbai
environment=prod


prod-singapore
environment=prod
```

Generator:

```yaml
clusters:

  selector:

    matchLabels:
      environment: prod
```

Result:

```text
prod-mumbai

prod-singapore
```

Dev and Stage are excluded.

---

# 14.1108 Multi-Region application generation

Now our DR architecture becomes:

```text
Argo CD
   │
   ▼
Cluster Generator
   │
   ├── prod-mumbai
   │
   └── prod-singapore
   │
   ▼
Generated Todo Applications
```

This is far better than copying cluster-specific Applications manually every time a regional cluster is added. ([Argo CD][7])

---

# 14.1109 Local-cluster nuance

The cluster on which Argo itself runs is treated specially.

Current Argo documentation notes that the default local cluster may not have the same cluster Secret representation as remote clusters. Therefore a selector relying specifically on the cluster-secret label:

```text
argocd.argoproj.io/secret-type=cluster
```

can exclude the default local cluster. Argo documents ways to create an explicit Secret representation when you want the local cluster to participate in label-based selection. ([Argo CD][7])

This is exactly the sort of subtle issue that causes:

> Why did ApplicationSet deploy to every cluster except the Argo cluster?

---

# 14.1110 List vs Cluster

Use:

```text
List Generator
```

when:

```text
YOU explicitly define
the inventory.
```

Use:

```text
Cluster Generator
```

when:

```text
ARGO'S cluster registration
is the inventory.
```

Cluster Generator becomes especially useful for platform add-ons:

```text
Prometheus agent

External Secrets

policy agent

logging agent

DNS controller
```

that should exist on every qualifying cluster.

---

# 14.1111 Matrix Generator

Now comes one of the most powerful generators.

Suppose we have:

```text
Applications:

todo
payments
orders
```

and:

```text
Clusters:

dev
staging
prod
```

We want:

```text
todo-dev
todo-staging
todo-prod

payments-dev
payments-staging
payments-prod

orders-dev
orders-staging
orders-prod
```

That is:

```text
3 × 3 = 9
```

The Matrix generator combines the parameter sets from **two child generators** and produces combinations of their outputs. ([Argo CD][8])

---

# 14.1112 Matrix mental model

```text
Generator A

todo
payments
orders
```

times:

```text
Generator B

dev
stage
prod
```

equals:

```text
todo-dev
todo-stage
todo-prod

payments-dev
payments-stage
payments-prod

orders-dev
orders-stage
orders-prod
```

Permanent mnemonic:

# **MATRIX = CARTESIAN PRODUCT**

---

# 14.1113 Matrix with Git + Cluster

A classic production architecture is:

```text
Git Directory Generator
=
which applications?
```

combined with:

```text
Cluster Generator
=
which clusters?
```

Matrix:

```text
Application directories
        ×
matching clusters
        ↓
one Application per combination.
```

Current Argo documentation specifically demonstrates Git Directory + Cluster as a Matrix use case. ([Argo CD][8])

---

# 14.1114 Example repository

```text
cluster-addons/
│
├── external-secrets/
├── metrics-server/
├── prometheus-agent/
└── policy-agent/
```

Argo knows:

```text
cluster-a
cluster-b
cluster-c
```

Matrix produces:

```text
external-secrets-cluster-a
external-secrets-cluster-b
external-secrets-cluster-c

metrics-server-cluster-a
...
```

This is fantastic for fleet management.

---

# 14.1115 Matrix ApplicationSet example

Conceptually:

```yaml
spec:

  goTemplate: true
  goTemplateOptions:
    - missingkey=error

  generators:

    - matrix:

        generators:

          - git:

              repoURL: https://git.example.com/platform-gitops.git

              revision: main

              directories:

                - path: cluster-addons/*

          - clusters:

              selector:

                matchLabels:
                  managed-addons: "true"

  template:

    metadata:

      name: '{{.path.basenameNormalized}}-{{.nameNormalized}}'

    spec:

      project: platform

      source:

        repoURL: https://git.example.com/platform-gitops.git

        targetRevision: main

        path: '{{.path.path}}'

      destination:

        server: '{{.server}}'

        namespace: '{{.path.basename}}'
```

One ApplicationSet can now manage an entire cluster add-on fleet. ([Argo CD][8])

---

# 14.1116 Matrix multiplication is also a danger

Suppose:

```text
100 application directories
```

and:

```text
50 clusters.
```

Naïve matrix:

```text
100 × 50
=
5,000 Applications.
```

Maybe you intended that.

Maybe you definitely did not.

Therefore before applying Matrix:

```text
FILTER
+
DRY RUN
+
COUNT.
```

ApplicationSet's power comes directly from multiplication.

---

# 14.1117 Use selectors to limit the product

Example clusters:

```text
tier=prod
```

or:

```text
addons=standard
```

Git directories can also include/exclude patterns.

The goal is:

```text
eligible app set
×
eligible cluster set
```

not:

```text
everything
×
everything.
```

Current generators support filtering through generator selectors and generator-specific selection mechanisms. ([Argo CD][1])

---

# 14.1118 Matrix with two Git generators

Suppose:

```text
Git generator A:
applications
```

and:

```text
Git generator B:
cluster configuration
```

Both naturally provide path-related parameters such as:

```text
.path.path
```

This causes naming collisions.

Argo provides:

```text
pathParamPrefix
```

to prefix path variables when combining Git generators in Matrix. Current documentation specifically requires one or both Git children to use it when path parameters would conflict. ([Argo CD][8])

---

# 14.1119 Merge Generator

Matrix says:

```text
combine every compatible pair.
```

Merge says something different:

> Start with a base parameter set and overlay matching parameter sets using selected merge keys.

Current Merge generator combines a base generator with matching outputs from subsequent generators; later matching generator values override earlier/base values. ([Argo CD][9])

---

# 14.1120 Merge use case

Imagine:

```text
All clusters:

Kafka enabled = true
```

except:

```text
Dev clusters:

Kafka enabled = false
```

and:

```text
Prod special cluster:

Kafka version = special
```

You don't want to manually duplicate every cluster entry.

Use:

```text
base cluster generator
```

plus:

```text
override generators.
```

Merge combines them using a key such as:

```text
server.
```

---

# 14.1121 Matrix vs Merge

Permanent distinction:

```text
MATRIX

A × B
```

while:

```text
MERGE

BASE
+
matching overrides
```

Matrix expands.

Merge enriches/overrides.

---

# 14.1122 Example

Matrix:

```text
Apps:
A B

Clusters:
1 2

Result:
A1 A2 B1 B2
```

Merge:

```text
Base:

cluster1 → region=mumbai
cluster2 → region=singapore

Override:

cluster2 → dr=true
```

Result:

```text
cluster1:
region=mumbai

cluster2:
region=singapore
dr=true
```

Very different use cases.

---

# 14.1123 Pull Request Generator

Now imagine:

```text
Developer opens PR #482.
```

You want:

```text
temporary preview environment
```

such as:

```text
todo-pr-482.example.com
```

The Pull Request generator discovers matching open PRs/MRs through supported SCM APIs and generates Applications from them. Current Argo documentation describes this specifically as a preview/test-environment use case. ([Argo CD][10])

---

# 14.1124 PR preview architecture

```text
Developer
    │
    ▼
Pull Request #482
    │
    ▼
SCM API
    │
    ▼
ApplicationSet
PR Generator
    │
    ▼
Application:
todo-pr-482
    │
    ▼
Namespace:
pr-482
    │
    ▼
Preview workload
```

When the PR no longer matches the generator criteria—for example after close/merge—the generated Application is removed according to the ApplicationSet lifecycle. ([Argo CD][10])

---

# 14.1125 Example PR generator

Conceptually:

```yaml
generators:

  - pullRequest:

      github:

        owner: company
        repo: todo-app

        labels:
          - preview

      requeueAfterSeconds: 1800
```

Template:

```yaml
metadata:
  name: 'todo-pr-{{.number}}'

spec:

  destination:

    namespace: 'todo-pr-{{.number}}'
```

Current PR generator defaults to periodic polling—documented as 30 minutes unless configured otherwise—and the ApplicationSet webhook server can be configured so SCM events trigger faster regeneration. ([Argo CD][10])

---

# 14.1126 Why preview environments are powerful

PR:

```text
feature/add-search
```

gets:

```text
isolated namespace
```

with:

```text
its own Deployment

its own Service

its own Ingress

its own temporary URL
```

QA/product reviewer can validate the change before merge.

Then closing the PR can trigger preview-environment cleanup.

This is powerful developer-platform functionality.

---

# 14.1127 But PR generators have serious security implications

Current Argo documentation warns explicitly about PR/SCM generators because they interact with SCM APIs and credentials, and because templating sensitive fields such as the Project can expand what externally influenced data may control. ApplicationSet creation itself should therefore be tightly restricted. ([Argo CD][10])

Never let:

```text
untrusted PR author
```

indirectly control:

```text
privileged AppProject

production destination

cluster-wide permissions
```

through poorly designed templating.

---

# 14.1128 Never template Project from untrusted input casually

Danger:

```yaml
project: '{{.somePRControlledValue}}'
```

If the PR generator's input can influence that value, a user might attempt to route a generated Application through a more privileged Project.

Current Argo explicitly warns about templated Project fields in SCM/PR generator security contexts. ([Argo CD][10])

Safer preview template:

```yaml
project: preview
```

hardcoded.

Then:

```text
preview AppProject
```

allows only:

```text
preview cluster

preview namespaces

limited resources.
```

---

# 14.1129 SCM Provider Generator

PR generator discovers:

```text
PRs.
```

SCM Provider generator discovers:

```text
repositories.
```

Current SCM Provider generator can scan SCM organizations/providers and automatically generate Applications for matching repositories. This suits organizations where microservices are distributed across many repos. ([Argo CD][11])

Example:

```text
GitHub organization:

payments-api
orders-api
todo-api
analytics-api
```

ApplicationSet can generate one Argo Application per matching repository.

---

# 14.1130 SCM Provider architecture

```text
GitHub / GitLab organization
          │
          ▼
ApplicationSet
SCM Generator
          │
      discovers repos
          │
          ▼
Generated Applications
```

This can enable:

```text
repository created
      │
      ▼
platform convention detected
      │
      ▼
Application automatically generated.
```

That's internal developer platform territory.

---

# 14.1131 Cluster Decision Resource Generator

Another current generator can consume Kubernetes custom resources that represent decisions about which Argo clusters should be targeted.

This becomes useful when some external cluster-placement system determines:

```text
which clusters
```

should receive a workload, and ApplicationSet consumes that decision. ([Argo CD][1])

You don't need it for ordinary Dev/Stage/Prod today, but you should recognize it in advanced architectures.

---

# 14.1132 Plugin Generator

What if none of the built-in generators can produce the inventory you need?

Current ApplicationSet Plugin generator lets the controller make HTTP RPC-style requests to custom logic that returns parameter objects. The plugin can be written in arbitrary languages and can itself be combined with Matrix or Merge. ([Argo CD][12])

Concept:

```text
ApplicationSet
     │
     ▼
Custom generator service
     │
     ├── CMDB
     ├── internal API
     ├── database
     └── platform inventory
     │
     ▼
parameter list
     │
     ▼
Applications
```

Very powerful.

Also another control-plane dependency to secure.

---

# 14.1133 Generator selection cheat sheet

Use:

| Generator                 | Best mental model                   |
| ------------------------- | ----------------------------------- |
| List                      | Explicit inventory                  |
| Git Directory             | Directories are inventory           |
| Git File                  | Files contain inventory metadata    |
| Cluster                   | Argo cluster registry is inventory  |
| Matrix                    | A × B combinations                  |
| Merge                     | Base + matched overrides            |
| Pull Request              | Open PRs create ephemeral apps      |
| SCM Provider              | Repositories are inventory          |
| Cluster Decision Resource | External cluster-placement decision |
| Plugin                    | Custom inventory logic              |

Current Argo exposes all of these generator families. ([Argo CD][1])

---

# 14.1134 Post selectors

Generators can additionally be filtered with:

```yaml
selector:
```

using Kubernetes-style label-selector semantics against generated values. ([Argo CD][13])

Example:

```yaml
selector:

  matchLabels:
    environment: prod
```

or:

```yaml
matchExpressions:

  - key: tier
    operator: In
    values:
      - critical
      - standard
```

Think:

```text
Generator
   │
   ▼
parameter sets
   │
   ▼
selector
   │
   ▼
only matching sets
   │
   ▼
template
```

---

# 14.1135 Generated labels are extremely important

Our template should often add metadata:

```yaml
metadata:

  labels:

    application: todo-backend
    environment: '{{.environment}}'
    region: '{{.region}}'
```

These labels become useful for:

```text
search

RBAC reasoning

notifications

Progressive Syncs

operations

fleet visibility.
```

Don't treat generated Application labels as decorative.

---

# 14.1136 Generated Application auto-sync

Suppose template contains:

```yaml
syncPolicy:

  automated:
    enabled: true
    prune: true
    selfHeal: true
```

Every generated Application inherits it.

That means:

```text
one ApplicationSet template edit
```

can enable:

```text
auto-prune
```

across hundreds of Applications.

This is why ApplicationSet changes are **high-blast-radius control-plane changes**.

---

# 14.1137 Do not manually disable auto-sync on a child and expect it to stick

We previewed this in Lesson 4.

If ApplicationSet template says:

```yaml
automated:
  enabled: true
```

and you manually edit one generated child:

```yaml
enabled: false
```

ApplicationSet may reconcile the child back to:

```yaml
enabled: true
```

because the generated Application is not independently owned.

Current Argo provides `ignoreApplicationDifferences` for cases where selected child Application fields should be temporarily allowed to diverge from the ApplicationSet-generated version. ([Argo CD][14])

---

# 14.1138 Temporarily allowing child auto-sync changes

Example:

```yaml
spec:

  ignoreApplicationDifferences:

    - jsonPointers:
        - /spec/syncPolicy
```

This can allow an operator to temporarily alter child sync policy without ApplicationSet immediately restoring that portion. Current Argo specifically documents temporarily toggling generated Application auto-sync as a common use case. ([Argo CD][14])

But use carefully.

Now you have:

```text
ApplicationSet declaration
```

plus:

```text
intentional child divergence.
```

That increases cognitive complexity.

---

# 14.1139 `ignoreApplicationDifferences` has limitations

ApplicationSet currently generates MergePatch-style updates, and lists may be replaced as entire lists when some portion changes.

This can make ignore rules involving fields inside arrays such as:

```text
spec.sources[]
```

less intuitive: a change elsewhere in the same list can cause the ignored field to be reset along with the replaced list. Argo's current documentation explicitly warns about this limitation. ([Argo CD][4])

So:

```text
ignore differences
```

is not a universal mechanism for arbitrary manual child customization.

---

# 14.1140 ApplicationSet lifecycle

This is one of the most dangerous parts of ApplicationSet.

Default lifecycle is conceptually:

```text
ApplicationSet
      │
      ▼
Application
      │
      ▼
Kubernetes resources
```

Delete the ApplicationSet and, under the normal cascading ownership/finalizer model, generated Applications and their managed resources can also be deleted. Current Argo documentation explicitly describes this lifecycle coupling. ([Argo CD][5])

---

# 14.1141 Why deletion can cascade

Generated Applications contain:

```text
ownerReference
→ ApplicationSet
```

and, when resources are not configured for preservation, Applications receive Argo's resource finalizer for workload cleanup. ([Argo CD][5])

Therefore:

```text
delete ApplicationSet
        │
        ▼
delete generated Applications
        │
        ▼
Application finalizer
        │
        ▼
delete managed workloads
```

Potential blast radius:

```text
entire fleet.
```

---

# 14.1142 Permanent rule

Never execute:

```bash
kubectl delete applicationset ...
```

in Production because:

> "I'll just recreate it."

until you understand:

```text
owner references

Application deletion

resource finalizers

preserveResourcesOnDeletion

cascade mode.
```

ApplicationSet deletion is not equivalent to deleting a harmless template file.

---

# 14.1143 `preserveResourcesOnDeletion`

ApplicationSet supports:

```yaml
spec:

  syncPolicy:

    preserveResourcesOnDeletion: true
```

This prevents the generated Applications from receiving the Argo resource-deletion finalizer used for cascading workload cleanup, so deleting the Application does not automatically remove its child workload resources. ([Argo CD][5])

Think:

```text
Delete ApplicationSet
      │
      ▼
Application may go away
      │
      ▼
Workload resources
remain
```

depending on the deletion path.

---

# 14.1144 But this changes ownership semantics

If workloads remain after deleting their Argo Applications:

```text
who owns them now?
```

You have potentially created:

```text
orphaned live infrastructure.
```

So:

```text
preserveResourcesOnDeletion=true
```

is not automatically:

```text
safer.
```

It's a lifecycle decision.

---

# 14.1145 Non-cascade deletion

Current Argo documentation also describes orphaning generated Applications when deleting an ApplicationSet through a non-cascading Kubernetes delete:

```bash
kubectl delete applicationset <NAME> \
  --cascade=orphan
```

This preserves the generated Applications themselves, but if those Applications retain their normal Argo deletion finalizer, later deleting the Applications can still cascade into their workloads. ([Argo CD][5])

So there are three different objects to think about:

```text
ApplicationSet

Application

Application workload resources.
```

---

# 14.1146 ApplicationsSync policies

ApplicationSet controller can be restricted to different child-modification modes.

Current semantics include: ([Argo CD][4])

```text
sync

Create:
YES

Update:
YES

Delete:
YES
```

```text
create-only

Create:
YES

Update:
NO

Delete due to generated-set diff:
NO
```

```text
create-update

Create:
YES

Update:
YES

Delete due to generated-set diff:
NO
```

```text
create-delete

Create:
YES

Update:
NO

Delete:
YES
```

---

# 14.1147 Why `create-update` can be useful

Imagine Git Directory Generator manages:

```text
100 Applications.
```

Someone accidentally removes:

```text
50 directories.
```

Default:

```text
ApplicationSet sees
50 Applications no longer generated
```

and can delete them.

With:

```yaml
applicationsSync: create-update
```

the ApplicationSet can create/update Applications but doesn't delete Applications merely because generator output disappears. ([Argo CD][4])

That's an extra safety mechanism for some environments.

---

# 14.1148 But applicationsSync doesn't solve ApplicationSet deletion by itself

Important nuance:

```text
create-update
```

can prevent generator-diff-driven child deletion.

But current Argo documentation warns it does **not by itself** prevent owner-reference cascading when the entire ApplicationSet is deleted. Additional finalizer/cascade handling is required for that scenario. ([Argo CD][14])

Never collapse:

```text
generator no longer generates child
```

and:

```text
parent ApplicationSet deleted.
```

into one deletion mechanism.

---

# 14.1149 Production deletion layers

Think:

```text
Layer 1

Generator output
```

Did an item disappear?

```text
Layer 2

ApplicationSet policy
```

May controller delete child?

```text
Layer 3

ApplicationSet deletion
```

Will owner refs delete Applications?

```text
Layer 4

Application finalizer
```

Will deleting Application remove workloads?

You need to reason through all four.

---

# 14.1150 Git directory deletion example

Repository:

```text
overlays/
├── dev
├── staging
└── prod
```

ApplicationSet generates:

```text
dev
staging
prod
```

Someone merges:

```text
delete overlays/prod
```

Generator now outputs:

```text
dev
staging
```

Default controller logic may interpret:

```text
prod Application
is no longer desired.
```

That can become:

```text
delete prod Application

→ potentially delete prod workload.
```

This is why Git directory deletion deserves production-level review.

---

# 14.1151 GitOps repository structure now controls Application existence

In ordinary Application GitOps:

```text
delete Deployment YAML
```

can prune:

```text
Deployment.
```

With ApplicationSet:

```text
delete environment directory
```

can remove:

```text
entire Application
```

which may remove:

```text
all resources in that Application.
```

ApplicationSet adds another deletion layer.

---

# 14.1152 Protect these paths heavily

Examples:

```text
applicationsets/

environments/prod/

clusters/prod/

appsets/
```

may deserve:

```text
CODEOWNERS

required reviews

policy validation

dry-run generation diff

deletion checks.
```

This is Git control-plane security again.

---

# 14.1153 ApplicationSet preview in CI

A strong ApplicationSet PR pipeline can calculate:

```text
Before:

97 Applications


After:

102 Applications
```

Then explicitly show:

```text
+ 6 applications
- 1 application
```

Deleting one generated Application should stand out like:

```text
Terraform plan:
1 destroy.
```

This is excellent platform safety.

---

# 14.1154 ApplicationSet dry-run as plan

Mental analogy:

```text
Terraform
→ terraform plan
```

ApplicationSet:

```text
argocd appset create --dry-run ...
```

Argo's dry-run populates generated resource information so you can inspect the child Application set before applying changes. ([Argo CD][4])

Not identical tools.

Same operational habit:

# **Review multiplication and deletion before reconciliation.**

---

# 14.1155 Progressive Syncs

Now another major problem.

Suppose ApplicationSet manages:

```text
100 production clusters.
```

A platform agent upgrade changes all 100 Applications.

Default ApplicationSet update strategy is effectively:

```text
update all matching generated Applications
```

rather than doing a staged fleet rollout. Current Argo's ApplicationSet Progressive Syncs feature adds ordered deployment strategies such as `RollingSync`. ([Argo CD][15])

---

# 14.1156 Current maturity — important

As of the current stable Argo documentation, **Progressive Syncs is a Beta feature since v3.3.0**. It is considered generally stable but may still contain unhandled edge cases and must be explicitly enabled in the ApplicationSet controller. ([Argo CD][15])

So we will learn it.

But we won't pretend:

```text
beta
=
boring mature default everywhere.
```

---

# 14.1157 Enabling Progressive Syncs

Current documented mechanisms include enabling the ApplicationSet controller with:

```text
--enable-progressive-syncs
```

or environment/config parameter equivalents such as:

```text
ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS=true
```

or the corresponding `argocd-cmd-params-cm` setting. ([Argo CD][15])

This is a controller-level feature gate.

Not just an Application YAML checkbox.

---

# 14.1158 RollingSync mental model

Instead of:

```text
100 clusters

↓ all at once

upgrade
```

you define groups:

```text
Wave 1:
Dev


Wave 2:
Staging


Wave 3:
Production canary 10%


Wave 4:
Remaining Production
```

ApplicationSet waits for selected Applications in one stage to become:

```text
Healthy
```

before proceeding to the next stage. ([Argo CD][16])

---

# 14.1159 Example labels

Generated Applications:

```text
envLabel=env-dev

envLabel=env-stage

envLabel=env-prod
```

Then:

```yaml
strategy:

  type: RollingSync

  rollingSync:

    steps:

      - matchExpressions:

          - key: envLabel
            operator: In
            values:
              - env-dev

      - matchExpressions:

          - key: envLabel
            operator: In
            values:
              - env-stage

      - matchExpressions:

          - key: envLabel
            operator: In
            values:
              - env-prod

        maxUpdate: 10%
```

Current RollingSync uses generated Application labels and `matchExpressions` to define ordered groups; `maxUpdate` limits concurrent Application updates within a group. ([Argo CD][15])

---

# 14.1160 RollingSync flow

```text
DEV Applications
      │
      ▼
sync
      │
      ▼
all Healthy?
      │
     YES
      ▼

STAGE Applications
      │
      ▼
sync
      │
      ▼
all Healthy?
      │
     YES
      ▼

PROD Applications
10% at a time
```

This helps reduce blast radius.

---

# 14.1161 Important RollingSync behavior

Current RollingSync **forces generated Applications to have auto-sync disabled** while the strategy controls sync operations itself. It triggers sync operations in a way that respects mechanisms such as Sync Windows and preserves Application retry configuration. ([Argo CD][15])

This is extremely important.

Don't design:

```text
Application auto-sync
+
RollingSync
```

and assume both independently control rollout ordering.

RollingSync takes control of the rollout.

---

# 14.1162 `maxUpdate`

Current RollingSync supports:

```text
integer
```

or:

```text
percentage.
```

For example:

```yaml
maxUpdate: 10%
```

means:

```text
only a fraction of matched
Applications update simultaneously.
```

The controller waits for batches to become Healthy before continuing. ([Argo CD][15])

This is fleet-level canarying.

---

# 14.1163 `maxUpdate: 0`

Interesting current behavior:

```yaml
maxUpdate: 0
```

can intentionally stop automatic updates for that stage.

That allows a pattern like:

```text
Dev
→ automatic

QA
→ manual gate

Prod
→ continue later
```

The current Progressive Sync example explicitly uses this pattern. ([Argo CD][15])

---

# 14.1164 Progressive Sync is not Argo Rollouts

Do not confuse:

```text
ApplicationSet RollingSync
```

with:

```text
Argo Rollouts
```

They operate at different levels.

```text
ApplicationSet Progressive Sync

=
roll many Applications
in an ordered manner
```

while:

```text
Argo Rollouts

=
progressively release workload replicas
inside an Application
```

Current Progressive Sync docs explicitly state that the feature operates through Application health and isn't intended as a direct integration with rollout controllers, though workloads such as Argo Rollouts can report health/progression to Argo. ([Argo CD][15])

---

# 14.1165 Two levels of progressive delivery

Imagine:

```text
10 clusters.
```

ApplicationSet RollingSync can do:

```text
Cluster 1
then Cluster 2
then Cluster 3...
```

Within each cluster, Argo Rollouts could do:

```text
5% Pods
25% Pods
50% Pods
100% Pods.
```

So:

```text
ApplicationSet
=
fleet rollout


Argo Rollouts
=
workload traffic/replica rollout
```

That's a powerful advanced architecture.

---

# 14.1166 Reverse deletion ordering

Current Progressive Syncs also supports deletion ordering, including a `Reverse` mode with RollingSync.

If creation order is:

```text
Backend
→ API
→ Frontend
```

reverse deletion can remove:

```text
Frontend
→ API
→ Backend
```

in the reverse stage order when that dependency model requires it. ([Argo CD][15])

Again, current feature is Beta, so use deliberate testing.

---

# 14.1167 ApplicationSet security boundary

Remember Lesson 8.

If a user can create an ApplicationSet whose template says:

```yaml
project: platform-admin

destination:
  namespace: kube-system
```

and generators let them produce hundreds of Applications, the privilege has just been multiplied.

Therefore:

```text
ApplicationSet create/update
```

is a high-trust platform operation.

Current Argo documentation explicitly flags security risks around SCM/PR generators and ApplicationSet-in-any-namespace due to secret access and cluster-discovery possibilities. ([Argo CD][11])

---

# 14.1168 ApplicationSet in any namespace

Modern Argo also supports ApplicationSets outside the normal Argo control-plane namespace when that feature is explicitly enabled along with Applications-in-any-namespace.

Generated Applications live in the same namespace as their ApplicationSet. This requires a cluster-scoped Argo installation and carries significant security considerations. ([Argo CD][17])

This is useful for platform self-service.

It is not something to switch on casually.

---

# 14.1169 Why it is particularly sensitive

Current Argo documentation warns that allowing arbitrary ApplicationSets in user namespaces can expose risks such as SCM/PR generator token exfiltration and cluster discovery through generators. ([Argo CD][17])

So:

```text
Application in any namespace
```

and:

```text
ApplicationSet in any namespace
```

are not merely convenience switches.

They affect the platform trust model.

---

# 14.1170 Production ownership model

A safe enterprise approach might be:

```text
Platform team
owns:

ApplicationSets

AppProjects

cluster registrations
```

while:

```text
Application teams
own:

approved Git overlay directories

image promotion config

application manifests
```

Then ApplicationSet automatically converts team-owned structured Git input into platform-governed Applications.

That's a powerful separation of responsibility.

---

# 14.1171 Git as self-service API

Application developer doesn't need:

```text
Argo admin
```

to request a new Dev environment.

Instead they create:

```text
environments/qa/config.yaml
```

through a reviewed PR.

Platform-controlled ApplicationSet says:

```text
I recognize approved environment configs
and generate safe Applications from them.
```

That's internal developer platform behavior:

```text
Git PR
=
self-service request.
```

---

# 14.1172 Guardrails remain in template

Team input may supply:

```text
environment name

image version

namespace suffix
```

but template hardcodes:

```text
AppProject

approved repo

destination cluster class

sync safety options.
```

This is much safer than letting application teams template:

```text
everything.
```

---

# 14.1173 Good self-service template

Developer-controlled metadata:

```text
appName

environment

imageTag
```

Platform-controlled:

```text
project

approved source repo

cluster selector

resource policies

sync settings.
```

Permanent principle:

> **Let tenants provide intent; keep privilege boundaries platform-owned.**

---

# 14.1174 Todo ApplicationSet design — Version 1

For our project, the most natural first production model is:

```text
Git Directory Generator
```

because we already designed:

```text
apps/
└── todo-backend/
    └── overlays/
        ├── dev/
        ├── staging/
        └── prod/
```

ApplicationSet:

```text
discovers overlays/*
```

and creates:

```text
todo-backend-dev
todo-backend-staging
todo-backend-prod.
```

This removes three hand-maintained Application files.

---

# 14.1175 Todo ApplicationSet full example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet

metadata:
  name: todo-backend
  namespace: argocd

spec:

  goTemplate: true

  goTemplateOptions:
    - missingkey=error

  generators:

    - git:

        repoURL: https://git.example.com/company/todo-gitops.git

        revision: main

        directories:

          - path: apps/todo-backend/overlays/*

          - path: apps/todo-backend/overlays/experimental
            exclude: true

  template:

    metadata:

      name: 'todo-backend-{{.path.basenameNormalized}}'

      labels:

        app.kubernetes.io/name: todo-backend

        environment: '{{.path.basename}}'

        managed-by: applicationset

    spec:

      project: 'todo-{{.path.basename}}'

      source:

        repoURL: https://git.example.com/company/todo-gitops.git

        targetRevision: main

        path: '{{.path.path}}'

      destination:

        server: https://kubernetes.default.svc

        namespace: 'todo-{{.path.basename}}'

      syncPolicy:

        automated:
          enabled: true
          prune: true
          selfHeal: true
          allowEmpty: false

        retry:

          limit: 5

          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m

        syncOptions:

          - CreateNamespace=true
          - PruneLast=true
          - FailOnSharedResource=true

  syncPolicy:

    applicationsSync: create-update

    preserveResourcesOnDeletion: false
```

This combines Git Directory generation with our production sync concepts from the previous lessons. Current ApplicationSet supports both per-child templates and parent-level ApplicationSet lifecycle policy controls. ([Argo CD][6])

---

# 14.1176 Notice the two `syncPolicy` blocks

Inside:

```yaml
template:
  spec:
    syncPolicy:
```

we configure:

```text
generated Application
→ workload behavior.
```

At:

```yaml
spec:
  syncPolicy:
```

we configure:

```text
ApplicationSet
→ Application lifecycle behavior.
```

Same field name.

Different resource level.

Interview trap.

---

# 14.1177 Why I used `create-update` in the example

For this learning production-oriented pattern:

```yaml
applicationsSync: create-update
```

means accidental disappearance of a generator entry doesn't immediately authorize ApplicationSet to delete the child Application through ordinary generated-set reconciliation. ([Argo CD][4])

That gives us an additional review opportunity.

But remember:

```text
it doesn't by itself protect
against deleting the parent ApplicationSet.
```

Deletion design remains separate.

---

# 14.1178 Dev vs Prod may deserve separate ApplicationSets

One big ApplicationSet:

```text
dev
staging
prod
```

is simple.

But this means one parent controls all environments.

For stronger blast-radius separation, you might eventually use:

```text
todo-nonprod ApplicationSet
```

and:

```text
todo-prod ApplicationSet.
```

Why?

Because:

```text
ApplicationSet bug
```

then doesn't necessarily span:

```text
Dev + Prod.
```

Again:

```text
ownership
+
blast radius
```

determine boundaries.

---

# 14.1179 ApplicationSet boundary is itself architecture

Ask:

```text
Which Applications
should always change
under the same generator/template lifecycle?
```

That answer tells you whether they belong to one ApplicationSet.

Do not create:

```text
company-everything-appset
```

merely because the controller technically supports many children.

---

# 14.1180 Platform add-on ApplicationSet

A much better large-scale use:

```text
cluster-addons
```

parent generates:

```text
external-secrets

monitoring-agent

policy-agent

logging-agent
```

across:

```text
all managed EKS clusters
```

with:

```text
Git × Cluster Matrix.
```

That is one coherent platform lifecycle.

---

# 14.1181 Workload ApplicationSet

Another:

```text
payments-services
```

generates:

```text
payments-api-dev

payments-api-stage

payments-api-prod
```

from:

```text
payments environment metadata.
```

Separate lifecycle.

Separate owners.

Separate blast radius.

---

# 14.1182 Multi-cluster Todo example

Later:

```text
todo-prod-mumbai
```

and:

```text
todo-prod-singapore
```

can be generated through Cluster/Matrix metadata.

Example labels:

```text
application=todo-backend

environment=prod

region=ap-south-1
```

and:

```text
application=todo-backend

environment=prod

region=ap-southeast-1
```

That can map naturally to our previous multi-region DR architecture.

---

# 14.1183 Production regions should not accidentally get the same capacity

Matrix says:

```text
Application
×
cluster.
```

But Mumbai might need:

```text
replicas=8
```

while Singapore warm standby:

```text
replicas=2.
```

Do not assume Matrix means identical runtime configuration.

Your Git file metadata or cluster labels can select:

```text
regional overlays

regional value files

capacity profiles.
```

ApplicationSet determines Application instances.

Kustomize/Helm determines rendered workload differences.

---

# 14.1184 Generator vs renderer

Another permanent distinction:

```text
APPLICATIONSET GENERATOR

determines:

WHICH Applications exist
```

whereas:

```text
HELM / KUSTOMIZE

determines:

WHAT Kubernetes resources
each Application renders.
```

Then:

```text
ARGO APPLICATION CONTROLLER

determines:

HOW desired/live state converges.
```

Three layers.

---

# 14.1185 Example

ApplicationSet:

```text
Generate:

todo-prod-mumbai
todo-prod-singapore
```

Kustomize:

```text
Mumbai overlay:
8 replicas

Singapore overlay:
2 replicas
```

Argo Application Controller:

```text
sync each rendered configuration.
```

Keep responsibilities separated.

---

# 14.1186 ApplicationSet troubleshooting flow

Use:

# **G → P → T → A → R → D → S → H**

```text
G
GENERATOR

Did it produce expected parameter sets?


P
PARAMETERS

Are parameter values correct?


T
TEMPLATE

Did the template generate correct Application spec?


A
APPLICATION

Does the generated child exist and look correct?


R
RENDER

Can that Application render Helm/Kustomize/YAML?


D
DIFF

What differs?


S
SYNC

Can it apply?


H
HEALTH

Does workload run?
```

This extends all of our previous troubleshooting models.

---

# 14.1187 Failure: no Application generated

Check:

```text
ApplicationSet exists?

Generator matches anything?

Git path correct?

Git credentials?

Cluster selector matches?

PR label matches?

missingkey error?

ApplicationSet controller healthy?
```

Commands:

```bash
kubectl get applicationset -n argocd
```

```bash
kubectl describe applicationset <NAME> -n argocd
```

```bash
kubectl logs \
  deployment/argocd-applicationset-controller \
  -n argocd
```

Now you're troubleshooting **generation**, not Kubernetes runtime.

---

# 14.1188 Failure: only two of three environments generated

Expected:

```text
dev
staging
prod
```

Actual:

```text
dev
staging
```

Don't immediately inspect Pods.

Start:

```text
Generator.
```

For Git Directory:

```text
Does prod directory match pattern?

Was it excluded?

Correct Git revision?

Correct repository?
```

For List:

```text
Does prod element exist?
```

For Cluster:

```text
Does prod cluster match labels?
```

---

# 14.1189 Failure: Application name invalid

Generated parameter:

```text
feature_my_branch
```

Template:

```yaml
name: '{{.branch}}'
```

Kubernetes name invalid.

Use current template helpers such as:

```text
normalize
```

or:

```text
slugify
```

for values intended to become Kubernetes-compatible names. Go Template support includes both helper functions. ([Argo CD][3])

Example:

```yaml
name: '{{.branch | normalize}}'
```

or:

```yaml
name: '{{.branch | slugify 40}}'
```

---

# 14.1190 Failure: child Application keeps reverting manual edit

That's probably correct.

ApplicationSet says:

```text
Generated child should be X.
```

You manually made it:

```text
Y.
```

ApplicationSet reconciliation:

```text
Y → X.
```

Fix:

```text
ApplicationSet generator/template
```

or the Git input driving it.

Do not fight the parent controller.

---

# 14.1191 Failure: deleted Git directory removed Application

Check:

```text
Generator output changed.
```

Then inspect:

```text
applicationsSync

preserveResourcesOnDeletion

Application finalizer

owner references

Git deletion.
```

Do not treat:

```text
Application disappeared
```

as a random Argo problem if the parent no longer generates it.

---

# 14.1192 Failure: workloads disappeared after deleting ApplicationSet

Likely lifecycle:

```text
ApplicationSet deleted
      │
      ▼
Applications deleted
      │
      ▼
resource finalizers
      │
      ▼
workloads deleted.
```

That's the documented default cascading model, not mysterious data loss. ([Argo CD][5])

This is exactly why ApplicationSet deletion requires extreme care.

---

# 14.1193 Failure: Matrix created far too many Applications

Formula:

```text
Git results
×
Cluster results
```

If:

```text
Git=20

Cluster=30
```

Matrix:

```text
600.
```

Fix selection logic:

```text
cluster labels

Git directory exclusions

post selectors

different ApplicationSet boundary.
```

Don't manually delete 500 generated Applications—they may come back.

---

# 14.1194 Failure: cluster Application not generated

Check:

```text
Is cluster actually registered in Argo?

Does Cluster generator selector match?

Does cluster Secret have expected labels?

Is it the special local cluster without matching Secret metadata?
```

Current Cluster generator operates directly from Argo's registered cluster metadata and label model. ([Argo CD][7])

---

# 14.1195 Failure: Pull Request preview not appearing quickly

PR generator normally polls according to:

```text
requeueAfterSeconds
```

with current documented default of 30 minutes.

For faster event-driven behavior, configure ApplicationSet's webhook server integration with the SCM provider. ([Argo CD][10])

So:

```text
PR opened 30 seconds ago
```

plus:

```text
no webhook
```

doesn't necessarily mean broken.

---

# 14.1196 Failure: RollingSync isn't respecting child's auto-sync

That's because current RollingSync intentionally disables auto-sync on generated Applications while Progressive Sync controls progression. ([Argo CD][15])

Troubleshooting must start with:

```text
Are Progressive Syncs enabled?

Is RollingSync configured?

Which label step matched?

What is maxUpdate?

Are previous apps Healthy?
```

---

# 14.1197 Failure: RollingSync stuck forever

Stage 1 Applications:

```text
Healthy
Healthy
Degraded
Healthy
```

RollingSync waits.

Why?

Current Progressive Sync logic uses Application health as the progression gate. Every selected Application in the current group must meet the expected Healthy condition before the next stage advances. ([Argo CD][15])

Now troubleshoot:

```text
Degraded Application.
```

Don't bypass the rollout automatically.

---

# 14.1198 ApplicationSet observability

At minimum monitor:

```text
ApplicationSet reconciliation errors

generated Application count

generation failures

Git/SCM API errors

unexpected child deletion

Applications stuck OutOfSync

Applications stuck Degraded

Progressive Sync progression

controller availability.
```

Because ApplicationSet is:

```text
fleet-generation control plane.
```

A healthy Application controller does not guarantee ApplicationSet generation is healthy.

---

# 14.1199 Controller logs

For generator issues:

```bash
kubectl logs \
  deployment/argocd-applicationset-controller \
  -n argocd
```

Current Argo can also log generated patches at debug level when investigating unexpected Application modifications. ([Argo CD][4])

Use this when asking:

```text
Why did ApplicationSet
change this child field?
```

---

# 14.1200 Interview — What is ApplicationSet?

Strong answer:

> **ApplicationSet is an Argo CD controller and custom resource that generates and manages multiple Argo `Application` resources from parameter-producing generators and an Application template. It is useful for multi-environment, multi-cluster, monorepo, fleet, preview-environment, and self-service GitOps patterns.** ([Argo CD][18])

---

# 14.1201 Interview — Application vs ApplicationSet

```text
ApplicationSet

reconciles
Application CRs


Application

reconciles
Kubernetes resources.
```

That's the clean answer.

---

# 14.1202 Interview — Generator vs Template

```text
Generator
=
which instances?


Template
=
what does each Application look like?
```

Then:

```text
parameters
+
template
=
generated Applications.
```

---

# 14.1203 Interview — List Generator

Strong answer:

> **The List generator supplies explicitly declared string key/value parameter sets to the Application template. It is simple and predictable for small static inventories such as a known set of environments or clusters.** ([Argo CD][2])

---

# 14.1204 Interview — Git Directory Generator

> **It discovers matching directories in a Git repository and exposes path metadata such as the full path and basename to the Application template. Adding or removing matching directories changes the generated Application inventory.** ([Argo CD][6])

---

# 14.1205 Interview — Git File Generator

> **It discovers matching YAML/JSON configuration files and exposes their structured contents as parameters, which is useful when directory names alone do not carry enough environment or cluster metadata.** ([Argo CD][6])

---

# 14.1206 Interview — Cluster Generator

> **It generates parameters from clusters already registered in Argo CD, including cluster names, API server addresses, and cluster Secret metadata such as labels and annotations. It can filter clusters with selectors.** ([Argo CD][7])

---

# 14.1207 Interview — Matrix

Answer:

> **Matrix takes the outputs of two child generators and creates combinations of those parameter sets—effectively a Cartesian product—so it is useful for patterns such as applications × clusters.** ([Argo CD][8])

---

# 14.1208 Interview — Merge

Answer:

> **Merge starts with parameters from a base generator and overlays parameters from matching subsequent generators using configured merge keys. Later matching values override earlier ones, so it is useful for defaults plus exceptions.** ([Argo CD][9])

---

# 14.1209 Interview — PR Generator

Strong answer:

> **The Pull Request generator discovers matching open PRs or merge requests from a supported SCM provider and can generate temporary Applications, making it useful for preview environments. When a PR stops matching—such as after close or merge—the corresponding generated Application is removed according to ApplicationSet lifecycle policy.** ([Argo CD][10])

---

# 14.1210 Interview — Why `missingkey=error`?

Because:

```text
undefined generator parameter
```

should fail template generation instead of silently producing a malformed Application.

Current Argo recommends this Go-template option even though it is not the default for compatibility reasons. ([Argo CD][3])

---

# 14.1211 Interview — Can Go templates template everything?

No.

Current ApplicationSet Go templates operate on:

```text
string fields
```

on a per-field basis.

You cannot directly use the Go template mechanism to dynamically generate arbitrary boolean/object fields such as an entire `syncPolicy` object. ([Argo CD][3])

---

# 14.1212 Interview — Why not edit generated Application manually?

Because ApplicationSet is its parent controller and may reconcile your manual edit back to the state produced by the generator/template.

If manual divergence is intentionally required, design it explicitly—such as through `ignoreApplicationDifferences`—rather than fighting the controller. ([Argo CD][14])

---

# 14.1213 Interview — `applicationsSync`

Answer:

```text
ApplicationSet-level
lifecycle policy
```

controlling whether the ApplicationSet controller may:

```text
create

update

delete
```

generated Application resources. Current modes include `sync`, `create-only`, `create-update`, and `create-delete`. ([Argo CD][4])

---

# 14.1214 Interview — `preserveResourcesOnDeletion`

> **It prevents generated Applications from using the normal resource-deletion finalizer for their workloads, so Application deletion does not automatically cascade into deleting the managed cluster resources. It changes lifecycle ownership and can leave workloads behind, so it should be an intentional decision.** ([Argo CD][5])

---

# 14.1215 Interview — What happens when ApplicationSet is deleted?

Default conceptual chain:

```text
ApplicationSet
deleted

↓

generated Applications
deleted through ownership

↓

their managed resources
may be deleted through
Argo deletion finalizers.
```

That's current documented ApplicationSet lifecycle behavior unless preservation/non-cascade controls alter it. ([Argo CD][5])

---

# 14.1216 Interview — Progressive Sync

> **ApplicationSet Progressive Syncs let you update generated Applications in ordered groups according to labels and Application health instead of updating the whole fleet simultaneously. RollingSync can restrict concurrency with `maxUpdate`.** ([Argo CD][15])

Then add:

> **As of current Argo documentation, Progressive Syncs is Beta and must be explicitly enabled.** ([Argo CD][15])

That's the current-version senior answer.

---

# 14.1217 Interview — ApplicationSet RollingSync vs Argo Rollouts

```text
ApplicationSet RollingSync

=
progress across Applications


Argo Rollouts

=
progress within a workload release.
```

You can use both at different layers.

---

# 14.1218 Interview trap — Matrix merges overrides

Wrong.

Matrix:

```text
combines parameter sets
into combinations.
```

Merge:

```text
matches parameter sets
and overlays values.
```

Different generators.

---

# 14.1219 Interview trap — Cluster Generator discovers all AWS clusters

Wrong.

It uses:

```text
clusters registered with Argo CD.
```

It isn't an AWS Organizations/EKS inventory scanner. ([Argo CD][7])

---

# 14.1220 Interview trap — ApplicationSet creates cluster credentials

Wrong.

Generator inventory does not automatically register Kubernetes clusters or provide destination credentials. For List in particular, current docs explicitly state clusters must already be defined in Argo CD. ([Argo CD][2])

---

# 14.1221 Interview trap — generated Application is independent

Wrong.

Its ApplicationSet is the authoritative generator/controller unless you intentionally configure divergence.

---

# 14.1222 Interview trap — deleting a Git directory only cleans Git

Wrong.

If directory existence drives Application generation:

```text
directory deletion
```

can become:

```text
Application deletion
```

which can become:

```text
workload deletion.
```

Deletion chain must be reviewed.

---

# 14.1223 Interview trap — `create-update` prevents all deletion

Wrong.

It prevents ApplicationSet's normal generated-set comparison from deleting Applications, but current Argo warns that owner-reference cascading when deleting the ApplicationSet is a separate concern. ([Argo CD][4])

---

# 14.1224 Interview trap — RollingSync + auto-sync both run normally

Wrong.

Current RollingSync forces generated Application auto-sync off while RollingSync orchestrates synchronization. ([Argo CD][15])

---

# 14.1225 Interview trap — `maxUpdate: 10%` means 10% of Pods

Wrong.

It is:

```text
percentage of generated Applications
in that RollingSync group.
```

Pod-level rollout behavior belongs to Deployment/Rollout controllers.

---

# 14.1226 ApplicationSet production checklist

Before introducing ApplicationSet to Production, verify:

```text
□ Generator output is predictable

□ goTemplate enabled intentionally

□ missingkey=error configured

□ generated names normalized

□ template Project is restricted

□ template destinations are restricted

□ generator multiplication calculated

□ Git directories/files are CODEOWNED

□ deletion paths reviewed

□ ApplicationSet dry-run is part of PR review

□ applicationsSync policy is intentional

□ preserveResourcesOnDeletion decision documented

□ generated Applications aren't manually owned

□ cluster selector labels are controlled

□ Matrix filters avoid accidental explosion

□ remote Git/SCM credentials are least privilege

□ PR/SCM generator security reviewed

□ ApplicationSet creation permission is restricted

□ controller logs/metrics monitored

□ Progressive Sync Beta status understood before adoption

□ rollback/deletion runbooks exist
```

---

# 14.1227 Never-forget ApplicationSet rules

```text
1.

Application
manages Kubernetes resources.


2.

ApplicationSet
manages Applications.


3.

Generator
produces parameter sets.


4.

Template
turns parameters into Applications.


5.

List
=
explicit inventory.


6.

Git Directory
=
directories are inventory.


7.

Git File
=
files provide structured inventory.


8.

Cluster Generator
=
Argo cluster registry is inventory.


9.

Matrix
=
A × B.


10.

Merge
=
base + overrides.


11.

PR Generator
=
ephemeral preview Applications.


12.

SCM Generator
=
repository discovery.


13.

Use Go Template
for new designs.


14.

Use missingkey=error.


15.

Go templates work
per string field.


16.

Generated Applications
belong to ApplicationSet.


17.

Don't manually fight
generated child specs.


18.

ApplicationSet syncPolicy
!=
Application syncPolicy.


19.

applicationsSync
controls child Application lifecycle.


20.

Application auto-sync
controls workload reconciliation.


21.

Deleting generator input
can delete Applications.


22.

Deleting ApplicationSet
can cascade much further.


23.

preserveResourcesOnDeletion
changes workload deletion behavior.


24.

Dry-run ApplicationSet changes
before fleet rollout.


25.

Count Matrix output
before applying.


26.

Label clusters intentionally.


27.

Don't template privileged Projects
from untrusted input.


28.

Protect ApplicationSet Git paths
like production control-plane code.


29.

Progressive Syncs
roll Applications in stages.


30.

RollingSync
is currently Beta.


31.

RollingSync is fleet-level,
not Pod-level rollout.


32.

ApplicationSet turns
repository structure into platform automation.
```

---

# 14.1228 Complete ApplicationSet control flow

```text
                         GIT / CLUSTERS / SCM
                                  │
                                  ▼
                              GENERATOR
                                  │
                         parameter objects
                                  │
                                  ▼
                              TEMPLATE
                                  │
                                  ▼
                         APPLICATIONSET
                            CONTROLLER
                                  │
                 ┌────────────────┼────────────────┐
                 ▼                ▼                ▼

          Application Dev   Application Stage  Application Prod

                 │                │                │
                 └────────────────┼────────────────┘
                                  ▼

                       APPLICATION CONTROLLER
                                  │
                             render/diff
                                  │
                                  ▼
                            KUBERNETES
```

And with Matrix:

```text
             Git Apps
               │
               ├──────┐
               │      │
               ▼      │
             Matrix   │
               ▲      │
               │      │
           Clusters ──┘
               │
               ▼

App × Cluster combinations
               │
               ▼
          Applications
```

---

# 14.1229 Production Todo architecture after Lesson 9

We started the Argo module with:

```text
one manually created
guestbook Application.
```

Now we can design:

```text
                     TODO SOURCE REPO
                            │
                            ▼
                          Jenkins
                            │
                       build once
                            │
                            ▼
                            ECR
                            │
                            ▼
                      TODO GITOPS
                            │
                ┌───────────┴───────────┐
                ▼                       ▼

        Kustomize overlays       environment metadata
                │                       │
                └───────────┬───────────┘
                            ▼
                      ApplicationSet
                            │
                  Git / Cluster generators
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼

       todo-backend-dev   stage          prod
              │             │             │
              ▼             ▼             ▼
            Argo          Argo          Argo
              │             │             │
              ▼             ▼             ▼
                       Kubernetes
```

At multi-region scale:

```text
ApplicationSet
      │
      ├── todo-prod-mumbai
      └── todo-prod-singapore
```

and later we can combine:

```text
environment metadata
×
cluster inventory
```

without manually copying Application YAML.

---

# 14.1230 Lesson 9 troubleshooting mnemonic

Memorize:

# **G-P-T-A-R-D-S-H**

```text
GENERATOR
     │
     ▼
PARAMETERS
     │
     ▼
TEMPLATE
     │
     ▼
APPLICATION
     │
     ▼
RENDER
     │
     ▼
DIFF
     │
     ▼
SYNC
     │
     ▼
HEALTH
```

Ask in this order.

If no Application exists:

```text
don't troubleshoot Pods.
```

If Application exists but rendering fails:

```text
don't troubleshoot Service networking.
```

If rendering succeeds but sync is forbidden:

```text
don't rewrite Generator YAML.
```

Layered troubleshooting is what turns ApplicationSet from "magic" into an understandable control plane.

---

# ✅ Module 14 — Lesson 9 Complete

You now understand:

```text
✓ Application vs ApplicationSet

✓ Generator + Template model

✓ List Generator

✓ Git Directory Generator

✓ Git File Generator

✓ Cluster Generator

✓ cluster metadata and selectors

✓ local-cluster selector nuance

✓ Matrix Generator

✓ Merge Generator

✓ PR Generator

✓ SCM Provider Generator

✓ Cluster Decision Resource Generator

✓ Plugin Generator

✓ post selectors

✓ Go Templates

✓ missingkey=error

✓ normalize / slugify

✓ Go template limitations

✓ generated Application ownership

✓ manual child drift

✓ ignoreApplicationDifferences

✓ ApplicationSet sync policy

✓ generated Application sync policy

✓ applicationsSync modes

✓ create-update safety

✓ owner references

✓ deletion finalizers

✓ preserveResourcesOnDeletion

✓ cascading deletion

✓ dry-run generation

✓ fleet blast radius

✓ Progressive Syncs

✓ current Beta status

✓ RollingSync

✓ maxUpdate

✓ health-gated rollout

✓ reverse deletion ordering

✓ ApplicationSet security

✓ multi-environment generation

✓ multi-cluster generation

✓ Todo ApplicationSet architecture
```

# Next — Module 14, Lesson 10

## App-of-Apps, Cluster Bootstrapping & GitOps Control-Plane Architecture

Next we'll answer a subtle question:

> **If ApplicationSet creates our Applications, who creates the ApplicationSets, AppProjects, platform Applications, and initial cluster configuration?**

We'll build the bootstrap hierarchy:

```text
                    Argo CD installed
                          │
                          ▼
                    ROOT / BOOTSTRAP
                       Application
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼

        AppProjects   ApplicationSets   Platform Apps
            │             │             │
            ▼             ▼             ▼

        Workloads     Dev/Stage/Prod   Cluster Add-ons
```

Then we'll compare **App-of-Apps vs ApplicationSet**, explain when each is appropriate, build a **root GitOps bootstrap repository**, discuss the current Argo recommendation toward ApplicationSet for many cluster-bootstrap scenarios, and cover the dangerous recursive questions around **who manages Argo CD itself, CRDs, AppProjects, ApplicationSets, repositories, cluster add-ons, and disaster recovery of the GitOps control plane**. ([Argo CD][19])

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/?utm_source=chatgpt.com "Generators - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-List/ "List Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/GoTemplate/ "Go Template - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/?utm_source=chatgpt.com "Controlling Resource Modification - Argo CD - Read the Docs"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Application-Deletion/?utm_source=chatgpt.com "Application Pruning & Resource Deletion - Argo CD"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/?utm_source=chatgpt.com "Git Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/ "Cluster Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Matrix/?utm_source=chatgpt.com "Matrix Generator - Declarative GitOps CD for Kubernetes"
[9]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Merge/?utm_source=chatgpt.com "Merge Generator - Declarative GitOps CD for Kubernetes"
[10]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request/ "Pull Request Generator - Argo CD - Declarative GitOps CD for Kubernetes"
[11]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-SCM-Provider/?utm_source=chatgpt.com "SCM Provider Generator - Declarative GitOps CD for Kubernetes"
[12]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Plugin/?utm_source=chatgpt.com "Plugin Generator - Declarative GitOps CD for Kubernetes"
[13]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Post-Selector/?utm_source=chatgpt.com "Post Selector all generators - Argo CD - Read the Docs"
[14]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/ "Controlling Resource Modification - Argo CD - Declarative GitOps CD for Kubernetes"
[15]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/ "Progressive Syncs - Argo CD - Declarative GitOps CD for Kubernetes"
[16]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/?utm_source=chatgpt.com "Progressive Syncs - Declarative GitOps CD for Kubernetes"
[17]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Appset-Any-Namespace/?utm_source=chatgpt.com "ApplicationSet in any namespace - Argo CD - Read the Docs"
[18]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/?utm_source=chatgpt.com "Introduction to ApplicationSet controller - Argo CD"
[19]: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/?utm_source=chatgpt.com "Cluster Bootstrapping - Declarative GitOps CD for Kubernetes"
