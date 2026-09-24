# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.2 — Pod Pending, ImagePullBackOff, CrashLoopBackOff, OOMKilled, and Evicted

In Lesson 11.1, you built the **troubleshooting mental model**.

Now we start hands-on failure simulations.

This lesson focuses on the most common Pod-level failures you will see in real Kubernetes work:

```text id="cg2l9t"
Pending
ImagePullBackOff
ErrImagePull
CreateContainerConfigError
CrashLoopBackOff
OOMKilled
Evicted
```

The key skill is not memorizing names. The key skill is knowing:

```text id="vsgp3i"
where to look
what the error means
which layer is broken
how to fix it safely
how to validate recovery
```

Kubernetes’ official debugging guidance starts with checking Pod status, `kubectl describe`, events, and container logs; for running or crashing Pods, `kubectl logs`, `kubectl logs --previous`, and debug containers are common tools. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="a4ja2p"
11.2.1   Pod failure classification
11.2.2   Pending due to insufficient resources
11.2.3   Pending due to taints
11.2.4   ImagePullBackOff due to bad image
11.2.5   CreateContainerConfigError due to missing Secret
11.2.6   CrashLoopBackOff due to app crash
11.2.7   CrashLoopBackOff due to bad command
11.2.8   OOMKilled due to memory limit
11.2.9   Evicted / node-pressure concept
11.2.10  Evidence collection
11.2.11  Fix and validate workflow
11.2.12  Troubleshooting scripts
11.2.13  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="1qq9i8"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="e9ryii"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging
```

---

# 3. Pod Failure Cheat Sheet

Create a quick note:

```bash id="f5aibh"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/notes/pod-failure-cheatsheet.md
```

Paste:

```markdown id="95dv61"
# Pod Failure Cheat Sheet

| Status / Reason | Meaning | First Commands |
|---|---|---|
| Pending | Pod accepted but not scheduled or waiting for dependency | describe pod, events |
| ImagePullBackOff | kubelet failed to pull image and is backing off | describe pod |
| ErrImagePull | image pull failed immediately | describe pod |
| CreateContainerConfigError | container config cannot be created | describe pod, check Secret/ConfigMap |
| CrashLoopBackOff | container starts, exits, restarts repeatedly | logs, logs --previous |
| OOMKilled | container exceeded memory limit or was killed by OOM | describe pod, previous logs, metrics |
| Evicted | kubelet removed Pod due to node pressure or disruption | describe pod, node events |
```

Kubernetes Pod lifecycle exposes container states such as `Waiting`, `Running`, and `Terminated`; when containers terminate, Kubernetes surfaces the reason, exit code, start time, and finish time, which is why `describe pod` and JSON status fields are so valuable during debugging. ([Kubernetes][2])

---

# 4. Universal Debug Commands

For every incident in this lesson, use this pattern:

```bash id="3b2zox"
kubectl get pods -n dev
kubectl get pods -n dev -o wide
kubectl describe pod POD_NAME -n dev
kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
kubectl logs POD_NAME -n dev --tail=100 || true
kubectl logs POD_NAME -n dev --previous --tail=100 || true
```

Useful JSON status command:

```bash id="8kfv3c"
kubectl get pod POD_NAME -n dev -o jsonpath='{.status.containerStatuses[*].state}'
echo
```

For last termination reason:

```bash id="qwy7sc"
kubectl get pod POD_NAME -n dev \
  -o jsonpath='{.status.containerStatuses[*].lastState.terminated.reason}'
echo
```

---

# 5. Incident 1 — Pending Due to Insufficient Resources

A Pod can remain `Pending` when the scheduler cannot place it on any node. Kubernetes scheduling uses resource requests, not actual current usage, to decide whether a Pod fits on a node; even if actual CPU or memory usage is low, the scheduler can reject placement if requested capacity would exceed node allocatable resources. ([Kubernetes][3])

Create manifest:

```bash id="kk21c4"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/01-pending-insufficient-resources.yaml
```

Paste:

```yaml id="p22tfl"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-insufficient-resources
  namespace: dev
  labels:
    app: pending-insufficient-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-insufficient-resources
  template:
    metadata:
      labels:
        app: pending-insufficient-resources
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: "1000"
              memory: "1000Gi"
            limits:
              cpu: "1000"
              memory: "1000Gi"
```

Apply:

```bash id="mrtveb"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/01-pending-insufficient-resources.yaml
```

Debug:

```bash id="j65jms"
kubectl get pods -n dev -l app=pending-insufficient-resources

POD="$(kubectl get pod -n dev -l app=pending-insufficient-resources -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 20
```

Expected event:

```text id="sz4lft"
0/3 nodes are available: insufficient cpu, insufficient memory
```

Fix by reducing requests:

```bash id="zsg48m"
kubectl patch deployment pending-insufficient-resources -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/requests/cpu",
      "value": "50m"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/requests/memory",
      "value": "64Mi"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/limits/cpu",
      "value": "200m"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/limits/memory",
      "value": "128Mi"
    }
  ]'
```

Validate:

```bash id="92zuxk"
kubectl rollout status deployment/pending-insufficient-resources -n dev
kubectl get pods -n dev -l app=pending-insufficient-resources -o wide
```

Clean:

```bash id="21qtve"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/01-pending-insufficient-resources.yaml --ignore-not-found=true
```

---

# 6. Incident 2 — Pending Due to Taint

A taint on a node repels Pods unless they have a matching toleration. This is common in production for dedicated nodes, GPU nodes, platform nodes, or nodes under conditions such as memory/disk pressure. Kubernetes scheduling checks taints when deciding whether a Pod can land on a node. ([Kubernetes][4])

Choose a worker node:

```bash id="3et22a"
kubectl get nodes
```

For kind from previous lessons, use:

```bash id="3axnmn"
kubectl taint nodes devops-k8s-worker dedicated=troubleshooting:NoSchedule --overwrite
```

Create manifest:

```bash id="rsd65g"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/02-pending-taint.yaml
```

Paste:

```yaml id="tzcxcg"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-taint-demo
  namespace: dev
  labels:
    app: pending-taint-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-taint-demo
  template:
    metadata:
      labels:
        app: pending-taint-demo
    spec:
      nodeSelector:
        kubernetes.io/hostname: devops-k8s-worker
      containers:
        - name: app
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="cem7mt"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/02-pending-taint.yaml
```

Debug:

```bash id="l41d28"
kubectl get pods -n dev -l app=pending-taint-demo

POD="$(kubectl get pod -n dev -l app=pending-taint-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected event:

```text id="2dxgxu"
node(s) had untolerated taint
```

Fix by adding toleration:

```bash id="aqrdq8"
kubectl patch deployment pending-taint-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/tolerations",
      "value": [
        {
          "key": "dedicated",
          "operator": "Equal",
          "value": "troubleshooting",
          "effect": "NoSchedule"
        }
      ]
    }
  ]'
```

Validate:

```bash id="e254zz"
kubectl rollout status deployment/pending-taint-demo -n dev
kubectl get pods -n dev -l app=pending-taint-demo -o wide
```

Remove taint:

```bash id="pl9k3d"
kubectl taint nodes devops-k8s-worker dedicated=troubleshooting:NoSchedule- || true
```

Clean:

```bash id="v0y9xn"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/02-pending-taint.yaml --ignore-not-found=true
```

---

# 7. Incident 3 — ImagePullBackOff

`ImagePullBackOff` usually means the kubelet failed to pull the container image and is backing off before retrying. Common causes are wrong image name, wrong tag, private registry authentication, registry/network outage, or missing `imagePullSecret`.

Create manifest:

```bash id="t0moay"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/03-imagepullbackoff.yaml
```

Paste:

```yaml id="sm4qsv"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: imagepullbackoff-demo
  namespace: dev
  labels:
    app: imagepullbackoff-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: imagepullbackoff-demo
  template:
    metadata:
      labels:
        app: imagepullbackoff-demo
    spec:
      containers:
        - name: app
          image: nginx:this-tag-does-not-exist
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="zm9tn5"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/03-imagepullbackoff.yaml
```

Debug:

```bash id="cffo3q"
kubectl get pods -n dev -l app=imagepullbackoff-demo

POD="$(kubectl get pod -n dev -l app=imagepullbackoff-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 20
```

Expected:

```text id="x6gxge"
ErrImagePull
ImagePullBackOff
manifest unknown
pull access denied
```

Fix:

```bash id="b4kxq2"
kubectl set image deployment/imagepullbackoff-demo app=nginx:1.27-alpine -n dev
kubectl rollout status deployment/imagepullbackoff-demo -n dev
kubectl get pods -n dev -l app=imagepullbackoff-demo
```

Clean:

```bash id="ff2dqx"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/03-imagepullbackoff.yaml --ignore-not-found=true
```

Production checklist:

```text id="w5mv83"
Check image repository.
Check image tag.
Check registry credentials.
Check imagePullSecret.
Check node access to registry.
Check whether image is private.
Check whether CI actually pushed the image.
```

---

# 8. Incident 4 — CreateContainerConfigError Due to Missing Secret

`CreateContainerConfigError` often means Kubernetes cannot build the container runtime config because a referenced ConfigMap, Secret, key, or volume is missing.

Create manifest:

```bash id="afh9q7"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/04-missing-secret.yaml
```

Paste:

```yaml id="1txhcg"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-secret-demo
  namespace: dev
  labels:
    app: missing-secret-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-secret-demo
  template:
    metadata:
      labels:
        app: missing-secret-demo
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          env:
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: missing-secret
                  key: API_TOKEN
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="yqxwlg"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/04-missing-secret.yaml
```

Debug:

```bash id="rfcm89"
kubectl get pods -n dev -l app=missing-secret-demo

POD="$(kubectl get pod -n dev -l app=missing-secret-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected event:

```text id="p03daj"
secret "missing-secret" not found
```

Fix by creating the Secret:

```bash id="11xkhf"
kubectl create secret generic missing-secret \
  -n dev \
  --from-literal=API_TOKEN='local-debug-token' \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Validate:

```bash id="ewdh0h"
kubectl rollout status deployment/missing-secret-demo -n dev
kubectl get pods -n dev -l app=missing-secret-demo
```

Clean:

```bash id="cqtq91"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/04-missing-secret.yaml --ignore-not-found=true
kubectl delete secret missing-secret -n dev --ignore-not-found=true
```

Production checklist:

```text id="flbahe"
Check Secret exists.
Check Secret key spelling.
Check namespace.
Check envFrom references.
Check volume references.
Check GitOps secret workflow.
Check External Secrets / Sealed Secrets / SOPS sync status if used.
```

---

# 9. Incident 5 — CrashLoopBackOff Due to App Crash

`CrashLoopBackOff` means the container starts and exits repeatedly. The most important commands are:

```bash id="j20ygd"
kubectl logs POD_NAME -n dev
kubectl logs POD_NAME -n dev --previous
```

Create manifest:

```bash id="kngwxm"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/05-crashloop-app-crash.yaml
```

Paste:

```yaml id="7m93ob"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crashloop-app-crash
  namespace: dev
  labels:
    app: crashloop-app-crash
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crashloop-app-crash
  template:
    metadata:
      labels:
        app: crashloop-app-crash
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Starting app"
              echo "Fatal error: cannot connect to required dependency"
              exit 1
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="4y8uim"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/05-crashloop-app-crash.yaml
```

Debug:

```bash id="uco6i8"
kubectl get pods -n dev -l app=crashloop-app-crash

POD="$(kubectl get pod -n dev -l app=crashloop-app-crash -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --tail=50 || true

kubectl logs "$POD" -n dev --previous --tail=50 || true
```

Expected logs:

```text id="j9gjie"
Starting app
Fatal error: cannot connect to required dependency
```

Fix:

```bash id="5my6gc"
kubectl patch deployment crashloop-app-crash -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/command",
      "value": ["sh", "-c", "echo app fixed; sleep 3600"]
    }
  ]'
```

Validate:

```bash id="sw6uc2"
kubectl rollout status deployment/crashloop-app-crash -n dev
kubectl get pods -n dev -l app=crashloop-app-crash
```

Clean:

```bash id="f7eg8s"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/05-crashloop-app-crash.yaml --ignore-not-found=true
```

Production checklist:

```text id="egbscj"
Check current logs.
Check previous logs.
Check exit code.
Check command and args.
Check env vars.
Check Secret/ConfigMap.
Check dependency connectivity.
Check probe behavior.
Check recent image/config changes.
```

---

# 10. Incident 6 — CrashLoopBackOff Due to Bad Command

Sometimes the app image is fine, but the command is wrong.

Create manifest:

```bash id="wg2t7x"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/06-crashloop-bad-command.yaml
```

Paste:

```yaml id="oqhh49"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crashloop-bad-command
  namespace: dev
  labels:
    app: crashloop-bad-command
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crashloop-bad-command
  template:
    metadata:
      labels:
        app: crashloop-bad-command
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - /does-not-exist
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="6t93f5"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/06-crashloop-bad-command.yaml
```

Debug:

```bash id="5svhgg"
kubectl get pods -n dev -l app=crashloop-bad-command

POD="$(kubectl get pod -n dev -l app=crashloop-bad-command -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --previous --tail=50 || true
```

Expected:

```text id="lu5fv7"
exec: "/does-not-exist": stat /does-not-exist: no such file or directory
```

Fix:

```bash id="jq81v9"
kubectl patch deployment crashloop-bad-command -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/command",
      "value": ["sh", "-c", "echo fixed command; sleep 3600"]
    }
  ]'
```

Validate:

```bash id="42l41t"
kubectl rollout status deployment/crashloop-bad-command -n dev
```

Clean:

```bash id="pllrse"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/06-crashloop-bad-command.yaml --ignore-not-found=true
```

---

# 11. Incident 7 — OOMKilled

`OOMKilled` usually appears when a container tries to use more memory than its configured limit. Kubernetes’ memory resource documentation shows `lastState.terminated.reason: OOMKilled` and explains that the container was killed because it exceeded memory. ([Kubernetes][3])

Create manifest:

```bash id="m85h0y"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/07-oomkilled.yaml
```

Paste:

```yaml id="um4ms1"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oomkilled-demo
  namespace: dev
  labels:
    app: oomkilled-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oomkilled-demo
  template:
    metadata:
      labels:
        app: oomkilled-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command:
            - python
            - -c
            - |
              import time
              data = []
              print("Starting memory allocation")
              while True:
                  data.append("x" * 1024 * 1024)
                  print(f"Allocated approx {len(data)} MiB", flush=True)
                  time.sleep(0.1)
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "64Mi"
```

Apply:

```bash id="2p8c18"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/07-oomkilled.yaml
```

Watch:

```bash id="gku1lq"
kubectl get pods -n dev -l app=oomkilled-demo -w
```

Exit watch:

```text id="m18c79"
Ctrl + C
```

Debug:

```bash id="1o2foq"
POD="$(kubectl get pod -n dev -l app=oomkilled-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --previous --tail=50 || true

kubectl get pod "$POD" -n dev \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
echo

kubectl get pod "$POD" -n dev \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
echo
```

Expected:

```text id="96yy5g"
Reason: OOMKilled
Exit code: 137
```

Fix option 1 — raise limit:

```bash id="ll26qg"
kubectl patch deployment oomkilled-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/requests/memory",
      "value": "128Mi"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/limits/memory",
      "value": "256Mi"
    }
  ]'
```

But for this intentionally leaking app, increasing memory only delays the crash.

Real production fix:

```text id="vt38wt"
Check memory leak.
Profile application.
Review request size and caching behavior.
Set correct requests/limits.
Add alerts for restart count and memory usage.
Load test before production.
```

Clean:

```bash id="14u6z6"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/07-oomkilled.yaml --ignore-not-found=true
```

---

# 12. Incident 8 — Evicted / Node Pressure Concept

A Pod can show `Evicted` when the kubelet terminates Pods to reclaim node resources such as memory, disk, or filesystem inodes. Kubernetes calls this **node-pressure eviction**; the kubelet can set selected Pods to `Failed` and terminate them to protect node stability. ([Kubernetes][5])

Important warning:

```text id="uwr4bq"
Do not intentionally fill disk or memory on your main machine just to force Evicted.
This can destabilize your local environment.
```

Instead, create a concept manifest and learn the debug workflow.

Create:

```bash id="ukfcmh"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/08-eviction-pressure-concept.yaml
```

Paste:

```yaml id="sypl82"
apiVersion: v1
kind: Pod
metadata:
  name: eviction-pressure-concept
  namespace: dev
  labels:
    app: eviction-pressure-concept
spec:
  containers:
    - name: disk-writer
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          echo "This is a concept-only Pod."
          echo "Do not run unsafe disk pressure tests on your main machine."
          sleep 3600
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
          ephemeral-storage: "16Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
          ephemeral-storage: "32Mi"
```

Apply safely:

```bash id="7qvxnq"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/08-eviction-pressure-concept.yaml
```

Debug commands for real eviction incidents:

```bash id="4vdjx0"
kubectl get pods -A | grep Evicted || true

kubectl describe pod EVICTED_POD -n NAMESPACE

kubectl get events -A --sort-by=.lastTimestamp | grep -i eviction || true

kubectl describe node NODE_NAME

kubectl top nodes
kubectl top pods -A
```

Check node pressure conditions:

```bash id="x27d2f"
kubectl describe node NODE_NAME | grep -A8 -i "Conditions"
```

Common pressure types:

```text id="s3lq8b"
MemoryPressure
DiskPressure
PIDPressure
```

Node-pressure eviction is different from API-initiated eviction used by commands such as `kubectl drain`; API-initiated evictions respect PodDisruptionBudgets, while node-pressure eviction is a kubelet action to reclaim resources under pressure. ([Kubernetes][5])

Clean:

```bash id="aoniz1"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests/08-eviction-pressure-concept.yaml --ignore-not-found=true
```

---

# 13. Create Pod Failure Debug Runbook

```bash id="g93r7c"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/runbooks/pod-failure-debugging-runbook.md
```

Paste:

````markdown id="1pkk81"
# Pod Failure Debugging Runbook

## 1. Check Pod Status

```bash
kubectl get pods -n NAMESPACE
kubectl get pods -n NAMESPACE -o wide
````

## 2. Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* Events
* State
* Last State
* Reason
* Exit Code
* Image
* Command
* Args
* Env references
* Volumes
* Probes
* Node

## 3. Check Logs

```bash id="y5wgeq"
kubectl logs POD_NAME -n NAMESPACE --tail=100
kubectl logs POD_NAME -n NAMESPACE --previous --tail=100
```

Use `--previous` for:

* CrashLoopBackOff
* restarted containers
* OOMKilled
* exited containers

## 4. Check Events

```bash id="qoz91p"
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## 5. Classify

| Reason                     | Focus                          |
| -------------------------- | ------------------------------ |
| Pending                    | scheduler/resources/taints/PVC |
| ImagePullBackOff           | image/registry/auth            |
| CreateContainerConfigError | Secret/ConfigMap/env/volume    |
| CrashLoopBackOff           | app crash/command/dependency   |
| OOMKilled                  | memory limit/leak              |
| Evicted                    | node pressure                  |

## 6. Fix

Prefer fixing YAML or Git source:

* Kustomize overlay
* Helm values
* GitOps commit
* correct Secret/ConfigMap
* correct image tag
* correct resources
* correct command

## 7. Validate

```bash id="y7lgh9"
kubectl rollout status deployment/DEPLOYMENT -n NAMESPACE
kubectl get pods -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 20
```

````

---

# 14. Create Pod Failure Classifier Script

```bash id="v2qrha"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/pod-failure-classifier.sh
````

Paste:

```bash id="7jomz1"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Pod Failure Classifier ====="
echo "Namespace: $NAMESPACE"

kubectl get pods -n "$NAMESPACE" -o json | jq -r '
.items[] |
{
  name: .metadata.name,
  phase: .status.phase,
  reason: (.status.reason // "none"),
  node: (.spec.nodeName // "none"),
  containerStatuses: (.status.containerStatuses // [])
} |
.name as $name |
.phase as $phase |
.reason as $reason |
.node as $node |
.containerStatuses[]? |
[
  $name,
  $phase,
  $reason,
  $node,
  .name,
  (.state.waiting.reason // .state.terminated.reason // .state.running.startedAt // "unknown"),
  (.lastState.terminated.reason // "none"),
  (.lastState.terminated.exitCode // "none"),
  (.restartCount | tostring)
] | @tsv
' | column -t -s $'\t'
```

Make executable:

```bash id="rvux9f"
chmod +x 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/pod-failure-classifier.sh
```

Run:

```bash id="alzw35"
./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/pod-failure-classifier.sh
```

---

# 15. Create Evidence Script for One Pod

```bash id="g35mw9"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/inspect-pod-failure.sh
```

Paste:

```bash id="eshirf"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
POD="${POD:-}"

if [ -z "$POD" ]; then
  echo "Usage: NAMESPACE=dev POD=my-pod ./inspect-pod-failure.sh"
  exit 1
fi

OUT_DIR="11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/reports/$POD-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "===== Inspect Pod Failure ====="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "Output: $OUT_DIR"

kubectl get pod "$POD" -n "$NAMESPACE" -o wide | tee "$OUT_DIR/pod-status.txt" || true
kubectl get pod "$POD" -n "$NAMESPACE" -o yaml > "$OUT_DIR/pod.yaml" 2>&1 || true
kubectl describe pod "$POD" -n "$NAMESPACE" > "$OUT_DIR/describe.txt" 2>&1 || true
kubectl logs "$POD" -n "$NAMESPACE" --all-containers --tail=200 > "$OUT_DIR/logs.txt" 2>&1 || true
kubectl logs "$POD" -n "$NAMESPACE" --all-containers --previous --tail=200 > "$OUT_DIR/previous-logs.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUT_DIR/events.txt" 2>&1 || true

kubectl get pod "$POD" -n "$NAMESPACE" \
  -o jsonpath='{.status.containerStatuses[*]}' > "$OUT_DIR/container-status.jsonpath.txt" 2>&1 || true

echo "Inspection saved to: $OUT_DIR"
```

Make executable:

```bash id="n0l67d"
chmod +x 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/inspect-pod-failure.sh
```

Example:

```bash id="dm7d78"
POD="$(kubectl get pod -n dev -l app=imagepullbackoff-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

NAMESPACE=dev POD="$POD" \
./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/inspect-pod-failure.sh
```

---

# 16. Create Run-All Incident Lab Script

This script applies all incident manifests except the taint-specific one, because taints are cluster-specific.

```bash id="zbb5xd"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/run-pod-failure-labs.sh
```

Paste:

```bash id="u0t6hm"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/01-pending-insufficient-resources.yaml"
kubectl apply -f "$BASE/03-imagepullbackoff.yaml"
kubectl apply -f "$BASE/04-missing-secret.yaml"
kubectl apply -f "$BASE/05-crashloop-app-crash.yaml"
kubectl apply -f "$BASE/06-crashloop-bad-command.yaml"
kubectl apply -f "$BASE/07-oomkilled.yaml"
kubectl apply -f "$BASE/08-eviction-pressure-concept.yaml"

echo "Labs applied."
echo "Run:"
echo "./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/pod-failure-classifier.sh"
```

Make executable:

```bash id="6z7fwx"
chmod +x 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/run-pod-failure-labs.sh
```

Run:

```bash id="0ocyh2"
./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/run-pod-failure-labs.sh
```

---

# 17. Cleanup Script

```bash id="n854xt"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/cleanup-lesson-11-2.sh
```

Paste:

```bash id="a06ebi"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/manifests"

echo "===== Cleanup Lesson 11.2 ====="

kubectl delete -f "$BASE/01-pending-insufficient-resources.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-pending-taint.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-imagepullbackoff.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-missing-secret.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-crashloop-app-crash.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-crashloop-bad-command.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-oomkilled.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/08-eviction-pressure-concept.yaml" --ignore-not-found=true

kubectl delete secret missing-secret -n dev --ignore-not-found=true

kubectl taint nodes devops-k8s-worker dedicated=troubleshooting:NoSchedule- || true

echo "Lesson 11.2 demo resources cleaned."
```

Make executable:

```bash id="r3zew4"
chmod +x 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/cleanup-lesson-11-2.sh
```

Run cleanup:

```bash id="i1n4yt"
./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/cleanup-lesson-11-2.sh
```

---

# 18. Validation Script

```bash id="pu15wz"
nano 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/validate-lesson-11-2.sh
```

Paste:

```bash id="sv55np"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.2 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/pod-failure-cheatsheet.md"
test -f "$BASE/runbooks/pod-failure-debugging-runbook.md"

test -f "$BASE/manifests/01-pending-insufficient-resources.yaml"
test -f "$BASE/manifests/02-pending-taint.yaml"
test -f "$BASE/manifests/03-imagepullbackoff.yaml"
test -f "$BASE/manifests/04-missing-secret.yaml"
test -f "$BASE/manifests/05-crashloop-app-crash.yaml"
test -f "$BASE/manifests/06-crashloop-bad-command.yaml"
test -f "$BASE/manifests/07-oomkilled.yaml"
test -f "$BASE/manifests/08-eviction-pressure-concept.yaml"

test -x "$BASE/scripts/pod-failure-classifier.sh"
test -x "$BASE/scripts/inspect-pod-failure.sh"
test -x "$BASE/scripts/run-pod-failure-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-2.sh"

kubectl get namespace dev >/dev/null

echo "Lesson 11.2 validation passed."
```

Make executable:

```bash id="7z439w"
chmod +x 11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/validate-lesson-11-2.sh
```

Run:

```bash id="jqfuev"
./11-advanced-kubernetes-troubleshooting/11.2-pod-failure-debugging/scripts/validate-lesson-11-2.sh
```

---

# 19. Real Production Debug Mapping

Use this in interviews and incidents:

```text id="1dk4bz"
Pending:
  scheduler cannot place Pod.
  Check resources, taints, affinity, PVC, quota.

ImagePullBackOff:
  node cannot pull image.
  Check image name, tag, registry auth, imagePullSecret, network.

CreateContainerConfigError:
  kubelet cannot create container config.
  Check Secret, ConfigMap, keys, volumes, env refs.

CrashLoopBackOff:
  container starts then exits.
  Check logs, previous logs, command, env, dependencies, probes.

OOMKilled:
  container memory exceeded limit or node OOM killed it.
  Check memory limit, app memory behavior, previous logs, metrics.

Evicted:
  kubelet removed Pod due to node pressure or disruption.
  Check node conditions, pressure, disk, memory, events.
```

---

# 20. Interview Explanation

Use this:

```text id="dd2pie"
When I troubleshoot Pod failures, I first classify the Pod status or container reason. For Pending Pods, I inspect scheduler events, resource requests, taints, affinity, and PVC binding. For ImagePullBackOff, I check image name, tag, registry access, and imagePullSecrets. For CreateContainerConfigError, I check missing Secrets, ConfigMaps, keys, and volume references.

For CrashLoopBackOff, I use kubectl logs and kubectl logs --previous to inspect why the container exited. For OOMKilled, I check lastState.terminated.reason, exit code, memory limits, and memory metrics. For Evicted Pods, I check node pressure conditions and kubelet events. I collect evidence before deleting resources, fix the underlying manifest or dependency, and validate recovery with rollout status, Pod readiness, events, and health checks.
```

Resume bullet:

```text id="7i4tdx"
Built hands-on Kubernetes Pod failure simulations and debugging automation for Pending, taint scheduling failures, ImagePullBackOff, missing Secret configuration errors, CrashLoopBackOff, OOMKilled, and eviction/node-pressure scenarios, with classifier scripts, evidence collection, runbooks, and cleanup workflows.
```

---

# 21. Commit Lesson 11.2

```bash id="j6n21o"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes pod failure debugging labs"

git push
```

---

# 22. Next Lesson

```text id="llqs98"
Lesson 11.3 — Deployment Rollout Failures and Rollback Debugging
```

We will cover:

```text id="bqd64i"
rollout stuck
progressDeadlineExceeded
bad image during rollout
readiness probe blocking rollout
maxUnavailable and maxSurge mistakes
ReplicaSet history
rollout status
rollout pause/resume
rollout undo
rollback to previous revision
safe production rollback workflow
ArgoCD rollback vs kubectl rollback
```

[1]: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/?utm_source=chatgpt.com "Debug Pods"
[2]: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/?utm_source=chatgpt.com "Pod Lifecycle"
[3]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/?utm_source=chatgpt.com "Resource Management for Pods and Containers"
[4]: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/?utm_source=chatgpt.com "Taints and Tolerations"
[5]: https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/?utm_source=chatgpt.com "Node-pressure Eviction"
