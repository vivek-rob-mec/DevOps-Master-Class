# Lesson 10.13 — Helm, Kustomize, Overlays, Release Packaging, and Environment Promotion

In Lesson 10.12, you learned **PersistentVolumes, PVCs, StorageClasses, StatefulSets, and database patterns**.

Now we move to a very practical production problem:

```text id="qdm1ge"
How do we manage Kubernetes YAML cleanly across dev, staging, and production?
```

Raw YAML is fine at the beginning. But after some time, your app has:

```text id="bcwr0x"
Deployment
Service
Ingress
ConfigMap
Secret reference
ServiceAccount
RBAC
HPA
PDB
NetworkPolicy
dev config
staging config
production config
different image tags
different replica counts
different hostnames
different resources
different rollout policies
```

Copy-pasting YAML across environments becomes dangerous.

This lesson covers the two most common packaging/configuration tools:

```text id="pbdopq"
Helm:
  template-based Kubernetes package manager

Kustomize:
  template-free Kubernetes YAML customization tool
```

Helm helps define, install, and upgrade Kubernetes applications using charts, while Kustomize customizes Kubernetes configuration using bases, overlays, generators, and patches without introducing a separate templating language. ([Helm][1])

---

# 1. What We Will Cover

```text id="cazdqq"
10.13.1   Why raw YAML becomes hard
10.13.2   Helm mental model
10.13.3   Chart.yaml
10.13.4   values.yaml
10.13.5   templates
10.13.6   helm template
10.13.7   helm install
10.13.8   helm upgrade
10.13.9   helm rollback
10.13.10  helm lint
10.13.11  helm package
10.13.12  Kustomize mental model
10.13.13  base and overlays
10.13.14  patches
10.13.15  configMapGenerator
10.13.16  secretGenerator
10.13.17  image tag promotion
10.13.18  dev/staging/production promotion
10.13.19  Helm vs Kustomize
10.13.20  demo-node-api packaging pattern
10.13.21  validation script
10.13.22  cleanup script
```

---

# 2. Create Lesson Folder

```bash id="1g2epb"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.13-helm-kustomize-release-packaging/{helm,kustomize,manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="apv6f2"
tree -L 2 10.13-helm-kustomize-release-packaging
```

---

# 3. Why Raw YAML Becomes Hard

At first, this is manageable:

```text id="543sxu"
deployment.yaml
service.yaml
ingress.yaml
```

Then production grows:

```text id="8fw9v2"
deployment.yaml
service.yaml
ingress.yaml
configmap.yaml
serviceaccount.yaml
hpa.yaml
pdb.yaml
networkpolicy.yaml
secret.example.yaml
rbac.yaml
```

Then environments appear:

```text id="nc5qsv"
dev:
  replicas: 1
  image tag: dev
  host: api-dev.localdev.me
  log level: debug

staging:
  replicas: 2
  image tag: release-candidate
  host: api-staging.example.com
  log level: info

production:
  replicas: 4
  image tag: stable release
  host: api.yourdatascientist.tech
  log level: warn
```

Bad approach:

```text id="ycqt7h"
copy deployment.yaml into dev/
copy deployment.yaml into staging/
copy deployment.yaml into production/
edit each manually
forget what changed
break production
```

Good approach:

```text id="qi8xt5"
one base definition
small environment-specific overrides
render before deploy
diff before apply
promote the same image through environments
```

Kubernetes supports declarative management through files and directories with `kubectl apply`; `kubectl diff` can preview changes before applying them. ([Kubernetes][2])

---

# 4. Helm Mental Model

Helm is like a package manager for Kubernetes.

Simple mental model:

```text id="o8dqzi"
Chart:
  package source code for Kubernetes manifests

Values:
  environment-specific inputs

Templates:
  Kubernetes YAML with placeholders

Release:
  installed instance of a chart in a cluster
```

Flow:

```text id="5ceds2"
Chart templates
  + values.yaml
  + values-dev.yaml
  ↓
helm template / helm install
  ↓
rendered Kubernetes YAML
  ↓
Kubernetes API
  ↓
running release
```

Helm charts are the packaging format; Helm can install charts from an unpacked chart directory, packaged chart, chart reference, or URL. ([Helm][3])

---

# 5. Install Helm

Check if Helm exists:

```bash id="9hz4c5"
helm version
```

If missing, install using the official script method:

```bash id="xgu0ja"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

helm version
```

The Helm install guide says Helm can be installed from source, pre-built binary releases, or official Helm project installation methods. ([Helm][4])

Production habit:

```text id="h1a08e"
Read install scripts before executing them.
Pin tool versions in CI/CD where possible.
```

---

# 6. Create Helm Demo Chart

Create chart folder:

```bash id="6g9l63"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates
```

Create `Chart.yaml`:

```bash id="05dd74"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/Chart.yaml
```

Paste:

```yaml id="v94pt0"
apiVersion: v2
name: helm-demo
description: A production-style Helm demo chart for Kubernetes learning
type: application
version: 0.1.0
appVersion: "1.27.0"
```

In Helm charts, `apiVersion: v2` is used for Helm 3 charts. The chart `version` is used by Helm tooling and packaging, while `appVersion` is informational and represents the application version. ([Helm][5])

---

# 7. Create Helm `values.yaml`

Create:

```bash id="9vz404"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/values.yaml
```

Paste:

```yaml id="q2lhcb"
replicaCount: 1

image:
  repository: nginx
  tag: "1.27-alpine"
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  name: ""

service:
  type: ClusterIP
  port: 80
  targetPort: http

ingress:
  enabled: false
  className: nginx
  host: helm-demo.localdev.me
  path: /
  pathType: Prefix

resources:
  requests:
    cpu: "50m"
    memory: "64Mi"
  limits:
    cpu: "250m"
    memory: "128Mi"

podLabels:
  environment: dev

config:
  APP_ENV: dev
  LOG_LEVEL: debug
```

Helm values files are YAML inputs used to supply configurable values to chart templates, and Helm commands can override values through additional values files or command-line flags. ([Helm][6])

---

# 8. Create Helper Template

Create:

```bash id="fzg0oy"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/_helpers.tpl
```

Paste:

```gotemplate id="zng814"
{{- define "helm-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "helm-demo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "helm-demo.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "helm-demo.labels" -}}
app.kubernetes.io/name: {{ include "helm-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "helm-demo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "helm-demo.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
```

This gives reusable names and labels.

---

# 9. Create ServiceAccount Template

Create:

```bash id="akq9lu"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/serviceaccount.yaml
```

Paste:

```yaml id="2oo2mn"
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "helm-demo.serviceAccountName" . }}
  labels:
    {{- include "helm-demo.labels" . | nindent 4 }}
automountServiceAccountToken: false
{{- end }}
```

Production note:

```text id="ddt061"
Default to automountServiceAccountToken: false unless the workload needs Kubernetes API access.
```

---

# 10. Create ConfigMap Template

Create:

```bash id="h5bmqm"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/configmap.yaml
```

Paste:

```yaml id="h4y8my"
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "helm-demo.fullname" . }}
  labels:
    {{- include "helm-demo.labels" . | nindent 4 }}
data:
  APP_ENV: {{ .Values.config.APP_ENV | quote }}
  LOG_LEVEL: {{ .Values.config.LOG_LEVEL | quote }}
```

---

# 11. Create Deployment Template

Create:

```bash id="qk5nej"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/deployment.yaml
```

Paste:

```yaml id="dy570r"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "helm-demo.fullname" . }}
  labels:
    {{- include "helm-demo.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ include "helm-demo.name" . }}
      app.kubernetes.io/instance: {{ .Release.Name }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ include "helm-demo.name" . }}
        app.kubernetes.io/instance: {{ .Release.Name }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ include "helm-demo.serviceAccountName" . }}
      automountServiceAccountToken: false
      containers:
        - name: web
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: {{ include "helm-demo.fullname" . }}
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: {{ include "helm-demo.fullname" . }}
                  key: LOG_LEVEL
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

---

# 12. Create Service Template

Create:

```bash id="2iz93i"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/service.yaml
```

Paste:

```yaml id="wc1c8s"
apiVersion: v1
kind: Service
metadata:
  name: {{ include "helm-demo.fullname" . }}
  labels:
    {{- include "helm-demo.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: {{ include "helm-demo.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
```

---

# 13. Create Optional Ingress Template

Create:

```bash id="h5bm5v"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/templates/ingress.yaml
```

Paste:

```yaml id="r93s97"
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "helm-demo.fullname" . }}
  labels:
    {{- include "helm-demo.labels" . | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: {{ .Values.ingress.path }}
            pathType: {{ .Values.ingress.pathType }}
            backend:
              service:
                name: {{ include "helm-demo.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
```

---

# 14. Create Environment Values Files

Create dev values:

```bash id="90ki6k"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml
```

Paste:

```yaml id="4vdzwn"
replicaCount: 1

image:
  repository: nginx
  tag: "1.27-alpine"

podLabels:
  environment: dev

config:
  APP_ENV: dev
  LOG_LEVEL: debug

ingress:
  enabled: false
  host: helm-demo-dev.localdev.me
```

Create staging values:

```bash id="9az1yi"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-staging.yaml
```

Paste:

```yaml id="6y4bwr"
replicaCount: 2

image:
  repository: nginx
  tag: "1.27-alpine"

podLabels:
  environment: staging

config:
  APP_ENV: staging
  LOG_LEVEL: info

ingress:
  enabled: true
  host: helm-demo-staging.localdev.me

resources:
  requests:
    cpu: "75m"
    memory: "96Mi"
  limits:
    cpu: "300m"
    memory: "192Mi"
```

Create production values:

```bash id="jm3zav"
nano 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-production.yaml
```

Paste:

```yaml id="2pyw7q"
replicaCount: 3

image:
  repository: nginx
  tag: "1.27-alpine"

podLabels:
  environment: production

config:
  APP_ENV: production
  LOG_LEVEL: warn

ingress:
  enabled: true
  host: helm-demo.yourdatascientist.tech

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

---

# 15. Render Helm Chart Locally

Before installing anything, render the chart.

```bash id="e0jsvx"
cd ~/devops-masterclass/10-kubernetes-production-operations

helm template helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml
```

Save rendered output:

```bash id="k9cnfs"
helm template helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml \
  > 10.13-helm-kustomize-release-packaging/reports/helm-demo-dev-rendered.yaml
```

Inspect:

```bash id="5p91z7"
less 10.13-helm-kustomize-release-packaging/reports/helm-demo-dev-rendered.yaml
```

Production habit:

```text id="9u13fd"
Always render and review before installing important releases.
```

---

# 16. Lint Helm Chart

Run:

```bash id="hcv6fx"
helm lint 10.13-helm-kustomize-release-packaging/helm/helm-demo
```

Expected:

```text id="6gevmj"
1 chart(s) linted, 0 chart(s) failed
```

Production rule:

```text id="wp1h1y"
helm lint should run in CI before helm upgrade.
```

---

# 17. Install Helm Release

Make sure namespace exists:

```bash id="mm0p5k"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
```

Install:

```bash id="680dn4"
helm install helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml
```

Check:

```bash id="0n8oza"
helm list -n dev
kubectl get deploy,svc,pods -n dev -l app.kubernetes.io/instance=helm-demo
kubectl rollout status deployment/helm-demo-helm-demo -n dev
```

Port-forward:

```bash id="6o8xor"
kubectl port-forward -n dev svc/helm-demo-helm-demo 8086:80
```

Another terminal:

```bash id="8bd7xc"
curl http://127.0.0.1:8086
```

Stop:

```text id="hp5umc"
Ctrl + C
```

---

# 18. Upgrade Helm Release

Change replica count and log level through values:

```bash id="i5lxq6"
helm upgrade helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml \
  --set replicaCount=2 \
  --set config.LOG_LEVEL=info
```

Check:

```bash id="dnt3as"
helm history helm-demo -n dev
kubectl get pods -n dev -l app.kubernetes.io/instance=helm-demo
kubectl get configmap helm-demo-helm-demo -n dev -o yaml
```

The `helm upgrade` command upgrades an existing release to a new chart version or values set, and values can be overridden with files or `--set`; when multiple values files are passed, later files take precedence. ([Helm][7])

---

# 19. Roll Back Helm Release

View history:

```bash id="g6zwed"
helm history helm-demo -n dev
```

Rollback to revision 1:

```bash id="ve3raw"
helm rollback helm-demo 1 -n dev
```

Check:

```bash id="f3rcdl"
helm history helm-demo -n dev
kubectl get deployment helm-demo-helm-demo -n dev
kubectl get configmap helm-demo-helm-demo -n dev -o yaml
```

The Helm rollback command rolls a release back to a previous revision; if the revision is omitted or set to `0`, it rolls back to the previous release revision. ([Helm][8])

---

# 20. Helm Upgrade with `--atomic`

For safer releases:

```bash id="j36kdy"
helm upgrade helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml \
  --set replicaCount=2 \
  --atomic \
  --timeout 2m
```

Meaning:

```text id="4yypyu"
If upgrade fails, Helm attempts to roll back automatically.
```

Production habit:

```text id="ervyyu"
Use --atomic and timeout in CI/CD for safer releases.
```

---

# 21. Package Helm Chart

Package:

```bash id="5udll9"
helm package \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  --destination 10.13-helm-kustomize-release-packaging/reports
```

Check:

```bash id="32m7uk"
ls -lh 10.13-helm-kustomize-release-packaging/reports/*.tgz
```

Expected:

```text id="xj7bau"
helm-demo-0.1.0.tgz
```

Chart package naming uses the chart `version` from `Chart.yaml`, and Helm expects that package version to match the chart metadata. ([Helm][5])

---

# 22. Kustomize Mental Model

Kustomize is different from Helm.

Helm:

```text id="6o0bi4"
uses templates
values are injected into templates
```

Kustomize:

```text id="c13enm"
uses plain Kubernetes YAML
base remains valid YAML
overlays patch/customize base
```

Kustomize can generate resources, set cross-cutting fields, and compose/customize collections of Kubernetes resources. It also supports `configMapGenerator` and `secretGenerator`. ([Kubernetes][9])

Simple structure:

```text id="djcnim"
base/
  deployment.yaml
  service.yaml
  kustomization.yaml

overlays/
  dev/
    kustomization.yaml
    patch.yaml

  staging/
    kustomization.yaml
    patch.yaml

  production/
    kustomization.yaml
    patch.yaml
```

Flow:

```text id="3xpq0y"
base YAML
  + overlay patches
  + environment config
  ↓
kubectl kustomize
  ↓
rendered YAML
  ↓
kubectl apply -k
```

---

# 23. Create Kustomize Demo Base

Create folders:

```bash id="qddcb8"
mkdir -p 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base
mkdir -p 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/{dev,staging,production}
```

Create base Deployment:

```bash id="k27sw5"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base/deployment.yaml
```

Paste:

```yaml id="i21kn2"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-demo
  labels:
    app.kubernetes.io/name: kustomize-demo
    app.kubernetes.io/component: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kustomize-demo
      app.kubernetes.io/component: web
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kustomize-demo
        app.kubernetes.io/component: web
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: kustomize-demo-config
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: kustomize-demo-config
                  key: LOG_LEVEL
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
```

Create base Service:

```bash id="4uccy0"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base/service.yaml
```

Paste:

```yaml id="xfy10t"
apiVersion: v1
kind: Service
metadata:
  name: kustomize-demo
  labels:
    app.kubernetes.io/name: kustomize-demo
    app.kubernetes.io/component: web
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: kustomize-demo
    app.kubernetes.io/component: web
  ports:
    - name: http
      port: 80
      targetPort: http
```

Create base kustomization:

```bash id="k5lskz"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base/kustomization.yaml
```

Paste:

```yaml id="j5s1dl"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

Render base:

```bash id="gdr7fn"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base
```

---

# 24. Create Dev Overlay

Create:

```bash id="od0xgs"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev/kustomization.yaml
```

Paste:

```yaml id="l2qtdp"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

commonLabels:
  environment: dev

replicas:
  - name: kustomize-demo
    count: 1

images:
  - name: nginx
    newTag: 1.27-alpine

configMapGenerator:
  - name: kustomize-demo-config
    literals:
      - APP_ENV=dev
      - LOG_LEVEL=debug
```

Render:

```bash id="aj35h9"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev
```

Save rendered output:

```bash id="scmd2j"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev \
  > 10.13-helm-kustomize-release-packaging/reports/kustomize-demo-dev-rendered.yaml
```

Apply:

```bash id="czufbs"
kubectl apply -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev
```

Check:

```bash id="h51wsy"
kubectl get deploy,svc,configmap,pods -n dev -l app.kubernetes.io/name=kustomize-demo
kubectl rollout status deployment/kustomize-demo -n dev
```

Kustomize generators can create ConfigMaps and Secrets from literals, files, or env files; generated names may include a hash so changes create new generated objects. ([Kubernetes][9])

---

# 25. Create Staging Overlay

Create patch:

```bash id="eotw1s"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging/deployment-patch.yaml
```

Paste:

```yaml id="e37tf4"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-demo
spec:
  template:
    spec:
      containers:
        - name: web
          resources:
            requests:
              cpu: "75m"
              memory: "96Mi"
            limits:
              cpu: "300m"
              memory: "192Mi"
```

Create kustomization:

```bash id="fig64s"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging/kustomization.yaml
```

Paste:

```yaml id="2683nc"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging

resources:
  - ../../base

commonLabels:
  environment: staging

replicas:
  - name: kustomize-demo
    count: 2

images:
  - name: nginx
    newTag: 1.27-alpine

configMapGenerator:
  - name: kustomize-demo-config
    literals:
      - APP_ENV=staging
      - LOG_LEVEL=info

patches:
  - path: deployment-patch.yaml
```

Render:

```bash id="aqyvqo"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging \
  > 10.13-helm-kustomize-release-packaging/reports/kustomize-demo-staging-rendered.yaml
```

Optional apply:

```bash id="f522kk"
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging
```

---

# 26. Create Production Overlay

Create patch:

```bash id="0fmqrb"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production/deployment-patch.yaml
```

Paste:

```yaml id="z425du"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-demo
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
        - name: web
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
```

Create kustomization:

```bash id="poyfu4"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production/kustomization.yaml
```

Paste:

```yaml id="6ns1km"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
  - ../../base

commonLabels:
  environment: production

replicas:
  - name: kustomize-demo
    count: 3

images:
  - name: nginx
    newTag: 1.27-alpine

configMapGenerator:
  - name: kustomize-demo-config
    literals:
      - APP_ENV=production
      - LOG_LEVEL=warn

patches:
  - path: deployment-patch.yaml
```

Render:

```bash id="b1qjwe"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production \
  > 10.13-helm-kustomize-release-packaging/reports/kustomize-demo-production-rendered.yaml
```

Do not apply production unless intentionally practicing:

```bash id="plep7v"
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production
```

---

# 27. Kustomize Diff Before Apply

Before changing a live environment:

```bash id="2rte15"
kubectl diff -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev || true
```

Then apply:

```bash id="gvjl6m"
kubectl apply -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev
```

Production habit:

```text id="qjaq4o"
Render, diff, review, then apply.
```

---

# 28. Kustomize Secret Generator Warning

Create example only:

```bash id="8qqtch"
nano 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev/secret-generator-example.yaml
```

Paste:

```yaml id="v6x1ge"
# Example only. Do not commit real production secrets.
secretGenerator:
  - name: demo-secret
    literals:
      - API_TOKEN=replace-me
```

Do not include this file in the dev overlay.

Important:

```text id="srnq56"
Kustomize can generate Secrets, but plaintext secret values in Git are still plaintext secret values.
For real production, use SOPS, Sealed Secrets, External Secrets Operator, cloud secret manager, or GitOps-compatible encrypted secret flow.
```

Kubernetes docs show that Kustomize `secretGenerator` can generate Secrets from literals, files, or env files, and that modified Secret data creates a new generated Secret object with a changed name hash. ([Kubernetes][10])

---

# 29. Environment Promotion Model

The promotion rule should be:

```text id="kx9di2"
Build once.
Promote the same image tag through environments.
Change config separately.
```

Bad:

```text id="wrwe0x"
dev image built from commit A
staging image rebuilt from commit A but slightly different
production image rebuilt later with different base image
```

Good:

```text id="0rrvst"
CI builds:
  demo-node-api:1.4.2
  digest: sha256:abc...

dev deploys:
  demo-node-api:1.4.2

staging deploys:
  demo-node-api:1.4.2

production deploys:
  demo-node-api:1.4.2
```

Promotion pipeline:

```text id="y136k1"
commit
  ↓
build image
  ↓
scan image
  ↓
push image
  ↓
deploy to dev
  ↓
run smoke tests
  ↓
promote same image to staging
  ↓
run integration tests
  ↓
approval
  ↓
promote same image to production
```

---

# 30. Create Release Promotion Runbook

Create:

```bash id="1z164z"
nano 10.13-helm-kustomize-release-packaging/runbooks/release-promotion-runbook.md
```

Paste:

````markdown id="7au8a4"
# Kubernetes Release Promotion Runbook

## Goal

Promote the same tested image across environments.

## Rule

Build once. Promote many times.

## Flow

1. Build image.
2. Scan image.
3. Push immutable tag and digest.
4. Deploy to dev.
5. Run smoke tests.
6. Promote same image to staging.
7. Run integration tests.
8. Approve production release.
9. Promote same image to production.
10. Watch rollout and metrics.
11. Roll back if needed.

## Helm Promotion

```bash
helm upgrade --install demo-node-api ./chart \
  -n dev \
  -f values-dev.yaml \
  --set image.tag=1.4.2
````

```bash
helm upgrade --install demo-node-api ./chart \
  -n staging \
  -f values-staging.yaml \
  --set image.tag=1.4.2
```

```bash
helm upgrade --install demo-node-api ./chart \
  -n production \
  -f values-production.yaml \
  --set image.tag=1.4.2 \
  --atomic \
  --timeout 5m
```

## Kustomize Promotion

Update overlay image tag:

```yaml
images:
  - name: demo-node-api
    newTag: 1.4.2
```

Then:

```bash
kubectl diff -k overlays/production
kubectl apply -k overlays/production
```

## Golden Rule

Do not rebuild between environments.
Promote the same artifact.

````

---

# 31. Create Helm vs Kustomize Notes

Create:

```bash id="s43h87"
nano 10.13-helm-kustomize-release-packaging/notes/helm-vs-kustomize.md
````

Paste:

```markdown id="o8f9qf"
# Helm vs Kustomize

## Helm

Best when:

- packaging reusable applications
- publishing charts
- many configurable values
- third-party apps
- install/upgrade/rollback release lifecycle needed
- teams want a package abstraction

Tradeoffs:

- templating complexity
- rendered YAML must be reviewed
- bad templates can be hard to debug
- chart values can become too flexible

## Kustomize

Best when:

- you want plain YAML
- environment overlays are enough
- GitOps workflows need simple diffs
- patching base manifests
- avoiding template language

Tradeoffs:

- less package-like than Helm
- complex conditionals are awkward
- large overlays can become hard to follow

## Practical Rule

Use Kustomize for simple app overlays and GitOps-friendly environment differences.

Use Helm for reusable packages, third-party charts, and release lifecycle management.

Many teams use both:
Helm for package rendering, Kustomize for final environment overlays.
```

---

# 32. Package `demo-node-api` with Kustomize

Your existing app base is here:

```text id="js9gm7"
apps/demo-node-api/base
```

It already contains files built across previous lessons:

```text id="ix1a1g"
deployment.yaml
service.yaml
ingress.yaml
configmap.yaml
serviceaccount.yaml
secret.example.yaml
service-nodeport-dev.yaml
```

Create base kustomization:

```bash id="50scjj"
nano apps/demo-node-api/base/kustomization.yaml
```

Paste:

```yaml id="d1414j"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

Create overlays:

```bash id="66uexd"
mkdir -p apps/demo-node-api/overlays/{dev,staging,production}
```

Create dev overlay:

```bash id="6okp6k"
nano apps/demo-node-api/overlays/dev/kustomization.yaml
```

Paste:

```yaml id="3mqsd2"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

commonLabels:
  environment: dev

replicas:
  - name: demo-node-api
    count: 1

images:
  - name: demo-node-api
    newTag: 0.1.0
```

Create staging patch:

```bash id="6fklqa"
nano apps/demo-node-api/overlays/staging/deployment-patch.yaml
```

Paste:

```yaml id="1zc10g"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 2
  template:
    metadata:
      labels:
        environment: staging
    spec:
      containers:
        - name: demo-node-api
          resources:
            requests:
              cpu: "150m"
              memory: "192Mi"
            limits:
              cpu: "750m"
              memory: "768Mi"
```

Create staging overlay:

```bash id="fjf2rb"
nano apps/demo-node-api/overlays/staging/kustomization.yaml
```

Paste:

```yaml id="se2oj8"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging

resources:
  - ../../base

commonLabels:
  environment: staging

replicas:
  - name: demo-node-api
    count: 2

images:
  - name: demo-node-api
    newTag: 0.1.0

patches:
  - path: deployment-patch.yaml
```

Create production patch:

```bash id="ltjy1w"
nano apps/demo-node-api/overlays/production/deployment-patch.yaml
```

Paste:

```yaml id="584ssq"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        environment: production
    spec:
      containers:
        - name: demo-node-api
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
```

Create production ingress patch:

```bash id="dkyajg"
nano apps/demo-node-api/overlays/production/ingress-patch.yaml
```

Paste:

```yaml id="hg8smw"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
spec:
  rules:
    - host: api.yourdatascientist.tech
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo-node-api
                port:
                  number: 80
```

Create production overlay:

```bash id="u3nbai"
nano apps/demo-node-api/overlays/production/kustomization.yaml
```

Paste:

```yaml id="quepvx"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
  - ../../base

commonLabels:
  environment: production

replicas:
  - name: demo-node-api
    count: 3

images:
  - name: demo-node-api
    newTag: 0.1.0

patches:
  - path: deployment-patch.yaml
  - path: ingress-patch.yaml
```

Render:

```bash id="rrm22a"
kubectl kustomize apps/demo-node-api/overlays/dev \
  > 10.13-helm-kustomize-release-packaging/reports/demo-node-api-dev-rendered.yaml

kubectl kustomize apps/demo-node-api/overlays/staging \
  > 10.13-helm-kustomize-release-packaging/reports/demo-node-api-staging-rendered.yaml

kubectl kustomize apps/demo-node-api/overlays/production \
  > 10.13-helm-kustomize-release-packaging/reports/demo-node-api-production-rendered.yaml
```

Do not apply until:

```text id="qaxkwq"
demo-node-api image exists in the cluster or registry
demo-node-api-secret exists in target namespace
MongoDB dependency exists
Ingress controller exists
```

---

# 33. Create Helm Packaging Pattern for `demo-node-api`

Create chart folder:

```bash id="akjrko"
mkdir -p apps/demo-node-api/chart/templates
```

Create:

```bash id="w1frb5"
nano apps/demo-node-api/chart/Chart.yaml
```

Paste:

```yaml id="m07bt3"
apiVersion: v2
name: demo-node-api
description: Helm chart for demo-node-api backend
type: application
version: 0.1.0
appVersion: "0.1.0"
```

Create:

```bash id="l42p7a"
nano apps/demo-node-api/chart/values.yaml
```

Paste:

```yaml id="cnwlt2"
replicaCount: 1

image:
  repository: demo-node-api
  tag: "0.1.0"
  pullPolicy: IfNotPresent

serviceAccount:
  create: true
  automount: false

service:
  type: ClusterIP
  port: 80
  targetPort: 3002

ingress:
  enabled: true
  className: nginx
  host: api.localdev.me
  path: /

config:
  NODE_ENV: production
  APP_PORT: "3002"
  LOG_LEVEL: info
  API_VERSION: v1
  CORS_ORIGIN: http://localhost:3000

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

For now, keep this as a chart skeleton. In a later capstone, we can fully convert your base manifests into Helm templates.

Render skeleton after adding templates later:

```bash id="7v8jti"
helm lint apps/demo-node-api/chart || true
helm template demo-node-api apps/demo-node-api/chart -n dev || true
```

---

# 34. Helm vs Kustomize Decision Table

| Need                             | Better Tool |
| -------------------------------- | ----------- |
| Simple env overlays              | Kustomize   |
| Keep YAML plain                  | Kustomize   |
| Patch base manifests             | Kustomize   |
| GitOps-friendly overlays         | Kustomize   |
| Package reusable app             | Helm        |
| Third-party apps                 | Helm        |
| Versioned release lifecycle      | Helm        |
| Install/upgrade/rollback history | Helm        |
| Many user-configurable settings  | Helm        |
| Complex templated chart          | Helm        |

Practical DevOps answer:

```text id="vuzgs6"
Use Kustomize when you own the YAML and need clean environment overlays.

Use Helm when you need a reusable, versioned, configurable application package.

Use both when Helm renders a package and Kustomize applies final organization-specific overlays.
```

---

# 35. Common Mistakes

## Mistake 1: Editing production YAML manually

Bad:

```text id="4x30nx"
kubectl edit deployment production-api
```

Better:

```text id="6u37zz"
change Git
render
diff
apply through pipeline
```

---

## Mistake 2: Rebuilding images between environments

Bad:

```text id="nkh241"
build dev image
build staging image
build production image
```

Better:

```text id="g46d6w"
build once
promote same digest
```

---

## Mistake 3: Putting real Secrets in Helm values

Bad:

```yaml id="ghuuan"
databasePassword: "prod-password"
```

Better:

```text id="cbmaam"
external secret manager
encrypted secrets
CI/CD secret injection
External Secrets Operator
SOPS
Sealed Secrets
```

---

## Mistake 4: Helm values become a programming language

Bad:

```text id="2v9hyo"
hundreds of values
deep conditionals
unreadable templates
```

Better:

```text id="6grh88"
sensible defaults
small values surface
documented values
rendered output reviewed
```

---

## Mistake 5: Kustomize overlays become copy-paste folders

Bad:

```text id="dzg8w3"
overlays contain full duplicate deployment.yaml
```

Better:

```text id="0qg2hk"
base contains full resource
overlays contain only patches
```

---

# 36. Create Packaging Runbook

Create:

```bash id="jc9e6y"
nano 10.13-helm-kustomize-release-packaging/runbooks/packaging-debugging-runbook.md
```

Paste:

````markdown id="lpltst"
# Helm and Kustomize Debugging Runbook

## Helm Debugging

Render:

```bash
helm template RELEASE CHART -n NAMESPACE -f values.yaml
````

Lint:

```bash
helm lint CHART
```

Install or upgrade:

```bash
helm upgrade --install RELEASE CHART -n NAMESPACE -f values.yaml --atomic --timeout 5m
```

History:

```bash
helm history RELEASE -n NAMESPACE
```

Rollback:

```bash
helm rollback RELEASE REVISION -n NAMESPACE
```

Common Helm issues:

| Symptom            | Likely Cause                     |
| ------------------ | -------------------------------- |
| template error     | bad template syntax              |
| install failed     | rendered YAML invalid            |
| upgrade failed     | immutable field or rollout issue |
| wrong config       | values file precedence           |
| rollback confusing | wrong revision selected          |

## Kustomize Debugging

Render:

```bash
kubectl kustomize overlays/dev
```

Diff:

```bash
kubectl diff -k overlays/dev
```

Apply:

```bash
kubectl apply -k overlays/dev
```

Common Kustomize issues:

| Symptom                | Likely Cause                  |
| ---------------------- | ----------------------------- |
| patch not applied      | name/kind mismatch            |
| wrong namespace        | namespace field override      |
| generated name changed | ConfigMap/Secret hash changed |
| app not restarted      | Pod template did not change   |
| wrong image            | image transformer mismatch    |

## Golden Rule

Always inspect rendered YAML before applying.

````

---

# 37. Create Validation Script

Create:

```bash id="61nv19"
nano 10.13-helm-kustomize-release-packaging/scripts/validate-lesson-10-13.sh
````

Paste:

```bash id="6fid0v"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.13 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

helm version >/dev/null

helm lint 10.13-helm-kustomize-release-packaging/helm/helm-demo >/dev/null

helm template helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml \
  >/tmp/helm-demo-rendered.yaml

grep -q "kind: Deployment" /tmp/helm-demo-rendered.yaml
grep -q "kind: Service" /tmp/helm-demo-rendered.yaml
grep -q "kind: ConfigMap" /tmp/helm-demo-rendered.yaml

kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev \
  >/tmp/kustomize-demo-dev-rendered.yaml

grep -q "kind: Deployment" /tmp/kustomize-demo-dev-rendered.yaml
grep -q "kind: Service" /tmp/kustomize-demo-dev-rendered.yaml
grep -q "kind: ConfigMap" /tmp/kustomize-demo-dev-rendered.yaml
grep -q "namespace: dev" /tmp/kustomize-demo-dev-rendered.yaml

kubectl get deployment kustomize-demo -n dev >/dev/null
kubectl get service kustomize-demo -n dev >/dev/null

helm list -n dev | grep -q "helm-demo"

kubectl get deployment helm-demo-helm-demo -n dev >/dev/null
kubectl get service helm-demo-helm-demo -n dev >/dev/null

test -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/Chart.yaml
test -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values.yaml
test -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml
test -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-staging.yaml
test -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-production.yaml

test -f 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/base/kustomization.yaml
test -f 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev/kustomization.yaml
test -f 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging/kustomization.yaml
test -f 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production/kustomization.yaml

test -f apps/demo-node-api/base/kustomization.yaml
test -f apps/demo-node-api/overlays/dev/kustomization.yaml
test -f apps/demo-node-api/overlays/staging/kustomization.yaml
test -f apps/demo-node-api/overlays/production/kustomization.yaml

kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-dev-rendered.yaml
grep -q "kind: Deployment" /tmp/demo-node-api-dev-rendered.yaml
grep -q "kind: Service" /tmp/demo-node-api-dev-rendered.yaml
grep -q "kind: Ingress" /tmp/demo-node-api-dev-rendered.yaml

test -f 10.13-helm-kustomize-release-packaging/notes/helm-vs-kustomize.md
test -f 10.13-helm-kustomize-release-packaging/runbooks/release-promotion-runbook.md
test -f 10.13-helm-kustomize-release-packaging/runbooks/packaging-debugging-runbook.md

echo "Lesson 10.13 validation passed."
```

Make executable:

```bash id="4x4f0m"
chmod +x 10.13-helm-kustomize-release-packaging/scripts/validate-lesson-10-13.sh
```

Run:

```bash id="zrxp1u"
./10.13-helm-kustomize-release-packaging/scripts/validate-lesson-10-13.sh
```

---

# 38. Create Cleanup Script

Create:

```bash id="4qzrvh"
nano 10.13-helm-kustomize-release-packaging/scripts/cleanup-lesson-10-13.sh
```

Paste:

```bash id="1ov5sp"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.13 ====="

helm uninstall helm-demo -n dev || true

kubectl delete -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev --ignore-not-found=true
kubectl delete -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/staging --ignore-not-found=true
kubectl delete -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/production --ignore-not-found=true

echo "Lesson 10.13 live resources cleaned."
echo "Files are kept for Git and future lessons."
```

Make executable:

```bash id="czw0w0"
chmod +x 10.13-helm-kustomize-release-packaging/scripts/cleanup-lesson-10-13.sh
```

Run only if you want cleanup:

```bash id="0hx351"
./10.13-helm-kustomize-release-packaging/scripts/cleanup-lesson-10-13.sh
```

---

# 39. Practical Lab Summary

Run the main Helm lab:

```bash id="l463kx"
cd ~/devops-masterclass/10-kubernetes-production-operations

helm lint 10.13-helm-kustomize-release-packaging/helm/helm-demo

helm template helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml

helm install helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml

helm upgrade helm-demo \
  10.13-helm-kustomize-release-packaging/helm/helm-demo \
  -n dev \
  -f 10.13-helm-kustomize-release-packaging/helm/helm-demo/values-dev.yaml \
  --set replicaCount=2

helm history helm-demo -n dev
helm rollback helm-demo 1 -n dev
```

Run the main Kustomize lab:

```bash id="p9bohs"
kubectl kustomize 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev

kubectl apply -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev

kubectl get deploy,svc,pods -n dev -l app.kubernetes.io/name=kustomize-demo

kubectl diff -k 10.13-helm-kustomize-release-packaging/kustomize/kustomize-demo/overlays/dev || true
```

Validate:

```bash id="dph68h"
./10.13-helm-kustomize-release-packaging/scripts/validate-lesson-10-13.sh
```

---

# 40. Production Rules

```text id="egz5qd"
Do not copy-paste full YAML across environments.
Use base plus overlays.
Use immutable image tags or digests.
Build once and promote the same artifact.
Render Helm charts before installing.
Run helm lint in CI.
Use helm upgrade --install for idempotent deploys.
Use --atomic and timeout for safer Helm upgrades.
Use helm history and rollback for emergency recovery.
Use kubectl kustomize to inspect overlays.
Use kubectl diff before kubectl apply.
Do not store plaintext production secrets in values.yaml or kustomization.yaml.
Keep overlays small and readable.
Document every production value.
```

---

# 41. Interview Explanation

Use this:

```text id="q029bi"
Helm and Kustomize solve the problem of managing Kubernetes manifests across environments. Helm packages Kubernetes applications into charts with templates and values files, then manages installed releases with install, upgrade, history, and rollback commands. I use Helm when I need reusable, versioned application packages or third-party charts.

Kustomize uses plain Kubernetes YAML with bases and overlays. A base contains common resources, while overlays apply environment-specific changes such as replicas, image tags, labels, ConfigMaps, and patches. I use Kustomize when I want GitOps-friendly, template-free environment customization.

In production, I render and review manifests before applying, promote the same image across dev, staging, and production, avoid plaintext secrets in Git, and use diff, linting, and rollback workflows for safer releases.
```

Resume version:

```text id="nrghrx"
Implemented Kubernetes release packaging with Helm and Kustomize, including Helm charts, values files, templated Deployments/Services/Ingress, install/upgrade/rollback workflows, Kustomize bases and overlays, environment promotion, rendered manifest reports, and production packaging strategy for demo-node-api.
```

---

# 42. Today’s Core Rules

```text id="nqgmdf"
Helm packages Kubernetes apps as charts.
Helm values customize templates.
A Helm release is an installed chart instance.
helm template renders YAML locally.
helm lint checks chart quality.
helm upgrade changes an existing release.
helm rollback returns to a previous revision.
Kustomize customizes plain YAML.
A base contains common manifests.
An overlay contains environment-specific changes.
configMapGenerator creates ConfigMaps.
secretGenerator creates Secrets, but does not solve secret security by itself.
Build once, promote the same image.
Render before deploy.
Diff before apply.
Do not store real plaintext production secrets in Git.
```

---

# 43. Commit Lesson 10.13

From repo root:

```bash id="2z1ufw"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes Helm Kustomize and release packaging lesson"

git push
```

---

# Next Lesson

```text id="5xe305"
Lesson 10.14 — Autoscaling: HPA, VPA Concepts, Cluster Autoscaler, PDBs, and Safe Scaling
```

We will cover:

```text id="fubbea"
HorizontalPodAutoscaler
metrics-server dependency
CPU-based scaling
memory-based scaling
custom metrics concept
VerticalPodAutoscaler concepts
Cluster Autoscaler concepts
PodDisruptionBudget
safe scale up
safe scale down
autoscaling failure modes
production autoscaling policy for demo-node-api
```

[1]: https://helm.sh/?utm_source=chatgpt.com "Helm"
[2]: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/ "Declarative Management of Kubernetes Objects Using Configuration Files | Kubernetes"
[3]: https://helm.sh/docs/helm/helm_install/?utm_source=chatgpt.com "helm install"
[4]: https://helm.sh/docs/intro/install/?utm_source=chatgpt.com "Installing Helm"
[5]: https://helm.sh/docs/topics/charts "Charts | Helm"
[6]: https://helm.sh/docs/topics/charts/?utm_source=chatgpt.com "Charts"
[7]: https://helm.sh/docs/helm/helm_upgrade/ "helm upgrade | Helm"
[8]: https://helm.sh/docs/helm/helm_rollback/?utm_source=chatgpt.com "helm rollback"
[9]: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/ "Declarative Management of Kubernetes Objects Using Kustomize | Kubernetes"
[10]: https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kustomize/ "Managing Secrets using Kustomize | Kubernetes"
