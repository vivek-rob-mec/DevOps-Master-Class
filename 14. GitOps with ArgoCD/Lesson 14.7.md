# Module 14 — GitOps with Argo CD

## Lesson 7: Kustomize + Argo CD — Base, Overlays & Production Environment Design

In Lesson 6 our reuse mechanism was:

```text
HELM

Template
   +
Values
   ↓
Rendered Kubernetes YAML
```

Now we solve the same problem differently:

```text
KUSTOMIZE

Valid Kubernetes YAML
        +
Patches / transformations
        ↓
Customized Kubernetes YAML
```

Kustomize is a Kubernetes configuration-customization tool built into `kubectl`; `kubectl kustomize <dir>` renders a directory containing a `kustomization.yaml`, and `kubectl apply -k <dir>` can apply that rendered configuration. ([Kubernetes][1])

The most important difference from Helm is:

```text
HELM
=
generate YAML from templates


KUSTOMIZE
=
transform existing Kubernetes YAML
```

---

# 14.796 The Kustomize mental model

Suppose our reusable Deployment says:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-backend
spec:
  replicas: 1
```

This is already:

# valid Kubernetes YAML.

Kustomize does not require:

```yaml
replicas: {{ .Values.replicaCount }}
```

Instead Production says:

```text
Start with the base Deployment.

Then modify:

replicas 1 → 5
image → production image
resources → production sizing
namespace → todo-prod
```

Result:

```text
BASE
 │
 ├── Deployment
 ├── Service
 └── ConfigMap
       │
       ▼
   PROD OVERLAY
       │
       ├── patch replicas
       ├── change image
       ├── set namespace
       └── add labels
       │
       ▼
   FINAL YAML
```

Kubernetes describes this model as **bases and overlays**: the base contains reusable resources, while overlays refer to the base and apply environment-specific customizations. ([Kubernetes][1])

---

# 14.797 Helm vs Kustomize in one picture

```text
HELM
                     values-prod.yaml
                           │
                           ▼
template.yaml ──────► Helm Render
                           │
                           ▼
                  Kubernetes YAML
```

versus:

```text
KUSTOMIZE

base/deployment.yaml
base/service.yaml
        │
        ▼
prod overlay
        │
        ├── patch
        ├── image
        ├── labels
        └── namespace
        │
        ▼
Kustomize Build
        │
        ▼
Kubernetes YAML
```

Permanent shortcut:

```text
Helm
=
Template + Values


Kustomize
=
Base + Overlay
```

---

# 14.798 Why Kustomize feels very Kubernetes-native

The base files remain completely normal Kubernetes manifests.

You can open:

```text
base/deployment.yaml
```

and see:

```yaml
apiVersion: apps/v1
kind: Deployment
...
```

instead of:

```yaml
{{ if .Values.something }}
...
{{ end }}
```

That makes Kustomize attractive when:

```text
the Kubernetes objects themselves
are already understandable

and

environments differ only
in a controlled number of fields.
```

---

# 14.799 Our production repository structure

Let's redesign our Todo backend using Kustomize:

```text
todo-gitops/
│
└── apps/
    └── todo-backend/
        │
        ├── base/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── kustomization.yaml
        │
        └── overlays/
            ├── dev/
            │   ├── kustomization.yaml
            │   └── patch-deployment.yaml
            │
            ├── staging/
            │   ├── kustomization.yaml
            │   └── patch-deployment.yaml
            │
            └── prod/
                ├── kustomization.yaml
                └── patch-deployment.yaml
```

Think:

```text
base/
=
what is common?


overlays/
=
what differs?
```

---

# 14.800 Create the lab directories

```bash
mkdir -p ~/argocd-labs/kustomize/todo-backend/base

mkdir -p \
  ~/argocd-labs/kustomize/todo-backend/overlays/dev \
  ~/argocd-labs/kustomize/todo-backend/overlays/staging \
  ~/argocd-labs/kustomize/todo-backend/overlays/prod
```

Then:

```bash
cd ~/argocd-labs/kustomize/todo-backend
```

---

# 14.801 Base Deployment

Create:

```bash
nano base/deployment.yaml
```

Use:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: todo-backend

spec:
  replicas: 1

  selector:
    matchLabels:
      app: todo-backend

  template:
    metadata:
      labels:
        app: todo-backend

    spec:
      containers:

        - name: todo-backend

          image: todo-backend:PLACEHOLDER

          ports:
            - name: http
              containerPort: 3002

          env:
            - name: NODE_ENV
              value: production

          resources:
            requests:
              cpu: 100m
              memory: 128Mi

            limits:
              cpu: 500m
              memory: 512Mi
```

Notice:

```text
No templating syntax.
```

This file is valid Kubernetes configuration.

---

# 14.802 Base Service

Create:

```bash
nano base/service.yaml
```

```yaml
apiVersion: v1
kind: Service

metadata:
  name: todo-backend

spec:
  type: ClusterIP

  selector:
    app: todo-backend

  ports:

    - name: http
      port: 80
      targetPort: 3002
```

Again:

```text
100% valid Kubernetes YAML.
```

---

# 14.803 Base `kustomization.yaml`

Create:

```bash
nano base/kustomization.yaml
```

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

The `resources` list tells Kustomize which resource files—or other Kustomization directories—to compose into the output. ([Kubernetes][1])

---

# 14.804 Render the base

Run:

```bash
kubectl kustomize base/
```

Kubernetes' built-in Kustomize integration renders the resources referenced by that directory's `kustomization.yaml`. ([Kubernetes][1])

You should see approximately:

```yaml
apiVersion: v1
kind: Service
...
---
apiVersion: apps/v1
kind: Deployment
...
```

Nothing was deployed.

We only performed:

```text
BUILD / RENDER.
```

---

# 14.805 Kustomize build vs apply

Very important:

```bash
kubectl kustomize overlays/prod
```

means:

```text
Render only.
```

While:

```bash
kubectl apply -k overlays/prod
```

means:

```text
Render
+
apply to Kubernetes.
```

Both behaviors are part of `kubectl`'s Kustomize integration. ([Kubernetes][1])

In GitOps:

```text
we normally use rendering
for validation,

while Argo CD
owns deployment.
```

So don't routinely run:

```bash
kubectl apply -k prod/
```

against an Argo-managed production application.

---

# 14.806 Now create the Dev overlay

Create:

```bash
nano overlays/dev/kustomization.yaml
```

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: todo-dev

labels:
  - pairs:
      environment: dev
      app.kubernetes.io/part-of: todo
    includeSelectors: false

images:
  - name: todo-backend
    newName: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend
    newTag: dev-f73ca19

patches:
  - path: patch-deployment.yaml
```

This overlay:

```text
imports base
+
sets Dev namespace
+
adds environment labels
+
changes image
+
patches Deployment.
```

Kustomize supports cross-cutting transformations such as namespaces, labels, name prefixes/suffixes, and annotations, in addition to patches and image transformations. ([Kubernetes][1])

---

# 14.807 Dev patch

Create:

```bash
nano overlays/dev/patch-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: todo-backend

spec:
  replicas: 1

  template:
    spec:
      containers:

        - name: todo-backend

          env:
            - name: NODE_ENV
              value: development

          resources:
            requests:
              cpu: 100m
              memory: 128Mi

            limits:
              cpu: 250m
              memory: 256Mi
```

Meaning:

```text
Start with base.

Only replace/merge
these particular fields.
```

---

# 14.808 Render Dev

Run:

```bash
kubectl kustomize overlays/dev
```

Now inspect:

```text
namespace

image

replicas

resource limits

NODE_ENV
```

The base files themselves remain unchanged.

That's the core beauty of Kustomize.

---

# 14.809 Production overlay

Create:

```bash
nano overlays/prod/kustomization.yaml
```

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namespace: todo-prod

labels:
  - pairs:
      environment: prod
      app.kubernetes.io/part-of: todo
    includeSelectors: false

images:
  - name: todo-backend
    newName: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend
    newTag: 52ac814

patches:
  - path: patch-deployment.yaml
```

Then:

```bash
nano overlays/prod/patch-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: todo-backend

spec:
  replicas: 4

  template:
    spec:
      containers:

        - name: todo-backend

          resources:
            requests:
              cpu: 500m
              memory: 512Mi

            limits:
              cpu: "1"
              memory: 1Gi
```

---

# 14.810 Same base — radically less duplication

Base:

```text
containerPort = 3002
Service target = 3002
labels
container structure
Deployment structure
```

Dev differences:

```text
replicas = 1
small resources
development environment
dev image
```

Prod differences:

```text
replicas = 4
large resources
prod image
prod namespace
```

Exactly what we wanted.

---

# 14.811 Render and compare

```bash
kubectl kustomize overlays/dev > /tmp/todo-dev.yaml
```

```bash
kubectl kustomize overlays/prod > /tmp/todo-prod.yaml
```

Then:

```bash
diff -u /tmp/todo-dev.yaml /tmp/todo-prod.yaml
```

This is an excellent review technique.

You can answer:

> What does Prod actually differ from Dev on?

without manually comparing dozens of duplicated manifests.

---

# 14.812 Base rule

The base should represent:

```text
common application architecture.
```

It should **not** be:

```text
production
with 25 patches undoing Prod assumptions
for Dev.
```

Better:

```text
base = neutral/common

overlay = environment intent
```

---

# 14.813 Base knows nothing about overlays

A healthy architecture looks like:

```text
                 BASE
                  │
         ┌────────┼────────┐
         ▼        ▼        ▼
        DEV     STAGE     PROD
```

Not:

```text
Base:
"If Dev do X,
if Prod do Y,
if Singapore do Z..."
```

That would recreate Helm-like conditional templating badly.

The Kubernetes Kustomize documentation describes bases specifically as reusable configurations that do not need knowledge of the overlays consuming them. ([Kubernetes][1])

---

# 14.814 `resources`

The most fundamental Kustomize field:

```yaml
resources:
  - deployment.yaml
  - service.yaml
```

or:

```yaml
resources:
  - ../../base
```

Think:

```text
resources
=
what configuration
should participate
in this build?
```

Kustomize supports composing both resource files and reusable Kustomization directories. ([Kubernetes][1])

---

# 14.815 `patches`

Think:

```text
PATCH
=
change selected parts
of an existing resource.
```

For example:

```yaml
patches:
  - path: patch-deployment.yaml
```

The modern Kustomize `patches` field can use file or inline patches and can target resources by attributes including kind, name, namespace, labels, and annotations. Patches are applied in listed order. ([Kubernetes][1])

---

# 14.816 Patch mental model

Base:

```yaml
spec:
  replicas: 1
```

Production patch:

```yaml
spec:
  replicas: 4
```

Output:

```yaml
spec:
  replicas: 4
```

The base remains:

```yaml
replicas: 1
```

unchanged.

---

# 14.817 Strategic-style patch

Our file:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: todo-backend

spec:
  replicas: 4
```

matches:

```text
kind:
Deployment

name:
todo-backend
```

and merges selected fields.

This works particularly naturally with Kubernetes-native object structures.

---

# 14.818 JSON 6902 patches

Sometimes you want very precise operations:

```yaml
- op: replace
  path: /spec/replicas
  value: 4
```

Then:

```yaml
patches:

  - target:
      group: apps
      version: v1
      kind: Deployment
      name: todo-backend

    path: patch-replicas.yaml
```

Kustomize supports JSON Patch through the `patches` field; JSON patches can target arbitrary fields precisely. ([Kubernetes][1])

---

# 14.819 Strategic patch vs JSON Patch

Think:

```text
STRUCTURED MERGE-STYLE PATCH
=
"Make Deployment look like this
for these fields."


JSON PATCH
=
"Perform exact operations
on exact field paths."
```

Example JSON:

```text
replace /spec/replicas
```

is extremely explicit.

---

# 14.820 When JSON patches are useful

Examples:

```text
replace one nested field

remove a field

add an array element

precisely target an object path
```

But beware:

```text
/spec/template/spec/containers/0/...
```

can become brittle if list ordering changes.

Use the simplest mechanism that accurately expresses your intent.

---

# 14.821 Targeted patching

You can make targeting explicit:

```yaml
patches:

  - target:
      kind: Deployment
      name: todo-backend

    patch: |-
      - op: replace
        path: /spec/replicas
        value: 5
```

Argo CD itself also supports Kustomize patches directly within the Application source configuration, using the same Kustomize patch logic. ([Argo CD][2])

We'll discuss when that is appropriate later.

---

# 14.822 Image transformation

For artifact promotion, this is one of the best Kustomize features:

```yaml
images:

  - name: todo-backend
    newName: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend
    newTag: f73ca19
```

Kustomize's `images` transformation can replace the image repository/name and tag without writing an ordinary patch. ([Kubernetes][1])

This fits our Lesson 5 promotion model beautifully.

---

# 14.823 Image promotion becomes tiny

Production currently:

```yaml
images:

  - name: todo-backend
    newName: ...
    newTag: 52ac814
```

Promotion PR:

```diff
 images:
   - name: todo-backend
     newName: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend
-    newTag: 52ac814
+    newTag: f73ca19
```

That's all.

---

# 14.824 CI can update image safely

Argo CD's official CI automation guide explicitly demonstrates:

```bash
kustomize edit set image ...
```

as a GitOps promotion mechanism: CI updates the local Kustomize configuration, commits it, and pushes the change to Git; if auto-sync is enabled, no direct `argocd app sync` call is required. ([Argo CD][3])

Example future command:

```bash
cd apps/todo-backend/overlays/dev

kustomize edit set image \
  todo-backend=123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend:f73ca19
```

Then:

```bash
git diff
```

---

# 14.825 Why this is better than `sed`

Compare:

```bash
sed -i 's/old/new/' kustomization.yaml
```

with:

```bash
kustomize edit set image ...
```

The second operation understands Kustomize's image configuration rather than blindly replacing arbitrary text.

Production promotion tooling should prefer configuration-aware changes.

---

# 14.826 Tags vs digests

You can use:

```text
newTag:
f73ca19
```

for commit-based tagging.

For stronger immutability, Kustomize image configuration also supports digest-oriented image references in modern Kustomize implementations; conceptually we want:

```text
todo-backend@sha256:...
```

for exact artifact identity.

The same Lesson 5 rule remains:

```text
BUILD ONCE

PROMOTE SAME ARTIFACT.
```

---

# 14.827 Namespace transformation

Overlay:

```yaml
namespace: todo-prod
```

lets Kustomize apply the namespace transformation to appropriate namespaced resources and recognized namespace references. Kubernetes documents namespace as a cross-cutting Kustomize transformation. ([Kubernetes][1])

This is often cleaner than repeating:

```yaml
metadata:
  namespace: todo-prod
```

in every manifest.

---

# 14.828 Important Argo namespace nuance

Suppose Application says:

```yaml
destination:
  namespace: todo-prod
```

Argo can add the destination namespace when generated manifests omit one.

However, current Argo documentation warns that this post-render namespace assignment can miss namespace fields embedded in some custom resources. Setting:

```yaml
source:
  kustomize:
    namespace: todo-prod
```

lets **Kustomize itself** perform namespace transformation, and when both are set the Kustomize namespace takes precedence. ([Argo CD][2])

This is a subtle production troubleshooting point.

---

# 14.829 Destination namespace vs Kustomize namespace

Mental model:

```text
destination.namespace
=
Argo deployment destination/default


kustomize.namespace
=
namespace transformation
during Kustomize rendering
```

For normal simple manifests:

```text
destination.namespace
```

may be sufficient.

For complex/custom resources containing namespace references:

```text
Kustomize namespace transformation
```

may be more correct.

---

# 14.830 Name prefixes

Kustomize supports:

```yaml
namePrefix: dev-
```

Then:

```text
Deployment:
todo-backend
```

becomes:

```text
dev-todo-backend
```

and recognized references are updated appropriately. Name prefixes and suffixes are standard Kustomize cross-cutting transformations. ([Kubernetes][1])

---

# 14.831 Should environments use name prefixes?

You could do:

```text
dev-todo-backend
stage-todo-backend
prod-todo-backend
```

But if each environment already has separate namespaces:

```text
todo-dev
todo-stage
todo-prod
```

you may not need prefixes.

Avoid redundant naming such as:

```text
prod-todo-backend-prod
```

unless there's a real operational reason.

---

# 14.832 Namespace is often the cleaner environment boundary

Example:

```text
namespace:
todo-dev

resource:
todo-backend
```

and:

```text
namespace:
todo-prod

resource:
todo-backend
```

This keeps application names stable while namespaces carry environment identity.

Later, separate clusters may make even the namespace environment suffix unnecessary depending on your model.

---

# 14.833 Labels

Modern upstream Kustomize configuration supports the `labels` transformer model, including whether labels should be injected into selectors. ([Kubernetes][1])

Example:

```yaml
labels:

  - pairs:
      app.kubernetes.io/part-of: todo
      environment: prod

    includeSelectors: false
```

Output resources gain metadata like:

```yaml
labels:
  app.kubernetes.io/part-of: todo
  environment: prod
```

---

# 14.834 Why be careful with selectors?

If you inject labels into:

```text
Service selectors

Deployment selectors
```

you are changing the identity relationship between resources.

Example:

```text
Service selector:
app=todo
environment=prod
```

is fine if Pod labels also consistently contain those labels.

But careless selector transformations can break:

```text
Service → Pod selection
```

or trigger immutable Deployment-selector changes.

Be deliberate about whether labels belong only on metadata or also selectors.

---

# 14.835 Annotations

Cross-cutting annotations can be added using Kustomize too.

Examples:

```text
owner=platform

compliance=pci

documentation URL

cost-center

on-call metadata
```

Kustomize supports common annotations as a cross-cutting transformation. ([Kubernetes][1])

---

# 14.836 Argo-specific Kustomize transformations

Argo Application sources also expose Kustomize options such as:

```text
namePrefix

nameSuffix

images

replicas

commonLabels

commonAnnotations

namespace

patches

components
```

in the Application spec. ([Argo CD][2])

For example:

```yaml
source:

  repoURL: ...

  path: apps/todo-backend/overlays/prod

  kustomize:

    images:
      - todo-backend=f73ca19
```

is possible.

---

# 14.837 But remember our GitOps preference

For persistent Production configuration, prefer:

```text
Git overlay contains
production desired state
```

rather than:

```text
Application parameter override
contains hidden production difference.
```

Same principle we learned with Helm.

We want someone opening:

```text
overlays/prod/kustomization.yaml
```

to understand Production.

---

# 14.838 `replicas` transformation

Argo's Application-level Kustomize configuration can also override replica counts. ([Argo CD][2])

Kustomize itself also has replica transformers.

But remember:

```text
if HPA owns replica count

do NOT make GitOps
fight HPA.
```

One field → one authoritative controller.

---

# 14.839 ConfigMap generator

Kustomize can generate ConfigMaps from:

```text
files

environment files

literal values
```

using:

```yaml
configMapGenerator:
```

Kubernetes documents this capability as part of standard Kustomize. ([Kubernetes][1])

Example:

```yaml
configMapGenerator:

  - name: todo-backend-config

    literals:
      - LOG_LEVEL=info
      - API_TIMEOUT=5
```

---

# 14.840 Generated ConfigMap names

By default, Kustomize adds a content-derived suffix.

You may see:

```text
todo-backend-config-7b4h29gk4m
```

rather than:

```text
todo-backend-config
```

When the content changes, the generated name changes. Kustomize also automatically updates references from consuming resources to the generated name. ([Kubernetes][1])

This is extremely useful.

---

# 14.841 Why the hash is useful

Imagine:

```text
ConfigMap v1
LOG_LEVEL=info
```

generates:

```text
todo-config-abc
```

Then Git changes:

```text
LOG_LEVEL=debug
```

Kustomize generates:

```text
todo-config-xyz
```

Deployment reference changes:

```text
todo-config-abc
       ↓
todo-config-xyz
```

That Deployment template change can trigger a rollout.

Very useful for declarative config changes.

---

# 14.842 `disableNameSuffixHash`

Kustomize can disable generated hash suffixes through:

```yaml
generatorOptions:
  disableNameSuffixHash: true
```

Kubernetes documents this option explicitly. ([Kubernetes][1])

But don't turn it off automatically.

The hash gives:

```text
config immutability-like identity

+
automatic rollout-friendly reference changes.
```

---

# 14.843 ConfigMap example for our Todo backend

Base:

```yaml
configMapGenerator:

  - name: todo-backend-config

    literals:
      - APP_NAME=todo-backend
```

Dev overlay could merge/replace environment config to produce:

```text
LOG_LEVEL=debug
```

while Prod:

```text
LOG_LEVEL=info
```

Then the Deployment consumes:

```yaml
envFrom:

  - configMapRef:
      name: todo-backend-config
```

Kustomize updates that reference to the generated hashed name. ([Kubernetes][1])

---

# 14.844 Secret generator exists too

Kustomize supports:

```yaml
secretGenerator:
```

for creating Kubernetes Secrets from files or literals. ([Kubernetes][1])

Example technically:

```yaml
secretGenerator:

  - name: todo-secret

    literals:
      - PASSWORD=example
```

But now recall our production rule:

# Do not put production plaintext secrets in Git.

---

# 14.845 SecretGenerator does NOT solve Git secret security

If Git contains:

```yaml
secretGenerator:

  - name: db-secret

    literals:
      - PASSWORD=MyProdPassword
```

then the password is:

```text
still in Git.
```

The generated Kubernetes Secret may be base64-encoded, but the source secret is still exposed to repository readers.

We'll use:

```text
External Secrets Operator

AWS Secrets Manager

Vault

Sealed Secrets
```

later.

---

# 14.846 Correct distinction

```text
secretGenerator
=
Kubernetes Secret generation mechanism


External secret manager
=
secure secret-value storage strategy
```

They solve different problems.

---

# 14.847 Replacements

Kustomize supports:

```yaml
replacements:
```

to copy a value from one resource field into another resource field.

Kubernetes specifically documents this for cases where transformed names—such as prefixed Service names—need to be injected into dependent resources without hardcoding them. ([Kubernetes][1])

---

# 14.848 Replacement mental model

Suppose:

```text
Service metadata.name
=
prod-todo-api
```

Deployment environment variable should receive:

```text
prod-todo-api
```

Instead of writing it twice:

```yaml
replacements:

  - source:
      kind: Service
      name: todo-api
      fieldPath: metadata.name

    targets:

      - select:
          kind: Deployment
          name: todo-api

        fieldPaths:
          - spec.template.spec.containers.0.env.0.value
```

Concept:

```text
Source field
    │
    ▼
Kustomize
    │
    ▼
Target field
```

---

# 14.849 Why replacements matter

Hardcoded resource references are fragile when transformations change:

```text
names

prefixes

suffixes
```

Kustomize understands Kubernetes resource relationships better than generic:

```bash
sed
```

and replacements can make those relationships explicit. ([Kubernetes][1])

---

# 14.850 Components

A component is useful when you want optional reusable configuration that is not necessarily a full base.

Concept:

```text
BASE
todo-backend
```

Optional:

```text
COMPONENT A
monitoring

COMPONENT B
debug tooling

COMPONENT C
extra NetworkPolicy
```

Then overlay:

```text
Prod
=
base
+
monitoring
+
strict-network
```

while Dev:

```text
Dev
=
base
+
debug
```

Current Argo CD supports Kustomize `components` directly in an Application source and has done so since Argo CD 2.10. ([Argo CD][2])

---

# 14.851 Component structure

Concept:

```text
todo-backend/
│
├── base/
│
├── components/
│   ├── monitoring/
│   └── strict-network/
│
└── overlays/
    ├── dev/
    └── prod/
```

Prod:

```yaml
components:
  - ../../components/monitoring
  - ../../components/strict-network
```

This is useful for orthogonal optional features.

---

# 14.852 `ignoreMissingComponents`

Argo's Application-level Kustomize integration currently supports:

```yaml
ignoreMissingComponents: true
```

which prevents missing configured components from being appended to the Kustomization/build and thereby avoids failing solely for that absence. ([Argo CD][2])

As always:

```text
optional component
=
good use


typo hidden by ignoreMissing
=
bad use
```

---

# 14.853 Remote bases

A Kustomize base can come from another Git repository or remote Git URL.

Kubernetes' `kubectl kustomize` supports Kustomization targets from remote Git URLs, including explicit refs. ([Kubernetes][4])

Example concept:

```yaml
resources:

  - https://github.com/company/platform-base.git/apps/node-service?ref=v2.4.1
```

This enables central reusable configuration.

---

# 14.854 Remote base architecture

Platform team:

```text
company-k8s-base
        │
        └── Node service baseline
```

Applications:

```text
Payments overlay
Orders overlay
Todo overlay
```

all reuse:

```text
platform-approved base.
```

That's potentially powerful platform engineering.

---

# 14.855 But pin remote bases

Bad:

```text
?ref=main
```

because tomorrow:

```text
main changes
```

and your application can render differently even if its own repository commit did not change.

Better:

```text
tag
or
immutable commit
```

for production reuse.

Our same immutable-dependency principle from Helm applies here.

---

# 14.856 Argo private remote-base limitation

Current Argo behavior has an important credential restriction:

A private remote base can inherit the credentials of the Application's main repository **if the remote base can use the same credentials**. It cannot simply access another private repository with unrelated credentials merely because Argo CD happens to know credentials for that other repository. ([Argo CD][2])

This matters in enterprise repo design.

---

# 14.857 Why that security restriction exists

Suppose:

```text
Team A Application
```

could automatically access:

```text
Team B private repository
```

just because Argo globally knows both credentials.

That could violate repository boundaries.

Argo intentionally limits the credential context available to the Kustomize build. ([Argo CD][2])

---

# 14.858 Remote-base troubleshooting

If local rendering works but Argo fails:

```text
Could local Git credentials
access the remote base?

Can Argo repo-server
use the same credentials?

Is the ref valid?

Is the remote path correct?

Is network/DNS available?
```

Do not assume:

```text
Argo knows repo B
=
Kustomize app A may automatically read repo B.
```

Current private-remote-base behavior is stricter than that. ([Argo CD][2])

---

# 14.859 Argo automatically detects Kustomize

An Argo Application can simply point to:

```yaml
source:

  repoURL: https://git.example.com/company/todo-gitops.git

  targetRevision: main

  path: apps/todo-backend/overlays/prod
```

If that path contains:

```text
kustomization.yaml
```

Argo renders it with Kustomize. ([Argo CD][2])

No need to specify:

```yaml
tool: kustomize
```

manually.

---

# 14.860 Production Argo Application

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: todo-backend-prod
  namespace: argocd

spec:

  project: todo-prod

  source:

    repoURL: https://git.example.com/company/todo-gitops.git

    targetRevision: main

    path: apps/todo-backend/overlays/prod

  destination:

    server: https://kubernetes.default.svc
    namespace: todo-prod

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

The critical Kustomize-specific part is simply:

```text
path
→ overlay directory.
```

Argo explicitly recommends pointing `source.path` to the overlay you want rendered. ([Argo CD][2])

---

# 14.861 Repo-server processing

Internally:

```text
Git
 │
 ▼
apps/todo-backend/overlays/prod
 │
 ▼
kustomization.yaml
 │
 ▼
repo-server
 │
 ▼
kustomize build
 │
 ▼
rendered manifests
 │
 ▼
Application Controller
 │
 ▼
diff
 │
 ▼
sync
```

Same Argo architecture as Helm.

Different renderer.

---

# 14.862 Helm and Kustomize converge at the same point

Helm:

```text
Chart + Values
     │
     ▼
Rendered YAML
```

Kustomize:

```text
Base + Overlay
     │
     ▼
Rendered YAML
```

After that:

```text
                 Rendered YAML
                       │
                       ▼
             Application Controller
                       │
                       ▼
                    Diff
                       │
                       ▼
                     Sync
```

Argo doesn't care whether the desired objects originated from:

```text
Helm

Kustomize

plain YAML
```

once it has the final manifests.

---

# 14.863 Argo can override Kustomize image

Current Application source supports:

```yaml
kustomize:

  images:
    - todo-backend=f73ca19
```

Argo documents Application-level Kustomize image overrides. ([Argo CD][2])

Technically useful.

But again:

```text
Production desired state
should preferably be visible
in the Git overlay.
```

---

# 14.864 Why Application overrides can become confusing

Overlay Git:

```yaml
newTag: 52ac814
```

Application spec:

```yaml
kustomize:
  images:
    - todo-backend=f73ca19
```

Actual render:

```text
f73ca19.
```

Engineer reads overlay:

```text
Why does cluster not run 52ac814?
```

Same problem as Helm parameter precedence.

Avoid unnecessary layers of override.

---

# 14.865 Kustomize version differences

Argo CD can be configured with multiple Kustomize binary versions and an Application can explicitly request one of the configured versions. ([Argo CD][2])

Why does this matter?

Your laptop:

```text
Kustomize X
```

Argo:

```text
Kustomize Y
```

could potentially produce different behavior for version-sensitive features.

---

# 14.866 Always check renderer versions during weird failures

Local:

```bash
kustomize version
```

or inspect the Kustomize version embedded in your `kubectl`.

Then compare with the version available/configured in Argo when behavior differs.

Production debugging question:

```text
Are local and Argo builds
using equivalent Kustomize behavior?
```

---

# 14.867 Argo Kustomize build options

Argo administrators can define global/version-specific:

```text
kustomize.buildOptions
```

in `argocd-cm`. Current docs show examples such as changing load restrictions. ([Argo CD][2])

This is a platform-level setting.

Application teams should not assume the repo alone tells the entire renderer configuration.

---

# 14.868 `LoadRestrictionsRootOnly`

Kustomize's command defaults to a load restriction that prevents arbitrary local file access outside the Kustomization root; `LoadRestrictionsNone` relaxes that and can reduce relocatability/security boundaries. ([Kubernetes][4])

If someone tells you:

> "Just disable load restrictions globally."

ask why.

It's a security/design choice, not merely an error fix.

---

# 14.869 Kustomize + Helm

Kustomize itself has support for Helm chart inflation when invoked with:

```text
--enable-helm
```

but current Argo documentation says this flag is **not an Application-level Kustomize option**. To use Helm inflation through Kustomize in Argo, you'd need a config-management plugin or configure the global Kustomize build options accordingly. ([Argo CD][2])

This is a classic interview/troubleshooting nuance.

---

# 14.870 Don't combine tools merely because you can

You could build:

```text
Helm
inside
Kustomize
inside
Argo
```

but ask:

```text
Does this simplify ownership?

Or just create
three rendering layers?
```

Complexity should buy real value.

---

# 14.871 Config generation and Argo diff

Generated ConfigMaps often include hashed names.

Example:

```text
todo-config-abc123
```

changes to:

```text
todo-config-def456
```

Argo sees:

```text
old generated resource
removed

new generated resource
added
```

With pruning enabled, old generated objects can be cleaned up according to Argo's reconciliation policy.

This can be a clean immutable-config rollout model.

---

# 14.872 Generated-resource comparison nuance

Current Argo Kustomize documentation specifically points users generating resources toward Argo's `IgnoreExtraneous` comparison behavior when generated objects need special comparison handling. ([Argo CD][2])

Do not reach for compare-ignore settings automatically; first understand:

```text
which generated resources
are actually owned

and

why Argo considers them extra.
```

---

# 14.873 Kustomize patches should be small

Bad:

```text
patch-deployment.yaml
=
entire 200-line Deployment copy.
```

Then you're almost back to duplication.

Better:

```yaml
spec:
  replicas: 4
```

plus only the environment-specific pieces.

Rule:

> **Overlay contains differences, not another full application definition.**

---

# 14.874 If overlay becomes huge...

Suppose base has:

```text
150 lines.
```

Prod patch has:

```text
145 lines.
```

Ask:

```text
Is Prod actually the same application shape?
```

Maybe your base abstraction is wrong.

Or perhaps:

```text
Prod needs a different base.
```

Do not force one base to represent systems that have diverged substantially.

---

# 14.875 Base versioning

If 30 apps use one remote base:

```text
platform/node-service
```

and you change that base:

```text
securityContext

probes

NetworkPolicy
```

you may affect many applications.

Therefore shared bases need:

```text
versioning

testing

controlled rollout

clear ownership.
```

This resembles library/module versioning.

---

# 14.876 Don't track shared base `main` blindly

Production app:

```text
remote base ref=main
```

means:

```text
Platform team merges base change
        │
        ▼
your application desired state changes
```

without your app repo changing.

That's a dangerous hidden dependency.

Prefer version pins for high-confidence production configuration.

---

# 14.877 Environment overlays vs application overlays

You can layer structure conceptually:

```text
BASE

      ↓

REGION

      ↓

ENVIRONMENT
```

For example:

```text
base/
regions/
  mumbai/
  singapore/
overlays/
  prod-mumbai/
  prod-singapore/
```

But don't create a seven-level inheritance maze.

---

# 14.878 DR example

Mumbai Production:

```text
replicas = 6
region label = ap-south-1
```

Singapore warm standby:

```text
replicas = 2
region label = ap-southeast-1
```

Both may reuse the same:

```text
Todo backend base.
```

This connects our AWS DR module with GitOps desired-state design.

---

# 14.879 Configuring image by environment

Example:

```text
Dev:
f73ca19


Stage:
f73ca19


Prod:
52ac814
```

Same base.

Only:

```yaml
images:
```

differs.

Promotion becomes extremely understandable.

---

# 14.880 GitOps CI flow with Kustomize

Argo's own CI guide gives the canonical shape:

```text
build new image
      │
      ▼
update Kustomize image
      │
      ▼
commit configuration
      │
      ▼
push Git
      │
      ▼
Argo detects
      │
      ▼
auto-sync
```

and explicitly shows `kustomize edit set image` for this workflow. ([Argo CD][3])

---

# 14.881 Production Jenkins pseudo-flow

Conceptually:

```groovy
stage('Build') {
    // test + image build
}

stage('Push ECR') {
    // push f73ca19
}

stage('Promote Dev') {
    // clone GitOps repo
    // kustomize edit set image ...
    // commit
    // push
}
```

Notice:

```text
NO kubectl production deploy.
```

Argo owns that.

---

# 14.882 Dev promotion command

Conceptually:

```bash
cd apps/todo-backend/overlays/dev

kustomize edit set image \
  todo-backend=123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend:f73ca19

git diff

git add kustomization.yaml

git commit -m \
  "Deploy todo-backend f73ca19 to dev"

git push
```

Then:

```text
Argo Dev
→ detects
→ renders
→ syncs
```

if automatic synchronization is enabled. ([Argo CD][3])

---

# 14.883 Stage promotion

Same artifact:

```bash
cd overlays/staging
```

Update:

```text
f73ca19
```

Commit:

```text
Promote todo-backend f73ca19 to staging
```

Do **not** rebuild.

---

# 14.884 Prod promotion

PR modifies:

```text
overlays/prod/kustomization.yaml
```

only:

```diff
- newTag: 52ac814
+ newTag: f73ca19
```

CODEOWNERS approves.

Merge.

Argo production reconciles.

This is exactly the production flow we designed in Lesson 5.

---

# 14.885 Kustomize patch ordering

When multiple entries exist in:

```yaml
patches:
```

Kustomize applies them in listed order. ([Kubernetes][1])

Example:

```yaml
patches:

  - path: common-prod.yaml
  - path: emergency-capacity.yaml
```

The second patch can affect output produced after the first.

Ordering is therefore part of desired-state semantics.

---

# 14.886 Avoid patch layering chaos

Bad:

```text
base
 ↓
patch 1
 ↓
patch 2
 ↓
patch 3
 ↓
patch 4
 ↓
patch 5
 ↓
patch 6
 ↓
"Why is replicas 17?"
```

Use layering only when it expresses real, understandable dimensions.

---

# 14.887 Production patch naming

Prefer:

```text
patch-resources.yaml

patch-replicas.yaml

patch-ingress.yaml
```

over:

```text
fix.yaml

newfix.yaml

fix2-final.yaml
```

Repository clarity matters operationally.

---

# 14.888 Kustomize is not templating—but it's still programming-like

You still have:

```text
composition

transformations

patch precedence

generated resources

dependency references
```

So do not assume:

```text
"No Go templates"
=
"Impossible to make complex."
```

Kustomize configurations can become unmaintainable too.

---

# 14.889 Local validation pipeline

Before merge:

```bash
kubectl kustomize apps/todo-backend/overlays/dev \
  > /tmp/dev.yaml
```

```bash
kubectl kustomize apps/todo-backend/overlays/staging \
  > /tmp/staging.yaml
```

```bash
kubectl kustomize apps/todo-backend/overlays/prod \
  > /tmp/prod.yaml
```

Then validate those rendered outputs with your schema/policy tooling.

Kustomize's output is just Kubernetes YAML, making it easy to feed into further validation. ([Kubernetes][1])

---

# 14.890 `kubectl diff -k`

Kubernetes supports:

```bash
kubectl diff -k <directory>
```

to compare the rendered Kustomization against the target cluster state. ([Kubernetes][1])

For Argo-managed Production, the preferred GitOps diff remains:

```bash
argocd app diff todo-backend-prod
```

because Argo's exact source/rendering configuration is the authoritative deployment path.

But `kubectl diff -k` is useful for local investigation.

---

# 14.891 Don't apply locally to Argo-managed production

Avoid:

```bash
kubectl apply -k overlays/prod
```

as your normal release flow.

Otherwise:

```text
Git
+
Argo
+
human kubectl
```

all become deployment paths.

Better:

```text
edit Git
→ Argo deploys.
```

---

# 14.892 Argo manifests command

After you create the Kustomize Application:

```bash
argocd app manifests todo-backend-prod
```

This answers:

> What did Argo actually render?

Always prefer evidence over assumptions.

---

# 14.893 Kustomize troubleshooting mnemonic

Use:

# **B → O → P → R → D → S → H**

```text
B
BASE


O
OVERLAY


P
PATCH


R
RENDER


D
DIFF


S
SYNC


H
HEALTH
```

This is our Kustomize-specific extension.

---

# 14.894 B — Base

Ask:

```text
Does base contain correct resources?

Valid Kubernetes YAML?

Selectors correct?

Container name correct?

Image placeholder matches
Kustomize image transformation?
```

If base is wrong:

```text
every environment
inherits the bug.
```

---

# 14.895 O — Overlay

Ask:

```text
Correct environment?

Correct base path?

Correct namespace?

Correct image?

Correct labels?

Correct components?
```

Common mistake:

```text
Prod Application
points to Dev overlay.
```

Argo then faithfully deploys Dev configuration to Production.

---

# 14.896 P — Patch

Ask:

```text
Does target resource exist?

Correct kind?

Correct name?

Correct API version?

Does container name match?

Patch order correct?
```

One of the most common Kustomize errors is:

```text
patch target not found
```

because the patch identifies a resource differently from the base.

---

# 14.897 Patch target example

Base:

```yaml
metadata:
  name: todo-backend
```

Patch:

```yaml
metadata:
  name: todo-api
```

Kustomize cannot magically know these are the same Deployment.

The patch must target the actual resource identity.

---

# 14.898 R — Render

Run:

```bash
kubectl kustomize overlays/prod
```

If this fails:

```text
Argo cannot produce
desired manifests either.
```

Fix rendering before investigating Kubernetes runtime.

---

# 14.899 D — Diff

Argo:

```bash
argocd app diff todo-backend-prod
```

Ask:

```text
Does Argo's rendered state
differ from live state?
```

Don't look only at source files.

Look at final rendered objects.

---

# 14.900 S — Sync

If rendering and diff are correct but deployment fails:

```text
Kubernetes authorization?

AppProject?

Admission policy?

Missing CRD?

Immutable field?

Shared resource?

Namespace issue?
```

Now you're beyond Kustomize.

---

# 14.901 H — Health

If:

```text
Synced
```

but:

```text
Degraded
```

check:

```bash
kubectl get pods -n todo-prod

kubectl describe pod ...

kubectl logs ...
```

Kustomize has already successfully generated desired YAML.

Now troubleshoot runtime.

---

# 14.902 Common failure — wrong overlay path

Application:

```yaml
path: apps/todo-backend/overlays/prod
```

but actual:

```text
apps/todo-backend/overlay/prod
```

Argo cannot render.

Check:

```text
repoURL

revision

path

kustomization.yaml
```

first.

---

# 14.903 Common failure — missing `kustomization.yaml`

Argo detects Kustomize when the source path contains a Kustomization file. ([Argo CD][2])

If you point to:

```text
overlays/prod/
```

but forget:

```text
kustomization.yaml
```

Argo won't process it as the Kustomize application you intended.

---

# 14.904 Common failure — wrong image name

Base:

```yaml
image: todo-backend:PLACEHOLDER
```

Overlay:

```yaml
images:

  - name: todo-api
    newTag: f73ca19
```

No match.

Result remains:

```text
todo-backend:PLACEHOLDER.
```

Always inspect:

```bash
kubectl kustomize overlays/prod | grep image:
```

before merge.

---

# 14.905 Common failure — patch changes selector

Imagine Production patch changes:

```yaml
spec:
  selector:
```

of an existing Deployment.

Deployment selectors are generally immutable after creation.

Kustomize may render perfectly.

Argo diff may be perfectly correct.

Kubernetes API can still reject the update.

Therefore:

```text
Render success
≠
Sync success.
```

---

# 14.906 Common failure — namespace confusion

Application:

```yaml
destination:
  namespace: todo-prod
```

but Kustomization:

```yaml
namespace: todo-stage
```

Current Argo behavior gives precedence to the Kustomize-defined namespace transformation when both are configured through the Application's Kustomize source settings. ([Argo CD][2])

Avoid conflicting namespace declarations.

---

# 14.907 Common failure — generated ConfigMap keeps changing

If ConfigMap contents genuinely change:

```text
hash changes
```

by design.

If they change unexpectedly every build:

```text
inspect generated input.
```

GitOps rendering should be deterministic.

Same principle as Helm's random-data warning.

---

# 14.908 Common failure — Secret committed to Git

Kustomize renders perfectly.

Argo syncs perfectly.

Security architecture fails.

Because:

```text
password exists
in Git history.
```

A technically successful GitOps pipeline can still be a security failure.

---

# 14.909 Common failure — remote base changed unexpectedly

Your app repo didn't change.

Argo now shows:

```text
OutOfSync.
```

Why?

Remote base referenced:

```text
main.
```

Upstream changed.

This is why immutable remote dependency references matter.

---

# 14.910 Common failure — local build works, Argo doesn't

Check:

```text
Kustomize version

remote credentials

global Argo build options

load restrictions

source path

environment differences
```

Argo supports custom/multiple Kustomize versions and global build options, so local and repo-server rendering environments may differ. ([Argo CD][2])

---

# 14.911 Common failure — private remote base

Your laptop:

```text
has SSH key A
and SSH key B.
```

So build succeeds.

Argo Application repo credential:

```text
only key A.
```

Remote base requires:

```text
key B.
```

Argo fails.

Current Argo private remote-base behavior does not automatically expose unrelated repository credentials to the Application build. ([Argo CD][2])

---

# 14.912 Helm vs Kustomize — practical comparison

| Question                   | Helm                            | Kustomize                         |
| -------------------------- | ------------------------------- | --------------------------------- |
| Core model                 | Template + values               | Base + overlays                   |
| Base files valid K8s YAML? | Usually templates, not directly | Yes                               |
| Conditional logic          | Strong                          | Limited/structural                |
| Packaging/distribution     | Excellent                       | Less package-oriented             |
| Dependency management      | Built-in charts                 | Resource composition/remote bases |
| Third-party software       | Extremely common                | Possible, less conventional       |
| Environment patches        | Via values/templates            | Native strength                   |
| Learning complexity        | Template language               | Patch/transformer model           |
| Risk                       | template complexity             | overlay/patch complexity          |

Both are first-class Argo rendering approaches; Argo's repo server ultimately turns either into manifests for reconciliation. ([Argo CD][2])

---

# 14.913 When I would prefer Kustomize

Strong candidate when:

```text
You already have
clean Kubernetes YAML.

Environment differences
are relatively small.

You want Git diffs
close to actual Kubernetes.

You dislike template syntax.

You need clear overlays
for Dev/Stage/Prod.
```

Example:

```text
your own internal microservice
with stable Kubernetes structure.
```

---

# 14.914 When I would prefer Helm

Strong candidate when:

```text
You need a reusable package.

Many consumers configure it.

Many resources are optional.

You need dependency/chart distribution.

You're deploying third-party software.

The deployment requires
substantial parameterization.
```

Examples:

```text
Prometheus stack

ingress-nginx

Grafana

reusable company service chart
```

---

# 14.915 Don't turn it into religion

Bad:

```text
"Helm is always better."
```

or:

```text
"Kustomize is always more GitOps."
```

No.

Choose based on:

```text
configuration shape

reuse model

ownership

distribution

complexity

team familiarity

reviewability.
```

---

# 14.916 A hybrid organization is normal

Platform team:

```text
Helm
for reusable platform products
```

Application team:

```text
Kustomize
for environment customization
```

Argo CD can reconcile both.

You do not need one rendering tool for the entire enterprise.

---

# 14.917 But avoid unnecessary renderer nesting

Good:

```text
App A
→ Helm


App B
→ Kustomize
```

Potentially confusing:

```text
App C
→ Kustomize
   → Helm
      → plugins
         → generated YAML
```

Each extra layer increases:

```text
debugging path

security surface

renderer-version dependency

review complexity.
```

---

# 14.918 Kustomize Application-level patches

Current Argo supports inline Kustomize patches directly in the Application spec. ([Argo CD][2])

Example concept:

```yaml
source:

  path: base

  kustomize:

    patches:

      - target:
          kind: Deployment
          name: todo-backend

        patch: |-
          - op: replace
            path: /spec/replicas
            value: 5
```

Technically useful.

---

# 14.919 But where should persistent Prod configuration live?

I'd prefer:

```text
Git overlay:
overlays/prod
```

over:

```text
large inline patch
inside Application CR.
```

Why?

The overlay provides a clear:

```text
environment configuration
```

unit that can be rendered outside Argo too.

Keep Application definitions focused on:

```text
source

destination

project

sync policy.
```

---

# 14.920 Build environment annotations

Current Argo can perform environment-variable substitution in Kustomize `commonAnnotations` when:

```yaml
commonAnnotationsEnvsubst: true
```

is set. For example, Argo exposes build environment data such as the Application name that can be injected into annotations. ([Argo CD][2])

Useful for metadata.

But don't turn runtime environment substitution into hidden business configuration.

---

# 14.921 Example deployment metadata

Concept:

```yaml
source:

  kustomize:

    commonAnnotationsEnvsubst: true

    commonAnnotations:
      gitops.application: ${ARGOCD_APP_NAME}
```

Rendered resource:

```yaml
annotations:
  gitops.application: todo-backend-prod
```

This can aid traceability. ([Argo CD][2])

---

# 14.922 Base should remain directly understandable

Open:

```text
base/deployment.yaml
```

A Kubernetes engineer should understand:

```text
what is deployed

which ports

which probes

which resources

which service accounts
```

without running a template engine mentally.

That's one of Kustomize's biggest human advantages.

---

# 14.923 Overlay should tell a story

Open:

```text
overlays/prod/
```

You should quickly learn:

```text
Production namespace

Production image

Production replicas

Production resource sizing

Production-only policies
```

If you cannot understand that after a few minutes:

```text
overlay design
may be too complicated.
```

---

# 14.924 Production overlay example with HPA

Suppose HPA owns replicas.

Then base Deployment should ideally avoid having Argo continuously enforce a static replica count if that field is dynamically controlled.

Prod overlay adds:

```text
hpa.yaml
```

and:

```yaml
resources:

  - ../../base
  - hpa.yaml
```

Then ownership:

```text
Argo
→ HPA configuration


HPA controller
→ Deployment replicas
```

Clean controller boundaries.

---

# 14.925 Production-only NetworkPolicy

Base may contain the application's normal resources.

Prod overlay:

```yaml
resources:

  - ../../base
  - network-policy.yaml
```

if Prod specifically requires stricter network rules.

But ask whether:

```text
security baseline
```

should really be common across all environments.

Often it should be.

Don't accidentally leave Dev as the insecure forgotten environment.

---

# 14.926 Common security belongs in base

Examples:

```text
runAsNonRoot

readOnlyRootFilesystem

drop capabilities

resource limits

health probes
```

should often be:

```text
base defaults.
```

Then Dev doesn't silently become fundamentally less secure.

Environment overlays should represent legitimate differences—not shortcuts.

---

# 14.927 Don't use overlay to disable every safety feature in Dev

Bad:

```text
Dev:
no NetworkPolicy
privileged=true
runAsRoot
no limits
latest images
```

Then Dev no longer validates the same production architecture.

A useful pre-production environment should resemble Prod enough for testing to matter.

---

# 14.928 Kustomize and immutable artifact promotion

Base:

```yaml
image: todo-backend:PLACEHOLDER
```

Dev:

```yaml
newTag: f73ca19
```

Stage:

```yaml
newTag: f73ca19
```

Prod:

```yaml
newTag: 52ac814
```

Promotion:

```text
change only Prod image selection.
```

Exactly aligned with:

```text
BUILD ONCE
PROMOTE MANY.
```

---

# 14.929 Kustomize CI validation

GitOps PR pipeline:

```text
Pull Request
    │
    ▼
Render Dev
    │
    ▼
Render Stage
    │
    ▼
Render Prod
    │
    ▼
Schema validate
    │
    ▼
Policy validate
    │
    ▼
Security validate
    │
    ▼
Review
```

No application image build is needed in this repository.

---

# 14.930 Suggested validation commands

```bash
kubectl kustomize \
  apps/todo-backend/overlays/dev \
  > rendered-dev.yaml
```

```bash
kubectl kustomize \
  apps/todo-backend/overlays/staging \
  > rendered-staging.yaml
```

```bash
kubectl kustomize \
  apps/todo-backend/overlays/prod \
  > rendered-prod.yaml
```

Then your policy/schema tools consume those outputs.

---

# 14.931 Check image after rendering

For a quick lab check:

```bash
kubectl kustomize \
  apps/todo-backend/overlays/prod \
  | grep 'image:'
```

Expected conceptually:

```text
image:
123456789012.dkr.ecr.ap-south-1.amazonaws.com/todo-backend:52ac814
```

Never assume your `images:` transformer matched correctly.

Verify.

---

# 14.932 Check namespace after rendering

```bash
kubectl kustomize \
  apps/todo-backend/overlays/prod \
  | grep 'namespace:'
```

But for robust validation, inspect structured output rather than relying only on `grep`.

The point is:

```text
verify final desired state
before merge.
```

---

# 14.933 Argo diff after Git change

Production PR merged:

```text
52ac814
 ↓
f73ca19
```

Argo sees:

```text
desired Deployment
image=f73ca19


live Deployment
image=52ac814
```

Therefore:

```text
OutOfSync.
```

Auto-sync:

```text
Deployment updated.
```

Kubernetes performs rolling rollout.

---

# 14.934 Kustomize didn't deploy anything

Important:

```text
Kustomize
=
rendered.
```

It did not:

```text
monitor rollout

self-heal drift

prune resources

report application health
```

Those are Argo/Kubernetes responsibilities.

---

# 14.935 Same three-layer rule as Helm

```text
KUSTOMIZE
=
TRANSFORM


ARGO CD
=
RECONCILE


KUBERNETES
=
RUN
```

This parallels Lesson 6:

```text
HELM
=
RENDER
```

The renderer changes.

The GitOps control model doesn't.

---

# 14.936 Interview — What is Kustomize?

Strong answer:

> **Kustomize is a Kubernetes-native configuration customization tool that starts with Kubernetes resource manifests and declaratively composes and transforms them through `kustomization.yaml`, including resources, patches, images, labels, namespaces, generators and other transformations. It is integrated into `kubectl`.** ([Kubernetes][1])

---

# 14.937 Interview — base vs overlay

```text
BASE
=
shared reusable Kubernetes configuration


OVERLAY
=
environment/use-case-specific
customization of a base
```

A base should be independently reusable and shouldn't need knowledge of its overlays. ([Kubernetes][1])

---

# 14.938 Interview — Helm vs Kustomize

Strong answer:

> Helm is primarily a packaging and templating model where values are injected into chart templates. Kustomize is template-free customization of Kubernetes resources using bases, overlays, patches and transformers. Both can be used by Argo CD to generate the final desired manifests, after which Argo owns reconciliation.

---

# 14.939 Interview — How does Argo detect Kustomize?

If the configured Application source path contains:

```text
kustomization.yaml
```

Argo renders that path using Kustomize. ([Argo CD][2])

---

# 14.940 Interview — How do you deploy an overlay with Argo?

Point:

```yaml
spec:
  source:
    path: apps/todo-backend/overlays/prod
```

to the overlay directory containing the desired `kustomization.yaml`. Argo's Kustomize docs explicitly describe this pattern. ([Argo CD][2])

---

# 14.941 Interview — How do you promote an image with Kustomize?

Use the Kustomization:

```yaml
images:
```

transformer or an appropriate `kustomize edit set image` command, commit the resulting configuration change to Git, and allow Argo to reconcile it. Argo's official CI automation guide shows this exact GitOps pattern. ([Argo CD][3])

---

# 14.942 Interview — What does `configMapGenerator` do?

It generates ConfigMaps from:

```text
files

env files

literal values
```

and by default gives generated objects content-derived name suffixes; Kustomize updates references to those generated names. ([Kubernetes][1])

---

# 14.943 Interview — Why hash generated ConfigMaps?

When the content changes:

```text
resource name changes.
```

Consumers referencing the generated ConfigMap are updated to the new name, which creates a declarative signal that configuration changed. ([Kubernetes][1])

---

# 14.944 Interview — Does SecretGenerator make Git secrets secure?

No.

It generates a Kubernetes Secret, but if your source value is plaintext in Git:

```text
Git still contains the secret.
```

Use proper secret-management architecture for sensitive Production values.

---

# 14.945 Interview — what are replacements?

They allow Kustomize to copy a field value from a source object into selected fields of target objects, useful when names or other values are transformed and shouldn't be duplicated/hardcoded. ([Kubernetes][1])

---

# 14.946 Interview — private remote bases

Strong current answer:

> Argo can use private remote Kustomize bases when they can inherit the credentials of the application's main repository. It does not simply make unrelated private-repository credentials available to a Kustomize build, even if those credentials exist elsewhere in Argo CD. ([Argo CD][2])

---

# 14.947 Interview — Kustomize version mismatch

Argo CD can be configured with multiple Kustomize versions and Applications can select a configured version. Therefore a local/Argo rendering discrepancy can sometimes be caused by renderer-version differences. ([Argo CD][2])

---

# 14.948 Interview — `destination.namespace` vs Kustomize namespace

Strong answer:

> `destination.namespace` identifies the Application's destination/default namespace in Argo. For Kustomize applications, `spec.source.kustomize.namespace` causes Kustomize itself to perform namespace transformation; Argo documents cases involving custom-resource namespace fields where this can be more reliable. When both are set, the Kustomize namespace wins. ([Argo CD][2])

---

# 14.949 Interview — Kustomize + Helm under Argo

Possible, but `--enable-helm` is not an ordinary Application-level Kustomize option in Argo. Current documented approaches are a config-management plugin or globally configuring Kustomize build options. ([Argo CD][2])

Senior answer:

> I would only introduce this renderer nesting if it clearly reduces rather than increases operational complexity.

---

# 14.950 Interview trap — overlays contain full copies

Bad practice.

If overlay contains the entire Deployment again:

```text
you've largely defeated
base reuse.
```

Overlays should focus on differences.

---

# 14.951 Interview trap — `kubectl apply -k` is the GitOps deployment method

Not for an Argo-managed environment.

`kubectl apply -k` is a valid Kubernetes/Kustomize operation, but your normal GitOps deployment path should be:

```text
Git
→ Argo
→ Kubernetes.
```

`kubectl apply -k` bypasses Argo as deployment authority.

---

# 14.952 Interview trap — patching means editing base

Wrong.

Overlay transformations:

```text
produce final output
```

without modifying the underlying base files.

---

# 14.953 Interview trap — remote `main` base is immutable

Wrong.

If the remote branch moves:

```text
rendered desired state
can change.
```

Pin stable production dependencies.

---

# 14.954 Interview trap — Kustomize eliminates configuration complexity

No.

Bad Kustomize design can produce:

```text
many layers

ambiguous patches

fragile JSON paths

remote dependency sprawl

ownership confusion.
```

It eliminates template syntax—not architecture complexity.

---

# 14.955 Interview trap — labels are harmless metadata

Not always.

If labels are added to selectors:

```text
resource-selection semantics
can change.
```

Understand:

```text
metadata labels

vs

selectors.
```

---

# 14.956 Interview trap — generated Secret is safe because Kubernetes base64 encodes it

No.

Base64 is representation, not secret protection.

The Git source still matters.

---

# 14.957 Interview trap — Application-level Kustomize image override is always preferable

No.

It can obscure the environment's desired state from the Git overlay.

For persistent Production configuration:

```text
Git overlay
```

should generally remain the obvious source of truth.

---

# 14.958 Helm vs Kustomize decision tree

Use:

```text
Do I need a distributable,
parameterized software package?
        │
      YES
        │
        ▼
      HELM
```

Otherwise:

```text
Do I already have clean
Kubernetes manifests,
with modest environment differences?
        │
      YES
        │
        ▼
    KUSTOMIZE
```

If:

```text
third-party project already
publishes a mature Helm chart
```

strongly consider using the chart rather than rewriting it as Kustomize solely for stylistic purity.

---

# 14.959 Internal microservice example

For our Todo backend:

```text
Deployment
Service
HPA
PDB
NetworkPolicy
```

with only:

```text
image

resources

namespace

replicas/HPA parameters

environment settings
```

changing across environments:

```text
Kustomize
can be an excellent fit.
```

---

# 14.960 Platform product example

For an internal company platform chart consumed by:

```text
300 teams
```

with:

```text
many optional integrations

Ingress options

autoscaling options

service mesh

observability

storage classes

dependencies
```

Helm may provide the stronger reusable-package abstraction.

---

# 14.961 Production Todo Kustomize structure

Our mature structure could look like:

```text
todo-gitops/
│
├── apps/
│   │
│   ├── todo-backend/
│   │   │
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── pdb.yaml
│   │   │   └── kustomization.yaml
│   │   │
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   │
│   └── todo-frontend/
│       ├── base/
│       └── overlays/
│
└── argocd/
    ├── projects/
    └── applications/
```

Then later:

```text
ApplicationSet
```

can generate the environment Applications from this predictable structure.

---

# 14.962 Production promotion end-to-end

```text
DEVELOPER
    │
    ▼
Application source commit
    │
    ▼
Jenkins
    │
    ├── test
    ├── scan
    └── build
         │
         ▼
        ECR

todo-backend:f73ca19
         │
         ▼
GitOps Dev overlay
         │
   images.newTag
         │
         ▼
    f73ca19
         │
         ▼
      Argo Dev
         │
         ▼
       tests
         │
         ▼
Stage overlay
         │
         ▼
    f73ca19
         │
         ▼
    Production PR
         │
    CODEOWNERS
         │
         ▼
Prod overlay
         │
52ac814 → f73ca19
         │
         ▼
      Argo Prod
         │
         ▼
     Kustomize
         │
         ▼
 Rendered Deployment
         │
         ▼
      Kubernetes
```

That's a real production GitOps flow.

---

# 14.963 Kustomize's "never forget" sentence

> **The base describes what the application fundamentally is; the overlay describes how that application differs in a particular environment.**

If you remember that, most repository-design questions become much easier.

---

# 14.964 Production Kustomize checklist

```text
□ Base is valid Kubernetes YAML

□ Base contains common architecture

□ Overlays contain differences only

□ Dev/Stage/Prod paths are explicit

□ Image references are immutable

□ Remote bases are version-pinned

□ Patches are small and targeted

□ Patch ordering is understandable

□ Namespace ownership is clear

□ Selector-changing labels are deliberate

□ Generated ConfigMap behavior understood

□ Plaintext secrets are absent

□ Shared field ownership is clear

□ CI renders every important overlay

□ Rendered YAML passes policy checks

□ Argo and local renderer versions understood

□ Remote-base credentials tested

□ Production promotion changes are small

□ Application points directly to intended overlay
```

---

# 14.965 Never-forget Lesson 7 rules

```text
1.
Kustomize is template-free customization.


2.
Base + Overlay = final configuration.


3.
Base contains common resources.


4.
Overlay contains differences.


5.
Base should not know about overlays.


6.
kustomization.yaml controls composition.


7.
resources defines what participates.


8.
patches changes selected resource fields.


9.
JSON Patch gives precise operations.


10.
Patch ordering matters.


11.
images is excellent for artifact promotion.


12.
kustomize edit set image
fits CI → GitOps promotion.


13.
Build once, promote the same image.


14.
namespace can be transformed centrally.


15.
Labels may affect selectors;
use them carefully.


16.
ConfigMapGenerator can add
content-hashed names.


17.
Generated resource references
are updated automatically.


18.
SecretGenerator does not make
plaintext Git secrets safe.


19.
replacements copies values
between resource fields.


20.
Components model optional
reusable features.


21.
Remote bases are powerful
shared dependencies.


22.
Pin remote bases for Production.


23.
Private remote bases have
credential-boundary constraints in Argo.


24.
Argo detects Kustomize from
kustomization.yaml.


25.
Point Argo path to the overlay.


26.
Argo repo-server renders.


27.
Application controller reconciles.


28.
Kubernetes runs.


29.
Application-level overrides can
hide Git overlay intent.


30.
Persistent Production config
should remain obvious in Git.


31.
Argo can support multiple
Kustomize versions.


32.
Local render and Argo render
can differ if tooling/config differs.


33.
Kustomize + Helm is possible,
but adds another rendering layer.


34.
Don't use kubectl apply -k
as normal Argo production deployment.


35.
One field/resource should have
one authoritative controller.


36.
Render before merge.


37.
Diff after render.


38.
Synced does not mean Healthy.


39.
Overlays should remain small.


40.
Choose Helm vs Kustomize
based on the configuration problem,
not preference.
```

---

# 14.966 Lesson 7 troubleshooting flow

Memorize:

```text
BASE
  │
  ▼
OVERLAY
  │
  ▼
PATCH
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

Or:

# **B-O-P-R-D-S-H**

If you follow that order, Kustomize troubleshooting becomes much less confusing.

---

# ✅ Module 14 — Lesson 7 Complete

You now understand:

```text
✓ Kustomize mental model

✓ Template-free configuration

✓ Base

✓ Overlay

✓ kustomization.yaml

✓ resources

✓ patches

✓ structured patches

✓ JSON 6902 patches

✓ patch targeting

✓ patch ordering

✓ image transformations

✓ kustomize edit set image

✓ image promotion

✓ namespace transforms

✓ prefixes/suffixes

✓ labels

✓ annotations

✓ ConfigMapGenerator

✓ generated hashes

✓ generatorOptions

✓ SecretGenerator

✓ secret-security limitation

✓ replacements

✓ components

✓ ignoreMissingComponents

✓ remote bases

✓ immutable remote refs

✓ private remote-base credentials

✓ Argo Kustomize detection

✓ Kustomize Application paths

✓ Application-level Kustomize options

✓ namespace precedence nuances

✓ multiple Kustomize versions

✓ build options

✓ Kustomize + Helm

✓ Helm vs Kustomize decision-making

✓ Todo production Kustomize design
```

# Next — Module 14, Lesson 8

## AppProject, RBAC, SSO & Multi-Team Isolation

Now we're ready to solve a much more serious production question:

> **If one Argo CD instance serves Payments, Orders, Todo, Platform, Dev and Production teams, how do we stop one team from deploying anything to anywhere?**

We'll build the security hierarchy:

```text
CORPORATE IdP
      │
      ▼
    Argo CD
      │
      ▼
     RBAC
      │
      ▼
   AppProject
      │
      ├── allowed Git repositories
      ├── allowed clusters
      ├── allowed namespaces
      ├── allowed resource kinds
      ├── denied resource kinds
      ├── roles
      └── sync windows
      │
      ▼
 Applications
```

Then we'll go deeply into **`AppProject`, source repositories, destinations, cluster-resource allow/deny lists, namespace-resource controls, project roles, Argo RBAC policy syntax, SSO/OIDC, group mapping, built-in admin risk, default project lockdown, least privilege, production-vs-dev roles, platform-team vs app-team boundaries, namespace isolation, cluster-scoped-resource escalation, and real multi-team attack/troubleshooting scenarios**.

[1]: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ "Declarative Management of Kubernetes Objects Using Kustomize | Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/ "Kustomize - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/ "Automation from CI Pipelines - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_kustomize/ "kubectl kustomize | Kubernetes"
