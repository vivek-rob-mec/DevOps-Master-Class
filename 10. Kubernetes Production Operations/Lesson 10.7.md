# Lesson 10.7 — ConfigMaps, Secrets, Environment Injection, Mounted Config, and Secret Management Patterns

In Lesson 10.6, you learned how external traffic enters Kubernetes through **Ingress**.

Now we learn how applications receive configuration and sensitive values.

This is a major production topic because almost every real application needs:

```text id="ny3gx7"
environment variables
feature flags
database URLs
API URLs
log levels
runtime modes
tokens
passwords
TLS files
config files
secret files
```

Kubernetes separates configuration from container images using **ConfigMaps** and stores sensitive values using **Secrets**. A ConfigMap is meant for non-sensitive configuration data, while a Secret is intended for sensitive data such as passwords, tokens, or keys. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="kt0t5z"
10.7.1   ConfigMap mental model
10.7.2   Secret mental model
10.7.3   ConfigMap vs Secret
10.7.4   env vs envFrom
10.7.5   valueFrom with configMapKeyRef
10.7.6   valueFrom with secretKeyRef
10.7.7   Mounting ConfigMaps as files
10.7.8   Mounting Secrets as files
10.7.9   Secret base64 confusion
10.7.10  Why Kubernetes Secrets are not enough by default
10.7.11  Config update behavior
10.7.12  Why env var config does not update automatically
10.7.13  Restart on config changes
10.7.14  Immutable config idea
10.7.15  Production config pattern for demo-node-api
10.7.16  Validation script
10.7.17  Cleanup script
```

---

# 2. Create Lesson Folder

```bash id="mih7sw"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.7-configmaps-secrets-config-injection/{manifests,scripts,notes,runbooks,reports,files}
```

Check:

```bash id="vfxzxy"
tree -L 2 10.7-configmaps-secrets-config-injection
```

---

# 3. ConfigMap Mental Model

A ConfigMap stores **non-secret configuration**.

Examples:

```text id="qevd5j"
NODE_ENV=production
LOG_LEVEL=info
APP_PORT=3002
API_BASE_URL=https://api.example.com
FEATURE_TODO_DELETE=true
config.json
nginx.conf
application.properties
```

A ConfigMap lets you decouple configuration from the container image so the same image can run in different environments with different settings. Kubernetes docs describe ConfigMaps as a way to inject configuration data into Pods and keep containerized applications portable across environments. ([Kubernetes][1])

Bad pattern:

```text id="2h334q"
Build one image for dev.
Build another image for staging.
Build another image for production.
```

Better pattern:

```text id="c9y0lr"
Build one image.
Change runtime config using ConfigMap and Secret.
```

Example:

```text id="6no6zq"
same image:
  demo-node-api:1.0.0

dev config:
  LOG_LEVEL=debug
  MONGO_HOST=dev-db

production config:
  LOG_LEVEL=info
  MONGO_HOST=prod-db
```

Golden rule:

```text id="2j990o"
Configuration changes should not require rebuilding the application image.
```

---

# 4. Secret Mental Model

A Secret stores sensitive data.

Examples:

```text id="779s4d"
database password
JWT secret
API token
OAuth client secret
TLS private key
SSH private key
Docker registry credentials
```

A Secret lets you avoid putting confidential values directly in application code, Pod specs, or container images. Kubernetes Secrets are specifically intended to hold confidential data, unlike ConfigMaps, which are for non-sensitive configuration. ([Kubernetes][2])

Bad pattern:

```yaml id="u8vqsz"
env:
  - name: DB_PASSWORD
    value: "my-prod-password"
```

Better pattern:

```yaml id="hq4w48"
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: demo-node-api-secret
        key: DB_PASSWORD
```

Important warning:

```text id="y6jdeh"
Kubernetes Secret is not magic encryption.
```

By default, Kubernetes Secrets are stored unencrypted in the API server’s backing datastore, etcd. Kubernetes recommends enabling encryption at rest, using least-privilege RBAC, restricting Secret access to specific containers, and considering external secret store providers. ([Kubernetes][2])

---

# 5. ConfigMap vs Secret

| Feature                      | ConfigMap                     | Secret                              |
| ---------------------------- | ----------------------------- | ----------------------------------- |
| Purpose                      | Non-sensitive config          | Sensitive config                    |
| Examples                     | log level, port, feature flag | password, token, private key        |
| Base64 required in YAML      | No                            | Usually yes for `data`              |
| Can be env vars              | Yes                           | Yes                                 |
| Can be mounted as files      | Yes                           | Yes                                 |
| Should be committed to Git   | Usually yes                   | Usually no, unless encrypted/sealed |
| Requires strict RBAC         | Moderate                      | Very strict                         |
| Encrypted by default in etcd | No                            | No, unless configured               |
| External manager recommended | Optional                      | Often yes                           |

Golden rule:

```text id="m9dq2o"
Use ConfigMap for non-sensitive values.
Use Secret for sensitive values.
Do not confuse base64 encoding with encryption.
```

---

# 6. Create Notes

```bash id="zwkn8e"
nano 10.7-configmaps-secrets-config-injection/notes/configmap-secret-mental-model.md
```

Paste:

```markdown id="c48ajw"
# ConfigMap and Secret Mental Model

## ConfigMap

ConfigMap stores non-sensitive configuration.

Examples:

- LOG_LEVEL
- APP_PORT
- FEATURE_FLAG
- config.json
- nginx.conf

## Secret

Secret stores sensitive data.

Examples:

- passwords
- tokens
- private keys
- database credentials

## Golden Rules

- Do not bake environment config into images.
- Do not store passwords in ConfigMaps.
- Do not commit plaintext production Secrets to Git.
- Base64 is encoding, not encryption.
- Use RBAC and encryption at rest for Secrets.
- Use external secret managers for serious production systems.

## Injection Methods

- env
- envFrom
- configMapKeyRef
- secretKeyRef
- volume mount
```

---

# 7. Create ConfigMap from YAML

Create:

```bash id="v51u9e"
nano 10.7-configmaps-secrets-config-injection/manifests/demo-configmap.yaml
```

Paste:

```yaml id="e7wwvd"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-app-config
  namespace: dev
  labels:
    app: config-demo
data:
  APP_NAME: "config-demo"
  APP_ENV: "dev"
  LOG_LEVEL: "debug"
  APP_PORT: "8080"
  FEATURE_GREETING: "true"
  config.json: |
    {
      "message": "Hello from ConfigMap file",
      "featureGreeting": true,
      "owner": "platform-team"
    }
```

Apply:

```bash id="hzfow1"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/demo-configmap.yaml
```

Inspect:

```bash id="ir5cip"
kubectl get configmap demo-app-config -n dev
kubectl describe configmap demo-app-config -n dev
kubectl get configmap demo-app-config -n dev -o yaml
```

---

# 8. Create Secret from YAML Using `stringData`

For learning, use `stringData` because it is readable. Kubernetes converts it into encoded `data` when storing the Secret.

Create:

```bash id="yzfo7z"
nano 10.7-configmaps-secrets-config-injection/manifests/demo-secret.yaml
```

Paste:

```yaml id="j0mrjt"
apiVersion: v1
kind: Secret
metadata:
  name: demo-app-secret
  namespace: dev
  labels:
    app: config-demo
type: Opaque
stringData:
  DB_USERNAME: "demo_user"
  DB_PASSWORD: "demo_password"
  API_TOKEN: "demo-token-123"
  JWT_SECRET: "local-jwt-secret"
```

Apply:

```bash id="05h7zf"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/demo-secret.yaml
```

Inspect:

```bash id="l7v6o6"
kubectl get secret demo-app-secret -n dev
kubectl describe secret demo-app-secret -n dev
kubectl get secret demo-app-secret -n dev -o yaml
```

You will see encoded values under:

```yaml id="r16gmi"
data:
```

Decode one value:

```bash id="9mln1x"
kubectl get secret demo-app-secret -n dev \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo
```

Important:

```text id="2lbixe"
If you can base64 decode it, it is not encryption.
```

Kubernetes good-practice docs explicitly state that Secret values are base64 encoded and stored unencrypted by default unless encryption at rest is configured. ([Kubernetes][3])

---

# 9. Create ConfigMap Using kubectl Literal

You can also create ConfigMaps from literals.

```bash id="cv7d5q"
kubectl create configmap literal-config-demo \
  -n dev \
  --from-literal=APP_ENV=dev \
  --from-literal=LOG_LEVEL=info \
  --from-literal=FEATURE_X=true
```

Check:

```bash id="muglxg"
kubectl get configmap literal-config-demo -n dev -o yaml
```

Delete after observing:

```bash id="60dq9c"
kubectl delete configmap literal-config-demo -n dev
```

The `kubectl create configmap` command can create a ConfigMap from literal values, files, or directories. ([Kubernetes][4])

---

# 10. Create Secret Using kubectl Literal

```bash id="3j7224"
kubectl create secret generic literal-secret-demo \
  -n dev \
  --from-literal=USERNAME=admin \
  --from-literal=PASSWORD=local-password
```

Check:

```bash id="aolq9n"
kubectl get secret literal-secret-demo -n dev -o yaml
```

Decode:

```bash id="k2tl6w"
kubectl get secret literal-secret-demo -n dev \
  -o jsonpath='{.data.PASSWORD}' | base64 -d
echo
```

Delete:

```bash id="hm7k58"
kubectl delete secret literal-secret-demo -n dev
```

The `kubectl create secret generic` command creates a Secret from literal values, files, or directories. ([Kubernetes][5])

---

# 11. envFrom — Inject All ConfigMap Keys

`envFrom` injects all keys from a ConfigMap or Secret as environment variables.

Create Deployment:

```bash id="n68w4l"
nano 10.7-configmaps-secrets-config-injection/manifests/envfrom-configmap-deployment.yaml
```

Paste:

```yaml id="g8xrhf"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envfrom-config-demo
  namespace: dev
  labels:
    app: envfrom-config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: envfrom-config-demo
  template:
    metadata:
      labels:
        app: envfrom-config-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command: ["sh", "-c", "env | sort && sleep 3600"]
          envFrom:
            - configMapRef:
                name: demo-app-config
```

Apply:

```bash id="2v7xpl"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-configmap-deployment.yaml
```

Check logs:

```bash id="d12236"
kubectl logs -n dev deployment/envfrom-config-demo
```

You should see:

```text id="5h4sfq"
APP_NAME=config-demo
APP_ENV=dev
LOG_LEVEL=debug
APP_PORT=8080
FEATURE_GREETING=true
```

Kubernetes lets you set environment variables with `env` or `envFrom`; `envFrom` imports all key-value pairs from a referenced ConfigMap or Secret, while `env` lets you define specific variables. ([Kubernetes][6])

---

# 12. envFrom — Inject All Secret Keys

Create:

```bash id="11b9v1"
nano 10.7-configmaps-secrets-config-injection/manifests/envfrom-secret-deployment.yaml
```

Paste:

```yaml id="ge2kec"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envfrom-secret-demo
  namespace: dev
  labels:
    app: envfrom-secret-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: envfrom-secret-demo
  template:
    metadata:
      labels:
        app: envfrom-secret-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "DB_USERNAME=$DB_USERNAME"
              echo "DB_PASSWORD is set but hidden"
              echo "API_TOKEN is set but hidden"
              sleep 3600
          envFrom:
            - secretRef:
                name: demo-app-secret
```

Apply:

```bash id="1155z9"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-secret-deployment.yaml
```

Logs:

```bash id="97a2qi"
kubectl logs -n dev deployment/envfrom-secret-demo
```

Important warning:

```text id="qo3esk"
Do not print actual secrets in logs.
This lab intentionally avoids echoing the secret value.
```

---

# 13. valueFrom — Inject Specific ConfigMap Key

`envFrom` is convenient, but sometimes too broad.

Better production pattern:

```text id="79bi5p"
Inject only the exact keys the container needs.
```

Create:

```bash id="22bjvj"
nano 10.7-configmaps-secrets-config-injection/manifests/specific-configmap-key-deployment.yaml
```

Paste:

```yaml id="9gypdr"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: specific-config-demo
  namespace: dev
  labels:
    app: specific-config-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: specific-config-demo
  template:
    metadata:
      labels:
        app: specific-config-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "APP_ENV=$APP_ENV"
              echo "LOG_LEVEL=$LOG_LEVEL"
              sleep 3600
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: demo-app-config
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: demo-app-config
                  key: LOG_LEVEL
```

Apply:

```bash id="v174bk"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/specific-configmap-key-deployment.yaml
```

Logs:

```bash id="tvzs15"
kubectl logs -n dev deployment/specific-config-demo
```

---

# 14. valueFrom — Inject Specific Secret Key

Create:

```bash id="avqhqb"
nano 10.7-configmaps-secrets-config-injection/manifests/specific-secret-key-deployment.yaml
```

Paste:

```yaml id="74bcm5"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: specific-secret-demo
  namespace: dev
  labels:
    app: specific-secret-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: specific-secret-demo
  template:
    metadata:
      labels:
        app: specific-secret-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "DB_USERNAME=$DB_USERNAME"
              echo "DB_PASSWORD is available but not printed"
              sleep 3600
          env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: demo-app-secret
                  key: DB_USERNAME
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: demo-app-secret
                  key: DB_PASSWORD
```

Apply:

```bash id="r4a84a"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/specific-secret-key-deployment.yaml
```

Logs:

```bash id="u6loqa"
kubectl logs -n dev deployment/specific-secret-demo
```

Production rule:

```text id="lnntm1"
Prefer specific secretKeyRef over envFrom for sensitive values.
```

Why?

```text id="3zsrqu"
envFrom gives the container every key in the Secret.
secretKeyRef gives only what the container needs.
```

---

# 15. Mount ConfigMap as Files

ConfigMaps can also appear as files inside the container. Kubernetes docs describe ConfigMaps as key-value data that can be consumed by Pods, including through volumes where each data item can appear as a file. ([Kubernetes][1])

Create:

```bash id="9em9yb"
nano 10.7-configmaps-secrets-config-injection/manifests/configmap-volume-deployment.yaml
```

Paste:

```yaml id="1ogf0d"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configmap-volume-demo
  namespace: dev
  labels:
    app: configmap-volume-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: configmap-volume-demo
  template:
    metadata:
      labels:
        app: configmap-volume-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Listing mounted config:"
              ls -la /etc/app-config
              echo "config.json:"
              cat /etc/app-config/config.json
              sleep 3600
          volumeMounts:
            - name: app-config
              mountPath: /etc/app-config
              readOnly: true
      volumes:
        - name: app-config
          configMap:
            name: demo-app-config
```

Apply:

```bash id="1uhvci"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/configmap-volume-deployment.yaml
```

Logs:

```bash id="zy49ku"
kubectl logs -n dev deployment/configmap-volume-demo
```

Exec:

```bash id="0r0tjs"
POD_NAME="$(kubectl get pod -n dev -l app=configmap-volume-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -it "$POD_NAME" -n dev -- sh
```

Inside:

```sh id="fz1a3r"
ls -la /etc/app-config
cat /etc/app-config/config.json
cat /etc/app-config/LOG_LEVEL
exit
```

---

# 16. Mount Secret as Files

Secrets can also be mounted as files. Kubernetes docs describe using Secrets as files from a Pod, where Kubernetes makes Secret values available in the container filesystem. ([Kubernetes][2])

Create:

```bash id="5zgwo7"
nano 10.7-configmaps-secrets-config-injection/manifests/secret-volume-deployment.yaml
```

Paste:

```yaml id="sw7ul1"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-volume-demo
  namespace: dev
  labels:
    app: secret-volume-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-volume-demo
  template:
    metadata:
      labels:
        app: secret-volume-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Listing mounted secret files:"
              ls -la /etc/app-secret
              echo "Secret files exist, but values are not printed"
              sleep 3600
          volumeMounts:
            - name: app-secret
              mountPath: /etc/app-secret
              readOnly: true
      volumes:
        - name: app-secret
          secret:
            secretName: demo-app-secret
```

Apply:

```bash id="9yrnw7"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-deployment.yaml
```

Logs:

```bash id="82s3qs"
kubectl logs -n dev deployment/secret-volume-demo
```

Exec:

```bash id="6vwg2i"
POD_NAME="$(kubectl get pod -n dev -l app=secret-volume-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -it "$POD_NAME" -n dev -- sh
```

Inside:

```sh id="8k39wy"
ls -la /etc/app-secret
exit
```

Do not casually run:

```sh id="u0f0dz"
cat /etc/app-secret/DB_PASSWORD
```

in shared terminals, recordings, CI logs, or screenshots.

---

# 17. File Permissions for Secrets

Create a Secret volume with controlled file mode.

```bash id="kg7btt"
nano 10.7-configmaps-secrets-config-injection/manifests/secret-volume-permissions-deployment.yaml
```

Paste:

```yaml id="yijvu7"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-permission-demo
  namespace: dev
  labels:
    app: secret-permission-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-permission-demo
  template:
    metadata:
      labels:
        app: secret-permission-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              ls -la /etc/app-secret
              sleep 3600
          volumeMounts:
            - name: app-secret
              mountPath: /etc/app-secret
              readOnly: true
      volumes:
        - name: app-secret
          secret:
            secretName: demo-app-secret
            defaultMode: 0400
```

Apply:

```bash id="qv1wm9"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-permissions-deployment.yaml
```

Logs:

```bash id="4okh5i"
kubectl logs -n dev deployment/secret-permission-demo
```

Expected permissions:

```text id="z3fc82"
-r--------
```

Production rule:

```text id="v9ckax"
Mount Secret files read-only and with restrictive permissions.
```

---

# 18. Config Update Behavior

This is where many people get confused.

There are two common ways to consume ConfigMaps and Secrets:

```text id="4h1frj"
Environment variables
Volume-mounted files
```

Behavior is different.

## Environment Variables

If a ConfigMap or Secret is used as environment variables:

```text id="anj2o2"
Pod gets values at container startup.
Existing running container does not automatically get updated env vars.
```

To pick up changed env vars:

```text id="asw5cm"
restart Pod
rollout restart Deployment
create new Pods
```

## Volume-Mounted ConfigMap or Secret

If mounted as files:

```text id="z38suq"
Kubernetes can update projected files eventually.
Application must reread the file to notice the change.
```

Kubernetes docs state that Secret data mounted as a volume is updated eventually when the Secret changes, but containers using a Secret as a `subPath` volume mount do not receive automated updates. The same update pattern is also demonstrated for ConfigMaps mounted as volumes. ([Kubernetes][2])

---

# 19. Demonstrate ConfigMap Update with Env Var

Check current logs:

```bash id="6kymew"
kubectl logs -n dev deployment/envfrom-config-demo
```

Change ConfigMap:

```bash id="6afvz1"
kubectl patch configmap demo-app-config -n dev \
  --type merge \
  -p '{"data":{"LOG_LEVEL":"warn"}}'
```

Restart logs:

```bash id="tcw30o"
kubectl logs -n dev deployment/envfrom-config-demo
```

You may still see old environment values because the running container already started.

Restart Deployment:

```bash id="zymfwh"
kubectl rollout restart deployment/envfrom-config-demo -n dev
kubectl rollout status deployment/envfrom-config-demo -n dev
```

Check logs again:

```bash id="wba7rm"
kubectl logs -n dev deployment/envfrom-config-demo
```

Expected:

```text id="paikzc"
LOG_LEVEL=warn
```

Golden rule:

```text id="bmakzh"
Env var config changes require Pod restart.
```

---

# 20. Demonstrate ConfigMap Update with Volume

Patch ConfigMap file data:

```bash id="pg44vd"
kubectl patch configmap demo-app-config -n dev \
  --type merge \
  -p '{"data":{"config.json":"{\"message\":\"Updated ConfigMap file\",\"featureGreeting\":false,\"owner\":\"platform-team\"}"}}'
```

Exec into mounted ConfigMap Pod:

```bash id="n8yalj"
POD_NAME="$(kubectl get pod -n dev -l app=configmap-volume-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -it "$POD_NAME" -n dev -- sh
```

Inside:

```sh id="i1bir8"
cat /etc/app-config/config.json
exit
```

If you do not see it immediately, wait and retry. Mounted ConfigMap updates are eventually consistent.

Important:

```text id="t2v03e"
File may update, but your app must reload or reread the file.
Kubernetes does not automatically restart your app when ConfigMap changes.
```

---

# 21. Rollout Restart on Config Change

The simple manual pattern:

```bash id="gco1rh"
kubectl rollout restart deployment/configmap-volume-demo -n dev
kubectl rollout status deployment/configmap-volume-demo -n dev
```

Production patterns:

```text id="w2oyvp"
Manual rollout restart
Helm checksum annotation
Kustomize configMapGenerator name hash
External controllers like Reloader
GitOps sync with new generated config name
```

Simple checksum idea:

```yaml id="371o7h"
template:
  metadata:
    annotations:
      config-checksum: "abc123"
```

When the annotation changes, the Pod template changes, causing a rollout.

Kubernetes Deployments create a new rollout when the Pod template changes, so changing an annotation under `spec.template.metadata.annotations` is enough to create new Pods.

---

# 22. Immutable ConfigMaps and Secrets

You can mark ConfigMaps and Secrets as immutable.

Example:

```yaml id="yr4qqs"
immutable: true
```

Why?

```text id="eyuakz"
prevents accidental changes
improves safety for stable release config
forces versioned config replacement
can reduce kubelet watching load in large clusters
```

Create immutable ConfigMap:

```bash id="srwsb7"
nano 10.7-configmaps-secrets-config-injection/manifests/immutable-configmap.yaml
```

Paste:

```yaml id="oc1vw1"
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-demo-config
  namespace: dev
data:
  RELEASE_MODE: "stable"
immutable: true
```

Apply:

```bash id="5q5akh"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/immutable-configmap.yaml
```

Try to patch:

```bash id="wd5r9d"
kubectl patch configmap immutable-demo-config -n dev \
  --type merge \
  -p '{"data":{"RELEASE_MODE":"changed"}}' || true
```

Expected:

```text id="z92w1o"
Update rejected because ConfigMap is immutable.
```

Production pattern:

```text id="s37y3h"
Instead of editing immutable config:
  create new ConfigMap name
  update Deployment reference
  roll out new Pods
```

---

# 23. Secret Base64 Confusion

Manual base64 encode:

```bash id="98b1r6"
echo -n "my-password" | base64
```

Decode:

```bash id="c5y7eq"
echo "bXktcGFzc3dvcmQ=" | base64 -d
echo
```

Important:

```text id="fx3nom"
base64 is reversible encoding.
It is not encryption.
It does not require a key.
Anyone who can read the Secret can decode it.
```

Bad misconception:

```text id="i1eej7"
Kubernetes Secret is safe because it is base64 encoded.
```

Correct:

```text id="hx5acp"
Kubernetes Secret is safer than putting plaintext in Pod YAML,
but it still needs RBAC, encryption at rest, audit, and often external secret management.
```

---

# 24. Secret Security Production Checklist

Create:

```bash id="o3p41q"
nano 10.7-configmaps-secrets-config-injection/runbooks/secret-security-checklist.md
```

Paste:

```markdown id="jnyj17"
# Kubernetes Secret Security Checklist

## Do

- Use Secrets for sensitive values.
- Restrict Secret access with RBAC.
- Enable encryption at rest.
- Avoid printing secrets in logs.
- Mount only required Secrets.
- Prefer specific secretKeyRef over broad envFrom.
- Rotate Secrets regularly.
- Use short-lived credentials where possible.
- Consider external secret managers.
- Keep production plaintext Secrets out of Git.

## Do Not

- Do not store passwords in ConfigMaps.
- Do not treat base64 as encryption.
- Do not give broad list/watch access to Secrets.
- Do not echo Secrets in CI/CD logs.
- Do not mount all Secrets into all Pods.
- Do not use one giant Secret for every application.

## Production Tools to Learn Later

- External Secrets Operator
- Secrets Store CSI Driver
- AWS Secrets Manager
- HashiCorp Vault
- Sealed Secrets
- SOPS
```

---

# 25. Config Debugging Runbook

Create:

```bash id="ayt6ml"
nano 10.7-configmaps-secrets-config-injection/runbooks/config-debugging-runbook.md
```

Paste:

````markdown id="bqvmyg"
# ConfigMap and Secret Debugging Runbook

## Step 1 — Check Object Exists

```bash
kubectl get configmap -n NAMESPACE
kubectl get secret -n NAMESPACE
````

## Step 2 — Inspect Non-Secret Config

```bash id="z3n3pk"
kubectl describe configmap CONFIG_NAME -n NAMESPACE
kubectl get configmap CONFIG_NAME -n NAMESPACE -o yaml
```

## Step 3 — Inspect Secret Metadata Safely

```bash id="raua6b"
kubectl describe secret SECRET_NAME -n NAMESPACE
```

Avoid printing secret values in shared terminals.

## Step 4 — Check Pod References

```bash id="qomijm"
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get pod POD_NAME -n NAMESPACE -o yaml
```

Look for:

* env
* envFrom
* configMapKeyRef
* secretKeyRef
* volumes
* volumeMounts

## Step 5 — Check Env Vars Inside Pod

```bash id="qvkb4b"
kubectl exec -it POD_NAME -n NAMESPACE -- env | sort
```

Do not print sensitive values.

## Step 6 — Check Mounted Files

```bash id="1tug4l"
kubectl exec -it POD_NAME -n NAMESPACE -- ls -la /etc/app-config
kubectl exec -it POD_NAME -n NAMESPACE -- ls -la /etc/app-secret
```

## Common Problems

| Symptom                     | Likely Cause                          |
| --------------------------- | ------------------------------------- |
| Pod fails to start          | referenced ConfigMap/Secret missing   |
| Env value old               | Pod not restarted after config change |
| File value old              | waiting for volume projection update  |
| Secret decode surprises you | base64 is encoding                    |
| App cannot read file        | mount path or permission problem      |
| Wrong environment config    | namespace or overlay mistake          |

## Golden Rule

Check object, namespace, reference name, key name, Pod env, volume mounts, and rollout state.

````

---

# 26. Create Missing ConfigMap Failure Demo

Create a Pod that references a missing ConfigMap.

```bash id="1tiu9j"
nano 10.7-configmaps-secrets-config-injection/manifests/missing-configmap-pod.yaml
````

Paste:

```yaml id="ondj6t"
apiVersion: v1
kind: Pod
metadata:
  name: missing-configmap-demo
  namespace: dev
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo should not start && sleep 3600"]
      env:
        - name: MISSING_VALUE
          valueFrom:
            configMapKeyRef:
              name: does-not-exist
              key: SOME_KEY
```

Apply:

```bash id="f8xk13"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/missing-configmap-pod.yaml
```

Check:

```bash id="ob1uug"
kubectl get pod missing-configmap-demo -n dev
kubectl describe pod missing-configmap-demo -n dev
kubectl get events -n dev --sort-by=.lastTimestamp
```

Expected:

```text id="zs6q2j"
Pod will not start correctly because the required ConfigMap key cannot be found.
```

Delete:

```bash id="1igk85"
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/missing-configmap-pod.yaml
```

---

# 27. Optional ConfigMap Reference

You can make a reference optional.

Create:

```bash id="qyui1s"
nano 10.7-configmaps-secrets-config-injection/manifests/optional-configmap-pod.yaml
```

Paste:

```yaml id="j86lk0"
apiVersion: v1
kind: Pod
metadata:
  name: optional-configmap-demo
  namespace: dev
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo Optional config demo started; env | grep OPTIONAL || true; sleep 3600"]
      env:
        - name: OPTIONAL_VALUE
          valueFrom:
            configMapKeyRef:
              name: does-not-exist
              key: SOME_KEY
              optional: true
```

Apply:

```bash id="iccn4l"
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/optional-configmap-pod.yaml
```

Check:

```bash id="nnwd1l"
kubectl get pod optional-configmap-demo -n dev
kubectl logs optional-configmap-demo -n dev
```

Delete:

```bash id="whe1dx"
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/optional-configmap-pod.yaml
```

Production warning:

```text id="4rszpk"
Use optional references carefully.
They can hide missing configuration mistakes.
```

---

# 28. Production Pattern for `demo-node-api`

Now update your Kubernetes app base.

Create ConfigMap:

```bash id="pstw1l"
nano apps/demo-node-api/base/configmap.yaml
```

Paste:

```yaml id="lo5ai6"
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-node-api-config
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
data:
  NODE_ENV: "production"
  APP_PORT: "3002"
  LOG_LEVEL: "info"
  API_VERSION: "v1"
  CORS_ORIGIN: "http://localhost:3000"
```

Create Secret template:

```bash id="j93mi6"
nano apps/demo-node-api/base/secret.example.yaml
```

Paste:

```yaml id="77yq5m"
apiVersion: v1
kind: Secret
metadata:
  name: demo-node-api-secret
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
type: Opaque
stringData:
  MONGO_URI: "mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo"
  JWT_SECRET: "replace-me"
```

Important:

```text id="n86kuh"
This is an example file.
Do not commit real production secrets in plaintext.
```

Now update Deployment:

```bash id="v613cb"
nano apps/demo-node-api/base/deployment.yaml
```

Use this improved version:

```yaml id="0v0ueo"
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
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: demo-node-api
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: todo-app
        environment: dev
      annotations:
        kubernetes.io/change-cause: "Add ConfigMap and Secret based runtime configuration"
    spec:
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
```

Do not apply this yet unless you have loaded the `demo-node-api:0.1.0` image into kind and created the Secret.

---

# 29. Local Secret Creation for `demo-node-api`

For local dev only:

```bash id="utqu7q"
kubectl create secret generic demo-node-api-secret \
  -n dev \
  --from-literal=MONGO_URI='mongodb://demo-user:demo-password@mongodb.dev.svc.cluster.local:27017/todo' \
  --from-literal=JWT_SECRET='local-dev-jwt-secret' \
  --dry-run=client \
  -o yaml > apps/demo-node-api/base/secret.local.generated.yaml
```

Apply local generated Secret:

```bash id="o9ygjf"
kubectl apply -f apps/demo-node-api/base/secret.local.generated.yaml
```

Add to `.gitignore` from repo root:

```bash id="slm4rd"
cd ~/devops-masterclass

cat >> .gitignore <<'EOF'

# Local Kubernetes generated secrets
**/secret.local.generated.yaml
EOF
```

Production rule:

```text id="57rgap"
Commit secret.example.yaml.
Do not commit secret.local.generated.yaml or production plaintext secrets.
```

---

# 30. Create Config Update Runbook

```bash id="11h4qs"
nano 10.7-configmaps-secrets-config-injection/runbooks/config-update-rollout-runbook.md
```

Paste:

````markdown id="oiukup"
# Config Update and Rollout Runbook

## Problem

ConfigMap or Secret changed, but application still uses old values.

## Reason

Environment variables are loaded when the container starts.

## Fix

Restart the workload:

```bash
kubectl rollout restart deployment/APP -n NAMESPACE
kubectl rollout status deployment/APP -n NAMESPACE
````

## For Volume-Mounted Config

Kubernetes eventually updates projected files, but the application must reread the file.

## Production Patterns

* Helm checksum annotation
* Kustomize configMapGenerator name hash
* Reloader controller
* manual rollout restart
* GitOps commit changing Pod template annotation

## Safe Production Steps

1. Update ConfigMap or Secret.
2. Trigger rollout.
3. Watch rollout status.
4. Check app logs.
5. Verify health endpoint.
6. Verify metrics.
7. Roll back if needed.

````

---

# 31. Create Production Secret Management Notes

```bash id="3nd3ao"
nano 10.7-configmaps-secrets-config-injection/notes/production-secret-management-patterns.md
````

Paste:

```markdown id="sx5u96"
# Production Secret Management Patterns

## Local Learning

Use Kubernetes Secret manifests with fake values.

## Small Internal Dev

Use kubectl create secret or sealed/encrypted manifests.

## Production

Prefer:

- external secret manager
- cloud KMS
- encryption at rest
- least-privilege RBAC
- short-lived credentials
- audit logging
- secret rotation

## Common Tools

- AWS Secrets Manager
- AWS Systems Manager Parameter Store
- HashiCorp Vault
- External Secrets Operator
- Secrets Store CSI Driver
- Sealed Secrets
- SOPS

## Rules

- Do not commit plaintext production Secrets.
- Do not print Secrets in logs.
- Do not give broad read/list/watch access to Secrets.
- Do not reuse one Secret across unrelated apps.
- Rotate Secrets after exposure.
```

---

# 32. Validation Script

Create:

```bash id="cpj8ga"
nano 10.7-configmaps-secrets-config-injection/scripts/validate-lesson-10-7.sh
```

Paste:

```bash id="d2bpvx"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.7 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get configmap demo-app-config -n dev >/dev/null
kubectl get secret demo-app-secret -n dev >/dev/null

kubectl get deployment envfrom-config-demo -n dev >/dev/null
kubectl get deployment envfrom-secret-demo -n dev >/dev/null
kubectl get deployment specific-config-demo -n dev >/dev/null
kubectl get deployment specific-secret-demo -n dev >/dev/null
kubectl get deployment configmap-volume-demo -n dev >/dev/null
kubectl get deployment secret-volume-demo -n dev >/dev/null
kubectl get deployment secret-permission-demo -n dev >/dev/null

CONFIG_VALUE="$(kubectl get configmap demo-app-config -n dev -o jsonpath='{.data.APP_ENV}')"
if [ "$CONFIG_VALUE" != "dev" ]; then
  echo "ERROR: demo-app-config APP_ENV should be dev"
  exit 1
fi

SECRET_KEY_COUNT="$(kubectl get secret demo-app-secret -n dev -o jsonpath='{.data}' | jq 'keys | length')"
if [ "$SECRET_KEY_COUNT" -lt 4 ]; then
  echo "ERROR: expected at least 4 keys in demo-app-secret"
  exit 1
fi

CM_VOLUME_POD="$(kubectl get pod -n dev -l app=configmap-volume-demo -o jsonpath='{.items[0].metadata.name}')"
SECRET_VOLUME_POD="$(kubectl get pod -n dev -l app=secret-volume-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$CM_VOLUME_POD" -n dev -- test -f /etc/app-config/config.json
kubectl exec "$SECRET_VOLUME_POD" -n dev -- test -f /etc/app-secret/DB_PASSWORD

test -f 10.7-configmaps-secrets-config-injection/notes/configmap-secret-mental-model.md
test -f 10.7-configmaps-secrets-config-injection/notes/production-secret-management-patterns.md
test -f 10.7-configmaps-secrets-config-injection/runbooks/config-debugging-runbook.md
test -f 10.7-configmaps-secrets-config-injection/runbooks/config-update-rollout-runbook.md
test -f 10.7-configmaps-secrets-config-injection/runbooks/secret-security-checklist.md

test -f apps/demo-node-api/base/configmap.yaml
test -f apps/demo-node-api/base/secret.example.yaml
test -f apps/demo-node-api/base/deployment.yaml

echo "Lesson 10.7 validation passed."
```

Make executable:

```bash id="5nveps"
chmod +x 10.7-configmaps-secrets-config-injection/scripts/validate-lesson-10-7.sh
```

Run:

```bash id="c24u5d"
./10.7-configmaps-secrets-config-injection/scripts/validate-lesson-10-7.sh
```

---

# 33. Cleanup Script

Create:

```bash id="i929ae"
nano 10.7-configmaps-secrets-config-injection/scripts/cleanup-lesson-10-7.sh
```

Paste:

```bash id="fpnerr"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.7 ====="

kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/missing-configmap-pod.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/optional-configmap-pod.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/immutable-configmap.yaml --ignore-not-found=true

kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-permissions-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/configmap-volume-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/specific-secret-key-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/specific-configmap-key-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-secret-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-configmap-deployment.yaml --ignore-not-found=true

kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/demo-secret.yaml --ignore-not-found=true
kubectl delete -f 10.7-configmaps-secrets-config-injection/manifests/demo-configmap.yaml --ignore-not-found=true

kubectl delete secret demo-node-api-secret -n dev --ignore-not-found=true

echo "Lesson 10.7 resources cleaned."
echo "Namespace dev and cluster kept for next lessons."
```

Make executable:

```bash id="g1t2j8"
chmod +x 10.7-configmaps-secrets-config-injection/scripts/cleanup-lesson-10-7.sh
```

Run only if you want cleanup:

```bash id="drrkov"
./10.7-configmaps-secrets-config-injection/scripts/cleanup-lesson-10-7.sh
```

---

# 34. Practical Lab Summary

Run the main lab:

```bash id="xu28ko"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/demo-configmap.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/demo-secret.yaml

kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-configmap-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/envfrom-secret-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/specific-configmap-key-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/specific-secret-key-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/configmap-volume-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-deployment.yaml
kubectl apply -f 10.7-configmaps-secrets-config-injection/manifests/secret-volume-permissions-deployment.yaml

./10.7-configmaps-secrets-config-injection/scripts/validate-lesson-10-7.sh
```

Inspect:

```bash id="a6mjbr"
kubectl get configmap,secret -n dev
kubectl get deployments -n dev | grep demo
kubectl logs -n dev deployment/envfrom-config-demo
kubectl logs -n dev deployment/configmap-volume-demo
```

---

# 35. Common Myths and Misconceptions

## Myth 1: ConfigMap is for every config value

Wrong.

```text id="4s8xg4"
ConfigMap is for non-sensitive config.
Sensitive config belongs in Secret or external secret manager.
```

## Myth 2: Kubernetes Secret is encrypted because values look unreadable

Wrong.

```text id="vlljk6"
Secret values are base64 encoded.
Base64 is not encryption.
```

## Myth 3: Updating ConfigMap automatically updates app env vars

Wrong.

```text id="xmi61j"
Env vars are loaded at container startup.
Restart Pods to pick up changed env vars.
```

## Myth 4: Mounted config update means app reloads automatically

Wrong.

```text id="3btgaf"
Kubernetes may update mounted files.
Your app still must reread or reload the file.
```

## Myth 5: Secrets are safe if RBAC allows many users to list them

Wrong.

```text id="aaz05j"
list/watch/get on Secrets exposes sensitive data.
Use least privilege.
```

Kubernetes good-practice docs warn that `list` access to Secrets effectively lets the subject fetch Secret contents, and users who can create Pods that use a Secret may indirectly access that Secret. ([Kubernetes][3])

---

# 36. Production Rules

```text id="2id903"
Do not bake environment config into images.
Use ConfigMaps for non-sensitive config.
Use Secrets for sensitive config.
Do not commit plaintext production Secrets.
Use secret.example.yaml for documentation.
Use external secret managers for serious production.
Enable encryption at rest for Secrets.
Restrict Secret access with RBAC.
Avoid printing secret values in logs.
Use specific key references where possible.
Restart Pods when env-based config changes.
Use checksum annotations, Kustomize generators, or reload controllers for config rollout.
Prefer immutable config for release-stable values.
```

---

# 37. Interview Explanation

Use this:

```text id="msf6o4"
ConfigMaps and Secrets let Kubernetes inject runtime configuration into Pods without rebuilding container images. ConfigMaps are for non-sensitive values such as log level, feature flags, ports, and config files. Secrets are for sensitive values such as passwords, tokens, and private keys.

Applications can consume ConfigMaps and Secrets as environment variables or as mounted files. Environment variables are loaded when the container starts, so a Pod restart is required to pick up changes. Mounted ConfigMap or Secret files can update eventually, but the application must reread or reload those files.

Kubernetes Secrets are base64 encoded, not automatically encrypted by default in etcd, so production setups should use encryption at rest, least-privilege RBAC, secret rotation, and often an external secret manager.
```

Resume version:

```text id="m13twy"
Implemented Kubernetes ConfigMap and Secret configuration patterns using env, envFrom, key references, mounted config files, mounted secret files, update behavior testing, rollout restart workflows, secret security runbooks, and production config manifests for demo-node-api.
```

---

# 38. Today’s Core Rules

```text id="b3unm2"
ConfigMap stores non-sensitive config.
Secret stores sensitive config.
Base64 is not encryption.
Secrets need RBAC and encryption at rest.
envFrom injects all keys.
configMapKeyRef and secretKeyRef inject specific keys.
Mounted ConfigMaps and Secrets appear as files.
Env var config changes require Pod restart.
Mounted files may update eventually.
Apps must reload files themselves.
Do not print secrets in logs.
Do not commit plaintext production secrets.
Use external secret management for real production.
```

---

# 39. Commit Lesson 10.7

From repo root:

```bash id="s4un9k"
cd ~/devops-masterclass

git status

git add .gitignore \
        10-kubernetes-production-operations

git commit -m "feat: add Kubernetes ConfigMaps Secrets and config injection lesson"

git push
```

---

# Next Lesson

```text id="77o0q2"
Lesson 10.8 — Probes, Lifecycle Hooks, Graceful Shutdown, and Production Health Design
```

We will cover:

```text id="wm5bhd"
livenessProbe
readinessProbe
startupProbe
probe types: HTTP, TCP, exec
initialDelaySeconds
periodSeconds
timeoutSeconds
failureThreshold
successThreshold
preStop hook
terminationGracePeriodSeconds
SIGTERM handling
why readiness is not liveness
bad probe simulations
production health endpoints for demo-node-api
```

[1]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/ "Configure a Pod to Use a ConfigMap | Kubernetes"
[2]: https://kubernetes.io/docs/concepts/configuration/secret/ "Secrets | Kubernetes"
[3]: https://kubernetes.io/docs/concepts/security/secrets-good-practices/ "Good practices for Kubernetes Secrets | Kubernetes"
[4]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_configmap/?utm_source=chatgpt.com "kubectl create configmap"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_generic/?utm_source=chatgpt.com "kubectl create secret generic"
[6]: https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/?utm_source=chatgpt.com "Define Environment Variables for a Container"
