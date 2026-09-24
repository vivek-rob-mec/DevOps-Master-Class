# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.5 — Ingress and TLS Troubleshooting

In Lesson 11.4, you learned **Service and DNS troubleshooting**:

```text id="m2mn4p"
Service selector mismatch
empty endpoints
wrong targetPort
wrong named port
Pod Running but not Ready
CoreDNS debugging
NetworkPolicy blocking DNS
EndpointSlice inspection
production traffic-path debugging
```

Now we move one layer above Service: **Ingress and TLS**.

Ingress problems are very common because Ingress combines many moving parts:

```text id="ssgwhu"
Ingress Controller
IngressClass
Ingress object
host rules
path rules
backend Service
Service endpoints
TLS Secret
certificate hostname
DNS / Host header
controller logs
```

Kubernetes Ingress can provide externally reachable URLs, name-based virtual hosting, load balancing, and SSL/TLS termination, but it only works when an **Ingress controller** is installed and actively reconciling Ingress objects. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="exm1pn"
11.5.1   Ingress traffic mental model
11.5.2   Ingress Controller vs Ingress resource
11.5.3   IngressClass debugging
11.5.4   Host mismatch
11.5.5   Path mismatch
11.5.6   Backend Service missing
11.5.7   Backend Service has no endpoints
11.5.8   Ingress 404 vs 503
11.5.9   Ingress controller logs
11.5.10  TLS Secret missing
11.5.11  TLS certificate hostname mismatch
11.5.12  Self-signed TLS local lab
11.5.13  curl with Host header
11.5.14  curl --resolve
11.5.15  Production HTTPS debugging flow
11.5.16  Scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="xmtim3"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/{manifests,scripts,notes,runbooks,reports,certs}
```

Check:

```bash id="rigrhq"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting
```

---

# 3. Ingress Traffic Mental Model

Ingress traffic path:

```text id="khb9si"
User / curl / browser
  ↓
DNS or Host header
  ↓
LoadBalancer / NodePort / port-forward to Ingress Controller
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
EndpointSlice / Endpoints
  ↓
Pod IP
  ↓
containerPort
```

Ingress debugging means checking each hop:

```text id="vj8x4v"
Is the Ingress Controller running?
Is the IngressClass correct?
Does host match?
Does path match?
Does backend Service exist?
Does backend Service have endpoints?
Does Service targetPort work?
Does TLS Secret exist?
Does certificate match the hostname?
What do controller logs say?
```

Important:

```text id="x5rbw8"
Ingress is only routing configuration.
Ingress Controller is the actual running component that receives traffic and applies that configuration.
```

The ingress-nginx project supports installing the controller through Helm or YAML manifests; without a controller, Kubernetes can store the Ingress object, but no data-plane component will route external HTTP/S traffic for it. ([GitHub][2])

---

# 4. Create Notes

```bash id="rziesj"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/notes/ingress-tls-mental-model.md
```

Paste:

```markdown id="hn4aw4"
# Ingress and TLS Mental Model

## Traffic Path

User -> DNS/Host header -> Ingress Controller -> Ingress -> Service -> EndpointSlice -> Pod -> Container

## Key Difference

Ingress:
  Kubernetes routing rule.

Ingress Controller:
  Actual software that receives traffic and implements the rule.

## Debug Order

1. Ingress Controller running
2. IngressClass exists and matches
3. Ingress object exists
4. host rule matches request Host header
5. path rule matches request path
6. backend Service exists
7. backend Service port is correct
8. Service has endpoints
9. Pod is Ready
10. TLS Secret exists if HTTPS is used
11. certificate hostname matches Ingress host
12. controller logs confirm routing decision

## Golden Rule

If Service has no endpoints, fix Service/Pod readiness before blaming Ingress.
```

---

# 5. First Ingress Debug Commands

```bash id="izbt3p"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/notes/ingress-debug-commands.md
```

Paste:

````markdown id="ypi5rq"
# Ingress Debug Commands

## Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
````

## IngressClass

```bash id="nvd3vi"
kubectl get ingressclass
kubectl describe ingressclass nginx
```

## Ingress

```bash id="l48l10"
kubectl get ingress -n NAMESPACE
kubectl describe ingress INGRESS_NAME -n NAMESPACE
kubectl get ingress INGRESS_NAME -n NAMESPACE -o yaml
```

## Backend Service

```bash id="ym8z37"
kubectl get svc SERVICE_NAME -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE
kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE_NAME
```

## Backend Pods

```bash id="ijk1f3"
kubectl get pods -n NAMESPACE --show-labels -o wide
kubectl describe pod POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --tail=100
```

## Test with Host header

```bash id="tdurnr"
curl -H "Host: app.localdev.me" http://127.0.0.1:8080/
```

## Test TLS with --resolve

```bash id="840wvg"
curl -vk --resolve app.localdev.me:8443:127.0.0.1 https://app.localdev.me:8443/
```

```id="n0xryq"

For TLS, ingress-nginx documents creating a `kubernetes.io/tls` Secret and ensuring that the Ingress rule hostname matches the certificate hostname. :contentReference[oaicite:2]{index=2}
```

---

# 6. Ensure Ingress Controller Exists

Check:

```bash id="pj0h0k"
kubectl get namespace ingress-nginx
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

If ingress-nginx is not installed, install it:

```bash id="qhmo3d"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
```

Wait:

```bash id="gcjri2"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

Check:

```bash id="kddo3s"
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl get ingressclass
```

For local kind clusters, you can port-forward the controller Service:

```bash id="lx37fv"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

For HTTPS later:

```bash id="b2rutq"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443
```

Keep one of these running in a separate terminal when testing.

---

# 7. Create Healthy Ingress App

Create a healthy backend app and Service.

```bash id="p2zui2"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/00-healthy-ingress-app.yaml
```

Paste:

```yaml id="t5ckw2"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ingress-demo
  template:
    metadata:
      labels:
        app: ingress-demo
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=ingress-demo-ok"
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
  name: ingress-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  type: ClusterIP
  selector:
    app: ingress-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="x5q27u"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/00-healthy-ingress-app.yaml

kubectl rollout status deployment/ingress-demo -n dev --timeout=120s
```

Check Service:

```bash id="b641ih"
kubectl get svc,endpoints -n dev ingress-demo
```

Test Service directly:

```bash id="ujye77"
kubectl port-forward -n dev svc/ingress-demo 18082:80
```

Another terminal:

```bash id="tfdud4"
curl http://127.0.0.1:18082/
```

Expected:

```text id="brpk1o"
ingress-demo-ok
```

Stop port-forward:

```text id="pn325v"
Ctrl + C
```

---

# 8. Create Healthy Ingress

```bash id="j1lnso"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/01-healthy-ingress.yaml
```

Paste:

```yaml id="wib1zk"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-demo
  namespace: dev
  labels:
    app: ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: ingress-demo.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ingress-demo
                port:
                  number: 80
```

Apply:

```bash id="d8ga5e"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/01-healthy-ingress.yaml
```

Check:

```bash id="o1zv9j"
kubectl get ingress ingress-demo -n dev
kubectl describe ingress ingress-demo -n dev
```

Start controller port-forward in another terminal:

```bash id="ke56ef"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

Test:

```bash id="zw1fxh"
curl -H "Host: ingress-demo.localdev.me" http://127.0.0.1:8080/
```

Expected:

```text id="tv3661"
ingress-demo-ok
```

---

# 9. Incident 1 — Wrong `ingressClassName`

If the IngressClass is wrong, the controller may ignore the Ingress.

Create:

```bash id="ajgi8s"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/02-wrong-ingressclass.yaml
```

Paste:

```yaml id="u2jz35"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wrong-ingressclass-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: does-not-exist
  rules:
    - host: wrong-class.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ingress-demo
                port:
                  number: 80
```

Apply:

```bash id="z1d7cf"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/02-wrong-ingressclass.yaml
```

Debug:

```bash id="zp4s72"
kubectl get ingressclass
kubectl describe ingress wrong-ingressclass-demo -n dev

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Test:

```bash id="d36jkf"
curl -H "Host: wrong-class.localdev.me" http://127.0.0.1:8080/ || true
```

Expected:

```text id="vpc3cf"
Request may return default backend 404 or not route as expected because ingressClassName does not match the controller.
```

Fix:

```bash id="o6sn2s"
kubectl patch ingress wrong-ingressclass-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/ingressClassName",
      "value": "nginx"
    }
  ]'
```

Validate:

```bash id="fxgj5d"
curl -H "Host: wrong-class.localdev.me" http://127.0.0.1:8080/
```

Clean:

```bash id="g62rnx"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/02-wrong-ingressclass.yaml --ignore-not-found=true
```

---

# 10. Incident 2 — Host Mismatch

Ingress host rules require the request Host header to match.

Test healthy Ingress with wrong host:

```bash id="bqg058"
curl -H "Host: wrong-host.localdev.me" http://127.0.0.1:8080/ || true
```

Expected:

```text id="wmhn7j"
404 from ingress controller default backend or unmatched host.
```

Now test correct host:

```bash id="hsuz7r"
curl -H "Host: ingress-demo.localdev.me" http://127.0.0.1:8080/
```

Expected:

```text id="u7liiu"
ingress-demo-ok
```

Debug commands:

```bash id="dxtzfb"
kubectl describe ingress ingress-demo -n dev

kubectl get ingress ingress-demo -n dev -o jsonpath='{.spec.rules[*].host}'
echo
```

Production rule:

```text id="v7ckl3"
For host-based Ingress, the DNS name, Host header, Ingress rule host, and TLS certificate hostname must align.
```

---

# 11. Incident 3 — Path Mismatch

Create an Ingress that only routes `/api`.

```bash id="nr1bdb"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/03-path-mismatch.yaml
```

Paste:

```yaml id="jw6v2n"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-mismatch-demo
  namespace: dev
  labels:
    app: ingress-demo
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: path-demo.localdev.me
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: ingress-demo
                port:
                  number: 80
```

Apply:

```bash id="bes6jh"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/03-path-mismatch.yaml
```

Test wrong path:

```bash id="l0kgqn"
curl -H "Host: path-demo.localdev.me" http://127.0.0.1:8080/ || true
```

Test correct path:

```bash id="cdyid1"
curl -H "Host: path-demo.localdev.me" http://127.0.0.1:8080/api
```

Expected:

```text id="h6tykk"
Root path may return 404.
The /api path should route.
```

Important rewrite note:

```text id="o611pn"
If your backend only understands / but Ingress exposes /api, you may need path rewriting.
```

ingress-nginx supports rewrite annotations for cases where the externally exposed path differs from the backend’s expected path; without a rewrite, path-based routing can produce backend 404s. ([GitHub][3])

Clean:

```bash id="nrbty5"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/03-path-mismatch.yaml --ignore-not-found=true
```

---

# 12. Incident 4 — Backend Service Missing

Create Ingress pointing to a Service that does not exist.

```bash id="otb0a8"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/04-backend-service-missing.yaml
```

Paste:

```yaml id="s6hohr"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: missing-service-demo
  namespace: dev
  labels:
    app: missing-service-demo
spec:
  ingressClassName: nginx
  rules:
    - host: missing-service.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-does-not-exist
                port:
                  number: 80
```

Apply:

```bash id="fg5m16"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/04-backend-service-missing.yaml
```

Debug:

```bash id="ql9jox"
kubectl describe ingress missing-service-demo -n dev

kubectl get svc service-does-not-exist -n dev || true

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Test:

```bash id="fy43ux"
curl -H "Host: missing-service.localdev.me" http://127.0.0.1:8080/ || true
```

Expected:

```text id="f9epcf"
Ingress should not route successfully because backend Service is missing.
You may see 503 or controller log warnings depending on controller behavior.
```

Fix by pointing to existing Service:

```bash id="fw1soq"
kubectl patch ingress missing-service-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/rules/0/http/paths/0/backend/service/name",
      "value": "ingress-demo"
    }
  ]'
```

Validate:

```bash id="y39e9f"
curl -H "Host: missing-service.localdev.me" http://127.0.0.1:8080/
```

Clean:

```bash id="p7i41r"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/04-backend-service-missing.yaml --ignore-not-found=true
```

---

# 13. Incident 5 — Backend Service Has No Endpoints

Create a Service selector mismatch and Ingress pointing to it.

```bash id="z1k1dv"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/05-backend-no-endpoints.yaml
```

Paste:

```yaml id="whd3is"
apiVersion: v1
kind: Service
metadata:
  name: no-endpoints-backend
  namespace: dev
  labels:
    app: no-endpoints-backend
spec:
  selector:
    app: no-pod-has-this-label
  ports:
    - name: http
      port: 80
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: no-endpoints-ingress
  namespace: dev
  labels:
    app: no-endpoints-backend
spec:
  ingressClassName: nginx
  rules:
    - host: no-endpoints.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: no-endpoints-backend
                port:
                  number: 80
```

Apply:

```bash id="vnh8ix"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/05-backend-no-endpoints.yaml
```

Debug:

```bash id="efmbiw"
kubectl get svc no-endpoints-backend -n dev
kubectl get endpoints no-endpoints-backend -n dev
kubectl get endpointslice -n dev -l kubernetes.io/service-name=no-endpoints-backend

kubectl describe ingress no-endpoints-ingress -n dev

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Test:

```bash id="b5km71"
curl -H "Host: no-endpoints.localdev.me" http://127.0.0.1:8080/ || true
```

Expected:

```text id="phzg5d"
Service exists.
Ingress exists.
Endpoints are empty.
Ingress commonly returns 503 because there is no healthy backend.
```

Fix selector:

```bash id="lqawlv"
kubectl patch service no-endpoints-backend -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/selector/app",
      "value": "ingress-demo"
    }
  ]'
```

Validate:

```bash id="uvrk0f"
kubectl get endpoints no-endpoints-backend -n dev

curl -H "Host: no-endpoints.localdev.me" http://127.0.0.1:8080/
```

Clean:

```bash id="d6hx46"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/05-backend-no-endpoints.yaml --ignore-not-found=true
```

---

# 14. Ingress 404 vs 503

Very useful production distinction:

```text id="n52uo7"
404 usually means:
  no Ingress rule matched host/path
  or backend app returned 404

503 usually means:
  Ingress matched route, but backend Service/endpoints/upstream unavailable
```

Debug 404:

```bash id="k4d9e1"
kubectl get ingress -n dev
kubectl describe ingress INGRESS_NAME -n dev
curl -H "Host: EXPECTED_HOST" http://127.0.0.1:8080/EXPECTED_PATH
```

Debug 503:

```bash id="mmcyku"
kubectl get svc BACKEND_SERVICE -n dev
kubectl get endpoints BACKEND_SERVICE -n dev
kubectl get pods -n dev --show-labels
kubectl describe pod POD_NAME -n dev
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Production rule:

```text id="q7r5us"
For 404, inspect host/path matching.
For 503, inspect backend Service, endpoints, readiness, and app health.
```

---

# 15. TLS Secret Missing

Ingress TLS needs a Secret containing certificate and private key.

Kubernetes TLS Secrets are commonly used for encryption in transit for Ingress, and `kubectl create secret tls` creates a TLS Secret from a PEM-encoded certificate and matching private key. ([Kubernetes][4])

Create Ingress referencing a missing TLS Secret:

```bash id="t0ahp0"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/06-missing-tls-secret.yaml
```

Paste:

```yaml id="nsqvlf"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: missing-tls-secret-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - missing-tls.localdev.me
      secretName: missing-tls-secret
  rules:
    - host: missing-tls.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ingress-demo
                port:
                  number: 80
```

Apply:

```bash id="y7wc63"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/06-missing-tls-secret.yaml
```

Start HTTPS port-forward if not running:

```bash id="vfyzow"
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443
```

In another terminal:

```bash id="z93o2z"
curl -vk --resolve missing-tls.localdev.me:8443:127.0.0.1 https://missing-tls.localdev.me:8443/
```

Debug:

```bash id="h3wjvt"
kubectl describe ingress missing-tls-secret-demo -n dev

kubectl get secret missing-tls-secret -n dev || true

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

Expected:

```text id="xqsuhn"
TLS may fall back to a default certificate or show certificate mismatch.
Ingress controller logs may mention missing Secret.
```

---

# 16. Create Self-Signed TLS Secret

Generate certificate:

```bash id="t1eb4s"
cd ~/devops-masterclass/11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/missing-tls.localdev.me.key \
  -out certs/missing-tls.localdev.me.crt \
  -subj "/CN=missing-tls.localdev.me/O=missing-tls.localdev.me" \
  -addext "subjectAltName = DNS:missing-tls.localdev.me"
```

Create Secret:

```bash id="woz23b"
kubectl create secret tls missing-tls-secret \
  -n dev \
  --key certs/missing-tls.localdev.me.key \
  --cert certs/missing-tls.localdev.me.crt \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Validate Secret type:

```bash id="gn8o0a"
kubectl get secret missing-tls-secret -n dev -o jsonpath='{.type}'
echo
```

Expected:

```text id="gpz8ne"
kubernetes.io/tls
```

Test HTTPS:

```bash id="w3ad15"
curl -vk --resolve missing-tls.localdev.me:8443:127.0.0.1 https://missing-tls.localdev.me:8443/
```

Expected:

```text id="hpfoi9"
TLS handshake succeeds with self-signed certificate warning.
Response body should be ingress-demo-ok.
```

ingress-nginx’s TLS guide shows this self-signed certificate pattern and notes that the generated Secret should be type `kubernetes.io/tls`. ([Kubernetes][5])

Clean later:

```bash id="ows8bs"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/06-missing-tls-secret.yaml --ignore-not-found=true
kubectl delete secret missing-tls-secret -n dev --ignore-not-found=true
```

---

# 17. TLS Certificate Hostname Mismatch

Create a certificate for one hostname but use it for another.

Generate mismatch cert:

```bash id="yei5fz"
cd ~/devops-masterclass/11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/wrong-host.key \
  -out certs/wrong-host.crt \
  -subj "/CN=wrong-cert.localdev.me/O=wrong-cert.localdev.me" \
  -addext "subjectAltName = DNS:wrong-cert.localdev.me"
```

Create Secret:

```bash id="xemubd"
kubectl create secret tls tls-host-mismatch-secret \
  -n dev \
  --key certs/wrong-host.key \
  --cert certs/wrong-host.crt \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Create Ingress:

```bash id="n2w2gu"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/07-tls-host-mismatch.yaml
```

Paste:

```yaml id="og3usg"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-host-mismatch-demo
  namespace: dev
  labels:
    app: ingress-demo
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - expected-cert.localdev.me
      secretName: tls-host-mismatch-secret
  rules:
    - host: expected-cert.localdev.me
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ingress-demo
                port:
                  number: 80
```

Apply:

```bash id="j2sfl0"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/07-tls-host-mismatch.yaml
```

Test:

```bash id="fffecw"
curl -vk --resolve expected-cert.localdev.me:8443:127.0.0.1 https://expected-cert.localdev.me:8443/
```

Expected:

```text id="hw922o"
Response may route, but TLS certificate verification should warn because certificate SAN does not match expected-cert.localdev.me.
```

Fix:

```text id="x0bv1v"
Regenerate certificate with SAN matching expected-cert.localdev.me.
Replace the TLS Secret.
```

Clean:

```bash id="vk5rqj"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests/07-tls-host-mismatch.yaml --ignore-not-found=true
kubectl delete secret tls-host-mismatch-secret -n dev --ignore-not-found=true
```

---

# 18. `curl -H Host` vs `curl --resolve`

Use Host header for HTTP testing:

```bash id="b230f5"
curl -H "Host: ingress-demo.localdev.me" http://127.0.0.1:8080/
```

Use `--resolve` for HTTPS hostname and SNI testing:

```bash id="goyiqe"
curl -vk --resolve missing-tls.localdev.me:8443:127.0.0.1 https://missing-tls.localdev.me:8443/
```

Why?

```text id="zmm7y2"
TLS certificate selection uses SNI during the TLS handshake.
A plain Host header is sent after TLS negotiation.
For HTTPS, use --resolve so curl connects to 127.0.0.1 but still uses the real hostname for TLS/SNI.
```

Production rule:

```text id="cv5hk6"
For HTTP host routing, Host header is enough.
For HTTPS certificate debugging, use --resolve or real DNS.
```

---

# 19. Create Ingress Summary Script

```bash id="r5nzyd"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-summary.sh
```

Paste:

```bash id="mwm7eu"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
INGRESS="${INGRESS:-ingress-demo}"

echo "===== Ingress Summary ====="
echo "Namespace: $NAMESPACE"
echo "Ingress: $INGRESS"

echo
echo "Ingress controller pods:"
kubectl get pods -n ingress-nginx -o wide || true

echo
echo "Ingress controller services:"
kubectl get svc -n ingress-nginx || true

echo
echo "IngressClasses:"
kubectl get ingressclass || true

echo
echo "Ingress:"
kubectl get ingress "$INGRESS" -n "$NAMESPACE" -o wide || true
kubectl describe ingress "$INGRESS" -n "$NAMESPACE" || true

echo
echo "Referenced backend services:"
SERVICES="$(kubectl get ingress "$INGRESS" -n "$NAMESPACE" -o jsonpath='{range .spec.rules[*].http.paths[*]}{.backend.service.name}{"\n"}{end}' 2>/dev/null | sort -u || true)"

for svc in $SERVICES; do
  echo
  echo "Service: $svc"
  kubectl get svc "$svc" -n "$NAMESPACE" -o wide || true
  kubectl describe svc "$svc" -n "$NAMESPACE" || true
  echo "Endpoints:"
  kubectl get endpoints "$svc" -n "$NAMESPACE" -o wide || true
  echo "EndpointSlices:"
  kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name="$svc" -o wide || true
done

echo
echo "TLS Secrets:"
SECRETS="$(kubectl get ingress "$INGRESS" -n "$NAMESPACE" -o jsonpath='{range .spec.tls[*]}{.secretName}{"\n"}{end}' 2>/dev/null || true)"
for secret in $SECRETS; do
  kubectl get secret "$secret" -n "$NAMESPACE" -o wide || true
done

echo
echo "Recent namespace events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true

echo
echo "Recent ingress-nginx logs:"
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50 || true
```

Make executable:

```bash id="lx9s8f"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-summary.sh
```

Run:

```bash id="c4ih9r"
NAMESPACE=dev INGRESS=ingress-demo \
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-summary.sh
```

---

# 20. Create Ingress HTTP Test Script

```bash id="wx7rlw"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-http-test.sh
```

Paste:

```bash id="jvnibp"
#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-ingress-demo.localdev.me}"
PATH_TO_TEST="${PATH_TO_TEST:-/}"
PORT="${PORT:-8080}"
IP="${IP:-127.0.0.1}"

echo "===== Ingress HTTP Test ====="
echo "Host: $HOST"
echo "Path: $PATH_TO_TEST"
echo "IP: $IP"
echo "Port: $PORT"

echo
echo "HTTP request:"
curl -i -H "Host: $HOST" "http://$IP:$PORT$PATH_TO_TEST" || true
```

Make executable:

```bash id="rl0smw"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-http-test.sh
```

Run:

```bash id="yey7p9"
HOST=ingress-demo.localdev.me PATH_TO_TEST=/ PORT=8080 \
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-http-test.sh
```

---

# 21. Create Ingress TLS Test Script

```bash id="xlev7p"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-tls-test.sh
```

Paste:

```bash id="ouumem"
#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-missing-tls.localdev.me}"
PATH_TO_TEST="${PATH_TO_TEST:-/}"
PORT="${PORT:-8443}"
IP="${IP:-127.0.0.1}"

echo "===== Ingress TLS Test ====="
echo "Host: $HOST"
echo "Path: $PATH_TO_TEST"
echo "IP: $IP"
echo "Port: $PORT"

echo
echo "TLS request with --resolve:"
curl -vk --resolve "$HOST:$PORT:$IP" "https://$HOST:$PORT$PATH_TO_TEST" || true
```

Make executable:

```bash id="c2mokl"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-tls-test.sh
```

Run:

```bash id="dlhjs8"
HOST=missing-tls.localdev.me PORT=8443 \
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-tls-test.sh
```

---

# 22. Create Ingress/TLS Runbook

```bash id="kzm6gl"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/runbooks/ingress-tls-troubleshooting-runbook.md
```

Paste:

````markdown id="xdurc8"
# Ingress and TLS Troubleshooting Runbook

## 1. Check Ingress Controller

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
````

## 2. Check IngressClass

```bash id="kgdbe4"
kubectl get ingressclass
kubectl describe ingressclass nginx
```

## 3. Check Ingress

```bash id="z3xsg5"
kubectl get ingress -n NAMESPACE
kubectl describe ingress INGRESS -n NAMESPACE
kubectl get ingress INGRESS -n NAMESPACE -o yaml
```

Check:

* ingressClassName
* host
* path
* pathType
* backend Service
* backend Service port
* TLS Secret

## 4. Check Backend Service

```bash id="2ngwqb"
kubectl get svc SERVICE -n NAMESPACE
kubectl describe svc SERVICE -n NAMESPACE
kubectl get endpoints SERVICE -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE
```

No endpoints means:

* selector mismatch
* Pods not Ready
* wrong labels
* wrong namespace

## 5. Check Pods

```bash id="xh46sc"
kubectl get pods -n NAMESPACE --show-labels
kubectl describe pod POD -n NAMESPACE
kubectl logs POD -n NAMESPACE --tail=100
```

## 6. Test HTTP Host Routing

```bash id="zxd98v"
curl -H "Host: HOSTNAME" http://INGRESS_IP_OR_PORT/
```

## 7. Test HTTPS and SNI

```bash id="cx5a5t"
curl -vk --resolve HOSTNAME:443:INGRESS_IP https://HOSTNAME/
```

For local port-forward to 8443:

```bash id="ynhbk5"
curl -vk --resolve HOSTNAME:8443:127.0.0.1 https://HOSTNAME:8443/
```

## 8. Check TLS Secret

```bash id="wji3sp"
kubectl get secret TLS_SECRET -n NAMESPACE
kubectl get secret TLS_SECRET -n NAMESPACE -o jsonpath='{.type}'
```

Expected:

```text id="alwz1s"
kubernetes.io/tls
```

## 9. Interpret HTTP Codes

| Code               | Common Meaning                                   |
| ------------------ | ------------------------------------------------ |
| 404                | host/path mismatch or backend app 404            |
| 503                | matched route but backend unavailable            |
| 502                | upstream connection problem                      |
| TLS warning        | self-signed, expired, or hostname mismatch       |
| connection refused | controller not reachable or port-forward missing |

## Golden Rule

Debug from backend outward: Pod -> Service -> Endpoints -> Ingress -> Controller -> DNS/TLS.

````id="pki17v"

---

# 23. Create Production HTTPS Runbook

```bash id="fd49o9"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/runbooks/production-https-debugging-runbook.md
````

Paste:

````markdown id="teqv9r"
# Production HTTPS Debugging Runbook

## Full Path

Client -> DNS -> Load Balancer -> Ingress Controller -> Ingress -> Service -> EndpointSlice -> Pod

## Step 1 — DNS

```bash
dig HOSTNAME
nslookup HOSTNAME
````

Check:

* correct public IP / CNAME
* TTL
* split-horizon DNS
* stale cache

## Step 2 — TLS

```bash id="zxom7h"
openssl s_client -connect HOSTNAME:443 -servername HOSTNAME
curl -v https://HOSTNAME/
```

Check:

* certificate SAN
* issuer
* expiry
* chain
* SNI
* wildcard coverage

## Step 3 — Load Balancer

Check cloud load balancer:

* listener 80/443
* target health
* security groups/firewall
* WAF rules
* certificate at correct layer

## Step 4 — Ingress Controller

```bash id="f2u2du"
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=200
```

## Step 5 — Ingress Object

```bash id="ut9sxb"
kubectl describe ingress APP -n NAMESPACE
```

Check:

* host
* path
* ingressClassName
* TLS secret
* annotations

## Step 6 — Backend

```bash id="o74qiz"
kubectl get svc,endpoints -n NAMESPACE
kubectl get pods -n NAMESPACE --show-labels
```

## Step 7 — Direct Service Test

```bash id="x2xfq6"
kubectl port-forward -n NAMESPACE svc/SERVICE 18080:80
curl http://127.0.0.1:18080/health
```

## Rule

If direct Service test fails, do not debug TLS first.
Fix backend health first.

````id="ck7wdf"

---

# 24. Run All Ingress Labs Script

```bash id="mqxuew"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/run-ingress-labs.sh
````

Paste:

```bash id="g6tjw6"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/00-healthy-ingress-app.yaml"
kubectl rollout status deployment/ingress-demo -n dev --timeout=120s

kubectl apply -f "$BASE/01-healthy-ingress.yaml"
kubectl apply -f "$BASE/02-wrong-ingressclass.yaml"
kubectl apply -f "$BASE/03-path-mismatch.yaml"
kubectl apply -f "$BASE/04-backend-service-missing.yaml"
kubectl apply -f "$BASE/05-backend-no-endpoints.yaml"

echo "Ingress labs applied."
echo "Start controller port-forward:"
echo "kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80"
echo
echo "Then test:"
echo "HOST=ingress-demo.localdev.me ./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/ingress-http-test.sh"
```

Make executable:

```bash id="qwfd8w"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/run-ingress-labs.sh
```

Run:

```bash id="p22y1k"
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/run-ingress-labs.sh
```

---

# 25. Cleanup Script

```bash id="syz3zj"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/cleanup-lesson-11-5.sh
```

Paste:

```bash id="zfejc9"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.5 ====="

kubectl delete -f "$BASE/07-tls-host-mismatch.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-missing-tls-secret.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-backend-no-endpoints.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-backend-service-missing.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-path-mismatch.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-wrong-ingressclass.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-healthy-ingress.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/00-healthy-ingress-app.yaml" --ignore-not-found=true

kubectl delete secret missing-tls-secret -n dev --ignore-not-found=true
kubectl delete secret tls-host-mismatch-secret -n dev --ignore-not-found=true

echo "Lesson 11.5 demo resources cleaned."
echo "Certificate files in certs/ are kept for learning unless you delete them manually."
```

Make executable:

```bash id="v57spd"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/cleanup-lesson-11-5.sh
```

Run cleanup:

```bash id="y3qbij"
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/cleanup-lesson-11-5.sh
```

---

# 26. Validation Script

```bash id="w5nk93"
nano 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/validate-lesson-11-5.sh
```

Paste:

```bash id="t4pxap"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.5 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"
test -d "$BASE/certs"

test -f "$BASE/notes/ingress-tls-mental-model.md"
test -f "$BASE/notes/ingress-debug-commands.md"

test -f "$BASE/runbooks/ingress-tls-troubleshooting-runbook.md"
test -f "$BASE/runbooks/production-https-debugging-runbook.md"

test -f "$BASE/manifests/00-healthy-ingress-app.yaml"
test -f "$BASE/manifests/01-healthy-ingress.yaml"
test -f "$BASE/manifests/02-wrong-ingressclass.yaml"
test -f "$BASE/manifests/03-path-mismatch.yaml"
test -f "$BASE/manifests/04-backend-service-missing.yaml"
test -f "$BASE/manifests/05-backend-no-endpoints.yaml"
test -f "$BASE/manifests/06-missing-tls-secret.yaml"
test -f "$BASE/manifests/07-tls-host-mismatch.yaml"

test -x "$BASE/scripts/ingress-summary.sh"
test -x "$BASE/scripts/ingress-http-test.sh"
test -x "$BASE/scripts/ingress-tls-test.sh"
test -x "$BASE/scripts/run-ingress-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-5.sh"

kubectl get namespace dev >/dev/null

kubectl get namespace ingress-nginx >/dev/null
kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller >/dev/null
kubectl get ingressclass nginx >/dev/null

kubectl apply -f "$BASE/manifests/00-healthy-ingress-app.yaml" >/dev/null
kubectl rollout status deployment/ingress-demo -n dev --timeout=120s >/dev/null

kubectl apply -f "$BASE/manifests/01-healthy-ingress.yaml" >/dev/null

kubectl get ingress ingress-demo -n dev >/dev/null
kubectl get svc ingress-demo -n dev >/dev/null
kubectl get endpoints ingress-demo -n dev >/dev/null

ENDPOINTS="$(kubectl get endpoints ingress-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: ingress-demo has no endpoints"
  exit 1
fi

echo "ingress-demo endpoints: $ENDPOINTS"
echo "Lesson 11.5 validation passed."
```

Make executable:

```bash id="d5n33f"
chmod +x 11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/validate-lesson-11-5.sh
```

Run:

```bash id="c9aay3"
./11-advanced-kubernetes-troubleshooting/11.5-ingress-tls-troubleshooting/scripts/validate-lesson-11-5.sh
```

---

# 27. Real Production Debug Mapping

```text id="mixajo"
Ingress object exists but nothing routes:
  check Ingress Controller and ingressClassName

404 from Ingress:
  check host/path match first

503 from Ingress:
  check backend Service, endpoints, readiness, controller logs

TLS default certificate shown:
  check TLS Secret exists and is in the same namespace as Ingress

TLS hostname warning:
  check certificate SAN matches Ingress host and curl hostname

HTTP works but HTTPS fails:
  check TLS Secret, certificate, controller 443 listener, SNI

Service direct test fails:
  fix Pod/Service/endpoints before debugging Ingress

Service direct test works but Ingress fails:
  debug Ingress rule, controller, host/path, TLS

ArgoCD says Synced but Ingress broken:
  Git desired state may be applied correctly, but runtime dependencies like controller, DNS, Service endpoints, or TLS cert may be unhealthy
```

---

# 28. Common Mistakes

## Mistake 1: Creating Ingress without an Ingress Controller

Ingress object alone is not enough.

```bash id="dalc60"
kubectl get pods -n ingress-nginx
```

---

## Mistake 2: Wrong `ingressClassName`

Check:

```bash id="jpxoo4"
kubectl get ingressclass
kubectl describe ingress INGRESS -n NAMESPACE
```

---

## Mistake 3: Testing with wrong Host header

Wrong:

```bash id="yn51yq"
curl http://127.0.0.1:8080/
```

Correct:

```bash id="ameh09"
curl -H "Host: ingress-demo.localdev.me" http://127.0.0.1:8080/
```

---

## Mistake 4: Debugging TLS before backend health

First:

```bash id="ln6z2m"
kubectl get endpoints SERVICE -n NAMESPACE
```

---

## Mistake 5: Using only `-H Host` for HTTPS testing

For HTTPS hostname/cert checks, use:

```bash id="hg9fla"
curl -vk --resolve hostname:443:IP https://hostname/
```

For local 8443:

```bash id="d2s4lw"
curl -vk --resolve hostname:8443:127.0.0.1 https://hostname:8443/
```

---

# 29. Interview Explanation

Use this:

```text id="vgiipw"
When troubleshooting Kubernetes Ingress, I follow the full traffic path: client, DNS or Host header, Ingress Controller, Ingress rule, backend Service, EndpointSlice, Pod, and container port. I first verify the Ingress Controller is running and the ingressClassName matches. Then I inspect the Ingress host, path, backend Service name, and backend port.

If I see 404, I check host and path matching. If I see 503, I check whether the backend Service has ready endpoints. I validate the Service directly before debugging Ingress. For TLS issues, I verify the TLS Secret exists in the same namespace, is type kubernetes.io/tls, and that the certificate SAN matches the Ingress host. For HTTPS tests, I use curl --resolve so the request uses the correct hostname for SNI while connecting to the intended IP.
```

Resume bullet:

```text id="j4prdd"
Built Kubernetes Ingress and TLS troubleshooting labs covering Ingress Controller health, ingressClassName mismatches, host/path routing failures, missing backend Services, empty endpoints, 404 vs 503 analysis, TLS Secret creation, certificate hostname mismatch, curl Host/SNI testing, controller logs, validation scripts, and production HTTPS runbooks.
```

---

# 30. Commit Lesson 11.5

```bash id="cvnsbi"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes Ingress and TLS troubleshooting labs"

git push
```

---

# 31. Next Lesson

```text id="atzli7"
Lesson 11.6 — ConfigMap and Secret Injection Troubleshooting
```

We will cover:

```text id="r3fqa6"
missing ConfigMap
missing Secret
wrong key name
env value not updating
envFrom mistakes
mounted file config
subPath config update issue
base64 Secret confusion
optional vs required config
CreateContainerConfigError
External Secret concept
production config debugging workflow
```

[1]: https://kubernetes.io/docs/concepts/services-networking/ingress/?utm_source=chatgpt.com "Ingress"
[2]: https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md?utm_source=chatgpt.com "ingress-nginx/docs/deploy/index.md at main"
[3]: https://github.com/kubernetes/ingress-nginx/blob/main/docs/user-guide/nginx-configuration/annotations.md?utm_source=chatgpt.com "kubernetes/ingress-nginx"
[4]: https://kubernetes.io/docs/concepts/configuration/secret/?utm_source=chatgpt.com "Secrets"
[5]: https://kubernetes.github.io/ingress-nginx/user-guide/tls/?utm_source=chatgpt.com "TLS/HTTPS - Ingress-Nginx Controller"
