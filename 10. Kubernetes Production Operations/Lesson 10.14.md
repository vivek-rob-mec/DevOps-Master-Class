# Lesson 10.14 — Autoscaling: HPA, VPA Concepts, Cluster Autoscaler, PDBs, and Safe Scaling

In Lesson 10.13, you learned **Helm, Kustomize, overlays, packaging, and release promotion**.

Now we move to production scaling.

This lesson answers:

```text id="3jby6d"
When should Kubernetes add more Pods?
When should Kubernetes remove Pods?
When should cluster nodes increase?
When should node capacity decrease?
How do we prevent too many Pods from being disrupted at once?
How do we scale safely without breaking availability?
```

Kubernetes supports workload autoscaling through the **HorizontalPodAutoscaler**, which adjusts replica count based on observed metrics such as CPU or memory utilization. Kubernetes also documents vertical scaling concepts, node autoscaling, and PodDisruptionBudgets as separate but related production scaling controls. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="j0up7o"
10.14.1   Scaling mental model
10.14.2   Manual scaling vs autoscaling
10.14.3   HPA mental model
10.14.4   metrics-server dependency
10.14.5   CPU-based HPA
10.14.6   Memory-based HPA
10.14.7   Custom metrics concept
10.14.8   Load generation
10.14.9   HPA debugging
10.14.10  VPA concepts
10.14.11  HPA vs VPA
10.14.12  Cluster Autoscaler concepts
10.14.13  Pending Pods and node scaling
10.14.14  PodDisruptionBudget
10.14.15  Safe scale up
10.14.16  Safe scale down
10.14.17  Autoscaling failure modes
10.14.18  Production autoscaling policy for demo-node-api
10.14.19  Validation script
10.14.20  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="p6f2dg"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.14-autoscaling-pdb-safe-scaling/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="kzctra"
tree -L 2 10.14-autoscaling-pdb-safe-scaling
```

---

# 3. Scaling Mental Model

There are three major scaling dimensions:

```text id="k7p2px"
Horizontal scaling:
  add or remove Pods

Vertical scaling:
  increase or decrease CPU/memory per Pod

Cluster/node scaling:
  add or remove nodes
```

Simple example:

```text id="8n36mq"
Traffic increases
  ↓
HPA adds Pods
  ↓
More Pods need resources
  ↓
Cluster Autoscaler may add Nodes
```

Another example:

```text id="7s6za0"
App memory usage grows
  ↓
VPA recommends higher memory request
  ↓
Deployment updated with better resources
  ↓
Pods restart with new sizing
```

Important:

```text id="lg98ni"
HPA scales replica count.
VPA adjusts Pod resource sizing.
Cluster Autoscaler adjusts node count.
PDB protects availability during voluntary disruptions.
```

---

# 4. Manual Scaling vs Autoscaling

Manual scaling:

```bash id="1yezfa"
kubectl scale deployment demo-node-api -n dev --replicas=5
```

Autoscaling:

```text id="r6gu9a"
Kubernetes watches metrics.
Kubernetes adjusts replica count.
```

Kubernetes documentation contrasts manual scaling, where you directly set `.spec.replicas`, with automatic scaling, where the HPA adjusts replicas based on observed metrics such as CPU, memory, or custom metrics. ([Kubernetes][2])

Manual scaling is useful for:

```text id="n9s1mo"
planned events
one-time traffic increase
testing
emergency intervention
known scheduled workload
```

Autoscaling is useful for:

```text id="094i63"
unpredictable traffic
variable load
cost optimization
automatic recovery from demand spikes
baseline elasticity
```

Production rule:

```text id="5bjks0"
Use autoscaling for variable demand, but keep manual override knowledge.
```

---

# 5. HPA Mental Model

HPA means:

```text id="2fjid3"
Horizontal Pod Autoscaler
```

Question HPA asks:

```text id="7c2g8h"
Does this workload need more or fewer replicas?
```

HPA watches metrics and changes the number of replicas on a target workload that supports the scale subresource, such as a Deployment or StatefulSet. The Kubernetes autoscaling/v2 API describes HPA as a resource that automatically manages replica count based on metrics. ([Kubernetes][3])

Flow:

```text id="gz4qk4"
Deployment
  ↓
Pods running with resource requests
  ↓
metrics-server exposes CPU/memory usage
  ↓
HPA checks usage vs target
  ↓
HPA updates Deployment replicas
  ↓
Deployment creates/removes Pods
```

HPA does **not** directly create Pods.

It updates:

```text id="vdnmqf"
Deployment.spec.replicas
```

Then Deployment controller handles Pods.

---

# 6. Metrics Server Dependency

For CPU and memory HPA, Kubernetes needs resource metrics.

In local clusters, this usually means installing **metrics-server**. Kubernetes’ resource metrics pipeline exposes CPU and memory usage for nodes and Pods through the Metrics API, which is used by tools like `kubectl top` and autoscaling components. ([Kubernetes][4])

Check:

```bash id="xdh3km"
kubectl top nodes
kubectl top pods -n dev
```

If you see:

```text id="vxgjei"
Metrics API not available
```

install metrics-server:

```bash id="ufcukj"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For kind, patch metrics-server because kubelet certificates are usually self-signed:

```bash id="c5qgqw"
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

```bash id="uf27x1"
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s
```

Retry after a minute:

```bash id="aeky32"
kubectl top nodes
kubectl top pods -n dev
```

Important:

```text id="2n3fke"
If metrics-server is not working, CPU/memory HPA will not work correctly.
```

---

# 7. Create Notes

```bash id="biblx2"
nano 10.14-autoscaling-pdb-safe-scaling/notes/autoscaling-mental-model.md
```

Paste:

```markdown id="s9mri7"
# Kubernetes Autoscaling Mental Model

## Horizontal Scaling

Add or remove Pods.

Tool:

- HorizontalPodAutoscaler

## Vertical Scaling

Adjust CPU/memory requests and limits.

Tool:

- VerticalPodAutoscaler concept or controller

## Node Scaling

Add or remove cluster nodes.

Tool:

- Cluster Autoscaler or cloud node autoscaler

## Availability Protection

Protect minimum available Pods during voluntary disruptions.

Tool:

- PodDisruptionBudget

## Golden Rules

- HPA scales replicas.
- VPA adjusts resource sizing.
- Cluster Autoscaler scales nodes.
- PDB protects availability during voluntary disruptions.
- Autoscaling needs good metrics and sane resource requests.
```

---

# 8. Create HPA Demo Deployment

We will use the standard HPA demo image style: a small PHP/Apache app that can consume CPU under load.

Create:

```bash id="us6l9c"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-deployment.yaml
```

Paste:

```yaml id="d436n2"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-demo
  namespace: dev
  labels:
    app: hpa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hpa-demo
  template:
    metadata:
      labels:
        app: hpa-demo
    spec:
      containers:
        - name: app
          image: registry.k8s.io/hpa-example
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: "100m"
              memory: "64Mi"
            limits:
              cpu: "500m"
              memory: "128Mi"
```

Apply:

```bash id="diuzvw"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-deployment.yaml
```

Check:

```bash id="qw11b5"
kubectl rollout status deployment/hpa-demo -n dev
kubectl get pods -n dev -l app=hpa-demo
```

Important:

```text id="sxl7nl"
CPU-based HPA needs CPU requests.
Without CPU requests, utilization percentage has no reliable baseline.
```

---

# 9. Create HPA Demo Service

Create:

```bash id="nry83y"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-service.yaml
```

Paste:

```yaml id="m5q8a0"
apiVersion: v1
kind: Service
metadata:
  name: hpa-demo
  namespace: dev
  labels:
    app: hpa-demo
spec:
  type: ClusterIP
  selector:
    app: hpa-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="lgy365"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-service.yaml
```

Check:

```bash id="t4toz6"
kubectl get svc hpa-demo -n dev
kubectl get endpoints hpa-demo -n dev
```

---

# 10. Create CPU-Based HPA

Create:

```bash id="eagzks"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-cpu-hpa.yaml
```

Paste:

```yaml id="k9is18"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo
  namespace: dev
  labels:
    app: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Apply:

```bash id="o3encd"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-cpu-hpa.yaml
```

Check:

```bash id="vnrmpb"
kubectl get hpa -n dev
kubectl describe hpa hpa-demo -n dev
```

Meaning:

```text id="q3cgcw"
Keep average CPU utilization around 50% of requested CPU.
Minimum replicas: 1
Maximum replicas: 5
```

Kubernetes’ HPA walkthrough demonstrates CPU-based scaling with `kubectl autoscale` and a CPU utilization target; the HPA then adjusts replicas based on observed CPU usage. ([Kubernetes][5])

---

# 11. Generate Load

Run a load generator Pod:

```bash id="u2is79"
kubectl run hpa-load-generator \
  -n dev \
  --image=busybox:1.36 \
  --restart=Never \
  -- sh -c "while true; do wget -q -O- http://hpa-demo.dev.svc.cluster.local; done"
```

Watch HPA:

```bash id="3rd95b"
kubectl get hpa hpa-demo -n dev -w
```

In another terminal, watch Pods:

```bash id="oaj2kc"
kubectl get pods -n dev -l app=hpa-demo -w
```

You should eventually see replicas increase.

Exit watches:

```text id="32e3tu"
Ctrl + C
```

Check:

```bash id="1vvpji"
kubectl get deployment hpa-demo -n dev
kubectl get hpa hpa-demo -n dev
kubectl top pods -n dev
```

Stop load:

```bash id="agudks"
kubectl delete pod hpa-load-generator -n dev --ignore-not-found=true
```

After some time, HPA should scale down.

Important:

```text id="pyw83g"
Scale up and scale down are not instant.
HPA reacts with delay because metrics collection and stabilization take time.
```

Kubernetes HPA includes behavior around metric readiness and scaling decisions, including special handling for recently started Pods and not-yet-ready Pods when calculating CPU metrics. ([Kubernetes][1])

---

# 12. Memory-Based HPA

CPU is common, but memory-based HPA is also possible.

Create a separate HPA example manifest, but do **not** apply it together with the CPU HPA for the same target unless you intentionally want multiple metrics on the same HPA.

Create:

```bash id="u9x7s6"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-memory-hpa.yaml
```

Paste:

```yaml id="xexxgg"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo-memory
  namespace: dev
  labels:
    app: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

Memory HPA meaning:

```text id="u6rh66"
If average memory utilization crosses the target,
HPA can increase replicas.
```

Production warning:

```text id="5l4he3"
Memory scaling is trickier than CPU scaling.
Some runtimes hold memory even after traffic drops.
Memory does not always decrease quickly after adding replicas.
```

Use memory HPA when:

```text id="btkp39"
memory grows with request volume
each replica has predictable memory behavior
you understand runtime memory behavior
you have tested scale-down behavior
```

---

# 13. Multi-Metric HPA

You can use multiple metrics in one HPA.

Example:

```yaml id="fzomkm"
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75
```

Meaning:

```text id="3g06no"
HPA evaluates multiple metrics.
If one metric recommends more replicas than another,
HPA generally chooses the larger replica count.
```

Production use:

```text id="92losa"
CPU protects against compute pressure.
Memory protects against memory pressure.
Custom metrics protect against app-specific bottlenecks.
```

---

# 14. Custom Metrics Concept

HPA can scale on more than CPU and memory when custom metrics are available.

Examples:

```text id="e17s2r"
requests per second
queue depth
Kafka lag
SQS queue length
HTTP latency
active users
inference queue length
pending jobs
```

This usually needs extra components:

```text id="87a54u"
Prometheus Adapter
KEDA
cloud metrics adapter
custom metrics API
external metrics API
```

Production example:

```text id="r61b2b"
Worker queue length > threshold
  ↓
HPA/KEDA adds worker Pods
```

For APIs, CPU-based HPA is often a starting point.

For workers, queue-based autoscaling is often better.

---

# 15. HPA Debugging Commands

Use these:

```bash id="fpocnu"
kubectl get hpa -n dev
kubectl describe hpa hpa-demo -n dev

kubectl get deployment hpa-demo -n dev
kubectl describe deployment hpa-demo -n dev

kubectl get pods -n dev -l app=hpa-demo
kubectl top pods -n dev
kubectl top nodes

kubectl get events -n dev --sort-by=.lastTimestamp
```

Common symptoms:

```text id="o855k7"
TARGETS shows <unknown>:
  metrics-server not working
  Pod metrics not available
  missing resource requests

HPA does not scale:
  no load
  metrics below target
  maxReplicas already reached
  target deployment wrong

HPA scales too aggressively:
  target too low
  app has CPU spikes
  min/max poorly chosen

HPA scales down too soon:
  stabilization not tuned
  workload spiky
```

---

# 16. Create HPA Debugging Runbook

Create:

```bash id="oy5ap4"
nano 10.14-autoscaling-pdb-safe-scaling/runbooks/hpa-debugging-runbook.md
```

Paste:

````markdown id="brp8la"
# HPA Debugging Runbook

## Step 1 — Check Metrics Server

```bash
kubectl top nodes
kubectl top pods -n NAMESPACE
````

If metrics are unavailable, fix metrics-server first.

## Step 2 — Check HPA

```bash id="uhe8cs"
kubectl get hpa -n NAMESPACE
kubectl describe hpa HPA_NAME -n NAMESPACE
```

Look for:

* targets
* current metrics
* desired replicas
* events
* scale target

## Step 3 — Check Deployment

```bash id="lvfugg"
kubectl get deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

## Step 4 — Check Resource Requests

```bash id="o1dkr9"
kubectl get pod POD_NAME -n NAMESPACE -o yaml | grep -A10 resources
```

CPU utilization percentage requires CPU requests.

## Step 5 — Check Load

```bash id="m3fmun"
kubectl top pods -n NAMESPACE
```

No load means no scale-up.

## Common Problems

| Symptom            | Likely Cause                            |
| ------------------ | --------------------------------------- |
| TARGETS unknown    | metrics-server issue or missing metrics |
| no scale-up        | load below target                       |
| maxed replicas     | maxReplicas too low                     |
| frequent scaling   | target too sensitive                    |
| no CPU utilization | missing CPU requests                    |
| slow reaction      | metrics delay and HPA stabilization     |

## Golden Rule

HPA needs metrics, resource requests, and a realistic scaling signal.

````

---

# 17. VPA Concepts

VPA means:

```text id="r27dfa"
Vertical Pod Autoscaler
````

Question VPA asks:

```text id="a38uz2"
Should this Pod have different CPU/memory requests?
```

Vertical scaling means assigning more or fewer resources such as CPU or memory to already-running workload Pods, whereas horizontal scaling adds more Pods. Kubernetes documentation describes VPA as rightsizing Pod resources, distinct from HPA’s replica scaling. ([Kubernetes][6])

VPA can be used for:

```text id="h34rlm"
resource recommendation
automatic request adjustment
right-sizing workloads
reducing wasted resources
reducing OOM risk
```

VPA modes commonly discussed:

```text id="7lb28s"
Off:
  recommendations only

Initial:
  apply recommendations only when Pods are created

Auto:
  evict/recreate Pods to apply recommendations
```

Production warning:

```text id="76v6qu"
VPA can restart Pods when applying new resources.
Use carefully for availability-sensitive workloads.
```

---

# 18. HPA vs VPA

| Feature                              | HPA                       | VPA                         |
| ------------------------------------ | ------------------------- | --------------------------- |
| Scales                               | Number of Pods            | CPU/memory per Pod          |
| Main target                          | Replica count             | Requests/limits             |
| Best for                             | Variable traffic          | Rightsizing                 |
| Can add capacity quickly             | Yes, if nodes available   | Not usually                 |
| Can restart Pods                     | No direct restart usually | Often yes when applying     |
| Good for stateless APIs              | Yes                       | Recommendations useful      |
| Good for single-replica stateful app | Maybe not                 | Sometimes useful, carefully |

Important production rule:

```text id="l217c5"
Do not blindly use HPA and VPA on the same CPU/memory signal without understanding controller interaction.
```

Common approach:

```text id="qfmjwt"
Use VPA in recommendation mode.
Use HPA for runtime scaling.
Review VPA recommendations to tune requests.
```

---

# 19. VPA Example Manifest — Concept Only

Do not apply unless VPA is installed.

Create:

```bash id="tywg5w"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/vpa-demo-example.yaml
```

Paste:

```yaml id="8l1y37"
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: demo-node-api-vpa
  namespace: dev
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-node-api
  updatePolicy:
    updateMode: "Off"
```

Meaning:

```text id="546n0s"
Observe demo-node-api.
Recommend CPU/memory values.
Do not automatically update Pods.
```

Why `Off`?

```text id="5yve8p"
Safe recommendation-only mode.
Good for learning and production review.
```

---

# 20. Cluster Autoscaler Concepts

Cluster Autoscaler answers:

```text id="dmj0f2"
Do we need more or fewer nodes?
```

Node autoscaling dynamically provisions or consolidates nodes so that the cluster has enough capacity for workloads while optimizing cost. Kubernetes documentation describes node autoscaling as adding capacity when Pods cannot be scheduled and removing unneeded nodes when possible. ([Kubernetes][7])

Flow:

```text id="5m6zqb"
HPA adds more Pods
  ↓
Some Pods become Pending due to insufficient resources
  ↓
Cluster Autoscaler sees unschedulable Pods
  ↓
Adds nodes through cloud provider/node group
  ↓
Pending Pods get scheduled
```

Scale-down flow:

```text id="c5p7qq"
Node underutilized
  ↓
Pods can be moved safely
  ↓
PDBs and constraints allow disruption
  ↓
Cluster Autoscaler drains node
  ↓
Node removed
```

In kind:

```text id="b1xq40"
Real Cluster Autoscaler is not useful because kind nodes are Docker containers and not cloud autoscaling groups.
```

But the concept is essential for EKS/AKS/GKE.

---

# 21. Pending Pod Simulation for Node Scaling

Create a Deployment that requests too much CPU so it stays Pending.

```bash id="n3bu01"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/pending-scale-demo.yaml
```

Paste:

```yaml id="sxz2hc"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pending-scale-demo
  namespace: dev
  labels:
    app: pending-scale-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pending-scale-demo
  template:
    metadata:
      labels:
        app: pending-scale-demo
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

```bash id="fjtevz"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/pending-scale-demo.yaml
```

Check:

```bash id="516ivq"
kubectl get pods -n dev -l app=pending-scale-demo
kubectl describe pod -n dev -l app=pending-scale-demo
kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text id="1su740"
Pod remains Pending due to insufficient CPU/memory.
```

In cloud production with Cluster Autoscaler:

```text id="j9g0ru"
This kind of unschedulable Pod can trigger node scale-up if a node group can satisfy the request.
```

Clean:

```bash id="2q4w0e"
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/pending-scale-demo.yaml
```

---

# 22. PodDisruptionBudget Mental Model

PDB means:

```text id="ug633j"
PodDisruptionBudget
```

Question PDB answers:

```text id="j2gyb6"
How many Pods must remain available during voluntary disruptions?
```

A PDB limits how many Pods of a replicated application can be down simultaneously from voluntary disruptions. Kubernetes docs give examples such as maintaining quorum or ensuring a frontend keeps a percentage of replicas serving traffic. ([Kubernetes][8])

Voluntary disruptions include:

```text id="ntk08m"
node drain
cluster autoscaler scale-down
planned maintenance
upgrade operations
manual eviction
```

PDB does **not** protect against all disruptions.

It does not prevent:

```text id="0te2ki"
node crash
kernel panic
hardware failure
out-of-memory kill
involuntary failure
bad app crash
```

Production rule:

```text id="93maaa"
Use PDB to protect availability during planned/voluntary disruptions.
```

---

# 23. Create PDB Demo Deployment

Create:

```bash id="tey3qz"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-deployment.yaml
```

Paste:

```yaml id="t1e2n0"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdb-demo
  namespace: dev
  labels:
    app: pdb-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pdb-demo
  template:
    metadata:
      labels:
        app: pdb-demo
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 5
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
```

Apply:

```bash id="ysd8pi"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-deployment.yaml
```

Check:

```bash id="klf8tg"
kubectl rollout status deployment/pdb-demo -n dev
kubectl get pods -n dev -l app=pdb-demo -o wide
```

---

# 24. Create PDB

Create:

```bash id="lnp4qr"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-pdb.yaml
```

Paste:

```yaml id="fy4q7t"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-demo
  namespace: dev
  labels:
    app: pdb-demo
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: pdb-demo
```

Apply:

```bash id="s2rvpk"
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-pdb.yaml
```

Check:

```bash id="r5k231"
kubectl get pdb -n dev
kubectl describe pdb pdb-demo -n dev
```

Meaning:

```text id="am2e9p"
At least 2 pdb-demo Pods should remain available during voluntary disruption.
```

Kubernetes PDBs can define availability using `minAvailable` or disruption allowance using `maxUnavailable`, and the stable `policy/v1` PDB API defines max disruption rules for a selected set of Pods. ([Kubernetes][9])

---

# 25. PDB with maxUnavailable

Alternative style:

```yaml id="pul0ik"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: api
```

Meaning:

```text id="e5xoc0"
Allow at most 1 matching Pod to be voluntarily disrupted at a time.
```

For 3 replicas:

```text id="l1hkpa"
maxUnavailable: 1
```

is similar to:

```text id="rbcrmv"
minAvailable: 2
```

Production preference:

```text id="ul3olf"
For APIs, maxUnavailable: 1 is often easy to reason about.
For quorum systems, minAvailable may be clearer.
```

---

# 26. Safe Drain Demo — Optional

Be careful with `kubectl drain` in your local cluster. It can evict Pods and change lab state.

Dry-run style check:

```bash id="na0gkq"
kubectl get pods -n dev -l app=pdb-demo -o wide
kubectl get pdb pdb-demo -n dev
```

If you intentionally want to practice:

```bash id="utakvj"
kubectl drain devops-k8s-worker \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --dry-run=server
```

If you actually drain, later uncordon:

```bash id="1m8t34"
kubectl uncordon devops-k8s-worker
```

Production warning:

```text id="h7upuv"
Always understand PDBs before node drains or cluster upgrades.
```

---

# 27. Safe Scale Up

Safe scale-up checklist:

```text id="bbn0zd"
1. Metrics are reliable.
2. Requests and limits are set.
3. maxReplicas is realistic.
4. Cluster has enough node capacity.
5. Cluster Autoscaler can add nodes if needed.
6. Readiness probes protect traffic.
7. Startup probes protect slow-starting Pods.
8. Ingress/Service can handle new Pods.
9. App dependencies can handle more clients.
10. Dashboards and alerts exist.
```

Common scale-up problem:

```text id="hnoqu0"
HPA adds Pods,
but database cannot handle more connections.
```

So scaling Pods is not always enough.

You must check:

```text id="p8zgz4"
database pool size
cache capacity
rate limits
external API quotas
message broker capacity
node capacity
ingress capacity
```

---

# 28. Safe Scale Down

Scale down is riskier than people think.

Possible problems:

```text id="xznh7o"
in-flight requests dropped
queue workers killed mid-job
cache warm instances removed
too few replicas left
PDB blocks node maintenance
HPA scale-down happens too early
```

Safe scale-down needs:

```text id="8errmz"
readinessProbe
preStop hook
SIGTERM handling
terminationGracePeriodSeconds
PDB
reasonable HPA behavior
queue-safe workers
idempotent job processing
```

Production rule:

```text id="76xq7b"
Scale down must be graceful, not just fast.
```

---

# 29. HPA Behavior Policy Example

Autoscaling/v2 supports behavior tuning.

Example:

```yaml id="c1sfqo"
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies:
      - type: Percent
        value: 100
        periodSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300
    policies:
      - type: Percent
        value: 50
        periodSeconds: 60
```

Meaning:

```text id="vqgdl3"
Scale up quickly.
Scale down more slowly.
```

Why?

```text id="35ibds"
Fast scale-up protects users.
Slow scale-down avoids flapping.
```

---

# 30. Create Tuned HPA Example

Create:

```bash id="ar4e6d"
nano 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-tuned-hpa.yaml
```

Paste:

```yaml id="2y68m2"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-demo-tuned
  namespace: dev
  labels:
    app: hpa-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-demo
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
      selectPolicy: Max
```

Do not apply this together with the existing `hpa-demo` HPA unless you delete the first HPA. A workload should not have multiple HPAs fighting over the same scale target.

To test this one:

```bash id="83b3xo"
kubectl delete hpa hpa-demo -n dev --ignore-not-found=true
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-tuned-hpa.yaml
```

---

# 31. Autoscaling Failure Modes

Common failure modes:

```text id="ph5q7z"
metrics-server unavailable
missing CPU requests
bad HPA target
maxReplicas too low
minReplicas too low
app has slow startup
no startupProbe
readiness never becomes true
database becomes bottleneck
cluster lacks capacity
Cluster Autoscaler cannot add nodes
PDB too strict
Pod anti-affinity too strict
resource requests too high
scale-down too aggressive
CPU metric not correlated with real load
memory metric does not drop after traffic drops
```

Production diagnosis principle:

```text id="p9q8z0"
Autoscaling incidents are usually metric + capacity + application behavior problems.
```

---

# 32. Production Autoscaling Policy for demo-node-api

Now create a production-style HPA for your `demo-node-api`.

Create:

```bash id="v886e6"
nano apps/demo-node-api/base/hpa.yaml
```

Paste:

```yaml id="03n45d"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-node-api
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 60
        - type: Pods
          value: 2
          periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
      selectPolicy: Max
```

Create PDB:

```bash id="bspsf3"
nano apps/demo-node-api/base/pdb.yaml
```

Paste:

```yaml id="x03ov1"
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
```

Update base kustomization:

```bash id="f8l8pi"
nano apps/demo-node-api/base/kustomization.yaml
```

Ensure it includes:

```yaml id="500fkh"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
```

Production note:

```text id="zim4tg"
HPA minReplicas and PDB minAvailable must work together.
Do not set PDB so strict that cluster maintenance becomes impossible.
```

---

# 33. demo-node-api Autoscaling Policy Note

Create:

```bash id="e91xk1"
nano 10.14-autoscaling-pdb-safe-scaling/notes/demo-node-api-autoscaling-policy.md
```

Paste:

````markdown id="v48nq7"
# demo-node-api Autoscaling Policy

## Workload

demo-node-api

## Scaling Type

HorizontalPodAutoscaler

## Initial Policy

```yaml
minReplicas: 2
maxReplicas: 6
cpu target: 60%
````

## Scale-Up Behavior

* scale up quickly
* allow up to 100% increase per minute
* allow up to 2 Pods per minute

## Scale-Down Behavior

* scale down slowly
* 5-minute stabilization window
* remove at most 50% per minute

## Availability Protection

Use PodDisruptionBudget:

```yaml
minAvailable: 1
```

## Requirements

* CPU requests must be set.
* metrics-server or metrics pipeline must work.
* readinessProbe must be reliable.
* startupProbe should protect slow starts.
* preStop and SIGTERM handling should protect scale-down.

## Future Improvements

* Add request-rate custom metric.
* Add latency SLO based scaling if needed.
* Add queue-depth scaling for workers.
* Review maxReplicas after load testing.
* Coordinate with database connection pool limits.

````

---

# 34. Autoscaling Runbook

Create:

```bash id="r6hirf"
nano 10.14-autoscaling-pdb-safe-scaling/runbooks/autoscaling-runbook.md
````

Paste:

````markdown id="k7ofr7"
# Kubernetes Autoscaling Runbook

## Check HPA

```bash
kubectl get hpa -n NAMESPACE
kubectl describe hpa HPA_NAME -n NAMESPACE
````

## Check Metrics

```bash
kubectl top nodes
kubectl top pods -n NAMESPACE
```

## Check Deployment

```bash
kubectl get deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

## Check Pods

```bash
kubectl get pods -n NAMESPACE -l app=APP -o wide
kubectl describe pod POD_NAME -n NAMESPACE
```

## Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Common Problems

| Symptom                      | Likely Cause                               |
| ---------------------------- | ------------------------------------------ |
| HPA targets unknown          | metrics-server problem                     |
| no scale-up                  | load below target                          |
| no scale-down                | stabilization window or metrics still high |
| Pods Pending                 | no node capacity                           |
| Pods not Ready               | readiness/startup problem                  |
| max replicas reached         | maxReplicas too low                        |
| app still slow after scaling | database or downstream bottleneck          |

## Golden Rule

Autoscaling needs metrics, capacity, readiness, and downstream dependency awareness.

````

---

# 35. PDB Runbook

Create:

```bash id="slrkfo"
nano 10.14-autoscaling-pdb-safe-scaling/runbooks/pdb-runbook.md
````

Paste:

````markdown id="03pv4o"
# PodDisruptionBudget Runbook

## Purpose

Protect minimum application availability during voluntary disruptions.

## Check PDB

```bash
kubectl get pdb -n NAMESPACE
kubectl describe pdb PDB_NAME -n NAMESPACE
````

## Example

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: api
```

## Voluntary Disruptions

* node drain
* cluster upgrade
* autoscaler node removal
* manual eviction

## Not Protected

* node crash
* app crash
* kernel panic
* OOMKilled
* hardware failure

## Common Problems

| Symptom                         | Likely Cause                         |
| ------------------------------- | ------------------------------------ |
| node drain blocked              | PDB too strict                       |
| eviction blocked                | not enough available replicas        |
| PDB shows 0 allowed disruptions | replicas too low or Pods not Ready   |
| maintenance stuck               | PDB conflicts with cluster operation |

## Golden Rule

PDB protects availability, but if too strict, it can block maintenance.

````

---

# 36. Cluster Autoscaler Runbook

Create:

```bash id="byi1l7"
nano 10.14-autoscaling-pdb-safe-scaling/runbooks/cluster-autoscaler-concepts.md
````

Paste:

````markdown id="hdnwo4"
# Cluster Autoscaler Concepts

## Purpose

Scale cluster nodes up and down based on schedulability and utilization.

## Scale Up

Triggered when Pods are Pending because no existing node can schedule them.

Common reasons:

- insufficient CPU
- insufficient memory
- node affinity requires a node group
- taints require matching tolerations
- topology spread needs more domains

## Scale Down

Possible when a node is underutilized and Pods can be safely moved elsewhere.

Blocked by:

- strict PDB
- local storage
- hard anti-affinity
- insufficient capacity elsewhere
- special annotations
- system workloads

## Debug

```bash
kubectl get pods -A | grep Pending
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -A --sort-by=.lastTimestamp
kubectl get nodes
kubectl describe node NODE_NAME
````

## Cloud Production

EKS/GKE/AKS node autoscaling depends on node groups, autoscaling groups, and cloud provider integration.

## Golden Rule

HPA adds Pods.
Cluster Autoscaler adds Nodes when Pods cannot fit.

````

---

# 37. Autoscaling Summary Script

Create:

```bash id="z1y6m0"
nano 10.14-autoscaling-pdb-safe-scaling/scripts/autoscaling-summary.sh
````

Paste:

```bash id="j22fpl"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Kubernetes Autoscaling Summary ====="

echo
echo "Namespace: $NAMESPACE"

echo
echo "HPA:"
kubectl get hpa -n "$NAMESPACE" || true

echo
echo "PDB:"
kubectl get pdb -n "$NAMESPACE" || true

echo
echo "Deployments:"
kubectl get deployments -n "$NAMESPACE"

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide

echo
echo "Metrics:"
kubectl top pods -n "$NAMESPACE" || true

echo
echo "Nodes:"
kubectl get nodes

echo
echo "Node metrics:"
kubectl top nodes || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30
```

Make executable:

```bash id="9yxb3x"
chmod +x 10.14-autoscaling-pdb-safe-scaling/scripts/autoscaling-summary.sh
```

Run:

```bash id="3tj6pq"
./10.14-autoscaling-pdb-safe-scaling/scripts/autoscaling-summary.sh
```

---

# 38. Validation Script

Create:

```bash id="uylnvr"
nano 10.14-autoscaling-pdb-safe-scaling/scripts/validate-lesson-10-14.sh
```

Paste:

```bash id="udhswo"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.14 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get deployment metrics-server -n kube-system >/dev/null
kubectl get deployment hpa-demo -n dev >/dev/null
kubectl get service hpa-demo -n dev >/dev/null

kubectl rollout status deployment/hpa-demo -n dev --timeout=120s >/dev/null

if kubectl get hpa hpa-demo -n dev >/dev/null 2>&1; then
  HPA_NAME="hpa-demo"
elif kubectl get hpa hpa-demo-tuned -n dev >/dev/null 2>&1; then
  HPA_NAME="hpa-demo-tuned"
else
  echo "ERROR: expected hpa-demo or hpa-demo-tuned HPA"
  exit 1
fi

kubectl get hpa "$HPA_NAME" -n dev >/dev/null

MIN_REPLICAS="$(kubectl get hpa "$HPA_NAME" -n dev -o jsonpath='{.spec.minReplicas}')"
MAX_REPLICAS="$(kubectl get hpa "$HPA_NAME" -n dev -o jsonpath='{.spec.maxReplicas}')"

if [ -z "$MIN_REPLICAS" ] || [ -z "$MAX_REPLICAS" ]; then
  echo "ERROR: HPA min/max replicas not found"
  exit 1
fi

kubectl get deployment pdb-demo -n dev >/dev/null
kubectl get pdb pdb-demo -n dev >/dev/null
kubectl rollout status deployment/pdb-demo -n dev --timeout=120s >/dev/null

PDB_MIN_AVAILABLE="$(kubectl get pdb pdb-demo -n dev -o jsonpath='{.spec.minAvailable}')"
if [ "$PDB_MIN_AVAILABLE" != "2" ]; then
  echo "ERROR: pdb-demo minAvailable should be 2"
  exit 1
fi

test -x 10.14-autoscaling-pdb-safe-scaling/scripts/autoscaling-summary.sh

test -f 10.14-autoscaling-pdb-safe-scaling/notes/autoscaling-mental-model.md
test -f 10.14-autoscaling-pdb-safe-scaling/notes/demo-node-api-autoscaling-policy.md
test -f 10.14-autoscaling-pdb-safe-scaling/runbooks/hpa-debugging-runbook.md
test -f 10.14-autoscaling-pdb-safe-scaling/runbooks/autoscaling-runbook.md
test -f 10.14-autoscaling-pdb-safe-scaling/runbooks/pdb-runbook.md
test -f 10.14-autoscaling-pdb-safe-scaling/runbooks/cluster-autoscaler-concepts.md

test -f apps/demo-node-api/base/hpa.yaml
test -f apps/demo-node-api/base/pdb.yaml
grep -q "hpa.yaml" apps/demo-node-api/base/kustomization.yaml
grep -q "pdb.yaml" apps/demo-node-api/base/kustomization.yaml

kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-autoscaling-rendered.yaml
grep -q "kind: HorizontalPodAutoscaler" /tmp/demo-node-api-autoscaling-rendered.yaml
grep -q "kind: PodDisruptionBudget" /tmp/demo-node-api-autoscaling-rendered.yaml

echo "HPA used: $HPA_NAME"
echo "HPA minReplicas: $MIN_REPLICAS"
echo "HPA maxReplicas: $MAX_REPLICAS"
echo "PDB minAvailable: $PDB_MIN_AVAILABLE"
echo "Lesson 10.14 validation passed."
```

Make executable:

```bash id="ma0txw"
chmod +x 10.14-autoscaling-pdb-safe-scaling/scripts/validate-lesson-10-14.sh
```

Run:

```bash id="syu26b"
./10.14-autoscaling-pdb-safe-scaling/scripts/validate-lesson-10-14.sh
```

---

# 39. Cleanup Script

Create:

```bash id="jbmnk3"
nano 10.14-autoscaling-pdb-safe-scaling/scripts/cleanup-lesson-10-14.sh
```

Paste:

```bash id="k8dzr2"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.14 ====="

kubectl delete pod hpa-load-generator -n dev --ignore-not-found=true

kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/pending-scale-demo.yaml --ignore-not-found=true

kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-tuned-hpa.yaml --ignore-not-found=true
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-cpu-hpa.yaml --ignore-not-found=true
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-memory-hpa.yaml --ignore-not-found=true
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-service.yaml --ignore-not-found=true
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-deployment.yaml --ignore-not-found=true

kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-pdb.yaml --ignore-not-found=true
kubectl delete -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-deployment.yaml --ignore-not-found=true

echo "Lesson 10.14 live demo resources cleaned."
echo "metrics-server is kept because it is useful for future lessons."
```

Make executable:

```bash id="krysp4"
chmod +x 10.14-autoscaling-pdb-safe-scaling/scripts/cleanup-lesson-10-14.sh
```

Run only if you want cleanup:

```bash id="nse7a5"
./10.14-autoscaling-pdb-safe-scaling/scripts/cleanup-lesson-10-14.sh
```

To remove metrics-server too:

```bash id="zlfnq3"
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For upcoming lessons, keep metrics-server installed.

---

# 40. Practical Lab Summary

Run main lab:

```bash id="towsf8"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/containers/0/args/-",
      "value": "--kubelet-insecure-tls"
    }
  ]' || true

kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-deployment.yaml
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-service.yaml
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/hpa-demo-cpu-hpa.yaml

kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-deployment.yaml
kubectl apply -f 10.14-autoscaling-pdb-safe-scaling/manifests/pdb-demo-pdb.yaml

./10.14-autoscaling-pdb-safe-scaling/scripts/autoscaling-summary.sh
./10.14-autoscaling-pdb-safe-scaling/scripts/validate-lesson-10-14.sh
```

Generate HPA load:

```bash id="xl8mn7"
kubectl run hpa-load-generator \
  -n dev \
  --image=busybox:1.36 \
  --restart=Never \
  -- sh -c "while true; do wget -q -O- http://hpa-demo.dev.svc.cluster.local; done"

kubectl get hpa hpa-demo -n dev -w
```

Stop load:

```bash id="9h1l7j"
kubectl delete pod hpa-load-generator -n dev --ignore-not-found=true
```

---

# 41. Common Myths and Misconceptions

## Myth 1: HPA creates Pods directly

Wrong.

```text id="wh3qhr"
HPA updates replica count.
Deployment creates/removes Pods.
```

---

## Myth 2: HPA works without metrics

Wrong.

```text id="mp3yhq"
CPU/memory HPA needs resource metrics.
metrics-server must work.
```

---

## Myth 3: CPU target means 50% of node CPU

Wrong.

```text id="9gt399"
CPU utilization target is based on Pod CPU request, not whole node CPU.
```

Example:

```text id="ipcx9g"
request: 100m
target: 50%

Target average usage:
  50m CPU per Pod
```

---

## Myth 4: HPA solves all performance problems

Wrong.

```text id="8akp7d"
If database is the bottleneck,
adding more API Pods may make the incident worse.
```

---

## Myth 5: VPA is always better than HPA

Wrong.

```text id="4nfply"
HPA handles variable traffic.
VPA helps right-size resource requests.
They solve different problems.
```

---

## Myth 6: Cluster Autoscaler scales because CPU is high

Not directly.

```text id="igohmg"
Cluster Autoscaler usually reacts to unschedulable Pods,
not simply high node CPU.
```

---

## Myth 7: PDB prevents all downtime

Wrong.

```text id="6x9i02"
PDB helps with voluntary disruptions.
It cannot prevent sudden node crashes or app failures.
```

---

# 42. Production Rules

```text id="5esp51"
Set CPU and memory requests before using HPA.
Install and monitor metrics-server or metrics pipeline.
Use minReplicas greater than 1 for production APIs.
Set realistic maxReplicas.
Scale up faster than scale down.
Use readiness probes so new Pods receive traffic only when ready.
Use startup probes for slow-starting workloads.
Use preStop and graceful shutdown for scale-down.
Use PDBs for production replicated workloads.
Do not make PDB too strict.
Coordinate HPA with database and downstream capacity.
Use VPA recommendation mode for right-sizing.
Use Cluster Autoscaler for node elasticity in cloud clusters.
Test autoscaling before trusting it in production.
```

---

# 43. Interview Explanation

Use this:

```text id="tgx2fn"
Kubernetes autoscaling has multiple layers. HPA scales horizontally by adjusting the replica count of a workload such as a Deployment based on metrics like CPU or memory. VPA focuses on vertical scaling by recommending or adjusting CPU and memory requests for Pods. Cluster Autoscaler works at the node level and can add nodes when Pods are unschedulable due to insufficient capacity.

For production, autoscaling requires reliable metrics, correct resource requests, readiness probes, startup probes, graceful shutdown, and downstream capacity awareness. I also use PodDisruptionBudgets to protect availability during voluntary disruptions such as node drains or cluster upgrades.
```

Resume version:

```text id="1a21de"
Implemented Kubernetes autoscaling labs with metrics-server, CPU-based HPA, load generation, HPA behavior tuning, VPA concepts, Cluster Autoscaler concepts, PodDisruptionBudgets, safe scaling runbooks, and production autoscaling policy for demo-node-api.
```

---

# 44. Today’s Core Rules

```text id="5dj9a2"
HPA scales Pods horizontally.
VPA adjusts resource sizing vertically.
Cluster Autoscaler scales nodes.
PDB protects availability during voluntary disruptions.
HPA needs metrics.
CPU HPA needs CPU requests.
Scaling is not instant.
Scale-up should protect users.
Scale-down should be graceful.
PDB does not protect against involuntary failures.
Custom metrics are often better for workers.
Cluster Autoscaler reacts to unschedulable Pods.
Autoscaling must consider downstream dependencies.
```

---

# 45. Commit Lesson 10.14

From repo root:

```bash id="qpj3tx"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes autoscaling PDB and safe scaling lesson"

git push
```

---

# Next Lesson

```text id="7lgzqp"
Lesson 10.15 — Kubernetes Observability: Events, Logs, Metrics, Prometheus, Grafana, Loki, and Production Debugging
```

We will cover:

```text id="mrjkkb"
kubectl events
application logs
previous container logs
structured logs
metrics-server vs Prometheus
Prometheus mental model
Grafana dashboards
Loki log aggregation
basic kube-state-metrics concept
golden signals
RED metrics
USE metrics
production observability workflow for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/?utm_source=chatgpt.com "Horizontal Pod Autoscaling"
[2]: https://kubernetes.io/docs/tasks/run-application/scale-deployment/?utm_source=chatgpt.com "Horizontal Manual Scaling for a Deployment"
[3]: https://kubernetes.io/docs/reference/kubernetes-api/autoscaling/horizontal-pod-autoscaler-v2/?utm_source=chatgpt.com "HorizontalPodAutoscaler"
[4]: https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/?utm_source=chatgpt.com "Resource metrics pipeline"
[5]: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/?utm_source=chatgpt.com "HorizontalPodAutoscaler Walkthrough"
[6]: https://kubernetes.io/docs/concepts/workloads/autoscaling/vertical-pod-autoscale/?utm_source=chatgpt.com "Vertical Pod Autoscaling"
[7]: https://kubernetes.io/docs/concepts/cluster-administration/node-autoscaling/?utm_source=chatgpt.com "Node Autoscaling"
[8]: https://kubernetes.io/docs/concepts/workloads/pods/disruptions/?utm_source=chatgpt.com "Disruptions"
[9]: https://kubernetes.io/docs/reference/kubernetes-api/policy/pod-disruption-budget-v1/?utm_source=chatgpt.com "PodDisruptionBudget"
