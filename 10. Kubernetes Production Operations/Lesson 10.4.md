# Lesson 10.4 — Deployments, ReplicaSets, Rollouts, Rollbacks, and Deployment Strategies

This lesson is where Kubernetes starts feeling like a real production deployment platform.

In previous lessons, you learned:

```text id="66mddn"
Pods
labels
annotations
selectors
Services
basic kubectl workflow
```

Now we will learn how production apps are actually released and recovered.

A Kubernetes **Deployment** manages application Pods through ReplicaSets and provides declarative updates for Pods and ReplicaSets. You describe the desired state, and the Deployment controller changes the actual state toward that desired state at a controlled rate. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="d7ot2r"
10.4.1   Deployment mental model
10.4.2   Deployment → ReplicaSet → Pod relationship
10.4.3   Why not create Pods directly in production
10.4.4   Deployment YAML anatomy
10.4.5   RollingUpdate strategy
10.4.6   Recreate strategy
10.4.7   maxSurge and maxUnavailable
10.4.8   rollout status
10.4.9   rollout history
10.4.10  rollout undo
10.4.11  bad rollout simulation
10.4.12  rollback to previous revision
10.4.13  rollback to specific revision
10.4.14  image update workflow
10.4.15  blue-green concept
10.4.16  canary concept
10.4.17  production manifest for demo-node-api
10.4.18  validation script
10.4.19  cleanup script
10.4.20  interview explanation
```

---

# 2. Create Lesson Folder

Run:

```bash id="gxm6tq"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.4-deployments-rollouts-rollbacks/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="6y5akf"
tree -L 2 10.4-deployments-rollouts-rollbacks
```

---

# 3. Deployment Mental Model

A Deployment is not the thing that directly runs your container.

A better mental model:

```text id="zx8lve"
Deployment
  owns ReplicaSet
    owns Pods
      contain containers
```

Official Kubernetes documentation says Deployments provide declarative updates for Pods and ReplicaSets; ReplicaSets are now mainly used by Deployments as a mechanism to orchestrate Pod creation, deletion, and updates. ([Kubernetes][1])

So when you create this:

```yaml id="oi37q0"
kind: Deployment
spec:
  replicas: 3
```

Kubernetes creates this chain:

```text id="0etbfe"
Deployment/demo-app
  ↓
ReplicaSet/demo-app-xxxxx
  ↓
Pod/demo-app-xxxxx-abcde
  ↓
Container/app
```

---

# 4. Why Not Create Pods Directly in Production?

A standalone Pod is fragile.

If you create a Pod directly:

```bash id="y1yx21"
kubectl run nginx --image=nginx:1.27-alpine
```

and then delete it:

```bash id="z3mqwk"
kubectl delete pod nginx
```

it is gone.

But if a Deployment creates Pods and one Pod dies, Kubernetes creates a replacement because the Deployment’s desired state still says:

```text id="9il5n3"
replicas: 3
```

Production rule:

```text id="33f8ro"
Do not run production applications as standalone Pods.
Use Deployments for stateless applications.
Use StatefulSets for stateful identity-based applications.
Use Jobs or CronJobs for batch workloads.
```

---

# 5. Create Notes

```bash id="9u62zd"
nano 10.4-deployments-rollouts-rollbacks/notes/deployment-mental-model.md
```

Paste:

````markdown id="ravhul"
# Deployment Mental Model

## Core Chain

Deployment
→ ReplicaSet
→ Pod
→ Container

## Why Deployment Exists

A Deployment provides:

- replica management
- self-healing
- rollout
- rollback
- image updates
- controlled replacement of Pods

## Important Commands

```bash
kubectl get deployments
kubectl get replicasets
kubectl get pods
kubectl rollout status deployment/NAME
kubectl rollout history deployment/NAME
kubectl rollout undo deployment/NAME
kubectl describe deployment NAME
````

## Golden Rule

Use Deployments for stateless production applications.
Do not manually manage ReplicaSets created by Deployments.

````

---

# 6. Deployment YAML Anatomy

A Deployment has some important fields:

```yaml id="mr4kua"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-name
  namespace: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app-name
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: app-name
    spec:
      containers:
        - name: app
          image: app:1.0.0
````

Meaning:

```text id="8jau5k"
metadata.name:
  Deployment name

spec.replicas:
  Desired number of Pods

spec.selector:
  Which Pods belong to this Deployment

spec.strategy:
  How updates happen

spec.template:
  Pod template used to create Pods

spec.template.metadata.labels:
  Labels applied to created Pods

spec.template.spec.containers:
  Containers inside each Pod
```

Critical rule:

```text id="45300l"
Deployment selector must match Pod template labels.
```

This must match:

```yaml id="itffpp"
selector:
  matchLabels:
    app: demo
```

with this:

```yaml id="cwc703"
template:
  metadata:
    labels:
      app: demo
```

If they do not match, Kubernetes rejects or breaks the workload relationship.

---

# 7. Create First Deployment

Create:

```bash id="rqcp29"
nano 10.4-deployments-rollouts-rollbacks/manifests/whoami-deployment-v1.yaml
```

Paste:

```yaml id="3j5fen"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami-rollout
  namespace: dev
  labels:
    app: whoami-rollout
    environment: dev
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: whoami-rollout
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: whoami-rollout
        environment: dev
        version: v1
      annotations:
        kubernetes.io/change-cause: "Initial deployment with whoami v1.10"
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10
          ports:
            - containerPort: 80
```

Apply:

```bash id="dkqpgo"
kubectl apply -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-deployment-v1.yaml
```

Check:

```bash id="06xr3q"
kubectl get deployment whoami-rollout -n dev
kubectl get rs -n dev -l app=whoami-rollout
kubectl get pods -n dev -l app=whoami-rollout -o wide
```

Watch rollout:

```bash id="es5xpu"
kubectl rollout status deployment/whoami-rollout -n dev
```

`kubectl rollout status` watches the latest rollout until it is done by default. ([Kubernetes][2])

---

# 8. Create Service for Testing

Create:

```bash id="e7yh1t"
nano 10.4-deployments-rollouts-rollbacks/manifests/whoami-service.yaml
```

Paste:

```yaml id="bjoi41"
apiVersion: v1
kind: Service
metadata:
  name: whoami-rollout
  namespace: dev
  labels:
    app: whoami-rollout
spec:
  type: ClusterIP
  selector:
    app: whoami-rollout
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply:

```bash id="7531ef"
kubectl apply -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-service.yaml
```

Check endpoints:

```bash id="m5ey6n"
kubectl get svc whoami-rollout -n dev
kubectl get endpoints whoami-rollout -n dev
```

Test with port-forward:

```bash id="lubd57"
kubectl port-forward -n dev svc/whoami-rollout 8082:80
```

In another terminal:

```bash id="jvffp6"
curl http://127.0.0.1:8082
```

Stop port-forward with:

```text id="scu8se"
Ctrl + C
```

---

# 9. Deployment, ReplicaSet, Pod Relationship

Run:

```bash id="vved3e"
kubectl get deployment whoami-rollout -n dev
kubectl get rs -n dev -l app=whoami-rollout
kubectl get pods -n dev -l app=whoami-rollout
```

Inspect ownership:

```bash id="dn84ef"
POD_NAME="$(kubectl get pods -n dev -l app=whoami-rollout -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.metadata.ownerReferences}'
echo
```

Get ReplicaSet owner:

```bash id="qauj9p"
RS_NAME="$(kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.metadata.ownerReferences[0].name}')"

kubectl get rs "$RS_NAME" -n dev -o jsonpath='{.metadata.ownerReferences}'
echo
```

Expected chain:

```text id="9t190d"
Pod owner:
  ReplicaSet

ReplicaSet owner:
  Deployment
```

---

# 10. RollingUpdate Strategy

`RollingUpdate` is the default Deployment update strategy. A rolling update incrementally replaces old Pods with new Pods, which helps avoid downtime during normal application updates. ([Kubernetes][3])

Example:

```yaml id="qep7fm"
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```

Meaning:

```text id="2r189c"
maxSurge: 1
  Kubernetes can create 1 extra Pod above desired replicas during update.

maxUnavailable: 1
  Kubernetes can allow 1 Pod to be unavailable during update.
```

If replicas are 3:

```text id="2wix2i"
desired replicas: 3
maxSurge: 1
maxUnavailable: 1

During rollout:
  minimum available Pods can be 2
  maximum total Pods can be 4
```

Production intuition:

```text id="cb6osl"
Lower maxUnavailable = safer availability.
Higher maxSurge = faster rollout but needs more capacity.
```

---

# 11. Recreate Strategy

`Recreate` means Kubernetes terminates old Pods before creating new ones.

Example:

```yaml id="9l4nqj"
strategy:
  type: Recreate
```

Use cases:

```text id="nj52ab"
single-writer apps
apps that cannot run old and new versions together
local dev experiments
legacy apps with migration constraints
```

Downside:

```text id="730hek"
downtime is likely
```

Production rule:

```text id="kqth27"
For stateless APIs, prefer RollingUpdate.
Use Recreate only when old and new versions cannot safely run together.
```

---

# 12. Create Deployment with Recreate Strategy

Create:

```bash id="az2yq3"
nano 10.4-deployments-rollouts-rollbacks/manifests/whoami-recreate.yaml
```

Paste:

```yaml id="boi8tb"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami-recreate
  namespace: dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami-recreate
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: whoami-recreate
        version: v1
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10
          ports:
            - containerPort: 80
```

Apply:

```bash id="61kd46"
kubectl apply -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-recreate.yaml
```

Check:

```bash id="z02stk"
kubectl get deployment whoami-recreate -n dev
kubectl get pods -n dev -l app=whoami-recreate
```

Delete later after observation:

```bash id="fqlgjp"
kubectl delete -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-recreate.yaml
```

---

# 13. Rollout History

Check history:

```bash id="yfk44j"
kubectl rollout history deployment/whoami-rollout -n dev
```

At this point, you may see one revision.

To make history useful, use change-cause annotations.

Add annotation manually:

```bash id="ojhz39"
kubectl annotate deployment whoami-rollout \
  -n dev \
  kubernetes.io/change-cause="Initial whoami rollout v1" \
  --overwrite
```

Check again:

```bash id="9fqsel"
kubectl rollout history deployment/whoami-rollout -n dev
```

The `kubectl rollout` command includes subcommands such as `history`, `status`, `undo`, `pause`, `resume`, and `restart`. ([Kubernetes][4])

---

# 14. Update Image — Version 2

We will update the image using `kubectl set image`.

Run:

```bash id="nwinlb"
kubectl set image deployment/whoami-rollout \
  -n dev \
  whoami=traefik/whoami:v1.11
```

Add change cause:

```bash id="zt4ab0"
kubectl annotate deployment whoami-rollout \
  -n dev \
  kubernetes.io/change-cause="Update whoami from v1.10 to v1.11" \
  --overwrite
```

Watch:

```bash id="jhj6bc"
kubectl rollout status deployment/whoami-rollout -n dev
```

Inspect:

```bash id="edp3n7"
kubectl get rs -n dev -l app=whoami-rollout
kubectl get pods -n dev -l app=whoami-rollout -o wide
kubectl rollout history deployment/whoami-rollout -n dev
```

What happened?

```text id="ol30cp"
Old ReplicaSet scaled down.
New ReplicaSet scaled up.
New Pods use new image.
Deployment revision increased.
```

---

# 15. Watch a Rollout Live

Open one terminal:

```bash id="2a2jls"
kubectl get pods -n dev -l app=whoami-rollout -w
```

In another terminal, update image again:

```bash id="wisrpg"
kubectl set image deployment/whoami-rollout \
  -n dev \
  whoami=traefik/whoami:v1.10
```

Add annotation:

```bash id="861ske"
kubectl annotate deployment whoami-rollout \
  -n dev \
  kubernetes.io/change-cause="Rollback-like update from v1.11 to v1.10 using set image" \
  --overwrite
```

Watch Pods being created and terminated.

Exit watch:

```text id="axrhzd"
Ctrl + C
```

---

# 16. Scale Deployment

Scale up:

```bash id="p83509"
kubectl scale deployment whoami-rollout -n dev --replicas=5
```

Check:

```bash id="v68scb"
kubectl get deployment whoami-rollout -n dev
kubectl get pods -n dev -l app=whoami-rollout
```

Scale down:

```bash id="a1zlkj"
kubectl scale deployment whoami-rollout -n dev --replicas=3
```

Check:

```bash id="gb2wo1"
kubectl get pods -n dev -l app=whoami-rollout
```

Important:

```text id="5yzsqr"
Scaling changes replica count.
It does not create a new rollout revision by itself.
```

---

# 17. Simulate Bad Rollout

Now we intentionally deploy a bad image tag.

Run:

```bash id="r89alm"
kubectl set image deployment/whoami-rollout \
  -n dev \
  whoami=traefik/whoami:this-tag-does-not-exist
```

Add change cause:

```bash id="qyhzs0"
kubectl annotate deployment whoami-rollout \
  -n dev \
  kubernetes.io/change-cause="Bad rollout with non-existent image tag" \
  --overwrite
```

Watch rollout:

```bash id="xgxz2s"
kubectl rollout status deployment/whoami-rollout -n dev --timeout=60s || true
```

Check:

```bash id="rw59yt"
kubectl get pods -n dev -l app=whoami-rollout
kubectl get rs -n dev -l app=whoami-rollout
kubectl describe deployment whoami-rollout -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

You should see errors like:

```text id="bf5bc4"
ErrImagePull
ImagePullBackOff
```

This is exactly why rollout status and events matter.

---

# 18. Rollback to Previous Revision

Rollback:

```bash id="j7wujv"
kubectl rollout undo deployment/whoami-rollout -n dev
```

Watch:

```bash id="6hi3z8"
kubectl rollout status deployment/whoami-rollout -n dev
```

Check:

```bash id="yg0ge4"
kubectl get pods -n dev -l app=whoami-rollout
kubectl rollout history deployment/whoami-rollout -n dev
```

`kubectl rollout undo` rolls back a resource to a previous rollout, and it can also roll back to a specific revision with `--to-revision`. ([Kubernetes][5])

---

# 19. Rollback to Specific Revision

Check revisions:

```bash id="8u0mbt"
kubectl rollout history deployment/whoami-rollout -n dev
```

View a specific revision:

```bash id="gf4gfq"
kubectl rollout history deployment/whoami-rollout -n dev --revision=1
```

Rollback to revision 1:

```bash id="vvzt48"
kubectl rollout undo deployment/whoami-rollout -n dev --to-revision=1
```

Watch:

```bash id="2i1l5b"
kubectl rollout status deployment/whoami-rollout -n dev
```

Production note:

```text id="ce0a5j"
kubectl rollout undo is useful during emergencies.
In GitOps workflows, the long-term fix should usually be committed back to Git.
```

---

# 20. Pause and Resume Rollout

Pause rollout:

```bash id="2ykecc"
kubectl rollout pause deployment/whoami-rollout -n dev
```

Change image while paused:

```bash id="3b1s6e"
kubectl set image deployment/whoami-rollout \
  -n dev \
  whoami=traefik/whoami:v1.11
```

Check:

```bash id="08bm7f"
kubectl rollout status deployment/whoami-rollout -n dev --timeout=20s || true
kubectl get deployment whoami-rollout -n dev
```

Resume:

```bash id="8tqp4e"
kubectl rollout resume deployment/whoami-rollout -n dev
```

Watch:

```bash id="361ei8"
kubectl rollout status deployment/whoami-rollout -n dev
```

Use case:

```text id="bna4jq"
Pause lets you stage multiple changes before rollout.
It can also support controlled manual rollout workflows.
```

---

# 21. Restart Rollout

Sometimes you need to restart Pods without changing the image, for example after ConfigMap or Secret changes.

Run:

```bash id="21viwz"
kubectl rollout restart deployment/whoami-rollout -n dev
```

Watch:

```bash id="u94ell"
kubectl rollout status deployment/whoami-rollout -n dev
```

Check:

```bash id="z8dogf"
kubectl get pods -n dev -l app=whoami-rollout
```

Important:

```text id="0n7xq6"
rollout restart updates the Pod template annotation.
That causes new Pods to be created.
```

---

# 22. Deployment Conditions

Inspect Deployment:

```bash id="yrkp9z"
kubectl describe deployment whoami-rollout -n dev
```

Look for:

```text id="kraswb"
Conditions:
  Available
  Progressing
```

Get YAML:

```bash id="fcok46"
kubectl get deployment whoami-rollout -n dev -o yaml | less
```

Look for:

```text id="mt1b7g"
status:
  observedGeneration
  replicas
  updatedReplicas
  readyReplicas
  availableReplicas
  conditions
```

These status fields are useful for automation and troubleshooting.

---

# 23. Common Deployment Problems

```text id="6gz3gb"
Problem:
  Rollout stuck

Likely causes:
  bad image tag
  image registry auth failure
  failing readiness probe
  insufficient resources
  bad config
  crash loop
  scheduling issue
```

Debug order:

```bash id="meemgi"
kubectl rollout status deployment/APP -n NAMESPACE
kubectl describe deployment APP -n NAMESPACE
kubectl get rs -n NAMESPACE
kubectl get pods -n NAMESPACE -l app=APP
kubectl describe pod POD -n NAMESPACE
kubectl logs POD -n NAMESPACE
kubectl logs POD -n NAMESPACE --previous
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

---

# 24. Create Runbook — Deployment Rollout Debugging

```bash id="n4xhfd"
nano 10.4-deployments-rollouts-rollbacks/runbooks/deployment-rollout-debugging.md
```

Paste:

````markdown id="1oq7lz"
# Deployment Rollout Debugging Runbook

## Step 1 — Check Rollout

```bash
kubectl rollout status deployment/APP -n NAMESPACE
````

## Step 2 — Check Deployment

```bash
kubectl describe deployment APP -n NAMESPACE
kubectl get deployment APP -n NAMESPACE -o yaml
```

Look for:

* replicas
* updatedReplicas
* readyReplicas
* availableReplicas
* conditions
* events

## Step 3 — Check ReplicaSets

```bash
kubectl get rs -n NAMESPACE -l app=APP
```

## Step 4 — Check Pods

```bash
kubectl get pods -n NAMESPACE -l app=APP -o wide
kubectl describe pod POD_NAME -n NAMESPACE
```

## Step 5 — Check Logs

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

## Step 6 — Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Common Causes

| Symptom                  | Likely Cause                          |
| ------------------------ | ------------------------------------- |
| ImagePullBackOff         | Bad image tag or registry credentials |
| CrashLoopBackOff         | App starts and exits repeatedly       |
| Pending                  | Scheduling/resource problem           |
| Available=false          | Pods not ready                        |
| ProgressDeadlineExceeded | Rollout could not complete in time    |

## Emergency Rollback

```bash
kubectl rollout undo deployment/APP -n NAMESPACE
kubectl rollout status deployment/APP -n NAMESPACE
```

## Golden Rule

A rollout problem is usually visible in Deployment conditions, Pod status, Pod events, or container logs.

````

---

# 25. Create Runbook — Production Rollout Checklist

```bash id="qd0p3t"
nano 10.4-deployments-rollouts-rollbacks/runbooks/production-rollout-checklist.md
````

Paste:

````markdown id="xce30t"
# Production Rollout Checklist

## Before Rollout

- [ ] Image tag is immutable.
- [ ] Image has passed security scans.
- [ ] SBOM exists.
- [ ] Deployment manifest reviewed.
- [ ] Readiness probe exists.
- [ ] Liveness probe exists.
- [ ] Resource requests and limits exist.
- [ ] Rollback version known.
- [ ] Monitoring dashboard available.
- [ ] Logs available.
- [ ] Alerts healthy.

## During Rollout

```bash
kubectl rollout status deployment/APP -n production
kubectl get pods -n production -l app=APP -w
````

Watch:

* new Pods becoming Ready
* old Pods terminating
* no CrashLoopBackOff
* no ImagePullBackOff
* no service endpoint loss

## After Rollout

* [ ] Health endpoint passes.
* [ ] Readiness endpoint passes.
* [ ] Error rate normal.
* [ ] Latency normal.
* [ ] Logs clean.
* [ ] Metrics normal.
* [ ] Deployment revision documented.

## Rollback

```bash
kubectl rollout undo deployment/APP -n production
kubectl rollout status deployment/APP -n production
```

````

---

# 26. Create Production-Style Deployment for `demo-node-api`

This is a preview manifest. We will improve it in future lessons with probes, resources, ConfigMaps, Secrets, RBAC, NetworkPolicy, HPA, and Ingress.

Create folder:

```bash id="0d31r4"
mkdir -p apps/demo-node-api/base
````

Create Deployment:

```bash id="3aer1o"
nano apps/demo-node-api/base/deployment.yaml
```

Paste:

```yaml id="go7kvg"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
    environment: dev
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
      environment: dev
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: demo-node-api
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: todo-app
        environment: dev
      annotations:
        kubernetes.io/change-cause: "Initial demo-node-api Kubernetes deployment"
    spec:
      containers:
        - name: demo-node-api
          image: demo-node-api:0.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3002
```

Create Service:

```bash id="smzvsg"
nano apps/demo-node-api/base/service.yaml
```

Paste:

```yaml id="4shwin"
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 3002
```

Important:

```text id="wuuzbt"
This image is local and may not run unless loaded into kind.
We will handle local image loading and complete demo-node-api deployment in upcoming lessons.
```

---

# 27. Blue-Green Deployment Concept

Blue-green means you run two versions side by side:

```text id="x42j82"
blue:
  current production

green:
  new version
```

Traffic switches when green is verified:

```text id="fcq4b4"
Service selector points to blue
  ↓
deploy green
  ↓
test green
  ↓
change Service selector to green
```

Example labels:

```yaml id="8ul8jl"
version: blue
```

and:

```yaml id="hogbq8"
version: green
```

Service selector before:

```yaml id="lrgr8q"
selector:
  app: demo-node-api
  version: blue
```

Service selector after:

```yaml id="zz6e3p"
selector:
  app: demo-node-api
  version: green
```

Production note:

```text id="h2u8qd"
Blue-green is simple conceptually, but it needs enough capacity to run both versions and safe database compatibility.
```

---

# 28. Canary Deployment Concept

Canary means gradually send small traffic to a new version.

Example:

```text id="hd4dol"
95% traffic → stable
5% traffic  → canary
```

In plain Kubernetes Services, canary is limited because a Service load-balances across matching Pods without weighted traffic controls.

Simple replica-based canary:

```text id="20dl4f"
stable Deployment replicas: 9
canary Deployment replicas: 1
same Service selector
```

This gives rough traffic distribution.

More advanced canary usually needs:

```text id="ux7m20"
Ingress controller weighted routing
service mesh
Argo Rollouts
Flagger
Gateway API traffic splitting
```

Production note:

```text id="6wm4u0"
Kubernetes Deployment alone gives rolling updates.
Advanced canary requires additional traffic management.
```

---

# 29. Deployment Strategy Myths

## Myth 1: RollingUpdate means zero risk

Wrong.

RollingUpdate reduces downtime risk, but a bad version can still roll out.

You need:

```text id="g4mkrq"
readiness probes
metrics
logs
alerts
rollout monitoring
rollback plan
```

## Myth 2: Rollback fixes everything

Rollback helps if the previous version is compatible.

Rollback may not fully help if:

```text id="do9xpk"
database migration is destructive
external API contract changed
message format changed
cache schema changed
state changed irreversibly
```

## Myth 3: Deployment is enough for stateful apps

Wrong.

For stateful identity-based workloads, use StatefulSets.

Deployments are best for stateless replicated apps.

## Myth 4: ReplicaSet should be managed manually

Usually wrong.

Kubernetes docs recommend using Deployments when you want ReplicaSets because Deployments own and manage their ReplicaSets. ([Kubernetes][6])

## Myth 5: `kubectl rollout status` proves the app is healthy

Not fully.

It proves Kubernetes rollout conditions completed.

You still need:

```text id="s0eq4z"
application health checks
service tests
metrics
logs
synthetic checks
business transaction checks
```

---

# 30. Validation Script

Create:

```bash id="se5dm0"
nano 10.4-deployments-rollouts-rollbacks/scripts/validate-lesson-10-4.sh
```

Paste:

```bash id="3kk7xj"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.4 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get deployment whoami-rollout -n dev >/dev/null
kubectl get service whoami-rollout -n dev >/dev/null

READY_REPLICAS="$(kubectl get deployment whoami-rollout -n dev -o jsonpath='{.status.readyReplicas}' || echo 0)"
DESIRED_REPLICAS="$(kubectl get deployment whoami-rollout -n dev -o jsonpath='{.spec.replicas}' || echo 0)"

if [ -z "$READY_REPLICAS" ]; then
  READY_REPLICAS=0
fi

if [ "$READY_REPLICAS" -lt 1 ]; then
  echo "ERROR: whoami-rollout has no ready replicas"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints whoami-rollout -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: whoami-rollout service has no endpoints"
  exit 1
fi

RS_COUNT="$(kubectl get rs -n dev -l app=whoami-rollout --no-headers | wc -l)"

if [ "$RS_COUNT" -lt 1 ]; then
  echo "ERROR: expected at least one ReplicaSet for whoami-rollout"
  exit 1
fi

test -f 10.4-deployments-rollouts-rollbacks/notes/deployment-mental-model.md
test -f 10.4-deployments-rollouts-rollbacks/runbooks/deployment-rollout-debugging.md
test -f 10.4-deployments-rollouts-rollbacks/runbooks/production-rollout-checklist.md
test -f apps/demo-node-api/base/deployment.yaml
test -f apps/demo-node-api/base/service.yaml

echo "Desired replicas: $DESIRED_REPLICAS"
echo "Ready replicas: $READY_REPLICAS"
echo "ReplicaSets: $RS_COUNT"
echo "Lesson 10.4 validation passed."
```

Make executable:

```bash id="a9ycig"
chmod +x 10.4-deployments-rollouts-rollbacks/scripts/validate-lesson-10-4.sh
```

Run:

```bash id="1dh2ti"
./10.4-deployments-rollouts-rollbacks/scripts/validate-lesson-10-4.sh
```

---

# 31. Cleanup Script

Create:

```bash id="yoxy7y"
nano 10.4-deployments-rollouts-rollbacks/scripts/cleanup-lesson-10-4.sh
```

Paste:

```bash id="ryg3lb"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.4 ====="

kubectl delete -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-service.yaml --ignore-not-found=true
kubectl delete -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-deployment-v1.yaml --ignore-not-found=true
kubectl delete -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-recreate.yaml --ignore-not-found=true

kubectl delete deployment whoami-rollout -n dev --ignore-not-found=true
kubectl delete service whoami-rollout -n dev --ignore-not-found=true

echo "Lesson 10.4 resources cleaned."
echo "Namespace dev and cluster kept for next lessons."
```

Make executable:

```bash id="5b2ci1"
chmod +x 10.4-deployments-rollouts-rollbacks/scripts/cleanup-lesson-10-4.sh
```

Run only if you want cleanup:

```bash id="b58w6t"
./10.4-deployments-rollouts-rollbacks/scripts/cleanup-lesson-10-4.sh
```

For the next lesson, you can keep the Deployment and Service.

---

# 32. Practical Lab Summary

Run full lab:

```bash id="a8sd19"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-deployment-v1.yaml
kubectl apply -f 10.4-deployments-rollouts-rollbacks/manifests/whoami-service.yaml

kubectl rollout status deployment/whoami-rollout -n dev
kubectl rollout history deployment/whoami-rollout -n dev

kubectl set image deployment/whoami-rollout -n dev whoami=traefik/whoami:v1.11
kubectl annotate deployment whoami-rollout -n dev kubernetes.io/change-cause="Update to v1.11" --overwrite
kubectl rollout status deployment/whoami-rollout -n dev

kubectl set image deployment/whoami-rollout -n dev whoami=traefik/whoami:this-tag-does-not-exist
kubectl annotate deployment whoami-rollout -n dev kubernetes.io/change-cause="Bad rollout simulation" --overwrite
kubectl rollout status deployment/whoami-rollout -n dev --timeout=60s || true

kubectl get events -n dev --sort-by=.lastTimestamp
kubectl rollout undo deployment/whoami-rollout -n dev
kubectl rollout status deployment/whoami-rollout -n dev

./10.4-deployments-rollouts-rollbacks/scripts/validate-lesson-10-4.sh
```

---

# 33. Production Deployment Rules

```text id="ip04o9"
Use Deployments for stateless services.
Use immutable image tags.
Do not deploy latest.
Use readiness probes before trusting rolling updates.
Use resource requests and limits.
Use rollout status during deployment.
Use rollout history for revision awareness.
Use rollback for emergency recovery.
Use GitOps commit revert for long-term correction.
Do not manually manage ReplicaSets owned by Deployments.
Do not rely only on Kubernetes rollout status; check metrics and logs too.
```

---

# 34. Interview Explanation

Use this:

```text id="qg6dr5"
A Kubernetes Deployment manages stateless application workloads by creating and managing ReplicaSets, which then manage Pods. When I update a Deployment, Kubernetes creates a new ReplicaSet for the new Pod template and gradually shifts replicas from the old ReplicaSet to the new one according to the deployment strategy.

The default strategy is RollingUpdate, where Kubernetes incrementally replaces old Pods with new Pods. maxSurge controls how many extra Pods can be created above the desired replica count, and maxUnavailable controls how many Pods can be unavailable during the update. I use kubectl rollout status to watch deployments, rollout history to inspect revisions, and rollout undo to roll back a bad release.
```

Resume version:

```text id="lju5g2"
Implemented Kubernetes Deployment rollout and rollback workflows using ReplicaSets, RollingUpdate strategy, rollout history, bad image simulation, emergency rollback, production rollout runbooks, and validation scripts.
```

---

# 35. Today’s Core Rules

```text id="xmt72l"
Deployment manages ReplicaSets.
ReplicaSets manage Pods.
Pods run containers.
Use Deployments for stateless production apps.
RollingUpdate is the normal stateless app strategy.
Recreate causes downtime but can be useful for incompatible versions.
maxSurge controls extra Pods during rollout.
maxUnavailable controls allowed unavailable Pods.
Use rollout status during updates.
Use rollout history for revision visibility.
Use rollout undo for emergency rollback.
A bad image rollout usually causes ImagePullBackOff.
Rollout success does not replace application monitoring.
```

---

# 36. Commit Lesson 10.4

From repo root:

```bash id="lq743q"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes deployments rollouts and rollbacks lesson"

git push
```

---

# Next Lesson

```text id="d8w05p"
Lesson 10.5 — Services, ClusterIP, NodePort, LoadBalancer, DNS, and Service Discovery
```

We will cover:

```text id="ed3r08"
Service deep dive
ClusterIP
NodePort
LoadBalancer
Headless Service
Endpoints and EndpointSlices
service DNS
kube-proxy basics
port vs targetPort vs nodePort
Service selector debugging
internal service discovery
kind NodePort testing
production service patterns
```

[1]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/?utm_source=chatgpt.com "Deployments"
[2]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/?utm_source=chatgpt.com "kubectl rollout status"
[3]: https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/?utm_source=chatgpt.com "Performing a Rolling Update"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/?utm_source=chatgpt.com "kubectl rollout"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_undo/?utm_source=chatgpt.com "kubectl rollout undo"
[6]: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/?utm_source=chatgpt.com "ReplicaSet"
