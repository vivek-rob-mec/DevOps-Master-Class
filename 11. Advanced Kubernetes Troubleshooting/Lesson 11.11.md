# Module 11 — Advanced Kubernetes Troubleshooting

# Lesson 11.11 — Storage, PVC, PV, StatefulSet, and Volume Troubleshooting

In Lesson 11.10, you learned **scheduling failure troubleshooting**:

```text id="recap-11-10"
FailedScheduling events
insufficient CPU and memory
nodeSelector mismatch
required node affinity mismatch
preferred affinity behavior
taints and tolerations
pod anti-affinity
topology spread constraints
ResourceQuota blocking
WaitForFirstConsumer concept
```

Now we move to **Kubernetes storage troubleshooting**.

Storage issues are tricky because they involve multiple layers:

```text id="storage-layers"
Pod
  ↓
PVC
  ↓
PV
  ↓
StorageClass
  ↓
CSI driver / local provisioner / cloud disk
  ↓
node mount
  ↓
filesystem permissions
  ↓
application read/write behavior
```

Common symptoms:

```text id="storage-symptoms"
PVC Pending
Pod stuck Pending
Pod stuck ContainerCreating
failed to mount volume
unbound PersistentVolumeClaims
StorageClass not found
PV/PVC accessModes mismatch
PV/PVC storageClass mismatch
ReadWriteOnce multi-node confusion
StatefulSet PVC not deleted
permission denied on mounted volume
subPath mount error
volume expansion stuck
WaitForFirstConsumer confusion
```

PersistentVolumes are cluster storage resources, PersistentVolumeClaims are user requests for storage, and StorageClasses allow dynamic provisioning of volumes with different storage backends and binding behavior. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/persistent-volumes/), [kubernetes.io](https://kubernetes.io/docs/concepts/storage/storage-classes/))

---

# 1. What We Will Cover

```text id="lesson-map"
11.11.1   Storage mental model
11.11.2   PV vs PVC vs StorageClass
11.11.3   PVC Pending
11.11.4   StorageClass missing
11.11.5   PV/PVC binding mismatch
11.11.6   accessModes mismatch
11.11.7   volumeMode mismatch
11.11.8   WaitForFirstConsumer
11.11.9   Pod stuck ContainerCreating due to mount
11.11.10  ReadWriteOnce multi-node confusion
11.11.11  StatefulSet volumeClaimTemplates
11.11.12  StatefulSet PVC retention
11.11.13  filesystem permissions
11.11.14  initContainer volume fix pattern
11.11.15  subPath mount mistakes
11.11.16  volume expansion concept
11.11.17  production storage incident workflow
11.11.18  scripts, runbooks, validation, cleanup
```

---

# 2. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash id="tree-folder"
tree -L 3 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset
```

---

# 3. Storage Mental Model

Kubernetes storage has a binding chain:

```text id="storage-chain"
Pod
  references PVC
PVC
  requests storage
PV
  satisfies the claim
StorageClass
  defines dynamic provisioning behavior
CSI driver / provisioner
  creates or attaches actual storage
Node
  mounts the volume
Container
  reads/writes filesystem
```

A Pod can fail even if the app image is correct because storage is not ready.

Typical flow:

```text id="storage-flow"
1. PVC created.
2. StorageClass provisions PV, or static PV already exists.
3. PVC binds to PV.
4. Pod references PVC.
5. Scheduler places Pod on compatible node.
6. kubelet mounts volume.
7. container starts.
8. app reads/writes mounted path.
```

If any link breaks, symptoms differ:

```text id="symptom-map"
PVC Pending:
  provisioning or binding problem

Pod Pending:
  PVC unbound or volume topology scheduling problem

Pod ContainerCreating:
  volume mount/attach problem

App CrashLoopBackOff:
  app cannot read/write mounted path

Permission denied:
  filesystem ownership/securityContext issue
```

Kubernetes supports several PersistentVolume access modes, including `ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`, and `ReadWriteOncePod`; access modes describe how a volume can be mounted by nodes or Pods, but support depends on the storage plugin. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/persistent-volumes/))

---

# 4. Create Storage Mental Model Notes

```bash id="mental-model-note"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/notes/storage-mental-model.md
```

Paste:

```markdown id="mental-model-content"
# Kubernetes Storage Mental Model

## Storage Chain

Pod -> PVC -> PV -> StorageClass -> CSI/provisioner -> Node mount -> Container filesystem

## Main Objects

PersistentVolume:
  Cluster storage resource.

PersistentVolumeClaim:
  Namespaced request for storage.

StorageClass:
  Defines dynamic provisioning behavior.

StatefulSet volumeClaimTemplates:
  Creates stable per-Pod PVCs.

## Common Symptoms

PVC Pending:
  StorageClass missing, no matching PV, provisioner issue, topology issue.

Pod Pending:
  PVC unbound, storage topology conflict, WaitForFirstConsumer.

Pod ContainerCreating:
  volume attach/mount failure.

CrashLoopBackOff:
  app cannot use mounted volume, permission issue, missing path.

Permission denied:
  filesystem ownership, runAsUser, fsGroup, readOnly mount.

## Golden Rule

Always debug storage from PVC first, then PV, then Pod events, then node mount/application permissions.
```

---

# 5. First Storage Debug Commands

```bash id="debug-note"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/notes/storage-debug-commands.md
```

Paste:

````markdown id="debug-note-content"
# Storage Debug Commands

## PVCs

```bash
kubectl get pvc -n NAMESPACE
kubectl describe pvc PVC_NAME -n NAMESPACE
kubectl get pvc PVC_NAME -n NAMESPACE -o yaml
````

## PVs

```bash id="pv-debug"
kubectl get pv
kubectl describe pv PV_NAME
kubectl get pv PV_NAME -o yaml
```

## StorageClasses

```bash id="sc-debug"
kubectl get storageclass
kubectl describe storageclass STORAGECLASS_NAME
```

## Pods

```bash id="pod-debug"
kubectl get pods -n NAMESPACE -o wide
kubectl describe pod POD_NAME -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
```

## StatefulSets

```bash id="sts-debug"
kubectl get statefulset -n NAMESPACE
kubectl describe statefulset STATEFULSET_NAME -n NAMESPACE
kubectl get pvc -n NAMESPACE
kubectl get pods -n NAMESPACE -l app=APP -o wide
```

## Volume mounts inside container

```bash id="mount-debug"
kubectl exec -n NAMESPACE POD_NAME -- df -h
kubectl exec -n NAMESPACE POD_NAME -- mount
kubectl exec -n NAMESPACE POD_NAME -- ls -la /data
kubectl exec -n NAMESPACE POD_NAME -- sh -c 'echo test > /data/test.txt'
```

## Storage events

```bash id="events-debug"
kubectl get events -A --sort-by=.lastTimestamp | grep -i -E 'volume|pvc|pv|mount|attach|storage|provision' || true
```

````

---

# 6. Create Namespace and Check StorageClass

Create namespace:

```bash id="create-ns"
kubectl create namespace storage-lab --dry-run=client -o yaml | kubectl apply -f -
````

Check available StorageClasses:

```bash id="check-sc"
kubectl get storageclass
```

In many local kind clusters, you may see a default StorageClass named `standard`.

Check default:

```bash id="check-default-sc"
kubectl get storageclass -o custom-columns=NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\\.kubernetes\\.io/is-default-class,PROVISIONER:.provisioner,VOLUME_BINDING:.volumeBindingMode
```

If you have no default StorageClass, some dynamic provisioning labs will remain Pending. That is still useful for troubleshooting, but the “healthy dynamic PVC” lab needs a working provisioner.

---

# 7. Lab 1 — Healthy Dynamic PVC

Create a PVC using your default StorageClass.

```bash id="healthy-pvc-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/00-healthy-dynamic-pvc.yaml
```

Paste:

```yaml id="healthy-pvc-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: healthy-dynamic-pvc
  namespace: storage-lab
  labels:
    app: healthy-storage-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthy-storage-demo
  namespace: storage-lab
  labels:
    app: healthy-storage-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: healthy-storage-demo
  template:
    metadata:
      labels:
        app: healthy-storage-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "healthy storage demo started"
              echo "hello-from-pvc" > /data/hello.txt
              cat /data/hello.txt
              sleep 3600
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
            claimName: healthy-dynamic-pvc
```

Apply:

```bash id="apply-healthy-pvc"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/00-healthy-dynamic-pvc.yaml
```

Debug:

```bash id="debug-healthy-pvc"
kubectl get pvc -n storage-lab
kubectl describe pvc healthy-dynamic-pvc -n storage-lab

kubectl get pv

kubectl rollout status deployment/healthy-storage-demo -n storage-lab --timeout=120s

POD="$(kubectl get pod -n storage-lab -l app=healthy-storage-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n storage-lab

kubectl exec "$POD" -n storage-lab -- cat /data/hello.txt
```

Expected:

```text id="healthy-expected"
PVC Bound
Pod Running
/data/hello.txt exists
```

Clean later, not now:

```bash id="healthy-clean-later"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/00-healthy-dynamic-pvc.yaml --ignore-not-found=true
```

---

# 8. Lab 2 — PVC Pending Due to Missing StorageClass

Create a PVC that references a StorageClass that does not exist.

```bash id="missing-sc-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/01-missing-storageclass.yaml
```

Paste:

```yaml id="missing-sc-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: missing-storageclass-pvc
  namespace: storage-lab
  labels:
    app: missing-storageclass-demo
spec:
  storageClassName: storage-class-does-not-exist
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: missing-storageclass-pod
  namespace: storage-lab
  labels:
    app: missing-storageclass-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo should-not-start; sleep 3600"]
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
        claimName: missing-storageclass-pvc
```

Apply:

```bash id="apply-missing-sc"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/01-missing-storageclass.yaml
```

Debug:

```bash id="debug-missing-sc"
kubectl get pvc missing-storageclass-pvc -n storage-lab

kubectl describe pvc missing-storageclass-pvc -n storage-lab

kubectl get pod missing-storageclass-pod -n storage-lab

kubectl describe pod missing-storageclass-pod -n storage-lab

kubectl get events -n storage-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="missing-sc-expected"
PVC Pending
StorageClass not found
Pod Pending because PVC is not bound
```

Fix option A — change PVC to an existing StorageClass.

PVC `storageClassName` is effectively part of the binding request, so the clean fix is usually delete/recreate the PVC with the correct class:

```bash id="fix-missing-sc"
kubectl delete pod missing-storageclass-pod -n storage-lab --ignore-not-found=true
kubectl delete pvc missing-storageclass-pvc -n storage-lab --ignore-not-found=true

DEFAULT_SC="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{end}')"

echo "Default StorageClass: $DEFAULT_SC"
```

Create fixed PVC and Pod:

```bash id="fix-missing-sc-apply"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: missing-storageclass-pvc
  namespace: storage-lab
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
  name: missing-storageclass-pod
  namespace: storage-lab
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo fixed-storageclass > /data/status.txt; sleep 3600"]
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
        claimName: missing-storageclass-pvc
EOF
```

Validate:

```bash id="validate-missing-sc"
kubectl wait --for=condition=Ready pod/missing-storageclass-pod -n storage-lab --timeout=120s

kubectl get pvc missing-storageclass-pvc -n storage-lab

kubectl exec -n storage-lab missing-storageclass-pod -- cat /data/status.txt
```

Clean:

```bash id="clean-missing-sc"
kubectl delete pod missing-storageclass-pod -n storage-lab --ignore-not-found=true
kubectl delete pvc missing-storageclass-pvc -n storage-lab --ignore-not-found=true
```

---

# 9. Lab 3 — Static PV/PVC StorageClass Mismatch

A PVC can remain Pending if no PV matches its requirements.

Binding depends on several fields:

```text id="binding-factors"
storageClassName
capacity
accessModes
volumeMode
selector
availability/topology
```

Create a PV with one StorageClass and a PVC asking for another.

```bash id="sc-mismatch-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/02-pv-pvc-storageclass-mismatch.yaml
```

Paste:

```yaml id="sc-mismatch-content"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv-sc-standard
  labels:
    app: pv-pvc-mismatch
spec:
  capacity:
    storage: 256Mi
  accessModes:
    - ReadWriteOnce
  storageClassName: static-standard
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: /tmp/static-pv-sc-standard
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-sc-mismatch
  namespace: storage-lab
  labels:
    app: pv-pvc-mismatch
spec:
  storageClassName: static-premium
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
```

Apply:

```bash id="apply-sc-mismatch"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/02-pv-pvc-storageclass-mismatch.yaml
```

Debug:

```bash id="debug-sc-mismatch"
kubectl get pv static-pv-sc-standard

kubectl get pvc static-pvc-sc-mismatch -n storage-lab

kubectl describe pvc static-pvc-sc-mismatch -n storage-lab

kubectl describe pv static-pv-sc-standard
```

Expected:

```text id="sc-mismatch-expected"
PV Available
PVC Pending
PVC asks for static-premium
PV offers static-standard
```

Fix by recreating PVC with matching `storageClassName`.

```bash id="fix-sc-mismatch"
kubectl delete pvc static-pvc-sc-mismatch -n storage-lab

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-sc-mismatch
  namespace: storage-lab
  labels:
    app: pv-pvc-mismatch
spec:
  storageClassName: static-standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
EOF
```

Validate:

```bash id="validate-sc-mismatch"
kubectl get pvc static-pvc-sc-mismatch -n storage-lab
kubectl get pv static-pv-sc-standard
```

Expected:

```text id="sc-mismatch-fixed"
PVC Bound
PV Bound
```

Clean:

```bash id="clean-sc-mismatch"
kubectl delete pvc static-pvc-sc-mismatch -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-sc-standard --ignore-not-found=true
```

---

# 10. Lab 4 — AccessModes Mismatch

A PVC requesting `ReadWriteMany` cannot bind to a PV that only supports `ReadWriteOnce`.

```bash id="access-mismatch-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/03-accessmodes-mismatch.yaml
```

Paste:

```yaml id="access-mismatch-content"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv-rwo-only
  labels:
    app: accessmodes-mismatch
spec:
  capacity:
    storage: 256Mi
  accessModes:
    - ReadWriteOnce
  storageClassName: static-access-demo
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: /tmp/static-pv-rwo-only
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-asks-rwx
  namespace: storage-lab
  labels:
    app: accessmodes-mismatch
spec:
  storageClassName: static-access-demo
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 256Mi
```

Apply:

```bash id="apply-access-mismatch"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/03-accessmodes-mismatch.yaml
```

Debug:

```bash id="debug-access-mismatch"
kubectl get pv static-pv-rwo-only
kubectl get pvc static-pvc-asks-rwx -n storage-lab
kubectl describe pvc static-pvc-asks-rwx -n storage-lab
```

Expected:

```text id="access-mismatch-expected"
PVC Pending
No matching PV because accessModes differ
```

Fix by recreating PVC with `ReadWriteOnce`:

```bash id="fix-access-mismatch"
kubectl delete pvc static-pvc-asks-rwx -n storage-lab

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-asks-rwx
  namespace: storage-lab
spec:
  storageClassName: static-access-demo
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
EOF
```

Validate:

```bash id="validate-access-mismatch"
kubectl get pvc static-pvc-asks-rwx -n storage-lab
kubectl get pv static-pv-rwo-only
```

Clean:

```bash id="clean-access-mismatch"
kubectl delete pvc static-pvc-asks-rwx -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-rwo-only --ignore-not-found=true
```

Production note:

```text id="access-prod-note"
Many cloud block volumes support ReadWriteOnce, not ReadWriteMany.
For shared multi-writer storage, use a backend that supports RWX, such as NFS/EFS/CephFS depending on environment.
```

---

# 11. Lab 5 — VolumeMode Mismatch

Kubernetes supports `Filesystem` and `Block` volume modes. A PVC requesting `Block` will not bind to a PV defined as `Filesystem`, and vice versa. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/persistent-volumes/))

Create:

```bash id="volumemode-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/04-volumemode-mismatch.yaml
```

Paste:

```yaml id="volumemode-content"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv-filesystem
  labels:
    app: volumemode-mismatch
spec:
  capacity:
    storage: 256Mi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: static-volume-mode-demo
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: /tmp/static-pv-filesystem
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-block-request
  namespace: storage-lab
  labels:
    app: volumemode-mismatch
spec:
  storageClassName: static-volume-mode-demo
  volumeMode: Block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
```

Apply:

```bash id="apply-volumemode"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/04-volumemode-mismatch.yaml
```

Debug:

```bash id="debug-volumemode"
kubectl get pv static-pv-filesystem
kubectl get pvc static-pvc-block-request -n storage-lab
kubectl describe pvc static-pvc-block-request -n storage-lab
```

Expected:

```text id="volumemode-expected"
PVC Pending
volumeMode mismatch
```

Fix:

```bash id="fix-volumemode"
kubectl delete pvc static-pvc-block-request -n storage-lab

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc-block-request
  namespace: storage-lab
spec:
  storageClassName: static-volume-mode-demo
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
EOF
```

Validate:

```bash id="validate-volumemode"
kubectl get pvc static-pvc-block-request -n storage-lab
```

Clean:

```bash id="clean-volumemode"
kubectl delete pvc static-pvc-block-request -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-filesystem --ignore-not-found=true
```

---

# 12. Lab 6 — WaitForFirstConsumer

`WaitForFirstConsumer` delays binding and provisioning until a Pod using the PVC is created, so scheduling can consider topology such as node zone and volume placement. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/storage-classes/))

Create a concept StorageClass and PVC:

```bash id="wffc-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/05-waitforfirstconsumer.yaml
```

Paste:

```yaml id="wffc-content"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-lab-wffc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wffc-pvc
  namespace: storage-lab
  labels:
    app: wffc-demo
spec:
  storageClassName: storage-lab-wffc
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
```

Apply:

```bash id="apply-wffc"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/05-waitforfirstconsumer.yaml
```

Debug PVC:

```bash id="debug-wffc"
kubectl get pvc wffc-pvc -n storage-lab
kubectl describe pvc wffc-pvc -n storage-lab
```

Expected:

```text id="wffc-expected"
PVC Pending
waiting for first consumer
```

Create consumer Pod:

```bash id="wffc-consumer-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/06-wffc-consumer-pod.yaml
```

Paste:

```yaml id="wffc-consumer-content"
apiVersion: v1
kind: Pod
metadata:
  name: wffc-consumer-pod
  namespace: storage-lab
  labels:
    app: wffc-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo using wffc pvc; sleep 3600"]
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
        claimName: wffc-pvc
```

Apply:

```bash id="apply-wffc-consumer"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/06-wffc-consumer-pod.yaml
```

Debug:

```bash id="debug-wffc-consumer"
kubectl get pod wffc-consumer-pod -n storage-lab
kubectl describe pod wffc-consumer-pod -n storage-lab
kubectl describe pvc wffc-pvc -n storage-lab
kubectl get events -n storage-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="wffc-consumer-expected"
Pod may remain Pending because this concept StorageClass has no dynamic provisioner and no matching PV.
The important learning is how PVC binding interacts with Pod scheduling.
```

Clean:

```bash id="clean-wffc"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/06-wffc-consumer-pod.yaml --ignore-not-found=true
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/05-waitforfirstconsumer.yaml --ignore-not-found=true
```

---

# 13. Lab 7 — Pod Stuck ContainerCreating Due to Mount Failure

This simulates a Pod that references a PVC that does not exist.

```bash id="missing-pvc-pod-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/07-pod-missing-pvc.yaml
```

Paste:

```yaml id="missing-pvc-pod-content"
apiVersion: v1
kind: Pod
metadata:
  name: pod-missing-pvc
  namespace: storage-lab
  labels:
    app: pod-missing-pvc
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo should-not-start; sleep 3600"]
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
        claimName: pvc-does-not-exist
```

Apply:

```bash id="apply-missing-pvc-pod"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/07-pod-missing-pvc.yaml
```

Debug:

```bash id="debug-missing-pvc-pod"
kubectl get pod pod-missing-pvc -n storage-lab

kubectl describe pod pod-missing-pvc -n storage-lab

kubectl get pvc -n storage-lab

kubectl get events -n storage-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="missing-pvc-pod-expected"
Pod Pending or ContainerCreating depending on cluster behavior.
Events mention persistentvolumeclaim pvc-does-not-exist not found.
```

Fix by creating the PVC:

```bash id="fix-missing-pvc-pod"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-does-not-exist
  namespace: storage-lab
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
EOF
```

Validate:

```bash id="validate-missing-pvc-pod"
kubectl wait --for=condition=Ready pod/pod-missing-pvc -n storage-lab --timeout=120s || true

kubectl get pod pod-missing-pvc -n storage-lab
kubectl get pvc pvc-does-not-exist -n storage-lab
```

Clean:

```bash id="clean-missing-pvc-pod"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/07-pod-missing-pvc.yaml --ignore-not-found=true
kubectl delete pvc pvc-does-not-exist -n storage-lab --ignore-not-found=true
```

---

# 14. Lab 8 — ReadWriteOnce Multi-Node Confusion

`ReadWriteOnce` usually means the volume can be mounted read-write by a single node. It does not mean “only one Pod forever,” and behavior depends on whether Pods land on the same node or different nodes. Kubernetes also has `ReadWriteOncePod`, which restricts a volume to a single Pod across the cluster for supported CSI drivers. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/persistent-volumes/))

This lab creates a Deployment with 2 replicas sharing one RWO PVC.

```bash id="rwo-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/08-rwo-multinode-confusion.yaml
```

Paste:

```yaml id="rwo-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-rwo-pvc
  namespace: storage-lab
  labels:
    app: rwo-confusion
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rwo-confusion
  namespace: storage-lab
  labels:
    app: rwo-confusion
spec:
  replicas: 2
  selector:
    matchLabels:
      app: rwo-confusion
  template:
    metadata:
      labels:
        app: rwo-confusion
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "$(hostname) started" >> /data/pods.txt
              cat /data/pods.txt
              sleep 3600
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
            claimName: shared-rwo-pvc
```

Apply:

```bash id="apply-rwo"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/08-rwo-multinode-confusion.yaml
```

Debug:

```bash id="debug-rwo"
kubectl get pvc shared-rwo-pvc -n storage-lab

kubectl get pods -n storage-lab -l app=rwo-confusion -o wide

kubectl get events -n storage-lab --sort-by=.lastTimestamp | tail -n 50
```

Possible outcomes:

```text id="rwo-outcomes"
Both Pods may run if they land on the same node or your local provisioner allows it.
One Pod may get stuck if the volume cannot attach/mount to another node.
On real cloud block storage, RWO multi-node attachment often fails.
```

Production fix pattern:

```text id="rwo-fix"
For shared stateful data:
  use StatefulSet with per-Pod PVCs, or use RWX storage if true sharing is required.
```

Clean:

```bash id="clean-rwo"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/08-rwo-multinode-confusion.yaml --ignore-not-found=true
```

---

# 15. Lab 9 — StatefulSet volumeClaimTemplates

StatefulSets provide stable network identity and stable storage. The `volumeClaimTemplates` field creates a PVC per Pod, giving each replica its own persistent volume. ([kubernetes.io](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/))

Create:

```bash id="sts-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/09-statefulset-volumeclaimtemplates.yaml
```

Paste:

```yaml id="sts-content"
apiVersion: v1
kind: Service
metadata:
  name: storage-sts
  namespace: storage-lab
  labels:
    app: storage-sts
spec:
  clusterIP: None
  selector:
    app: storage-sts
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: storage-sts
  namespace: storage-lab
  labels:
    app: storage-sts
spec:
  serviceName: storage-sts
  replicas: 2
  selector:
    matchLabels:
      app: storage-sts
  template:
    metadata:
      labels:
        app: storage-sts
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "pod=$(hostname)" > /data/identity.txt
              cat /data/identity.txt
              sleep 3600
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
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 256Mi
```

Apply:

```bash id="apply-sts"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/09-statefulset-volumeclaimtemplates.yaml
```

Debug:

```bash id="debug-sts"
kubectl rollout status statefulset/storage-sts -n storage-lab --timeout=180s

kubectl get statefulset storage-sts -n storage-lab

kubectl get pods -n storage-lab -l app=storage-sts -o wide

kubectl get pvc -n storage-lab -l app=storage-sts

kubectl get pvc -n storage-lab | grep data-storage-sts || true
```

Check identity files:

```bash id="check-sts-files"
kubectl exec -n storage-lab storage-sts-0 -- cat /data/identity.txt
kubectl exec -n storage-lab storage-sts-1 -- cat /data/identity.txt
```

Expected:

```text id="sts-expected"
Each Pod has its own PVC:
data-storage-sts-0
data-storage-sts-1
```

Delete one Pod:

```bash id="delete-sts-pod"
kubectl delete pod storage-sts-0 -n storage-lab
```

Wait:

```bash id="wait-sts-pod"
kubectl wait --for=condition=Ready pod/storage-sts-0 -n storage-lab --timeout=180s

kubectl exec -n storage-lab storage-sts-0 -- cat /data/identity.txt
```

Expected:

```text id="sts-persistence-expected"
storage-sts-0 comes back with the same identity and same PVC.
```

Important cleanup behavior:

```text id="sts-cleanup-note"
Deleting a StatefulSet does not automatically delete the PVCs created from volumeClaimTemplates.
This protects data from accidental deletion.
```

StatefulSet storage is stable across Pod rescheduling; Kubernetes documents that the PersistentVolumes associated with a StatefulSet are not deleted when Pods or the StatefulSet are deleted, unless you explicitly manage retention behavior. ([kubernetes.io](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/))

Clean StatefulSet but keep PVCs briefly:

```bash id="clean-sts-app"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/09-statefulset-volumeclaimtemplates.yaml --ignore-not-found=true

kubectl get pvc -n storage-lab | grep data-storage-sts || true
```

Then clean PVCs:

```bash id="clean-sts-pvcs"
kubectl delete pvc data-storage-sts-0 data-storage-sts-1 -n storage-lab --ignore-not-found=true
```

---

# 16. Lab 10 — Filesystem Permission Denied

A common production issue:

```text id="permission-issue"
Container runs as non-root.
Mounted volume is owned by root.
App tries to write.
App gets permission denied.
```

Create:

```bash id="permission-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/10-permission-denied-volume.yaml
```

Paste:

```yaml id="permission-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: permission-denied-pvc
  namespace: storage-lab
  labels:
    app: permission-denied-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: permission-denied-demo
  namespace: storage-lab
  labels:
    app: permission-denied-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: permission-denied-demo
  template:
    metadata:
      labels:
        app: permission-denied-demo
    spec:
      securityContext:
        runAsUser: 10001
        runAsGroup: 10001
        runAsNonRoot: true
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "trying to write as uid=$(id -u) gid=$(id -g)"
              echo test > /data/test.txt
              echo "write succeeded"
              sleep 3600
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
            claimName: permission-denied-pvc
```

Apply:

```bash id="apply-permission"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/10-permission-denied-volume.yaml
```

Debug:

```bash id="debug-permission"
kubectl get pods -n storage-lab -l app=permission-denied-demo

POD="$(kubectl get pod -n storage-lab -l app=permission-denied-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n storage-lab --previous || true
kubectl logs "$POD" -n storage-lab || true

kubectl describe pod "$POD" -n storage-lab
```

Possible result:

```text id="permission-expected"
Permission denied
CrashLoopBackOff
```

Fix with `fsGroup`.

Kubernetes Pod security context supports `fsGroup`, and kubelet may adjust volume ownership/permissions so processes in that group can access the mounted volume. The `fsGroupChangePolicy` field can reduce recursive ownership changes for large volumes. ([kubernetes.io](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/))

Patch:

```bash id="fix-permission-fsgroup"
kubectl patch deployment permission-denied-demo -n storage-lab \
  --type='json' \
  -p='[
    {
      "op": "add",
      "path": "/spec/template/spec/securityContext/fsGroup",
      "value": 10001
    },
    {
      "op": "add",
      "path": "/spec/template/spec/securityContext/fsGroupChangePolicy",
      "value": "OnRootMismatch"
    }
  ]'
```

Validate:

```bash id="validate-permission"
kubectl rollout status deployment/permission-denied-demo -n storage-lab --timeout=180s

POD="$(kubectl get pod -n storage-lab -l app=permission-denied-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n storage-lab

kubectl exec "$POD" -n storage-lab -- ls -la /data
```

Clean:

```bash id="clean-permission"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/10-permission-denied-volume.yaml --ignore-not-found=true
```

---

# 17. Lab 11 — initContainer Permission Fix Pattern

Sometimes `fsGroup` is not enough or the storage driver does not behave as expected. An `initContainer` can prepare directories before the main app starts.

Create:

```bash id="init-permission-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/11-initcontainer-permission-fix.yaml
```

Paste:

```yaml id="init-permission-content"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: init-permission-pvc
  namespace: storage-lab
  labels:
    app: init-permission-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: init-permission-demo
  namespace: storage-lab
  labels:
    app: init-permission-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: init-permission-demo
  template:
    metadata:
      labels:
        app: init-permission-demo
    spec:
      initContainers:
        - name: fix-permissions
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              mkdir -p /data/app
              chown -R 10001:10001 /data/app
              chmod -R 770 /data/app
          volumeMounts:
            - name: data
              mountPath: /data
          securityContext:
            runAsUser: 0
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "uid=$(id -u) gid=$(id -g)"
              echo init-container-fixed > /data/app/result.txt
              cat /data/app/result.txt
              sleep 3600
          securityContext:
            runAsUser: 10001
            runAsGroup: 10001
            runAsNonRoot: true
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
            claimName: init-permission-pvc
```

Apply:

```bash id="apply-init-permission"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/11-initcontainer-permission-fix.yaml
```

Validate:

```bash id="validate-init-permission"
kubectl rollout status deployment/init-permission-demo -n storage-lab --timeout=180s

POD="$(kubectl get pod -n storage-lab -l app=init-permission-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl logs "$POD" -n storage-lab

kubectl exec "$POD" -n storage-lab -- ls -la /data/app
```

Clean:

```bash id="clean-init-permission"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/11-initcontainer-permission-fix.yaml --ignore-not-found=true
```

Production note:

```text id="init-prod-note"
Use initContainers for one-time volume preparation, migrations, or permission fixes.
Avoid running your main container as root just to fix volume ownership.
```

---

# 18. Lab 12 — subPath Mount Mistake

A `subPath` mount can fail if the expected file/directory is missing or if the mount type does not match.

Create a ConfigMap with one file, but mount a missing key via subPath:

```bash id="subpath-manifest"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/12-subpath-mount-mistake.yaml
```

Paste:

```yaml id="subpath-content"
apiVersion: v1
kind: ConfigMap
metadata:
  name: subpath-storage-config
  namespace: storage-lab
  labels:
    app: subpath-mount-demo
data:
  app.conf: |
    mode=demo
---
apiVersion: v1
kind: Pod
metadata:
  name: subpath-mount-demo
  namespace: storage-lab
  labels:
    app: subpath-mount-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/missing.conf; sleep 3600"]
      volumeMounts:
        - name: config
          mountPath: /etc/app/missing.conf
          subPath: missing.conf
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
  volumes:
    - name: config
      configMap:
        name: subpath-storage-config
```

Apply:

```bash id="apply-subpath"
kubectl apply -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/12-subpath-mount-mistake.yaml
```

Debug:

```bash id="debug-subpath"
kubectl get pod subpath-mount-demo -n storage-lab

kubectl describe pod subpath-mount-demo -n storage-lab

kubectl get events -n storage-lab --sort-by=.lastTimestamp | tail -n 50
```

Expected:

```text id="subpath-expected"
Mount/setup failure because subPath key/path does not exist.
```

Fix by using the existing key:

```bash id="fix-subpath"
kubectl delete pod subpath-mount-demo -n storage-lab --ignore-not-found=true

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: subpath-mount-demo
  namespace: storage-lab
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "cat /etc/app/app.conf; sleep 3600"]
      volumeMounts:
        - name: config
          mountPath: /etc/app/app.conf
          subPath: app.conf
      resources:
        requests:
          cpu: "25m"
          memory: "32Mi"
        limits:
          cpu: "100m"
          memory: "64Mi"
  volumes:
    - name: config
      configMap:
        name: subpath-storage-config
EOF
```

Validate:

```bash id="validate-subpath"
kubectl wait --for=condition=Ready pod/subpath-mount-demo -n storage-lab --timeout=120s

kubectl logs subpath-mount-demo -n storage-lab
```

Clean:

```bash id="clean-subpath"
kubectl delete -f 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests/12-subpath-mount-mistake.yaml --ignore-not-found=true
kubectl delete pod subpath-mount-demo -n storage-lab --ignore-not-found=true
kubectl delete configmap subpath-storage-config -n storage-lab --ignore-not-found=true
```

---

# 19. Lab 13 — Volume Expansion Concept

PVC expansion depends on the StorageClass setting `allowVolumeExpansion: true` and support from the underlying volume plugin. Kubernetes documents PVC expansion through editing PVC storage requests when the StorageClass allows it. ([kubernetes.io](https://kubernetes.io/docs/concepts/storage/storage-classes/), [kubernetes.io](https://kubernetes.io/docs/concepts/storage/persistent-volumes/))

Check if your StorageClass allows expansion:

```bash id="check-expansion"
kubectl get storageclass -o custom-columns=NAME:.metadata.name,ALLOW_EXPANSION:.allowVolumeExpansion,PROVISIONER:.provisioner
```

Create expansion concept note manifest:

```bash id="expansion-note"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/notes/volume-expansion-concept.md
```

Paste:

````markdown id="expansion-note-content"
# Volume Expansion Concept

PVC expansion requires:

1. StorageClass has allowVolumeExpansion: true.
2. Storage backend supports expansion.
3. PVC request is increased.
4. Filesystem expansion may happen online or after Pod restart depending on driver/filesystem.

Debug commands:

```bash
kubectl get storageclass
kubectl describe storageclass STORAGECLASS
kubectl get pvc PVC -n NAMESPACE
kubectl describe pvc PVC -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 50
````

Common symptoms:

* PVC resize stuck
* FileSystemResizePending
* backend driver does not support expansion
* StorageClass does not allow expansion
* application still sees old filesystem size

````

Production rule:

```text id="expansion-rule"
Never assume every StorageClass supports expansion.
Check StorageClass and CSI driver capability first.
````

---

# 20. Storage Summary Script

```bash id="summary-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/storage-summary.sh
```

Paste:

```bash id="summary-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-storage-lab}"

echo "===== Storage Summary ====="
echo "Namespace: $NAMESPACE"

echo
echo "StorageClasses:"
kubectl get storageclass -o wide || true

echo
echo "PVCs:"
kubectl get pvc -n "$NAMESPACE" -o wide || true

echo
echo "PVs:"
kubectl get pv -o wide || true

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide || true

echo
echo "StatefulSets:"
kubectl get statefulset -n "$NAMESPACE" || true

echo
echo "Recent storage-related events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | grep -i -E 'volume|pvc|pv|mount|attach|storage|provision|claim' || true

echo
echo "Recent namespace events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 50 || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/storage-summary.sh
```

Run:

```bash id="run-summary"
NAMESPACE=storage-lab \
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/storage-summary.sh
```

---

# 21. PVC Inspector Script

```bash id="pvc-inspector-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/inspect-pvc.sh
```

Paste:

```bash id="pvc-inspector-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-storage-lab}"
PVC="${PVC:-}"

if [ -z "$PVC" ]; then
  PVC="$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [ -z "$PVC" ]; then
  echo "No PVC found in namespace $NAMESPACE. Or set PVC=my-pvc."
  exit 0
fi

OUT_DIR="11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/reports/pvc-$PVC-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"

echo "===== PVC Inspector ====="
echo "Namespace: $NAMESPACE"
echo "PVC: $PVC"
echo "Output: $OUT_DIR"

kubectl get pvc "$PVC" -n "$NAMESPACE" -o wide | tee "$OUT_DIR/pvc-status.txt" || true
kubectl get pvc "$PVC" -n "$NAMESPACE" -o yaml > "$OUT_DIR/pvc.yaml" 2>&1 || true
kubectl describe pvc "$PVC" -n "$NAMESPACE" > "$OUT_DIR/pvc-describe.txt" 2>&1 || true
kubectl get pv -o wide > "$OUT_DIR/pv-list.txt" 2>&1 || true
kubectl get storageclass -o yaml > "$OUT_DIR/storageclasses.yaml" 2>&1 || true
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp > "$OUT_DIR/events.txt" 2>&1 || true

PV_NAME="$(kubectl get pvc "$PVC" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)"

if [ -n "$PV_NAME" ]; then
  kubectl get pv "$PV_NAME" -o yaml > "$OUT_DIR/bound-pv.yaml" 2>&1 || true
  kubectl describe pv "$PV_NAME" > "$OUT_DIR/bound-pv-describe.txt" 2>&1 || true
fi

echo
echo "Storage-related findings:"
grep -i -E "pending|waiting|failed|provision|storageclass|volume|claim|bound|mount" "$OUT_DIR/pvc-describe.txt" "$OUT_DIR/events.txt" || true

echo
echo "Inspection saved to: $OUT_DIR"
```

Make executable:

```bash id="chmod-pvc-inspector"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/inspect-pvc.sh
```

Run:

```bash id="run-pvc-inspector"
NAMESPACE=storage-lab PVC=healthy-dynamic-pvc \
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/inspect-pvc.sh
```

---

# 22. Volume Mount Test Script

```bash id="mount-test-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/volume-mount-test.sh
```

Paste:

```bash id="mount-test-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-storage-lab}"
POD="${POD:-}"
MOUNT_PATH="${MOUNT_PATH:-/data}"

if [ -z "$POD" ]; then
  POD="$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
fi

if [ -z "$POD" ]; then
  echo "No running Pod found in namespace $NAMESPACE. Or set POD=my-pod."
  exit 1
fi

echo "===== Volume Mount Test ====="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "Mount path: $MOUNT_PATH"

echo
echo "df:"
kubectl exec -n "$NAMESPACE" "$POD" -- df -h "$MOUNT_PATH" || true

echo
echo "mount path listing:"
kubectl exec -n "$NAMESPACE" "$POD" -- ls -la "$MOUNT_PATH" || true

echo
echo "write test:"
kubectl exec -n "$NAMESPACE" "$POD" -- sh -c "echo volume-test-\$(date +%s) > $MOUNT_PATH/volume-test.txt && cat $MOUNT_PATH/volume-test.txt" || true

echo
echo "identity:"
kubectl exec -n "$NAMESPACE" "$POD" -- id || true
```

Make executable:

```bash id="chmod-mount-test"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/volume-mount-test.sh
```

Run:

```bash id="run-mount-test"
POD="$(kubectl get pod -n storage-lab -l app=healthy-storage-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

NAMESPACE=storage-lab POD="$POD" MOUNT_PATH=/data \
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/volume-mount-test.sh
```

---

# 23. StatefulSet Storage Inspector Script

```bash id="sts-inspector-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/statefulset-storage-inspect.sh
```

Paste:

```bash id="sts-inspector-content"
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-storage-lab}"
STATEFULSET="${STATEFULSET:-storage-sts}"
APP_LABEL="${APP_LABEL:-app=$STATEFULSET}"

echo "===== StatefulSet Storage Inspector ====="
echo "Namespace: $NAMESPACE"
echo "StatefulSet: $STATEFULSET"
echo "App label: $APP_LABEL"

echo
echo "StatefulSet:"
kubectl get statefulset "$STATEFULSET" -n "$NAMESPACE" -o wide || true
kubectl describe statefulset "$STATEFULSET" -n "$NAMESPACE" || true

echo
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" -o wide || true

echo
echo "PVCs likely related:"
kubectl get pvc -n "$NAMESPACE" | grep "$STATEFULSET" || true

echo
echo "All PVCs:"
kubectl get pvc -n "$NAMESPACE" -o wide || true

echo
echo "Recent events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 50 || true
```

Make executable:

```bash id="chmod-sts-inspector"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/statefulset-storage-inspect.sh
```

Run:

```bash id="run-sts-inspector"
NAMESPACE=storage-lab STATEFULSET=storage-sts APP_LABEL='app=storage-sts' \
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/statefulset-storage-inspect.sh
```

---

# 24. Run All Safe Storage Labs Script

```bash id="run-labs-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/run-storage-labs.sh
```

Paste:

```bash id="run-labs-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests"

kubectl create namespace storage-lab --dry-run=client -o yaml | kubectl apply -f -

echo "Applying safe storage labs..."

kubectl apply -f "$BASE/00-healthy-dynamic-pvc.yaml" || true
kubectl apply -f "$BASE/01-missing-storageclass.yaml" || true
kubectl apply -f "$BASE/02-pv-pvc-storageclass-mismatch.yaml" || true
kubectl apply -f "$BASE/03-accessmodes-mismatch.yaml" || true
kubectl apply -f "$BASE/04-volumemode-mismatch.yaml" || true
kubectl apply -f "$BASE/07-pod-missing-pvc.yaml" || true
kubectl apply -f "$BASE/12-subpath-mount-mistake.yaml" || true

echo
echo "Safe storage labs applied."
echo
echo "Run:"
echo "NAMESPACE=storage-lab ./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/storage-summary.sh"
echo
echo "Manual longer labs:"
echo "09-statefulset-volumeclaimtemplates.yaml"
echo "10-permission-denied-volume.yaml"
echo "11-initcontainer-permission-fix.yaml"
```

Make executable:

```bash id="chmod-run-labs"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/run-storage-labs.sh
```

Run:

```bash id="run-storage-labs"
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/run-storage-labs.sh
```

---

# 25. Cleanup Script

```bash id="cleanup-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/cleanup-lesson-11-11.sh
```

Paste:

```bash id="cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

BASE="11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/manifests"

echo "===== Cleanup Lesson 11.11 ====="

kubectl delete -f "$BASE/12-subpath-mount-mistake.yaml" --ignore-not-found=true
kubectl delete pod subpath-mount-demo -n storage-lab --ignore-not-found=true
kubectl delete configmap subpath-storage-config -n storage-lab --ignore-not-found=true

kubectl delete -f "$BASE/11-initcontainer-permission-fix.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/10-permission-denied-volume.yaml" --ignore-not-found=true

kubectl delete -f "$BASE/09-statefulset-volumeclaimtemplates.yaml" --ignore-not-found=true
kubectl delete pvc data-storage-sts-0 data-storage-sts-1 -n storage-lab --ignore-not-found=true

kubectl delete -f "$BASE/08-rwo-multinode-confusion.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/07-pod-missing-pvc.yaml" --ignore-not-found=true
kubectl delete pvc pvc-does-not-exist -n storage-lab --ignore-not-found=true

kubectl delete -f "$BASE/06-wffc-consumer-pod.yaml" --ignore-not-found=true
kubectl delete -f "$BASE/05-waitforfirstconsumer.yaml" --ignore-not-found=true

kubectl delete -f "$BASE/04-volumemode-mismatch.yaml" --ignore-not-found=true
kubectl delete pvc static-pvc-block-request -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-filesystem --ignore-not-found=true

kubectl delete -f "$BASE/03-accessmodes-mismatch.yaml" --ignore-not-found=true
kubectl delete pvc static-pvc-asks-rwx -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-rwo-only --ignore-not-found=true

kubectl delete -f "$BASE/02-pv-pvc-storageclass-mismatch.yaml" --ignore-not-found=true
kubectl delete pvc static-pvc-sc-mismatch -n storage-lab --ignore-not-found=true
kubectl delete pv static-pv-sc-standard --ignore-not-found=true

kubectl delete -f "$BASE/01-missing-storageclass.yaml" --ignore-not-found=true
kubectl delete pod missing-storageclass-pod -n storage-lab --ignore-not-found=true
kubectl delete pvc missing-storageclass-pvc -n storage-lab --ignore-not-found=true

kubectl delete -f "$BASE/00-healthy-dynamic-pvc.yaml" --ignore-not-found=true

echo "Lesson 11.11 demo resources cleaned."
echo "Check for leftovers:"
echo "kubectl get pvc,pv -A | grep storage-lab || true"
```

Make executable:

```bash id="chmod-cleanup"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/cleanup-lesson-11-11.sh
```

Run cleanup:

```bash id="run-cleanup"
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/cleanup-lesson-11-11.sh
```

---

# 26. Validation Script

```bash id="validation-script"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/validate-lesson-11-11.sh
```

Paste:

```bash id="validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 11.11 ====="

kubectl version --client >/dev/null

BASE="11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset"

test -d "$BASE"
test -d "$BASE/manifests"
test -d "$BASE/scripts"
test -d "$BASE/notes"
test -d "$BASE/runbooks"

test -f "$BASE/notes/storage-mental-model.md"
test -f "$BASE/notes/storage-debug-commands.md"
test -f "$BASE/notes/volume-expansion-concept.md"

test -f "$BASE/manifests/00-healthy-dynamic-pvc.yaml"
test -f "$BASE/manifests/01-missing-storageclass.yaml"
test -f "$BASE/manifests/02-pv-pvc-storageclass-mismatch.yaml"
test -f "$BASE/manifests/03-accessmodes-mismatch.yaml"
test -f "$BASE/manifests/04-volumemode-mismatch.yaml"
test -f "$BASE/manifests/05-waitforfirstconsumer.yaml"
test -f "$BASE/manifests/06-wffc-consumer-pod.yaml"
test -f "$BASE/manifests/07-pod-missing-pvc.yaml"
test -f "$BASE/manifests/08-rwo-multinode-confusion.yaml"
test -f "$BASE/manifests/09-statefulset-volumeclaimtemplates.yaml"
test -f "$BASE/manifests/10-permission-denied-volume.yaml"
test -f "$BASE/manifests/11-initcontainer-permission-fix.yaml"
test -f "$BASE/manifests/12-subpath-mount-mistake.yaml"

test -x "$BASE/scripts/storage-summary.sh"
test -x "$BASE/scripts/inspect-pvc.sh"
test -x "$BASE/scripts/volume-mount-test.sh"
test -x "$BASE/scripts/statefulset-storage-inspect.sh"
test -x "$BASE/scripts/run-storage-labs.sh"
test -x "$BASE/scripts/cleanup-lesson-11-11.sh"

kubectl create namespace storage-lab --dry-run=client -o yaml | kubectl apply -f - >/dev/null

SC_COUNT="$(kubectl get storageclass --no-headers 2>/dev/null | wc -l | tr -d ' ')"

if [ "$SC_COUNT" -lt 1 ]; then
  echo "WARNING: no StorageClass found. Dynamic PVC validation may not bind."
else
  kubectl apply -f "$BASE/manifests/00-healthy-dynamic-pvc.yaml" >/dev/null
  kubectl rollout status deployment/healthy-storage-demo -n storage-lab --timeout=180s >/dev/null

  PVC_STATUS="$(kubectl get pvc healthy-dynamic-pvc -n storage-lab -o jsonpath='{.status.phase}')"

  if [ "$PVC_STATUS" != "Bound" ]; then
    echo "ERROR: healthy-dynamic-pvc should be Bound"
    exit 1
  fi

  POD="$(kubectl get pod -n storage-lab -l app=healthy-storage-demo -o jsonpath='{.items[0].metadata.name}')"
  kubectl exec "$POD" -n storage-lab -- test -f /data/hello.txt
fi

echo "StorageClass count: $SC_COUNT"
echo "Lesson 11.11 validation passed."
```

Make executable:

```bash id="chmod-validation"
chmod +x 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/validate-lesson-11-11.sh
```

Run:

```bash id="run-validation"
./11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/scripts/validate-lesson-11-11.sh
```

---

# 27. Storage Troubleshooting Runbook

```bash id="storage-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/runbooks/storage-troubleshooting-runbook.md
```

Paste:

````markdown id="storage-runbook-content"
# Kubernetes Storage Troubleshooting Runbook

## 1. Start with PVC

```bash
kubectl get pvc -n NAMESPACE
kubectl describe pvc PVC -n NAMESPACE
````

Check:

* status
* storageClassName
* accessModes
* volumeMode
* requested size
* events
* bound PV

## 2. Check PV

```bash id="rb-pv"
kubectl get pv
kubectl describe pv PV
```

Check:

* status
* claimRef
* storageClassName
* accessModes
* volumeMode
* reclaimPolicy
* node affinity
* capacity

## 3. Check StorageClass

```bash id="rb-sc"
kubectl get storageclass
kubectl describe storageclass STORAGECLASS
```

Check:

* provisioner
* volumeBindingMode
* allowVolumeExpansion
* reclaimPolicy
* parameters

## 4. Check Pod

```bash id="rb-pod"
kubectl get pod POD -n NAMESPACE
kubectl describe pod POD -n NAMESPACE
```

Look for:

* unbound PersistentVolumeClaims
* failed mount
* attach failed
* timeout waiting for volume
* permission denied
* subPath errors

## 5. Check inside container

```bash id="rb-inside"
kubectl exec -n NAMESPACE POD -- df -h
kubectl exec -n NAMESPACE POD -- ls -la /data
kubectl exec -n NAMESPACE POD -- sh -c 'echo test > /data/test.txt'
```

## 6. Common failures

| Symptom                                | Likely Cause                                         |
| -------------------------------------- | ---------------------------------------------------- |
| PVC Pending                            | StorageClass missing, no provisioner, no matching PV |
| PV Available but PVC Pending           | storageClass/accessModes/volumeMode/size mismatch    |
| Pod Pending                            | PVC unbound or WaitForFirstConsumer                  |
| Pod ContainerCreating                  | attach/mount failure                                 |
| App CrashLoopBackOff                   | permission/path/write issue                          |
| Permission denied                      | runAsUser/fsGroup/initContainer needed               |
| RWO conflict                           | volume cannot attach to multiple nodes               |
| StatefulSet recreated but data remains | PVCs are retained                                    |
| Resize stuck                           | StorageClass/CSI does not support expansion          |

## 7. Fix safely

* Do not delete PVCs before confirming data impact.
* Snapshot/backup before risky storage operations.
* Fix StorageClass/PV/PVC matching.
* Use StatefulSet volumeClaimTemplates for per-Pod state.
* Use RWX-capable storage for shared multi-writer workloads.
* Use fsGroup or initContainer for permissions.
* Use WaitForFirstConsumer for topology-aware storage.

````

---

# 28. StatefulSet Storage Runbook

```bash id="sts-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/runbooks/statefulset-storage-runbook.md
````

Paste:

````markdown id="sts-runbook-content"
# StatefulSet Storage Runbook

## 1. Inspect StatefulSet

```bash
kubectl get statefulset -n NAMESPACE
kubectl describe statefulset STATEFULSET -n NAMESPACE
````

## 2. Inspect Pods

```bash id="sts-rb-pods"
kubectl get pods -n NAMESPACE -l app=APP -o wide
```

StatefulSet Pods have stable names:

```text
app-0
app-1
app-2
```

## 3. Inspect PVCs

```bash id="sts-rb-pvcs"
kubectl get pvc -n NAMESPACE
```

PVCs from volumeClaimTemplates usually look like:

```text
data-app-0
data-app-1
data-app-2
```

## 4. Verify per-Pod storage

```bash id="sts-rb-exec"
kubectl exec -n NAMESPACE app-0 -- ls -la /data
kubectl exec -n NAMESPACE app-1 -- ls -la /data
```

## 5. Important behavior

* Deleting a Pod does not delete its PVC.
* Deleting a StatefulSet usually does not delete PVCs.
* PVC retention protects data.
* Clean PVCs manually only after confirming backup/data policy.

## 6. Common issues

| Symptom                    | Cause                                |
| -------------------------- | ------------------------------------ |
| StatefulSet Pod Pending    | PVC Pending                          |
| One replica broken         | its specific PVC/PV has issue        |
| Data persists after delete | expected PVC retention               |
| Permission denied          | volume ownership/securityContext     |
| Cannot scale due to PVC    | provisioning failure for new ordinal |

````

---

# 29. Production Storage Incident Runbook

```bash id="prod-runbook"
nano 11-advanced-kubernetes-troubleshooting/11.11-storage-pvc-pv-statefulset/runbooks/production-storage-incident-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production Storage Incident Runbook

## Step 1 — Classify impact

- one Pod
- one StatefulSet ordinal
- one namespace
- one node
- one storage class
- full cluster storage incident

## Step 2 — Identify symptom

```bash
kubectl get pods -A | grep -E 'Pending|ContainerCreating|CrashLoopBackOff'
kubectl get pvc -A
kubectl get pv
````

## Step 3 — Inspect PVC

```bash id="prod-pvc"
kubectl describe pvc PVC -n NAMESPACE
```

## Step 4 — Inspect Pod events

```bash id="prod-pod"
kubectl describe pod POD -n NAMESPACE
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp | tail -n 100
```

## Step 5 — Inspect StorageClass and provisioner

```bash id="prod-sc"
kubectl get storageclass
kubectl describe storageclass STORAGECLASS
```

Also check CSI/provisioner Pods:

```bash id="prod-csi"
kubectl get pods -A | grep -i -E 'csi|provisioner|storage'
```

## Step 6 — Check node placement

```bash id="prod-node"
kubectl get pod POD -n NAMESPACE -o wide
kubectl describe node NODE
```

## Step 7 — Check app filesystem

```bash id="prod-fs"
kubectl exec -n NAMESPACE POD -- df -h
kubectl exec -n NAMESPACE POD -- ls -la /data
kubectl exec -n NAMESPACE POD -- id
```

## Step 8 — Safety before destructive action

Before deleting PVC/PV:

* confirm backup
* confirm snapshot
* confirm application owner approval
* confirm reclaimPolicy
* confirm whether data is disposable

## Golden Rule

Never delete a production PVC just to “fix Pending” unless you understand the data impact.

````

---

# 30. Real Production Debug Mapping

```text id="prod-map"
PVC Pending:
  check StorageClass, provisioner, PV matching, accessModes, volumeMode, size, events

PV Available but PVC Pending:
  check storageClassName, claimRef, selector, accessModes, volumeMode, requested size

Pod Pending with unbound PVC:
  fix PVC binding before app debugging

Pod ContainerCreating:
  check attach/mount events, node, CSI driver, volume permissions

Pod CrashLoopBackOff after mount:
  check app path, write permissions, filesystem ownership, readOnly mount

StatefulSet one Pod stuck:
  inspect that ordinal's PVC and PV

ReadWriteOnce multi-node issue:
  use per-Pod PVCs or RWX backend

Permission denied:
  use fsGroup, fsGroupChangePolicy, initContainer chown, or correct image user

Volume expansion stuck:
  check allowVolumeExpansion and CSI support

WaitForFirstConsumer confusion:
  create consumer Pod and inspect scheduling/storage events
````

---

# 31. Common Mistakes

## Mistake 1: Debugging app logs before PVC

If the Pod has not started, there may be no useful app logs.

Start with:

```bash id="mistake-pvc"
kubectl describe pvc PVC -n NAMESPACE
kubectl describe pod POD -n NAMESPACE
```

---

## Mistake 2: Deleting PVC too quickly

PVC deletion can delete or orphan real data depending on reclaim policy and provisioner behavior.

Check first:

```bash id="mistake-reclaim"
kubectl get pv
kubectl describe pv PV_NAME | grep -i reclaim
```

---

## Mistake 3: Assuming RWO means only one Pod

`ReadWriteOnce` is node-scoped for many plugins. It often allows one node, not necessarily one Pod. Use `ReadWriteOncePod` where supported if you need single-Pod access.

---

## Mistake 4: Forgetting StatefulSet PVC retention

Deleting StatefulSet does not mean deleting its data.

---

## Mistake 5: Ignoring permissions

A storage mount can be healthy but unusable by a non-root app.

---

## Mistake 6: Using RWX requirements on block storage

Most cloud block volumes are not RWX. Use a shared filesystem backend when true multi-writer access is required.

---

# 32. Interview Explanation

Use this:

```text id="interview-answer"
When troubleshooting Kubernetes storage issues, I start with the PVC because most storage failures show up there first. I check whether the PVC is Pending or Bound, then inspect the StorageClass, requested size, accessModes, volumeMode, events, and bound PV. If the PVC is Pending, I check whether the StorageClass exists, whether a dynamic provisioner is available, or whether a static PV matches the claim.

If the Pod is Pending or stuck in ContainerCreating, I inspect Pod events for unbound PVC, attach, mount, or provisioning errors. For StatefulSets, I check volumeClaimTemplates and the per-Pod PVCs such as data-app-0 and data-app-1. I remember that StatefulSet PVCs are retained to protect data.

If the volume mounts but the app fails, I check filesystem permissions, runAsUser, fsGroup, readOnly mounts, and whether an initContainer is needed to prepare the volume. In production, I avoid deleting PVCs until data impact, reclaim policy, backups, and snapshots are understood.
```

Resume bullet:

```text id="resume-bullet"
Built Kubernetes storage troubleshooting labs covering PVC Pending, missing StorageClass, PV/PVC binding mismatches, accessModes and volumeMode mismatch, WaitForFirstConsumer behavior, missing PVC mount failures, ReadWriteOnce multi-node pitfalls, StatefulSet volumeClaimTemplates, PVC retention, filesystem permissions, fsGroup, initContainer volume fixes, subPath mount errors, volume expansion concepts, inspector scripts, and production storage incident runbooks.
```

---

# 33. Commit Lesson 11.11

```bash id="commit"
cd ~/devops-masterclass

git status

git add 11-advanced-kubernetes-troubleshooting

git commit -m "feat: add Kubernetes storage PVC PV StatefulSet troubleshooting labs"

git push
```

---

# 34. Next Lesson

```text id="next-lesson"
Lesson 11.12 — NetworkPolicy and CNI Troubleshooting
```

We will cover:

```text id="next-topics"
default deny ingress
default deny egress
DNS blocked by NetworkPolicy
Service reachable but Pod traffic blocked
namespaceSelector and podSelector mistakes
ingress vs egress direction confusion
CNI enforcement differences
debug Pods with curl/nslookup
testing connectivity matrix
allowing traffic from ingress-nginx
allowing database access
NetworkPolicy production design
CNI incident runbook
```
