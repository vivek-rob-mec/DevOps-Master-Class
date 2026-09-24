 # Lesson 10.11 — RBAC, ServiceAccounts, Least Privilege, and Namespace Isolation

In Lesson 10.10, you learned **node labels, taints, tolerations, affinity, anti-affinity, and topology spread**.

Now we move into Kubernetes access control.

This lesson is very important for DevOps engineers because production Kubernetes is not only about deploying apps. It is also about controlling:

```text id="4l3w2h"
who can access the cluster
which workloads can talk to the Kubernetes API
which namespace a team can manage
which resources CI/CD can deploy
which secrets an app can read
which permissions are too dangerous
```

Kubernetes RBAC uses four main API objects: `Role`, `ClusterRole`, `RoleBinding`, and `ClusterRoleBinding`. These objects define permissions and bind those permissions to users, groups, or ServiceAccounts. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="1vopua"
10.11.1   RBAC mental model
10.11.2   Authentication vs authorization
10.11.3   User vs ServiceAccount
10.11.4   default ServiceAccount risk
10.11.5   Role
10.11.6   ClusterRole
10.11.7   RoleBinding
10.11.8   ClusterRoleBinding
10.11.9   apiGroups
10.11.10  resources
10.11.11  verbs
10.11.12  resourceNames
10.11.13  least privilege
10.11.14  kubectl auth can-i
10.11.15  serviceAccountName in Pods
10.11.16  automountServiceAccountToken
10.11.17  namespace isolation reality
10.11.18  dangerous permissions
10.11.19  RBAC debugging
10.11.20  production RBAC for demo-node-api
10.11.21  validation script
10.11.22  cleanup script
```

---

# 2. Create Lesson Folder

```bash id="6i86y4"
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.11-rbac-serviceaccounts-namespace-isolation/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="id1rzr"
tree -L 2 10.11-rbac-serviceaccounts-namespace-isolation
```

---

# 3. RBAC Mental Model

RBAC means:

```text id="g7bnf8"
Role-Based Access Control
```

Simple meaning:

```text id="v3hurc"
Who can do what, on which resources, in which scope?
```

Example:

```text id="xkqu9x"
ServiceAccount demo-node-api
  can get ConfigMaps
  can get Secrets
  can list Pods
  cannot delete Deployments
  cannot read Secrets from other namespaces
  cannot modify Nodes
```

Kubernetes RBAC is a key security control for ensuring that cluster users and workloads have only the access they need. Kubernetes good-practice docs specifically emphasize understanding privilege escalation risks and avoiding excessive access. ([Kubernetes][2])

---

# 4. Authentication vs Authorization

These two are different.

## Authentication

Question:

```text id="ckygzt"
Who are you?
```

Examples:

```text id="qkid6j"
human user
CI/CD system
ServiceAccount
cloud IAM identity
certificate identity
OIDC identity
```

## Authorization

Question:

```text id="4yf0sl"
What are you allowed to do?
```

Examples:

```text id="5bpbth"
Can you list Pods?
Can you create Deployments?
Can you delete Secrets?
Can you update Nodes?
Can you read logs?
```

Kubernetes authorization checks whether an authenticated identity is allowed to perform a requested action, and RBAC is one authorization mode that uses the `rbac.authorization.k8s.io` API group to drive decisions. ([Kubernetes][3])

Golden rule:

```text id="v7blxb"
Authentication proves identity.
Authorization grants or denies action.
```

---

# 5. User vs ServiceAccount

Kubernetes has two common identity types:

```text id="hlylhk"
User:
  usually external human or system identity

ServiceAccount:
  Kubernetes API object used by Pods/workloads
```

A ServiceAccount provides an identity for processes running in Pods and maps to a Kubernetes `ServiceAccount` object. Kubernetes recognizes users, but Kubernetes itself does not have a `User` API object like it has a `ServiceAccount` API object. ([Kubernetes][4])

Simple example:

```text id="59y2i1"
You using kubectl:
  user identity from kubeconfig

App running inside Pod:
  ServiceAccount identity
```

---

# 6. Create Notes

```bash id="80yx5j"
nano 10.11-rbac-serviceaccounts-namespace-isolation/notes/rbac-mental-model.md
```

Paste:

```markdown id="mj9m21"
# Kubernetes RBAC Mental Model

## Authentication

Who are you?

Examples:

- user
- CI/CD identity
- ServiceAccount

## Authorization

What are you allowed to do?

Examples:

- get Pods
- list Secrets
- create Deployments
- delete Services

## Core RBAC Objects

- Role
- ClusterRole
- RoleBinding
- ClusterRoleBinding

## Golden Rule

Grant the smallest permission needed for the smallest scope needed.
```

---

# 7. RBAC Objects

There are four main RBAC objects.

```text id="o01kwd"
Role:
  namespaced permissions

ClusterRole:
  cluster-scoped permissions or reusable permission template

RoleBinding:
  grants Role or ClusterRole permissions inside a namespace

ClusterRoleBinding:
  grants ClusterRole permissions cluster-wide
```

The Kubernetes RBAC reference states that `Role` and `ClusterRole` contain rules representing permissions, while `RoleBinding` and `ClusterRoleBinding` bind those permissions to subjects. A Role is always namespaced, while a ClusterRole is cluster-scoped. ([Kubernetes][1])

---

# 8. Role

A `Role` defines permissions inside one namespace.

Example:

```yaml id="62w3gg"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

Meaning:

```text id="8t037v"
In namespace dev,
allow get/list/watch on Pods.
```

Important:

```text id="zdnw4f"
Role is namespace-scoped.
It does not grant access to other namespaces.
```

---

# 9. ClusterRole

A `ClusterRole` is cluster-scoped.

It can be used for:

```text id="rucqn0"
cluster-wide permissions
cluster-scoped resources like nodes
reusable permission templates
namespaced permissions reused across namespaces
```

Example:

```yaml id="3xwb3q"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
```

Meaning:

```text id="xem6n7"
Allow get/list on cluster-scoped Node resources.
```

---

# 10. RoleBinding

A `RoleBinding` grants a Role or ClusterRole to a subject inside a namespace.

Example:

```yaml id="5z0k8k"
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: dev
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: dev
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Meaning:

```text id="jibr5x"
Bind Role pod-reader to ServiceAccount pod-reader-sa in namespace dev.
```

A RoleBinding can reference either a Role in the same namespace or a ClusterRole. When a ClusterRole is bound using a RoleBinding, the permissions are granted only inside the RoleBinding’s namespace. ([Kubernetes][1])

---

# 11. ClusterRoleBinding

A `ClusterRoleBinding` grants a ClusterRole cluster-wide.

Example:

```yaml id="vxulp4"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes
subjects:
  - kind: ServiceAccount
    name: node-reader-sa
    namespace: dev
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

Meaning:

```text id="yink88"
ServiceAccount node-reader-sa can read Nodes cluster-wide.
```

Production warning:

```text id="ipgmbx"
ClusterRoleBinding is powerful.
Use it carefully.
Prefer RoleBinding when namespace scope is enough.
```

---

# 12. apiGroups, resources, verbs

Every RBAC rule has three main parts:

```yaml id="h2f2ik"
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

## apiGroups

The API group.

Examples:

```text id="7wwjd3"
"":
  core API group
  pods, services, configmaps, secrets

"apps":
  deployments, replicasets, statefulsets, daemonsets

"batch":
  jobs, cronjobs

"networking.k8s.io":
  ingresses, networkpolicies

"rbac.authorization.k8s.io":
  roles, rolebindings, clusterroles, clusterrolebindings
```

## resources

The Kubernetes resource.

Examples:

```text id="2kdbbq"
pods
pods/log
services
configmaps
secrets
deployments
ingresses
nodes
```

## verbs

The action.

Common verbs:

```text id="54j21v"
get
list
watch
create
update
patch
delete
deletecollection
```

Important difference:

```text id="h5dd44"
get:
  read one named object

list:
  read many objects

watch:
  subscribe to changes
```

For Secrets, `list` and `watch` are dangerous because they can expose many secret values. Kubernetes good-practice docs warn that `list` access to Secrets effectively allows clients to inspect the values of all Secrets in that scope. ([Kubernetes][2])

---

# 13. Create ServiceAccounts

Create manifest:

```bash id="r5okhj"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/serviceaccounts.yaml
```

Paste:

```yaml id="9gjv7u"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader-sa
  namespace: dev
  labels:
    app: rbac-demo
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: config-reader-sa
  namespace: dev
  labels:
    app: rbac-demo
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: node-reader-sa
  namespace: dev
  labels:
    app: rbac-demo
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: dev
  labels:
    app: rbac-demo
```

Apply:

```bash id="ewgz78"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/serviceaccounts.yaml
```

Check:

```bash id="w6c1fx"
kubectl get serviceaccounts -n dev
```

Short form:

```bash id="bt75sb"
kubectl get sa -n dev
```

---

# 14. default ServiceAccount Risk

Every namespace normally has a `default` ServiceAccount.

Check:

```bash id="2uzk9k"
kubectl get serviceaccount default -n dev
```

Many beginners ignore it and let every Pod use the default ServiceAccount.

Bad pattern:

```yaml id="u1tidh"
spec:
  containers:
    - name: app
      image: app
```

If you do not specify a ServiceAccount, the Pod uses the namespace’s default ServiceAccount.

Better pattern:

```yaml id="a4wgx9"
spec:
  serviceAccountName: demo-node-api
```

Production rule:

```text id="iz5vwa"
Create a dedicated ServiceAccount for each workload.
Do not rely on the default ServiceAccount for production apps.
```

---

# 15. automountServiceAccountToken

By default, Pods may receive a mounted ServiceAccount token that allows them to authenticate to the Kubernetes API.

If your app does not need to call the Kubernetes API, disable token mounting:

```yaml id="5qyq0p"
automountServiceAccountToken: false
```

Kubernetes docs explain that Pods can use ServiceAccount tokens to communicate with the API server, and ServiceAccounts can be configured for Pods. Modern clusters use projected, time-bound ServiceAccount tokens rather than relying on older long-lived automatically generated tokens. ([Kubernetes][4])

Production rule:

```text id="jmwzsh"
If the workload does not need Kubernetes API access, set automountServiceAccountToken: false.
```

---

# 16. Create Pod Reader Role and RoleBinding

Create:

```bash id="5on8s3"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-rbac.yaml
```

Paste:

```yaml id="f390pl"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: dev
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: dev
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: dev
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash id="8ksz23"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-rbac.yaml
```

Check:

```bash id="i2bgti"
kubectl get role,rolebinding -n dev
kubectl describe role pod-reader -n dev
kubectl describe rolebinding pod-reader-binding -n dev
```

---

# 17. Test with kubectl auth can-i

`kubectl auth can-i` checks whether an action is allowed. It accepts a Kubernetes API verb such as `get`, `list`, or `delete` and a resource type such as `pods`, and it pairs well with impersonation using `--as`. ([Kubernetes][5])

Test allowed actions:

```bash id="itltq1"
kubectl auth can-i list pods \
  -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa

kubectl auth can-i get pods/log \
  -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa
```

Expected:

```text id="g9f9et"
yes
yes
```

Test denied actions:

```bash id="b6gz8o"
kubectl auth can-i delete pods \
  -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa

kubectl auth can-i list secrets \
  -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa

kubectl auth can-i list pods \
  -n production \
  --as=system:serviceaccount:dev:pod-reader-sa
```

Expected:

```text id="fsr1oh"
no
no
no
```

Important:

```text id="xjzxi9"
The ServiceAccount can read Pods only in namespace dev.
It cannot delete Pods.
It cannot read Secrets.
It cannot list Pods in production.
```

---

# 18. Create Config Reader Role

Create a Role that can read ConfigMaps but not Secrets.

```bash id="28y4xz"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/config-reader-rbac.yaml
```

Paste:

```yaml id="l5njjw"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-reader
  namespace: dev
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: config-reader-binding
  namespace: dev
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: config-reader-sa
    namespace: dev
roleRef:
  kind: Role
  name: config-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash id="5k46d9"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/config-reader-rbac.yaml
```

Test:

```bash id="j03dmc"
kubectl auth can-i list configmaps \
  -n dev \
  --as=system:serviceaccount:dev:config-reader-sa

kubectl auth can-i list secrets \
  -n dev \
  --as=system:serviceaccount:dev:config-reader-sa

kubectl auth can-i list pods \
  -n dev \
  --as=system:serviceaccount:dev:config-reader-sa
```

Expected:

```text id="07orjm"
yes
no
no
```

Lesson:

```text id="7p43cy"
Separate ConfigMap access from Secret access.
Do not grant Secret access just because the app can read non-sensitive config.
```

---

# 19. Create ClusterRole for Node Read Access

Nodes are cluster-scoped resources, so a namespaced Role is not enough.

Create:

```bash id="v96gi0"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/node-reader-clusterrole.yaml
```

Paste:

```yaml id="s3e2ot"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: rbac-demo-node-reader
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: rbac-demo-node-reader-binding
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: node-reader-sa
    namespace: dev
roleRef:
  kind: ClusterRole
  name: rbac-demo-node-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash id="n6fc2p"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/node-reader-clusterrole.yaml
```

Test:

```bash id="z48ydj"
kubectl auth can-i list nodes \
  --as=system:serviceaccount:dev:node-reader-sa

kubectl auth can-i get nodes \
  --as=system:serviceaccount:dev:node-reader-sa

kubectl auth can-i delete nodes \
  --as=system:serviceaccount:dev:node-reader-sa
```

Expected:

```text id="pdukvz"
yes
yes
no
```

Production warning:

```text id="10sqpv"
Even read-only cluster-wide permissions should be intentional.
Do not grant cluster-wide access unless the workload really needs it.
```

---

# 20. RoleBinding to ClusterRole in One Namespace

A useful pattern:

```text id="wm6bqj"
Create ClusterRole once.
Bind it with RoleBinding per namespace.
```

This reuses permission rules but keeps access namespaced.

Create:

```bash id="ngky4i"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/reusable-configmap-reader-clusterrole.yaml
```

Paste:

```yaml id="4uy28b"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: reusable-configmap-reader
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: reusable-configmap-reader-binding
  namespace: dev
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: restricted-sa
    namespace: dev
roleRef:
  kind: ClusterRole
  name: reusable-configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash id="bt9kss"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/reusable-configmap-reader-clusterrole.yaml
```

Test:

```bash id="73ttbv"
kubectl auth can-i list configmaps \
  -n dev \
  --as=system:serviceaccount:dev:restricted-sa

kubectl auth can-i list configmaps \
  -n production \
  --as=system:serviceaccount:dev:restricted-sa
```

Expected:

```text id="o24ds1"
yes
no
```

Why?

```text id="1k55dn"
ClusterRole defines reusable rules.
RoleBinding grants those rules only inside namespace dev.
```

---

# 21. resourceNames

Sometimes you want to restrict access to one named object.

Example:

```yaml id="p2rqhe"
resourceNames:
  - app-runtime-config
```

Create a specific ConfigMap:

```bash id="k39nge"
kubectl create configmap app-runtime-config \
  -n dev \
  --from-literal=LOG_LEVEL=info \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Create Role:

```bash id="yhtrbj"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/specific-configmap-rbac.yaml
```

Paste:

```yaml id="i073tx"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: specific-config-reader-sa
  namespace: dev
  labels:
    app: rbac-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-configmap-reader
  namespace: dev
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["app-runtime-config"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: specific-configmap-reader-binding
  namespace: dev
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: specific-config-reader-sa
    namespace: dev
roleRef:
  kind: Role
  name: specific-configmap-reader
  apiGroup: rbac.authorization.k8s.io
```

Apply:

```bash id="v1ujbz"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/specific-configmap-rbac.yaml
```

Test:

```bash id="ncvlnj"
kubectl auth can-i get configmap/app-runtime-config \
  -n dev \
  --as=system:serviceaccount:dev:specific-config-reader-sa

kubectl auth can-i list configmaps \
  -n dev \
  --as=system:serviceaccount:dev:specific-config-reader-sa

kubectl auth can-i get configmap/demo-app-config \
  -n dev \
  --as=system:serviceaccount:dev:specific-config-reader-sa
```

Expected:

```text id="oq6ijg"
yes
no
no
```

Important:

```text id="5cr974"
resourceNames can restrict get/update/delete style access to named objects.
It does not work the same way for broad list access.
```

---

# 22. Run a Pod with Dedicated ServiceAccount

Create a Pod that uses `pod-reader-sa`.

```bash id="9h9fxf"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-workload.yaml
```

Paste:

```yaml id="bu4ykh"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pod-reader-workload
  namespace: dev
  labels:
    app: pod-reader-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pod-reader-workload
  template:
    metadata:
      labels:
        app: pod-reader-workload
    spec:
      serviceAccountName: pod-reader-sa
      automountServiceAccountToken: true
      containers:
        - name: app
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

```bash id="pjhmt7"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-workload.yaml
```

Check:

```bash id="7sjgwp"
kubectl rollout status deployment/pod-reader-workload -n dev
kubectl get pod -n dev -l app=pod-reader-workload -o yaml | grep -A5 serviceAccount
```

Expected:

```text id="1ith6u"
serviceAccountName: pod-reader-sa
```

---

# 23. Pod Without API Token

Now create a workload that does not need Kubernetes API access.

```bash id="cbzzbv"
nano 10.11-rbac-serviceaccounts-namespace-isolation/manifests/no-api-token-workload.yaml
```

Paste:

```yaml id="0j4eg4"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: no-api-token-workload
  namespace: dev
  labels:
    app: no-api-token-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: no-api-token-workload
  template:
    metadata:
      labels:
        app: no-api-token-workload
    spec:
      serviceAccountName: restricted-sa
      automountServiceAccountToken: false
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
```

Apply:

```bash id="9341nj"
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/no-api-token-workload.yaml
```

Check:

```bash id="3c99hf"
kubectl rollout status deployment/no-api-token-workload -n dev

NO_API_POD="$(kubectl get pod -n dev -l app=no-api-token-workload -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$NO_API_POD" -n dev -o yaml | grep -A5 automountServiceAccountToken
```

Expected:

```text id="ycxi4l"
automountServiceAccountToken: false
```

Production rule:

```text id="tz5u01"
Most normal web apps do not need Kubernetes API access.
Disable token automount unless needed.
```

---

# 24. Namespace Isolation Reality

Namespaces help organize and scope resources.

But namespaces alone are not a full security boundary.

Namespace helps with:

```text id="8l591z"
resource organization
RBAC scope
ResourceQuota
LimitRange
NetworkPolicy scope
environment separation
team separation
```

Namespace does **not automatically** guarantee:

```text id="dh0qln"
network isolation
secret isolation if RBAC is broad
node-level isolation
runtime isolation from privileged workloads
multi-tenant hard security
```

Production namespace isolation needs multiple controls:

```text id="7lg6g7"
RBAC
NetworkPolicy
ResourceQuota
LimitRange
Pod Security Admission
separate ServiceAccounts
least privilege
admission policies
node isolation when required
```

---

# 25. Dangerous RBAC Permissions

Be very careful with these:

```text id="6eutsz"
secrets get/list/watch
pods/exec create
pods/attach create
pods/portforward create
pods create
deployments update/patch
roles create/update
rolebindings create/update
clusterroles create/update
clusterrolebindings create/update
nodes update/patch
certificatesigningrequests approve
```

Why?

```text id="6v43iz"
secrets list:
  can expose credentials

pods/exec:
  can enter containers

pods create:
  can mount ServiceAccount tokens or Secrets if allowed

rolebindings create:
  can grant more permissions

cluster-admin:
  full control
```

RBAC good practices warn that workload creation access can indirectly grant access to Secrets mounted by those workloads, and that Secret read permissions should be tightly restricted. ([Kubernetes][2])

---

# 26. kubectl auth can-i Cheat Sheet

Check yourself:

```bash id="xnvekj"
kubectl auth can-i list pods -n dev
kubectl auth can-i create deployments -n dev
kubectl auth can-i list secrets -n dev
```

Check a ServiceAccount:

```bash id="66cyxh"
kubectl auth can-i list pods \
  -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa
```

Check cluster-scoped:

```bash id="eu33qk"
kubectl auth can-i list nodes \
  --as=system:serviceaccount:dev:node-reader-sa
```

List allowed actions for current identity:

```bash id="dmke8k"
kubectl auth can-i --list -n dev
```

Check a non-resource URL:

```bash id="1ybsbm"
kubectl auth can-i get /healthz
```

---

# 27. RBAC Debugging Script

Create:

```bash id="l7znoc"
nano 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh
```

Paste:

```bash id="jeswdf"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-pod-reader-sa}"
SUBJECT="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}"

echo "===== RBAC Check ====="
echo "Namespace: $NAMESPACE"
echo "ServiceAccount: $SERVICE_ACCOUNT"
echo "Subject: $SUBJECT"
echo

check() {
  local verb="$1"
  local resource="$2"
  local ns_flag="${3:-namespaced}"

  if [ "$ns_flag" = "cluster" ]; then
    printf "%-10s %-25s " "$verb" "$resource"
    kubectl auth can-i "$verb" "$resource" --as="$SUBJECT"
  else
    printf "%-10s %-25s " "$verb" "$resource"
    kubectl auth can-i "$verb" "$resource" -n "$NAMESPACE" --as="$SUBJECT"
  fi
}

check get pods
check list pods
check get pods/log
check delete pods
check list configmaps
check list secrets
check create deployments.apps
check list nodes cluster

echo
echo "RoleBindings in namespace:"
kubectl get rolebinding -n "$NAMESPACE"

echo
echo "Roles in namespace:"
kubectl get role -n "$NAMESPACE"
```

Make executable:

```bash id="4158bp"
chmod +x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh
```

Run:

```bash id="882nzy"
SERVICE_ACCOUNT=pod-reader-sa ./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh

SERVICE_ACCOUNT=config-reader-sa ./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh

SERVICE_ACCOUNT=node-reader-sa ./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh
```

---

# 28. RBAC Inventory Script

Create:

```bash id="1ze3jv"
nano 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-inventory.sh
```

Paste:

```bash id="p9555k"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== RBAC Inventory ====="

echo
echo "Namespace: $NAMESPACE"

echo
echo "ServiceAccounts:"
kubectl get serviceaccounts -n "$NAMESPACE"

echo
echo "Roles:"
kubectl get roles -n "$NAMESPACE"

echo
echo "RoleBindings:"
kubectl get rolebindings -n "$NAMESPACE"

echo
echo "ClusterRoles created for this lab:"
kubectl get clusterroles -l app=rbac-demo

echo
echo "ClusterRoleBindings created for this lab:"
kubectl get clusterrolebindings -l app=rbac-demo

echo
echo "Pods and ServiceAccounts:"
kubectl get pods -n "$NAMESPACE" \
  -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName,NODE:.spec.nodeName,PHASE:.status.phase
```

Make executable:

```bash id="zcf25q"
chmod +x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-inventory.sh
```

Run:

```bash id="pob013"
./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-inventory.sh
```

---

# 29. RBAC Debugging Runbook

Create:

```bash id="spmwmy"
nano 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/rbac-debugging-runbook.md
```

Paste:

````markdown id="fu5nlf"
# Kubernetes RBAC Debugging Runbook

## Step 1 — Identify Subject

For workload:

```bash
kubectl get pod POD_NAME -n NAMESPACE -o jsonpath='{.spec.serviceAccountName}'
````

Subject format:

```text
system:serviceaccount:NAMESPACE:SERVICEACCOUNT
```

## Step 2 — Check Permission

```bash
kubectl auth can-i VERB RESOURCE -n NAMESPACE \
  --as=system:serviceaccount:NAMESPACE:SERVICEACCOUNT
```

Example:

```bash id="yaapki"
kubectl auth can-i list pods -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa
```

## Step 3 — Check Roles and Bindings

```bash id="mgtary"
kubectl get role,rolebinding -n NAMESPACE
kubectl describe role ROLE_NAME -n NAMESPACE
kubectl describe rolebinding ROLEBINDING_NAME -n NAMESPACE
```

## Step 4 — Check Cluster-Wide Bindings

```bash id="gnapya"
kubectl get clusterrole,clusterrolebinding
kubectl describe clusterrole CLUSTERROLE_NAME
kubectl describe clusterrolebinding CLUSTERROLEBINDING_NAME
```

## Step 5 — Common Problems

| Symptom                          | Likely Cause                         |
| -------------------------------- | ------------------------------------ |
| forbidden                        | missing RBAC permission              |
| can read in dev but not prod     | RoleBinding is namespaced            |
| can read nodes but not pods      | ClusterRole grants nodes only        |
| Role exists but no access        | missing RoleBinding                  |
| RoleBinding exists but no access | wrong subject or wrong namespace     |
| Secret access denied             | Secret permissions not granted       |
| App should not call API          | disable automountServiceAccountToken |

## Golden Rule

A Role defines permissions.
A Binding grants them to a subject.
No binding means no permission.

````

---

# 30. ServiceAccount Security Runbook

Create:

```bash id="o8kpn4"
nano 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/serviceaccount-security-runbook.md
````

Paste:

````markdown id="u9y2ra"
# ServiceAccount Security Runbook

## Production Rules

- Create one ServiceAccount per workload.
- Do not rely on the default ServiceAccount.
- Disable token automount if the app does not need Kubernetes API access.
- Grant least privilege.
- Avoid broad Secret permissions.
- Avoid cluster-wide permissions unless necessary.
- Use RoleBinding instead of ClusterRoleBinding when namespace scope is enough.
- Review ServiceAccount usage regularly.

## Check Pod ServiceAccount

```bash
kubectl get pod POD_NAME -n NAMESPACE -o jsonpath='{.spec.serviceAccountName}'
````

## Disable Token Automount

```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

## ServiceAccount Subject Format

```text
system:serviceaccount:NAMESPACE:SERVICEACCOUNT
```

## Dangerous Permissions

* secrets list/watch/get
* pods/exec create
* pods create
* rolebindings create/update
* clusterrolebindings create/update
* cluster-admin

````

---

# 31. Namespace Isolation Runbook

Create:

```bash id="vluo3h"
nano 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/namespace-isolation-runbook.md
````

Paste:

````markdown id="4t2okk"
# Namespace Isolation Runbook

## Namespace Gives

- resource grouping
- namespaced RBAC
- quota boundaries
- policy boundaries
- environment/team separation

## Namespace Alone Does Not Give

- full network isolation
- full tenant isolation
- automatic secret protection
- node isolation
- runtime isolation

## Production Isolation Stack

Use:

- namespaces
- RBAC
- NetworkPolicy
- ResourceQuota
- LimitRange
- Pod Security Admission
- dedicated ServiceAccounts
- least privilege
- admission policies
- separate node pools for strong isolation needs

## Check Namespace Access

```bash
kubectl auth can-i list pods -n dev \
  --as=system:serviceaccount:dev:pod-reader-sa

kubectl auth can-i list pods -n production \
  --as=system:serviceaccount:dev:pod-reader-sa
````

## Golden Rule

Namespace is an isolation building block, not a complete isolation solution.

````

---

# 32. Production RBAC for `demo-node-api`

Now create production-style RBAC for your app.

Your Node.js API usually does **not** need to call the Kubernetes API.

So the safest default:

```text id="3b30im"
dedicated ServiceAccount
no unnecessary RBAC permissions
automountServiceAccountToken: false
````

Create:

```bash id="df43w2"
nano apps/demo-node-api/base/serviceaccount.yaml
```

Paste:

```yaml id="mxlx7d"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-node-api
  namespace: dev
  labels:
    app.kubernetes.io/name: demo-node-api
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: todo-app
automountServiceAccountToken: false
```

Important:

```text id="ghllru"
No Role or RoleBinding is required if the app does not need Kubernetes API access.
```

Update Deployment:

```bash id="b49xef"
nano apps/demo-node-api/base/deployment.yaml
```

Inside:

```yaml id="mbmhld"
spec:
  template:
    spec:
```

ensure this exists:

```yaml id="4u6cvo"
      serviceAccountName: demo-node-api
      automountServiceAccountToken: false
```

Your `spec.template.spec` should conceptually look like:

```yaml id="3dtd5v"
    spec:
      serviceAccountName: demo-node-api
      automountServiceAccountToken: false
      terminationGracePeriodSeconds: 30

      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-role
                    operator: In
                    values:
                      - app

      containers:
        - name: demo-node-api
```

Create note:

```bash id="4j7icl"
nano 10.11-rbac-serviceaccounts-namespace-isolation/notes/demo-node-api-rbac-policy.md
```

Paste:

```markdown id="rc29zv"
# demo-node-api RBAC Policy

## Workload

demo-node-api

## ServiceAccount

demo-node-api

## Kubernetes API Access

Not required by default.

## Policy

- Use a dedicated ServiceAccount.
- Disable automountServiceAccountToken.
- Do not bind Roles unless the app needs Kubernetes API access.
- Do not grant Secret list/watch.
- Do not use default ServiceAccount.
- Keep config and secret injection through Pod spec references.

## Future Exceptions

If demo-node-api later needs Kubernetes API access:

1. Define exact resource and verb.
2. Use a namespaced Role.
3. Bind only to demo-node-api ServiceAccount.
4. Validate with kubectl auth can-i.
5. Document reason and owner.
```

---

# 33. RBAC Myths and Misconceptions

## Myth 1: ServiceAccount is only for cloud IAM

Wrong.

```text id="r21lwj"
Kubernetes ServiceAccount is a Kubernetes identity for Pods.
Cloud IAM integration is a separate layer that may map to it.
```

---

## Myth 2: Role grants access by itself

Wrong.

```text id="t77661"
Role only defines permissions.
RoleBinding grants those permissions to a subject.
```

---

## Myth 3: ClusterRole always means cluster-wide access

Not always.

```text id="7fpygg"
ClusterRole + ClusterRoleBinding:
  cluster-wide

ClusterRole + RoleBinding:
  namespaced grant using reusable ClusterRole rules
```

---

## Myth 4: Namespace means full isolation

Wrong.

```text id="s8q6m8"
Namespace scopes many resources, but complete isolation needs RBAC, NetworkPolicy, quotas, Pod Security, and sometimes node isolation.
```

---

## Myth 5: Secret access is safe if only get is granted

Be careful.

```text id="rk2so4"
get secrets:
  can read specific Secret values

list secrets:
  can read many Secret values

watch secrets:
  can observe Secret changes
```

Grant Secret access only when truly needed.

---

## Myth 6: Apps should always mount ServiceAccount tokens

Wrong.

```text id="axtzjy"
Most normal web apps do not need Kubernetes API access.
Disable token mounting.
```

---

# 34. Validation Script

Create:

```bash id="p69kkd"
nano 10.11-rbac-serviceaccounts-namespace-isolation/scripts/validate-lesson-10-11.sh
```

Paste:

```bash id="pxtmjv"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.11 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get serviceaccount pod-reader-sa -n dev >/dev/null
kubectl get serviceaccount config-reader-sa -n dev >/dev/null
kubectl get serviceaccount node-reader-sa -n dev >/dev/null
kubectl get serviceaccount restricted-sa -n dev >/dev/null

kubectl get role pod-reader -n dev >/dev/null
kubectl get rolebinding pod-reader-binding -n dev >/dev/null

kubectl get role config-reader -n dev >/dev/null
kubectl get rolebinding config-reader-binding -n dev >/dev/null

kubectl get clusterrole rbac-demo-node-reader >/dev/null
kubectl get clusterrolebinding rbac-demo-node-reader-binding >/dev/null

kubectl get clusterrole reusable-configmap-reader >/dev/null
kubectl get rolebinding reusable-configmap-reader-binding -n dev >/dev/null

kubectl get serviceaccount specific-config-reader-sa -n dev >/dev/null
kubectl get role specific-configmap-reader -n dev >/dev/null
kubectl get rolebinding specific-configmap-reader-binding -n dev >/dev/null

kubectl get deployment pod-reader-workload -n dev >/dev/null
kubectl get deployment no-api-token-workload -n dev >/dev/null

kubectl rollout status deployment/pod-reader-workload -n dev --timeout=120s >/dev/null
kubectl rollout status deployment/no-api-token-workload -n dev --timeout=120s >/dev/null

POD_READER_SUBJECT="system:serviceaccount:dev:pod-reader-sa"
CONFIG_READER_SUBJECT="system:serviceaccount:dev:config-reader-sa"
NODE_READER_SUBJECT="system:serviceaccount:dev:node-reader-sa"
RESTRICTED_SUBJECT="system:serviceaccount:dev:restricted-sa"
SPECIFIC_SUBJECT="system:serviceaccount:dev:specific-config-reader-sa"

kubectl auth can-i list pods -n dev --as="$POD_READER_SUBJECT" | grep -q yes
kubectl auth can-i delete pods -n dev --as="$POD_READER_SUBJECT" | grep -q no
kubectl auth can-i list secrets -n dev --as="$POD_READER_SUBJECT" | grep -q no

kubectl auth can-i list configmaps -n dev --as="$CONFIG_READER_SUBJECT" | grep -q yes
kubectl auth can-i list secrets -n dev --as="$CONFIG_READER_SUBJECT" | grep -q no

kubectl auth can-i list nodes --as="$NODE_READER_SUBJECT" | grep -q yes
kubectl auth can-i delete nodes --as="$NODE_READER_SUBJECT" | grep -q no

kubectl auth can-i list configmaps -n dev --as="$RESTRICTED_SUBJECT" | grep -q yes
kubectl auth can-i list configmaps -n production --as="$RESTRICTED_SUBJECT" | grep -q no

kubectl auth can-i get configmap/app-runtime-config -n dev --as="$SPECIFIC_SUBJECT" | grep -q yes
kubectl auth can-i list configmaps -n dev --as="$SPECIFIC_SUBJECT" | grep -q no

NO_API_POD="$(kubectl get pod -n dev -l app=no-api-token-workload -o jsonpath='{.items[0].metadata.name}')"
AUTOMOUNT_VALUE="$(kubectl get pod "$NO_API_POD" -n dev -o jsonpath='{.spec.automountServiceAccountToken}')"

if [ "$AUTOMOUNT_VALUE" != "false" ]; then
  echo "ERROR: no-api-token-workload should have automountServiceAccountToken=false"
  exit 1
fi

test -x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh
test -x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-inventory.sh

test -f 10.11-rbac-serviceaccounts-namespace-isolation/notes/rbac-mental-model.md
test -f 10.11-rbac-serviceaccounts-namespace-isolation/notes/demo-node-api-rbac-policy.md
test -f 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/rbac-debugging-runbook.md
test -f 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/serviceaccount-security-runbook.md
test -f 10.11-rbac-serviceaccounts-namespace-isolation/runbooks/namespace-isolation-runbook.md

test -f apps/demo-node-api/base/serviceaccount.yaml
grep -q "serviceAccountName: demo-node-api" apps/demo-node-api/base/deployment.yaml
grep -q "automountServiceAccountToken: false" apps/demo-node-api/base/deployment.yaml

echo "Lesson 10.11 validation passed."
```

Make executable:

```bash id="fvpmaj"
chmod +x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/validate-lesson-10-11.sh
```

Run:

```bash id="7p87xe"
./10.11-rbac-serviceaccounts-namespace-isolation/scripts/validate-lesson-10-11.sh
```

---

# 35. Cleanup Script

Create:

```bash id="l0btjj"
nano 10.11-rbac-serviceaccounts-namespace-isolation/scripts/cleanup-lesson-10-11.sh
```

Paste:

```bash id="kfjtqd"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.11 ====="

kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/no-api-token-workload.yaml --ignore-not-found=true
kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-workload.yaml --ignore-not-found=true

kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/specific-configmap-rbac.yaml --ignore-not-found=true
kubectl delete configmap app-runtime-config -n dev --ignore-not-found=true

kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/reusable-configmap-reader-clusterrole.yaml --ignore-not-found=true
kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/node-reader-clusterrole.yaml --ignore-not-found=true
kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/config-reader-rbac.yaml --ignore-not-found=true
kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-rbac.yaml --ignore-not-found=true
kubectl delete -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/serviceaccounts.yaml --ignore-not-found=true

echo "Lesson 10.11 resources cleaned."
echo "demo-node-api ServiceAccount manifest is kept in apps/demo-node-api/base."
```

Make executable:

```bash id="1nrcc7"
chmod +x 10.11-rbac-serviceaccounts-namespace-isolation/scripts/cleanup-lesson-10-11.sh
```

Run only if you want cleanup:

```bash id="918eee"
./10.11-rbac-serviceaccounts-namespace-isolation/scripts/cleanup-lesson-10-11.sh
```

---

# 36. Practical Lab Summary

Run the main lab:

```bash id="qfml45"
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/serviceaccounts.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-rbac.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/config-reader-rbac.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/node-reader-clusterrole.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/reusable-configmap-reader-clusterrole.yaml

kubectl create configmap app-runtime-config \
  -n dev \
  --from-literal=LOG_LEVEL=info \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/specific-configmap-rbac.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/pod-reader-workload.yaml
kubectl apply -f 10.11-rbac-serviceaccounts-namespace-isolation/manifests/no-api-token-workload.yaml

./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-inventory.sh
SERVICE_ACCOUNT=pod-reader-sa ./10.11-rbac-serviceaccounts-namespace-isolation/scripts/rbac-check.sh
./10.11-rbac-serviceaccounts-namespace-isolation/scripts/validate-lesson-10-11.sh
```

---

# 37. Production RBAC Rules

```text id="6ubira"
Use one ServiceAccount per workload.
Avoid using the default ServiceAccount.
Disable automountServiceAccountToken when API access is not needed.
Use RoleBinding instead of ClusterRoleBinding when namespace scope is enough.
Grant exact verbs only.
Grant exact resources only.
Avoid Secret get/list/watch unless truly needed.
Avoid pods/exec and pods/create unless necessary.
Use kubectl auth can-i before and after changes.
Remember: Role defines permissions; Binding grants them.
Namespace helps isolation but is not a full security boundary.
```

---

# 38. Interview Explanation

Use this:

```text id="rdp32p"
Kubernetes RBAC controls what authenticated users and ServiceAccounts are allowed to do. A Role defines namespaced permissions, while a ClusterRole defines cluster-scoped or reusable permissions. A RoleBinding grants a Role or ClusterRole inside a namespace, while a ClusterRoleBinding grants ClusterRole permissions cluster-wide.

For workloads, I create a dedicated ServiceAccount instead of using the default ServiceAccount. If the application does not need Kubernetes API access, I set automountServiceAccountToken to false. I validate permissions with kubectl auth can-i and follow least privilege by granting only required verbs, resources, and scope.
```

Resume version:

```text id="2x9t8y"
Implemented Kubernetes RBAC and ServiceAccount security labs covering Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, kubectl auth can-i validation, least-privilege access, disabled token automounting, namespace isolation runbooks, and production RBAC policy for demo-node-api.
```

---

# 39. Today’s Core Rules

```text id="drrmfm"
Authentication asks: who are you?
Authorization asks: what can you do?
ServiceAccount is workload identity.
Role is namespaced.
ClusterRole is cluster-scoped or reusable.
RoleBinding grants permissions in a namespace.
ClusterRoleBinding grants permissions cluster-wide.
apiGroups identify API families.
resources identify Kubernetes resources.
verbs identify allowed actions.
Role alone grants nothing without a binding.
Use kubectl auth can-i to test access.
Do not use default ServiceAccount for production apps.
Disable automountServiceAccountToken when not needed.
Namespaces are not complete security boundaries by themselves.
Least privilege is the default production rule.
```

---

# 40. Commit Lesson 10.11

From repo root:

```bash id="cbxvx3"
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes RBAC ServiceAccounts and namespace isolation lesson"

git push
```

---

# Next Lesson

```text id="vq4j1f"
Lesson 10.12 — PersistentVolumes, PersistentVolumeClaims, StorageClasses, StatefulSets, and Database Patterns
```

We will cover:

```text id="e9l365"
ephemeral storage
emptyDir
PersistentVolume
PersistentVolumeClaim
StorageClass
dynamic provisioning
access modes
reclaim policies
volume binding modes
StatefulSet mental model
stable network identity
stable storage identity
headless Service
database patterns
why Deployments are not ideal for databases
production storage pattern for demo-node-api dependencies
```

[1]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/?utm_source=chatgpt.com "Using RBAC Authorization"
[2]: https://kubernetes.io/docs/concepts/security/rbac-good-practices/?utm_source=chatgpt.com "Role Based Access Control Good Practices"
[3]: https://kubernetes.io/docs/reference/access-authn-authz/authorization/?utm_source=chatgpt.com "Authorization"
[4]: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/?utm_source=chatgpt.com "Configure Service Accounts for Pods"
[5]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/?utm_source=chatgpt.com "kubectl auth can-i"
