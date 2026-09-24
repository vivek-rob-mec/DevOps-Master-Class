# Lesson 10.9 — Resource Requests, Limits, QoS Classes, Scheduling, and Capacity Planning

In Lesson 10.8, you learned **probes, lifecycle hooks, and graceful shutdown**.

Now we move into one of the most important Kubernetes production topics:

```text id="q6ulgc"
CPU
memory
requests
limits
QoS classes
OOMKilled
CPU throttling
scheduler decisions
node allocatable
capacity planning
```

This topic decides whether your cluster is stable or constantly suffering from:

```text id="l70b2k"
Pending Pods
OOMKilled containers
evicted Pods
noisy neighbor problems
CPU throttling
slow APIs
wasted cloud cost
bad autoscaling signals
production incidents
```

Kubernetes lets you specify CPU and memory **requests** and **limits** for containers. Requests are used by the scheduler to place Pods on nodes, while limits constrain how much CPU or memory a container can use at runtime. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="z1kqaa"
10.9.1   CPU and memory mental model
10.9.2   requests vs limits
10.9.3   CPU units and millicores
10.9.4   memory units: Mi vs MB
10.9.5   scheduler resource decisions
10.9.6   node capacity vs allocatable
10.9.7   QoS classes
10.9.8   Guaranteed
10.9.9   Burstable
10.9.10  BestEffort
10.9.11  OOMKilled
10.9.12  CPU throttling
10.9.13  metrics-server
10.9.14  kubectl top
10.9.15  resource debugging
10.9.16  bad resource simulations
10.9.17  production sizing workflow
10.9.18  demo-node-api resource policy
10.9.19  validation script
10.9.20  cleanup script
```

---

# 2. Create Lesson Folder

```bash id="jt7ep7"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.9-resources-qos-capacity-planning/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="g7bi09"
tree -L 2 10.9-resources-qos-capacity-planning
```

---

# 3. Resource Management Mental Model

Every container uses resources.

The two most important resources are:

```text id="whqfmb"
CPU
memory
```

Kubernetes needs to know two things:

```text id="uw91mk"
How much resource does the container need to run normally?
How much resource is the container allowed to use at maximum?
```

That gives us:

```text id="qj8ppi"
requests:
  minimum reserved amount used for scheduling

limits:
  maximum allowed amount at runtime
```

Example:

```yaml id="bi08ls"
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Meaning:

```text id="a3g0k8"
requests.cpu: 100m
  scheduler reserves 0.1 CPU for this container

requests.memory: 128Mi
  scheduler reserves 128 MiB memory for this container

limits.cpu: 500m
  container can use up to 0.5 CPU

limits.memory: 256Mi
  container is killed if it exceeds this memory limit
```

---

# 4. Requests vs Limits

## Requests

Request means:

```text id="jo28cb"
I need at least this much to run properly.
```

The scheduler uses requests to decide where a Pod can fit.

Example:

```yaml id="tclhlv"
requests:
  cpu: "250m"
  memory: "256Mi"
```

Kubernetes scheduler thinks:

```text id="snzl34"
This Pod needs 0.25 CPU and 256Mi memory reserved on a node.
```

## Limits

Limit means:

```text id="h4sdhg"
Do not allow this container to use more than this.
```

Example:

```yaml id="cfstgx"
limits:
  cpu: "1000m"
  memory: "512Mi"
```

Runtime behavior:

```text id="37k0mu"
CPU above limit:
  throttled

Memory above limit:
  container can be killed with OOMKilled
```

Important:

```text id="mfgbmx"
CPU is compressible.
Memory is not.
```

Meaning:

```text id="joklrn"
CPU pressure:
  app becomes slower

Memory pressure:
  process may be killed
```

---

# 5. CPU Units

Kubernetes CPU is measured in CPU cores.

```text id="3pq4s2"
1 CPU = 1 vCPU/core/hyperthread depending on provider
```

You can write CPU as:

```yaml id="9pu9ef"
cpu: "1"
```

or millicores:

```yaml id="u3rk37"
cpu: "1000m"
```

These are equal:

```text id="gkq9wc"
1 CPU = 1000m
0.5 CPU = 500m
0.1 CPU = 100m
0.05 CPU = 50m
```

Common examples:

```text id="231dzh"
small sidecar:
  25m to 100m

small Node.js API:
  100m to 250m request

medium API:
  250m to 500m request

CPU-heavy worker:
  1000m+
```

---

# 6. Memory Units

Kubernetes memory units can use decimal or binary suffixes.

Common binary units:

```text id="aj8iaf"
Ki
Mi
Gi
```

Common decimal units:

```text id="ylfsmu"
K
M
G
```

Important:

```text id="ogc6xe"
Mi is mebibytes.
M is megabytes.
```

Usually in Kubernetes manifests, use:

```text id="2nyvnm"
Mi
Gi
```

Examples:

```yaml id="sh8ura"
memory: "128Mi"
memory: "512Mi"
memory: "1Gi"
```

Avoid confusing:

```yaml id="uvhe5q"
memory: "400m"
```

That means **0.4 bytes**, not 400 megabytes. This is a classic mistake.

Correct:

```yaml id="oxm57d"
memory: "400Mi"
```

---

# 7. Create Notes

```bash id="w8roef"
nano 10.9-resources-qos-capacity-planning/notes/resource-requests-limits-mental-model.md
```

Paste:

```markdown id="qo89pw"
# Kubernetes Resource Requests and Limits Mental Model

## Requests

Requests are used by the scheduler.

They answer:

How much CPU and memory should Kubernetes reserve for this container?

## Limits

Limits are enforced at runtime.

They answer:

What is the maximum CPU or memory this container can use?

## CPU

- 1 CPU = 1000m
- 500m = half CPU
- CPU above limit is throttled

## Memory

- Use Mi or Gi
- Memory above limit can cause OOMKilled

## Golden Rules

- Set memory requests and limits carefully.
- Do not set memory limits too low.
- CPU limits can cause throttling.
- Requests affect scheduling and cluster capacity.
- Limits affect runtime behavior.
```

---

# 8. Scheduler Resource Decisions

The Kubernetes scheduler places Pods on nodes based partly on requests.

Example node allocatable:

```text id="4kna3i"
Node allocatable:
  cpu: 2
  memory: 4Gi
```

Existing scheduled Pods request:

```text id="fibxg5"
cpu: 1500m
memory: 3Gi
```

New Pod request:

```text id="i8n78o"
cpu: 700m
memory: 512Mi
```

Can it fit?

```text id="v092av"
CPU available:
  2000m - 1500m = 500m

New Pod needs:
  700m

Result:
  cannot schedule on this node
```

Even if actual CPU usage is low, scheduler uses **requests**, not live usage.

This is a big point:

```text id="txllkz"
Scheduling is based on requested resources.
Runtime usage is different.
```

---

# 9. Node Capacity vs Allocatable

A node has capacity.

But Pods do not get all capacity.

Some resources are reserved for:

```text id="2xbh2h"
kubelet
container runtime
system daemons
OS
eviction thresholds
```

Kubernetes exposes **Allocatable** as the amount of compute resources available for Pods, and the scheduler does not over-subscribe allocatable resources. ([Kubernetes][2])

Check:

```bash id="se3kpe"
kubectl describe node
```

Look for:

```text id="3b42ih"
Capacity:
  cpu
  memory

Allocatable:
  cpu
  memory

Allocated resources:
  Requests
  Limits
```

Cleaner commands:

```bash id="ev9xby"
kubectl get nodes

kubectl describe node devops-k8s-worker | less
```

Useful extraction:

```bash id="jy822m"
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,ALLOC_CPU:.status.allocatable.cpu,ALLOC_MEM:.status.allocatable.memory
```

---

# 10. QoS Classes

Kubernetes assigns each Pod a QoS class based on resource requests and limits.

QoS classes:

```text id="o2x4sl"
Guaranteed
Burstable
BestEffort
```

Kubernetes uses QoS classes to help decide which Pods to evict first during node pressure. BestEffort Pods are evicted before Burstable Pods, and Guaranteed Pods are the last to be evicted. ([Kubernetes][3])

Check a Pod’s QoS:

```bash id="fnr8fr"
kubectl get pod POD_NAME -n dev -o jsonpath='{.status.qosClass}'
echo
```

---

# 11. Guaranteed QoS

A Pod gets `Guaranteed` QoS when every container has CPU and memory request and limit set, and request equals limit for both CPU and memory.

Example:

```yaml id="0i3eeo"
resources:
  requests:
    cpu: "500m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Characteristics:

```text id="vo6l8l"
most protected during eviction
least flexible
can reduce bin-packing efficiency
useful for critical workloads
```

Use for:

```text id="aia8hi"
critical system components
latency-sensitive apps with known usage
strictly sized workloads
```

---

# 12. Burstable QoS

A Pod gets `Burstable` QoS when at least one request or limit is set, but it does not meet Guaranteed criteria.

Example:

```yaml id="apdpbi"
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Characteristics:

```text id="y5b92p"
common for applications
can burst above request up to limit
less protected than Guaranteed
more protected than BestEffort
```

Most production apps are often Burstable.

This is a good starting point for your Node.js API.

---

# 13. BestEffort QoS

A Pod gets `BestEffort` QoS when no CPU or memory requests/limits are set.

Example:

```yaml id="adyosw"
containers:
  - name: app
    image: busybox
```

Characteristics:

```text id="8m0vo9"
no guaranteed resources
first to be evicted under pressure
bad for production applications
easy to create accidentally
```

Use for:

```text id="u4htfd"
quick experiments
temporary debug Pods
very low importance workloads
```

Production rule:

```text id="swc6qr"
Do not run important production apps as BestEffort.
```

---

# 14. Create QoS Demo Pods

## BestEffort Pod

Create:

```bash id="xfec19"
nano 10.9-resources-qos-capacity-planning/manifests/qos-besteffort-pod.yaml
```

Paste:

```yaml id="brknmu"
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort
  namespace: dev
  labels:
    app: qos-demo
    qos: besteffort
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
```

## Burstable Pod

Create:

```bash id="e7qtzf"
nano 10.9-resources-qos-capacity-planning/manifests/qos-burstable-pod.yaml
```

Paste:

```yaml id="qlu831"
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable
  namespace: dev
  labels:
    app: qos-demo
    qos: burstable
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "50m"
          memory: "64Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
```

## Guaranteed Pod

Create:

```bash id="ltl350"
nano 10.9-resources-qos-capacity-planning/manifests/qos-guaranteed-pod.yaml
```

Paste:

```yaml id="oii98n"
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed
  namespace: dev
  labels:
    app: qos-demo
    qos: guaranteed
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "100m"
          memory: "128Mi"
```

Apply:

```bash id="hlf40k"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-besteffort-pod.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-burstable-pod.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-guaranteed-pod.yaml
```

Check:

```bash id="h7n7k0"
kubectl get pods -n dev -l app=qos-demo
```

View QoS:

```bash id="usqj45"
for pod in qos-besteffort qos-burstable qos-guaranteed; do
  echo -n "$pod QoS: "
  kubectl get pod "$pod" -n dev -o jsonpath='{.status.qosClass}'
  echo
done
```

Expected:

```text id="ekp0ed"
qos-besteffort QoS: BestEffort
qos-burstable QoS: Burstable
qos-guaranteed QoS: Guaranteed
```

---

# 15. Pending Pod Due to Huge Request

Create a Pod that cannot fit because it requests too much CPU and memory.

```bash id="vx56rd"
nano 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml
```

Paste:

```yaml id="cu12dy"
apiVersion: v1
kind: Pod
metadata:
  name: pending-huge-request
  namespace: dev
  labels:
    app: resource-demo
    scenario: huge-request
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "1000"
          memory: "1000Gi"
        limits:
          cpu: "1000"
          memory: "1000Gi"
```

Apply:

```bash id="kyq7rw"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml
```

Check:

```bash id="ueebvi"
kubectl get pod pending-huge-request -n dev
kubectl describe pod pending-huge-request -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text id="muu64m"
Pending
Insufficient cpu
Insufficient memory
```

Lesson:

```text id="ed0ci7"
A Pod can stay Pending because no node has enough allocatable resources for its requests.
```

Delete:

```bash id="ikhr4e"
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml
```

---

# 16. OOMKilled Demo

Now create a Pod with a low memory limit and a process that allocates memory.

Create:

```bash id="ly50zb"
nano 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml
```

Paste:

```yaml id="9kocx5"
apiVersion: v1
kind: Pod
metadata:
  name: oomkilled-demo
  namespace: dev
  labels:
    app: resource-demo
    scenario: oomkilled
spec:
  restartPolicy: Always
  containers:
    - name: app
      image: python:3.12-alpine
      command:
        - python
        - -c
        - |
          import time
          data = []
          print("Allocating memory...", flush=True)
          while True:
              data.append("x" * 1024 * 1024)
              print(f"Allocated ~{len(data)} MiB", flush=True)
              time.sleep(0.2)
      resources:
        requests:
          cpu: "50m"
          memory: "32Mi"
        limits:
          cpu: "200m"
          memory: "64Mi"
```

Apply:

```bash id="fqb493"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml
```

Watch:

```bash id="5w9sia"
kubectl get pod oomkilled-demo -n dev -w
```

After some time, you may see restarts.

Exit:

```text id="re4rrm"
Ctrl + C
```

Inspect:

```bash id="aq7g2k"
kubectl describe pod oomkilled-demo -n dev
kubectl get pod oomkilled-demo -n dev -o jsonpath='{.status.containerStatuses[0].lastState}'
echo
kubectl logs oomkilled-demo -n dev --previous || true
```

Look for:

```text id="1we8ii"
reason: OOMKilled
exitCode: 137
```

Lesson:

```text id="s7fw4v"
Memory limit is a hard boundary.
If the process exceeds it, it can be killed.
```

Clean it after observation:

```bash id="hmvxfk"
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml
```

---

# 17. CPU Limit and Throttling Demo

CPU limits do not usually kill a container.

They throttle it.

Create:

```bash id="gl8093"
nano 10.9-resources-qos-capacity-planning/manifests/cpu-limit-demo-deployment.yaml
```

Paste:

```yaml id="nr973g"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-limit-demo
  namespace: dev
  labels:
    app: cpu-limit-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cpu-limit-demo
  template:
    metadata:
      labels:
        app: cpu-limit-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Starting CPU loop"
              while true; do :; done
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="lzpwvo"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/cpu-limit-demo-deployment.yaml
```

Check:

```bash id="h0coqf"
kubectl get pod -n dev -l app=cpu-limit-demo
kubectl describe pod -n dev -l app=cpu-limit-demo
```

If metrics-server is installed, later `kubectl top` will show CPU usage.

Lesson:

```text id="b5l7mf"
CPU limit slows/throttles.
Memory limit kills when exceeded.
```

Delete after observing:

```bash id="y593f6"
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/cpu-limit-demo-deployment.yaml
```

---

# 18. metrics-server and kubectl top

`kubectl top` shows recent resource consumption for nodes and Pods. It gets metrics from Metrics Server, which aggregates data from kubelets on each node. Metrics Server must be installed and running for `kubectl top` to work. ([Kubernetes][4])

Try:

```bash id="9z0tmi"
kubectl top nodes
kubectl top pods -n dev
```

If you see:

```text id="l77log"
Metrics API not available
```

install metrics-server.

For kind/local labs, install:

```bash id="hy79do"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Patch metrics-server for kind self-signed kubelet certificates:

```bash id="ls17r9"
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--kubelet-insecure-tls"
    }
  ]'
```

Wait:

```bash id="9l8q7r"
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
```

Try again after a minute:

```bash id="6uy26d"
kubectl top nodes
kubectl top pods -n dev
```

Metrics Server fetches resource metrics from kubelets and exposes them through the Kubernetes Metrics API for tools such as HPA, VPA, and `kubectl top`. ([Kubernetes][5])

---

# 19. Create Resource Demo Deployment

Create a more realistic deployment with requests and limits.

```bash id="qetshj"
nano 10.9-resources-qos-capacity-planning/manifests/resource-demo-deployment.yaml
```

Paste:

```yaml id="2gqw0k"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-demo
  namespace: dev
  labels:
    app: resource-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: resource-demo
  template:
    metadata:
      labels:
        app: resource-demo
        environment: dev
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
```

Apply:

```bash id="qlzj60"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/resource-demo-deployment.yaml
```

Check:

```bash id="e4fgol"
kubectl rollout status deployment/resource-demo -n dev
kubectl get pods -n dev -l app=resource-demo
kubectl describe pod -n dev -l app=resource-demo
```

Check QoS:

```bash id="85gj30"
POD_NAME="$(kubectl get pod -n dev -l app=resource-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.status.qosClass}'
echo
```

Expected:

```text id="u1mpb4"
Burstable
```

---

# 20. Inspect Node Allocated Resources

Run:

```bash id="duy5zv"
kubectl describe node devops-k8s-worker | less
```

Search inside `less`:

```text id="pjroum"
/Allocated resources
```

You will see something like:

```text id="2r0kom"
Resource           Requests      Limits
cpu                ...
memory             ...
```

This is where you understand how your Pods consume node schedulable capacity.

Useful custom script:

```bash id="0u0erb"
kubectl get pods -A \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName,QOS:.status.qosClass
```

---

# 21. Create Resource Summary Script

Create:

```bash id="cyxeim"
nano 10.9-resources-qos-capacity-planning/scripts/resource-summary.sh
```

Paste:

```bash id="41zl9j"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Kubernetes Resource Summary ====="

echo
echo "Current context:"
kubectl config current-context

echo
echo "Namespace: $NAMESPACE"

echo
echo "Nodes capacity and allocatable:"
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory,ALLOC_CPU:.status.allocatable.cpu,ALLOC_MEM:.status.allocatable.memory

echo
echo "Pods with QoS and Node:"
kubectl get pods -n "$NAMESPACE" \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,QOS:.status.qosClass

echo
echo "Resource requests/limits by Pod:"
kubectl get pods -n "$NAMESPACE" -o json | jq -r '
.items[] |
[
  .metadata.name,
  (.status.qosClass // "unknown"),
  ([.spec.containers[].resources.requests.cpu // "none"] | join(",")),
  ([.spec.containers[].resources.requests.memory // "none"] | join(",")),
  ([.spec.containers[].resources.limits.cpu // "none"] | join(",")),
  ([.spec.containers[].resources.limits.memory // "none"] | join(","))
] | @tsv' | column -t -s $'\t'

echo
echo "kubectl top nodes, if metrics-server is available:"
kubectl top nodes || true

echo
echo "kubectl top pods, if metrics-server is available:"
kubectl top pods -n "$NAMESPACE" || true
```

Make executable:

```bash id="p13a1j"
chmod +x 10.9-resources-qos-capacity-planning/scripts/resource-summary.sh
```

Run:

```bash id="e77tg2"
./10.9-resources-qos-capacity-planning/scripts/resource-summary.sh
```

---

# 22. Resource Debugging Runbook

Create:

```bash id="mhvpvv"
nano 10.9-resources-qos-capacity-planning/runbooks/resource-debugging-runbook.md
```

Paste:

````markdown id="mgtjg1"
# Kubernetes Resource Debugging Runbook

## Step 1 — Check Pod Status

```bash
kubectl get pods -n NAMESPACE
````

Look for:

* Pending
* OOMKilled
* Evicted
* CrashLoopBackOff

## Step 2 — Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* requests
* limits
* events
* reason
* last state
* exit code
* node

## Step 3 — Check Node Capacity

```bash
kubectl describe node NODE_NAME
```

Look for:

* Capacity
* Allocatable
* Allocated resources
* Conditions
* Pressure

## Step 4 — Check QoS

```bash
kubectl get pod POD_NAME -n NAMESPACE -o jsonpath='{.status.qosClass}'
```

## Step 5 — Check Usage

```bash
kubectl top nodes
kubectl top pods -n NAMESPACE
```

Requires metrics-server.

## Common Problems

| Symptom    | Likely Cause                         |
| ---------- | ------------------------------------ |
| Pending    | request too high or no matching node |
| OOMKilled  | memory limit too low or memory leak  |
| CPU slow   | CPU throttling or insufficient CPU   |
| Evicted    | node pressure                        |
| BestEffort | missing requests and limits          |

## Golden Rule

Requests affect scheduling.
Limits affect runtime behavior.
QoS affects eviction priority.

````

---

# 23. OOMKilled Runbook

Create:

```bash id="jbtb02"
nano 10.9-resources-qos-capacity-planning/runbooks/oomkilled-runbook.md
````

Paste:

````markdown id="625j7c"
# OOMKilled Debugging Runbook

## Meaning

OOMKilled means the container exceeded its memory limit or was killed under memory pressure.

## Check

```bash
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get pod POD_NAME -n NAMESPACE -o yaml
kubectl logs POD_NAME -n NAMESPACE --previous
````

Look for:

* Last State
* Reason: OOMKilled
* Exit Code: 137
* memory limits
* restart count

## Common Causes

* memory limit too low
* memory leak
* large startup allocation
* unexpected traffic spike
* inefficient cache
* JVM/Node/Python runtime memory behavior
* sidecar memory usage ignored

## Fix Options

* increase memory limit
* increase memory request
* optimize application memory
* tune runtime memory settings
* reduce concurrency
* fix memory leak
* add autoscaling
* split workload

## Production Warning

Increasing memory limit may hide the symptom.
Always investigate actual memory behavior.

````

---

# 24. Capacity Planning Runbook

Create:

```bash id="2btab2"
nano 10.9-resources-qos-capacity-planning/runbooks/capacity-planning-runbook.md
````

Paste:

````markdown id="xtsjc4"
# Kubernetes Capacity Planning Runbook

## Goal

Right-size requests and limits for stable performance and cost efficiency.

## Inputs

- current CPU usage
- current memory usage
- peak CPU
- peak memory
- startup memory
- traffic patterns
- replica count
- latency SLO
- autoscaling policy
- node size
- cost target

## Starting Point

For a small Node.js API:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
````

## Observe

```bash
kubectl top pods -n production
kubectl top nodes
```

Use Prometheus/Grafana later for better history.

## Tune

* request too high: wasted capacity
* request too low: poor scheduling and eviction risk
* memory limit too low: OOMKilled
* CPU limit too low: throttling and latency
* no request: weak scheduling
* no limit: noisy neighbor risk

## Production Rule

Size based on observed p95/p99 usage, startup behavior, and SLOs.
Do not guess once real metrics are available.

````

---

# 25. Update `demo-node-api` Deployment with Resources

Open:

```bash id="kmecyl"
nano apps/demo-node-api/base/deployment.yaml
````

Add this under the container section, after probes or before probes:

```yaml id="ywhgkx"
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
```

Full improved container section should include:

```yaml id="fbvmv3"
        - name: demo-node-api
          image: demo-node-api:0.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3002

          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"

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
```

Why this starting point?

```text id="5dhl3i"
100m CPU request:
  small baseline reservation for Node.js API

128Mi memory request:
  baseline memory reservation

500m CPU limit:
  lets API burst under load

512Mi memory limit:
  protects node from runaway memory while giving enough room for small API
```

Production note:

```text id="dq1m1g"
These are starting values.
Real values should come from metrics after load testing and production observation.
```

---

# 26. Resource Policy for `demo-node-api`

Create:

```bash id="cer73h"
nano 10.9-resources-qos-capacity-planning/notes/demo-node-api-resource-policy.md
```

Paste:

````markdown id="oaocfz"
# demo-node-api Resource Policy

## Starting Resource Profile

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
````

## Rationale

* Node.js API is lightweight at baseline.
* CPU can burst during request spikes.
* Memory limit protects the node from runaway memory.
* Burstable QoS is acceptable for this app at this stage.

## Review Triggers

Adjust resources if:

* p95 CPU usage is consistently above request
* memory usage is near limit
* OOMKilled occurs
* latency increases during CPU throttling
* HPA scales too late or too often
* startup memory exceeds normal runtime memory
* traffic grows significantly

## Production Rule

Requests and limits must be reviewed after load testing and after real production metrics are available.

````

---

# 27. LimitRange Preview

In production, teams often set namespace defaults using `LimitRange`.

Create preview only:

```bash id="f8alvg"
nano 10.9-resources-qos-capacity-planning/manifests/dev-limitrange.yaml
````

Paste:

```yaml id="ds8ncl"
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-default-limits
  namespace: dev
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: "50m"
        memory: "64Mi"
      default:
        cpu: "250m"
        memory: "256Mi"
```

Apply:

```bash id="jlpct3"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/dev-limitrange.yaml
```

Check:

```bash id="yemabx"
kubectl describe limitrange dev-default-limits -n dev
```

LimitRange can set default resource requests and limits for containers in a namespace. This helps avoid accidental BestEffort Pods. We will discuss namespace governance more deeply later.

---

# 28. ResourceQuota Preview

ResourceQuota controls total resource consumption inside a namespace.

Create preview:

```bash id="p7fcpm"
nano 10.9-resources-qos-capacity-planning/manifests/dev-resourcequota.yaml
```

Paste:

```yaml id="3k5fro"
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-compute-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    pods: "30"
```

Apply:

```bash id="uj23kz"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/dev-resourcequota.yaml
```

Check:

```bash id="rjqq7x"
kubectl describe resourcequota dev-compute-quota -n dev
```

Production use:

```text id="ct1x6z"
prevent one namespace from consuming entire cluster
enforce team budgets
support multi-team cluster governance
```

We will revisit this in namespace governance and platform engineering.

---

# 29. Resource Myths and Misconceptions

## Myth 1: Limit and request are the same

Wrong.

```text id="n5925h"
request:
  scheduling reservation

limit:
  runtime maximum
```

## Myth 2: CPU limit kills the container

Usually wrong.

```text id="4dlkoi"
CPU over limit is throttled.
Memory over limit can be killed.
```

## Myth 3: No limits means best performance

Risky.

```text id="tm8u1a"
A container without limits can become a noisy neighbor.
```

## Myth 4: No requests means Kubernetes will figure it out

Wrong.

```text id="iokgu4"
Without requests, scheduler cannot reserve realistic capacity.
```

## Myth 5: Guaranteed QoS is always best

Not always.

```text id="aprhmb"
Guaranteed is protected but less flexible.
Burstable is common and practical for many apps.
```

## Myth 6: OOMKilled always means Kubernetes problem

Usually not.

```text id="f2gjw2"
It may mean memory limit too low, memory leak, or app memory spike.
```

---

# 30. Validation Script

Create:

```bash id="o6y236"
nano 10.9-resources-qos-capacity-planning/scripts/validate-lesson-10-9.sh
```

Paste:

```bash id="fug8va"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.9 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get pod qos-besteffort -n dev >/dev/null
kubectl get pod qos-burstable -n dev >/dev/null
kubectl get pod qos-guaranteed -n dev >/dev/null
kubectl get deployment resource-demo -n dev >/dev/null

BESTEFFORT_QOS="$(kubectl get pod qos-besteffort -n dev -o jsonpath='{.status.qosClass}')"
BURSTABLE_QOS="$(kubectl get pod qos-burstable -n dev -o jsonpath='{.status.qosClass}')"
GUARANTEED_QOS="$(kubectl get pod qos-guaranteed -n dev -o jsonpath='{.status.qosClass}')"

if [ "$BESTEFFORT_QOS" != "BestEffort" ]; then
  echo "ERROR: qos-besteffort should be BestEffort, got $BESTEFFORT_QOS"
  exit 1
fi

if [ "$BURSTABLE_QOS" != "Burstable" ]; then
  echo "ERROR: qos-burstable should be Burstable, got $BURSTABLE_QOS"
  exit 1
fi

if [ "$GUARANTEED_QOS" != "Guaranteed" ]; then
  echo "ERROR: qos-guaranteed should be Guaranteed, got $GUARANTEED_QOS"
  exit 1
fi

RESOURCE_POD="$(kubectl get pod -n dev -l app=resource-demo -o jsonpath='{.items[0].metadata.name}')"

REQ_CPU="$(kubectl get pod "$RESOURCE_POD" -n dev -o jsonpath='{.spec.containers[0].resources.requests.cpu}')"
REQ_MEM="$(kubectl get pod "$RESOURCE_POD" -n dev -o jsonpath='{.spec.containers[0].resources.requests.memory}')"
LIMIT_CPU="$(kubectl get pod "$RESOURCE_POD" -n dev -o jsonpath='{.spec.containers[0].resources.limits.cpu}')"
LIMIT_MEM="$(kubectl get pod "$RESOURCE_POD" -n dev -o jsonpath='{.spec.containers[0].resources.limits.memory}')"

if [ "$REQ_CPU" != "50m" ] || [ "$REQ_MEM" != "64Mi" ] || [ "$LIMIT_CPU" != "250m" ] || [ "$LIMIT_MEM" != "128Mi" ]; then
  echo "ERROR: resource-demo resources mismatch"
  echo "requests cpu=$REQ_CPU memory=$REQ_MEM limits cpu=$LIMIT_CPU memory=$LIMIT_MEM"
  exit 1
fi

kubectl get limitrange dev-default-limits -n dev >/dev/null
kubectl get resourcequota dev-compute-quota -n dev >/dev/null

test -x 10.9-resources-qos-capacity-planning/scripts/resource-summary.sh
test -f 10.9-resources-qos-capacity-planning/notes/resource-requests-limits-mental-model.md
test -f 10.9-resources-qos-capacity-planning/notes/demo-node-api-resource-policy.md
test -f 10.9-resources-qos-capacity-planning/runbooks/resource-debugging-runbook.md
test -f 10.9-resources-qos-capacity-planning/runbooks/oomkilled-runbook.md
test -f 10.9-resources-qos-capacity-planning/runbooks/capacity-planning-runbook.md
test -f apps/demo-node-api/base/deployment.yaml

grep -q 'cpu: "100m"' apps/demo-node-api/base/deployment.yaml
grep -q 'memory: "128Mi"' apps/demo-node-api/base/deployment.yaml
grep -q 'cpu: "500m"' apps/demo-node-api/base/deployment.yaml
grep -q 'memory: "512Mi"' apps/demo-node-api/base/deployment.yaml

echo "QoS:"
echo "  qos-besteffort=$BESTEFFORT_QOS"
echo "  qos-burstable=$BURSTABLE_QOS"
echo "  qos-guaranteed=$GUARANTEED_QOS"
echo "Lesson 10.9 validation passed."
```

Make executable:

```bash id="5k8umf"
chmod +x 10.9-resources-qos-capacity-planning/scripts/validate-lesson-10-9.sh
```

Run:

```bash id="hxmy3r"
./10.9-resources-qos-capacity-planning/scripts/validate-lesson-10-9.sh
```

---

# 31. Cleanup Script

Create:

```bash id="scclba"
nano 10.9-resources-qos-capacity-planning/scripts/cleanup-lesson-10-9.sh
```

Paste:

```bash id="dhbi62"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.9 ====="

kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/cpu-limit-demo-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/resource-demo-deployment.yaml --ignore-not-found=true

kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/qos-besteffort-pod.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/qos-burstable-pod.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/qos-guaranteed-pod.yaml --ignore-not-found=true

kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/dev-limitrange.yaml --ignore-not-found=true
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/dev-resourcequota.yaml --ignore-not-found=true

echo "Lesson 10.9 resources cleaned."
echo "Namespace dev and cluster kept for next lessons."
```

Make executable:

```bash id="n5gq7z"
chmod +x 10.9-resources-qos-capacity-planning/scripts/cleanup-lesson-10-9.sh
```

Run only if you want cleanup:

```bash id="y3hcwz"
./10.9-resources-qos-capacity-planning/scripts/cleanup-lesson-10-9.sh
```

---

# 32. Practical Lab Summary

Run the main lab:

```bash id="3xg7tc"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-besteffort-pod.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-burstable-pod.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/qos-guaranteed-pod.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/resource-demo-deployment.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/dev-limitrange.yaml
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/dev-resourcequota.yaml

for pod in qos-besteffort qos-burstable qos-guaranteed; do
  echo -n "$pod QoS: "
  kubectl get pod "$pod" -n dev -o jsonpath='{.status.qosClass}'
  echo
done

./10.9-resources-qos-capacity-planning/scripts/resource-summary.sh
./10.9-resources-qos-capacity-planning/scripts/validate-lesson-10-9.sh
```

Run failure demos separately:

```bash id="etjtba"
kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml
kubectl describe pod pending-huge-request -n dev
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/pending-huge-request-pod.yaml

kubectl apply -f 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml
kubectl describe pod oomkilled-demo -n dev
kubectl delete -f 10.9-resources-qos-capacity-planning/manifests/oomkilled-demo-pod.yaml
```

---

# 33. Production Sizing Workflow

Use this approach:

```text id="6sqahl"
1. Start with reasonable initial requests/limits.
2. Load test the app.
3. Observe CPU and memory usage.
4. Check p50, p95, p99 usage.
5. Check startup memory spikes.
6. Check latency under CPU pressure.
7. Check OOMKilled history.
8. Adjust requests for scheduling reliability.
9. Adjust limits for safety without over-throttling.
10. Add HPA after resource signals are reliable.
```

Example for `demo-node-api`:

```text id="xqv44s"
Initial:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

After observation:
  if CPU p95 is 220m:
    request may become 250m

  if memory p95 is 280Mi:
    request may become 320Mi
    limit may become 768Mi

  if CPU throttling hurts latency:
    increase or remove CPU limit depending on policy
```

---

# 34. Production Rules

```text id="guwruu"
Set resource requests for every production container.
Set memory limits carefully.
Avoid BestEffort for production workloads.
Understand that CPU limit throttles and memory limit kills.
Use Mi/Gi for memory.
Use millicores for CPU.
Right-size from metrics, not guessing.
Use QoS class intentionally.
Use LimitRange for namespace defaults.
Use ResourceQuota for namespace governance.
Watch node allocatable, not just capacity.
Use metrics-server for basic current metrics.
Use Prometheus/Grafana for historical production metrics.
```

---

# 35. Interview Explanation

Use this:

```text id="7iu5ru"
In Kubernetes, resource requests are used by the scheduler to decide where a Pod can run, while limits define the maximum runtime resources a container can use. CPU is measured in cores or millicores, where 1000m equals 1 CPU. Memory is usually defined using Mi or Gi.

If a container exceeds its CPU limit, it is throttled. If it exceeds its memory limit, it can be killed with OOMKilled. Kubernetes also assigns Pods QoS classes: Guaranteed, Burstable, and BestEffort. QoS affects eviction priority under node pressure, with BestEffort evicted first and Guaranteed last.

For production, I set resource requests and limits based on observed metrics, load testing, and SLOs, and I avoid running important workloads without requests.
```

Resume version:

```text id="4ut6to"
Implemented Kubernetes resource management labs covering CPU/memory requests and limits, QoS classes, Pending scheduling failures, OOMKilled debugging, metrics-server, kubectl top, LimitRange, ResourceQuota, and production resource policy for demo-node-api.
```

---

# 36. Today’s Core Rules

```text id="ggfn8u"
Requests are for scheduling.
Limits are for runtime enforcement.
CPU above limit is throttled.
Memory above limit can be OOMKilled.
1 CPU = 1000m.
Use Mi/Gi for memory.
BestEffort has no requests or limits.
Burstable has partial or unequal requests/limits.
Guaranteed has equal CPU and memory requests/limits for all containers.
Scheduler uses requests, not live usage.
Node allocatable is what Pods can use.
OOMKilled often means memory limit too low or memory leak.
kubectl top needs metrics-server.
Capacity planning must use real metrics.
```

---

# 37. Commit Lesson 10.9

From repo root:

```bash id="fpoeqg"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes resources QoS and capacity planning lesson"

git push
```

---

# Next Lesson

```text id="spb2hm"
Lesson 10.10 — Nodes, Taints, Tolerations, Affinity, Anti-Affinity, Topology Spread, and Workload Placement
```

We will cover:

```text id="80esyz"
node labels
nodeSelector
node affinity
pod affinity
pod anti-affinity
taints
tolerations
NoSchedule
PreferNoSchedule
NoExecute
topology spread constraints
zone-aware placement
dedicated nodes
system vs application workloads
production placement strategy for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/?utm_source=chatgpt.com "Resource Management for Pods and Containers"
[2]: https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/?utm_source=chatgpt.com "Reserve Compute Resources for System Daemons"
[3]: https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/?utm_source=chatgpt.com "Pod Quality of Service Classes"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/?utm_source=chatgpt.com "kubectl top"
[5]: https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/?utm_source=chatgpt.com "Resource metrics pipeline"
