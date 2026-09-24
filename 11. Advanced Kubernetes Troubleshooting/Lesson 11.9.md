# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.9 — Node Pressure and Kubelet Troubleshooting

In Lesson 11.8, you learned **RBAC permission troubleshooting**:

```text id="s1ift1"
Forbidden errors
ServiceAccount identity
Role vs ClusterRole
RoleBinding vs ClusterRoleBinding
kubectl auth can-i
wrong subject
wrong namespace binding
missing verbs
in-cluster API access
automountServiceAccountToken behavior
least privilege fixes
```

Now we move below Pods and Deployments into the **node layer**.

This is where Kubernetes troubleshooting becomes more serious because node issues can affect many workloads at once.

Common symptoms:

```text id="jowxu8"
Node NotReady
Pods stuck Pending
Pods Evicted
MemoryPressure
DiskPressure
PIDPressure
kubelet not reporting
container runtime issues
image pull issues only on one node
Pods failing only on one node
drain stuck
PDB blocking maintenance
node unschedulable
ephemeral-storage problems
```

A Kubernetes Node status includes addresses, conditions, capacity, allocatable resources, and system information. Node conditions include `Ready`, `DiskPressure`, `MemoryPressure`, `PIDPressure`, and related health signals. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="xv3aok"
11.9.1   Node troubleshooting mental model
11.9.2   Node status and conditions
11.9.3   capacity vs allocatable
11.9.4   requests vs actual usage
11.9.5   Node NotReady
11.9.6   MemoryPressure
11.9.7   DiskPressure
11.9.8   PIDPressure
11.9.9   node-pressure eviction
11.9.10  Pod eviction debugging
11.9.11  kubelet troubleshooting
11.9.12  container runtime troubleshooting
11.9.13  image garbage collection concept
11.9.14  cordon and uncordon
11.9.15  safe drain workflow
11.9.16  PDB and drain interaction
11.9.17  Pods failing only on one node
11.9.18  node maintenance runbook
11.9.19  scripts, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="rrj1ea"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="nl4d0h"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting
```

---

# 3. Node Troubleshooting Mental Model

A Pod does not run directly on “Kubernetes.”

A Pod runs on a **specific node**.

```text id="14g8q6"
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Node
  ↓
kubelet
  ↓
container runtime
  ↓
container process
```

When many Pods fail on the same node, the issue may not be the application.

It may be:

```text id="3tq3p8"
node resource pressure
kubelet issue
container runtime issue
CNI/network issue
disk pressure
image filesystem pressure
PID exhaustion
node cordoned
node tainted
node NotReady
```

Production rule:

```text id="suc3jx"
If failures are concentrated on one node, debug the node.
If failures are spread across all nodes, debug cluster-wide components or shared dependencies.
```

---

# 4. Create Node Mental Model Notes

```bash id="hm6er2"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/notes/node-troubleshooting-mental-model.md
```

Paste:

```markdown id="wlt5hf"
# Node Troubleshooting Mental Model

## Workload Chain

Deployment -> ReplicaSet -> Pod -> Node -> kubelet -> container runtime -> container

## First Question

Is this issue affecting:

- one Pod
- one Deployment
- one namespace
- one node
- many nodes
- the whole cluster

## Node-Level Symptoms

- Node NotReady
- Pods stuck Pending
- Pods Evicted
- MemoryPressure
- DiskPressure
- PIDPressure
- kubelet not reporting
- container runtime errors
- image pull issues on one node
- Pods failing only on one node

## Golden Rule

If many unrelated Pods fail on one node, investigate the node before blaming the applications.
```

---

# 5. First Node Debug Commands

```bash id="t7i4ez"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/notes/node-debug-commands.md
```

Paste:

````markdown id="1ln4zv"
# Node Debug Commands

## List nodes

```bash
kubectl get nodes -o wide
````

## Describe node

```bash id="gxs8hd"
kubectl describe node NODE_NAME
```

## Node conditions

```bash id="rtlamc"
kubectl get nodes

kubectl get node NODE_NAME \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
```

## Capacity and allocatable

```bash id="qy9nlg"
kubectl get node NODE_NAME \
  -o jsonpath='{.status.capacity}'
echo

kubectl get node NODE_NAME \
  -o jsonpath='{.status.allocatable}'
echo
```

## Pods on one node

```bash id="7qqxmk"
kubectl get pods -A -o wide --field-selector spec.nodeName=NODE_NAME
```

## Node events

```bash id="j69shg"
kubectl get events -A --sort-by=.lastTimestamp | grep NODE_NAME || true
```

## Metrics

```bash id="1xtxbl"
kubectl top nodes
kubectl top pods -A
```

## Cordon

```bash id="22bdoq"
kubectl cordon NODE_NAME
```

## Uncordon

```bash id="6zobha"
kubectl uncordon NODE_NAME
```

## Drain dry run

```bash id="gyvolb"
kubectl drain NODE_NAME \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

````

---

# 6. Node Conditions You Must Know

Important node conditions:

```text id="kbd0ie"
Ready:
  whether node is healthy and accepting Pods

MemoryPressure:
  node memory is under pressure

DiskPressure:
  disk capacity is low

PIDPressure:
  too many processes / process IDs are being used

NetworkUnavailable:
  node network is not correctly configured
````

`Ready=True` means the node is healthy and ready to accept Pods, while `Ready=False` means the node is unhealthy and not accepting Pods. `Ready=Unknown` means the node controller has stopped hearing from the node within the monitoring grace period. ([Kubernetes][1])

Check all nodes:

```bash id="svduci"
kubectl get nodes
```

Detailed node conditions:

```bash id="dq17o0"
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

kubectl get node "$NODE" \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
```

Example output:

```text id="2f7wsn"
MemoryPressure | False | KubeletHasSufficientMemory | kubelet has sufficient memory available
DiskPressure | False | KubeletHasNoDiskPressure | kubelet has no disk pressure
PIDPressure | False | KubeletHasSufficientPID | kubelet has sufficient PID available
Ready | True | KubeletReady | kubelet is posting ready status
```

---

# 7. Capacity vs Allocatable

Node `capacity` is the total resource amount.

Node `allocatable` is what Kubernetes can allocate to Pods after accounting for reserved system resources.

```text id="pz31ip"
capacity:
  total CPU, memory, pods, ephemeral-storage

allocatable:
  resources available for Pods
```

The scheduler uses Pod resource requests when placing Pods. It checks whether the sum of requested resources fits available node capacity/allocatable resources, not whether current usage looks low at that moment. ([Kubernetes][2])

Check:

```bash id="553yp2"
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

echo "Capacity:"
kubectl get node "$NODE" -o jsonpath='{.status.capacity}'
echo
echo

echo "Allocatable:"
kubectl get node "$NODE" -o jsonpath='{.status.allocatable}'
echo
```

Readable:

```bash id="28ush8"
kubectl describe node "$NODE" | sed -n '/Capacity:/,/System Info:/p'
```

Important:

```text id="3sq760"
A node can have free actual CPU but still reject a Pod if requests do not fit.
A node can have low actual memory and trigger pressure even if scheduling looked valid earlier.
```

---

# 8. Create Node Inventory Script

```bash id="f5sqdp"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-inventory.sh
```

Paste:

```bash id="cxqzgf"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Node Inventory ====="

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "Node conditions:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo
  echo "----- $node -----"
  kubectl get node "$node" \
    -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
done

echo
echo "Capacity and allocatable:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo
  echo "----- $node -----"
  echo "Capacity:"
  kubectl get node "$node" -o jsonpath='{.status.capacity}'
  echo
  echo "Allocatable:"
  kubectl get node "$node" -o jsonpath='{.status.allocatable}'
  echo
done

echo
echo "Top nodes if metrics-server is available:"
kubectl top nodes || true
```

Make executable:

```bash id="nmwpq1"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-inventory.sh
```

Run:

```bash id="vjp44t"
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-inventory.sh
```

---

# 9. Lab 1 — Pod Pending Because Node Is Cordoned

`cordon` marks a node unschedulable. It prevents new Pods from being scheduled onto that node, but it does not remove existing Pods. This is useful before maintenance such as rebooting or upgrading a node. ([Kubernetes][3])

Pick a worker node:

```bash id="tbbhto"
kubectl get nodes
```

For your kind cluster, likely:

```text id="c5xrfu"
devops-k8s-worker
devops-k8s-worker2
```

Set variable:

```bash id="y44am3"
NODE_NAME="devops-k8s-worker"
```

Cordon:

```bash id="i2232n"
kubectl cordon "$NODE_NAME"
```

Check:

```bash id="u8q7o7"
kubectl get nodes
```

Expected:

```text id="7np0uk"
SchedulingDisabled
```

Create a Pod that must schedule on that node:

```bash id="q320hc"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/01-pending-cordoned-node.yaml
```

Paste:

```yaml id="1otvou"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-cordoned-node
  namespace: dev
  labels:
    app: pending-cordoned-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-cordoned-node
  template:
    metadata:
      labels:
        app: pending-cordoned-node
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

```bash id="kefd7w"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/01-pending-cordoned-node.yaml
```

Debug:

```bash id="gak8eu"
kubectl get pods -n dev -l app=pending-cordoned-node

POD="$(kubectl get pod -n dev -l app=pending-cordoned-node -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text id="azid3w"
Pod remains Pending.
Events mention node is unschedulable.
```

Fix:

```bash id="2tq3sp"
kubectl uncordon "$NODE_NAME"
```

Validate:

```bash id="abn8lj"
kubectl rollout status deployment/pending-cordoned-node -n dev --timeout=120s

kubectl get pods -n dev -l app=pending-cordoned-node -o wide
```

Clean:

```bash id="o3y5a2"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/01-pending-cordoned-node.yaml --ignore-not-found=true
```

---

# 10. Lab 2 — Pod Pending Due to Node Taint

When nodes are under conditions such as memory pressure, Kubernetes can add taints such as `node.kubernetes.io/memory-pressure`. Taints repel Pods unless Pods have matching tolerations. ([Kubernetes][4])

We will simulate a maintenance taint safely.

Taint a worker node:

```bash id="ikd14e"
NODE_NAME="devops-k8s-worker"

kubectl taint node "$NODE_NAME" troubleshooting=reserved:NoSchedule --overwrite
```

Create a Pod forced to that node without toleration:

```bash id="yeybq5"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/02-pending-tainted-node.yaml
```

Paste:

```yaml id="ie21n6"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-tainted-node
  namespace: dev
  labels:
    app: pending-tainted-node
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-tainted-node
  template:
    metadata:
      labels:
        app: pending-tainted-node
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

```bash id="mxqmu2"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/02-pending-tainted-node.yaml
```

Debug:

```bash id="td7bxm"
kubectl get pods -n dev -l app=pending-tainted-node

POD="$(kubectl get pod -n dev -l app=pending-tainted-node -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected:

```text id="lnjz9l"
untolerated taint
```

Fix with toleration:

```bash id="3nvpdd"
kubectl patch deployment pending-tainted-node -n dev \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/tolerations",
      "value": [
        {
          "key": "troubleshooting",
          "operator": "Equal",
          "value": "reserved",
          "effect": "NoSchedule"
        }
      ]
    }
  ]'
```

Validate:

```bash id="3uk4h6"
kubectl rollout status deployment/pending-tainted-node -n dev --timeout=120s
kubectl get pods -n dev -l app=pending-tainted-node -o wide
```

Cleanup:

```bash id="1c404f"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/02-pending-tainted-node.yaml --ignore-not-found=true

kubectl taint node "$NODE_NAME" troubleshooting=reserved:NoSchedule- || true
```

---

# 11. Lab 3 — Pending Due to Insufficient Node Resources

This lab shows scheduler behavior.

Create a Pod requesting impossible resources:

```bash id="uv50uu"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/03-pending-node-resources.yaml
```

Paste:

```yaml id="j5i84m"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-node-resources
  namespace: dev
  labels:
    app: pending-node-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-node-resources
  template:
    metadata:
      labels:
        app: pending-node-resources
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

```bash id="47xp3i"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/03-pending-node-resources.yaml
```

Debug:

```bash id="4q5srl"
kubectl get pods -n dev -l app=pending-node-resources

POD="$(kubectl get pod -n dev -l app=pending-node-resources -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl describe nodes | grep -A8 -E "Allocated resources|Resource"
```

Expected:

```text id="u10rt2"
insufficient cpu
insufficient memory
```

Fix:

```bash id="1r5nw7"
kubectl patch deployment pending-node-resources -n dev \
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

```bash id="9w2i1e"
kubectl rollout status deployment/pending-node-resources -n dev --timeout=120s
```

Cleanup:

```bash id="2g8vks"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/03-pending-node-resources.yaml --ignore-not-found=true
```

---

# 12. Node Pressure Eviction Concept

Node-pressure eviction is when kubelet proactively terminates Pods to reclaim resources on a node. It can happen for memory, disk, PID, or filesystem pressure signals. ([Kubernetes][5])

Important:

```text id="wwmpup"
Do not intentionally fill your laptop disk or memory to force real node pressure.
You can destabilize your machine.
We will learn the debugging pattern safely.
```

Eviction is different from a normal application crash.

```text id="1pc9zm"
CrashLoopBackOff:
  application/container exits and Kubernetes restarts it

Evicted:
  kubelet removed the Pod to protect node stability
```

Check for evicted Pods:

```bash id="ib5mq7"
kubectl get pods -A | grep Evicted || true
```

If you find one:

```bash id="zd25x9"
kubectl describe pod EVICTED_POD -n NAMESPACE

kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | grep -i evict || true

kubectl describe node NODE_NAME
```

---

# 13. Lab 4 — Ephemeral Storage Limit Concept

This lab shows how to set ephemeral-storage requests and limits. It may or may not trigger eviction depending on your runtime and node configuration, but it is useful for learning inspection.

Create:

```bash id="do8e97"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/04-ephemeral-storage-concept.yaml
```

Paste:

```yaml id="48vmtt"
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-storage-concept
  namespace: dev
  labels:
    app: ephemeral-storage-concept
spec:
  containers:
    - name: writer
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          echo "Writing a small file safely."
          dd if=/dev/zero of=/tmp/test-file bs=1M count=10
          echo "Done. Sleeping."
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

Apply:

```bash id="10ea51"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/04-ephemeral-storage-concept.yaml
```

Debug:

```bash id="iwls4o"
kubectl get pod ephemeral-storage-concept -n dev -o wide

kubectl describe pod ephemeral-storage-concept -n dev

kubectl logs ephemeral-storage-concept -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Check node:

```bash id="y4qe2p"
NODE="$(kubectl get pod ephemeral-storage-concept -n dev -o jsonpath='{.spec.nodeName}')"

kubectl describe node "$NODE" | sed -n '/Conditions:/,/Addresses:/p'
```

Clean:

```bash id="l0ehsc"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/04-ephemeral-storage-concept.yaml --ignore-not-found=true
```

Production warning:

```text id="7not4h"
Unbounded logs, temp files, caches, and emptyDir writes can contribute to node disk pressure.
Set ephemeral-storage requests/limits where appropriate and collect logs centrally.
```

---

# 14. Lab 5 — Memory Limit vs Node Memory Pressure

A container memory limit can cause `OOMKilled`. Node memory pressure is different: the node itself is under memory pressure and kubelet may evict Pods to protect the node. Kubernetes memory resource docs explain that container memory limits are enforced by the kubelet/runtime, while node-pressure eviction handles broader node resource pressure. ([Kubernetes][6])

Create a controlled OOMKilled lab:

```bash id="tw4u8p"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/05-container-oom-vs-node-pressure.yaml
```

Paste:

```yaml id="g1tm1w"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: container-oom-demo
  namespace: dev
  labels:
    app: container-oom-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: container-oom-demo
  template:
    metadata:
      labels:
        app: container-oom-demo
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
              print("Allocating memory until container limit is reached", flush=True)
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

```bash id="wyngen"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/05-container-oom-vs-node-pressure.yaml
```

Watch:

```bash id="ruig34"
kubectl get pods -n dev -l app=container-oom-demo -w
```

Stop after restart:

```text id="d0w2i0"
Ctrl + C
```

Debug:

```bash id="72dnwt"
POD="$(kubectl get pod -n dev -l app=container-oom-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --previous --tail=50 || true

kubectl get pod "$POD" -n dev \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
echo
```

Expected:

```text id="54n7sr"
OOMKilled
```

Now check node conditions:

```bash id="p5xvfw"
NODE="$(kubectl get pod "$POD" -n dev -o jsonpath='{.spec.nodeName}')"

kubectl get node "$NODE" \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{"\n"}{end}'
```

Interpretation:

```text id="bixiyd"
If Pod says OOMKilled but Node MemoryPressure is False:
  container exceeded its limit.

If many Pods are evicted and Node MemoryPressure is True:
  node-level memory pressure is likely.
```

Clean:

```bash id="nrtvmp"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/05-container-oom-vs-node-pressure.yaml --ignore-not-found=true
```

---

# 15. Kubelet Troubleshooting

The kubelet is the agent running on each node. It talks to the API server, manages Pods on the node, and reports node status.

Common kubelet-related symptoms:

```text id="ooowsu"
Node NotReady
Node status Unknown
Pods stuck ContainerCreating
volume mount errors
container runtime errors
image pull issues on one node
kubelet not posting status
eviction events
```

On a normal Linux node, check:

```bash id="helrox"
sudo systemctl status kubelet

sudo journalctl -u kubelet -n 200 --no-pager

sudo journalctl -u kubelet -f
```

On kind, nodes are Docker containers. Check:

```bash id="4yv55s"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

docker logs devops-k8s-worker --tail=200

docker logs devops-k8s-worker2 --tail=200
```

Exec into a kind node:

```bash id="4zwfcg"
docker exec -it devops-k8s-worker bash
```

Inside kind node:

```bash id="p6f10q"
crictl ps
crictl images
crictl pods
```

Exit:

```bash id="ltoyj8"
exit
```

Production note:

```text id="9d7v41"
On managed Kubernetes, you may not have SSH access to nodes.
Use cloud provider node logs, managed node diagnostics, kubectl describe node, events, and monitoring.
```

---

# 16. Container Runtime Troubleshooting

Kubernetes uses a container runtime through CRI.

Common runtime symptoms:

```text id="rvdw5o"
container cannot start
image pull works on one node but fails on another
runtime socket unavailable
Pod stuck ContainerCreating
container runtime not ready
```

On Linux node:

```bash id="0dselw"
sudo crictl ps
sudo crictl images
sudo crictl pods
sudo crictl info
```

On kind node:

```bash id="kb59ce"
docker exec devops-k8s-worker crictl ps

docker exec devops-k8s-worker crictl images

docker exec devops-k8s-worker crictl info
```

Find Pods on one node:

```bash id="e3i277"
NODE_NAME="devops-k8s-worker"

kubectl get pods -A -o wide --field-selector spec.nodeName="$NODE_NAME"
```

Production rule:

```text id="y50d2f"
If only one node cannot start containers, inspect kubelet and runtime on that node.
```

---

# 17. Image Garbage Collection Concept

Nodes store pulled container images.

Problems can happen when:

```text id="4km757"
image filesystem fills up
old images are not cleaned fast enough
large images consume disk
many image versions are pulled
logs and images compete for disk
```

Kubelet has image garbage collection behavior, and node-pressure eviction can reclaim resources when filesystems are under pressure. ([Kubernetes][5])

Useful checks on kind:

```bash id="l0enls"
docker exec devops-k8s-worker crictl images

docker exec devops-k8s-worker df -h

docker exec devops-k8s-worker du -sh /var/lib/containerd 2>/dev/null || true
```

Production best practices:

```text id="s2lvli"
Use smaller images.
Avoid too many unique tags on nodes.
Centralize logs.
Set ephemeral-storage requests/limits for heavy temp writers.
Monitor node filesystem usage.
Alert before DiskPressure.
```

---

# 18. Safe Cordon and Drain Workflow

`kubectl drain` safely evicts Pods from a node before maintenance and respects PodDisruptionBudgets during safe evictions. Use it before kernel upgrades, reboots, or node replacement. ([Kubernetes][7])

Production workflow:

```text id="sl9okx"
1. Check node health.
2. Check Pods on node.
3. Check PDBs.
4. Cordon node.
5. Drain node with dry-run first.
6. Drain node for real if safe.
7. Perform maintenance.
8. Uncordon node.
9. Validate Pods reschedule and apps recover.
```

Dry-run first:

```bash id="u1ai51"
NODE_NAME="devops-k8s-worker"

kubectl drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

Cordon:

```bash id="ym8ida"
kubectl cordon "$NODE_NAME"
```

Actual drain for a lab cluster only:

```bash id="1ctqd3"
kubectl drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data
```

Uncordon:

```bash id="c22eft"
kubectl uncordon "$NODE_NAME"
```

`kubectl uncordon` marks a node schedulable again after maintenance. ([Kubernetes][8])

---

# 19. Lab 6 — PDB Blocking Drain

Create a Deployment with one replica and a strict PDB.

```bash id="6okfnj"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/06-pdb-blocks-drain.yaml
```

Paste:

```yaml id="8k667o"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdb-drain-demo
  namespace: dev
  labels:
    app: pdb-drain-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pdb-drain-demo
  template:
    metadata:
      labels:
        app: pdb-drain-demo
    spec:
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
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-drain-demo
  namespace: dev
  labels:
    app: pdb-drain-demo
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: pdb-drain-demo
```

Apply:

```bash id="vq0lfw"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/06-pdb-blocks-drain.yaml

kubectl rollout status deployment/pdb-drain-demo -n dev --timeout=120s
```

Find node:

```bash id="c1p3ai"
POD="$(kubectl get pod -n dev -l app=pdb-drain-demo -o jsonpath='{.items[0].metadata.name}')"

NODE_NAME="$(kubectl get pod "$POD" -n dev -o jsonpath='{.spec.nodeName}')"

echo "$POD is on $NODE_NAME"
```

Drain dry-run:

```bash id="iex9e5"
kubectl drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

You may see that eviction is blocked or would be unsafe due to PDB.

Fix by scaling to 2 replicas:

```bash id="xsmkog"
kubectl scale deployment pdb-drain-demo -n dev --replicas=2

kubectl rollout status deployment/pdb-drain-demo -n dev --timeout=120s

kubectl get pdb pdb-drain-demo -n dev
```

Dry-run again:

```bash id="q33flm"
kubectl drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

Production lesson:

```text id="zmmf4j"
A strict PDB with too few replicas can block node maintenance.
PDBs protect availability, but they must match replica count and operational needs.
```

Clean:

```bash id="6w1sou"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/06-pdb-blocks-drain.yaml --ignore-not-found=true
```

---

# 20. Lab 7 — Pods Failing Only on One Node

Sometimes only one node has a problem.

Common signs:

```text id="0y0gcy"
same app works on one node but fails on another
image pull fails only on one node
network to dependency fails only on one node
disk pressure on one node
runtime issue on one node
```

Create a node-pinned app:

```bash id="6oq2nl"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/07-node-specific-debug.yaml
```

Paste:

```yaml id="a8jag6"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-specific-debug
  namespace: dev
  labels:
    app: node-specific-debug
spec:
  replicas: 1
  selector:
    matchLabels:
      app: node-specific-debug
  template:
    metadata:
      labels:
        app: node-specific-debug
    spec:
      nodeSelector:
        kubernetes.io/hostname: devops-k8s-worker
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Running on node-specific debug pod"
              sleep 3600
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="th0nbu"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/07-node-specific-debug.yaml

kubectl rollout status deployment/node-specific-debug -n dev --timeout=120s
```

Check:

```bash id="ictcnb"
kubectl get pods -n dev -l app=node-specific-debug -o wide

NODE_NAME="$(kubectl get pod -n dev -l app=node-specific-debug -o jsonpath='{.items[0].spec.nodeName}')"

kubectl describe node "$NODE_NAME" | sed -n '/Conditions:/,/Addresses:/p'

kubectl get pods -A -o wide --field-selector spec.nodeName="$NODE_NAME"
```

Use this workflow when a real workload fails on one node:

```bash id="67dndn"
FAILED_NODE="NODE_NAME"

kubectl describe node "$FAILED_NODE"

kubectl get pods -A -o wide --field-selector spec.nodeName="$FAILED_NODE"

kubectl get events -A --sort-by=.lastTimestamp | grep "$FAILED_NODE" || true
```

Clean:

```bash id="sxj6f2"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests/07-node-specific-debug.yaml --ignore-not-found=true
```

---

# 21. Create Node Pressure Summary Script

```bash id="ghhpdl"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-pressure-summary.sh
```

Paste:

```bash id="cqq5vm"
#!/usr/bin/env bash
set -euo pipefail

NODE_NAME="${NODE_NAME:-}"

if [ -z "$NODE_NAME" ]; then
  NODE_NAME="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
fi

echo "===== Node Pressure Summary ====="
echo "Node: $NODE_NAME"

echo
echo "Node status:"
kubectl get node "$NODE_NAME" -o wide || true

echo
echo "Conditions:"
kubectl get node "$NODE_NAME" \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}' || true

echo
echo "Capacity:"
kubectl get node "$NODE_NAME" -o jsonpath='{.status.capacity}' || true
echo

echo
echo "Allocatable:"
kubectl get node "$NODE_NAME" -o jsonpath='{.status.allocatable}' || true
echo

echo
echo "Pods on node:"
kubectl get pods -A -o wide --field-selector spec.nodeName="$NODE_NAME" || true

echo
echo "Allocated resources section:"
kubectl describe node "$NODE_NAME" | sed -n '/Allocated resources:/,/Events:/p' || true

echo
echo "Node events:"
kubectl describe node "$NODE_NAME" | sed -n '/Events:/,$p' || true

echo
echo "Top node if metrics available:"
kubectl top node "$NODE_NAME" || true
```

Make executable:

```bash id="bfa3z1"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-pressure-summary.sh
```

Run:

```bash id="h0eocs"
NODE_NAME="devops-k8s-worker" \
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-pressure-summary.sh
```

---

# 22. Create Node Pod Distribution Script

```bash id="fckydn"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/pods-by-node.sh
```

Paste:

```bash id="emfr68"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Pods by Node ====="

for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo
  echo "----- $node -----"
  kubectl get pods -A -o wide --field-selector spec.nodeName="$node" || true
done
```

Make executable:

```bash id="t89ka3"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/pods-by-node.sh
```

Run:

```bash id="s695zm"
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/pods-by-node.sh
```

---

# 23. Create Kubelet Kind Logs Script

```bash id="sfjsj9"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/kind-node-logs.sh
```

Paste:

```bash id="a9g25x"
#!/usr/bin/env bash
set -euo pipefail

NODE_CONTAINER="${NODE_CONTAINER:-devops-k8s-worker}"

echo "===== kind Node Logs ====="
echo "Node container: $NODE_CONTAINER"

echo
echo "Docker container status:"
docker ps --filter "name=$NODE_CONTAINER" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' || true

echo
echo "Last 200 lines of node container logs:"
docker logs "$NODE_CONTAINER" --tail=200 || true

echo
echo "Container runtime info:"
docker exec "$NODE_CONTAINER" crictl info 2>/dev/null | head -n 80 || true

echo
echo "Running containers:"
docker exec "$NODE_CONTAINER" crictl ps 2>/dev/null || true

echo
echo "Images:"
docker exec "$NODE_CONTAINER" crictl images 2>/dev/null | head -n 50 || true

echo
echo "Filesystem:"
docker exec "$NODE_CONTAINER" df -h || true
```

Make executable:

```bash id="ty9ylc"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/kind-node-logs.sh
```

Run:

```bash id="7vbx6v"
NODE_CONTAINER=devops-k8s-worker \
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/kind-node-logs.sh
```

---

# 24. Create Safe Drain Helper Script

```bash id="yjij62"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/safe-drain-preview.sh
```

Paste:

```bash id="3j80f0"
#!/usr/bin/env bash
set -euo pipefail

NODE_NAME="${NODE_NAME:-}"

if [ -z "$NODE_NAME" ]; then
  echo "Usage: NODE_NAME=my-node ./safe-drain-preview.sh"
  exit 1
fi

echo "===== Safe Drain Preview ====="
echo "Node: $NODE_NAME"

echo
echo "Node status:"
kubectl get node "$NODE_NAME" -o wide

echo
echo "Pods on node:"
kubectl get pods -A -o wide --field-selector spec.nodeName="$NODE_NAME"

echo
echo "PDBs:"
kubectl get pdb -A || true

echo
echo "Drain dry-run:"
kubectl drain "$NODE_NAME" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

Make executable:

```bash id="3u34e9"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/safe-drain-preview.sh
```

Run:

```bash id="6s9vwr"
NODE_NAME=devops-k8s-worker \
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/safe-drain-preview.sh
```

---

# 25. Run All Node Labs Script

```bash id="b48f3d"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/run-node-labs.sh
```

Paste:

```bash id="kp5u2n"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests"
NODE_NAME="${NODE_NAME:-devops-k8s-worker}"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "Applying safe node troubleshooting labs..."

kubectl apply -f "$BASE/03-pending-node-resources.yaml" || true
kubectl apply -f "$BASE/04-ephemeral-storage-concept.yaml" || true
kubectl apply -f "$BASE/06-pdb-blocks-drain.yaml" || true
kubectl apply -f "$BASE/07-node-specific-debug.yaml" || true

echo
echo "Node labs applied."
echo
echo "Run summaries:"
echo "./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-inventory.sh"
echo "NODE_NAME=$NODE_NAME ./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/node-pressure-summary.sh"
echo "NODE_NAME=$NODE_NAME ./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/safe-drain-preview.sh"
echo
echo "Note: cordon and taint labs are manual to avoid accidentally leaving your node unschedulable."
```

Make executable:

```bash id="jpr62z"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/run-node-labs.sh
```

Run:

```bash id="hjoi94"
NODE_NAME=devops-k8s-worker \
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/run-node-labs.sh
```

---

# 26. Cleanup Script

```bash id="ftqjz7"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/cleanup-lesson-11-9.sh
```

Paste:

```bash id="6rcsfi"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/manifests"
NODE_NAME="${NODE_NAME:-devops-k8s-worker}"

echo "===== Cleanup Lesson 11.9 ====="

kubectl delete -f "$BASE/07-node-specific-debug.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-pdb-blocks-drain.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-container-oom-vs-node-pressure.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-ephemeral-storage-concept.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-pending-node-resources.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-pending-tainted-node.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-pending-cordoned-node.yaml" --ignore-not-found=true

kubectl uncordon "$NODE_NAME" || true
kubectl taint node "$NODE_NAME" troubleshooting=reserved:NoSchedule- || true

echo "Lesson 11.9 demo resources cleaned."
echo "Node $NODE_NAME has been uncordoned and troubleshooting taint removed if present."
```

Make executable:

```bash id="8f2d2e"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/cleanup-lesson-11-9.sh
```

Run cleanup:

```bash id="j87rtv"
NODE_NAME=devops-k8s-worker \
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/cleanup-lesson-11-9.sh
```

---

# 27. Validation Script

```bash id="vwvcvp"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/validate-lesson-11-9.sh
```

Paste:

```bash id="5xv4sx"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.9 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/node-troubleshooting-mental-model.md"
test -f "$BASE/notes/node-debug-commands.md"

test -f "$BASE/manifests/01-pending-cordoned-node.yaml"
test -f "$BASE/manifests/02-pending-tainted-node.yaml"
test -f "$BASE/manifests/03-pending-node-resources.yaml"
test -f "$BASE/manifests/04-ephemeral-storage-concept.yaml"
test -f "$BASE/manifests/05-container-oom-vs-node-pressure.yaml"
test -f "$BASE/manifests/06-pdb-blocks-drain.yaml"
test -f "$BASE/manifests/07-node-specific-debug.yaml"

test -x "$BASE/scripts/node-inventory.sh"
test -x "$BASE/scripts/node-pressure-summary.sh"
test -x "$BASE/scripts/pods-by-node.sh"
test -x "$BASE/scripts/kind-node-logs.sh"
test -x "$BASE/scripts/safe-drain-preview.sh"
test -x "$BASE/scripts/run-node-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-9.sh"

NODE_COUNT="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"

if [ "$NODE_COUNT" -lt 1 ]; then
  echo "ERROR: no Kubernetes nodes found"
  exit 1
fi

NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

kubectl get node "$NODE" >/dev/null

READY_STATUS="$(kubectl get node "$NODE" -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}')"

if [ -z "$READY_STATUS" ]; then
  echo "ERROR: node Ready condition not found"
  exit 1
fi

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl apply -f "$BASE/manifests/04-ephemeral-storage-concept.yaml" >/dev/null
kubectl wait --for=condition=Ready pod/ephemeral-storage-concept -n dev --timeout=120s >/dev/null

echo "Node count: $NODE_COUNT"
echo "Sample node: $NODE"
echo "Ready status: $READY_STATUS"
echo "Lesson 11.9 validation passed."
```

Make executable:

```bash id="bpjjlm"
chmod +x 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/validate-lesson-11-9.sh
```

Run:

```bash id="lqg4u4"
./11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/scripts/validate-lesson-11-9.sh
```

---

# 28. Node Troubleshooting Runbook

```bash id="3afosz"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/runbooks/node-pressure-kubelet-troubleshooting-runbook.md
```

Paste:

````markdown id="5t8px1"
# Node Pressure and Kubelet Troubleshooting Runbook

## 1. Scope the issue

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
````

Ask:

* one node?
* many nodes?
* one app?
* many unrelated apps?

## 2. Check node conditions

```bash
kubectl describe node NODE_NAME

kubectl get node NODE_NAME \
  -o jsonpath='{range .status.conditions[*]}{.type}{" | "}{.status}{" | "}{.reason}{" | "}{.message}{"\n"}{end}'
```

Look for:

* Ready
* MemoryPressure
* DiskPressure
* PIDPressure
* NetworkUnavailable

## 3. Check Pods on node

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=NODE_NAME
```

Look for:

* Evicted
* CrashLoopBackOff
* ContainerCreating
* ImagePullBackOff
* Running but unhealthy
* many restarts

## 4. Check resource allocation

```bash
kubectl describe node NODE_NAME | sed -n '/Allocated resources:/,/Events:/p'

kubectl top node NODE_NAME
kubectl top pods -A
```

## 5. Check events

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
kubectl describe node NODE_NAME | sed -n '/Events:/,$p'
```

## 6. Check kubelet

Linux node:

```bash
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 200 --no-pager
```

kind node:

```bash
docker logs KIND_NODE_CONTAINER --tail=200
docker exec KIND_NODE_CONTAINER crictl ps
docker exec KIND_NODE_CONTAINER crictl images
docker exec KIND_NODE_CONTAINER df -h
```

## 7. Check runtime

```bash
crictl info
crictl ps
crictl images
```

## 8. For node maintenance

Preview:

```bash
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data --dry-run=server
```

Cordon:

```bash
kubectl cordon NODE_NAME
```

Drain:

```bash
kubectl drain NODE_NAME --ignore-daemonsets --delete-emptydir-data
```

Uncordon:

```bash
kubectl uncordon NODE_NAME
```

## Golden Rule

If many unrelated Pods are affected on one node, treat it as a node incident.

````

---

# 29. Safe Node Maintenance Runbook

```bash id="v4n5zv"
nano 11-advanced-kubernetes-troubleshooting/11.9-node-pressure-kubelet-troubleshooting/runbooks/safe-node-maintenance-runbook.md
````

Paste:

````markdown id="94x5nz"
# Safe Node Maintenance Runbook

## Use Cases

- kernel upgrade
- node reboot
- container runtime upgrade
- disk cleanup
- node replacement
- security patching

## Step 1 — Identify Node

```bash
kubectl get nodes -o wide
````

## Step 2 — Check Workloads

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=NODE_NAME
```

## Step 3 — Check PDBs

```bash
kubectl get pdb -A
```

## Step 4 — Drain Dry Run

```bash
kubectl drain NODE_NAME \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

## Step 5 — Cordon

```bash
kubectl cordon NODE_NAME
```

## Step 6 — Drain

```bash
kubectl drain NODE_NAME \
  --ignore-daemonsets \
  --delete-emptydir-data
```

## Step 7 — Maintain Node

Perform maintenance:

* reboot
* patch
* disk cleanup
* runtime restart
* cloud instance replacement

## Step 8 — Validate Node

```bash
kubectl get node NODE_NAME
kubectl describe node NODE_NAME
```

## Step 9 — Uncordon

```bash
kubectl uncordon NODE_NAME
```

## Step 10 — Validate Apps

```bash
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

## Safety Rules

* Never drain production without checking PDBs.
* Do not drain multiple nodes at once unless capacity and disruption budgets allow it.
* Prefer dry-run first.
* Confirm apps reschedule before moving to the next node.
* Watch alerts and dashboards during maintenance.

````

---

# 30. Node Pressure Production Debug Mapping

```text id="zcfyrm"
Node NotReady:
  check kubelet, runtime, network, node logs, cloud instance health

MemoryPressure:
  check memory usage, requests/limits, OOMKilled Pods, high-memory workloads

DiskPressure:
  check logs, image filesystem, ephemeral-storage, emptyDir usage, image garbage collection

PIDPressure:
  check process count, fork bombs, runaway processes, too many containers

Evicted Pods:
  inspect Pod describe, node events, node conditions, pressure signals

Pods Pending on one node:
  check cordon, taints, nodeSelector, affinity, allocatable resources

Pods failing only on one node:
  inspect node conditions, kubelet logs, runtime, CNI, disk, image cache

Drain stuck:
  check PDBs, local storage, DaemonSets, static Pods, grace periods

Image pulls fail on one node:
  check runtime, registry connectivity from node, image cache, disk pressure
````

---

# 31. Common Mistakes

## Mistake 1: Debugging app logs when node is NotReady

If the node is NotReady, kubelet/runtime/network may be the real problem.

---

## Mistake 2: Confusing OOMKilled with node MemoryPressure

```text id="dcxtbr"
OOMKilled:
  container exceeded memory limit

MemoryPressure:
  node is under memory pressure and may evict Pods
```

---

## Mistake 3: Forgetting cordon state

Check:

```bash id="22paam"
kubectl get nodes
```

If node says `SchedulingDisabled`, new Pods will not schedule there.

---

## Mistake 4: Draining without PDB review

Always check:

```bash id="74wfgf"
kubectl get pdb -A
```

---

## Mistake 5: Leaving node cordoned

After maintenance:

```bash id="i1nm47"
kubectl uncordon NODE_NAME
```

---

## Mistake 6: Ignoring ephemeral storage

Logs, temp files, and caches can break nodes even when CPU and memory look okay.

---

# 32. Interview Explanation

Use this:

```text id="zjjbsi"
When troubleshooting Kubernetes node issues, I first check whether the problem is isolated to one node or spread across the cluster. I inspect node status with kubectl get nodes and kubectl describe node, focusing on Ready, MemoryPressure, DiskPressure, PIDPressure, capacity, allocatable resources, taints, and events.

Then I list all Pods running on the affected node using a field selector and look for Evicted, Pending, ImagePullBackOff, ContainerCreating, OOMKilled, or high restart counts. I compare resource requests, actual usage from metrics, and node allocated resources. For kubelet or runtime issues, I inspect kubelet logs, container runtime status, crictl output, filesystem usage, and node-level events.

For maintenance, I use a safe workflow: check workloads and PDBs, run drain dry-run, cordon the node, drain it safely, perform maintenance, validate node health, uncordon the node, and confirm workloads reschedule correctly.
```

Resume bullet:

```text id="gxqjt6"
Built Kubernetes node troubleshooting labs and runbooks covering Node conditions, NotReady diagnosis, MemoryPressure, DiskPressure, PIDPressure, node-pressure eviction, capacity vs allocatable analysis, cordon/uncordon, safe drain dry-runs, PDB drain blocking, kubelet/runtime inspection, kind node diagnostics, Pod distribution by node, and production node maintenance workflows.
```

---

# 33. Commit Lesson 11.9

```bash id="gx2sjh"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes node pressure and kubelet troubleshooting labs"

git push
```

---

# 34. Next Lesson

```text id="mawp8v"
Lesson 11.10 — Scheduling Failures, Taints, Affinity, Topology, and Resource Shortages
```

We will cover:

```text id="fnpgsg"
FailedScheduling events
insufficient CPU and memory
nodeSelector mismatch
required node affinity mismatch
preferred affinity behavior
taints and tolerations
NoSchedule vs PreferNoSchedule vs NoExecute
pod anti-affinity blocking scheduling
topology spread constraints
PVC WaitForFirstConsumer scheduling
quota-related scheduling failures
scheduler debugging workflow
production scheduling incident runbook
```

[1]: https://kubernetes.io/docs/reference/node/node-status/?utm_source=chatgpt.com "Node Status"
[2]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/?utm_source=chatgpt.com "Resource Management for Pods and Containers"
[3]: https://kubernetes.io/docs/concepts/architecture/nodes/?utm_source=chatgpt.com "Nodes"
[4]: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/?utm_source=chatgpt.com "Taints and Tolerations"
[5]: https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/?utm_source=chatgpt.com "Node-pressure Eviction"
[6]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/?utm_source=chatgpt.com "Assign Memory Resources to Containers and Pods"
[7]: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/?utm_source=chatgpt.com "Safely Drain a Node"
[8]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_uncordon/?utm_source=chatgpt.com "kubectl uncordon"
