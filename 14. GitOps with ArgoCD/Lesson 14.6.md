# Module 14 — GitOps with Argo CD

## Lesson 6: Helm + Argo CD — Production Helm GitOps Deep Dive

We now solve the duplication problem from Lesson 5.

Without Helm, we could easily end up with:

```text
deployment-dev.yaml
deployment-staging.yaml
deployment-prod.yaml

service-dev.yaml
service-staging.yaml
service-prod.yaml
```

where perhaps 90% of every file is identical.

Helm gives us:

```text
                 ONE HELM CHART
                       │
                 templates/
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼

        DEV VALUES  STAGE VALUES  PROD VALUES
             │         │              │
             ▼         ▼              ▼
       rendered YAML rendered YAML rendered YAML
             │         │              │
             └─────────┼──────────────┘
                       ▼
                     ARGO CD
                       │
                       ▼
                   Kubernetes
```

The single most important Argo + Helm rule is this:

> **Argo CD uses Helm to render/inflate the chart with `helm template`; Argo CD—not Helm—owns the application's deployment lifecycle and reconciliation.** ([Argo CD][1])

That sentence will prevent a lot of confusion later.

---

# 14.652 First — what problem does Helm solve?

Suppose our Todo backend needs:

```yaml
replicas: 1
```

in Dev,

```yaml
replicas: 2
```

in Staging,

and:

```yaml
replicas: 4
```

in Production.

Everything else is mostly identical:

```text
Deployment
Service
containerPort
health checks
security context
labels
```

Without templating:

```text
Copy YAML
↓
modify Dev

Copy YAML
↓
modify Stage

Copy YAML
↓
modify Prod
```

Eventually:

```text
Dev gets security fix
Prod doesn't.

Prod gets new probe
Stage doesn't.

One file uses port 3002.
Another accidentally uses 3001.
```

This is configuration duplication.

Helm lets us separate:

```text
STRUCTURE
+
VARIABLE DATA
```

---

# 14.653 Helm mental model

Think:

```text
TEMPLATE
+
VALUES
=
KUBERNETES MANIFEST
```

Example template:

```yaml
spec:
  replicas: {{ .Values.replicaCount }}
```

Values:

```yaml
replicaCount: 4
```

Rendered output:

```yaml
spec:
  replicas: 4
```

Helm templates are rendered into normal Kubernetes YAML; chart templates live under `templates/` and receive values through Helm's templating system. ([Helm][2])

---

# 14.654 Helm does not create a new Kubernetes API

This:

```yaml
replicas: {{ .Values.replicaCount }}
```

is **not valid Kubernetes YAML by itself**.

Kubernetes never sees the template expression.

Flow:

```text
Helm template
     │
     ▼
render
     │
     ▼
normal YAML
     │
     ▼
Kubernetes
```

So:

```text
Helm
=
manifest generator/package system
```

and:

```text
Kubernetes
=
runtime API.
```

---

# 14.655 Argo + Helm adds another layer

Without Argo:

```text
Helm CLI
   │
   ▼
helm install / upgrade
   │
   ▼
Kubernetes
```

With Argo:

```text
Git
 │
 ▼
Argo repo-server
 │
 ▼
Helm rendering
 │
 ▼
Desired Kubernetes YAML
 │
 ▼
Argo Application Controller
 │
 ▼
Diff / Sync / Self-Heal / Prune
 │
 ▼
Kubernetes
```

Argo CD's current Helm integration explicitly says Helm is used only to inflate the chart while Argo manages lifecycle. ([Argo CD][1])

---

# 14.656 This means there is no normal Helm release lifecycle

This is subtle.

If you deploy using:

```bash
helm install todo ...
```

Helm manages a Helm release.

But under Argo CD:

```text
helm template
```

is used to generate desired manifests.

Then Argo tracks the resulting Kubernetes objects.

So do not troubleshoot an Argo-managed Helm application by immediately thinking:

```bash
helm list
helm history
helm rollback
```

as though Helm itself installed the release.

The primary lifecycle tools become:

```bash
argocd app get
argocd app diff
argocd app sync
argocd app history
```

because Argo owns the lifecycle. ([Argo CD][1])

---

# 14.657 Permanent rule

```text
HELM
=
RENDER


ARGO CD
=
RECONCILE


KUBERNETES
=
RUN
```

Never forget this.

---

# 14.658 Current Helm version nuance in Argo CD

There is a very current detail worth knowing.

Current Argo CD 3.5 documentation says Argo uses a **Helm v4 binary** for chart rendering; the old Application field for choosing Helm v2/v3 exists only for backward compatibility. ([Argo CD][1])

So if you are following old tutorials containing:

```yaml
helm:
  version: v3
```

do not assume that configuration is still meaningful in current Argo CD.

---

# 14.659 Check your local Helm CLI

Run:

```bash
helm version
```

This local binary is useful for:

```text
chart development
linting
local rendering
debugging
```

Even though Argo's repo-server performs the actual production rendering for Argo-managed Applications.

---

# 14.660 Helm chart directory

A standard chart looks like:

```text
todo-backend/
│
├── Chart.yaml
├── values.yaml
├── values.schema.json      optional
│
├── charts/                 dependencies
├── crds/                   CRDs
│
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── _helpers.tpl
    └── ...
```

`Chart.yaml` is required; `values.yaml` contains default configuration, `templates/` contains templates, `charts/` holds dependencies, and `crds/` is reserved for CRDs. ([Helm][2])

---

# 14.661 Create our Todo Helm structure

Inside the GitOps repository conceptually:

```bash
mkdir -p charts/todo-backend/templates
mkdir -p charts/todo-backend/values
```

Structure:

```text
todo-gitops/
│
├── charts/
│   └── todo-backend/
│       ├── Chart.yaml
│       ├── values.yaml
│       │
│       ├── values/
│       │   ├── dev.yaml
│       │   ├── staging.yaml
│       │   └── prod.yaml
│       │
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           └── service.yaml
│
└── argocd/
    └── applications/
```

One chart.

Three environment overlays.

---

# 14.662 `Chart.yaml`

Create:

```yaml
apiVersion: v2

name: todo-backend

description: Helm chart for Todo backend

type: application

version: 0.1.0

appVersion: "1.0.0"
```

For modern application charts, `apiVersion: v2` is the normal chart API. `version` is the **chart package version**, while `appVersion` is informational metadata about the application version and does not control chart-version calculations. ([Helm][2])

---

# 14.663 Chart version vs app version

This distinction causes interview mistakes.

```text
Chart version
=
version of deployment package/template


Application version
=
version of software being deployed
```

Example:

```yaml
version: 0.8.2
appVersion: "4.7.1"
```

Meaning:

```text
Helm chart:
0.8.2

Application:
4.7.1
```

They do not have to match. ([Helm][2])

---

# 14.664 And container version is yet another thing

We may also have:

```yaml
image:
  tag: f73ca19
```

So now:

```text
Chart version
=
0.1.0


appVersion
=
1.0.0


Container tag
=
f73ca19
```

Three separate concepts.

The actual workload artifact is controlled by the rendered image reference—not automatically by `Chart.appVersion`.

---

# 14.665 `values.yaml` — default configuration

Create:

```yaml
replicaCount: 1

image:
  repository: ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/dev-todo-backend
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 3002

container:
  port: 3002

resources:
  requests:
    cpu: 100m
    memory: 128Mi

  limits:
    cpu: 500m
    memory: 512Mi

env:
  NODE_ENV: production
```

For our learning chart, this gives one central schema of configurable settings.

We will replace:

```text
latest
```

with an immutable CI-produced tag/digest before calling the release model production-ready.

---

# 14.666 Why keep defaults?

Templates should not contain random environment-specific constants everywhere.

Instead of:

```yaml
replicas: 4
```

inside `deployment.yaml`, use:

```yaml
replicas: {{ .Values.replicaCount }}
```

Then defaults come from:

```text
values.yaml
```

and environments override only what differs.

Helm supports chart defaults plus supplied values files and command-line/set overrides. ([Helm][3])

---

# 14.667 `_helpers.tpl`

Create:

```yaml
{{- define "todo-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "todo-backend.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "todo-backend.labels" -}}
app.kubernetes.io/name: {{ include "todo-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}
```

Helper templates allow repeated naming/labeling logic to live in one place.

---

# 14.668 Built-in Helm objects

Templates can access objects such as:

```text
.Values
.Chart
.Release
.Capabilities
```

For example:

```text
.Values.image.tag
```

comes from configuration.

```text
.Chart.Name
```

comes from `Chart.yaml`.

```text
.Release.Name
```

is the release name supplied during rendering.

Helm exposes built-in template objects such as Chart, Release, Values, and Capabilities. ([Helm][2])

---

# 14.669 Deployment template

Create:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: {{ include "todo-backend.fullname" . }}

  labels:
    {{- include "todo-backend.labels" . | nindent 4 }}

spec:
  replicas: {{ .Values.replicaCount }}

  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "todo-backend.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}

  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "todo-backend.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}

    spec:
      containers:

        - name: todo-backend

          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"

          imagePullPolicy: {{ .Values.image.pullPolicy }}

          ports:

            - name: http
              containerPort: {{ .Values.container.port }}

          env:

            - name: NODE_ENV
              value: {{ .Values.env.NODE_ENV | quote }}

          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

Now the **shape** of the Deployment is shared.

Environment-specific data lives elsewhere.

---

# 14.670 Service template

```yaml
apiVersion: v1
kind: Service

metadata:
  name: {{ include "todo-backend.fullname" . }}

  labels:
    {{- include "todo-backend.labels" . | nindent 4 }}

spec:

  type: {{ .Values.service.type }}

  selector:
    app.kubernetes.io/name: {{ include "todo-backend.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}

  ports:

    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
```

The backend application can continue listening on `3002`, while the Kubernetes Service exposes an internal service port such as `80`.

---

# 14.671 Render locally before involving Argo

Run:

```bash
helm template todo-dev ./charts/todo-backend
```

`helm template` renders the chart locally and prints the resulting manifests without actually installing them into Kubernetes. ([Helm][4])

This is one of the most important Helm debugging commands.

---

# 14.672 Think like Argo's repo-server

When you run:

```bash
helm template ...
```

locally, you're approximating one important part of what Argo's repo-server does.

Argo itself ultimately generates manifests using Helm rendering, then its Application Controller compares the result with the cluster. ([Argo CD][1])

So when Argo reports:

```text
ManifestGenerationError
```

your first instinct should often be:

```bash
helm template ...
```

not:

```bash
kubectl logs my-app
```

because the application hasn't even reached Kubernetes yet.

---

# 14.673 Validate the chart

Run:

```bash
helm lint ./charts/todo-backend
```

`helm lint` checks a chart for structural and conventional problems and reports errors/warnings. ([Helm][5])

A useful local workflow becomes:

```bash
helm lint ./charts/todo-backend

helm template todo-dev \
  ./charts/todo-backend
```

---

# 14.674 Render with debug

When something breaks:

```bash
helm template todo-dev \
  ./charts/todo-backend \
  --debug
```

This lets you inspect:

```text
template rendering

computed output

syntax problems

wrong indentation

missing values
```

before involving Argo.

---

# 14.675 Dev environment values

Create:

```yaml
# values/dev.yaml

replicaCount: 1

image:
  tag: dev-f73ca19

resources:
  requests:
    cpu: 100m
    memory: 128Mi

  limits:
    cpu: 250m
    memory: 256Mi

env:
  NODE_ENV: development
```

Now render:

```bash
helm template todo-dev \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/dev.yaml
```

---

# 14.676 Staging values

```yaml
replicaCount: 2

image:
  tag: f73ca19

resources:
  requests:
    cpu: 250m
    memory: 256Mi

  limits:
    cpu: 500m
    memory: 512Mi

env:
  NODE_ENV: production
```

Render:

```bash
helm template todo-staging \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/staging.yaml
```

---

# 14.677 Production values

```yaml
replicaCount: 4

image:
  tag: 52ac814

resources:
  requests:
    cpu: 500m
    memory: 512Mi

  limits:
    cpu: "1"
    memory: 1Gi

env:
  NODE_ENV: production
```

Render:

```bash
helm template todo-prod \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/prod.yaml
```

Same chart.

Different desired manifests.

---

# 14.678 Compare rendered output

Try:

```bash
helm template todo-dev \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/dev.yaml \
  > /tmp/dev.yaml
```

and:

```bash
helm template todo-prod \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/prod.yaml \
  > /tmp/prod.yaml
```

Then:

```bash
diff -u /tmp/dev.yaml /tmp/prod.yaml
```

You should see differences primarily in:

```text
release-dependent names

replicas

image tag

resources

environment
```

instead of maintaining whole duplicate manifest trees.

---

# 14.679 Helm values precedence

This is an interview favorite.

For current Argo CD Helm integration, highest → lowest precedence is:

```text
parameters
   ↓
valuesObject
   ↓
values
   ↓
valueFiles
   ↓
chart values.yaml
```

Argo CD documents that exact precedence order. ([Argo CD][1])

---

# 14.680 Never-forget precedence

```text
parameters
=
strongest override


valuesObject
=
next


values
=
next


valueFiles
=
next


chart values.yaml
=
base defaults
```

Think:

```text
DEFAULT
   ↓
ENV FILE
   ↓
INLINE OVERRIDE
   ↓
PARAMETER
```

---

# 14.681 Multiple value files

You can also do:

```yaml
helm:

  valueFiles:
    - values/common.yaml
    - values/prod.yaml
```

If the same key exists in both:

```text
later file wins.
```

Current Argo/Helm behavior gives higher precedence to later values files. ([Argo CD][1])

Example:

`common.yaml`:

```yaml
replicaCount: 2
```

`prod.yaml`:

```yaml
replicaCount: 5
```

Result:

```text
5
```

---

# 14.682 This gives a layering model

```text
values.yaml
     │
     ▼
common.yaml
     │
     ▼
region-mumbai.yaml
     │
     ▼
prod.yaml
```

For overlapping keys:

```text
later layer wins.
```

Useful.

But don't create:

```text
13 overlapping values files
```

where nobody knows which layer wins.

---

# 14.683 Current Argo supports globbing value files

Current Argo CD docs also support glob patterns in `valueFiles`, including `*` and recursive `**`. Matched files are sorted lexically before being passed to Helm, and because later values files win, filename ordering can affect final values. ([Argo CD][1])

Example:

```yaml
valueFiles:
  - values/*.yaml
```

with:

```text
00-defaults.yaml
10-region.yaml
20-prod.yaml
30-emergency-override.yaml
```

gives obvious ordering.

That is a current Argo capability you won't find in many older courses.

---

# 14.684 Missing value files

Normally, if Argo passes a missing Helm values file, manifest generation fails.

You can explicitly configure:

```yaml
helm:
  valueFiles:
    - values/common.yaml
    - values/prod-optional.yaml

  ignoreMissingValueFiles: true
```

This is useful in default/override patterns where an environment-specific override may intentionally not exist. ([Argo CD][1])

---

# 14.685 But don't hide typos

Suppose you meant:

```text
values/prod.yaml
```

but accidentally write:

```text
values/prdo.yaml
```

and have:

```yaml
ignoreMissingValueFiles: true
```

Argo may quietly proceed without the production override.

So:

```text
ignore missing
```

should express intentional optionality—not avoid fixing file paths.

---

# 14.686 Argo Application using our Git chart

Example Dev Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: todo-backend-dev
  namespace: argocd

spec:

  project: default

  source:

    repoURL: https://git.example.com/company/todo-gitops.git

    targetRevision: main

    path: charts/todo-backend

    helm:

      valueFiles:
        - values/dev.yaml

  destination:

    server: https://kubernetes.default.svc
    namespace: todo-dev

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

Because the chart is stored in Git, we specify:

```text
path
```

to the chart directory.

---

# 14.687 Production Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: todo-backend-prod
  namespace: argocd

spec:

  project: default

  source:

    repoURL: https://git.example.com/company/todo-gitops.git

    targetRevision: main

    path: charts/todo-backend

    helm:

      valueFiles:
        - values/prod.yaml

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

Same chart.

Different values.

Different Argo Application.

---

# 14.688 Argo detects Helm automatically

When an Application path contains a valid Helm chart, Argo's repo-server uses Helm as the manifest-generation tool.

Conceptually:

```text
Application
   │
   ▼
path: charts/todo-backend
   │
   ▼
Chart.yaml found
   │
   ▼
Helm rendering
```

---

# 14.689 Helm repository source is different

Suppose the chart is **not stored in Git**.

Instead:

```text
Helm Repository

https://example.com/charts
```

Then an Argo Application uses:

```yaml
source:

  repoURL: https://example.com/charts

  chart: todo-backend

  targetRevision: 1.8.2
```

When creating an Application from a Helm repository, Argo expects `chart` rather than Git `path`. ([Argo CD][6])

---

# 14.690 Git chart vs Helm repository

## Chart in Git

```yaml
repoURL: https://git.example.com/todo-gitops.git
path: charts/todo-backend
targetRevision: main
```

## Packaged Helm repository

```yaml
repoURL: https://charts.example.com
chart: todo-backend
targetRevision: 1.8.2
```

Permanent distinction:

```text
Git
→ path


Helm repository
→ chart
```

---

# 14.691 OCI Helm charts

Argo CD also supports Helm charts stored in OCI registries.

Current official example looks conceptually like:

```yaml
source:

  repoURL: registry-1.docker.io/bitnamicharts
  chart: nginx
  targetRevision: 15.9.0
```

One Argo-specific nuance: the documented OCI `repoURL` in the Application source does **not** include the `oci://` prefix. ([Argo CD][1])

---

# 14.692 Why OCI is interesting

It lets organizations store packaged Helm artifacts in an OCI-capable registry model alongside other artifact workflows.

Then:

```text
Chart package
→ immutable/versioned artifact

Values
→ desired environment configuration

Argo
→ reconciler
```

This can create strong separation between:

```text
chart release
```

and:

```text
environment config.
```

---

# 14.693 Chart version vs Git chart

Two useful patterns:

### Pattern A

```text
Chart source code in same GitOps repo
```

Argo tracks:

```text
Git revision
+
path
```

Simple for internal application charts.

### Pattern B

```text
Chart packaged and published
```

Argo tracks:

```text
chart version
```

Values may live separately in Git.

Useful for standardized platform/shared charts.

---

# 14.694 External chart + internal values

A very common enterprise case:

```text
public/third-party Helm chart
          │
          ▼
      Argo CD

plus

company Git repository
with approved values
```

Argo CD's multiple-sources feature explicitly supports using a Helm chart from one source and values files from another Git repository. ([Argo CD][7])

---

# 14.695 Multi-source Application example

Concept:

```yaml
spec:

  sources:

    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: prometheus
      targetRevision: 27.0.0

      helm:
        valueFiles:
          - $values/platform/prometheus/prod.yaml

    - repoURL: https://git.example.com/platform-config.git
      targetRevision: main
      ref: values
```

Meaning:

```text
Chart
=
external Helm repo


Values
=
our Git repo
```

This pattern is directly supported by Argo's multiple-sources model. ([Argo CD][7])

---

# 14.696 Why this is useful

You don't need to fork:

```text
Prometheus Helm chart
```

just to maintain:

```text
company values.
```

Instead:

```text
Upstream chart

+
Company-controlled values
```

Argo combines them.

This reduces unnecessary chart duplication while letting your company control deployment configuration.

---

# 14.697 But do not abuse multiple sources

Current Argo docs explicitly warn that `sources` is **not** intended as a generic mechanism to combine many unrelated applications; if you start adding many unrelated sources, ApplicationSet/App-of-Apps is usually the better architecture. ([Argo CD][7])

Think:

```text
Chart + Values
=
good multi-source use


Payments + Orders + Kafka + Grafana
=
probably wrong use
```

---

# 14.698 `valuesObject`

Instead of a file:

```yaml
helm:

  valuesObject:

    replicaCount: 4

    image:
      tag: f73ca19
```

Argo supports inline structured Helm values through `valuesObject`. ([Argo CD][1])

This is technically convenient.

But ask:

> Where do we want environment configuration to live?

For substantial production configuration, a Git values file is usually easier to:

```text
review
diff
reuse
own
```

than embedding a huge values block inside the Application CR.

---

# 14.699 `values`

Another option:

```yaml
helm:

  values: |
    replicaCount: 4

    image:
      tag: f73ca19
```

Current Argo also supports this string-based inline representation, but `valuesObject` has higher precedence than `values`. ([Argo CD][1])

---

# 14.700 Parameters

You can override individual Helm values:

```yaml
helm:

  parameters:

    - name: image.tag
      value: f73ca19

    - name: replicaCount
      value: "4"
```

These correspond conceptually to Helm's:

```bash
--set
```

and have the highest precedence among Argo's main value-injection methods. ([Argo CD][1])

---

# 14.701 Parameters can undermine GitOps clarity

Suppose Git's:

```text
values/prod.yaml
```

says:

```yaml
replicaCount: 4
```

but the Application contains:

```yaml
parameters:
  - name: replicaCount
    value: "1"
```

Result:

```text
1
```

because parameter wins.

An engineer reading `prod.yaml` may wonder:

> Why does production have one replica?!

Always understand the precedence chain.

---

# 14.702 Avoid UI-only production overrides

If you run:

```bash
argocd app set todo-prod \
  -p image.tag=f73ca19
```

you can change application parameters without editing the source values file.

Technically useful.

But now:

```text
Git values
≠
complete obvious production desired state.
```

Argo's own parameter-override documentation notes that many consider this pattern an anti-pattern for GitOps and recommends it primarily for convenience scenarios such as development/testing. ([Argo CD][8])

For Production, prefer changing Git.

---

# 14.703 Our production rule

```text
Dev experiment
→ parameter override may be convenient


Production desired state
→ change Git
```

This preserves:

```text
PR
approval
history
rollback
auditability
```

---

# 14.704 Helm `releaseName`

By default, Argo uses:

```text
Application name
```

as the Helm release name during rendering.

You can override:

```yaml
helm:
  releaseName: todo
```

Current Argo supports this directly. ([Argo CD][1])

---

# 14.705 But release-name overrides have a trap

Argo's docs warn that overriding the Helm release name can break charts that rely on:

```text
app.kubernetes.io/instance
```

because Argo uses its own Application name for resource tracking and can overwrite that label, causing selectors to disagree with the Helm release name. ([Argo CD][1])

So don't override:

```text
releaseName
```

casually.

---

# 14.706 Our naming strategy

Simplest:

```text
Application:
todo-backend-prod
```

Then allow:

```text
Release.Name
=
todo-backend-prod
```

and build labels/selectors consistently.

No unnecessary release-name override.

This minimizes tracking/selector surprises.

---

# 14.707 Chart dependencies

Suppose Todo chart depends on:

```text
common-library chart
```

or another Helm subchart.

Dependencies can be declared in:

```yaml
Chart.yaml
```

Example:

```yaml
dependencies:

  - name: common
    version: 1.4.2
    repository: https://charts.example.com
```

Helm supports chart dependencies via the `dependencies` field and stores downloaded dependency charts under `charts/`. ([Helm][9])

---

# 14.708 Lock dependencies

Run:

```bash
helm dependency update ./charts/todo-backend
```

Helm can generate a lock file capturing resolved dependency versions; `helm dependency build` can reconstruct dependencies from that lock instead of re-negotiating versions. ([Helm][10])

This improves reproducibility.

Think:

```text
Chart.yaml
=
allowed dependencies


Chart.lock
=
resolved dependencies
```

---

# 14.709 Reproducibility rule

Do not rely on:

```text
dependency:
latest compatible whatever
```

without understanding resolution.

For production:

```text
pin versions
+
keep lock state
+
test rendered output.
```

Same principle as:

```text
immutable container artifact.
```

---

# 14.710 `values.schema.json`

You can validate values structurally.

Example:

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1
    },
    "image": {
      "type": "object",
      "properties": {
        "repository": {
          "type": "string"
        },
        "tag": {
          "type": "string"
        }
      },
      "required": ["repository", "tag"]
    }
  },
  "required": ["replicaCount", "image"]
}
```

Helm supports `values.schema.json` as a JSON Schema for validating chart values. ([Helm][2])

---

# 14.711 Why schema matters

Without schema:

```yaml
replicaCount: banana
```

might only cause trouble deeper in rendering/API validation.

With schema:

```text
Values validation
     │
     X
invalid integer
```

earlier.

This is a strong **fail-left** control for GitOps configuration.

---

# 14.712 Don't skip schema validation casually

Argo CD can configure:

```yaml
helm:
  skipSchemaValidation: true
```

but this exists for specific compatibility situations. Current Argo maps this to Helm's schema-validation skipping behavior. ([Argo CD][1])

Production rule:

```text
Validation failure
→ normally fix values/schema

not
→ disable validation.
```

---

# 14.713 CRDs

Helm reserves:

```text
crds/
```

for CustomResourceDefinitions.

Helm treats CRDs specially: CRDs under `crds/` are plain YAML, cannot be templated, and are installed before normal chart templates under Helm's normal install semantics. ([Helm][2])

Argo CD exposes:

```yaml
helm:
  skipCrds: true
```

if CRD installation should be skipped. ([Argo CD][1])

---

# 14.714 Why skip CRDs?

A platform team might separately own:

```text
Prometheus Operator CRDs

cert-manager CRDs

Argo CRDs
```

while workload Applications consume the custom resources.

Then:

```text
Platform GitOps Application
=
owns CRDs


Workload Application
=
owns CR instances
```

This can make upgrade ownership clearer.

Again:

> One resource should have one authoritative lifecycle owner.

---

# 14.715 Helm hooks vs Argo hooks

Helm supports lifecycle hooks such as:

```text
pre-install
post-install
pre-upgrade
post-upgrade
```

Argo supports many Helm hook annotations by translating them into Argo hook/sync-phase semantics. But the semantics are not identical. ([Argo CD][1])

Example mapping:

```text
Helm pre-install
→ Argo PreSync

Helm pre-upgrade
→ Argo PreSync

Helm post-install
→ Argo PostSync

Helm post-upgrade
→ Argo PostSync
```

([Argo CD][1])

---

# 14.716 The install-vs-upgrade trap

Argo's docs highlight an important difference:

> Argo doesn't fundamentally know Helm's “first install” versus “upgrade” lifecycle—Argo performs **syncs**.

Consequently, Helm `pre-install` and `pre-upgrade` hooks can map into the same Argo `PreSync` phase. ([Argo CD][1])

This is why you shouldn't assume:

```text
Helm chart works under helm upgrade
=
identical lifecycle under Argo.
```

Test the Argo behavior.

---

# 14.717 Prefer Argo hooks for Argo-owned workflows

When designing our own GitOps charts, we will generally reason in Argo terms:

```text
PreSync

Sync

PostSync

SyncFail

sync waves
```

especially for operations such as:

```text
database migrations
pre-deployment validation
post-deployment jobs
```

Lesson 12 will go deeply into hooks/waves.

---

# 14.718 Another hook trap

Current Argo docs say if you define Argo CD hooks, Helm hooks in the same application are ignored. ([Argo CD][1])

So avoid creating:

```text
half Helm hook design
+
half Argo hook design
```

without understanding which controller semantics are actually active.

---

# 14.719 Random template data — major GitOps anti-pattern

Suppose Helm template contains:

```yaml
password: {{ randAlphaNum 20 }}
```

Every render can generate:

```text
new value.
```

Argo repeatedly renders charts while comparing desired state.

Therefore:

```text
Render 1 → ABC

Render 2 → XYZ

Render 3 → QWE
```

Argo sees:

```text
desired changed again
```

and the Application can remain continuously `OutOfSync`. Argo's Helm documentation explicitly calls out `randAlphaNum` as this exact problem. ([Argo CD][1])

---

# 14.720 Never generate unstable desired state

GitOps expects:

```text
same source
+
same inputs
=
same desired output
```

Random template generation violates that.

Permanent rule:

```text
Helm rendering
must be deterministic
for GitOps.
```

---

# 14.721 Secrets should not be generated randomly during render

Instead of:

```yaml
password: {{ randAlphaNum 20 }}
```

we will later use:

```text
External Secrets Operator
       │
       ▼
AWS Secrets Manager
```

so:

```text
Helm chart
=
declares secret reference


Secrets Manager
=
owns secret value.
```

Much cleaner.

---

# 14.722 Private Helm repositories

For private Helm repositories, Argo CD stores repository configuration/credentials in labeled Kubernetes Secrets. Current declarative setup supports credentials such as username/password and TLS client material. ([Argo CD][6])

Concept:

```text
Argo repo-server
      │
      ▼
repository credential
      │
      ▼
private Helm repository
```

Production principle:

```text
read-only credential
where possible.
```

---

# 14.723 Private OCI registry

OCI Helm repositories can likewise be configured as repository secrets with:

```yaml
type: helm
enableOCI: "true"
```

in current Argo declarative repository configuration. ([Argo CD][6])

We'll revisit this when we integrate private registries.

---

# 14.724 Don't put Helm repo passwords in Application YAML

Bad:

```yaml
username: admin
password: supersecret
```

inside version-controlled Application configuration.

Use:

```text
Argo repository credential Secret
```

and later integrate secret management appropriately.

Git desired state can declare:

```text
which source
```

without exposing:

```text
credentials.
```

---

# 14.725 Helm vs Kustomize — early preview

Helm thinks:

```text
TEMPLATE
+
VALUES
```

Kustomize thinks:

```text
BASE YAML
+
PATCHES
```

Example Helm:

```yaml
replicas: {{ .Values.replicaCount }}
```

Example Kustomize:

```text
base:
replicas 1

prod patch:
replicas 5
```

Both can produce:

```yaml
replicas: 5
```

We'll compare them properly in Lesson 7.

---

# 14.726 When Helm is especially useful

Helm is strong when you need:

```text
reusable application package

many configurable knobs

chart distribution

dependency management

third-party software packaging

conditional resources
```

Examples:

```text
Prometheus

Grafana

ingress-nginx

cert-manager

your reusable internal service chart
```

---

# 14.727 When Helm becomes dangerous

Bad chart:

```text
842 values

39 conditionals

10 layers of helpers

templates no one can understand
```

Now:

```text
Git review
```

doesn't meaningfully tell people what gets deployed.

Templating power should reduce duplication—not hide infrastructure logic.

---

# 14.728 Chart values design

Prefer:

```yaml
image:
  repository:
  tag:
  pullPolicy:

service:
  type:
  port:

resources:
  requests:
  limits:
```

over random flat names:

```yaml
img:
imgtag:
svcport:
maxmem:
```

Helm's own best-practice guidance recommends values structures that remain practical for users to override via values files or set-style inputs. ([Helm][11])

---

# 14.729 Don't template everything

Bad:

```yaml
apiVersion: {{ .Values.apiVersion }}
kind: {{ .Values.kind }}
```

Why make:

```text
Deployment
```

a configurable value if the chart fundamentally represents a Deployment?

Template things that are actually variable.

Keep stable architecture stable.

---

# 14.730 Environment differences should remain small

Our ideal chart:

```text
templates/
=
almost identical across environments
```

Environment values:

```text
Dev:
1 replica

Stage:
2 replicas

Prod:
4 replicas
```

rather than:

```text
Dev:
400-value override

Stage:
different 500-value override

Prod:
totally different architecture.
```

At that point, they may not really be one reusable deployment model anymore.

---

# 14.731 Production image promotion with Helm

Now Lesson 5 becomes simple.

Current Production:

```yaml
# values/prod.yaml

image:
  tag: 52ac814
```

CI builds:

```text
f73ca19
```

After Dev/Stage pass, Production PR:

```diff
 image:
-  tag: 52ac814
+  tag: f73ca19
```

Merge.

Argo:

```text
Git changed
   │
   ▼
repo-server
   │
   ▼
Helm render
   │
   ▼
Deployment image:
f73ca19
   │
   ▼
OutOfSync
   │
   ▼
Auto-sync
   │
   ▼
Kubernetes rollout
```

This is our production promotion model.

---

# 14.732 Helm chart did NOT change

Notice:

```text
templates/deployment.yaml
=
unchanged


Chart version
=
possibly unchanged


Prod values
=
image changed
```

A new application release does not necessarily require a new internal Git chart version if you're directly tracking the chart source in the same Git repository.

If you're publishing packaged Helm charts as artifacts, chart-versioning rules become more important.

---

# 14.733 Third-party chart version promotion

Suppose you're using:

```text
ingress-nginx chart 4.x
```

Then desired state might explicitly specify:

```yaml
chart: ingress-nginx
targetRevision: 4.14.0
```

Upgrade becomes:

```diff
-targetRevision: 4.14.0
+targetRevision: 4.15.1
```

This is chart promotion.

Different from:

```text
application image promotion.
```

---

# 14.734 Values and chart should both be versioned

Your rendered output depends on:

```text
chart version/source

+

values
```

Therefore production traceability needs both.

Example:

```text
Chart:
2.4.1


Values Git commit:
91bd2ee


Image:
sha256:abc...
```

Together they determine desired resources.

---

# 14.735 Inspect what Argo rendered

For an Argo Helm Application:

```bash
argocd app manifests todo-backend-prod
```

This is extremely valuable.

You don't just ask:

```text
"What values do I think Helm used?"
```

You ask:

```text
"What Kubernetes YAML did Argo actually render?"
```

That is the truth Argo compares against live state.

---

# 14.736 Helm troubleshooting hierarchy

Use:

# **C-V-R-D-S-H**

```text
C
CHART


V
VALUES


R
RENDER


D
DIFF


S
SYNC


H
HEALTH
```

This extends our earlier GitOps troubleshooting model.

---

# 14.737 C — Chart

Ask:

```text
Does Chart.yaml exist?

Correct chart path?

Correct chart version?

Dependencies available?

Correct repository?
```

If not:

```text
manifest generation never reaches Kubernetes.
```

---

# 14.738 V — Values

Ask:

```text
Which valueFiles?

Correct order?

Inline valuesObject?

parameters overriding files?

Wrong environment file?

Missing value?
```

This is where value precedence becomes essential.

---

# 14.739 R — Render

Locally:

```bash
helm lint ./charts/todo-backend
```

Then:

```bash
helm template todo-prod \
  ./charts/todo-backend \
  -f ./charts/todo-backend/values/prod.yaml \
  --debug
```

On Argo:

```bash
argocd app manifests todo-backend-prod
```

Compare expected with actual rendering.

---

# 14.740 D — Diff

```bash
argocd app diff todo-backend-prod
```

Ask:

```text
What rendered desired object
differs from live Kubernetes?
```

---

# 14.741 S — Sync

If rendering is correct but sync fails:

```text
Kubernetes RBAC?

AppProject?

admission webhook?

missing CRD?

immutable field?

resource ownership conflict?
```

Now you're beyond Helm templating.

---

# 14.742 H — Health

If:

```text
Synced
```

but:

```text
Degraded
```

then Helm already did its job.

Now check:

```bash
kubectl get pods -n todo-prod

kubectl describe pod <POD> -n todo-prod

kubectl logs <POD> -n todo-prod
```

Don't keep editing Helm values if the real problem is:

```text
application crash.
```

---

# 14.743 Common failure — `nil pointer`

Example:

```text
can't evaluate field repository
```

Template:

```yaml
{{ .Values.image.repository }}
```

but your values structure accidentally is:

```yaml
images:
  repository: ...
```

instead of:

```yaml
image:
  repository: ...
```

This is a **values/rendering issue**.

Run:

```bash
helm template ... --debug
```

---

# 14.744 Common failure — wrong indentation

Helm:

```yaml
resources:
{{ toYaml .Values.resources }}
```

may render malformed YAML.

Use:

```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

Template whitespace/indentation is one of the most common Helm debugging areas.

Always inspect rendered YAML.

---

# 14.745 Common failure — wrong values file

Argo Dev accidentally uses:

```yaml
valueFiles:
  - values/prod.yaml
```

Now Dev gets:

```text
4 replicas
production resources
production configuration
```

Argo is behaving correctly.

Your desired-state source is wrong.

---

# 14.746 Common failure — parameter silently wins

`values/prod.yaml`:

```yaml
replicaCount: 4
```

Application:

```yaml
parameters:
  - name: replicaCount
    value: "1"
```

Result:

```text
1
```

because parameters have higher precedence. ([Argo CD][1])

Never troubleshoot values without checking the whole precedence chain.

---

# 14.747 Common failure — random secret causes permanent OutOfSync

Chart:

```yaml
password: {{ randAlphaNum 16 }}
```

Every comparison renders a different password.

Argo sees perpetual differences.

Fix:

```text
stable deterministic value
```

or:

```text
external secret management.
```

This is an explicitly documented Argo/Helm GitOps failure pattern. ([Argo CD][1])

---

# 14.748 Common failure — releaseName breaks selectors

Chart selector expects:

```text
app.kubernetes.io/instance = custom-release
```

Argo tracking sets:

```text
app.kubernetes.io/instance = ApplicationName
```

Selector mismatch.

Symptoms may include:

```text
Service has no endpoints

Deployment selector mismatch

resources not selected properly
```

This is exactly why Argo warns about overriding Helm release names. ([Argo CD][1])

---

# 14.749 Common failure — Helm works manually, Argo doesn't

Engineer runs locally:

```bash
helm install ...
```

Works.

Argo fails.

Possible reasons:

```text
Different Helm version

different values

different releaseName

different namespace

different repository credentials

hook semantics

Argo tracking labels

different build environment
```

Remember current Argo 3.5 renders using Helm v4, so an older local Helm binary may not precisely reproduce Argo's rendering behavior. ([Argo CD][1])

---

# 14.750 Common failure — external chart values file unavailable

Application references:

```text
chart source A
```

and:

```text
values source B
```

If repository B can't be fetched:

```text
manifest generation fails.
```

Multi-source architecture creates multiple source dependencies.

Use it deliberately.

---

# 14.751 Common failure — dependency missing

`Chart.yaml` declares:

```yaml
dependencies:
  ...
```

but chart dependencies aren't resolved/available.

Locally:

```bash
helm dependency build ./charts/todo-backend
```

or:

```bash
helm dependency update ./charts/todo-backend
```

depending on whether you want locked reconstruction or dependency resolution. Helm distinguishes build-from-lock from update/resolve behavior. ([Helm][10])

---

# 14.752 Helm CI pipeline

Your GitOps PR pipeline should run something like:

```text
Pull Request
    │
    ▼
helm lint
    │
    ▼
helm dependency build
    │
    ▼
helm template Dev
    │
    ▼
helm template Stage
    │
    ▼
helm template Prod
    │
    ▼
schema validation
    │
    ▼
Kubernetes policy validation
    │
    ▼
review
```

This catches errors before Argo sees them.

---

# 14.753 Basic CI commands

For example:

```bash
helm lint charts/todo-backend
```

Then:

```bash
helm template todo-dev \
  charts/todo-backend \
  -f charts/todo-backend/values/dev.yaml \
  > rendered-dev.yaml
```

Then:

```bash
helm template todo-staging \
  charts/todo-backend \
  -f charts/todo-backend/values/staging.yaml \
  > rendered-staging.yaml
```

Then:

```bash
helm template todo-prod \
  charts/todo-backend \
  -f charts/todo-backend/values/prod.yaml \
  > rendered-prod.yaml
```

`helm lint` and `helm template` are standard Helm chart-development validation tools. ([Helm][5])

---

# 14.754 Add immutable CI image promotion

After Jenkins produces:

```text
f73ca19
```

do **not** change:

```text
Chart template.
```

Change:

```yaml
values/dev.yaml

image:
  tag: f73ca19
```

Then:

```text
Git commit
→ Argo render
→ Diff
→ Sync
```

Exactly what we designed in Lesson 5.

---

# 14.755 Production promotion PR

After Dev/Stage pass:

```diff
# values/prod.yaml

 image:
-  tag: 52ac814
+  tag: f73ca19
```

That's an excellent production promotion diff.

Reviewer immediately knows:

```text
Application:
Todo backend

Old artifact:
52ac814

New artifact:
f73ca19
```

No template refactor hidden inside the release.

---

# 14.756 Separate chart changes from image promotion

Prefer:

### PR A

```text
Upgrade health probe behavior
```

changes:

```text
templates/deployment.yaml
```

### PR B

```text
Promote backend f73ca19
```

changes:

```text
values/prod.yaml
```

This keeps:

```text
deployment package evolution
```

separate from:

```text
application release promotion.
```

---

# 14.757 Helm and secret values

Do not create:

```yaml
# values-prod.yaml

mongodbPassword: SuperSecret123
```

simply because Helm values files are convenient.

Values files are Git configuration.

Later we will use secret-management integration.

Remember:

```text
Helm
=
templates configuration


Secret Manager
=
secret material.
```

---

# 14.758 Helm chart should expose secret references

Better:

```yaml
secret:

  existingSecret: todo-backend-db
```

Template:

```yaml
env:

  - name: MONGODB_URI

    valueFrom:

      secretKeyRef:
        name: {{ .Values.secret.existingSecret }}
        key: mongodb-uri
```

Git contains:

```text
secret resource name
```

not:

```text
database password.
```

Later External Secrets will create the actual Kubernetes Secret.

---

# 14.759 Helm + HPA ownership

If an HPA manages replicas, do not make:

```text
Argo/Helm
```

and:

```text
HPA
```

fight over:

```text
spec.replicas.
```

A chart can conditionally omit static replica configuration when autoscaling is enabled.

Concept:

```yaml
autoscaling:
  enabled: true
```

Then template logic can avoid setting static replica ownership.

This carries forward our earlier controller-ownership rule.

---

# 14.760 Conditional resources

Helm allows:

```yaml
{{- if .Values.ingress.enabled }}

apiVersion: networking.k8s.io/v1
kind: Ingress
...

{{- end }}
```

Then:

```yaml
Dev:
ingress.enabled: false


Prod:
ingress.enabled: true
```

Possible.

But don't create so many conditions that one chart represents completely different systems.

---

# 14.761 Helm `required`

For critical values:

```yaml
image:
  repository: {{ required "image.repository is required" .Values.image.repository }}
```

Helm provides template functions such as `required` that can fail rendering when mandatory values are absent. ([Helm][12])

This is another fail-left technique.

---

# 14.762 Values schema is usually better for broad validation

`required` is useful for particular template requirements.

`values.schema.json` gives:

```text
type validation
minimum/maximum
required fields
structure
```

across the values model.

Use validation intentionally.

---

# 14.763 `tpl` — powerful but dangerous

Helm can render strings as templates with advanced techniques such as `tpl`.

Useful.

But excessive template-in-template design creates configuration that is difficult to audit.

Remember our GitOps goal:

```text
reviewable desired state.
```

Power is not automatically maintainability.

---

# 14.764 Helm release name vs Application name

For our design:

```text
Application:
todo-backend-prod
```

we'll generally let:

```text
Release.Name
=
todo-backend-prod
```

Then resources might become:

```text
todo-backend-prod-todo-backend
```

If that's too verbose, fix:

```text
chart naming helpers
```

rather than immediately overriding Argo's release name and potentially affecting tracking labels.

---

# 14.765 `fullnameOverride`

You can expose:

```yaml
fullnameOverride: ""
```

and if required:

```yaml
fullnameOverride: todo-backend
```

This can control Kubernetes resource names without changing Argo's release tracking identity.

Often cleaner than changing Argo `releaseName`.

---

# 14.766 One chart for frontend and backend?

We have:

```text
Todo frontend
Todo backend
```

Should they be one chart?

Maybe—but ask:

```text
Do they deploy together?

Do they version together?

Do they roll back together?

Do they have same owner?

Same scaling lifecycle?
```

If not, separate charts are usually cleaner:

```text
todo-frontend chart

todo-backend chart
```

and Argo manages them as separate Applications.

---

# 14.767 Our likely course architecture

```text
todo-gitops/
│
├── charts/
│   ├── todo-backend/
│   └── todo-frontend/
│
├── argocd/
│   ├── projects/
│   └── applications/
│
└── platform/
```

Then:

```text
todo-backend-dev
todo-backend-stage
todo-backend-prod

todo-frontend-dev
todo-frontend-stage
todo-frontend-prod
```

Later ApplicationSet will generate much of this automatically.

---

# 14.768 One generic company chart?

Some platform teams create:

```text
company-web-service
```

a reusable chart for hundreds of similar microservices.

Advantages:

```text
standard probes
securityContext
PDB
Service
Ingress
monitoring
labels
```

But it must remain flexible enough without becoming a 1,000-option abstraction monster.

We will discuss platform-engineering chart patterns later.

---

# 14.769 Helm is not a reason to hide Kubernetes

You still need to understand:

```text
Deployment

Service

Ingress

ConfigMap

Secret

HPA

PDB

NetworkPolicy
```

because Helm is only generating those objects.

When something fails:

```text
kubectl describe
```

still matters.

---

# 14.770 Argo UI shows rendered Kubernetes objects

You will not primarily see:

```text
Template line 32
```

in runtime topology.

Argo manages:

```text
Deployment
Service
Pod
...
```

because those are the rendered desired resources.

This reinforces:

```text
Helm
=
rendering layer.
```

---

# 14.771 Helm source → desired state flow

```text
                    GIT
                     │
                     ▼
               Helm Chart
                     │
              ┌──────┴──────┐
              ▼             ▼
         Templates        Values
              │             │
              └──────┬──────┘
                     ▼
                repo-server
                     │
                     ▼
                Helm render
                     │
                     ▼
             Kubernetes YAML
                     │
                     ▼
            Application Controller
                     │
              ┌──────┴──────┐
              ▼             ▼
           Desired          Live
              │             │
              └──────┬──────┘
                     ▼
                    Diff
                     │
                     ▼
                   Sync
```

That's the complete Argo + Helm pipeline.

---

# 14.772 Helm troubleshooting commands — never forget

```bash
helm version
```

Which Helm CLI do I have?

```bash
helm lint ./chart
```

Is chart structurally sound?

```bash
helm template RELEASE ./chart
```

What does it render?

```bash
helm template RELEASE ./chart \
  -f values/prod.yaml \
  --debug
```

What exactly renders with Production values?

```bash
helm dependency build ./chart
```

Are locked dependencies reconstructable?

Then Argo:

```bash
argocd app manifests APP
```

What did Argo render?

```bash
argocd app diff APP
```

What differs live?

---

# 14.773 Interview — How does Argo use Helm?

Strong answer:

> **Argo CD uses Helm as a manifest-generation engine, effectively rendering the chart with Helm template semantics. Helm does not own the Application lifecycle in this model; Argo CD owns comparison, synchronization, pruning, self-healing, and application status.** ([Argo CD][1])

---

# 14.774 Interview — `path` vs `chart`

```text
Helm chart stored in Git
→ path


Helm chart stored in Helm/OCI repo
→ chart
```

Argo's declarative setup explicitly distinguishes these two source types. ([Argo CD][6])

---

# 14.775 Interview — values precedence

Answer immediately:

```text
Highest

parameters
valuesObject
values
valueFiles
chart values.yaml

Lowest
```

([Argo CD][1])

---

# 14.776 Interview — multiple values files

> Later values files override earlier values files when the same key is defined. ([Argo CD][1])

So:

```yaml
valueFiles:
  - common.yaml
  - prod.yaml
```

means:

```text
prod
wins conflicts.
```

---

# 14.777 Interview — `valuesObject` vs `values`

```text
valuesObject
=
structured YAML object


values
=
YAML represented as string block
```

`valuesObject` has higher precedence than `values` in Argo's Helm integration. ([Argo CD][1])

---

# 14.778 Interview — What is chart `version` vs `appVersion`?

```text
version
=
Helm chart/package version


appVersion
=
informational application version
```

They are independent. ([Helm][2])

---

# 14.779 Interview — Why avoid `randAlphaNum`?

Because Argo repeatedly renders the chart during comparison.

A random value changes every render:

```text
desired A
desired B
desired C
```

causing perpetual drift/OutOfSync behavior. ([Argo CD][1])

---

# 14.780 Interview — Helm hooks vs Argo hooks

Good answer:

> Argo supports mappings for many Helm hook annotations, but the lifecycle semantics are Argo sync semantics, not a full reproduction of Helm install/upgrade behavior. For Argo-native workflows I prefer to reason using Argo hook phases and sync waves. ([Argo CD][1])

---

# 14.781 Interview — Can values live in another repo from the chart?

Yes.

Current Argo CD supports multi-source Applications where:

```text
Helm chart
=
source A


valueFiles
=
Git source B
```

This is a particularly useful pattern for third-party charts plus company-owned values. ([Argo CD][7])

---

# 14.782 Interview — OCI Helm chart syntax

Current Argo examples use an OCI registry-style `repoURL` without an `oci://` prefix in the Application source. ([Argo CD][1])

This is a nice current-version interview nuance.

---

# 14.783 Interview — why not parameter overrides in Production?

Because they can move part of desired state outside the obvious Git values file and make Git less authoritative/readable.

Prefer a Git PR:

```text
values/prod.yaml
```

for persistent Production configuration.

---

# 14.784 Interview trap — `helm list` is the main way to manage Argo Helm apps

Wrong.

Under Argo, Helm renders manifests while Argo owns lifecycle.

Use:

```text
argocd app ...
```

as the primary control plane. ([Argo CD][1])

---

# 14.785 Interview trap — chart version automatically updates container image

Wrong.

These are independent unless the chart explicitly wires:

```text
.Chart.AppVersion
```

into the image tag.

Even then, that is chart-template behavior—not automatic Helm magic.

---

# 14.786 Interview trap — values files override parameters

Wrong.

Parameters are higher precedence. ([Argo CD][1])

---

# 14.787 Interview trap — first value file wins

Wrong.

For overlapping values:

```text
last values file wins.
```

([Argo CD][1])

---

# 14.788 Interview trap — Helm hooks behave exactly like Helm CLI under Argo

Wrong.

Argo maps supported annotations to Argo hook semantics and treats operations as syncs rather than Helm's install/upgrade distinction. ([Argo CD][1])

---

# 14.789 Interview trap — `releaseName` is harmless

Not always.

It can interact badly with charts using:

```text
app.kubernetes.io/instance
```

because Argo also uses application tracking labels. ([Argo CD][1])

---

# 14.790 Interview trap — random password generation is good Helm security

Not under GitOps rendering.

Random rendering creates nondeterministic desired state.

Use proper secret management.

---

# 14.791 Production Helm checklist

Before a chart enters Production:

```text
□ helm lint passes

□ chart renders for every environment

□ values schema validates

□ immutable image reference

□ no plaintext secret values

□ no random rendering

□ chart dependencies pinned/locked

□ release-name behavior understood

□ hooks tested under Argo semantics

□ environment values are small/clear

□ resource ownership is clear

□ render output policy-validated

□ Argo diff understood

□ rollback artifact retained
```

---

# 14.792 Our production Todo flow with Helm

```text
Todo Backend Source
        │
        ▼
      Jenkins
        │
   Test / Scan
        │
        ▼
 Docker Build
        │
        ▼
       ECR

todo-backend:f73ca19
        │
        ▼
GitOps PR

values/dev.yaml
tag → f73ca19
        │
        ▼
      Argo
        │
        ▼
   Helm Render
        │
        ▼
 Kubernetes Dev
        │
        ▼
     Testing
        │
        ▼
values/staging.yaml
tag → f73ca19
        │
        ▼
      Stage
        │
        ▼
    Prod PR

values/prod.yaml

52ac814
   ↓
f73ca19
        │
        ▼
      Argo
        │
        ▼
   Helm Render
        │
        ▼
    Production
```

One application artifact.

One reusable chart.

Environment-specific values.

---

# 14.793 The most important Helm/Argo sentence

Memorize:

> **Git contains chart + values, Helm turns them into Kubernetes manifests, and Argo CD continuously reconciles those rendered manifests with the cluster.**

That is the entire architecture compressed into one sentence.

---

# 14.794 Never-forget Lesson 6 rules

```text
1.
Helm solves manifest reuse/configuration.


2.
Template + values = manifest.


3.
Argo uses Helm mainly to render.


4.
Argo owns lifecycle and reconciliation.


5.
Kubernetes receives ordinary YAML.


6.
Chart.yaml describes the chart.


7.
values.yaml provides defaults.


8.
templates/ contains manifest templates.


9.
Chart version ≠ appVersion.


10.
Container version is another concern.


11.
Render locally with helm template.


12.
Validate with helm lint.


13.
Use environment-specific values.


14.
Avoid full manifest duplication.


15.
Later value files override earlier files.


16.
Parameters have highest Argo Helm
value precedence.


17.
Production configuration should
prefer Git over UI parameter overrides.


18.
Git chart source uses path.


19.
Helm repo source uses chart.


20.
OCI Helm charts are supported.


21.
Chart and values may come
from separate sources.


22.
Don't abuse multi-source Applications.


23.
Pin chart/dependency versions.


24.
Use Chart.lock for reproducibility
when dependencies are involved.


25.
Use values.schema.json for validation.


26.
CRD ownership must be deliberate.


27.
Helm hooks under Argo use
Argo sync semantics.


28.
Install vs upgrade is not the
primary Argo lifecycle model.


29.
Random template values break
deterministic GitOps.


30.
Avoid plaintext secrets in values.


31.
Be careful overriding releaseName.


32.
One resource should have
one controller/lifecycle owner.


33.
Promote immutable image references
through values files.


34.
Separate chart changes from
application release promotion.


35.
Always inspect rendered manifests
when troubleshooting.
```

---

# 14.795 Lesson 6 troubleshooting mnemonic

Remember:

# **C → V → R → D → S → H**

```text
C
CHART

Is the chart correct?


V
VALUES

Which values actually won?


R
RENDER

What YAML did Helm/Argo generate?


D
DIFF

What differs from live?


S
SYNC

Could Argo apply it?


H
HEALTH

Does the resulting workload work?
```

This is the Helm-specific extension of our GitOps troubleshooting flow.

---

# ✅ Module 14 — Lesson 6 Complete

You now understand:

```text
✓ Helm mental model

✓ Argo + Helm architecture

✓ helm template lifecycle

✓ Chart.yaml

✓ chart version

✓ appVersion

✓ values.yaml

✓ templates

✓ helpers

✓ Deployment templating

✓ Service templating

✓ environment values

✓ local rendering

✓ helm lint

✓ values precedence

✓ multiple values files

✓ current value-file glob support

✓ ignoreMissingValueFiles

✓ valuesObject

✓ parameters

✓ Git Helm charts

✓ packaged Helm repositories

✓ OCI Helm charts

✓ multi-source Helm values

✓ releaseName

✓ dependency management

✓ Chart.lock

✓ values.schema.json

✓ CRDs

✓ Helm hooks under Argo

✓ nondeterministic rendering

✓ private repositories

✓ CI validation

✓ immutable promotion

✓ Todo backend Helm architecture
```

# Next — Module 14, Lesson 7

## Kustomize + Argo CD — Base, Overlays & Production Environment Design

Next we'll solve the same configuration-reuse problem **without templating**.

Instead of:

```text
Helm

template:
replicas: {{ .Values.replicaCount }}
```

we'll use:

```text
Kustomize

BASE
  │
  ▼
real Kubernetes YAML
  │
  ├── Dev patches
  ├── Stage patches
  └── Prod patches
```

Architecture:

```text
                         BASE

                  Deployment
                  Service
                  HPA
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼

      DEV OVERLAY  STAGE OVERLAY  PROD OVERLAY
          │           │              │
          ▼           ▼              ▼

       Kustomize   Kustomize      Kustomize
          │           │              │
          ▼           ▼              ▼

        Argo Dev    Argo Stage      Argo Prod
```

We'll go deeply into **`kustomization.yaml`, resources, patches, images, labels, namespace transformation, ConfigMap/Secret generators, base/overlay design, components, replacements, image promotion, Argo's native Kustomize rendering, overlay drift, remote bases, immutable references, Helm vs Kustomize decision-making, and converting the same Todo application so you can understand exactly when to choose Helm and when to choose Kustomize.**

[1]: https://argo-cd.readthedocs.io/en/latest/user-guide/helm/ "Helm - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://helm.sh/docs/topics/charts/ "Charts | Helm"
[3]: https://helm.sh/docs/chart_template_guide/values_files/ "Values Files | Helm"
[4]: https://helm.sh/docs/helm/helm_template?utm_source=chatgpt.com "helm template"
[5]: https://helm.sh/docs/helm/helm_lint/?utm_source=chatgpt.com "helm lint"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/ "Declarative Setup - Argo CD - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/latest/user-guide/multiple_sources/ "Multiple Sources for an Application - Argo CD - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/user-guide/parameters/?utm_source=chatgpt.com "Parameter Overrides - Declarative GitOps CD for Kubernetes"
[9]: https://helm.sh/docs/topics/charts?utm_source=chatgpt.com "Charts"
[10]: https://helm.sh/docs/helm/helm_dependency_update?utm_source=chatgpt.com "helm dependency update"
[11]: https://helm.sh/docs/chart_best_practices/values?utm_source=chatgpt.com "Values"
[12]: https://helm.sh/docs/howto/charts_tips_and_tricks?utm_source=chatgpt.com "Chart Development Tips and Tricks"
