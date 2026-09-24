# Module 10 Begins — Kubernetes Production Operations

## Lesson 10.1 — Kubernetes Mental Model, Cluster Architecture, Workloads, Services, Ingress, Namespaces, RBAC, and Deployment Flow

Yes — Modules 10 and 11 should be treated as a **full Kubernetes specialization**, not just two normal modules.

From now on:

```text
Module 10 = Kubernetes Production Operations
Module 11 = Advanced Kubernetes Troubleshooting
```

Module 10 will teach you how Kubernetes works, how production workloads are deployed, exposed, secured, scaled, monitored, and operated.

Module 11 will teach you how to troubleshoot broken Kubernetes systems like a real DevOps/SRE engineer.

Kubernetes is a portable, extensible open-source platform for managing containerized workloads and services, and it supports declarative configuration and automation. ([Kubernetes][1])

---

# 1. Expanded Module 10 Roadmap

We will make Module 10 deep and production-oriented.

```text
Module 10 — Kubernetes Production Operations

10.1  Kubernetes mental model and architecture
10.2  Local cluster setup with kind, kubectl, namespaces, and context management
10.3  Pods, labels, annotations, selectors, and YAML anatomy
10.4  Deployments, ReplicaSets, rollout, rollback, and deployment strategies
10.5  Services, ClusterIP, NodePort, LoadBalancer, DNS, and service discovery
10.6  Ingress, Ingress Controller, TLS, host/path routing, and production traffic flow
10.7  ConfigMaps, Secrets, env injection, mounted config, and secret management patterns
10.8  Probes, lifecycle hooks, graceful shutdown, and production health design
10.9  Resource requests, limits, QoS classes, scheduling, and capacity planning
10.10 Nodes, taints, tolerations, affinity, topology spread, and workload placement
10.11 RBAC, ServiceAccounts, least privilege, and namespace isolation
10.12 PersistentVolumes, PVCs, StorageClasses, StatefulSets, and database patterns
10.13 Helm, Kustomize, overlays, release packaging, and environment promotion
10.14 Autoscaling: HPA, VPA concepts, Cluster Autoscaler, PDBs, and safe scaling
10.15 Kubernetes observability: events, logs, metrics, Prometheus, Grafana, Loki
10.16 Production hardening: NetworkPolicy, Pod Security, image policy, admission control
10.17 GitOps deployment flow with ArgoCD preview
10.18 Module 10 capstone: production-grade Kubernetes deployment for demo-node-api
```

---

# 2. Expanded Module 11 Roadmap

Module 11 will be a troubleshooting masterclass.

```text
Module 11 — Advanced Kubernetes Troubleshooting

11.1  Kubernetes troubleshooting mental model
11.2  Pod Pending, ImagePullBackOff, CrashLoopBackOff, OOMKilled, and Evicted
11.3  Deployment rollout failures and rollback debugging
11.4  Service and DNS troubleshooting
11.5  Ingress and TLS troubleshooting
11.6  ConfigMap and Secret injection troubleshooting
11.7  Probe failure troubleshooting
11.8  RBAC permission troubleshooting
11.9  Node pressure, disk pressure, memory pressure, and kubelet issues
11.10 Scheduling failures, taints, affinity, topology, and resource shortages
11.11 Storage, PVC, PV, StatefulSet, and volume mount failures
11.12 NetworkPolicy and CNI troubleshooting
11.13 HPA/autoscaling debugging
11.14 Logs, events, metrics, traces, and incident diagnosis
11.15 Production incident simulations
11.16 Final Kubernetes troubleshooting capstone
```

---

# 3. Kubernetes in One Simple Sentence

Kubernetes is a system that keeps your applications running in the desired state.

You tell Kubernetes:

```text
I want 3 replicas of this app.
Use this container image.
Expose it internally.
Restart it if it crashes.
Route traffic to healthy pods.
Roll out new versions safely.
Limit CPU and memory.
Use these secrets.
Only allow this ServiceAccount.
```

Kubernetes continuously tries to make the real world match that desired state.

This is the most important mental model:

```text
desired state
  ↓
Kubernetes control loop
  ↓
actual state
```

If actual state is different from desired state, Kubernetes controllers try to fix it. Kubernetes controllers are control loops that watch cluster state and make or request changes to move the current state closer to the desired state. ([Kubernetes][2])

---

# 4. The Biggest Kubernetes Misconception

Many beginners think:

```text
Kubernetes runs containers.
```

Better understanding:

```text
Kubernetes schedules Pods.
Pods contain containers.
Nodes run Pods.
Container runtime runs containers.
Control plane manages the desired state.
```

Kubernetes workloads run inside Pods, and a Pod represents one or more running containers in the cluster. ([Kubernetes][3])

So the real flow is:

```text
Deployment
  creates ReplicaSet
    creates Pods
      contain containers
        run on Nodes
```

---

# 5. Kubernetes Cluster Architecture

A Kubernetes cluster has two big parts:

```text
Control Plane
Worker Nodes
```

A Kubernetes cluster consists of a control plane plus worker machines called nodes, and those nodes run containerized applications. ([Kubernetes][4])

## Control Plane

The control plane is the brain.

It answers:

```text
What should exist?
Where should workloads run?
Are Pods healthy?
Should more Pods be created?
Is a node unavailable?
Who is allowed to do what?
```

Main control plane components:

```text
kube-apiserver
etcd
kube-scheduler
kube-controller-manager
cloud-controller-manager
```

## Worker Node

A worker node is where application workloads run.

Node components include:

```text
kubelet
container runtime
kube-proxy
Pods
```

Each node is managed by the control plane and contains the services needed to run Pods; node components include the kubelet, container runtime, and kube-proxy. ([Kubernetes][5])

---

# 6. Simple Architecture Diagram

```text
User / CI/CD / kubectl
        |
        v
+----------------------+
|   kube-apiserver     |
+----------------------+
        |
        v
+----------------------+
|      etcd            |
| cluster state store  |
+----------------------+

Control Plane:
+----------------------+       +----------------------+
| kube-scheduler       |       | controller-manager   |
| chooses nodes        |       | reconciles state     |
+----------------------+       +----------------------+

Worker Nodes:
+----------------------------------------------------+
| Node 1                                             |
|  kubelet + container runtime + kube-proxy          |
|  Pod: app container                                |
|  Pod: app container                                |
+----------------------------------------------------+

+----------------------------------------------------+
| Node 2                                             |
|  kubelet + container runtime + kube-proxy          |
|  Pod: app container                                |
+----------------------------------------------------+
```

---

# 7. Kubernetes Object Mental Model

Everything in Kubernetes is an object.

Examples:

```text
Pod
Deployment
ReplicaSet
Service
Ingress
ConfigMap
Secret
Namespace
ServiceAccount
Role
RoleBinding
PersistentVolumeClaim
```

You usually create objects using YAML.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-node-api
  template:
    metadata:
      labels:
        app: demo-node-api
    spec:
      containers:
        - name: demo-node-api
          image: demo-node-api:0.1.0
          ports:
            - containerPort: 3002
```

Important sections:

```text
apiVersion:
  Which Kubernetes API version this object uses.

kind:
  What type of object this is.

metadata:
  Name, labels, annotations, namespace.

spec:
  Desired state.

status:
  Actual state, created by Kubernetes.
```

You write `spec`.

Kubernetes writes `status`.

---

# 8. Pod

A Pod is the smallest deployable unit in Kubernetes.

A Pod can contain:

```text
one container
multiple tightly coupled containers
shared network namespace
shared volumes
same lifecycle
```

Most of the time:

```text
1 Pod = 1 app container
```

But technically:

```text
1 Pod = 1 or more containers
```

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo-node-api-pod
  labels:
    app: demo-node-api
spec:
  containers:
    - name: demo-node-api
      image: demo-node-api:0.1.0
      ports:
        - containerPort: 3002
```

Myth:

```text
A Pod is the same as a container.
```

Reality:

```text
A Pod is a wrapper around one or more containers.
```

---

# 9. Deployment

In production, you usually do not create standalone Pods.

You create a Deployment.

A Deployment manages Pods through ReplicaSets and provides declarative updates for application workloads. ([Kubernetes][6])

A Deployment gives you:

```text
replicas
rollout
rollback
self-healing
version updates
ReplicaSet management
```

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-node-api
  template:
    metadata:
      labels:
        app: demo-node-api
    spec:
      containers:
        - name: demo-node-api
          image: demo-node-api:0.1.0
          ports:
            - containerPort: 3002
```

Flow:

```text
Deployment
  ↓
ReplicaSet
  ↓
Pods
```

Myth:

```text
Deployment runs the container directly.
```

Reality:

```text
Deployment manages ReplicaSets.
ReplicaSets manage Pods.
Pods run containers.
```

---

# 10. Service

Pods are temporary.

They can be deleted and recreated.

Their IP addresses can change.

So you should not send traffic directly to Pod IPs.

A Service gives stable networking in front of Pods. Kubernetes Service is a method for exposing a network application running as one or more Pods in the cluster. ([Kubernetes][7])

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api
spec:
  type: ClusterIP
  selector:
    app: demo-node-api
  ports:
    - port: 80
      targetPort: 3002
```

Meaning:

```text
port: 80
  Service port

targetPort: 3002
  Container port inside Pod

selector:
  Which Pods receive traffic
```

Flow:

```text
Service
  selector app=demo-node-api
    ↓
matching Pods
```

Myth:

```text
Service always means external load balancer.
```

Reality:

```text
Service can be internal or external depending on type.
```

Common Service types:

```text
ClusterIP:
  internal only

NodePort:
  exposes port on every node

LoadBalancer:
  asks cloud provider for external load balancer

ExternalName:
  maps service to external DNS name
```

---

# 11. Ingress

A Service exposes apps inside the cluster.

Ingress handles HTTP/HTTPS routing from outside.

Ingress lets you map traffic to backends based on rules such as hosts and paths. ([Kubernetes][8])

Example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: demo-node-api
                port:
                  number: 80
```

Flow:

```text
Internet
  ↓
Load Balancer
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
Pods
```

Critical point:

```text
Ingress object alone does nothing.
You need an Ingress Controller.
```

The official docs state that for an Ingress to work, an Ingress controller must be running in the cluster. ([Kubernetes][9])

Myth:

```text
I created Ingress, so traffic should work.
```

Reality:

```text
Ingress needs an Ingress Controller like nginx-ingress, AWS Load Balancer Controller, Traefik, HAProxy, or another controller.
```

---

# 12. Namespace

Namespace is logical separation inside a cluster.

Example:

```text
dev
staging
production
monitoring
ingress-nginx
argocd
```

Namespace is not a full security boundary by itself.

It helps organize resources.

Example:

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

Then:

```bash
kubectl get pods -n dev
kubectl get pods -n production
```

Myth:

```text
Namespace means complete isolation.
```

Reality:

```text
Namespace organizes resources.
Security isolation needs RBAC, NetworkPolicy, Pod Security, admission policies, and correct cluster configuration.
```

---

# 13. RBAC

RBAC means Role-Based Access Control.

It answers:

```text
Who can do what?
On which resources?
In which namespace?
```

Kubernetes RBAC is a key security control for ensuring cluster users and workloads only have the access required for their roles. ([Kubernetes][10])

Important objects:

```text
ServiceAccount
Role
ClusterRole
RoleBinding
ClusterRoleBinding
```

Example Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: demo
  name: pod-reader
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

Example RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: demo
subjects:
  - kind: ServiceAccount
    name: demo-reader
    namespace: demo
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Myth:

```text
If a Pod runs inside a namespace, it can access everything in that namespace.
```

Reality:

```text
A Pod uses a ServiceAccount.
The ServiceAccount gets permissions through RBAC.
By default, service accounts do not automatically get broad application permissions.
```

Default RBAC policies grant scoped permissions to control-plane components, nodes, and controllers, but do not grant permissions to ServiceAccounts outside `kube-system` beyond API discovery roles. ([Kubernetes][11])

---

# 14. Full Request Flow in Production

Imagine your Node.js app is running in Kubernetes.

User opens:

```text
https://api.yourdatascientist.tech/todos
```

The request flow may look like this:

```text
User
  ↓
DNS
  ↓
Cloud Load Balancer
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Kubernetes Service
  ↓
Pod
  ↓
Container
  ↓
Node.js app on port 3002
```

Kubernetes objects involved:

```text
Deployment:
  keeps app Pods running

Pods:
  run app containers

Service:
  stable internal endpoint

Ingress:
  HTTP routing rule

Ingress Controller:
  actual traffic router

ConfigMap:
  non-secret config

Secret:
  sensitive config

ServiceAccount:
  identity for workload

RBAC:
  permissions for workload

Namespace:
  logical grouping
```

---

# 15. Setup Folder for Module 10

Run:

```bash
cd ~/devops-masterclass

mkdir -p 10-kubernetes-production-operations/{notes,manifests,scripts,runbooks,reports,apps,capstone}
cd 10-kubernetes-production-operations
```

Create lesson folder:

```bash
mkdir -p 10.1-kubernetes-mental-model/{notes,manifests,scripts,runbooks}
```

Create notes file:

```bash
nano 10.1-kubernetes-mental-model/notes/kubernetes-mental-model.md
```

Paste:

```markdown
# Kubernetes Mental Model

## Core Idea

Kubernetes keeps the actual state of applications close to the desired state declared by users.

## Main Parts

- Control plane: manages cluster state
- Worker nodes: run application workloads
- Pods: smallest deployable unit
- Deployments: manage ReplicaSets and Pods
- Services: stable networking for Pods
- Ingress: HTTP/HTTPS routing into the cluster
- Namespaces: logical grouping
- RBAC: permission control

## Golden Flow

User request
→ Ingress Controller
→ Ingress
→ Service
→ Pod
→ Container
→ Application

## Golden Rule

Do not think in containers first.
Think in Kubernetes objects and desired state.
```

---

# 16. Install `kubectl`

`kubectl` is the Kubernetes command-line tool used to deploy applications, inspect resources, manage cluster objects, and view logs. ([Kubernetes][12])

Install on Linux:

```bash
mkdir -p ~/.local/bin

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
mv kubectl ~/.local/bin/kubectl

export PATH="$HOME/.local/bin:$PATH"

kubectl version --client
```

Persist PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

# 17. Install `kind`

For local Kubernetes labs, we will use `kind`.

`kind` runs local Kubernetes clusters using Docker container “nodes” and is commonly used for local development and CI testing. ([Kind][13])

Install:

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64

chmod +x ./kind
mv ./kind ~/.local/bin/kind

kind version
```

Create cluster:

```bash
kind create cluster --name devops-k8s
```

The kind quick start states that creating a cluster can be as simple as `kind create cluster`. ([Kind][14])

Verify:

```bash
kubectl cluster-info
kubectl get nodes
```

Expected:

```text
NAME                       STATUS   ROLES           AGE   VERSION
devops-k8s-control-plane   Ready    control-plane   ...   ...
```

---

# 18. First Kubernetes Inspection Commands

Run:

```bash
kubectl get nodes
kubectl get namespaces
kubectl get pods -A
kubectl get services -A
kubectl get deployments -A
```

Meaning:

```text
kubectl get nodes:
  show worker/control-plane nodes

kubectl get namespaces:
  show logical namespaces

kubectl get pods -A:
  show Pods across all namespaces

kubectl get services -A:
  show Services across all namespaces

kubectl get deployments -A:
  show Deployments across all namespaces
```

Now inspect the cluster:

```bash
kubectl describe node devops-k8s-control-plane
```

Look for:

```text
Roles
Labels
Taints
Capacity
Allocatable
Conditions
System Info
Non-terminated Pods
Events
```

This is the beginning of Kubernetes troubleshooting.

---

# 19. Create Your First Namespace

```bash
kubectl create namespace demo
```

Verify:

```bash
kubectl get namespaces
```

Set current namespace:

```bash
kubectl config set-context --current --namespace=demo
```

Verify:

```bash
kubectl config view --minify | grep namespace
```

Important:

```text
If you forget the namespace, you may think resources are missing.
```

Common confusion:

```bash
kubectl get pods
```

shows only current namespace.

But:

```bash
kubectl get pods -A
```

shows all namespaces.

---

# 20. Create First Pod

Create:

```bash
nano 10.1-kubernetes-mental-model/manifests/pod.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: demo
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
```

Apply:

```bash
kubectl apply -f 10.1-kubernetes-mental-model/manifests/pod.yaml
```

Check:

```bash
kubectl get pods -n demo
kubectl describe pod nginx-pod -n demo
```

Watch:

```bash
kubectl get pods -n demo -w
```

Exit watch with:

```text
Ctrl + C
```

---

# 21. Create First Deployment

Create:

```bash
nano 10.1-kubernetes-mental-model/manifests/deployment.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: demo
  labels:
    app: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-managed
  template:
    metadata:
      labels:
        app: nginx-managed
    spec:
      containers:
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f 10.1-kubernetes-mental-model/manifests/deployment.yaml
```

Check:

```bash
kubectl get deployments -n demo
kubectl get replicasets -n demo
kubectl get pods -n demo
```

You should see 3 Pods from the Deployment.

Now delete one Pod:

```bash
kubectl delete pod -n demo -l app=nginx-managed
```

Check again:

```bash
kubectl get pods -n demo
```

Kubernetes recreates Pods because the Deployment wants 3 replicas.

This is self-healing.

---

# 22. Create First Service

Create:

```bash
nano 10.1-kubernetes-mental-model/manifests/service.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: demo
spec:
  type: ClusterIP
  selector:
    app: nginx-managed
  ports:
    - port: 80
      targetPort: 80
```

Apply:

```bash
kubectl apply -f 10.1-kubernetes-mental-model/manifests/service.yaml
```

Check:

```bash
kubectl get svc -n demo
kubectl describe svc nginx-service -n demo
```

Check endpoints:

```bash
kubectl get endpoints -n demo
```

Important:

```text
Service selector must match Pod labels.
If selector does not match, Service has no endpoints.
```

This is one of the most common beginner mistakes.

---

# 23. Test Service from Inside Cluster

Create temporary curl Pod:

```bash
kubectl run curl-test \
  -n demo \
  --image=curlimages/curl:latest \
  --rm -it \
  --restart=Never \
  -- sh
```

Inside the shell:

```sh
curl nginx-service
```

Exit:

```sh
exit
```

If it works, your flow is:

```text
curl-test Pod
  ↓
nginx-service
  ↓
nginx-managed Pods
```

---

# 24. Key Confusions Cleared

## Confusion 1: Why not just run Docker?

Docker runs containers.

Kubernetes manages applications across nodes with scheduling, self-healing, service discovery, rollouts, config, secrets, scaling, and access control.

```text
Docker:
  run this container

Kubernetes:
  keep this application running correctly over time
```

## Confusion 2: Why do Pods restart?

Because a controller, like a Deployment, wants a desired number of replicas.

If a Pod dies, Kubernetes creates a replacement.

## Confusion 3: Why does Service not work?

Usually one of these:

```text
wrong selector
Pod label mismatch
targetPort wrong
Pod not ready
namespace mismatch
NetworkPolicy blocking traffic
```

## Confusion 4: Why does Ingress not work?

Usually one of these:

```text
Ingress Controller missing
wrong ingressClassName
Service name wrong
Service port wrong
DNS not pointing to load balancer
TLS secret missing
backend Pods not ready
```

## Confusion 5: Is Kubernetes only for microservices?

No.

Kubernetes can run:

```text
monoliths
microservices
APIs
workers
batch jobs
cron jobs
stateful apps
platform components
ML workloads
internal tools
```

---

# 25. Production-Level View for Your `demo-node-api`

Eventually your Node.js API will look like this:

```text
Namespace: production

Deployment:
  demo-node-api
  replicas: 3
  image: demo-node-api:1.0.0
  readinessProbe: /ready
  livenessProbe: /health
  resources: requests/limits
  env from ConfigMap and Secret
  ServiceAccount: demo-node-api

Service:
  demo-node-api
  type: ClusterIP
  port 80 -> targetPort 3002

Ingress:
  api.yourdatascientist.tech
  TLS enabled
  routes / to demo-node-api Service

RBAC:
  workload has minimum required permissions

HPA:
  scales based on CPU or custom metrics

PDB:
  protects availability during voluntary disruptions

NetworkPolicy:
  restricts inbound/outbound traffic

Observability:
  logs, metrics, traces, events
```

That is the direction of Module 10.

---

# 26. Lesson 10.1 Validation Script

Create:

```bash
nano 10.1-kubernetes-mental-model/scripts/validate-lesson-10-1.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.1 ====="

kubectl version --client >/dev/null
kubectl cluster-info >/dev/null

kubectl get namespace demo >/dev/null

kubectl get pod nginx-pod -n demo >/dev/null
kubectl get deployment nginx-deployment -n demo >/dev/null
kubectl get service nginx-service -n demo >/dev/null

READY_PODS="$(kubectl get pods -n demo -l app=nginx-managed --field-selector=status.phase=Running --no-headers | wc -l)"

if [ "$READY_PODS" -lt 1 ]; then
  echo "ERROR: expected at least one running nginx-managed Pod"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints nginx-service -n demo -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: nginx-service has no endpoints"
  exit 1
fi

echo "Lesson 10.1 validation passed."
```

Make executable:

```bash
chmod +x 10.1-kubernetes-mental-model/scripts/validate-lesson-10-1.sh
```

Run:

```bash
./10.1-kubernetes-mental-model/scripts/validate-lesson-10-1.sh
```

---

# 27. Cleanup

Delete lesson resources:

```bash
kubectl delete -f 10.1-kubernetes-mental-model/manifests/service.yaml
kubectl delete -f 10.1-kubernetes-mental-model/manifests/deployment.yaml
kubectl delete -f 10.1-kubernetes-mental-model/manifests/pod.yaml
kubectl delete namespace demo
```

Delete cluster only if you want to stop all Kubernetes labs:

```bash
kind delete cluster --name devops-k8s
```

For Module 10, keep the cluster if you want to continue directly.

---

# 28. Commit Lesson 10.1

From repo root:

```bash
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: start Kubernetes production operations module"

git push
```

---

# 29. Interview Explanation

Use this:

```text
Kubernetes is a declarative container orchestration platform. Instead of manually running containers, I define desired state using objects like Deployments, Services, ConfigMaps, Secrets, and Ingress. The Kubernetes control plane continuously reconciles the actual cluster state toward the desired state.

A Deployment manages ReplicaSets and Pods, Pods run containers, Services provide stable networking to changing Pods, and Ingress routes external HTTP/HTTPS traffic through an Ingress Controller to Services. Namespaces organize resources, and RBAC controls who or what can access Kubernetes APIs.
```

Resume version:

```text
Built Kubernetes production foundations using kind, kubectl, namespaces, Pods, Deployments, Services, and validation scripts while learning control plane, worker node, workload, networking, and RBAC mental models.
```

---

# 30. Today’s Core Rules

```text
Kubernetes works by desired state and reconciliation.
Control plane manages the cluster.
Nodes run Pods.
Pods contain containers.
Deployments manage ReplicaSets and Pods.
Services give stable networking to Pods.
Ingress requires an Ingress Controller.
Namespaces organize resources but are not full security boundaries.
RBAC controls permissions.
Service selectors must match Pod labels.
Most Kubernetes debugging starts with describe, logs, events, labels, selectors, and namespaces.
```

---

# Next Lesson

```text
Lesson 10.2 — Local Kubernetes Lab Setup Deep Dive
```

We will cover:

```text
kind cluster config
multi-node local cluster
kubectl contexts
namespaces
kubectl output formats
imperative vs declarative commands
events
logs
describe
exec
port-forward
Kubernetes YAML anatomy
first production-style folder structure
```

[1]: https://kubernetes.io/docs/concepts/overview/?utm_source=chatgpt.com "Overview"
[2]: https://kubernetes.io/docs/concepts/architecture/controller/?utm_source=chatgpt.com "Controllers"
[3]: https://kubernetes.io/docs/concepts/workloads/?utm_source=chatgpt.com "Workloads"
[4]: https://kubernetes.io/docs/concepts/architecture/?utm_source=chatgpt.com "Cluster Architecture"
[5]: https://kubernetes.io/docs/concepts/architecture/nodes/?utm_source=chatgpt.com "Nodes"
[6]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/?utm_source=chatgpt.com "Deployments"
[7]: https://kubernetes.io/docs/concepts/services-networking/service/?utm_source=chatgpt.com "Service"
[8]: https://kubernetes.io/docs/concepts/services-networking/ingress/?utm_source=chatgpt.com "Ingress"
[9]: https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/?utm_source=chatgpt.com "Ingress Controllers"
[10]: https://kubernetes.io/docs/concepts/security/rbac-good-practices/?utm_source=chatgpt.com "Role Based Access Control Good Practices"
[11]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/?utm_source=chatgpt.com "Using RBAC Authorization"
[12]: https://kubernetes.io/docs/tasks/tools/?utm_source=chatgpt.com "Install Tools"
[13]: https://kind.sigs.k8s.io/?utm_source=chatgpt.com "kind - Kubernetes"
[14]: https://kind.sigs.k8s.io/docs/user/quick-start/?utm_source=chatgpt.com "Quick Start - kind - Kubernetes"
