# Lesson 10.10 — Nodes, Taints, Tolerations, Affinity, Anti-Affinity, Topology Spread, and Workload Placement

In Lesson 10.9, you learned how Kubernetes handles **CPU, memory, requests, limits, QoS, and capacity planning**.

Now we learn how Kubernetes decides **where Pods should run**.

This is called **workload placement** or **scheduling control**.

By default, the Kubernetes scheduler chooses a suitable node based on available resources and constraints. But in production, DevOps engineers often need more control using node labels, `nodeSelector`, node affinity, pod affinity, pod anti-affinity, taints, tolerations, and topology spread constraints. Kubernetes officially documents these features under Pod-to-node assignment and scheduling controls. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="jm3c1s"
10.10.1   Scheduling mental model
10.10.2   Nodes and node labels
10.10.3   nodeSelector
10.10.4   Node affinity
10.10.5   requiredDuringSchedulingIgnoredDuringExecution
10.10.6   preferredDuringSchedulingIgnoredDuringExecution
10.10.7   Pod affinity
10.10.8   Pod anti-affinity
10.10.9   Taints
10.10.10  Tolerations
10.10.11  NoSchedule
10.10.12  PreferNoSchedule
10.10.13  NoExecute
10.10.14  Topology spread constraints
10.10.15  Zone-aware placement
10.10.16  Dedicated node pattern
10.10.17  System vs application workload placement
10.10.18  Production placement strategy for demo-node-api
10.10.19  Validation script
10.10.20  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="wmd0ux"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.10-workload-placement-scheduling/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="a2wwfu"
tree -L 2 10.10-workload-placement-scheduling
```

---

# 3. Scheduling Mental Model

When you create a Pod, Kubernetes must answer:

```text id="fa3byu"
Which node should this Pod run on?
```

The scheduler checks many things:

```text id="k15q2w"
resource requests
node capacity
node labels
nodeSelector
node affinity
pod affinity
pod anti-affinity
taints and tolerations
topology spread constraints
volume constraints
node readiness
ports
policies
```

Simple flow:

```text id="vmig4p"
Pod created
  ↓
Pod is Pending
  ↓
Scheduler evaluates nodes
  ↓
Scheduler chooses a node
  ↓
kubelet on that node starts the Pod
  ↓
Pod becomes Running
```

Important:

```text id="5lvkst"
Scheduling happens before the Pod runs.
```

If the scheduler cannot find a valid node, the Pod remains:

```text id="xkqx1y"
Pending
```

You debug it with:

```bash id="dwpzmk"
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

---

# 4. Node Labels

Node labels are key-value pairs attached to nodes. Kubernetes nodes come with standard labels, and you can also add your own labels to nodes using the Kubernetes API or `kubectl label`. Labels are used by placement features such as `nodeSelector`, node affinity, pod affinity topology keys, and topology spread constraints. ([Kubernetes][2])

Check your nodes:

```bash id="petu41"
kubectl get nodes
kubectl get nodes --show-labels
```

Cleaner view:

```bash id="lme5nh"
kubectl get nodes \
  -L node-role \
  -L workload \
  -L topology.kubernetes.io/zone
```

In your kind cluster from Lesson 10.2, you may already have labels like:

```text id="3afw5n"
node-role=app
workload=stateless

node-role=platform
workload=system
```

But we will label nodes manually to make the lesson reproducible.

---

# 5. Label the kind Nodes

Check node names:

```bash id="3npt5s"
kubectl get nodes
```

Expected kind node names:

```text id="ab8e96"
devops-k8s-control-plane
devops-k8s-worker
devops-k8s-worker2
```

Apply labels:

```bash id="ohq6g9"
kubectl label node devops-k8s-worker \
  node-role=app \
  workload=stateless \
  topology.kubernetes.io/zone=zone-a \
  placement-demo=enabled \
  --overwrite

kubectl label node devops-k8s-worker2 \
  node-role=platform \
  workload=system \
  topology.kubernetes.io/zone=zone-b \
  placement-demo=enabled \
  --overwrite
```

Check:

```bash id="xrxu21"
kubectl get nodes \
  -L node-role \
  -L workload \
  -L topology.kubernetes.io/zone \
  -L placement-demo
```

Expected:

```text id="nksv3d"
devops-k8s-worker    node-role=app       workload=stateless   zone-a
devops-k8s-worker2   node-role=platform  workload=system      zone-b
```

---

# 6. Create Notes

```bash id="clshav"
nano 10.10-workload-placement-scheduling/notes/workload-placement-mental-model.md
```

Paste:

```markdown id="wnxw32"
# Kubernetes Workload Placement Mental Model

## Core Question

Where should this Pod run?

## Scheduling Controls

- nodeSelector
- node affinity
- pod affinity
- pod anti-affinity
- taints
- tolerations
- topology spread constraints

## Simple Meanings

nodeSelector:
  hard match on node labels

node affinity:
  advanced node label rules

pod affinity:
  place this Pod near other Pods

pod anti-affinity:
  keep this Pod away from other Pods

taint:
  node repels Pods

toleration:
  Pod is allowed to tolerate a taint

topology spread:
  spread Pods across zones, nodes, or other topology domains

## Golden Rule

Use the weakest rule that safely achieves the placement goal.
Hard rules can create Pending Pods.
```

---

# 7. nodeSelector

`nodeSelector` is the simplest way to force a Pod onto nodes with specific labels.

If a Pod has:

```yaml id="xvl4vz"
nodeSelector:
  node-role: app
```

then it can only run on nodes with:

```text id="cqx3vb"
node-role=app
```

Kubernetes documentation shows assigning Pods to nodes using labels and `nodeSelector`; the Pod is only eligible for nodes that match the selector. ([Kubernetes][3])

## Create nodeSelector Deployment

Create:

```bash id="xs57bf"
nano 10.10-workload-placement-scheduling/manifests/nodeselector-app-deployment.yaml
```

Paste:

```yaml id="qbnwdh"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeselector-app
  namespace: dev
  labels:
    app: nodeselector-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeselector-app
  template:
    metadata:
      labels:
        app: nodeselector-app
    spec:
      nodeSelector:
        node-role: app
      containers:
        - name: app
          image: nginx:1.27-alpine
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

```bash id="t1buwd"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/nodeselector-app-deployment.yaml
```

Check:

```bash id="yy2ym1"
kubectl get pods -n dev -l app=nodeselector-app -o wide
```

Expected:

```text id="5m33q3"
Pods should run on devops-k8s-worker.
```

Why?

```text id="gtwrfn"
devops-k8s-worker has node-role=app.
```

---

# 8. nodeSelector Failure Demo

Create a Deployment that asks for a node label that does not exist.

```bash id="xrdb9w"
nano 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml
```

Paste:

```yaml id="c3yylr"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeselector-pending
  namespace: dev
  labels:
    app: nodeselector-pending
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nodeselector-pending
  template:
    metadata:
      labels:
        app: nodeselector-pending
    spec:
      nodeSelector:
        node-role: gpu
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

```bash id="tmktl4"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml
```

Check:

```bash id="wr0x29"
kubectl get pods -n dev -l app=nodeselector-pending
kubectl describe pod -n dev -l app=nodeselector-pending
kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text id="931ejg"
Pod stays Pending.
Events mention node selector or affinity mismatch.
```

Delete:

```bash id="eb5qs5"
kubectl delete -f 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml
```

Lesson:

```text id="1lej58"
Hard placement rules can make Pods unschedulable.
```

---

# 9. Node Affinity

Node affinity is like an advanced version of `nodeSelector`. It lets you use operators such as `In`, `NotIn`, `Exists`, and `DoesNotExist`, and it supports both hard and soft preferences. Kubernetes docs describe node affinity as conceptually similar to `nodeSelector`, but more expressive. ([Kubernetes][1])

Types:

```text id="d62b14"
requiredDuringSchedulingIgnoredDuringExecution:
  hard requirement

preferredDuringSchedulingIgnoredDuringExecution:
  soft preference
```

Meaning:

```text id="ym9g95"
required:
  Pod cannot schedule unless rule matches

preferred:
  Scheduler tries to honor it, but can place elsewhere if needed
```

Important phrase:

```text id="wppj7d"
IgnoredDuringExecution
```

Meaning:

```text id="c6zz4c"
If node labels change after the Pod is already running,
the Pod is not automatically evicted only because affinity no longer matches.
```

---

# 10. Required Node Affinity

Create:

```bash id="a2plya"
nano 10.10-workload-placement-scheduling/manifests/required-node-affinity-deployment.yaml
```

Paste:

```yaml id="y9dy6i"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: required-node-affinity
  namespace: dev
  labels:
    app: required-node-affinity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: required-node-affinity
  template:
    metadata:
      labels:
        app: required-node-affinity
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: workload
                    operator: In
                    values:
                      - stateless
      containers:
        - name: app
          image: nginx:1.27-alpine
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

```bash id="9u9zsw"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/required-node-affinity-deployment.yaml
```

Check:

```bash id="r05vqy"
kubectl get pods -n dev -l app=required-node-affinity -o wide
```

Expected:

```text id="mbttqd"
Pods should run on the node with workload=stateless.
```

---

# 11. Preferred Node Affinity

Preferred affinity means:

```text id="74jnx9"
I prefer this node type, but do not block scheduling if unavailable.
```

Create:

```bash id="re9vam"
nano 10.10-workload-placement-scheduling/manifests/preferred-node-affinity-deployment.yaml
```

Paste:

```yaml id="yf3n6g"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: preferred-node-affinity
  namespace: dev
  labels:
    app: preferred-node-affinity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: preferred-node-affinity
  template:
    metadata:
      labels:
        app: preferred-node-affinity
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-role
                    operator: In
                    values:
                      - app
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

```bash id="e3cd2q"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/preferred-node-affinity-deployment.yaml
```

Check:

```bash id="uib8uh"
kubectl get pods -n dev -l app=preferred-node-affinity -o wide
```

Expected:

```text id="xgojhm"
Scheduler should prefer the node with node-role=app, but this is not a hard rule.
```

Production rule:

```text id="0iqad2"
Use preferred rules when availability is more important than strict placement.
Use required rules only when placement is mandatory.
```

---

# 12. Pod Affinity

Pod affinity says:

```text id="rhubku"
Schedule this Pod near other Pods matching these labels.
```

Example use cases:

```text id="ni8q91"
place app close to cache
place worker near message broker
place side workload near related service
reduce network latency between tightly coupled workloads
```

Kubernetes inter-pod affinity lets you constrain scheduling based on labels of Pods already running in a topology domain such as a node, zone, or region. The docs also warn that inter-pod affinity and anti-affinity can require significant scheduler processing in very large clusters. ([Kubernetes][1])

Create an anchor Deployment first:

```bash id="epbovt"
nano 10.10-workload-placement-scheduling/manifests/cache-anchor-deployment.yaml
```

Paste:

```yaml id="8gs6z6"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-anchor
  namespace: dev
  labels:
    app: cache-anchor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-anchor
  template:
    metadata:
      labels:
        app: cache-anchor
        role: cache
    spec:
      nodeSelector:
        node-role: app
      containers:
        - name: cache
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

```bash id="aryhyi"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/cache-anchor-deployment.yaml
kubectl rollout status deployment/cache-anchor -n dev
kubectl get pods -n dev -l app=cache-anchor -o wide
```

Now create a Pod-affinity workload:

```bash id="58rvo6"
nano 10.10-workload-placement-scheduling/manifests/pod-affinity-deployment.yaml
```

Paste:

```yaml id="6px9iz"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-affinity-demo
  namespace: dev
  labels:
    app: pod-affinity-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pod-affinity-demo
  template:
    metadata:
      labels:
        app: pod-affinity-demo
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  role: cache
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

```bash id="v82q6a"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/pod-affinity-deployment.yaml
kubectl get pods -n dev -l app=pod-affinity-demo -o wide
```

Expected:

```text id="q71jx2"
pod-affinity-demo should run on the same node as cache-anchor.
```

Because:

```text id="r17eva"
topologyKey: kubernetes.io/hostname
```

means:

```text id="u7v4e8"
same node hostname
```

---

# 13. Pod Anti-Affinity

Pod anti-affinity says:

```text id="enfxna"
Do not schedule this Pod near other Pods matching these labels.
```

Use cases:

```text id="3bvini"
spread replicas across nodes
avoid single-node failure impact
avoid noisy-neighbor placement
separate primary and replica workloads
separate same-service replicas for high availability
```

Create:

```bash id="y54i84"
nano 10.10-workload-placement-scheduling/manifests/pod-anti-affinity-deployment.yaml
```

Paste:

```yaml id="i7hnqd"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-anti-affinity-demo
  namespace: dev
  labels:
    app: pod-anti-affinity-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pod-anti-affinity-demo
  template:
    metadata:
      labels:
        app: pod-anti-affinity-demo
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: pod-anti-affinity-demo
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

```bash id="k1r2da"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/pod-anti-affinity-deployment.yaml
```

Check:

```bash id="wcx4qp"
kubectl get pods -n dev -l app=pod-anti-affinity-demo -o wide
```

Expected:

```text id="njjp8x"
The two replicas should land on different nodes if possible.
```

Important:

```text id="n061w6"
If you request more replicas than eligible topology domains,
hard anti-affinity can make extra Pods Pending.
```

For example, if you have only two eligible worker nodes and ask for three replicas with required anti-affinity by hostname, the third may stay Pending.

---

# 14. Taints and Tolerations

Taints and tolerations are the opposite side of placement control.

Simple meaning:

```text id="5m6tmh"
taint:
  node repels Pods

toleration:
  Pod is allowed to tolerate that taint
```

Kubernetes docs state that taints are applied to nodes and tolerations are applied to Pods. A taint marks that the node should not accept Pods that do not tolerate it, while a toleration allows scheduling onto matching tainted nodes but does not guarantee placement there. ([Kubernetes][4])

---

# 15. Taint Effects

Taint effects:

```text id="hz6v64"
NoSchedule
PreferNoSchedule
NoExecute
```

Meaning:

```text id="ouws04"
NoSchedule:
  Do not schedule new Pods unless they tolerate the taint.

PreferNoSchedule:
  Try to avoid scheduling Pods that do not tolerate the taint, but not guaranteed.

NoExecute:
  Evict already-running Pods that do not tolerate the taint and prevent new ones from scheduling.
```

The official `kubectl taint` documentation defines taints as `key=value:effect`, where the effect must be `NoSchedule`, `PreferNoSchedule`, or `NoExecute`. ([Kubernetes][5])

Important production warning:

```text id="1o0t7i"
Be careful with NoExecute.
It can evict already-running workloads.
```

For this lab, we will use:

```text id="s8cvm2"
NoSchedule
```

because it is safer.

---

# 16. Taint the Platform Node

We will taint the platform node so normal application Pods do not schedule there unless they tolerate it.

Run:

```bash id="rmi53j"
kubectl taint nodes devops-k8s-worker2 \
  dedicated=platform:NoSchedule \
  --overwrite
```

Check:

```bash id="g4tbhc"
kubectl describe node devops-k8s-worker2 | grep -i taints -A3
```

Expected:

```text id="qpork5"
dedicated=platform:NoSchedule
```

Meaning:

```text id="mfwg1a"
Pods without matching toleration should not be scheduled onto devops-k8s-worker2.
```

---

# 17. Pod Without Toleration

Create a Deployment that targets the platform node but has no toleration.

```bash id="cyx47u"
nano 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml
```

Paste:

```yaml id="khv6ux"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-toleration-pending
  namespace: dev
  labels:
    app: no-toleration-pending
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-toleration-pending
  template:
    metadata:
      labels:
        app: no-toleration-pending
    spec:
      nodeSelector:
        node-role: platform
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

```bash id="og6jta"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml
```

Check:

```bash id="g8vg97"
kubectl get pods -n dev -l app=no-toleration-pending
kubectl describe pod -n dev -l app=no-toleration-pending
```

Expected:

```text id="o0t40y"
Pod stays Pending.
Events mention untolerated taint.
```

Delete:

```bash id="ocx39t"
kubectl delete -f 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml
```

---

# 18. Pod With Toleration

Create:

```bash id="qx90ag"
nano 10.10-workload-placement-scheduling/manifests/toleration-platform-deployment.yaml
```

Paste:

```yaml id="hqhx53"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toleration-platform
  namespace: dev
  labels:
    app: toleration-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: toleration-platform
  template:
    metadata:
      labels:
        app: toleration-platform
    spec:
      nodeSelector:
        node-role: platform
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "platform"
          effect: "NoSchedule"
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

```bash id="mz1bk6"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/toleration-platform-deployment.yaml
```

Check:

```bash id="wtotfi"
kubectl get pods -n dev -l app=toleration-platform -o wide
```

Expected:

```text id="ery41u"
Pod should schedule onto devops-k8s-worker2.
```

Important:

```text id="yc83y1"
Toleration allows scheduling onto tainted node.
nodeSelector forces it to target that node type.
```

Toleration alone does not force placement.

That is a very important misconception.

---

# 19. Dedicated Node Pattern

For dedicated nodes, use both:

```text id="34hweb"
taint:
  repel unwanted Pods

label:
  attract intended Pods
```

Then intended workloads use both:

```text id="gcxixv"
toleration:
  allowed onto tainted node

nodeSelector or nodeAffinity:
  intentionally target that node
```

Pattern:

```text id="xq5br2"
Node:
  label: dedicated=platform
  taint: dedicated=platform:NoSchedule

Pod:
  toleration: dedicated=platform:NoSchedule
  nodeSelector: dedicated=platform
```

Why both?

```text id="o3k1cu"
Taint prevents random Pods from landing there.
Affinity/selector attracts the right Pods there.
```

---

# 20. Topology Spread Constraints

Topology spread constraints tell Kubernetes to spread Pods across topology domains such as nodes, zones, or regions. They rely on node labels such as `topology.kubernetes.io/zone` to identify those domains. ([Kubernetes][6])

Simple meaning:

```text id="i8jgi9"
Do not put too many replicas in one failure domain.
```

Example domains:

```text id="98f4sb"
hostname:
  spread across nodes

zone:
  spread across availability zones

region:
  spread across regions, if applicable
```

Key fields:

```yaml id="58f5n7"
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: my-app
```

Meaning:

```text id="x1nhml"
maxSkew: 1
  Difference between most-loaded and least-loaded topology domain should not exceed 1.

topologyKey:
  Label that defines the topology domain.

whenUnsatisfiable:
  What to do if spread cannot be satisfied.

labelSelector:
  Which Pods are counted for spreading.
```

`whenUnsatisfiable` common values:

```text id="94q8bn"
DoNotSchedule:
  hard rule

ScheduleAnyway:
  soft rule
```

---

# 21. Topology Spread by Node

Create:

```bash id="t0tp83"
nano 10.10-workload-placement-scheduling/manifests/topology-spread-hostname-deployment.yaml
```

Paste:

```yaml id="v43jpd"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-spread-hostname
  namespace: dev
  labels:
    app: topology-spread-hostname
spec:
  replicas: 2
  selector:
    matchLabels:
      app: topology-spread-hostname
  template:
    metadata:
      labels:
        app: topology-spread-hostname
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: topology-spread-hostname
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

```bash id="q9x1o6"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/topology-spread-hostname-deployment.yaml
```

Check:

```bash id="piupql"
kubectl get pods -n dev -l app=topology-spread-hostname -o wide
```

Expected:

```text id="8ubp82"
Pods should spread across different nodes where possible.
```

---

# 22. Topology Spread by Zone

Create:

```bash id="t4fo80"
nano 10.10-workload-placement-scheduling/manifests/topology-spread-zone-deployment.yaml
```

Paste:

```yaml id="1839vq"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: topology-spread-zone
  namespace: dev
  labels:
    app: topology-spread-zone
spec:
  replicas: 2
  selector:
    matchLabels:
      app: topology-spread-zone
  template:
    metadata:
      labels:
        app: topology-spread-zone
    spec:
      nodeSelector:
        placement-demo: enabled
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: topology-spread-zone
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

```bash id="oydkr4"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/topology-spread-zone-deployment.yaml
```

Check:

```bash id="ayq3nr"
kubectl get pods -n dev -l app=topology-spread-zone -o wide
```

Expected:

```text id="c1qo03"
Pods should spread between zone-a and zone-b where possible.
```

Important:

```text id="8zlh2g"
Topology spread depends on correct node labels.
If nodes are missing the topologyKey label, scheduling behavior may surprise you.
```

---

# 23. Anti-Affinity vs Topology Spread

Both can help spread Pods.

## Pod anti-affinity

Best for:

```text id="9625oz"
do not place replicas together
strict separation
avoid co-location
```

Example:

```text id="bfj97h"
Do not place two replicas of same app on same node.
```

## Topology spread

Best for:

```text id="hjdj44"
balanced distribution
zone-aware spreading
fine control over skew
larger replica sets
availability optimization
```

Example:

```text id="xseddb"
Keep replicas balanced across zones with maxSkew=1.
```

Practical production rule:

```text id="eeu02o"
Use topologySpreadConstraints for balanced spreading.
Use podAntiAffinity when strict separation from specific Pods is required.
```

---

# 24. System vs Application Workloads

A real production cluster often has different node pools:

```text id="wl9hnk"
system node pool:
  CoreDNS
  ingress controller
  monitoring
  logging agents
  service mesh control plane
  cluster autoscaler

application node pool:
  frontend
  backend APIs
  workers

specialized node pool:
  GPU workloads
  high memory workloads
  batch jobs
  databases
```

Placement strategy:

```text id="7am6ts"
system nodes:
  tainted to repel normal apps

application nodes:
  default place for app workloads

special nodes:
  tainted and labeled for special workloads
```

Example:

```text id="dmmmbb"
platform nodes:
  taint: dedicated=platform:NoSchedule
  label: node-role=platform

app Pods:
  prefer node-role=app

platform Pods:
  tolerate dedicated=platform and target node-role=platform
```

---

# 25. Placement Debugging Commands

Use this command set:

```bash id="tpnbsa"
kubectl get nodes --show-labels

kubectl describe node NODE_NAME

kubectl get pods -n dev -o wide

kubectl describe pod POD_NAME -n dev

kubectl get events -n dev --sort-by=.lastTimestamp
```

For node taints:

```bash id="quuz5w"
kubectl describe node NODE_NAME | grep -i taints -A3
```

For Pod scheduling rules:

```bash id="hpfq82"
kubectl get pod POD_NAME -n dev -o yaml | grep -A80 affinity
kubectl get pod POD_NAME -n dev -o yaml | grep -A20 tolerations
kubectl get pod POD_NAME -n dev -o yaml | grep -A20 nodeSelector
```

---

# 26. Create Placement Summary Script

Create:

```bash id="kjkj6u"
nano 10.10-workload-placement-scheduling/scripts/placement-summary.sh
```

Paste:

```bash id="lu2b1b"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Kubernetes Workload Placement Summary ====="

echo
echo "Nodes with placement labels:"
kubectl get nodes \
  -L node-role \
  -L workload \
  -L topology.kubernetes.io/zone \
  -L placement-demo

echo
echo "Node taints:"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Node: $node"
  kubectl describe node "$node" | grep -i "Taints:" || true
done

echo
echo "Pods by node in namespace: $NAMESPACE"
kubectl get pods -n "$NAMESPACE" \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,QOS:.status.qosClass

echo
echo "Recent scheduling events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30
```

Make executable:

```bash id="db37s1"
chmod +x 10.10-workload-placement-scheduling/scripts/placement-summary.sh
```

Run:

```bash id="dl6ozx"
./10.10-workload-placement-scheduling/scripts/placement-summary.sh
```

---

# 27. Scheduling Debugging Runbook

Create:

```bash id="hff13e"
nano 10.10-workload-placement-scheduling/runbooks/scheduling-debugging-runbook.md
```

Paste:

````markdown id="gxoqo9"
# Kubernetes Scheduling Debugging Runbook

## Step 1 — Check Pod Status

```bash
kubectl get pods -n NAMESPACE
````

If Pod is Pending, continue.

## Step 2 — Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* nodeSelector mismatch
* node affinity mismatch
* untolerated taint
* insufficient cpu
* insufficient memory
* topology spread failure
* volume node affinity conflict

## Step 3 — Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Step 4 — Check Node Labels

```bash
kubectl get nodes --show-labels
kubectl get nodes -L node-role -L workload -L topology.kubernetes.io/zone
```

## Step 5 — Check Node Taints

```bash
kubectl describe node NODE_NAME | grep -i Taints -A3
```

## Step 6 — Check Pod Placement Rules

```bash
kubectl get pod POD_NAME -n NAMESPACE -o yaml
```

Look for:

* nodeSelector
* affinity
* tolerations
* topologySpreadConstraints
* resources.requests

## Common Root Causes

| Symptom                             | Likely Cause                            |
| ----------------------------------- | --------------------------------------- |
| Pending                             | hard placement rule cannot be satisfied |
| Pending with untolerated taint      | Pod lacks matching toleration           |
| Pending with node affinity conflict | required node affinity too strict       |
| All replicas on one node            | no anti-affinity or topology spread     |
| Platform node receives app Pods     | missing taint                           |
| App cannot use dedicated node       | missing toleration or selector          |

## Golden Rule

Scheduling issues are usually visible in Pod events.

````

---

# 28. Taints and Tolerations Runbook

Create:

```bash id="e50q7e"
nano 10.10-workload-placement-scheduling/runbooks/taints-tolerations-runbook.md
````

Paste:

````markdown id="gmri3n"
# Taints and Tolerations Runbook

## Meaning

A taint repels Pods from a node.
A toleration allows a Pod to tolerate that taint.

## Add Taint

```bash
kubectl taint nodes NODE_NAME dedicated=platform:NoSchedule
````

## Remove Taint

```bash
kubectl taint nodes NODE_NAME dedicated=platform:NoSchedule-
```

## Check Taints

```bash
kubectl describe node NODE_NAME | grep -i Taints -A3
```

## Pod Toleration Example

```yaml
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "platform"
    effect: "NoSchedule"
```

## Taint Effects

NoSchedule:
Do not schedule new Pods unless tolerated.

PreferNoSchedule:
Try to avoid scheduling Pods unless tolerated.

NoExecute:
Evict existing Pods that do not tolerate the taint.

## Production Pattern

Dedicated node:

* label node
* taint node
* add toleration to intended Pods
* add nodeSelector or nodeAffinity to intended Pods

## Golden Rule

Toleration allows placement.
It does not force placement.
Use affinity or selector to attract the Pod.

````

---

# 29. Topology Spread Runbook

Create:

```bash id="waphpz"
nano 10.10-workload-placement-scheduling/runbooks/topology-spread-runbook.md
````

Paste:

````markdown id="1r1alt"
# Topology Spread Runbook

## Goal

Spread replicas across failure domains such as nodes or zones.

## Example

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: demo-node-api
````

## Key Fields

maxSkew:
Maximum allowed imbalance.

topologyKey:
Node label that defines the domain.

whenUnsatisfiable:
DoNotSchedule or ScheduleAnyway.

labelSelector:
Which Pods are counted.

## Debug

```bash
kubectl get nodes -L topology.kubernetes.io/zone
kubectl get pods -n NAMESPACE -l app=APP -o wide
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Common Problems

* nodes missing topologyKey label
* too few topology domains
* maxSkew too strict
* nodeSelector limits eligible nodes
* taints block some domains
* resource requests too high

## Golden Rule

Topology spread needs correct node labels and enough eligible nodes.

````

---

# 30. Production Placement for `demo-node-api`

Now update your production base manifest.

Open:

```bash id="q243r2"
nano apps/demo-node-api/base/deployment.yaml
````

Inside:

```yaml id="cg2grl"
spec:
  template:
    spec:
```

add this placement block before `containers:`:

```yaml id="8t5jtg"
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-role
                    operator: In
                    values:
                      - app
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: demo-node-api
                    app.kubernetes.io/component: backend
                topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: demo-node-api
              app.kubernetes.io/component: backend
```

Meaning:

```text id="we56x4"
Prefer app nodes.
Prefer not to place demo-node-api replicas together.
Try to spread replicas across nodes.
Do not block scheduling if spread is impossible.
```

Why `ScheduleAnyway`?

```text id="95sblv"
For local/dev clusters, availability is better than Pending Pods.
In production, you may use DoNotSchedule if enough nodes/zones exist.
```

Your `spec.template.spec` should look conceptually like:

```yaml id="gqna1x"
    spec:
      terminationGracePeriodSeconds: 30

      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-role
                    operator: In
                    values:
                      - app
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: demo-node-api
                    app.kubernetes.io/component: backend
                topologyKey: kubernetes.io/hostname

      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: demo-node-api
              app.kubernetes.io/component: backend

      containers:
        - name: demo-node-api
```

---

# 31. Create demo-node-api Placement Policy Note

Create:

```bash id="q6s0xs"
nano 10.10-workload-placement-scheduling/notes/demo-node-api-placement-policy.md
```

Paste:

```markdown id="f1od8l"
# demo-node-api Placement Policy

## Goal

Run demo-node-api on application nodes and reduce the chance that all replicas land on the same node.

## Strategy

- Prefer nodes labeled node-role=app.
- Prefer spreading replicas across different hostnames.
- Use topology spread with maxSkew=1.
- Use ScheduleAnyway in dev to avoid Pending Pods.
- Use stricter rules only when production has enough nodes/zones.

## Why Preferred Rules?

Preferred rules improve placement without reducing availability in small clusters.

## Future Production Options

For EKS production:

- app node group
- system node group
- taints on system nodes
- tolerations for platform workloads
- topology spread across availability zones
- PodDisruptionBudget
- HPA
- cluster autoscaler
```

---

# 32. Placement Myths and Misconceptions

## Myth 1: Toleration means the Pod will run on that node

Wrong.

```text id="qj35es"
Toleration only allows scheduling onto a tainted node.
It does not attract the Pod.
```

Use:

```text id="u94m7f"
toleration + nodeSelector
```

or:

```text id="p8djz8"
toleration + nodeAffinity
```

---

## Myth 2: nodeSelector and nodeAffinity are unrelated

Not exactly.

```text id="dmdbmj"
nodeSelector is simple hard label matching.
nodeAffinity is advanced label-based placement.
```

---

## Myth 3: Hard anti-affinity is always best

Wrong.

```text id="cdhbks"
Hard anti-affinity can make Pods Pending if there are not enough nodes.
```

Use preferred anti-affinity when you want resilience but still want scheduling flexibility.

---

## Myth 4: Topology spread works without node labels

Wrong.

```text id="d6c5ax"
Topology spread depends on topologyKey labels existing on nodes.
```

---

## Myth 5: Scheduler moves Pods when labels change

Usually wrong.

Many scheduling constraints say:

```text id="rk8n1z"
IgnoredDuringExecution
```

Meaning:

```text id="8x741n"
The rule is checked during scheduling.
Existing running Pods are not automatically evicted just because labels later changed.
```

---

## Myth 6: System and app workloads should share all nodes freely

Usually not ideal.

Production clusters often separate:

```text id="06usno"
system workloads
application workloads
special workloads
batch workloads
GPU workloads
```

using labels, taints, tolerations, and affinity.

---

# 33. Validation Script

Create:

```bash id="jmc1c1"
nano 10.10-workload-placement-scheduling/scripts/validate-lesson-10-10.sh
```

Paste:

```bash id="q83cbi"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.10 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get node devops-k8s-worker >/dev/null
kubectl get node devops-k8s-worker2 >/dev/null

APP_NODE_ROLE="$(kubectl get node devops-k8s-worker -o jsonpath='{.metadata.labels.node-role}')"
PLATFORM_NODE_ROLE="$(kubectl get node devops-k8s-worker2 -o jsonpath='{.metadata.labels.node-role}')"

if [ "$APP_NODE_ROLE" != "app" ]; then
  echo "ERROR: devops-k8s-worker should have node-role=app"
  exit 1
fi

if [ "$PLATFORM_NODE_ROLE" != "platform" ]; then
  echo "ERROR: devops-k8s-worker2 should have node-role=platform"
  exit 1
fi

kubectl get deployment nodeselector-app -n dev >/dev/null
kubectl get deployment required-node-affinity -n dev >/dev/null
kubectl get deployment preferred-node-affinity -n dev >/dev/null
kubectl get deployment cache-anchor -n dev >/dev/null
kubectl get deployment pod-affinity-demo -n dev >/dev/null
kubectl get deployment pod-anti-affinity-demo -n dev >/dev/null
kubectl get deployment toleration-platform -n dev >/dev/null
kubectl get deployment topology-spread-hostname -n dev >/dev/null
kubectl get deployment topology-spread-zone -n dev >/dev/null

kubectl rollout status deployment/nodeselector-app -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/required-node-affinity -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/preferred-node-affinity -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/cache-anchor -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/pod-affinity-demo -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/pod-anti-affinity-demo -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/toleration-platform -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/topology-spread-hostname -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/topology-spread-zone -n dev --timeout=120s >/dev/null

NODESELECTOR_NODE="$(kubectl get pod -n dev -l app=nodeselector-app -o jsonpath='{.items[0].spec.nodeName}')"
NODESELECTOR_NODE_ROLE="$(kubectl get node "$NODESELECTOR_NODE" -o jsonpath='{.metadata.labels.node-role}')"

if [ "$NODESELECTOR_NODE_ROLE" != "app" ]; then
  echo "ERROR: nodeselector-app should run on node-role=app"
  exit 1
fi

PLATFORM_POD_NODE="$(kubectl get pod -n dev -l app=toleration-platform -o jsonpath='{.items[0].spec.nodeName}')"
PLATFORM_POD_NODE_ROLE="$(kubectl get node "$PLATFORM_POD_NODE" -o jsonpath='{.metadata.labels.node-role}')"

if [ "$PLATFORM_POD_NODE_ROLE" != "platform" ]; then
  echo "ERROR: toleration-platform should run on node-role=platform"
  exit 1
fi

kubectl describe node devops-k8s-worker2 | grep -q "dedicated=platform:NoSchedule"

test -x 10.10-workload-placement-scheduling/scripts/placement-summary.sh
test -f 10.10-workload-placement-scheduling/notes/workload-placement-mental-model.md
test -f 10.10-workload-placement-scheduling/notes/demo-node-api-placement-policy.md
test -f 10.10-workload-placement-scheduling/runbooks/scheduling-debugging-runbook.md
test -f 10.10-workload-placement-scheduling/runbooks/taints-tolerations-runbook.md
test -f 10.10-workload-placement-scheduling/runbooks/topology-spread-runbook.md
test -f apps/demo-node-api/base/deployment.yaml

grep -q "topologySpreadConstraints" apps/demo-node-api/base/deployment.yaml
grep -q "podAntiAffinity" apps/demo-node-api/base/deployment.yaml
grep -q "nodeAffinity" apps/demo-node-api/base/deployment.yaml

echo "Node selector pod node: $NODESELECTOR_NODE"
echo "Platform pod node: $PLATFORM_POD_NODE"
echo "Lesson 10.10 validation passed."
```

Make executable:

```bash id="zlipy4"
chmod +x 10.10-workload-placement-scheduling/scripts/validate-lesson-10-10.sh
```

Run:

```bash id="ygm8eg"
./10.10-workload-placement-scheduling/scripts/validate-lesson-10-10.sh
```

---

# 34. Cleanup Script

Create:

```bash id="i2bzyv"
nano 10.10-workload-placement-scheduling/scripts/cleanup-lesson-10-10.sh
```

Paste:

```bash id="a2d3st"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.10 ====="

kubectl delete -f 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml --ignore-not-found=true

kubectl delete -f 10.10-workload-placement-scheduling/manifests/topology-spread-zone-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/topology-spread-hostname-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/toleration-platform-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/pod-anti-affinity-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/pod-affinity-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/cache-anchor-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/preferred-node-affinity-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/required-node-affinity-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.10-workload-placement-scheduling/manifests/nodeselector-app-deployment.yaml --ignore-not-found=true

kubectl taint nodes devops-k8s-worker2 dedicated=platform:NoSchedule- || true

echo "Lesson 10.10 resources cleaned."
echo "Node labels are kept because they are useful for future lessons."
```

Make executable:

```bash id="i2rcoc"
chmod +x 10.10-workload-placement-scheduling/scripts/cleanup-lesson-10-10.sh
```

Run only if you want cleanup:

```bash id="tleydb"
./10.10-workload-placement-scheduling/scripts/cleanup-lesson-10-10.sh
```

---

# 35. Practical Lab Summary

Run the main lab:

```bash id="ugxnm3"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl label node devops-k8s-worker \
  node-role=app \
  workload=stateless \
  topology.kubernetes.io/zone=zone-a \
  placement-demo=enabled \
  --overwrite

kubectl label node devops-k8s-worker2 \
  node-role=platform \
  workload=system \
  topology.kubernetes.io/zone=zone-b \
  placement-demo=enabled \
  --overwrite

kubectl taint nodes devops-k8s-worker2 \
  dedicated=platform:NoSchedule \
  --overwrite

kubectl apply -f 10.10-workload-placement-scheduling/manifests/nodeselector-app-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/required-node-affinity-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/preferred-node-affinity-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/cache-anchor-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/pod-affinity-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/pod-anti-affinity-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/toleration-platform-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/topology-spread-hostname-deployment.yaml
kubectl apply -f 10.10-workload-placement-scheduling/manifests/topology-spread-zone-deployment.yaml

./10.10-workload-placement-scheduling/scripts/placement-summary.sh
./10.10-workload-placement-scheduling/scripts/validate-lesson-10-10.sh
```

Failure demos:

```bash id="l99opl"
kubectl apply -f 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml
kubectl describe pod -n dev -l app=nodeselector-pending
kubectl delete -f 10.10-workload-placement-scheduling/manifests/nodeselector-pending-deployment.yaml

kubectl apply -f 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml
kubectl describe pod -n dev -l app=no-toleration-pending
kubectl delete -f 10.10-workload-placement-scheduling/manifests/no-toleration-pending-deployment.yaml
```

---

# 36. Production Placement Rules

```text id="lhakio"
Use node labels to describe node purpose.
Use nodeSelector for simple hard placement.
Use node affinity for expressive placement.
Use preferred affinity when availability matters.
Use required affinity only when mandatory.
Use taints to repel unwanted Pods.
Use tolerations to allow intended Pods.
Use taint + affinity together for dedicated nodes.
Use pod anti-affinity or topology spread for high availability.
Use topology spread across zones in multi-AZ clusters.
Avoid overly strict rules in small clusters.
Always debug Pending Pods with describe and events.
```

---

# 37. Interview Explanation

Use this:

```text id="0vpxvb"
Kubernetes scheduling decides which node should run a Pod. By default, the scheduler considers available resources and constraints, but I can control placement using node labels, nodeSelector, node affinity, pod affinity, pod anti-affinity, taints, tolerations, and topology spread constraints.

nodeSelector is a simple hard match on node labels. Node affinity is a more expressive version with required and preferred rules. Pod affinity places Pods near other Pods, while pod anti-affinity keeps matching Pods apart, often for high availability. Taints are applied to nodes to repel Pods, and tolerations are applied to Pods to allow scheduling onto tainted nodes. Topology spread constraints distribute replicas across topology domains such as nodes or zones to reduce failure impact.
```

Resume version:

```text id="jyztu3"
Implemented Kubernetes workload placement labs using node labels, nodeSelector, node affinity, pod affinity, pod anti-affinity, taints, tolerations, topology spread constraints, dedicated node patterns, scheduling debug runbooks, and production placement policy for demo-node-api.
```

---

# 38. Today’s Core Rules

```text id="x7k6mi"
nodeSelector is simple hard node label matching.
Node affinity is advanced node label matching.
requiredDuringScheduling is a hard rule.
preferredDuringScheduling is a soft rule.
Pod affinity places Pods near matching Pods.
Pod anti-affinity keeps Pods away from matching Pods.
Taint repels Pods from nodes.
Toleration allows Pods onto tainted nodes.
Toleration does not force placement.
Use taints plus affinity for dedicated nodes.
NoSchedule blocks new non-tolerating Pods.
PreferNoSchedule is soft avoidance.
NoExecute can evict existing non-tolerating Pods.
Topology spread balances Pods across domains.
Hard placement rules can cause Pending Pods.
```

---

# 39. Commit Lesson 10.10

From repo root:

```bash id="nbxobp"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes workload placement scheduling lesson"

git push
```

---

# Next Lesson

```text id="7bcvok"
Lesson 10.11 — RBAC, ServiceAccounts, Least Privilege, and Namespace Isolation
```

We will cover:

```text id="dr0q5p"
ServiceAccount mental model
default ServiceAccount risk
Role
ClusterRole
RoleBinding
ClusterRoleBinding
verbs
resources
apiGroups
least privilege
kubectl auth can-i
workload identity basics
namespace isolation
RBAC debugging
production RBAC for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/?utm_source=chatgpt.com "Assigning Pods to Nodes"
[2]: https://kubernetes.io/docs/reference/node/node-labels/?utm_source=chatgpt.com "Node Labels Populated By The Kubelet"
[3]: https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/?utm_source=chatgpt.com "Assign Pods to Nodes"
[4]: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/?utm_source=chatgpt.com "Taints and Tolerations"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_taint/?utm_source=chatgpt.com "kubectl taint"
[6]: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/?utm_source=chatgpt.com "Pod Topology Spread Constraints"
