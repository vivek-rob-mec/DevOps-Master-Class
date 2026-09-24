# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.12 — NetworkPolicy and CNI Troubleshooting

In Lesson 11.11, you learned **storage troubleshooting**:

```text id="recap-11-11"
PVC Pending
PV/PVC binding mismatch
StorageClass issues
accessModes mismatch
volumeMode mismatch
WaitForFirstConsumer
StatefulSet volumeClaimTemplates
ReadWriteOnce confusion
filesystem permissions
initContainer volume fixes
subPath mount mistakes
```

Now we move into **NetworkPolicy and CNI troubleshooting**.

This lesson is important because networking incidents often look like application incidents:

```text id="network-symptoms"
Service exists but traffic times out
DNS suddenly stops working
Ingress returns 503
database connection times out
curl works from one namespace but not another
Pod-to-Pod traffic blocked
egress to internet blocked
NetworkPolicy YAML looks correct but nothing is blocked
default deny applied and app breaks
```

Kubernetes NetworkPolicy controls traffic at IP/port level for selected Pods, but enforcement depends on the cluster’s CNI/network plugin. If your CNI does not support NetworkPolicy, the objects can exist but traffic may not actually be restricted. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="lesson-map"
11.12.1   NetworkPolicy mental model
11.12.2   CNI enforcement reality
11.12.3   ingress vs egress direction
11.12.4   default deny ingress
11.12.5   default deny egress
11.12.6   DNS blocked by egress policy
11.12.7   namespaceSelector mistakes
11.12.8   podSelector mistakes
11.12.9   allowing frontend to backend
11.12.10  allowing app to database
11.12.11  allowing ingress-nginx to app
11.12.12  Service reachable but Pod traffic blocked
11.12.13  testing with curl/nslookup
11.12.14  connectivity matrix
11.12.15  CNI troubleshooting workflow
11.12.16  production NetworkPolicy design
11.12.17  scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting
```

---

# 3. NetworkPolicy Mental Model

NetworkPolicy is **allow-list based**.

That means:

```text id="allow-list"
Without any NetworkPolicy selecting a Pod:
  traffic is usually allowed.

After a NetworkPolicy selects a Pod for ingress:
  only explicitly allowed ingress traffic is allowed.

After a NetworkPolicy selects a Pod for egress:
  only explicitly allowed egress traffic is allowed.
```

Core chain:

```text id="network-chain"
Client Pod
  ↓
egress policy on client Pod
  ↓
network path / CNI
  ↓
Service or Pod IP
  ↓
ingress policy on destination Pod
  ↓
destination container port
```

Important:

```text id="source-dest-rule"
For traffic to work, both sides may matter:

Source Pod egress must allow the traffic.
Destination Pod ingress must allow the traffic.
```

NetworkPolicy rules can select traffic sources and destinations using `podSelector`, `namespaceSelector`, `ipBlock`, and ports. The policy itself only applies to Pods selected by its top-level `podSelector`. ([Kubernetes][1])

---

# 4. Create NetworkPolicy Mental Model Notes

```bash id="mental-model-note"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/notes/networkpolicy-mental-model.md
```

Paste:

```markdown id="mental-model-content"
# NetworkPolicy Mental Model

## Important Rule

NetworkPolicy is allow-list based.

## No policy selects a Pod

Traffic is generally allowed.

## Ingress policy selects a Pod

Only allowed incoming traffic is allowed.

## Egress policy selects a Pod

Only allowed outgoing traffic is allowed.

## Direction

Ingress:
  traffic coming into the selected Pod

Egress:
  traffic leaving the selected Pod

## Two-sided traffic check

For A -> B to work:

1. A's egress policy must allow traffic to B.
2. B's ingress policy must allow traffic from A.

## Selector Scope

NetworkPolicy metadata.namespace:
  namespace where the policy lives

spec.podSelector:
  which Pods the policy applies to

ingress.from.podSelector:
  source Pods in the same namespace unless combined with namespaceSelector

egress.to.podSelector:
  destination Pods in the same namespace unless combined with namespaceSelector

## Golden Rule

A NetworkPolicy only affects Pods selected by spec.podSelector.
```

---

# 5. First NetworkPolicy Debug Commands

```bash id="debug-note"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/notes/networkpolicy-debug-commands.md
```

Paste:

````markdown id="debug-note-content"
# NetworkPolicy and CNI Debug Commands

## Policies

```bash
kubectl get networkpolicy -A
kubectl get networkpolicy -n NAMESPACE
kubectl describe networkpolicy POLICY -n NAMESPACE
kubectl get networkpolicy POLICY -n NAMESPACE -o yaml
````

## Pods and labels

```bash id="pod-labels"
kubectl get pods -n NAMESPACE --show-labels -o wide
kubectl get pods -A --show-labels | grep APP
```

## Namespaces and labels

```bash id="namespace-labels"
kubectl get namespace --show-labels
kubectl label namespace NAMESPACE key=value --overwrite
```

## Services and endpoints

```bash id="svc-endpoints"
kubectl get svc,endpoints,endpointslice -n NAMESPACE
```

## Test DNS

```bash id="dns-test"
kubectl exec -n NAMESPACE CLIENT_POD -- nslookup SERVICE
kubectl exec -n NAMESPACE CLIENT_POD -- nslookup kubernetes.default.svc.cluster.local
```

## Test HTTP

```bash id="http-test"
kubectl exec -n NAMESPACE CLIENT_POD -- wget -T 5 -qO- http://SERVICE
kubectl exec -n NAMESPACE CLIENT_POD -- wget -T 5 -qO- http://SERVICE.NAMESPACE.svc.cluster.local
```

## CoreDNS

```bash id="coredns"
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc kube-dns -n kube-system
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
```

## CNI-related pods

```bash id="cni-pods"
kubectl get pods -A | grep -i -E 'calico|cilium|weave|flannel|antrea|ovn|canal|cni' || true
```

```id="end-debug-note"

Kubernetes DNS debugging starts from a test Pod, then checks `/etc/resolv.conf`, CoreDNS Pods, the kube-dns Service, and DNS logs when lookups fail. :contentReference[oaicite:2]{index=2}
```

---

# 6. CNI Enforcement Reality

This is very important for your local kind cluster.

```text id="cni-reality"
NetworkPolicy objects are Kubernetes API resources.
Actual packet enforcement is done by the network plugin / CNI.
```

If your CNI does not enforce NetworkPolicy:

```text id="no-enforcement"
kubectl get networkpolicy will show policies.
YAML will look correct.
But traffic may still pass.
```

Check CNI-related Pods:

```bash id="check-cni"
kubectl get pods -A | grep -i -E 'calico|cilium|weave|antrea|ovn|canal|flannel|kindnet|cni' || true
```

Common local result:

```text id="kind-cni-note"
kindnet may be present in kind clusters.
Basic kind networking commonly does not provide NetworkPolicy enforcement by itself.
```

Production lesson:

```text id="prod-cni-lesson"
If NetworkPolicy appears ignored, verify CNI support before blaming the YAML.
```

The Kubernetes API reference explicitly states that NetworkPolicies require a network plugin that supports NetworkPolicy enforcement. ([Kubernetes][2])

---

# 7. Create Baseline Apps

We will create three namespaces:

```text id="namespaces"
np-frontend
np-backend
np-database
```

And apps:

```text id="apps"
frontend-client:
  debug client

backend-api:
  HTTP backend

database:
  fake database service on port 5432
```

Create manifest:

```bash id="baseline-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/00-baseline-apps.yaml
```

Paste:

```yaml id="baseline-content"
apiVersion: v1
kind: Namespace
metadata:
  name: np-frontend
  labels:
    role: frontend
    network-lab: "true"
---
apiVersion: v1
kind: Namespace
metadata:
  name: np-backend
  labels:
    role: backend
    network-lab: "true"
---
apiVersion: v1
kind: Namespace
metadata:
  name: np-database
  labels:
    role: database
    network-lab: "true"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-client
  namespace: np-frontend
  labels:
    app: frontend-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend-client
  template:
    metadata:
      labels:
        app: frontend-client
    spec:
      containers:
        - name: client
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
  namespace: np-backend
  labels:
    app: backend-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=backend-api-ok"
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
  name: backend-api
  namespace: np-backend
  labels:
    app: backend-api
spec:
  selector:
    app: backend-api
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: np-database
  labels:
    app: database
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
        - name: db
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:5432"
            - "-text=fake-database-ok"
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
  namespace: np-database
  labels:
    app: database
spec:
  selector:
    app: database
  ports:
    - name: db
      port: 5432
      targetPort: db
```

Apply:

```bash id="apply-baseline"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/00-baseline-apps.yaml
```

Wait:

```bash id="wait-baseline"
kubectl rollout status deployment/frontend-client -n np-frontend --timeout=120s
kubectl rollout status deployment/backend-api -n np-backend --timeout=120s
kubectl rollout status deployment/database -n np-database --timeout=120s
```

Set client variable:

```bash id="client-var"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

echo "$CLIENT_POD"
```

Test baseline DNS and connectivity:

```bash id="baseline-tests"
kubectl exec -n np-frontend "$CLIENT_POD" -- nslookup backend-api.np-backend.svc.cluster.local

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://database.np-database.svc.cluster.local:5432
```

Expected:

```text id="baseline-expected"
backend-api-ok
fake-database-ok
```

If this baseline fails, debug Service/DNS before NetworkPolicy.

---

# 8. Lab 1 — Default Deny Ingress

A default deny ingress policy selects all Pods in a namespace and allows no incoming traffic.

Create:

```bash id="deny-ingress-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/01-default-deny-ingress-backend.yaml
```

Paste:

```yaml id="deny-ingress-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: np-backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

Apply:

```bash id="apply-deny-ingress"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/01-default-deny-ingress-backend.yaml
```

Test:

```bash id="test-deny-ingress"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local || true
```

Expected with enforcing CNI:

```text id="deny-ingress-expected-enforced"
Connection times out or fails.
```

Expected without enforcing CNI:

```text id="deny-ingress-expected-not-enforced"
Traffic still works.
This means your CNI probably does not enforce NetworkPolicy.
```

Debug:

```bash id="debug-deny-ingress"
kubectl get networkpolicy -n np-backend

kubectl describe networkpolicy default-deny-ingress -n np-backend

kubectl get pods -n np-backend --show-labels

kubectl get svc,endpoints -n np-backend
```

Important:

```text id="deny-ingress-important"
The Service and endpoints may be healthy.
NetworkPolicy can still block Pod traffic.
```

Clean for next lab:

```bash id="clean-deny-ingress"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/01-default-deny-ingress-backend.yaml --ignore-not-found=true
```

---

# 9. Lab 2 — Allow Frontend to Backend

Now apply default deny ingress and then allow only frontend namespace traffic to backend-api.

Create:

```bash id="allow-frontend-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/02-allow-frontend-to-backend.yaml
```

Paste:

```yaml id="allow-frontend-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: np-backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: np-backend
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              role: frontend
          podSelector:
            matchLabels:
              app: frontend-client
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

```bash id="apply-allow-frontend"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/02-allow-frontend-to-backend.yaml
```

Test:

```bash id="test-allow-frontend"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local
```

Expected with enforcing CNI:

```text id="allow-frontend-expected"
backend-api-ok
```

Why port `8080`, not Service port `80`?

```text id="port-note"
NetworkPolicy port checks traffic at the destination Pod/container port.
The Service exposes port 80, but forwards to targetPort 8080.
```

Debug:

```bash id="debug-allow-frontend"
kubectl describe networkpolicy allow-frontend-to-backend -n np-backend

kubectl get namespace np-frontend --show-labels

kubectl get pods -n np-frontend --show-labels
kubectl get pods -n np-backend --show-labels
```

Clean later, not now if you want to continue testing.

---

# 10. Lab 3 — namespaceSelector and podSelector Mistake

This is a very common YAML mistake.

These two forms are different.

## Correct: same `from` item means namespace AND pod

```yaml id="selector-correct"
from:
  - namespaceSelector:
      matchLabels:
        role: frontend
    podSelector:
      matchLabels:
        app: frontend-client
```

Meaning:

```text id="selector-correct-meaning"
Allow Pods with app=frontend-client in namespaces with role=frontend.
```

## Different list items mean namespace OR pod

```yaml id="selector-wrong"
from:
  - namespaceSelector:
      matchLabels:
        role: frontend
  - podSelector:
      matchLabels:
        app: frontend-client
```

Meaning:

```text id="selector-wrong-meaning"
Allow all Pods from frontend namespaces
OR allow Pods named frontend-client from the policy namespace.
```

This can be accidentally broader than intended.

Create note:

```bash id="selector-note"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/notes/selector-and-or-mistake.md
```

Paste:

````markdown id="selector-note-content"
# namespaceSelector and podSelector AND/OR Mistake

## AND behavior

One list item with both namespaceSelector and podSelector:

```yaml
from:
  - namespaceSelector:
      matchLabels:
        role: frontend
    podSelector:
      matchLabels:
        app: frontend-client
````

Meaning:

Allow Pods matching app=frontend-client inside namespaces matching role=frontend.

## OR behavior

Two separate list items:

```yaml
from:
  - namespaceSelector:
      matchLabels:
        role: frontend
  - podSelector:
      matchLabels:
        app: frontend-client
```

Meaning:

Allow all Pods from namespaces role=frontend OR Pods app=frontend-client in the policy namespace.

## Rule

Indentation changes security meaning.

````

---

# 11. Lab 4 — Default Deny Egress Breaks DNS

A default deny egress policy often breaks DNS first.

Create:

```bash id="deny-egress-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/03-default-deny-egress-frontend.yaml
````

Paste:

```yaml id="deny-egress-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: np-frontend
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

Apply:

```bash id="apply-deny-egress"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/03-default-deny-egress-frontend.yaml
```

Test DNS:

```bash id="test-deny-egress-dns"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- nslookup backend-api.np-backend.svc.cluster.local || true
```

Expected with enforcing CNI:

```text id="dns-blocked-expected"
DNS timeout or lookup failure.
```

Also test direct Service name:

```bash id="test-deny-egress-http"
kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local || true
```

Debug DNS components:

```bash id="debug-dns-components"
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc kube-dns -n kube-system
kubectl exec -n np-frontend "$CLIENT_POD" -- cat /etc/resolv.conf
```

If DNS service is healthy but lookup fails after default deny egress, suspect egress NetworkPolicy.

Kubernetes’ DNS debugging guide recommends checking DNS from inside a test Pod and then verifying CoreDNS Pods and the kube-dns Service. ([Kubernetes][3])

---

# 12. Lab 5 — Allow DNS Egress

Create a policy that allows DNS to CoreDNS.

```bash id="allow-dns-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/04-allow-dns-egress.yaml
```

Paste:

```yaml id="allow-dns-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: np-frontend
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

```bash id="apply-allow-dns"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/04-allow-dns-egress.yaml
```

Test DNS again:

```bash id="test-allow-dns"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- nslookup backend-api.np-backend.svc.cluster.local
```

Expected with enforcing CNI:

```text id="allow-dns-expected"
DNS works again.
HTTP may still fail because only DNS egress is allowed.
```

Test HTTP:

```bash id="test-http-after-dns"
kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local || true
```

Expected:

```text id="http-still-blocked"
DNS resolves, but HTTP egress is still blocked until allowed.
```

---

# 13. Lab 6 — Allow Frontend Egress to Backend

Create egress allow from frontend to backend.

```bash id="allow-frontend-egress-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/05-allow-frontend-egress-to-backend.yaml
```

Paste:

```yaml id="allow-frontend-egress-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-egress-to-backend
  namespace: np-frontend
spec:
  podSelector:
    matchLabels:
      app: frontend-client
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              role: backend
          podSelector:
            matchLabels:
              app: backend-api
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

```bash id="apply-allow-frontend-egress"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/05-allow-frontend-egress-to-backend.yaml
```

If you still have backend ingress default deny from Lab 2, keep `02-allow-frontend-to-backend.yaml` applied too.

Test:

```bash id="test-frontend-egress"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local
```

Expected:

```text id="frontend-egress-expected"
backend-api-ok
```

Now test database:

```bash id="test-db-blocked"
kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://database.np-database.svc.cluster.local:5432 || true
```

Expected with enforcing CNI:

```text id="db-blocked"
Database traffic should be blocked because frontend egress allows backend only.
```

---

# 14. Lab 7 — Backend to Database Allowed, Frontend to Database Denied

Create a backend client Pod and policies.

```bash id="backend-client-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/06-backend-client-and-db-policy.yaml
```

Paste:

```yaml id="backend-client-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-client
  namespace: np-backend
  labels:
    app: backend-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-client
  template:
    metadata:
      labels:
        app: backend-client
    spec:
      containers:
        - name: client
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-database-ingress
  namespace: np-database
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: np-database
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              role: backend
      ports:
        - protocol: TCP
          port: 5432
```

Apply:

```bash id="apply-backend-db"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/06-backend-client-and-db-policy.yaml

kubectl rollout status deployment/backend-client -n np-backend --timeout=120s
```

Test from backend:

```bash id="test-backend-db"
BACKEND_CLIENT="$(kubectl get pod -n np-backend -l app=backend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-backend "$BACKEND_CLIENT" -- wget -T 5 -qO- http://database.np-database.svc.cluster.local:5432
```

Expected:

```text id="backend-db-expected"
fake-database-ok
```

Test from frontend:

```bash id="test-frontend-db-denied"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://database.np-database.svc.cluster.local:5432 || true
```

Expected with enforcing CNI:

```text id="frontend-db-denied"
Frontend cannot reach database.
```

Production pattern:

```text id="prod-pattern"
frontend -> backend allowed
backend -> database allowed
frontend -> database denied
```

---

# 15. Lab 8 — Allow ingress-nginx to App

When you apply default deny ingress to an application namespace, Ingress traffic may break unless you allow the ingress controller namespace.

Create an app in `np-backend` and allow ingress-nginx.

If ingress-nginx is installed, check labels:

```bash id="check-ingress-nginx-labels"
kubectl get namespace ingress-nginx --show-labels || true

kubectl get pods -n ingress-nginx --show-labels || true
```

Label the namespace if needed:

```bash id="label-ingress-nginx"
kubectl label namespace ingress-nginx app.kubernetes.io/name=ingress-nginx --overwrite || true
```

Create policy:

```bash id="allow-ingress-nginx-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/07-allow-ingress-nginx-to-backend.yaml
```

Paste:

```yaml id="allow-ingress-nginx-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-nginx-to-backend
  namespace: np-backend
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

```bash id="apply-allow-ingress-nginx"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests/07-allow-ingress-nginx-to-backend.yaml
```

Debug checklist:

```bash id="debug-ingress-policy"
kubectl describe networkpolicy allow-ingress-nginx-to-backend -n np-backend

kubectl get namespace ingress-nginx --show-labels

kubectl get pods -n np-backend --show-labels
```

Production rule:

```text id="ingress-prod-rule"
If default deny ingress is enabled, allow traffic from the ingress controller namespace to the application Pod port.
```

---

# 16. Lab 9 — Service Works, But NetworkPolicy Blocks Pod Traffic

This is a key troubleshooting point.

Check Service:

```bash id="svc-healthy"
kubectl get svc,endpoints -n np-backend backend-api
```

Service and endpoints can be healthy:

```text id="svc-healthy-note"
Service exists.
Endpoint exists.
Pod is Ready.
```

But traffic can still fail because NetworkPolicy blocks the packet path.

Test:

```bash id="test-svc-but-blocked"
CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- nslookup backend-api.np-backend.svc.cluster.local

kubectl exec -n np-frontend "$CLIENT_POD" -- wget -T 5 -qO- http://backend-api.np-backend.svc.cluster.local || true
```

Interpretation:

```text id="svc-blocked-interpretation"
DNS works:
  name resolution is OK.

Service endpoints exist:
  Kubernetes Service selection is OK.

HTTP times out:
  NetworkPolicy or CNI/network path may be blocking.
```

This is why NetworkPolicy debugging must include:

```text id="np-debug-needs"
Service
Endpoints
Pod labels
Namespace labels
Ingress policies on destination
Egress policies on source
CNI enforcement
```

---

# 17. NetworkPolicy Troubleshooting Algorithm

Use this every time:

```text id="algorithm"
1. Confirm baseline Service and endpoints.
2. Confirm source Pod identity and labels.
3. Confirm destination Pod labels.
4. Confirm source namespace labels.
5. Confirm destination namespace labels.
6. Check egress policies selecting source Pod.
7. Check ingress policies selecting destination Pod.
8. Check ports use destination Pod port, not always Service port.
9. Test DNS separately.
10. Verify CNI supports NetworkPolicy.
```

Command sequence:

```bash id="algorithm-commands"
SOURCE_NS=np-frontend
SOURCE_LABEL='app=frontend-client'
DEST_NS=np-backend
DEST_SVC=backend-api
DEST_LABEL='app=backend-api'

SOURCE_POD="$(kubectl get pod -n "$SOURCE_NS" -l "$SOURCE_LABEL" -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$SOURCE_POD" -n "$SOURCE_NS" --show-labels
kubectl get namespace "$SOURCE_NS" --show-labels

kubectl get svc,endpoints "$DEST_SVC" -n "$DEST_NS"
kubectl get pods -n "$DEST_NS" -l "$DEST_LABEL" --show-labels
kubectl get namespace "$DEST_NS" --show-labels

kubectl get networkpolicy -n "$SOURCE_NS"
kubectl get networkpolicy -n "$DEST_NS"

kubectl exec -n "$SOURCE_NS" "$SOURCE_POD" -- nslookup "$DEST_SVC.$DEST_NS.svc.cluster.local"
kubectl exec -n "$SOURCE_NS" "$SOURCE_POD" -- wget -T 5 -qO- "http://$DEST_SVC.$DEST_NS.svc.cluster.local" || true
```

---

# 18. Create Connectivity Matrix Script

```bash id="matrix-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/connectivity-matrix.sh
```

Paste:

```bash id="matrix-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== NetworkPolicy Connectivity Matrix ====="

FRONTEND_NS="${FRONTEND_NS:-np-frontend}"
BACKEND_NS="${BACKEND_NS:-np-backend}"
DATABASE_NS="${DATABASE_NS:-np-database}"

FRONTEND_POD="$(kubectl get pod -n "$FRONTEND_NS" -l app=frontend-client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
BACKEND_CLIENT="$(kubectl get pod -n "$BACKEND_NS" -l app=backend-client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

test_from_pod() {
  local ns="$1"
  local pod="$2"
  local name="$3"
  local url="$4"

  echo
  echo "[$ns/$pod] -> $name"
  if [ -z "$pod" ]; then
    echo "SKIP: source Pod not found"
    return
  fi

  kubectl exec -n "$ns" "$pod" -- wget -T 5 -qO- "$url" || echo "FAILED"
}

echo
echo "Namespaces:"
kubectl get namespace np-frontend np-backend np-database --show-labels || true

echo
echo "Policies:"
kubectl get networkpolicy -A | grep -E 'np-frontend|np-backend|np-database' || true

test_from_pod "$FRONTEND_NS" "$FRONTEND_POD" "backend-api" "http://backend-api.np-backend.svc.cluster.local"
test_from_pod "$FRONTEND_NS" "$FRONTEND_POD" "database" "http://database.np-database.svc.cluster.local:5432"

test_from_pod "$BACKEND_NS" "$BACKEND_CLIENT" "database" "http://database.np-database.svc.cluster.local:5432"
test_from_pod "$BACKEND_NS" "$BACKEND_CLIENT" "backend-api" "http://backend-api.np-backend.svc.cluster.local"
```

Make executable:

```bash id="chmod-matrix"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/connectivity-matrix.sh
```

Run:

```bash id="run-matrix"
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/connectivity-matrix.sh
```

---

# 19. Create NetworkPolicy Summary Script

```bash id="summary-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/networkpolicy-summary.sh
```

Paste:

```bash id="summary-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== NetworkPolicy Summary ====="

echo
echo "CNI-related Pods:"
kubectl get pods -A | grep -i -E 'calico|cilium|weave|antrea|ovn|canal|flannel|kindnet|cni' || true

echo
echo "Namespaces:"
kubectl get namespace np-frontend np-backend np-database kube-system --show-labels || true

echo
echo "NetworkPolicies:"
kubectl get networkpolicy -A || true

echo
echo "Frontend Pods:"
kubectl get pods -n np-frontend --show-labels -o wide || true

echo
echo "Backend Pods:"
kubectl get pods -n np-backend --show-labels -o wide || true

echo
echo "Database Pods:"
kubectl get pods -n np-database --show-labels -o wide || true

echo
echo "Services and endpoints:"
kubectl get svc,endpoints -n np-backend || true
kubectl get svc,endpoints -n np-database || true

echo
echo "CoreDNS:"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
kubectl get svc kube-dns -n kube-system || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/networkpolicy-summary.sh
```

Run:

```bash id="run-summary"
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/networkpolicy-summary.sh
```

---

# 20. Create Policy Inspector Script

```bash id="policy-inspector-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/inspect-networkpolicy.sh
```

Paste:

```bash id="policy-inspector-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-np-backend}"
POLICY="${POLICY:-}"

if [ -z "$POLICY" ]; then
  POLICY="$(kubectl get networkpolicy -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [ -z "$POLICY" ]; then
  echo "No NetworkPolicy found in namespace $NAMESPACE. Or set POLICY=my-policy."
  exit 0
fi

OUT_DIR="11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/reports/networkpolicy-$NAMESPACE-$POLICY-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "===== NetworkPolicy Inspector ====="
echo "Namespace: $NAMESPACE"
echo "Policy: $POLICY"
echo "Output: $OUT_DIR"

kubectl get networkpolicy "$POLICY" -n "$NAMESPACE" -o yaml > "$OUT_DIR/policy.yaml" 2>&1 || true
kubectl describe networkpolicy "$POLICY" -n "$NAMESPACE" > "$OUT_DIR/policy-describe.txt" 2>&1 || true
kubectl get pods -n "$NAMESPACE" --show-labels -o wide > "$OUT_DIR/pods.txt" 2>&1 || true
kubectl get namespace "$NAMESPACE" --show-labels > "$OUT_DIR/namespace-labels.txt" 2>&1 || true
kubectl get namespace --show-labels > "$OUT_DIR/all-namespace-labels.txt" 2>&1 || true
kubectl get networkpolicy -A > "$OUT_DIR/all-networkpolicies.txt" 2>&1 || true
kubectl get svc,endpoints -n "$NAMESPACE" -o wide > "$OUT_DIR/services-endpoints.txt" 2>&1 || true

echo
echo "Policy summary:"
cat "$OUT_DIR/policy-describe.txt"

echo
echo "Inspection saved to: $OUT_DIR"
```

Make executable:

```bash id="chmod-policy-inspector"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/inspect-networkpolicy.sh
```

Run:

```bash id="run-policy-inspector"
NAMESPACE=np-backend POLICY=allow-frontend-to-backend \
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/inspect-networkpolicy.sh
```

---

# 21. Create DNS Egress Test Script

```bash id="dns-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/dns-egress-test.sh
```

Paste:

```bash id="dns-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-np-frontend}"
POD_LABEL="${POD_LABEL:-app=frontend-client}"
NAME_TO_LOOKUP="${NAME_TO_LOOKUP:-kubernetes.default.svc.cluster.local}"

POD="$(kubectl get pod -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [ -z "$POD" ]; then
  echo "No Pod found for $POD_LABEL in namespace $NAMESPACE"
  exit 1
fi

echo "===== DNS Egress Test ====="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "Lookup: $NAME_TO_LOOKUP"

echo
echo "resolv.conf:"
kubectl exec -n "$NAMESPACE" "$POD" -- cat /etc/resolv.conf || true

echo
echo "nslookup:"
kubectl exec -n "$NAMESPACE" "$POD" -- nslookup "$NAME_TO_LOOKUP" || true

echo
echo "CoreDNS status:"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
kubectl get svc kube-dns -n kube-system || true
```

Make executable:

```bash id="chmod-dns-script"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/dns-egress-test.sh
```

Run:

```bash id="run-dns-script"
NAMESPACE=np-frontend POD_LABEL='app=frontend-client' \
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/dns-egress-test.sh
```

---

# 22. Run All NetworkPolicy Labs Script

```bash id="run-labs-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/run-networkpolicy-labs.sh
```

Paste:

```bash id="run-labs-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests"

kubectl apply -f "$BASE/00-baseline-apps.yaml"

kubectl rollout status deployment/frontend-client -n np-frontend --timeout=120s
kubectl rollout status deployment/backend-api -n np-backend --timeout=120s
kubectl rollout status deployment/database -n np-database --timeout=120s

kubectl apply -f "$BASE/02-allow-frontend-to-backend.yaml"
kubectl apply -f "$BASE/03-default-deny-egress-frontend.yaml"
kubectl apply -f "$BASE/04-allow-dns-egress.yaml"
kubectl apply -f "$BASE/05-allow-frontend-egress-to-backend.yaml"
kubectl apply -f "$BASE/06-backend-client-and-db-policy.yaml"

kubectl rollout status deployment/backend-client -n np-backend --timeout=120s

echo "NetworkPolicy labs applied."
echo
echo "Run:"
echo "./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/networkpolicy-summary.sh"
echo "./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/connectivity-matrix.sh"
echo
echo "If blocked traffic still succeeds, your CNI may not enforce NetworkPolicy."
```

Make executable:

```bash id="chmod-run-labs"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/run-networkpolicy-labs.sh
```

Run:

```bash id="run-labs"
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/run-networkpolicy-labs.sh
```

---

# 23. Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/cleanup-lesson-11-12.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.12 ====="

kubectl delete -f "$BASE/07-allow-ingress-nginx-to-backend.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-backend-client-and-db-policy.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-allow-frontend-egress-to-backend.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-allow-dns-egress.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-default-deny-egress-frontend.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-allow-frontend-to-backend.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-default-deny-ingress-backend.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/00-baseline-apps.yaml" --ignore-not-found=true

echo "Lesson 11.12 demo resources cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/cleanup-lesson-11-12.sh
```

Run:

```bash id="run-cleanup"
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/cleanup-lesson-11-12.sh
```

---

# 24. Validation Script

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/validate-lesson-11-12.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.12 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/networkpolicy-mental-model.md"
test -f "$BASE/notes/networkpolicy-debug-commands.md"
test -f "$BASE/notes/selector-and-or-mistake.md"

test -f "$BASE/manifests/00-baseline-apps.yaml"
test -f "$BASE/manifests/01-default-deny-ingress-backend.yaml"
test -f "$BASE/manifests/02-allow-frontend-to-backend.yaml"
test -f "$BASE/manifests/03-default-deny-egress-frontend.yaml"
test -f "$BASE/manifests/04-allow-dns-egress.yaml"
test -f "$BASE/manifests/05-allow-frontend-egress-to-backend.yaml"
test -f "$BASE/manifests/06-backend-client-and-db-policy.yaml"
test -f "$BASE/manifests/07-allow-ingress-nginx-to-backend.yaml"

test -x "$BASE/scripts/connectivity-matrix.sh"
test -x "$BASE/scripts/networkpolicy-summary.sh"
test -x "$BASE/scripts/inspect-networkpolicy.sh"
test -x "$BASE/scripts/dns-egress-test.sh"
test -x "$BASE/scripts/run-networkpolicy-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-12.sh"

kubectl apply -f "$BASE/manifests/00-baseline-apps.yaml" >/dev/null

kubectl rollout status deployment/frontend-client -n np-frontend --timeout=120s >/dev/null
kubectl rollout status deployment/backend-api -n np-backend --timeout=120s >/dev/null
kubectl rollout status deployment/database -n np-database --timeout=120s >/dev/null

CLIENT_POD="$(kubectl get pod -n np-frontend -l app=frontend-client -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n np-frontend "$CLIENT_POD" -- nslookup backend-api.np-backend.svc.cluster.local >/dev/null

kubectl apply -f "$BASE/manifests/02-allow-frontend-to-backend.yaml" >/dev/null
kubectl get networkpolicy allow-frontend-to-backend -n np-backend >/dev/null

echo "Baseline apps and NetworkPolicy objects validated."
echo "Note: traffic enforcement depends on your CNI."
echo "Lesson 11.12 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/validate-lesson-11-12.sh
```

Run:

```bash id="run-validation"
./11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/scripts/validate-lesson-11-12.sh
```

---

# 25. NetworkPolicy Troubleshooting Runbook

```bash id="np-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/runbooks/networkpolicy-troubleshooting-runbook.md
```

Paste:

````markdown id="np-runbook-content"
# NetworkPolicy Troubleshooting Runbook

## 1. Confirm CNI enforcement

```bash
kubectl get pods -A | grep -i -E 'calico|cilium|weave|antrea|ovn|canal|flannel|kindnet|cni' || true
````

If policies are ignored, check whether your CNI supports NetworkPolicy.

## 2. Confirm Service and endpoints

```bash id="rb-svc"
kubectl get svc,endpoints -n DEST_NAMESPACE
```

If endpoints are empty, fix Service/Pod readiness first.

## 3. Check source Pod

```bash id="rb-source"
kubectl get pod SOURCE_POD -n SOURCE_NAMESPACE --show-labels -o wide
kubectl get namespace SOURCE_NAMESPACE --show-labels
```

## 4. Check destination Pod

```bash id="rb-dest"
kubectl get pods -n DEST_NAMESPACE --show-labels -o wide
kubectl get namespace DEST_NAMESPACE --show-labels
```

## 5. Check egress policies on source namespace

```bash id="rb-egress"
kubectl get networkpolicy -n SOURCE_NAMESPACE
kubectl describe networkpolicy POLICY -n SOURCE_NAMESPACE
```

## 6. Check ingress policies on destination namespace

```bash id="rb-ingress"
kubectl get networkpolicy -n DEST_NAMESPACE
kubectl describe networkpolicy POLICY -n DEST_NAMESPACE
```

## 7. Test DNS separately

```bash id="rb-dns"
kubectl exec -n SOURCE_NAMESPACE SOURCE_POD -- nslookup SERVICE.DEST_NAMESPACE.svc.cluster.local
```

If DNS fails after default deny egress, allow UDP/TCP 53 to CoreDNS.

## 8. Test HTTP/TCP

```bash id="rb-http"
kubectl exec -n SOURCE_NAMESPACE SOURCE_POD -- wget -T 5 -qO- http://SERVICE.DEST_NAMESPACE.svc.cluster.local
```

## 9. Common causes

| Symptom                                       | Likely Cause                                         |
| --------------------------------------------- | ---------------------------------------------------- |
| Policies exist but no traffic blocked         | CNI does not enforce NetworkPolicy                   |
| DNS fails                                     | egress blocks CoreDNS                                |
| Service endpoints healthy but traffic timeout | NetworkPolicy blocking ingress/egress                |
| frontend cannot reach backend                 | missing source egress or destination ingress rule    |
| ingress-nginx returns 503                     | app namespace default deny blocks ingress controller |
| database accessible from frontend             | policy too broad or missing database default deny    |
| podSelector not matching                      | wrong labels or wrong namespace                      |
| namespaceSelector not matching                | namespace labels missing                             |
| port mismatch                                 | NetworkPolicy uses Pod port, not always Service port |

## Golden Rule

NetworkPolicy debugging is label debugging plus direction debugging plus CNI verification.

````id="np-runbook-end"

---

# 26. CNI Troubleshooting Runbook

```bash id="cni-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/runbooks/cni-troubleshooting-runbook.md
````

Paste:

````markdown id="cni-runbook-content"
# CNI Troubleshooting Runbook

## 1. Identify CNI

```bash
kubectl get pods -A | grep -i -E 'calico|cilium|weave|antrea|ovn|canal|flannel|kindnet|cni' || true
````

## 2. Check CNI Pods

```bash id="cni-pods-rb"
kubectl get pods -A -o wide | grep -i -E 'calico|cilium|weave|antrea|ovn|canal|flannel|kindnet|cni' || true
```

## 3. Check CNI Logs

Examples:

```bash id="cni-logs-rb"
kubectl logs -n kube-system -l k8s-app=calico-node --tail=100 || true
kubectl logs -n kube-system -l k8s-app=cilium --tail=100 || true
kubectl logs -n kube-system -l app=kindnet --tail=100 || true
```

Labels vary by CNI.

## 4. Check Node Networking Symptoms

```bash id="node-network-rb"
kubectl get nodes -o wide
kubectl describe node NODE
kubectl get pods -A -o wide
```

Look for:

* Pods cannot get IPs
* CNI plugin errors
* network unavailable condition
* cross-node traffic failure
* DNS failures
* NetworkPolicy not enforced

## 5. Separate Problems

DNS problem:
nslookup fails, CoreDNS or DNS egress issue.

Service problem:
Service endpoints missing or targetPort wrong.

NetworkPolicy problem:
DNS and endpoints healthy, but traffic blocked.

CNI problem:
broad Pod network issues, IP allocation problems, cross-node failures, policy enforcement missing.

## 6. Production Escalation

Collect:

* CNI type and version
* affected namespaces
* affected nodes
* source/destination Pod IPs
* policies
* service/endpoints
* CNI logs
* node conditions
* packet path evidence

````id="cni-runbook-end"

---

# 27. Production NetworkPolicy Design Runbook

```bash id="prod-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.12-networkpolicy-cni-troubleshooting/runbooks/production-networkpolicy-design-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production NetworkPolicy Design Runbook

## Recommended rollout order

1. Confirm CNI supports NetworkPolicy.
2. Label namespaces consistently.
3. Label Pods consistently.
4. Start with observe/test namespace.
5. Apply default deny ingress.
6. Add required ingress allows.
7. Apply default deny egress.
8. Add DNS egress.
9. Add required app egress.
10. Test with a connectivity matrix.
11. Roll out namespace by namespace.

## Baseline policies

### Default deny ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
````

### Default deny egress

```yaml id="prod-deny-egress"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

### Allow DNS

```yaml id="prod-allow-dns"
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

## Design rules

* Use namespace labels intentionally.
* Avoid broad `podSelector: {}` allows unless required.
* Allow DNS before testing application egress.
* Prefer explicit app-to-app flows.
* Allow ingress controller namespace to app namespaces.
* Keep database access narrow.
* Test both positive and negative cases.
* Document expected allowed traffic.

````id="prod-runbook-end"

---

# 28. Real Production Debug Mapping

```text id="prod-map"
NetworkPolicy exists but traffic still works:
  CNI may not enforce NetworkPolicy, or policy does not select the Pod.

Traffic timeout after default deny ingress:
  destination ingress policy blocks source.

Traffic timeout after default deny egress:
  source egress policy blocks destination or DNS.

DNS broken:
  allow UDP/TCP 53 to CoreDNS and verify CoreDNS health.

Service endpoints exist but curl fails:
  check source egress and destination ingress policies.

Ingress returns 503 after default deny:
  allow ingress-nginx namespace to app Pod port.

Frontend can directly reach database:
  database namespace lacks default deny ingress or allow rule is too broad.

Policy selector looks right but no effect:
  check Pod labels, namespace labels, and top-level spec.podSelector.

Only some Pods fail:
  compare labels; policy may select only part of the workload.

Works in dev, fails in prod:
  CNI, namespace labels, Pod labels, or policy set may differ.
````

---

# 29. Common Mistakes

## Mistake 1: Forgetting CNI enforcement

NetworkPolicy is not enough by itself. The network plugin must enforce it. ([Kubernetes][2])

---

## Mistake 2: Blocking DNS with default deny egress

Fix by allowing both:

```text id="dns-ports"
UDP 53
TCP 53
```

to CoreDNS.

---

## Mistake 3: Using Service port instead of Pod port

If Service is:

```yaml id="svc-target-port"
port: 80
targetPort: 8080
```

NetworkPolicy usually needs destination Pod port:

```yaml id="np-pod-port"
port: 8080
```

---

## Mistake 4: Confusing ingress and egress

```text id="direction-confusion"
Ingress policy lives on destination side.
Egress policy lives on source side.
```

---

## Mistake 5: Selector indentation mistake

This can change AND logic to OR logic.

---

## Mistake 6: Missing namespace labels

Check:

```bash id="check-ns-labels"
kubectl get namespace --show-labels
```

---

# 30. Interview Explanation

Use this:

```text id="interview-answer"
When troubleshooting Kubernetes NetworkPolicy, I first confirm whether the CNI supports policy enforcement. If policies exist but traffic is not blocked, I do not assume the YAML is wrong until I verify the CNI.

Then I separate DNS, Service, and NetworkPolicy issues. I check that the Service has endpoints and that DNS resolves from a debug Pod. If DNS fails after default deny egress, I allow TCP and UDP 53 to CoreDNS. If DNS and endpoints are healthy but traffic times out, I inspect egress policies selecting the source Pod and ingress policies selecting the destination Pod.

I check Pod labels, namespace labels, podSelector, namespaceSelector, and ports carefully. I also remember that NetworkPolicy often uses the destination Pod port, not just the Service port. In production, I roll out policies gradually, start with namespace labels, use default deny plus explicit allows, test a connectivity matrix, and keep database and ingress-controller access narrow.
```

Resume bullet:

```text id="resume-bullet"
Built Kubernetes NetworkPolicy and CNI troubleshooting labs covering default deny ingress and egress, DNS egress failures, CoreDNS allow rules, frontend-to-backend policy, backend-to-database policy, ingress-nginx access, namespaceSelector and podSelector mistakes, Service-vs-policy debugging, CNI enforcement validation, connectivity matrix testing, policy inspection scripts, and production NetworkPolicy runbooks.
```

---

# 31. Commit Lesson 11.12

```bash id="commit"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes NetworkPolicy and CNI troubleshooting labs"

git push
```

---

# 32. Next Lesson

```text id="next-lesson"
Lesson 11.13 — HPA and Autoscaling Troubleshooting
```

We will cover:

```text id="next-topics"
HPA not scaling
metrics-server unavailable
unknown CPU metrics
missing resource requests
CPU utilization calculation
scale up delay
scale down stabilization
HPA with custom metrics concept
Deployment replica conflicts
HPA vs manual scaling
load generation
autoscaling event debugging
production autoscaling runbook
```

[1]: https://kubernetes.io/docs/concepts/services-networking/network-policies/?utm_source=chatgpt.com "Network Policies"
[2]: https://kubernetes.io/docs/reference/kubernetes-api/networking/network-policy-v1/?utm_source=chatgpt.com "NetworkPolicy"
[3]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/?utm_source=chatgpt.com "Debugging DNS Resolution"
