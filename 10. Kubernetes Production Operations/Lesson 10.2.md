# Lesson 10.2 — Local Kubernetes Lab Setup Deep Dive

## kind Multi-Node Cluster, kubectl Contexts, Namespaces, Output Formats, Imperative vs Declarative, Events, Logs, Exec, Port-Forward, YAML Anatomy, and Production Folder Structure

In Lesson 10.1, we learned the Kubernetes mental model.

Now we build a **serious local Kubernetes lab environment** that we will use throughout Modules 10 and 11.

This lesson is very important because many Kubernetes confusions come from weak local setup, namespace mistakes, wrong contexts, bad YAML habits, and not knowing the core `kubectl` inspection commands.

`kind` runs local Kubernetes clusters using Docker container nodes, which makes it useful for local development and CI-style Kubernetes testing. A kind cluster can be configured using a YAML config file. ([kind.sigs.k8s.io][1])

---

# 1. What We Will Build Today

We will create:

```text id="uyr6n8"
multi-node kind cluster
kubectl context workflow
namespace workflow
kubectl command cheat sheet
imperative vs declarative examples
events/logs/describe/exec/port-forward practice
YAML anatomy notes
production-style Kubernetes folder structure
validation script
cleanup script
```

By the end, you should be comfortable with:

```text id="dqk4qh"
kubectl get
kubectl describe
kubectl logs
kubectl exec
kubectl port-forward
kubectl config
kubectl apply
kubectl delete
kubectl explain
kubectl api-resources
kubectl output formats
```

The Kubernetes quick reference documents common `kubectl` commands and flags, and we will turn those commands into a real workflow instead of memorizing them randomly. ([Kubernetes][2])

---

# 2. Why This Lesson Matters

Most beginners fail in Kubernetes not because Kubernetes is impossible.

They fail because they are confused about:

```text id="fkv56n"
Which cluster am I connected to?
Which namespace am I using?
Did I create a Pod or Deployment?
Why does kubectl get pods show nothing?
Where are the logs?
Where are the events?
Is my Service selecting the right Pods?
How do I test an app without Ingress?
How do I inspect generated YAML?
```

A production DevOps engineer must be fast with cluster navigation.

Golden rule:

```text id="ym6huj"
Before troubleshooting Kubernetes, first confirm context, namespace, object kind, labels, events, and logs.
```

---

# 3. Create Lesson Folder

Run:

```bash id="m3ew8a"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.2-local-kubernetes-lab-setup/{kind,manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="f9zoxy"
tree -L 2 10.2-local-kubernetes-lab-setup
```

Expected:

```text id="y36tfl"
10.2-local-kubernetes-lab-setup
├── kind
├── manifests
├── notes
├── reports
├── runbooks
└── scripts
```

---

# 4. Check Existing Cluster

From the previous lesson, you may already have:

```text id="42d04s"
kind cluster: devops-k8s
```

Check:

```bash id="bddfmt"
kind get clusters
kubectl config get-contexts
kubectl current-context
kubectl get nodes
```

If the previous cluster exists and you want a cleaner multi-node cluster for serious labs, delete it:

```bash id="o9dxcj"
kind delete cluster --name devops-k8s
```

This is safe for local labs.

---

# 5. Create Multi-Node kind Cluster Config

Why multi-node?

A single-node cluster is good for basics.

But production Kubernetes has multiple nodes, so we need to understand:

```text id="06onmw"
scheduling
node placement
node labels
taints
resource allocation
DaemonSets
node failure thinking
networking across nodes
```

Create config:

```bash id="zu7e66"
nano 10.2-local-kubernetes-lab-setup/kind/devops-k8s-multinode.yaml
```

Paste:

```yaml id="gg8aqs"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: devops-k8s
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP

  - role: worker
    labels:
      node-role: app
      workload: stateless

  - role: worker
    labels:
      node-role: platform
      workload: system
```

Explanation:

```text id="2zznop"
control-plane:
  runs Kubernetes control plane components

worker:
  runs application workloads

extraPortMappings:
  maps local machine ports to kind node ports

labels:
  useful later for scheduling labs
```

kind’s configuration docs show that kind cluster creation can be customized using a YAML config with `kind: Cluster` and `apiVersion: kind.x-k8s.io/v1alpha4`. ([kind.sigs.k8s.io][3])

---

# 6. Create Multi-Node Cluster

Run:

```bash id="6glyrs"
kind create cluster --config 10.2-local-kubernetes-lab-setup/kind/devops-k8s-multinode.yaml
```

Verify:

```bash id="fem4ps"
kind get clusters
kubectl cluster-info
kubectl get nodes -o wide
```

Expected:

```text id="snser9"
devops-k8s-control-plane
devops-k8s-worker
devops-k8s-worker2
```

Check labels:

```bash id="15jxh0"
kubectl get nodes --show-labels
```

Cleaner view:

```bash id="ox0fyw"
kubectl get nodes \
  -L node-role \
  -L workload
```

---

# 7. Understand kubeconfig and Contexts

`kubectl` talks to a cluster using kubeconfig.

A kubeconfig usually contains:

```text id="9j766b"
clusters:
  where the API server is

users:
  credentials

contexts:
  cluster + user + namespace combination

current-context:
  active context
```

Check your contexts:

```bash id="w3ids9"
kubectl config get-contexts
kubectl config current-context
kubectl config view --minify
```

Set current context explicitly:

```bash id="8eu4r2"
kubectl config use-context kind-devops-k8s
```

Set default namespace later:

```bash id="r4lscg"
kubectl config set-context --current --namespace=dev
```

The official `kubectl config set-context` command can modify a context, including setting its namespace using `--namespace`. ([Kubernetes][4])

---

# 8. Namespace Strategy for Labs

Create three namespaces:

```bash id="v7hw9c"
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace production
```

Check:

```bash id="i1krko"
kubectl get namespaces
```

Set current namespace to `dev`:

```bash id="d6sm6x"
kubectl config set-context --current --namespace=dev
```

Verify:

```bash id="aq2v7a"
kubectl config view --minify | grep namespace
```

Namespaces provide a mechanism for isolating groups of resources within one cluster. Resource names must be unique within a namespace, but not necessarily across namespaces; some resources are namespaced, while others like Nodes and StorageClasses are cluster-scoped. ([Kubernetes][5])

---

# 9. Namespace Confusion Example

Create same object name in different namespaces:

```bash id="rlyfna"
kubectl create deployment hello --image=nginx:1.27-alpine -n dev
kubectl create deployment hello --image=nginx:1.27-alpine -n staging
```

Check:

```bash id="qj2lta"
kubectl get deployments -n dev
kubectl get deployments -n staging
kubectl get deployments -A | grep hello
```

Important:

```text id="p1h697"
hello in dev and hello in staging are different objects.
```

Delete:

```bash id="ptrpai"
kubectl delete deployment hello -n dev
kubectl delete deployment hello -n staging
```

Myth:

```text id="iy6yfh"
Object names must be unique across the whole cluster.
```

Reality:

```text id="03n11r"
Namespaced object names must be unique only inside that namespace.
Cluster-scoped object names must be unique cluster-wide.
```

---

# 10. Create kubectl Notes

Create:

```bash id="9wxkpi"
nano 10.2-local-kubernetes-lab-setup/notes/kubectl-core-workflow.md
```

Paste:

````markdown id="dy9vxl"
# kubectl Core Workflow

## Always Check First

```bash
kubectl config current-context
kubectl config view --minify | grep namespace
kubectl get nodes
kubectl get pods -A
````

## Common Inspection Commands

```bash id="d7ztxy"
kubectl get pods
kubectl get pods -o wide
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl logs -f POD_NAME
kubectl exec -it POD_NAME -- sh
kubectl get events --sort-by=.lastTimestamp
```

## Common Apply/Delete Commands

```bash id="zi7w84"
kubectl apply -f file.yaml
kubectl delete -f file.yaml
```

## Common Output Formats

```bash id="wp8y6w"
kubectl get pod POD_NAME -o yaml
kubectl get pod POD_NAME -o json
kubectl get pods -o wide
kubectl get pods --show-labels
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase
```

## Golden Rule

Never troubleshoot blindly. First check context, namespace, object status, events, and logs.

````

---

# 11. Imperative vs Declarative Kubernetes

This is a very important concept.

## Imperative

You directly tell Kubernetes what to do:

```bash id="kgdvjl"
kubectl create deployment nginx --image=nginx:1.27-alpine
kubectl scale deployment nginx --replicas=3
kubectl delete deployment nginx
````

Good for:

```text id="aajbmh"
quick testing
learning
debugging
generating YAML
```

Bad for:

```text id="t7nyh2"
production history
GitOps
review
repeatability
audit
```

## Declarative

You write YAML and apply it:

```bash id="jtnmg2"
kubectl apply -f deployment.yaml
```

Good for:

```text id="eh0c7b"
production
GitOps
code review
repeatability
environment promotion
rollback
```

Production rule:

```text id="ylfivb"
Use imperative commands for learning and debugging.
Use declarative manifests for production.
```

---

# 12. Generate YAML from Imperative Command

This is a professional trick.

Generate YAML without creating object:

```bash id="vte5b3"
kubectl create deployment demo-nginx \
  --image=nginx:1.27-alpine \
  --replicas=2 \
  --dry-run=client \
  -o yaml
```

Save it:

```bash id="124b3x"
kubectl create deployment demo-nginx \
  --image=nginx:1.27-alpine \
  --replicas=2 \
  --dry-run=client \
  -o yaml \
  > 10.2-local-kubernetes-lab-setup/manifests/generated-deployment.yaml
```

Inspect:

```bash id="khmz37"
cat 10.2-local-kubernetes-lab-setup/manifests/generated-deployment.yaml
```

Apply:

```bash id="s534t7"
kubectl apply -f 10.2-local-kubernetes-lab-setup/manifests/generated-deployment.yaml -n dev
```

Check:

```bash id="kt3y4s"
kubectl get deployment demo-nginx -n dev
kubectl get pods -n dev
```

Delete:

```bash id="pbvpm2"
kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/generated-deployment.yaml -n dev
```

---

# 13. Kubernetes YAML Anatomy

Kubernetes objects are persistent entities in the Kubernetes API, and Kubernetes represents these objects in YAML or JSON. A Kubernetes object usually declares desired state, and the system works to maintain that state. ([Kubernetes][6])

Create notes:

```bash id="w5hlmp"
nano 10.2-local-kubernetes-lab-setup/notes/kubernetes-yaml-anatomy.md
```

Paste:

````markdown id="j9izd0"
# Kubernetes YAML Anatomy

## Required Top-Level Fields

```yaml
apiVersion:
kind:
metadata:
spec:
````

## apiVersion

The API group and version.

Examples:

```yaml
apiVersion: v1
apiVersion: apps/v1
apiVersion: networking.k8s.io/v1
```

## kind

The object type.

Examples:

```yaml
kind: Pod
kind: Deployment
kind: Service
kind: Ingress
kind: ConfigMap
kind: Secret
```

## metadata

Identity and organization.

Common fields:

```yaml
metadata:
  name: app-name
  namespace: dev
  labels:
    app: demo
  annotations:
    owner: platform-team
```

## spec

Desired state written by the user.

Examples:

```yaml
spec:
  replicas: 3
```

## status

Actual state written by Kubernetes.

You normally do not write `status` in manifests.

## Golden Rule

Humans write spec.
Kubernetes writes status.

````

---

# 14. Use `kubectl explain`

`kubectl explain` is one of the best ways to understand YAML fields.

Run:

```bash id="nv6z1x"
kubectl explain pod
kubectl explain pod.spec
kubectl explain deployment
kubectl explain deployment.spec
kubectl explain deployment.spec.template.spec.containers
kubectl explain service.spec
````

Use recursive view:

```bash id="sqnk70"
kubectl explain deployment --recursive | less
```

This helps when you ask:

```text id="cui35w"
Where does this field go in YAML?
Is this field valid?
What does this field mean?
```

---

# 15. Create Practice App Deployment

Create:

```bash id="qu31vh"
nano 10.2-local-kubernetes-lab-setup/manifests/whoami-deployment.yaml
```

Paste:

```yaml id="bghppf"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: dev
  labels:
    app: whoami
    tier: backend
    environment: dev
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
      environment: dev
  template:
    metadata:
      labels:
        app: whoami
        tier: backend
        environment: dev
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10
          ports:
            - containerPort: 80
```

Apply:

```bash id="hvd35p"
kubectl apply -f 10.2-local-kubernetes-lab-setup/manifests/whoami-deployment.yaml
```

Check:

```bash id="hf4ydx"
kubectl get deployment whoami -n dev
kubectl get pods -n dev
kubectl get pods -n dev -o wide
kubectl get pods -n dev --show-labels
```

---

# 16. Create Service

Create:

```bash id="z91ifu"
nano 10.2-local-kubernetes-lab-setup/manifests/whoami-service.yaml
```

Paste:

```yaml id="y0dzfm"
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: dev
  labels:
    app: whoami
spec:
  type: ClusterIP
  selector:
    app: whoami
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply:

```bash id="l5vgzx"
kubectl apply -f 10.2-local-kubernetes-lab-setup/manifests/whoami-service.yaml
```

Check:

```bash id="2j37rm"
kubectl get svc -n dev
kubectl describe svc whoami -n dev
kubectl get endpoints whoami -n dev
```

Critical rule:

```text id="wu16g4"
Service selector must match Pod labels.
If selector does not match, Service has no endpoints.
```

---

# 17. Test with Port Forward

Port-forward is one of the most useful local debugging commands.

Run:

```bash id="enbo7j"
kubectl port-forward -n dev svc/whoami 8080:80
```

In another terminal:

```bash id="v2eqt5"
curl http://127.0.0.1:8080
```

Expected output includes request details.

Flow:

```text id="3wut6j"
Your laptop
  ↓
kubectl port-forward
  ↓
Kubernetes API connection
  ↓
Service whoami
  ↓
Pod
```

Stop port-forward with:

```text id="wzjl3h"
Ctrl + C
```

Myth:

```text id="ls3fqb"
I need Ingress or LoadBalancer to test every app.
```

Reality:

```text id="tw7zg5"
For local testing, kubectl port-forward is often enough.
```

---

# 18. Test with Exec

Get Pod name:

```bash id="m9g6c2"
kubectl get pods -n dev -l app=whoami
```

Exec into Pod:

```bash id="g6qsze"
POD_NAME="$(kubectl get pods -n dev -l app=whoami -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -it "$POD_NAME" -n dev -- sh
```

Inside:

```sh id="azod44"
hostname
ip addr
env
exit
```

If the image does not have shell tools, use a debug Pod instead:

```bash id="8iqrm7"
kubectl run debug-shell \
  -n dev \
  --image=busybox:1.36 \
  --rm -it \
  --restart=Never \
  -- sh
```

Inside debug Pod:

```sh id="87zvfp"
wget -qO- http://whoami
nslookup whoami
exit
```

---

# 19. Logs

Get logs:

```bash id="ot9u3x"
kubectl logs -n dev deployment/whoami
```

Follow logs:

```bash id="eq13p9"
kubectl logs -n dev deployment/whoami -f
```

Logs for one Pod:

```bash id="k0l8xe"
kubectl logs -n dev "$POD_NAME"
```

Previous container logs after crash:

```bash id="d2a2ms"
kubectl logs -n dev "$POD_NAME" --previous
```

Important:

```text id="4crli3"
For CrashLoopBackOff debugging, --previous is often critical.
```

---

# 20. Describe

Describe Deployment:

```bash id="oh6ok6"
kubectl describe deployment whoami -n dev
```

Describe Pod:

```bash id="p89iea"
kubectl describe pod "$POD_NAME" -n dev
```

Describe Service:

```bash id="exn679"
kubectl describe svc whoami -n dev
```

Look for:

```text id="te93ef"
Events
Conditions
Image
Node
Labels
Selectors
Ports
Environment
Volumes
Readiness
Liveness
```

Professional habit:

```text id="5smgzr"
When something is broken, kubectl describe is usually the first deep inspection command.
```

---

# 21. Events

Events show what Kubernetes is doing or complaining about.

Run:

```bash id="jnpwcc"
kubectl get events -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

All namespaces:

```bash id="763a06"
kubectl get events -A --sort-by=.lastTimestamp
```

Events help detect:

```text id="xa1z7z"
image pull failures
scheduling failures
probe failures
volume mount errors
node issues
backoff behavior
```

Module 11 will use events heavily.

---

# 22. Output Formats

Normal:

```bash id="jcrqaj"
kubectl get pods -n dev
```

Wide:

```bash id="gsgz6m"
kubectl get pods -n dev -o wide
```

YAML:

```bash id="386snd"
kubectl get deployment whoami -n dev -o yaml
```

JSON:

```bash id="1092wr"
kubectl get deployment whoami -n dev -o json
```

JSONPath:

```bash id="pmfdzt"
kubectl get pods -n dev -o jsonpath='{.items[*].metadata.name}'
echo
```

Custom columns:

```bash id="a6gx0e"
kubectl get pods -n dev \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PHASE:.status.phase,POD_IP:.status.podIP
```

Sort:

```bash id="f1d81e"
kubectl get pods -n dev --sort-by=.metadata.creationTimestamp
```

Why this matters:

```text id="c3zzzo"
Production clusters have many objects.
You must filter and format output quickly.
```

---

# 23. Labels and Selectors Practice

Get by label:

```bash id="b2yatg"
kubectl get pods -n dev -l app=whoami
kubectl get pods -n dev -l environment=dev
kubectl get pods -n dev -l app=whoami,tier=backend
```

Show labels:

```bash id="nr4ajs"
kubectl get pods -n dev --show-labels
```

Add label to namespace:

```bash id="yk738a"
kubectl label namespace dev purpose=learning
```

Check:

```bash id="pvpm79"
kubectl get namespace dev --show-labels
```

Remove label:

```bash id="xyp6l8"
kubectl label namespace dev purpose-
```

Important:

```text id="m36w74"
Labels are for selection.
Annotations are for metadata.
```

---

# 24. Create Intentional Service Selector Bug

This teaches a very common real-world issue.

Patch Service selector to wrong label:

```bash id="b1fibm"
kubectl patch svc whoami -n dev \
  -p '{"spec":{"selector":{"app":"wrong-label"}}}'
```

Check endpoints:

```bash id="o05ed1"
kubectl get endpoints whoami -n dev
```

You will see no endpoints.

Try port-forward:

```bash id="ojactf"
kubectl port-forward -n dev svc/whoami 8080:80
```

It may fail or route nowhere.

Fix:

```bash id="65p2lm"
kubectl apply -f 10.2-local-kubernetes-lab-setup/manifests/whoami-service.yaml
```

Check:

```bash id="rsf59x"
kubectl get endpoints whoami -n dev
```

Lesson:

```text id="0g4w72"
Service problems are often label selector problems.
```

---

# 25. Create Intentional Image Pull Bug

Create bad deployment:

```bash id="mnzg5l"
nano 10.2-local-kubernetes-lab-setup/manifests/bad-image-deployment.yaml
```

Paste:

```yaml id="wbvky8"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-image
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-image
  template:
    metadata:
      labels:
        app: bad-image
    spec:
      containers:
        - name: bad-image
          image: nginx:this-tag-does-not-exist
```

Apply:

```bash id="6m9048"
kubectl apply -f 10.2-local-kubernetes-lab-setup/manifests/bad-image-deployment.yaml
```

Check:

```bash id="ze34ub"
kubectl get pods -n dev
kubectl describe pod -n dev -l app=bad-image
kubectl get events -n dev --sort-by=.lastTimestamp
```

You should see:

```text id="q7jo3e"
ErrImagePull
ImagePullBackOff
```

Delete:

```bash id="5y782f"
kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/bad-image-deployment.yaml
```

This is a preview of Module 11.

---

# 26. Create Production-Style Folder Structure

Now create a structure we will grow through Module 10:

```bash id="awyg4b"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p apps/demo-node-api/{base,overlays/dev,overlays/staging,overlays/production}
mkdir -p platform/{ingress,monitoring,rbac,network-policy,storage}
mkdir -p scripts runbooks reports
```

Create README:

```bash id="azs7z7"
nano README.md
```

Paste:

````markdown id="fe5ysj"
# Module 10 — Kubernetes Production Operations

## Goal

Learn Kubernetes from fundamentals to production operations.

## Structure

```text
apps/
  demo-node-api/
    base/
    overlays/
      dev/
      staging/
      production/

platform/
  ingress/
  monitoring/
  rbac/
  network-policy/
  storage/

scripts/
runbooks/
reports/
````

## Principles

* Use declarative manifests.
* Separate base from environment overlays.
* Use namespaces intentionally.
* Validate with kubectl before production.
* Treat labels/selectors as critical infrastructure.
* Prefer least privilege.
* Debug with describe, logs, events, and port-forward.

````

---

# 27. Create Cluster Info Script

Create:

```bash id="oj2pyp"
nano scripts/k8s-cluster-info.sh
````

Paste:

```bash id="kwcs6e"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Kubernetes Cluster Info ====="

echo
echo "Current context:"
kubectl config current-context

echo
echo "Current namespace:"
kubectl config view --minify --output 'jsonpath={..namespace}'
echo

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "Namespaces:"
kubectl get namespaces

echo
echo "Pods across all namespaces:"
kubectl get pods -A

echo
echo "Services across all namespaces:"
kubectl get svc -A

echo
echo "Recent events:"
kubectl get events -A --sort-by=.lastTimestamp | tail -n 20
```

Make executable:

```bash id="udwkwc"
chmod +x scripts/k8s-cluster-info.sh
```

Run:

```bash id="t5fp85"
./scripts/k8s-cluster-info.sh
```

---

# 28. Create kubectl Troubleshooting Runbook

Create:

```bash id="qob31p"
nano 10.2-local-kubernetes-lab-setup/runbooks/kubectl-troubleshooting-runbook.md
```

Paste:

````markdown id="5vfz1o"
# kubectl Troubleshooting Runbook

## Step 1 — Confirm Context

```bash
kubectl config current-context
kubectl config get-contexts
````

## Step 2 — Confirm Namespace

```bash id="ms7k75"
kubectl config view --minify | grep namespace
kubectl get pods -A
```

## Step 3 — Check Object

```bash id="a7040t"
kubectl get deployment -n NAMESPACE
kubectl get pods -n NAMESPACE
kubectl get svc -n NAMESPACE
```

## Step 4 — Describe

```bash id="v0ywbv"
kubectl describe pod POD_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE
```

## Step 5 — Logs

```bash id="7p5yt5"
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

## Step 6 — Events

```bash id="lmlggf"
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Step 7 — Service Debug

```bash id="787u8b"
kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get pods -n NAMESPACE --show-labels
kubectl describe svc SERVICE_NAME -n NAMESPACE
```

## Step 8 — Temporary Debug Pod

```bash id="zg7mo0"
kubectl run debug-shell \
  -n NAMESPACE \
  --image=busybox:1.36 \
  --rm -it \
  --restart=Never \
  -- sh
```

## Golden Rule

Most Kubernetes issues are visible in one of these places:

* status
* describe output
* logs
* events
* labels/selectors
* namespace/context

````

---

# 29. Lesson 10.2 Validation Script

Create:

```bash id="uosgl0"
nano 10.2-local-kubernetes-lab-setup/scripts/validate-lesson-10-2.sh
````

Paste:

```bash id="e188sk"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.2 ====="

kubectl version --client >/dev/null
kind get clusters | grep -q "devops-k8s"

kubectl cluster-info >/dev/null

NODE_COUNT="$(kubectl get nodes --no-headers | wc -l)"
if [ "$NODE_COUNT" -lt 3 ]; then
  echo "ERROR: expected at least 3 nodes for multi-node kind cluster"
  exit 1
fi

kubectl get namespace dev >/dev/null
kubectl get namespace staging >/dev/null
kubectl get namespace production >/dev/null

kubectl get deployment whoami -n dev >/dev/null
kubectl get service whoami -n dev >/dev/null

ENDPOINTS="$(kubectl get endpoints whoami -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: whoami service has no endpoints"
  exit 1
fi

test -f 10.2-local-kubernetes-lab-setup/notes/kubectl-core-workflow.md
test -f 10.2-local-kubernetes-lab-setup/notes/kubernetes-yaml-anatomy.md
test -f 10.2-local-kubernetes-lab-setup/runbooks/kubectl-troubleshooting-runbook.md
test -x scripts/k8s-cluster-info.sh

echo "Lesson 10.2 validation passed."
```

Make executable:

```bash id="tj2h9r"
chmod +x 10.2-local-kubernetes-lab-setup/scripts/validate-lesson-10-2.sh
```

Run:

```bash id="29zl19"
./10.2-local-kubernetes-lab-setup/scripts/validate-lesson-10-2.sh
```

---

# 30. Cleanup Script

Create:

```bash id="obfusq"
nano 10.2-local-kubernetes-lab-setup/scripts/cleanup-lesson-10-2.sh
```

Paste:

```bash id="jwsuex"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.2 ====="

kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/whoami-service.yaml --ignore-not-found=true
kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/whoami-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/generated-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.2-local-kubernetes-lab-setup/manifests/bad-image-deployment.yaml --ignore-not-found=true

echo "Lesson 10.2 resources cleaned."
echo "Namespaces and cluster kept for next lessons."
```

Make executable:

```bash id="rip31c"
chmod +x 10.2-local-kubernetes-lab-setup/scripts/cleanup-lesson-10-2.sh
```

Run only if you want cleanup:

```bash id="w0se9x"
./10.2-local-kubernetes-lab-setup/scripts/cleanup-lesson-10-2.sh
```

For next lessons, keep the cluster and namespaces.

---

# 31. Common Mistakes Cleared

## Mistake 1: Wrong Context

Symptom:

```text id="vz26or"
kubectl get pods shows unexpected resources.
```

Check:

```bash id="j2eqlk"
kubectl config current-context
```

Fix:

```bash id="6zov51"
kubectl config use-context kind-devops-k8s
```

---

## Mistake 2: Wrong Namespace

Symptom:

```text id="dzwhty"
kubectl get pods shows No resources found.
```

Check all namespaces:

```bash id="axg91x"
kubectl get pods -A
```

Set namespace:

```bash id="b9re4f"
kubectl config set-context --current --namespace=dev
```

---

## Mistake 3: Service Has No Endpoints

Symptom:

```bash id="ffnl1l"
kubectl get endpoints whoami -n dev
```

shows empty.

Check labels:

```bash id="hv22xg"
kubectl get pods -n dev --show-labels
kubectl describe svc whoami -n dev
```

Fix selector mismatch.

---

## Mistake 4: Editing Generated YAML Without Understanding Fields

Use:

```bash id="ld6c07"
kubectl explain deployment.spec.template.spec.containers
```

Do not guess YAML structure.

---

## Mistake 5: Debugging Only with Logs

Logs are not enough.

Use:

```bash id="18unyt"
kubectl describe pod POD_NAME -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

Many Kubernetes problems are not application log problems. They are scheduling, image, networking, or configuration problems.

---

# 32. Production Engineer Workflow

When given any Kubernetes issue, follow this order:

```text id="ol91hp"
1. Confirm context
2. Confirm namespace
3. Get resource status
4. Describe resource
5. Check events
6. Check logs
7. Check labels/selectors
8. Check endpoints
9. Test with port-forward
10. Exec/debug from inside cluster
```

This workflow will become your troubleshooting backbone.

---

# 33. Commit Lesson 10.2

From repo root:

```bash id="rp0v9p"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add local Kubernetes lab setup deep dive"

git push
```

---

# 34. Interview Explanation

Use this:

```text id="vjfk3u"
For local Kubernetes learning and CI-style testing, I use kind to create multi-node clusters backed by Docker container nodes. I manage access through kubectl contexts and organize resources with namespaces. For day-to-day operations, I use kubectl get, describe, logs, events, exec, and port-forward to inspect workloads and troubleshoot issues.

I prefer declarative YAML for production because it is repeatable and reviewable, while imperative kubectl commands are useful for quick testing, debugging, and generating starter manifests. I also pay close attention to labels and selectors because Services, Deployments, and many Kubernetes controllers depend on them for correct object targeting.
```

Resume version:

```text id="66c4cf"
Built a multi-node kind Kubernetes lab with kubectl context management, namespace workflows, declarative manifests, service debugging, port-forward testing, event/log inspection, validation scripts, and production-style Kubernetes project structure.
```

---

# 35. Today’s Core Rules

```text id="a2v10m"
Always check current context.
Always check namespace.
Use -A when unsure.
Use declarative YAML for production.
Use imperative commands for quick testing and YAML generation.
Service selectors must match Pod labels.
kubectl describe shows events and object details.
kubectl logs shows application output.
kubectl events show cluster-level problems.
kubectl port-forward is excellent for local testing.
kubectl exec helps debug from inside a Pod.
kubectl explain helps write correct YAML.
Do not troubleshoot Kubernetes blindly.
```

---

# Next Lesson

```text id="06ansc"
Lesson 10.3 — Pods, Labels, Annotations, Selectors, and YAML Anatomy Deep Dive
```

We will cover:

```text id="gwqtbx"
Pod lifecycle
Pod phases
container states
restartPolicy
labels vs annotations
selector mechanics
ownerReferences
generatedName
YAML schema patterns
init containers
sidecar mental model
multi-container Pods
debug Pods
common Pod mistakes
production Pod manifest standards
```

[1]: https://kind.sigs.k8s.io/?utm_source=chatgpt.com "kind"
[2]: https://kubernetes.io/docs/reference/kubectl/quick-reference/?utm_source=chatgpt.com "kubectl Quick Reference"
[3]: https://kind.sigs.k8s.io/docs/user/configuration/?utm_source=chatgpt.com "kind – Configuration - Kubernetes"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_set-context/?utm_source=chatgpt.com "kubectl config set-context"
[5]: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/?utm_source=chatgpt.com "Namespaces"
[6]: https://kubernetes.io/docs/concepts/overview/working-with-objects/?utm_source=chatgpt.com "Objects In Kubernetes"
