# Lesson 10.16 — Production Hardening: NetworkPolicy, Pod Security, Image Policy, Admission Control, and Runtime Safety

In Lesson 10.15, you learned **events, logs, metrics, Prometheus, Grafana, Loki concepts, RED/USE metrics, and production debugging**.

Now we move into Kubernetes hardening.

This lesson answers:

```text id="w6ru6a"
How do we stop every Pod from talking to every other Pod?
How do we prevent containers from running as root?
How do we restrict Linux capabilities?
How do we make root filesystems read-only?
How do we enforce safe image practices?
How do we block unsafe manifests before they enter the cluster?
How do we create production guardrails for demo-node-api?
```

Kubernetes hardening is not one feature. It is a layered approach using **NetworkPolicy**, **Pod Security Standards**, `securityContext`, image rules, admission controllers, policy-as-code, and runtime detection. NetworkPolicy controls Pod network traffic, Pod Security Standards define safe Pod isolation levels, and admission controllers can intercept API requests after authentication/authorization but before persistence. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="s8n3ce"
10.16.1   Production hardening mental model
10.16.2   Default Kubernetes risk model
10.16.3   NetworkPolicy mental model
10.16.4   Default deny ingress
10.16.5   Default deny egress
10.16.6   Allow frontend-to-backend traffic
10.16.7   Allow backend-to-database traffic
10.16.8   Allow DNS egress
10.16.9   Pod Security Standards
10.16.10  Pod Security Admission
10.16.11  privileged, baseline, restricted
10.16.12  securityContext
10.16.13  runAsNonRoot
10.16.14  readOnlyRootFilesystem
10.16.15  drop Linux capabilities
10.16.16  seccompProfile
10.16.17  image tags and digests
10.16.18  admission controllers
10.16.19  Kyverno and OPA Gatekeeper concepts
10.16.20  runtime security basics
10.16.21  production hardening policy for demo-node-api
10.16.22  validation script
10.16.23  cleanup script
```

---

# 2. Create Lesson Folder

```bash id="vb8v5s"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.16-production-hardening/{manifests,scripts,notes,runbooks,reports,policies}
```

Check:

```bash id="iwzthd"
tree -L 2 10.16-production-hardening
```

---

# 3. Production Hardening Mental Model

Production hardening means reducing the damage an attacker, bug, or misconfiguration can cause.

Think in layers:

```text id="v5qcs0"
Layer 1:
  Only allowed traffic flows work.

Layer 2:
  Containers run with minimum Linux privileges.

Layer 3:
  Workloads cannot casually access Kubernetes API.

Layer 4:
  Unsafe manifests are rejected before deployment.

Layer 5:
  Images are scanned, pinned, signed, and trusted.

Layer 6:
  Runtime behavior is monitored for suspicious activity.
```

Simple goal:

```text id="vlem59"
Even if one Pod is compromised, blast radius should be limited.
```

Bad cluster posture:

```text id="rpyzjb"
every Pod can talk to every Pod
containers run as root
root filesystem is writable
all Linux capabilities are available
default ServiceAccount token mounted
latest image tags are allowed
secrets are broadly readable
no admission policy
no runtime detection
```

Better posture:

```text id="r6wgyz"
deny-by-default networking
least-privilege ServiceAccounts
run as non-root
read-only root filesystem
drop all capabilities
seccomp enabled
image tags controlled
digests preferred
admission policy enforced
runtime anomalies monitored
```

---

# 4. Create Notes

```bash id="yfliq5"
nano 10.16-production-hardening/notes/hardening-mental-model.md
```

Paste:

```markdown id="sm0kqz"
# Kubernetes Production Hardening Mental Model

## Goal

Reduce blast radius and prevent unsafe workloads from entering or harming the cluster.

## Main Layers

1. NetworkPolicy
2. Pod Security Standards
3. securityContext
4. ServiceAccount least privilege
5. image policy
6. admission control
7. runtime monitoring

## Golden Rules

- Deny by default.
- Allow only required traffic.
- Run as non-root.
- Drop Linux capabilities.
- Use read-only root filesystem where possible.
- Disable ServiceAccount token automount if not needed.
- Avoid mutable image tags.
- Enforce policy before deployment.
- Monitor runtime behavior.
```

---

# 5. Default Kubernetes Network Risk

By default, many clusters allow broad Pod-to-Pod communication unless NetworkPolicy is implemented and policies are applied.

NetworkPolicy is a namespaced Kubernetes API object that defines how selected Pods are allowed to communicate with other Pods, namespaces, or IP blocks. Kubernetes also notes that NetworkPolicies require a network plugin or CNI that supports enforcement; otherwise, creating the objects alone may not affect traffic. ([Kubernetes][1])

Important for your local kind cluster:

```text id="shvivf"
If NetworkPolicies do not seem to block traffic, your CNI may not enforce them.
For real enforcement, use a CNI such as Calico, Cilium, or another provider that supports NetworkPolicy.
```

Calico and Cilium both provide Kubernetes NetworkPolicy enforcement; Cilium enforces policies through its Cilium agent on each node. ([docs.tigera.io][2])

For this lesson, we will still create correct Kubernetes NetworkPolicy YAML. If your local CNI does not enforce it, treat the manifests as production patterns and test them later on a policy-capable CNI.

---

# 6. Create Hardening Lab Namespace

Use a separate namespace so we do not break earlier labs.

```bash id="utw4rf"
kubectl create namespace hardening-lab --dry-run=client -o yaml | kubectl apply -f -
```

Label it:

```bash id="p4d3nl"
kubectl label namespace hardening-lab \
  environment=dev \
  purpose=hardening-lab \
  --overwrite
```

Check:

```bash id="ll3ygg"
kubectl get namespace hardening-lab --show-labels
```

---

# 7. Create Three-Tier Demo App

We will create:

```text id="xo50f0"
frontend
backend
database
```

Traffic should eventually be:

```text id="ae9tqv"
frontend → backend
backend → database
backend → DNS
frontend → DNS
```

Everything else should be denied.

Create:

```bash id="g2tnkn"
nano 10.16-production-hardening/manifests/three-tier-demo.yaml
```

Paste:

```yaml id="9aa1uk"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: hardening-lab
  labels:
    app: frontend
    tier: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
        - name: frontend
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
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: hardening-lab
  labels:
    app: frontend
spec:
  selector:
    app: frontend
    tier: frontend
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: hardening-lab
  labels:
    app: backend
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
        - name: backend
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=backend-ok"
          ports:
            - name: http
              containerPort: 8080
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
  name: backend
  namespace: hardening-lab
  labels:
    app: backend
spec:
  selector:
    app: backend
    tier: backend
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: hardening-lab
  labels:
    app: database
    tier: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
        - name: database
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:5432"
            - "-text=database-ok"
          ports:
            - name: db
              containerPort: 5432
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
  name: database
  namespace: hardening-lab
  labels:
    app: database
spec:
  selector:
    app: database
    tier: database
  ports:
    - name: db
      port: 5432
      targetPort: db
```

Apply:

```bash id="d3kycz"
kubectl apply -f 10.16-production-hardening/manifests/three-tier-demo.yaml
```

Check:

```bash id="c318wv"
kubectl rollout status deployment/frontend -n hardening-lab
kubectl rollout status deployment/backend -n hardening-lab
kubectl rollout status deployment/database -n hardening-lab

kubectl get pods,svc -n hardening-lab -o wide
```

---

# 8. Create Debug Pod

Create a temporary curl Pod:

```bash id="rmcwzv"
kubectl run net-debug \
  -n hardening-lab \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  -- sleep 3600
```

Check:

```bash id="plqdtu"
kubectl get pod net-debug -n hardening-lab
```

Test before policies:

```bash id="mxyz3k"
kubectl exec -n hardening-lab net-debug -- curl -sS http://frontend
kubectl exec -n hardening-lab net-debug -- curl -sS http://backend
kubectl exec -n hardening-lab net-debug -- curl -sS http://database:5432
```

Before NetworkPolicy enforcement, these may all work.

---

# 9. Default Deny Ingress

A default deny ingress policy blocks incoming traffic to selected Pods unless another policy allows it.

Create:

```bash id="qgv4v4"
nano 10.16-production-hardening/manifests/default-deny-ingress.yaml
```

Paste:

```yaml id="fh56px"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: hardening-lab
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Apply:

```bash id="wwj9u9"
kubectl apply -f 10.16-production-hardening/manifests/default-deny-ingress.yaml
```

Check:

```bash id="c46ftw"
kubectl get networkpolicy -n hardening-lab
kubectl describe networkpolicy default-deny-ingress -n hardening-lab
```

If your CNI enforces NetworkPolicy, this should block incoming traffic to all Pods in the namespace unless explicitly allowed.

Test:

```bash id="jq7kv0"
kubectl exec -n hardening-lab net-debug -- curl -m 3 -sS http://backend || true
kubectl exec -n hardening-lab net-debug -- curl -m 3 -sS http://database:5432 || true
```

Expected with enforcing CNI:

```text id="13w6c3"
Requests timeout or fail.
```

Expected without enforcing CNI:

```text id="fb5nvx"
Requests may still work.
That means your CNI is not enforcing NetworkPolicy.
```

---

# 10. Allow Frontend to Backend

Create a policy that allows Pods labeled `tier=frontend` to call backend on port 80.

```bash id="j2e53z"
nano 10.16-production-hardening/manifests/allow-frontend-to-backend.yaml
```

Paste:

```yaml id="miq1j4"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: hardening-lab
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

```bash id="7opks4"
kubectl apply -f 10.16-production-hardening/manifests/allow-frontend-to-backend.yaml
```

Test using frontend Pod:

```bash id="9v12jb"
FRONTEND_POD="$(kubectl get pod -n hardening-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n hardening-lab "$FRONTEND_POD" -- wget -qO- http://backend || true
```

Expected with enforcing CNI:

```text id="kpue07"
backend-ok
```

Test from debug Pod:

```bash id="2ir1cf"
kubectl exec -n hardening-lab net-debug -- curl -m 3 -sS http://backend || true
```

Expected with enforcing CNI:

```text id="33qso5"
debug Pod should still be blocked because it is not tier=frontend.
```

---

# 11. Allow Backend to Database

Create:

```bash id="ajb08h"
nano 10.16-production-hardening/manifests/allow-backend-to-database.yaml
```

Paste:

```yaml id="lpsybd"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: hardening-lab
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 5432
```

Apply:

```bash id="qnbuvn"
kubectl apply -f 10.16-production-hardening/manifests/allow-backend-to-database.yaml
```

Test from backend:

```bash id="a6tams"
BACKEND_POD="$(kubectl get pod -n hardening-lab -l app=backend -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n hardening-lab "$BACKEND_POD" -- wget -qO- http://database:5432 || true
```

Expected with enforcing CNI:

```text id="5wtkls"
database-ok
```

Test from frontend:

```bash id="xdx66r"
kubectl exec -n hardening-lab "$FRONTEND_POD" -- wget -T 3 -qO- http://database:5432 || true
```

Expected with enforcing CNI:

```text id="115bup"
frontend should not be able to access database directly.
```

Production rule:

```text id="ir7i74"
Frontend should not talk directly to database.
Only backend should talk to database.
```

---

# 12. Default Deny Egress

Egress controls outgoing traffic from selected Pods.

Create:

```bash id="8maq0x"
nano 10.16-production-hardening/manifests/default-deny-egress.yaml
```

Paste:

```yaml id="rc4tr0"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: hardening-lab
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

Apply:

```bash id="gkjd11"
kubectl apply -f 10.16-production-hardening/manifests/default-deny-egress.yaml
```

Important:

```text id="3dbrc1"
Default deny egress is powerful.
It can break DNS, package downloads, external APIs, databases, and monitoring until explicit egress rules are added.
```

---

# 13. Allow DNS Egress

Most Pods need DNS to resolve service names.

CoreDNS usually runs in `kube-system` and is commonly labeled `k8s-app=kube-dns`.

Check:

```bash id="xxhsx1"
kubectl get pods -n kube-system --show-labels | grep -E 'coredns|kube-dns'
```

Create policy:

```bash id="zcr0i3"
nano 10.16-production-hardening/manifests/allow-dns-egress.yaml
```

Paste:

```yaml id="4n13ak"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: hardening-lab
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Apply:

```bash id="58el0t"
kubectl apply -f 10.16-production-hardening/manifests/allow-dns-egress.yaml
```

---

# 14. Allow Frontend Egress to Backend

Default deny egress blocks frontend from initiating traffic unless we allow it.

Create:

```bash id="0f0io4"
nano 10.16-production-hardening/manifests/allow-frontend-egress-backend.yaml
```

Paste:

```yaml id="8f7dzz"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-backend
  namespace: hardening-lab
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

```bash id="6fdxvf"
kubectl apply -f 10.16-production-hardening/manifests/allow-frontend-egress-backend.yaml
```

---

# 15. Allow Backend Egress to Database

Create:

```bash id="ult70b"
nano 10.16-production-hardening/manifests/allow-backend-egress-database.yaml
```

Paste:

```yaml id="sq6agy"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-egress-database
  namespace: hardening-lab
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              tier: database
      ports:
        - protocol: TCP
          port: 5432
```

Apply:

```bash id="5ev5gr"
kubectl apply -f 10.16-production-hardening/manifests/allow-backend-egress-database.yaml
```

Test again:

```bash id="m06no6"
kubectl exec -n hardening-lab "$FRONTEND_POD" -- wget -T 3 -qO- http://backend || true
kubectl exec -n hardening-lab "$BACKEND_POD" -- wget -T 3 -qO- http://database:5432 || true
kubectl exec -n hardening-lab "$FRONTEND_POD" -- wget -T 3 -qO- http://database:5432 || true
```

Expected with enforcing CNI:

```text id="snhd8j"
frontend → backend: allowed
backend → database: allowed
frontend → database: denied
```

---

# 16. NetworkPolicy Debugging Checklist

NetworkPolicy bugs usually come from:

```text id="jxw8lr"
wrong namespace
wrong pod labels
wrong selector
wrong port
wrong protocol
missing DNS egress
CNI does not enforce NetworkPolicy
Ingress allowed but egress denied
Egress allowed but ingress denied
```

Useful commands:

```bash id="sl2jqm"
kubectl get networkpolicy -n hardening-lab
kubectl describe networkpolicy -n hardening-lab

kubectl get pods -n hardening-lab --show-labels
kubectl get namespace --show-labels

kubectl get events -n hardening-lab --sort-by=.lastTimestamp
```

Production rule:

```text id="6qwq87"
For a connection to work under deny-by-default policy, both source egress and destination ingress may need to be allowed.
```

---

# 17. Pod Security Standards

Kubernetes defines three Pod Security Standards:

```text id="9x4d96"
Privileged
Baseline
Restricted
```

The standards are cumulative and cover a spectrum from highly permissive to strongly restricted; Kubernetes documents them as policy profiles for Pod isolation. ([Kubernetes][3])

Simple meaning:

```text id="c12qw4"
Privileged:
  mostly unrestricted, for trusted system workloads

Baseline:
  blocks known privilege escalations while allowing common workloads

Restricted:
  strongly hardened, follows current Pod hardening best practices
```

Production rule:

```text id="xzrrmk"
Application namespaces should aim for restricted.
System namespaces may need baseline or privileged depending on workload.
```

---

# 18. Pod Security Admission

Pod Security Admission is the built-in admission controller that can enforce Pod Security Standards at namespace level. It became stable in Kubernetes v1.25. ([Kubernetes][4])

Modes:

```text id="y9h4ks"
enforce:
  reject Pods that violate policy

audit:
  record audit annotations for violations

warn:
  show warnings to the user
```

Typical production pattern:

```text id="caupn3"
dev:
  warn=restricted
  audit=restricted

staging:
  warn=restricted
  audit=restricted
  enforce=baseline

production:
  enforce=restricted where workloads are ready
```

For learning, use warn/audit first.

Label namespace:

```bash id="ixdq4k"
kubectl label namespace hardening-lab \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
```

Check:

```bash id="uhh94z"
kubectl get namespace hardening-lab --show-labels
```

---

# 19. Insecure Pod Demo

Create an intentionally insecure Pod.

```bash id="e8hpyh"
nano 10.16-production-hardening/manifests/insecure-pod.yaml
```

Paste:

```yaml id="csfb39"
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: hardening-lab
  labels:
    app: insecure-pod
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        privileged: true
```

Apply:

```bash id="x3u8em"
kubectl apply -f 10.16-production-hardening/manifests/insecure-pod.yaml || true
```

If namespace has only `warn` and `audit`, it may be created but warnings should appear.

Clean:

```bash id="pg7q6h"
kubectl delete -f 10.16-production-hardening/manifests/insecure-pod.yaml --ignore-not-found=true
```

Do not run privileged Pods in application namespaces.

---

# 20. securityContext Mental Model

A `securityContext` defines privilege and access control settings for a Pod or container. Kubernetes documents settings such as discretionary access control, SELinux, privileged/unprivileged mode, Linux capabilities, AppArmor, seccomp, `allowPrivilegeEscalation`, and read-only root filesystem. ([Kubernetes][5])

There are two levels:

```text id="13hnkf"
Pod securityContext:
  applies to all containers where relevant

Container securityContext:
  applies to one container
```

Common hardening fields:

```yaml id="0so71t"
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```

Container-level:

```yaml id="iif9wf"
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

---

# 21. Secure Pod Demo

Create:

```bash id="ltzfrd"
nano 10.16-production-hardening/manifests/secure-pod.yaml
```

Paste:

```yaml id="ek0i11"
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: hardening-lab
  labels:
    app: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo secure pod running; sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
```

Apply:

```bash id="e1t3ch"
kubectl apply -f 10.16-production-hardening/manifests/secure-pod.yaml
```

Check:

```bash id="8bwa2p"
kubectl get pod secure-pod -n hardening-lab
kubectl describe pod secure-pod -n hardening-lab
```

Test identity:

```bash id="nzzmz8"
kubectl exec -n hardening-lab secure-pod -- id
```

Expected:

```text id="u30s1c"
uid=10001
gid=10001
```

Test read-only root filesystem:

```bash id="01xq98"
kubectl exec -n hardening-lab secure-pod -- sh -c 'touch /test-file' || true
```

Expected:

```text id="q8mk52"
Read-only filesystem error.
```

---

# 22. Handling Writable Paths with readOnlyRootFilesystem

Many apps need writable directories for temporary files.

Pattern:

```text id="phmxoh"
root filesystem:
  read-only

/tmp:
  writable emptyDir

app cache:
  writable emptyDir if needed
```

Example:

```yaml id="n54n1p"
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

Production rule:

```text id="oacdkx"
Make root filesystem read-only and explicitly mount only required writable paths.
```

---

# 23. Image Tags and Digests

Kubernetes image references can use tags or digests. Tags can move, while digests are immutable hashes of image content. Kubernetes documentation states that tags identify versions, but digests uniquely identify a specific image content hash and are immutable. ([Kubernetes][6])

Bad:

```yaml id="b3dlmy"
image: demo-node-api:latest
```

Better:

```yaml id="z867g4"
image: demo-node-api:1.4.2
```

Best for strict production:

```yaml id="06qrqw"
image: demo-node-api@sha256:abcdef...
```

Why avoid `latest`?

```text id="ln6gid"
It is mutable.
It makes rollback harder.
It makes debugging harder.
It makes supply-chain evidence weaker.
```

Production rule:

```text id="n4d458"
Use immutable tags and preferably image digests for production.
```

---

# 24. imagePullPolicy

Common values:

```text id="z2t3nr"
Always
IfNotPresent
Never
```

Kubernetes documents that image pull policy and image tag affect when kubelet pulls images. If you omit `imagePullPolicy`, Kubernetes applies defaults based on the tag; for example, `:latest` defaults to `Always`. ([Kubernetes][6])

Practical rules:

```text id="t5kiiz"
local kind development:
  imagePullPolicy: IfNotPresent

production with immutable tags:
  imagePullPolicy: IfNotPresent or Always depending on platform policy

never use:
  latest for production releases
```

For your kind-local `demo-node-api:0.1.0`:

```yaml id="slkhyl"
imagePullPolicy: IfNotPresent
```

For registry-backed production:

```text id="nufo7r"
Use immutable tag or digest.
Let deployment pipeline control exact artifact.
```

---

# 25. Admission Controllers

Admission controllers intercept requests to the Kubernetes API server after authentication and authorization but before the object is persisted. They can validate, reject, or mutate requests depending on controller type. ([Kubernetes][7])

Simple flow:

```text id="45ohzk"
kubectl apply
  ↓
authentication
  ↓
authorization / RBAC
  ↓
admission control
  ↓
object stored in etcd
```

Admission controls can enforce:

```text id="3n9p99"
no privileged Pods
no latest image tag
required labels
required resource requests
required probes
required securityContext
allowed registries
image signature verification
namespace policy
```

Production rule:

```text id="zh0rbo"
Do not rely only on humans remembering best practices.
Use admission policy to enforce guardrails.
```

---

# 26. Kyverno and OPA Gatekeeper Concepts

Two popular policy-as-code tools:

```text id="3n26i1"
Kyverno
OPA Gatekeeper
```

Kyverno is a Kubernetes-native policy engine that can validate, mutate, generate, clean up resources, and verify container images. ([Kyverno][8])

Gatekeeper is a validating and mutating webhook that enforces CRD-based policies executed by Open Policy Agent. ([Open Policy Agent][9])

Simple choice:

```text id="5q2y1m"
Kyverno:
  YAML-native, Kubernetes-focused, easy for many platform teams

OPA Gatekeeper:
  OPA/Rego-based, powerful policy language, useful across broader policy domains
```

This lesson does not require installing them, but you should understand the pattern.

---

# 27. Example Kyverno Policy — Block latest Tag

Create concept policy:

```bash id="f29wh9"
nano 10.16-production-hardening/policies/kyverno-disallow-latest-tag.yaml
```

Paste:

```yaml id="x3nxx8"
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: require-image-tag-not-latest
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Using the latest image tag is not allowed."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

Do not apply unless Kyverno is installed:

```bash id="v4z0an"
kubectl get crd clusterpolicies.kyverno.io
```

This is a concept artifact for your repo.

---

# 28. Example Gatekeeper Constraint Concept

Create concept file:

```bash id="muz2p7"
nano 10.16-production-hardening/policies/gatekeeper-required-labels-concept.yaml
```

Paste:

```yaml id="5pdsnk"
# Concept only. Requires Gatekeeper ConstraintTemplate and CRDs.
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-labels
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels:
      - key: app.kubernetes.io/name
      - key: app.kubernetes.io/component
```

Production policy ideas:

```text id="i31c8l"
require resource requests and limits
require probes
require non-root user
block privileged containers
block hostPath
allow only trusted registries
require approved labels
require signed images
```

---

# 29. Runtime Security Basics

Admission control prevents unsafe objects from entering the cluster.

Runtime security watches what actually happens after containers run.

Runtime suspicious behaviors:

```text id="rcu74y"
shell spawned inside app container
unexpected outbound connection
write to sensitive path
crypto miner process
package manager used at runtime
secret file accessed unexpectedly
container escape attempt
unexpected privilege escalation
```

Common runtime security tools:

```text id="amjvtq"
Falco
Tetragon
Cilium Hubble
cloud provider runtime detection
EDR/agent-based tools
eBPF-based sensors
```

Production rule:

```text id="tdvzh4"
Prevent with admission policy.
Detect with runtime monitoring.
Respond with incident runbooks.
```

---

# 30. Create Hardening Checklist

```bash id="kkf61t"
nano 10.16-production-hardening/runbooks/production-hardening-checklist.md
```

Paste:

```markdown id="lop3yt"
# Kubernetes Production Hardening Checklist

## Network

- Use NetworkPolicy-capable CNI.
- Apply default deny ingress.
- Apply default deny egress where practical.
- Allow only required app flows.
- Always allow DNS intentionally.
- Test policies with debug Pods.

## Pod Security

- Enforce Pod Security Standards.
- Aim for restricted profile for app namespaces.
- Run as non-root.
- Disable privilege escalation.
- Drop all Linux capabilities by default.
- Use RuntimeDefault seccomp.
- Use read-only root filesystem where possible.
- Mount explicit writable paths only.

## API Access

- One ServiceAccount per workload.
- Disable token automount if API access is not required.
- Least-privilege RBAC only.

## Images

- Avoid latest.
- Use immutable tags.
- Prefer digests for production.
- Scan images.
- Sign and verify images where possible.
- Use trusted registries.

## Admission

- Enforce required labels.
- Enforce resources.
- Enforce probes.
- Enforce securityContext.
- Block privileged Pods.
- Block hostPath unless approved.
- Block untrusted registries.

## Runtime

- Monitor suspicious process execution.
- Monitor unexpected network activity.
- Monitor sensitive file access.
- Alert on unusual behavior.
```

---

# 31. NetworkPolicy Runbook

```bash id="t583qg"
nano 10.16-production-hardening/runbooks/networkpolicy-runbook.md
```

Paste:

````markdown id="au9ou3"
# NetworkPolicy Runbook

## Check Policies

```bash
kubectl get networkpolicy -n NAMESPACE
kubectl describe networkpolicy POLICY_NAME -n NAMESPACE
````

## Check Labels

```bash
kubectl get pods -n NAMESPACE --show-labels
kubectl get namespace --show-labels
```

## Test Traffic

```bash
kubectl run net-debug -n NAMESPACE --image=curlimages/curl:8.10.1 --restart=Never -- sleep 3600
kubectl exec -n NAMESPACE net-debug -- curl -m 3 http://SERVICE
```

## Common Problems

| Symptom                 | Likely Cause                           |
| ----------------------- | -------------------------------------- |
| policy does nothing     | CNI does not enforce NetworkPolicy     |
| all DNS broken          | missing DNS egress                     |
| ingress blocked         | destination ingress not allowed        |
| egress blocked          | source egress not allowed              |
| expected Pod blocked    | selector label mismatch                |
| only some replicas work | labels inconsistent                    |
| external API broken     | default deny egress without allow rule |

## Golden Rule

Check CNI support, namespace, pod labels, selectors, ports, protocol, DNS, ingress, and egress.

````

---

# 32. Pod Security Runbook

```bash id="g6v0cq"
nano 10.16-production-hardening/runbooks/pod-security-runbook.md
````

Paste:

````markdown id="q2aiyc"
# Pod Security Runbook

## Check Namespace Policy

```bash
kubectl get namespace NAMESPACE --show-labels
````

Look for:

```text
pod-security.kubernetes.io/enforce
pod-security.kubernetes.io/warn
pod-security.kubernetes.io/audit
```

## Apply Warning Mode First

```bash
kubectl label namespace NAMESPACE \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
```

## Common Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  seccompProfile:
    type: RuntimeDefault
```

Container:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

## Common Problems

| Symptom                | Likely Cause                                  |
| ---------------------- | --------------------------------------------- |
| Pod rejected           | violates Pod Security level                   |
| container cannot write | readOnlyRootFilesystem without writable mount |
| app fails as non-root  | image expects root                            |
| port bind denied       | non-root trying to bind privileged port       |
| permission denied      | file ownership/user mismatch                  |

## Golden Rule

Pod hardening often requires both Kubernetes manifest changes and Dockerfile/image changes.

````

---

# 33. Admission Policy Runbook

```bash id="u6dgsd"
nano 10.16-production-hardening/runbooks/admission-policy-runbook.md
````

Paste:

````markdown id="sz4tlk"
# Admission Policy Runbook

## Purpose

Reject or mutate unsafe Kubernetes objects before they are stored.

## Enforce

- required labels
- resource requests and limits
- probes
- securityContext
- trusted registries
- no latest tag
- no privileged containers
- no hostPath
- approved ServiceAccounts

## Tools

- built-in admission controllers
- Pod Security Admission
- ValidatingAdmissionPolicy
- Kyverno
- OPA Gatekeeper

## Debug

```bash
kubectl apply -f manifest.yaml
kubectl describe validatingwebhookconfiguration
kubectl get events -A --sort-by=.lastTimestamp
````

## Production Rule

Start in audit/warn mode.
Measure violations.
Fix workloads.
Then enforce.

````

---

# 34. Production Hardening for demo-node-api

Now update `demo-node-api`.

## 34.1 NetworkPolicy

Create:

```bash id="i2mcf5"
nano apps/demo-node-api/base/networkpolicy.yaml
````

Paste:

```yaml id="ko4i5m"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-default-deny
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-allow-ingress
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3002
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: demo-node-api
      ports:
        - protocol: TCP
          port: 3002
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-node-api-allow-dns-egress
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Note:

```text id="wplb9d"
Add MongoDB egress allow rules when you deploy MongoDB in-cluster.
For managed MongoDB, use ipBlock egress carefully with known CIDRs, or use private networking/security groups outside Kubernetes.
```

## 34.2 Update kustomization

Open:

```bash id="ltl9q5"
nano apps/demo-node-api/base/kustomization.yaml
```

Add:

```yaml id="f7scj6"
  - networkpolicy.yaml
```

Expected list:

```yaml id="ihnwum"
resources:
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
  - servicemonitor.yaml
  - networkpolicy.yaml
```

---

# 35. Harden demo-node-api Deployment

Open:

```bash id="k5ovb7"
nano apps/demo-node-api/base/deployment.yaml
```

Inside:

```yaml id="krxa7g"
spec:
  template:
    spec:
```

ensure:

```yaml id="mg3ebe"
      serviceAccountName: demo-node-api
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
```

Inside container:

```yaml id="ntm6hw"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

If your Node.js app needs `/tmp`, add:

```yaml id="gbny5a"
          volumeMounts:
            - name: tmp
              mountPath: /tmp
```

and under Pod spec:

```yaml id="av39r4"
      volumes:
        - name: tmp
          emptyDir: {}
```

Important:

```text id="xzzt94"
This hardening requires your container image to support running as UID 10001.
If the image currently runs only as root, update your Dockerfile.
```

Example Dockerfile pattern:

```dockerfile id="63ro0z"
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app

USER appuser

EXPOSE 3002

CMD ["node", "start.js"]
```

---

# 36. demo-node-api Hardening Policy Note

Create:

```bash id="svj1qz"
nano 10.16-production-hardening/notes/demo-node-api-hardening-policy.md
```

Paste:

```markdown id="xiq9mc"
# demo-node-api Production Hardening Policy

## Network

- Default deny ingress and egress for demo-node-api Pods.
- Allow ingress only from ingress controller or approved frontend.
- Allow DNS egress.
- Allow MongoDB egress only to approved destination.
- Do not allow direct database access from frontend.

## Pod Security

- Run as non-root.
- Disable privilege escalation.
- Drop all Linux capabilities.
- Use RuntimeDefault seccomp.
- Use read-only root filesystem.
- Mount /tmp as emptyDir only if required.
- Disable ServiceAccount token automount.

## Images

- Do not use latest.
- Use immutable semantic tags for dev/staging.
- Prefer digest pinning for production.
- Scan image before release.
- Sign/verify image when supply-chain controls are available.

## Admission

Recommended policies:

- require app labels
- require resource requests/limits
- require probes
- block privileged containers
- block latest tag
- require runAsNonRoot
- require allowPrivilegeEscalation=false
- require capability drop ALL

## Runtime

Monitor:

- unexpected shell execution
- unexpected outbound connections
- writes to sensitive paths
- suspicious processes
- repeated crash loops
```

---

# 37. Hardening Summary Script

Create:

```bash id="2w80ka"
nano 10.16-production-hardening/scripts/hardening-summary.sh
```

Paste:

```bash id="tftlgf"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-hardening-lab}"

echo "===== Kubernetes Hardening Summary ====="

echo
echo "Namespace labels:"
kubectl get namespace "$NAMESPACE" --show-labels

echo
echo "NetworkPolicies:"
kubectl get networkpolicy -n "$NAMESPACE" || true

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide --show-labels || true

echo
echo "ServiceAccounts:"
kubectl get serviceaccounts -n "$NAMESPACE" || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "Security context overview:"
kubectl get pods -n "$NAMESPACE" -o json | jq -r '
.items[] |
[
  .metadata.name,
  (.spec.securityContext.runAsNonRoot // "unset"),
  (.spec.securityContext.runAsUser // "unset"),
  (.spec.securityContext.seccompProfile.type // "unset")
] | @tsv' | column -t -s $'\t' || true

echo
echo "demo-node-api hardening files:"
test -f apps/demo-node-api/base/networkpolicy.yaml && echo "networkpolicy.yaml exists" || echo "networkpolicy.yaml missing"
test -f 10.16-production-hardening/notes/demo-node-api-hardening-policy.md && echo "demo-node-api hardening policy note exists" || true
```

Make executable:

```bash id="6qaeor"
chmod +x 10.16-production-hardening/scripts/hardening-summary.sh
```

Run:

```bash id="b8rf9a"
./10.16-production-hardening/scripts/hardening-summary.sh
```

---

# 38. Validation Script

Create:

```bash id="0675tx"
nano 10.16-production-hardening/scripts/validate-lesson-10-16.sh
```

Paste:

```bash id="bi158k"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.16 ====="

kubectl version --client >/dev/null
kubectl get namespace hardening-lab >/dev/null

kubectl get deployment frontend -n hardening-lab >/dev/null
kubectl get deployment backend -n hardening-lab >/dev/null
kubectl get deployment database -n hardening-lab >/dev/null

kubectl rollout status deployment/frontend -n hardening-lab --timeout=120s >/dev/null
kubectl rollout status deployment/backend -n hardening-lab --timeout=120s >/dev/null
kubectl rollout status deployment/database -n hardening-lab --timeout=120s >/dev/null

kubectl get networkpolicy default-deny-ingress -n hardening-lab >/dev/null
kubectl get networkpolicy default-deny-egress -n hardening-lab >/dev/null
kubectl get networkpolicy allow-frontend-to-backend -n hardening-lab >/dev/null
kubectl get networkpolicy allow-backend-to-database -n hardening-lab >/dev/null
kubectl get networkpolicy allow-dns-egress -n hardening-lab >/dev/null
kubectl get networkpolicy allow-frontend-egress-backend -n hardening-lab >/dev/null
kubectl get networkpolicy allow-backend-egress-database -n hardening-lab >/dev/null

kubectl get pod secure-pod -n hardening-lab >/dev/null

RUN_AS_USER="$(kubectl get pod secure-pod -n hardening-lab -o jsonpath='{.spec.securityContext.runAsUser}')"
if [ "$RUN_AS_USER" != "10001" ]; then
  echo "ERROR: secure-pod should run as UID 10001"
  exit 1
fi

SECCOMP="$(kubectl get pod secure-pod -n hardening-lab -o jsonpath='{.spec.securityContext.seccompProfile.type}')"
if [ "$SECCOMP" != "RuntimeDefault" ]; then
  echo "ERROR: secure-pod should use RuntimeDefault seccomp"
  exit 1
fi

READONLY="$(kubectl get pod secure-pod -n hardening-lab -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')"
if [ "$READONLY" != "true" ]; then
  echo "ERROR: secure-pod should use readOnlyRootFilesystem=true"
  exit 1
fi

test -x 10.16-production-hardening/scripts/hardening-summary.sh

test -f 10.16-production-hardening/notes/hardening-mental-model.md
test -f 10.16-production-hardening/notes/demo-node-api-hardening-policy.md

test -f 10.16-production-hardening/runbooks/production-hardening-checklist.md
test -f 10.16-production-hardening/runbooks/networkpolicy-runbook.md
test -f 10.16-production-hardening/runbooks/pod-security-runbook.md
test -f 10.16-production-hardening/runbooks/admission-policy-runbook.md

test -f 10.16-production-hardening/policies/kyverno-disallow-latest-tag.yaml
test -f 10.16-production-hardening/policies/gatekeeper-required-labels-concept.yaml

test -f apps/demo-node-api/base/networkpolicy.yaml
grep -q "networkpolicy.yaml" apps/demo-node-api/base/kustomization.yaml
grep -q "runAsNonRoot" apps/demo-node-api/base/deployment.yaml
grep -q "allowPrivilegeEscalation" apps/demo-node-api/base/deployment.yaml
grep -q "readOnlyRootFilesystem" apps/demo-node-api/base/deployment.yaml
grep -q "capabilities" apps/demo-node-api/base/deployment.yaml
grep -q "seccompProfile" apps/demo-node-api/base/deployment.yaml

kubectl kustomize apps/demo-node-api/overlays/dev >/tmp/demo-node-api-hardening-rendered.yaml
grep -q "kind: NetworkPolicy" /tmp/demo-node-api-hardening-rendered.yaml

echo "secure-pod runAsUser: $RUN_AS_USER"
echo "secure-pod seccomp: $SECCOMP"
echo "secure-pod readOnlyRootFilesystem: $READONLY"
echo "Lesson 10.16 validation passed."
```

Make executable:

```bash id="o8v9q2"
chmod +x 10.16-production-hardening/scripts/validate-lesson-10-16.sh
```

Run:

```bash id="fxo9fj"
./10.16-production-hardening/scripts/validate-lesson-10-16.sh
```

---

# 39. Cleanup Script

Create:

```bash id="u8oq9g"
nano 10.16-production-hardening/scripts/cleanup-lesson-10-16.sh
```

Paste:

```bash id="ryv8up"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.16 ====="

kubectl delete pod net-debug -n hardening-lab --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/insecure-pod.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/secure-pod.yaml --ignore-not-found=true

kubectl delete -f 10.16-production-hardening/manifests/allow-backend-egress-database.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/allow-frontend-egress-backend.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/allow-dns-egress.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/default-deny-egress.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/allow-backend-to-database.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/allow-frontend-to-backend.yaml --ignore-not-found=true
kubectl delete -f 10.16-production-hardening/manifests/default-deny-ingress.yaml --ignore-not-found=true

kubectl delete -f 10.16-production-hardening/manifests/three-tier-demo.yaml --ignore-not-found=true

kubectl delete namespace hardening-lab --ignore-not-found=true

echo "Lesson 10.16 live lab resources cleaned."
echo "demo-node-api hardening manifests are kept in apps/demo-node-api/base."
```

Make executable:

```bash id="5v5h5t"
chmod +x 10.16-production-hardening/scripts/cleanup-lesson-10-16.sh
```

Run only if you want cleanup:

```bash id="bwrp0b"
./10.16-production-hardening/scripts/cleanup-lesson-10-16.sh
```

---

# 40. Practical Lab Summary

Run the main lab:

```bash id="zolm61"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl create namespace hardening-lab --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace hardening-lab \
  environment=dev \
  purpose=hardening-lab \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite

kubectl apply -f 10.16-production-hardening/manifests/three-tier-demo.yaml

kubectl run net-debug \
  -n hardening-lab \
  --image=curlimages/curl:8.10.1 \
  --restart=Never \
  -- sleep 3600

kubectl apply -f 10.16-production-hardening/manifests/default-deny-ingress.yaml
kubectl apply -f 10.16-production-hardening/manifests/allow-frontend-to-backend.yaml
kubectl apply -f 10.16-production-hardening/manifests/allow-backend-to-database.yaml

kubectl apply -f 10.16-production-hardening/manifests/default-deny-egress.yaml
kubectl apply -f 10.16-production-hardening/manifests/allow-dns-egress.yaml
kubectl apply -f 10.16-production-hardening/manifests/allow-frontend-egress-backend.yaml
kubectl apply -f 10.16-production-hardening/manifests/allow-backend-egress-database.yaml

kubectl apply -f 10.16-production-hardening/manifests/secure-pod.yaml

./10.16-production-hardening/scripts/hardening-summary.sh
./10.16-production-hardening/scripts/validate-lesson-10-16.sh
```

---

# 41. Common Myths and Misconceptions

## Myth 1: NetworkPolicy works automatically everywhere

Wrong.

```text id="m0gpus"
NetworkPolicy requires a CNI/plugin that enforces it.
If your CNI does not support enforcement, policies may not block traffic.
```

---

## Myth 2: Default deny ingress is enough

Not always.

```text id="dd8mfy"
If egress remains open, compromised Pods can still call external systems or internal services.
```

---

## Myth 3: Tighter NetworkPolicy means only destination ingress

Wrong.

```text id="qmvxw9"
With default deny egress and ingress, both source egress and destination ingress may need allow rules.
```

---

## Myth 4: runAsNonRoot is only a YAML change

Wrong.

```text id="dsv4pw"
The container image must support non-root execution.
You may need Dockerfile ownership and USER changes.
```

---

## Myth 5: readOnlyRootFilesystem never breaks apps

Wrong.

```text id="ounbk7"
Many apps write temp files.
You need explicit writable emptyDir mounts such as /tmp.
```

---

## Myth 6: Admission policy replaces runtime security

Wrong.

```text id="gys40o"
Admission prevents unsafe config.
Runtime security detects suspicious behavior after containers are running.
```

---

## Myth 7: Image tag pinning is enough

Not always.

```text id="dmfz69"
Tags can move.
Digests are stronger for exact artifact identity.
```

---

# 42. Production Hardening Rules

```text id="bgxj8p"
Use NetworkPolicy-capable CNI.
Use default deny ingress for app namespaces.
Use default deny egress where practical.
Allow DNS explicitly.
Allow only required app-to-app flows.
Use Pod Security Admission.
Aim for restricted Pod Security profile.
Run containers as non-root.
Disable privilege escalation.
Drop all Linux capabilities by default.
Use RuntimeDefault seccomp.
Use read-only root filesystem where possible.
Mount writable paths explicitly.
Disable ServiceAccount token automount if API access is not needed.
Avoid latest image tag.
Prefer immutable tags and digests.
Scan images before release.
Use admission policy for guardrails.
Use runtime monitoring for detection.
```

---

# 43. Interview Explanation

Use this:

```text id="4x7xft"
Kubernetes production hardening is a layered approach. I use NetworkPolicy to limit allowed traffic between Pods and namespaces, usually starting with default deny and then allowing only required flows such as ingress-controller to API and API to database. I use Pod Security Standards and securityContext to run containers as non-root, disable privilege escalation, drop Linux capabilities, use RuntimeDefault seccomp, and make the root filesystem read-only where possible.

For supply-chain and governance, I avoid mutable image tags such as latest, prefer immutable tags or digests, scan images, and use admission controls such as Pod Security Admission, Kyverno, or OPA Gatekeeper to block unsafe manifests before they enter the cluster. I also treat runtime security as a separate layer to detect suspicious behavior after deployment.
```

Resume version:

```text id="l3m9ue"
Implemented Kubernetes production hardening labs with NetworkPolicy default-deny rules, controlled app-to-db traffic, DNS egress, Pod Security Admission labels, secure securityContext settings, non-root execution, read-only root filesystem, capability dropping, seccomp, image policy concepts, admission-control runbooks, and demo-node-api hardening manifests.
```

---

# 44. Today’s Core Rules

```text id="uhbjfj"
NetworkPolicy controls Pod traffic.
NetworkPolicy needs enforcing CNI support.
Default deny is the safest starting point.
Allow only required traffic flows.
DNS egress must be allowed intentionally.
Pod Security Standards are privileged, baseline, and restricted.
Pod Security Admission enforces namespace-level Pod security.
securityContext controls container privilege settings.
runAsNonRoot requires compatible images.
readOnlyRootFilesystem may need explicit writable mounts.
Drop ALL capabilities by default.
Use RuntimeDefault seccomp.
Avoid latest image tag.
Digests are immutable; tags can move.
Admission control blocks unsafe objects before persistence.
Runtime security detects suspicious behavior after start.
```

---

# 45. Commit Lesson 10.16

From repo root:

```bash id="mxc6op"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes production hardening and security policy lesson"

git push
```

---

# Next Lesson

```text id="ovjjd8"
Lesson 10.17 — GitOps Deployment Flow with ArgoCD Preview
```

We will cover:

```text id="bv3ae4"
GitOps mental model
desired state in Git
cluster state reconciliation
ArgoCD architecture
Application CRD
repo path
target revision
sync status
health status
manual sync
auto sync
self-heal
prune
rollback by Git revert
demo-node-api GitOps layout
production GitOps promotion flow
```

[1]: https://kubernetes.io/docs/concepts/services-networking/network-policies/?utm_source=chatgpt.com "Network Policies"
[2]: https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises?utm_source=chatgpt.com "Installing on on-premises deployments"
[3]: https://kubernetes.io/docs/concepts/security/pod-security-standards/?utm_source=chatgpt.com "Pod Security Standards"
[4]: https://kubernetes.io/docs/concepts/security/pod-security-admission/?utm_source=chatgpt.com "Pod Security Admission"
[5]: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/?utm_source=chatgpt.com "Configure a Security Context for a Pod or Container"
[6]: https://kubernetes.io/docs/concepts/containers/images/?utm_source=chatgpt.com "Images"
[7]: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/?utm_source=chatgpt.com "Admission Control in Kubernetes"
[8]: https://kyverno.io/docs/introduction/?utm_source=chatgpt.com "Introduction"
[9]: https://open-policy-agent.github.io/gatekeeper/website/docs/?utm_source=chatgpt.com "Introduction | Gatekeeper"
