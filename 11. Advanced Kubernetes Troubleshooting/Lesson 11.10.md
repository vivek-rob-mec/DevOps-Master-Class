# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.10 — Scheduling Failures, Taints, Affinity, Topology, and Resource Shortages

In Lesson 11.9, you debugged the **node layer**:

```text id="recap-11-9"
Node conditions
Node NotReady concepts
MemoryPressure
DiskPressure
PIDPressure
Evicted Pods
kubelet troubleshooting
container runtime checks
cordon and uncordon
safe drain workflow
PDB blocking drain
Pods failing only on one node
```

Now we go deeper into **scheduler-level troubleshooting**.

A Pod can be perfectly valid YAML, but still never start because the Kubernetes scheduler cannot find a suitable node.

Common symptoms:

```text id="scheduler-symptoms"
Pod stays Pending
FailedScheduling events
0/3 nodes are available
insufficient cpu
insufficient memory
node(s) didn't match node selector
node(s) didn't match Pod's node affinity
node(s) had untolerated taint
node(s) didn't satisfy pod anti-affinity
topology spread constraints blocked scheduling
PVC is waiting for first consumer
quota exceeded
preemption is not helpful
```

Kubernetes scheduling means matching Pods to Nodes so kubelet can run them. If a Pod is stuck in `Pending`, it often means the scheduler cannot place it on a node due to resources, constraints, taints, affinity, volumes, or policies. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="lesson-map"
11.10.1   Scheduler mental model
11.10.2   FailedScheduling event anatomy
11.10.3   Requests vs actual usage
11.10.4   insufficient CPU and memory
11.10.5   nodeSelector mismatch
11.10.6   required node affinity mismatch
11.10.7   preferred affinity behavior
11.10.8   taints and tolerations
11.10.9   NoSchedule vs PreferNoSchedule vs NoExecute
11.10.10  pod anti-affinity blocking scheduling
11.10.11  topology spread constraints
11.10.12  quota-related scheduling failures
11.10.13  PVC WaitForFirstConsumer scheduling
11.10.14  preemption messages
11.10.15  scheduler debugging workflow
11.10.16  scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="check-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures
```

---

# 3. Scheduler Mental Model

The scheduler watches for Pods that do not have a node assigned.

Then it asks:

```text id="scheduler-questions"
Which nodes are available?
Which nodes have enough requested CPU and memory?
Which nodes match nodeSelector?
Which nodes match required affinity?
Which nodes are not blocked by taints?
Which nodes satisfy topology spread?
Which nodes satisfy volume topology?
Which nodes satisfy quota/policy constraints?
Which node is the best final choice?
```

The scheduler mostly makes placement decisions based on **requested resources**, not actual live usage. Kubernetes documentation explains that the scheduler ensures requested resources fit on a node; actual runtime usage is a separate concern handled by kubelet, runtime enforcement, and eviction behavior. ([Kubernetes][2])

Simple chain:

```text id="scheduler-chain"
Pod created
  ↓
Pod has no nodeName
  ↓
scheduler evaluates nodes
  ↓
scheduler picks node
  ↓
Pod gets spec.nodeName
  ↓
kubelet on that node starts containers
```

If scheduling fails:

```text id="scheduling-fails"
Pod remains Pending
scheduler emits FailedScheduling events
kubectl describe pod shows why
```

---

# 4. Create Scheduling Mental Model Notes

```bash id="mental-model-note"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/notes/scheduler-mental-model.md
```

Paste:

```markdown id="mental-model-content"
# Kubernetes Scheduler Mental Model

## Scheduling Chain

Pod created -> scheduler evaluates nodes -> scheduler binds Pod to node -> kubelet starts containers

## Main Question

Why can this Pod not be placed on any node?

## Common Scheduling Blockers

- insufficient CPU requests
- insufficient memory requests
- nodeSelector mismatch
- required node affinity mismatch
- untolerated taints
- required pod anti-affinity
- topology spread constraints
- PVC / volume topology
- namespace ResourceQuota
- node cordoned / unschedulable
- max pod count on node
- preemption not helpful

## Golden Rule

For Pending Pods, always start with:

kubectl describe pod POD -n NAMESPACE

The scheduler usually tells you the reason in Events.
```

---

# 5. First Scheduling Debug Commands

```bash id="debug-note"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/notes/scheduling-debug-commands.md
```

Paste:

````markdown id="debug-note-content"
# Scheduling Debug Commands

## Pending Pods

```bash
kubectl get pods -A | grep Pending || true
kubectl get pods -n NAMESPACE -o wide
````

## Describe Pending Pod

```bash id="describe-pending"
kubectl describe pod POD_NAME -n NAMESPACE
```

## Events

```bash id="events"
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
kubectl get events -A --sort-by=.lastTimestamp | grep FailedScheduling || true
```

## Nodes

```bash id="nodes"
kubectl get nodes -o wide
kubectl describe node NODE_NAME
```

## Node labels

```bash id="node-labels"
kubectl get nodes --show-labels
kubectl get node NODE_NAME --show-labels
```

## Node taints

```bash id="node-taints"
kubectl describe node NODE_NAME | grep -i -A3 Taints
```

## Node capacity and allocatable

```bash id="capacity"
kubectl describe node NODE_NAME | sed -n '/Capacity:/,/System Info:/p'
kubectl describe node NODE_NAME | sed -n '/Allocated resources:/,/Events:/p'
```

## Quota

```bash id="quota"
kubectl get resourcequota -n NAMESPACE
kubectl describe resourcequota -n NAMESPACE
```

## PVCs

```bash id="pvc"
kubectl get pvc -n NAMESPACE
kubectl describe pvc PVC_NAME -n NAMESPACE
kubectl get storageclass
```

````

---

# 6. FailedScheduling Event Anatomy

A real scheduling error often looks like this:

```text id="failedscheduling-example"
0/3 nodes are available:
1 Insufficient cpu,
1 node(s) had untolerated taint {dedicated: gpu},
1 node(s) didn't match Pod's node affinity/selector.
preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
````

Breakdown:

```text id="event-breakdown"
0/3 nodes are available:
  Scheduler checked 3 nodes.
  None were suitable.

Insufficient cpu:
  Requests do not fit.

Untolerated taint:
  Node has a taint.
  Pod does not have matching toleration.

Didn't match affinity/selector:
  Hard placement rule does not match node labels.

Preemption not helpful:
  Even evicting lower-priority Pods would not solve the constraint.
```

Production rule:

```text id="failedscheduling-rule"
Do not guess. Read the FailedScheduling event carefully.
It usually names the blocking plugin or constraint.
```

---

# 7. Create Baseline Namespace and Node Labels

We will use a dedicated namespace.

```bash id="create-ns"
kubectl create namespace scheduling-lab --dry-run=client -o yaml | kubectl apply -f -
```

Check nodes:

```bash id="check-nodes"
kubectl get nodes
kubectl get nodes --show-labels
```

For kind, label two worker nodes if they exist:

```bash id="label-nodes"
kubectl label node devops-k8s-worker node-role=app zone=zone-a disk=standard --overwrite || true

kubectl label node devops-k8s-worker2 node-role=app zone=zone-b disk=ssd --overwrite || true
```

If you only have one worker node, label it:

```bash id="label-one-node"
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

kubectl label node "$NODE" node-role=app zone=zone-a disk=standard --overwrite
```

Validate:

```bash id="validate-labels"
kubectl get nodes -L node-role,zone,disk
```

---

# 8. Lab 1 — Insufficient CPU and Memory

Create a Deployment that requests impossible resources.

```bash id="manifest-resources"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/01-insufficient-resources.yaml
```

Paste:

```yaml id="manifest-resources-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insufficient-resources
  namespace: scheduling-lab
  labels:
    app: insufficient-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insufficient-resources
  template:
    metadata:
      labels:
        app: insufficient-resources
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

```bash id="apply-resources"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/01-insufficient-resources.yaml
```

Debug:

```bash id="debug-resources"
kubectl get pods -n scheduling-lab -l app=insufficient-resources

POD="$(kubectl get pod -n scheduling-lab -l app=insufficient-resources -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n scheduling-lab

kubectl get events -n scheduling-lab --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text id="expected-resources"
FailedScheduling
Insufficient cpu
Insufficient memory
```

Fix:

```bash id="fix-resources"
kubectl patch deployment insufficient-resources -n scheduling-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/requests/cpu",
      "value": "25m"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/requests/memory",
      "value": "32Mi"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/limits/cpu",
      "value": "100m"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/resources/limits/memory",
      "value": "64Mi"
    }
  ]'
```

Validate:

```bash id="validate-resources"
kubectl rollout status deployment/insufficient-resources -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=insufficient-resources -o wide
```

Clean:

```bash id="clean-resources"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/01-insufficient-resources.yaml --ignore-not-found=true
```

---

# 9. Requests vs Actual Usage

This is a major Kubernetes misconception.

```text id="requests-vs-usage"
Scheduler placement:
  uses resource requests.

Runtime pressure:
  depends on actual usage.

OOMKilled:
  container exceeded memory limit.

Evicted:
  node needed to reclaim resources.
```

Example:

```text id="requests-example"
Node allocatable memory:
  2Gi

Existing Pods request:
  1.9Gi

New Pod request:
  512Mi

Actual node usage:
  only 800Mi

Result:
  scheduler still rejects the new Pod because requested memory does not fit.
```

The scheduler checks resource requests against node capacity/allocatable, even if actual current usage looks low. This is why over-requesting resources causes Pending Pods and poor cluster utilization. ([Kubernetes][2])

---

# 10. Lab 2 — nodeSelector Mismatch

`nodeSelector` is a hard scheduling requirement. The Pod can only run on nodes with matching labels.

Kubernetes supports assigning Pods to nodes using node labels, node selectors, affinity, and related scheduling constraints. Hard constraints can prevent scheduling if no node matches. ([Kubernetes][3])

Create:

```bash id="manifest-nodeselector"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/02-nodeselector-mismatch.yaml
```

Paste:

```yaml id="manifest-nodeselector-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeselector-mismatch
  namespace: scheduling-lab
  labels:
    app: nodeselector-mismatch
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nodeselector-mismatch
  template:
    metadata:
      labels:
        app: nodeselector-mismatch
    spec:
      nodeSelector:
        disk: ultra-fast-nonexistent
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

```bash id="apply-nodeselector"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/02-nodeselector-mismatch.yaml
```

Debug:

```bash id="debug-nodeselector"
kubectl get pods -n scheduling-lab -l app=nodeselector-mismatch

POD="$(kubectl get pod -n scheduling-lab -l app=nodeselector-mismatch -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n scheduling-lab

kubectl get nodes -L disk
```

Expected:

```text id="expected-nodeselector"
node(s) didn't match Pod's node affinity/selector
```

Fix option A — change Pod selector to existing label:

```bash id="fix-nodeselector-pod"
kubectl patch deployment nodeselector-mismatch -n scheduling-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/nodeSelector/disk",
      "value": "standard"
    }
  ]'
```

Fix option B — label a node to match:

```bash id="fix-nodeselector-node"
kubectl label node devops-k8s-worker disk=ultra-fast-nonexistent --overwrite
```

For this lab, prefer option A.

Validate:

```bash id="validate-nodeselector"
kubectl rollout status deployment/nodeselector-mismatch -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=nodeselector-mismatch -o wide
```

Clean:

```bash id="clean-nodeselector"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/02-nodeselector-mismatch.yaml --ignore-not-found=true
```

---

# 11. Lab 3 — Required Node Affinity Mismatch

Node affinity is more expressive than `nodeSelector`.

There are two major types:

```text id="node-affinity-types"
requiredDuringSchedulingIgnoredDuringExecution:
  hard rule

preferredDuringSchedulingIgnoredDuringExecution:
  soft preference
```

`requiredDuringSchedulingIgnoredDuringExecution` must match during scheduling. If no node matches, the Pod remains Pending. The “IgnoredDuringExecution” part means that if node labels later change, Kubernetes does not automatically evict the already-running Pod solely because the label no longer matches. ([Kubernetes][3])

Create:

```bash id="manifest-required-affinity"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/03-required-node-affinity-mismatch.yaml
```

Paste:

```yaml id="manifest-required-affinity-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: required-affinity-mismatch
  namespace: scheduling-lab
  labels:
    app: required-affinity-mismatch
spec:
  replicas: 1
  selector:
    matchLabels:
      app: required-affinity-mismatch
  template:
    metadata:
      labels:
        app: required-affinity-mismatch
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: workload-tier
                    operator: In
                    values:
                      - platinum
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

```bash id="apply-required-affinity"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/03-required-node-affinity-mismatch.yaml
```

Debug:

```bash id="debug-required-affinity"
kubectl get pods -n scheduling-lab -l app=required-affinity-mismatch

POD="$(kubectl get pod -n scheduling-lab -l app=required-affinity-mismatch -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n scheduling-lab

kubectl get nodes -L workload-tier
```

Expected:

```text id="expected-required-affinity"
node(s) didn't match Pod's node affinity/selector
```

Fix by labeling a node:

```bash id="fix-required-affinity"
kubectl label node devops-k8s-worker workload-tier=platinum --overwrite
```

Validate:

```bash id="validate-required-affinity"
kubectl rollout status deployment/required-affinity-mismatch -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=required-affinity-mismatch -o wide
```

Clean:

```bash id="clean-required-affinity"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/03-required-node-affinity-mismatch.yaml --ignore-not-found=true

kubectl label node devops-k8s-worker workload-tier- || true
```

---

# 12. Lab 4 — Preferred Node Affinity Behavior

Preferred affinity is a soft preference. If the scheduler cannot satisfy the preference, it can still schedule the Pod elsewhere.

Create:

```bash id="manifest-preferred-affinity"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/04-preferred-node-affinity.yaml
```

Paste:

```yaml id="manifest-preferred-affinity-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: preferred-affinity-demo
  namespace: scheduling-lab
  labels:
    app: preferred-affinity-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: preferred-affinity-demo
  template:
    metadata:
      labels:
        app: preferred-affinity-demo
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: workload-tier
                    operator: In
                    values:
                      - nonexistent-soft-preference
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

```bash id="apply-preferred-affinity"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/04-preferred-node-affinity.yaml
```

Validate:

```bash id="validate-preferred-affinity"
kubectl rollout status deployment/preferred-affinity-demo -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=preferred-affinity-demo -o wide
```

Expected:

```text id="expected-preferred-affinity"
Pod schedules successfully even though the preferred label does not exist.
```

Production rule:

```text id="preferred-rule"
Use required affinity for must-have placement.
Use preferred affinity for best-effort placement.
```

Clean:

```bash id="clean-preferred-affinity"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/04-preferred-node-affinity.yaml --ignore-not-found=true
```

---

# 13. Lab 5 — Taints and Tolerations

Taints repel Pods from nodes unless Pods have matching tolerations. This is commonly used for dedicated nodes, GPU nodes, maintenance, platform nodes, or pressure conditions. ([Kubernetes][1])

Taint effects:

```text id="taint-effects"
NoSchedule:
  new Pods without toleration will not schedule.

PreferNoSchedule:
  scheduler tries to avoid the node, but it is not a hard rule.

NoExecute:
  new Pods without toleration will not schedule,
  and existing Pods without toleration may be evicted.
```

Safely taint a worker:

```bash id="taint-node"
NODE_NAME="devops-k8s-worker"

kubectl taint node "$NODE_NAME" dedicated=infra:NoSchedule --overwrite
```

Create a Pod pinned to that node without toleration:

```bash id="manifest-taint"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/05-untolerated-taint.yaml
```

Paste:

```yaml id="manifest-taint-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: untolerated-taint
  namespace: scheduling-lab
  labels:
    app: untolerated-taint
spec:
  replicas: 1
  selector:
    matchLabels:
      app: untolerated-taint
  template:
    metadata:
      labels:
        app: untolerated-taint
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

```bash id="apply-taint"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/05-untolerated-taint.yaml
```

Debug:

```bash id="debug-taint"
kubectl get pods -n scheduling-lab -l app=untolerated-taint

POD="$(kubectl get pod -n scheduling-lab -l app=untolerated-taint -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n scheduling-lab
```

Expected:

```text id="expected-taint"
node(s) had untolerated taint
```

Fix by adding toleration:

```bash id="fix-taint"
kubectl patch deployment untolerated-taint -n scheduling-lab \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/tolerations",
      "value": [
        {
          "key": "dedicated",
          "operator": "Equal",
          "value": "infra",
          "effect": "NoSchedule"
        }
      ]
    }
  ]'
```

Validate:

```bash id="validate-taint"
kubectl rollout status deployment/untolerated-taint -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=untolerated-taint -o wide
```

Cleanup:

```bash id="clean-taint"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/05-untolerated-taint.yaml --ignore-not-found=true

kubectl taint node "$NODE_NAME" dedicated=infra:NoSchedule- || true
```

---

# 14. Lab 6 — Pod Anti-Affinity Blocking Scheduling

Pod anti-affinity can prevent Pods from colocating on the same topology domain.

This is useful for high availability, but if you make it too strict, replicas may not schedule.

Create a Deployment with required anti-affinity across hostname and too many replicas for your available nodes.

```bash id="manifest-antiaffinity"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/06-required-pod-anti-affinity.yaml
```

Paste:

```yaml id="manifest-antiaffinity-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: required-anti-affinity
  namespace: scheduling-lab
  labels:
    app: required-anti-affinity
spec:
  replicas: 5
  selector:
    matchLabels:
      app: required-anti-affinity
  template:
    metadata:
      labels:
        app: required-anti-affinity
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: required-anti-affinity
              topologyKey: kubernetes.io/hostname
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

```bash id="apply-antiaffinity"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/06-required-pod-anti-affinity.yaml
```

Debug:

```bash id="debug-antiaffinity"
kubectl get pods -n scheduling-lab -l app=required-anti-affinity -o wide

kubectl get events -n scheduling-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="expected-antiaffinity"
Some Pods may run.
Extra Pods remain Pending because required anti-affinity allows only one matching Pod per node.
```

Fix option A — reduce replicas to node count:

```bash id="fix-antiaffinity-scale"
NODE_COUNT="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"

kubectl scale deployment required-anti-affinity -n scheduling-lab --replicas="$NODE_COUNT"
```

Fix option B — make anti-affinity preferred instead of required:

```text id="fix-antiaffinity-soft"
Use preferredDuringSchedulingIgnoredDuringExecution for soft spreading.
```

Validate:

```bash id="validate-antiaffinity"
kubectl rollout status deployment/required-anti-affinity -n scheduling-lab --timeout=120s || true

kubectl get pods -n scheduling-lab -l app=required-anti-affinity -o wide
```

Clean:

```bash id="clean-antiaffinity"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/06-required-pod-anti-affinity.yaml --ignore-not-found=true
```

Production rule:

```text id="antiaffinity-rule"
Hard anti-affinity improves availability but can reduce schedulability.
For small clusters, prefer topology spread constraints or preferred anti-affinity.
```

---

# 15. Lab 7 — Topology Spread Constraints

Topology spread constraints control how Pods are spread across topology domains such as nodes, zones, or custom labels. They help with high availability and resource distribution. ([Kubernetes][4])

Important fields:

```text id="topology-fields"
maxSkew:
  maximum allowed imbalance across topology domains

topologyKey:
  node label used as the topology domain

whenUnsatisfiable:
  DoNotSchedule or ScheduleAnyway

labelSelector:
  which Pods are counted for spreading
```

Create a strict topology spread rule:

```bash id="manifest-topology"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/07-topology-spread-strict.yaml
```

Paste:

```yaml id="manifest-topology-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-spread-strict
  namespace: scheduling-lab
  labels:
    app: topology-spread-strict
spec:
  replicas: 3
  selector:
    matchLabels:
      app: topology-spread-strict
  template:
    metadata:
      labels:
        app: topology-spread-strict
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: topology-spread-strict
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

```bash id="apply-topology"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/07-topology-spread-strict.yaml
```

Debug:

```bash id="debug-topology"
kubectl get nodes -L zone
kubectl get pods -n scheduling-lab -l app=topology-spread-strict -o wide
kubectl get events -n scheduling-lab --sort-by=.lastTimestamp | tail -n 50
```

Possible outcomes:

```text id="topology-outcomes"
If nodes have zone labels:
  Pods should spread across zones/nodes as allowed.

If only one zone exists:
  Pods may still schedule depending on eligible domains and cluster shape.

If topology labels are missing or constraints cannot be satisfied:
  some Pods may remain Pending.
```

Create a deliberately impossible topology key:

```bash id="patch-topology-bad"
kubectl patch deployment topology-spread-strict -n scheduling-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/topologySpreadConstraints/0/topologyKey",
      "value": "nonexistent-topology-key"
    }
  ]'
```

Debug:

```bash id="debug-topology-bad"
kubectl rollout status deployment/topology-spread-strict -n scheduling-lab --timeout=60s || true

kubectl get pods -n scheduling-lab -l app=topology-spread-strict -o wide

kubectl describe pod -n scheduling-lab -l app=topology-spread-strict
```

Fix:

```bash id="fix-topology"
kubectl patch deployment topology-spread-strict -n scheduling-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/topologySpreadConstraints/0/topologyKey",
      "value": "kubernetes.io/hostname"
    }
  ]'
```

Validate:

```bash id="validate-topology"
kubectl rollout status deployment/topology-spread-strict -n scheduling-lab --timeout=120s

kubectl get pods -n scheduling-lab -l app=topology-spread-strict -o wide
```

Clean:

```bash id="clean-topology"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/07-topology-spread-strict.yaml --ignore-not-found=true
```

Production rule:

```text id="topology-rule"
Use topology spread constraints for high availability, but verify every node has the required topology labels.
```

---

# 16. Lab 8 — Namespace ResourceQuota Blocking Pod Creation

ResourceQuota can block workloads before or during creation when namespace resource limits would be exceeded.

Create quota:

```bash id="manifest-quota"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/08-resourcequota-blocks.yaml
```

Paste:

```yaml id="manifest-quota-content"
apiVersion: v1
kind: ResourceQuota
metadata:
  name: scheduling-lab-quota
  namespace: scheduling-lab
spec:
  hard:
    requests.cpu: "100m"
    requests.memory: "128Mi"
    limits.cpu: "200m"
    limits.memory: "256Mi"
    pods: "2"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quota-block-demo
  namespace: scheduling-lab
  labels:
    app: quota-block-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: quota-block-demo
  template:
    metadata:
      labels:
        app: quota-block-demo
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: "75m"
              memory: "96Mi"
            limits:
              cpu: "100m"
              memory: "128Mi"
```

Apply:

```bash id="apply-quota"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/08-resourcequota-blocks.yaml
```

Debug:

```bash id="debug-quota"
kubectl get resourcequota -n scheduling-lab
kubectl describe resourcequota scheduling-lab-quota -n scheduling-lab

kubectl get pods -n scheduling-lab -l app=quota-block-demo

kubectl get events -n scheduling-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="expected-quota"
Some replicas may not be created.
ReplicaSet events may mention exceeded quota.
```

Fix option A — reduce replicas:

```bash id="fix-quota-scale"
kubectl scale deployment quota-block-demo -n scheduling-lab --replicas=1
```

Fix option B — increase quota:

```bash id="fix-quota-patch"
kubectl patch resourcequota scheduling-lab-quota -n scheduling-lab \
  --type='merge' \
  -p='{"spec":{"hard":{"requests.cpu":"500m","requests.memory":"512Mi","limits.cpu":"1","limits.memory":"1Gi","pods":"10"}}}'
```

Validate:

```bash id="validate-quota"
kubectl rollout status deployment/quota-block-demo -n scheduling-lab --timeout=120s

kubectl describe resourcequota scheduling-lab-quota -n scheduling-lab
```

Clean:

```bash id="clean-quota"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/08-resourcequota-blocks.yaml --ignore-not-found=true
```

---

# 17. Lab 9 — PVC WaitForFirstConsumer Scheduling Concept

Storage can also affect scheduling.

With `volumeBindingMode: WaitForFirstConsumer`, Kubernetes delays volume binding/provisioning until the Pod is scheduled or tentatively scheduled. This lets the scheduler consider node constraints, topology, affinity, and storage topology together. ([Kubernetes][5])

Create a local concept StorageClass and PVC.

```bash id="manifest-wffc"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/09-wait-for-first-consumer-concept.yaml
```

Paste:

```yaml id="manifest-wffc-content"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: scheduling-lab-wffc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wffc-demo-pvc
  namespace: scheduling-lab
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: scheduling-lab-wffc
  resources:
    requests:
      storage: 1Gi
```

Apply:

```bash id="apply-wffc"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/09-wait-for-first-consumer-concept.yaml
```

Check PVC:

```bash id="debug-wffc-pvc"
kubectl get pvc -n scheduling-lab
kubectl describe pvc wffc-demo-pvc -n scheduling-lab
```

Expected:

```text id="expected-wffc"
PVC may remain Pending.
It is waiting for a consumer Pod and compatible PV/provisioner.
```

Now create a Pod that uses the PVC:

```bash id="manifest-wffc-pod"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/10-wffc-consumer-pod.yaml
```

Paste:

```yaml id="manifest-wffc-pod-content"
apiVersion: v1
kind: Pod
metadata:
  name: wffc-consumer-pod
  namespace: scheduling-lab
  labels:
    app: wffc-consumer-pod
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo using pvc; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: wffc-demo-pvc
```

Apply:

```bash id="apply-wffc-pod"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/10-wffc-consumer-pod.yaml
```

Debug:

```bash id="debug-wffc-pod"
kubectl get pod wffc-consumer-pod -n scheduling-lab
kubectl describe pod wffc-consumer-pod -n scheduling-lab

kubectl describe pvc wffc-demo-pvc -n scheduling-lab

kubectl get events -n scheduling-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="expected-wffc-pod"
Pod may remain Pending because no suitable PV/provisioner exists.
Events may mention unbound immediate PersistentVolumeClaims or waiting for volume binding, depending on cluster behavior.
```

Clean:

```bash id="clean-wffc"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/10-wffc-consumer-pod.yaml --ignore-not-found=true

kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests/09-wait-for-first-consumer-concept.yaml --ignore-not-found=true
```

Production rule:

```text id="wffc-rule"
For zonal storage, scheduling and volume binding must agree.
A Pod can be Pending because the PVC, PV, node zone, and affinity cannot be satisfied together.
```

---

# 18. Preemption Messages

You may see:

```text id="preemption-message"
preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling
```

Meaning:

```text id="preemption-meaning"
The scheduler considered whether evicting lower-priority Pods would help.
It decided that preemption would not solve the issue.
```

Common reasons preemption does not help:

```text id="preemption-not-helpful"
nodeSelector mismatch
required node affinity mismatch
untolerated taints
PVC topology conflict
topology spread cannot be satisfied
no node has required labels
resource shortage too large
```

Kubernetes preemption can evict lower-priority Pods to make room for higher-priority Pods, but it cannot fix constraints such as wrong labels, missing tolerations, or impossible affinity. ([Kubernetes][6])

---

# 19. Create Scheduling Summary Script

```bash id="summary-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/scheduling-summary.sh
```

Paste:

```bash id="summary-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-scheduling-lab}"

echo "===== Scheduling Summary ====="
echo "Namespace: $NAMESPACE"

echo
echo "Pending Pods:"
kubectl get pods -n "$NAMESPACE" -o wide | grep Pending || true

echo
echo "All Pods:"
kubectl get pods -n "$NAMESPACE" -o wide || true

echo
echo "Nodes:"
kubectl get nodes -o wide || true

echo
echo "Node labels:"
kubectl get nodes -L node-role,zone,disk,workload-tier || true

echo
echo "Node taints:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo
  echo "----- $node -----"
  kubectl describe node "$node" | grep -i -A2 Taints || true
done

echo
echo "ResourceQuota:"
kubectl get resourcequota -n "$NAMESPACE" || true
kubectl describe resourcequota -n "$NAMESPACE" || true

echo
echo "PVCs:"
kubectl get pvc -n "$NAMESPACE" || true

echo
echo "Recent FailedScheduling events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | grep -i FailedScheduling || true

echo
echo "Recent namespace events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 50 || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/scheduling-summary.sh
```

Run:

```bash id="run-summary"
NAMESPACE=scheduling-lab \
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/scheduling-summary.sh
```

---

# 20. Create Pending Pod Inspector Script

```bash id="inspector-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/inspect-pending-pod.sh
```

Paste:

```bash id="inspector-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-scheduling-lab}"
POD="${POD:-}"

if [ -z "$POD" ]; then
  POD="$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [ -z "$POD" ]; then
  echo "No Pending Pod found in namespace $NAMESPACE. Or set POD=my-pod."
  exit 0
fi

OUT_DIR="11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/reports/$POD-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "===== Pending Pod Inspector ====="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "Output: $OUT_DIR"

kubectl get pod "$POD" -n "$NAMESPACE" -o wide | tee "$OUT_DIR/pod-status.txt" || true
kubectl get pod "$POD" -n "$NAMESPACE" -o yaml > "$OUT_DIR/pod.yaml" 2>&1 || true
kubectl describe pod "$POD" -n "$NAMESPACE" > "$OUT_DIR/pod-describe.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUT_DIR/events.txt" 2>&1 || true
kubectl get nodes -o wide > "$OUT_DIR/nodes.txt" 2>&1 || true
kubectl get nodes --show-labels > "$OUT_DIR/node-labels.txt" 2>&1 || true

echo
echo "Scheduling-related events:"
grep -i -E "FailedScheduling|insufficient|taint|affinity|selector|topology|quota|volume|preemption" "$OUT_DIR/pod-describe.txt" "$OUT_DIR/events.txt" || true

echo
echo "Inspection saved to: $OUT_DIR"
```

Make executable:

```bash id="chmod-inspector"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/inspect-pending-pod.sh
```

Run:

```bash id="run-inspector"
NAMESPACE=scheduling-lab \
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/inspect-pending-pod.sh
```

---

# 21. Create Node Scheduling Matrix Script

```bash id="matrix-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/node-scheduling-matrix.sh
```

Paste:

```bash id="matrix-script-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Node Scheduling Matrix ====="

printf "%-35s %-12s %-12s %-12s %-20s\n" "NODE" "READY" "SCHEDULABLE" "ZONE" "TAINTS"

for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  ready="$(kubectl get node "$node" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"
  unschedulable="$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || true)"
  zone="$(kubectl get node "$node" -o jsonpath='{.metadata.labels.zone}' 2>/dev/null || true)"
  taints="$(kubectl get node "$node" -o jsonpath='{range .spec.taints[*]}{.key}{"="}{.value}{":"}{.effect}{","}{end}' 2>/dev/null || true)"

  if [ "$unschedulable" = "true" ]; then
    schedulable="No"
  else
    schedulable="Yes"
  fi

  if [ -z "$zone" ]; then
    zone="-"
  fi

  if [ -z "$taints" ]; then
    taints="-"
  fi

  printf "%-35s %-12s %-12s %-12s %-20s\n" "$node" "$ready" "$schedulable" "$zone" "$taints"
done
```

Make executable:

```bash id="chmod-matrix"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/node-scheduling-matrix.sh
```

Run:

```bash id="run-matrix"
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/node-scheduling-matrix.sh
```

---

# 22. Run All Scheduling Labs Script

```bash id="run-labs-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/run-scheduling-labs.sh
```

Paste:

```bash id="run-labs-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests"

kubectl create namespace scheduling-lab --dry-run=client -o yaml | kubectl apply -f -

kubectl label node devops-k8s-worker node-role=app zone=zone-a disk=standard --overwrite || true
kubectl label node devops-k8s-worker2 node-role=app zone=zone-b disk=ssd --overwrite || true

kubectl apply -f "$BASE/01-insufficient-resources.yaml" || true
kubectl apply -f "$BASE/02-nodeselector-mismatch.yaml" || true
kubectl apply -f "$BASE/03-required-node-affinity-mismatch.yaml" || true
kubectl apply -f "$BASE/04-preferred-node-affinity.yaml" || true
kubectl apply -f "$BASE/06-required-pod-anti-affinity.yaml" || true
kubectl apply -f "$BASE/07-topology-spread-strict.yaml" || true

echo "Core scheduling labs applied."
echo
echo "Manual labs:"
echo "  05-untolerated-taint.yaml requires temporary node taint."
echo "  08-resourcequota-blocks.yaml changes namespace quota."
echo "  09/10 WaitForFirstConsumer labs are storage concept labs."
echo
echo "Run:"
echo "NAMESPACE=scheduling-lab ./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/scheduling-summary.sh"
```

Make executable:

```bash id="chmod-run-labs"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/run-scheduling-labs.sh
```

Run:

```bash id="run-labs"
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/run-scheduling-labs.sh
```

---

# 23. Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/cleanup-lesson-11-10.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/manifests"
NODE_NAME="${NODE_NAME:-devops-k8s-worker}"

echo "===== Cleanup Lesson 11.10 ====="

kubectl delete -f "$BASE/10-wffc-consumer-pod.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/09-wait-for-first-consumer-concept.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/08-resourcequota-blocks.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-topology-spread-strict.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-required-pod-anti-affinity.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-untolerated-taint.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-preferred-node-affinity.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-required-node-affinity-mismatch.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-nodeselector-mismatch.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-insufficient-resources.yaml" --ignore-not-found=true

kubectl taint node "$NODE_NAME" dedicated=infra:NoSchedule- || true
kubectl label node devops-k8s-worker workload-tier- || true

echo "Lesson 11.10 demo resources cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/cleanup-lesson-11-10.sh
```

Run cleanup:

```bash id="run-cleanup"
NODE_NAME=devops-k8s-worker \
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/cleanup-lesson-11-10.sh
```

---

# 24. Validation Script

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/validate-lesson-11-10.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.10 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/scheduler-mental-model.md"
test -f "$BASE/notes/scheduling-debug-commands.md"

test -f "$BASE/manifests/01-insufficient-resources.yaml"
test -f "$BASE/manifests/02-nodeselector-mismatch.yaml"
test -f "$BASE/manifests/03-required-node-affinity-mismatch.yaml"
test -f "$BASE/manifests/04-preferred-node-affinity.yaml"
test -f "$BASE/manifests/05-untolerated-taint.yaml"
test -f "$BASE/manifests/06-required-pod-anti-affinity.yaml"
test -f "$BASE/manifests/07-topology-spread-strict.yaml"
test -f "$BASE/manifests/08-resourcequota-blocks.yaml"
test -f "$BASE/manifests/09-wait-for-first-consumer-concept.yaml"
test -f "$BASE/manifests/10-wffc-consumer-pod.yaml"

test -x "$BASE/scripts/scheduling-summary.sh"
test -x "$BASE/scripts/inspect-pending-pod.sh"
test -x "$BASE/scripts/node-scheduling-matrix.sh"
test -x "$BASE/scripts/run-scheduling-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-10.sh"

kubectl create namespace scheduling-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

NODE_COUNT="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"

if [ "$NODE_COUNT" -lt 1 ]; then
  echo "ERROR: no nodes found"
  exit 1
fi

kubectl apply -f "$BASE/manifests/04-preferred-node-affinity.yaml" >/dev/null
kubectl rollout status deployment/preferred-affinity-demo -n scheduling-lab --timeout=120s >/dev/null

kubectl get pods -n scheduling-lab -l app=preferred-affinity-demo >/dev/null

echo "Node count: $NODE_COUNT"
echo "Lesson 11.10 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/validate-lesson-11-10.sh
```

Run:

```bash id="run-validation"
./11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/scripts/validate-lesson-11-10.sh
```

---

# 25. Scheduling Troubleshooting Runbook

```bash id="runbook"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/runbooks/scheduling-failure-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# Scheduling Failure Troubleshooting Runbook

## 1. Find Pending Pods

```bash
kubectl get pods -A | grep Pending || true
kubectl get pods -n NAMESPACE -o wide
````

## 2. Describe the Pending Pod

```bash id="rb-describe"
kubectl describe pod POD_NAME -n NAMESPACE
```

Focus on Events.

Look for:

* FailedScheduling
* Insufficient cpu
* Insufficient memory
* node(s) didn't match node selector
* node(s) didn't match Pod's node affinity
* node(s) had untolerated taint
* pod anti-affinity rules
* topology spread constraints
* unbound PersistentVolumeClaims
* exceeded quota
* preemption is not helpful

## 3. Check Nodes

```bash id="rb-nodes"
kubectl get nodes -o wide
kubectl get nodes --show-labels
kubectl describe node NODE_NAME
```

Check:

* Ready condition
* SchedulingDisabled
* labels
* taints
* capacity
* allocatable
* allocated resources

## 4. Check Pod Constraints

```bash id="rb-pod-yaml"
kubectl get pod POD_NAME -n NAMESPACE -o yaml
```

Check:

* nodeSelector
* nodeAffinity
* podAffinity
* podAntiAffinity
* topologySpreadConstraints
* tolerations
* resource requests
* PVCs
* priorityClassName

## 5. Check Quota

```bash id="rb-quota"
kubectl get resourcequota -n NAMESPACE
kubectl describe resourcequota -n NAMESPACE
```

## 6. Check PVC / Storage

```bash id="rb-pvc"
kubectl get pvc -n NAMESPACE
kubectl describe pvc PVC_NAME -n NAMESPACE
kubectl get storageclass
```

## 7. Common Fixes

| Event                   | Fix                                               |
| ----------------------- | ------------------------------------------------- |
| Insufficient cpu/memory | lower requests, scale nodes, free capacity        |
| node selector mismatch  | correct selector or label nodes                   |
| affinity mismatch       | relax required affinity or label nodes            |
| untolerated taint       | add toleration or remove taint                    |
| anti-affinity blocked   | reduce replicas or use preferred anti-affinity    |
| topology spread blocked | label nodes, relax constraint, use ScheduleAnyway |
| quota exceeded          | reduce replicas/requests or increase quota        |
| unbound PVC             | fix StorageClass/PV/topology/provisioner          |
| node unschedulable      | uncordon node if safe                             |

## Golden Rule

The scheduler explains most Pending Pod problems in the Pod Events section.

````

---

# 26. Production Scheduling Design Runbook

```bash id="prod-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.10-scheduling-failures/runbooks/production-scheduling-design-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production Scheduling Design Runbook

## Recommended Placement Strategy

Use a layered approach:

1. Requests and limits
2. PodDisruptionBudget
3. topologySpreadConstraints
4. soft pod anti-affinity
5. node affinity only when required
6. taints/tolerations for dedicated nodes
7. resource quota per namespace

## Avoid

- hard nodeSelector for normal apps
- hard anti-affinity with more replicas than nodes
- missing topology labels
- over-requesting CPU/memory
- broad tolerations
- using NoExecute taints casually
- one-replica apps with strict availability constraints
- PVC topology without understanding zones

## Good API Workload Pattern

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: my-api
````

## Dedicated Node Pattern

Use taint:

```bash
kubectl taint node NODE dedicated=api:NoSchedule
```

Use toleration:

```yaml
tolerations:
  - key: dedicated
    operator: Equal
    value: api
    effect: NoSchedule
```

Use node affinity:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-pool
              operator: In
              values:
                - api
```

## Review Checklist

* Can replicas fit across available nodes?
* Are requests realistic?
* Are all required labels present?
* Are taints intentional?
* Do Pods have correct tolerations?
* Are hard anti-affinity rules safe?
* Are topology labels present?
* Is storage topology compatible?
* Are namespace quotas sufficient?

````

---

# 27. Real Production Debug Mapping

```text id="prod-map"
Pod Pending + Insufficient cpu/memory:
  scheduler cannot fit requests; reduce requests or add capacity

Pod Pending + node selector mismatch:
  nodeSelector requires label no node has

Pod Pending + node affinity mismatch:
  required affinity is too strict or labels are missing

Pod Pending + untolerated taint:
  node has taint; Pod lacks toleration

Pod Pending + anti-affinity:
  too many replicas for available topology domains

Pod Pending + topology spread:
  maxSkew / topologyKey / labels make spreading impossible

Pod Pending + quota:
  namespace ResourceQuota blocks creation or scaling

Pod Pending + unbound PVC:
  storage provisioning/binding/topology issue

Preemption not helpful:
  evicting lower-priority Pods cannot solve this constraint

Works in dev but Pending in prod:
  different labels, taints, quota, node pools, storage classes, or capacity
````

---

# 28. Common Mistakes

## Mistake 1: Checking only logs

Pending Pods usually do not have container logs because they never started.

Start with:

```bash id="mistake-logs"
kubectl describe pod POD -n NAMESPACE
```

---

## Mistake 2: Confusing resource limits with scheduling

Scheduler uses requests.

```text id="requests-rule"
requests affect scheduling.
limits affect runtime enforcement.
```

---

## Mistake 3: Adding tolerations too broadly

Bad:

```yaml id="bad-toleration"
tolerations:
  - operator: Exists
```

This tolerates many taints and can place apps on nodes they should avoid.

---

## Mistake 4: Hard anti-affinity with too few nodes

If you request 5 replicas and hard anti-affinity requires one per node, you need at least 5 eligible nodes.

---

## Mistake 5: Missing topology labels

Topology spread only works correctly when nodes have the expected topology labels.

---

## Mistake 6: Using nodeSelector for normal apps

For normal apps, let the scheduler place them unless you truly need dedicated hardware or node pools.

---

# 29. Interview Explanation

Use this:

```text id="interview-answer"
When troubleshooting Kubernetes scheduling failures, I start with kubectl describe pod because Pending Pods usually contain FailedScheduling events that explain why no node was suitable. I look for messages such as insufficient CPU or memory, node selector mismatch, required node affinity mismatch, untolerated taints, pod anti-affinity, topology spread constraints, PVC binding issues, quota failures, or preemption not being helpful.

Then I compare the Pod’s scheduling constraints with the cluster state. I check node labels, taints, cordon status, capacity, allocatable resources, allocated requests, namespace ResourceQuota, PVCs, and StorageClasses. I remember that the scheduler uses resource requests for placement, not actual current usage.

For production, I prefer realistic requests, soft placement rules where possible, topology spread constraints for high availability, taints and tolerations only for dedicated node pools, and least-surprise scheduling policies. I avoid overly strict anti-affinity or node selectors unless there is a clear operational requirement.
```

Resume bullet:

```text id="resume-bullet"
Built Kubernetes scheduling troubleshooting labs covering FailedScheduling events, insufficient CPU/memory, nodeSelector mismatch, required and preferred node affinity, taints and tolerations, NoSchedule behavior, pod anti-affinity, topology spread constraints, ResourceQuota blocking, WaitForFirstConsumer storage scheduling, Pending Pod inspection scripts, node scheduling matrices, and production scheduling runbooks.
```

---

# 30. Commit Lesson 11.10

```bash id="commit"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes scheduling failure troubleshooting labs"

git push
```

---

# 31. Next Lesson

```text id="next-lesson"
Lesson 11.11 — Storage, PVC, PV, StatefulSet, and Volume Troubleshooting
```

We will cover:

```text id="next-topics"
PVC Pending
PV/PVC binding mismatch
StorageClass issues
accessModes mismatch
volumeMode mismatch
WaitForFirstConsumer
StatefulSet volumeClaimTemplates
Pod stuck ContainerCreating due to volume mount
ReadWriteOnce multi-node confusion
local-path storage in kind
filesystem permissions
initContainer volume fix patterns
volume expansion issues
production storage incident runbook
```

[1]: https://kubernetes.io/docs/concepts/scheduling-eviction/?utm_source=chatgpt.com "Scheduling, Preemption and Eviction"
[2]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/?utm_source=chatgpt.com "Resource Management for Pods and Containers"
[3]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/?utm_source=chatgpt.com "Assigning Pods to Nodes"
[4]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/?utm_source=chatgpt.com "Pod Topology Spread Constraints"
[5]: https://kubernetes.io/docs/concepts/storage/storage-classes/?utm_source=chatgpt.com "Storage Classes"
[6]: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/?utm_source=chatgpt.com "Pod Priority and Preemption"
