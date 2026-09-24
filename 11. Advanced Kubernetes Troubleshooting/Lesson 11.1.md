# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.1 — Kubernetes Troubleshooting Mental Model

You have completed **Module 10: Kubernetes Production Operations**.

Now we start **Module 11: Advanced Kubernetes Troubleshooting**.

This module is where you start thinking like a production DevOps/SRE engineer.

In Module 10, we learned how to build:

```text id="m10-recap"
Deployment
Service
Ingress
ConfigMap
Secret
ServiceAccount
HPA
PDB
NetworkPolicy
Kustomize
ArgoCD
observability hooks
production hardening
```

In Module 11, we learn how to debug when these things break.

Kubernetes troubleshooting is not about randomly running commands. It is about following a clear path:

```text id="debug-core"
observe
classify
isolate
confirm
fix
validate
document
prevent recurrence
```

Kubernetes has official debugging workflows for Pods, running Pods, failed Pods, cluster issues, `kubectl describe`, logs, events, and ephemeral debug containers. `kubectl describe` shows resource details and related events, `kubectl logs` retrieves container logs, and ephemeral containers are specifically useful when `kubectl exec` is not enough because the container has crashed or lacks debugging tools. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="lesson-11-1-map"
11.1.1   Troubleshooting mindset
11.1.2   Do not guess: classify first
11.1.3   Application vs Kubernetes vs infrastructure
11.1.4   Control plane vs data plane
11.1.5   Desired state vs actual state
11.1.6   Events, logs, metrics, describe output
11.1.7   The Kubernetes debugging pyramid
11.1.8   The first 10 commands in any incident
11.1.9   Pod failure classification
11.1.10  Service/Ingress/DNS failure classification
11.1.11  Rollout failure classification
11.1.12  Storage failure classification
11.1.13  RBAC failure classification
11.1.14  NetworkPolicy failure classification
11.1.15  Node/resource pressure classification
11.1.16  Incident timeline method
11.1.17  Production debugging runbook
11.1.18  Troubleshooting scripts
11.1.19  Validation script
11.1.20  Resume-ready takeaway
```

---

# 2. Create Module 11 Folder

```bash id="create-11-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/{11.1-troubleshooting-mental-model,shared}

mkdir -p 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/{scripts,runbooks,notes,reports,manifests}
```

Check:

```bash id="tree-11-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting
```

---

# 3. Troubleshooting Mindset

Bad troubleshooting looks like this:

```text id="bad-debug"
Pod failed.
Maybe restart it.
Maybe delete it.
Maybe increase CPU.
Maybe redeploy.
Maybe blame Kubernetes.
```

Good troubleshooting looks like this:

```text id="good-debug"
What changed?
What is the symptom?
Which layer is failing?
What does Kubernetes think is happening?
What does the application say?
Are endpoints available?
Are events showing scheduling, image, probe, mount, or network errors?
Can I reproduce the issue safely?
What is the smallest safe fix?
How do I prove the fix worked?
```

Production mindset:

```text id="prod-debug-mindset"
Do not start by fixing.
Start by classifying.
```

The first question is not:

```text id="wrong-question"
How do I fix this?
```

The first question is:

```text id="right-question"
Which layer is failing?
```

---

# 4. Main Troubleshooting Layers

Almost every Kubernetes issue belongs to one or more of these layers:

```text id="troubleshooting-layers"
1. Manifest/config problem
2. Scheduling problem
3. Image/runtime problem
4. Application startup problem
5. Probe/health problem
6. Service selector/endpoints problem
7. Ingress/routing problem
8. DNS problem
9. NetworkPolicy/CNI problem
10. Storage/PVC problem
11. RBAC/ServiceAccount problem
12. Node/resource pressure problem
13. Autoscaling problem
14. GitOps/sync drift problem
15. External dependency problem
```

This is your main classification map.

---

# 5. Application vs Kubernetes vs Infrastructure

When something fails, decide which bucket it belongs to.

## Application problem

Examples:

```text id="app-problems"
bad environment variable
bad MongoDB URI
application exception
missing dependency
app cannot bind port
startup script fails
readiness endpoint returns 500
```

Evidence:

```text id="app-evidence"
kubectl logs shows stack trace
container starts then exits
probe reaches app but app returns failure
```

## Kubernetes object problem

Examples:

```text id="k8s-object-problems"
wrong labels
wrong Service selector
wrong targetPort
wrong ConfigMap name
missing Secret
bad Ingress path
wrong ServiceAccount
wrong HPA target
```

Evidence:

```text id="k8s-object-evidence"
kubectl describe shows missing config
Service has no endpoints
HPA cannot find target
Ingress backend unavailable
```

## Infrastructure problem

Examples:

```text id="infra-problems"
node NotReady
disk pressure
memory pressure
CNI failure
CoreDNS failure
storage driver issue
container runtime problem
cloud load balancer issue
```

Evidence:

```text id="infra-evidence"
many Pods affected
node events show pressure
CoreDNS unavailable
cluster-wide DNS failures
multiple namespaces impacted
```

---

# 6. Control Plane vs Data Plane

## Control plane

The control plane decides and records desired state.

Examples:

```text id="control-plane"
kube-apiserver
scheduler
controller-manager
etcd
cloud-controller-manager
```

Control plane failure symptoms:

```text id="control-plane-symptoms"
kubectl is slow or unavailable
new Pods are not scheduled
Deployments do not reconcile
API requests fail
controllers do not create resources
```

## Data plane

The data plane runs workloads.

Examples:

```text id="data-plane"
worker nodes
kubelet
container runtime
kube-proxy
CNI
Pods
Services
Ingress controller
```

Data plane failure symptoms:

```text id="data-plane-symptoms"
Pods crash
traffic does not route
Service endpoints missing
DNS failure
node NotReady
container runtime errors
```

Production question:

```text id="control-data-question"
Can Kubernetes accept and reconcile desired state, or are already-running workloads failing?
```

---

# 7. Desired State vs Actual State

Kubernetes is a desired-state system.

You declare:

```text id="desired-state"
I want 3 replicas of this Deployment.
```

Kubernetes tries to make actual state match.

Debugging means comparing:

```text id="state-compare"
Desired state:
  What YAML says should exist

Actual state:
  What is really running

Controller state:
  What Kubernetes is trying to do

Observed symptoms:
  What users see
```

Example:

```text id="state-example"
Desired:
  Deployment replicas = 3

Actual:
  1 Pod Running
  2 Pods Pending

Controller:
  ReplicaSet created 3 Pods

Events:
  2 Pods cannot schedule because insufficient memory
```

Conclusion:

```text id="state-conclusion"
Deployment is correct.
Scheduler capacity is the problem.
```

---

# 8. Events, Logs, Metrics, Describe Output

Use each signal correctly.

| Signal                                  | Best Use                              |
| --------------------------------------- | ------------------------------------- |
| `kubectl get`                           | See current object status             |
| `kubectl describe`                      | See details, conditions, events       |
| `kubectl logs`                          | See application/container output      |
| `kubectl logs --previous`               | See previous crashed container output |
| `kubectl get events` / `kubectl events` | See Kubernetes lifecycle messages     |
| `kubectl top`                           | See CPU/memory usage                  |
| Prometheus/Grafana                      | See historical metrics                |
| ArgoCD                                  | See Git desired state vs live state   |

Kubernetes events are informative, best-effort reports about activity in the cluster, and the API docs warn that events have limited retention and should be treated as supplemental data. ([Kubernetes][2])

Production rule:

```text id="signal-rule"
Events explain Kubernetes decisions.
Logs explain application behavior.
Metrics explain impact and trends.
Describe output connects object configuration with events.
```

---

# 9. Kubernetes Debugging Pyramid

Use this order.

```text id="debug-pyramid"
Level 1: Scope
  Is it one Pod, one app, one namespace, one node, or whole cluster?

Level 2: Object status
  kubectl get pods,deploy,svc,ingress,hpa,pvc

Level 3: Events and describe
  kubectl describe pod
  kubectl get events

Level 4: Logs
  kubectl logs
  kubectl logs --previous

Level 5: Connectivity
  service endpoints
  DNS
  curl from debug Pod
  ingress path

Level 6: Resources
  CPU/memory
  node pressure
  requests/limits
  HPA

Level 7: Platform components
  CoreDNS
  ingress controller
  CNI
  storage driver
  metrics-server
  ArgoCD

Level 8: Root cause and prevention
  fix
  validate
  document
  add guardrail
```

---

# 10. The First 10 Commands in Any Kubernetes Incident

Create notes:

```bash id="create-first-10-note"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/first-10-commands.md
```

Paste:

````markdown id="first-10-note"
# First 10 Commands in a Kubernetes Incident

## 1. Check current context

```bash
kubectl config current-context
````

## 2. Check nodes

```bash
kubectl get nodes -o wide
```

## 3. Check non-running Pods across all namespaces

```bash
kubectl get pods -A | grep -v Running
```

## 4. Check recent events

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

## 5. Check app resources

```bash
kubectl get deploy,rs,pods,svc,ingress,hpa,pdb -n NAMESPACE
```

## 6. Describe the failing Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

## 7. Check current logs

```bash
kubectl logs POD_NAME -n NAMESPACE --tail=100
```

## 8. Check previous logs

```bash
kubectl logs POD_NAME -n NAMESPACE --previous --tail=100
```

## 9. Check Service endpoints

```bash
kubectl get svc,endpoints -n NAMESPACE
```

## 10. Check metrics

```bash
kubectl top pods -n NAMESPACE
kubectl top nodes
```

````

---

# 11. Pod Failure Classification

When a Pod is not healthy, classify it by status/reason.

Common statuses:

```text id="pod-statuses"
Pending
ContainerCreating
ImagePullBackOff
ErrImagePull
CrashLoopBackOff
CreateContainerConfigError
RunContainerError
OOMKilled
Evicted
Completed
Error
Terminating
Unknown
````

Kubernetes has official docs for debugging Pods, determining reasons for Pod failure, debugging running or crashing Pods, and debugging init containers. These docs emphasize `kubectl describe`, logs, container status, events, and related object details as the main starting points. ([Kubernetes][3])

## Quick classification table

| Symptom                      | Most likely layer                 |
| ---------------------------- | --------------------------------- |
| `Pending`                    | scheduling/resources/taints/PVC   |
| `ImagePullBackOff`           | image name/tag/registry/auth      |
| `CreateContainerConfigError` | ConfigMap/Secret/env/volume issue |
| `CrashLoopBackOff`           | app crash/startup/probe/runtime   |
| `OOMKilled`                  | memory limit/app leak             |
| `Evicted`                    | node pressure                     |
| `Running but NotReady`       | readiness probe/app dependency    |
| `Service has no endpoints`   | labels/readiness/selector         |
| `Ingress 404`                | host/path/IngressClass/backend    |
| `DNS timeout`                | CoreDNS/NetworkPolicy/CNI         |
| `Forbidden`                  | RBAC/ServiceAccount               |

---

# 12. Create Incident Classification Notes

```bash id="create-classification-note"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/incident-classification-map.md
```

Paste:

```markdown id="classification-map"
# Kubernetes Incident Classification Map

## Pod Pending

Check:

- scheduler events
- resource requests
- node capacity
- taints/tolerations
- affinity
- PVC binding

## ImagePullBackOff

Check:

- image name
- image tag
- registry access
- imagePullSecret
- network access to registry

## CrashLoopBackOff

Check:

- logs
- previous logs
- command/args
- environment variables
- missing secrets
- app startup
- probes

## CreateContainerConfigError

Check:

- ConfigMap exists
- Secret exists
- key names
- volume references
- envFrom references

## Service Failure

Check:

- Service selector
- Pod labels
- endpoints
- targetPort
- readiness

## Ingress Failure

Check:

- ingressClassName
- controller running
- host header
- path
- backend service
- TLS secret

## DNS Failure

Check:

- CoreDNS Pods
- kube-dns Service
- NetworkPolicy egress to DNS
- /etc/resolv.conf inside Pod

## RBAC Failure

Check:

- ServiceAccount
- Role
- RoleBinding
- ClusterRole
- ClusterRoleBinding
- kubectl auth can-i

## NetworkPolicy Failure

Check:

- CNI supports policy
- source egress
- destination ingress
- labels
- namespace selectors
- DNS egress
```

---

# 13. The “One Pod or Many Pods?” Rule

First scope the blast radius.

```bash id="scope-commands"
kubectl get pods -A | grep -v Running
kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

Interpretation:

```text id="scope-interpretation"
One Pod failing:
  likely app/config/image/probe issue

All replicas of one Deployment failing:
  likely deployment config, image, secret, app startup, dependency

Many apps in one namespace failing:
  likely namespace quota, NetworkPolicy, secret/config, node placement, admission policy

Pods across many namespaces failing:
  likely node, CNI, DNS, storage, image registry, control plane, cluster-wide issue

Only Pods on one node failing:
  likely node pressure, kubelet, runtime, CNI, disk, network issue
```

Production shortcut:

```text id="scope-shortcut"
The wider the blast radius, the lower in the platform you should look.
```

---

# 14. The “Did It Ever Work?” Rule

Ask:

```text id="did-it-work"
Did this ever work before?
```

If **no**:

```text id="never-worked"
focus on manifest, image, config, Secret, Service selector, Ingress, RBAC, NetworkPolicy
```

If **yes**:

```text id="worked-before"
focus on recent changes, rollout history, node changes, config changes, secret rotation, image tag change, traffic spike, dependency outage
```

Commands:

```bash id="rollout-history-commands"
kubectl rollout history deployment/demo-node-api -n dev
kubectl describe deployment demo-node-api -n dev
kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 50
```

If GitOps is used:

```bash id="argocd-checks"
kubectl get applications -n argocd
kubectl describe application demo-node-api-dev -n argocd
```

---

# 15. Incident Timeline Method

Do not only collect commands. Build a timeline.

Example:

```text id="incident-timeline-example"
10:02 - new image tag deployed
10:03 - rollout started
10:04 - first readiness failures
10:05 - Pods entered CrashLoopBackOff
10:06 - Service endpoints dropped to zero
10:07 - Ingress returned 503
10:10 - rollback started
10:12 - endpoints restored
```

Timeline sources:

```text id="timeline-sources"
kubectl get events
kubectl rollout history
ArgoCD sync history
CI/CD pipeline logs
application logs
Prometheus/Grafana metrics
cloud provider events
```

Create note:

```bash id="create-timeline-note"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/incident-timeline-template.md
```

Paste:

```markdown id="timeline-template"
# Incident Timeline Template

## Incident

Title:

Date:

Environment:

Namespace:

Service:

## Timeline

| Time | Event | Evidence |
|---|---|---|
| HH:MM | Symptom started | alert/user report |
| HH:MM | Change detected | rollout/Git/ArgoCD |
| HH:MM | Kubernetes event observed | kubectl events |
| HH:MM | Logs checked | kubectl logs |
| HH:MM | Metrics checked | Grafana/Prometheus |
| HH:MM | Fix applied | command/commit |
| HH:MM | Service recovered | health check/metrics |

## Root Cause

## Impact

## Fix

## Validation

## Prevention

## Follow-up Actions
```

---

# 16. The “Do Not Delete First” Rule

Many beginners immediately run:

```bash id="bad-delete"
kubectl delete pod failing-pod -n dev
```

Sometimes this is okay, but not as the first step.

Why?

```text id="delete-risk"
You may destroy useful evidence.
You may reset logs.
You may hide the real issue temporarily.
You may cause another Pod to fail the same way.
```

Better order:

```bash id="evidence-first"
kubectl get pod POD_NAME -n NAMESPACE -o yaml > reports/pod-before-fix.yaml
kubectl describe pod POD_NAME -n NAMESPACE > reports/pod-describe-before-fix.txt
kubectl logs POD_NAME -n NAMESPACE --tail=200 > reports/pod-logs-before-fix.txt || true
kubectl logs POD_NAME -n NAMESPACE --previous --tail=200 > reports/pod-previous-logs-before-fix.txt || true
```

Then fix.

Production rule:

```text id="evidence-rule"
Collect evidence before destructive actions.
```

---

# 17. Create Evidence Collection Script

```bash id="create-evidence-script"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/collect-k8s-evidence.sh
```

Paste:

```bash id="evidence-script"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP_LABEL="${APP_LABEL:-app.kubernetes.io/name=demo-node-api}"
OUT_DIR="${OUT_DIR:-11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/reports/evidence-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT_DIR"

echo "===== Collecting Kubernetes Evidence ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"
echo "Output: $OUT_DIR"

kubectl config current-context > "$OUT_DIR/context.txt" 2>&1 || true
kubectl get nodes -o wide > "$OUT_DIR/nodes.txt" 2>&1 || true
kubectl get pods -A -o wide > "$OUT_DIR/all-pods.txt" 2>&1 || true
kubectl get events -A --sort-by=.lastTimestamp > "$OUT_DIR/all-events.txt" 2>&1 || true

kubectl get all -n "$NAMESPACE" -o wide > "$OUT_DIR/namespace-all.txt" 2>&1 || true
kubectl get deploy,rs,pods,svc,endpoints,ingress,hpa,pdb,pvc,networkpolicy -n "$NAMESPACE" -o wide > "$OUT_DIR/namespace-resources.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUT_DIR/namespace-events.txt" 2>&1 || true

PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"

for pod in $PODS; do
  echo "Collecting pod: $pod"
  kubectl get pod "$pod" -n "$NAMESPACE" -o yaml > "$OUT_DIR/pod-$pod.yaml" 2>&1 || true
  kubectl describe pod "$pod" -n "$NAMESPACE" > "$OUT_DIR/pod-$pod-describe.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --tail=200 > "$OUT_DIR/pod-$pod-logs.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --previous --tail=200 > "$OUT_DIR/pod-$pod-previous-logs.txt" 2>&1 || true
done

kubectl top nodes > "$OUT_DIR/top-nodes.txt" 2>&1 || true
kubectl top pods -n "$NAMESPACE" > "$OUT_DIR/top-pods.txt" 2>&1 || true

echo "Evidence collected in: $OUT_DIR"
```

Make executable:

```bash id="chmod-evidence"
chmod +x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/collect-k8s-evidence.sh
```

Run for `demo-node-api`:

```bash id="run-evidence"
NAMESPACE=dev \
APP_LABEL='app.kubernetes.io/name=demo-node-api' \
./11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/collect-k8s-evidence.sh
```

---

# 18. Create Troubleshooting Decision Tree

```bash id="create-decision-tree"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/kubernetes-troubleshooting-decision-tree.md
```

Paste:

```markdown id="decision-tree"
# Kubernetes Troubleshooting Decision Tree

## Step 1 — Is kubectl working?

No:

- check kubeconfig
- check API server access
- check current context
- check VPN/network

Yes:

- continue

## Step 2 — Is it one app or many apps?

One app:

- check Deployment
- check Pods
- check Service
- check Ingress
- check ConfigMap/Secret

Many apps:

- check nodes
- check CoreDNS
- check CNI
- check storage
- check cluster events
- check admission policies

## Step 3 — Are Pods created?

No:

- check Deployment/ReplicaSet
- check quota
- check admission errors
- check events

Yes:

- continue

## Step 4 — Are Pods scheduled?

No, Pending:

- check scheduler events
- check resources
- check taints/tolerations
- check affinity
- check PVC

Yes:

- continue

## Step 5 — Are containers starting?

No:

- ImagePullBackOff
- CreateContainerConfigError
- RunContainerError

Check:

- image
- registry
- Secret
- ConfigMap
- command/args
- volume mounts

Yes:

- continue

## Step 6 — Are containers staying up?

No, CrashLoopBackOff:

- check logs
- check previous logs
- check startup
- check probes
- check dependencies

Yes:

- continue

## Step 7 — Are Pods Ready?

No:

- check readinessProbe
- check app dependency
- check logs
- check endpoints

Yes:

- continue

## Step 8 — Does Service have endpoints?

No:

- check Service selector
- check Pod labels
- check readiness

Yes:

- continue

## Step 9 — Does DNS resolve?

No:

- check CoreDNS
- check NetworkPolicy DNS egress
- check service name

Yes:

- continue

## Step 10 — Does Ingress route?

No:

- check ingressClassName
- check controller
- check host header
- check path
- check backend service
```

---

# 19. Create Main Troubleshooting Runbook

```bash id="create-main-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/runbooks/kubernetes-troubleshooting-mental-model-runbook.md
```

Paste:

````markdown id="main-runbook"
# Kubernetes Troubleshooting Mental Model Runbook

## 1. Scope the issue

```bash
kubectl get pods -A | grep -v Running
kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
````

Determine:

* one Pod
* one Deployment
* one namespace
* one node
* many namespaces
* whole cluster

## 2. Check desired vs actual state

```bash
kubectl get deploy,rs,pods,svc,endpoints,ingress,hpa,pdb,pvc -n NAMESPACE
```

Ask:

* What did we want?
* What actually exists?
* What controller is responsible?
* What is not reconciling?

## 3. Describe failing objects

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl describe service SERVICE_NAME -n NAMESPACE
kubectl describe ingress INGRESS_NAME -n NAMESPACE
```

Look for:

* events
* conditions
* image
* ports
* env refs
* volume mounts
* probes
* selectors

## 4. Check logs

```bash
kubectl logs POD_NAME -n NAMESPACE --tail=200
kubectl logs POD_NAME -n NAMESPACE --previous --tail=200
```

Use `--previous` for:

* CrashLoopBackOff
* restarted containers
* containers that exited quickly

## 5. Check Service path

```bash
kubectl get svc,endpoints -n NAMESPACE
kubectl get pods -n NAMESPACE --show-labels
```

If endpoints are empty:

* Pod not Ready
* Service selector mismatch
* wrong labels
* wrong namespace

## 6. Check resource pressure

```bash
kubectl top pods -n NAMESPACE
kubectl top nodes
kubectl describe node NODE_NAME
```

Look for:

* CPU pressure
* memory pressure
* disk pressure
* OOMKilled
* Evicted

## 7. Check recent changes

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

If GitOps:

```bash
kubectl get applications -n argocd
kubectl describe application APP_NAME -n argocd
```

## 8. Fix safely

Prefer:

* Git commit
* Kustomize overlay patch
* Helm values update
* ArgoCD sync
* controlled rollout

Avoid:

* random live edits
* deleting evidence first
* changing many variables at once

## 9. Validate

```bash
kubectl rollout status deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl get endpoints SERVICE_NAME -n NAMESPACE
curl health endpoint
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 30
```

## 10. Prevent recurrence

Add:

* alert
* runbook
* validation script
* admission policy
* CI/CD check
* resource request
* probe
* test

````

---

# 20. Create Incident Triage Script

```bash id="create-triage-script"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/k8s-triage.sh
````

Paste:

```bash id="triage-script"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP_LABEL="${APP_LABEL:-app.kubernetes.io/name=demo-node-api}"

echo "===== Kubernetes Incident Triage ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"

echo
echo "1. Current context"
kubectl config current-context || true

echo
echo "2. Nodes"
kubectl get nodes -o wide || true

echo
echo "3. Non-running Pods across cluster"
kubectl get pods -A | grep -v Running || true

echo
echo "4. Namespace resources"
kubectl get deploy,rs,pods,svc,endpoints,ingress,hpa,pdb,pvc,networkpolicy -n "$NAMESPACE" -o wide || true

echo
echo "5. App Pods"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide --show-labels || true

echo
echo "6. Recent namespace events"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "7. Recent cluster events"
kubectl get events -A --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "8. Metrics if available"
kubectl top pods -n "$NAMESPACE" || true
kubectl top nodes || true

echo
echo "9. App logs tail"
PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
for pod in $PODS; do
  echo
  echo "----- Logs: $pod -----"
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --tail=50 || true
  echo
  echo "----- Previous logs: $pod -----"
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --previous --tail=50 || true
done

echo
echo "10. Triage completed."
```

Make executable:

```bash id="chmod-triage"
chmod +x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/k8s-triage.sh
```

Run:

```bash id="run-triage"
NAMESPACE=dev \
APP_LABEL='app.kubernetes.io/name=demo-node-api' \
./11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/k8s-triage.sh
```

---

# 21. Create Practice Incident Manifest

This creates a safe broken Deployment with a bad image.

```bash id="create-bad-image"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/manifests/incident-bad-image.yaml
```

Paste:

```yaml id="bad-image-yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-bad-image
  namespace: dev
  labels:
    app: incident-bad-image
spec:
  replicas: 1
  selector:
    matchLabels:
      app: incident-bad-image
  template:
    metadata:
      labels:
        app: incident-bad-image
    spec:
      containers:
        - name: app
          image: nginx:this-tag-does-not-exist
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="apply-bad-image"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/manifests/incident-bad-image.yaml
```

Debug:

```bash id="debug-bad-image"
kubectl get pods -n dev -l app=incident-bad-image
kubectl describe pod -n dev -l app=incident-bad-image
kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 20
```

Expected:

```text id="bad-image-expected"
ErrImagePull
ImagePullBackOff
failed to pull image
```

Fix:

```bash id="fix-bad-image"
kubectl set image deployment/incident-bad-image app=nginx:1.27-alpine -n dev
kubectl rollout status deployment/incident-bad-image -n dev
```

Clean:

```bash id="clean-bad-image"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/manifests/incident-bad-image.yaml --ignore-not-found=true
```

---

# 22. Create Validation Script

```bash id="create-validate-11-1"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/validate-lesson-11-1.sh
```

Paste:

```bash id="validate-11-1-script"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.1 ====="

kubectl version --client >/dev/null

test -d 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model

test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/first-10-commands.md
test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/incident-classification-map.md
test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/incident-timeline-template.md
test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/notes/kubernetes-troubleshooting-decision-tree.md

test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/runbooks/kubernetes-troubleshooting-mental-model-runbook.md

test -x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/collect-k8s-evidence.sh
test -x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/k8s-triage.sh

test -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/manifests/incident-bad-image.yaml

kubectl get nodes >/dev/null

echo "Lesson 11.1 validation passed."
```

Make executable:

```bash id="chmod-validate-11-1"
chmod +x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/validate-lesson-11-1.sh
```

Run:

```bash id="run-validate-11-1"
./11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/validate-lesson-11-1.sh
```

---

# 23. Cleanup Script

```bash id="create-cleanup-11-1"
nano 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/cleanup-lesson-11-1.sh
```

Paste:

```bash id="cleanup-11-1-script"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 11.1 ====="

kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/manifests/incident-bad-image.yaml --ignore-not-found=true

echo "Lesson 11.1 demo resources cleaned."
echo "Notes, scripts, and runbooks are kept."
```

Make executable:

```bash id="chmod-cleanup-11-1"
chmod +x 11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/cleanup-lesson-11-1.sh
```

Run only if needed:

```bash id="run-cleanup-11-1"
./11-advanced-kubernetes-troubleshooting/11.1-troubleshooting-mental-model/scripts/cleanup-lesson-11-1.sh
```

---

# 24. Production Troubleshooting Rules

```text id="prod-troubleshooting-rules"
1. Scope before fixing.
2. Collect evidence before deleting.
3. Classify the failure layer.
4. Use events for Kubernetes decisions.
5. Use logs for application behavior.
6. Use previous logs for restarted containers.
7. Use endpoints to debug Service routing.
8. Use labels/selectors to debug Service and NetworkPolicy.
9. Use rollout history to connect failures to changes.
10. Use metrics to understand impact.
11. Change one variable at a time.
12. Validate the fix with health checks and rollout status.
13. Document root cause and prevention.
14. Prefer Git/Kustomize/ArgoCD changes over manual cluster edits.
```

---

# 25. Common Mistakes

## Mistake 1: Starting with `kubectl delete pod`

Better:

```bash id="better-than-delete"
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Mistake 2: Only checking logs

Logs do not show everything.

For scheduling, image pull, volume mount, and probe issues, `describe` and events are often more useful.

## Mistake 3: Ignoring Service endpoints

If Ingress or Service fails, always check:

```bash id="check-endpoints"
kubectl get svc,endpoints -n NAMESPACE
```

No endpoints usually means:

```text id="no-endpoints-causes"
selector mismatch
Pods not Ready
wrong namespace
wrong labels
```

## Mistake 4: Blaming Kubernetes too early

Many issues are simple:

```text id="simple-causes"
wrong image tag
missing Secret
wrong port
wrong selector
readiness endpoint failing
bad environment variable
```

## Mistake 5: Fixing without recording evidence

In production, always keep evidence for RCA.

---

# 26. Interview Explanation

Use this answer:

```text id="interview-11-1"
My Kubernetes troubleshooting approach starts with scoping the incident. I first determine whether the issue affects one Pod, one Deployment, one namespace, one node, or the whole cluster. Then I classify the failure layer: scheduling, image pull, container startup, application crash, probe failure, Service endpoints, Ingress routing, DNS, NetworkPolicy, storage, RBAC, node pressure, or GitOps drift.

I use kubectl get for current status, kubectl describe for conditions and events, kubectl logs and --previous for application failures, kubectl get events for Kubernetes lifecycle messages, kubectl top for resource pressure, and Service endpoints to debug traffic routing. I collect evidence before deleting resources, connect symptoms to recent changes using rollout history or ArgoCD sync history, apply the smallest safe fix, and validate recovery with rollout status, endpoints, health checks, and metrics.
```

Resume bullet:

```text id="resume-11-1"
Built a Kubernetes troubleshooting framework with incident classification, first-response command sets, evidence collection automation, decision trees, timeline templates, Pod failure analysis, and production debugging runbooks for advanced cluster operations.
```

---

# 27. Commit Lesson 11.1

```bash id="commit-11-1"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes troubleshooting mental model lesson"

git push
```

---

# 28. What Comes Next

```text id="next-11-2"
Lesson 11.2 — Pod Pending, ImagePullBackOff, CrashLoopBackOff, OOMKilled, and Evicted
```

We will do hands-on incident simulations for:

```text id="next-failures"
Pending Pod due to insufficient resources
Pending Pod due to taints
ImagePullBackOff due to bad image tag
ImagePullBackOff due to private registry concept
CreateContainerConfigError due to missing Secret
CrashLoopBackOff due to app crash
CrashLoopBackOff due to bad command
OOMKilled due to memory limit
Evicted due to node pressure concept
```

Module 11 has started.

[1]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/?utm_source=chatgpt.com "kubectl describe"
[2]: https://kubernetes.io/docs/reference/kubernetes-api/core/event-v1/?utm_source=chatgpt.com "Event"
[3]: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/?utm_source=chatgpt.com "Debug Pods"
