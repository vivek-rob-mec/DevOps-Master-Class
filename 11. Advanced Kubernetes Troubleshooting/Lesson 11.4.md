# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.4 — Service and DNS Troubleshooting

In Lesson 11.3, you learned **Deployment rollout failure debugging**:

```text id="qgwtxx"
rollout status
ReplicaSet history
bad image rollout
readiness-blocked rollout
ProgressDeadlineExceeded
rollback
ArgoCD rollback vs kubectl rollback
```

Now we move to **Service and DNS troubleshooting**.

This is one of the most common production Kubernetes problems:

```text id="z71p0y"
Pod is Running.
Application logs look fine.
But traffic is not reaching the app.
```

Most Service/DNS incidents come from a small set of causes:

```text id="x61m20"
wrong Service selector
wrong Pod labels
empty endpoints
wrong targetPort
wrong named port
Pod not Ready
wrong namespace
wrong DNS name
CoreDNS issue
NetworkPolicy blocking DNS
Ingress pointing to wrong Service
```

A Kubernetes Service exposes a network application running in one or more Pods behind a stable endpoint, while EndpointSlices track the actual backend endpoint IPs used by Services. DNS resolution for Services is usually handled by CoreDNS in the cluster. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="z2v7mf"
11.4.1   Service traffic mental model
11.4.2   Service → EndpointSlice → Pod chain
11.4.3   Service selector mismatch
11.4.4   Empty endpoints
11.4.5   Wrong targetPort
11.4.6   Wrong named port
11.4.7   Pod Running but not Ready
11.4.8   ClusterIP debugging
11.4.9   NodePort debugging
11.4.10  DNS names
11.4.11  CoreDNS debugging
11.4.12  nslookup and curl from debug Pods
11.4.13  NetworkPolicy blocking DNS
11.4.14  kube-proxy and EndpointSlice concepts
11.4.15  Ingress-to-Service traffic path
11.4.16  Production traffic path debugging
11.4.17  Scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="n687tz"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="yx1mki"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting
```

---

# 3. Service Traffic Mental Model

A Service is not your application.

A Service is a stable virtual access point.

The real traffic path is:

```text id="sjt6ut"
Client Pod
  ↓
DNS name
  ↓
Service ClusterIP
  ↓
EndpointSlice / Endpoints
  ↓
Pod IP
  ↓
Container port
```

For Ingress:

```text id="8jr2fr"
User
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
EndpointSlice
  ↓
Pod IP
  ↓
Container port
```

If traffic fails, you debug each link.

```text id="j59rib"
Can DNS resolve the Service?
Does the Service exist?
Does the Service selector match Pods?
Does the Service have endpoints?
Is targetPort correct?
Are Pods Ready?
Is NetworkPolicy blocking traffic?
Is kube-proxy / CNI working?
```

Kubernetes Services can target Pods by selector, and Services can map a Service port to a Pod `targetPort`; the `targetPort` can be a number or a named port from the Pod. ([Kubernetes][1])

---

# 4. Create Notes

```bash id="dbkbjn"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/notes/service-dns-mental-model.md
```

Paste:

```markdown id="kw5ji8"
# Service and DNS Mental Model

## Service Path

Client -> DNS -> Service ClusterIP -> EndpointSlice -> Pod IP -> containerPort

## Ingress Path

User -> Ingress Controller -> Ingress -> Service -> EndpointSlice -> Pod -> container

## Service Debug Order

1. Service exists
2. Service selector is correct
3. Pod labels match selector
4. Pods are Ready
5. EndpointSlice has endpoints
6. targetPort maps to real containerPort or named port
7. DNS resolves
8. NetworkPolicy allows traffic
9. kube-proxy/CNI are healthy
10. Ingress points to correct Service and port

## Golden Rule

If a Service has no endpoints, fix labels, selectors, or readiness before blaming DNS.
```

---

# 5. First Commands for Service/DNS Incidents

Create note:

```bash id="pft0o6"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/notes/service-dns-debug-commands.md
```

Paste:

````markdown id="na5b7l"
# Service and DNS Debug Commands

## Service

```bash
kubectl get svc -n NAMESPACE
kubectl describe svc SERVICE -n NAMESPACE
````

## Endpoints and EndpointSlices

```bash id="91ljsy"
kubectl get endpoints SERVICE -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE
kubectl describe endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE
```

## Pods and labels

```bash id="8043gt"
kubectl get pods -n NAMESPACE --show-labels
kubectl get pods -n NAMESPACE -l key=value -o wide
```

## DNS debug Pod

```bash id="24cgzg"
kubectl run dns-debug -n NAMESPACE --image=registry.k8s.io/e2e-test-images/agnhost:2.39 --restart=Never -- sleep 3600
```

## DNS lookup

```bash id="3581mz"
kubectl exec -n NAMESPACE dns-debug -- nslookup SERVICE
kubectl exec -n NAMESPACE dns-debug -- nslookup SERVICE.NAMESPACE.svc.cluster.local
```

## Connectivity

```bash id="3vv8il"
kubectl exec -n NAMESPACE dns-debug -- wget -qO- http://SERVICE
kubectl exec -n NAMESPACE dns-debug -- wget -qO- http://SERVICE.NAMESPACE.svc.cluster.local
```

## CoreDNS

```bash id="mh8odp"
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
kubectl get svc -n kube-system kube-dns
```

```id="rvyx7m"

Kubernetes’ DNS debugging guide recommends using a DNS test Pod, checking local DNS config from inside the Pod, verifying DNS Pods in `kube-system`, and inspecting DNS service/logs when lookups fail. :contentReference[oaicite:2]{index=2}
```

---

# 6. Create Healthy Baseline App

```bash id="z6x78f"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/00-healthy-service-demo.yaml
```

Paste:

```yaml id="6ez7z0"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-demo
  namespace: dev
  labels:
    app: service-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: service-demo
  template:
    metadata:
      labels:
        app: service-demo
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=service-demo-ok"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
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
  name: service-demo
  namespace: dev
  labels:
    app: service-demo
spec:
  type: ClusterIP
  selector:
    app: service-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="swb2y1"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/00-healthy-service-demo.yaml
```

Validate:

```bash id="3t8q3w"
kubectl rollout status deployment/service-demo -n dev --timeout=120s

kubectl get deploy,pods,svc,endpoints,endpointslice -n dev -l app=service-demo -o wide
```

Test with port-forward:

```bash id="t5qsfo"
kubectl port-forward -n dev svc/service-demo 18081:80
```

Another terminal:

```bash id="p6o3zy"
curl http://127.0.0.1:18081
```

Expected:

```text id="ufgyv4"
service-demo-ok
```

Stop port-forward:

```text id="g5nl6g"
Ctrl + C
```

---

# 7. Create Debug Pod

Use a debug Pod with DNS tools.

```bash id="6zscvf"
kubectl run dns-debug \
  -n dev \
  --image=registry.k8s.io/e2e-test-images/agnhost:2.39 \
  --restart=Never \
  -- sleep 3600
```

Wait:

```bash id="ckaatn"
kubectl wait --for=condition=Ready pod/dns-debug -n dev --timeout=120s
```

Test Service DNS:

```bash id="43mss6"
kubectl exec -n dev dns-debug -- nslookup service-demo

kubectl exec -n dev dns-debug -- nslookup service-demo.dev.svc.cluster.local
```

Test HTTP:

```bash id="3aqr45"
kubectl exec -n dev dns-debug -- wget -qO- http://service-demo

kubectl exec -n dev dns-debug -- wget -qO- http://service-demo.dev.svc.cluster.local
```

Expected:

```text id="wyfzmm"
service-demo-ok
```

Kubernetes creates DNS records for Services and Pods; for normal Services, DNS resolves the Service name to the Service’s cluster IP. ([Kubernetes][2])

---

# 8. Incident 1 — Service Selector Mismatch

This is the most common Service issue.

Create broken Service:

```bash id="kg8895"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/01-selector-mismatch.yaml
```

Paste:

```yaml id="nffk3r"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selector-mismatch-demo
  namespace: dev
  labels:
    app: selector-mismatch-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: selector-mismatch-demo
  template:
    metadata:
      labels:
        app: selector-mismatch-demo
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=selector-mismatch-ok"
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
  name: selector-mismatch-demo
  namespace: dev
  labels:
    app: selector-mismatch-demo
spec:
  type: ClusterIP
  selector:
    app: wrong-label
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="hho8nv"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/01-selector-mismatch.yaml
kubectl rollout status deployment/selector-mismatch-demo -n dev
```

Debug:

```bash id="i9stdt"
kubectl get svc selector-mismatch-demo -n dev
kubectl describe svc selector-mismatch-demo -n dev

kubectl get pods -n dev --show-labels | grep selector-mismatch-demo

kubectl get endpoints selector-mismatch-demo -n dev

kubectl get endpointslice -n dev -l kubernetes.io/service-name=selector-mismatch-demo
```

Expected:

```text id="49nvjk"
Service exists.
Pods exist.
Endpoints are empty.
```

Test:

```bash id="9jyhjh"
kubectl exec -n dev dns-debug -- nslookup selector-mismatch-demo

kubectl exec -n dev dns-debug -- wget -T 3 -qO- http://selector-mismatch-demo || true
```

Important observation:

```text id="vmlq7q"
DNS may resolve because the Service exists.
HTTP fails because the Service has no backend endpoints.
```

Fix selector:

```bash id="77epwo"
kubectl patch service selector-mismatch-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/selector/app",
      "value": "selector-mismatch-demo"
    }
  ]'
```

Validate:

```bash id="d9gn3q"
kubectl get endpoints selector-mismatch-demo -n dev

kubectl get endpointslice -n dev -l kubernetes.io/service-name=selector-mismatch-demo

kubectl exec -n dev dns-debug -- wget -qO- http://selector-mismatch-demo
```

Expected:

```text id="84rqy3"
selector-mismatch-ok
```

Clean:

```bash id="n3uiix"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/01-selector-mismatch.yaml --ignore-not-found=true
```

---

# 9. Incident 2 — Wrong `targetPort`

A Service has:

```text id="lsyhrx"
port:
  Service port clients use

targetPort:
  Pod/container port the Service forwards to
```

If `targetPort` is wrong, endpoints may exist but traffic fails.

Create:

```bash id="kuvq3g"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/02-wrong-targetport.yaml
```

Paste:

```yaml id="828wg6"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-targetport-demo
  namespace: dev
  labels:
    app: wrong-targetport-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wrong-targetport-demo
  template:
    metadata:
      labels:
        app: wrong-targetport-demo
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=wrong-targetport-fixed"
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
  name: wrong-targetport-demo
  namespace: dev
  labels:
    app: wrong-targetport-demo
spec:
  type: ClusterIP
  selector:
    app: wrong-targetport-demo
  ports:
    - name: http
      port: 80
      targetPort: 9999
```

Apply:

```bash id="vrkw7l"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/02-wrong-targetport.yaml
kubectl rollout status deployment/wrong-targetport-demo -n dev
```

Debug:

```bash id="ktk8vr"
kubectl get endpoints wrong-targetport-demo -n dev

kubectl describe svc wrong-targetport-demo -n dev

kubectl get pod -n dev -l app=wrong-targetport-demo -o yaml | grep -A5 "ports:"
```

Test:

```bash id="57kzco"
kubectl exec -n dev dns-debug -- wget -T 3 -qO- http://wrong-targetport-demo || true
```

Expected:

```text id="2l97r0"
DNS resolves.
Endpoints may exist.
HTTP fails because Service forwards to port 9999 instead of 8080.
```

Fix:

```bash id="j6a2yo"
kubectl patch service wrong-targetport-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/ports/0/targetPort",
      "value": "http"
    }
  ]'
```

Validate:

```bash id="jxk2ue"
kubectl exec -n dev dns-debug -- wget -qO- http://wrong-targetport-demo
```

Expected:

```text id="6q1ybh"
wrong-targetport-fixed
```

Clean:

```bash id="f1gpqq"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/02-wrong-targetport.yaml --ignore-not-found=true
```

---

# 10. Incident 3 — Wrong Named Port

Named ports are useful, but the names must match.

Create:

```bash id="d6586e"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/03-wrong-named-port.yaml
```

Paste:

```yaml id="mze5dq"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-named-port-demo
  namespace: dev
  labels:
    app: wrong-named-port-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wrong-named-port-demo
  template:
    metadata:
      labels:
        app: wrong-named-port-demo
    spec:
      containers:
        - name: web
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=wrong-named-port-fixed"
          ports:
            - name: web-http
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
  name: wrong-named-port-demo
  namespace: dev
  labels:
    app: wrong-named-port-demo
spec:
  type: ClusterIP
  selector:
    app: wrong-named-port-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="xy822l"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/03-wrong-named-port.yaml
kubectl rollout status deployment/wrong-named-port-demo -n dev
```

Debug:

```bash id="7q2jh8"
kubectl describe svc wrong-named-port-demo -n dev

kubectl get endpointslice -n dev -l kubernetes.io/service-name=wrong-named-port-demo -o yaml
```

Test:

```bash id="orwn28"
kubectl exec -n dev dns-debug -- wget -T 3 -qO- http://wrong-named-port-demo || true
```

Fix by matching targetPort to `web-http`:

```bash id="m9izjn"
kubectl patch service wrong-named-port-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/ports/0/targetPort",
      "value": "web-http"
    }
  ]'
```

Validate:

```bash id="nj0t9p"
kubectl exec -n dev dns-debug -- wget -qO- http://wrong-named-port-demo
```

Clean:

```bash id="o5a9u9"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/03-wrong-named-port.yaml --ignore-not-found=true
```

---

# 11. Incident 4 — Pod Running but Not Ready

A Service only routes to ready endpoints for normal use.

If Pods are Running but not Ready:

```text id="ma4x55"
Service may have no ready endpoints.
Ingress may return 503.
Client traffic may fail.
```

Create:

```bash id="u5mnln"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/04-running-not-ready.yaml
```

Paste:

```yaml id="equmqk"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: running-not-ready-demo
  namespace: dev
  labels:
    app: running-not-ready-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: running-not-ready-demo
  template:
    metadata:
      labels:
        app: running-not-ready-demo
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /not-ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
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
  name: running-not-ready-demo
  namespace: dev
  labels:
    app: running-not-ready-demo
spec:
  type: ClusterIP
  selector:
    app: running-not-ready-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="8zzjxq"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/04-running-not-ready.yaml
```

Debug:

```bash id="438zdr"
kubectl get pods -n dev -l app=running-not-ready-demo

kubectl describe pod -n dev -l app=running-not-ready-demo

kubectl get endpoints running-not-ready-demo -n dev

kubectl get endpointslice -n dev -l kubernetes.io/service-name=running-not-ready-demo -o yaml
```

Test:

```bash id="my1dml"
kubectl exec -n dev dns-debug -- wget -T 3 -qO- http://running-not-ready-demo || true
```

Expected:

```text id="zd89uw"
Pod Running but 0/1 Ready.
Readiness probe failed.
Service has no ready endpoint for traffic.
```

Fix readiness path:

```bash id="2eu93b"
kubectl patch deployment running-not-ready-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
      "value": "/"
    }
  ]'
```

Validate:

```bash id="a16kk0"
kubectl rollout status deployment/running-not-ready-demo -n dev
kubectl get endpoints running-not-ready-demo -n dev
kubectl exec -n dev dns-debug -- wget -qO- http://running-not-ready-demo
```

Clean:

```bash id="bsvtok"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/04-running-not-ready.yaml --ignore-not-found=true
```

---

# 12. DNS Names You Must Know

Inside the same namespace:

```text id="itvf3k"
http://service-name
```

From another namespace:

```text id="gz40rh"
http://service-name.namespace
```

Fully qualified:

```text id="ke7gzr"
http://service-name.namespace.svc.cluster.local
```

Examples:

```bash id="h8olp8"
kubectl exec -n dev dns-debug -- nslookup service-demo

kubectl exec -n dev dns-debug -- nslookup service-demo.dev

kubectl exec -n dev dns-debug -- nslookup service-demo.dev.svc.cluster.local
```

From another namespace:

```bash id="1bb22g"
kubectl create namespace dns-other --dry-run=client -o yaml | kubectl apply -f -

kubectl run dns-debug-other \
  -n dns-other \
  --image=registry.k8s.io/e2e-test-images/agnhost:2.39 \
  --restart=Never \
  -- sleep 3600

kubectl wait --for=condition=Ready pod/dns-debug-other -n dns-other --timeout=120s
```

Test:

```bash id="c38fs6"
kubectl exec -n dns-other dns-debug-other -- nslookup service-demo || true

kubectl exec -n dns-other dns-debug-other -- nslookup service-demo.dev.svc.cluster.local

kubectl exec -n dns-other dns-debug-other -- wget -qO- http://service-demo.dev.svc.cluster.local
```

Expected:

```text id="lwf73s"
service-demo alone may fail from another namespace.
service-demo.dev.svc.cluster.local should work.
```

Clean later:

```bash id="1wgeje"
kubectl delete namespace dns-other --ignore-not-found=true
```

---

# 13. CoreDNS Debugging

CoreDNS is usually installed as the cluster DNS provider.

Check CoreDNS Pods:

```bash id="q5f3qu"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

Check kube-dns Service:

```bash id="a37icm"
kubectl get svc kube-dns -n kube-system
kubectl describe svc kube-dns -n kube-system
```

Check logs:

```bash id="w0veyl"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
```

Check config:

```bash id="g3zrxj"
kubectl get configmap coredns -n kube-system -o yaml
```

From inside a Pod:

```bash id="p7kbl3"
kubectl exec -n dev dns-debug -- cat /etc/resolv.conf
```

Expected search domains:

```text id="b3m4t0"
dev.svc.cluster.local
svc.cluster.local
cluster.local
```

The Kubernetes DNS debugging guide recommends checking the test Pod’s `/etc/resolv.conf`, verifying CoreDNS Pods are running, and inspecting the DNS service and logs when lookups fail. ([Kubernetes][2])

---

# 14. Incident 5 — NetworkPolicy Blocking DNS

This is common after adding default deny egress.

Create namespace:

```bash id="xdxb6a"
kubectl create namespace dns-policy-lab --dry-run=client -o yaml | kubectl apply -f -
```

Create app + default deny egress:

```bash id="4i0m64"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/05-networkpolicy-blocks-dns.yaml
```

Paste:

```yaml id="tmon6v"
apiVersion: v1
kind: Pod
metadata:
  name: dns-policy-debug
  namespace: dns-policy-lab
  labels:
    app: dns-policy-debug
spec:
  containers:
    - name: debug
      image: registry.k8s.io/e2e-test-images/agnhost:2.39
      command: ["sleep", "3600"]
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
  name: default-deny-egress
  namespace: dns-policy-lab
spec:
  podSelector: {}
  policyTypes:
    - Egress
```

Apply:

```bash id="6w5v27"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/05-networkpolicy-blocks-dns.yaml

kubectl wait --for=condition=Ready pod/dns-policy-debug -n dns-policy-lab --timeout=120s
```

Test DNS:

```bash id="fdpyba"
kubectl exec -n dns-policy-lab dns-policy-debug -- nslookup kubernetes.default.svc.cluster.local || true
```

Expected with enforcing CNI:

```text id="lmd8xm"
DNS timeout or failure.
```

Expected without enforcing CNI:

```text id="ii2szv"
DNS may still work if your CNI does not enforce NetworkPolicy.
```

Create DNS allow policy:

```bash id="oaodvl"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/06-allow-dns-egress.yaml
```

Paste:

```yaml id="ampm7o"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: dns-policy-lab
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

```bash id="i77q6a"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests/06-allow-dns-egress.yaml
```

Retest:

```bash id="1zt31j"
kubectl exec -n dns-policy-lab dns-policy-debug -- nslookup kubernetes.default.svc.cluster.local || true
```

Clean:

```bash id="oy9xyb"
kubectl delete namespace dns-policy-lab --ignore-not-found=true
```

NetworkPolicy enforcement depends on a compatible CNI plugin; if your local kind CNI does not enforce policies, this lab still gives you the correct production YAML pattern. ([Kubernetes][1])

---

# 15. kube-proxy and EndpointSlice Concept

Do not deep dive too much yet, but understand the traffic responsibility.

```text id="b1kall"
Service:
  stable frontend abstraction

EndpointSlice:
  list of backend Pod IPs and ports

kube-proxy:
  runs on nodes and implements Service forwarding rules

CoreDNS:
  resolves Service DNS names
```

The kube-proxy reference describes it as the Kubernetes network proxy that runs on each node and reflects Services from the Kubernetes API on each node. EndpointSlices track backend IP addresses for Services and help Kubernetes scale backend tracking efficiently. ([Kubernetes][3])

Debug kube-proxy:

```bash id="42qo00"
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide || true

kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=100 || true
```

In some clusters, kube-proxy labels may differ.

List:

```bash id="rl70g7"
kubectl get pods -n kube-system --show-labels | grep kube-proxy || true
```

---

# 16. Ingress-to-Service Debug Path

If Ingress fails, do not start at Ingress only.

Follow the chain:

```text id="11dw9t"
1. Ingress Controller Pod running?
2. IngressClass correct?
3. Ingress host/path correct?
4. Backend Service exists?
5. Service port correct?
6. Service has endpoints?
7. Pod readiness OK?
8. App listens on targetPort?
```

Commands:

```bash id="aqk9pu"
kubectl get ingress -n dev
kubectl describe ingress INGRESS_NAME -n dev

kubectl get svc SERVICE_NAME -n dev
kubectl describe svc SERVICE_NAME -n dev

kubectl get endpoints SERVICE_NAME -n dev
kubectl get pods -n dev --show-labels

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

For your `demo-node-api`:

```bash id="5ubtxb"
kubectl get ingress demo-node-api -n dev
kubectl describe ingress demo-node-api -n dev

kubectl get svc,endpoints demo-node-api -n dev

kubectl get pods -n dev -l app.kubernetes.io/name=demo-node-api -o wide
```

Test direct Service first:

```bash id="b2l694"
kubectl port-forward -n dev svc/demo-node-api 3002:80

curl http://127.0.0.1:3002/health
```

Then test Ingress:

```bash id="k4w2q2"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

curl -H "Host: api.localdev.me" http://127.0.0.1:8080/health
```

Rule:

```text id="7m0gmo"
If Service direct test fails, fix Service/Pod first.
If Service direct test works but Ingress fails, debug Ingress.
```

---

# 17. Create Service/DNS Summary Script

```bash id="o4wgl2"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/service-dns-summary.sh
```

Paste:

```bash id="2pj2p5"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
SERVICE="${SERVICE:-service-demo}"

echo "===== Service/DNS Summary ====="
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE"

echo
echo "Service:"
kubectl get svc "$SERVICE" -n "$NAMESPACE" -o wide || true
kubectl describe svc "$SERVICE" -n "$NAMESPACE" || true

echo
echo "Endpoints:"
kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o wide || true

echo
echo "EndpointSlices:"
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name="$SERVICE" -o wide || true

echo
echo "Pods in namespace with labels:"
kubectl get pods -n "$NAMESPACE" --show-labels -o wide || true

echo
echo "Recent namespace events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "CoreDNS:"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide || true
kubectl get svc kube-dns -n kube-system || true
```

Make executable:

```bash id="h6bdgl"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/service-dns-summary.sh
```

Run:

```bash id="rw44lk"
NAMESPACE=dev SERVICE=service-demo \
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/service-dns-summary.sh
```

---

# 18. Create DNS Test Script

```bash id="vll6ks"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/dns-connectivity-test.sh
```

Paste:

```bash id="9f52ni"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
DEBUG_POD="${DEBUG_POD:-dns-debug}"
SERVICE="${SERVICE:-service-demo}"
SERVICE_NAMESPACE="${SERVICE_NAMESPACE:-$NAMESPACE}"
PORT_PATH="${PORT_PATH:-/}"

echo "===== DNS Connectivity Test ====="
echo "Namespace: $NAMESPACE"
echo "Debug Pod: $DEBUG_POD"
echo "Service: $SERVICE"
echo "Service namespace: $SERVICE_NAMESPACE"

if ! kubectl get pod "$DEBUG_POD" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Creating debug pod..."
  kubectl run "$DEBUG_POD" \
    -n "$NAMESPACE" \
    --image=registry.k8s.io/e2e-test-images/agnhost:2.39 \
    --restart=Never \
    -- sleep 3600
fi

kubectl wait --for=condition=Ready pod/"$DEBUG_POD" -n "$NAMESPACE" --timeout=120s

echo
echo "resolv.conf:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- cat /etc/resolv.conf || true

echo
echo "nslookup short name:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- nslookup "$SERVICE" || true

echo
echo "nslookup namespace name:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- nslookup "$SERVICE.$SERVICE_NAMESPACE" || true

echo
echo "nslookup FQDN:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- nslookup "$SERVICE.$SERVICE_NAMESPACE.svc.cluster.local" || true

echo
echo "HTTP short name:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- wget -T 5 -qO- "http://$SERVICE$PORT_PATH" || true

echo
echo
echo "HTTP FQDN:"
kubectl exec -n "$NAMESPACE" "$DEBUG_POD" -- wget -T 5 -qO- "http://$SERVICE.$SERVICE_NAMESPACE.svc.cluster.local$PORT_PATH" || true

echo
echo
echo "DNS connectivity test completed."
```

Make executable:

```bash id="i85c67"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/dns-connectivity-test.sh
```

Run:

```bash id="drxecz"
NAMESPACE=dev SERVICE=service-demo \
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/dns-connectivity-test.sh
```

---

# 19. Create Endpoint Debug Script

```bash id="6ikqxb"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/endpoint-debug.sh
```

Paste:

```bash id="nznarh"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
SERVICE="${SERVICE:-service-demo}"

echo "===== Endpoint Debug ====="
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE"

SELECTOR="$(kubectl get svc "$SERVICE" -n "$NAMESPACE" -o jsonpath='{range $k,$v := .spec.selector}{$k}{"="}{$v}{","}{end}' 2>/dev/null | sed 's/,$//' || true)"

echo
echo "Service selector: ${SELECTOR:-<none>}"

echo
echo "Service YAML summary:"
kubectl get svc "$SERVICE" -n "$NAMESPACE" -o yaml | sed -n '1,120p' || true

echo
echo "Endpoints:"
kubectl get endpoints "$SERVICE" -n "$NAMESPACE" -o yaml || true

echo
echo "EndpointSlices:"
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name="$SERVICE" -o yaml || true

if [ -n "$SELECTOR" ]; then
  echo
  echo "Pods matching selector:"
  kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" -o wide --show-labels || true
fi

echo
echo "All Pod labels in namespace:"
kubectl get pods -n "$NAMESPACE" --show-labels || true
```

Make executable:

```bash id="vhl1b6"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/endpoint-debug.sh
```

Run:

```bash id="62zinb"
NAMESPACE=dev SERVICE=service-demo \
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/endpoint-debug.sh
```

---

# 20. Create Service/DNS Troubleshooting Runbook

```bash id="560ckw"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/runbooks/service-dns-troubleshooting-runbook.md
```

Paste:

````markdown id="r69q4z"
# Service and DNS Troubleshooting Runbook

## 1. Check Service

```bash
kubectl get svc SERVICE -n NAMESPACE
kubectl describe svc SERVICE -n NAMESPACE
````

Check:

* type
* ClusterIP
* ports
* targetPort
* selector

## 2. Check endpoints

```bash id="f8tav8"
kubectl get endpoints SERVICE -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE
```

If endpoints are empty, check:

* Service selector
* Pod labels
* Pod readiness
* namespace

## 3. Check Pods and labels

```bash id="wmgsi7"
kubectl get pods -n NAMESPACE --show-labels
kubectl get pods -n NAMESPACE -l key=value -o wide
```

## 4. Check targetPort

```bash id="ov0wq7"
kubectl describe svc SERVICE -n NAMESPACE
kubectl get pod POD -n NAMESPACE -o yaml | grep -A10 ports
```

If using named ports, ensure Service `targetPort` exactly matches container port `name`.

## 5. Test DNS

```bash id="ijq72p"
kubectl run dns-debug -n NAMESPACE --image=registry.k8s.io/e2e-test-images/agnhost:2.39 --restart=Never -- sleep 3600

kubectl exec -n NAMESPACE dns-debug -- nslookup SERVICE
kubectl exec -n NAMESPACE dns-debug -- nslookup SERVICE.NAMESPACE.svc.cluster.local
```

## 6. Test connectivity

```bash id="r8hpjm"
kubectl exec -n NAMESPACE dns-debug -- wget -T 5 -qO- http://SERVICE
kubectl exec -n NAMESPACE dns-debug -- wget -T 5 -qO- http://SERVICE.NAMESPACE.svc.cluster.local
```

## 7. Check CoreDNS

```bash id="j8k40j"
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=100
kubectl get svc kube-dns -n kube-system
kubectl get configmap coredns -n kube-system -o yaml
```

## 8. Check NetworkPolicy

```bash id="dxa2gf"
kubectl get networkpolicy -n NAMESPACE
kubectl describe networkpolicy -n NAMESPACE
```

Look for:

* default deny egress
* missing DNS egress allow
* missing destination ingress allow
* missing source egress allow

## 9. Ingress path

```bash id="5v4ly9"
kubectl get ingress -n NAMESPACE
kubectl describe ingress INGRESS -n NAMESPACE
kubectl get svc,endpoints -n NAMESPACE
```

## Golden Rule

DNS resolving does not mean traffic will work.
A Service also needs valid endpoints and a correct targetPort.

````id="a3efvg"

---

# 21. Create Production Traffic Path Runbook

```bash id="m7yl9o"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/runbooks/production-traffic-path-runbook.md
````

Paste:

````markdown id="nr8fhf"
# Production Traffic Path Debugging Runbook

## Path

User -> Load Balancer -> Ingress Controller -> Ingress -> Service -> EndpointSlice -> Pod -> Container

## Step 1 — Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
````

## Step 2 — Check Ingress

```bash id="adnknu"
kubectl get ingress -n NAMESPACE
kubectl describe ingress APP -n NAMESPACE
```

Check:

* host
* path
* ingressClassName
* backend Service
* backend port
* TLS secret

## Step 3 — Check Service

```bash id="zr5j1i"
kubectl get svc APP -n NAMESPACE
kubectl describe svc APP -n NAMESPACE
```

Check:

* selector
* port
* targetPort

## Step 4 — Check Endpoints

```bash id="xg8p2f"
kubectl get endpoints APP -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=APP
```

No endpoints means:

* selector mismatch
* Pods not Ready
* wrong namespace
* labels missing

## Step 5 — Check Pods

```bash id="s80z0r"
kubectl get pods -n NAMESPACE --show-labels
kubectl describe pod POD -n NAMESPACE
kubectl logs POD -n NAMESPACE --tail=100
```

## Step 6 — Test inside cluster

```bash id="2c72wo"
kubectl exec -n NAMESPACE dns-debug -- wget -qO- http://SERVICE
```

## Step 7 — Test Ingress host

```bash id="a74kj4"
curl -H "Host: HOSTNAME" http://INGRESS_CONTROLLER_IP/PATH
```

## Rule

Test from inside out:

1. Pod direct
2. Service
3. Ingress
4. external load balancer
5. DNS/domain

````id="yvahj1"

---

# 22. Run All Labs Script

```bash id="wy90gf"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/run-service-dns-labs.sh
````

Paste:

```bash id="eekwfu"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/00-healthy-service-demo.yaml"
kubectl rollout status deployment/service-demo -n dev --timeout=120s

kubectl run dns-debug \
  -n dev \
  --image=registry.k8s.io/e2e-test-images/agnhost:2.39 \
  --restart=Never \
  -- sleep 3600 \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl wait --for=condition=Ready pod/dns-debug -n dev --timeout=120s

kubectl apply -f "$BASE/01-selector-mismatch.yaml"
kubectl apply -f "$BASE/02-wrong-targetport.yaml"
kubectl apply -f "$BASE/03-wrong-named-port.yaml"
kubectl apply -f "$BASE/04-running-not-ready.yaml"

echo "Service/DNS labs applied."
echo "Run:"
echo "NAMESPACE=dev SERVICE=service-demo ./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/service-dns-summary.sh"
```

Make executable:

```bash id="s2nmj2"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/run-service-dns-labs.sh
```

Run:

```bash id="ds75x2"
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/run-service-dns-labs.sh
```

---

# 23. Cleanup Script

```bash id="guz4ds"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/cleanup-lesson-11-4.sh
```

Paste:

```bash id="14a2i7"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.4 ====="

kubectl delete -f "$BASE/00-healthy-service-demo.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-selector-mismatch.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-wrong-targetport.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-wrong-named-port.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-running-not-ready.yaml" --ignore-not-found=true

kubectl delete pod dns-debug -n dev --ignore-not-found=true

kubectl delete namespace dns-other --ignore-not-found=true
kubectl delete namespace dns-policy-lab --ignore-not-found=true

echo "Lesson 11.4 demo resources cleaned."
```

Make executable:

```bash id="2ku94c"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/cleanup-lesson-11-4.sh
```

Run cleanup:

```bash id="3khmbj"
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/cleanup-lesson-11-4.sh
```

---

# 24. Validation Script

```bash id="wiym6d"
nano 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/validate-lesson-11-4.sh
```

Paste:

```bash id="g9cn04"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.4 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/service-dns-mental-model.md"
test -f "$BASE/notes/service-dns-debug-commands.md"

test -f "$BASE/runbooks/service-dns-troubleshooting-runbook.md"
test -f "$BASE/runbooks/production-traffic-path-runbook.md"

test -f "$BASE/manifests/00-healthy-service-demo.yaml"
test -f "$BASE/manifests/01-selector-mismatch.yaml"
test -f "$BASE/manifests/02-wrong-targetport.yaml"
test -f "$BASE/manifests/03-wrong-named-port.yaml"
test -f "$BASE/manifests/04-running-not-ready.yaml"
test -f "$BASE/manifests/05-networkpolicy-blocks-dns.yaml"
test -f "$BASE/manifests/06-allow-dns-egress.yaml"

test -x "$BASE/scripts/service-dns-summary.sh"
test -x "$BASE/scripts/dns-connectivity-test.sh"
test -x "$BASE/scripts/endpoint-debug.sh"
test -x "$BASE/scripts/run-service-dns-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-4.sh"

kubectl get namespace dev >/dev/null

kubectl apply -f "$BASE/manifests/00-healthy-service-demo.yaml" >/dev/null
kubectl rollout status deployment/service-demo -n dev --timeout=120s >/dev/null

kubectl get svc service-demo -n dev >/dev/null
kubectl get endpoints service-demo -n dev >/dev/null

ENDPOINTS="$(kubectl get endpoints service-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: service-demo has no endpoints"
  exit 1
fi

echo "service-demo endpoints: $ENDPOINTS"
echo "Lesson 11.4 validation passed."
```

Make executable:

```bash id="qozsp2"
chmod +x 11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/validate-lesson-11-4.sh
```

Run:

```bash id="0gj7kj"
./11-advanced-kubernetes-troubleshooting/11.4-service-dns-troubleshooting/scripts/validate-lesson-11-4.sh
```

---

# 25. Real Production Debug Mapping

```text id="coyq97"
Service exists but DNS fails:
  check CoreDNS, kube-dns Service, Pod resolv.conf, NetworkPolicy DNS egress

DNS resolves but HTTP fails:
  check endpoints, targetPort, Pod readiness, NetworkPolicy

Service has no endpoints:
  check selector, Pod labels, readiness, namespace

Endpoints exist but connection fails:
  check targetPort, named port, container listens, NetworkPolicy, kube-proxy/CNI

Ingress returns 503:
  check backend Service endpoints and readiness

Ingress returns 404:
  check host, path, ingressClassName, controller routing

Works in same namespace but fails from another namespace:
  use service.namespace.svc.cluster.local and check NetworkPolicy

NetworkPolicy added and DNS broke:
  allow UDP/TCP 53 egress to CoreDNS
```

---

# 26. Common Mistakes

## Mistake 1: Blaming DNS when endpoints are empty

Check:

```bash id="9xvx7r"
kubectl get endpoints SERVICE -n NAMESPACE
```

If endpoints are empty, DNS is not the main issue.

---

## Mistake 2: Confusing Service `port` and `targetPort`

```text id="yuz9pe"
port:
  what clients call on the Service

targetPort:
  where Service forwards inside the Pod
```

---

## Mistake 3: Using short Service name from another namespace

From another namespace, use:

```text id="gectvm"
service-name.namespace.svc.cluster.local
```

---

## Mistake 4: Forgetting readiness affects endpoints

A Running Pod is not enough.

It must be Ready.

---

## Mistake 5: Adding default deny egress and forgetting DNS

Allow:

```text id="h82668"
UDP 53
TCP 53
to CoreDNS
```

---

# 27. Interview Explanation

Use this:

```text id="ly3ugf"
When troubleshooting Kubernetes Service and DNS issues, I follow the traffic path from DNS to Service to EndpointSlice to Pod. I first check whether the Service exists, then inspect its selector, ports, and targetPort. Next I check Endpoints and EndpointSlices. If endpoints are empty, I inspect Pod labels and readiness because the Service is not selecting ready backends.

For DNS, I test from a debug Pod using nslookup against the short name, namespace-qualified name, and full service FQDN. I check CoreDNS Pods, kube-dns Service, CoreDNS logs, and the Pod’s /etc/resolv.conf. If DNS works but HTTP fails, I focus on endpoints, targetPort, NetworkPolicy, and whether the app is actually listening. For Ingress failures, I test the Service directly first, then debug Ingress host/path and controller logs.
```

Resume bullet:

```text id="81hb0d"
Built Kubernetes Service and DNS troubleshooting labs covering selector mismatches, empty endpoints, targetPort and named-port failures, Running-but-not-Ready Pods, ClusterIP connectivity, CoreDNS diagnostics, cross-namespace DNS, NetworkPolicy DNS egress failures, EndpointSlice inspection, and production traffic-path runbooks.
```

---

# 28. Commit Lesson 11.4

```bash id="7kg5y6"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes Service and DNS troubleshooting labs"

git push
```

---

# 29. Next Lesson

```text id="t78hws"
Lesson 11.5 — Ingress and TLS Troubleshooting
```

We will cover:

```text id="6hh2x8"
Ingress Controller not running
wrong ingressClassName
host mismatch
path mismatch
backend Service missing
backend Service has no endpoints
Ingress 404 vs 503
TLS Secret missing
TLS certificate mismatch
self-signed TLS in local lab
curl --resolve
nginx ingress controller logs
production Ingress debugging flow
```

[1]: https://kubernetes.io/docs/concepts/services-networking/service/?utm_source=chatgpt.com "Service"
[2]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/?utm_source=chatgpt.com "Debugging DNS Resolution"
[3]: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/?utm_source=chatgpt.com "kube-proxy"
