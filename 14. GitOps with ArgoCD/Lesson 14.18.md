# Module 14 — GitOps with Argo CD

## Lesson 18: Production GitOps Capstone

This capstone combines the entire module into one production system.

You will design and validate:

```text
source code
    │
    ▼
CI build, test, scan, sign
    │
    ▼
immutable ECR digest
    │
    ▼
GitOps promotion PR
    │
    ▼
HA Argo CD control plane
    │
    ├── AppProject policy
    ├── ApplicationSet placement
    ├── foundation Application
    └── workload Application
             │
             ├── migration hook
             ├── Argo Rollout
             ├── Prometheus analysis
             └── notifications
```

This is not a copy-paste production platform.

It is a reference architecture and assessment project. Replace example domains, IDs, versions, policies, and resource sizing with values validated for your environment.

---

# 14.1892 Capstone objective

Deploy the Todo application to:

```text
dev EKS

staging EKS

production EKS in ap-south-1

warm DR EKS in ap-southeast-1
```

with:

```text
no plaintext secrets in Git

no CI production kubeconfig

immutable image digests

reviewed production promotion

automated drift correction

canary analysis

tested rollback and DR
```

---

# 14.1893 Success definition

The project is complete only when you can prove:

```text
1. New source commit produces one immutable artifact.

2. Same digest moves through environments.

3. Production changes only after config PR approval.

4. Argo reconciles without CI cluster access.

5. Database migration gates workload release.

6. Canary aborts on a bad metric.

7. Manual drift self-heals.

8. Secret rotates without a plaintext Git change.

9. Alerts and notifications reach the right team.

10. Argo and application recovery meet measured RTO/RPO.
```

---

# 14.1894 Reference AWS accounts

```text
111111111111
platform/shared-services
  └── GitOps EKS

222222222222
non-production workloads
  ├── dev EKS
  └── staging EKS

333333333333
production workloads
  └── prod ap-south-1 EKS

444444444444
disaster recovery
  └── prod DR ap-southeast-1 EKS
```

Account boundaries are examples.

Use the AWS organization and trust model designed in earlier modules.

---

# 14.1895 Reference control-plane architecture

```text
                       GIT PROVIDER
                            │
                            ▼
                    PLATFORM ACCOUNT
                    GitOps EKS cluster
                            │
                  Argo CD HA installation
                            │
                 management IAM identity
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
      DEV/STAGE          PROD PRIMARY       PROD DR
       EKS APIs           EKS API           EKS API
          │                 │                 │
          ▼                 ▼                 ▼
    application        application        standby desired
     instances          instances             state
```

All production EKS APIs use approved private connectivity.

---

# 14.1896 Three repositories

```text
todo-api
→ application source, tests, Dockerfile, CI

platform-gitops
→ Argo CD, Projects, cluster add-ons, monitoring, secret operators

workloads-gitops
→ Todo desired state per environment
```

This separates:

```text
application development

platform administration

environment promotion
```

---

# 14.1897 Application repository

```text
todo-api/
│
├── src/
├── tests/
├── migrations/
├── Dockerfile
├── scripts/
│   ├── test.sh
│   ├── scan-image.sh
│   └── release-image.sh
├── Jenkinsfile
├── .github/workflows/build.yml
└── .gitlab-ci.yml
```

Use only the CI system chosen by your organization; the three files can be separate practice variants.

---

# 14.1898 Platform repository

```text
platform-gitops/
│
├── bootstrap/
│   └── root-application.yaml
├── argocd/
│   ├── values.yaml
│   ├── rbac/
│   ├── projects/
│   └── notifications/
├── add-ons/
│   ├── external-secrets/
│   ├── argo-rollouts/
│   ├── prometheus/
│   ├── aws-load-balancer-controller/
│   └── policy-engine/
├── clusters/
│   ├── nonprod/
│   ├── prod-primary/
│   └── prod-dr/
└── applicationsets/
```

Only platform administrators may approve high-privilege paths.

---

# 14.1899 Workload repository

```text
workloads-gitops/
│
├── apps/todo/
│   ├── base/
│   │   ├── rollout.yaml
│   │   ├── services.yaml
│   │   ├── analysis-template.yaml
│   │   ├── migration-job.yaml
│   │   ├── pdb.yaml
│   │   ├── network-policy.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       ├── prod-primary/
│       └── prod-dr/
├── foundations/todo/
│   ├── base/
│   └── overlays/
├── applications/
└── applicationsets/
```

Foundation and workload ownership are intentionally separated.

---

# 14.1900 Why separate foundation and workload?

Foundation owns long-lived dependencies:

```text
Namespace

ResourceQuota/LimitRange

ServiceAccounts and RBAC

SecretStore and ExternalSecret

baseline NetworkPolicy
```

Workload owns release-scoped resources:

```text
migration hook

Rollout

Services

AnalysisTemplate

Ingress
```

This avoids relying on a PreSync migration to wait for an ordinary Sync-phase ExternalSecret in the same operation.

---

# 14.1901 Bootstrap boundary

The handoff follows Argo CD's declarative-setup model: infrastructure establishes the minimum control plane, then Git becomes authoritative for the managed configuration. ([Argo CD][1]) ([Argo CD][2])

Terraform creates:

```text
EKS cluster

node capacity

network and endpoints

KMS keys

IAM roles and EKS access entries

initial Argo installation

minimal bootstrap Application
```

Argo then manages:

```text
its declarative configuration

platform add-ons

ApplicationSets

workload desired state
```

Document exactly where Terraform ownership stops.

---

# 14.1902 Version inventory

Start from the supported high-availability installation and pin the exact reviewed release used by the platform. ([Argo CD][3])

Create a release bill of materials:

```text
EKS Kubernetes version

Argo CD version

Argo Rollouts version

External Secrets version

Helm/Kustomize versions

AWS Load Balancer Controller version

Prometheus stack version

policy-engine version
```

Pin versions and record compatibility evidence.

Do not let capstone manifests reference moving `latest` artifacts.

---

# 14.1903 Production AppProject

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: todo-production
  namespace: argocd
spec:
  description: Todo production workloads
  sourceRepos:
    - https://github.com/example/workloads-gitops.git
  destinations:
    - name: prod-ap-south-1
      namespace: todo-prod
    - name: prod-dr-ap-southeast-1
      namespace: todo-prod
  clusterResourceWhitelist: []
  namespaceResourceWhitelist:
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Service
    - group: ""
      kind: ServiceAccount
    - group: apps
      kind: Deployment
    - group: batch
      kind: Job
    - group: networking.k8s.io
      kind: Ingress
    - group: networking.k8s.io
      kind: NetworkPolicy
    - group: policy
      kind: PodDisruptionBudget
    - group: argoproj.io
      kind: Rollout
    - group: argoproj.io
      kind: AnalysisTemplate
  orphanedResources:
    warn: true
```

Add External Secrets kinds to the separate foundation Project, not necessarily the workload Project.

---

# 14.1904 Project role

```yaml
spec:
  roles:
    - name: release-operator
      description: Observe and promote Todo production releases
      policies:
        - p, proj:todo-production:release-operator, applications, get, todo-production/*, allow
        - p, proj:todo-production:release-operator, applications, sync, todo-production/*, allow
      groups:
        - platform:todo-release-operators
```

Whether manual sync is allowed depends on the chosen production process.

Argo Rollout promote/abort actions need separately reviewed authorization.

---

# 14.1905 Cluster registration labels

Primary:

```yaml
metadata:
  labels:
    environment: production
    application-fleet: business
    region: ap-south-1
    role: primary
    deploy-todo: "true"
```

DR:

```yaml
metadata:
  labels:
    environment: production
    application-fleet: business
    region: ap-southeast-1
    role: disaster-recovery
    deploy-todo: "true"
```

Registration Secrets themselves are delivered through the protected bootstrap secret mechanism.

---

# 14.1906 Foundation ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: todo-foundations
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - clusters:
        selector:
          matchLabels:
            deploy-todo: "true"
  template:
    metadata:
      name: 'todo-foundation-{{.nameNormalized}}'
      labels:
        application: todo
        layer: foundation
    spec:
      project: todo-foundation
      source:
        repoURL: https://github.com/example/workloads-gitops.git
        targetRevision: refs/heads/main
        path: 'foundations/todo/overlays/{{index .metadata.labels "role"}}'
      destination:
        name: '{{.name}}'
        namespace: todo-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Ensure overlay paths actually match `primary` and `disaster-recovery`, or use an explicit path label.

---

# 14.1907 Foundation ExternalSecret

This resource stores the secret reference and delivery policy in Git while External Secrets obtains the runtime value from the configured provider. ([External Secrets][7])

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: todo-database
  namespace: todo-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: todo-prod
    kind: SecretStore
  target:
    name: todo-database
    creationPolicy: Owner
  data:
    - secretKey: application-url
      remoteRef:
        key: /production/todo/database
        property: application_url
    - secretKey: migrator-url
      remoteRef:
        key: /production/todo/database
        property: migrator_url
```

For stronger separation, use separate external secrets and target Secrets for runtime and migration identities.

---

# 14.1908 Foundation readiness gate

Before enabling the workload Application, verify:

```bash
argocd app wait todo-foundation-prod-ap-south-1 \
  --sync --health --timeout 600

kubectl get externalsecret -n todo-prod

kubectl get secret todo-database -n todo-prod

kubectl get serviceaccount todo-migrator -n todo-prod
```

This is a cluster onboarding gate.

Day-to-day releases assume the foundation remains continuously monitored.

---

# 14.1909 Workload ApplicationSet

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: todo-workloads
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - clusters:
        selector:
          matchLabels:
            deploy-todo: "true"
  template:
    metadata:
      name: 'todo-{{.nameNormalized}}'
      labels:
        application: todo
        team: todo
        environment: production
      annotations:
        notifications.argoproj.io/subscribe.on-sync-failed.slack: todo-prod-alerts
    spec:
      project: todo-production
      source:
        repoURL: https://github.com/example/workloads-gitops.git
        targetRevision: refs/heads/main
        path: 'apps/todo/overlays/{{index .metadata.labels "role"}}'
      destination:
        name: '{{.name}}'
        namespace: todo-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        retry:
          limit: 3
          backoff:
            duration: 10s
            factor: 2
            maxDuration: 2m
        syncOptions:
          - PruneLast=true
```

Production auto-sync is acceptable only when Git approvals and progressive delivery provide the intended gates.

---

# 14.1910 Base Kustomization

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - rollout.yaml
  - services.yaml
  - analysis-template.yaml
  - migration-job.yaml
  - pdb.yaml
  - network-policy.yaml

commonLabels:
  app.kubernetes.io/name: todo-api
  app.kubernetes.io/part-of: todo
```

Do not put environment-specific secret identifiers or hostnames in the base.

---

# 14.1911 Migration hook

The `PreSync` annotation places this Job in Argo CD's pre-deployment hook phase. ([Argo CD][4])

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: todo-db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  backoffLimit: 1
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 86400
  template:
    spec:
      serviceAccountName: todo-migrator
      restartPolicy: Never
      containers:
        - name: migrate
          image: todo-api@sha256:REPLACED_BY_OVERLAY
          args: ["migrate", "up"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: todo-database
                  key: migrator-url
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

The migration framework must implement locking and version history.

---

# 14.1912 Canary Rollout

The canary steps progressively alter exposure and pause for evidence before further promotion. ([Argo Rollouts][5])

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: todo-api
spec:
  replicas: 10
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: todo-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: todo-api
    spec:
      serviceAccountName: todo-api
      containers:
        - name: api
          image: todo-api@sha256:REPLACED_BY_OVERLAY
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: todo-database
                  key: application-url
          startupProbe:
            httpGet:
              path: /startup
              port: http
            failureThreshold: 30
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /live
              port: http
            periodSeconds: 10
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              memory: 512Mi
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
  strategy:
    canary:
      stableService: todo-api-stable
      canaryService: todo-api-canary
      steps:
        - setWeight: 5
        - pause:
            duration: 5m
        - analysis:
            templates:
              - templateName: todo-canary-safety
        - setWeight: 25
        - pause:
            duration: 10m
        - analysis:
            templates:
              - templateName: todo-canary-safety
        - setWeight: 50
        - pause: {}
        - setWeight: 100
```

Add the traffic-routing stanza required by your tested ingress or service mesh.

---

# 14.1913 Canary Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: todo-api-stable
spec:
  selector:
    app.kubernetes.io/name: todo-api
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: v1
kind: Service
metadata:
  name: todo-api-canary
spec:
  selector:
    app.kubernetes.io/name: todo-api
  ports:
    - name: http
      port: 80
      targetPort: http
```

The Rollouts controller owns the revision-specific selector additions.

Verify Argo does not fight them.

---

# 14.1914 AnalysisTemplate

An AnalysisTemplate defines the measurements and success/failure conditions used by an AnalysisRun. ([Argo Rollouts][6])

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: todo-canary-safety
spec:
  metrics:
    - name: request-volume
      interval: 1m
      count: 5
      successCondition: result[0] >= 100
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus-operated.monitoring.svc:9090
          query: |
            sum(increase(http_requests_total{
              namespace="todo-prod",
              rollout="todo-api",
              revision="canary"
            }[2m]))

    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.995
      failureLimit: 2
      provider:
        prometheus:
          address: http://prometheus-operated.monitoring.svc:9090
          query: |
            sum(rate(http_requests_total{
              namespace="todo-prod",
              rollout="todo-api",
              revision="canary",
              status!~"5.."
            }[2m]))
            /
            sum(rate(http_requests_total{
              namespace="todo-prod",
              rollout="todo-api",
              revision="canary"
            }[2m]))
```

Your application instrumentation must actually provide these labels.

---

# 14.1915 Add latency evidence

Conceptual p95 query:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(http_request_duration_seconds_bucket{
      namespace="todo-prod",
      rollout="todo-api",
      revision="canary"
    }[5m])
  )
)
```

Set a threshold based on the service SLO and known metric units.

Do not copy an arbitrary number from a tutorial.

---

# 14.1916 PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: todo-api
spec:
  minAvailable: 80%
  selector:
    matchLabels:
      app.kubernetes.io/name: todo-api
```

Test this with Rollout surge and node-drain behavior.

Ensure the percentage does not prevent normal platform maintenance.

---

# 14.1917 NetworkPolicy

Conceptual default isolation:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: todo-api
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: todo-api
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-system
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

Add the real DNS, database, telemetry, and AWS endpoint paths required by the selected CNI implementation.

---

# 14.1918 Production overlay

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: todo-prod

resources:
  - ../../base
  - ingress.yaml

images:
  - name: todo-api
    newName: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api
    digest: sha256:REPLACE_WITH_APPROVED_DIGEST

patches:
  - path: rollout-prod-patch.yaml
```

CI changes only the digest through a reviewed PR.

---

# 14.1919 DR overlay

```yaml
images:
  - name: todo-api
    newName: 444444444444.dkr.ecr.ap-southeast-1.amazonaws.com/todo-api
    digest: sha256:SAME_APPROVED_DIGEST
```

The same image digest must exist in the replicated ECR registry.

DR patch may set:

```text
replicas = warm-standby capacity

Ingress = internal/disabled until failover

database endpoint = DR replica/cluster
```

without changing application artifact identity.

---

# 14.1920 CI release flow

```text
1. Merge application source PR.
2. CI tests and scans source.
3. CI builds image once.
4. CI pushes immutable commit tag.
5. CI resolves registry digest.
6. CI creates SBOM and provenance.
7. CI signs/attests artifact.
8. CI writes release.json.
9. Promotion automation opens dev config PR.
10. Dev validation passes.
11. Same digest PR moves to staging.
12. Staging soak/performance tests pass.
13. Same digest PR moves to production.
```

---

# 14.1921 Production PR controls

Required checks:

```text
Kustomize build succeeds

schema validation succeeds

policy checks succeed

digest exists in primary and DR registries

signature/provenance is valid

vulnerability policy passes

migration compatibility declaration exists

change window allows release

Todo owner approves

platform/SRE approves for high-risk changes
```

---

# 14.1922 Promotion commit

Example:

```text
promote(todo-api): prod to a61c92f

Image: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api
Digest: sha256:ab12cd34...
Source: a61c92f
CI: https://ci.example/runs/1842
Staging evidence: https://observability.example/release/1842
Migration class: expand-only
Rollback-compatible: yes
```

Make evidence easy for the reviewer to inspect.

---

# 14.1923 Reconciliation sequence

```text
config PR merged
      │
      ▼
Git webhook / polling
      │
      ▼
Argo detects new digest
      │
      ▼
PreSync migration Job
      │ success
      ▼
Rollout Pod template changes
      │
      ▼
5% canary
      │
      ▼
Prometheus AnalysisRun
      │ success
      ▼
25% → analysis → 50% manual gate → 100%
      │
      ▼
Synced + Healthy + fully promoted
```

---

# 14.1924 Migration failure test

Create a disposable branch whose migration exits non-zero.

Prove:

```text
PreSync Job fails

Rollout image remains stable

Argo operation reports Failed

notification arrives

failed Job logs remain

no destructive partial schema change occurred
```

Then fix Git and retry through a new commit.

---

# 14.1925 Canary failure test

Deploy a test candidate that returns controlled 5xx responses only when a test header or flag is enabled.

Send canary traffic and prove:

```text
minimum request volume reached

success-rate metric fails

AnalysisRun fails

Rollout aborts/stops progression

stable service remains healthy

Git is reverted to the known-good digest
```

Do this outside real customer production first.

---

# 14.1926 Drift test

Manual change:

```bash
kubectl scale rollout todo-api -n todo-prod --replicas=3
```

Expected:

```text
Argo reports OutOfSync

self-heal restores declared replicas

audit/event evidence records the sequence
```

If an HPA owns replicas, design and test ignore ownership instead of expecting Git to win.

---

# 14.1927 Secret rotation test

```text
1. Rotate database credential in the real provider.
2. Verify database accepts new credential.
3. Verify ESO refreshes target Secret.
4. Verify workload reload/restart mechanism.
5. Verify old credential is revoked after overlap.
6. Verify no plaintext value appears in Git, logs, Argo UI, or CI.
```

Rotation is not complete until the running application uses the new value.

---

# 14.1928 Observability dashboard

Build the Argo CD panels from the component metrics exposed for Prometheus collection. ([Argo CD][8])

Create panels for:

```text
Application sync and health status

reconciliation p50/p95/p99

cluster connection and cache age

repo-server render latency/restarts/memory/disk

sync success/failure rate

Rollout phase and pause duration

AnalysisRun result

stable vs canary request rate

stable vs canary success rate and p95 latency

ESO Ready and refresh age
```

---

# 14.1929 Alert routing

```text
Argo platform unavailable
→ platform on-call

one target cluster disconnected
→ platform + cluster owner

Todo production Degraded
→ Todo on-call

canary AnalysisRun failed
→ release channel + Todo on-call

secret refresh failed
→ security/platform + Todo owner

DR drift or registry replication failure
→ resilience owner
```

Pages should name the owner and runbook.

---

# 14.1930 Backup design

Argo CD's disaster-recovery procedure can export and import cluster configuration, but the complete platform recovery design must also cover Git, credentials, infrastructure, images, and application data. ([Argo CD][9])

```text
Git repositories
→ provider backup/mirror and protected history

Argo configuration
→ Git + encrypted admin export

Argo/cluster secrets
→ external secret provider and recovery procedure

IAM/EKS access/network
→ Terraform state and source

container images
→ immutable retention and cross-region replication

database
→ managed backups, PITR, cross-region DR design
```

Every item has its own owner, RPO, and restore test.

---

# 14.1931 DR exercise

```text
1. Freeze production promotions.
2. Declare primary control plane unavailable.
3. Fence old Argo cluster credentials.
4. Restore/bootstrap replacement Argo.
5. Restore external secret delivery.
6. Validate Git and target cluster access.
7. Compare without broad auto-sync first.
8. Re-enable reconciliation by risk group.
9. Activate DR data and traffic procedure.
10. Validate customer transaction.
11. Measure RTO and data RPO.
12. Re-establish one authoritative control plane.
```

Record observed time for every step.

---

# 14.1932 Primary-region failover is more than Argo

```text
Argo deploys DR configuration
```

but failover still needs:

```text
database promotion

DNS/Global Accelerator/Route 53 change

certificate validity

secret validity

queue/event topology

third-party allowlists

customer-session strategy
```

The capstone runbook must cover the application system, not only Kubernetes.

---

# 14.1933 Security test plan

Prove denial, not only success:

```text
□ developer cannot change production overlay without owner approval

□ CI cannot call production Kubernetes API

□ workload Project cannot deploy to argocd namespace

□ workload Project cannot create ClusterRole

□ Todo Argo target identity cannot mutate another team's namespace

□ untrusted PR cannot obtain AWS release role

□ unsigned image is rejected

□ wrong repository source is denied

□ plaintext Secret policy blocks merge/admission

□ break-glass use generates alert
```

---

# 14.1934 Upgrade test plan

For Argo and add-ons:

```text
1. Review release and upgrade notes.
2. Render old vs new manifests.
3. Back up current configuration.
4. Upgrade disposable/non-production control plane.
5. Re-run fleet reconciliation tests.
6. Re-run SSO/RBAC/secret/notification tests.
7. Re-run controller failure tests.
8. Observe resource and latency changes.
9. Roll back in test.
10. Schedule production upgrade.
```

The capstone includes an upgrade rehearsal, not only initial installation.

---

# 14.1935 Operational runbook — release

```text
PRE-RELEASE
verify approvals, digest, health, capacity, change window

RELEASE
merge config PR and observe migration

CANARY
verify traffic volume, success, latency, dependency health

PROMOTION
approve indefinite pause only with evidence

COMPLETE
verify 100%, stable designation, SLOs, alerts, Git/Argo state

ROLLBACK
abort exposure, validate schema compatibility, revert Git digest
```

---

# 14.1936 Operational runbook — stuck sync

```text
1. Capture Application and operation state.
2. Identify phase and earliest wave.
3. Inspect hook Job or unhealthy resource.
4. Determine desired/render/cluster/workload layer.
5. Preserve logs and events.
6. Correct authoritative Git/config/dependency cause.
7. Retry only after idempotency is established.
8. Confirm Synced, Healthy, and customer behavior.
```

---

# 14.1937 Operational runbook — bad release

```text
1. Stop promotion or abort Rollout.
2. Check whether stable version is serving.
3. Check migration and external side effects.
4. Choose roll forward or Git revert.
5. Apply emergency approval path.
6. Observe Argo and Rollout convergence.
7. Validate data and customer SLOs.
8. Preserve evidence and start incident review.
```

---

# 14.1938 Capstone test matrix

```text
TEST                         EXPECTED RESULT

Good source release          digest promoted and canary completes

Bad migration                PreSync blocks workload update

Bad readiness                canary does not receive/complete traffic

High 5xx canary              analysis fails and rollout aborts

Manual replica drift         Argo self-heals or HPA ownership applies

Git unavailable              workloads run; reconciliation alerts

Target EKS unreachable       cluster alert; other clusters continue

repo-server failure          HA replica serves after limited disruption

secret rotation             app consumes new credential

primary Argo loss            restore meets measured RTO

primary region loss          DR system meets defined RTO/RPO
```

---

# 14.1939 Evidence folder

Store non-secret evidence:

```text
capstone-evidence/
│
├── architecture.md
├── threat-model.md
├── versions.md
├── release-trace.md
├── test-results.md
├── screenshots/
├── promql/
├── runbooks/
├── restore-report.md
└── incident-review.md
```

Do not store tokens, kubeconfigs, private keys, Secret values, or unredacted exports.

---

# 14.1940 Required deliverables

```text
□ architecture diagram

□ repository ownership model

□ CODEOWNERS/branch protection design

□ pinned version inventory

□ Argo HA values/manifests

□ AppProjects

□ ApplicationSets

□ foundation manifests

□ workload Kustomize base/overlays

□ ExternalSecret design

□ migration hook

□ Rollout and AnalysisTemplate

□ CI pipeline and release.json

□ promotion PR checks

□ dashboards and alerts

□ release/rollback/DR runbooks

□ completed failure test matrix

□ restore timing and lessons
```

---

# 14.1941 Evaluation rubric

```text
20%  GitOps correctness and ownership

15%  security and least privilege

15%  immutable build/promotion design

15%  safe migrations/progressive delivery

15%  observability and troubleshooting

10%  HA, backup, and DR

10%  documentation and evidence
```

A visually impressive dashboard cannot compensate for plaintext secrets or untested rollback.

---

# 14.1942 Common capstone shortcuts that fail

```text
CI runs kubectl against production

image uses latest

prod auto-updates to newest tag

Secrets committed as base64

one default AppProject allows everything

Argo cluster role is global admin without review

migration drops columns before rollout

canary metric mixes stable and canary

DR cluster has manifests but no data/image/secret path

backup exists but restore never tested
```

Any one of these is a material capstone gap.

---

# 14.1943 Capstone interview walkthrough

Explain in this order:

```text
1. Business/reliability objective

2. Trust and cluster topology

3. Repository ownership

4. Build and artifact identity

5. Promotion controls

6. Argo placement and authorization

7. Secret delivery

8. Migration and rollout safety

9. Observability

10. Failure and recovery evidence
```

Do not begin with a list of tools.

Begin with the architecture problem they solve.

---

# 14.1944 Never-forget Capstone rules

```text
1. Infrastructure bootstraps the GitOps control plane.

2. GitOps manages declared platform/workload state.

3. Ownership boundaries must not overlap.

4. Foundation dependencies precede release hooks.

5. CI never needs production Kubernetes access.

6. One build creates one promoted digest.

7. Production promotion is an approved Git change.

8. AppProject and target RBAC both restrict deployment.

9. Secrets are references in Git.

10. Runtime and migrator identities are distinct.

11. Schema expands before it contracts.

12. Canary needs candidate-specific telemetry.

13. Traffic volume is part of analysis evidence.

14. Self-heal ownership must respect HPA/controllers.

15. Alerts route by owner and failure domain.

16. Git, registry, secrets, and data each need DR.

17. Fencing prevents dual Argo control planes.

18. DR is proven by customer transaction.

19. Security tests must prove forbidden actions fail.

20. A capstone is complete when failure tests pass.
```

---

# 14.1945 Capstone execution mnemonic

Memorize:

# **B-A-S-E-L-I-N-E**

```text
BOOTSTRAP
   ↓
AUTHORIZATION
   ↓
SECRETS
   ↓
ENVIRONMENTS
   ↓
LOAD / RELEASE
   ↓
INSIGHT
   ↓
NEGATIVE TESTS
   ↓
EVIDENCE
```

This is the order in which to build and prove the platform.

---

# ✅ Module 14 — Lesson 18 Complete

You have assembled:

```text
✓ multi-account/multi-cluster architecture

✓ HA Argo CD control plane

✓ repository and ownership boundaries

✓ AppProject least privilege

✓ ApplicationSet placement

✓ foundation/workload separation

✓ External Secrets delivery

✓ database migration gating

✓ Argo Rollouts canary

✓ Prometheus analysis

✓ immutable CI promotion

✓ notifications and alerting

✓ backup and DR plan

✓ negative security tests

✓ release, rollback, and incident runbooks

✓ evidence-based production readiness
```

# Next — Module 14, Lesson 19

## Incident Scenarios, Interview Mastery & Never-Forget Revision

The final lesson converts the entire module into operational reflexes.

You will practice:

```text
real incidents

layered diagnosis

architecture decisions

interview answers

rapid revision

final production checklist
```

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.18.1946 Professional Mastery Workbook

This workbook expands **Production GitOps Capstone** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 54 lesson-specific anchors.
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

### Concept card 1 - Capstone objective

- Lesson anchor: Deploy the Todo application to: dev EKS staging EKS production EKS in ap-south-1 warm DR EKS in ap-southeast-1 with: no plaintext secrets in Git no CI production kubeconfig immutable image digests reviewed production promotion
- Beginner explanation: Restate **Capstone objective** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Capstone objective** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Capstone objective**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Capstone objective**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Capstone objective** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Success definition

- Lesson anchor: The project is complete only when you can prove: ---
- Beginner explanation: Restate **Success definition** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Success definition** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Success definition**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Success definition**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Success definition** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Reference AWS accounts

- Lesson anchor: 111111111111 platform/shared-services └── GitOps EKS 222222222222 non-production workloads ├── dev EKS └── staging EKS 333333333333 production workloads └── prod ap-south-1 EKS 444444444444 disaster recovery └── prod DR ap-southeast-1 EKS
- Beginner explanation: Restate **Reference AWS accounts** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reference AWS accounts** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Reference AWS accounts**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Reference AWS accounts**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Reference AWS accounts** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - Reference control-plane architecture

- Lesson anchor: GIT PROVIDER │ ▼ PLATFORM ACCOUNT GitOps EKS cluster │ Argo CD HA installation │ management IAM identity │ ┌─────────────────┼─────────────────┐ │                 │                 │ ▼                 ▼                 ▼
- Beginner explanation: Restate **Reference control-plane architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reference control-plane architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Reference control-plane architecture**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Reference control-plane architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Reference control-plane architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Three repositories

- Lesson anchor: todo-api → application source, tests, Dockerfile, CI platform-gitops → Argo CD, Projects, cluster add-ons, monitoring, secret operators workloads-gitops → Todo desired state per environment This separates: application development
- Beginner explanation: Restate **Three repositories** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Three repositories** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Three repositories**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Three repositories**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Three repositories** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Application repository

- Lesson anchor: todo-api/ │ ├── src/ ├── tests/ ├── migrations/ ├── Dockerfile ├── scripts/ │   ├── test.sh │   ├── scan-image.sh │   └── release-image.sh ├── Jenkinsfile ├── .github/workflows/build.yml └── .gitlab-ci.yml Use only the CI system chosen by your organization;...
- Beginner explanation: Restate **Application repository** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Application repository** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Application repository**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Application repository**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Application repository** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Platform repository

- Lesson anchor: platform-gitops/ │ ├── bootstrap/ │   └── root-application.yaml ├── argocd/ │   ├── values.yaml │   ├── rbac/ │   ├── projects/ │   └── notifications/ ├── add-ons/ │   ├── external-secrets/ │   ├── argo-rollouts/ │   ├── prometheus/
- Beginner explanation: Restate **Platform repository** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Platform repository** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Platform repository**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Platform repository**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Platform repository** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Workload repository

- Lesson anchor: workloads-gitops/ │ ├── apps/todo/ │   ├── base/ │   │   ├── rollout.yaml │   │   ├── services.yaml │   │   ├── analysis-template.yaml │   │   ├── migration-job.yaml │   │   ├── pdb.yaml │   │   ├── network-policy.yaml │   │   └── kustomization.yaml
- Beginner explanation: Restate **Workload repository** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Workload repository** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Workload repository**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Workload repository**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Workload repository** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Why separate foundation and workload?

- Lesson anchor: Foundation owns long-lived dependencies: Namespace ResourceQuota/LimitRange ServiceAccounts and RBAC SecretStore and ExternalSecret baseline NetworkPolicy Workload owns release-scoped resources: migration hook Rollout Services
- Beginner explanation: Restate **Why separate foundation and workload?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why separate foundation and workload?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Why separate foundation and workload?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Why separate foundation and workload?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why separate foundation and workload?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Bootstrap boundary

- Lesson anchor: The handoff follows Argo CD's declarative-setup model: infrastructure establishes the minimum control plane, then Git becomes authoritative for the managed configuration. ([Argo CD][1]) ([Argo CD][2]) Terraform creates: EKS cluster
- Beginner explanation: Restate **Bootstrap boundary** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Bootstrap boundary** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Bootstrap boundary**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Bootstrap boundary**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Bootstrap boundary** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Version inventory

- Lesson anchor: Start from the supported high-availability installation and pin the exact reviewed release used by the platform. ([Argo CD][3]) Create a release bill of materials: EKS Kubernetes version Argo CD version Argo Rollouts version
- Beginner explanation: Restate **Version inventory** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Version inventory** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Version inventory**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Version inventory**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Version inventory** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Production AppProject

- Lesson anchor: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: todo-production namespace: argocd spec: description: Todo production workloads sourceRepos: destinations: namespace: todo-prod namespace: todo-prod clusterResourceWhitelist: []
- Beginner explanation: Restate **Production AppProject** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production AppProject** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production AppProject**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production AppProject**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production AppProject** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Project role

- Lesson anchor: spec: roles: description: Observe and promote Todo production releases policies: groups: Whether manual sync is allowed depends on the chosen production process. Argo Rollout promote/abort actions need separately reviewed authorization.
- Beginner explanation: Restate **Project role** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Project role** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Project role**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Project role**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Project role** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Cluster registration labels

- Lesson anchor: Primary: metadata: labels: environment: production application-fleet: business region: ap-south-1 role: primary deploy-todo: "true" DR: metadata: labels: environment: production application-fleet: business region: ap-southeast-1
- Beginner explanation: Restate **Cluster registration labels** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Cluster registration labels** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Cluster registration labels**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Cluster registration labels**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Cluster registration labels** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Foundation ApplicationSet

- Lesson anchor: apiVersion: argoproj.io/v1alpha1 kind: ApplicationSet metadata: name: todo-foundations namespace: argocd spec: goTemplate: true goTemplateOptions: ["missingkey=error"] generators: selector: matchLabels: deploy-todo: "true"
- Beginner explanation: Restate **Foundation ApplicationSet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Foundation ApplicationSet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Foundation ApplicationSet**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Foundation ApplicationSet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Foundation ApplicationSet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Foundation ExternalSecret

- Lesson anchor: This resource stores the secret reference and delivery policy in Git while External Secrets obtains the runtime value from the configured provider. ([External Secrets][7]) apiVersion: external-secrets.io/v1 kind: ExternalSecret
- Beginner explanation: Restate **Foundation ExternalSecret** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Foundation ExternalSecret** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Foundation ExternalSecret**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Foundation ExternalSecret**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Foundation ExternalSecret** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Foundation readiness gate

- Lesson anchor: Before enabling the workload Application, verify: argocd app wait todo-foundation-prod-ap-south-1 \ --sync --health --timeout 600 kubectl get externalsecret -n todo-prod kubectl get secret todo-database -n todo-prod kubectl get serviceaccount todo-migrator...
- Beginner explanation: Restate **Foundation readiness gate** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Foundation readiness gate** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Foundation readiness gate**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Foundation readiness gate**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Foundation readiness gate** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Workload ApplicationSet

- Lesson anchor: apiVersion: argoproj.io/v1alpha1 kind: ApplicationSet metadata: name: todo-workloads namespace: argocd spec: goTemplate: true goTemplateOptions: ["missingkey=error"] generators: selector: matchLabels: deploy-todo: "true"
- Beginner explanation: Restate **Workload ApplicationSet** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Workload ApplicationSet** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Workload ApplicationSet**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Workload ApplicationSet**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Workload ApplicationSet** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Base Kustomization

- Lesson anchor: apiVersion: kustomize.config.k8s.io/v1beta1 kind: Kustomization resources: commonLabels: app.kubernetes.io/name: todo-api app.kubernetes.io/part-of: todo Do not put environment-specific secret identifiers or hostnames in the base.
- Beginner explanation: Restate **Base Kustomization** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Base Kustomization** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Base Kustomization**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Base Kustomization**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Base Kustomization** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Migration hook

- Lesson anchor: The PreSync annotation places this Job in Argo CD's pre-deployment hook phase. ([Argo CD][4]) apiVersion: batch/v1 kind: Job metadata: name: todo-db-migrate annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/hook-delete-policy: HookSucceeded
- Beginner explanation: Restate **Migration hook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Migration hook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Migration hook**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Migration hook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Migration hook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Canary Rollout

- Lesson anchor: The canary steps progressively alter exposure and pause for evidence before further promotion. ([Argo Rollouts][5]) apiVersion: argoproj.io/v1alpha1 kind: Rollout metadata: name: todo-api spec: replicas: 10 revisionHistoryLimit: 3
- Beginner explanation: Restate **Canary Rollout** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Canary Rollout** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Canary Rollout**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Canary Rollout**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Canary Rollout** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Canary Services

- Lesson anchor: apiVersion: v1 kind: Service metadata: name: todo-api-stable spec: selector: app.kubernetes.io/name: todo-api ports: port: 80 targetPort: http --- apiVersion: v1 kind: Service metadata: name: todo-api-canary spec: selector:
- Beginner explanation: Restate **Canary Services** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Canary Services** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Canary Services**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Canary Services**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Canary Services** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - AnalysisTemplate

- Lesson anchor: An AnalysisTemplate defines the measurements and success/failure conditions used by an AnalysisRun. ([Argo Rollouts][6]) apiVersion: argoproj.io/v1alpha1 kind: AnalysisTemplate metadata: name: todo-canary-safety spec: metrics:
- Beginner explanation: Restate **AnalysisTemplate** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AnalysisTemplate** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **AnalysisTemplate**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **AnalysisTemplate**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AnalysisTemplate** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Add latency evidence

- Lesson anchor: Conceptual p95 query: histogramquantile( 0.95, sum by (le) ( rate(httprequestdurationsecondsbucket{ namespace="todo-prod", rollout="todo-api", revision="canary" }[5m]) ) ) Set a threshold based on the service SLO and known metric units.
- Beginner explanation: Restate **Add latency evidence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Add latency evidence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Add latency evidence**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Add latency evidence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Add latency evidence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - PodDisruptionBudget

- Lesson anchor: apiVersion: policy/v1 kind: PodDisruptionBudget metadata: name: todo-api spec: minAvailable: 80% selector: matchLabels: app.kubernetes.io/name: todo-api Test this with Rollout surge and node-drain behavior. Ensure the percentage does not prevent normal plat...
- Beginner explanation: Restate **PodDisruptionBudget** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PodDisruptionBudget** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **PodDisruptionBudget**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **PodDisruptionBudget**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PodDisruptionBudget** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - NetworkPolicy

- Lesson anchor: Conceptual default isolation: apiVersion: networking.k8s.io/v1 kind: NetworkPolicy metadata: name: todo-api spec: podSelector: matchLabels: app.kubernetes.io/name: todo-api policyTypes: [Ingress, Egress] ingress: matchLabels:
- Beginner explanation: Restate **NetworkPolicy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **NetworkPolicy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **NetworkPolicy**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **NetworkPolicy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **NetworkPolicy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Production overlay

- Lesson anchor: apiVersion: kustomize.config.k8s.io/v1beta1 kind: Kustomization namespace: todo-prod resources: images: newName: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api digest: sha256:REPLACEWITHAPPROVEDDIGEST patches: CI changes only the digest through a re...
- Beginner explanation: Restate **Production overlay** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production overlay** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Production overlay**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Production overlay**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production overlay** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - DR overlay

- Lesson anchor: images: newName: 444444444444.dkr.ecr.ap-southeast-1.amazonaws.com/todo-api digest: sha256:SAMEAPPROVEDDIGEST The same image digest must exist in the replicated ECR registry. DR patch may set: replicas = warm-standby capacity
- Beginner explanation: Restate **DR overlay** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **DR overlay** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **DR overlay**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **DR overlay**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **DR overlay** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - CI release flow

- Lesson anchor: ---
- Beginner explanation: Restate **CI release flow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **CI release flow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **CI release flow**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **CI release flow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **CI release flow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Production PR controls

- Lesson anchor: Required checks: Kustomize build succeeds schema validation succeeds policy checks succeed digest exists in primary and DR registries signature/provenance is valid vulnerability policy passes migration compatibility declaration exists
- Beginner explanation: Restate **Production PR controls** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production PR controls** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Production PR controls**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Production PR controls**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production PR controls** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - Promotion commit

- Lesson anchor: Example: promote(todo-api): prod to a61c92f Image: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api Digest: sha256:ab12cd34... Source: a61c92f CI: https://ci.example/runs/1842 Staging evidence: https://observability.example/release/1842
- Beginner explanation: Restate **Promotion commit** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Promotion commit** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Promotion commit**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Promotion commit**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Promotion commit** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Reconciliation sequence

- Lesson anchor: config PR merged │ ▼ Git webhook / polling │ ▼ Argo detects new digest │ ▼ PreSync migration Job │ success ▼ Rollout Pod template changes │ ▼ 5% canary │ ▼ Prometheus AnalysisRun │ success ▼ 25% → analysis → 50% manual gate → 100%
- Beginner explanation: Restate **Reconciliation sequence** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Reconciliation sequence** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Reconciliation sequence**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Reconciliation sequence**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Reconciliation sequence** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Migration failure test

- Lesson anchor: Create a disposable branch whose migration exits non-zero. Prove: PreSync Job fails Rollout image remains stable Argo operation reports Failed notification arrives failed Job logs remain no destructive partial schema change occurred
- Beginner explanation: Restate **Migration failure test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Migration failure test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Migration failure test**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Migration failure test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Migration failure test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Canary failure test

- Lesson anchor: Deploy a test candidate that returns controlled 5xx responses only when a test header or flag is enabled. Send canary traffic and prove: minimum request volume reached success-rate metric fails AnalysisRun fails Rollout aborts/stops progression
- Beginner explanation: Restate **Canary failure test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Canary failure test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Canary failure test**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Canary failure test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Canary failure test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Drift test

- Lesson anchor: Manual change: kubectl scale rollout todo-api -n todo-prod --replicas=3 Expected: Argo reports OutOfSync self-heal restores declared replicas audit/event evidence records the sequence If an HPA owns replicas, design and test ignore ownership instead of expe...
- Beginner explanation: Restate **Drift test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Drift test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Drift test**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Drift test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Drift test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Secret rotation test

- Lesson anchor: Rotation is not complete until the running application uses the new value. ---
- Beginner explanation: Restate **Secret rotation test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Secret rotation test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Secret rotation test**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Secret rotation test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Secret rotation test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - Observability dashboard

- Lesson anchor: Build the Argo CD panels from the component metrics exposed for Prometheus collection. ([Argo CD][8]) Create panels for: Application sync and health status reconciliation p50/p95/p99 cluster connection and cache age repo-server render latency/restarts/memor...
- Beginner explanation: Restate **Observability dashboard** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Observability dashboard** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Observability dashboard**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Observability dashboard**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Observability dashboard** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - Alert routing

- Lesson anchor: Argo platform unavailable → platform on-call one target cluster disconnected → platform + cluster owner Todo production Degraded → Todo on-call canary AnalysisRun failed → release channel + Todo on-call secret refresh failed
- Beginner explanation: Restate **Alert routing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Alert routing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Alert routing**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Alert routing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Alert routing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Backup design

- Lesson anchor: Argo CD's disaster-recovery procedure can export and import cluster configuration, but the complete platform recovery design must also cover Git, credentials, infrastructure, images, and application data. ([Argo CD][9]) Git repositories
- Beginner explanation: Restate **Backup design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backup design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Backup design**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Backup design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backup design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - DR exercise

- Lesson anchor: Record observed time for every step. ---
- Beginner explanation: Restate **DR exercise** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **DR exercise** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **DR exercise**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **DR exercise**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **DR exercise** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Primary-region failover is more than Argo

- Lesson anchor: Argo deploys DR configuration but failover still needs: database promotion DNS/Global Accelerator/Route 53 change certificate validity secret validity queue/event topology third-party allowlists customer-session strategy
- Beginner explanation: Restate **Primary-region failover is more than Argo** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Primary-region failover is more than Argo** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Primary-region failover is more than Argo**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Primary-region failover is more than Argo**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Primary-region failover is more than Argo** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - Security test plan

- Lesson anchor: Prove denial, not only success: □ developer cannot change production overlay without owner approval □ CI cannot call production Kubernetes API □ workload Project cannot deploy to argocd namespace □ workload Project cannot create ClusterRole
- Beginner explanation: Restate **Security test plan** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Security test plan** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Security test plan**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Security test plan**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Security test plan** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - Upgrade test plan

- Lesson anchor: For Argo and add-ons: The capstone includes an upgrade rehearsal, not only initial installation. ---
- Beginner explanation: Restate **Upgrade test plan** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Upgrade test plan** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Upgrade test plan**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Upgrade test plan**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Upgrade test plan** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - Operational runbook — release

- Lesson anchor: PRE-RELEASE verify approvals, digest, health, capacity, change window RELEASE merge config PR and observe migration CANARY verify traffic volume, success, latency, dependency health PROMOTION approve indefinite pause only with evidence
- Beginner explanation: Restate **Operational runbook — release** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Operational runbook — release** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Operational runbook — release**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Operational runbook — release**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Operational runbook — release** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Operational runbook — stuck sync

- Lesson anchor: ---
- Beginner explanation: Restate **Operational runbook — stuck sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Operational runbook — stuck sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Operational runbook — stuck sync**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Operational runbook — stuck sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Operational runbook — stuck sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Operational runbook — bad release

- Lesson anchor: ---
- Beginner explanation: Restate **Operational runbook — bad release** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Operational runbook — bad release** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Operational runbook — bad release**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Operational runbook — bad release**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Operational runbook — bad release** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - Capstone test matrix

- Lesson anchor: TEST                         EXPECTED RESULT Good source release          digest promoted and canary completes Bad migration                PreSync blocks workload update Bad readiness                canary does not receive/complete traffic
- Beginner explanation: Restate **Capstone test matrix** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Capstone test matrix** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Capstone test matrix**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Capstone test matrix**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Capstone test matrix** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Evidence folder

- Lesson anchor: Store non-secret evidence: capstone-evidence/ │ ├── architecture.md ├── threat-model.md ├── versions.md ├── release-trace.md ├── test-results.md ├── screenshots/ ├── promql/ ├── runbooks/ ├── restore-report.md └── incident-review.md
- Beginner explanation: Restate **Evidence folder** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Evidence folder** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Evidence folder**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Evidence folder**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Evidence folder** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Required deliverables

- Lesson anchor: □ architecture diagram □ repository ownership model □ CODEOWNERS/branch protection design □ pinned version inventory □ Argo HA values/manifests □ AppProjects □ ApplicationSets □ foundation manifests □ workload Kustomize base/overlays
- Beginner explanation: Restate **Required deliverables** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Required deliverables** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Required deliverables**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Required deliverables**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Required deliverables** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Evaluation rubric

- Lesson anchor: 20%  GitOps correctness and ownership 15%  security and least privilege 15%  immutable build/promotion design 15%  safe migrations/progressive delivery 15%  observability and troubleshooting 10%  HA, backup, and DR 10%  documentation and evidence
- Beginner explanation: Restate **Evaluation rubric** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Evaluation rubric** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Evaluation rubric**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Evaluation rubric**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Evaluation rubric** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Common capstone shortcuts that fail

- Lesson anchor: CI runs kubectl against production image uses latest prod auto-updates to newest tag Secrets committed as base64 one default AppProject allows everything Argo cluster role is global admin without review migration drops columns before rollout
- Beginner explanation: Restate **Common capstone shortcuts that fail** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Common capstone shortcuts that fail** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Common capstone shortcuts that fail**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Common capstone shortcuts that fail**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Common capstone shortcuts that fail** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - Capstone interview walkthrough

- Lesson anchor: Explain in this order: Do not begin with a list of tools. Begin with the architecture problem they solve. ---
- Beginner explanation: Restate **Capstone interview walkthrough** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Capstone interview walkthrough** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Capstone interview walkthrough**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Capstone interview walkthrough**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Capstone interview walkthrough** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - Never-forget Capstone rules

- Lesson anchor: ---
- Beginner explanation: Restate **Never-forget Capstone rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget Capstone rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Never-forget Capstone rules**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Never-forget Capstone rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget Capstone rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - Capstone execution mnemonic

- Lesson anchor: Memorize: BOOTSTRAP ↓ AUTHORIZATION ↓ SECRETS ↓ ENVIRONMENTS ↓ LOAD / RELEASE ↓ INSIGHT ↓ NEGATIVE TESTS ↓ EVIDENCE This is the order in which to build and prove the platform. --- You have assembled: ✓ multi-account/multi-cluster architecture
- Beginner explanation: Restate **Capstone execution mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Capstone execution mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Capstone execution mnemonic**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Capstone execution mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Capstone execution mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - Capstone objective x developer experience

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Capstone objective** while a change involving **Reference control-plane architecture** places **developer experience** at risk.
- Plain-language question: What problem does **Capstone objective** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deploy the Todo application to: dev EKS staging EKS production EKS in ap-south-1 warm DR EKS in ap-southeast-1 with: no plaintext secrets in Git no CI production kubeconfig immutable image digests reviewed production promotion
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Capstone objective** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Success definition x availability

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Success definition** while a change involving **Version inventory** places **availability** at risk.
- Plain-language question: What problem does **Success definition** solve here, and who notices first when it fails?
- Lesson evidence anchor: The project is complete only when you can prove: ---
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Success definition** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Reference AWS accounts x security

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Reference AWS accounts** while a change involving **Workload ApplicationSet** places **security** at risk.
- Plain-language question: What problem does **Reference AWS accounts** solve here, and who notices first when it fails?
- Lesson evidence anchor: 111111111111 platform/shared-services └── GitOps EKS 222222222222 non-production workloads ├── dev EKS └── staging EKS 333333333333 production workloads └── prod ap-south-1 EKS 444444444444 disaster recovery └── prod DR ap-southeast-1 EKS
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Reference AWS accounts** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - Reference control-plane architecture x delivery safety

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Reference control-plane architecture** while a change involving **PodDisruptionBudget** places **delivery safety** at risk.
- Plain-language question: What problem does **Reference control-plane architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: GIT PROVIDER │ ▼ PLATFORM ACCOUNT GitOps EKS cluster │ Argo CD HA installation │ management IAM identity │ ┌─────────────────┼─────────────────┐ │                 │                 │ ▼                 ▼                 ▼
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Reference control-plane architecture** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Three repositories x multi-tenancy

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Three repositories** while a change involving **Reconciliation sequence** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Three repositories** solve here, and who notices first when it fails?
- Lesson evidence anchor: todo-api → application source, tests, Dockerfile, CI platform-gitops → Argo CD, Projects, cluster add-ons, monitoring, secret operators workloads-gitops → Todo desired state per environment This separates: application development
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Three repositories** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - Application repository x observability

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Application repository** while a change involving **Backup design** places **observability** at risk.
- Plain-language question: What problem does **Application repository** solve here, and who notices first when it fails?
- Lesson evidence anchor: todo-api/ │ ├── src/ ├── tests/ ├── migrations/ ├── Dockerfile ├── scripts/ │   ├── test.sh │   ├── scan-image.sh │   └── release-image.sh ├── Jenkinsfile ├── .github/workflows/build.yml └── .gitlab-ci.yml Use only the CI system chosen by your organization;...
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Application repository** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - Platform repository x regional resilience

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Platform repository** while a change involving **Operational runbook — bad release** places **regional resilience** at risk.
- Plain-language question: What problem does **Platform repository** solve here, and who notices first when it fails?
- Lesson evidence anchor: platform-gitops/ │ ├── bootstrap/ │   └── root-application.yaml ├── argocd/ │   ├── values.yaml │   ├── rbac/ │   ├── projects/ │   └── notifications/ ├── add-ons/ │   ├── external-secrets/ │   ├── argo-rollouts/ │   ├── prometheus/
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Platform repository** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Workload repository x business value

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Workload repository** while a change involving **Never-forget Capstone rules** places **business value** at risk.
- Plain-language question: What problem does **Workload repository** solve here, and who notices first when it fails?
- Lesson evidence anchor: workloads-gitops/ │ ├── apps/todo/ │   ├── base/ │   │   ├── rollout.yaml │   │   ├── services.yaml │   │   ├── analysis-template.yaml │   │   ├── migration-job.yaml │   │   ├── pdb.yaml │   │   ├── network-policy.yaml │   │   └── kustomization.yaml
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Workload repository** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Why separate foundation and workload? x latency

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Why separate foundation and workload?** while a change involving **Application repository** places **latency** at risk.
- Plain-language question: What problem does **Why separate foundation and workload?** solve here, and who notices first when it fails?
- Lesson evidence anchor: Foundation owns long-lived dependencies: Namespace ResourceQuota/LimitRange ServiceAccounts and RBAC SecretStore and ExternalSecret baseline NetworkPolicy Workload owns release-scoped resources: migration hook Rollout Services
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Why separate foundation and workload?** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Bootstrap boundary x privacy

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Bootstrap boundary** while a change involving **Project role** places **privacy** at risk.
- Plain-language question: What problem does **Bootstrap boundary** solve here, and who notices first when it fails?
- Lesson evidence anchor: The handoff follows Argo CD's declarative-setup model: infrastructure establishes the minimum control plane, then Git becomes authoritative for the managed configuration. ([Argo CD][1]) ([Argo CD][2]) Terraform creates: EKS cluster
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Bootstrap boundary** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Version inventory x operability

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Version inventory** while a change involving **Migration hook** places **operability** at risk.
- Plain-language question: What problem does **Version inventory** solve here, and who notices first when it fails?
- Lesson evidence anchor: Start from the supported high-availability installation and pin the exact reviewed release used by the platform. ([Argo CD][3]) Create a release bill of materials: EKS Kubernetes version Argo CD version Argo Rollouts version
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Version inventory** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Production AppProject x data integrity

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **Production AppProject** while a change involving **Production overlay** places **data integrity** at risk.
- Plain-language question: What problem does **Production AppProject** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: todo-production namespace: argocd spec: description: Todo production workloads sourceRepos: destinations: namespace: todo-prod namespace: todo-prod clusterResourceWhitelist: []
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production AppProject** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Project role x automation safety

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Project role** while a change involving **Canary failure test** places **automation safety** at risk.
- Plain-language question: What problem does **Project role** solve here, and who notices first when it fails?
- Lesson evidence anchor: spec: roles: description: Observe and promote Todo production releases policies: groups: Whether manual sync is allowed depends on the chosen production process. Argo Rollout promote/abort actions need separately reviewed authorization.
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Project role** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Cluster registration labels x governance

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Cluster registration labels** while a change involving **Primary-region failover is more than Argo** places **governance** at risk.
- Plain-language question: What problem does **Cluster registration labels** solve here, and who notices first when it fails?
- Lesson evidence anchor: Primary: metadata: labels: environment: production application-fleet: business region: ap-south-1 role: primary deploy-todo: "true" DR: metadata: labels: environment: production application-fleet: business region: ap-southeast-1
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Cluster registration labels** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Foundation ApplicationSet x correctness

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Foundation ApplicationSet** while a change involving **Evidence folder** places **correctness** at risk.
- Plain-language question: What problem does **Foundation ApplicationSet** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: argoproj.io/v1alpha1 kind: ApplicationSet metadata: name: todo-foundations namespace: argocd spec: goTemplate: true goTemplateOptions: ["missingkey=error"] generators: selector: matchLabels: deploy-todo: "true"
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Foundation ApplicationSet** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Foundation ExternalSecret x capacity

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Foundation ExternalSecret** while a change involving **Capstone objective** places **capacity** at risk.
- Plain-language question: What problem does **Foundation ExternalSecret** solve here, and who notices first when it fails?
- Lesson evidence anchor: This resource stores the secret reference and delivery policy in Git while External Secrets obtains the runtime value from the configured provider. ([External Secrets][7]) apiVersion: external-secrets.io/v1 kind: ExternalSecret
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Foundation ExternalSecret** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - Foundation readiness gate x cost efficiency

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Foundation readiness gate** while a change involving **Workload repository** places **cost efficiency** at risk.
- Plain-language question: What problem does **Foundation readiness gate** solve here, and who notices first when it fails?
- Lesson evidence anchor: Before enabling the workload Application, verify: argocd app wait todo-foundation-prod-ap-south-1 \ --sync --health --timeout 600 kubectl get externalsecret -n todo-prod kubectl get secret todo-database -n todo-prod kubectl get serviceaccount todo-migrator...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Foundation readiness gate** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Workload ApplicationSet x recovery

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Workload ApplicationSet** while a change involving **Foundation ApplicationSet** places **recovery** at risk.
- Plain-language question: What problem does **Workload ApplicationSet** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: argoproj.io/v1alpha1 kind: ApplicationSet metadata: name: todo-workloads namespace: argocd spec: goTemplate: true goTemplateOptions: ["missingkey=error"] generators: selector: matchLabels: deploy-todo: "true"
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Workload ApplicationSet** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Base Kustomization x change management

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Base Kustomization** while a change involving **Canary Services** places **change management** at risk.
- Plain-language question: What problem does **Base Kustomization** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: kustomize.config.k8s.io/v1beta1 kind: Kustomization resources: commonLabels: app.kubernetes.io/name: todo-api app.kubernetes.io/part-of: todo Do not put environment-specific secret identifiers or hostnames in the base.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Base Kustomization** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Migration hook x dependency failure

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Migration hook** while a change involving **CI release flow** places **dependency failure** at risk.
- Plain-language question: What problem does **Migration hook** solve here, and who notices first when it fails?
- Lesson evidence anchor: The PreSync annotation places this Job in Argo CD's pre-deployment hook phase. ([Argo CD][4]) apiVersion: batch/v1 kind: Job metadata: name: todo-db-migrate annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/hook-delete-policy: HookSucceeded
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Migration hook** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - Canary Rollout x developer experience

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Canary Rollout** while a change involving **Secret rotation test** places **developer experience** at risk.
- Plain-language question: What problem does **Canary Rollout** solve here, and who notices first when it fails?
- Lesson evidence anchor: The canary steps progressively alter exposure and pause for evidence before further promotion. ([Argo Rollouts][5]) apiVersion: argoproj.io/v1alpha1 kind: Rollout metadata: name: todo-api spec: replicas: 10 revisionHistoryLimit: 3
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Canary Rollout** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Canary Services x availability

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Canary Services** while a change involving **Upgrade test plan** places **availability** at risk.
- Plain-language question: What problem does **Canary Services** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: v1 kind: Service metadata: name: todo-api-stable spec: selector: app.kubernetes.io/name: todo-api ports: port: 80 targetPort: http --- apiVersion: v1 kind: Service metadata: name: todo-api-canary spec: selector:
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Canary Services** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - AnalysisTemplate x security

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **AnalysisTemplate** while a change involving **Evaluation rubric** places **security** at risk.
- Plain-language question: What problem does **AnalysisTemplate** solve here, and who notices first when it fails?
- Lesson evidence anchor: An AnalysisTemplate defines the measurements and success/failure conditions used by an AnalysisRun. ([Argo Rollouts][6]) apiVersion: argoproj.io/v1alpha1 kind: AnalysisTemplate metadata: name: todo-canary-safety spec: metrics:
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **AnalysisTemplate** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - Add latency evidence x delivery safety

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Add latency evidence** while a change involving **Reference AWS accounts** places **delivery safety** at risk.
- Plain-language question: What problem does **Add latency evidence** solve here, and who notices first when it fails?
- Lesson evidence anchor: Conceptual p95 query: histogramquantile( 0.95, sum by (le) ( rate(httprequestdurationsecondsbucket{ namespace="todo-prod", rollout="todo-api", revision="canary" }[5m]) ) ) Set a threshold based on the service SLO and known metric units.
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Add latency evidence** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - PodDisruptionBudget x multi-tenancy

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **PodDisruptionBudget** while a change involving **Bootstrap boundary** places **multi-tenancy** at risk.
- Plain-language question: What problem does **PodDisruptionBudget** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: policy/v1 kind: PodDisruptionBudget metadata: name: todo-api spec: minAvailable: 80% selector: matchLabels: app.kubernetes.io/name: todo-api Test this with Rollout surge and node-drain behavior. Ensure the percentage does not prevent normal plat...
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **PodDisruptionBudget** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - NetworkPolicy x observability

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **NetworkPolicy** while a change involving **Foundation readiness gate** places **observability** at risk.
- Plain-language question: What problem does **NetworkPolicy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Conceptual default isolation: apiVersion: networking.k8s.io/v1 kind: NetworkPolicy metadata: name: todo-api spec: podSelector: matchLabels: app.kubernetes.io/name: todo-api policyTypes: [Ingress, Egress] ingress: matchLabels:
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **NetworkPolicy** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Production overlay x regional resilience

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Production overlay** while a change involving **Add latency evidence** places **regional resilience** at risk.
- Plain-language question: What problem does **Production overlay** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: kustomize.config.k8s.io/v1beta1 kind: Kustomization namespace: todo-prod resources: images: newName: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api digest: sha256:REPLACEWITHAPPROVEDDIGEST patches: CI changes only the digest through a re...
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production overlay** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - DR overlay x business value

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **DR overlay** while a change involving **Promotion commit** places **business value** at risk.
- Plain-language question: What problem does **DR overlay** solve here, and who notices first when it fails?
- Lesson evidence anchor: images: newName: 444444444444.dkr.ecr.ap-southeast-1.amazonaws.com/todo-api digest: sha256:SAMEAPPROVEDDIGEST The same image digest must exist in the replicated ECR registry. DR patch may set: replicas = warm-standby capacity
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **DR overlay** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - CI release flow x latency

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **CI release flow** while a change involving **Alert routing** places **latency** at risk.
- Plain-language question: What problem does **CI release flow** solve here, and who notices first when it fails?
- Lesson evidence anchor: ---
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **CI release flow** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Production PR controls x privacy

- Learning level: Intermediate.
- Environment: an operator handoff.
- Scenario: The team must apply **Production PR controls** while a change involving **Operational runbook — stuck sync** places **privacy** at risk.
- Plain-language question: What problem does **Production PR controls** solve here, and who notices first when it fails?
- Lesson evidence anchor: Required checks: Kustomize build succeeds schema validation succeeds policy checks succeed digest exists in primary and DR registries signature/provenance is valid vulnerability policy passes migration compatibility declaration exists
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production PR controls** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - Promotion commit x operability

- Learning level: Expert.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Promotion commit** while a change involving **Capstone interview walkthrough** places **operability** at risk.
- Plain-language question: What problem does **Promotion commit** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: promote(todo-api): prod to a61c92f Image: 333333333333.dkr.ecr.ap-south-1.amazonaws.com/todo-api Digest: sha256:ab12cd34... Source: a61c92f CI: https://ci.example/runs/1842 Staging evidence: https://observability.example/release/1842
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Promotion commit** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Reconciliation sequence x data integrity

- Learning level: Professional.
- Environment: an operator handoff.
- Scenario: The team must apply **Reconciliation sequence** while a change involving **Three repositories** places **data integrity** at risk.
- Plain-language question: What problem does **Reconciliation sequence** solve here, and who notices first when it fails?
- Lesson evidence anchor: config PR merged │ ▼ Git webhook / polling │ ▼ Argo detects new digest │ ▼ PreSync migration Job │ success ▼ Rollout Pod template changes │ ▼ 5% canary │ ▼ Prometheus AnalysisRun │ success ▼ 25% → analysis → 50% manual gate → 100%
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Reconciliation sequence** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Migration failure test x automation safety

- Learning level: Industry-ready.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Migration failure test** while a change involving **Production AppProject** places **automation safety** at risk.
- Plain-language question: What problem does **Migration failure test** solve here, and who notices first when it fails?
- Lesson evidence anchor: Create a disposable branch whose migration exits non-zero. Prove: PreSync Job fails Rollout image remains stable Argo operation reports Failed notification arrives failed Job logs remain no destructive partial schema change occurred
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Migration failure test** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Canary failure test x governance

- Learning level: Certification review.
- Environment: an operator handoff.
- Scenario: The team must apply **Canary failure test** while a change involving **Base Kustomization** places **governance** at risk.
- Plain-language question: What problem does **Canary failure test** solve here, and who notices first when it fails?
- Lesson evidence anchor: Deploy a test candidate that returns controlled 5xx responses only when a test header or flag is enabled. Send canary traffic and prove: minimum request volume reached success-rate metric fails AnalysisRun fails Rollout aborts/stops progression
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Canary failure test** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Drift test x correctness

- Learning level: Interview defense.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Drift test** while a change involving **NetworkPolicy** places **correctness** at risk.
- Plain-language question: What problem does **Drift test** solve here, and who notices first when it fails?
- Lesson evidence anchor: Manual change: kubectl scale rollout todo-api -n todo-prod --replicas=3 Expected: Argo reports OutOfSync self-heal restores declared replicas audit/event evidence records the sequence If an HPA owns replicas, design and test ignore ownership instead of expe...
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Drift test** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Secret rotation test x capacity

- Learning level: Beginner.
- Environment: an operator handoff.
- Scenario: The team must apply **Secret rotation test** while a change involving **Migration failure test** places **capacity** at risk.
- Plain-language question: What problem does **Secret rotation test** solve here, and who notices first when it fails?
- Lesson evidence anchor: Rotation is not complete until the running application uses the new value. ---
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Secret rotation test** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - Observability dashboard x cost efficiency

- Learning level: Intermediate.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Observability dashboard** while a change involving **DR exercise** places **cost efficiency** at risk.
- Plain-language question: What problem does **Observability dashboard** solve here, and who notices first when it fails?
- Lesson evidence anchor: Build the Argo CD panels from the component metrics exposed for Prometheus collection. ([Argo CD][8]) Create panels for: Application sync and health status reconciliation p50/p95/p99 cluster connection and cache age repo-server render latency/restarts/memor...
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Observability dashboard** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Alert routing x recovery

- Learning level: Expert.
- Environment: an operator handoff.
- Scenario: The team must apply **Alert routing** while a change involving **Capstone test matrix** places **recovery** at risk.
- Plain-language question: What problem does **Alert routing** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo platform unavailable → platform on-call one target cluster disconnected → platform + cluster owner Todo production Degraded → Todo on-call canary AnalysisRun failed → release channel + Todo on-call secret refresh failed
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Alert routing** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Backup design x change management

- Learning level: Professional.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Backup design** while a change involving **Capstone execution mnemonic** places **change management** at risk.
- Plain-language question: What problem does **Backup design** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD's disaster-recovery procedure can export and import cluster configuration, but the complete platform recovery design must also cover Git, credentials, infrastructure, images, and application data. ([Argo CD][9]) Git repositories
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Backup design** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - DR exercise x dependency failure

- Learning level: Industry-ready.
- Environment: an operator handoff.
- Scenario: The team must apply **DR exercise** while a change involving **Platform repository** places **dependency failure** at risk.
- Plain-language question: What problem does **DR exercise** solve here, and who notices first when it fails?
- Lesson evidence anchor: Record observed time for every step. ---
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **DR exercise** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Primary-region failover is more than Argo x developer experience

- Learning level: Certification review.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Primary-region failover is more than Argo** while a change involving **Cluster registration labels** places **developer experience** at risk.
- Plain-language question: What problem does **Primary-region failover is more than Argo** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo deploys DR configuration but failover still needs: database promotion DNS/Global Accelerator/Route 53 change certificate validity secret validity queue/event topology third-party allowlists customer-session strategy
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Primary-region failover is more than Argo** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - Security test plan x availability

- Learning level: Interview defense.
- Environment: an operator handoff.
- Scenario: The team must apply **Security test plan** while a change involving **Canary Rollout** places **availability** at risk.
- Plain-language question: What problem does **Security test plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: Prove denial, not only success: □ developer cannot change production overlay without owner approval □ CI cannot call production Kubernetes API □ workload Project cannot deploy to argocd namespace □ workload Project cannot create ClusterRole
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Security test plan** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - Upgrade test plan x security

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **Upgrade test plan** while a change involving **DR overlay** places **security** at risk.
- Plain-language question: What problem does **Upgrade test plan** solve here, and who notices first when it fails?
- Lesson evidence anchor: For Argo and add-ons: The capstone includes an upgrade rehearsal, not only initial installation. ---
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence and link it to this practice case ID.
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
- Interview prompt: Defend **Upgrade test plan** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 43.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/ "Argo CD Documentation"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/ "Declarative Setup - Argo CD"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/ "High Availability - Argo CD"
[4]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ "Sync Phases and Waves - Argo CD"
[5]: https://argo-rollouts.readthedocs.io/en/stable/features/canary/ "Canary Strategy - Argo Rollouts"
[6]: https://argo-rollouts.readthedocs.io/en/stable/features/analysis/ "Analysis - Argo Rollouts"
[7]: https://external-secrets.io/latest/ "External Secrets Operator"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/ "Metrics - Argo CD"
[9]: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/ "Disaster Recovery - Argo CD"
