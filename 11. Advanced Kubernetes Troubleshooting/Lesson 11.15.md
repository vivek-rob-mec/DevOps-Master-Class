# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.15 — Production Incident Simulations

In Lesson 11.14, you learned **incident diagnosis using logs, events, metrics, traces, and timelines**:

```text id="recap-11-14"
kubectl logs
previous logs
event timelines
metrics correlation
request ID debugging
RED and USE methods
root cause vs trigger
evidence collection
production incident runbooks
```

Now we combine everything into **production-style incident simulations**.

This lesson is different. Instead of learning one failure type, you will run multiple incidents, diagnose them, fix them, and document them like an SRE/DevOps engineer.

Kubernetes debugging usually starts with Pod state, logs, events, workload status, and recent changes. `kubectl logs` is used for container logs, `kubectl events` can show recent Kubernetes events, and `kubectl rollout undo` can roll back a previous workload rollout when a bad deployment caused the incident. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="lesson-map"
11.15.1   Production incident simulation mindset
11.15.2   Baseline app and namespace
11.15.3   Incident evidence collection
11.15.4   Bad image rollout incident
11.15.5   CrashLoopBackOff incident
11.15.6   Readiness rollout incident
11.15.7   Service endpoint incident
11.15.8   ConfigMap missing key incident
11.15.9   RBAC Forbidden incident
11.15.10  Scheduling incident
11.15.11  PVC Pending incident
11.15.12  NetworkPolicy incident
11.15.13  HPA unknown metrics incident
11.15.14  Incident timeline writing
11.15.15  Post-incident review
11.15.16  Scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/{manifests,scripts,notes,runbooks,reports,incident-reports}
```

Check:

```bash id="tree-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations
```

---

# 3. Production Incident Simulation Mindset

During an incident, your job is not to run random commands.

Your job is to:

```text id="incident-job"
1. Stabilize impact.
2. Collect evidence.
3. Identify scope.
4. Find the failing layer.
5. Apply the safest fix.
6. Validate recovery.
7. Document timeline.
8. Prevent recurrence.
```

The key question:

```text id="key-question"
Where did the request path break?
```

Request path:

```text id="request-path"
User / Client
  ↓
Ingress
  ↓
Service
  ↓
EndpointSlice / Endpoints
  ↓
Pod readiness
  ↓
Container
  ↓
Config / Secret
  ↓
RBAC / API access
  ↓
Storage
  ↓
NetworkPolicy
  ↓
Node / Scheduler
  ↓
Dependencies
```

Kubernetes Deployments support rollout status, rollout history, and rollback workflows, which are core tools when a new rollout triggers an incident. ([Kubernetes][2])

---

# 4. Create Incident Simulation Notes

```bash id="notes"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/notes/incident-simulation-mindset.md
```

Paste:

```markdown id="notes-content"
# Production Incident Simulation Mindset

## Incident workflow

1. Detect
2. Scope
3. Stabilize
4. Collect evidence
5. Diagnose
6. Fix or rollback
7. Validate
8. Document
9. Prevent recurrence

## Golden questions

- What changed?
- What broke?
- When did it start?
- Which users/workloads are affected?
- Is it app, Kubernetes, node, network, storage, config, RBAC, or dependency?
- What is the safest rollback or mitigation?

## Evidence order

1. kubectl get pods/deploy/svc/endpoints
2. kubectl describe failing resource
3. kubectl get events
4. kubectl logs and --previous logs
5. metrics
6. recent rollout history
7. config/RBAC/network/storage checks

## Golden rule

Do not delete evidence before collecting it.
```

---

# 5. Create Baseline App

This baseline app will be intentionally broken in different ways.

```bash id="baseline-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/00-baseline-incident-app.yaml
```

Paste:

```yaml id="baseline-content"
apiVersion: v1
kind: Namespace
metadata:
  name: prod-sim
  labels:
    purpose: production-incident-simulation
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-app-config
  namespace: prod-sim
  labels:
    app: incident-app
data:
  APP_MODE: "production"
  LOG_LEVEL: "info"
  RESPONSE_TEXT: "incident-app-ok"
---
apiVersion: v1
kind: Secret
metadata:
  name: incident-app-secret
  namespace: prod-sim
  labels:
    app: incident-app
type: Opaque
stringData:
  API_TOKEN: "local-demo-token"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: incident-app-sa
  namespace: prod-sim
  labels:
    app: incident-app
automountServiceAccountToken: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-app
  namespace: prod-sim
  labels:
    app: incident-app
spec:
  replicas: 2
  revisionHistoryLimit: 5
  progressDeadlineSeconds: 60
  selector:
    matchLabels:
      app: incident-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: incident-app
      annotations:
        kubernetes.io/change-cause: "baseline healthy incident app"
    spec:
      serviceAccountName: incident-app-sa
      containers:
        - name: app
          image: python:3.12-alpine
          command:
            - python
            - -c
            - |
              import json
              import os
              import time
              import uuid
              from http.server import BaseHTTPRequestHandler, HTTPServer

              RESPONSE_TEXT = os.environ.get("RESPONSE_TEXT", "missing-response")
              APP_MODE = os.environ.get("APP_MODE", "missing-mode")
              LOG_LEVEL = os.environ.get("LOG_LEVEL", "info")
              API_TOKEN = os.environ.get("API_TOKEN", "")

              def log(level, message, **kwargs):
                  event = {
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                      "level": level,
                      "message": message,
                      "pod": os.environ.get("HOSTNAME", "unknown"),
                      "app_mode": APP_MODE,
                  }
                  event.update(kwargs)
                  print(json.dumps(event), flush=True)

              class Handler(BaseHTTPRequestHandler):
                  def log_message(self, format, *args):
                      return

                  def do_GET(self):
                      request_id = self.headers.get("X-Request-ID", str(uuid.uuid4()))

                      if self.path == "/":
                          self.send_response(200)
                          self.end_headers()
                          self.wfile.write((RESPONSE_TEXT + "\n").encode())
                          log("info", "request_ok", request_id=request_id, path=self.path)

                      elif self.path == "/health":
                          self.send_response(200)
                          self.end_headers()
                          self.wfile.write(b"healthy\n")
                          log("info", "health_ok", request_id=request_id)

                      elif self.path == "/ready":
                          if API_TOKEN:
                              self.send_response(200)
                              self.end_headers()
                              self.wfile.write(b"ready\n")
                              log("info", "ready_ok", request_id=request_id)
                          else:
                              self.send_response(503)
                              self.end_headers()
                              self.wfile.write(b"missing token\n")
                              log("error", "ready_failed_missing_token", request_id=request_id)

                      elif self.path == "/error":
                          self.send_response(500)
                          self.end_headers()
                          self.wfile.write(b"simulated error\n")
                          log("error", "simulated_error", request_id=request_id)

                      elif self.path == "/slow":
                          time.sleep(2)
                          self.send_response(200)
                          self.end_headers()
                          self.wfile.write(b"slow-ok\n")
                          log("warn", "slow_request", request_id=request_id, duration_seconds=2)

                      else:
                          self.send_response(404)
                          self.end_headers()
                          self.wfile.write(b"not found\n")
                          log("warn", "not_found", request_id=request_id, path=self.path)

              log("info", "service_starting", log_level=LOG_LEVEL)
              HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: APP_MODE
              valueFrom:
                configMapKeyRef:
                  name: incident-app-config
                  key: APP_MODE
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: incident-app-config
                  key: LOG_LEVEL
            - name: RESPONSE_TEXT
              valueFrom:
                configMapKeyRef:
                  name: incident-app-config
                  key: RESPONSE_TEXT
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: incident-app-secret
                  key: API_TOKEN
          startupProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 3
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
---
apiVersion: v1
kind: Service
metadata:
  name: incident-app
  namespace: prod-sim
  labels:
    app: incident-app
spec:
  selector:
    app: incident-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply:

```bash id="apply-baseline"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/00-baseline-incident-app.yaml

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s
```

Validate:

```bash id="validate-baseline"
kubectl get deploy,rs,pods,svc,endpoints -n prod-sim -o wide

kubectl port-forward -n prod-sim svc/incident-app 18087:80
```

Another terminal:

```bash id="curl-baseline"
curl -H "X-Request-ID: baseline-001" http://127.0.0.1:18087/
curl -H "X-Request-ID: baseline-ready-001" http://127.0.0.1:18087/ready
```

Expected:

```text id="baseline-expected"
incident-app-ok
ready
```

Stop port-forward:

```text id="stop-pf"
Ctrl + C
```

---

# 6. Universal Evidence Collection Script

Create:

```bash id="evidence-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Paste:

```bash id="evidence-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod-sim}"
APP_LABEL="${APP_LABEL:-app=incident-app}"
INCIDENT_ID="${INCIDENT_ID:-incident-$(date +%Y%m%d-%H%M%S)}"

BASE_DIR="11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/reports/$INCIDENT_ID"
mkdir -p "$BASE_DIR"

echo "===== Production Simulation Evidence Collection ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"
echo "Incident ID: $INCIDENT_ID"
echo "Output: $BASE_DIR"

kubectl get all -n "$NAMESPACE" -o wide > "$BASE_DIR/all.txt" 2>&1 || true
kubectl get deploy,rs,pods,svc,endpoints,endpointslice -n "$NAMESPACE" -o wide > "$BASE_DIR/workload-network.txt" 2>&1 || true
kubectl get configmap,secret,serviceaccount,role,rolebinding -n "$NAMESPACE" > "$BASE_DIR/config-rbac.txt" 2>&1 || true
kubectl get networkpolicy -n "$NAMESPACE" -o yaml > "$BASE_DIR/networkpolicy.yaml" 2>&1 || true
kubectl get hpa -n "$NAMESPACE" -o yaml > "$BASE_DIR/hpa.yaml" 2>&1 || true
kubectl get pvc -n "$NAMESPACE" -o wide > "$BASE_DIR/pvc.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$BASE_DIR/events.txt" 2>&1 || true
kubectl top pods -n "$NAMESPACE" > "$BASE_DIR/top-pods.txt" 2>&1 || true
kubectl top nodes > "$BASE_DIR/top-nodes.txt" 2>&1 || true
kubectl rollout history deployment/incident-app -n "$NAMESPACE" > "$BASE_DIR/rollout-history.txt" 2>&1 || true

for pod in $(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
  mkdir -p "$BASE_DIR/pods/$pod"
  kubectl get pod "$pod" -n "$NAMESPACE" -o yaml > "$BASE_DIR/pods/$pod/pod.yaml" 2>&1 || true
  kubectl describe pod "$pod" -n "$NAMESPACE" > "$BASE_DIR/pods/$pod/describe.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true --tail=500 > "$BASE_DIR/pods/$pod/logs-current.txt" 2>&1 || true
  kubectl logs "$pod" -n "$NAMESPACE" --all-containers=true --previous --tail=500 > "$BASE_DIR/pods/$pod/logs-previous.txt" 2>&1 || true
done

echo
echo "Evidence files:"
find "$BASE_DIR" -type f | sort

echo
echo "Key warnings:"
grep -RiE "Failed|BackOff|Unhealthy|Forbidden|Pending|not found|denied|unknown|timeout|OOMKilled|FailedScheduling|FailedMount|ImagePull" "$BASE_DIR" || true
```

Make executable:

```bash id="chmod-evidence"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Run baseline evidence:

```bash id="run-evidence-baseline"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=baseline-healthy \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

---

# 7. Incident 1 — Bad Image Rollout

## Symptom

```text id="bad-image-symptom"
New rollout stuck.
New Pods show ImagePullBackOff.
Old Pods may continue serving because maxUnavailable=0.
```

Kubernetes rolling update tutorials show that a bad image tag can cause `ImagePullBackOff`, and the fix can be to roll back to the previous known-good deployment revision. ([Kubernetes][3])

Trigger incident:

```bash id="bad-image-trigger"
kubectl set image deployment/incident-app app=python:this-tag-does-not-exist -n prod-sim

kubectl annotate deployment/incident-app -n prod-sim kubernetes.io/change-cause="incident 1 bad image rollout" --overwrite
```

Watch:

```bash id="bad-image-watch"
kubectl rollout status deployment/incident-app -n prod-sim --timeout=60s || true

kubectl get pods -n prod-sim -l app=incident-app -o wide
```

Collect evidence:

```bash id="bad-image-evidence"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=incident-01-bad-image \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Debug:

```bash id="bad-image-debug"
kubectl get rs,pods -n prod-sim -l app=incident-app -o wide

POD="$(kubectl get pod -n prod-sim -l app=incident-app -o jsonpath='{.items[-1:].metadata.name}')"

kubectl describe pod "$POD" -n prod-sim

kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 50

kubectl rollout history deployment/incident-app -n prod-sim
```

Expected finding:

```text id="bad-image-finding"
ImagePullBackOff
Failed to pull image python:this-tag-does-not-exist
```

Fix with rollback:

```bash id="bad-image-fix"
kubectl rollout undo deployment/incident-app -n prod-sim

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s
```

Validate:

```bash id="bad-image-validate"
kubectl get pods -n prod-sim -l app=incident-app -o wide

kubectl port-forward -n prod-sim svc/incident-app 18087:80
```

Another terminal:

```bash id="bad-image-curl"
curl -H "X-Request-ID: incident-01-validate" http://127.0.0.1:18087/
```

Expected:

```text id="bad-image-expected"
incident-app-ok
```

Stop port-forward:

```text id="bad-image-stop"
Ctrl + C
```

---

# 8. Incident 2 — CrashLoopBackOff

## Symptom

```text id="crashloop-symptom"
Pods repeatedly restart.
Current logs may not show the original failure.
Previous logs reveal crash reason.
```

Create patch manifest:

```bash id="crash-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/01-crashloop-command.yaml
```

Paste:

```yaml id="crash-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-app
  namespace: prod-sim
spec:
  template:
    metadata:
      annotations:
        kubernetes.io/change-cause: "incident 2 crashloop command"
    spec:
      containers:
        - name: app
          command:
            - sh
            - -c
            - |
              echo "simulated startup failure"
              echo "missing required dependency"
              exit 1
```

Apply:

```bash id="crash-apply"
kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/command",
    "value": ["sh", "-c", "echo simulated startup failure; echo missing required dependency; exit 1"]
  }
]'
```

Watch:

```bash id="crash-watch"
kubectl rollout status deployment/incident-app -n prod-sim --timeout=60s || true

kubectl get pods -n prod-sim -l app=incident-app
```

Collect evidence:

```bash id="crash-evidence"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=incident-02-crashloop \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Debug:

```bash id="crash-debug"
POD="$(kubectl get pod -n prod-sim -l app=incident-app -o jsonpath='{.items[-1:].metadata.name}')"

kubectl describe pod "$POD" -n prod-sim

kubectl logs "$POD" -n prod-sim --tail=100 || true

kubectl logs "$POD" -n prod-sim --previous --tail=100 || true
```

`kubectl logs --previous` is specifically useful when the current container instance has restarted and the original failure was in the previous instance. ([Kubernetes][1])

Expected finding:

```text id="crash-finding"
simulated startup failure
missing required dependency
Back-off restarting failed container
```

Fix rollback:

```bash id="crash-fix"
kubectl rollout undo deployment/incident-app -n prod-sim

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s
```

Validate:

```bash id="crash-validate"
kubectl get pods -n prod-sim -l app=incident-app

kubectl get deployment incident-app -n prod-sim
```

---

# 9. Incident 3 — Readiness Rollout Incident

## Symptom

```text id="readiness-symptom"
Pods are Running but NotReady.
Service endpoints disappear or shrink.
Ingress/Service traffic returns 503 or times out.
```

Kubernetes readiness probes determine whether a Pod is ready to receive traffic; failed readiness removes the Pod from ready endpoints and can stall rollouts. ([Kubernetes][4])

Trigger:

```bash id="readiness-trigger"
kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
    "value": "/bad-ready-path"
  }
]'

kubectl annotate deployment/incident-app -n prod-sim kubernetes.io/change-cause="incident 3 bad readiness path" --overwrite
```

Watch:

```bash id="readiness-watch"
kubectl rollout status deployment/incident-app -n prod-sim --timeout=60s || true

kubectl get pods,endpoints -n prod-sim -l app=incident-app -o wide
```

Collect evidence:

```bash id="readiness-evidence"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=incident-03-readiness \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Debug:

```bash id="readiness-debug"
kubectl get pods -n prod-sim -l app=incident-app

POD="$(kubectl get pod -n prod-sim -l app=incident-app -o jsonpath='{.items[-1:].metadata.name}')"

kubectl describe pod "$POD" -n prod-sim

kubectl get endpoints incident-app -n prod-sim

kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 50
```

Expected finding:

```text id="readiness-finding"
Readiness probe failed with HTTP 404.
Pods Running but NotReady.
Service endpoints affected.
```

Fix:

```bash id="readiness-fix"
kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
    "value": "/ready"
  }
]'

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s
```

Validate:

```bash id="readiness-validate"
kubectl get pods,endpoints -n prod-sim -l app=incident-app -o wide
```

---

# 10. Incident 4 — Service Selector Mismatch

## Symptom

```text id="service-symptom"
Pods are healthy.
Service exists.
But Service has no endpoints.
```

Kubernetes Services select backend Pods by labels; if the selector does not match Pod labels, the Service has no ready backend endpoints. ([Kubernetes][5])

Trigger:

```bash id="svc-trigger"
kubectl patch service incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/selector/app",
    "value": "wrong-label"
  }
]'
```

Debug:

```bash id="svc-debug"
kubectl get svc incident-app -n prod-sim -o yaml

kubectl get pods -n prod-sim --show-labels

kubectl get endpoints incident-app -n prod-sim

kubectl describe svc incident-app -n prod-sim
```

Collect evidence:

```bash id="svc-evidence"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=incident-04-service-selector \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Expected finding:

```text id="svc-finding"
Service selector app=wrong-label does not match Pods app=incident-app.
Endpoints are empty.
```

Fix:

```bash id="svc-fix"
kubectl patch service incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/selector/app",
    "value": "incident-app"
  }
]'
```

Validate:

```bash id="svc-validate"
kubectl get endpoints incident-app -n prod-sim
```

---

# 11. Incident 5 — ConfigMap Missing Key

## Symptom

```text id="config-symptom"
Pod stuck in CreateContainerConfigError.
Container never starts.
Events mention missing ConfigMap key.
```

Trigger:

```bash id="config-trigger"
kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env/2/valueFrom/configMapKeyRef/key",
    "value": "RESPONSE_TEXT_WRONG"
  }
]'
```

Watch:

```bash id="config-watch"
kubectl rollout status deployment/incident-app -n prod-sim --timeout=60s || true

kubectl get pods -n prod-sim -l app=incident-app
```

Collect evidence:

```bash id="config-evidence"
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=incident-05-config-missing-key \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

Debug:

```bash id="config-debug"
POD="$(kubectl get pod -n prod-sim -l app=incident-app -o jsonpath='{.items[-1:].metadata.name}')"

kubectl describe pod "$POD" -n prod-sim

kubectl get configmap incident-app-config -n prod-sim -o yaml

kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 50
```

Expected finding:

```text id="config-finding"
CreateContainerConfigError
couldn't find key RESPONSE_TEXT_WRONG
```

Fix:

```bash id="config-fix"
kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env/2/valueFrom/configMapKeyRef/key",
    "value": "RESPONSE_TEXT"
  }
]'

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s
```

---

# 12. Incident 6 — RBAC Forbidden

## Symptom

```text id="rbac-symptom"
Application or debug Pod can authenticate to Kubernetes API.
But API returns Forbidden.
```

RBAC uses Roles, ClusterRoles, RoleBindings, and ClusterRoleBindings to authorize actions; a ServiceAccount identity such as `system:serviceaccount:namespace:name` needs an appropriate binding to perform actions. ([Kubernetes][6])

Create RBAC incident:

```bash id="rbac-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/02-rbac-forbidden.yaml
```

Paste:

```yaml id="rbac-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbac-debugger
  namespace: prod-sim
  labels:
    app: rbac-debugger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rbac-debugger
  template:
    metadata:
      labels:
        app: rbac-debugger
    spec:
      serviceAccountName: incident-app-sa
      containers:
        - name: curl
          image: curlimages/curl:8.10.1
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="rbac-apply"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/02-rbac-forbidden.yaml

kubectl rollout status deployment/rbac-debugger -n prod-sim --timeout=120s
```

Test permission:

```bash id="rbac-can-i"
kubectl auth can-i list pods \
  --as=system:serviceaccount:prod-sim:incident-app-sa \
  -n prod-sim
```

Expected:

```text id="rbac-no"
no
```

Call API from Pod:

```bash id="rbac-api-call"
RBAC_POD="$(kubectl get pod -n prod-sim -l app=rbac-debugger -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n prod-sim "$RBAC_POD" -- sh -c '
TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
curl -sS --cacert "$CA" \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/prod-sim/pods
'
```

Expected finding:

```text id="rbac-finding"
Forbidden
```

Fix least privilege:

```bash id="rbac-fix"
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: incident-app-pod-reader
  namespace: prod-sim
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: incident-app-pod-reader-binding
  namespace: prod-sim
subjects:
  - kind: ServiceAccount
    name: incident-app-sa
    namespace: prod-sim
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: incident-app-pod-reader
EOF
```

Validate:

```bash id="rbac-validate"
kubectl auth can-i list pods \
  --as=system:serviceaccount:prod-sim:incident-app-sa \
  -n prod-sim

kubectl exec -n prod-sim "$RBAC_POD" -- sh -c '
TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
curl -sS --cacert "$CA" \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/prod-sim/pods | head -c 300
echo
'
```

Clean:

```bash id="rbac-clean"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/02-rbac-forbidden.yaml --ignore-not-found=true

kubectl delete rolebinding incident-app-pod-reader-binding -n prod-sim --ignore-not-found=true
kubectl delete role incident-app-pod-reader -n prod-sim --ignore-not-found=true
```

---

# 13. Incident 7 — Scheduling Failure

## Symptom

```text id="scheduling-symptom"
Pod remains Pending.
Events show FailedScheduling.
```

Create impossible resource request:

```bash id="scheduling-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/03-scheduling-failure.yaml
```

Paste:

```yaml id="scheduling-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scheduling-incident
  namespace: prod-sim
  labels:
    app: scheduling-incident
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scheduling-incident
  template:
    metadata:
      labels:
        app: scheduling-incident
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          resources:
            requests:
              cpu: "1000"
              memory: "1000Gi"
            limits:
              cpu: "1000"
              memory: "1000Gi"
```

Apply:

```bash id="scheduling-apply"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/03-scheduling-failure.yaml
```

Debug:

```bash id="scheduling-debug"
kubectl get pods -n prod-sim -l app=scheduling-incident

POD="$(kubectl get pod -n prod-sim -l app=scheduling-incident -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n prod-sim

kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 50

kubectl describe nodes | grep -A10 "Allocated resources"
```

Kubernetes scheduler decisions depend on whether Pods can fit available node resources and constraints; `FailedScheduling` events usually explain why a Pending Pod could not be placed. ([Kubernetes][7])

Expected finding:

```text id="scheduling-finding"
Insufficient cpu
Insufficient memory
```

Fix:

```bash id="scheduling-fix"
kubectl patch deployment scheduling-incident -n prod-sim --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/cpu",
    "value": "25m"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/memory",
    "value": "32Mi"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/cpu",
    "value": "100m"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/memory",
    "value": "64Mi"
  }
]'

kubectl rollout status deployment/scheduling-incident -n prod-sim --timeout=120s
```

Clean:

```bash id="scheduling-clean"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/03-scheduling-failure.yaml --ignore-not-found=true
```

---

# 14. Incident 8 — PVC Pending

## Symptom

```text id="pvc-symptom"
PVC remains Pending.
Pod using PVC remains Pending.
StorageClass not found or no matching PV.
```

PersistentVolumes and PersistentVolumeClaims are the core Kubernetes abstraction for persistent storage; a PVC can stay Pending when provisioning or binding cannot satisfy its request. ([Kubernetes][8])

Create:

```bash id="pvc-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/04-pvc-pending.yaml
```

Paste:

```yaml id="pvc-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: incident-pvc
  namespace: prod-sim
  labels:
    app: pvc-incident
spec:
  storageClassName: missing-storage-class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-incident-pod
  namespace: prod-sim
  labels:
    app: pvc-incident
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo pvc mounted > /data/status.txt; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: incident-pvc
```

Apply:

```bash id="pvc-apply"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/04-pvc-pending.yaml
```

Debug:

```bash id="pvc-debug"
kubectl get pvc -n prod-sim

kubectl describe pvc incident-pvc -n prod-sim

kubectl get pod pvc-incident-pod -n prod-sim

kubectl describe pod pvc-incident-pod -n prod-sim

kubectl get storageclass

kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 50
```

Expected finding:

```text id="pvc-finding"
StorageClass missing-storage-class not found
PVC Pending
Pod Pending
```

Fix by recreating PVC with default StorageClass:

```bash id="pvc-fix"
kubectl delete pod pvc-incident-pod -n prod-sim --ignore-not-found=true
kubectl delete pvc incident-pvc -n prod-sim --ignore-not-found=true

DEFAULT_SC="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}')"

echo "Default StorageClass: $DEFAULT_SC"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: incident-pvc
  namespace: prod-sim
spec:
  storageClassName: ${DEFAULT_SC}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: pvc-incident-pod
  namespace: prod-sim
  labels:
    app: pvc-incident
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo pvc mounted > /data/status.txt; sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: incident-pvc
EOF
```

Validate:

```bash id="pvc-validate"
kubectl wait --for=condition=Ready pod/pvc-incident-pod -n prod-sim --timeout=180s || true

kubectl get pvc,pod -n prod-sim

kubectl exec -n prod-sim pvc-incident-pod -- cat /data/status.txt || true
```

Clean:

```bash id="pvc-clean"
kubectl delete pod pvc-incident-pod -n prod-sim --ignore-not-found=true
kubectl delete pvc incident-pvc -n prod-sim --ignore-not-found=true
```

---

# 15. Incident 9 — NetworkPolicy Blocks Traffic

## Symptom

```text id="np-symptom"
Service and endpoints are healthy.
DNS works.
HTTP traffic times out.
```

NetworkPolicy controls allowed Pod communication, but actual enforcement requires a CNI plugin that supports NetworkPolicy. ([Kubernetes][9])

Create default deny ingress:

```bash id="np-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/05-networkpolicy-blocks-app.yaml
```

Paste:

```yaml id="np-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-incident-app-ingress
  namespace: prod-sim
spec:
  podSelector:
    matchLabels:
      app: incident-app
  policyTypes:
    - Ingress
```

Apply:

```bash id="np-apply"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/05-networkpolicy-blocks-app.yaml
```

Create test client:

```bash id="np-client"
kubectl run np-client -n prod-sim --image=busybox:1.36 --restart=Never -- sleep 3600

kubectl wait --for=condition=Ready pod/np-client -n prod-sim --timeout=120s
```

Test:

```bash id="np-test"
kubectl exec -n prod-sim np-client -- nslookup incident-app.prod-sim.svc.cluster.local

kubectl exec -n prod-sim np-client -- wget -T 5 -qO- http://incident-app.prod-sim.svc.cluster.local || true
```

Interpretation:

```text id="np-interpretation"
If traffic fails:
  NetworkPolicy is enforced and default deny blocks ingress.

If traffic still works:
  your CNI may not enforce NetworkPolicy.
```

Debug:

```bash id="np-debug"
kubectl get networkpolicy -n prod-sim

kubectl describe networkpolicy default-deny-incident-app-ingress -n prod-sim

kubectl get pods -n prod-sim --show-labels

kubectl get svc,endpoints -n prod-sim incident-app
```

Fix allow same namespace client:

```bash id="np-fix"
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prod-sim-client-to-incident-app
  namespace: prod-sim
spec:
  podSelector:
    matchLabels:
      app: incident-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              run: np-client
      ports:
        - protocol: TCP
          port: 8080
EOF
```

Validate:

```bash id="np-validate"
kubectl exec -n prod-sim np-client -- wget -T 5 -qO- http://incident-app.prod-sim.svc.cluster.local || true
```

Clean:

```bash id="np-clean"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/05-networkpolicy-blocks-app.yaml --ignore-not-found=true

kubectl delete networkpolicy allow-prod-sim-client-to-incident-app -n prod-sim --ignore-not-found=true
kubectl delete pod np-client -n prod-sim --ignore-not-found=true
```

---

# 16. Incident 10 — HPA Unknown Metrics

## Symptom

```text id="hpa-symptom"
HPA TARGETS shows <unknown>.
HPA cannot calculate CPU utilization.
```

HPA periodically adjusts desired replicas based on observed metrics such as CPU, memory, custom metrics, or external metrics; CPU utilization requires usable metrics and appropriate resource requests. ([Kubernetes][10])

Create bad HPA target with missing CPU request:

```bash id="hpa-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/06-hpa-unknown.yaml
```

Paste:

```yaml id="hpa-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hpa-unknown-demo
  namespace: prod-sim
  labels:
    app: hpa-unknown-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hpa-unknown-demo
  template:
    metadata:
      labels:
        app: hpa-unknown-demo
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=hpa-unknown-demo"
          ports:
            - name: http
              containerPort: 8080
          resources:
            limits:
              cpu: "250m"
              memory: "128Mi"
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-unknown-demo
  namespace: prod-sim
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hpa-unknown-demo
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Apply:

```bash id="hpa-apply"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/06-hpa-unknown.yaml

kubectl rollout status deployment/hpa-unknown-demo -n prod-sim --timeout=120s
```

Debug:

```bash id="hpa-debug"
kubectl get hpa hpa-unknown-demo -n prod-sim

kubectl describe hpa hpa-unknown-demo -n prod-sim

kubectl top pods -n prod-sim || true

kubectl get deployment hpa-unknown-demo -n prod-sim -o yaml | grep -A15 resources:
```

Expected finding:

```text id="hpa-finding"
CPU request missing, so CPU utilization cannot be calculated.
```

Fix:

```bash id="hpa-fix"
kubectl patch deployment hpa-unknown-demo -n prod-sim --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/resources/requests",
    "value": {
      "cpu": "50m",
      "memory": "64Mi"
    }
  }
]'

kubectl rollout status deployment/hpa-unknown-demo -n prod-sim --timeout=120s
```

Validate after metrics refresh:

```bash id="hpa-validate"
sleep 30

kubectl get hpa hpa-unknown-demo -n prod-sim

kubectl describe hpa hpa-unknown-demo -n prod-sim
```

Clean:

```bash id="hpa-clean"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests/06-hpa-unknown.yaml --ignore-not-found=true
```

---

# 17. Create Incident Classifier Script

```bash id="classifier-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/incident-classifier.sh
```

Paste:

```bash id="classifier-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-prod-sim}"

echo "===== Incident Classifier ====="
echo "Namespace: $NAMESPACE"

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide || true

echo
echo "Quick diagnosis hints:"
kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | while read -r name ready status restarts age rest; do
  case "$status" in
    Pending)
      echo "$name: Pending -> check describe pod for FailedScheduling, PVC, taints, resources"
      ;;
    ImagePullBackOff|ErrImagePull)
      echo "$name: Image pull issue -> check image name/tag/registry credentials"
      ;;
    CrashLoopBackOff)
      echo "$name: CrashLoopBackOff -> check logs --previous and exit code"
      ;;
    CreateContainerConfigError)
      echo "$name: CreateContainerConfigError -> check ConfigMap/Secret refs and keys"
      ;;
    ContainerCreating)
      echo "$name: ContainerCreating -> check mounts, CNI, image pull, volume attach"
      ;;
    Running)
      echo "$name: Running -> check READY column, probes, logs, endpoints"
      ;;
    *)
      echo "$name: $status -> inspect pod/events"
      ;;
  esac
done

echo
echo "Services/endpoints:"
kubectl get svc,endpoints -n "$NAMESPACE" || true

echo
echo "HPA:"
kubectl get hpa -n "$NAMESPACE" || true

echo
echo "PVC:"
kubectl get pvc -n "$NAMESPACE" || true

echo
echo "Recent warnings:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | grep Warning || true
```

Make executable:

```bash id="chmod-classifier"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/incident-classifier.sh
```

Run:

```bash id="run-classifier"
NAMESPACE=prod-sim \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/incident-classifier.sh
```

---

# 18. Create One-Command Simulation Runner

This script applies the baseline and shows the incident menu.

```bash id="runner-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/run-incident-simulation.sh
```

Paste:

```bash id="runner-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations"
MANIFESTS="$BASE/manifests"
INCIDENT="${INCIDENT:-baseline}"

kubectl apply -f "$MANIFESTS/00-baseline-incident-app.yaml"
kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s

case "$INCIDENT" in
  baseline)
    echo "Baseline app deployed."
    ;;

  bad-image)
    kubectl set image deployment/incident-app app=python:this-tag-does-not-exist -n prod-sim
    kubectl annotate deployment/incident-app -n prod-sim kubernetes.io/change-cause="simulation bad image" --overwrite
    ;;

  crashloop)
    kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/command",
        "value": ["sh", "-c", "echo simulated startup failure; exit 1"]
      }
    ]'
    ;;

  readiness)
    kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
        "value": "/bad-ready-path"
      }
    ]'
    ;;

  service)
    kubectl patch service incident-app -n prod-sim --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/selector/app",
        "value": "wrong-label"
      }
    ]'
    ;;

  config)
    kubectl patch deployment incident-app -n prod-sim --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/env/2/valueFrom/configMapKeyRef/key",
        "value": "RESPONSE_TEXT_WRONG"
      }
    ]'
    ;;

  rbac)
    kubectl apply -f "$MANIFESTS/02-rbac-forbidden.yaml"
    kubectl rollout status deployment/rbac-debugger -n prod-sim --timeout=120s
    ;;

  scheduling)
    kubectl apply -f "$MANIFESTS/03-scheduling-failure.yaml"
    ;;

  pvc)
    kubectl apply -f "$MANIFESTS/04-pvc-pending.yaml"
    ;;

  networkpolicy)
    kubectl apply -f "$MANIFESTS/05-networkpolicy-blocks-app.yaml"
    ;;

  hpa)
    kubectl apply -f "$MANIFESTS/06-hpa-unknown.yaml"
    kubectl rollout status deployment/hpa-unknown-demo -n prod-sim --timeout=120s
    ;;

  *)
    echo "Unknown INCIDENT=$INCIDENT"
    echo "Valid: baseline bad-image crashloop readiness service config rbac scheduling pvc networkpolicy hpa"
    exit 1
    ;;
esac

echo
echo "Simulation applied: $INCIDENT"
echo
echo "Run:"
echo "NAMESPACE=prod-sim ./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/incident-classifier.sh"
echo
echo "Collect evidence:"
echo "NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=$INCIDENT ./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh"
```

Make executable:

```bash id="chmod-runner"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/run-incident-simulation.sh
```

Examples:

```bash id="runner-examples"
INCIDENT=baseline ./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/run-incident-simulation.sh

INCIDENT=bad-image ./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/run-incident-simulation.sh

INCIDENT=readiness ./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/run-incident-simulation.sh
```

---

# 19. Create Recovery Script

```bash id="recovery-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/recover-baseline.sh
```

Paste:

```bash id="recovery-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests"

echo "===== Recover Baseline ====="

kubectl delete -f "$BASE/02-rbac-forbidden.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-scheduling-failure.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-pvc-pending.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-networkpolicy-blocks-app.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-hpa-unknown.yaml" --ignore-not-found=true

kubectl delete pod np-client -n prod-sim --ignore-not-found=true
kubectl delete networkpolicy allow-prod-sim-client-to-incident-app -n prod-sim --ignore-not-found=true
kubectl delete rolebinding incident-app-pod-reader-binding -n prod-sim --ignore-not-found=true
kubectl delete role incident-app-pod-reader -n prod-sim --ignore-not-found=true
kubectl delete pod pvc-incident-pod -n prod-sim --ignore-not-found=true
kubectl delete pvc incident-pvc -n prod-sim --ignore-not-found=true

kubectl apply -f "$BASE/00-baseline-incident-app.yaml"

kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s

kubectl get deploy,pods,svc,endpoints -n prod-sim -o wide

echo "Baseline recovered."
```

Make executable:

```bash id="chmod-recovery"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/recover-baseline.sh
```

Run:

```bash id="run-recovery"
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/recover-baseline.sh
```

---

# 20. Incident Report Template

```bash id="report-template"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/incident-reports/template.md
```

Paste:

````markdown id="report-template-content"
# Incident Report

## Incident title

Example:
Bad image rollout caused ImagePullBackOff

## Severity

SEV:

## Impact

- service:
- namespace:
- users affected:
- start time:
- end time:
- duration:

## Detection

How was it detected?

- alert
- user report
- synthetic check
- dashboard
- manual validation

## Timeline

| Time | Evidence | Observation |
|---|---|---|
| HH:MM | rollout history | new revision created |
| HH:MM | pod status | ImagePullBackOff |
| HH:MM | describe pod | image tag not found |
| HH:MM | action | rollout undo |
| HH:MM | validation | service healthy |

## Trigger

Immediate event that started the incident.

## Root cause

Underlying cause or process gap.

## What went well

-

## What went poorly

-

## Resolution

What fixed it?

## Prevention

- validation
- CI/CD gate
- alert
- runbook update
- better probe/config/security policy

## Commands used

```bash
kubectl ...
````

## Evidence path

reports/<incident-id>

````

---

# 21. Post-Incident Review Checklist

```bash id="pir-checklist"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/notes/post-incident-review-checklist.md
````

Paste:

```markdown id="pir-content"
# Post-Incident Review Checklist

## Technical

- Was the root cause identified?
- Was the trigger identified?
- Was evidence collected before destructive action?
- Was rollback safe?
- Was recovery validated?
- Was monitoring sufficient?
- Were logs useful?
- Were events captured before expiry?
- Did dashboards show the impact?
- Did alerts fire correctly?

## Process

- Who owned the incident?
- Was escalation clear?
- Was communication timely?
- Were runbooks accurate?
- Did the fix introduce new risk?

## Prevention

- add CI validation
- add policy checks
- improve probes
- improve resource requests
- add PDB
- improve NetworkPolicy tests
- add RBAC can-i checks
- add storage validation
- add rollout smoke test
- improve alerts
```

---

# 22. Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/cleanup-lesson-11-15.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/manifests"

echo "===== Cleanup Lesson 11.15 ====="

kubectl delete -f "$BASE/06-hpa-unknown.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-networkpolicy-blocks-app.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-pvc-pending.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-scheduling-failure.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-rbac-forbidden.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/00-baseline-incident-app.yaml" --ignore-not-found=true

kubectl delete pod np-client -n prod-sim --ignore-not-found=true
kubectl delete networkpolicy allow-prod-sim-client-to-incident-app -n prod-sim --ignore-not-found=true
kubectl delete rolebinding incident-app-pod-reader-binding -n prod-sim --ignore-not-found=true
kubectl delete role incident-app-pod-reader -n prod-sim --ignore-not-found=true
kubectl delete pod pvc-incident-pod -n prod-sim --ignore-not-found=true
kubectl delete pvc incident-pvc -n prod-sim --ignore-not-found=true

echo "Lesson 11.15 demo resources cleaned."
echo "Reports remain under:"
echo "11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/reports"
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/cleanup-lesson-11-15.sh
```

Run:

```bash id="run-cleanup"
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/cleanup-lesson-11-15.sh
```

---

# 23. Validation Script

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/validate-lesson-11-15.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.15 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"
test -d "$BASE/reports"
test -d "$BASE/incident-reports"

test -f "$BASE/notes/incident-simulation-mindset.md"
test -f "$BASE/notes/post-incident-review-checklist.md"
test -f "$BASE/incident-reports/template.md"

test -f "$BASE/manifests/00-baseline-incident-app.yaml"
test -f "$BASE/manifests/01-crashloop-command.yaml"
test -f "$BASE/manifests/02-rbac-forbidden.yaml"
test -f "$BASE/manifests/03-scheduling-failure.yaml"
test -f "$BASE/manifests/04-pvc-pending.yaml"
test -f "$BASE/manifests/05-networkpolicy-blocks-app.yaml"
test -f "$BASE/manifests/06-hpa-unknown.yaml"

test -x "$BASE/scripts/collect-prod-sim-evidence.sh"
test -x "$BASE/scripts/incident-classifier.sh"
test -x "$BASE/scripts/run-incident-simulation.sh"
test -x "$BASE/scripts/recover-baseline.sh"
test -x "$BASE/scripts/cleanup-lesson-11-15.sh"

kubectl apply -f "$BASE/manifests/00-baseline-incident-app.yaml" >/dev/null
kubectl rollout status deployment/incident-app -n prod-sim --timeout=180s >/dev/null

kubectl get svc incident-app -n prod-sim >/dev/null
kubectl get endpoints incident-app -n prod-sim >/dev/null

POD_COUNT="$(kubectl get pods -n prod-sim -l app=incident-app --no-headers | wc -l | tr -d ' ')"

if [ "$POD_COUNT" -lt 1 ]; then
  echo "ERROR: no incident-app Pods found"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints incident-app -n prod-sim -o jsonpath='{.subsets[*].addresses[*].ip}' || true)"

if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: incident-app Service has no endpoints"
  exit 1
fi

echo "Pod count: $POD_COUNT"
echo "Endpoints: $ENDPOINTS"
echo "Lesson 11.15 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/validate-lesson-11-15.sh
```

Run:

```bash id="run-validation"
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/validate-lesson-11-15.sh
```

---

# 24. Production Incident Simulation Runbook

```bash id="runbook"
nano 11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/runbooks/production-incident-simulation-runbook.md
```

Paste:

````markdown id="runbook-content"
# Production Incident Simulation Runbook

## Step 1 — Stabilize

Check current state:

```bash
kubectl get deploy,rs,pods,svc,endpoints -n prod-sim -o wide
kubectl get events -n prod-sim --sort-by=.lastTimestamp | tail -n 80
````

## Step 2 — Collect evidence

```bash
NAMESPACE=prod-sim APP_LABEL='app=incident-app' INCIDENT_ID=my-incident \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/collect-prod-sim-evidence.sh
```

## Step 3 — Classify

```bash
NAMESPACE=prod-sim \
./11-advanced-kubernetes-troubleshooting/11.15-production-incident-simulations/scripts/incident-classifier.sh
```

## Step 4 — Diagnose by symptom

### ImagePullBackOff

```bash
kubectl describe pod POD -n prod-sim
kubectl rollout history deployment/incident-app -n prod-sim
kubectl rollout undo deployment/incident-app -n prod-sim
```

### CrashLoopBackOff

```bash
kubectl logs POD -n prod-sim --previous
kubectl describe pod POD -n prod-sim
```

### Running but NotReady

```bash
kubectl describe pod POD -n prod-sim
kubectl get endpoints incident-app -n prod-sim
```

### Service no endpoints

```bash
kubectl get svc incident-app -n prod-sim -o yaml
kubectl get pods -n prod-sim --show-labels
```

### ConfigMap/Secret error

```bash
kubectl describe pod POD -n prod-sim
kubectl get configmap,secret -n prod-sim
```

### RBAC Forbidden

```bash
kubectl auth can-i VERB RESOURCE \
  --as=system:serviceaccount:prod-sim:incident-app-sa \
  -n prod-sim
```

### Scheduling failure

```bash
kubectl describe pod POD -n prod-sim
kubectl describe nodes
```

### PVC Pending

```bash
kubectl describe pvc PVC -n prod-sim
kubectl get storageclass
```

### NetworkPolicy issue

```bash
kubectl get networkpolicy -n prod-sim
kubectl get svc,endpoints -n prod-sim
```

### HPA unknown

```bash
kubectl get hpa -n prod-sim
kubectl describe hpa HPA -n prod-sim
kubectl top pods -n prod-sim
```

## Step 5 — Validate recovery

```bash
kubectl rollout status deployment/incident-app -n prod-sim
kubectl get pods,svc,endpoints -n prod-sim -o wide
kubectl logs -n prod-sim -l app=incident-app --tail=100
```

## Step 6 — Write incident report

Use:

```text
incident-reports/template.md
```

## Golden rule

Collect evidence before rollback when possible. Roll back first only when user impact is severe and evidence is already sufficient.

````

---

# 25. Real Production Debug Mapping

```text id="prod-debug-map"
Bad image:
  ImagePullBackOff -> describe Pod -> rollout history -> rollout undo

Crash:
  CrashLoopBackOff -> logs --previous -> exit code -> fix command/config/app

Readiness incident:
  Running but NotReady -> describe Pod -> endpoints -> fix probe or readiness dependency

Service incident:
  Service exists, no endpoints -> selector/labels/readiness

Config incident:
  CreateContainerConfigError -> missing ConfigMap/Secret/key

RBAC incident:
  Forbidden -> kubectl auth can-i -> Role/RoleBinding fix

Scheduling incident:
  Pending -> FailedScheduling -> resources/taints/affinity/nodeSelector/PVC

PVC incident:
  PVC Pending -> StorageClass/PV/accessModes/volumeMode/provisioner

NetworkPolicy incident:
  endpoints healthy, traffic timeout -> source egress/destination ingress/CNI

HPA incident:
  TARGETS unknown -> metrics-server/API/resource requests
````

---

# 26. Common Mistakes

## Mistake 1: Fixing before collecting evidence

In a real incident, evidence disappears quickly:

```text id="evidence-warning"
old Pods deleted
previous logs lost
events expire
manual changes hide root cause
```

---

## Mistake 2: Always deleting Pods

Deleting Pods may hide the failure. Prefer:

```bash id="safe-debug"
kubectl describe pod POD -n NAMESPACE
kubectl logs POD -n NAMESPACE --previous
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

---

## Mistake 3: Rollback without validation

Rollback is not complete until:

```text id="rollback-validate"
Pods Ready
endpoints restored
health check passes
logs clean
metrics recovering
```

---

## Mistake 4: Confusing trigger and root cause

Example:

```text id="trigger-root"
Trigger:
  bad image deployed

Root cause:
  CI/CD allowed nonexistent tag to deploy without image validation
```

---

## Mistake 5: Over-fixing with broad permissions

For RBAC, do not jump to `cluster-admin`.

Use least privilege.

---

# 27. Interview Explanation

Use this:

```text id="interview-answer"
In production incident simulations, I follow a structured workflow. I first define impact and collect evidence from workloads, Pods, Services, endpoints, events, logs, previous logs, metrics, HPA, PVCs, NetworkPolicies, and rollout history. Then I classify the symptom: ImagePullBackOff, CrashLoopBackOff, NotReady, empty endpoints, Forbidden, Pending, PVC Pending, NetworkPolicy timeout, or HPA unknown metrics.

For rollout-related incidents, I compare ReplicaSets and rollout history, inspect failing Pods, and use kubectl rollout undo when rollback is the safest mitigation. For runtime incidents, I use logs and previous logs. For Kubernetes decisions, I rely on events and describe output. For service incidents, I check labels and endpoints. For RBAC, I use kubectl auth can-i. For storage, I inspect PVC and PV binding. For NetworkPolicy, I check source egress, destination ingress, labels, and CNI enforcement.

After mitigation, I validate recovery with rollout status, Pod readiness, endpoints, health checks, logs, and metrics. Finally, I write a post-incident review that separates trigger from root cause and documents prevention actions.
```

Resume bullet:

```text id="resume-bullet"
Built production-style Kubernetes incident simulations covering bad image rollouts, CrashLoopBackOff, readiness rollout failures, Service selector outages, ConfigMap key errors, RBAC Forbidden responses, scheduling failures, PVC Pending storage incidents, NetworkPolicy traffic blocks, HPA unknown metrics, automated evidence collection, incident classification, rollback workflows, validation checks, and post-incident review templates.
```

---

# 28. Commit Lesson 11.15

```bash id="commit"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes production incident simulations"

git push
```

---

# 29. Next Lesson

```text id="next-lesson"
Lesson 11.16 — Final Kubernetes Troubleshooting Capstone
```

This will be the final lesson of Module 11.

You will build a complete capstone package:

```text id="next-topics"
multi-incident Kubernetes troubleshooting environment
automated incident injector
evidence collector
diagnostic classifier
runbook library
fix scripts
validation suite
post-incident report template
resume-ready final summary
Module 11 completion commit and tag v0.11.0
```

[1]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/?utm_source=chatgpt.com "kubectl logs"
[2]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/?utm_source=chatgpt.com "Deployments"
[3]: https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/?utm_source=chatgpt.com "Performing a Rolling Update"
[4]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/?utm_source=chatgpt.com "Configure Liveness, Readiness and Startup Probes"
[5]: https://kubernetes.io/docs/concepts/services-networking/service/?utm_source=chatgpt.com "Service"
[6]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/?utm_source=chatgpt.com "Using RBAC Authorization"
[7]: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/?utm_source=chatgpt.com "Pod Lifecycle"
[8]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/?utm_source=chatgpt.com "Persistent Volumes"
[9]: https://kubernetes.io/docs/concepts/services-networking/network-policies/?utm_source=chatgpt.com "Network Policies"
[10]: https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/?utm_source=chatgpt.com "Horizontal Pod Autoscaling"
