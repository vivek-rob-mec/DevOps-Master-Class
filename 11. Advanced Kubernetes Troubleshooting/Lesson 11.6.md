# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.6 — ConfigMap and Secret Injection Troubleshooting

In Lesson 11.5, you learned **Ingress and TLS troubleshooting**:

```text id="q8m0bi"
Ingress Controller health
ingressClassName mismatch
host/path mismatch
backend Service missing
backend Service has no endpoints
Ingress 404 vs 503
TLS Secret missing
certificate hostname mismatch
curl --resolve
production HTTPS debugging
```

Now we move into **ConfigMap and Secret injection troubleshooting**.

This is one of the most common reasons Pods fail with:

```text id="x9o02q"
CreateContainerConfigError
CreateContainerError
CrashLoopBackOff
wrong environment value
stale configuration
missing mounted file
application starts with default config unexpectedly
```

ConfigMaps store non-confidential configuration data as key-value pairs, while Secrets are meant for confidential data such as passwords, tokens, and keys. Both can be consumed as environment variables or mounted as files into Pods. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="w62f9s"
11.6.1   ConfigMap and Secret mental model
11.6.2   env vs envFrom
11.6.3   missing ConfigMap
11.6.4   missing Secret
11.6.5   wrong key name
11.6.6   env value not updating
11.6.7   mounted file config
11.6.8   mounted file updates
11.6.9   subPath update issue
11.6.10  base64 Secret confusion
11.6.11  optional vs required config
11.6.12  CreateContainerConfigError
11.6.13  External Secret concept
11.6.14  production config debugging workflow
11.6.15  scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="bu3rcj"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="aa5g1j"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting
```

---

# 3. ConfigMap and Secret Mental Model

A ConfigMap is for normal configuration:

```text id="p0nq6a"
LOG_LEVEL
APP_ENV
FEATURE_FLAG
API_BASE_URL
TIMEOUT_SECONDS
```

A Secret is for sensitive configuration:

```text id="k3g9lv"
DATABASE_PASSWORD
JWT_SECRET
API_TOKEN
TLS_KEY
PRIVATE_KEY
```

Ways to inject them:

```text id="ccuzsz"
1. Single env var using configMapKeyRef / secretKeyRef
2. Multiple env vars using envFrom
3. Mounted files using volumes
4. Projected volumes combining multiple sources
```

Important behavior:

```text id="tm0k04"
Environment variable values are captured when the container starts.
Mounted ConfigMap/Secret volumes can update over time.
ConfigMap/Secret mounted using subPath will not receive updates automatically.
```

Kubernetes documents that `env` and `envFrom` are used to set environment variables, but they behave differently. It also documents that ConfigMaps and Secrets can be mounted as volumes, and a ConfigMap mounted using `subPath` will not receive updates when the ConfigMap changes. ([Kubernetes][2])

---

# 4. Create Notes

```bash id="uzmq8c"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/notes/configmap-secret-mental-model.md
```

Paste:

```markdown id="hsc7p7"
# ConfigMap and Secret Troubleshooting Mental Model

## ConfigMap

Use for non-sensitive configuration.

Examples:

- LOG_LEVEL
- APP_ENV
- FEATURE_FLAG
- API_URL

## Secret

Use for sensitive configuration.

Examples:

- DB_PASSWORD
- JWT_SECRET
- API_TOKEN
- PRIVATE_KEY

## Injection Methods

1. env with configMapKeyRef / secretKeyRef
2. envFrom
3. mounted volume files
4. projected volumes

## Key Behaviors

- Missing required ConfigMap can stop Pod startup.
- Missing required Secret can stop Pod startup.
- Wrong key name can stop Pod startup.
- Environment variables do not update inside running containers automatically.
- Mounted ConfigMap/Secret files can update.
- subPath-mounted ConfigMap/Secret files do not update automatically.
- Secret data is base64-encoded, not encrypted by default.
```

---

# 5. First Debug Commands

Create:

```bash id="l7ynzz"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/notes/config-debug-commands.md
```

Paste:

````markdown id="ymg01w"
# ConfigMap and Secret Debug Commands

## Pod status

```bash
kubectl get pods -n NAMESPACE
kubectl describe pod POD_NAME -n NAMESPACE
````

## Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## ConfigMaps

```bash
kubectl get configmap -n NAMESPACE
kubectl describe configmap CONFIGMAP_NAME -n NAMESPACE
kubectl get configmap CONFIGMAP_NAME -n NAMESPACE -o yaml
```

## Secrets

```bash
kubectl get secret -n NAMESPACE
kubectl describe secret SECRET_NAME -n NAMESPACE
kubectl get secret SECRET_NAME -n NAMESPACE -o yaml
```

## Decode one Secret key

```bash
kubectl get secret SECRET_NAME -n NAMESPACE \
  -o jsonpath='{.data.KEY}' | base64 -d
echo
```

## Check env inside container

```bash
kubectl exec -n NAMESPACE POD_NAME -- env | sort
```

## Check mounted files

```bash
kubectl exec -n NAMESPACE POD_NAME -- ls -la /config
kubectl exec -n NAMESPACE POD_NAME -- cat /config/app.conf
```

````

---

# 6. Create Healthy Config Demo

Create a healthy ConfigMap, Secret, and Deployment.

```bash id="ad28c3"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/00-healthy-config-demo.yaml
````

Paste:

```yaml id="e77l96"
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-demo
  namespace: dev
  labels:
    app: config-demo
data:
  APP_ENV: "dev"
  LOG_LEVEL: "info"
  FEATURE_FLAG: "enabled"
  app.conf: |
    app_name=config-demo
    log_level=info
    feature_flag=enabled
---
apiVersion: v1
kind: Secret
metadata:
  name: config-demo-secret
  namespace: dev
  labels:
    app: config-demo
type: Opaque
stringData:
  API_TOKEN: "local-demo-token"
  DB_PASSWORD: "local-demo-password"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-demo
  namespace: dev
  labels:
    app: config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-demo
  template:
    metadata:
      labels:
        app: config-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "App started"
              echo "APP_ENV=$APP_ENV"
              echo "LOG_LEVEL=$LOG_LEVEL"
              echo "FEATURE_FLAG=$FEATURE_FLAG"
              echo "API_TOKEN length: ${#API_TOKEN}"
              echo "Mounted config:"
              cat /config/app.conf
              sleep 3600
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: config-demo
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: config-demo
                  key: LOG_LEVEL
            - name: FEATURE_FLAG
              valueFrom:
                configMapKeyRef:
                  name: config-demo
                  key: FEATURE_FLAG
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: config-demo-secret
                  key: API_TOKEN
          volumeMounts:
            - name: app-config
              mountPath: /config
              readOnly: true
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
      volumes:
        - name: app-config
          configMap:
            name: config-demo
            items:
              - key: app.conf
                path: app.conf
```

Apply:

```bash id="fmkxh8"
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/00-healthy-config-demo.yaml

kubectl rollout status deployment/config-demo -n dev --timeout=120s
```

Check:

```bash id="bca2ld"
kubectl get pod -n dev -l app=config-demo

POD="$(kubectl get pod -n dev -l app=config-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n dev

kubectl exec "$POD" -n dev -- env | sort | grep -E 'APP_ENV|LOG_LEVEL|FEATURE_FLAG|API_TOKEN'

kubectl exec "$POD" -n dev -- cat /config/app.conf
```

---

# 7. Incident 1 — Missing ConfigMap

Create a Deployment that references a ConfigMap that does not exist.

```bash id="makf6u"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/01-missing-configmap.yaml
```

Paste:

```yaml id="sy83id"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-configmap-demo
  namespace: dev
  labels:
    app: missing-configmap-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-configmap-demo
  template:
    metadata:
      labels:
        app: missing-configmap-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "echo APP_ENV=$APP_ENV; sleep 3600"]
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: missing-configmap
                  key: APP_ENV
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="dt68fp"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/01-missing-configmap.yaml
```

Debug:

```bash id="l9bnbz"
kubectl get pods -n dev -l app=missing-configmap-demo

POD="$(kubectl get pod -n dev -l app=missing-configmap-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev

kubectl get events -n dev --sort-by=.lastTimestamp | tail -n 30
```

Expected:

```text id="camf1n"
CreateContainerConfigError
configmap "missing-configmap" not found
```

Fix:

```bash id="rm5i0b"
kubectl create configmap missing-configmap \
  -n dev \
  --from-literal=APP_ENV=dev \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Validate:

```bash id="rrgm3l"
kubectl rollout status deployment/missing-configmap-demo -n dev --timeout=120s
kubectl get pods -n dev -l app=missing-configmap-demo
```

Clean:

```bash id="lc9r1g"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/01-missing-configmap.yaml --ignore-not-found=true
kubectl delete configmap missing-configmap -n dev --ignore-not-found=true
```

---

# 8. Incident 2 — Missing Secret

Create:

```bash id="n536rl"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/02-missing-secret.yaml
```

Paste:

```yaml id="ztj1eq"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: missing-secret-demo
  namespace: dev
  labels:
    app: missing-secret-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: missing-secret-demo
  template:
    metadata:
      labels:
        app: missing-secret-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "echo API_TOKEN=$API_TOKEN; sleep 3600"]
          env:
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: missing-app-secret
                  key: API_TOKEN
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="ojf4pm"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/02-missing-secret.yaml
```

Debug:

```bash id="kd9tdk"
kubectl get pods -n dev -l app=missing-secret-demo

POD="$(kubectl get pod -n dev -l app=missing-secret-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected:

```text id="xycab9"
CreateContainerConfigError
secret "missing-app-secret" not found
```

Fix:

```bash id="xg21l1"
kubectl create secret generic missing-app-secret \
  -n dev \
  --from-literal=API_TOKEN=local-secret-token \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Validate:

```bash id="j522em"
kubectl rollout status deployment/missing-secret-demo -n dev --timeout=120s
```

Clean:

```bash id="tityns"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/02-missing-secret.yaml --ignore-not-found=true
kubectl delete secret missing-app-secret -n dev --ignore-not-found=true
```

---

# 9. Incident 3 — Wrong Key Name

A ConfigMap may exist but the specific key may be wrong.

Create:

```bash id="z829iq"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/03-wrong-key-name.yaml
```

Paste:

```yaml id="js22g6"
apiVersion: v1
kind: ConfigMap
metadata:
  name: wrong-key-config
  namespace: dev
  labels:
    app: wrong-key-demo
data:
  APP_ENVIRONMENT: "dev"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrong-key-demo
  namespace: dev
  labels:
    app: wrong-key-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wrong-key-demo
  template:
    metadata:
      labels:
        app: wrong-key-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "echo APP_ENV=$APP_ENV; sleep 3600"]
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: wrong-key-config
                  key: APP_ENV
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="r82617"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/03-wrong-key-name.yaml
```

Debug:

```bash id="s5xwvx"
kubectl get configmap wrong-key-config -n dev -o yaml

kubectl get pods -n dev -l app=wrong-key-demo

POD="$(kubectl get pod -n dev -l app=wrong-key-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl describe pod "$POD" -n dev
```

Expected:

```text id="fyyul2"
CreateContainerConfigError
couldn't find key APP_ENV in ConfigMap wrong-key-config
```

Fix:

```bash id="thz52m"
kubectl patch configmap wrong-key-config -n dev \
  --type='merge' \
  -p='{"data":{"APP_ENV":"dev"}}'
```

Validate:

```bash id="kz4blm"
kubectl rollout status deployment/wrong-key-demo -n dev --timeout=120s
```

Clean:

```bash id="n25lwc"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/03-wrong-key-name.yaml --ignore-not-found=true
```

---

# 10. Incident 4 — `envFrom` Invalid Variable Names

`envFrom` imports all keys from a ConfigMap or Secret as environment variables. But environment variable names must be valid. Kubernetes allows the Pod to start, but invalid keys are skipped and recorded as an event. ([Kubernetes][3])

Create:

```bash id="xk8qhj"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/04-envfrom-invalid-key.yaml
```

Paste:

```yaml id="yf13el"
apiVersion: v1
kind: ConfigMap
metadata:
  name: envfrom-invalid-config
  namespace: dev
  labels:
    app: envfrom-invalid-demo
data:
  VALID_KEY: "this-will-appear"
  invalid-key: "this-will-be-skipped"
  another.invalid.key: "this-will-also-be-skipped"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envfrom-invalid-demo
  namespace: dev
  labels:
    app: envfrom-invalid-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: envfrom-invalid-demo
  template:
    metadata:
      labels:
        app: envfrom-invalid-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "env | sort; sleep 3600"]
          envFrom:
            - configMapRef:
                name: envfrom-invalid-config
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="qu55aq"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/04-envfrom-invalid-key.yaml

kubectl rollout status deployment/envfrom-invalid-demo -n dev --timeout=120s
```

Debug:

```bash id="dxx17s"
POD="$(kubectl get pod -n dev -l app=envfrom-invalid-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n dev | grep -E 'VALID_KEY|invalid-key|another.invalid.key' || true

kubectl get events -n dev --sort-by=.lastTimestamp | grep -i InvalidVariableNames || true
```

Expected:

```text id="ndlh1g"
VALID_KEY appears.
invalid-key and another.invalid.key are skipped.
Event mentions InvalidVariableNames.
```

Clean:

```bash id="o2whwk"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/04-envfrom-invalid-key.yaml --ignore-not-found=true
```

---

# 11. Incident 5 — Environment Value Not Updating

This is a classic production confusion.

Create:

```bash id="fz444k"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/05-env-value-not-updating.yaml
```

Paste:

```yaml id="b2c0qv"
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-update-config
  namespace: dev
  labels:
    app: env-update-demo
data:
  LOG_LEVEL: "info"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: env-update-demo
  namespace: dev
  labels:
    app: env-update-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: env-update-demo
  template:
    metadata:
      labels:
        app: env-update-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Starting with LOG_LEVEL=$LOG_LEVEL"
              while true; do
                echo "Current env LOG_LEVEL=$LOG_LEVEL"
                sleep 10
              done
          env:
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: env-update-config
                  key: LOG_LEVEL
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="ba3uav"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/05-env-value-not-updating.yaml
kubectl rollout status deployment/env-update-demo -n dev --timeout=120s
```

Check:

```bash id="p7be5k"
POD="$(kubectl get pod -n dev -l app=env-update-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n dev --tail=5
```

Update ConfigMap:

```bash id="h5affl"
kubectl patch configmap env-update-config -n dev \
  --type='merge' \
  -p='{"data":{"LOG_LEVEL":"debug"}}'
```

Check running Pod:

```bash id="ct7vkm"
kubectl logs "$POD" -n dev --tail=10
kubectl exec "$POD" -n dev -- printenv LOG_LEVEL
```

Expected:

```text id="pnd884"
The running container still has LOG_LEVEL=info.
Environment variables do not change inside an already-running container.
```

Fix by restarting rollout:

```bash id="y6jh7j"
kubectl rollout restart deployment/env-update-demo -n dev
kubectl rollout status deployment/env-update-demo -n dev --timeout=120s

NEW_POD="$(kubectl get pod -n dev -l app=env-update-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$NEW_POD" -n dev -- printenv LOG_LEVEL
```

Expected:

```text id="zp13a2"
debug
```

Clean:

```bash id="ozrayy"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/05-env-value-not-updating.yaml --ignore-not-found=true
```

---

# 12. Incident 6 — Mounted File Config Updates

Mounted ConfigMap files can update inside the Pod after the ConfigMap changes, although propagation is not instant.

Create:

```bash id="z3jyn0"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/06-mounted-file-updates.yaml
```

Paste:

```yaml id="z0qoh1"
apiVersion: v1
kind: ConfigMap
metadata:
  name: mounted-file-config
  namespace: dev
  labels:
    app: mounted-file-demo
data:
  app.conf: |
    log_level=info
    feature_flag=enabled
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mounted-file-demo
  namespace: dev
  labels:
    app: mounted-file-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mounted-file-demo
  template:
    metadata:
      labels:
        app: mounted-file-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo '--- config ---'; cat /config/app.conf; sleep 10; done"]
          volumeMounts:
            - name: app-config
              mountPath: /config
              readOnly: true
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
      volumes:
        - name: app-config
          configMap:
            name: mounted-file-config
```

Apply:

```bash id="pxj03n"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/06-mounted-file-updates.yaml
kubectl rollout status deployment/mounted-file-demo -n dev --timeout=120s
```

Check:

```bash id="jhhbks"
POD="$(kubectl get pod -n dev -l app=mounted-file-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$POD" -n dev -- cat /config/app.conf
```

Update ConfigMap:

```bash id="ueddnd"
kubectl patch configmap mounted-file-config -n dev \
  --type='merge' \
  -p='{"data":{"app.conf":"log_level=debug\nfeature_flag=enabled\n"}}'
```

Wait and check:

```bash id="qjmjwu"
sleep 30

kubectl exec "$POD" -n dev -- cat /config/app.conf
```

Expected eventually:

```text id="vmj039"
log_level=debug
feature_flag=enabled
```

Important:

```text id="djd215"
The file may update, but your application must re-read the file or reload configuration to use the new value.
```

Clean:

```bash id="ia2vxg"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/06-mounted-file-updates.yaml --ignore-not-found=true
```

---

# 13. Incident 7 — `subPath` Config Does Not Update

Kubernetes explicitly documents that containers using a ConfigMap as a `subPath` volume mount will not receive updates when the ConfigMap changes. ([Kubernetes][4])

Create:

```bash id="mpgq87"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/07-subpath-no-update.yaml
```

Paste:

```yaml id="dv8z34"
apiVersion: v1
kind: ConfigMap
metadata:
  name: subpath-config
  namespace: dev
  labels:
    app: subpath-demo
data:
  app.conf: |
    log_level=info
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: subpath-demo
  namespace: dev
  labels:
    app: subpath-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: subpath-demo
  template:
    metadata:
      labels:
        app: subpath-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "while true; do cat /app/app.conf; sleep 10; done"]
          volumeMounts:
            - name: app-config
              mountPath: /app/app.conf
              subPath: app.conf
              readOnly: true
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
      volumes:
        - name: app-config
          configMap:
            name: subpath-config
```

Apply:

```bash id="cntlxk"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/07-subpath-no-update.yaml
kubectl rollout status deployment/subpath-demo -n dev --timeout=120s
```

Check:

```bash id="gcjvj6"
POD="$(kubectl get pod -n dev -l app=subpath-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$POD" -n dev -- cat /app/app.conf
```

Update ConfigMap:

```bash id="v52uie"
kubectl patch configmap subpath-config -n dev \
  --type='merge' \
  -p='{"data":{"app.conf":"log_level=debug\n"}}'
```

Wait and check:

```bash id="duwy99"
sleep 30

kubectl exec "$POD" -n dev -- cat /app/app.conf
```

Expected:

```text id="dlfabe"
Still log_level=info
```

Fix:

```bash id="co1h8i"
kubectl rollout restart deployment/subpath-demo -n dev
kubectl rollout status deployment/subpath-demo -n dev --timeout=120s

NEW_POD="$(kubectl get pod -n dev -l app=subpath-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$NEW_POD" -n dev -- cat /app/app.conf
```

Expected:

```text id="q2jncn"
log_level=debug
```

Clean:

```bash id="fq57vk"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/07-subpath-no-update.yaml --ignore-not-found=true
```

---

# 14. Incident 8 — Secret Base64 Confusion

Secret `data` is base64-encoded, but base64 is not encryption.

Create:

```bash id="tg6kpp"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/08-secret-base64-demo.yaml
```

Paste:

```yaml id="s4d5v1"
apiVersion: v1
kind: Secret
metadata:
  name: base64-demo-secret
  namespace: dev
  labels:
    app: base64-demo
type: Opaque
data:
  API_TOKEN: bXktc2VjcmV0LXRva2Vu
```

Apply:

```bash id="xcu9os"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/08-secret-base64-demo.yaml
```

Decode:

```bash id="dbkp3y"
kubectl get secret base64-demo-secret -n dev \
  -o jsonpath='{.data.API_TOKEN}' | base64 -d
echo
```

Expected:

```text id="dndyti"
my-secret-token
```

Kubernetes Secrets are stored as base64-encoded values in manifests under `data`; Kubernetes also supports `stringData` for easier plaintext input that the API server converts into `data`. Good practices recommend encryption at rest, least-privilege access, and avoiding unnecessary Secret exposure. ([Kubernetes][5])

Clean:

```bash id="nq7f9k"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/08-secret-base64-demo.yaml --ignore-not-found=true
```

---

# 15. Optional vs Required Config

You can make ConfigMap/Secret references optional.

Required reference:

```yaml id="z7sskh"
configMapKeyRef:
  name: app-config
  key: LOG_LEVEL
```

Optional reference:

```yaml id="rl3prb"
configMapKeyRef:
  name: app-config
  key: LOG_LEVEL
  optional: true
```

Create:

```bash id="tzi2dr"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/09-optional-config.yaml
```

Paste:

```yaml id="o2v11n"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: optional-config-demo
  namespace: dev
  labels:
    app: optional-config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: optional-config-demo
  template:
    metadata:
      labels:
        app: optional-config-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "OPTIONAL_VALUE=${OPTIONAL_VALUE:-not-set}"
              sleep 3600
          env:
            - name: OPTIONAL_VALUE
              valueFrom:
                configMapKeyRef:
                  name: optional-config-that-does-not-exist
                  key: OPTIONAL_VALUE
                  optional: true
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="h577k2"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/09-optional-config.yaml

kubectl rollout status deployment/optional-config-demo -n dev --timeout=120s
```

Check logs:

```bash id="d0ygot"
POD="$(kubectl get pod -n dev -l app=optional-config-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n dev
```

Expected:

```text id="jxz4pi"
OPTIONAL_VALUE=not-set
```

Clean:

```bash id="glbqqb"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests/09-optional-config.yaml --ignore-not-found=true
```

Production rule:

```text id="j9pkth"
Use optional config only when the app has a safe default.
Do not make critical secrets optional.
```

---

# 16. Create Config Inspection Script

```bash id="z6gbic"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/config-injection-summary.sh
```

Paste:

```bash id="k7585h"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
APP_LABEL="${APP_LABEL:-app=config-demo}"

echo "===== ConfigMap/Secret Injection Summary ====="
echo "Namespace: $NAMESPACE"
echo "App label: $APP_LABEL"

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide || true

echo
echo "ConfigMaps:"
kubectl get configmap -n "$NAMESPACE" || true

echo
echo "Secrets:"
kubectl get secret -n "$NAMESPACE" || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 40 || true

PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"

for pod in $PODS; do
  echo
  echo "----- Pod: $pod -----"
  kubectl describe pod "$pod" -n "$NAMESPACE" | sed -n '/Environment:/,/Mounts:/p' || true
  echo
  echo "Logs:"
  kubectl logs "$pod" -n "$NAMESPACE" --tail=50 || true
done
```

Make executable:

```bash id="buag9j"
chmod +x 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/config-injection-summary.sh
```

Run:

```bash id="ev2ipc"
NAMESPACE=dev APP_LABEL='app=config-demo' \
./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/config-injection-summary.sh
```

---

# 17. Create Secret Decode Helper Script

```bash id="tmpr0n"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/decode-secret-key.sh
```

Paste:

```bash id="btov8r"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
SECRET="${SECRET:-}"
KEY="${KEY:-}"

if [ -z "$SECRET" ] || [ -z "$KEY" ]; then
  echo "Usage: NAMESPACE=dev SECRET=my-secret KEY=my-key ./decode-secret-key.sh"
  exit 1
fi

kubectl get secret "$SECRET" -n "$NAMESPACE" -o jsonpath="{.data.$KEY}" | base64 -d
echo
```

Make executable:

```bash id="clcng9"
chmod +x 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/decode-secret-key.sh
```

Example:

```bash id="o1umov"
NAMESPACE=dev SECRET=config-demo-secret KEY=API_TOKEN \
./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/decode-secret-key.sh
```

---

# 18. Create Run-All Labs Script

```bash id="u2f1h5"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/run-config-secret-labs.sh
```

Paste:

```bash id="dkfwt6"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests"

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$BASE/00-healthy-config-demo.yaml"
kubectl rollout status deployment/config-demo -n dev --timeout=120s

kubectl apply -f "$BASE/01-missing-configmap.yaml" || true
kubectl apply -f "$BASE/02-missing-secret.yaml" || true
kubectl apply -f "$BASE/03-wrong-key-name.yaml" || true
kubectl apply -f "$BASE/04-envfrom-invalid-key.yaml" || true
kubectl apply -f "$BASE/05-env-value-not-updating.yaml" || true
kubectl apply -f "$BASE/06-mounted-file-updates.yaml" || true
kubectl apply -f "$BASE/07-subpath-no-update.yaml" || true
kubectl apply -f "$BASE/08-secret-base64-demo.yaml" || true
kubectl apply -f "$BASE/09-optional-config.yaml" || true

echo "ConfigMap/Secret labs applied."
echo "Run:"
echo "NAMESPACE=dev APP_LABEL='app=config-demo' ./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/config-injection-summary.sh"
```

Make executable:

```bash id="nxo262"
chmod +x 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/run-config-secret-labs.sh
```

Run:

```bash id="m3c5de"
./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/run-config-secret-labs.sh
```

---

# 19. Cleanup Script

```bash id="v4zfd6"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/cleanup-lesson-11-6.sh
```

Paste:

```bash id="h2bj7f"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.6 ====="

kubectl delete -f "$BASE/09-optional-config.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/08-secret-base64-demo.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-subpath-no-update.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-mounted-file-updates.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-env-value-not-updating.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-envfrom-invalid-key.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-wrong-key-name.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-missing-secret.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-missing-configmap.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/00-healthy-config-demo.yaml" --ignore-not-found=true

kubectl delete configmap missing-configmap -n dev --ignore-not-found=true
kubectl delete secret missing-app-secret -n dev --ignore-not-found=true

echo "Lesson 11.6 demo resources cleaned."
```

Make executable:

```bash id="oytsbc"
chmod +x 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/cleanup-lesson-11-6.sh
```

Run cleanup:

```bash id="uqvcz4"
./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/cleanup-lesson-11-6.sh
```

---

# 20. Validation Script

```bash id="vswlky"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/validate-lesson-11-6.sh
```

Paste:

```bash id="ty8prv"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.6 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/configmap-secret-mental-model.md"
test -f "$BASE/notes/config-debug-commands.md"

test -f "$BASE/manifests/00-healthy-config-demo.yaml"
test -f "$BASE/manifests/01-missing-configmap.yaml"
test -f "$BASE/manifests/02-missing-secret.yaml"
test -f "$BASE/manifests/03-wrong-key-name.yaml"
test -f "$BASE/manifests/04-envfrom-invalid-key.yaml"
test -f "$BASE/manifests/05-env-value-not-updating.yaml"
test -f "$BASE/manifests/06-mounted-file-updates.yaml"
test -f "$BASE/manifests/07-subpath-no-update.yaml"
test -f "$BASE/manifests/08-secret-base64-demo.yaml"
test -f "$BASE/manifests/09-optional-config.yaml"

test -x "$BASE/scripts/config-injection-summary.sh"
test -x "$BASE/scripts/decode-secret-key.sh"
test -x "$BASE/scripts/run-config-secret-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-6.sh"

kubectl get namespace dev >/dev/null

kubectl apply -f "$BASE/manifests/00-healthy-config-demo.yaml" >/dev/null
kubectl rollout status deployment/config-demo -n dev --timeout=120s >/dev/null

kubectl get configmap config-demo -n dev >/dev/null
kubectl get secret config-demo-secret -n dev >/dev/null

POD="$(kubectl get pod -n dev -l app=config-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$POD" -n dev -- printenv APP_ENV | grep -q dev
kubectl exec "$POD" -n dev -- test -f /config/app.conf
kubectl exec "$POD" -n dev -- grep -q "app_name=config-demo" /config/app.conf

echo "Lesson 11.6 validation passed."
```

Make executable:

```bash id="lnlm4d"
chmod +x 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/validate-lesson-11-6.sh
```

Run:

```bash id="zeufff"
./11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/scripts/validate-lesson-11-6.sh
```

---

# 21. Create Runbook

```bash id="hf6scf"
nano 11-advanced-kubernetes-troubleshooting/11.6-configmap-secret-troubleshooting/runbooks/configmap-secret-troubleshooting-runbook.md
```

Paste:

````markdown id="qk1xrv"
# ConfigMap and Secret Troubleshooting Runbook

## 1. Check Pod status

```bash
kubectl get pods -n NAMESPACE
kubectl describe pod POD_NAME -n NAMESPACE
````

Look for:

* CreateContainerConfigError
* ConfigMap not found
* Secret not found
* key not found
* failed mount

## 2. Check events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## 3. Check ConfigMap

```bash
kubectl get configmap CONFIGMAP -n NAMESPACE -o yaml
```

Check:

* name
* namespace
* key names
* values

## 4. Check Secret

```bash
kubectl get secret SECRET -n NAMESPACE
kubectl describe secret SECRET -n NAMESPACE
```

Decode key:

```bash
kubectl get secret SECRET -n NAMESPACE -o jsonpath='{.data.KEY}' | base64 -d
echo
```

## 5. Check env inside container

```bash
kubectl exec -n NAMESPACE POD_NAME -- env | sort
```

## 6. Check mounted files

```bash
kubectl exec -n NAMESPACE POD_NAME -- ls -la /config
kubectl exec -n NAMESPACE POD_NAME -- cat /config/app.conf
```

## 7. Common causes

| Symptom                    | Likely Cause                                    |
| -------------------------- | ----------------------------------------------- |
| CreateContainerConfigError | missing ConfigMap/Secret/key                    |
| Env var missing            | wrong key, optional reference, invalid env name |
| Env value stale            | Pod not restarted                               |
| Mounted file stale         | app not re-reading config or subPath used       |
| Secret appears unreadable  | forgot base64 decode                            |
| Secret leaked in Git       | no secret-management workflow                   |

## 8. Fix

* create missing ConfigMap/Secret
* correct key name
* correct namespace
* restart Deployment for env var changes
* avoid subPath if live file updates are required
* use `stringData` for easier Secret manifests in dev
* use External Secrets/SOPS/Sealed Secrets/Vault for production

## Golden Rule

Config changes are not automatically application changes. Know whether the app reads config from env at startup or from files at runtime.

````

---

# 22. External Secret Concept

For production, avoid committing real Secrets to Git.

Common patterns:

```text id="r4chv3"
External Secrets Operator
Secrets Store CSI Driver
Sealed Secrets
SOPS with age/GPG/KMS
HashiCorp Vault
AWS Secrets Manager
GCP Secret Manager
Azure Key Vault
````

Kubernetes good practices recommend least-privilege access to Secrets and mention external secret store integrations such as the Secrets Store CSI Driver, which lets kubelet retrieve secrets from external stores and mount them into Pods. ([Kubernetes][6])

For your DevOps portfolio, say:

```text id="vvm1ty"
In Git, I keep secret.example.yaml only.
Real secrets are injected through a secure secret-management workflow.
```

---

# 23. Real Production Debug Mapping

```text id="wgjb36"
CreateContainerConfigError:
  check missing ConfigMap, missing Secret, wrong key, wrong namespace

Pod starts but env is wrong:
  check env/envFrom, key names, optional references, invalid env var names

ConfigMap updated but app still uses old env:
  restart Pod/Deployment because env vars are captured at container startup

Mounted config file updated but app behavior unchanged:
  app may not reload file; trigger reload or restart

subPath config not updating:
  expected Kubernetes behavior; restart Pod or avoid subPath for dynamic config

Secret value looks unreadable:
  it is base64-encoded; decode it

Secret committed in Git:
  security issue; rotate secret and move to secret manager workflow
```

---

# 24. Common Mistakes

## Mistake 1: Wrong namespace

```bash id="xue15p"
kubectl get configmap app-config -n dev
kubectl get configmap app-config -n production
```

ConfigMap and Secret references are namespaced.

---

## Mistake 2: Assuming env values update automatically

They do not.

Fix:

```bash id="k1yjc7"
kubectl rollout restart deployment/app -n namespace
```

---

## Mistake 3: Confusing Secret base64 with encryption

Base64 is encoding, not encryption.

---

## Mistake 4: Using `envFrom` with invalid key names

Keys like this are invalid env names:

```text id="ex2ppc"
invalid-key
app.name
```

Use:

```text id="d1f0ln"
APP_NAME
APP_ENV
LOG_LEVEL
```

---

## Mistake 5: Using `subPath` and expecting updates

`subPath` config mounts do not receive ConfigMap updates automatically. ([Kubernetes][4])

---

# 25. Interview Explanation

Use this:

```text id="hl8soh"
When troubleshooting ConfigMap and Secret injection, I first inspect the Pod status and events. If the Pod is in CreateContainerConfigError, I check whether the referenced ConfigMap or Secret exists in the same namespace and whether the exact key names match. I use kubectl describe pod to see missing object or missing key errors.

If the Pod starts but config is wrong, I check env, envFrom, mounted files, and invalid environment variable names. I know that environment variables from ConfigMaps and Secrets are captured at container startup, so updating the ConfigMap does not update existing container env values. For mounted files, updates can propagate, but applications must re-read the file, and subPath mounts do not receive updates automatically. For Secrets, I remember that data is base64-encoded, not encrypted, and production secrets should come from a secure secret-management workflow rather than plaintext Git manifests.
```

Resume bullet:

```text id="aalpby"
Built Kubernetes ConfigMap and Secret troubleshooting labs covering missing objects, wrong keys, env/envFrom injection, invalid environment names, mounted config files, stale env values, subPath update limitations, Secret base64 decoding, optional config, CreateContainerConfigError diagnosis, validation scripts, and production secret-management runbooks.
```

---

# 26. Commit Lesson 11.6

```bash id="mjyysp"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes ConfigMap and Secret troubleshooting labs"

git push
```

---

# 27. Next Lesson

```text id="rzfdck"
Lesson 11.7 — Probe Failure Troubleshooting
```

We will cover:

```text id="akib2b"
startupProbe failures
readinessProbe failures
livenessProbe failures
wrong path
wrong port
slow startup
dependency-based readiness
liveness killing healthy-but-slow apps
probe timeout/failureThreshold tuning
HTTP vs TCP vs exec probes
rollout stuck due to readiness
CrashLoopBackOff due to liveness
production probe debugging workflow
```

[1]: https://kubernetes.io/docs/concepts/configuration/configmap/?utm_source=chatgpt.com "ConfigMaps"
[2]: https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/?utm_source=chatgpt.com "Define Environment Variables for a Container"
[3]: https://v1-33.docs.kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/?utm_source=chatgpt.com "Configure a Pod to Use a ConfigMap"
[4]: https://kubernetes.io/docs/concepts/storage/volumes/?utm_source=chatgpt.com "Volumes"
[5]: https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-config-file/?utm_source=chatgpt.com "Managing Secrets using Configuration File"
[6]: https://kubernetes.io/docs/concepts/security/secrets-good-practices/?utm_source=chatgpt.com "Good practices for Kubernetes Secrets"
