# Lesson 10.5 — Services, ClusterIP, NodePort, LoadBalancer, DNS, and Service Discovery

In Lesson 10.4, you learned how **Deployments** manage ReplicaSets and Pods.

Now we learn how traffic reaches those Pods.

This lesson is critical because Kubernetes networking confusion usually starts here:

```text id="rwdk5y"
Pod IP changes.
Pods restart.
Pods move across nodes.
Service selectors may be wrong.
targetPort may be wrong.
NodePort may not be exposed.
DNS name may be wrong.
Ingress may point to the wrong Service.
```

A Kubernetes Service exposes a network application running as one or more Pods. The set of Pods targeted by a Service is usually determined by a selector, and Kubernetes tracks the matching backend endpoints for that Service. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="5e4c8w"
10.5.1   Service mental model
10.5.2   Why Pod IP is not enough
10.5.3   ClusterIP
10.5.4   NodePort
10.5.5   LoadBalancer
10.5.6   Headless Service
10.5.7   port vs targetPort vs nodePort
10.5.8   Service selectors
10.5.9   Endpoints and EndpointSlices
10.5.10  Kubernetes DNS
10.5.11  Internal service discovery
10.5.12  kube-proxy basics
10.5.13  kind NodePort testing
10.5.14  Service debugging
10.5.15  Production Service patterns
10.5.16  Validation script
10.5.17  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="9m1p2f"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.5-services-dns-service-discovery/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="khfhjj"
tree -L 2 10.5-services-dns-service-discovery
```

---

# 3. Service Mental Model

Pods are temporary.

A Pod can be:

```text id="tzaw2x"
created
deleted
restarted
rescheduled
replaced during rollout
moved to another node
```

That means Pod IPs are not stable enough for other apps to depend on.

Bad idea:

```text id="0d7hpu"
frontend calls http://10.244.1.23:3002
```

Why?

```text id="5yovtq"
That Pod can disappear.
The replacement Pod may get a different IP.
```

Good idea:

```text id="i05hx0"
frontend calls http://demo-node-api
```

A Service provides a stable network identity in front of changing Pods.

Mental model:

```text id="aj115y"
Service
  stable name
  stable virtual IP
  stable port
    ↓
selects Pods by label
    ↓
routes traffic to matching healthy endpoints
```

---

# 4. Why Pod IP Is Not Enough

Run:

```bash id="mgc5hs"
kubectl get pods -n dev -o wide
```

You will see Pod IPs.

Example:

```text id="uictsc"
NAME                              IP
whoami-rollout-xxxxx-abcde        10.244.1.12
whoami-rollout-xxxxx-fghij        10.244.2.18
```

Now delete a Pod:

```bash id="ngibmr"
kubectl delete pod -n dev -l app=whoami-rollout
```

Check again:

```bash id="7b4c0i"
kubectl get pods -n dev -l app=whoami-rollout -o wide
```

New Pods may get new IPs.

Lesson:

```text id="8ymxpu"
Pod IPs are for Kubernetes internals.
Services are for stable app-to-app communication.
```

---

# 5. Create Notes

```bash id="a82w4m"
nano 10.5-services-dns-service-discovery/notes/service-mental-model.md
```

Paste:

````markdown id="ot2j38"
# Kubernetes Service Mental Model

## Problem

Pods are temporary and Pod IPs can change.

## Solution

A Service gives stable networking in front of Pods.

## Flow

```text
Client
  ↓
Service DNS name / ClusterIP
  ↓
Service selector
  ↓
EndpointSlice / endpoints
  ↓
Pod IPs
````

## Service Types

* ClusterIP
* NodePort
* LoadBalancer
* ExternalName
* Headless Service

## Golden Rule

Do not connect applications directly to Pod IPs.
Use Services and DNS names.

````

---

# 6. Service Types Overview

Common Service types:

```text id="we5dko"
ClusterIP:
  Internal cluster access only.

NodePort:
  Exposes the Service on a static port on each node.

LoadBalancer:
  Requests an external load balancer from the cloud/provider.

ExternalName:
  Maps a Kubernetes Service name to an external DNS name.

Headless Service:
  No virtual ClusterIP; DNS returns backend Pod IPs directly.
````

The Kubernetes Service docs define Service types including `ClusterIP`, `NodePort`, `LoadBalancer`, and `ExternalName`. `ClusterIP` exposes a Service on a cluster-internal IP, `NodePort` exposes the Service on each node’s IP at a static port, and `LoadBalancer` exposes it externally using a load balancer when supported by the platform. ([Kubernetes][1])

---

# 7. ClusterIP

`ClusterIP` is the default Service type.

It is used for internal app-to-app communication inside the cluster.

Example:

```yaml id="my9n0p"
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 3002
```

Meaning:

```text id="e4ss4c"
Inside cluster:
  http://backend

Service receives traffic on:
  port 80

Traffic goes to Pod container port:
  targetPort 3002
```

Use cases:

```text id="ar07ym"
frontend → backend
backend → database proxy
api → internal worker
microservice → microservice
```

Production rule:

```text id="kccz3u"
Use ClusterIP for internal-only services.
Expose externally with Ingress, Gateway API, or LoadBalancer when needed.
```

---

# 8. NodePort

`NodePort` exposes a Service on every node at a static port.

Example:

```yaml id="vl7kqp"
type: NodePort
ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

Flow:

```text id="s1x2i4"
Your machine
  ↓
Node IP:30080
  ↓
NodePort Service
  ↓
Pods
```

Useful for:

```text id="xushvi"
local kind testing
simple demos
bare-metal labs
debugging without Ingress
```

Not usually preferred for production internet traffic.

Production usually uses:

```text id="f23eft"
Ingress Controller
LoadBalancer Service
Gateway API
cloud load balancer
```

---

# 9. LoadBalancer

`LoadBalancer` asks the infrastructure provider to create an external load balancer.

In cloud platforms:

```text id="5y28ri"
AWS:
  creates ELB/NLB depending on controller/provider

GCP:
  creates cloud load balancer

Azure:
  creates Azure load balancer
```

In local kind:

```text id="qzhtfo"
LoadBalancer usually stays Pending unless a load balancer implementation is installed.
```

Example:

```yaml id="g5g2zz"
apiVersion: v1
kind: Service
metadata:
  name: public-api
spec:
  type: LoadBalancer
  selector:
    app: public-api
  ports:
    - port: 80
      targetPort: 3002
```

Check:

```bash id="vtzmia"
kubectl get svc public-api
```

On cloud:

```text id="8u97sf"
EXTERNAL-IP gets assigned.
```

On kind without extra load-balancer support:

```text id="6ygtdk"
EXTERNAL-IP may remain <pending>.
```

---

# 10. Headless Service

A normal Service gets a virtual ClusterIP.

A headless Service does not.

You create one with:

```yaml id="fuw7qx"
clusterIP: None
```

Example:

```yaml id="hp3x57"
apiVersion: v1
kind: Service
metadata:
  name: backend-headless
spec:
  clusterIP: None
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 80
```

Use cases:

```text id="hms2fa"
StatefulSets
databases
direct Pod discovery
peer-to-peer systems
service discovery where client needs individual Pod IPs
```

Normal Service DNS:

```text id="v9sbvy"
backend.dev.svc.cluster.local
  → Service virtual IP
```

Headless Service DNS:

```text id="t3sppl"
backend-headless.dev.svc.cluster.local
  → individual Pod IPs
```

---

# 11. port vs targetPort vs nodePort

This confuses almost everyone at first.

```yaml id="g17gbk"
ports:
  - port: 80
    targetPort: 3002
    nodePort: 30080
```

Meaning:

```text id="o55jly"
port:
  Port exposed by the Service inside the cluster.

targetPort:
  Port on the Pod/container where traffic should go.

nodePort:
  Port exposed on each Kubernetes node.
```

For your Node.js API:

```text id="iv82mj"
App listens inside container:
  3002

Service exposes internally:
  80

NodePort exposes externally on node:
  30080
```

Flow:

```text id="76mu43"
NodeIP:30080
  ↓ nodePort
Service:80
  ↓ port
Pod:3002
  targetPort
```

Golden rule:

```text id="7lny6i"
targetPort must match the container's listening port.
```

---

# 12. Create Demo Deployment

Create:

```bash id="0it6eu"
nano 10.5-services-dns-service-discovery/manifests/whoami-deployment.yaml
```

Paste:

```yaml id="1xzscw"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: svc-demo
  namespace: dev
  labels:
    app: svc-demo
    environment: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: svc-demo
      environment: dev
  template:
    metadata:
      labels:
        app: svc-demo
        environment: dev
        tier: backend
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10
          ports:
            - name: http
              containerPort: 80
```

Apply:

```bash id="b6bwx3"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-deployment.yaml
```

Check:

```bash id="eeqtgv"
kubectl get deployment svc-demo -n dev
kubectl get pods -n dev -l app=svc-demo -o wide
kubectl get pods -n dev -l app=svc-demo --show-labels
```

---

# 13. Create ClusterIP Service

Create:

```bash id="7jl62j"
nano 10.5-services-dns-service-discovery/manifests/whoami-clusterip-service.yaml
```

Paste:

```yaml id="qk5dy6"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo
  namespace: dev
  labels:
    app: svc-demo
spec:
  type: ClusterIP
  selector:
    app: svc-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="1qgvp3"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-clusterip-service.yaml
```

Check:

```bash id="yvhxen"
kubectl get svc svc-demo -n dev
kubectl describe svc svc-demo -n dev
kubectl get endpoints svc-demo -n dev
```

Notice:

```text id="a8ktba"
targetPort: http
```

This points to the named container port:

```yaml id="pw7g4w"
ports:
  - name: http
    containerPort: 80
```

This is good practice because names are easier to maintain than numbers.

---

# 14. EndpointSlices

Older commands show `Endpoints`.

Modern Kubernetes also uses `EndpointSlice`.

EndpointSlices represent subsets of backend network endpoints for a Service. They let Kubernetes scale Service endpoint tracking more efficiently and are normally associated with a Service; backend endpoints usually represent Pods. ([Kubernetes][2])

Check:

```bash id="3zwrx2"
kubectl get endpoints svc-demo -n dev
kubectl get endpointslices -n dev
```

Filter EndpointSlices for this Service:

```bash id="q3a5an"
kubectl get endpointslices -n dev \
  -l kubernetes.io/service-name=svc-demo
```

Detailed:

```bash id="g79z99"
kubectl describe endpointslice -n dev \
  -l kubernetes.io/service-name=svc-demo
```

Mental model:

```text id="f66nvl"
Service selector
  ↓
matching Pods
  ↓
EndpointSlice controller
  ↓
EndpointSlices
  ↓
traffic routing data
```

---

# 15. Test Service from Inside Cluster

Run a temporary curl Pod:

```bash id="zpoz7c"
kubectl run curl-test \
  -n dev \
  --image=curlimages/curl:8.10.1 \
  --rm -it \
  --restart=Never \
  -- sh
```

Inside:

```sh id="3ijh74"
curl http://svc-demo
curl http://svc-demo.dev
curl http://svc-demo.dev.svc
curl http://svc-demo.dev.svc.cluster.local
exit
```

All should work from inside the cluster.

This is Kubernetes DNS/service discovery.

---

# 16. Kubernetes DNS

Kubernetes creates DNS records for Services and Pods. For a normal Service named `svc-demo` in namespace `dev`, workloads in the same namespace can usually reach it by `svc-demo`, and workloads in other namespaces can use a more complete name such as `svc-demo.dev.svc.cluster.local`. ([Kubernetes][3])

Common DNS forms:

```text id="a5p4l0"
Same namespace:
  svc-demo

Different namespace:
  svc-demo.dev

More explicit:
  svc-demo.dev.svc

Fully qualified:
  svc-demo.dev.svc.cluster.local
```

Production example:

```text id="rakzgt"
frontend.production.svc.cluster.local
backend.production.svc.cluster.local
postgres.database.svc.cluster.local
```

Golden rule:

```text id="11eupx"
Use Service DNS names for app-to-app communication.
Do not hardcode Pod IPs.
```

---

# 17. DNS Debug Pod

Create a reusable DNS debug Pod.

```bash id="u9l0jh"
nano 10.5-services-dns-service-discovery/manifests/dns-debug-pod.yaml
```

Paste:

```yaml id="nfx5m3"
apiVersion: v1
kind: Pod
metadata:
  name: dns-debug
  namespace: dev
  labels:
    app: dns-debug
spec:
  containers:
    - name: dnsutils
      image: registry.k8s.io/e2e-test-images/agnhost:2.39
      command: ["sleep", "3600"]
  restartPolicy: Always
```

Apply:

```bash id="yphdgv"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/dns-debug-pod.yaml
```

Check:

```bash id="oi9y8r"
kubectl get pod dns-debug -n dev
```

Exec:

```bash id="8w1glz"
kubectl exec -it dns-debug -n dev -- sh
```

Inside:

```sh id="om3h3l"
nslookup svc-demo
nslookup svc-demo.dev
nslookup svc-demo.dev.svc.cluster.local
wget -qO- http://svc-demo
exit
```

The Kubernetes DNS debugging docs recommend using a simple test Pod and checking DNS Pods such as CoreDNS in `kube-system` when DNS resolution is not working. ([Kubernetes][4])

Check CoreDNS:

```bash id="i7dl33"
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

# 18. Test with Port-Forward

ClusterIP is internal, but you can test it locally using port-forward.

```bash id="2tqr12"
kubectl port-forward -n dev svc/svc-demo 8083:80
```

Another terminal:

```bash id="1zk2iz"
curl http://127.0.0.1:8083
```

Flow:

```text id="yzzo73"
Your machine
  ↓
kubectl port-forward
  ↓
Service/svc-demo
  ↓
Pods
```

Stop:

```text id="hmdr5q"
Ctrl + C
```

---

# 19. Create NodePort Service

Your kind config from Lesson 10.2 mapped host port `30080` to container node port `30080`.

Create:

```bash id="hlh893"
nano 10.5-services-dns-service-discovery/manifests/whoami-nodeport-service.yaml
```

Paste:

```yaml id="ay1zhv"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo-nodeport
  namespace: dev
  labels:
    app: svc-demo
spec:
  type: NodePort
  selector:
    app: svc-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: http
      nodePort: 30080
```

Apply:

```bash id="ehue9s"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-nodeport-service.yaml
```

Check:

```bash id="svepom"
kubectl get svc svc-demo-nodeport -n dev
kubectl describe svc svc-demo-nodeport -n dev
kubectl get endpoints svc-demo-nodeport -n dev
```

Test from local machine:

```bash id="qop7y2"
curl http://127.0.0.1:30080
```

If it works, your flow is:

```text id="eakipn"
localhost:30080
  ↓
kind extraPortMapping
  ↓
kind control-plane node:30080
  ↓
NodePort Service
  ↓
svc-demo Pods
```

kind extra port mappings are a cross-platform way to forward traffic from the host into kind nodes, which is useful for exposing NodePort or ingress-style traffic in local clusters. ([kind.sigs.k8s.io][5])

---

# 20. NodePort Troubleshooting in kind

If this fails:

```bash id="e4wpoz"
curl http://127.0.0.1:30080
```

Check:

```bash id="r6zxhu"
kubectl get svc svc-demo-nodeport -n dev
kubectl get endpoints svc-demo-nodeport -n dev
kubectl get pods -n dev -l app=svc-demo -o wide
```

Check kind cluster config exists:

```bash id="n8p0bh"
cat 10.2-local-kubernetes-lab-setup/kind/devops-k8s-multinode.yaml
```

You need this mapping:

```yaml id="jltzje"
extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
```

If the cluster was created without that mapping, recreate it:

```bash id="fy1bif"
kind delete cluster --name devops-k8s

kind create cluster \
  --config 10.2-local-kubernetes-lab-setup/kind/devops-k8s-multinode.yaml
```

Then recreate namespaces and manifests.

---

# 21. Create LoadBalancer Service

Create:

```bash id="x7fs6s"
nano 10.5-services-dns-service-discovery/manifests/whoami-loadbalancer-service.yaml
```

Paste:

```yaml id="gi627l"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo-loadbalancer
  namespace: dev
  labels:
    app: svc-demo
spec:
  type: LoadBalancer
  selector:
    app: svc-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="f5ks92"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-loadbalancer-service.yaml
```

Check:

```bash id="f2pw9m"
kubectl get svc svc-demo-loadbalancer -n dev
```

In kind, you may see:

```text id="501jms"
EXTERNAL-IP   <pending>
```

That is normal without a local load balancer implementation.

Delete it after observing:

```bash id="5mafdw"
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-loadbalancer-service.yaml
```

Production note:

```text id="7jra7t"
In AWS/EKS, LoadBalancer Services depend on cloud provider integration or controllers.
In local kind, use NodePort, port-forward, ingress setup, or cloud-provider-kind.
```

---

# 22. Create Headless Service

Create:

```bash id="o2i6fw"
nano 10.5-services-dns-service-discovery/manifests/whoami-headless-service.yaml
```

Paste:

```yaml id="jcwyhb"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo-headless
  namespace: dev
  labels:
    app: svc-demo
spec:
  clusterIP: None
  selector:
    app: svc-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="pf3n85"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-headless-service.yaml
```

Check:

```bash id="0vmfcg"
kubectl get svc svc-demo-headless -n dev
kubectl get endpoints svc-demo-headless -n dev
```

Exec into DNS debug Pod:

```bash id="fztlrp"
kubectl exec -it dns-debug -n dev -- sh
```

Inside:

```sh id="a82ck4"
nslookup svc-demo-headless
exit
```

You should see backend Pod IPs instead of a single virtual ClusterIP.

---

# 23. Service Without Selector

Most Services use selectors.

But Services can also exist without selectors.

Use case:

```text id="1ssixn"
Expose external database through Kubernetes Service name.
Manually manage Endpoints or EndpointSlices.
Migrate external service behind internal DNS.
```

For now, remember:

```text id="pbn8sz"
Normal Service:
  selector finds Pods automatically.

Service without selector:
  you must provide backend endpoints separately.
```

We will revisit this later when discussing external services, databases, and migrations.

---

# 24. kube-proxy Basics

`kube-proxy` is a node-level networking component that helps implement Service networking.

Simple mental model:

```text id="5j4d9f"
Service virtual IP / NodePort
  ↓
node networking rules
  ↓
Pod endpoints
```

In many clusters, kube-proxy programs iptables or IPVS rules so traffic to a Service can reach one of the backend endpoints.

Check kube-proxy:

```bash id="k9ci05"
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

In kind, you may see kube-proxy running as a DaemonSet.

```bash id="7a42k2"
kubectl get daemonset -n kube-system
```

Important:

```text id="l42evj"
Service is an API object.
kube-proxy helps implement traffic routing for Services on nodes.
EndpointSlices tell which backend IPs are available.
```

---

# 25. Intentional Selector Bug

Create broken Service:

```bash id="r8d3hv"
nano 10.5-services-dns-service-discovery/manifests/whoami-broken-service.yaml
```

Paste:

```yaml id="xa0q6x"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo-broken
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: wrong-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="89navn"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-broken-service.yaml
```

Check:

```bash id="qfwdox"
kubectl get svc svc-demo-broken -n dev
kubectl get endpoints svc-demo-broken -n dev
kubectl get endpointslices -n dev -l kubernetes.io/service-name=svc-demo-broken
kubectl describe svc svc-demo-broken -n dev
```

Expected:

```text id="akst29"
No endpoints.
```

Why?

```text id="q1p36x"
selector app=wrong-app matches zero Pods.
```

Fix:

```bash id="vyju7l"
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-broken-service.yaml
```

---

# 26. Intentional targetPort Bug

Create:

```bash id="cn0yq8"
nano 10.5-services-dns-service-discovery/manifests/whoami-wrong-targetport-service.yaml
```

Paste:

```yaml id="c1gamd"
apiVersion: v1
kind: Service
metadata:
  name: svc-demo-wrong-port
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: svc-demo
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 9999
```

Apply:

```bash id="4awf1n"
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-wrong-targetport-service.yaml
```

Check endpoints:

```bash id="3svu7c"
kubectl get endpoints svc-demo-wrong-port -n dev
```

You may see endpoints, because the selector matches Pods.

But traffic fails because the Pods are not listening on port `9999`.

Test:

```bash id="x0dfz2"
kubectl port-forward -n dev svc/svc-demo-wrong-port 8084:80
```

Another terminal:

```bash id="tnyc5y"
curl --max-time 5 http://127.0.0.1:8084 || true
```

Stop port-forward.

Delete:

```bash id="n1yrg5"
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-wrong-targetport-service.yaml
```

Lesson:

```text id="8bazx1"
Endpoints existing does not always mean traffic works.
targetPort must match the container listening port.
```

---

# 27. Service Debugging Runbook

Create:

```bash id="n22fnc"
nano 10.5-services-dns-service-discovery/runbooks/service-debugging-runbook.md
```

Paste:

````markdown id="vhgn3h"
# Kubernetes Service Debugging Runbook

## Step 1 — Check Service

```bash
kubectl get svc SERVICE_NAME -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE
````

Check:

* type
* ClusterIP
* ports
* targetPort
* selector

## Step 2 — Check Pods and Labels

```bash
kubectl get pods -n NAMESPACE --show-labels
kubectl get pods -n NAMESPACE -l app=VALUE
```

## Step 3 — Check Endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get endpointslices -n NAMESPACE -l kubernetes.io/service-name=SERVICE_NAME
```

## Step 4 — Test from Inside Cluster

```bash
kubectl run curl-test \
  -n NAMESPACE \
  --image=curlimages/curl:8.10.1 \
  --rm -it \
  --restart=Never \
  -- sh
```

Inside:

```sh
curl http://SERVICE_NAME
```

## Step 5 — Test DNS

```bash
kubectl exec -it dns-debug -n NAMESPACE -- sh
```

Inside:

```sh
nslookup SERVICE_NAME
nslookup SERVICE_NAME.NAMESPACE.svc.cluster.local
```

## Step 6 — Port-Forward

```bash
kubectl port-forward -n NAMESPACE svc/SERVICE_NAME 8080:80
curl http://127.0.0.1:8080
```

## Common Problems

| Symptom                        | Likely Cause                          |
| ------------------------------ | ------------------------------------- |
| No endpoints                   | selector mismatch or Pods not ready   |
| Endpoints exist but curl fails | wrong targetPort or app not listening |
| DNS fails                      | CoreDNS issue or wrong namespace/name |
| NodePort not reachable         | kind port mapping missing or firewall |
| LoadBalancer pending           | no cloud/load-balancer implementation |

## Golden Rule

Service debugging starts with selector, endpoints, targetPort, DNS, and namespace.

````

---

# 28. DNS Debugging Runbook

Create:

```bash id="f6e332"
nano 10.5-services-dns-service-discovery/runbooks/dns-debugging-runbook.md
````

Paste:

````markdown id="frgrzp"
# Kubernetes DNS Debugging Runbook

## Step 1 — Check Service Exists

```bash
kubectl get svc -n NAMESPACE
````

## Step 2 — Check DNS from a Pod

```bash
kubectl exec -it dns-debug -n NAMESPACE -- sh
```

Inside:

```sh
nslookup SERVICE_NAME
nslookup SERVICE_NAME.NAMESPACE
nslookup SERVICE_NAME.NAMESPACE.svc.cluster.local
```

## Step 3 — Check CoreDNS

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Step 4 — Check Namespace

Service short name works from same namespace.

From another namespace, use:

```text
SERVICE_NAME.NAMESPACE
```

or:

```text
SERVICE_NAME.NAMESPACE.svc.cluster.local
```

## Step 5 — Check Endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
```

DNS can resolve even if there are no healthy endpoints, but traffic will fail.

## Golden Rule

DNS tells you the name exists.
Endpoints tell you whether traffic has backends.

````

---

# 29. NodePort Runbook

Create:

```bash id="u7nn8b"
nano 10.5-services-dns-service-discovery/runbooks/nodeport-kind-runbook.md
````

Paste:

````markdown id="lz1vb6"
# NodePort Testing with kind

## Goal

Expose a Service from a kind cluster to your local machine.

## Requirements

kind cluster config must include extraPortMappings:

```yaml
extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
````

## Service

```yaml
type: NodePort
ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

## Test

```bash
curl http://127.0.0.1:30080
```

## Debug

```bash
kubectl get svc -n dev
kubectl describe svc svc-demo-nodeport -n dev
kubectl get endpoints svc-demo-nodeport -n dev
kubectl get pods -n dev --show-labels
```

## Common Problems

* kind cluster created without extraPortMappings
* nodePort does not match mapped containerPort
* Service selector does not match Pods
* targetPort is wrong
* Pod is not ready or not listening

````

---

# 30. Production Service Patterns

For your `demo-node-api`, production usually looks like:

```text id="65dyqq"
Deployment:
  demo-node-api Pods listen on 3002

Service:
  ClusterIP
  port 80
  targetPort 3002

Ingress:
  api.yourdatascientist.tech
  routes to Service port 80
````

Service manifest:

```yaml id="3deuzj"
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api
  namespace: production
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
  ports:
    - name: http
      port: 80
      targetPort: 3002
```

Why ClusterIP?

```text id="msk769"
The app should be internal to the cluster.
Ingress or Gateway handles external traffic.
```

Why not NodePort directly?

```text id="4x5iaw"
Harder to manage TLS.
Harder to manage host/path routing.
Less flexible than Ingress/Gateway.
Not ideal as the primary production HTTP exposure model.
```

---

# 31. Update `demo-node-api` Service Base

Open your existing Service from Lesson 10.4:

```bash id="nalp33"
nano apps/demo-node-api/base/service.yaml
```

Ensure it looks like this:

```yaml id="8cgbg2"
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 3002
```

Create NodePort dev-only Service example:

```bash id="kap5xh"
nano apps/demo-node-api/base/service-nodeport-dev.yaml
```

Paste:

```yaml id="c3pmt8"
apiVersion: v1
kind: Service
metadata:
  name: demo-node-api-nodeport
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    environment: dev
  ports:
    - name: http
      port: 80
      targetPort: 3002
      nodePort: 30082
```

Note:

```text id="t3ed9u"
This NodePort requires kind extraPortMappings for 30082 if you want to access it from localhost.
We will mainly use port-forward and Ingress in upcoming lessons.
```

---

# 32. Service Myths and Misconceptions

## Myth 1: Service creates Pods

Wrong.

```text id="bh7s9m"
Deployment creates Pods.
Service selects Pods.
```

## Myth 2: Service selector changes Pod labels

Wrong.

```text id="15kx02"
Service selector only finds matching Pods.
It does not modify Pods.
```

## Myth 3: Endpoints always mean app works

Not always.

```text id="nzkxqn"
Endpoints mean Pods match selector.
Traffic can still fail if targetPort is wrong or app is not listening.
```

## Myth 4: ClusterIP is external

Wrong.

```text id="8c1cf1"
ClusterIP is internal to the cluster.
```

## Myth 5: LoadBalancer always works

Wrong.

```text id="d3reyn"
LoadBalancer depends on the infrastructure provider or local load balancer implementation.
In kind, it may stay pending.
```

## Myth 6: Short DNS names work everywhere

Wrong.

```text id="f46k7x"
Short names work best inside the same namespace.
From another namespace, use service.namespace or full DNS.
```

---

# 33. Service Debugging Command Set

Keep this in memory:

```bash id="baz5az"
kubectl get svc -n dev
kubectl describe svc svc-demo -n dev
kubectl get endpoints svc-demo -n dev
kubectl get endpointslices -n dev -l kubernetes.io/service-name=svc-demo
kubectl get pods -n dev --show-labels
kubectl get pods -n dev -l app=svc-demo
kubectl exec -it dns-debug -n dev -- nslookup svc-demo
kubectl port-forward -n dev svc/svc-demo 8083:80
```

---

# 34. Validation Script

Create:

```bash id="z3cqfw"
nano 10.5-services-dns-service-discovery/scripts/validate-lesson-10-5.sh
```

Paste:

```bash id="v2finl"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.5 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get deployment svc-demo -n dev >/dev/null
kubectl get service svc-demo -n dev >/dev/null
kubectl get service svc-demo-nodeport -n dev >/dev/null
kubectl get service svc-demo-headless -n dev >/dev/null
kubectl get pod dns-debug -n dev >/dev/null

ENDPOINTS="$(kubectl get endpoints svc-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: svc-demo has no endpoints"
  exit 1
fi

NODEPORT_ENDPOINTS="$(kubectl get endpoints svc-demo-nodeport -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$NODEPORT_ENDPOINTS" ]; then
  echo "ERROR: svc-demo-nodeport has no endpoints"
  exit 1
fi

HEADLESS_ENDPOINTS="$(kubectl get endpoints svc-demo-headless -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$HEADLESS_ENDPOINTS" ]; then
  echo "ERROR: svc-demo-headless has no endpoints"
  exit 1
fi

ENDPOINTSLICE_COUNT="$(kubectl get endpointslices -n dev -l kubernetes.io/service-name=svc-demo --no-headers 2>/dev/null | wc -l)"

if [ "$ENDPOINTSLICE_COUNT" -lt 1 ]; then
  echo "ERROR: expected at least one EndpointSlice for svc-demo"
  exit 1
fi

DNS_OUTPUT="$(kubectl exec dns-debug -n dev -- nslookup svc-demo 2>/dev/null || true)"

if ! echo "$DNS_OUTPUT" | grep -q "Name:"; then
  echo "ERROR: DNS lookup for svc-demo failed"
  echo "$DNS_OUTPUT"
  exit 1
fi

test -f 10.5-services-dns-service-discovery/notes/service-mental-model.md
test -f 10.5-services-dns-service-discovery/runbooks/service-debugging-runbook.md
test -f 10.5-services-dns-service-discovery/runbooks/dns-debugging-runbook.md
test -f 10.5-services-dns-service-discovery/runbooks/nodeport-kind-runbook.md
test -f apps/demo-node-api/base/service.yaml
test -f apps/demo-node-api/base/service-nodeport-dev.yaml

echo "svc-demo endpoints: $ENDPOINTS"
echo "EndpointSlice count: $ENDPOINTSLICE_COUNT"
echo "Lesson 10.5 validation passed."
```

Make executable:

```bash id="rod09b"
chmod +x 10.5-services-dns-service-discovery/scripts/validate-lesson-10-5.sh
```

Run:

```bash id="5vxqgo"
./10.5-services-dns-service-discovery/scripts/validate-lesson-10-5.sh
```

---

# 35. Cleanup Script

Create:

```bash id="e4rkcq"
nano 10.5-services-dns-service-discovery/scripts/cleanup-lesson-10-5.sh
```

Paste:

```bash id="osgkb1"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.5 ====="

kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-broken-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-wrong-targetport-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-loadbalancer-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-headless-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-nodeport-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-clusterip-service.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/whoami-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.5-services-dns-service-discovery/manifests/dns-debug-pod.yaml --ignore-not-found=true

echo "Lesson 10.5 resources cleaned."
echo "Namespace dev and cluster kept for next lessons."
```

Make executable:

```bash id="l9ou3u"
chmod +x 10.5-services-dns-service-discovery/scripts/cleanup-lesson-10-5.sh
```

Run only if you want cleanup:

```bash id="ru1cgp"
./10.5-services-dns-service-discovery/scripts/cleanup-lesson-10-5.sh
```

---

# 36. Practical Lab Summary

Run full lab:

```bash id="cegg2u"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-deployment.yaml
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-clusterip-service.yaml
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-nodeport-service.yaml
kubectl apply -f 10.5-services-dns-service-discovery/manifests/whoami-headless-service.yaml
kubectl apply -f 10.5-services-dns-service-discovery/manifests/dns-debug-pod.yaml

kubectl get svc -n dev
kubectl get endpoints -n dev
kubectl get endpointslices -n dev

kubectl exec -it dns-debug -n dev -- nslookup svc-demo
kubectl exec -it dns-debug -n dev -- wget -qO- http://svc-demo

curl http://127.0.0.1:30080

./10.5-services-dns-service-discovery/scripts/validate-lesson-10-5.sh
```

---

# 37. Production Rules

```text id="6gzsdr"
Use ClusterIP for internal service-to-service traffic.
Use Ingress/Gateway/LoadBalancer for external HTTP traffic.
Avoid direct Pod IP dependencies.
Use meaningful named ports like http.
targetPort must match the container listening port.
Service selectors must match Pod labels.
Check endpoints and EndpointSlices when traffic fails.
Use full DNS names across namespaces.
Use port-forward for local debugging.
NodePort is useful for labs but not usually the main production exposure method.
LoadBalancer depends on cloud or local provider support.
Headless Services are useful for StatefulSets and direct Pod discovery.
```

---

# 38. Interview Explanation

Use this:

```text id="27xf49"
A Kubernetes Service provides stable networking for a dynamic set of Pods. Since Pods are temporary and their IPs can change, clients should use a Service name or ClusterIP instead of connecting directly to Pod IPs.

A Service usually selects Pods through labels. Kubernetes then tracks the matching backend Pods using Endpoints and EndpointSlices. ClusterIP is used for internal cluster communication, NodePort exposes a static port on each node, LoadBalancer requests an external load balancer from the infrastructure provider, and headless Services skip the virtual ClusterIP and return backend Pod IPs directly through DNS.

When debugging Services, I check the Service selector, Pod labels, endpoints, EndpointSlices, targetPort, DNS resolution, and namespace.
```

Resume version:

```text id="mvkg0s"
Built Kubernetes Service and service discovery labs covering ClusterIP, NodePort, LoadBalancer behavior, headless Services, EndpointSlices, DNS, port/targetPort/nodePort mapping, kind NodePort testing, and Service debugging runbooks.
```

---

# 39. Today’s Core Rules

```text id="wmc8np"
Pods are temporary; Services are stable.
Service selects Pods using labels.
ClusterIP is internal.
NodePort exposes a node-level port.
LoadBalancer needs infrastructure support.
Headless Service has clusterIP: None.
port is the Service port.
targetPort is the Pod/container port.
nodePort is the node-exposed port.
EndpointSlices track backend endpoints for Services.
DNS gives stable Service names.
Short DNS names work best in the same namespace.
No endpoints usually means selector mismatch or Pods not ready.
Endpoints exist but traffic fails usually means targetPort or app listener issue.
```

---

# 40. Commit Lesson 10.5

From repo root:

```bash id="6m01wr"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes Services DNS and service discovery lesson"

git push
```

---

# Next Lesson

```text id="9l0d6v"
Lesson 10.6 — Ingress, Ingress Controller, TLS, Host/Path Routing, and Production Traffic Flow
```

We will cover:

```text id="r4ud0o"
Ingress mental model
Ingress vs Service
Ingress Controller requirement
kind ingress setup
NGINX Ingress Controller
host-based routing
path-based routing
TLS secret basics
HTTP to HTTPS concept
Ingress annotations
debugging 404/502/503
production traffic flow for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/services-networking/service/?utm_source=chatgpt.com "Service"
[2]: https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/?utm_source=chatgpt.com "EndpointSlices"
[3]: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/?utm_source=chatgpt.com "DNS for Services and Pods"
[4]: https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/?utm_source=chatgpt.com "Debugging DNS Resolution"
[5]: https://kind.sigs.k8s.io/docs/user/configuration/?utm_source=chatgpt.com "kind – Configuration - Kubernetes"
