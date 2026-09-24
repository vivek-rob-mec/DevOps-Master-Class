# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.3 — Deployment Rollout Failures and Rollback Debugging

In Lesson 11.2, you debugged **Pod-level failures**:

```text id="w2diar"
Pending
ImagePullBackOff
CreateContainerConfigError
CrashLoopBackOff
OOMKilled
Evicted
```

Now we move one level higher: **Deployment rollout troubleshooting**.

A Pod can fail by itself, but a Deployment rollout failure affects the whole release process.

This lesson answers:

```text id="uetruu"
Why is my rollout stuck?
Why did the new ReplicaSet not become available?
Why is kubectl rollout status waiting forever?
Why did the Deployment exceed its progress deadline?
How do I inspect ReplicaSet history?
How do I rollback safely?
When should I use kubectl rollout undo?
When should I rollback through Git or ArgoCD?
```

Kubernetes Deployments support rolling updates, rollout status, rollout history, pause/resume, restart, and undo operations. A rolling update gradually replaces old Pods with new Pods, and `kubectl rollout status` watches the latest rollout until it completes unless told otherwise. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="tdi5zz"
11.3.1   Deployment rollout mental model
11.3.2   Deployment → ReplicaSet → Pod chain
11.3.3   Rollout status and conditions
11.3.4   Revision history
11.3.5   Bad image rollout failure
11.3.6   Readiness probe blocking rollout
11.3.7   progressDeadlineExceeded
11.3.8   maxSurge and maxUnavailable mistakes
11.3.9   Rollout pause and resume
11.3.10  Rollout undo
11.3.11  Rollback to a specific revision
11.3.12  Rollout restart
11.3.13  Evidence collection
11.3.14  Safe production rollback workflow
11.3.15  ArgoCD rollback vs kubectl rollback
11.3.16  Runbooks
11.3.17  Scripts
11.3.18  Validation
11.3.19  Cleanup
```

---

# 2. Create Lesson Folder

```bash id="255bz8"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="vy3y0z"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging
```

---

# 3. Deployment Rollout Mental Model

A Deployment does not directly run containers.

The chain is:

```text id="fnducj"
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Container
```

When you update a Deployment’s Pod template, Kubernetes creates a new ReplicaSet and gradually shifts replicas from the old ReplicaSet to the new one. The Deployment strategy fields `maxSurge` and `maxUnavailable` control how many extra Pods may be created above desired replicas and how many Pods may be unavailable during the update. ([Kubernetes][2])

Example:

```text id="c5es3l"
Current state:
  Deployment wants 3 replicas
  Old ReplicaSet has 3 ready Pods

New rollout:
  Deployment creates new ReplicaSet
  New ReplicaSet creates new Pods
  Kubernetes waits for new Pods to become Ready
  Old ReplicaSet scales down
```

If new Pods never become Ready:

```text id="xsf7zt"
rollout gets stuck
old ReplicaSet may stay alive
new ReplicaSet may stay partially scaled
Deployment may hit ProgressDeadlineExceeded
```

---

# 4. Create Rollout Mental Model Notes

```bash id="ci2mla"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/notes/deployment-rollout-mental-model.md
```

Paste:

```markdown id="ejp2yw"
# Deployment Rollout Mental Model

## Chain

Deployment -> ReplicaSet -> Pod -> Container

## What Triggers a New Rollout?

A change to `.spec.template`.

Examples:

- image change
- env var change
- command change
- labels/annotations under template metadata
- probes change
- resources change
- securityContext change

## What Does Not Usually Trigger a New Rollout?

Changes outside `.spec.template`.

Examples:

- scaling replicas
- changing Service
- changing HPA
- changing PDB

## Rollout Debugging Questions

1. Did a new ReplicaSet get created?
2. Did new Pods get created?
3. Are new Pods scheduled?
4. Are containers starting?
5. Are new Pods Ready?
6. Are old Pods being scaled down?
7. Did the rollout exceed the progress deadline?
8. Is the rollout paused?
9. Can we rollback safely?
```

---

# 5. First Rollout Debugging Commands

Create note:

```bash id="u6l9g6"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/notes/rollout-debug-commands.md
```

Paste:

````markdown id="zf19px"
# Deployment Rollout Debug Commands

## Status

```bash
kubectl rollout status deployment/APP -n NAMESPACE
````

## History

```bash id="v3of5m"
kubectl rollout history deployment/APP -n NAMESPACE
kubectl rollout history deployment/APP -n NAMESPACE --revision=REVISION
```

## Deployment

```bash id="jicbda"
kubectl get deployment APP -n NAMESPACE -o wide
kubectl describe deployment APP -n NAMESPACE
```

## ReplicaSets

```bash id="gjfo6d"
kubectl get rs -n NAMESPACE -l app=APP
kubectl describe rs RS_NAME -n NAMESPACE
```

## Pods

```bash id="hl36yt"
kubectl get pods -n NAMESPACE -l app=APP -o wide
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

## Events

```bash id="h7opzq"
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## Rollback

```bash id="ok4q7u"
kubectl rollout undo deployment/APP -n NAMESPACE
kubectl rollout undo deployment/APP -n NAMESPACE --to-revision=REVISION
```

````

`kubectl rollout history` shows rollout history, while `kubectl rollout undo` rolls a workload back to a previous rollout revision or a specific revision. :contentReference[oaicite:2]{index=2}

---

# 6. Create Baseline Healthy Deployment

We will use a simple nginx app so rollout behavior is easy to observe.

```bash id="t22jjw"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/00-rollout-demo-good.yaml
````

Paste:

```yaml id="vaeb4h"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollout-demo
  namespace: dev
  labels:
    app: rollout-demo
spec:
  replicas: 3
  revisionHistoryLimit: 5
  progressDeadlineSeconds: 60
  selector:
    matchLabels:
      app: rollout-demo
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: rollout-demo
      annotations:
        kubernetes.io/change-cause: "Initial healthy rollout-demo deployment"
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
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
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: rollout-demo
  namespace: dev
  labels:
    app: rollout-demo
spec:
  selector:
    app: rollout-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="f9rg2g"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/00-rollout-demo-good.yaml
```

Validate:

```bash id="tfatjz"
kubectl rollout status deployment/rollout-demo -n dev --timeout=120s

kubectl get deploy,rs,pods,svc -n dev -l app=rollout-demo -o wide
```

Test:

```bash id="q7ks6e"
kubectl port-forward -n dev svc/rollout-demo 18080:80
```

Another terminal:

```bash id="dfhk5i"
curl -I http://127.0.0.1:18080
```

Stop port-forward:

```text id="hpyhvu"
Ctrl + C
```

---

# 7. Inspect Revision History

Run:

```bash id="romd7b"
kubectl rollout history deployment/rollout-demo -n dev
```

You should see revision 1.

Now update the change-cause and image to create a new revision:

```bash id="cx7dpn"
kubectl annotate deployment rollout-demo \
  -n dev \
  kubernetes.io/change-cause="Update nginx to 1.27-alpine via rollout lesson" \
  --overwrite

kubectl set image deployment/rollout-demo web=nginx:1.27-alpine -n dev
```

If the image tag did not actually change, Kubernetes may not create a new meaningful ReplicaSet. Force a template annotation change:

```bash id="zf5ey5"
kubectl patch deployment rollout-demo -n dev \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"lesson-run\":\"$(date +%s)\"}}}}}"
```

Check:

```bash id="n6sl44"
kubectl rollout status deployment/rollout-demo -n dev
kubectl rollout history deployment/rollout-demo -n dev
kubectl get rs -n dev -l app=rollout-demo
```

Production note:

```text id="rp0i7r"
A new Deployment revision is created when the Pod template changes.
Scaling replicas alone does not create a new application version.
```

---

# 8. Incident 1 — Bad Image During Rollout

This is one of the most common rollout failures.

Start from healthy state:

```bash id="nfgcja"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/00-rollout-demo-good.yaml

kubectl rollout status deployment/rollout-demo -n dev
```

Set a bad image:

```bash id="byqc63"
kubectl annotate deployment rollout-demo \
  -n dev \
  kubernetes.io/change-cause="Bad image rollout simulation" \
  --overwrite

kubectl set image deployment/rollout-demo web=nginx:this-tag-does-not-exist -n dev
```

Watch rollout:

```bash id="de8tde"
kubectl rollout status deployment/rollout-demo -n dev --timeout=30s || true
```

Debug:

```bash id="fb7jti"
kubectl get deployment rollout-demo -n dev

kubectl get rs -n dev -l app=rollout-demo

kubectl get pods -n dev -l app=rollout-demo -o wide

kubectl describe deployment rollout-demo -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Find the bad Pod:

```bash id="g53c6m"
kubectl get pods -n dev -l app=rollout-demo
```

Describe it:

```bash id="eay1yk"
BAD_POD="$(kubectl get pod -n dev -l app=rollout-demo -o jsonpath='{range .items[?(@.status.phase!="Running")]}{.metadata.name}{"\n"}{end}' | head -n 1)"

kubectl describe pod "$BAD_POD" -n dev
```

Expected:

```text id="eq57zg"
ErrImagePull
ImagePullBackOff
manifest unknown
failed to pull image
```

Why old Pods may still be serving:

```text id="orlmti"
maxUnavailable: 0 means Kubernetes should not voluntarily reduce available old Pods during rollout until new Pods are available.
```

This is why good rollout strategy protects availability.

Rollback:

```bash id="bm18ir"
kubectl rollout undo deployment/rollout-demo -n dev

kubectl rollout status deployment/rollout-demo -n dev --timeout=120s

kubectl get pods -n dev -l app=rollout-demo
```

Check history:

```bash id="t2dgfd"
kubectl rollout history deployment/rollout-demo -n dev
```

`kubectl rollout undo` rolls a Deployment back to a previous rollout, and can also target a specific revision with `--to-revision`. ([Kubernetes][3])

---

# 9. Incident 2 — Readiness Probe Blocking Rollout

A rollout can get stuck even when containers start successfully.

Why?

```text id="fvsyqe"
Pods are Running but not Ready.
Deployment waits for Ready Pods before considering the rollout successful.
Service endpoints may not include NotReady Pods.
```

Create manifest:

```bash id="hceq4y"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/01-readiness-block-rollout.yaml
```

Paste:

```yaml id="s943u0"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollout-readiness-demo
  namespace: dev
  labels:
    app: rollout-readiness-demo
spec:
  replicas: 3
  revisionHistoryLimit: 5
  progressDeadlineSeconds: 45
  selector:
    matchLabels:
      app: rollout-readiness-demo
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: rollout-readiness-demo
      annotations:
        kubernetes.io/change-cause: "Bad readiness probe simulation"
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /this-path-does-not-exist
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 10
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: rollout-readiness-demo
  namespace: dev
  labels:
    app: rollout-readiness-demo
spec:
  selector:
    app: rollout-readiness-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="pss1tv"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/01-readiness-block-rollout.yaml
```

Watch:

```bash id="b7bedx"
kubectl rollout status deployment/rollout-readiness-demo -n dev --timeout=60s || true
```

Debug:

```bash id="pgurni"
kubectl get pods -n dev -l app=rollout-readiness-demo

kubectl describe deployment rollout-readiness-demo -n dev

kubectl get endpoints rollout-readiness-demo -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Describe a Pod:

```bash id="c4pgz0"
POD="$(kubectl get pod -n dev -l app=rollout-readiness-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected:

```text id="yh509h"
Readiness probe failed
HTTP probe failed with statuscode: 404
```

Fix the readiness path:

```bash id="s0w74d"
kubectl patch deployment rollout-readiness-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
      "value": "/"
    }
  ]'
```

Validate:

```bash id="u6uceo"
kubectl rollout status deployment/rollout-readiness-demo -n dev --timeout=120s

kubectl get pods -n dev -l app=rollout-readiness-demo

kubectl get endpoints rollout-readiness-demo -n dev
```

Clean:

```bash id="e1u4hp"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/01-readiness-block-rollout.yaml --ignore-not-found=true
```

---

# 10. Incident 3 — `ProgressDeadlineExceeded`

`progressDeadlineSeconds` controls how long Kubernetes waits for a Deployment to make progress before reporting failure. When progress is not made within the deadline, the Deployment condition can show `ProgressDeadlineExceeded`. ([Kubernetes][1])

Create manifest:

```bash id="af4826"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/02-progress-deadline-exceeded.yaml
```

Paste:

```yaml id="jsk851"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: progress-deadline-demo
  namespace: dev
  labels:
    app: progress-deadline-demo
spec:
  replicas: 2
  revisionHistoryLimit: 5
  progressDeadlineSeconds: 20
  selector:
    matchLabels:
      app: progress-deadline-demo
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: progress-deadline-demo
      annotations:
        kubernetes.io/change-cause: "Progress deadline exceeded simulation"
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /never-ready
              port: http
            periodSeconds: 3
            timeoutSeconds: 1
            failureThreshold: 1
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="ktajye"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/02-progress-deadline-exceeded.yaml
```

Wait:

```bash id="qfebwr"
kubectl rollout status deployment/progress-deadline-demo -n dev --timeout=45s || true
```

Check condition:

```bash id="h0br76"
kubectl describe deployment progress-deadline-demo -n dev

kubectl get deployment progress-deadline-demo -n dev \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
```

Expected:

```text id="x5e5vq"
Progressing | False | ProgressDeadlineExceeded
```

Fix readiness:

```bash id="klo3ee"
kubectl patch deployment progress-deadline-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
      "value": "/"
    }
  ]'
```

Validate:

```bash id="pi43vc"
kubectl rollout status deployment/progress-deadline-demo -n dev --timeout=120s

kubectl get deployment progress-deadline-demo -n dev \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{"\n"}{end}'
```

Clean:

```bash id="jjm5zb"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/02-progress-deadline-exceeded.yaml --ignore-not-found=true
```

---

# 11. Incident 4 — Dangerous `maxUnavailable` / `maxSurge`

`maxSurge` is the maximum number of Pods that can be scheduled above the desired replica count, while `maxUnavailable` is the maximum number of Pods that can be unavailable during the update. Both can be absolute numbers or percentages, and Kubernetes requires that they are not both zero. ([Kubernetes][2])

Safe API pattern:

```yaml id="y66e1h"
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 0
```

Risky pattern for small replica counts:

```yaml id="nr37tz"
rollingUpdate:
  maxSurge: 0
  maxUnavailable: 100%
```

Why risky?

```text id="cswmjx"
If desired replicas = 2, maxUnavailable 100% can allow both old Pods to be unavailable during rollout.
This can cause downtime if new Pods are not ready fast enough.
```

Create concept manifest:

```bash id="g5ex36"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/03-dangerous-rollout-strategy.yaml
```

Paste:

```yaml id="c2zobd"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dangerous-rollout-strategy
  namespace: dev
  labels:
    app: dangerous-rollout-strategy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dangerous-rollout-strategy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 100%
  template:
    metadata:
      labels:
        app: dangerous-rollout-strategy
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="d2pi4y"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/03-dangerous-rollout-strategy.yaml
kubectl rollout status deployment/dangerous-rollout-strategy -n dev
```

Inspect:

```bash id="wucxi3"
kubectl describe deployment dangerous-rollout-strategy -n dev
```

Fix strategy:

```bash id="ra03a1"
kubectl patch deployment dangerous-rollout-strategy -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/strategy/rollingUpdate/maxSurge",
      "value": 1
    },
    {
      "op": "replace",
      "path": "/spec/strategy/rollingUpdate/maxUnavailable",
      "value": 0
    }
  ]'
```

Clean:

```bash id="rsi6t2"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/03-dangerous-rollout-strategy.yaml --ignore-not-found=true
```

Production rule:

```text id="n8lxqh"
For APIs with low replica counts, prefer maxUnavailable: 0 and maxSurge: 1 or a small positive value.
```

---

# 12. Rollout Pause and Resume

You can pause a Deployment rollout, apply multiple changes, then resume it. Kubernetes documents `kubectl rollout pause` as marking a resource paused so it is not reconciled by the controller until resumed. ([Kubernetes][4])

Start healthy:

```bash id="u4zkhp"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests/00-rollout-demo-good.yaml
kubectl rollout status deployment/rollout-demo -n dev
```

Pause:

```bash id="rufv1p"
kubectl rollout pause deployment/rollout-demo -n dev
```

Make changes while paused:

```bash id="rcpydo"
kubectl set image deployment/rollout-demo web=nginx:1.27-alpine -n dev

kubectl patch deployment rollout-demo -n dev \
  -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"paused-change\":\"$(date +%s)\"}}}}}"
```

Check:

```bash id="r387ni"
kubectl rollout status deployment/rollout-demo -n dev --timeout=20s || true
kubectl describe deployment rollout-demo -n dev | grep -i paused -A3 || true
```

Resume:

```bash id="rfcvqh"
kubectl rollout resume deployment/rollout-demo -n dev
kubectl rollout status deployment/rollout-demo -n dev --timeout=120s
```

Production use:

```text id="tlqa6b"
Pause is useful when you want to batch several template changes into one rollout revision instead of triggering multiple rollouts.
```

---

# 13. Rollout Restart

Sometimes you need to restart Pods without changing the image.

Examples:

```text id="opn6b1"
ConfigMap mounted as files changed
external dependency recovered
app needs refresh
temporary runtime issue
```

Command:

```bash id="r3to5k"
kubectl rollout restart deployment/rollout-demo -n dev
kubectl rollout status deployment/rollout-demo -n dev --timeout=120s
```

`kubectl rollout restart` restarts a workload rollout; Kubernetes provides examples for restarting Deployments and DaemonSets. ([Kubernetes][5])

Production warning:

```text id="f7h8cy"
Do not use rollout restart as a blind fix.
First understand why the restart is needed.
```

---

# 14. Rollback to Previous Revision

Create a bad rollout again:

```bash id="bxbckd"
kubectl annotate deployment rollout-demo \
  -n dev \
  kubernetes.io/change-cause="Bad image before rollback demo" \
  --overwrite

kubectl set image deployment/rollout-demo web=nginx:this-tag-does-not-exist -n dev

kubectl rollout status deployment/rollout-demo -n dev --timeout=30s || true
```

Check history:

```bash id="ch7z0h"
kubectl rollout history deployment/rollout-demo -n dev
```

Rollback to previous revision:

```bash id="s9tki3"
kubectl rollout undo deployment/rollout-demo -n dev

kubectl rollout status deployment/rollout-demo -n dev --timeout=120s
```

Check:

```bash id="j5aukr"
kubectl get deployment rollout-demo -n dev -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
```

---

# 15. Rollback to Specific Revision

View history:

```bash id="pp7dmx"
kubectl rollout history deployment/rollout-demo -n dev
```

Inspect revision:

```bash id="nsjt1x"
kubectl rollout history deployment/rollout-demo -n dev --revision=1
```

Rollback to revision 1:

```bash id="g5s2jk"
kubectl rollout undo deployment/rollout-demo -n dev --to-revision=1

kubectl rollout status deployment/rollout-demo -n dev --timeout=120s
```

Production rule:

```text id="rgswga"
Rollback to a specific revision only after checking what that revision contains.
```

---

# 16. Deployment Conditions to Understand

Useful command:

```bash id="i32ot7"
kubectl get deployment rollout-demo -n dev \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
```

Common Deployment conditions:

```text id="hxqysg"
Available:
  whether minimum availability is satisfied

Progressing:
  whether the Deployment is making rollout progress

ReplicaFailure:
  whether a ReplicaSet/Pod creation failure happened
```

When debugging rollout failures, always check:

```bash id="xjpshf"
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

because it shows:

```text id="h7azb4"
strategy
replica counts
conditions
old ReplicaSets
new ReplicaSet
events
```

---

# 17. Create Rollout Evidence Script

```bash id="ss0da9"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/collect-rollout-evidence.sh
```

Paste:

```bash id="za6jik"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
DEPLOYMENT="${DEPLOYMENT:-rollout-demo}"
APP_LABEL="${APP_LABEL:-app=$DEPLOYMENT}"
OUT_DIR="${OUT_DIR:-11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/reports/rollout-$DEPLOYMENT-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT_DIR"

echo "===== Collect Rollout Evidence ====="
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT"
echo "App label: $APP_LABEL"
echo "Output: $OUT_DIR"

kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o yaml > "$OUT_DIR/deployment.yaml" 2>&1 || true
kubectl describe deployment "$DEPLOYMENT" -n "$NAMESPACE" > "$OUT_DIR/deployment-describe.txt" 2>&1 || true
kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE" > "$OUT_DIR/rollout-history.txt" 2>&1 || true
kubectl get rs -n "$NAMESPACE" -l "$APP_LABEL" -o wide > "$OUT_DIR/replicasets.txt" 2>&1 || true
kubectl get rs -n "$NAMESPACE" -l "$APP_LABEL" -o yaml > "$OUT_DIR/replicasets.yaml" 2>&1 || true
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide > "$OUT_DIR/pods.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUT_DIR/events.txt" 2>&1 || true

PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"

for pod in $PODS; do
  kubectl describe pod "$pod" -n "$NAMESPACE" > "$OUT_DIR/pod-$pod-describe.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --tail=100 > "$OUT_DIR/pod-$pod-logs.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers --previous --tail=100 > "$OUT_DIR/pod-$pod-previous-logs.txt" 2>&1 || true
done

kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}' \
  > "$OUT_DIR/deployment-conditions.txt" 2>&1 || true

echo "Evidence collected in: $OUT_DIR"
```

Make executable:

```bash id="rsq8lk"
chmod +x 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/collect-rollout-evidence.sh
```

Run:

```bash id="zmfnnk"
NAMESPACE=dev DEPLOYMENT=rollout-demo APP_LABEL='app=rollout-demo' \
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/collect-rollout-evidence.sh
```

---

# 18. Create Rollout Summary Script

```bash id="hb8k33"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/rollout-summary.sh
```

Paste:

```bash id="dcwkum"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
DEPLOYMENT="${DEPLOYMENT:-rollout-demo}"
APP_LABEL="${APP_LABEL:-app=$DEPLOYMENT}"

echo "===== Deployment Rollout Summary ====="
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT"
echo "App label: $APP_LABEL"

echo
echo "Deployment:"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o wide || true

echo
echo "Rollout history:"
kubectl rollout history deployment/"$DEPLOYMENT" -n "$NAMESPACE" || true

echo
echo "ReplicaSets:"
kubectl get rs -n "$NAMESPACE" -l "$APP_LABEL" -o wide || true

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide || true

echo
echo "Conditions:"
kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}' || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true
```

Make executable:

```bash id="ze2di2"
chmod +x 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/rollout-summary.sh
```

Run:

```bash id="hm1c55"
NAMESPACE=dev DEPLOYMENT=rollout-demo APP_LABEL='app=rollout-demo' \
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/rollout-summary.sh
```

---

# 19. Create Rollout Debugging Runbook

```bash id="yo0ut6"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/runbooks/deployment-rollout-debugging-runbook.md
```

Paste:

````markdown id="l6ol0z"
# Deployment Rollout Debugging Runbook

## 1. Check rollout status

```bash
kubectl rollout status deployment/APP -n NAMESPACE
````

## 2. Check Deployment

```bash id="lz65ad"
kubectl get deployment APP -n NAMESPACE -o wide
kubectl describe deployment APP -n NAMESPACE
```

Look for:

* desired replicas
* updated replicas
* ready replicas
* available replicas
* unavailable replicas
* conditions
* old ReplicaSets
* new ReplicaSet
* events

## 3. Check history

```bash id="y8yzy9"
kubectl rollout history deployment/APP -n NAMESPACE
kubectl rollout history deployment/APP -n NAMESPACE --revision=REVISION
```

## 4. Check ReplicaSets

```bash id="urrddj"
kubectl get rs -n NAMESPACE -l app=APP
kubectl describe rs RS_NAME -n NAMESPACE
```

## 5. Check Pods

```bash id="gn1wd4"
kubectl get pods -n NAMESPACE -l app=APP -o wide
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --tail=100
kubectl logs POD_NAME -n NAMESPACE --previous --tail=100
```

## 6. Common rollout failures

| Symptom                  | Likely Cause                |
| ------------------------ | --------------------------- |
| rollout stuck            | new Pods not Ready          |
| ProgressDeadlineExceeded | no progress before deadline |
| ImagePullBackOff         | bad image or registry issue |
| Running but not Ready    | readinessProbe failure      |
| old Pods not scaled down | new Pods not available      |
| no new ReplicaSet        | Pod template did not change |
| rollout paused           | Deployment paused           |
| sudden downtime          | bad maxUnavailable strategy |

## 7. Rollback

Previous revision:

```bash id="ovux6s"
kubectl rollout undo deployment/APP -n NAMESPACE
```

Specific revision:

```bash id="nlma09"
kubectl rollout undo deployment/APP -n NAMESPACE --to-revision=REVISION
```

## 8. Validate after rollback

```bash id="rfjzqj"
kubectl rollout status deployment/APP -n NAMESPACE
kubectl get pods -n NAMESPACE -l app=APP
kubectl get endpoints SERVICE -n NAMESPACE
curl health endpoint
```

## Golden Rule

A rollout is successful only when the new ReplicaSet creates Pods that become Ready and available.

````

---

# 20. Safe Production Rollback Workflow

Create runbook:

```bash id="hkswgb"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/runbooks/safe-production-rollback-runbook.md
````

Paste:

````markdown id="w8gkuy"
# Safe Production Rollback Runbook

## Step 1 — Confirm impact

Check:

- alerts
- error rate
- latency
- customer impact
- rollout status
- endpoints

## Step 2 — Identify bad rollout

```bash
kubectl rollout history deployment/APP -n production
kubectl describe deployment APP -n production
````

## Step 3 — Collect evidence

```bash id="udd5rf"
NAMESPACE=production DEPLOYMENT=APP APP_LABEL='app=APP' \
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/collect-rollout-evidence.sh
```

## Step 4 — Choose rollback method

### If managed by ArgoCD / GitOps

Preferred:

```bash id="v5b3fu"
git revert <bad-commit>
git push
```

Then sync through ArgoCD.

### If emergency and user impact is high

```bash id="gdd9r4"
kubectl rollout undo deployment/APP -n production
```

Then backport the fix to Git immediately.

## Step 5 — Validate

```bash id="u8sbam"
kubectl rollout status deployment/APP -n production
kubectl get pods -n production -l app=APP
kubectl get endpoints SERVICE -n production
```

Also check:

* dashboards
* logs
* error rate
* latency
* HPA
* ingress metrics

## Step 6 — Document

Record:

* bad version
* rollback version
* impact
* timeline
* root cause
* prevention

````

---

# 21. ArgoCD Rollback vs `kubectl rollout undo`

If ArgoCD manages the app, be careful with direct `kubectl rollout undo`.

Why?

```text id="u71yzb"
ArgoCD compares live cluster state with Git.
If you rollback manually but Git still points to the bad version, ArgoCD may mark the app OutOfSync or eventually re-apply the Git desired state.
````

Preferred GitOps rollback:

```text id="pke9p9"
git revert bad manifest/image tag commit
push revert
ArgoCD syncs cluster back
```

Emergency exception:

```text id="oyqcqq"
If production is down and GitOps rollback will take too long,
use kubectl rollout undo,
then immediately fix Git so desired state matches live recovery state.
```

Create note:

```bash id="opm9tp"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/notes/argocd-vs-kubectl-rollback.md
```

Paste:

````markdown id="a8u7q8"
# ArgoCD Rollback vs kubectl Rollback

## kubectl rollout undo

Changes live cluster state directly.

Good for:

- emergency rollback
- non-GitOps workloads
- quick lab debugging

Risk for GitOps:

- live state may differ from Git
- ArgoCD may re-sync bad desired state
- audit trail may be split

## GitOps rollback

Changes Git desired state.

Good for:

- normal production rollback
- audit trail
- ArgoCD-managed apps
- reviewed rollback

Flow:

```bash
git revert <bad-commit>
git push
````

Then ArgoCD syncs.

## Rule

For ArgoCD-managed workloads, prefer Git rollback.
Use kubectl rollback only as emergency mitigation, then fix Git immediately.

````

---

# 22. Run All Rollout Labs Script

```bash id="pmyf9o"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/run-rollout-labs.sh
````

Paste:

```bash id="n31dgv"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/00-rollout-demo-good.yaml"
kubectl rollout status deployment/rollout-demo -n dev --timeout=120s

kubectl apply -f "$BASE/01-readiness-block-rollout.yaml" || true
kubectl apply -f "$BASE/02-progress-deadline-exceeded.yaml" || true
kubectl apply -f "$BASE/03-dangerous-rollout-strategy.yaml" || true

echo "Rollout labs applied."
echo "Use rollout-summary.sh and collect-rollout-evidence.sh to inspect."
```

Make executable:

```bash id="xyfk21"
chmod +x 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/run-rollout-labs.sh
```

Run:

```bash id="swubx8"
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/run-rollout-labs.sh
```

---

# 23. Cleanup Script

```bash id="dml197"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/cleanup-lesson-11-3.sh
```

Paste:

```bash id="cn6297"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/manifests"

echo "===== Cleanup Lesson 11.3 ====="

kubectl delete -f "$BASE/00-rollout-demo-good.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-readiness-block-rollout.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-progress-deadline-exceeded.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-dangerous-rollout-strategy.yaml" --ignore-not-found=true

echo "Lesson 11.3 demo resources cleaned."
```

Make executable:

```bash id="knl0t0"
chmod +x 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/cleanup-lesson-11-3.sh
```

Run cleanup:

```bash id="athd8r"
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/cleanup-lesson-11-3.sh
```

---

# 24. Validation Script

```bash id="yz90c8"
nano 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/validate-lesson-11-3.sh
```

Paste:

```bash id="p437oz"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.3 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/deployment-rollout-mental-model.md"
test -f "$BASE/notes/rollout-debug-commands.md"
test -f "$BASE/notes/argocd-vs-kubectl-rollback.md"

test -f "$BASE/runbooks/deployment-rollout-debugging-runbook.md"
test -f "$BASE/runbooks/safe-production-rollback-runbook.md"

test -f "$BASE/manifests/00-rollout-demo-good.yaml"
test -f "$BASE/manifests/01-readiness-block-rollout.yaml"
test -f "$BASE/manifests/02-progress-deadline-exceeded.yaml"
test -f "$BASE/manifests/03-dangerous-rollout-strategy.yaml"

test -x "$BASE/scripts/collect-rollout-evidence.sh"
test -x "$BASE/scripts/rollout-summary.sh"
test -x "$BASE/scripts/run-rollout-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-3.sh"

kubectl get namespace dev >/dev/null

kubectl apply -f "$BASE/manifests/00-rollout-demo-good.yaml" >/dev/null
kubectl rollout status deployment/rollout-demo -n dev --timeout=120s >/dev/null

kubectl get deployment rollout-demo -n dev >/dev/null
kubectl get service rollout-demo -n dev >/dev/null
kubectl get rs -n dev -l app=rollout-demo >/dev/null
kubectl get pods -n dev -l app=rollout-demo >/dev/null

echo "Lesson 11.3 validation passed."
```

Make executable:

```bash id="niocjs"
chmod +x 11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/validate-lesson-11-3.sh
```

Run:

```bash id="p89umx"
./11-advanced-kubernetes-troubleshooting/11.3-deployment-rollout-debugging/scripts/validate-lesson-11-3.sh
```

---

# 25. Real Production Debug Mapping

Use this mapping:

```text id="bwsp96"
rollout status waits forever:
  new Pods are not becoming Ready

ProgressDeadlineExceeded:
  Deployment failed to make progress before progressDeadlineSeconds

new ReplicaSet exists but Pods fail:
  inspect Pods, events, image, probes, config

no new ReplicaSet:
  Pod template did not change, or rollout is paused

old Pods not scaling down:
  new Pods are not available, maxUnavailable is conservative, or PDB/probes block availability

sudden downtime during rollout:
  maxUnavailable too high, too few replicas, readiness probe missing or weak

rollback works but ArgoCD reverts it:
  Git desired state still points to bad version
```

---

# 26. Common Mistakes

## Mistake 1: Only checking Pods

Rollout debugging also needs:

```bash id="gf7r7l"
kubectl describe deployment APP -n NAMESPACE
kubectl get rs -n NAMESPACE -l app=APP
kubectl rollout history deployment/APP -n NAMESPACE
```

## Mistake 2: Ignoring readiness

A Pod can be:

```text id="egxxb3"
Running but not Ready
```

That can block rollout and remove it from Service endpoints.

## Mistake 3: Rollback without checking history

Always run:

```bash id="so9ycf"
kubectl rollout history deployment/APP -n NAMESPACE
```

before rolling back to a specific revision.

## Mistake 4: Manual rollback under GitOps without fixing Git

For ArgoCD-managed apps:

```text id="t8e1gs"
kubectl rollback is temporary unless Git desired state is corrected.
```

## Mistake 5: Dangerous rollout strategy

For small APIs, avoid:

```yaml id="n0ktai"
maxUnavailable: 100%
maxSurge: 0
```

unless downtime is acceptable.

---

# 27. Interview Explanation

Use this:

```text id="ker756"
When debugging a Kubernetes Deployment rollout, I first check rollout status, then inspect the Deployment conditions, ReplicaSets, Pods, and events. A Deployment rollout creates a new ReplicaSet when the Pod template changes, and the rollout succeeds only when the new Pods become Ready and available.

If rollout status is stuck, I check whether new Pods are Pending, ImagePullBackOff, CrashLoopBackOff, or Running but not Ready. I inspect readiness probes, image tags, events, and logs. If the Deployment exceeds progressDeadlineSeconds, I check the Progressing condition and identify why the new ReplicaSet is not making progress.

For rollback, I check rollout history, inspect the previous revision if needed, then use kubectl rollout undo for non-GitOps or emergency recovery. For ArgoCD-managed workloads, I prefer Git revert so the desired state in Git matches the recovered live state.
```

Resume bullet:

```text id="b6n878"
Built Kubernetes Deployment rollout failure labs covering stuck rollouts, bad images, readiness probe failures, ProgressDeadlineExceeded, risky rolling update strategy, pause/resume, rollout restart, revision history, rollback to previous/specific revisions, GitOps rollback strategy, evidence collection, and production rollback runbooks.
```

---

# 28. Commit Lesson 11.3

```bash id="etkyx3"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes deployment rollout debugging labs"

git push
```

---

# 29. Next Lesson

```text id="fjkrp8"
Lesson 11.4 — Service and DNS Troubleshooting
```

We will cover:

```text id="sspuv5"
Service selector mismatch
empty endpoints
wrong targetPort
wrong named port
ClusterIP debugging
NodePort debugging
DNS names
CoreDNS debugging
nslookup from debug Pods
curl service.namespace.svc.cluster.local
NetworkPolicy blocking DNS
kube-proxy / EndpointSlice concepts
production traffic path debugging
```

[1]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/?utm_source=chatgpt.com "Deployments"
[2]: https://kubernetes.io/docs/reference/kubernetes-api/apps/deployment-v1/?utm_source=chatgpt.com "Deployment"
[3]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_undo/?utm_source=chatgpt.com "kubectl rollout undo"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_pause/?utm_source=chatgpt.com "kubectl rollout pause"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_restart/?utm_source=chatgpt.com "kubectl rollout restart"
