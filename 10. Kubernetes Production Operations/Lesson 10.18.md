# Lesson 10.18 — Module 10 Capstone: Production-Grade Kubernetes Deployment for `demo-node-api`

This is the final capstone for **Module 10 — Kubernetes Production Operations**.

We will combine everything from Lessons 10.1 to 10.17 into one production-style Kubernetes package:

```text id="y6vh61"
Deployment
Service
Ingress
ConfigMap
Secret example
ServiceAccount
probes
resources
securityContext
HPA
PDB
NetworkPolicy
Kustomize overlays
ArgoCD Application
observability hooks
validation script
cleanup script
runbooks
resume-ready summary
```

The goal is not only to “run a container.” The goal is to create a **portfolio-ready Kubernetes deployment structure** that looks like real DevOps work.

Kubernetes Deployments manage rollout and replica lifecycle, Services provide stable networking, NetworkPolicies restrict Pod traffic, HPAs adjust replica count through the scale subresource, PDBs protect availability during voluntary disruptions, and ArgoCD reconciles live cluster state from Git desired state. ([Kubernetes][1])

---

# 1. Capstone Goal

By the end, you will have:

```text id="v9em0b"
A complete Kubernetes production deployment package for demo-node-api.

A dev overlay that can run locally on kind.

A staging overlay for pre-production testing.

A production overlay with stronger defaults.

A GitOps-ready ArgoCD Application.

Validation and cleanup scripts.

Runbooks for operations, troubleshooting, rollback, and release.
```

Resume-ready outcome:

```text id="oi3xdo"
Built a production-grade Kubernetes deployment package for a Node.js API using Kustomize overlays, probes, resources, HPA, PDB, NetworkPolicy, ServiceAccount hardening, securityContext, Ingress, observability hooks, ArgoCD GitOps manifests, validation automation, and operational runbooks.
```

---

# 2. Architecture

```text id="z418r8"
User / curl / browser
        ↓
Ingress Controller
        ↓
Ingress: api.localdev.me
        ↓
Service: demo-node-api
        ↓
Deployment: demo-node-api Pods
        ↓
Container: Node.js API on port 3002
        ↓
MongoDB dependency / external DB / lab DB
```

Production control layers:

```text id="hlf85c"
Config:
  ConfigMap + Secret reference

Availability:
  replicas + readinessProbe + livenessProbe + startupProbe + PDB

Scaling:
  HPA

Security:
  ServiceAccount
  automountServiceAccountToken: false
  securityContext
  NetworkPolicy
  non-root container
  read-only root filesystem

Release:
  Kustomize overlays
  ArgoCD Application
```

---

# 3. Prerequisites

You should already have:

```bash id="r85x29"
kubectl version --client
kind version
docker version
helm version
```

Cluster:

```bash id="g855s3"
kubectl config current-context
kubectl get nodes
kubectl get namespace dev
```

If `dev` does not exist:

```bash id="q8bese"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
```

Optional but recommended:

```bash id="lu4r5j"
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods -n dev
```

If metrics-server is missing, install it:

```bash id="egntor"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--kubelet-insecure-tls"
    }
  ]' || true

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
```

---

# 4. Create Capstone Folder

```bash id="y0rxqu"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.18-module-10-capstone/{scripts,runbooks,notes,reports,argocd}
mkdir -p apps/demo-node-api/base
mkdir -p apps/demo-node-api/overlays/{dev,staging,production}
mkdir -p apps/demo-node-api/optional/monitoring
```

Check:

```bash id="d8rjup"
tree -L 3 apps/demo-node-api
tree -L 2 10.18-module-10-capstone
```

---

# 5. Important Capstone Design Decision

Earlier lessons added many resources directly into `apps/demo-node-api/base`.

For capstone quality, we will keep the base clean and stable:

```text id="4bfvxi"
Base:
  resources required for the app to run

Optional:
  ServiceMonitor and monitoring-specific CRDs
```

Why?

```text id="odlqkh"
If ServiceMonitor CRD is missing, kubectl apply can fail.
The base app should run even without Prometheus Operator.
Monitoring integration should be optional.
```

This is a real production pattern:

```text id="pqkb41"
Core app manifests should not depend on optional platform CRDs unless the platform guarantees them.
```

---

# 6. Create Base ServiceAccount

```bash id="aqhn3b"
nano apps/demo-node-api/base/serviceaccount.yaml
```

Paste:

```yaml id="y6xjjo"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
automountServiceAccountToken: false
```

Why:

```text id="zxppaw"
The app does not need Kubernetes API access.
So it should not automatically receive a ServiceAccount token.
```

---

# 7. Create Base ConfigMap

```bash id="sd32ux"
nano apps/demo-node-api/base/configmap.yaml
```

Paste:

```yaml id="fbx0w8"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-node-api-config
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
data:
  NODE_ENV: "production"
  APP_PORT: "3002"
  LOG_LEVEL: "info"
  API_VERSION: "v1"
  CORS_ORIGIN: "http://localhost:3000"
```

---

# 8. Create Secret Example

Do **not** commit real production secrets.

```bash id="vpk7lh"
nano apps/demo-node-api/base/secret.example.yaml
```

Paste:

```yaml id="tocq8r"
apiVersion: v1
kind: Secret
metadata:
  name: demo-node-api-secret
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
type: Opaque
stringData:
  MONGO_URI: "mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo"
  JWT_SECRET: "replace-me"
```

Create local secret for dev:

```bash id="c47z49"
kubectl create secret generic demo-node-api-secret \
  -n dev \
  --from-literal=MONGO_URI='mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo' \
  --from-literal=JWT_SECRET='local-dev-jwt-secret' \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Add generated/local secret files to `.gitignore`:

```bash id="m0mw1p"
cd ~/devops-masterclass

grep -q "secret.local.generated.yaml" .gitignore || cat >> .gitignore <<'EOF'

# Local generated Kubernetes secrets
**/secret.local.generated.yaml
EOF
```

---

# 9. Create Base Deployment

```bash id="tt883x"
nano apps/demo-node-api/base/deployment.yaml
```

Paste:

```yaml id="y9h1kr"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  replicas: 2
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: demo-node-api
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: todo-app
      annotations:
        kubernetes.io/change-cause: "Module 10 capstone production deployment"
        prometheus.io/scrape: "true"
        prometheus.io/path: "/metrics"
        prometheus.io/port: "3002"
    spec:
      serviceAccountName: demo-node-api
      automountServiceAccountToken: false

      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault

      terminationGracePeriodSeconds: 30

      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 80
              preference:
                matchExpressions:
                  - key: node-role
                    operator: In
                    values:
                      - app
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: demo-node-api
                    app.kubernetes.io/component: backend
                topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: demo-node-api
              app.kubernetes.io/component: backend

      containers:
        - name: demo-node-api
          image: demo-node-api:0.1.0
          imagePullPolicy: IfNotPresent

          ports:
            - name: http
              containerPort: 3002

          env:
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: NODE_ENV
            - name: PORT
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: APP_PORT
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: LOG_LEVEL
            - name: API_VERSION
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: API_VERSION
            - name: CORS_ORIGIN
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: CORS_ORIGIN
            - name: MONGO_URI
              valueFrom:
                secretKeyRef:
                  name: demo-node-api-secret
                  key: MONGO_URI
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: demo-node-api-secret
                  key: JWT_SECRET

          startupProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 30

          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
            successThreshold: 1

          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3

          lifecycle:
            preStop:
              exec:
                command:
                  - sh
                  - -c
                  - "sleep 10"

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"

          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

This Deployment includes rollout strategy, probes, resources, non-root execution, dropped capabilities, read-only root filesystem, graceful shutdown support, anti-affinity, topology spread, and config/secret injection. Kubernetes security contexts define privilege and access-control settings for Pods and containers, and Pod Security Standards describe `restricted` as the profile aimed at current Pod hardening best practices. ([Kubernetes][2])

---

# 10. Create Service

```bash id="ymrvwb"
nano apps/demo-node-api/base/service.yaml
```

Paste:

```yaml id="n5au5k"
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
  ports:
    - name: http
      port: 80
      targetPort: http
```

---

# 11. Create Ingress

```bash id="kwd0ji"
nano apps/demo-node-api/base/ingress.yaml
```

Paste:

```yaml id="1erhcu"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: api.localdev.me
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

---

# 12. Create HPA

```bash id="rhz7hb"
nano apps/demo-node-api/base/hpa.yaml
```

Paste:

```yaml id="cqpl32"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-node-api
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
      selectPolicy: Max
```

HPA `autoscaling/v2` automatically manages replica count for resources that implement the scale subresource, such as Deployments. ([Kubernetes][3])

---

# 13. Create PDB

```bash id="sy88bd"
nano apps/demo-node-api/base/pdb.yaml
```

Paste:

```yaml id="7vxy5b"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
```

A PDB limits concurrent voluntary disruptions so an app can remain available during maintenance operations such as node drains. ([Kubernetes][4])

---

# 14. Create NetworkPolicy

```bash id="ak6uso"
nano apps/demo-node-api/base/networkpolicy.yaml
```

Paste:

```yaml id="5qxy8k"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-default-deny
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-allow-ingress
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3002
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: demo-node-api
      ports:
        - protocol: TCP
          port: 3002
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-allow-dns-egress
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

NetworkPolicies define how selected Pods are allowed to communicate with other network endpoints, but enforcement requires a CNI/plugin that supports NetworkPolicy. ([Kubernetes][1])

---

# 15. Create Base Kustomization

```bash id="a2zete"
nano apps/demo-node-api/base/kustomization.yaml
```

Paste:

```yaml id="qhud6l"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
  - networkpolicy.yaml

commonLabels:
  app.kubernetes.io/managed-by: kustomize
```

Kustomize lets you use a base plus overlays to customize Kubernetes manifests without a separate template language. ([Kubernetes][5])

---

# 16. Optional ServiceMonitor

Create optional monitoring integration:

```bash id="jv3kia"
nano apps/demo-node-api/optional/monitoring/servicemonitor.yaml
```

Paste:

```yaml id="dukesm"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: demo-node-api
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  namespaceSelector:
    matchNames:
      - dev
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

Create optional kustomization:

```bash id="mv772k"
nano apps/demo-node-api/optional/monitoring/kustomization.yaml
```

Paste:

```yaml id="1gkfqr"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - servicemonitor.yaml
```

Apply only if CRD exists:

```bash id="z2yyk7"
kubectl get crd servicemonitors.monitoring.coreos.com

kubectl apply -k apps/demo-node-api/optional/monitoring -n dev
```

---

# 17. Create Dev Overlay

```bash id="bxft7k"
nano apps/demo-node-api/overlays/dev/kustomization.yaml
```

Paste:

```yaml id="lprrsv"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

commonLabels:
  environment: dev

replicas:
  - name: demo-node-api
    count: 2

images:
  - name: demo-node-api
    newTag: 0.1.0

patches:
  - path: configmap-patch.yaml
  - path: ingress-patch.yaml
```

Create config patch:

```bash id="nkv78t"
nano apps/demo-node-api/overlays/dev/configmap-patch.yaml
```

Paste:

```yaml id="09pjry"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-node-api-config
data:
  NODE_ENV: "production"
  APP_PORT: "3002"
  LOG_LEVEL: "debug"
  API_VERSION: "v1"
  CORS_ORIGIN: "http://localhost:3000"
```

Create ingress patch:

```bash id="t789mq"
nano apps/demo-node-api/overlays/dev/ingress-patch.yaml
```

Paste:

```yaml id="n6l8vs"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
spec:
  rules:
    - host: api.localdev.me
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

---

# 18. Create Staging Overlay

```bash id="xryolw"
nano apps/demo-node-api/overlays/staging/kustomization.yaml
```

Paste:

```yaml id="o3n3c4"
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
  - path: configmap-patch.yaml
  - path: deployment-patch.yaml
  - path: ingress-patch.yaml
```

```bash id="0wbs43"
nano apps/demo-node-api/overlays/staging/configmap-patch.yaml
```

Paste:

```yaml id="zgzjbg"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-node-api-config
data:
  NODE_ENV: "production"
  APP_PORT: "3002"
  LOG_LEVEL: "info"
  API_VERSION: "v1"
  CORS_ORIGIN: "https://frontend-staging.example.com"
```

```bash id="p6kp2x"
nano apps/demo-node-api/overlays/staging/deployment-patch.yaml
```

Paste:

```yaml id="4eb74d"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  template:
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

```bash id="peci53"
nano apps/demo-node-api/overlays/staging/ingress-patch.yaml
```

Paste:

```yaml id="nkcwnr"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
spec:
  rules:
    - host: api-staging.localdev.me
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

---

# 19. Create Production Overlay

```bash id="zbhq6v"
nano apps/demo-node-api/overlays/production/kustomization.yaml
```

Paste:

```yaml id="tji8wb"
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
  - path: configmap-patch.yaml
  - path: deployment-patch.yaml
  - path: ingress-patch.yaml
  - path: hpa-patch.yaml
  - path: pdb-patch.yaml
```

```bash id="5ao8kk"
nano apps/demo-node-api/overlays/production/configmap-patch.yaml
```

Paste:

```yaml id="6z1vxg"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-node-api-config
data:
  NODE_ENV: "production"
  APP_PORT: "3002"
  LOG_LEVEL: "warn"
  API_VERSION: "v1"
  CORS_ORIGIN: "https://yourdatascientist.tech"
```

```bash id="jdyiqg"
nano apps/demo-node-api/overlays/production/deployment-patch.yaml
```

Paste:

```yaml id="lyxjpe"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 3
  template:
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

```bash id="dz65kz"
nano apps/demo-node-api/overlays/production/ingress-patch.yaml
```

Paste:

```yaml id="xgou9l"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
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

```bash id="gj8fta"
nano apps/demo-node-api/overlays/production/hpa-patch.yaml
```

Paste:

```yaml id="s8d1fw"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-node-api
spec:
  minReplicas: 3
  maxReplicas: 10
```

```bash id="ofp8r7"
nano apps/demo-node-api/overlays/production/pdb-patch.yaml
```

Paste:

```yaml id="73zngm"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: demo-node-api
spec:
  minAvailable: 2
```

---

# 20. Render All Overlays

```bash id="bpfsns"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl kustomize apps/demo-node-api/overlays/dev \
  > 10.18-module-10-capstone/reports/demo-node-api-dev-rendered.yaml

kubectl kustomize apps/demo-node-api/overlays/staging \
  > 10.18-module-10-capstone/reports/demo-node-api-staging-rendered.yaml

kubectl kustomize apps/demo-node-api/overlays/production \
  > 10.18-module-10-capstone/reports/demo-node-api-production-rendered.yaml
```

Check rendered objects:

```bash id="fu1itz"
grep '^kind:' 10.18-module-10-capstone/reports/demo-node-api-dev-rendered.yaml

grep '^kind:' 10.18-module-10-capstone/reports/demo-node-api-production-rendered.yaml
```

Expected kinds:

```text id="dlc9br"
ServiceAccount
ConfigMap
Deployment
Service
Ingress
HorizontalPodAutoscaler
PodDisruptionBudget
NetworkPolicy
NetworkPolicy
NetworkPolicy
```

---

# 21. Build and Load Image into kind

If you already have a working `demo-node-api:0.1.0` image, skip to the next section.

If your image does not exist, build it from your Node app directory.

Example if app source exists at:

```text id="ua1o7z"
~/devops-masterclass/05-application-runtime/demo-node-api
```

Run:

```bash id="h625wt"
cd ~/devops-masterclass/05-application-runtime/demo-node-api

docker build -t demo-node-api:0.1.0 .
```

Load into kind:

```bash id="sa7zo9"
kind load docker-image demo-node-api:0.1.0 --name devops-k8s
```

Check image on nodes:

```bash id="cx8jwq"
docker exec devops-k8s-worker crictl images | grep demo-node-api || true
docker exec devops-k8s-worker2 crictl images | grep demo-node-api || true
```

If your kind cluster name is different:

```bash id="s6d80g"
kind get clusters
```

Then use:

```bash id="i9jts7"
kind load docker-image demo-node-api:0.1.0 --name YOUR_CLUSTER_NAME
```

---

# 22. Apply Dev Capstone

Create namespace:

```bash id="nng46x"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
```

Apply local secret:

```bash id="a6d4m5"
kubectl create secret generic demo-node-api-secret \
  -n dev \
  --from-literal=MONGO_URI='mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo' \
  --from-literal=JWT_SECRET='local-dev-jwt-secret' \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Apply overlay:

```bash id="mnjsg4"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -k apps/demo-node-api/overlays/dev
```

Check rollout:

```bash id="swbhkf"
kubectl rollout status deployment/demo-node-api -n dev --timeout=180s

kubectl get deploy,svc,ingress,hpa,pdb,networkpolicy -n dev \
  -l app.kubernetes.io/name=demo-node-api

kubectl get pods -n dev \
  -l app.kubernetes.io/name=demo-node-api \
  -o wide
```

---

# 23. Validate App Locally

Port-forward:

```bash id="i1vysp"
kubectl port-forward -n dev svc/demo-node-api 3002:80
```

In another terminal:

```bash id="bm2rxm"
curl -i http://127.0.0.1:3002/health
curl -i http://127.0.0.1:3002/ready
curl -i http://127.0.0.1:3002/version || true
curl -i http://127.0.0.1:3002/config-summary || true
```

Stop port-forward:

```text id="g3fset"
Ctrl + C
```

If Ingress Controller is running:

```bash id="plhz83"
kubectl get pods -n ingress-nginx
```

Port-forward ingress controller:

```bash id="hbj7qk"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

Test:

```bash id="hkp631"
curl -H "Host: api.localdev.me" http://127.0.0.1:8080/health
```

---

# 24. Create Capstone Validation Script

```bash id="spra5q"
nano 10.18-module-10-capstone/scripts/validate-module-10-capstone.sh
```

Paste:

```bash id="ju2gje"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP="demo-node-api"

echo "===== Validate Module 10 Capstone ====="
echo "Namespace: $NAMESPACE"
echo "App: $APP"

kubectl version --client >/dev/null
kubectl get namespace "$NAMESPACE" >/dev/null

echo
echo "Checking required files..."
test -f apps/demo-node-api/base/serviceaccount.yaml
test -f apps/demo-node-api/base/configmap.yaml
test -f apps/demo-node-api/base/secret.example.yaml
test -f apps/demo-node-api/base/deployment.yaml
test -f apps/demo-node-api/base/service.yaml
test -f apps/demo-node-api/base/ingress.yaml
test -f apps/demo-node-api/base/hpa.yaml
test -f apps/demo-node-api/base/pdb.yaml
test -f apps/demo-node-api/base/networkpolicy.yaml
test -f apps/demo-node-api/base/kustomization.yaml

test -f apps/demo-node-api/overlays/dev/kustomization.yaml
test -f apps/demo-node-api/overlays/staging/kustomization.yaml
test -f apps/demo-node-api/overlays/production/kustomization.yaml

echo
echo "Rendering overlays..."
kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-dev.yaml
kubectl kustomize apps/demo-node-api/overlays/staging >/tmp/demo-node-api-staging.yaml
kubectl kustomize apps/demo-node-api/overlays/production >/tmp/demo-node-api-production.yaml

grep -q "kind: Deployment" /tmp/demo-node-api-dev.yaml
grep -q "kind: Service" /tmp/demo-node-api-dev.yaml
grep -q "kind: Ingress" /tmp/demo-node-api-dev.yaml
grep -q "kind: HorizontalPodAutoscaler" /tmp/demo-node-api-dev.yaml
grep -q "kind: PodDisruptionBudget" /tmp/demo-node-api-dev.yaml
grep -q "kind: NetworkPolicy" /tmp/demo-node-api-dev.yaml

echo
echo "Checking live resources..."
kubectl get serviceaccount "$APP" -n "$NAMESPACE" >/dev/null
kubectl get configmap "$APP-config" -n "$NAMESPACE" >/dev/null
kubectl get secret "$APP-secret" -n "$NAMESPACE" >/dev/null
kubectl get deployment "$APP" -n "$NAMESPACE" >/dev/null
kubectl get service "$APP" -n "$NAMESPACE" >/dev/null
kubectl get ingress "$APP" -n "$NAMESPACE" >/dev/null
kubectl get hpa "$APP" -n "$NAMESPACE" >/dev/null
kubectl get pdb "$APP" -n "$NAMESPACE" >/dev/null
kubectl get networkpolicy "$APP-default-deny" -n "$NAMESPACE" >/dev/null
kubectl get networkpolicy "$APP-allow-ingress" -n "$NAMESPACE" >/dev/null
kubectl get networkpolicy "$APP-allow-dns-egress" -n "$NAMESPACE" >/dev/null

echo
echo "Checking rollout..."
kubectl rollout status deployment/"$APP" -n "$NAMESPACE" --timeout=180s >/dev/null

READY_REPLICAS="$(kubectl get deployment "$APP" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' || echo 0)"
if [ -z "$READY_REPLICAS" ] || [ "$READY_REPLICAS" -lt 1 ]; then
  echo "ERROR: deployment has no ready replicas"
  exit 1
fi

echo
echo "Checking endpoints..."
ENDPOINTS="$(kubectl get endpoints "$APP" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: service has no endpoints"
  exit 1
fi

echo
echo "Checking Pod security settings..."
POD="$(kubectl get pod -n "$NAMESPACE" -l app.kubernetes.io/name="$APP" -o jsonpath='{.items[0].metadata.name}')"

RUN_AS_NON_ROOT="$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsNonRoot}')"
AUTOMOUNT="$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.automountServiceAccountToken}')"
SECCOMP="$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.seccompProfile.type}')"
READONLY="$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')"
NO_PRIV_ESC="$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}')"

if [ "$RUN_AS_NON_ROOT" != "true" ]; then
  echo "ERROR: runAsNonRoot should be true"
  exit 1
fi

if [ "$AUTOMOUNT" != "false" ]; then
  echo "ERROR: automountServiceAccountToken should be false"
  exit 1
fi

if [ "$SECCOMP" != "RuntimeDefault" ]; then
  echo "ERROR: seccompProfile should be RuntimeDefault"
  exit 1
fi

if [ "$READONLY" != "true" ]; then
  echo "ERROR: readOnlyRootFilesystem should be true"
  exit 1
fi

if [ "$NO_PRIV_ESC" != "false" ]; then
  echo "ERROR: allowPrivilegeEscalation should be false"
  exit 1
fi

echo
echo "Checking probes and resources..."
kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].startupProbe}' | grep -q "httpGet"
kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].readinessProbe}' | grep -q "httpGet"
kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].livenessProbe}' | grep -q "httpGet"
kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' | grep -q "100m"

echo
echo "Checking health endpoint through port-forward..."
kubectl port-forward -n "$NAMESPACE" svc/"$APP" 18092:80 >/tmp/demo-node-api-capstone-pf.log 2>&1 &
PF_PID=$!

cleanup() {
  kill "$PF_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 5

if ! curl -fsS http://127.0.0.1:18092/health >/dev/null; then
  echo "ERROR: /health endpoint failed"
  exit 1
fi

echo
echo "Ready replicas: $READY_REPLICAS"
echo "Endpoints: $ENDPOINTS"
echo "Pod checked: $POD"
echo "Module 10 capstone validation passed."
```

Make executable:

```bash id="i9idrm"
chmod +x 10.18-module-10-capstone/scripts/validate-module-10-capstone.sh
```

Run:

```bash id="lg5z5u"
./10.18-module-10-capstone/scripts/validate-module-10-capstone.sh
```

---

# 25. Create Capstone Summary Script

```bash id="s6ofqm"
nano 10.18-module-10-capstone/scripts/capstone-summary.sh
```

Paste:

```bash id="hn6627"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP="${APP:-demo-node-api}"

echo "===== Module 10 Capstone Summary ====="

echo
echo "Context:"
kubectl config current-context

echo
echo "Namespace:"
kubectl get namespace "$NAMESPACE" --show-labels || true

echo
echo "Core resources:"
kubectl get serviceaccount,configmap,secret,deployment,service,ingress,hpa,pdb,networkpolicy \
  -n "$NAMESPACE" \
  -l app.kubernetes.io/name="$APP" || true

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP" -o wide || true

echo
echo "Deployment:"
kubectl describe deployment "$APP" -n "$NAMESPACE" | sed -n '1,120p' || true

echo
echo "HPA:"
kubectl get hpa "$APP" -n "$NAMESPACE" || true
kubectl describe hpa "$APP" -n "$NAMESPACE" | sed -n '1,120p' || true

echo
echo "PDB:"
kubectl get pdb "$APP" -n "$NAMESPACE" || true

echo
echo "Service endpoints:"
kubectl get endpoints "$APP" -n "$NAMESPACE" || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "Metrics if available:"
kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/name="$APP" || true
```

Make executable:

```bash id="u47mz3"
chmod +x 10.18-module-10-capstone/scripts/capstone-summary.sh
```

Run:

```bash id="gkb9d3"
./10.18-module-10-capstone/scripts/capstone-summary.sh
```

---

# 26. Create Cleanup Script

```bash id="gmh9ss"
nano 10.18-module-10-capstone/scripts/cleanup-module-10-capstone.sh
```

Paste:

```bash id="w96svb"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Cleanup Module 10 Capstone ====="
echo "Namespace: $NAMESPACE"

kubectl delete -k apps/demo-node-api/optional/monitoring -n "$NAMESPACE" --ignore-not-found=true || true
kubectl delete -k apps/demo-node-api/overlays/dev --ignore-not-found=true || true

kubectl delete secret demo-node-api-secret -n "$NAMESPACE" --ignore-not-found=true

echo
echo "Capstone live resources cleaned from namespace $NAMESPACE."
echo "Files are kept for Git, portfolio, and future modules."
```

Make executable:

```bash id="y6g60q"
chmod +x 10.18-module-10-capstone/scripts/cleanup-module-10-capstone.sh
```

Run only if you want cleanup:

```bash id="vrhub1"
./10.18-module-10-capstone/scripts/cleanup-module-10-capstone.sh
```

---

# 27. Create ArgoCD Application for Capstone

```bash id="8l4m9x"
nano 10.18-module-10-capstone/argocd/demo-node-api-dev.yaml
```

Paste and replace `repoURL`:

```yaml id="aqx5e0"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-dev
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    environment: dev
spec:
  project: default

  source:
    repoURL: https://github.com/YOUR_USERNAME/devops-masterclass.git
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: dev

  syncPolicy:
    automated:
      enabled: false
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

For production, keep manual sync initially:

```bash id="zrn1lq"
nano 10.18-module-10-capstone/argocd/demo-node-api-production.yaml
```

Paste and replace `repoURL`:

```yaml id="ag8hrj"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-production
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    environment: production
spec:
  project: default

  source:
    repoURL: https://github.com/YOUR_USERNAME/devops-masterclass.git
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    automated:
      enabled: false
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

ArgoCD automated sync can reconcile Git changes automatically, but for production the safer starting point is manual sync with review and approval. ([Argo CD][6])

---

# 28. Create Operations Runbook

```bash id="pqny3u"
nano 10.18-module-10-capstone/runbooks/demo-node-api-operations-runbook.md
```

Paste:

````markdown id="cqln58"
# demo-node-api Kubernetes Operations Runbook

## App

demo-node-api

## Namespace

dev / staging / production

## Core Commands

```bash
kubectl get deploy,svc,ingress,hpa,pdb,networkpolicy -n dev -l app.kubernetes.io/name=demo-node-api
kubectl get pods -n dev -l app.kubernetes.io/name=demo-node-api -o wide
kubectl describe deployment demo-node-api -n dev
kubectl logs deployment/demo-node-api -n dev --tail=100
````

## Health Check

```bash
kubectl port-forward -n dev svc/demo-node-api 3002:80
curl http://127.0.0.1:3002/health
curl http://127.0.0.1:3002/ready
```

## Rollout

```bash
kubectl rollout status deployment/demo-node-api -n dev
kubectl rollout history deployment/demo-node-api -n dev
kubectl rollout undo deployment/demo-node-api -n dev
```

## Scaling

```bash
kubectl get hpa demo-node-api -n dev
kubectl describe hpa demo-node-api -n dev
kubectl top pods -n dev -l app.kubernetes.io/name=demo-node-api
```

## Network

```bash
kubectl get networkpolicy -n dev -l app.kubernetes.io/name=demo-node-api
kubectl describe networkpolicy demo-node-api-default-deny -n dev
```

## Common Issues

| Symptom          | First Checks                                |
| ---------------- | ------------------------------------------- |
| Pod Pending      | describe Pod, events, resources, scheduling |
| ImagePullBackOff | image name, tag, registry, pull policy      |
| CrashLoopBackOff | logs --previous, env vars, secrets          |
| NotReady         | readinessProbe, app port, dependencies      |
| No endpoints     | Service selector, Pod labels, readiness     |
| Ingress 404      | host/path, ingressClassName                 |
| HPA unknown      | metrics-server, CPU requests                |
| Network timeout  | NetworkPolicy, DNS egress, CNI support      |

## Golden Rule

Check events, describe, logs, metrics, rollout history, and Git changes together.

````

---

# 29. Create Release Runbook

```bash id="kj3j99"
nano 10.18-module-10-capstone/runbooks/demo-node-api-release-runbook.md
````

Paste:

````markdown id="g2wmsh"
# demo-node-api Release Runbook

## Build

```bash
docker build -t demo-node-api:0.1.0 .
````

## Local kind Load

```bash
kind load docker-image demo-node-api:0.1.0 --name devops-k8s
```

## Render

```bash
kubectl kustomize apps/demo-node-api/overlays/dev
kubectl kustomize apps/demo-node-api/overlays/staging
kubectl kustomize apps/demo-node-api/overlays/production
```

## Deploy Dev

```bash
kubectl apply -k apps/demo-node-api/overlays/dev
kubectl rollout status deployment/demo-node-api -n dev
```

## Validate

```bash
./10.18-module-10-capstone/scripts/validate-module-10-capstone.sh
```

## Promote Image

Update overlay image tag:

```yaml
images:
  - name: demo-node-api
    newTag: 1.4.2
```

## GitOps Promotion

1. Commit dev overlay change.
2. ArgoCD syncs dev.
3. Test dev.
4. Promote same image tag to staging.
5. Test staging.
6. Promote same image tag to production.
7. Manual production sync.
8. Monitor dashboards and logs.

## Rollback

Preferred GitOps rollback:

```bash
git revert <bad-commit>
git push
```

Emergency Kubernetes rollback:

```bash
kubectl rollout undo deployment/demo-node-api -n production
```

## Golden Rule

Build once. Promote the same artifact. Roll back through Git whenever possible.

````

---

# 30. Create Troubleshooting Runbook

```bash id="h7wl3n"
nano 10.18-module-10-capstone/runbooks/demo-node-api-troubleshooting-runbook.md
````

Paste:

````markdown id="2agfna"
# demo-node-api Troubleshooting Runbook

## 1. Is the Pod running?

```bash
kubectl get pods -n dev -l app.kubernetes.io/name=demo-node-api
kubectl describe pod POD_NAME -n dev
````

## 2. Are events showing errors?

```bash
kubectl get events -n dev --sort-by=.lastTimestamp
```

## 3. Did the app crash?

```bash
kubectl logs POD_NAME -n dev
kubectl logs POD_NAME -n dev --previous
```

## 4. Are endpoints available?

```bash
kubectl get svc demo-node-api -n dev
kubectl get endpoints demo-node-api -n dev
```

## 5. Are probes failing?

```bash
kubectl describe pod POD_NAME -n dev | grep -A20 -i probe
```

## 6. Is HPA working?

```bash
kubectl get hpa demo-node-api -n dev
kubectl describe hpa demo-node-api -n dev
kubectl top pods -n dev
```

## 7. Is Ingress routing?

```bash
kubectl get ingress demo-node-api -n dev
kubectl describe ingress demo-node-api -n dev
```

## 8. Is NetworkPolicy blocking traffic?

```bash
kubectl get networkpolicy -n dev
kubectl describe networkpolicy -n dev
```

## 9. Did config or image change?

```bash
kubectl rollout history deployment/demo-node-api -n dev
kubectl describe deployment demo-node-api -n dev
```

## 10. GitOps check

```bash
kubectl get applications -n argocd
kubectl describe application demo-node-api-dev -n argocd
```

## Golden Rule

Most Kubernetes incidents become clear after checking events, describe output, logs, endpoints, rollout history, and metrics.

````

---

# 31. Create Capstone Documentation Note

```bash id="gr1irs"
nano 10.18-module-10-capstone/notes/module-10-capstone-summary.md
````

Paste:

```markdown id="9f3t6o"
# Module 10 Capstone Summary

## Project

Production-grade Kubernetes deployment package for demo-node-api.

## Included

- Deployment
- Service
- Ingress
- ConfigMap
- Secret example
- ServiceAccount
- startupProbe
- readinessProbe
- livenessProbe
- graceful shutdown preStop
- resource requests and limits
- HPA
- PDB
- NetworkPolicy
- securityContext
- non-root execution
- read-only root filesystem
- dropped Linux capabilities
- RuntimeDefault seccomp
- Kustomize base and overlays
- ArgoCD Applications
- validation script
- cleanup script
- operations runbook
- release runbook
- troubleshooting runbook

## Environments

- dev
- staging
- production

## Production Themes

- reliability
- repeatability
- security
- observability
- GitOps readiness
- least privilege
- safe scaling
- safe rollout
- clear troubleshooting
```

---

# 32. Full Capstone Execution Flow

Use this as your final run sequence:

```bash id="mvd7g8"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic demo-node-api-secret \
  -n dev \
  --from-literal=MONGO_URI='mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo' \
  --from-literal=JWT_SECRET='local-dev-jwt-secret' \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl kustomize apps/demo-node-api/overlays/dev \
  > 10.18-module-10-capstone/reports/demo-node-api-dev-rendered.yaml

kubectl apply -k apps/demo-node-api/overlays/dev

kubectl rollout status deployment/demo-node-api -n dev --timeout=180s

./10.18-module-10-capstone/scripts/capstone-summary.sh

./10.18-module-10-capstone/scripts/validate-module-10-capstone.sh
```

---

# 33. Expected Final Resource View

```bash id="ozifw8"
kubectl get all -n dev -l app.kubernetes.io/name=demo-node-api
```

Expected:

```text id="6xv37e"
pod/demo-node-api-...
service/demo-node-api
deployment.apps/demo-node-api
replicaset.apps/demo-node-api-...
horizontalpodautoscaler.autoscaling/demo-node-api
```

Additional:

```bash id="kycmgk"
kubectl get ingress,hpa,pdb,networkpolicy,serviceaccount,configmap,secret -n dev \
  -l app.kubernetes.io/name=demo-node-api
```

Expected:

```text id="f9cg4w"
ingress.networking.k8s.io/demo-node-api
horizontalpodautoscaler.autoscaling/demo-node-api
poddisruptionbudget.policy/demo-node-api
networkpolicy.networking.k8s.io/demo-node-api-default-deny
networkpolicy.networking.k8s.io/demo-node-api-allow-ingress
networkpolicy.networking.k8s.io/demo-node-api-allow-dns-egress
serviceaccount/demo-node-api
configmap/demo-node-api-config
secret/demo-node-api-secret
```

---

# 34. Common Capstone Issues and Fixes

## Issue 1: `ImagePullBackOff`

Check:

```bash id="xxmk9b"
kubectl describe pod -n dev -l app.kubernetes.io/name=demo-node-api
```

Fix for kind:

```bash id="x5ne5c"
docker build -t demo-node-api:0.1.0 .
kind load docker-image demo-node-api:0.1.0 --name devops-k8s
kubectl rollout restart deployment/demo-node-api -n dev
```

---

## Issue 2: `CreateContainerConfigError`

Usually missing Secret or ConfigMap.

Check:

```bash id="h25j2b"
kubectl describe pod -n dev -l app.kubernetes.io/name=demo-node-api
kubectl get configmap demo-node-api-config -n dev
kubectl get secret demo-node-api-secret -n dev
```

Fix:

```bash id="hxowry"
kubectl create secret generic demo-node-api-secret \
  -n dev \
  --from-literal=MONGO_URI='mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo' \
  --from-literal=JWT_SECRET='local-dev-jwt-secret' \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

---

## Issue 3: Pod fails because of non-root user

Your Docker image may not support UID `10001`.

Fix Dockerfile:

```dockerfile id="wme9tn"
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app

USER appuser
```

Or temporarily patch dev overlay while fixing image:

```yaml id="zou4tf"
securityContext:
  runAsNonRoot: false
```

But do not leave production this way.

---

## Issue 4: App cannot write to filesystem

Because:

```yaml id="jyqbhs"
readOnlyRootFilesystem: true
```

Fix with explicit writable mount:

```yaml id="r7hkhz"
volumeMounts:
  - name: tmp
    mountPath: /tmp

volumes:
  - name: tmp
    emptyDir: {}
```

Already included in this capstone.

---

## Issue 5: HPA shows `<unknown>`

Check:

```bash id="3nbdzi"
kubectl top pods -n dev
kubectl describe hpa demo-node-api -n dev
```

Fix:

```bash id="n91ar2"
kubectl get deployment metrics-server -n kube-system
```

Ensure CPU requests exist:

```bash id="vlz1z6"
kubectl get pod -n dev -l app.kubernetes.io/name=demo-node-api \
  -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}'
```

---

## Issue 6: Ingress returns 404

Check:

```bash id="j4txgt"
kubectl get ingress demo-node-api -n dev
kubectl describe ingress demo-node-api -n dev
kubectl get pods -n ingress-nginx
```

Test with correct host:

```bash id="51e2f5"
curl -H "Host: api.localdev.me" http://127.0.0.1:8080/health
```

---

# 35. Production Readiness Checklist

```text id="lgkycj"
Application image built and scanned
Immutable image tag or digest used
ConfigMap created
Secret created by secure process
ServiceAccount dedicated
ServiceAccount token automount disabled
Deployment has probes
Deployment has resource requests/limits
Deployment runs as non-root
Privilege escalation disabled
Capabilities dropped
Root filesystem read-only
Writable /tmp explicitly mounted
Service exposes correct port
Ingress routes correct host/path
HPA configured
PDB configured
NetworkPolicy configured
Metrics-server installed for HPA
Optional Prometheus ServiceMonitor installed only if CRD exists
Kustomize overlays render successfully
ArgoCD Application created
Validation script passes
Runbooks committed
```

---

# 36. Interview Explanation

Use this:

```text id="g3cthm"
For the Kubernetes capstone, I built a production-style deployment package for a Node.js API. The package uses Kustomize with base, dev, staging, and production overlays. The base includes a Deployment, Service, Ingress, ConfigMap, Secret example, ServiceAccount, HPA, PDB, and NetworkPolicy.

The Deployment includes startup, readiness, and liveness probes, resource requests and limits, rolling update settings, graceful shutdown with preStop, topology spread, pod anti-affinity, and security hardening such as runAsNonRoot, readOnlyRootFilesystem, disabled privilege escalation, dropped capabilities, and RuntimeDefault seccomp.

For operations, I added validation, cleanup, summary scripts, GitOps-ready ArgoCD Applications, and runbooks for release, rollback, troubleshooting, autoscaling, network policy, and production operations.
```

Resume bullet:

```text id="bh5gqh"
Built a production-grade Kubernetes deployment package for a Node.js API using Kustomize overlays, hardened securityContext, probes, resources, HPA, PDB, NetworkPolicy, Ingress, ServiceAccount least privilege, observability hooks, ArgoCD GitOps manifests, validation automation, and operational runbooks.
```

---

# 37. Commit and Tag Module 10

From repo root:

```bash id="ysqsl8"
cd ~/devops-masterclass

git status

git add .gitignore 10-kubernetes-production-operations

git commit -m "feat: complete Kubernetes production operations capstone"

git tag -a v0.10.0 -m "Complete Module 10 Kubernetes Production Operations"

git push

git push origin v0.10.0
```

---

# 38. Module 10 Final Completion Summary

You completed:

```text id="gp9oj0"
10.1  Kubernetes mental model and architecture
10.2  Local cluster setup with kind and kubectl
10.3  Pods, labels, annotations, selectors, YAML anatomy
10.4  Deployments, ReplicaSets, rollouts, rollbacks
10.5  Services, DNS, ClusterIP, NodePort, LoadBalancer
10.6  Ingress, controller, TLS, host/path routing
10.7  ConfigMaps, Secrets, config injection
10.8  Probes, lifecycle hooks, graceful shutdown
10.9  Resource requests, limits, QoS, capacity
10.10 Workload placement, affinity, taints, topology spread
10.11 RBAC, ServiceAccounts, namespace isolation
10.12 PersistentVolumes, PVCs, StatefulSets, DB patterns
10.13 Helm, Kustomize, packaging, promotion
10.14 HPA, VPA concepts, Cluster Autoscaler, PDB
10.15 Observability, events, logs, metrics, Prometheus, Grafana, Loki
10.16 Production hardening, NetworkPolicy, Pod Security, admission
10.17 GitOps deployment flow with ArgoCD
10.18 Production-grade Kubernetes capstone
```

Module 10 is complete after the validation passes and the `v0.10.0` tag is pushed.

---

# Next Module

```text id="105q1h"
Module 11 — Advanced Kubernetes Troubleshooting
```

We will start with:

```text id="rrlat6"
Lesson 11.1 — Kubernetes Troubleshooting Mental Model
```

You will learn a production incident-style debugging framework for:

```text id="2du8mi"
Pending Pods
ImagePullBackOff
CrashLoopBackOff
OOMKilled
Evicted Pods
rollout failures
Service/DNS failures
Ingress/TLS failures
RBAC failures
probe failures
storage mount failures
NetworkPolicy failures
node pressure
autoscaling failures
```

[1]: https://kubernetes.io/docs/concepts/services-networking/network-policies/?utm_source=chatgpt.com "Network Policies"
[2]: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/?utm_source=chatgpt.com "Configure a Security Context for a Pod or Container"
[3]: https://kubernetes.io/docs/reference/kubernetes-api/autoscaling/horizontal-pod-autoscaler-v2/?utm_source=chatgpt.com "HorizontalPodAutoscaler"
[4]: https://kubernetes.io/docs/tasks/run-application/configure-pdb/?utm_source=chatgpt.com "Specifying a Disruption Budget for your Application"
[5]: https://kubernetes.io/docs/home/?utm_source=chatgpt.com "Kubernetes Documentation"
[6]: https://argo-cd.readthedocs.io/en/latest/user-guide/auto_sync/?utm_source=chatgpt.com "Automated Sync Policy - Declarative GitOps CD for Kubernetes"
