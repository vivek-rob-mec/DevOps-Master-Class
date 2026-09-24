# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.8 — RBAC Permission Troubleshooting

In Lesson 11.7, you learned **probe failure troubleshooting**:

```text id="l11-7-recap"
readinessProbe failures
livenessProbe restarts
startupProbe protection
wrong path
wrong port
slow startup
dependency-based readiness
probe timeouts
TCP probes
exec probes
```

Now we move to **RBAC permission troubleshooting**.

This lesson is critical because RBAC failures appear everywhere in Kubernetes operations:

```text id="rbac-failures"
kubectl Forbidden errors
ArgoCD cannot apply resources
controller cannot list/watch resources
Pod cannot read Kubernetes API
ServiceAccount has no permission
RoleBinding points to wrong subject
Role exists but nothing is granted
ClusterRole used incorrectly
wrong namespace binding
default ServiceAccount mistake
```

Kubernetes RBAC is built around four main API objects: `Role`, `ClusterRole`, `RoleBinding`, and `ClusterRoleBinding`. A `Role` grants namespaced permissions, a `ClusterRole` can grant cluster-scoped permissions or reusable permission templates, and bindings attach those permissions to users, groups, or ServiceAccounts. ([Kubernetes][1])

---

# 1. What We Will Cover

```text id="lesson-map"
11.8.1   RBAC mental model
11.8.2   Authentication vs authorization vs admission
11.8.3   Forbidden error meaning
11.8.4   ServiceAccount identity
11.8.5   Role vs ClusterRole
11.8.6   RoleBinding vs ClusterRoleBinding
11.8.7   kubectl auth can-i
11.8.8   Impersonation testing
11.8.9   Missing verb troubleshooting
11.8.10  Wrong namespace binding
11.8.11  Wrong subject in RoleBinding
11.8.12  Role exists but not bound
11.8.13  In-cluster API access debugging
11.8.14  default ServiceAccount mistakes
11.8.15  automountServiceAccountToken
11.8.16  Least privilege fixes
11.8.17  Scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting
```

---

# 3. RBAC Mental Model

RBAC answers one question:

```text id="rbac-question"
Is this identity allowed to perform this action on this resource?
```

A Kubernetes API request goes through these major stages:

```text id="api-stages"
1. Authentication:
   Who are you?

2. Authorization:
   Are you allowed to do this?

3. Admission:
   Is this request acceptable before persistence?
```

If authentication fails, the request is rejected as unauthenticated. If authentication succeeds but authorization denies the action, you commonly see a `Forbidden` error. Kubernetes authorization evaluates whether the authenticated user is allowed to perform a requested verb on a resource. ([Kubernetes][2])

Simple example:

```text id="forbidden-example"
User:
  system:serviceaccount:dev:app-reader

Action:
  list pods

Namespace:
  dev

RBAC question:
  Does this ServiceAccount have a RoleBinding or ClusterRoleBinding that grants list pods?
```

---

# 4. Create RBAC Mental Model Notes

```bash id="mental-note"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/notes/rbac-mental-model.md
```

Paste:

```markdown id="mental-note-content"
# RBAC Mental Model

## API Request Flow

1. Authentication:
   Who are you?

2. Authorization:
   Are you allowed to do this?

3. Admission:
   Is the request allowed before it is stored?

## RBAC Objects

Role:
  Namespaced permissions.

ClusterRole:
  Cluster-scoped permissions or reusable permission template.

RoleBinding:
  Grants a Role or ClusterRole within one namespace.

ClusterRoleBinding:
  Grants a ClusterRole cluster-wide.

## Main Debug Question

Who is trying to do what, on which resource, in which namespace?

## Golden Rule

A Role alone grants nothing.
A binding is what gives the permission to a subject.
```

---

# 5. RBAC Object Cheat Sheet

Create:

```bash id="cheat-note"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/notes/rbac-object-cheatsheet.md
```

Paste:

```markdown id="cheat-note-content"
# RBAC Object Cheat Sheet

## Role

Namespaced permission set.

Example:

- get pods
- list pods
- watch pods
- get configmaps

Only applies inside one namespace.

## ClusterRole

Cluster-level permission set.

Can be used for:

- cluster-scoped resources such as nodes
- permissions reusable across namespaces
- non-resource URLs

## RoleBinding

Grants a Role or ClusterRole inside one namespace.

Common use:

- grant pod read access in dev namespace only

## ClusterRoleBinding

Grants a ClusterRole across the whole cluster.

Common use:

- cluster admin
- node reader
- controller-wide permissions

## Subject Types

- User
- Group
- ServiceAccount

## ServiceAccount Identity Format

system:serviceaccount:<namespace>:<serviceaccount-name>
```

---

# 6. First RBAC Debug Commands

Create:

```bash id="debug-commands-note"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/notes/rbac-debug-commands.md
```

Paste:

````markdown id="debug-commands-content"
# RBAC Debug Commands

## Check current user permissions

```bash
kubectl auth can-i get pods -n dev
kubectl auth can-i list pods -n dev
kubectl auth can-i create deployments -n dev
````

## Check ServiceAccount permissions by impersonation

```bash
kubectl auth can-i get pods \
  --as=system:serviceaccount:dev:pod-reader-sa \
  -n dev

kubectl auth can-i list secrets \
  --as=system:serviceaccount:dev:pod-reader-sa \
  -n dev
```

## Check all permissions for a ServiceAccount

```bash
kubectl auth can-i --list \
  --as=system:serviceaccount:dev:pod-reader-sa \
  -n dev
```

## Inspect ServiceAccounts

```bash
kubectl get serviceaccount -n dev
kubectl describe serviceaccount pod-reader-sa -n dev
```

## Inspect Roles and RoleBindings

```bash
kubectl get role,rolebinding -n dev
kubectl describe role pod-reader -n dev
kubectl describe rolebinding pod-reader-binding -n dev
```

## Inspect ClusterRoles and ClusterRoleBindings

```bash
kubectl get clusterrole | grep demo
kubectl get clusterrolebinding | grep demo
kubectl describe clusterrole demo-node-reader
kubectl describe clusterrolebinding demo-node-reader-binding
```

## Find RoleBindings mentioning a ServiceAccount

```bash
kubectl get rolebinding -A -o yaml | grep -B5 -A10 "name: pod-reader-sa"
kubectl get clusterrolebinding -o yaml | grep -B5 -A10 "name: pod-reader-sa"
```

````

`kubectl auth can-i` checks whether an action is allowed; it accepts Kubernetes verbs such as `get`, `list`, `watch`, `create`, and resources such as `pods`, `deployments`, or `secrets`. It can also be combined with impersonation using `--as`, which is useful for testing a ServiceAccount’s permissions without entering a Pod. :contentReference[oaicite:2]{index=2}

---

# 7. Common Forbidden Error Shape

A typical RBAC error looks like this:

```text id="forbidden-shape"
Error from server (Forbidden): pods is forbidden:
User "system:serviceaccount:dev:pod-reader-sa"
cannot list resource "pods"
in API group ""
in the namespace "dev"
````

Break it down:

```text id="forbidden-breakdown"
User:
  system:serviceaccount:dev:pod-reader-sa

Verb:
  list

Resource:
  pods

API group:
  core API group, shown as ""

Namespace:
  dev
```

Troubleshooting question:

```text id="forbidden-question"
Does this exact identity have this exact verb on this exact resource in this exact namespace?
```

---

# 8. Create Namespace and Baseline ServiceAccounts

Create:

```bash id="sa-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/00-serviceaccounts.yaml
```

Paste:

```yaml id="sa-content"
apiVersion: v1
kind: Namespace
metadata:
  name: rbac-lab
  labels:
    purpose: rbac-troubleshooting
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-access-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: config-reader-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: node-reader-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: no-token-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
automountServiceAccountToken: false
```

Apply:

```bash id="apply-sa"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/00-serviceaccounts.yaml
```

Check:

```bash id="check-sa"
kubectl get serviceaccount -n rbac-lab
kubectl describe serviceaccount pod-reader-sa -n rbac-lab
```

By default, Kubernetes can provide Pods with credentials for their assigned ServiceAccount, but you can disable automatic token mounting with `automountServiceAccountToken: false`. If both the ServiceAccount and Pod specify `automountServiceAccountToken`, the Pod specification takes precedence. ([Kubernetes][3])

---

# 9. Incident 1 — ServiceAccount Has No Permissions

Check `no-access-sa`:

```bash id="check-no-access"
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:no-access-sa \
  -n rbac-lab

kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:no-access-sa \
  -n rbac-lab

kubectl auth can-i get configmaps \
  --as=system:serviceaccount:rbac-lab:no-access-sa \
  -n rbac-lab
```

Expected:

```text id="no-access-expected"
no
no
no
```

Why?

```text id="no-access-why"
The ServiceAccount exists.
But no RoleBinding or ClusterRoleBinding grants it permissions.
```

Production lesson:

```text id="no-access-rule"
Creating a ServiceAccount does not grant permissions.
It only creates an identity.
```

---

# 10. Incident 2 — Role Exists but Is Not Bound

Create a Role but no RoleBinding:

```bash id="unbound-role-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/01-role-without-binding.yaml
```

Paste:

```yaml id="unbound-role-content"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: unbound-pod-reader
  namespace: rbac-lab
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

Apply:

```bash id="apply-unbound"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/01-role-without-binding.yaml
```

Test:

```bash id="test-unbound"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab
```

Expected:

```text id="unbound-expected"
no
```

Debug:

```bash id="debug-unbound"
kubectl get role,rolebinding -n rbac-lab
kubectl describe role unbound-pod-reader -n rbac-lab
```

Root cause:

```text id="unbound-root"
Role exists, but no RoleBinding grants it to pod-reader-sa.
```

Fix with RoleBinding:

```bash id="fix-unbound"
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: unbound-pod-reader-fix
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: unbound-pod-reader
EOF
```

Validate:

```bash id="validate-unbound"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab
```

Expected:

```text id="unbound-fixed"
yes
```

Clean the temporary fix later:

```bash id="clean-unbound-fix"
kubectl delete rolebinding unbound-pod-reader-fix -n rbac-lab --ignore-not-found=true
```

---

# 11. Create Correct Pod Reader RBAC

Now create a proper Role and RoleBinding.

```bash id="pod-reader-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/02-pod-reader-rbac.yaml
```

Paste:

```yaml id="pod-reader-content"
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: rbac-lab
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
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
```

Apply:

```bash id="apply-pod-reader"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/02-pod-reader-rbac.yaml
```

Test:

```bash id="test-pod-reader"
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab

kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab

kubectl auth can-i get pods/log \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab

kubectl auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab
```

Expected:

```text id="pod-reader-expected"
yes
yes
yes
no
```

Why `delete pods` is `no`:

```text id="delete-no"
The Role grants get/list/watch pods and get pods/log only.
It does not grant delete.
```

This is least privilege.

---

# 12. Incident 3 — Missing Verb

A very common RBAC failure:

```text id="missing-verb-example"
The controller can get Pods but cannot list or watch Pods.
```

Create a Role that only grants `get`, not `list`:

```bash id="missing-verb-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/03-missing-verb.yaml
```

Paste:

```yaml id="missing-verb-content"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: get-only-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: get-only-pods
  namespace: rbac-lab
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: get-only-pods-binding
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: get-only-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: get-only-pods
```

Apply:

```bash id="apply-missing-verb"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/03-missing-verb.yaml
```

Test:

```bash id="test-missing-verb"
kubectl auth can-i get pods \
  --as=system:serviceaccount:rbac-lab:get-only-sa \
  -n rbac-lab

kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:get-only-sa \
  -n rbac-lab

kubectl auth can-i watch pods \
  --as=system:serviceaccount:rbac-lab:get-only-sa \
  -n rbac-lab
```

Expected:

```text id="missing-verb-expected"
yes
no
no
```

Fix:

```bash id="fix-missing-verb"
kubectl patch role get-only-pods -n rbac-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/rules/0/verbs",
      "value": ["get", "list", "watch"]
    }
  ]'
```

Validate:

```bash id="validate-missing-verb"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:get-only-sa \
  -n rbac-lab

kubectl auth can-i watch pods \
  --as=system:serviceaccount:rbac-lab:get-only-sa \
  -n rbac-lab
```

Expected:

```text id="missing-verb-fixed"
yes
yes
```

Production lesson:

```text id="verb-rule"
Controllers usually need get, list, and watch.
Human read-only users may need get and list.
Mutation requires create, update, patch, or delete.
```

---

# 13. Incident 4 — Wrong Namespace Binding

A RoleBinding grants permissions only in the namespace where the RoleBinding exists.

Create another namespace:

```bash id="other-ns"
kubectl create namespace rbac-other --dry-run=client -o yaml | kubectl apply -f -
```

Test `pod-reader-sa` in `rbac-lab`:

```bash id="test-pod-reader-ns"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab

kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-other
```

Expected:

```text id="namespace-expected"
yes
no
```

Why?

```text id="namespace-why"
The RoleBinding exists in rbac-lab.
It grants namespaced permissions in rbac-lab only.
It does not grant pod access in rbac-other.
```

Fix option A — create RoleBinding in `rbac-other`:

```bash id="fix-other-ns"
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding-from-rbac-lab-sa
  namespace: rbac-other
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: pod-reader-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
EOF
```

Validate:

```bash id="validate-other-ns"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-other
```

Expected:

```text id="other-ns-fixed"
yes
```

Clean temporary RoleBinding:

```bash id="clean-other-ns-binding"
kubectl delete rolebinding pod-reader-binding-from-rbac-lab-sa -n rbac-other --ignore-not-found=true
```

Production warning:

```text id="namespace-warning"
Do not use ClusterRoleBinding just because one namespace binding is missing.
Use the smallest scope that solves the problem.
```

---

# 14. Incident 5 — Wrong Subject in RoleBinding

A common typo:

```text id="wrong-subject"
RoleBinding points to the wrong ServiceAccount name or namespace.
```

Create:

```bash id="wrong-subject-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/04-wrong-subject.yaml
```

Paste:

```yaml id="wrong-subject-content"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wrong-subject-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: wrong-subject-pod-reader
  namespace: rbac-lab
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: wrong-subject-binding
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: typo-serviceaccount-name
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: wrong-subject-pod-reader
```

Apply:

```bash id="apply-wrong-subject"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/04-wrong-subject.yaml
```

Test:

```bash id="test-wrong-subject"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:wrong-subject-sa \
  -n rbac-lab
```

Expected:

```text id="wrong-subject-expected"
no
```

Debug:

```bash id="debug-wrong-subject"
kubectl describe rolebinding wrong-subject-binding -n rbac-lab
kubectl get serviceaccount -n rbac-lab
```

Root cause:

```text id="wrong-subject-root"
RoleBinding grants permissions to typo-serviceaccount-name.
The real ServiceAccount is wrong-subject-sa.
```

Fix:

```bash id="fix-wrong-subject"
kubectl patch rolebinding wrong-subject-binding -n rbac-lab \
  --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/subjects/0/name",
      "value": "wrong-subject-sa"
    }
  ]'
```

Validate:

```bash id="validate-wrong-subject"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:wrong-subject-sa \
  -n rbac-lab
```

Expected:

```text id="wrong-subject-fixed"
yes
```

---

# 15. Incident 6 — Cluster-Scoped Resource Needs ClusterRole

Nodes are cluster-scoped. A namespaced Role cannot grant access to nodes.

Test with `pod-reader-sa`:

```bash id="test-node-no"
kubectl auth can-i list nodes \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa
```

Expected:

```text id="node-no"
no
```

Create ClusterRole and ClusterRoleBinding:

```bash id="node-reader-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/05-node-reader-clusterrole.yaml
```

Paste:

```yaml id="node-reader-content"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: rbac-demo-node-reader
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
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
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rbac-demo-node-reader
```

Apply:

```bash id="apply-node-reader"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/05-node-reader-clusterrole.yaml
```

Validate:

```bash id="validate-node-reader"
kubectl auth can-i list nodes \
  --as=system:serviceaccount:rbac-lab:node-reader-sa

kubectl auth can-i delete nodes \
  --as=system:serviceaccount:rbac-lab:node-reader-sa
```

Expected:

```text id="node-reader-expected"
yes
no
```

Production rule:

```text id="clusterrole-rule"
Use ClusterRoleBinding only when the permission truly needs cluster-wide scope.
```

---

# 16. Incident 7 — ClusterRole with RoleBinding

A `ClusterRole` can be bound with a `RoleBinding` to grant permissions only inside one namespace.

This is useful when you want reusable permission definitions but namespace-limited grants.

Create:

```bash id="clusterrole-rolebinding-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/06-clusterrole-with-rolebinding.yaml
```

Paste:

```yaml id="clusterrole-rolebinding-content"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: rbac-demo-configmap-reader
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
  name: configmap-reader-binding
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: config-reader-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rbac-demo-configmap-reader
```

Apply:

```bash id="apply-clusterrole-rolebinding"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/06-clusterrole-with-rolebinding.yaml
```

Test:

```bash id="test-clusterrole-rolebinding"
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:rbac-lab:config-reader-sa \
  -n rbac-lab

kubectl auth can-i list configmaps \
  --as=system:serviceaccount:rbac-lab:config-reader-sa \
  -n rbac-other
```

Expected:

```text id="clusterrole-rolebinding-expected"
yes
no
```

Why?

```text id="clusterrole-rolebinding-why"
The permission definition is a ClusterRole.
But the grant is a RoleBinding in rbac-lab.
So the permission is namespace-limited to rbac-lab.
```

This is a good production pattern.

---

# 17. Incident 8 — Secret Access Denied

Secrets should be tightly controlled.

Test `pod-reader-sa`:

```bash id="secret-denied-test"
kubectl auth can-i get secrets \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab

kubectl auth can-i list secrets \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa \
  -n rbac-lab
```

Expected:

```text id="secret-denied-expected"
no
no
```

Good.

Create a specific Secret reader for one Secret only:

```bash id="specific-secret"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: app-runtime-secret
  namespace: rbac-lab
  labels:
    app: rbac-demo
type: Opaque
stringData:
  API_TOKEN: local-token
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: specific-secret-reader-sa
  namespace: rbac-lab
  labels:
    app: rbac-demo
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-secret-reader
  namespace: rbac-lab
  labels:
    app: rbac-demo
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["app-runtime-secret"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: specific-secret-reader-binding
  namespace: rbac-lab
  labels:
    app: rbac-demo
subjects:
  - kind: ServiceAccount
    name: specific-secret-reader-sa
    namespace: rbac-lab
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: specific-secret-reader
EOF
```

Test:

```bash id="test-specific-secret"
kubectl auth can-i get secret/app-runtime-secret \
  --as=system:serviceaccount:rbac-lab:specific-secret-reader-sa \
  -n rbac-lab

kubectl auth can-i list secrets \
  --as=system:serviceaccount:rbac-lab:specific-secret-reader-sa \
  -n rbac-lab

kubectl auth can-i delete secret/app-runtime-secret \
  --as=system:serviceaccount:rbac-lab:specific-secret-reader-sa \
  -n rbac-lab
```

Expected:

```text id="specific-secret-expected"
yes
no
no
```

Production note:

```text id="secret-rbac-note"
Use resourceNames for narrow Secret access when practical.
Avoid broad list/watch access to Secrets.
```

Kubernetes RBAC good practices recommend minimizing powerful permissions and being careful with Secret access because Secrets can contain credentials that lead to further privilege. ([Kubernetes][4])

---

# 18. In-Cluster API Access Debugging

Now create Pods that call the Kubernetes API from inside the cluster.

Create:

```bash id="api-pods-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/07-incluster-api-debug.yaml
```

Paste:

```yaml id="api-pods-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-caller-no-access
  namespace: rbac-lab
  labels:
    app: api-caller-no-access
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-caller-no-access
  template:
    metadata:
      labels:
        app: api-caller-no-access
    spec:
      serviceAccountName: no-access-sa
      automountServiceAccountToken: true
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-caller-pod-reader
  namespace: rbac-lab
  labels:
    app: api-caller-pod-reader
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-caller-pod-reader
  template:
    metadata:
      labels:
        app: api-caller-pod-reader
    spec:
      serviceAccountName: pod-reader-sa
      automountServiceAccountToken: true
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-caller-no-token
  namespace: rbac-lab
  labels:
    app: api-caller-no-token
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-caller-no-token
  template:
    metadata:
      labels:
        app: api-caller-no-token
    spec:
      serviceAccountName: no-token-sa
      automountServiceAccountToken: false
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

```bash id="apply-api-pods"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/07-incluster-api-debug.yaml

kubectl rollout status deployment/api-caller-no-access -n rbac-lab --timeout=120s
kubectl rollout status deployment/api-caller-pod-reader -n rbac-lab --timeout=120s
kubectl rollout status deployment/api-caller-no-token -n rbac-lab --timeout=120s
```

Create helper command to call Kubernetes API from inside a Pod:

```bash id="api-call-helper"
NO_ACCESS_POD="$(kubectl get pod -n rbac-lab -l app=api-caller-no-access -o jsonpath='{.items[0].metadata.name}')"

READER_POD="$(kubectl get pod -n rbac-lab -l app=api-caller-pod-reader -o jsonpath='{.items[0].metadata.name}')"

NO_TOKEN_POD="$(kubectl get pod -n rbac-lab -l app=api-caller-no-token -o jsonpath='{.items[0].metadata.name}')"
```

Check token path:

```bash id="check-token-path"
kubectl exec -n rbac-lab "$NO_ACCESS_POD" -- ls -la /var/run/secrets/kubernetes.io/serviceaccount

kubectl exec -n rbac-lab "$NO_TOKEN_POD" -- ls -la /var/run/secrets/kubernetes.io/serviceaccount || true
```

Expected:

```text id="token-path-expected"
no-access Pod has token files.
no-token Pod does not have serviceaccount token files.
```

Call API with no-access ServiceAccount:

```bash id="call-api-no-access"
kubectl exec -n rbac-lab "$NO_ACCESS_POD" -- sh -c '
TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
curl -sS --cacert "$CA" \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/rbac-lab/pods
'
```

Expected:

```text id="api-no-access-result"
Forbidden
```

Call API with pod-reader ServiceAccount:

```bash id="call-api-reader"
kubectl exec -n rbac-lab "$READER_POD" -- sh -c '
TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
curl -sS --cacert "$CA" \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/rbac-lab/pods | head -c 300
echo
'
```

Expected:

```text id="api-reader-result"
JSON response listing Pods
```

Call API with no-token Pod:

```bash id="call-api-no-token"
kubectl exec -n rbac-lab "$NO_TOKEN_POD" -- sh -c '
cat /var/run/secrets/kubernetes.io/serviceaccount/token
' || true
```

Expected:

```text id="api-no-token-result"
No such file or directory
```

Production lesson:

```text id="api-access-rule"
A Pod needs both a mounted ServiceAccount token and RBAC permission.
No token means it cannot authenticate as that ServiceAccount from inside the Pod.
Token with no RBAC means it authenticates but receives Forbidden.
```

---

# 19. Incident 9 — default ServiceAccount Mistake

If you do not set `serviceAccountName`, a Pod uses the namespace’s `default` ServiceAccount.

Create:

```bash id="default-sa-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/08-default-serviceaccount-mistake.yaml
```

Paste:

```yaml id="default-sa-content"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: default-sa-demo
  namespace: rbac-lab
  labels:
    app: default-sa-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: default-sa-demo
  template:
    metadata:
      labels:
        app: default-sa-demo
    spec:
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

```bash id="apply-default-sa"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests/08-default-serviceaccount-mistake.yaml

kubectl rollout status deployment/default-sa-demo -n rbac-lab --timeout=120s
```

Check Pod spec:

```bash id="check-default-sa"
POD="$(kubectl get pod -n rbac-lab -l app=default-sa-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl get pod "$POD" -n rbac-lab -o jsonpath='{.spec.serviceAccountName}'
echo
```

Expected:

```text id="default-sa-expected"
default
```

Test permission:

```bash id="test-default-sa"
kubectl auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:default \
  -n rbac-lab
```

Expected usually:

```text id="default-sa-no"
no
```

Production rule:

```text id="default-sa-rule"
Do not rely on the default ServiceAccount for application workloads.
Create a dedicated ServiceAccount per app or controller.
```

RBAC good practices recommend avoiding default token auto-mounting where it is not needed, and Kubernetes security guidance commonly recommends setting `automountServiceAccountToken: false` unless the workload needs API access. ([Kubernetes][4])

---

# 20. Create RBAC Summary Script

```bash id="summary-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-summary.sh
```

Paste:

```bash id="summary-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-rbac-lab}"

echo "===== RBAC Summary ====="
echo "Namespace: $NAMESPACE"

echo
echo "ServiceAccounts:"
kubectl get serviceaccount -n "$NAMESPACE" -o wide || true

echo
echo "Roles:"
kubectl get role -n "$NAMESPACE" || true

echo
echo "RoleBindings:"
kubectl get rolebinding -n "$NAMESPACE" || true

echo
echo "ClusterRoles matching rbac-demo:"
kubectl get clusterrole | grep rbac-demo || true

echo
echo "ClusterRoleBindings matching rbac-demo:"
kubectl get clusterrolebinding | grep rbac-demo || true

echo
echo "Workloads:"
kubectl get deploy,pods -n "$NAMESPACE" -o wide || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30 || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-summary.sh
```

Run:

```bash id="run-summary"
NAMESPACE=rbac-lab \
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-summary.sh
```

---

# 21. Create RBAC `can-i` Matrix Script

```bash id="matrix-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-can-i-matrix.sh
```

Paste:

```bash id="matrix-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-rbac-lab}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-pod-reader-sa}"

IDENTITY="system:serviceaccount:${NAMESPACE}:${SERVICE_ACCOUNT}"

echo "===== RBAC can-i Matrix ====="
echo "Namespace: $NAMESPACE"
echo "ServiceAccount: $SERVICE_ACCOUNT"
echo "Identity: $IDENTITY"

checks=(
  "get pods"
  "list pods"
  "watch pods"
  "get pods/log"
  "delete pods"
  "get configmaps"
  "list configmaps"
  "get secrets"
  "list secrets"
  "create deployments.apps"
  "update deployments.apps"
  "patch deployments.apps"
)

for check in "${checks[@]}"; do
  echo
  echo "$ check: $check"
  kubectl auth can-i $check --as="$IDENTITY" -n "$NAMESPACE"
done

echo
echo "Cluster-scoped checks:"
kubectl auth can-i list nodes --as="$IDENTITY" || true
kubectl auth can-i get namespaces --as="$IDENTITY" || true
```

Make executable:

```bash id="chmod-matrix"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-can-i-matrix.sh
```

Run:

```bash id="run-matrix"
NAMESPACE=rbac-lab SERVICE_ACCOUNT=pod-reader-sa \
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-can-i-matrix.sh
```

---

# 22. Create RoleBinding Subject Audit Script

```bash id="subject-audit-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-subject-audit.sh
```

Paste:

```bash id="subject-audit-content"
#!/usr/bin/env bash
set -euo pipefail

SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-pod-reader-sa}"
SERVICE_ACCOUNT_NAMESPACE="${SERVICE_ACCOUNT_NAMESPACE:-rbac-lab}"

echo "===== RBAC Subject Audit ====="
echo "ServiceAccount: $SERVICE_ACCOUNT"
echo "ServiceAccount namespace: $SERVICE_ACCOUNT_NAMESPACE"

echo
echo "Namespaced RoleBindings referencing ServiceAccount:"
kubectl get rolebinding -A -o json | jq -r \
  --arg sa "$SERVICE_ACCOUNT" \
  --arg ns "$SERVICE_ACCOUNT_NAMESPACE" '
  .items[]
  | select(.subjects != null)
  | select(.subjects[]? | .kind == "ServiceAccount" and .name == $sa and .namespace == $ns)
  | [.metadata.namespace, .metadata.name, .roleRef.kind, .roleRef.name] | @tsv
' | column -t || true

echo
echo "ClusterRoleBindings referencing ServiceAccount:"
kubectl get clusterrolebinding -o json | jq -r \
  --arg sa "$SERVICE_ACCOUNT" \
  --arg ns "$SERVICE_ACCOUNT_NAMESPACE" '
  .items[]
  | select(.subjects != null)
  | select(.subjects[]? | .kind == "ServiceAccount" and .name == $sa and .namespace == $ns)
  | [.metadata.name, .roleRef.kind, .roleRef.name] | @tsv
' | column -t || true
```

Make executable:

```bash id="chmod-subject-audit"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-subject-audit.sh
```

Run:

```bash id="run-subject-audit"
SERVICE_ACCOUNT=pod-reader-sa SERVICE_ACCOUNT_NAMESPACE=rbac-lab \
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-subject-audit.sh
```

---

# 23. Create In-Cluster API Test Script

```bash id="api-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/incluster-api-test.sh
```

Paste:

```bash id="api-script-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-rbac-lab}"
POD_LABEL="${POD_LABEL:-app=api-caller-pod-reader}"
API_PATH="${API_PATH:-/api/v1/namespaces/rbac-lab/pods}"

POD="$(kubectl get pod -n "$NAMESPACE" -l "$POD_LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

if [ -z "$POD" ]; then
  echo "No Pod found for label $POD_LABEL in namespace $NAMESPACE"
  exit 1
fi

echo "===== In-Cluster API Test ====="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "API path: $API_PATH"

kubectl exec -n "$NAMESPACE" "$POD" -- sh -c '
if [ ! -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
  echo "No service account token mounted."
  exit 2
fi

TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CA="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

curl -sS --cacert "$CA" \
  -H "Authorization: Bearer $TOKEN" \
  "https://kubernetes.default.svc'"$API_PATH"'" | head -c 1000
echo
'
```

Make executable:

```bash id="chmod-api-script"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/incluster-api-test.sh
```

Run:

```bash id="run-api-script-reader"
NAMESPACE=rbac-lab POD_LABEL='app=api-caller-pod-reader' \
API_PATH='/api/v1/namespaces/rbac-lab/pods' \
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/incluster-api-test.sh
```

Run no-access test:

```bash id="run-api-script-no-access"
NAMESPACE=rbac-lab POD_LABEL='app=api-caller-no-access' \
API_PATH='/api/v1/namespaces/rbac-lab/pods' \
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/incluster-api-test.sh
```

---

# 24. Run All RBAC Labs Script

```bash id="run-labs-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/run-rbac-labs.sh
```

Paste:

```bash id="run-labs-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests"

kubectl apply -f "$BASE/00-serviceaccounts.yaml"
kubectl apply -f "$BASE/01-role-without-binding.yaml"
kubectl apply -f "$BASE/02-pod-reader-rbac.yaml"
kubectl apply -f "$BASE/03-missing-verb.yaml"
kubectl apply -f "$BASE/04-wrong-subject.yaml"
kubectl apply -f "$BASE/05-node-reader-clusterrole.yaml"
kubectl apply -f "$BASE/06-clusterrole-with-rolebinding.yaml"
kubectl apply -f "$BASE/07-incluster-api-debug.yaml"
kubectl apply -f "$BASE/08-default-serviceaccount-mistake.yaml"

kubectl rollout status deployment/api-caller-no-access -n rbac-lab --timeout=120s
kubectl rollout status deployment/api-caller-pod-reader -n rbac-lab --timeout=120s
kubectl rollout status deployment/api-caller-no-token -n rbac-lab --timeout=120s
kubectl rollout status deployment/default-sa-demo -n rbac-lab --timeout=120s

echo "RBAC labs applied."
echo
echo "Try:"
echo "NAMESPACE=rbac-lab SERVICE_ACCOUNT=pod-reader-sa ./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/rbac-can-i-matrix.sh"
```

Make executable:

```bash id="chmod-run-labs"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/run-rbac-labs.sh
```

Run:

```bash id="run-labs"
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/run-rbac-labs.sh
```

---

# 25. Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/cleanup-lesson-11-8.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/manifests"

echo "===== Cleanup Lesson 11.8 ====="

kubectl delete -f "$BASE/08-default-serviceaccount-mistake.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-incluster-api-debug.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/06-clusterrole-with-rolebinding.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-node-reader-clusterrole.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/04-wrong-subject.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/03-missing-verb.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/02-pod-reader-rbac.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/01-role-without-binding.yaml" --ignore-not-found=true

kubectl delete rolebinding unbound-pod-reader-fix -n rbac-lab --ignore-not-found=true
kubectl delete rolebinding pod-reader-binding-from-rbac-lab-sa -n rbac-other --ignore-not-found=true

kubectl delete role specific-secret-reader -n rbac-lab --ignore-not-found=true
kubectl delete rolebinding specific-secret-reader-binding -n rbac-lab --ignore-not-found=true
kubectl delete serviceaccount specific-secret-reader-sa -n rbac-lab --ignore-not-found=true
kubectl delete secret app-runtime-secret -n rbac-lab --ignore-not-found=true

kubectl delete namespace rbac-other --ignore-not-found=true
kubectl delete -f "$BASE/00-serviceaccounts.yaml" --ignore-not-found=true

echo "Lesson 11.8 demo resources cleaned."
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/cleanup-lesson-11-8.sh
```

Run cleanup:

```bash id="run-cleanup"
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/cleanup-lesson-11-8.sh
```

---

# 26. Validation Script

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/validate-lesson-11-8.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.8 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/rbac-mental-model.md"
test -f "$BASE/notes/rbac-object-cheatsheet.md"
test -f "$BASE/notes/rbac-debug-commands.md"

test -f "$BASE/manifests/00-serviceaccounts.yaml"
test -f "$BASE/manifests/01-role-without-binding.yaml"
test -f "$BASE/manifests/02-pod-reader-rbac.yaml"
test -f "$BASE/manifests/03-missing-verb.yaml"
test -f "$BASE/manifests/04-wrong-subject.yaml"
test -f "$BASE/manifests/05-node-reader-clusterrole.yaml"
test -f "$BASE/manifests/06-clusterrole-with-rolebinding.yaml"
test -f "$BASE/manifests/07-incluster-api-debug.yaml"
test -f "$BASE/manifests/08-default-serviceaccount-mistake.yaml"

test -x "$BASE/scripts/rbac-summary.sh"
test -x "$BASE/scripts/rbac-can-i-matrix.sh"
test -x "$BASE/scripts/rbac-subject-audit.sh"
test -x "$BASE/scripts/incluster-api-test.sh"
test -x "$BASE/scripts/run-rbac-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-8.sh"

kubectl apply -f "$BASE/manifests/00-serviceaccounts.yaml" >/dev/null
kubectl apply -f "$BASE/manifests/02-pod-reader-rbac.yaml" >/dev/null
kubectl apply -f "$BASE/manifests/05-node-reader-clusterrole.yaml" >/dev/null
kubectl apply -f "$BASE/manifests/06-clusterrole-with-rolebinding.yaml" >/dev/null

kubectl get namespace rbac-lab >/dev/null
kubectl get serviceaccount pod-reader-sa -n rbac-lab >/dev/null
kubectl get role pod-reader -n rbac-lab >/dev/null
kubectl get rolebinding pod-reader-binding -n rbac-lab >/dev/null
kubectl get clusterrole rbac-demo-node-reader >/dev/null
kubectl get clusterrolebinding rbac-demo-node-reader-binding >/dev/null

POD_LIST_ALLOWED="$(kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:pod-reader-sa -n rbac-lab)"
SECRET_LIST_ALLOWED="$(kubectl auth can-i list secrets --as=system:serviceaccount:rbac-lab:pod-reader-sa -n rbac-lab)"
NODE_LIST_ALLOWED="$(kubectl auth can-i list nodes --as=system:serviceaccount:rbac-lab:node-reader-sa)"

if [ "$POD_LIST_ALLOWED" != "yes" ]; then
  echo "ERROR: pod-reader-sa should be able to list pods in rbac-lab"
  exit 1
fi

if [ "$SECRET_LIST_ALLOWED" != "no" ]; then
  echo "ERROR: pod-reader-sa should not list secrets"
  exit 1
fi

if [ "$NODE_LIST_ALLOWED" != "yes" ]; then
  echo "ERROR: node-reader-sa should list nodes"
  exit 1
fi

echo "Lesson 11.8 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/validate-lesson-11-8.sh
```

Run:

```bash id="run-validation"
./11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/scripts/validate-lesson-11-8.sh
```

---

# 27. Create RBAC Troubleshooting Runbook

```bash id="runbook"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/runbooks/rbac-permission-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# RBAC Permission Troubleshooting Runbook

## 1. Capture the Forbidden error

Look for:

- user
- verb
- resource
- API group
- namespace

Example:

```text
User "system:serviceaccount:dev:app-sa" cannot list resource "pods" in API group "" in the namespace "dev"
````

## 2. Test with kubectl auth can-i

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:dev:app-sa \
  -n dev
```

## 3. Check ServiceAccount

```bash
kubectl get serviceaccount app-sa -n dev
kubectl describe serviceaccount app-sa -n dev
```

## 4. Check Role and RoleBinding

```bash
kubectl get role,rolebinding -n dev
kubectl describe role ROLE -n dev
kubectl describe rolebinding ROLEBINDING -n dev
```

Check:

* correct subject kind
* correct ServiceAccount name
* correct ServiceAccount namespace
* correct roleRef
* correct verbs
* correct resources
* correct API group

## 5. Check ClusterRole and ClusterRoleBinding

```bash
kubectl get clusterrole | grep APP
kubectl get clusterrolebinding | grep APP
kubectl describe clusterrole CLUSTERROLE
kubectl describe clusterrolebinding CLUSTERROLEBINDING
```

Use for:

* cluster-scoped resources
* cross-namespace controller permissions
* reusable roles

## 6. Common Causes

| Symptom                              | Likely Cause                                             |
| ------------------------------------ | -------------------------------------------------------- |
| Forbidden                            | missing RoleBinding or verb                              |
| Role exists but denied               | Role is not bound                                        |
| Works in one namespace only          | RoleBinding is namespace scoped                          |
| Cannot list nodes                    | needs ClusterRole and ClusterRoleBinding                 |
| Pod cannot access API                | no token, wrong ServiceAccount, or missing RBAC          |
| ArgoCD sync Forbidden                | ArgoCD controller lacks permission                       |
| Controller fails watch               | missing list/watch verbs                                 |
| Secret access denied                 | intentional least privilege or missing secret permission |
| Works with kubectl admin but not Pod | Pod uses different ServiceAccount                        |

## 7. Fix Safely

Prefer:

* add missing verb only
* add missing resource only
* bind in the target namespace only
* use RoleBinding before ClusterRoleBinding when possible
* avoid wildcard permissions
* avoid broad Secret access
* avoid cluster-admin for apps

## Golden Rule

Who is doing what, on which resource, in which namespace?

````

---

# 28. Create Production RBAC Design Runbook

```bash id="prod-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.8-rbac-permission-troubleshooting/runbooks/production-rbac-design-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production RBAC Design Runbook

## Principles

- Create dedicated ServiceAccounts per workload.
- Disable automountServiceAccountToken when API access is not needed.
- Use Role and RoleBinding for namespace-local permissions.
- Use ClusterRoleBinding only for cluster-wide needs.
- Avoid cluster-admin for applications.
- Avoid wildcards unless justified.
- Avoid list/watch secrets.
- Use resourceNames for specific Secret access when practical.
- Audit RoleBindings and ClusterRoleBindings.
- Test with kubectl auth can-i before deployment.

## Good Pattern

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: app
automountServiceAccountToken: false
````

If API access is needed:

```yaml
automountServiceAccountToken: true
```

Then add the smallest Role and RoleBinding required.

## Review Checklist

* Does the workload need Kubernetes API access?
* Which exact resource does it need?
* Which exact verb does it need?
* Which namespace?
* Is cluster scope required?
* Are secrets involved?
* Can access be narrowed with resourceNames?
* Has can-i validation passed?

````

---

# 29. Real Production Debug Mapping

```text id="prod-debug-map"
Forbidden:
  authenticated identity lacks authorization.

401 Unauthorized:
  authentication failed or token missing/invalid.

Role exists but still denied:
  RoleBinding missing or wrong subject.

RoleBinding exists but still denied:
  wrong namespace, wrong subject namespace, wrong roleRef, missing verb/resource.

get works but list fails:
  missing list verb.

list works but controller fails:
  missing watch verb.

Pod can authenticate but gets Forbidden:
  token exists, RBAC missing.

Pod has no token file:
  automountServiceAccountToken false or projected token disabled.

Works in dev but not staging:
  binding exists in dev namespace only.

Cannot access nodes/namespaces:
  cluster-scoped resource needs ClusterRole/ClusterRoleBinding.

ArgoCD or controller Forbidden:
  controller ServiceAccount lacks permissions for target resource.
````

---

# 30. Common Mistakes

## Mistake 1: Creating a Role but no RoleBinding

A Role alone grants nothing.

---

## Mistake 2: Binding the wrong ServiceAccount

Check:

```bash id="wrong-sa-check"
kubectl describe rolebinding ROLEBINDING -n NAMESPACE
```

---

## Mistake 3: Forgetting ServiceAccount namespace in subject

For ServiceAccount subjects, namespace matters.

```yaml id="sa-subject"
subjects:
  - kind: ServiceAccount
    name: app-sa
    namespace: app
```

---

## Mistake 4: Using ClusterRoleBinding unnecessarily

Bad habit:

```text id="cluster-admin-bad"
App fails with Forbidden.
Give cluster-admin.
```

Better:

```text id="least-privilege-good"
Identify exact missing verb/resource/namespace.
Grant the smallest permission.
```

---

## Mistake 5: Allowing broad Secret access

Avoid:

```yaml id="bad-secret-access"
resources: ["secrets"]
verbs: ["get", "list", "watch"]
```

unless there is a strong reason.

---

## Mistake 6: Leaving tokens mounted when not needed

Use:

```yaml id="token-disable"
automountServiceAccountToken: false
```

for workloads that do not need Kubernetes API access.

---

# 31. Interview Explanation

Use this:

```text id="interview-answer"
When troubleshooting Kubernetes RBAC, I start by reading the Forbidden error carefully. It tells me the identity, verb, resource, API group, and namespace. Then I reproduce the authorization check with kubectl auth can-i, often impersonating the ServiceAccount using --as=system:serviceaccount:namespace:name.

I inspect the ServiceAccount, Role, RoleBinding, ClusterRole, and ClusterRoleBinding. I check for common issues such as a Role existing without a binding, missing verbs like list or watch, wrong subject name, wrong ServiceAccount namespace, binding in the wrong namespace, or using a Role for cluster-scoped resources such as nodes.

For in-cluster API access, I also verify whether the ServiceAccount token is mounted. A Pod with no token cannot authenticate, while a Pod with a token but missing RBAC will authenticate and then receive Forbidden. In production, I use least privilege, dedicated ServiceAccounts, RoleBindings for namespace-scoped access, ClusterRoleBindings only when required, and I disable automountServiceAccountToken when workloads do not need API access.
```

Resume bullet:

```text id="resume-bullet"
Built Kubernetes RBAC troubleshooting labs covering Forbidden errors, ServiceAccount identity, Role vs ClusterRole, RoleBinding vs ClusterRoleBinding, kubectl auth can-i impersonation, missing verbs, wrong namespace bindings, wrong subjects, in-cluster API access, automountServiceAccountToken behavior, Secret access minimization, validation scripts, and production least-privilege runbooks.
```

---

# 32. Commit Lesson 11.8

```bash id="commit"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes RBAC permission troubleshooting labs"

git push
```

---

# 33. Next Lesson

```text id="next-lesson"
Lesson 11.9 — Node Pressure and Kubelet Troubleshooting
```

We will cover:

```text id="next-topics"
Node NotReady
MemoryPressure
DiskPressure
PIDPressure
kubelet issues
container runtime issues
Pod eviction
node allocatable vs capacity
system-reserved and kube-reserved concepts
image garbage collection
ephemeral-storage problems
debugging Pods stuck on one node
cordon and drain
safe node maintenance workflow
production node incident runbook
```

[1]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/?utm_source=chatgpt.com "Using RBAC Authorization"
[2]: https://kubernetes.io/docs/reference/access-authn-authz/authorization/?utm_source=chatgpt.com "Authorization"
[3]: https://kubernetes.io/docs/concepts/security/service-accounts/?utm_source=chatgpt.com "Service Accounts"
[4]: https://kubernetes.io/docs/concepts/security/rbac-good-practices/?utm_source=chatgpt.com "Role Based Access Control Good Practices"
