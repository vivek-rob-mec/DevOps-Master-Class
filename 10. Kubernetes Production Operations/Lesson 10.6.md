# Lesson 10.6 — Ingress, Ingress Controller, TLS, Host/Path Routing, and Production Traffic Flow

In Lesson 10.5, you learned **Services, ClusterIP, NodePort, LoadBalancer, DNS, and service discovery**.

Now we learn how external HTTP/HTTPS traffic reaches applications inside Kubernetes.

A Kubernetes **Ingress** manages external access to Services, typically HTTP/HTTPS. It can provide host-based routing, path-based routing, load balancing, and TLS termination, but only when an **Ingress Controller** is actually running in the cluster. Creating only an Ingress object has no effect without a controller. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="odrw0t"
10.6.1   Ingress mental model
10.6.2   Ingress vs Service
10.6.3   Why an Ingress Controller is mandatory
10.6.4   NGINX Ingress Controller setup
10.6.5   Host-based routing
10.6.6   Path-based routing
10.6.7   ingressClassName
10.6.8   TLS Secret basics
10.6.9   Self-signed TLS for local lab
10.6.10  HTTP to HTTPS concept
10.6.11  Ingress annotations
10.6.12  Debugging 404, 502, 503
10.6.13  Production traffic flow for demo-node-api
10.6.14  Validation script
10.6.15  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="c0b3mu"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.6-ingress-controller-tls-routing/{manifests,scripts,notes,runbooks,reports,tls}
```

Check:

```bash id="lv6ptn"
tree -L 2 10.6-ingress-controller-tls-routing
```

---

# 3. Ingress Mental Model

A Service gives stable networking **inside** the cluster.

Ingress handles HTTP/HTTPS routing **from outside** the cluster.

Simple flow:

```text id="adz4kh"
User
  ↓
DNS
  ↓
Load Balancer / NodePort / Port Forward
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
Pod
  ↓
Container
```

Important:

```text id="2uu7uv"
Ingress is the routing rule.
Ingress Controller is the actual router/proxy that implements the rule.
```

Think of it like this:

```text id="xg8rou"
Ingress:
  configuration

Ingress Controller:
  running traffic proxy
```

In Kubernetes docs, Ingress exposes HTTP and HTTPS routes from outside the cluster to Services inside the cluster, and traffic routing is controlled by rules defined on the Ingress resource. ([Kubernetes][1])

---

# 4. Ingress vs Service

| Object             | Purpose                                       |
| ------------------ | --------------------------------------------- |
| Pod                | Runs containers                               |
| Deployment         | Manages Pods                                  |
| Service            | Gives stable internal networking to Pods      |
| Ingress            | Defines HTTP/HTTPS routing rules              |
| Ingress Controller | Actually receives and routes external traffic |

Example:

```text id="3enf48"
Service:
  demo-node-api.default.svc.cluster.local

Ingress:
  api.yourdatascientist.tech/
    → demo-node-api Service
```

Service answers:

```text id="28jkuw"
Which Pods should receive traffic?
```

Ingress answers:

```text id="cddjuf"
Which HTTP host/path should route to which Service?
```

---

# 5. Big Misconception: “I Created Ingress, Why Is It Not Working?”

Wrong assumption:

```text id="avmm4y"
Ingress object alone exposes my app.
```

Correct understanding:

```text id="muulz2"
Ingress object is only a routing rule.
An Ingress Controller must be installed and reachable.
```

The Kubernetes documentation is explicit: you must have an Ingress Controller to satisfy an Ingress; creating only an Ingress resource has no effect. ([Kubernetes][1])

---

# 6. Gateway API Note

Kubernetes documentation now recommends **Gateway API** over Ingress for newer designs, and the Ingress API is frozen. However, Ingress is still stable, widely used, and common in production clusters. We will learn Ingress first because it is still very common in DevOps jobs; Gateway API will come later. ([Kubernetes][1])

Simple comparison:

```text id="6xft4s"
Ingress:
  older, stable, common, simpler

Gateway API:
  newer, more expressive, better role separation
```

For your current learning path:

```text id="5bk7cx"
First learn Service + Ingress.
Then learn Gateway API later.
```

---

# 7. Create Notes

```bash id="t16qhu"
nano 10.6-ingress-controller-tls-routing/notes/ingress-mental-model.md
```

Paste:

````markdown id="i7z5w5"
# Ingress Mental Model

## Core Idea

Ingress defines HTTP/HTTPS routing rules from outside the cluster to Services inside the cluster.

## Traffic Flow

```text
User
  ↓
DNS
  ↓
Load Balancer / NodePort / port-forward
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
Pod
  ↓
Container
````

## Important Difference

Ingress:
routing rule

Ingress Controller:
actual proxy/load balancer implementation

## Golden Rule

Creating an Ingress object alone is not enough.
An Ingress Controller must be installed and reachable.

````

---

# 8. Install NGINX Ingress Controller

There are many Ingress Controllers: NGINX, Traefik, HAProxy, Envoy-based controllers, cloud-provider controllers, and others. Kubernetes supports using multiple Ingress Controllers via `IngressClass`, and an Ingress should specify `ingressClassName` when needed. :contentReference[oaicite:4]{index=4}

For this lab, we will use **ingress-nginx** because it is common and easy to test locally.

Install:

```bash id="34tsn9"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
````

Wait:

```bash id="wwlr1l"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

The ingress-nginx installation guide supports installation with `kubectl apply` using YAML manifests, and its pre-flight check waits for the controller Pod in the `ingress-nginx` namespace to become ready. ([Kubernetes][2])

Check:

```bash id="6jug8n"
kubectl get namespace ingress-nginx
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

You should see something like:

```text id="9rej7w"
ingress-nginx-controller
```

---

# 9. Local Testing Strategy

In cloud, the Ingress Controller is usually exposed with a `LoadBalancer` Service.

In kind, the external IP may stay pending unless local load-balancer support is configured.

So for reliable local learning, we will use:

```text id="b33cp6"
kubectl port-forward
```

Run this in a separate terminal:

```bash id="6cy1oq"
kubectl port-forward --namespace=ingress-nginx \
  service/ingress-nginx-controller \
  8080:80
```

Now traffic to:

```text id="8o768n"
localhost:8080
```

goes to:

```text id="zme1ue"
ingress-nginx-controller Service port 80
```

The ingress-nginx docs use this same local-testing pattern and explain that port-forwarding is not for production, but it is useful to simulate traffic entering the ingress controller during local testing. ([Kubernetes][2])

---

# 10. Create Demo App A

Create:

```bash id="bmcknq"
nano 10.6-ingress-controller-tls-routing/manifests/app-a.yaml
```

Paste:

```yaml id="pyxdew"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-a
  namespace: dev
  labels:
    app: app-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
        environment: dev
        tier: backend
    spec:
      containers:
        - name: app-a
          image: registry.k8s.io/e2e-test-images/agnhost:2.39
          args:
            - serve-hostname
            - --http=true
            - --port=8080
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: app-a
  namespace: dev
  labels:
    app: app-a
spec:
  type: ClusterIP
  selector:
    app: app-a
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="9mrt7c"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/app-a.yaml
```

Check:

```bash id="vi8i0d"
kubectl get deploy,svc,pods -n dev -l app=app-a
kubectl get endpoints app-a -n dev
```

---

# 11. Create Demo App B

Create:

```bash id="7h90vd"
nano 10.6-ingress-controller-tls-routing/manifests/app-b.yaml
```

Paste:

```yaml id="5ek4ro"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b
  namespace: dev
  labels:
    app: app-b
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
        environment: dev
        tier: backend
    spec:
      containers:
        - name: app-b
          image: registry.k8s.io/e2e-test-images/agnhost:2.39
          args:
            - serve-hostname
            - --http=true
            - --port=8080
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: app-b
  namespace: dev
  labels:
    app: app-b
spec:
  type: ClusterIP
  selector:
    app: app-b
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="mkteye"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/app-b.yaml
```

Check:

```bash id="d4lqly"
kubectl get deploy,svc,pods -n dev -l app=app-b
kubectl get endpoints app-b -n dev
```

---

# 12. Path-Based Routing

Create an Ingress that routes:

```text id="9e79oa"
/app-a → app-a Service
/app-b → app-b Service
```

Create:

```bash id="u5tf1x"
nano 10.6-ingress-controller-tls-routing/manifests/path-routing-ingress.yaml
```

Paste:

```yaml id="m3w6sz"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: nginx
  rules:
    - host: demo.localdev.me
      http:
        paths:
          - path: /app-a
            pathType: Prefix
            backend:
              service:
                name: app-a
                port:
                  number: 80
          - path: /app-b
            pathType: Prefix
            backend:
              service:
                name: app-b
                port:
                  number: 80
```

Apply:

```bash id="ajtajr"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/path-routing-ingress.yaml
```

Check:

```bash id="pfymsb"
kubectl get ingress -n dev
kubectl describe ingress path-routing-demo -n dev
```

Ingress HTTP rules match optional host and path information, and each path references a backend Service name and Service port. Host and path must match before traffic is directed to the backend Service. ([Kubernetes][1])

---

# 13. Test Path Routing

Make sure port-forward is running:

```bash id="bfdwn7"
kubectl port-forward --namespace=ingress-nginx \
  service/ingress-nginx-controller \
  8080:80
```

In another terminal:

```bash id="1nzvpa"
curl --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-a

curl --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-b
```

Expected:

```text id="48siox"
Each path should return a hostname response from a backend Pod.
```

If you get `404`, jump to the debugging section below.

---

# 14. Host-Based Routing

Host-based routing sends different domains to different Services.

Example:

```text id="g6maj9"
a.localdev.me → app-a
b.localdev.me → app-b
```

Create:

```bash id="98xllh"
nano 10.6-ingress-controller-tls-routing/manifests/host-routing-ingress.yaml
```

Paste:

```yaml id="uiqcd5"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: nginx
  rules:
    - host: a.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-a
                port:
                  number: 80
    - host: b.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-b
                port:
                  number: 80
```

Apply:

```bash id="cth0u9"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/host-routing-ingress.yaml
```

Test:

```bash id="7kb0gg"
curl --resolve a.localdev.me:8080:127.0.0.1 \
  http://a.localdev.me:8080/

curl --resolve b.localdev.me:8080:127.0.0.1 \
  http://b.localdev.me:8080/
```

Name-based virtual hosting lets Ingress route traffic to different backends based on the HTTP `Host` header. ([Kubernetes][1])

---

# 15. ingressClassName

This field tells Kubernetes which Ingress Controller should handle the Ingress.

Example:

```yaml id="elkwgo"
spec:
  ingressClassName: nginx
```

Why it matters:

```text id="j95vfg"
A cluster can have multiple Ingress Controllers.
Example:
  nginx
  traefik
  alb
  internal-nginx
  external-nginx
```

If you omit `ingressClassName`, behavior depends on whether the cluster has a default IngressClass. Kubernetes docs recommend defining a default IngressClass or explicitly specifying `ingressClassName`. ([Kubernetes][1])

Check:

```bash id="7ck1cq"
kubectl get ingressclass
kubectl describe ingressclass nginx
```

---

# 16. TLS Mental Model

TLS with Ingress usually means:

```text id="56qnkl"
Client uses HTTPS
  ↓
Ingress Controller terminates TLS
  ↓
Ingress Controller sends HTTP to Service/Pods
```

Ingress can secure traffic by referencing a Secret that contains a TLS certificate and private key. Ingress supports TLS on port 443 and assumes TLS termination at the ingress point; traffic from the Ingress Controller to the Service and Pods is then usually plaintext unless you configure additional encryption. ([Kubernetes][1])

Production flow:

```text id="97u9lq"
Browser
  HTTPS
  ↓
Load Balancer / Ingress Controller
  HTTP or HTTPS
  ↓
Service
  ↓
Pod
```

Common production options:

```text id="87bfq1"
TLS at cloud load balancer
TLS at ingress controller
TLS all the way to app
mTLS via service mesh
```

For now, learn TLS termination at Ingress.

---

# 17. Create Self-Signed TLS Certificate

For local lab:

```bash id="g4q39v"
cd ~/devops-masterclass/10-kubernetes-production-operations

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout 10.6-ingress-controller-tls-routing/tls/demo.localdev.me.key \
  -out 10.6-ingress-controller-tls-routing/tls/demo.localdev.me.crt \
  -subj "/CN=demo.localdev.me/O=devops-masterclass"
```

Create Kubernetes TLS Secret:

```bash id="3v5paj"
kubectl create secret tls demo-localdev-tls \
  -n dev \
  --cert=10.6-ingress-controller-tls-routing/tls/demo.localdev.me.crt \
  --key=10.6-ingress-controller-tls-routing/tls/demo.localdev.me.key
```

Kubernetes supports `kubectl create secret tls` for creating a TLS Secret from an existing PEM certificate and matching private key. ([Kubernetes][3])

Check:

```bash id="ge0fxn"
kubectl get secret demo-localdev-tls -n dev
kubectl describe secret demo-localdev-tls -n dev
```

---

# 18. Create TLS Ingress

Create:

```bash id="9uv3t7"
nano 10.6-ingress-controller-tls-routing/manifests/tls-ingress.yaml
```

Paste:

```yaml id="5p4xed"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - demo.localdev.me
      secretName: demo-localdev-tls
  rules:
    - host: demo.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-a
                port:
                  number: 80
```

Apply:

```bash id="y7qevx"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/tls-ingress.yaml
```

Check:

```bash id="hetj79"
kubectl get ingress tls-demo -n dev
kubectl describe ingress tls-demo -n dev
```

---

# 19. Test TLS Ingress Locally

Start HTTPS port-forward in a separate terminal:

```bash id="4qwkcy"
kubectl port-forward --namespace=ingress-nginx \
  service/ingress-nginx-controller \
  8443:443
```

Test:

```bash id="3wm64j"
curl -k --resolve demo.localdev.me:8443:127.0.0.1 \
  https://demo.localdev.me:8443/
```

Why `-k`?

```text id="7g4i6z"
Because this is a self-signed certificate.
Your system does not trust it by default.
```

In production, use a trusted certificate from:

```text id="e1i7b8"
ACM
cert-manager
Let's Encrypt
corporate CA
cloud certificate manager
```

---

# 20. HTTP to HTTPS Redirect Concept

Many production setups redirect HTTP to HTTPS.

For NGINX Ingress, this is often controlled by annotations or controller configuration.

Example annotation:

```yaml id="qsfwof"
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

Create:

```bash id="sktgyx"
nano 10.6-ingress-controller-tls-routing/manifests/tls-redirect-ingress.yaml
```

Paste:

```yaml id="wurv47"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-redirect-demo
  namespace: dev
  labels:
    app: ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - secure.localdev.me
      secretName: demo-localdev-tls
  rules:
    - host: secure.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-a
                port:
                  number: 80
```

Apply:

```bash id="sc9ai5"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/tls-redirect-ingress.yaml
```

Test HTTP:

```bash id="fobzrj"
curl -I --resolve secure.localdev.me:8080:127.0.0.1 \
  http://secure.localdev.me:8080/
```

You may see a redirect depending on the controller behavior and TLS setup.

Important:

```text id="s1h8a5"
Annotations are controller-specific.
Always check the documentation for your specific Ingress Controller.
```

The Kubernetes Ingress documentation notes that Ingress Controllers frequently use annotations to configure behavior, and that users should review their chosen controller’s documentation for supported annotations. ([Kubernetes][1])

---

# 21. Common Ingress Status Codes

## 404

Usually means:

```text id="qgi9l9"
Ingress Controller received request,
but no host/path rule matched.
```

Check:

```bash id="pq8tjv"
kubectl get ingress -n dev
kubectl describe ingress -n dev
```

Common causes:

```text id="6w4cja"
wrong Host header
wrong path
wrong ingressClassName
Ingress object not created
request going to wrong controller
```

## 502

Usually means:

```text id="rsrulk"
Ingress rule matched,
but upstream connection failed.
```

Common causes:

```text id="fn9mr9"
Service targetPort wrong
app not listening
backend connection refused
protocol mismatch
```

## 503

Usually means:

```text id="14lrh6"
Ingress rule matched,
but no healthy backend endpoints are available.
```

Common causes:

```text id="fsyo0f"
Service has no endpoints
Pods not ready
selector mismatch
readiness probe failing
```

Remember:

```text id="w4p7gk"
404 = no matching rule
502 = backend connection problem
503 = no healthy backend
```

---

# 22. Intentional 404 Demo

Send request with wrong host:

```bash id="y1klzz"
curl -i --resolve wrong.localdev.me:8080:127.0.0.1 \
  http://wrong.localdev.me:8080/app-a
```

Expected:

```text id="j7qlgp"
404 or default backend response
```

Why?

```text id="f6lp6s"
No Ingress rule matches host wrong.localdev.me.
```

Fix:

```bash id="e2qlqj"
curl -i --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-a
```

---

# 23. Intentional 503 Demo

Create Service with wrong selector:

```bash id="81n7f2"
nano 10.6-ingress-controller-tls-routing/manifests/broken-backend-service.yaml
```

Paste:

```yaml id="nwongx"
apiVersion: v1
kind: Service
metadata:
  name: broken-backend
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: does-not-exist
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

Create Ingress:

```bash id="dmxe8q"
nano 10.6-ingress-controller-tls-routing/manifests/broken-backend-ingress.yaml
```

Paste:

```yaml id="pa5623"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-backend
  namespace: dev
spec:
  ingressClassName: nginx
  rules:
    - host: broken.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: broken-backend
                port:
                  number: 80
```

Apply:

```bash id="hg3eh1"
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-service.yaml
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-ingress.yaml
```

Check:

```bash id="gvcwsu"
kubectl get endpoints broken-backend -n dev
```

Test:

```bash id="8s6fsz"
curl -i --resolve broken.localdev.me:8080:127.0.0.1 \
  http://broken.localdev.me:8080/
```

Expected:

```text id="jly8k3"
503 or backend unavailable response
```

Fix:

```bash id="kc9ifq"
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-ingress.yaml
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-service.yaml
```

---

# 24. Debug Ingress Controller Logs

Check controller Pods:

```bash id="41f0ey"
kubectl get pods -n ingress-nginx
```

Logs:

```bash id="8ssuo5"
kubectl logs -n ingress-nginx \
  -l app.kubernetes.io/component=controller \
  --tail=100
```

Follow logs:

```bash id="a8jru3"
kubectl logs -n ingress-nginx \
  -l app.kubernetes.io/component=controller \
  -f
```

In another terminal, send request:

```bash id="6hmju0"
curl --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-a
```

You should see access log activity.

---

# 25. Ingress Debugging Command Set

Memorize this:

```bash id="61fvm6"
kubectl get ingress -A
kubectl describe ingress INGRESS_NAME -n NAMESPACE

kubectl get ingressclass

kubectl get svc -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE

kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get endpointslices -n NAMESPACE -l kubernetes.io/service-name=SERVICE_NAME

kubectl get pods -n NAMESPACE --show-labels
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Debug order:

```text id="r2q6be"
1. Is the Ingress Controller running?
2. Does ingressClassName match?
3. Does host/path match the request?
4. Does backend Service exist?
5. Does backend Service port match?
6. Does Service have endpoints?
7. Are Pods ready?
8. Do controller logs show errors?
```

---

# 26. Production Traffic Flow for `demo-node-api`

Your final production flow will look like:

```text id="wma5uo"
User
  ↓
DNS: api.yourdatascientist.tech
  ↓
Cloud Load Balancer
  ↓
Ingress Controller
  ↓
Ingress: api.yourdatascientist.tech /
  ↓
Service: demo-node-api:80
  ↓
Pods: demo-node-api:3002
  ↓
Node.js Express app
```

For AWS EKS, common options are:

```text id="8ru8m6"
Option 1:
  AWS Load Balancer Controller creates ALB directly from Ingress

Option 2:
  NGINX Ingress Controller behind NLB/LoadBalancer Service

Option 3:
  Gateway API with supported controller
```

For your learning path:

```text id="jpwkbr"
Local kind:
  NGINX Ingress + port-forward

Later EKS:
  ALB Ingress or NGINX Ingress behind AWS Load Balancer
```

---

# 27. Create `demo-node-api` Ingress Base Manifest

Create:

```bash id="6oerow"
nano apps/demo-node-api/base/ingress.yaml
```

Paste:

```yaml id="vi7ocv"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: api.localdev.me
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

Important:

```text id="3r6hra"
This assumes the demo-node-api Deployment and Service exist.
We will complete that production-ready app deployment in upcoming lessons.
```

---

# 28. Ingress Runbook

Create:

```bash id="m2i9ht"
nano 10.6-ingress-controller-tls-routing/runbooks/ingress-debugging-runbook.md
```

Paste:

````markdown id="gyr1vm"
# Ingress Debugging Runbook

## Step 1 — Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
````

## Step 2 — Check Ingress Object

```bash
kubectl get ingress -n NAMESPACE
kubectl describe ingress INGRESS_NAME -n NAMESPACE
```

Check:

* ingressClassName
* host
* path
* backend Service name
* backend Service port
* TLS Secret

## Step 3 — Check Service

```bash
kubectl get svc SERVICE_NAME -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE
```

## Step 4 — Check Endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get endpointslices -n NAMESPACE -l kubernetes.io/service-name=SERVICE_NAME
```

## Step 5 — Check Pods

```bash
kubectl get pods -n NAMESPACE --show-labels
kubectl describe pod POD_NAME -n NAMESPACE
```

## Step 6 — Check Controller Logs

```bash
kubectl logs -n ingress-nginx \
  -l app.kubernetes.io/component=controller \
  --tail=100
```

## Status Code Meaning

| Code | Meaning                       |
| ---- | ----------------------------- |
| 404  | No matching Ingress host/path |
| 502  | Backend connection problem    |
| 503  | No healthy backend endpoints  |

## Golden Rule

Ingress debugging is usually:
Ingress Controller → IngressClass → host/path → Service → endpoints → Pods → logs.

````

---

# 29. TLS Runbook

Create:

```bash id="tot0du"
nano 10.6-ingress-controller-tls-routing/runbooks/ingress-tls-runbook.md
````

Paste:

````markdown id="g75n1u"
# Ingress TLS Runbook

## Goal

Terminate HTTPS at the Ingress Controller.

## Requirements

- TLS certificate
- private key
- Kubernetes TLS Secret
- Ingress tls section
- matching host

## Create TLS Secret

```bash
kubectl create secret tls demo-localdev-tls \
  -n dev \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
````

## Ingress TLS Section

```yaml
spec:
  tls:
    - hosts:
        - demo.localdev.me
      secretName: demo-localdev-tls
```

## Debug

```bash
kubectl get secret demo-localdev-tls -n dev
kubectl describe ingress tls-demo -n dev
curl -k --resolve demo.localdev.me:8443:127.0.0.1 https://demo.localdev.me:8443/
```

## Common Problems

* Secret missing
* Secret in wrong namespace
* host mismatch
* certificate CN/SAN mismatch
* wrong ingressClassName
* HTTPS port not forwarded/exposed

## Golden Rule

Ingress and TLS Secret must be in the same namespace.

````

---

# 30. Production Ingress Checklist

Create:

```bash id="gn8swm"
nano 10.6-ingress-controller-tls-routing/runbooks/production-ingress-checklist.md
````

Paste:

```markdown id="opxe2g"
# Production Ingress Checklist

## Controller

- [ ] Ingress Controller installed.
- [ ] Controller Pods are Ready.
- [ ] Controller Service is exposed correctly.
- [ ] IngressClass exists.
- [ ] Logs are accessible.

## Routing

- [ ] DNS points to load balancer.
- [ ] Ingress host is correct.
- [ ] Ingress path is correct.
- [ ] backend Service name is correct.
- [ ] backend Service port is correct.
- [ ] Service has endpoints.
- [ ] Pods are Ready.

## TLS

- [ ] Certificate is valid.
- [ ] Secret exists in same namespace as Ingress.
- [ ] Ingress tls.hosts matches rule host.
- [ ] HTTP to HTTPS redirect policy is intentional.
- [ ] Certificate renewal is automated.

## Security

- [ ] No unintended wildcard hosts.
- [ ] Only required paths exposed.
- [ ] Admin/debug endpoints are not publicly exposed.
- [ ] Request body/timeouts configured appropriately.
- [ ] WAF/security controls considered where needed.

## Observability

- [ ] Access logs enabled.
- [ ] Error logs monitored.
- [ ] 4xx/5xx metrics collected.
- [ ] Latency metrics collected.
```

---

# 31. Validation Script

Create:

```bash id="ap7zz6"
nano 10.6-ingress-controller-tls-routing/scripts/validate-lesson-10-6.sh
```

Paste:

```bash id="m1sviu"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.6 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null
kubectl get namespace ingress-nginx >/dev/null

kubectl get pods -n ingress-nginx \
  -l app.kubernetes.io/component=controller >/dev/null

kubectl get ingressclass nginx >/dev/null

kubectl get deployment app-a -n dev >/dev/null
kubectl get deployment app-b -n dev >/dev/null
kubectl get service app-a -n dev >/dev/null
kubectl get service app-b -n dev >/dev/null

kubectl get ingress path-routing-demo -n dev >/dev/null
kubectl get ingress host-routing-demo -n dev >/dev/null
kubectl get ingress tls-demo -n dev >/dev/null

kubectl get secret demo-localdev-tls -n dev >/dev/null

APP_A_ENDPOINTS="$(kubectl get endpoints app-a -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"
APP_B_ENDPOINTS="$(kubectl get endpoints app-b -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$APP_A_ENDPOINTS" ]; then
  echo "ERROR: app-a has no endpoints"
  exit 1
fi

if [ -z "$APP_B_ENDPOINTS" ]; then
  echo "ERROR: app-b has no endpoints"
  exit 1
fi

test -f 10.6-ingress-controller-tls-routing/notes/ingress-mental-model.md
test -f 10.6-ingress-controller-tls-routing/runbooks/ingress-debugging-runbook.md
test -f 10.6-ingress-controller-tls-routing/runbooks/ingress-tls-runbook.md
test -f 10.6-ingress-controller-tls-routing/runbooks/production-ingress-checklist.md
test -f apps/demo-node-api/base/ingress.yaml

echo "app-a endpoints: $APP_A_ENDPOINTS"
echo "app-b endpoints: $APP_B_ENDPOINTS"
echo "Lesson 10.6 validation passed."
```

Make executable:

```bash id="qhkqdf"
chmod +x 10.6-ingress-controller-tls-routing/scripts/validate-lesson-10-6.sh
```

Run:

```bash id="mid09r"
./10.6-ingress-controller-tls-routing/scripts/validate-lesson-10-6.sh
```

---

# 32. Cleanup Script

Create:

```bash id="bnlh6w"
nano 10.6-ingress-controller-tls-routing/scripts/cleanup-lesson-10-6.sh
```

Paste:

```bash id="zwx1ef"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.6 ====="

kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-ingress.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/broken-backend-service.yaml --ignore-not-found=true

kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/tls-redirect-ingress.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/tls-ingress.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/host-routing-ingress.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/path-routing-ingress.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/app-a.yaml --ignore-not-found=true
kubectl delete -f 10.6-ingress-controller-tls-routing/manifests/app-b.yaml --ignore-not-found=true

kubectl delete secret demo-localdev-tls -n dev --ignore-not-found=true

echo "Lesson 10.6 app resources cleaned."
echo "Ingress controller kept for future lessons."
```

Make executable:

```bash id="7d5q93"
chmod +x 10.6-ingress-controller-tls-routing/scripts/cleanup-lesson-10-6.sh
```

Run only if you want cleanup:

```bash id="ty8v78"
./10.6-ingress-controller-tls-routing/scripts/cleanup-lesson-10-6.sh
```

To remove the controller too:

```bash id="vl2ctk"
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
```

For upcoming lessons, keep the controller installed.

---

# 33. Practical Lab Summary

Run the full lab:

```bash id="2vkdlg"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/app-a.yaml
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/app-b.yaml
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/path-routing-ingress.yaml
kubectl apply -f 10.6-ingress-controller-tls-routing/manifests/host-routing-ingress.yaml

kubectl port-forward --namespace=ingress-nginx \
  service/ingress-nginx-controller \
  8080:80
```

In another terminal:

```bash id="dvpewl"
curl --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-a

curl --resolve demo.localdev.me:8080:127.0.0.1 \
  http://demo.localdev.me:8080/app-b

curl --resolve a.localdev.me:8080:127.0.0.1 \
  http://a.localdev.me:8080/

curl --resolve b.localdev.me:8080:127.0.0.1 \
  http://b.localdev.me:8080/
```

---

# 34. Common Myths and Misconceptions

## Myth 1: Ingress is a LoadBalancer

Not exactly.

```text id="0g8g4b"
Ingress:
  HTTP routing rule

Ingress Controller:
  proxy/load balancer implementation

Cloud Load Balancer:
  external entry point in many cloud setups
```

## Myth 2: Ingress works without a controller

Wrong.

```text id="gek8av"
Ingress object alone has no effect.
```

## Myth 3: Service is not needed if Ingress exists

Wrong.

```text id="7uzjqq"
Ingress routes to Services.
Services route to Pods.
```

## Myth 4: TLS Secret can be in any namespace

Wrong.

```text id="afk3a6"
Ingress and its referenced TLS Secret must be in the same namespace.
```

## Myth 5: 404 always means app is broken

Wrong.

```text id="kf6bxa"
404 often means Ingress host/path did not match.
```

## Myth 6: 503 always means Ingress Controller is broken

Wrong.

```text id="3bxxbe"
503 often means backend Service has no healthy endpoints.
```

---

# 35. Production Rules

```text id="9a4c9v"
Install and monitor the Ingress Controller.
Always set ingressClassName intentionally.
Use Services as Ingress backends.
Use TLS for public routes.
Automate certificate renewal.
Do not expose debug/admin paths publicly.
Use host-based routing for clean domain separation.
Use path-based routing carefully; apps must support path prefixes.
Check Service endpoints before blaming Ingress.
Check controller logs for routing errors.
Understand 404 vs 502 vs 503.
Ingress is common, but Gateway API is the modern direction.
```

---

# 36. Interview Explanation

Use this:

```text id="b8g9e5"
A Kubernetes Ingress defines HTTP and HTTPS routing rules from outside the cluster to Services inside the cluster. It does not work by itself; an Ingress Controller such as NGINX, Traefik, HAProxy, or a cloud-specific controller must be running to implement those rules.

The request flow is usually DNS to a load balancer, then to the Ingress Controller, then the Ingress rule matches host and path, then traffic goes to a Kubernetes Service, and finally to backend Pods. I debug Ingress issues by checking the Ingress Controller, IngressClass, host/path rules, backend Service, Service endpoints, Pod readiness, and controller logs.
```

Resume version:

```text id="lq0187"
Built Kubernetes Ingress labs with ingress-nginx, host/path routing, TLS Secret termination, local port-forward testing, debugging for 404/502/503 errors, and production ingress runbooks for service exposure.
```

---

# 37. Today’s Core Rules

```text id="krxj7c"
Ingress exposes HTTP/HTTPS routes.
Ingress routes to Services, not directly to Pods.
Ingress requires an Ingress Controller.
ingressClassName chooses the controller.
Host and path must match the request.
TLS is configured with a Secret.
TLS Secret must be in the same namespace as the Ingress.
404 usually means no matching host/path.
502 usually means backend connection problem.
503 usually means no healthy backend endpoints.
Controller logs are critical for debugging.
Production ingress needs DNS, TLS, logs, metrics, and careful exposure control.
```

---

# 38. Commit Lesson 10.6

From repo root:

```bash id="c0du2j"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes Ingress controller TLS and routing lesson"

git push
```

---

# Next Lesson

```text id="erq9lc"
Lesson 10.7 — ConfigMaps, Secrets, Environment Injection, Mounted Config, and Secret Management Patterns
```

We will cover:

```text id="xrxw95"
ConfigMap mental model
Secret mental model
env vars from ConfigMaps
env vars from Secrets
volume-mounted config
file-based secrets
immutable config idea
secret base64 confusion
why Kubernetes Secret is not automatically encrypted enough
config rollout problem
restart on config changes
production config patterns for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/services-networking/ingress/ "Ingress | Kubernetes"
[2]: https://kubernetes.github.io/ingress-nginx/deploy/ "Installation Guide - Ingress-Nginx Controller"
[3]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_tls/?utm_source=chatgpt.com "kubectl create secret tls"
