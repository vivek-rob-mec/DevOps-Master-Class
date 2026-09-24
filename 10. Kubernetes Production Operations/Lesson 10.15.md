# Lesson 10.15 — Kubernetes Observability: Events, Logs, Metrics, Prometheus, Grafana, Loki, and Production Debugging

In Lesson 10.14, you learned **HPA, VPA concepts, Cluster Autoscaler concepts, PodDisruptionBudgets, and safe scaling**.

Now we move into observability.

This is one of the most important production Kubernetes skills because real DevOps work is not only:

```text
deploy application
```

It is also:

```text
prove it is healthy
debug when it breaks
understand why it is slow
know what changed
know which Pod failed
know whether users are affected
know whether the cluster or app is the problem
```

Kubernetes gives you basic inspection tools like events, `describe`, logs, and resource metrics. For real production, you usually add a full observability stack such as Prometheus for metrics, Grafana for dashboards, and Loki or another logging backend for centralized logs. Kubernetes itself notes that cluster-level logging should have storage and lifecycle independent of nodes, Pods, and containers because container/runtime logs alone are not enough for a complete logging solution. ([Kubernetes][1])

---

# 1. What We Will Cover

```text
10.15.1   Observability mental model
10.15.2   Events vs logs vs metrics vs traces
10.15.3   kubectl get events
10.15.4   kubectl describe
10.15.5   kubectl logs
10.15.6   previous container logs
10.15.7   multi-container logs
10.15.8   structured JSON logs
10.15.9   metrics-server vs Prometheus
10.15.10  Prometheus mental model
10.15.11  Prometheus metric types
10.15.12  Grafana dashboard mental model
10.15.13  Loki log aggregation mental model
10.15.14  Promtail / Alloy note
10.15.15  RED metrics
10.15.16  USE metrics
10.15.17  Golden signals
10.15.18  Production debugging workflow
10.15.19  demo-node-api observability policy
10.15.20  Validation script
10.15.21  Cleanup script
```

---

# 2. Create Lesson Folder

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.15-kubernetes-observability/{manifests,scripts,notes,runbooks,reports,app}
```

Check:

```bash
tree -L 2 10.15-kubernetes-observability
```

---

# 3. Observability Mental Model

Observability answers:

```text
What is happening?
Why is it happening?
How bad is it?
Who is affected?
What changed?
What should I do next?
```

The four major signals:

```text
Events:
  Kubernetes object lifecycle messages

Logs:
  application and system text/structured output

Metrics:
  numeric time-series measurements

Traces:
  request journey across services
```

Simple production debugging map:

```text
User reports issue
  ↓
Check Ingress / Service / Pod health
  ↓
Check events
  ↓
Check logs
  ↓
Check metrics
  ↓
Check recent deployments/config changes
  ↓
Identify app, cluster, dependency, or traffic issue
```

Important rule:

```text
Events tell you what Kubernetes did.
Logs tell you what the app said.
Metrics tell you how the system behaved over time.
Traces tell you where a request spent time.
```

---

# 4. Events vs Logs vs Metrics

| Signal  | Best For                       | Example                                    |
| ------- | ------------------------------ | ------------------------------------------ |
| Events  | Kubernetes lifecycle/debugging | ImagePullBackOff, FailedScheduling         |
| Logs    | Application behavior           | request failed, exception, startup message |
| Metrics | Trends and alerting            | CPU, memory, latency, error rate           |
| Traces  | Request path debugging         | API → DB → cache latency                   |

Do not confuse them.

Example:

```text
Pod is Pending
  events explain scheduling failure

App returns 500
  logs explain exception

Latency increased
  metrics show duration and saturation

One request is slow
  trace shows where time was spent
```

---

# 5. Create Notes

```bash
nano 10.15-kubernetes-observability/notes/observability-mental-model.md
```

Paste:

```markdown
# Kubernetes Observability Mental Model

## Four Signals

### Events

Kubernetes object lifecycle and scheduling messages.

### Logs

Application and system output.

### Metrics

Numeric time-series data.

### Traces

Request path across services.

## Debugging Rule

Events explain Kubernetes behavior.
Logs explain application behavior.
Metrics explain trends and impact.
Traces explain request flow.

## Golden Rule

Do not debug production using only logs.
Use events, logs, metrics, and recent-change context together.
```

---

# 6. Kubernetes Events

Kubernetes events are extremely useful when Pods are not scheduling, images are not pulling, probes are failing, PVCs are not mounting, or nodes are under pressure.

Useful commands:

```bash
kubectl get events -n dev

kubectl get events -n dev --sort-by=.lastTimestamp

kubectl get events -A --sort-by=.lastTimestamp

kubectl get events -n dev --field-selector involvedObject.kind=Pod
```

If your kubectl supports the newer events command:

```bash
kubectl events -n dev
kubectl events -A
```

Most reliable command:

```bash
kubectl get events -A --sort-by=.lastTimestamp
```

Events are also visible through `kubectl describe`, which prints detailed resource information including related events. ([Kubernetes][2])

---

# 7. Create Events Demo — Bad Image

Create:

```bash
nano 10.15-kubernetes-observability/manifests/bad-image-demo.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-image-observability-demo
  namespace: dev
  labels:
    app: bad-image-observability-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-image-observability-demo
  template:
    metadata:
      labels:
        app: bad-image-observability-demo
    spec:
      containers:
        - name: app
          image: nginx:this-tag-does-not-exist
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
kubectl apply -f 10.15-kubernetes-observability/manifests/bad-image-demo.yaml
```

Check:

```bash
kubectl get pods -n dev -l app=bad-image-observability-demo

kubectl describe pod -n dev -l app=bad-image-observability-demo

kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text
ImagePullBackOff
ErrImagePull
failed to pull image
```

Clean:

```bash
kubectl delete -f 10.15-kubernetes-observability/manifests/bad-image-demo.yaml
```

Lesson:

```text
For image pull problems, events are usually more useful than application logs because the app never started.
```

---

# 8. kubectl describe

`kubectl describe` is your first deep inspection command.

Use it for:

```bash
kubectl describe pod POD_NAME -n dev
kubectl describe deployment DEPLOYMENT_NAME -n dev
kubectl describe service SERVICE_NAME -n dev
kubectl describe ingress INGRESS_NAME -n dev
kubectl describe pvc PVC_NAME -n dev
kubectl describe node NODE_NAME
```

It shows:

```text
labels
annotations
selectors
containers
images
ports
env references
volumes
mounts
conditions
events
```

For Pod issues, always run:

```bash
kubectl describe pod POD_NAME -n dev
```

before guessing.

---

# 9. Kubernetes Logs

Use logs when the container started and the application produced output.

Basic:

```bash
kubectl logs POD_NAME -n dev
```

Follow:

```bash
kubectl logs POD_NAME -n dev -f
```

Deployment logs:

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n dev
```

Label selector logs:

```bash
kubectl logs -n dev -l app=my-app
```

Multi-container Pod:

```bash
kubectl logs POD_NAME -n dev -c CONTAINER_NAME
```

Previous crashed container:

```bash
kubectl logs POD_NAME -n dev --previous
```

The `kubectl logs` command prints logs for a container in a Pod; it supports following logs, previous container logs, selecting containers, and using resource names such as Deployment or Pod. ([Kubernetes][3])

---

# 10. Create Observable Demo App

We will create a small Python app that exposes:

```text
/
 /health
 /ready
 /metrics
 /simulate-error
 /slow
 /crash
```

It will print structured JSON logs and expose basic Prometheus-style metrics.

Create:

```bash
nano 10.15-kubernetes-observability/manifests/observable-app-configmap.yaml
```

Paste:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: observable-app-code
  namespace: dev
  labels:
    app: observable-app
data:
  app.py: |
    import http.server
    import socketserver
    import json
    import os
    import sys
    import time
    import traceback
    from datetime import datetime

    PORT = int(os.environ.get("PORT", "8080"))
    APP_NAME = os.environ.get("APP_NAME", "observable-app")
    APP_ENV = os.environ.get("APP_ENV", "dev")
    POD_NAME = os.environ.get("POD_NAME", "unknown")
    POD_NAMESPACE = os.environ.get("POD_NAMESPACE", "unknown")

    request_count = 0
    error_count = 0
    slow_count = 0
    start_time = time.time()

    def log(level, message, **fields):
        record = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": level,
            "app": APP_NAME,
            "environment": APP_ENV,
            "pod": POD_NAME,
            "namespace": POD_NAMESPACE,
            "message": message,
            **fields
        }
        print(json.dumps(record), flush=True)

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            global request_count, error_count, slow_count

            start = time.time()
            request_count += 1

            try:
                if self.path == "/health":
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"alive\n")
                    status = 200

                elif self.path == "/ready":
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ready\n")
                    status = 200

                elif self.path == "/simulate-error":
                    error_count += 1
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(b"simulated error\n")
                    status = 500

                elif self.path == "/slow":
                    slow_count += 1
                    time.sleep(2)
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"slow response\n")
                    status = 200

                elif self.path == "/crash":
                    log("error", "crash endpoint called, exiting intentionally")
                    sys.exit(1)

                elif self.path == "/metrics":
                    uptime = int(time.time() - start_time)
                    metrics = f"""# HELP observable_app_requests_total Total HTTP requests.
    # TYPE observable_app_requests_total counter
    observable_app_requests_total{{app="{APP_NAME}",environment="{APP_ENV}"}} {request_count}
    # HELP observable_app_errors_total Total simulated HTTP errors.
    # TYPE observable_app_errors_total counter
    observable_app_errors_total{{app="{APP_NAME}",environment="{APP_ENV}"}} {error_count}
    # HELP observable_app_slow_requests_total Total slow requests.
    # TYPE observable_app_slow_requests_total counter
    observable_app_slow_requests_total{{app="{APP_NAME}",environment="{APP_ENV}"}} {slow_count}
    # HELP observable_app_uptime_seconds App uptime in seconds.
    # TYPE observable_app_uptime_seconds gauge
    observable_app_uptime_seconds{{app="{APP_NAME}",environment="{APP_ENV}"}} {uptime}
    """
                    self.send_response(200)
                    self.send_header("Content-Type", "text/plain; version=0.0.4")
                    self.end_headers()
                    self.wfile.write(metrics.encode())
                    status = 200

                else:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(f"hello from {APP_NAME} on {POD_NAME}\n".encode())
                    status = 200

                duration_ms = int((time.time() - start) * 1000)
                log("info", "request completed", method="GET", path=self.path, status=status, duration_ms=duration_ms)

            except SystemExit:
                raise
            except Exception as exc:
                error_count += 1
                duration_ms = int((time.time() - start) * 1000)
                log("error", "request failed", path=self.path, error=str(exc), traceback=traceback.format_exc(), duration_ms=duration_ms)
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b"internal error\n")

        def log_message(self, format, *args):
            return

    log("info", "starting observable app", port=PORT)

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        log("info", "server listening", port=PORT)
        httpd.serve_forever()
```

Apply:

```bash
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-configmap.yaml
```

---

# 11. Create Observable App Deployment

Create:

```bash
nano 10.15-kubernetes-observability/manifests/observable-app-deployment.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observable-app
  namespace: dev
  labels:
    app: observable-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: observable-app
  template:
    metadata:
      labels:
        app: observable-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/metrics"
        prometheus.io/port: "8080"
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
            - name: APP_NAME
              value: "observable-app"
            - name: APP_ENV
              value: "dev"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
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
          volumeMounts:
            - name: app-code
              mountPath: /app
              readOnly: true
      volumes:
        - name: app-code
          configMap:
            name: observable-app-code
```

Apply:

```bash
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-deployment.yaml
```

Check:

```bash
kubectl rollout status deployment/observable-app -n dev
kubectl get pods -n dev -l app=observable-app -o wide
```

---

# 12. Create Observable App Service

Create:

```bash
nano 10.15-kubernetes-observability/manifests/observable-app-service.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: observable-app
  namespace: dev
  labels:
    app: observable-app
spec:
  type: ClusterIP
  selector:
    app: observable-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-service.yaml
```

Check:

```bash
kubectl get svc observable-app -n dev
kubectl get endpoints observable-app -n dev
```

---

# 13. Test App and Logs

Port-forward:

```bash
kubectl port-forward -n dev svc/observable-app 8087:80
```

Another terminal:

```bash
curl http://127.0.0.1:8087/
curl http://127.0.0.1:8087/health
curl http://127.0.0.1:8087/ready
curl http://127.0.0.1:8087/metrics
curl http://127.0.0.1:8087/simulate-error
curl http://127.0.0.1:8087/slow
```

Check logs:

```bash
kubectl logs deployment/observable-app -n dev
```

Follow logs:

```bash
kubectl logs deployment/observable-app -n dev -f
```

You should see JSON logs like:

```json
{"timestamp":"...","level":"info","app":"observable-app","environment":"dev","pod":"observable-app-...","namespace":"dev","message":"request completed","method":"GET","path":"/health","status":200,"duration_ms":0}
```

Stop port-forward:

```text
Ctrl + C
```

---

# 14. Structured Logs

Structured logs are logs with consistent fields.

Bad log:

```text
Something failed
```

Better log:

```json
{
  "timestamp": "2026-07-15T10:30:00Z",
  "level": "error",
  "service": "demo-node-api",
  "request_id": "abc-123",
  "method": "GET",
  "path": "/api/get-todo",
  "status": 500,
  "duration_ms": 42,
  "error": "MongoTimeoutError"
}
```

Why structured logs matter:

```text
easy to search
easy to filter
easy to parse
easy to alert
easy to correlate with metrics/traces
```

Production fields to include:

```text
timestamp
level
service
environment
pod
namespace
request_id
trace_id
method
path
status
duration_ms
error
user_id_hash if appropriate
```

Do not log:

```text
passwords
tokens
JWTs
API keys
full credit card numbers
private keys
sensitive personal data
```

---

# 15. Previous Container Logs

Crash the app intentionally:

```bash
POD_NAME="$(kubectl get pod -n dev -l app=observable-app -o jsonpath='{.items[0].metadata.name}')"

kubectl port-forward -n dev pod/"$POD_NAME" 18087:8080
```

Another terminal:

```bash
curl http://127.0.0.1:18087/crash || true
```

Watch:

```bash
kubectl get pod "$POD_NAME" -n dev -w
```

Exit:

```text
Ctrl + C
```

Check current logs:

```bash
kubectl logs "$POD_NAME" -n dev
```

Check previous crashed container logs:

```bash
kubectl logs "$POD_NAME" -n dev --previous
```

This is critical for `CrashLoopBackOff`.

Production rule:

```text
If a container restarted, always check --previous logs.
```

---

# 16. Multi-Container Logs Demo

Create:

```bash
nano 10.15-kubernetes-observability/manifests/multi-container-logs-pod.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-logs
  namespace: dev
  labels:
    app: multi-container-logs
spec:
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          i=0
          while true; do
            echo "{\"container\":\"app\",\"message\":\"app log line\",\"count\":$i}"
            i=$((i+1))
            sleep 5
          done

    - name: sidecar
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          i=0
          while true; do
            echo "{\"container\":\"sidecar\",\"message\":\"sidecar log line\",\"count\":$i}"
            i=$((i+1))
            sleep 7
          done
```

Apply:

```bash
kubectl apply -f 10.15-kubernetes-observability/manifests/multi-container-logs-pod.yaml
```

Check:

```bash
kubectl get pod multi-container-logs -n dev
```

Logs from app container:

```bash
kubectl logs multi-container-logs -n dev -c app
```

Logs from sidecar container:

```bash
kubectl logs multi-container-logs -n dev -c sidecar
```

Clean later:

```bash
kubectl delete -f 10.15-kubernetes-observability/manifests/multi-container-logs-pod.yaml
```

---

# 17. Metrics Server vs Prometheus

You already installed metrics-server in Lesson 10.14.

Metrics-server is for recent resource metrics:

```text
CPU
memory
```

Used by:

```text
kubectl top
HPA
VPA
```

Kubernetes states that the Metrics API provides the minimum CPU and memory metrics needed for autoscaling, while richer monitoring should be provided by another metrics pipeline such as a custom metrics pipeline. ([Kubernetes][4])

Prometheus is for richer time-series monitoring:

```text
HTTP requests
error rate
latency
queue depth
custom app metrics
Kubernetes object metrics
node metrics
container metrics
SLO dashboards
alerts
```

Simple comparison:

| Tool           | Purpose                               |
| -------------- | ------------------------------------- |
| metrics-server | recent CPU/memory for autoscaling     |
| Prometheus     | full time-series metrics and alerting |
| Grafana        | dashboards and visualization          |
| Loki           | centralized logs                      |
| Tempo/Jaeger   | traces                                |

`kubectl top` fetches CPU and memory usage from Metrics Server, and Metrics Server must be installed and running for the command to work. ([Kubernetes][5])

---

# 18. Prometheus Mental Model

Prometheus works like this:

```text
Targets expose /metrics
  ↓
Prometheus scrapes targets
  ↓
Prometheus stores time-series data
  ↓
PromQL queries analyze data
  ↓
Grafana visualizes data
  ↓
Alertmanager sends alerts
```

Example metric:

```text
http_requests_total{method="GET",status="200",service="demo-node-api"} 12345
```

Prometheus data is stored as time series identified by metric name and labels. Prometheus recommends metric names that describe the measured feature, such as `http_requests_total` for total HTTP requests. ([Prometheus][6])

---

# 19. Prometheus Metric Types

Prometheus instrumentation libraries define four core metric types:

```text
Counter
Gauge
Histogram
Summary
```

Prometheus documents these four metric types and explains that counters are values that only increase or reset, gauges can go up and down, and histograms/summaries are used for distributions such as request duration. ([Prometheus][7])

## Counter

Use for values that only increase:

```text
requests_total
errors_total
jobs_processed_total
retries_total
```

Example:

```text
observable_app_requests_total 100
```

## Gauge

Use for values that go up and down:

```text
memory_usage_bytes
queue_depth
active_connections
current_replicas
```

Example:

```text
observable_app_uptime_seconds 360
```

## Histogram

Use for distributions:

```text
request_duration_seconds
response_size_bytes
queue_wait_seconds
```

Common query:

```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Summary

Also used for distributions, but less flexible for aggregation across instances than histograms.

Production rule:

```text
Use counters for totals.
Use gauges for current values.
Use histograms for latency and size distributions.
```

---

# 20. Install kube-prometheus-stack — Optional Lab

This is heavier than previous labs, but very useful.

It installs:

```text
Prometheus
Grafana
Alertmanager
kube-state-metrics
node-exporter
Prometheus Operator
```

Add repo:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Create namespace:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
```

Install:

```bash
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --set grafana.service.type=ClusterIP
```

Wait:

```bash
kubectl get pods -n monitoring
```

Check:

```bash
helm list -n monitoring
kubectl get svc -n monitoring
```

Port-forward Grafana:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open in browser:

```text
http://127.0.0.1:3000
```

Get admin password:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

Default user:

```text
admin
```

Port-forward Prometheus:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open:

```text
http://127.0.0.1:9090
```

Production note:

```text
For production, do not expose Grafana/Prometheus casually.
Use authentication, authorization, TLS, NetworkPolicy, and controlled access.
```

---

# 21. Prometheus Queries to Try

In Prometheus UI:

```promql
up
```

Node CPU-related metrics:

```promql
rate(node_cpu_seconds_total[5m])
```

Pod count from kube-state-metrics:

```promql
kube_pod_info
```

Container CPU:

```promql
rate(container_cpu_usage_seconds_total[5m])
```

Container memory:

```promql
container_memory_working_set_bytes
```

Your app metric if scraped:

```promql
observable_app_requests_total
```

If your app metric is not found, do not worry yet. ServiceMonitor setup depends on the Prometheus Operator configuration. We will add a ServiceMonitor next.

---

# 22. Add ServiceMonitor for Observable App

The kube-prometheus-stack uses Prometheus Operator CRDs. One common way to tell Prometheus to scrape a Service is a `ServiceMonitor`.

Create:

```bash
nano 10.15-kubernetes-observability/manifests/observable-app-servicemonitor.yaml
```

Paste:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: observable-app
  namespace: dev
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: observable-app
  namespaceSelector:
    matchNames:
      - dev
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

Apply only if kube-prometheus-stack is installed:

```bash
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-servicemonitor.yaml
```

Check:

```bash
kubectl get servicemonitor -n dev
```

Generate traffic:

```bash
kubectl run observable-load \
  -n dev \
  --image=busybox:1.36 \
  --restart=Never \
  -- sh -c "while true; do wget -q -O- http://observable-app.dev.svc.cluster.local/; wget -q -O- http://observable-app.dev.svc.cluster.local/simulate-error || true; sleep 2; done"
```

Query after a minute:

```promql
observable_app_requests_total
observable_app_errors_total
rate(observable_app_requests_total[1m])
rate(observable_app_errors_total[1m])
```

Clean load:

```bash
kubectl delete pod observable-load -n dev --ignore-not-found=true
```

---

# 23. Grafana Dashboard Mental Model

Grafana is for visualization.

Dashboard examples:

```text
Kubernetes cluster overview
Node CPU/memory/disk/network
Namespace workload overview
Deployment health
Pod restart dashboard
Ingress request rate and latency
Application RED metrics
Database health
HPA scaling dashboard
```

Good dashboard layout:

```text
Top:
  service health summary

Middle:
  request rate, errors, latency

Bottom:
  CPU, memory, restarts, saturation, logs link
```

A dashboard should answer:

```text
Is the service healthy?
Are users affected?
Is the problem app, cluster, or dependency?
What changed recently?
```

---

# 24. RED Metrics

RED is useful for request-driven services.

```text
R = Rate
E = Errors
D = Duration
```

For `demo-node-api`:

```text
Rate:
  requests per second

Errors:
  4xx/5xx rate

Duration:
  p50/p95/p99 latency
```

Example PromQL:

```promql
rate(http_requests_total[5m])
```

```promql
rate(http_requests_total{status=~"5.."}[5m])
```

```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

Use RED for:

```text
APIs
frontends
Ingress
HTTP services
RPC services
```

---

# 25. USE Metrics

USE is useful for infrastructure resources.

```text
U = Utilization
S = Saturation
E = Errors
```

For node CPU:

```text
Utilization:
  CPU usage

Saturation:
  CPU run queue / throttling

Errors:
  CPU-related errors usually indirect
```

For disk:

```text
Utilization:
  disk busy percentage

Saturation:
  disk queue latency

Errors:
  read/write errors
```

For Kubernetes node:

```text
CPU utilization
memory utilization
disk pressure
network errors
Pod capacity
```

Use USE for:

```text
nodes
disks
network
container runtime
databases
queues
```

---

# 26. Golden Signals

Golden signals:

```text
latency
traffic
errors
saturation
```

Map to Kubernetes:

```text
Latency:
  request duration

Traffic:
  request rate

Errors:
  HTTP 5xx, failed jobs, failed probes

Saturation:
  CPU, memory, disk, queue depth, connection pool usage
```

Production rule:

```text
Every production service should have dashboards and alerts for latency, traffic, errors, and saturation.
```

---

# 27. Loki Mental Model

Loki is a log aggregation system from Grafana Labs.

Simple flow:

```text
Pod writes logs to stdout/stderr
  ↓
node log collector reads container logs
  ↓
collector sends logs to Loki
  ↓
Grafana queries logs using LogQL
```

Loki is designed as a horizontally scalable, distributed log system with multiple components in microservices mode, though it can also be deployed in simpler modes for smaller setups. ([Grafana Labs][8])

Important difference from Elasticsearch-style systems:

```text
Loki indexes labels, not full log text by default.
```

Good Loki labels:

```text
namespace
pod
container
app
environment
cluster
```

Bad Loki labels:

```text
request_id
user_id
trace_id
timestamp
unique error message
```

Why?

```text
High-cardinality labels make the logging system expensive and unstable.
```

---

# 28. Promtail / Grafana Alloy Note

Many older tutorials use Promtail to ship logs to Loki.

Important current note: Grafana documentation states that **Promtail reached end of life on March 2, 2026**, and future development has moved to Grafana Alloy. ([Grafana Labs][9])

So for new learning:

```text
Understand Promtail if you see it in older clusters.
Prefer Grafana Alloy or another supported collector for new Loki setups.
```

Practical DevOps reality:

```text
Old clusters:
  may still use Promtail

New clusters:
  should evaluate Grafana Alloy, Fluent Bit, OpenTelemetry Collector, or cloud-native log collectors
```

---

# 29. Install Loki Stack — Optional Concept Lab

For current production-grade Loki deployments, check Grafana’s latest Helm chart docs before deploying. The ecosystem changes, and the Promtail-to-Alloy migration matters. For this lesson, keep Loki as a concept unless you are ready for a heavier logging stack.

Basic conceptual install path:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Then evaluate current charts:

```bash
helm search repo grafana/loki
helm search repo grafana/alloy
```

Production note:

```text
Do not blindly install old loki-stack tutorials.
Check current Grafana Loki and Alloy documentation.
```

---

# 30. Kubernetes System Logs

Application logs are not enough.

You may also need:

```text
kubelet logs
container runtime logs
control plane logs
ingress controller logs
CNI logs
CoreDNS logs
storage driver logs
```

Kubernetes system component logs record cluster events and can be useful for debugging component behavior such as pod state changes, controller actions, scheduler decisions, and HTTP access logs. ([Kubernetes][10])

Examples:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns

kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

For kind node-level logs, you can inspect Docker container logs:

```bash
docker ps | grep devops-k8s

docker logs devops-k8s-control-plane
```

---

# 31. kube-state-metrics Concept

`kube-state-metrics` exposes Kubernetes object state as metrics.

Examples:

```text
Deployment desired replicas
Deployment available replicas
Pod phase
Pod restart count
PVC status
HPA status
Node conditions
```

Why it matters:

```text
metrics-server tells current CPU/memory usage
kube-state-metrics tells Kubernetes object state
```

Example alert ideas:

```text
Deployment replicas unavailable
Pod stuck Pending
PVC stuck Pending
Pod restarts increasing
HPA maxed out
Node NotReady
```

kube-prometheus-stack usually includes kube-state-metrics.

---

# 32. Production Debugging Workflow

When something breaks, use this order.

## Step 1 — Confirm Scope

```bash
kubectl get namespaces
kubectl get pods -A | grep -v Running
kubectl get nodes
```

Ask:

```text
One Pod?
One Deployment?
One namespace?
Whole cluster?
One node?
One dependency?
```

## Step 2 — Check Recent Events

```bash
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

## Step 3 — Check Workload

```bash
kubectl get deploy,rs,pods,svc,ingress -n dev
kubectl describe deployment observable-app -n dev
kubectl describe pod POD_NAME -n dev
```

## Step 4 — Check Logs

```bash
kubectl logs deployment/observable-app -n dev --tail=100
kubectl logs POD_NAME -n dev --previous
```

## Step 5 — Check Metrics

```bash
kubectl top pods -n dev
kubectl top nodes
```

Prometheus:

```promql
up
rate(container_cpu_usage_seconds_total[5m])
container_memory_working_set_bytes
kube_pod_container_status_restarts_total
```

## Step 6 — Check Traffic Path

```bash
kubectl get ingress -n dev
kubectl describe ingress observable-app -n dev

kubectl get svc observable-app -n dev
kubectl get endpoints observable-app -n dev
```

## Step 7 — Check Recent Changes

```bash
kubectl rollout history deployment/observable-app -n dev
kubectl describe deployment observable-app -n dev
```

If GitOps or CI/CD is used:

```text
check latest commit
check deployment pipeline
check image tag
check Helm release history
check ArgoCD sync history
```

---

# 33. Create Observability Runbook

Create:

```bash
nano 10.15-kubernetes-observability/runbooks/observability-debugging-runbook.md
```

Paste:

````markdown
# Kubernetes Observability Debugging Runbook

## Step 1 — Scope the Incident

```bash
kubectl get pods -A | grep -v Running
kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
````

Questions:

* One Pod or many?
* One namespace or whole cluster?
* One node or all nodes?
* App issue or cluster issue?
* New deployment or config change?

## Step 2 — Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
kubectl describe pod POD_NAME -n NAMESPACE
```

Events are best for:

* scheduling failures
* image pull failures
* probe failures
* volume mount failures
* node pressure

## Step 3 — Check Logs

```bash
kubectl logs POD_NAME -n NAMESPACE
kubectl logs POD_NAME -n NAMESPACE --previous
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE
```

Logs are best for:

* app exceptions
* startup failures
* request failures
* dependency errors

## Step 4 — Check Metrics

```bash
kubectl top pods -n NAMESPACE
kubectl top nodes
```

Prometheus examples:

```promql
up
rate(container_cpu_usage_seconds_total[5m])
container_memory_working_set_bytes
kube_pod_container_status_restarts_total
```

Metrics are best for:

* trends
* saturation
* alerting
* capacity
* latency/error impact

## Step 5 — Check Traffic Path

```bash
kubectl get ingress,svc,endpoints -n NAMESPACE
kubectl describe svc SERVICE_NAME -n NAMESPACE
kubectl describe ingress INGRESS_NAME -n NAMESPACE
```

## Step 6 — Check Recent Changes

```bash
kubectl rollout history deployment/DEPLOYMENT_NAME -n NAMESPACE
kubectl describe deployment DEPLOYMENT_NAME -n NAMESPACE
```

## Golden Rule

Use events, logs, metrics, and change history together.
Do not rely on only one signal.

````

---

# 34. Create Logging Runbook

Create:

```bash
nano 10.15-kubernetes-observability/runbooks/logging-runbook.md
````

Paste:

````markdown
# Kubernetes Logging Runbook

## Basic Logs

```bash
kubectl logs POD_NAME -n NAMESPACE
````

## Follow Logs

```bash
kubectl logs POD_NAME -n NAMESPACE -f
```

## Deployment Logs

```bash
kubectl logs deployment/DEPLOYMENT_NAME -n NAMESPACE
```

## Multi-Container Pod

```bash
kubectl logs POD_NAME -n NAMESPACE -c CONTAINER_NAME
```

## Previous Container Logs

```bash
kubectl logs POD_NAME -n NAMESPACE --previous
```

Use this for:

* CrashLoopBackOff
* container restarted
* app exited quickly

## Structured Logging Fields

Recommended:

* timestamp
* level
* service
* environment
* namespace
* pod
* request_id
* trace_id
* method
* path
* status
* duration_ms
* error

## Do Not Log

* passwords
* API tokens
* JWTs
* private keys
* secrets
* sensitive personal data

## Golden Rule

Logs should explain application decisions and failures.
They should not be the only observability signal.

````

---

# 35. Create Metrics Runbook

Create:

```bash
nano 10.15-kubernetes-observability/runbooks/metrics-runbook.md
````

Paste:

````markdown
# Kubernetes Metrics Runbook

## Metrics Server

```bash
kubectl top nodes
kubectl top pods -n NAMESPACE
````

Used for:

* recent CPU/memory
* HPA
* VPA

## Prometheus

Used for:

* time-series history
* dashboards
* alerts
* app metrics
* Kubernetes object metrics

## RED Metrics

For services:

* Rate
* Errors
* Duration

## USE Metrics

For infrastructure:

* Utilization
* Saturation
* Errors

## Golden Signals

* latency
* traffic
* errors
* saturation

## Common PromQL

```promql
up
rate(container_cpu_usage_seconds_total[5m])
container_memory_working_set_bytes
kube_pod_container_status_restarts_total
rate(http_requests_total[5m])
rate(http_requests_total{status=~"5.."}[5m])
```

## Golden Rule

Metrics show impact and trends.
Logs show details.
Events show Kubernetes decisions.

````

---

# 36. demo-node-api Observability Policy

Create:

```bash
nano 10.15-kubernetes-observability/notes/demo-node-api-observability-policy.md
````

Paste:

````markdown
# demo-node-api Observability Policy

## Required Signals

demo-node-api should expose:

- structured JSON logs
- /health endpoint
- /ready endpoint
- /metrics endpoint
- request rate metric
- error rate metric
- request duration histogram
- process/resource metrics
- version/build info

## Required Log Fields

- timestamp
- level
- service
- environment
- pod
- namespace
- request_id
- method
- path
- status
- duration_ms
- error

## Required Metrics

Recommended metric names:

```text
http_requests_total
http_request_duration_seconds
http_errors_total
nodejs_eventloop_lag_seconds
process_resident_memory_bytes
process_cpu_seconds_total
````

## Dashboards

Minimum dashboards:

* API overview
* Kubernetes workload overview
* Pod restarts
* CPU/memory
* request rate
* error rate
* latency p95/p99
* HPA status

## Alerts

Minimum alerts:

* high 5xx rate
* high p95 latency
* Pod restart spike
* Deployment unavailable
* HPA max replicas reached
* high memory usage
* readiness failures
* Ingress 5xx spike

## Golden Rule

A production API is not complete until it can be observed, alerted, and debugged.

````

---

# 37. Update demo-node-api Kustomize Base with ServiceMonitor

Create optional ServiceMonitor for your app:

```bash
nano apps/demo-node-api/base/servicemonitor.yaml
````

Paste:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-node-api
      app.kubernetes.io/component: backend
  namespaceSelector:
    matchNames:
      - dev
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

Update base kustomization:

```bash
nano apps/demo-node-api/base/kustomization.yaml
```

Add:

```yaml
  - servicemonitor.yaml
```

Full expected resources list:

```yaml
resources:
  - serviceaccount.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - hpa.yaml
  - pdb.yaml
  - servicemonitor.yaml
```

Important:

```text
Only apply this if the ServiceMonitor CRD exists.
It exists after installing kube-prometheus-stack or Prometheus Operator.
```

Check CRD:

```bash
kubectl get crd servicemonitors.monitoring.coreos.com
```

---

# 38. Observability Summary Script

Create:

```bash
nano 10.15-kubernetes-observability/scripts/observability-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Kubernetes Observability Summary ====="

echo
echo "Namespace: $NAMESPACE"

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide

echo
echo "Deployments:"
kubectl get deployments -n "$NAMESPACE"

echo
echo "Services and endpoints:"
kubectl get svc,endpoints -n "$NAMESPACE"

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30

echo
echo "Pod metrics if metrics-server is available:"
kubectl top pods -n "$NAMESPACE" || true

echo
echo "Node metrics if metrics-server is available:"
kubectl top nodes || true

echo
echo "Recent observable-app logs:"
kubectl logs deployment/observable-app -n "$NAMESPACE" --tail=20 || true

echo
echo "Monitoring namespace resources if installed:"
kubectl get pods -n monitoring || true
kubectl get svc -n monitoring || true
```

Make executable:

```bash
chmod +x 10.15-kubernetes-observability/scripts/observability-summary.sh
```

Run:

```bash
./10.15-kubernetes-observability/scripts/observability-summary.sh
```

---

# 39. Validation Script

Create:

```bash
nano 10.15-kubernetes-observability/scripts/validate-lesson-10-15.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.15 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get configmap observable-app-code -n dev >/dev/null
kubectl get deployment observable-app -n dev >/dev/null
kubectl get service observable-app -n dev >/dev/null

kubectl rollout status deployment/observable-app -n dev --timeout=120s >/dev/null

ENDPOINTS="$(kubectl get endpoints observable-app -n dev -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: observable-app service has no endpoints"
  exit 1
fi

POD_NAME="$(kubectl get pod -n dev -l app=observable-app -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD_NAME" -n dev --tail=20 | grep -q "observable-app"

kubectl port-forward -n dev svc/observable-app 18087:80 >/tmp/observable-app-pf.log 2>&1 &
PF_PID=$!

cleanup() {
  kill "$PF_PID" >/dev/null 2>&1 || true
}

trap cleanup EXIT

sleep 5

curl -fsS http://127.0.0.1:18087/health >/dev/null
curl -fsS http://127.0.0.1:18087/ready >/dev/null
curl -fsS http://127.0.0.1:18087/metrics | grep -q "observable_app_requests_total"

test -x 10.15-kubernetes-observability/scripts/observability-summary.sh

test -f 10.15-kubernetes-observability/notes/observability-mental-model.md
test -f 10.15-kubernetes-observability/notes/demo-node-api-observability-policy.md

test -f 10.15-kubernetes-observability/runbooks/observability-debugging-runbook.md
test -f 10.15-kubernetes-observability/runbooks/logging-runbook.md
test -f 10.15-kubernetes-observability/runbooks/metrics-runbook.md

test -f apps/demo-node-api/base/servicemonitor.yaml
grep -q "servicemonitor.yaml" apps/demo-node-api/base/kustomization.yaml

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl apply --dry-run=server -f apps/demo-node-api/base/servicemonitor.yaml >/dev/null
else
  echo "ServiceMonitor CRD not installed; skipping server-side ServiceMonitor validation."
fi

echo "observable-app endpoints: $ENDPOINTS"
echo "Lesson 10.15 validation passed."
```

Make executable:

```bash
chmod +x 10.15-kubernetes-observability/scripts/validate-lesson-10-15.sh
```

Run:

```bash
./10.15-kubernetes-observability/scripts/validate-lesson-10-15.sh
```

---

# 40. Cleanup Script

Create:

```bash
nano 10.15-kubernetes-observability/scripts/cleanup-lesson-10-15.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.15 ====="

kubectl delete pod observable-load -n dev --ignore-not-found=true

kubectl delete -f 10.15-kubernetes-observability/manifests/observable-app-servicemonitor.yaml --ignore-not-found=true
kubectl delete -f 10.15-kubernetes-observability/manifests/multi-container-logs-pod.yaml --ignore-not-found=true
kubectl delete -f 10.15-kubernetes-observability/manifests/bad-image-demo.yaml --ignore-not-found=true
kubectl delete -f 10.15-kubernetes-observability/manifests/observable-app-service.yaml --ignore-not-found=true
kubectl delete -f 10.15-kubernetes-observability/manifests/observable-app-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.15-kubernetes-observability/manifests/observable-app-configmap.yaml --ignore-not-found=true

echo "Lesson 10.15 demo resources cleaned."
echo "Monitoring stack is kept if installed."
echo "To remove kube-prometheus-stack:"
echo "helm uninstall kube-prometheus-stack -n monitoring"
```

Make executable:

```bash
chmod +x 10.15-kubernetes-observability/scripts/cleanup-lesson-10-15.sh
```

Run only if you want cleanup:

```bash
./10.15-kubernetes-observability/scripts/cleanup-lesson-10-15.sh
```

To remove Prometheus/Grafana:

```bash
helm uninstall kube-prometheus-stack -n monitoring
```

---

# 41. Practical Lab Summary

Run main lab:

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-configmap.yaml
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-deployment.yaml
kubectl apply -f 10.15-kubernetes-observability/manifests/observable-app-service.yaml

kubectl rollout status deployment/observable-app -n dev

kubectl port-forward -n dev svc/observable-app 8087:80
```

In another terminal:

```bash
curl http://127.0.0.1:8087/
curl http://127.0.0.1:8087/metrics
curl http://127.0.0.1:8087/simulate-error
curl http://127.0.0.1:8087/slow
```

Check observability:

```bash
kubectl get events -n dev --sort-by=.lastTimestamp
kubectl logs deployment/observable-app -n dev --tail=50
kubectl top pods -n dev || true

./10.15-kubernetes-observability/scripts/observability-summary.sh
./10.15-kubernetes-observability/scripts/validate-lesson-10-15.sh
```

Optional Prometheus/Grafana:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring

kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

---

# 42. Common Myths and Misconceptions

## Myth 1: Logs are observability

Wrong.

```text
Logs are one observability signal.
You also need metrics, events, and ideally traces.
```

---

## Myth 2: metrics-server replaces Prometheus

Wrong.

```text
metrics-server gives recent CPU/memory for Kubernetes autoscaling.
Prometheus gives richer time-series monitoring, dashboards, and alerting.
```

---

## Myth 3: kubectl logs is enough for production

Wrong.

```text
If the Pod dies, node dies, or logs rotate, local container logs may disappear.
Production needs cluster-level log storage.
```

Kubernetes logging architecture recommends cluster-level logging with storage independent from nodes, Pods, and containers. ([Kubernetes][1])

---

## Myth 4: All log fields should be Loki labels

Wrong.

```text
Use low-cardinality labels.
Do not label by request_id, user_id, or unique error message.
```

---

## Myth 5: High CPU always means the app is broken

Not always.

```text
Could be traffic spike.
Could be bad deployment.
Could be expensive request.
Could be noisy neighbor.
Could be insufficient replicas.
```

Use logs plus metrics plus events.

---

## Myth 6: A dashboard is enough

Wrong.

```text
You also need alerts, runbooks, ownership, and debugging workflows.
```

---

# 43. Production Observability Rules

```text
Use structured JSON logs for applications.
Never log secrets.
Always check events for Kubernetes lifecycle problems.
Use --previous logs for restarted containers.
Use metrics-server for current CPU/memory and autoscaling.
Use Prometheus for historical metrics and alerting.
Use Grafana for dashboards.
Use Loki or another backend for centralized logs.
Prefer Grafana Alloy or supported collectors for new Loki setups.
Track RED metrics for APIs.
Track USE metrics for infrastructure.
Create alerts for user-impacting symptoms, not only resource usage.
Correlate logs, metrics, events, traces, and deployments.
A service is not production-ready until it is observable.
```

---

# 44. Interview Explanation

Use this:

```text
Kubernetes observability uses multiple signals. Events show Kubernetes lifecycle and scheduling decisions, logs show application behavior, metrics show trends and impact over time, and traces show request flow across services.

For basic debugging, I use kubectl get events, kubectl describe, kubectl logs, kubectl logs --previous, and kubectl top. In production, I use Prometheus for metrics, Grafana for dashboards, and a centralized logging backend such as Loki or another log platform. I design dashboards around RED metrics for services and USE metrics for infrastructure, and I correlate incidents with recent deployments, configuration changes, and Kubernetes events.
```

Resume version:

```text
Implemented Kubernetes observability labs covering events, describe workflows, structured JSON logs, previous container logs, metrics-server, Prometheus metrics, Grafana dashboards, Loki logging concepts, ServiceMonitor integration, RED/USE metrics, golden signals, and production debugging runbooks for demo-node-api.
```

---

# 45. Today’s Core Rules

```text
Events explain Kubernetes decisions.
Logs explain application behavior.
Metrics explain trends and impact.
Traces explain request flow.
kubectl describe includes useful events.
kubectl logs --previous is critical for restarts.
metrics-server is not Prometheus.
Prometheus scrapes and stores time-series metrics.
Grafana visualizes metrics and logs.
Loki stores and queries logs.
Use RED metrics for request-driven services.
Use USE metrics for infrastructure.
Do not log secrets.
Centralize production logs.
Always correlate observability with recent changes.
```

---

# 46. Commit Lesson 10.15

From repo root:

```bash
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes observability events logs metrics and debugging lesson"

git push
```

---

# Next Lesson

```text
Lesson 10.16 — Production Hardening: NetworkPolicy, Pod Security, Image Policy, Admission Control, and Runtime Safety
```

We will cover:

```text
NetworkPolicy
default deny ingress
default deny egress
allow app-to-db traffic
allow ingress controller traffic
Pod Security Standards
restricted baseline privileged
securityContext
runAsNonRoot
readOnlyRootFilesystem
drop capabilities
seccompProfile
imagePullPolicy
image tag/digest policy
admission controllers
OPA Gatekeeper / Kyverno concepts
runtime security basics
production hardening policy for demo-node-api
```

[1]: https://kubernetes.io/docs/concepts/cluster-administration/logging/?utm_source=chatgpt.com "Logging Architecture"
[2]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/?utm_source=chatgpt.com "kubectl describe"
[3]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/?utm_source=chatgpt.com "kubectl logs"
[4]: https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/?utm_source=chatgpt.com "Resource metrics pipeline"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/?utm_source=chatgpt.com "kubectl top"
[6]: https://prometheus.io/docs/concepts/data_model/?utm_source=chatgpt.com "Data model"
[7]: https://prometheus.io/docs/concepts/metric_types/?utm_source=chatgpt.com "Metric types"
[8]: https://grafana.com/docs/loki/latest/get-started/architecture/?utm_source=chatgpt.com "Loki architecture"
[9]: https://grafana.com/docs/loki/latest/send-data/promtail/?utm_source=chatgpt.com "Promtail agent | Grafana Loki documentation"
[10]: https://kubernetes.io/docs/concepts/cluster-administration/system-logs/?utm_source=chatgpt.com "System Logs"
