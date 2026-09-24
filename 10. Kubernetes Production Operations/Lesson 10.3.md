# Lesson 10.3 — Pods, Labels, Annotations, Selectors, and YAML Anatomy Deep Dive

This lesson is one of the most important Kubernetes foundations.

If you understand **Pods, labels, annotations, selectors, owner references, and YAML structure**, then Deployments, Services, Ingress, NetworkPolicy, monitoring, autoscaling, and troubleshooting become much easier.

Kubernetes Pods are the smallest deployable compute unit in Kubernetes; a Pod can run one or more containers that share networking and storage context. Pod lifecycle has phases such as `Pending`, `Running`, `Succeeded`, `Failed`, and `Unknown`, and container restart behavior is controlled by restart policy and kubelet behavior. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="gp68x7"
10.3.1  Pod mental model
10.3.2  Pod lifecycle
10.3.3  Pod phases
10.3.4  Container states
10.3.5  restartPolicy
10.3.6  Labels
10.3.7  Selectors
10.3.8  Annotations
10.3.9  Labels vs annotations
10.3.10 OwnerReferences
10.3.11 generatedName
10.3.12 YAML anatomy
10.3.13 Common selector bugs
10.3.14 Hands-on manifests
10.3.15 Validation script
10.3.16 Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="eh1vfl"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.3-pods-labels-annotations-selectors/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="acwoum"
tree -L 2 10.3-pods-labels-annotations-selectors
```

---

# 3. Pod Mental Model

A Pod is not just “a container.”

A better definition:

```text id="ad0xm7"
Pod = the smallest Kubernetes workload unit that wraps one or more containers.
```

Most real applications use:

```text id="xsihdh"
1 Pod = 1 main application container
```

But Kubernetes allows:

```text id="yyw78c"
1 Pod = main container + helper containers
```

Example:

```text id="r4s1vp"
Pod
├── app container
├── sidecar log shipper
└── shared volume
```

Officially, a Pod represents a set of running containers in a cluster. Containers inside the same Pod share network namespace and can communicate over `localhost`. ([Kubernetes][1])

---

# 4. Big Misconception: Pod vs Container

Wrong thinking:

```text id="p1tzx0"
Kubernetes runs containers directly.
```

Correct thinking:

```text id="fjyjn3"
Kubernetes schedules Pods.
Pods contain containers.
Nodes run Pods.
Container runtime runs containers.
```

Flow:

```text id="af159l"
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Container
```

This is why many Kubernetes commands are Pod-focused:

```bash id="xdwt94"
kubectl get pods
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl exec -it POD_NAME -- sh
```

---

# 5. Pod Lifecycle

A Pod goes through lifecycle phases.

Common phases:

```text id="r7pi5o"
Pending
Running
Succeeded
Failed
Unknown
```

Meaning:

```text id="htmbfz"
Pending:
  Pod accepted by Kubernetes, but one or more containers are not running yet.

Running:
  Pod is bound to a node and at least one container is running or starting/restarting.

Succeeded:
  All containers finished successfully and will not restart.

Failed:
  All containers terminated, and at least one failed.

Unknown:
  Kubernetes cannot determine Pod state, often due to node communication issues.
```

Pod phase is a high-level summary. It does not tell you every detail. For deep debugging, inspect:

```bash id="xsydmw"
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get pod POD_NAME -n NAMESPACE -o yaml
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

---

# 6. Container States Inside a Pod

A Pod phase is not the same as a container state.

Container states include:

```text id="mhrsbz"
Waiting
Running
Terminated
```

Examples:

```text id="1sjiqh"
Waiting:
  Image is pulling
  Container is waiting to start
  CrashLoopBackOff
  ImagePullBackOff

Running:
  Container is currently executing

Terminated:
  Container completed or crashed
```

Check container state:

```bash id="7q0xly"
kubectl get pod POD_NAME -n dev -o jsonpath='{.status.containerStatuses[*].state}'
echo
```

Pretty view:

```bash id="gby5yd"
kubectl get pod POD_NAME -n dev -o yaml | less
```

Look for:

```text id="ge9fv7"
status:
  containerStatuses:
    state:
    lastState:
    restartCount:
    ready:
```

Important troubleshooting point:

```text id="ujbrmr"
restartCount tells you how many times the container restarted.
lastState tells you why it previously stopped.
```

---

# 7. restartPolicy

Pod `restartPolicy` tells kubelet when to restart containers in the Pod.

Common values:

```text id="4ytjg3"
Always
OnFailure
Never
```

Meaning:

```text id="3n3kzz"
Always:
  Restart containers whenever they stop.
  Common for Deployments.

OnFailure:
  Restart only if container exits with non-zero status.
  Common for Jobs.

Never:
  Do not restart stopped containers.
```

Important point:

```text id="yi8crd"
restartPolicy restarts containers inside the same Pod.
It does not create a new Pod by itself.
```

For Deployments, the Deployment/ReplicaSet controller also ensures the desired number of Pods exists. So there are two related but different ideas:

```text id="rj6k01"
kubelet:
  restarts containers inside an existing Pod

Deployment/ReplicaSet:
  creates replacement Pods if Pods are deleted
```

The kubelet restarts containers according to restart policy and uses exponential backoff for repeated failures, capped at a maximum delay. ([Kubernetes][1])

---

# 8. Create Notes File

```bash id="efzlr7"
nano 10.3-pods-labels-annotations-selectors/notes/pod-lifecycle-mental-model.md
```

Paste:

````markdown id="vwzfdd"
# Pod Lifecycle Mental Model

## Pod

A Pod is the smallest Kubernetes workload unit.

Most commonly:

```text
1 Pod = 1 application container
````

But a Pod can contain multiple containers that share network and volumes.

## Pod Phases

* Pending
* Running
* Succeeded
* Failed
* Unknown

## Container States

* Waiting
* Running
* Terminated

## restartPolicy

* Always
* OnFailure
* Never

## Important Difference

Pod phase is a high-level summary.

Container state gives deeper detail.

## Debug Commands

```bash
kubectl get pods
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl logs POD_NAME --previous
kubectl get events --sort-by=.lastTimestamp
```

## Golden Rule

For Pod issues, inspect phase, container state, restart count, last state, events, and logs.

````

---

# 9. Labels

Labels are key-value pairs attached to Kubernetes objects.

They are used for:

```text id="ozzunc"
grouping
filtering
selecting
routing
organizing
automation
ownership patterns
environment separation
````

Officially, labels are key-value pairs attached to objects such as Pods, and they are intended to specify identifying attributes that are meaningful to users. Labels can be used to organize and select subsets of objects. ([Kubernetes][2])

Example:

```yaml id="g7y1bb"
metadata:
  labels:
    app: demo-node-api
    environment: dev
    tier: backend
    version: v1
```

Common label strategy:

```text id="6lpk75"
app:
  application name

environment:
  dev, staging, production

tier:
  frontend, backend, database

version:
  v1, v2

managed-by:
  kubectl, helm, argocd

team:
  platform, payments, data
```

---

# 10. Selectors

Selectors find objects by label.

Example:

```bash id="ta3df6"
kubectl get pods -l app=demo-node-api
```

This means:

```text id="ar67se"
Find Pods where label app equals demo-node-api.
```

There are two selector styles:

```text id="8vqqae"
equality-based
set-based
```

## Equality-Based Selectors

```bash id="e4x72l"
kubectl get pods -l app=whoami
kubectl get pods -l environment=dev
kubectl get pods -l app=whoami,environment=dev
```

## Negative Selector

```bash id="b8bday"
kubectl get pods -l environment!=production
```

## Set-Based Selectors

```bash id="ebgzi4"
kubectl get pods -l 'environment in (dev,staging)'
kubectl get pods -l 'tier notin (database,cache)'
```

Selectors matter because many Kubernetes objects use them:

```text id="z7lp8u"
Deployment selector:
  chooses Pods it owns

Service selector:
  chooses Pods that receive traffic

NetworkPolicy selector:
  chooses Pods affected by policy

PodDisruptionBudget selector:
  chooses Pods protected by disruption budget

ServiceMonitor selector:
  chooses targets for monitoring
```

---

# 11. Critical Selector Rule

A Service routes traffic to Pods selected by labels.

If this matches:

```yaml id="r1uxom"
Service selector:
  app: demo-node-api
```

Then Pods must have:

```yaml id="pvrr96"
metadata:
  labels:
    app: demo-node-api
```

If not:

```text id="z6780v"
Service has no endpoints.
Traffic fails.
```

This is one of the most common Kubernetes mistakes.

---

# 12. Annotations

Annotations are metadata too, but they are not used for selection.

Officially, labels can be used to select objects, while annotations are not used to identify and select objects. Annotation metadata can be small or large, structured or unstructured, and may include characters that labels do not allow. ([Kubernetes][3])

Example:

```yaml id="vxw9dw"
metadata:
  annotations:
    owner: "platform-team"
    runbook: "https://internal.example.com/runbooks/demo-node-api"
    description: "Production backend API"
    last-reviewed: "2026-07-13"
```

Use annotations for:

```text id="nrk387"
descriptions
runbook links
Git commit SHA
build metadata
monitoring hints
ingress controller configuration
cert-manager configuration
external-dns configuration
policy metadata
```

---

# 13. Labels vs Annotations

| Feature                    | Labels     | Annotations |
| -------------------------- | ---------- | ----------- |
| Key-value metadata         | Yes        | Yes         |
| Used for selection         | Yes        | No          |
| Used by Services           | Yes        | No          |
| Used by Deployments        | Yes        | No          |
| Good for filtering         | Yes        | No          |
| Good for long metadata     | No         | Yes         |
| Good for runbook links     | Usually no | Yes         |
| Good for team/app/env      | Yes        | Sometimes   |
| Good for controller config | Sometimes  | Yes         |

Golden rule:

```text id="q27uzm"
Use labels to select.
Use annotations to describe.
```

Bad:

```yaml id="qvtg7s"
metadata:
  annotations:
    app: demo-node-api
```

Better:

```yaml id="ncrq3g"
metadata:
  labels:
    app: demo-node-api
  annotations:
    description: "Node.js backend API"
```

---

# 14. OwnerReferences

Kubernetes uses owner references to track ownership between objects.

Example:

```text id="sv5cwo"
Deployment
  owns ReplicaSet
    owns Pods
```

A dependent object has `metadata.ownerReferences` pointing to its owner. Kubernetes automatically sets owner references for dependents of objects such as ReplicaSets, Deployments, Jobs, CronJobs, DaemonSets, and similar controllers. ([Kubernetes][4])

Why it matters:

```text id="upvu2p"
kubectl delete deployment my-app
  ↓
ReplicaSet is deleted
  ↓
Pods are deleted
```

This is garbage collection.

A ReplicaSet is linked to its Pods using the Pods’ `metadata.ownerReferences`, and that link lets the ReplicaSet know which Pods it maintains. ([Kubernetes][5])

Check owner references:

```bash id="qf8z1g"
kubectl get pod POD_NAME -n dev -o jsonpath='{.metadata.ownerReferences}'
echo
```

Pretty:

```bash id="hh3tyk"
kubectl get pod POD_NAME -n dev -o yaml | grep -A20 ownerReferences
```

---

# 15. generatedName

Sometimes Kubernetes can generate object names.

Instead of:

```yaml id="men4gb"
metadata:
  name: demo-pod
```

You can use:

```yaml id="fewcpn"
metadata:
  generateName: demo-pod-
```

Kubernetes then creates a unique name with that prefix.

Example result:

```text id="ah11vr"
demo-pod-abc12
demo-pod-k9f5x
```

Each Kubernetes object has a `name` unique for that resource type within its namespace, and a UID unique across the whole cluster. Kubernetes can also generate names from `generateName` by appending a generated suffix. ([Kubernetes][6])

Use cases:

```text id="p7er18"
temporary Pods
Jobs
generated test resources
controllers creating child objects
```

Production rule:

```text id="x085dy"
For stable application resources, use explicit names.
For temporary/generated resources, generatedName can be useful.
```

---

# 16. YAML Anatomy Deep Dive

Every Kubernetes object generally has:

```yaml id="w6e87i"
apiVersion:
kind:
metadata:
spec:
```

Kubernetes objects are persistent entities in the Kubernetes API; they represent desired state such as which applications are running, what resources are available, and what policies control behavior. ([Kubernetes][7])

Example:

```yaml id="f0q59c"
apiVersion: v1
kind: Pod
metadata:
  name: demo-pod
  namespace: dev
  labels:
    app: demo
spec:
  containers:
    - name: app
      image: nginx:1.27-alpine
```

Meaning:

```text id="goy3ow"
apiVersion:
  Which API group/version handles this object.

kind:
  Type of object.

metadata:
  Identity and metadata.

spec:
  Desired state written by user.

status:
  Actual state written by Kubernetes.
```

Important:

```text id="ywzcfm"
You normally do not write status in YAML.
Kubernetes writes status.
```

---

# 17. Hands-On: Create Namespace

Use the existing `dev` namespace from Lesson 10.2.

Check:

```bash id="awyfy5"
kubectl get namespace dev
```

If missing:

```bash id="2wqzb4"
kubectl create namespace dev
```

Set namespace:

```bash id="2qe732"
kubectl config set-context --current --namespace=dev
```

Verify:

```bash id="66wo4v"
kubectl config view --minify | grep namespace
```

---

# 18. Hands-On Pod with Labels and Annotations

Create:

```bash id="vl4f0p"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-labels-annotations.yaml
```

Paste:

```yaml id="rhhke8"
apiVersion: v1
kind: Pod
metadata:
  name: labeled-nginx
  namespace: dev
  labels:
    app: nginx
    environment: dev
    tier: frontend
    version: v1
  annotations:
    owner: "platform-team"
    description: "Demo Pod for labels and annotations"
    runbook: "10.3-pods-labels-annotations-selectors/runbooks/pod-debugging-runbook.md"
spec:
  restartPolicy: Always
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
```

Apply:

```bash id="ysx0za"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-labels-annotations.yaml
```

Inspect:

```bash id="wmbzed"
kubectl get pod labeled-nginx -n dev
kubectl get pod labeled-nginx -n dev --show-labels
kubectl describe pod labeled-nginx -n dev
```

Get labels:

```bash id="mkhdt2"
kubectl get pod labeled-nginx -n dev -o jsonpath='{.metadata.labels}'
echo
```

Get annotations:

```bash id="p9958u"
kubectl get pod labeled-nginx -n dev -o jsonpath='{.metadata.annotations}'
echo
```

---

# 19. Filter with Labels

Run:

```bash id="6byyo1"
kubectl get pods -n dev -l app=nginx
kubectl get pods -n dev -l environment=dev
kubectl get pods -n dev -l tier=frontend
kubectl get pods -n dev -l app=nginx,version=v1
```

Set-based:

```bash id="8b3zpy"
kubectl get pods -n dev -l 'environment in (dev,staging)'
kubectl get pods -n dev -l 'tier notin (backend,database)'
```

Negative:

```bash id="z65ymk"
kubectl get pods -n dev -l environment!=production
```

---

# 20. Add and Remove Labels Live

Add label:

```bash id="0ryumv"
kubectl label pod labeled-nginx -n dev release=canary
```

Check:

```bash id="700qvw"
kubectl get pod labeled-nginx -n dev --show-labels
```

Overwrite label:

```bash id="shstbl"
kubectl label pod labeled-nginx -n dev release=stable --overwrite
```

Remove label:

```bash id="tbcv2r"
kubectl label pod labeled-nginx -n dev release-
```

Check:

```bash id="4mbd3d"
kubectl get pod labeled-nginx -n dev --show-labels
```

Production warning:

```text id="9tz8ch"
Live label edits can change traffic routing if Services, NetworkPolicies, or monitoring selectors depend on those labels.
```

---

# 21. Add and Remove Annotations Live

Add annotation:

```bash id="rmns0o"
kubectl annotate pod labeled-nginx -n dev reviewed-by=vivek
```

Check:

```bash id="gqy2bh"
kubectl describe pod labeled-nginx -n dev | grep -A10 Annotations
```

Overwrite:

```bash id="noap5k"
kubectl annotate pod labeled-nginx -n dev reviewed-by=platform-team --overwrite
```

Remove:

```bash id="97wbhh"
kubectl annotate pod labeled-nginx -n dev reviewed-by-
```

Important:

```text id="dbfhvc"
Changing annotations usually does not change Service selection.
Changing labels can change selection and traffic behavior.
```

---

# 22. Hands-On Deployment with Labels

Create:

```bash id="6z3vlb"
nano 10.3-pods-labels-annotations-selectors/manifests/deployment-label-selector.yaml
```

Paste:

```yaml id="4o1w5v"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: label-demo
  namespace: dev
  labels:
    app: label-demo
    environment: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: label-demo
      environment: dev
  template:
    metadata:
      labels:
        app: label-demo
        environment: dev
        tier: backend
        version: v1
      annotations:
        owner: "platform-team"
        purpose: "selector practice"
    spec:
      containers:
        - name: app
          image: traefik/whoami:v1.10
          ports:
            - containerPort: 80
```

Apply:

```bash id="z4kh4w"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/deployment-label-selector.yaml
```

Check:

```bash id="vq4nqo"
kubectl get deployment label-demo -n dev
kubectl get rs -n dev
kubectl get pods -n dev -l app=label-demo --show-labels
```

Owner chain:

```bash id="1z1m44"
POD_NAME="$(kubectl get pods -n dev -l app=label-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.metadata.ownerReferences}'
echo
```

Pretty:

```bash id="yoj0rr"
kubectl get pod "$POD_NAME" -n dev -o yaml | grep -A20 ownerReferences
```

You should see owner kind similar to:

```text id="lq5i62"
ReplicaSet
```

Then inspect the ReplicaSet owner:

```bash id="htblvg"
RS_NAME="$(kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.metadata.ownerReferences[0].name}')"

kubectl get rs "$RS_NAME" -n dev -o yaml | grep -A20 ownerReferences
```

You should see owner kind similar to:

```text id="qvynxa"
Deployment
```

---

# 23. Hands-On Service Selector

Create:

```bash id="9fv791"
nano 10.3-pods-labels-annotations-selectors/manifests/service-label-selector.yaml
```

Paste:

```yaml id="4xvjsj"
apiVersion: v1
kind: Service
metadata:
  name: label-demo
  namespace: dev
  labels:
    app: label-demo
spec:
  type: ClusterIP
  selector:
    app: label-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply:

```bash id="8abpwr"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/service-label-selector.yaml
```

Check:

```bash id="x4w9pv"
kubectl get svc label-demo -n dev
kubectl get endpoints label-demo -n dev
kubectl describe svc label-demo -n dev
```

Test:

```bash id="oh7abi"
kubectl port-forward -n dev svc/label-demo 8081:80
```

Another terminal:

```bash id="bkm6zj"
curl http://127.0.0.1:8081
```

Stop port-forward:

```text id="myxyye"
Ctrl + C
```

---

# 24. Intentional Selector Bug

Now create a broken Service.

```bash id="drqfj6"
nano 10.3-pods-labels-annotations-selectors/manifests/service-wrong-selector.yaml
```

Paste:

```yaml id="8hq8kp"
apiVersion: v1
kind: Service
metadata:
  name: label-demo-broken
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: does-not-exist
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply:

```bash id="khd071"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/service-wrong-selector.yaml
```

Check:

```bash id="j9bfgj"
kubectl get svc label-demo-broken -n dev
kubectl get endpoints label-demo-broken -n dev
kubectl describe svc label-demo-broken -n dev
```

You should see no endpoints.

Why?

```text id="r3f1u7"
Service selector app=does-not-exist matches zero Pods.
```

Fix by deleting broken Service:

```bash id="utfij9"
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/service-wrong-selector.yaml
```

Lesson:

```text id="s6h1y8"
No endpoints usually means selector mismatch or Pods are not ready.
```

---

# 25. Pod Lifecycle Demo: Succeeded Pod

Create a Pod that finishes successfully.

```bash id="nk2v3p"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-succeeded.yaml
```

Paste:

```yaml id="edgkys"
apiVersion: v1
kind: Pod
metadata:
  name: pod-succeeded-demo
  namespace: dev
  labels:
    app: lifecycle-demo
    outcome: succeeded
spec:
  restartPolicy: Never
  containers:
    - name: success
      image: busybox:1.36
      command: ["sh", "-c", "echo 'I will complete successfully'; sleep 2; exit 0"]
```

Apply:

```bash id="waln3g"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-succeeded.yaml
```

Watch:

```bash id="8t9sgx"
kubectl get pod pod-succeeded-demo -n dev -w
```

Exit with:

```text id="xj5dw1"
Ctrl + C
```

Check:

```bash id="aum32v"
kubectl describe pod pod-succeeded-demo -n dev
kubectl logs pod-succeeded-demo -n dev
```

Expected phase:

```text id="forqwv"
Succeeded
```

---

# 26. Pod Lifecycle Demo: Failed Pod

Create:

```bash id="9mfbpo"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-failed.yaml
```

Paste:

```yaml id="uyx9h8"
apiVersion: v1
kind: Pod
metadata:
  name: pod-failed-demo
  namespace: dev
  labels:
    app: lifecycle-demo
    outcome: failed
spec:
  restartPolicy: Never
  containers:
    - name: fail
      image: busybox:1.36
      command: ["sh", "-c", "echo 'I will fail intentionally'; sleep 2; exit 1"]
```

Apply:

```bash id="dtyu15"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-failed.yaml
```

Watch:

```bash id="0uxbxb"
kubectl get pod pod-failed-demo -n dev -w
```

Exit with:

```text id="id6qki"
Ctrl + C
```

Inspect:

```bash id="eg4u2d"
kubectl describe pod pod-failed-demo -n dev
kubectl logs pod-failed-demo -n dev
```

Expected phase:

```text id="yzoxro"
Failed
```

---

# 27. CrashLoopBackOff Demo

Create:

```bash id="79bg9t"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-crashloop.yaml
```

Paste:

```yaml id="e9hanm"
apiVersion: v1
kind: Pod
metadata:
  name: pod-crashloop-demo
  namespace: dev
  labels:
    app: lifecycle-demo
    outcome: crashloop
spec:
  restartPolicy: Always
  containers:
    - name: crash
      image: busybox:1.36
      command: ["sh", "-c", "echo 'crashing intentionally'; sleep 2; exit 1"]
```

Apply:

```bash id="sjvw10"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-crashloop.yaml
```

Watch:

```bash id="ouo9dt"
kubectl get pod pod-crashloop-demo -n dev -w
```

After some time, you should see:

```text id="yn8290"
CrashLoopBackOff
```

Exit:

```text id="c1mcw0"
Ctrl + C
```

Inspect:

```bash id="0r9oh0"
kubectl describe pod pod-crashloop-demo -n dev
kubectl logs pod-crashloop-demo -n dev
kubectl logs pod-crashloop-demo -n dev --previous
kubectl get events -n dev --sort-by=.lastTimestamp
```

Important:

```text id="wlpzlx"
--previous is useful because the current container may have already restarted.
```

---

# 28. Pending Pod Demo

Create a Pod that cannot be scheduled because it requests too much CPU.

```bash id="yhp7l7"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-pending.yaml
```

Paste:

```yaml id="pgv3ok"
apiVersion: v1
kind: Pod
metadata:
  name: pod-pending-demo
  namespace: dev
  labels:
    app: lifecycle-demo
    outcome: pending
spec:
  containers:
    - name: huge-request
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "1000"
          memory: "1Gi"
```

Apply:

```bash id="v57xc0"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-pending.yaml
```

Check:

```bash id="v4uoz2"
kubectl get pod pod-pending-demo -n dev
kubectl describe pod pod-pending-demo -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text id="r7w30a"
Pending
Insufficient cpu
```

Delete after observing:

```bash id="g49c14"
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-pending.yaml
```

This is a preview of scheduling troubleshooting.

---

# 29. generatedName Demo

Create:

```bash id="1n808n"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-generated-name.yaml
```

Paste:

```yaml id="bzwjwe"
apiVersion: v1
kind: Pod
metadata:
  generateName: generated-demo-
  namespace: dev
  labels:
    app: generated-demo
spec:
  restartPolicy: Never
  containers:
    - name: hello
      image: busybox:1.36
      command: ["sh", "-c", "echo generated pod; sleep 5"]
```

Apply multiple times:

```bash id="2l7b75"
kubectl create -f 10.3-pods-labels-annotations-selectors/manifests/pod-generated-name.yaml
kubectl create -f 10.3-pods-labels-annotations-selectors/manifests/pod-generated-name.yaml
kubectl create -f 10.3-pods-labels-annotations-selectors/manifests/pod-generated-name.yaml
```

Check:

```bash id="ql6kfv"
kubectl get pods -n dev -l app=generated-demo
```

You should see multiple Pods with generated suffixes.

Delete:

```bash id="lgkzsn"
kubectl delete pods -n dev -l app=generated-demo
```

---

# 30. Init Container Demo

Init containers run before the main app container and must complete before app containers start. Kubernetes init containers are designed to run to completion during Pod initialization. ([Kubernetes][8])

Create:

```bash id="ycq5n0"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-init-container.yaml
```

Paste:

```yaml id="6uuehp"
apiVersion: v1
kind: Pod
metadata:
  name: init-container-demo
  namespace: dev
  labels:
    app: init-demo
spec:
  initContainers:
    - name: init-message
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Init container running first'; sleep 5"]
  containers:
    - name: main
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Main container started'; sleep 3600"]
```

Apply:

```bash id="v0cehu"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-init-container.yaml
```

Watch:

```bash id="pc73gk"
kubectl get pod init-container-demo -n dev -w
```

Inspect init status:

```bash id="hf6bq0"
kubectl describe pod init-container-demo -n dev
```

Logs for init container:

```bash id="su085u"
kubectl logs init-container-demo -n dev -c init-message
```

Logs for main container:

```bash id="8ie4qn"
kubectl logs init-container-demo -n dev -c main
```

Use case:

```text id="wfxkhq"
wait for dependency
prepare files
run migration carefully
check config before app starts
```

Warning:

```text id="ku660m"
Do not put long-running processes in normal init containers.
They must complete before the app starts.
```

---

# 31. Multi-Container Pod Demo

Create:

```bash id="q3f2ep"
nano 10.3-pods-labels-annotations-selectors/manifests/pod-multi-container.yaml
```

Paste:

```yaml id="8jtgv0"
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-demo
  namespace: dev
  labels:
    app: multi-container-demo
spec:
  volumes:
    - name: shared-logs
      emptyDir: {}
  containers:
    - name: writer
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          i=0
          while true; do
            echo "log line $i from writer" >> /var/log/shared/app.log
            i=$((i+1))
            sleep 3
          done
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/shared

    - name: reader
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          touch /var/log/shared/app.log
          tail -f /var/log/shared/app.log
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log/shared
```

Apply:

```bash id="udq0bi"
kubectl apply -f 10.3-pods-labels-annotations-selectors/manifests/pod-multi-container.yaml
```

Check:

```bash id="v30b1g"
kubectl get pod multi-container-demo -n dev
```

Logs from writer:

```bash id="tlxjuy"
kubectl logs multi-container-demo -n dev -c writer
```

Logs from reader:

```bash id="49e09b"
kubectl logs multi-container-demo -n dev -c reader
```

Exec into reader:

```bash id="ybej9n"
kubectl exec -it multi-container-demo -n dev -c reader -- sh
```

Inside:

```sh id="2rj5yv"
cat /var/log/shared/app.log
exit
```

Lesson:

```text id="aq7xcs"
Containers in the same Pod can share volumes.
```

---

# 32. Sidecar Concept

A sidecar is a helper container that runs alongside the main application container.

Examples:

```text id="bl63ae"
log shipper
proxy
service mesh sidecar
metrics exporter
file synchronizer
security agent
```

Kubernetes now documents sidecar containers as a special case of init containers that remain running after Pod startup, while regular init containers run only during startup and complete. ([Kubernetes][9])

Simple mental model:

```text id="yzgnqm"
init container:
  runs before app, then exits

sidecar:
  runs with app, supports app
```

We will go deeper into sidecars later when we cover logging, service mesh, and production runtime patterns.

---

# 33. Pod Debugging Runbook

Create:

```bash id="c8pn60"
nano 10.3-pods-labels-annotations-selectors/runbooks/pod-debugging-runbook.md
```

Paste:

````markdown id="or52mc"
# Pod Debugging Runbook

## Step 1 — Check Pod Status

```bash
kubectl get pods -n NAMESPACE
kubectl get pods -n NAMESPACE -o wide
````

## Step 2 — Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* Events
* Node
* Image
* State
* Last State
* Restart Count
* Conditions
* Volumes
* Environment

## Step 3 — Check Logs

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

For multi-container Pods:

```bash
kubectl logs POD_NAME -n NAMESPACE -c CONTAINER_NAME
```

## Step 4 — Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Step 5 — Check Owner

```bash
kubectl get pod POD_NAME -n NAMESPACE -o jsonpath='{.metadata.ownerReferences}'
```

## Step 6 — Check Labels

```bash
kubectl get pod POD_NAME -n NAMESPACE --show-labels
```

## Common Issues

| Symptom                | Likely Cause                          |
| ---------------------- | ------------------------------------- |
| Pending                | Scheduling/resource/node issue        |
| ImagePullBackOff       | Bad image/tag/registry/auth           |
| CrashLoopBackOff       | App starts then exits repeatedly      |
| Running but no traffic | Service selector/port/readiness issue |
| Succeeded              | Short-lived process completed         |
| Failed                 | Process exited with failure           |

## Golden Rule

Always check describe, logs, events, labels, and ownerReferences.

````

---

# 34. Selector Debugging Runbook

Create:

```bash id="eq6i6z"
nano 10.3-pods-labels-annotations-selectors/runbooks/selector-debugging-runbook.md
````

Paste:

````markdown id="p3r464"
# Selector Debugging Runbook

## Problem

Service has no endpoints or traffic does not reach Pods.

## Step 1 — Check Service Selector

```bash
kubectl describe svc SERVICE_NAME -n NAMESPACE
````

## Step 2 — Check Pod Labels

```bash
kubectl get pods -n NAMESPACE --show-labels
```

## Step 3 — Query Matching Pods

```bash
kubectl get pods -n NAMESPACE -l app=VALUE
```

## Step 4 — Check Endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
```

## Common Root Cause

Service selector does not match Pod labels.

## Example

Service selector:

```yaml
selector:
  app: backend
```

Pod labels must include:

```yaml
labels:
  app: backend
```

## Golden Rule

Traffic follows selectors. Wrong labels mean wrong traffic.

````

---

# 35. Validation Script

Create:

```bash id="3ef44n"
nano 10.3-pods-labels-annotations-selectors/scripts/validate-lesson-10-3.sh
````

Paste:

```bash id="zlywjj"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.3 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get pod labeled-nginx -n dev >/dev/null
kubectl get deployment label-demo -n dev >/dev/null
kubectl get service label-demo -n dev >/dev/null

LABEL_VALUE="$(kubectl get pod labeled-nginx -n dev -o jsonpath='{.metadata.labels.app}')"
if [ "$LABEL_VALUE" != "nginx" ]; then
  echo "ERROR: labeled-nginx app label mismatch"
  exit 1
fi

ANNOTATION_VALUE="$(kubectl get pod labeled-nginx -n dev -o jsonpath='{.metadata.annotations.owner}')"
if [ "$ANNOTATION_VALUE" != "platform-team" ]; then
  echo "ERROR: labeled-nginx owner annotation mismatch"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints label-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: label-demo service has no endpoints"
  exit 1
fi

PODS_MATCHING_SELECTOR="$(kubectl get pods -n dev -l app=label-demo,environment=dev --no-headers | wc -l)"
if [ "$PODS_MATCHING_SELECTOR" -lt 1 ]; then
  echo "ERROR: expected Pods matching app=label-demo,environment=dev"
  exit 1
fi

test -f 10.3-pods-labels-annotations-selectors/notes/pod-lifecycle-mental-model.md
test -f 10.3-pods-labels-annotations-selectors/runbooks/pod-debugging-runbook.md
test -f 10.3-pods-labels-annotations-selectors/runbooks/selector-debugging-runbook.md

echo "Lesson 10.3 validation passed."
```

Make executable:

```bash id="qvvp9w"
chmod +x 10.3-pods-labels-annotations-selectors/scripts/validate-lesson-10-3.sh
```

Run:

```bash id="vh6v1v"
./10.3-pods-labels-annotations-selectors/scripts/validate-lesson-10-3.sh
```

---

# 36. Cleanup Script

Create:

```bash id="gfth2u"
nano 10.3-pods-labels-annotations-selectors/scripts/cleanup-lesson-10-3.sh
```

Paste:

```bash id="js4ug0"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.3 ====="

kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/service-label-selector.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/service-wrong-selector.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/deployment-label-selector.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-labels-annotations.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-succeeded.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-failed.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-crashloop.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-pending.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-generated-name.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-init-container.yaml --ignore-not-found=true
kubectl delete -f 10.3-pods-labels-annotations-selectors/manifests/pod-multi-container.yaml --ignore-not-found=true

kubectl delete pods -n dev -l app=generated-demo --ignore-not-found=true

echo "Lesson 10.3 resources cleaned."
```

Make executable:

```bash id="lx30ur"
chmod +x 10.3-pods-labels-annotations-selectors/scripts/cleanup-lesson-10-3.sh
```

Run only if you want cleanup:

```bash id="rp4vmm"
./10.3-pods-labels-annotations-selectors/scripts/cleanup-lesson-10-3.sh
```

---

# 37. Common Myths and Misconceptions

## Myth 1: Labels are only for humans

Wrong.

Labels are used by Kubernetes controllers and networking objects.

Examples:

```text id="gbbs42"
Deployment selector
Service selector
NetworkPolicy selector
PodDisruptionBudget selector
monitoring selector
```

## Myth 2: Annotations and labels are the same

Wrong.

```text id="ig1ffu"
Labels:
  select and group objects

Annotations:
  store descriptive or controller-specific metadata
```

## Myth 3: Pod name is the best way to route traffic

Wrong.

Pod names are unstable for managed workloads.

Use labels and Services.

## Myth 4: Pod phase tells the full story

Wrong.

Pod phase is only a summary.

For real debugging, check:

```text id="d96my8"
container state
last state
restart count
events
logs
conditions
ownerReferences
```

## Myth 5: If a Service exists, traffic must work

Wrong.

A Service with no matching endpoints routes nowhere.

Check:

```bash id="90dqoy"
kubectl get endpoints SERVICE_NAME -n NAMESPACE
```

## Myth 6: Deleting a Pod always removes the app

If the Pod is owned by a Deployment, it comes back.

Why?

```text id="qoxper"
Deployment desired state says replicas=3.
ReplicaSet recreates missing Pods.
```

---

# 38. Production Labeling Strategy

For real projects, use consistent labels.

Recommended for your `demo-node-api`:

```yaml id="ayd1lq"
labels:
  app.kubernetes.io/name: demo-node-api
  app.kubernetes.io/instance: demo-node-api-dev
  app.kubernetes.io/version: "0.1.0"
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: todo-app
  app.kubernetes.io/managed-by: kubectl
  environment: dev
  team: platform
```

Kubernetes documents well-known labels and annotations, including reserved namespaces such as `kubernetes.io` and `k8s.io`; using standard app labels like `app.kubernetes.io/name` and similar conventions improves consistency across tools. ([Kubernetes][10])

Simple learning version:

```yaml id="tg3rji"
labels:
  app: demo-node-api
  environment: dev
  tier: backend
```

Production version:

```yaml id="758ow8"
labels:
  app.kubernetes.io/name: demo-node-api
  app.kubernetes.io/component: backend
  environment: production
```

---

# 39. Interview Explanation

Use this:

```text id="v9h7kr"
A Pod is the smallest deployable unit in Kubernetes. It can contain one or more containers that share network and volumes. The Pod lifecycle includes phases like Pending, Running, Succeeded, Failed, and Unknown, while individual containers have states like Waiting, Running, and Terminated.

Labels are key-value pairs used to organize and select Kubernetes objects. Selectors use labels to connect objects, such as Services selecting Pods or Deployments managing Pods. Annotations are also metadata, but they are not used for selection; they are better for descriptive or tool-specific information.

OwnerReferences show which controller owns an object. For example, a Deployment owns a ReplicaSet, and the ReplicaSet owns Pods. This ownership chain enables Kubernetes garbage collection and self-healing behavior.
```

Resume version:

```text id="r2a5yh"
Built hands-on Kubernetes foundations covering Pod lifecycle, container states, restart policies, labels, annotations, selectors, ownerReferences, init containers, multi-container Pods, Service endpoint debugging, and validation scripts.
```

---

# 40. Today’s Core Rules

```text id="uioylg"
Pod is the smallest Kubernetes workload unit.
Pods contain containers.
Pod phase is not the same as container state.
restartPolicy controls container restart behavior inside a Pod.
Labels are for selection and grouping.
Annotations are for descriptive/tool metadata.
Services route to Pods through selectors.
Wrong selectors create empty endpoints.
Deployments own ReplicaSets.
ReplicaSets own Pods.
ownerReferences explain the ownership chain.
generatedName creates unique object names from a prefix.
Use describe, logs, events, labels, selectors, and endpoints for debugging.
```

---

# 41. Commit Lesson 10.3

From repo root:

```bash id="ciii7z"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes Pods labels annotations and selectors deep dive"

git push
```

---

# Next Lesson

```text id="osj1ps"
Lesson 10.4 — Deployments, ReplicaSets, Rollouts, Rollbacks, and Deployment Strategies
```

We will cover:

```text id="wsewgr"
Deployment controller deep dive
ReplicaSet relationship
rolling updates
rollout history
rollback
revision tracking
maxSurge
maxUnavailable
Recreate strategy
RollingUpdate strategy
blue-green concept
canary concept
image update workflow
bad rollout simulation
production deployment manifest for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/?utm_source=chatgpt.com "Pod Lifecycle"
[2]: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/?utm_source=chatgpt.com "Labels and Selectors"
[3]: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/?utm_source=chatgpt.com "Annotations"
[4]: https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/?utm_source=chatgpt.com "Owners and Dependents"
[5]: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/?utm_source=chatgpt.com "ReplicaSet"
[6]: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/?utm_source=chatgpt.com "Object Names and IDs"
[7]: https://kubernetes.io/docs/concepts/overview/working-with-objects/?utm_source=chatgpt.com "Objects In Kubernetes"
[8]: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/?utm_source=chatgpt.com "Init Containers"
[9]: https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/?utm_source=chatgpt.com "Sidecar Containers"
[10]: https://kubernetes.io/docs/reference/labels-annotations-taints/?utm_source=chatgpt.com "Well-Known Labels, Annotations and Taints"
