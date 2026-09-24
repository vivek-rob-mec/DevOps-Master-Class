# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.7 — Probe Failure Troubleshooting

In Lesson 11.6, you debugged **ConfigMap and Secret injection failures**:

```text
missing ConfigMap
missing Secret
wrong key name
env value not updating
mounted file config
subPath config update issue
Secret base64 confusion
optional vs required config
CreateContainerConfigError
```

Now we move to **probe failures**.

This lesson is extremely important because probe mistakes can cause:

```text
rollout stuck
Pod Running but NotReady
Service has no endpoints
Ingress 503
CrashLoopBackOff
unnecessary restarts
false production incidents
traffic going to unhealthy Pods
healthy but slow apps being killed
```

Kubernetes supports **liveness**, **readiness**, and **startup** probes. Liveness checks whether a container should be restarted, readiness checks whether a Pod should receive traffic, and startup checks whether a slow-starting app has finished initialization. Kubernetes supports probe mechanisms such as HTTP, TCP, exec, and gRPC checks. ([Kubernetes][1])

---

# 1. What We Will Cover

```text
11.7.1   Probe mental model
11.7.2   Liveness vs readiness vs startup
11.7.3   HTTP, TCP, exec, and gRPC probe concepts
11.7.4   Wrong readiness path
11.7.5   Wrong readiness port
11.7.6   Readiness blocking Service endpoints
11.7.7   Liveness causing CrashLoopBackOff
11.7.8   Slow startup without startupProbe
11.7.9   Fixing slow startup with startupProbe
11.7.10  Dependency-based readiness
11.7.11  Probe timeout and failureThreshold tuning
11.7.12  TCP probe debugging
11.7.13  Exec probe debugging
11.7.14  Rollout stuck due to readiness
11.7.15  Production probe design
11.7.16  Scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash
tree -L 3 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting
```

---

# 3. Probe Mental Model

A probe is a health check run by kubelet.

```text
kubelet
  ↓
checks container using probe config
  ↓
updates Pod/container state
  ↓
Kubernetes reacts
```

The three main probe types:

```text
readinessProbe:
  Should this Pod receive traffic?

livenessProbe:
  Should this container be restarted?

startupProbe:
  Has this slow-starting app finished startup?
```

The most important difference:

```text
Readiness removes traffic.
Liveness restarts the container.
Startup protects slow startup from premature liveness/readiness checks.
```

If a startup probe is configured, Kubernetes does not run liveness or readiness probes until the startup probe succeeds. This is useful for applications that need extra initialization time. ([Kubernetes][2])

---

# 4. Create Probe Mental Model Notes

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/notes/probe-mental-model.md
```

Paste:

```markdown
# Kubernetes Probe Mental Model

## Probe Types

### readinessProbe

Answers:

Can this Pod receive traffic?

Failure result:

- Pod becomes NotReady
- Service endpoints may remove the Pod
- Deployment rollout may pause/stall

### livenessProbe

Answers:

Should this container be restarted?

Failure result:

- kubelet restarts the container
- repeated failures can cause CrashLoopBackOff

### startupProbe

Answers:

Has the app finished starting?

Failure result:

- container may be restarted if startup never succeeds
- while startupProbe is running, liveness/readiness are delayed

## Golden Rules

- Readiness is for traffic.
- Liveness is for deadlock/restart.
- Startup is for slow startup.
- Do not use liveness for dependency checks.
- Do not make liveness too aggressive.
- Readiness can check dependencies.
- Startup probe should protect slow applications.
```

---

# 5. First Probe Debug Commands

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/notes/probe-debug-commands.md
```

Paste:

````markdown
# Probe Debug Commands

## Pod status

```bash
kubectl get pods -n NAMESPACE
kubectl get pods -n NAMESPACE -o wide
````

## Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* Readiness probe failed
* Liveness probe failed
* Startup probe failed
* HTTP probe failed with statuscode
* connection refused
* context deadline exceeded
* no route to host
* exec probe failed

## Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## Logs

```bash
kubectl logs POD_NAME -n NAMESPACE --tail=100
kubectl logs POD_NAME -n NAMESPACE --previous --tail=100
```

## Service endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
kubectl get endpointslice -n NAMESPACE -l kubernetes.io/service-name=SERVICE_NAME
```

## Probe config from Pod

```bash
kubectl get pod POD_NAME -n NAMESPACE -o yaml | sed -n '/readinessProbe:/,/resources:/p'
kubectl get pod POD_NAME -n NAMESPACE -o yaml | sed -n '/livenessProbe:/,/resources:/p'
kubectl get pod POD_NAME -n NAMESPACE -o yaml | sed -n '/startupProbe:/,/resources:/p'
```

````

---

# 6. Probe Types: HTTP, TCP, Exec, gRPC

Kubernetes probes can check a container in different ways. HTTP probes send an HTTP request, TCP probes check whether a port accepts TCP connections, exec probes run a command inside the container, and gRPC probes use the gRPC health checking protocol. :contentReference[oaicite:2]{index=2}

Simple selection:

```text
HTTP probe:
  Best for HTTP APIs with /health, /ready, /live.

TCP probe:
  Best when only port-open check is available.

Exec probe:
  Best for local process/file/command checks.

gRPC probe:
  Best for gRPC services implementing health checking.
````

Production warning:

```text
A TCP probe only proves the port is open.
It does not prove the app is logically healthy.
```

---

# 7. Create Healthy Probe Demo App

Create a small Python app with `/health`, `/ready`, `/slow`, and `/toggle-ready`.

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/00-healthy-probe-demo.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: probe-demo-code
  namespace: dev
  labels:
    app: probe-demo
data:
  app.py: |
    import os
    import time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    START_TIME = time.time()
    READY_FILE = "/tmp/ready"

    with open(READY_FILE, "w") as f:
        f.write("ready")

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args), flush=True)

        def do_GET(self):
            if self.path == "/":
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"probe-demo-ok\n")

            elif self.path == "/health":
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"live\n")

            elif self.path == "/ready":
                if os.path.exists(READY_FILE):
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ready\n")
                else:
                    self.send_response(503)
                    self.end_headers()
                    self.wfile.write(b"not ready\n")

            elif self.path == "/toggle-not-ready":
                if os.path.exists(READY_FILE):
                    os.remove(READY_FILE)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"readiness disabled\n")

            elif self.path == "/toggle-ready":
                with open(READY_FILE, "w") as f:
                    f.write("ready")
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"readiness enabled\n")

            elif self.path == "/slow":
                time.sleep(5)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"slow response\n")

            else:
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"not found\n")

    port = int(os.environ.get("PORT", "8080"))
    print(f"probe-demo starting on port {port}", flush=True)
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-demo
  namespace: dev
  labels:
    app: probe-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe-demo
  template:
    metadata:
      labels:
        app: probe-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: PORT
              value: "8080"
          volumeMounts:
            - name: app-code
              mountPath: /app
          startupProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 3
            timeoutSeconds: 2
            failureThreshold: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
      volumes:
        - name: app-code
          configMap:
            name: probe-demo-code
---
apiVersion: v1
kind: Service
metadata:
  name: probe-demo
  namespace: dev
  labels:
    app: probe-demo
spec:
  selector:
    app: probe-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/00-healthy-probe-demo.yaml

kubectl rollout status deployment/probe-demo -n dev --timeout=180s
```

Check:

```bash
kubectl get deploy,pods,svc,endpoints -n dev -l app=probe-demo -o wide
```

Test Service:

```bash
kubectl port-forward -n dev svc/probe-demo 18083:80
```

Another terminal:

```bash
curl http://127.0.0.1:18083/
curl http://127.0.0.1:18083/health
curl http://127.0.0.1:18083/ready
```

Expected:

```text
probe-demo-ok
live
ready
```

Stop port-forward:

```text
Ctrl + C
```

---

# 8. Incident 1 — Wrong Readiness Path

A wrong readiness path causes the Pod to run but remain NotReady.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/01-wrong-readiness-path.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-readiness-path
  namespace: dev
  labels:
    app: wrong-readiness-path
spec:
  replicas: 2
  progressDeadlineSeconds: 45
  selector:
    matchLabels:
      app: wrong-readiness-path
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: wrong-readiness-path
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /this-path-does-not-exist
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 10
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
  name: wrong-readiness-path
  namespace: dev
  labels:
    app: wrong-readiness-path
spec:
  selector:
    app: wrong-readiness-path
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/01-wrong-readiness-path.yaml
```

Debug:

```bash
kubectl get pods -n dev -l app=wrong-readiness-path

POD="$(kubectl get pod -n dev -l app=wrong-readiness-path -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30

kubectl get endpoints wrong-readiness-path -n dev
```

Expected:

```text
Pods are Running but 0/1 Ready.
Events show readiness probe failed.
Service endpoints may be empty.
```

A failing readiness probe means the Pod is not considered ready to receive traffic. This affects Service endpoints and can block Deployment rollouts. ([Kubernetes][1])

Fix:

```bash
kubectl patch deployment wrong-readiness-path -n dev \
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

```bash
kubectl rollout status deployment/wrong-readiness-path -n dev --timeout=120s
kubectl get pods -n dev -l app=wrong-readiness-path
kubectl get endpoints wrong-readiness-path -n dev
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/01-wrong-readiness-path.yaml --ignore-not-found=true
```

---

# 9. Incident 2 — Wrong Readiness Port

A wrong port can cause `connection refused`.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/02-wrong-readiness-port.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-readiness-port
  namespace: dev
  labels:
    app: wrong-readiness-port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wrong-readiness-port
  template:
    metadata:
      labels:
        app: wrong-readiness-port
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=wrong-readiness-port-fixed"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /
              port: 9999
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
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/02-wrong-readiness-port.yaml
```

Debug:

```bash
kubectl get pods -n dev -l app=wrong-readiness-port

POD="$(kubectl get pod -n dev -l app=wrong-readiness-port -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text
Readiness probe failed: connection refused
```

Fix:

```bash
kubectl patch deployment wrong-readiness-port -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/port",
      "value": "http"
    }
  ]'
```

Validate:

```bash
kubectl rollout status deployment/wrong-readiness-port -n dev --timeout=120s
kubectl get pods -n dev -l app=wrong-readiness-port
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/02-wrong-readiness-port.yaml --ignore-not-found=true
```

---

# 10. Incident 3 — Liveness Probe Killing the App

Liveness probes restart containers when they fail. This is useful for true deadlocks, but dangerous if configured too aggressively or pointed at a dependency-sensitive endpoint. ([Kubernetes][1])

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/03-liveness-kills-app.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: liveness-kills-app
  namespace: dev
  labels:
    app: liveness-kills-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: liveness-kills-app
  template:
    metadata:
      labels:
        app: liveness-kills-app
    spec:
      containers:
        - name: web
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          livenessProbe:
            httpGet:
              path: /bad-liveness-path
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 1
          readinessProbe:
            httpGet:
              path: /
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
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/03-liveness-kills-app.yaml
```

Watch:

```bash
kubectl get pods -n dev -l app=liveness-kills-app -w
```

Stop watch after you see restarts:

```text
Ctrl + C
```

Debug:

```bash
POD="$(kubectl get pod -n dev -l app=liveness-kills-app -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get pod "$POD" -n dev \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text
Liveness probe failed
Container restarted repeatedly
Restart count increases
```

Fix:

```bash
kubectl patch deployment liveness-kills-app -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path",
      "value": "/"
    },
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/livenessProbe/failureThreshold",
      "value": 3
    }
  ]'
```

Validate:

```bash
kubectl rollout status deployment/liveness-kills-app -n dev --timeout=120s
kubectl get pods -n dev -l app=liveness-kills-app
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/03-liveness-kills-app.yaml --ignore-not-found=true
```

Production rule:

```text
Liveness should answer: is this process unrecoverably stuck?
It should not fail just because a database or downstream API is temporarily unavailable.
```

---

# 11. Incident 4 — Slow Startup Without Startup Probe

A slow app can be killed before it finishes starting if liveness is active too early.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/04-slow-start-no-startup-probe.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: slow-start-code
  namespace: dev
  labels:
    app: slow-start-no-startup-probe
data:
  app.py: |
    import time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    STARTED = False

    print("Simulating slow startup: sleeping for 60 seconds", flush=True)
    time.sleep(60)
    STARTED = True
    print("Startup complete", flush=True)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path in ["/", "/health", "/ready"]:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"slow-start-ok\n")
            else:
                self.send_response(404)
                self.end_headers()

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-start-no-startup-probe
  namespace: dev
  labels:
    app: slow-start-no-startup-probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: slow-start-no-startup-probe
  template:
    metadata:
      labels:
        app: slow-start-no-startup-probe
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: app-code
              mountPath: /app
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
      volumes:
        - name: app-code
          configMap:
            name: slow-start-code
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/04-slow-start-no-startup-probe.yaml
```

Watch:

```bash
kubectl get pods -n dev -l app=slow-start-no-startup-probe -w
```

Stop after restarts:

```text
Ctrl + C
```

Debug:

```bash
POD="$(kubectl get pod -n dev -l app=slow-start-no-startup-probe -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --previous --tail=100 || true

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text
App sleeps for startup.
Liveness begins too early.
Container is restarted before startup completes.
```

Fix pattern:

```text
Use startupProbe for slow-starting applications.
Do not rely only on large initialDelaySeconds.
```

Clean before next incident:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/04-slow-start-no-startup-probe.yaml --ignore-not-found=true
```

---

# 12. Incident 5 — Slow Startup Fixed with startupProbe

Now use startupProbe correctly.

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/05-slow-start-with-startup-probe.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: slow-start-fixed-code
  namespace: dev
  labels:
    app: slow-start-with-startup-probe
data:
  app.py: |
    import time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    print("Simulating slow startup: sleeping for 40 seconds", flush=True)
    time.sleep(40)
    print("Startup complete", flush=True)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path in ["/", "/health", "/ready"]:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"slow-start-fixed-ok\n")
            else:
                self.send_response(404)
                self.end_headers()

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slow-start-with-startup-probe
  namespace: dev
  labels:
    app: slow-start-with-startup-probe
spec:
  replicas: 1
  progressDeadlineSeconds: 120
  selector:
    matchLabels:
      app: slow-start-with-startup-probe
  template:
    metadata:
      labels:
        app: slow-start-with-startup-probe
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: app-code
              mountPath: /app
          startupProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 15
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
      volumes:
        - name: app-code
          configMap:
            name: slow-start-fixed-code
---
apiVersion: v1
kind: Service
metadata:
  name: slow-start-with-startup-probe
  namespace: dev
  labels:
    app: slow-start-with-startup-probe
spec:
  selector:
    app: slow-start-with-startup-probe
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/05-slow-start-with-startup-probe.yaml
```

Watch rollout:

```bash
kubectl rollout status deployment/slow-start-with-startup-probe -n dev --timeout=180s
```

Check:

```bash
kubectl get pods -n dev -l app=slow-start-with-startup-probe

POD="$(kubectl get pod -n dev -l app=slow-start-with-startup-probe -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl logs "$POD" -n dev --tail=100
```

Expected:

```text
App survives slow startup.
startupProbe protects it until /health starts responding.
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/05-slow-start-with-startup-probe.yaml --ignore-not-found=true
```

---

# 13. Incident 6 — Dependency-Based Readiness

Readiness can include dependencies.

Example:

```text
API process is alive.
But database is unavailable.
Pod should not receive traffic yet.
```

This is valid readiness behavior.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/06-dependency-readiness.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dependency-readiness-code
  namespace: dev
  labels:
    app: dependency-readiness-demo
data:
  app.py: |
    import os
    from http.server import BaseHTTPRequestHandler, HTTPServer

    DEP_FILE = "/tmp/dependency-ok"

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/health":
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"process alive\n")

            elif self.path == "/ready":
                if os.path.exists(DEP_FILE):
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"dependency ready\n")
                else:
                    self.send_response(503)
                    self.end_headers()
                    self.wfile.write(b"dependency unavailable\n")

            elif self.path == "/enable-dependency":
                with open(DEP_FILE, "w") as f:
                    f.write("ok")
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"dependency enabled\n")

            elif self.path == "/disable-dependency":
                if os.path.exists(DEP_FILE):
                    os.remove(DEP_FILE)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"dependency disabled\n")

            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"app alive\n")

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dependency-readiness-demo
  namespace: dev
  labels:
    app: dependency-readiness-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dependency-readiness-demo
  template:
    metadata:
      labels:
        app: dependency-readiness-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: app-code
              mountPath: /app
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
      volumes:
        - name: app-code
          configMap:
            name: dependency-readiness-code
---
apiVersion: v1
kind: Service
metadata:
  name: dependency-readiness-demo
  namespace: dev
  labels:
    app: dependency-readiness-demo
spec:
  selector:
    app: dependency-readiness-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/06-dependency-readiness.yaml
```

Check:

```bash
kubectl get pods -n dev -l app=dependency-readiness-demo

POD="$(kubectl get pod -n dev -l app=dependency-readiness-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get endpoints dependency-readiness-demo -n dev
```

Expected:

```text
Pod Running but NotReady.
Liveness is OK.
Readiness fails because dependency is unavailable.
Service has no ready endpoint.
```

Enable dependency:

```bash
kubectl port-forward -n dev pod/"$POD" 18084:8080
```

Another terminal:

```bash
curl http://127.0.0.1:18084/enable-dependency
```

Now check:

```bash
kubectl get pods -n dev -l app=dependency-readiness-demo
kubectl get endpoints dependency-readiness-demo -n dev
```

Expected:

```text
Pod becomes Ready.
Endpoint appears.
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/06-dependency-readiness.yaml --ignore-not-found=true
```

Production rule:

```text
Dependency checks belong in readiness, not liveness.
If the database is down, remove the Pod from traffic.
Do not keep restarting the app because a dependency is temporarily unavailable.
```

---

# 14. Incident 7 — Probe Timeout Too Low

A probe can fail because the timeout is too aggressive.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/07-probe-timeout-too-low.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: timeout-probe-code
  namespace: dev
  labels:
    app: timeout-probe-demo
data:
  app.py: |
    import time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/ready":
                time.sleep(3)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ready but slow\n")
            elif self.path == "/health":
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"live\n")
            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ok\n")

    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: timeout-probe-demo
  namespace: dev
  labels:
    app: timeout-probe-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: timeout-probe-demo
  template:
    metadata:
      labels:
        app: timeout-probe-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: app-code
              mountPath: /app
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 1
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "250m"
              memory: "128Mi"
      volumes:
        - name: app-code
          configMap:
            name: timeout-probe-code
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/07-probe-timeout-too-low.yaml
```

Debug:

```bash
kubectl get pods -n dev -l app=timeout-probe-demo

POD="$(kubectl get pod -n dev -l app=timeout-probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text
Readiness probe fails with timeout.
```

Fix timeout:

```bash
kubectl patch deployment timeout-probe-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/timeoutSeconds",
      "value": 5
    }
  ]'
```

Validate:

```bash
kubectl rollout status deployment/timeout-probe-demo -n dev --timeout=120s
kubectl get pods -n dev -l app=timeout-probe-demo
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/07-probe-timeout-too-low.yaml --ignore-not-found=true
```

Production warning:

```text
Increasing timeout can hide performance problems.
Use metrics to decide whether the app is slow or the probe is unrealistic.
```

---

# 15. Incident 8 — TCP Probe

TCP probe checks whether the port accepts connections.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/08-tcp-probe.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tcp-probe-demo
  namespace: dev
  labels:
    app: tcp-probe-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tcp-probe-demo
  template:
    metadata:
      labels:
        app: tcp-probe-demo
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=tcp-probe-ok"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            tcpSocket:
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/08-tcp-probe.yaml

kubectl rollout status deployment/tcp-probe-demo -n dev --timeout=120s
```

Debug:

```bash
kubectl get pods -n dev -l app=tcp-probe-demo

POD="$(kubectl get pod -n dev -l app=tcp-probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Break TCP probe by changing the port:

```bash
kubectl patch deployment tcp-probe-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/tcpSocket/port",
      "value": 9999
    }
  ]'
```

Debug:

```bash
kubectl get pods -n dev -l app=tcp-probe-demo
kubectl describe pod -n dev -l app=tcp-probe-demo
```

Fix:

```bash
kubectl patch deployment tcp-probe-demo -n dev \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/tcpSocket/port",
      "value": "http"
    }
  ]'
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/08-tcp-probe.yaml --ignore-not-found=true
```

---

# 16. Incident 9 — Exec Probe

Exec probe runs a command inside the container.

Create:

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/09-exec-probe.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exec-probe-demo
  namespace: dev
  labels:
    app: exec-probe-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exec-probe-demo
  template:
    metadata:
      labels:
        app: exec-probe-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              touch /tmp/ready
              sleep 3600
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - test -f /tmp/ready
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            exec:
              command:
                - sh
                - -c
                - test -f /tmp/ready
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/09-exec-probe.yaml

kubectl rollout status deployment/exec-probe-demo -n dev --timeout=120s
```

Break readiness by removing file:

```bash
POD="$(kubectl get pod -n dev -l app=exec-probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$POD" -n dev -- rm -f /tmp/ready
```

Check:

```bash
kubectl get pods -n dev -l app=exec-probe-demo
kubectl describe pod "$POD" -n dev
```

Expected:

```text
Readiness probe fails.
If liveness also fails enough times, container restarts and recreates /tmp/ready.
```

Clean:

```bash
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests/09-exec-probe.yaml --ignore-not-found=true
```

Production warning:

```text
Exec probes run inside the container.
They can be slower or more expensive than HTTP/TCP checks.
Keep them lightweight.
```

---

# 17. Probe Failure Summary Script

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP_LABEL="${APP_LABEL:-app=probe-demo}"

echo "===== Probe Failure Summary ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide || true

echo
echo "Endpoints:"
APP_NAME="$(echo "$APP_LABEL" | awk -F= '{print $2}')"
kubectl get endpoints "$APP_NAME" -n "$NAMESPACE" || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | grep -i -E 'probe|unhealthy|readiness|liveness|startup|killing|failed' | tail -n 40 || true

PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"

for pod in $PODS; do
  echo
  echo "----- Pod: $pod -----"
  kubectl describe pod "$pod" -n "$NAMESPACE" | sed -n '/Containers:/,/Conditions:/p' || true
  echo
  echo "Restart counts:"
  kubectl get pod "$pod" -n "$NAMESPACE" \
    -o jsonpath='{range .status.containerStatuses[*]}{.name}{" restarts="}{.restartCount}{" state="}{.state}{"\n"}{end}' || true
done
```

Make executable:

```bash
chmod +x 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-summary.sh
```

Run:

```bash
NAMESPACE=dev APP_LABEL='app=probe-demo' \
./11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-summary.sh
```

---

# 18. Probe Endpoint Test Script

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-endpoint-test.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
SERVICE="${SERVICE:-probe-demo}"
LOCAL_PORT="${LOCAL_PORT:-18083}"

echo "===== Probe Endpoint Test ====="
echo "Namespace: $NAMESPACE"
echo "Service: $SERVICE"
echo "Local port: $LOCAL_PORT"

kubectl port-forward -n "$NAMESPACE" svc/"$SERVICE" "$LOCAL_PORT":80 >/tmp/probe-endpoint-test.log 2>&1 &
PF_PID=$!

cleanup() {
  kill "$PF_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 5

for path in / /health /ready /slow; do
  echo
  echo "Testing $path"
  curl -i --max-time 10 "http://127.0.0.1:$LOCAL_PORT$path" || true
done
```

Make executable:

```bash
chmod +x 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-endpoint-test.sh
```

Run:

```bash
NAMESPACE=dev SERVICE=probe-demo LOCAL_PORT=18083 \
./11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/probe-endpoint-test.sh
```

---

# 19. Run All Probe Labs Script

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/run-probe-labs.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/00-healthy-probe-demo.yaml"
kubectl rollout status deployment/probe-demo -n dev --timeout=180s

kubectl apply -f "$BASE/01-wrong-readiness-path.yaml" || true
kubectl apply -f "$BASE/02-wrong-readiness-port.yaml" || true
kubectl apply -f "$BASE/03-liveness-kills-app.yaml" || true
kubectl apply -f "$BASE/06-dependency-readiness.yaml" || true
kubectl apply -f "$BASE/07-probe-timeout-too-low.yaml" || true
kubectl apply -f "$BASE/08-tcp-probe.yaml" || true
kubectl apply -f "$BASE/09-exec-probe.yaml" || true

echo "Probe labs applied."
echo "Slow-start labs are intentionally excluded because they take longer and cause restarts."
echo "Run them manually:"
echo "kubectl apply -f $BASE/04-slow-start-no-startup-probe.yaml"
echo "kubectl apply -f $BASE/05-slow-start-with-startup-probe.yaml"
```

Make executable:

```bash
chmod +x 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/run-probe-labs.sh
```

Run:

```bash
./11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/run-probe-labs.sh
```

---

# 20. Cleanup Script

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/cleanup-lesson-11-7.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.7 ====="

kubectl delete -f "$BASE/09-exec-probe.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/08-tcp-probe.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-probe-timeout-too-low.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-dependency-readiness.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-slow-start-with-startup-probe.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-slow-start-no-startup-probe.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-liveness-kills-app.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-wrong-readiness-port.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-wrong-readiness-path.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/00-healthy-probe-demo.yaml" --ignore-not-found=true

echo "Lesson 11.7 demo resources cleaned."
```

Make executable:

```bash
chmod +x 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/cleanup-lesson-11-7.sh
```

Run cleanup:

```bash
./11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/cleanup-lesson-11-7.sh
```

---

# 21. Validation Script

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/validate-lesson-11-7.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.7 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/probe-mental-model.md"
test -f "$BASE/notes/probe-debug-commands.md"

test -f "$BASE/manifests/00-healthy-probe-demo.yaml"
test -f "$BASE/manifests/01-wrong-readiness-path.yaml"
test -f "$BASE/manifests/02-wrong-readiness-port.yaml"
test -f "$BASE/manifests/03-liveness-kills-app.yaml"
test -f "$BASE/manifests/04-slow-start-no-startup-probe.yaml"
test -f "$BASE/manifests/05-slow-start-with-startup-probe.yaml"
test -f "$BASE/manifests/06-dependency-readiness.yaml"
test -f "$BASE/manifests/07-probe-timeout-too-low.yaml"
test -f "$BASE/manifests/08-tcp-probe.yaml"
test -f "$BASE/manifests/09-exec-probe.yaml"

test -x "$BASE/scripts/probe-summary.sh"
test -x "$BASE/scripts/probe-endpoint-test.sh"
test -x "$BASE/scripts/run-probe-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-7.sh"

kubectl get namespace dev >/dev/null

kubectl apply -f "$BASE/manifests/00-healthy-probe-demo.yaml" >/dev/null
kubectl rollout status deployment/probe-demo -n dev --timeout=180s >/dev/null

kubectl get svc probe-demo -n dev >/dev/null
kubectl get endpoints probe-demo -n dev >/dev/null

ENDPOINTS="$(kubectl get endpoints probe-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: probe-demo has no endpoints"
  exit 1
fi

POD="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD" -n dev -o yaml | grep -q "startupProbe"
kubectl get pod "$POD" -n dev -o yaml | grep -q "readinessProbe"
kubectl get pod "$POD" -n dev -o yaml | grep -q "livenessProbe"

echo "probe-demo endpoints: $ENDPOINTS"
echo "Lesson 11.7 validation passed."
```

Make executable:

```bash
chmod +x 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/validate-lesson-11-7.sh
```

Run:

```bash
./11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/scripts/validate-lesson-11-7.sh
```

---

# 22. Probe Troubleshooting Runbook

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/runbooks/probe-failure-troubleshooting-runbook.md
```

Paste:

````markdown
# Probe Failure Troubleshooting Runbook

## 1. Check Pod status

```bash
kubectl get pods -n NAMESPACE
````

Look for:

* Running but 0/1 Ready
* high restart count
* CrashLoopBackOff
* rollout stuck

## 2. Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for events:

* Readiness probe failed
* Liveness probe failed
* Startup probe failed
* HTTP probe failed with statuscode
* connection refused
* context deadline exceeded
* exec probe failed

## 3. Check logs

```bash
kubectl logs POD_NAME -n NAMESPACE --tail=100
kubectl logs POD_NAME -n NAMESPACE --previous --tail=100
```

Use previous logs when liveness restarts the container.

## 4. Check endpoints

```bash
kubectl get endpoints SERVICE -n NAMESPACE
```

If readiness fails, endpoints may be empty.

## 5. Check probe configuration

```bash
kubectl get pod POD_NAME -n NAMESPACE -o yaml
```

Check:

* path
* port
* scheme
* timeoutSeconds
* periodSeconds
* failureThreshold
* initialDelaySeconds
* startupProbe

## 6. Test manually

```bash
kubectl port-forward -n NAMESPACE pod/POD_NAME 18080:PORT
curl -i http://127.0.0.1:18080/health
curl -i http://127.0.0.1:18080/ready
```

## 7. Common failures

| Symptom                            | Likely Cause                            |
| ---------------------------------- | --------------------------------------- |
| Running but NotReady               | readiness path/port/dependency issue    |
| CrashLoopBackOff with probe events | liveness is restarting container        |
| rollout stuck                      | new Pods not Ready                      |
| connection refused                 | wrong port or app not listening yet     |
| context deadline exceeded          | timeout too low or app too slow         |
| HTTP 404                           | wrong path                              |
| HTTP 500/503                       | app dependency or health endpoint logic |
| slow startup killed                | missing startupProbe                    |

## 8. Fix patterns

* Fix path.
* Fix port.
* Add startupProbe.
* Increase timeout only if justified.
* Move dependency checks from liveness to readiness.
* Keep liveness simple.
* Validate Service endpoints after readiness fix.

## Golden Rule

Readiness controls traffic. Liveness controls restarts. Startup protects slow startup.

````

---

# 23. Production Probe Design Runbook

```bash
nano 11-advanced-kubernetes-troubleshooting/11.7-probe-failure-troubleshooting/runbooks/production-probe-design-runbook.md
````

Paste:

````markdown
# Production Probe Design Runbook

## API Service Recommended Pattern

### startupProbe

Use for slow startup.

```yaml
startupProbe:
  httpGet:
    path: /health
    port: http
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 30
````

### readinessProbe

Use for traffic eligibility.

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: http
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

### livenessProbe

Use only for unrecoverable stuck process detection.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

## Endpoint Semantics

### /health

Should answer:

* Is process alive?
* Is event loop/server responsive?

Should not fail because:

* database temporarily down
* external API temporarily down
* queue temporarily slow

### /ready

Can check:

* database connectivity
* required cache
* migrations complete
* required config loaded
* app can serve traffic

## Rules

* Liveness should be conservative.
* Readiness can be strict.
* Startup protects slow initialization.
* Probe endpoints should be fast.
* Probe endpoints should not perform expensive queries.
* Probe endpoints should not mutate state.
* Use named ports to avoid port mismatch.
* Watch restart counts and probe failure events.

````

---

# 24. Real Production Debug Mapping

```text
Pod Running but NotReady:
  readinessProbe is failing
  check path, port, dependency, logs, events

Service has no endpoints:
  Pods may be NotReady because readiness failed

Ingress returns 503:
  backend Service may have no ready endpoints

CrashLoopBackOff with probe events:
  livenessProbe is restarting the container

Slow app restarts during startup:
  missing or insufficient startupProbe

Readiness succeeds locally but fails in cluster:
  wrong path, wrong port, NetworkPolicy, app binds only localhost, timeout too low

Probe timeout:
  endpoint too slow, CPU throttling, timeoutSeconds too low, app under load

Dependency outage causes restarts:
  dependency check is incorrectly placed in liveness instead of readiness
````

---

# 25. Common Mistakes

## Mistake 1: Using same endpoint for everything

Bad:

```text
/health checks app + DB + Redis + external API
used for liveness and readiness
```

Better:

```text
/health = process alive
/ready = can serve traffic
```

---

## Mistake 2: No startupProbe for slow apps

If startup is slow, add startupProbe instead of making liveness very delayed.

---

## Mistake 3: Liveness checks dependencies

Bad:

```text
DB down → liveness fails → app restarts endlessly
```

Better:

```text
DB down → readiness fails → Pod removed from traffic
```

---

## Mistake 4: Timeout too low

A 1-second timeout can fail under CPU throttling or cold starts.

---

## Mistake 5: Readiness path not included in app routing

Always test:

```bash
curl /health
curl /ready
```

before deploying.

---

# 26. Interview Explanation

Use this:

```text
When troubleshooting Kubernetes probe failures, I first distinguish whether the problem is readiness, liveness, or startup. Readiness controls whether the Pod receives traffic, so a failing readiness probe usually causes Running but NotReady Pods, empty Service endpoints, stuck rollouts, or Ingress 503s. Liveness controls restarts, so a failing liveness probe can cause repeated restarts and CrashLoopBackOff. Startup probes protect slow-starting applications by delaying liveness and readiness checks until startup completes.

I debug probe failures with kubectl describe pod, events, logs, previous logs, endpoints, and manual curl tests against the probe paths. I check the probe path, port, timeoutSeconds, periodSeconds, failureThreshold, and whether the endpoint is doing the right kind of check. In production, I keep liveness simple, use readiness for dependency-based traffic gating, and use startupProbe for slow initialization.
```

Resume bullet:

```text
Built Kubernetes probe failure troubleshooting labs covering readiness failures, wrong paths and ports, liveness-induced restarts, slow startup without startupProbe, startupProbe recovery, dependency-based readiness, timeout tuning, TCP and exec probes, Service endpoint impact, validation scripts, and production probe design runbooks.
```

---

# 27. Commit Lesson 11.7

```bash
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes probe failure troubleshooting labs"

git push
```

---

# 28. Next Lesson

```text
Lesson 11.8 — RBAC Permission Troubleshooting
```

We will cover:

```text
Forbidden errors
ServiceAccount identity
Role vs ClusterRole
RoleBinding vs ClusterRoleBinding
kubectl auth can-i
debugging in-cluster API access
missing verbs
wrong namespace binding
wrong subject
default ServiceAccount mistakes
least privilege fixes
production RBAC debugging workflow
```

[1]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/?utm_source=chatgpt.com "Configure Liveness, Readiness and Startup Probes"
[2]: https://kubernetes.io/docs/concepts/workloads/pods/probes/?utm_source=chatgpt.com "Liveness, Readiness, and Startup Probes"
