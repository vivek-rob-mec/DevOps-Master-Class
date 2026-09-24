# Lesson 10.17 — GitOps Deployment Flow with Argo CD Preview

In Lesson 10.16, you hardened Kubernetes workloads using **NetworkPolicy, Pod Security, `securityContext`, image policy, admission concepts, and runtime safety**.

Now we move to **GitOps**.

Until now, many lessons used:

```bash
kubectl apply -f ...
kubectl apply -k ...
helm install ...
helm upgrade ...
```

That is useful for learning, but production teams usually want a safer model:

```text
Git is the source of truth.
Pull request reviews change desired state.
A GitOps controller reconciles the cluster to match Git.
Rollback is usually a Git revert, not manual cluster editing.
```

Argo CD is a Kubernetes GitOps controller that compares desired manifests from Git with live cluster state and can sync the cluster to match Git. Its automated sync mode lets CI/CD update Git instead of requiring direct access to the Argo CD API server or the Kubernetes cluster. ([Argo CD][1])

---

# 1. What We Will Cover

```text
10.17.1   GitOps mental model
10.17.2   Push CD vs pull-based GitOps
10.17.3   Argo CD architecture
10.17.4   Installing Argo CD
10.17.5   Accessing Argo CD UI
10.17.6   Argo CD Application CRD
10.17.7   repoURL, path, targetRevision, destination
10.17.8   sync status vs health status
10.17.9   manual sync
10.17.10  automated sync
10.17.11  prune
10.17.12  self-heal
10.17.13  sync options
10.17.14  AppProject
10.17.15  demo-node-api GitOps layout
10.17.16  dev/staging/production promotion flow
10.17.17  rollback by Git revert
10.17.18  production GitOps rules
10.17.19  validation script
10.17.20  cleanup script
```

---

# 2. Create Lesson Folder

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.17-gitops-argocd-preview/{manifests,applications,projects,scripts,notes,runbooks,reports}
```

Check:

```bash
tree -L 2 10.17-gitops-argocd-preview
```

---

# 3. GitOps Mental Model

Traditional CI/CD often works like this:

```text
CI/CD pipeline
  ↓
kubectl apply / helm upgrade
  ↓
cluster changes
```

GitOps works more like this:

```text
Developer changes Kubernetes desired state in Git
  ↓
Pull request review
  ↓
Merge to main
  ↓
Argo CD detects Git change
  ↓
Argo CD compares Git state vs cluster state
  ↓
Argo CD syncs cluster to Git
```

The biggest mindset shift:

```text
Do not treat the cluster as the source of truth.
Treat Git as the source of truth.
```

Production meaning:

```text
If someone manually edits a Deployment in the cluster,
Argo CD can show OutOfSync.

If self-heal is enabled,
Argo CD can revert the manual change back to Git state.
```

---

# 4. Push CD vs Pull-Based GitOps

## Push CD

```text
Jenkins / GitHub Actions / GitLab CI
  has kubeconfig or cloud credentials
  pushes changes into cluster
```

Pros:

```text
simple to understand
fast to start
works with existing pipelines
```

Risks:

```text
CI/CD system needs cluster write credentials
manual cluster drift can go unnoticed
rollback history may be split between CI logs and cluster state
```

## Pull-Based GitOps

```text
Argo CD runs inside or near the cluster
  watches Git
  pulls desired state
  applies to cluster
```

Pros:

```text
cluster access can be reduced from CI/CD
Git history becomes deployment history
drift is visible
rollback by Git revert is natural
declarative deployment flow
```

Risk:

```text
bad Git commit can still break production if review/policy is weak
```

Production rule:

```text
GitOps does not replace review, tests, policy, and observability.
It makes desired state reconciliation safer and more auditable.
```

---

# 5. Argo CD Architecture

Basic Argo CD components:

```text
argocd-server:
  UI and API server

application-controller:
  watches Applications and reconciles desired/live state

repo-server:
  clones Git repositories and renders manifests

redis:
  cache/session support

dex:
  optional identity provider integration
```

Core object:

```text
Application:
  tells Argo CD which Git repo/path/revision to deploy,
  and which cluster/namespace to deploy into
```

Simple flow:

```text
Git repo
  ↓
repo-server renders manifests
  ↓
application-controller compares desired vs live state
  ↓
sync operation applies changes
  ↓
Application shows sync/health status
```

---

# 6. Install Argo CD

The official getting-started guide installs Argo CD by creating the `argocd` namespace and applying the official stable install manifest; it also recommends pinning a version for production instead of relying on the moving stable branch. ([Argo CD][2])

For this learning lab:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait:

```bash
kubectl get pods -n argocd -w
```

Or:

```bash
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
```

Check:

```bash
kubectl get all -n argocd
kubectl get crd | grep argoproj
```

You should see CRDs such as:

```text
applications.argoproj.io
applicationsets.argoproj.io
appprojects.argoproj.io
```

---

# 7. Access Argo CD UI

By default, Argo CD is not exposed outside the cluster; the official guide lists options such as LoadBalancer, Ingress, or port-forwarding for access. ([Argo CD][2])

For local kind:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```text
https://127.0.0.1:8080
```

The browser will warn about a self-signed certificate. For local lab, continue safely.

Get initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

Username:

```text
admin
```

Production rule:

```text
Do not keep the default admin password.
Use SSO, RBAC, TLS, and restricted access for production Argo CD.
```

The official guide states that the initial admin password is stored in the `argocd-initial-admin-secret` secret and can also be retrieved using the Argo CD CLI. ([Argo CD][2])

---

# 8. Install Argo CD CLI — Optional

Check if installed:

```bash
argocd version --client
```

On WSL/Linux, one option is:

```bash
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

rm argocd-linux-amd64

argocd version --client
```

Login through port-forward:

```bash
argocd login 127.0.0.1:8080 \
  --username admin \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)" \
  --insecure
```

Check:

```bash
argocd app list
```

---

# 9. Application CRD Mental Model

An Argo CD `Application` answers:

```text
Where is the desired state?
Which revision should be used?
Which path inside the repo should be deployed?
Which cluster should receive it?
Which namespace should receive it?
Should sync be manual or automatic?
Should removed Git resources be pruned?
Should manual cluster drift be self-healed?
```

A typical `Application` has:

```yaml
spec:
  source:
    repoURL: ...
    targetRevision: ...
    path: ...
  destination:
    server: ...
    namespace: ...
  syncPolicy:
    ...
```

Argo CD’s Application specification reference documents `syncPolicy`, including automated sync settings such as `enabled`, `prune`, and related fields. ([Argo CD][3])

---

# 10. Create GitOps Repo Layout

Inside your existing repo, create a GitOps folder:

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p gitops/demo-node-api/{dev,staging,production}
mkdir -p gitops/argocd/{applications,projects}
```

We will point GitOps environments to the Kustomize overlays created in Lesson 10.13.

Create environment README:

```bash
nano gitops/demo-node-api/README.md
```

Paste:

```markdown
# demo-node-api GitOps Layout

This folder documents the GitOps deployment flow for demo-node-api.

## Source of Truth

The Kubernetes desired state is stored in Git.

## Environments

- dev
- staging
- production

## Deployment Tool

Argo CD

## Manifest Strategy

Kustomize overlays:

- apps/demo-node-api/overlays/dev
- apps/demo-node-api/overlays/staging
- apps/demo-node-api/overlays/production

## Promotion Rule

Build once.
Promote the same image tag or digest from dev to staging to production.
```

---

# 11. Create AppProject

Argo CD `AppProject` is useful for grouping applications and limiting what they can deploy.

Create:

```bash
nano gitops/argocd/projects/demo-node-api-project.yaml
```

Paste:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: demo-node-api
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: gitops-project
spec:
  description: Project for demo-node-api GitOps deployments

  sourceRepos:
    - "*"

  destinations:
    - namespace: dev
      server: https://kubernetes.default.svc
    - namespace: staging
      server: https://kubernetes.default.svc
    - namespace: production
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ""
      kind: Namespace

  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
```

Apply:

```bash
kubectl apply -f gitops/argocd/projects/demo-node-api-project.yaml
```

Check:

```bash
kubectl get appproject -n argocd
kubectl describe appproject demo-node-api -n argocd
```

Production note:

```text
For real production, avoid sourceRepos: "*".
Pin allowed repositories explicitly.
Also restrict destinations and allowed resource kinds carefully.
```

---

# 12. Create Dev Argo CD Application

Replace this placeholder:

```text
YOUR_GIT_REPO_URL
```

with your real Git repository URL, for example:

```text
https://github.com/<your-username>/devops-masterclass.git
```

Create:

```bash
nano gitops/argocd/applications/demo-node-api-dev.yaml
```

Paste:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-dev
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: dev
spec:
  project: demo-node-api

  source:
    repoURL: YOUR_GIT_REPO_URL
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: dev

  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

Important:

```text
This is manual-sync mode.
Argo CD will detect drift, but it will not automatically apply changes.
```

Apply:

```bash
kubectl apply -f gitops/argocd/applications/demo-node-api-dev.yaml
```

Check:

```bash
kubectl get applications -n argocd
kubectl describe application demo-node-api-dev -n argocd
```

With CLI:

```bash
argocd app get demo-node-api-dev
```

---

# 13. Sync Dev Application Manually

In UI:

```text
Applications
  → demo-node-api-dev
  → Sync
```

CLI:

```bash
argocd app sync demo-node-api-dev
```

Wait:

```bash
argocd app wait demo-node-api-dev --health --sync --timeout 180
```

Check Kubernetes resources:

```bash
kubectl get deploy,svc,ingress,hpa,pdb -n dev | grep demo-node-api || true
kubectl get application demo-node-api-dev -n argocd
```

If sync fails, inspect:

```bash
argocd app get demo-node-api-dev
argocd app events demo-node-api-dev
kubectl describe application demo-node-api-dev -n argocd
```

Common failure:

```text
repoURL placeholder was not replaced
path is wrong
repo is private and not configured
ServiceMonitor CRD missing
image is unavailable
secret does not exist
```

---

# 14. ServiceMonitor CRD Problem

From Lesson 10.15, your `demo-node-api` base includes:

```text
servicemonitor.yaml
```

If kube-prometheus-stack is not installed, this CRD may not exist:

```bash
kubectl get crd servicemonitors.monitoring.coreos.com
```

If missing, Argo CD sync may fail because Kubernetes does not know `ServiceMonitor`.

For this lab, choose one option.

Option A — install kube-prometheus-stack:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring
```

Option B — temporarily remove `servicemonitor.yaml` from the `apps/demo-node-api/base/kustomization.yaml` while practicing Argo CD.

Option C — create separate overlays where observability resources are included only when monitoring CRDs exist.

Production rule:

```text
Do not let optional CRDs break base application deployment.
Separate optional platform integrations or use sync options carefully.
```

Argo CD has sync options such as `SkipDryRunOnMissingResource=true`, but use it carefully because it can hide real mistakes. Sync options are configured under `spec.syncPolicy.syncOptions` or resource annotations. ([Argo CD][4])

---

# 15. Sync Status vs Health Status

Argo CD shows two important statuses.

## Sync Status

Question:

```text
Does live cluster state match desired Git state?
```

Common values:

```text
Synced
OutOfSync
Unknown
```

## Health Status

Question:

```text
Are the Kubernetes resources healthy?
```

Common values:

```text
Healthy
Progressing
Degraded
Suspended
Missing
Unknown
```

Important examples:

```text
Synced + Healthy:
  Git and cluster match, app is healthy.

Synced + Degraded:
  Git and cluster match, but app is broken.

OutOfSync + Healthy:
  app may be running fine, but live state differs from Git.

OutOfSync + Degraded:
  drift exists and app is unhealthy.
```

Production rule:

```text
Synced does not always mean healthy.
Healthy does not always mean synced.
Check both.
```

---

# 16. Manual Drift Demo

After Argo CD syncs the dev app, manually change replicas:

```bash
kubectl scale deployment demo-node-api -n dev --replicas=5
```

Check:

```bash
argocd app get demo-node-api-dev
kubectl get application demo-node-api-dev -n argocd
```

Expected:

```text
Application becomes OutOfSync.
```

Why?

```text
Git says one replica in dev overlay.
Cluster now has five replicas.
```

Fix by syncing:

```bash
argocd app sync demo-node-api-dev
```

Or through UI:

```text
demo-node-api-dev → Sync
```

Production lesson:

```text
Manual kubectl changes create drift.
GitOps makes drift visible.
```

---

# 17. Automated Sync

Automated sync means Argo CD can apply Git changes automatically when desired state differs from live state.

Argo CD’s automated sync documentation says it can automatically sync when it detects differences between manifests in Git and live cluster state; this allows CI/CD to deploy by committing changes to the tracking repo instead of calling Argo CD directly. ([Argo CD][1])

Create auto-sync Application for dev:

```bash
nano gitops/argocd/applications/demo-node-api-dev-auto.yaml
```

Paste:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-dev-auto
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: dev
spec:
  project: demo-node-api

  source:
    repoURL: YOUR_GIT_REPO_URL
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: dev

  syncPolicy:
    automated:
      enabled: true
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

Do not apply both `demo-node-api-dev` and `demo-node-api-dev-auto` to the same resources at the same time unless you are intentionally testing. Prefer one Application per environment/resource set.

---

# 18. Prune

Prune means:

```text
If a resource is removed from Git,
Argo CD can delete it from the cluster.
```

By default, Argo CD automated sync does not delete resources that disappeared from Git as a safety mechanism; automatic pruning must be enabled explicitly. ([Argo CD][1])

Example:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: true
```

Production warning:

```text
Prune is powerful.
A bad commit can delete resources.
Use PR review, branch protection, and environment-specific rules.
```

Safe production pattern:

```text
dev:
  automated sync + prune allowed

staging:
  automated sync + prune allowed after confidence

production:
  manual sync or automated sync with strong review/policy
  prune used carefully
```

---

# 19. Self-Heal

Self-heal means:

```text
If someone manually changes live cluster state,
Argo CD can automatically restore it to Git state.
```

Argo CD documents that live cluster changes do not trigger automated sync by default; self-healing must be enabled with `selfHeal: true`. ([Argo CD][1])

Example:

```yaml
syncPolicy:
  automated:
    enabled: true
    prune: true
    selfHeal: true
```

Production meaning:

```text
Manual kubectl edits are temporary.
Git wins.
```

Good:

```text
prevents silent drift
keeps cluster aligned to approved Git state
```

Risk:

```text
emergency manual fixes may be reverted
```

Production rule:

```text
If self-heal is enabled, emergency fixes should be committed to Git quickly.
```

---

# 20. Create Staging Application

Create:

```bash
nano gitops/argocd/applications/demo-node-api-staging.yaml
```

Paste:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-staging
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: staging
spec:
  project: demo-node-api

  source:
    repoURL: YOUR_GIT_REPO_URL
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/staging

  destination:
    server: https://kubernetes.default.svc
    namespace: staging

  syncPolicy:
    automated:
      enabled: true
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply after replacing repo URL:

```bash
kubectl apply -f gitops/argocd/applications/demo-node-api-staging.yaml
```

Check:

```bash
argocd app get demo-node-api-staging
```

---

# 21. Create Production Application

For production, start with manual sync.

Create:

```bash
nano gitops/argocd/applications/demo-node-api-production.yaml
```

Paste:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-node-api-production
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: production
spec:
  project: demo-node-api

  source:
    repoURL: YOUR_GIT_REPO_URL
    targetRevision: main
    path: 10-kubernetes-production-operations/apps/demo-node-api/overlays/production

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

Apply after replacing repo URL:

```bash
kubectl apply -f gitops/argocd/applications/demo-node-api-production.yaml
```

Production rule:

```text
Start production with manual sync.
Move to automated sync only after your tests, policies, rollback flow, and monitoring are mature.
```

---

# 22. Create Application Summary Script

Create:

```bash
nano 10.17-gitops-argocd-preview/scripts/argocd-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Argo CD Summary ====="

echo
echo "Argo CD namespace:"
kubectl get namespace argocd || true

echo
echo "Argo CD pods:"
kubectl get pods -n argocd || true

echo
echo "Argo CD services:"
kubectl get svc -n argocd || true

echo
echo "Argo CD CRDs:"
kubectl get crd | grep argoproj || true

echo
echo "AppProjects:"
kubectl get appprojects -n argocd || true

echo
echo "Applications:"
kubectl get applications -n argocd || true

echo
echo "Application details:"
for app in $(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
  echo
  echo "---- $app ----"
  kubectl get application "$app" -n argocd \
    -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision \
    --no-headers || true
done

echo
echo "demo-node-api resources:"
kubectl get deploy,svc,ingress,hpa,pdb -n dev 2>/dev/null | grep demo-node-api || true
kubectl get deploy,svc,ingress,hpa,pdb -n staging 2>/dev/null | grep demo-node-api || true
kubectl get deploy,svc,ingress,hpa,pdb -n production 2>/dev/null | grep demo-node-api || true
```

Make executable:

```bash
chmod +x 10.17-gitops-argocd-preview/scripts/argocd-summary.sh
```

Run:

```bash
./10.17-gitops-argocd-preview/scripts/argocd-summary.sh
```

---

# 23. Create GitOps Promotion Runbook

Create:

```bash
nano 10.17-gitops-argocd-preview/runbooks/gitops-promotion-runbook.md
```

Paste:

````markdown
# GitOps Promotion Runbook

## Goal

Promote the same tested image across dev, staging, and production using Git.

## Rule

Build once. Promote the same image tag or digest.

## Flow

1. CI builds image from commit.
2. CI scans image.
3. CI pushes immutable image tag and digest.
4. Pull request updates dev overlay image tag.
5. Merge PR.
6. Argo CD syncs dev.
7. Smoke tests pass.
8. Pull request updates staging overlay to same tag/digest.
9. Merge PR.
10. Argo CD syncs staging.
11. Integration tests pass.
12. Pull request updates production overlay to same tag/digest.
13. Approval.
14. Argo CD syncs production.
15. Watch metrics, logs, alerts, and rollout.

## Kustomize Image Promotion

```yaml
images:
  - name: demo-node-api
    newTag: 1.4.2
````

## Production Rollback

Preferred GitOps rollback:

```bash
git revert <bad_commit>
git push
```

Then Argo CD syncs the reverted desired state.

## Emergency Rule

If manual kubectl is used during an incident, create a follow-up Git commit immediately.
Git must become the source of truth again.

````

---

# 24. Rollback by Git Revert

Bad rollback habit:

```bash
kubectl rollout undo deployment/demo-node-api -n production
````

This can work in an emergency, but it creates drift from Git.

GitOps rollback:

```bash
git log --oneline
git revert <bad_commit_sha>
git push
```

Then:

```bash
argocd app sync demo-node-api-production
```

or if automated sync is enabled:

```text
Argo CD detects revert commit and reconciles automatically.
```

Production explanation:

```text
In GitOps, rollback means changing desired state in Git back to a known-good version.
The cluster follows Git.
```

---

# 25. Manual Sync vs Automated Sync Strategy

## Dev

```yaml
automated:
  enabled: true
  prune: true
  selfHeal: true
```

Why:

```text
fast feedback
safe enough for development
drift should be corrected
```

## Staging

```yaml
automated:
  enabled: true
  prune: true
  selfHeal: true
```

Why:

```text
should behave like production
but still safe enough for automation
```

## Production

Start with:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

Meaning:

```text
manual sync
human approves sync after PR merge
```

Later, after maturity:

```yaml
automated:
  enabled: true
  prune: true
  selfHeal: true
```

with:

```text
branch protection
required reviews
CI validation
image scanning
policy-as-code
progressive delivery
alerts
rollback runbook
```

---

# 26. Argo CD Sync Options

Sync options customize how Argo CD applies desired state. Argo CD documents that most sync options are configured under `spec.syncPolicy.syncOptions`, while some can also be defined as annotations on resources. ([Argo CD][4])

Useful examples:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - PruneLast=true
```

Common options to know:

```text
CreateNamespace=true:
  create destination namespace if missing

PruneLast=true:
  prune after other resources sync

Prune=false:
  prevent pruning of selected resources

SkipDryRunOnMissingResource=true:
  useful when CRDs may not exist yet, but use carefully

ServerSideApply=true:
  use server-side apply
```

Production rule:

```text
Use sync options intentionally.
Do not add options just to silence errors without understanding root cause.
```

---

# 27. GitOps Validation Before Merge

Before merging a GitOps PR, run local validation:

```bash
kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-dev.yaml
kubectl kustomize apps/demo-node-api/overlays/staging >/tmp/demo-node-api-staging.yaml
kubectl kustomize apps/demo-node-api/overlays/production >/tmp/demo-node-api-production.yaml
```

Validate YAML:

```bash
kubectl apply --dry-run=client -f /tmp/demo-node-api-dev.yaml
kubectl apply --dry-run=client -f /tmp/demo-node-api-staging.yaml
kubectl apply --dry-run=client -f /tmp/demo-node-api-production.yaml
```

If the cluster has all CRDs:

```bash
kubectl apply --dry-run=server -f /tmp/demo-node-api-dev.yaml
```

Production CI should run:

```text
kustomize build
yaml validation
kubeconform or kubeval
policy checks
security checks
image tag/digest check
Argo CD app manifest validation
```

---

# 28. Create GitOps Validation Script

Create:

```bash
nano 10.17-gitops-argocd-preview/scripts/validate-gitops-manifests.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate GitOps Manifests ====="

ROOT="$(pwd)"

for env in dev staging production; do
  echo
  echo "Rendering demo-node-api overlay: $env"

  kubectl kustomize "apps/demo-node-api/overlays/$env" \
    > "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"

  grep -q "kind: Deployment" "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"
  grep -q "kind: Service" "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"
  grep -q "kind: HorizontalPodAutoscaler" "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"
  grep -q "kind: PodDisruptionBudget" "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"
  grep -q "kind: NetworkPolicy" "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml"

  kubectl apply --dry-run=client \
    -f "10.17-gitops-argocd-preview/reports/demo-node-api-$env-rendered.yaml" >/dev/null

  echo "$env overlay validation passed."
done

for app_file in gitops/argocd/applications/*.yaml; do
  echo
  echo "Validating Argo CD Application manifest: $app_file"
  grep -q "kind: Application" "$app_file"
  grep -q "repoURL:" "$app_file"
  grep -q "targetRevision:" "$app_file"
  grep -q "path:" "$app_file"
  grep -q "destination:" "$app_file"
done

echo
echo "GitOps manifest validation passed."
```

Make executable:

```bash
chmod +x 10.17-gitops-argocd-preview/scripts/validate-gitops-manifests.sh
```

Run:

```bash
./10.17-gitops-argocd-preview/scripts/validate-gitops-manifests.sh
```

---

# 29. Create Argo CD Debugging Runbook

Create:

```bash
nano 10.17-gitops-argocd-preview/runbooks/argocd-debugging-runbook.md
```

Paste:

````markdown
# Argo CD Debugging Runbook

## Step 1 — Check Argo CD Components

```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
````

## Step 2 — Check Applications

```bash
kubectl get applications -n argocd
kubectl describe application APP_NAME -n argocd
```

With CLI:

```bash
argocd app list
argocd app get APP_NAME
```

## Step 3 — Check Sync and Health

Look for:

* Synced
* OutOfSync
* Healthy
* Progressing
* Degraded
* Missing

## Step 4 — Check Repo and Path

Common errors:

* wrong repoURL
* private repo not configured
* wrong path
* wrong branch
* invalid Kustomize/Helm rendering
* missing CRD

## Step 5 — Check Destination

Common errors:

* namespace missing
* CreateNamespace not enabled
* project does not allow destination
* cluster not registered
* RBAC issue

## Step 6 — Check Kubernetes Resources

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
kubectl get pods -n NAMESPACE
kubectl describe pod POD_NAME -n NAMESPACE
```

## Common Root Causes

| Symptom               | Likely Cause                         |
| --------------------- | ------------------------------------ |
| App Unknown           | controller/repo issue                |
| OutOfSync             | Git differs from cluster             |
| Degraded              | Kubernetes resources unhealthy       |
| Sync failed           | manifest, RBAC, CRD, or policy issue |
| Repo error            | bad URL, auth, branch, or path       |
| Resource missing      | prune or path issue                  |
| App stuck Progressing | rollout not healthy                  |

## Golden Rule

Argo CD tells you desired-vs-live state.
Kubernetes events/logs tell you why resources are unhealthy.

````

---

# 30. Create GitOps Production Rules Note

Create:

```bash
nano 10.17-gitops-argocd-preview/notes/production-gitops-rules.md
````

Paste:

````markdown
# Production GitOps Rules

## Source of Truth

Git is the source of truth.

## Do

- use pull requests for changes
- protect production branches
- require CI validation
- require security and policy checks
- promote the same image tag or digest
- use Argo CD Projects to limit blast radius
- use manual sync for production until mature
- use automated sync carefully
- use self-heal only with strong operational discipline
- use prune carefully
- document rollback procedure
- monitor sync and health status

## Do Not

- manually edit production resources without follow-up Git commit
- give CI/CD broad cluster-admin access
- use latest tags
- store real secrets unencrypted in Git
- allow all repos and all destinations in production projects
- ignore OutOfSync applications
- treat Synced as equal to Healthy

## Rollback

Preferred rollback:

```bash
git revert <bad_commit>
git push
````

Then Argo CD reconciles the cluster.

````

---

# 31. Create demo-node-api GitOps Policy

Create:

```bash
nano 10.17-gitops-argocd-preview/notes/demo-node-api-gitops-policy.md
````

Paste:

```markdown
# demo-node-api GitOps Policy

## Application

demo-node-api

## Desired State

Stored in Git under:

- apps/demo-node-api/base
- apps/demo-node-api/overlays/dev
- apps/demo-node-api/overlays/staging
- apps/demo-node-api/overlays/production

## GitOps Controller

Argo CD

## Environments

dev:
  automated sync allowed
  prune allowed
  self-heal allowed

staging:
  automated sync allowed after validation
  prune allowed
  self-heal allowed

production:
  manual sync at first
  automated sync only after maturity

## Promotion

Build once and promote the same image tag or digest.

## Rollback

Rollback by Git revert.

## Emergency Manual Changes

Allowed only during incident response.
Must be followed by Git commit to restore source of truth.
```

---

# 32. Validation Script

Create:

```bash
nano 10.17-gitops-argocd-preview/scripts/validate-lesson-10-17.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.17 ====="

kubectl version --client >/dev/null

kubectl get namespace argocd >/dev/null
kubectl get deployment argocd-server -n argocd >/dev/null
kubectl get deployment argocd-repo-server -n argocd >/dev/null
kubectl get statefulset argocd-application-controller -n argocd >/dev/null

kubectl get crd applications.argoproj.io >/dev/null
kubectl get crd appprojects.argoproj.io >/dev/null

test -f gitops/argocd/projects/demo-node-api-project.yaml
test -f gitops/argocd/applications/demo-node-api-dev.yaml
test -f gitops/argocd/applications/demo-node-api-staging.yaml
test -f gitops/argocd/applications/demo-node-api-production.yaml

grep -q "kind: AppProject" gitops/argocd/projects/demo-node-api-project.yaml
grep -q "kind: Application" gitops/argocd/applications/demo-node-api-dev.yaml
grep -q "kind: Application" gitops/argocd/applications/demo-node-api-staging.yaml
grep -q "kind: Application" gitops/argocd/applications/demo-node-api-production.yaml

test -x 10.17-gitops-argocd-preview/scripts/argocd-summary.sh
test -x 10.17-gitops-argocd-preview/scripts/validate-gitops-manifests.sh

test -f 10.17-gitops-argocd-preview/notes/production-gitops-rules.md
test -f 10.17-gitops-argocd-preview/notes/demo-node-api-gitops-policy.md
test -f 10.17-gitops-argocd-preview/runbooks/gitops-promotion-runbook.md
test -f 10.17-gitops-argocd-preview/runbooks/argocd-debugging-runbook.md

kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-gitops-dev.yaml
grep -q "kind: Deployment" /tmp/demo-node-api-gitops-dev.yaml
grep -q "kind: Service" /tmp/demo-node-api-gitops-dev.yaml
grep -q "kind: HorizontalPodAutoscaler" /tmp/demo-node-api-gitops-dev.yaml
grep -q "kind: PodDisruptionBudget" /tmp/demo-node-api-gitops-dev.yaml

./10.17-gitops-argocd-preview/scripts/validate-gitops-manifests.sh >/tmp/gitops-validation.log

if grep -R "YOUR_GIT_REPO_URL" gitops/argocd/applications >/dev/null 2>&1; then
  echo "WARNING: Replace YOUR_GIT_REPO_URL before applying Argo CD Applications."
fi

echo "Lesson 10.17 validation passed."
```

Make executable:

```bash
chmod +x 10.17-gitops-argocd-preview/scripts/validate-lesson-10-17.sh
```

Run:

```bash
./10.17-gitops-argocd-preview/scripts/validate-lesson-10-17.sh
```

---

# 33. Cleanup Script

Create:

```bash
nano 10.17-gitops-argocd-preview/scripts/cleanup-lesson-10-17.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.17 ====="

kubectl delete -f gitops/argocd/applications/demo-node-api-production.yaml --ignore-not-found=true
kubectl delete -f gitops/argocd/applications/demo-node-api-staging.yaml --ignore-not-found=true
kubectl delete -f gitops/argocd/applications/demo-node-api-dev-auto.yaml --ignore-not-found=true
kubectl delete -f gitops/argocd/applications/demo-node-api-dev.yaml --ignore-not-found=true
kubectl delete -f gitops/argocd/projects/demo-node-api-project.yaml --ignore-not-found=true

echo
echo "Argo CD applications/project removed."
echo "Argo CD itself is kept because it is useful for the next lesson/capstone."
echo
echo "To uninstall Argo CD completely:"
echo "kubectl delete namespace argocd"
```

Make executable:

```bash
chmod +x 10.17-gitops-argocd-preview/scripts/cleanup-lesson-10-17.sh
```

Run only if needed:

```bash
./10.17-gitops-argocd-preview/scripts/cleanup-lesson-10-17.sh
```

To uninstall Argo CD completely:

```bash
kubectl delete namespace argocd
```

---

# 34. Practical Lab Summary

Run the main lab:

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s
```

Prepare manifests:

```bash
kubectl apply -f gitops/argocd/projects/demo-node-api-project.yaml
```

Replace repo placeholders:

```bash
grep -R "YOUR_GIT_REPO_URL" gitops/argocd/applications
```

Edit each Application file:

```bash
nano gitops/argocd/applications/demo-node-api-dev.yaml
nano gitops/argocd/applications/demo-node-api-staging.yaml
nano gitops/argocd/applications/demo-node-api-production.yaml
```

Apply dev app:

```bash
kubectl apply -f gitops/argocd/applications/demo-node-api-dev.yaml
```

Access UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Get password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

Validate:

```bash
./10.17-gitops-argocd-preview/scripts/argocd-summary.sh
./10.17-gitops-argocd-preview/scripts/validate-lesson-10-17.sh
```

---

# 35. Common Myths and Misconceptions

## Myth 1: GitOps means no CI/CD

Wrong.

```text
CI still builds, tests, scans, and publishes artifacts.
GitOps controls deployment reconciliation.
```

## Myth 2: Argo CD replaces Kubernetes controllers

Wrong.

```text
Argo CD reconciles Git desired state to Kubernetes objects.
Kubernetes controllers still reconcile Deployments, Pods, Services, HPAs, and other resources.
```

## Myth 3: Synced means the app is healthy

Wrong.

```text
Synced means Git and cluster match.
Health tells whether resources are operational.
```

## Myth 4: Automated sync is always safe

Wrong.

```text
Automated sync is only as safe as your Git review, validation, policy, tests, and rollback flow.
```

## Myth 5: Prune should always be enabled

Not always.

```text
Prune can delete resources removed from Git.
Use it carefully, especially for production.
```

## Myth 6: Manual kubectl is forbidden forever

In emergencies, manual action may be needed.

But:

```text
After manual action, update Git immediately.
Otherwise drift remains.
```

## Myth 7: Rollback means clicking rollback in UI only

In GitOps, preferred rollback is:

```text
Git revert
merge
sync
```

---

# 36. Production GitOps Rules

```text
Git is the source of truth.
Use pull requests for desired state changes.
Protect production branches.
Validate manifests before merge.
Use policy checks before merge.
Promote the same image tag/digest across environments.
Use Argo CD Projects to restrict repos and destinations.
Use manual production sync until mature.
Use automated sync carefully.
Use prune carefully.
Use self-heal only with clear incident process.
Do not store plaintext production secrets in Git.
Use External Secrets, SOPS, Sealed Secrets, or cloud secret manager integrations.
Monitor Argo CD sync and health status.
Rollback by Git revert.
```

---

# 37. Interview Explanation

Use this:

```text
GitOps means the desired state of Kubernetes applications is stored in Git and reconciled into the cluster by an operator such as Argo CD. Instead of CI/CD directly applying manifests with cluster credentials, the pipeline updates Git with the new image tag or manifest change. Argo CD compares the desired Git state with the live cluster state and reports whether the application is Synced or OutOfSync, and whether it is Healthy or Degraded.

For production, I use pull requests, CI validation, image scanning, policy checks, and protected branches before changes reach Git. I usually start production with manual sync, then enable automated sync only after the team has mature validation, monitoring, and rollback processes. Rollback is typically done by reverting the Git commit so the cluster returns to a known-good desired state.
```

Resume version:

```text
Implemented GitOps deployment flow with Argo CD, including Application and AppProject manifests, Kustomize-based dev/staging/production overlays, manual and automated sync policies, prune/self-heal concepts, drift detection, Git-based promotion, rollback-by-revert runbooks, and production GitOps policy for demo-node-api.
```

---

# 38. Today’s Core Rules

```text
Git is desired state.
Cluster is live state.
Argo CD compares desired vs live.
Sync applies Git state to cluster.
OutOfSync means Git and cluster differ.
Healthy means Kubernetes resources are operational.
Synced does not always mean Healthy.
Manual kubectl creates drift.
Self-heal can revert drift.
Prune can delete resources removed from Git.
CI builds and updates Git.
Argo CD deploys from Git.
Rollback should usually be Git revert.
Production GitOps needs PR review, validation, policy, and observability.
```

---

# 39. Commit Lesson 10.17

From repo root:

```bash
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes GitOps Argo CD deployment flow lesson"

git push
```

---

# Next Lesson

```text
Lesson 10.18 — Module 10 Capstone: Production-Grade Kubernetes Deployment for demo-node-api
```

We will combine everything from Module 10:

```text
namespace structure
Deployment
Service
Ingress
ConfigMap
Secret
ServiceAccount
RBAC posture
probes
resources
securityContext
NetworkPolicy
HPA
PDB
ServiceMonitor
Kustomize overlays
Argo CD Application
validation scripts
smoke tests
rollback runbook
production README
resume-ready project summary
```

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/ "Automated Sync Policy - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/getting_started/ "Getting Started - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/latest/user-guide/application-specification/ "Application Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/ "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
