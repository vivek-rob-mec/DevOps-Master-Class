# Lesson 10.8 — Probes, Lifecycle Hooks, Graceful Shutdown, and Production Health Design

In Lesson 10.7, you learned how applications receive configuration through **ConfigMaps** and **Secrets**.

Now we learn how Kubernetes decides whether an application is:

```text id="xvwg8c"
started
alive
ready for traffic
safe to terminate
safe to replace during rollout
```

This lesson is one of the biggest differences between “I can deploy to Kubernetes” and “I can operate production workloads on Kubernetes.”

Kubernetes provides **liveness**, **readiness**, and **startup** probes. A probe is a diagnostic performed periodically by the kubelet on a container; based on the result, Kubernetes can restart unhealthy containers or stop sending traffic to containers that are not ready. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="p3nwia"
10.8.1   Probe mental model
10.8.2   livenessProbe
10.8.3   readinessProbe
10.8.4   startupProbe
10.8.5   HTTP probe
10.8.6   TCP probe
10.8.7   exec probe
10.8.8   initialDelaySeconds
10.8.9   periodSeconds
10.8.10  timeoutSeconds
10.8.11  failureThreshold
10.8.12  successThreshold
10.8.13  readiness vs liveness confusion
10.8.14  bad probe simulations
10.8.15  preStop hook
10.8.16  terminationGracePeriodSeconds
10.8.17  SIGTERM handling
10.8.18  graceful shutdown flow
10.8.19  production health design
10.8.20  demo-node-api production probe pattern
10.8.21  validation script
10.8.22  cleanup script
```

---

# 2. Create Lesson Folder

```bash id="b6gzwr"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.8-probes-lifecycle-graceful-shutdown/{manifests,scripts,notes,runbooks,reports,app}
```

Check:

```bash id="lvxh7r"
tree -L 2 10.8-probes-lifecycle-graceful-shutdown
```

---

# 3. Probe Mental Model

A probe is a health question Kubernetes asks your container.

```text id="5p4v2m"
Kubernetes:
  Are you alive?
  Are you ready?
  Have you started successfully?
```

Your app answers using:

```text id="fz829z"
HTTP endpoint
TCP socket
exec command
gRPC health check
```

In this lesson, we focus mainly on:

```text id="zq2kz2"
HTTP
TCP
exec
```

The official Kubernetes probe docs describe HTTP, TCP, gRPC, and exec probes as supported mechanisms for container health checks. ([Kubernetes][2])

---

# 4. The Three Main Probes

## livenessProbe

Question:

```text id="e2o6jw"
Should this container be restarted?
```

If liveness fails repeatedly:

```text id="hwsom8"
kubelet restarts the container
```

Use liveness for:

```text id="z7zmuw"
deadlock
stuck process
app cannot recover without restart
event loop frozen
internal fatal state
```

Do **not** use liveness for temporary dependency issues.

Bad:

```text id="159z1m"
Database down → liveness fails → app restarts repeatedly
```

Better:

```text id="5zqj2e"
Database down → readiness fails → traffic stops, container stays running
```

---

## readinessProbe

Question:

```text id="q7ibhi"
Should this Pod receive traffic?
```

If readiness fails:

```text id="w9lvb8"
Pod is removed from Service endpoints
traffic stops going to that Pod
container is not restarted just because readiness failed
```

Use readiness for:

```text id="4lhymq"
app warming up
database connection not ready
cache loading
migration check
dependency unavailable
temporary overload
```

Readiness controls traffic eligibility.

---

## startupProbe

Question:

```text id="4gylbs"
Has this slow-starting app finished startup?
```

If startup probe is configured, Kubernetes does not run liveness or readiness probes until the startup probe succeeds. This protects slow-starting applications from being killed too early. ([Kubernetes][3])

Use startup probe for:

```text id="7b98ud"
slow JVM app startup
large model loading
database migration at startup
cache warmup
AI model server loading
large Node.js app initialization
```

---

# 5. The Most Important Confusion

Many beginners think:

```text id="l3hzbt"
readinessProbe and livenessProbe are almost the same.
```

They are not.

```text id="ocq7e7"
livenessProbe:
  restart me if I am broken

readinessProbe:
  stop sending traffic to me if I am not ready

startupProbe:
  wait for me to fully start before judging liveness/readiness
```

Golden rule:

```text id="q7jlkd"
Do not use liveness when you only mean readiness.
```

---

# 6. Create Notes

```bash id="htr51r"
nano 10.8-probes-lifecycle-graceful-shutdown/notes/probes-mental-model.md
```

Paste:

```markdown id="11v6v8"
# Kubernetes Probes Mental Model

## livenessProbe

Question:

Should Kubernetes restart this container?

Use for unrecoverable broken states.

## readinessProbe

Question:

Should this Pod receive traffic?

Use for traffic eligibility.

## startupProbe

Question:

Has this app finished starting?

Use for slow-starting applications.

## Golden Rules

- Liveness failure restarts the container.
- Readiness failure removes Pod from Service endpoints.
- Startup probe disables liveness/readiness until startup succeeds.
- Do not use liveness for temporary dependency issues.
- Do not use readiness as a fake liveness probe.
```

---

# 7. Probe Timing Fields

Common fields:

```yaml id="zp68ja"
initialDelaySeconds: 10
periodSeconds: 5
timeoutSeconds: 2
failureThreshold: 3
successThreshold: 1
```

Meaning:

```text id="xw708o"
initialDelaySeconds:
  wait before first probe after container starts

periodSeconds:
  how often to probe

timeoutSeconds:
  probe timeout

failureThreshold:
  how many failures before Kubernetes considers probe failed

successThreshold:
  how many successes before Kubernetes considers probe successful again
```

Example:

```yaml id="mknhd1"
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

Interpretation:

```text id="69f1rx"
Wait 5 seconds.
Probe every 5 seconds.
Each probe must finish within 2 seconds.
After 3 failures, mark Pod NotReady.
```

---

# 8. Create Probe Demo App as ConfigMap

We will create a tiny Python HTTP app with endpoints:

```text id="hkl18s"
/startup
/ready
/live
/drain
/unready
/unhealthy
```

Create:

```bash id="1iixqt"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-app-configmap.yaml
```

Paste:

```yaml id="qthct6"
apiVersion: v1
kind: ConfigMap
metadata:
  name: probe-demo-app
  namespace: dev
  labels:
    app: probe-demo
data:
  app.py: |
    import http.server
    import socketserver
    import os
    import time
    import threading
    import signal
    import sys

    PORT = int(os.environ.get("PORT", "8080"))
    STARTUP_DELAY = int(os.environ.get("STARTUP_DELAY", "15"))
    READY_DELAY = int(os.environ.get("READY_DELAY", "20"))

    startup_ok = False
    ready = False
    live = True
    draining = False

    def initialize():
        global startup_ok, ready
        print(f"Starting app. Startup delay={STARTUP_DELAY}s, ready delay={READY_DELAY}s", flush=True)
        time.sleep(STARTUP_DELAY)
        startup_ok = True
        print("Startup completed", flush=True)
        time.sleep(max(0, READY_DELAY - STARTUP_DELAY))
        ready = True
        print("App is ready", flush=True)

    def handle_sigterm(signum, frame):
        global ready, draining
        print("SIGTERM received. Marking app unready and draining.", flush=True)
        ready = False
        draining = True
        time.sleep(10)
        print("Graceful shutdown completed.", flush=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_sigterm)

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            global ready, live, startup_ok, draining

            if self.path == "/startup":
                if startup_ok:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"startup ok\n")
                else:
                    self.send_response(503)
                    self.end_headers()
                    self.wfile.write(b"starting\n")

            elif self.path == "/ready":
                if ready and not draining:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ready\n")
                else:
                    self.send_response(503)
                    self.end_headers()
                    self.wfile.write(b"not ready\n")

            elif self.path == "/live":
                if live:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"alive\n")
                else:
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(b"unhealthy\n")

            elif self.path == "/unready":
                ready = False
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"marked unready\n")

            elif self.path == "/ready-now":
                ready = True
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"marked ready\n")

            elif self.path == "/unhealthy":
                live = False
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"marked unhealthy\n")

            elif self.path == "/drain":
                ready = False
                draining = True
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"draining\n")

            else:
                self.send_response(200)
                self.end_headers()
                message = f"probe-demo path={self.path} ready={ready} live={live} startup_ok={startup_ok} draining={draining}\n"
                self.wfile.write(message.encode())

        def log_message(self, format, *args):
            print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args), flush=True)

    threading.Thread(target=initialize, daemon=True).start()

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Serving on port {PORT}", flush=True)
        httpd.serve_forever()
```

Apply:

```bash id="vvdmmg"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-app-configmap.yaml
```

---

# 9. Deployment with Startup, Readiness, and Liveness Probes

Create:

```bash id="h30qdu"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-deployment.yaml
```

Paste:

```yaml id="p9snx7"
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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: probe-demo
        environment: dev
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          env:
            - name: PORT
              value: "8080"
            - name: STARTUP_DELAY
              value: "10"
            - name: READY_DELAY
              value: "15"
          ports:
            - name: http
              containerPort: 8080

          startupProbe:
            httpGet:
              path: /startup
              port: http
            periodSeconds: 2
            timeoutSeconds: 1
            failureThreshold: 15

          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
            successThreshold: 1

          livenessProbe:
            httpGet:
              path: /live
              port: http
            initialDelaySeconds: 0
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3

          lifecycle:
            preStop:
              httpGet:
                path: /drain
                port: http

          volumeMounts:
            - name: app-code
              mountPath: /app
              readOnly: true

      volumes:
        - name: app-code
          configMap:
            name: probe-demo-app
```

Apply:

```bash id="yjbh7d"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-deployment.yaml
```

Watch:

```bash id="keb15v"
kubectl get pods -n dev -l app=probe-demo -w
```

You should see Pods start, become Running, and then become Ready after the startup and readiness delays.

Exit watch:

```text id="tfi61t"
Ctrl + C
```

Check rollout:

```bash id="if04a5"
kubectl rollout status deployment/probe-demo -n dev
```

---

# 10. Create Service

Create:

```bash id="bj6qkp"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-service.yaml
```

Paste:

```yaml id="pc017l"
apiVersion: v1
kind: Service
metadata:
  name: probe-demo
  namespace: dev
  labels:
    app: probe-demo
spec:
  type: ClusterIP
  selector:
    app: probe-demo
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="q6viod"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-service.yaml
```

Check:

```bash id="olfdq6"
kubectl get svc probe-demo -n dev
kubectl get endpoints probe-demo -n dev
```

Important:

```text id="1vv8xl"
Only Ready Pods should appear as traffic-ready backends for the Service.
```

---

# 11. Inspect Probe Status

Describe Pod:

```bash id="xb5ghk"
POD_NAME="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD_NAME" -n dev
```

Look for:

```text id="bu0xlg"
Liveness
Readiness
Startup
Events
Conditions
```

Check Pod conditions:

```bash id="f7ec70"
kubectl get pod "$POD_NAME" -n dev \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```

Expected conditions include:

```text id="edbb0h"
Ready=True
ContainersReady=True
PodScheduled=True
```

Check container restart count:

```bash id="yfn9c6"
kubectl get pod "$POD_NAME" -n dev \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo
```

---

# 12. Test Service

Port-forward:

```bash id="l6jnim"
kubectl port-forward -n dev svc/probe-demo 8085:80
```

Another terminal:

```bash id="qnp2t5"
curl http://127.0.0.1:8085/
curl http://127.0.0.1:8085/startup
curl http://127.0.0.1:8085/ready
curl http://127.0.0.1:8085/live
```

Stop port-forward:

```text id="mpt7fp"
Ctrl + C
```

---

# 13. Readiness Failure Demo

Readiness failure should remove a Pod from Service endpoints but should not restart the container.

Pick one Pod:

```bash id="5s7ndm"
POD_NAME="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl port-forward -n dev pod/"$POD_NAME" 18085:8080
```

Another terminal:

```bash id="zi225e"
curl http://127.0.0.1:18085/unready
```

Wait:

```bash id="m35yx9"
sleep 10
```

Check Pod readiness:

```bash id="6k464s"
kubectl get pods -n dev -l app=probe-demo
kubectl get endpoints probe-demo -n dev
```

Check restart count:

```bash id="n3uc98"
kubectl get pod "$POD_NAME" -n dev \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo
```

Expected:

```text id="vgrjg4"
Pod becomes NotReady.
Service endpoints may exclude it.
Restart count should not increase because readiness failure does not restart the container.
```

Mark it ready again:

```bash id="xejp1c"
curl http://127.0.0.1:18085/ready-now
```

Stop port-forward:

```text id="zo6zr1"
Ctrl + C
```

---

# 14. Liveness Failure Demo

Liveness failure should restart the container.

Start pod port-forward again if needed:

```bash id="lb5x9c"
POD_NAME="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl port-forward -n dev pod/"$POD_NAME" 18085:8080
```

Another terminal:

```bash id="vad2tz"
curl http://127.0.0.1:18085/unhealthy
```

Wait for liveness checks to fail:

```bash id="wz89w0"
kubectl get pod "$POD_NAME" -n dev -w
```

You may see the Pod stay Running but the container restart count increases.

Exit watch:

```text id="x54d2m"
Ctrl + C
```

Check restart count:

```bash id="426w71"
kubectl get pod "$POD_NAME" -n dev \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
echo
```

Describe events:

```bash id="t1fkaf"
kubectl describe pod "$POD_NAME" -n dev
```

Look for liveness probe failure events.

Expected:

```text id="4w88s6"
Container restart count increases.
```

Stop port-forward if it is still running.

---

# 15. Startup Probe Demo

The Deployment already used startup probe.

To observe it clearly, restart the Deployment:

```bash id="t6s7m1"
kubectl rollout restart deployment/probe-demo -n dev
kubectl get pods -n dev -l app=probe-demo -w
```

In another terminal, describe a new Pod quickly:

```bash id="blr2t9"
NEW_POD="$(kubectl get pod -n dev -l app=probe-demo --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')"

kubectl describe pod "$NEW_POD" -n dev
```

Look for startup probe events early in lifecycle.

Important concept:

```text id="vmyiqy"
While startupProbe is still failing, Kubernetes does not run liveness/readiness probes.
Once startupProbe succeeds, liveness/readiness take over.
```

This is why startupProbe is ideal for slow-starting apps. ([Kubernetes][3])

---

# 16. HTTP Probe

You already used HTTP probes:

```yaml id="cfkxvl"
readinessProbe:
  httpGet:
    path: /ready
    port: http
```

Use HTTP probes when:

```text id="4zhdmd"
your app exposes health endpoints
you need app-level readiness
you want to check specific route behavior
```

Best for web APIs:

```text id="advxaj"
Node.js Express
Spring Boot
FastAPI
Go HTTP servers
Nginx
application gateways
```

---

# 17. TCP Probe

TCP probe only checks whether a port accepts a connection.

It does **not** know whether the app is logically healthy.

Create:

```bash id="r2crmn"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/tcp-probe-deployment.yaml
```

Paste:

```yaml id="abacyd"
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
        - name: nginx
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            tcpSocket:
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
```

Apply:

```bash id="qg5ee7"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/tcp-probe-deployment.yaml
```

Check:

```bash id="9kgnph"
kubectl rollout status deployment/tcp-probe-demo -n dev
kubectl get pods -n dev -l app=tcp-probe-demo
```

Use TCP probes for:

```text id="oldq49"
simple port availability
non-HTTP services
databases
TCP proxies
legacy apps without health endpoints
```

Limitation:

```text id="o69e0r"
TCP open does not mean the app is actually healthy.
```

---

# 18. Exec Probe

Exec probe runs a command inside the container.

Create:

```bash id="vr2sti"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/exec-probe-deployment.yaml
```

Paste:

```yaml id="5zss0a"
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
              touch /tmp/healthy
              echo "exec probe demo started"
              sleep 3600
          readinessProbe:
            exec:
              command:
                - test
                - -f
                - /tmp/healthy
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            exec:
              command:
                - test
                - -f
                - /tmp/healthy
            initialDelaySeconds: 10
            periodSeconds: 10
```

Apply:

```bash id="kp68zj"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/exec-probe-deployment.yaml
```

Check:

```bash id="y5nbms"
kubectl rollout status deployment/exec-probe-demo -n dev
kubectl get pods -n dev -l app=exec-probe-demo
```

Break it:

```bash id="p8uec3"
EXEC_POD="$(kubectl get pod -n dev -l app=exec-probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$EXEC_POD" -n dev -- rm -f /tmp/healthy
```

Watch:

```bash id="nsdpha"
kubectl get pod "$EXEC_POD" -n dev -w
```

After enough failures, the container should restart.

Exit watch:

```text id="9kxqds"
Ctrl + C
```

Exec probes are powerful but should be used carefully because they run commands inside the container and can be more expensive or brittle than simple HTTP/TCP probes.

---

# 19. Bad Probe Simulation — Liveness Too Aggressive

This is a very common production mistake.

Create a Deployment where liveness starts too early and kills the app before startup completes.

```bash id="s8e4fe"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml
```

Paste:

```yaml id="fnn2p7"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-liveness-demo
  namespace: dev
  labels:
    app: bad-liveness-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-liveness-demo
  template:
    metadata:
      labels:
        app: bad-liveness-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          env:
            - name: PORT
              value: "8080"
            - name: STARTUP_DELAY
              value: "60"
            - name: READY_DELAY
              value: "70"
          ports:
            - name: http
              containerPort: 8080
          livenessProbe:
            httpGet:
              path: /startup
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 1
            failureThreshold: 2
          volumeMounts:
            - name: app-code
              mountPath: /app
              readOnly: true
      volumes:
        - name: app-code
          configMap:
            name: probe-demo-app
```

Apply:

```bash id="ionasf"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml
```

Watch:

```bash id="jdr5f3"
kubectl get pods -n dev -l app=bad-liveness-demo -w
```

You may see repeated restarts.

Exit:

```text id="zf7x9e"
Ctrl + C
```

Inspect:

```bash id="k64hb1"
BAD_POD="$(kubectl get pod -n dev -l app=bad-liveness-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$BAD_POD" -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

Lesson:

```text id="ntfgwd"
Aggressive liveness probes can create CrashLoopBackOff even when the app only needs more startup time.
```

Fix:

```bash id="fac5lw"
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml
```

Correct pattern:

```text id="zb5cph"
Use startupProbe for slow startup.
Then use livenessProbe after startup succeeds.
```

---

# 20. Bad Probe Simulation — Readiness Wrong Path

Create:

```bash id="am6r7e"
nano 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml
```

Paste:

```yaml id="kcgpy9"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-readiness-demo
  namespace: dev
  labels:
    app: bad-readiness-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-readiness-demo
  template:
    metadata:
      labels:
        app: bad-readiness-demo
    spec:
      containers:
        - name: app
          image: python:3.12-alpine
          command: ["python", "/app/app.py"]
          env:
            - name: PORT
              value: "8080"
            - name: STARTUP_DELAY
              value: "5"
            - name: READY_DELAY
              value: "5"
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /wrong-ready-path
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 2
          volumeMounts:
            - name: app-code
              mountPath: /app
              readOnly: true
      volumes:
        - name: app-code
          configMap:
            name: probe-demo-app
```

Apply:

```bash id="ewsp4i"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml
```

Check:

```bash id="dnge32"
kubectl get pods -n dev -l app=bad-readiness-demo
kubectl describe pod -n dev -l app=bad-readiness-demo
```

Expected:

```text id="q92qk5"
Pod may be Running but not Ready.
```

Lesson:

```text id="tcjowf"
A running container is not always a ready Pod.
```

Delete:

```bash id="vfqkzo"
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml
```

---

# 21. Lifecycle Hooks

Kubernetes supports container lifecycle hooks, including `PostStart` and `PreStop`. `PostStart` runs after a container starts, and `PreStop` runs immediately before a container is terminated due to events such as API deletion, liveness/startup probe failure, preemption, or resource contention. ([Kubernetes][4])

Common hooks:

```text id="i6kt3c"
postStart:
  run logic just after container starts

preStop:
  run logic before container terminates
```

Important:

```text id="1p9tpp"
preStop must complete before Kubernetes sends the TERM signal.
The termination grace period includes preStop time.
```

Use `preStop` for:

```text id="mupnnd"
mark app unready
sleep briefly for endpoint propagation
drain connections
flush buffers
stop accepting new work
```

Do not use `preStop` for:

```text id="9q60wk"
long migrations
slow backups
unbounded cleanup
critical tasks that must never be interrupted
```

---

# 22. Graceful Shutdown Mental Model

When Kubernetes terminates a Pod, the normal flow is:

```text id="7h7c6p"
1. Pod enters Terminating state.
2. Kubernetes starts removing it from endpoints.
3. preStop hook runs if configured.
4. kubelet sends SIGTERM to container process.
5. App should stop accepting new work and finish in-flight work.
6. Kubernetes waits up to terminationGracePeriodSeconds.
7. If still running after grace period, SIGKILL is sent.
```

Kubernetes docs explain that if a `preStop` hook needs longer than the default grace period, you must modify `terminationGracePeriodSeconds` accordingly. ([Kubernetes][5])

Production goal:

```text id="rjxtz0"
No new traffic to terminating Pod.
Existing requests finish.
App exits cleanly before SIGKILL.
```

---

# 23. preStop and Graceful Shutdown Demo

The `probe-demo` Deployment already has:

```yaml id="isvta4"
terminationGracePeriodSeconds: 30

lifecycle:
  preStop:
    httpGet:
      path: /drain
      port: http
```

Delete one Pod and observe:

```bash id="iwhs7t"
POD_NAME="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl delete pod "$POD_NAME" -n dev
```

Immediately watch:

```bash id="u1mby6"
kubectl get pods -n dev -l app=probe-demo -w
```

In another terminal, check logs of the terminating Pod if still available:

```bash id="c6f2t9"
kubectl logs "$POD_NAME" -n dev
```

You should see messages similar to:

```text id="62punc"
SIGTERM received. Marking app unready and draining.
Graceful shutdown completed.
```

Exit watch:

```text id="t2d6le"
Ctrl + C
```

---

# 24. Why Graceful Shutdown Matters

Without graceful shutdown:

```text id="7w9k2b"
rolling deployment starts
old Pod receives SIGTERM
request in progress is killed
user gets 502/connection reset
```

With graceful shutdown:

```text id="8q10zn"
old Pod becomes unready
Service stops sending new traffic
in-flight requests finish
process exits cleanly
new Pods handle traffic
```

This matters for:

```text id="of7u0j"
APIs
payment flows
file uploads
database writes
message consumers
batch workers
WebSocket connections
AI inference requests
```

---

# 25. Production Health Endpoint Design

For your apps, design endpoints intentionally.

## `/live`

Should answer:

```text id="uqkkbn"
Is the process fundamentally alive?
```

Should usually check:

```text id="ee30l5"
process can respond
event loop not completely stuck
critical internal fatal state absent
```

Should usually **not** depend on:

```text id="67t6ya"
database
external API
cache
third-party service
```

Why?

```text id="ez4u3g"
If database goes down, restarting every app Pod usually makes the incident worse.
```

---

## `/ready`

Should answer:

```text id="i87ri1"
Can this Pod safely receive traffic right now?
```

Can check:

```text id="c9x90l"
database connectivity
required config loaded
migration state compatible
cache warmed enough
downstream dependency available
queue connection established
```

If `/ready` fails:

```text id="hgp5d9"
remove from traffic
do not necessarily restart
```

---

## `/startup`

Should answer:

```text id="f8bfez"
Has this container completed initialization?
```

Can check:

```text id="bsy2v3"
large app loaded
model loaded
migration completed
warmup complete
required local files prepared
```

---

# 26. Health Endpoint Anti-Patterns

Bad liveness:

```text id="r6x3q9"
GET /live checks database
```

Result:

```text id="rd7r1v"
Database outage causes all Pods to restart.
Incident worsens.
```

Bad readiness:

```text id="lgcqud"
GET /ready always returns 200
```

Result:

```text id="m5hvud"
Pod receives traffic even when it cannot serve.
```

Bad startup:

```text id="68yo35"
No startupProbe for app that takes 3 minutes to start
```

Result:

```text id="nqd671"
liveness kills app before it finishes starting.
```

Bad timeout:

```text id="eih4k3"
timeoutSeconds: 1 for slow endpoint
```

Result:

```text id="6c6e5d"
False failures during CPU pressure or cold starts.
```

---

# 27. Production Probe Defaults

Good starting point for many HTTP APIs:

```yaml id="6iydo9"
startupProbe:
  httpGet:
    path: /startup
    port: http
  periodSeconds: 5
  failureThreshold: 30

readinessProbe:
  httpGet:
    path: /ready
    port: http
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
  successThreshold: 1

livenessProbe:
  httpGet:
    path: /live
    port: http
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

Meaning:

```text id="r9xri7"
startupProbe:
  app can take up to 150 seconds to start

readinessProbe:
  Pod removed from traffic after about 15 seconds of failed readiness

livenessProbe:
  container restarted after about 30 seconds of failed liveness
```

Adjust based on real startup time, traffic patterns, and incident behavior.

---

# 28. Production Pattern for `demo-node-api`

Your Node.js app already had health-style endpoints in Module 5:

```text id="qoe37r"
/health
/ready
/version
```

For Kubernetes, use:

```text id="h2kpz3"
livenessProbe:
  /health

readinessProbe:
  /ready

startupProbe:
  /health or /ready depending on startup behavior
```

Update `apps/demo-node-api/base/deployment.yaml`.

Open:

```bash id="qok2ql"
nano apps/demo-node-api/base/deployment.yaml
```

Use this improved version:

```yaml id="2wfvr0"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
    environment: dev
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
      environment: dev
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app.kubernetes.io/name: demo-node-api
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: todo-app
        environment: dev
      annotations:
        kubernetes.io/change-cause: "Add probes lifecycle and graceful shutdown configuration"
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: demo-node-api
          image: demo-node-api:0.1.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 3002

          env:
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: NODE_ENV
            - name: PORT
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: APP_PORT
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: demo-node-api-config
                  key: LOG_LEVEL
            - name: MONGO_URI
              valueFrom:
                secretKeyRef:
                  name: demo-node-api-secret
                  key: MONGO_URI
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: demo-node-api-secret
                  key: JWT_SECRET

          startupProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 30

          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
            successThreshold: 1

          livenessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3

          lifecycle:
            preStop:
              exec:
                command:
                  - sh
                  - -c
                  - "sleep 10"
```

Why `maxUnavailable: 0`?

```text id="jxdir1"
During rollout, Kubernetes should not intentionally make any existing Ready Pod unavailable before a replacement is ready.
```

Why `preStop sleep 10`?

```text id="shqlky"
It gives time for endpoint removal and connection draining.
In real apps, combine this with SIGTERM handling in application code.
```

---

# 29. Node.js Graceful Shutdown Pattern

In your Node.js app, production-grade graceful shutdown should look like this:

```javascript id="4jxn4q"
const http = require("http");
const app = require("./app");

const port = process.env.PORT || 3002;

let isReady = false;
let isShuttingDown = false;

app.get("/health", (req, res) => {
  res.status(200).json({ status: "alive" });
});

app.get("/ready", (req, res) => {
  if (isReady && !isShuttingDown) {
    return res.status(200).json({ status: "ready" });
  }

  return res.status(503).json({ status: "not_ready" });
});

const server = http.createServer(app);

server.listen(port, () => {
  isReady = true;
  console.log(`Server listening on port ${port}`);
});

function shutdown(signal) {
  console.log(`${signal} received. Starting graceful shutdown.`);
  isShuttingDown = true;
  isReady = false;

  server.close((error) => {
    if (error) {
      console.error("Error during server close:", error);
      process.exit(1);
    }

    console.log("HTTP server closed.");
    process.exit(0);
  });

  setTimeout(() => {
    console.error("Graceful shutdown timeout. Forcing exit.");
    process.exit(1);
  }, 25000);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
```

Important logic:

```text id="o6rs1x"
SIGTERM received
  ↓
readiness becomes false
  ↓
server stops accepting new connections
  ↓
in-flight requests finish
  ↓
process exits before terminationGracePeriodSeconds
```

---

# 30. Probe Debugging Runbook

Create:

```bash id="twhq0j"
nano 10.8-probes-lifecycle-graceful-shutdown/runbooks/probe-debugging-runbook.md
```

Paste:

````markdown id="oqkzpd"
# Kubernetes Probe Debugging Runbook

## Step 1 — Check Pod Status

```bash
kubectl get pods -n NAMESPACE
````

## Step 2 — Describe Pod

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* Liveness probe failed
* Readiness probe failed
* Startup probe failed
* Restart count
* Events

## Step 3 — Check Logs

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
```

## Step 4 — Check Probe Endpoint Manually

```bash
kubectl port-forward -n NAMESPACE pod/POD_NAME 18080:PORT
curl -i http://127.0.0.1:18080/health
curl -i http://127.0.0.1:18080/ready
```

## Step 5 — Check Service Endpoints

```bash
kubectl get endpoints SERVICE_NAME -n NAMESPACE
```

If readiness fails, the Pod may be removed from endpoints.

## Common Issues

| Symptom                        | Likely Cause             |
| ------------------------------ | ------------------------ |
| CrashLoopBackOff after startup | liveness too aggressive  |
| Running but 0/1 Ready          | readiness failing        |
| rollout stuck                  | readiness never succeeds |
| endpoint missing               | Pod NotReady             |
| restarts increasing            | liveness failing         |
| app killed before startup      | missing startupProbe     |

## Golden Rule

Liveness restarts containers.
Readiness controls traffic.
Startup protects slow startup.

````

---

# 31. Graceful Shutdown Runbook

Create:

```bash id="i4yjbf"
nano 10.8-probes-lifecycle-graceful-shutdown/runbooks/graceful-shutdown-runbook.md
````

Paste:

````markdown id="a3stb0"
# Graceful Shutdown Runbook

## Goal

Terminate Pods without dropping active requests.

## Kubernetes Flow

1. Pod enters Terminating.
2. Pod is removed from Service endpoints.
3. preStop hook runs.
4. SIGTERM is sent to process 1.
5. App stops accepting new requests.
6. App finishes in-flight requests.
7. App exits before terminationGracePeriodSeconds.
8. SIGKILL is sent if it does not exit in time.

## App Requirements

The app should:

- handle SIGTERM
- mark itself unready
- stop accepting new requests
- finish in-flight requests
- close database/message connections
- exit before grace period ends

## Kubernetes Requirements

Deployment should include:

```yaml
terminationGracePeriodSeconds: 30
lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 10"]
````

## Debug Commands

```bash
kubectl delete pod POD_NAME -n NAMESPACE
kubectl get pods -n NAMESPACE -w
kubectl logs POD_NAME -n NAMESPACE
kubectl get endpoints SERVICE_NAME -n NAMESPACE -w
```

## Golden Rule

Graceful shutdown requires both Kubernetes config and application code.

````

---

# 32. Production Health Design Runbook

Create:

```bash id="dbxjtr"
nano 10.8-probes-lifecycle-graceful-shutdown/runbooks/production-health-design.md
````

Paste:

```markdown id="le50jd"
# Production Health Endpoint Design

## /health

Purpose:

- prove process is alive
- should be fast
- should not depend on fragile external systems

Use for:

- livenessProbe

## /ready

Purpose:

- prove Pod can safely receive traffic

May check:

- required config loaded
- database reachable
- cache initialized
- dependency available
- local warmup complete

Use for:

- readinessProbe

## /startup

Purpose:

- prove application startup is complete

May check:

- app initialized
- model loaded
- startup migration done
- cache warmed

Use for:

- startupProbe

## Anti-Patterns

- liveness checks database
- readiness always returns 200
- health endpoint performs slow work
- health endpoint requires external internet
- startupProbe missing for slow-starting app
- probe timeout too small
- failureThreshold too aggressive

## Golden Rule

Health endpoints are part of the production contract of the application.
```

---

# 33. Validation Script

Create:

```bash id="nm1r9a"
nano 10.8-probes-lifecycle-graceful-shutdown/scripts/validate-lesson-10-8.sh
```

Paste:

```bash id="ljbni7"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.8 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get configmap probe-demo-app -n dev >/dev/null
kubectl get deployment probe-demo -n dev >/dev/null
kubectl get service probe-demo -n dev >/dev/null
kubectl get deployment tcp-probe-demo -n dev >/dev/null
kubectl get deployment exec-probe-demo -n dev >/dev/null

kubectl rollout status deployment/probe-demo -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/tcp-probe-demo -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/exec-probe-demo -n dev --timeout=120s >/dev/null

READY_REPLICAS="$(kubectl get deployment probe-demo -n dev -o jsonpath='{.status.readyReplicas}' || echo 0)"
if [ -z "$READY_REPLICAS" ]; then
  READY_REPLICAS=0
fi

if [ "$READY_REPLICAS" -lt 1 ]; then
  echo "ERROR: probe-demo has no ready replicas"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints probe-demo -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: probe-demo service has no endpoints"
  exit 1
fi

POD_NAME="$(kubectl get pod -n dev -l app=probe-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.spec.containers[0].startupProbe}' | grep -q "httpGet"
kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.spec.containers[0].readinessProbe}' | grep -q "httpGet"
kubectl get pod "$POD_NAME" -n dev -o jsonpath='{.spec.containers[0].livenessProbe}' | grep -q "httpGet"

test -f 10.8-probes-lifecycle-graceful-shutdown/notes/probes-mental-model.md
test -f 10.8-probes-lifecycle-graceful-shutdown/runbooks/probe-debugging-runbook.md
test -f 10.8-probes-lifecycle-graceful-shutdown/runbooks/graceful-shutdown-runbook.md
test -f 10.8-probes-lifecycle-graceful-shutdown/runbooks/production-health-design.md
test -f apps/demo-node-api/base/deployment.yaml

echo "Ready replicas: $READY_REPLICAS"
echo "Endpoints: $ENDPOINTS"
echo "Lesson 10.8 validation passed."
```

Make executable:

```bash id="dzqlpl"
chmod +x 10.8-probes-lifecycle-graceful-shutdown/scripts/validate-lesson-10-8.sh
```

Run:

```bash id="vdkttn"
./10.8-probes-lifecycle-graceful-shutdown/scripts/validate-lesson-10-8.sh
```

---

# 34. Cleanup Script

Create:

```bash id="bz2pod"
nano 10.8-probes-lifecycle-graceful-shutdown/scripts/cleanup-lesson-10-8.sh
```

Paste:

```bash id="kv4bzq"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.8 ====="

kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/exec-probe-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/tcp-probe-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-service.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-app-configmap.yaml --ignore-not-found=true

echo "Lesson 10.8 resources cleaned."
echo "Namespace dev and cluster kept for next lessons."
```

Make executable:

```bash id="w9ddai"
chmod +x 10.8-probes-lifecycle-graceful-shutdown/scripts/cleanup-lesson-10-8.sh
```

Run only if you want cleanup:

```bash id="xcoamm"
./10.8-probes-lifecycle-graceful-shutdown/scripts/cleanup-lesson-10-8.sh
```

---

# 35. Practical Lab Summary

Run the main lab:

```bash id="f29jqx"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-app-configmap.yaml
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-deployment.yaml
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/probe-demo-service.yaml
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/tcp-probe-deployment.yaml
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/exec-probe-deployment.yaml

kubectl rollout status deployment/probe-demo -n dev
kubectl get pods -n dev -l app=probe-demo
kubectl describe pod -n dev -l app=probe-demo

./10.8-probes-lifecycle-graceful-shutdown/scripts/validate-lesson-10-8.sh
```

Run bad simulations only when you want practice:

```bash id="q84pkd"
kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml
kubectl get pods -n dev -l app=bad-liveness-demo -w
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-liveness-deployment.yaml

kubectl apply -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml
kubectl describe pod -n dev -l app=bad-readiness-demo
kubectl delete -f 10.8-probes-lifecycle-graceful-shutdown/manifests/bad-readiness-deployment.yaml
```

---

# 36. Common Myths and Misconceptions

## Myth 1: Liveness and readiness are the same

Wrong.

```text id="yb5z1e"
liveness:
  restart container

readiness:
  remove from traffic
```

---

## Myth 2: Liveness should check database

Usually wrong.

```text id="cdxbrv"
Database outage should not cause every app Pod to restart repeatedly.
```

Put dependency checks in readiness, not liveness.

---

## Myth 3: Running means Ready

Wrong.

```text id="pbyami"
A Pod can be Running but not Ready.
```

Example:

```text id="ta9byn"
app process is running
but readiness probe fails
Service does not send traffic
```

---

## Myth 4: Startup probe is optional for slow apps

For slow apps, missing startup probe can cause restart loops.

```text id="aixobq"
slow startup + aggressive liveness = CrashLoopBackOff
```

---

## Myth 5: preStop alone guarantees graceful shutdown

Wrong.

Graceful shutdown needs both:

```text id="79gz2s"
Kubernetes lifecycle config
application SIGTERM handling
```

---

## Myth 6: Kubernetes instantly stops sending traffic when readiness fails

Endpoint changes are fast, but not magical. Proxies, load balancers, clients, keep-alive connections, and propagation delay matter.

Use:

```text id="ing1kh"
readinessProbe
preStop
terminationGracePeriodSeconds
application-level graceful shutdown
connection draining
```

---

# 37. Production Rules

```text id="q77tst"
Every production HTTP app should have readiness and liveness probes.
Slow-starting apps should have startupProbe.
Liveness should not depend on fragile external dependencies.
Readiness may check dependencies required to serve traffic.
Startup probe protects slow startup from premature liveness restarts.
Use named ports in probes.
Set realistic timeouts and failure thresholds.
Use maxUnavailable: 0 for safer rollouts when capacity allows.
Use preStop and terminationGracePeriodSeconds for graceful shutdown.
App code must handle SIGTERM.
Do not log secrets in health endpoints.
Do not make health endpoints slow or expensive.
```

---

# 38. Interview Explanation

Use this:

```text id="8kckiy"
Kubernetes probes let the kubelet monitor container health. A liveness probe answers whether the container should be restarted. A readiness probe answers whether the Pod should receive traffic through Services. A startup probe gives slow-starting applications time to initialize before liveness and readiness probes begin.

For production APIs, I usually use `/health` for liveness, `/ready` for readiness, and a startup probe when initialization is slow. I avoid putting fragile external dependencies in liveness checks because that can cause restart storms during dependency outages. I combine probes with graceful shutdown using readiness, preStop hooks, terminationGracePeriodSeconds, and application SIGTERM handling.
```

Resume version:

```text id="jcofmt"
Implemented Kubernetes production health checks using startup, readiness, and liveness probes, HTTP/TCP/exec probe patterns, bad probe simulations, preStop lifecycle hooks, graceful shutdown behavior, and production probe manifests for demo-node-api.
```

---

# 39. Today’s Core Rules

```text id="o74pwz"
Liveness answers: should Kubernetes restart this container?
Readiness answers: should this Pod receive traffic?
Startup answers: has the app finished starting?
Startup probe disables liveness/readiness until it succeeds.
HTTP probes are best for app-level web health.
TCP probes only check port availability.
Exec probes run commands inside containers.
Readiness failure does not restart the container.
Liveness failure restarts the container.
Aggressive liveness can cause CrashLoopBackOff.
preStop runs before termination.
terminationGracePeriodSeconds must be long enough for graceful shutdown.
App code must handle SIGTERM.
```

---

# 40. Commit Lesson 10.8

From repo root:

```bash id="lis2pv"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes probes lifecycle hooks and graceful shutdown lesson"

git push
```

---

# Next Lesson

```text id="wqjkyk"
Lesson 10.9 — Resource Requests, Limits, QoS Classes, Scheduling, and Capacity Planning
```

We will cover:

```text id="h84kk6"
CPU requests
memory requests
CPU limits
memory limits
millicores
Mi vs MB
QoS classes: Guaranteed, Burstable, BestEffort
OOMKilled
CPU throttling
scheduler resource decisions
node allocatable
kubectl top
metrics-server
capacity planning
production resource policy for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/workloads/pods/probes/?utm_source=chatgpt.com "Liveness, Readiness, and Startup Probes"
[2]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/?utm_source=chatgpt.com "Configure Liveness, Readiness and Startup Probes"
[3]: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/?utm_source=chatgpt.com "Pod Lifecycle"
[4]: https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/?utm_source=chatgpt.com "Container Lifecycle Hooks"
[5]: https://v1-32.docs.kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/?utm_source=chatgpt.com "Pod Lifecycle"
