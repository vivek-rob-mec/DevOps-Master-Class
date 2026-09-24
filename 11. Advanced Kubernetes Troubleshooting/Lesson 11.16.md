# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.16 — Final Kubernetes Troubleshooting Capstone

This is the **final lesson of Module 11**.

You will now build a complete Kubernetes troubleshooting capstone package with:

```text id="capstone-scope"
multi-incident Kubernetes lab environment
incident injector
evidence collector
diagnostic classifier
fix automation
validation suite
cleanup workflow
runbook library
post-incident report template
resume-ready summary
Module 11 completion commit
Git tag v0.11.0
```

This capstone combines everything from Module 11:

```text id="module-11-covered"
Pod failures
Deployment rollouts
Service and DNS
Ingress and TLS
ConfigMap and Secret injection
Probe failures
RBAC
Node and kubelet issues
Scheduling
Storage
NetworkPolicy and CNI
HPA autoscaling
Logs, events, metrics, and incident diagnosis
Production incident simulations
```

Kubernetes troubleshooting relies heavily on `kubectl describe`, `kubectl logs`, Events, rollout status/history, resource metrics, Service endpoints, PVC status, NetworkPolicy state, and HPA conditions. Kubernetes official docs specifically cover debugging Pods, rollouts, NetworkPolicies, PersistentVolumes, and the resource metrics pipeline used by HPA and `kubectl top`. ([Kubernetes][1])

---

# 1. Capstone Goal

By the end, you will have a portfolio-ready Kubernetes troubleshooting toolkit:

```text id="goal"
A reusable incident simulation and diagnosis framework for Kubernetes workloads.
```

You will be able to inject incidents such as:

```text id="incident-types"
bad image rollout
CrashLoopBackOff
readiness probe failure
Service selector mismatch
ConfigMap missing key
RBAC Forbidden
scheduling failure
PVC Pending
NetworkPolicy block
HPA unknown metrics
```

Then you will:

```text id="diagnosis-flow"
collect evidence
classify the issue
apply a safe fix
validate recovery
write a post-incident report
commit and tag Module 11
```

---

# 2. Create Capstone Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/{manifests,scripts,runbooks,notes,reports,incident-reports,fixes,validation}
```

Check:

```bash id="tree-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone
```

---

# 3. Capstone Architecture

Create the architecture note:

```bash id="architecture-note"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/notes/capstone-architecture.md
```

Paste:

```markdown id="architecture-content"
# Kubernetes Troubleshooting Capstone Architecture

## Namespace

trbl-capstone

## Main workload

capstone-api

## Supporting resources

- ConfigMap
- Secret
- ServiceAccount
- Role / RoleBinding
- Service
- HPA
- optional PVC
- optional NetworkPolicy
- debug client Pods

## Capstone tools

- incident injector
- evidence collector
- diagnostic classifier
- fix script
- validation suite
- cleanup script
- incident report template
- production runbooks

## Incident classes

1. bad-image
2. crashloop
3. readiness
4. service-selector
5. config-key
6. rbac
7. scheduling
8. pvc
9. networkpolicy
10. hpa

## Golden workflow

1. Inject or observe incident.
2. Collect evidence.
3. Classify symptom.
4. Identify failing layer.
5. Apply least-risk fix.
6. Validate recovery.
7. Write post-incident report.
```

---

# 4. Create Baseline Capstone App

This app supports health checks, readiness, CPU load, structured logs, request IDs, and config/secret injection.

```bash id="baseline-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/00-capstone-baseline.yaml
```

Paste:

```yaml id="baseline-content"
apiVersion: v1
kind: Namespace
metadata:
  name: trbl-capstone
  labels:
    purpose: troubleshooting-capstone
    environment: lab
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: capstone-api-config
  namespace: trbl-capstone
  labels:
    app: capstone-api
data:
  APP_ENV: "capstone"
  LOG_LEVEL: "info"
  RESPONSE_TEXT: "capstone-api-ok"
---
apiVersion: v1
kind: Secret
metadata:
  name: capstone-api-secret
  namespace: trbl-capstone
  labels:
    app: capstone-api
type: Opaque
stringData:
  API_TOKEN: "local-capstone-token"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: capstone-api-sa
  namespace: trbl-capstone
  labels:
    app: capstone-api
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: capstone-api-reader
  namespace: trbl-capstone
  labels:
    app: capstone-api
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: capstone-api-reader-binding
  namespace: trbl-capstone
  labels:
    app: capstone-api
subjects:
  - kind: ServiceAccount
    name: capstone-api-sa
    namespace: trbl-capstone
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: capstone-api-reader
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-api
  namespace: trbl-capstone
  labels:
    app: capstone-api
spec:
  replicas: 2
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 90
  selector:
    matchLabels:
      app: capstone-api
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: capstone-api
      annotations:
        kubernetes.io/change-cause: "baseline healthy capstone-api"
    spec:
      serviceAccountName: capstone-api-sa
      terminationGracePeriodSeconds: 30
      containers:
        - name: app
          image: python:3.12-alpine
          command:
            - python
            - -c
            - |
              import json
              import os
              import sys
              import time
              import uuid
              from http.server import BaseHTTPRequestHandler, HTTPServer

              START_TIME = time.time()

              APP_ENV = os.environ.get("APP_ENV", "missing")
              LOG_LEVEL = os.environ.get("LOG_LEVEL", "info")
              RESPONSE_TEXT = os.environ.get("RESPONSE_TEXT", "missing-response")
              API_TOKEN = os.environ.get("API_TOKEN", "")

              def log(level, message, **kwargs):
                  event = {
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                      "level": level,
                      "service": "capstone-api",
                      "pod": os.environ.get("HOSTNAME", "unknown"),
                      "app_env": APP_ENV,
                      "message": message,
                  }
                  event.update(kwargs)
                  print(json.dumps(event), flush=True)

              class Handler(BaseHTTPRequestHandler):
                  def log_message(self, format, *args):
                      return

                  def send_text(self, code, body, request_id, level="info", message="request_completed", **kwargs):
                      self.send_response(code)
                      self.send_header("Content-Type", "text/plain")
                      self.send_header("X-Request-ID", request_id)
                      self.end_headers()
                      self.wfile.write(body.encode())
                      log(level, message, request_id=request_id, path=self.path, status=code, **kwargs)

                  def do_GET(self):
                      request_id = self.headers.get("X-Request-ID", str(uuid.uuid4()))

                      if self.path == "/":
                          self.send_text(200, RESPONSE_TEXT + "\n", request_id)

                      elif self.path == "/health":
                          self.send_text(200, "healthy\n", request_id, message="health_ok")

                      elif self.path == "/ready":
                          if API_TOKEN:
                              self.send_text(200, "ready\n", request_id, message="ready_ok")
                          else:
                              self.send_text(503, "missing token\n", request_id, level="error", message="ready_failed_missing_token")

                      elif self.path == "/version":
                          self.send_text(200, "capstone-api version 1\n", request_id)

                      elif self.path == "/slow":
                          time.sleep(2)
                          self.send_text(200, "slow-ok\n", request_id, level="warn", message="slow_request", duration_seconds=2)

                      elif self.path == "/cpu":
                          end = time.time() + 0.5
                          x = 0
                          while time.time() < end:
                              x += 1
                          self.send_text(200, "cpu-ok\n", request_id, message="cpu_burn_complete", iterations=x)

                      elif self.path == "/crash":
                          log("error", "simulated_crash", request_id=request_id)
                          sys.stdout.flush()
                          os._exit(1)

                      else:
                          self.send_text(404, "not found\n", request_id, level="warn", message="not_found")

              log("info", "service_starting", log_level=LOG_LEVEL)
              HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: capstone-api-config
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: capstone-api-config
                  key: LOG_LEVEL
            - name: RESPONSE_TEXT
              valueFrom:
                configMapKeyRef:
                  name: capstone-api-config
                  key: RESPONSE_TEXT
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: capstone-api-secret
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
  name: capstone-api
  namespace: trbl-capstone
  labels:
    app: capstone-api
spec:
  selector:
    app: capstone-api
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: capstone-api
  namespace: trbl-capstone
  labels:
    app: capstone-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: capstone-api
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
```

Apply baseline:

```bash id="apply-baseline"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/00-capstone-baseline.yaml

kubectl rollout status deployment/capstone-api -n trbl-capstone --timeout=180s
```

Validate:

```bash id="validate-baseline"
kubectl get deploy,rs,pods,svc,endpoints,hpa -n trbl-capstone -o wide

kubectl port-forward -n trbl-capstone svc/capstone-api 18088:80
```

In another terminal:

```bash id="curl-baseline"
curl -H "X-Request-ID: capstone-baseline-001" http://127.0.0.1:18088/
curl -H "X-Request-ID: capstone-ready-001" http://127.0.0.1:18088/ready
curl -H "X-Request-ID: capstone-version-001" http://127.0.0.1:18088/version
```

Expected:

```text id="baseline-expected"
capstone-api-ok
ready
capstone-api version 1
```

Stop port-forward:

```text id="stop-port-forward"
Ctrl + C
```

---

# 5. Create Incident Manifests

## 5.1 RBAC Debugger

```bash id="rbac-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/10-rbac-debugger.yaml
```

Paste:

```yaml id="rbac-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rbac-debugger
  namespace: trbl-capstone
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
      serviceAccountName: capstone-api-sa
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

---

## 5.2 Scheduling Failure

```bash id="scheduling-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/11-scheduling-failure.yaml
```

Paste:

```yaml id="scheduling-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-scheduling-failure
  namespace: trbl-capstone
  labels:
    app: capstone-scheduling-failure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: capstone-scheduling-failure
  template:
    metadata:
      labels:
        app: capstone-scheduling-failure
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

---

## 5.3 PVC Pending

```bash id="pvc-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/12-pvc-pending.yaml
```

Paste:

```yaml id="pvc-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: capstone-pending-pvc
  namespace: trbl-capstone
  labels:
    app: capstone-pvc-failure
spec:
  storageClassName: capstone-missing-storageclass
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: capstone-pvc-pod
  namespace: trbl-capstone
  labels:
    app: capstone-pvc-failure
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
        claimName: capstone-pending-pvc
```

Kubernetes binds a PVC to a PV only when the requested storage class, access mode, volume mode, size, and other constraints can be satisfied; a missing or mismatched StorageClass can leave the PVC Pending. ([Kubernetes][2])

---

## 5.4 NetworkPolicy Block

```bash id="np-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/13-networkpolicy-block.yaml
```

Paste:

```yaml id="np-content"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: capstone-default-deny-api-ingress
  namespace: trbl-capstone
spec:
  podSelector:
    matchLabels:
      app: capstone-api
  policyTypes:
    - Ingress
---
apiVersion: v1
kind: Pod
metadata:
  name: capstone-client
  namespace: trbl-capstone
  labels:
    app: capstone-client
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
```

NetworkPolicy controls Pod traffic at IP/port level, but the cluster CNI must support NetworkPolicy enforcement; otherwise policy objects can exist while traffic still passes. ([Kubernetes][3])

---

## 5.5 HPA Unknown Metrics

```bash id="hpa-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/manifests/14-hpa-unknown.yaml
```

Paste:

```yaml id="hpa-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: capstone-hpa-unknown
  namespace: trbl-capstone
  labels:
    app: capstone-hpa-unknown
spec:
  replicas: 1
  selector:
    matchLabels:
      app: capstone-hpa-unknown
  template:
    metadata:
      labels:
        app: capstone-hpa-unknown
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args:
            - "-listen=:8080"
            - "-text=capstone-hpa-unknown"
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
  name: capstone-hpa-unknown
  namespace: trbl-capstone
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: capstone-hpa-unknown
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

HPA uses metrics such as CPU and memory to adjust replicas, and `kubectl top` shows resource metrics optimized for autoscaling decisions. For CPU utilization-based scaling, missing CPU requests often leads to unknown targets because utilization is calculated relative to requested CPU. ([Kubernetes][4])

---

# 6. Create Incident Injector

```bash id="injector-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh
```

Paste:

```bash id="injector-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone"
MANIFESTS="$BASE/manifests"

INCIDENT="${INCIDENT:-}"
NAMESPACE="${NAMESPACE:-trbl-capstone}"

if [ -z "$INCIDENT" ]; then
  echo "Usage: INCIDENT=<incident-name> ./inject-incident.sh"
  echo
  echo "Valid incidents:"
  echo "  baseline"
  echo "  bad-image"
  echo "  crashloop"
  echo "  readiness"
  echo "  service-selector"
  echo "  config-key"
  echo "  rbac"
  echo "  scheduling"
  echo "  pvc"
  echo "  networkpolicy"
  echo "  hpa"
  exit 1
fi

echo "===== Inject Incident ====="
echo "Namespace: $NAMESPACE"
echo "Incident: $INCIDENT"

case "$INCIDENT" in
  baseline)
    kubectl apply -f "$MANIFESTS/00-capstone-baseline.yaml"
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=180s
    ;;

  bad-image)
    kubectl set image deployment/capstone-api app=python:this-tag-does-not-exist -n "$NAMESPACE"
    kubectl annotate deployment/capstone-api -n "$NAMESPACE" kubernetes.io/change-cause="capstone incident bad-image" --overwrite
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=60s || true
    ;;

  crashloop)
    kubectl patch deployment capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/command",
        "value": ["sh", "-c", "echo capstone simulated crashloop; echo missing dependency; exit 1"]
      }
    ]'
    kubectl annotate deployment/capstone-api -n "$NAMESPACE" kubernetes.io/change-cause="capstone incident crashloop" --overwrite
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=60s || true
    ;;

  readiness)
    kubectl patch deployment capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
        "value": "/bad-ready-path"
      }
    ]'
    kubectl annotate deployment/capstone-api -n "$NAMESPACE" kubernetes.io/change-cause="capstone incident readiness" --overwrite
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=60s || true
    ;;

  service-selector)
    kubectl patch service capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/selector/app",
        "value": "wrong-label"
      }
    ]'
    ;;

  config-key)
    kubectl patch deployment capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/env/2/valueFrom/configMapKeyRef/key",
        "value": "RESPONSE_TEXT_WRONG"
      }
    ]'
    kubectl annotate deployment/capstone-api -n "$NAMESPACE" kubernetes.io/change-cause="capstone incident config-key" --overwrite
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=60s || true
    ;;

  rbac)
    kubectl delete rolebinding capstone-api-reader-binding -n "$NAMESPACE" --ignore-not-found=true
    kubectl apply -f "$MANIFESTS/10-rbac-debugger.yaml"
    kubectl rollout status deployment/rbac-debugger -n "$NAMESPACE" --timeout=120s
    ;;

  scheduling)
    kubectl apply -f "$MANIFESTS/11-scheduling-failure.yaml"
    ;;

  pvc)
    kubectl apply -f "$MANIFESTS/12-pvc-pending.yaml"
    ;;

  networkpolicy)
    kubectl apply -f "$MANIFESTS/13-networkpolicy-block.yaml"
    kubectl wait --for=condition=Ready pod/capstone-client -n "$NAMESPACE" --timeout=120s || true
    ;;

  hpa)
    kubectl apply -f "$MANIFESTS/14-hpa-unknown.yaml"
    kubectl rollout status deployment/capstone-hpa-unknown -n "$NAMESPACE" --timeout=120s
    ;;

  *)
    echo "Unknown incident: $INCIDENT"
    exit 1
    ;;
esac

echo
echo "Incident injected: $INCIDENT"
echo
echo "Next:"
echo "NAMESPACE=$NAMESPACE ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh"
echo
echo "Collect evidence:"
echo "NAMESPACE=$NAMESPACE INCIDENT_ID=$INCIDENT ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh"
```

Make executable:

```bash id="chmod-injector"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh
```

Examples:

```bash id="injector-examples"
INCIDENT=baseline ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh

INCIDENT=bad-image ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh

INCIDENT=readiness ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh
```

---

# 7. Create Evidence Collector

```bash id="evidence-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh
```

Paste:

```bash id="evidence-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-trbl-capstone}"
APP_LABEL="${APP_LABEL:-app=capstone-api}"
INCIDENT_ID="${INCIDENT_ID:-incident-$(date +%Y%m%d-%H%M%S)}"

BASE_DIR="11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/reports/$INCIDENT_ID"
mkdir -p "$BASE_DIR"

echo "===== Capstone Evidence Collector ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"
echo "Incident ID: $INCIDENT_ID"
echo "Output: $BASE_DIR"

kubectl get all -n "$NAMESPACE" -o wide > "$BASE_DIR/all.txt" 2>&1 || true
kubectl get deploy,rs,pods,svc,endpoints,endpointslice -n "$NAMESPACE" -o wide > "$BASE_DIR/workload-network.txt" 2>&1 || true
kubectl get configmap,secret,serviceaccount,role,rolebinding -n "$NAMESPACE" > "$BASE_DIR/config-rbac.txt" 2>&1 || true
kubectl get networkpolicy -n "$NAMESPACE" -o yaml > "$BASE_DIR/networkpolicy.yaml" 2>&1 || true
kubectl get hpa -n "$NAMESPACE" -o wide > "$BASE_DIR/hpa.txt" 2>&1 || true
kubectl get hpa -n "$NAMESPACE" -o yaml > "$BASE_DIR/hpa.yaml" 2>&1 || true
kubectl get pvc -n "$NAMESPACE" -o wide > "$BASE_DIR/pvc.txt" 2>&1 || true
kubectl get pv -o wide > "$BASE_DIR/pv.txt" 2>&1 || true
kubectl get storageclass -o wide > "$BASE_DIR/storageclass.txt" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$BASE_DIR/events.txt" 2>&1 || true
kubectl top pods -n "$NAMESPACE" > "$BASE_DIR/top-pods.txt" 2>&1 || true
kubectl top nodes > "$BASE_DIR/top-nodes.txt" 2>&1 || true
kubectl rollout history deployment/capstone-api -n "$NAMESPACE" > "$BASE_DIR/rollout-history.txt" 2>&1 || true
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml > "$BASE_DIR/metrics-api.yaml" 2>&1 || true
kubectl get nodes -o wide > "$BASE_DIR/nodes.txt" 2>&1 || true

for pod in $(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
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
echo "Potential findings:"
grep -RiE "ImagePullBackOff|ErrImagePull|CrashLoopBackOff|CreateContainerConfigError|FailedScheduling|FailedMount|Unhealthy|Forbidden|Pending|not found|denied|unknown|OOMKilled|BackOff|timeout|no endpoints|FailedGetResourceMetric" "$BASE_DIR" || true
```

Make executable:

```bash id="chmod-evidence"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh
```

Run:

```bash id="run-evidence"
NAMESPACE=trbl-capstone INCIDENT_ID=baseline \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh
```

---

# 8. Create Diagnostic Classifier

```bash id="diagnose-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh
```

Paste:

```bash id="diagnose-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-trbl-capstone}"

echo "===== Capstone Diagnostic Classifier ====="
echo "Namespace: $NAMESPACE"

echo
echo "Workloads:"
kubectl get deploy,rs,pods,svc,endpoints,hpa,pvc -n "$NAMESPACE" -o wide || true

echo
echo "Pod diagnosis:"
kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | while read -r name ready status restarts age extra; do
  case "$status" in
    Pending)
      echo "[$name] Pending -> check FailedScheduling, PVC, taints, affinity, resource requests"
      ;;
    ImagePullBackOff|ErrImagePull)
      echo "[$name] ImagePullBackOff -> bad image tag/name/registry auth"
      ;;
    CrashLoopBackOff)
      echo "[$name] CrashLoopBackOff -> check logs --previous and exit code"
      ;;
    CreateContainerConfigError)
      echo "[$name] CreateContainerConfigError -> check ConfigMap/Secret/key references"
      ;;
    ContainerCreating)
      echo "[$name] ContainerCreating -> check volume mount, image pull, CNI, node"
      ;;
    Running)
      if echo "$ready" | grep -q '^0/'; then
        echo "[$name] Running but NotReady -> check readiness probe, endpoints, app readiness dependency"
      else
        echo "[$name] Running and Ready -> check Service, NetworkPolicy, HPA, logs if traffic still fails"
      fi
      ;;
    *)
      echo "[$name] $status -> inspect describe/events"
      ;;
  esac
done

echo
echo "Service and endpoints:"
kubectl get svc,endpoints -n "$NAMESPACE" || true

ENDPOINTS="$(kubectl get endpoints capstone-api -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "Hint: capstone-api has no endpoints -> check Service selector and Pod readiness."
fi

echo
echo "HPA:"
kubectl get hpa -n "$NAMESPACE" || true
if kubectl get hpa -n "$NAMESPACE" 2>/dev/null | grep -q '<unknown>'; then
  echo "Hint: HPA has unknown targets -> check metrics-server and CPU/memory requests."
fi

echo
echo "PVC:"
kubectl get pvc -n "$NAMESPACE" || true
if kubectl get pvc -n "$NAMESPACE" 2>/dev/null | grep -q Pending; then
  echo "Hint: PVC Pending -> check StorageClass, PV match, accessModes, volumeMode."
fi

echo
echo "NetworkPolicy:"
kubectl get networkpolicy -n "$NAMESPACE" || true
if kubectl get networkpolicy -n "$NAMESPACE" 2>/dev/null | grep -q capstone-default-deny-api-ingress; then
  echo "Hint: default deny ingress exists -> traffic may be blocked if CNI enforces NetworkPolicy."
fi

echo
echo "RBAC:"
kubectl auth can-i list pods \
  --as=system:serviceaccount:"$NAMESPACE":capstone-api-sa \
  -n "$NAMESPACE" || true

echo
echo "Recent warning events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | grep Warning || true

echo
echo "Recommended next command:"
echo "NAMESPACE=$NAMESPACE INCIDENT_ID=diagnosis ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh"
```

Make executable:

```bash id="chmod-diagnose"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh
```

Run:

```bash id="run-diagnose"
NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh
```

---

# 9. Create Unified Fix Script

This script applies the safest fix for each known capstone incident.

```bash id="fix-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh
```

Paste:

```bash id="fix-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-trbl-capstone}"
FIX="${FIX:-}"

if [ -z "$FIX" ]; then
  echo "Usage: FIX=<fix-name> ./fix-incident.sh"
  echo
  echo "Valid fixes:"
  echo "  baseline"
  echo "  bad-image"
  echo "  crashloop"
  echo "  readiness"
  echo "  service-selector"
  echo "  config-key"
  echo "  rbac"
  echo "  scheduling"
  echo "  pvc"
  echo "  networkpolicy"
  echo "  hpa"
  echo "  all"
  exit 1
fi

BASE="11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone"
MANIFESTS="$BASE/manifests"

echo "===== Fix Incident ====="
echo "Namespace: $NAMESPACE"
echo "Fix: $FIX"

restore_baseline() {
  kubectl apply -f "$MANIFESTS/00-capstone-baseline.yaml"
  kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=180s
}

case "$FIX" in
  baseline)
    restore_baseline
    ;;

  bad-image)
    kubectl rollout undo deployment/capstone-api -n "$NAMESPACE"
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=180s
    ;;

  crashloop)
    restore_baseline
    ;;

  readiness)
    kubectl patch deployment capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
        "value": "/ready"
      }
    ]'
    kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=180s
    ;;

  service-selector)
    kubectl patch service capstone-api -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/selector/app",
        "value": "capstone-api"
      }
    ]'
    ;;

  config-key)
    restore_baseline
    ;;

  rbac)
    kubectl apply -f "$MANIFESTS/00-capstone-baseline.yaml"
    kubectl auth can-i list pods --as=system:serviceaccount:"$NAMESPACE":capstone-api-sa -n "$NAMESPACE" || true
    ;;

  scheduling)
    kubectl patch deployment capstone-scheduling-failure -n "$NAMESPACE" --type='json' -p='[
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
    ]' || true
    kubectl rollout status deployment/capstone-scheduling-failure -n "$NAMESPACE" --timeout=120s || true
    ;;

  pvc)
    kubectl delete pod capstone-pvc-pod -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete pvc capstone-pending-pvc -n "$NAMESPACE" --ignore-not-found=true

    DEFAULT_SC="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}' 2>/dev/null || true)"

    if [ -z "$DEFAULT_SC" ]; then
      echo "No default StorageClass found. Cannot auto-fix PVC with dynamic provisioning."
      exit 1
    fi

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: capstone-pending-pvc
  namespace: $NAMESPACE
spec:
  storageClassName: $DEFAULT_SC
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: capstone-pvc-pod
  namespace: $NAMESPACE
  labels:
    app: capstone-pvc-failure
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo pvc fixed > /data/status.txt; sleep 3600"]
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
        claimName: capstone-pending-pvc
EOF
    kubectl wait --for=condition=Ready pod/capstone-pvc-pod -n "$NAMESPACE" --timeout=180s || true
    ;;

  networkpolicy)
    kubectl delete networkpolicy capstone-default-deny-api-ingress -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete pod capstone-client -n "$NAMESPACE" --ignore-not-found=true
    ;;

  hpa)
    kubectl patch deployment capstone-hpa-unknown -n "$NAMESPACE" --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/resources/requests",
        "value": {
          "cpu": "50m",
          "memory": "64Mi"
        }
      }
    ]' || true
    kubectl rollout status deployment/capstone-hpa-unknown -n "$NAMESPACE" --timeout=120s || true
    ;;

  all)
    kubectl delete -f "$MANIFESTS/10-rbac-debugger.yaml" --ignore-not-found=true
    kubectl delete -f "$MANIFESTS/11-scheduling-failure.yaml" --ignore-not-found=true
    kubectl delete -f "$MANIFESTS/12-pvc-pending.yaml" --ignore-not-found=true
    kubectl delete -f "$MANIFESTS/13-networkpolicy-block.yaml" --ignore-not-found=true
    kubectl delete -f "$MANIFESTS/14-hpa-unknown.yaml" --ignore-not-found=true
    kubectl delete pod capstone-client -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete pod capstone-pvc-pod -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete pvc capstone-pending-pvc -n "$NAMESPACE" --ignore-not-found=true
    restore_baseline
    ;;

  *)
    echo "Unknown fix: $FIX"
    exit 1
    ;;
esac

echo
echo "Fix completed: $FIX"
echo
echo "Validate:"
echo "NAMESPACE=$NAMESPACE ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh"
```

Make executable:

```bash id="chmod-fix"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh
```

Examples:

```bash id="fix-examples"
FIX=bad-image ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh

FIX=readiness ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh

FIX=all ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh
```

`kubectl rollout undo` rolls a workload back to a previous rollout revision and is a standard mitigation when a bad rollout caused the incident. ([Kubernetes][5])

---

# 10. Create Validation Suite

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-trbl-capstone}"

echo "===== Validate Kubernetes Troubleshooting Capstone ====="
echo "Namespace: $NAMESPACE"

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone"

test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/fixes"
test -d "$BASE/runbooks"
test -d "$BASE/notes"
test -d "$BASE/reports"
test -d "$BASE/incident-reports"
test -d "$BASE/validation"

test -f "$BASE/manifests/00-capstone-baseline.yaml"
test -f "$BASE/manifests/10-rbac-debugger.yaml"
test -f "$BASE/manifests/11-scheduling-failure.yaml"
test -f "$BASE/manifests/12-pvc-pending.yaml"
test -f "$BASE/manifests/13-networkpolicy-block.yaml"
test -f "$BASE/manifests/14-hpa-unknown.yaml"

test -x "$BASE/scripts/inject-incident.sh"
test -x "$BASE/scripts/collect-evidence.sh"
test -x "$BASE/scripts/diagnose.sh"
test -x "$BASE/fixes/fix-incident.sh"

kubectl apply -f "$BASE/manifests/00-capstone-baseline.yaml" >/dev/null
kubectl rollout status deployment/capstone-api -n "$NAMESPACE" --timeout=180s >/dev/null

kubectl get deployment capstone-api -n "$NAMESPACE" >/dev/null
kubectl get service capstone-api -n "$NAMESPACE" >/dev/null
kubectl get endpoints capstone-api -n "$NAMESPACE" >/dev/null
kubectl get hpa capstone-api -n "$NAMESPACE" >/dev/null

POD_COUNT="$(kubectl get pods -n "$NAMESPACE" -l app=capstone-api --no-headers | wc -l | tr -d ' ')"
if [ "$POD_COUNT" -lt 1 ]; then
  echo "ERROR: no capstone-api Pods found"
  exit 1
fi

ENDPOINTS="$(kubectl get endpoints capstone-api -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
if [ -z "$ENDPOINTS" ]; then
  echo "ERROR: capstone-api has no ready endpoints"
  exit 1
fi

READY_PODS="$(kubectl get pods -n "$NAMESPACE" -l app=capstone-api --no-headers | awk '{print $2}' | grep -c '^1/1' || true)"
if [ "$READY_PODS" -lt 1 ]; then
  echo "ERROR: no Ready capstone-api Pods found"
  exit 1
fi

kubectl auth can-i list pods \
  --as=system:serviceaccount:"$NAMESPACE":capstone-api-sa \
  -n "$NAMESPACE" >/dev/null

echo
echo "Runtime validation:"
CLIENT_POD="capstone-validation-client"

kubectl run "$CLIENT_POD" \
  -n "$NAMESPACE" \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -i \
  -- wget -T 10 -qO- http://capstone-api/version || {
    echo "ERROR: service validation failed"
    exit 1
  }

echo
echo "Metrics validation:"
if kubectl top pods -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Metrics pipeline available."
else
  echo "WARNING: kubectl top failed. HPA may show unknown until metrics-server is healthy."
fi

echo
echo "Capstone validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

Run:

```bash id="run-validation"
NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

---

# 11. Create Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/cleanup-capstone.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-trbl-capstone}"

BASE="11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone"
MANIFESTS="$BASE/manifests"

echo "===== Cleanup Troubleshooting Capstone ====="
echo "Namespace: $NAMESPACE"

kubectl delete -f "$MANIFESTS/14-hpa-unknown.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS/13-networkpolicy-block.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS/12-pvc-pending.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS/11-scheduling-failure.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS/10-rbac-debugger.yaml" --ignore-not-found=true
kubectl delete -f "$MANIFESTS/00-capstone-baseline.yaml" --ignore-not-found=true

kubectl delete pod capstone-client -n "$NAMESPACE" --ignore-not-found=true
kubectl delete pod capstone-pvc-pod -n "$NAMESPACE" --ignore-not-found=true
kubectl delete pvc capstone-pending-pvc -n "$NAMESPACE" --ignore-not-found=true

echo
echo "Capstone resources cleaned."
echo "Reports are preserved under:"
echo "$BASE/reports"
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/cleanup-capstone.sh
```

Run cleanup:

```bash id="run-cleanup"
NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/cleanup-capstone.sh
```

---

# 12. Create Capstone Runbook

```bash id="capstone-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/runbooks/capstone-troubleshooting-runbook.md
```

Paste:

````markdown id="capstone-runbook-content"
# Final Kubernetes Troubleshooting Capstone Runbook

## 1. Deploy baseline

```bash
INCIDENT=baseline ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh
````

## 2. Inject incident

```bash id="rb-inject"
INCIDENT=bad-image ./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh
```

Valid incidents:

* bad-image
* crashloop
* readiness
* service-selector
* config-key
* rbac
* scheduling
* pvc
* networkpolicy
* hpa

## 3. Collect evidence

```bash id="rb-evidence"
NAMESPACE=trbl-capstone INCIDENT_ID=bad-image \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh
```

## 4. Diagnose

```bash id="rb-diagnose"
NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh
```

## 5. Fix

```bash id="rb-fix"
FIX=bad-image \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh
```

## 6. Validate

```bash id="rb-validate"
NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

## 7. Write incident report

Use:

```text id="rb-report-template"
incident-reports/post-incident-report-template.md
```

## Diagnosis map

| Symptom                    | First area                                     |
| -------------------------- | ---------------------------------------------- |
| ImagePullBackOff           | image tag, registry, rollout                   |
| CrashLoopBackOff           | logs --previous, command, app config           |
| Running but NotReady       | readiness probe, endpoints                     |
| Service no endpoints       | selector, labels, readiness                    |
| CreateContainerConfigError | ConfigMap/Secret/key                           |
| Forbidden                  | RBAC Role/Binding/ServiceAccount               |
| Pending                    | scheduler, resources, taints, affinity, PVC    |
| PVC Pending                | StorageClass, PV/PVC binding                   |
| DNS works but HTTP timeout | NetworkPolicy/CNI                              |
| HPA unknown                | metrics-server, metrics API, resource requests |

````

---

# 13. Create Incident Report Template

```bash id="report-template"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/incident-reports/post-incident-report-template.md
````

Paste:

````markdown id="report-template-content"
# Post-Incident Report

## Incident title

Example:
Capstone bad image rollout caused ImagePullBackOff

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

How was the incident detected?

- alert
- synthetic check
- user report
- failed deployment
- manual validation

## Timeline

| Time | Evidence | Observation |
|---|---|---|
| HH:MM | rollout history | new revision created |
| HH:MM | pod status | failure observed |
| HH:MM | describe pod | root symptom found |
| HH:MM | evidence collector | evidence saved |
| HH:MM | fix script | mitigation applied |
| HH:MM | validation | service recovered |

## Trigger

Immediate event that started the incident.

## Root cause

Underlying cause or process gap.

## Resolution

What fixed the incident?

## Validation

How recovery was confirmed:

- rollout status
- Pod readiness
- endpoints
- curl health check
- logs
- metrics

## What went well

-

## What went poorly

-

## Prevention actions

- CI/CD validation
- manifest policy
- better probes
- better resource requests
- RBAC test
- NetworkPolicy test
- storage preflight
- autoscaling check
- alert improvement
- runbook update

## Evidence path

```text
reports/<incident-id>
````

## Commands used

```bash
kubectl ...
```

````

---

# 14. Create Module 11 Final Summary

```bash id="summary-note"
nano 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/notes/module-11-final-summary.md
````

Paste:

```markdown id="summary-content"
# Module 11 Final Summary — Advanced Kubernetes Troubleshooting

## Completed lessons

1. Troubleshooting mental model
2. Pod failure debugging
3. Deployment rollout debugging
4. Service and DNS troubleshooting
5. Ingress and TLS troubleshooting
6. ConfigMap and Secret troubleshooting
7. Probe failure troubleshooting
8. RBAC permission troubleshooting
9. Node pressure and kubelet troubleshooting
10. Scheduling failures
11. Storage, PVC, PV, StatefulSet troubleshooting
12. NetworkPolicy and CNI troubleshooting
13. HPA autoscaling troubleshooting
14. Logs, events, metrics, traces, and incident diagnosis
15. Production incident simulations
16. Final troubleshooting capstone

## Capstone deliverables

- baseline Kubernetes app
- incident injector
- evidence collector
- diagnostic classifier
- fix automation
- validation suite
- cleanup script
- runbooks
- incident report template

## Key capabilities

- identify Pod failure modes
- debug rollouts and rollback safely
- debug Services, DNS, endpoints, and ingress
- troubleshoot probes and readiness
- fix ConfigMap/Secret injection errors
- diagnose RBAC Forbidden errors
- analyze scheduling failures
- debug PVC/PV/StorageClass issues
- verify NetworkPolicy and CNI behavior
- diagnose HPA metrics problems
- collect incident evidence
- build post-incident reports

## Production mindset

Evidence first.
Fix second.
Validate always.
Document prevention.
```

---

# 15. Capstone Practice Flow

Run the full flow for one incident:

```bash id="practice-bad-image"
cd ~/devops-masterclass

INCIDENT=baseline \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh

INCIDENT=bad-image \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh

NAMESPACE=trbl-capstone INCIDENT_ID=capstone-bad-image \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh

NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh

FIX=bad-image \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh

NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

Run another incident:

```bash id="practice-config"
FIX=all \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh

INCIDENT=config-key \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/inject-incident.sh

NAMESPACE=trbl-capstone INCIDENT_ID=capstone-config-key \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh

NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/diagnose.sh

FIX=config-key \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/fixes/fix-incident.sh

NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

---

# 16. Real Production Debug Mapping

```text id="prod-debug-map"
ImagePullBackOff:
  describe Pod -> image name/tag/registry -> rollout history -> rollout undo

CrashLoopBackOff:
  logs --previous -> exit code -> command/config/app dependency

Running but NotReady:
  describe Pod -> readiness probe -> endpoints -> app /ready behavior

Service has no endpoints:
  Service selector mismatch or Pods not Ready

CreateContainerConfigError:
  missing ConfigMap, missing Secret, wrong key, wrong namespace

Forbidden:
  ServiceAccount authenticated but RBAC denied; use kubectl auth can-i

Pending:
  FailedScheduling due to requests, taints, nodeSelector, affinity, PVC, quota

PVC Pending:
  StorageClass missing, no provisioner, no matching PV, accessModes/volumeMode mismatch

Network timeout with healthy endpoints:
  NetworkPolicy source egress or destination ingress, or CNI issue

HPA TARGETS unknown:
  metrics-server, metrics API, missing CPU/memory requests
```

---

# 17. Common Capstone Mistakes

## Mistake 1: Fixing before collecting evidence

Collect first:

```bash id="mistake-evidence"
NAMESPACE=trbl-capstone INCIDENT_ID=my-incident \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/scripts/collect-evidence.sh
```

---

## Mistake 2: Looking only at logs

For Kubernetes decisions, Events and `describe` are often more useful than app logs.

---

## Mistake 3: Deleting Pods too early

Deleting a Pod can remove useful context. First collect:

```bash id="mistake-before-delete"
kubectl describe pod POD -n trbl-capstone
kubectl logs POD -n trbl-capstone --previous
kubectl get events -n trbl-capstone --sort-by=.lastTimestamp
```

---

## Mistake 4: Treating rollback as complete without validation

Validate with:

```bash id="rollback-validation"
kubectl rollout status deployment/capstone-api -n trbl-capstone
kubectl get pods,svc,endpoints -n trbl-capstone -o wide
curl health endpoint
```

---

## Mistake 5: Over-fixing permissions

For RBAC, avoid `cluster-admin`. Add the exact missing verb/resource/namespace.

---

## Mistake 6: Ignoring CNI support

If NetworkPolicy does not block traffic, check CNI enforcement before assuming the policy is wrong.

---

# 18. Interview Explanation

Use this:

```text id="interview-answer"
In my Kubernetes troubleshooting capstone, I built a multi-incident simulation environment with a baseline API workload, ConfigMap and Secret injection, ServiceAccount and RBAC, Service and endpoints, HPA, PVC scenarios, NetworkPolicy scenarios, and automated incident injection.

My troubleshooting workflow starts with evidence collection. I collect workload state, Pods, ReplicaSets, Services, endpoints, Events, logs, previous logs, HPA, PVCs, NetworkPolicies, rollout history, metrics, and node state. Then I classify the incident based on symptoms such as ImagePullBackOff, CrashLoopBackOff, CreateContainerConfigError, Pending, NotReady, empty endpoints, Forbidden, PVC Pending, NetworkPolicy timeout, or HPA unknown metrics.

For rollout incidents, I use rollout history and rollout undo. For app crashes, I use previous logs and exit codes. For Kubernetes decisions, I use Events and describe output. For Service issues, I compare selectors, labels, and endpoints. For RBAC, I use kubectl auth can-i. For storage, I inspect PVC, PV, and StorageClass. For NetworkPolicy, I verify selectors, direction, ports, and CNI enforcement. For HPA, I check metrics-server, metrics.k8s.io, kubectl top, and resource requests.

After applying a fix, I validate recovery using rollout status, Pod readiness, endpoints, service curl tests, logs, metrics, and a validation script. Finally, I write a post-incident report separating trigger, root cause, resolution, and prevention actions.
```

Resume bullet:

```text id="resume-bullet"
Built a production-grade Kubernetes troubleshooting capstone with automated incident injection, evidence collection, diagnostic classification, fix automation, validation scripts, runbooks, and post-incident reporting across bad image rollouts, CrashLoopBackOff, readiness failures, Service endpoint outages, ConfigMap/Secret errors, RBAC Forbidden issues, scheduling failures, PVC Pending storage incidents, NetworkPolicy traffic blocks, and HPA unknown metrics.
```

---

# 19. Commit and Tag Module 11

Run final validation first:

```bash id="final-validation"
cd ~/devops-masterclass

NAMESPACE=trbl-capstone \
./11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone/validation/validate-capstone.sh
```

Review files:

```bash id="git-status"
git status

find 11-advanced-kubernetes-troubleshooting/11.16-final-troubleshooting-capstone -maxdepth 3 -type f | sort
```

Commit:

```bash id="commit"
git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: complete advanced Kubernetes troubleshooting capstone"

git push
```

Tag Module 11:

```bash id="tag"
git tag -a v0.11.0 -m "Complete Module 11 Advanced Kubernetes Troubleshooting"

git push origin v0.11.0
```

Verify:

```bash id="verify-tag"
git tag --list | grep v0.11.0

git log --oneline --decorate -n 5
```

---

# 20. Module 11 Complete

```text id="module-complete"
Module 11 — Advanced Kubernetes Troubleshooting is complete.
```

You now have:

```text id="module-11-deliverables"
16 Kubernetes troubleshooting lessons
production-style labs
incident runbooks
debug scripts
evidence collectors
incident simulations
final capstone
Git tag v0.11.0
```

---

# 21. Next Module

```text id="next-module"
Module 12 — Terraform, Ansible, and Infrastructure as Code
```

We will start with:

```text id="module-12-preview"
12.1 IaC mental model
12.2 Terraform project structure
12.3 Terraform state and backend
12.4 variables, locals, outputs
12.5 modules
12.6 workspaces
12.7 AWS VPC infrastructure
12.8 EC2 and security groups
12.9 ALB and target groups
12.10 S3 and CloudFront
12.11 IAM troubleshooting
12.12 Ansible inventory and roles
12.13 Terraform + Ansible integration
12.14 CI/CD for IaC
12.15 policy checks
12.16 final IaC capstone
```

[1]: https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/?utm_source=chatgpt.com "Debug Running Pods"
[2]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/?utm_source=chatgpt.com "Persistent Volumes"
[3]: https://kubernetes.io/docs/concepts/services-networking/network-policies/?utm_source=chatgpt.com "Network Policies"
[4]: https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/?utm_source=chatgpt.com "Horizontal Pod Autoscaling"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_undo/?utm_source=chatgpt.com "kubectl rollout undo"
