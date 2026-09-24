# Lesson 10.12 — PersistentVolumes, PersistentVolumeClaims, StorageClasses, StatefulSets, and Database Patterns

In Lesson 10.11, you learned **RBAC, ServiceAccounts, least privilege, and namespace isolation**.

Now we move into Kubernetes storage and stateful workloads.

This lesson is important because most real systems are not only stateless APIs. They also need:

```text
databases
message brokers
file uploads
persistent app data
cache warmup data
logs
indexes
stateful identity
stable storage
backup and restore
```

Kubernetes supports many volume types for giving containers filesystem-backed data, and PersistentVolumes/PersistentVolumeClaims provide a cluster-level storage abstraction so Pods can use durable storage without knowing the underlying storage implementation. ([Kubernetes][1])

---

# 1. What We Will Cover

```text
10.12.1   Storage mental model
10.12.2   Ephemeral storage
10.12.3   emptyDir
10.12.4   PersistentVolume
10.12.5   PersistentVolumeClaim
10.12.6   StorageClass
10.12.7   Dynamic provisioning
10.12.8   Access modes
10.12.9   Reclaim policies
10.12.10  Volume binding modes
10.12.11  Deployment with PVC
10.12.12  StatefulSet mental model
10.12.13  Stable Pod identity
10.12.14  Stable storage identity
10.12.15  Headless Service
10.12.16  volumeClaimTemplates
10.12.17  Database patterns
10.12.18  Why Deployments are not ideal for databases
10.12.19  Production storage pattern for demo-node-api dependencies
10.12.20  Validation script
10.12.21  Cleanup script
```

---

# 2. Create Lesson Folder

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

mkdir -p 10.12-persistent-volumes-statefulsets/{manifests,scripts,notes,runbooks,reports}
```

Check:

```bash
tree -L 2 10.12-persistent-volumes-statefulsets
```

---

# 3. Storage Mental Model

Containers are temporary.

Pods are also temporary.

If a Pod disappears, its container filesystem disappears with it.

Bad assumption:

```text
My app wrote a file inside the container.
So the file is safe.
```

Correct understanding:

```text
Container filesystem is ephemeral.
If the container or Pod is replaced, local container data can be lost.
```

Kubernetes volumes solve this by giving containers filesystem storage that can be shared between containers in a Pod or backed by external/persistent storage depending on the volume type. ([Kubernetes][1])

Simple hierarchy:

```text
Pod
  ↓
Volume
  ↓
Container volumeMount
  ↓
Application sees a filesystem path
```

Example:

```yaml
volumeMounts:
  - name: app-data
    mountPath: /data

volumes:
  - name: app-data
    emptyDir: {}
```

---

# 4. Ephemeral vs Persistent Storage

## Ephemeral storage

Ephemeral means:

```text
temporary
tied to Pod or container lifecycle
not suitable for durable database data
```

Examples:

```text
emptyDir
container writable layer
temporary cache
scratch space
```

## Persistent storage

Persistent means:

```text
storage can survive Pod restart/replacement
storage has lifecycle independent from one Pod
```

Examples:

```text
PersistentVolume
PersistentVolumeClaim
cloud disk
network file system
CSI volume
```

Production rule:

```text
Use ephemeral storage for temporary data.
Use persistent storage for durable state.
```

---

# 5. emptyDir

`emptyDir` is created when a Pod is assigned to a node and exists as long as that Pod runs on that node. It survives container restarts inside the same Pod, but when the Pod is removed from the node, the `emptyDir` data is deleted. ([Kubernetes][1])

Use `emptyDir` for:

```text
scratch files
temporary cache
shared files between containers in one Pod
build workspace
temporary processing data
```

Do not use `emptyDir` for:

```text
database data
uploaded user files
important logs
persistent app state
anything you cannot lose
```

---

# 6. Create Notes

```bash
nano 10.12-persistent-volumes-statefulsets/notes/storage-mental-model.md
```

Paste:

```markdown
# Kubernetes Storage Mental Model

## Ephemeral Storage

Temporary storage tied to Pod/container lifecycle.

Examples:

- container writable layer
- emptyDir
- scratch data
- temporary cache

## Persistent Storage

Storage that survives Pod replacement.

Core objects:

- PersistentVolume
- PersistentVolumeClaim
- StorageClass

## Stateful Workloads

Use StatefulSet when the app needs:

- stable Pod identity
- stable DNS identity
- stable storage identity
- ordered deployment or scaling

## Golden Rule

Do not store durable database data only inside the container filesystem.
```

---

# 7. emptyDir Demo

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/emptydir-demo-pod.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
  namespace: dev
  labels:
    app: emptydir-demo
spec:
  volumes:
    - name: shared-data
      emptyDir: {}

  containers:
    - name: writer
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          i=0
          while true; do
            echo "line $i written at $(date)" >> /shared/data.log
            i=$((i+1))
            sleep 5
          done
      volumeMounts:
        - name: shared-data
          mountPath: /shared

    - name: reader
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          touch /shared/data.log
          tail -f /shared/data.log
      volumeMounts:
        - name: shared-data
          mountPath: /shared
```

Apply:

```bash
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/emptydir-demo-pod.yaml
```

Check:

```bash
kubectl get pod emptydir-demo -n dev
kubectl logs emptydir-demo -n dev -c reader
```

Exec into reader:

```bash
kubectl exec -it emptydir-demo -n dev -c reader -- sh
```

Inside:

```sh
ls -la /shared
cat /shared/data.log
exit
```

Important lesson:

```text
Both containers can see the same emptyDir volume.
The data survives container restarts inside the same Pod.
The data is removed when the Pod is deleted.
```

Delete and recreate:

```bash
kubectl delete pod emptydir-demo -n dev

kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/emptydir-demo-pod.yaml
```

Check again:

```bash
kubectl logs emptydir-demo -n dev -c reader
```

The old data is gone because the old Pod’s `emptyDir` was deleted.

---

# 8. PersistentVolume and PersistentVolumeClaim

Now we move to persistent storage.

## PersistentVolume

A `PersistentVolume`, or PV, is a piece of storage in the cluster.

It can be backed by:

```text
cloud disk
network disk
local storage
NFS
CSI driver
storage appliance
```

## PersistentVolumeClaim

A `PersistentVolumeClaim`, or PVC, is a request for storage.

Simple mental model:

```text
PV:
  actual storage

PVC:
  request to use storage

Pod:
  mounts PVC
```

Flow:

```text
StorageClass
  ↓
PVC requests storage
  ↓
PV is provisioned or matched
  ↓
Pod mounts PVC
  ↓
Container writes to mountPath
```

The Kubernetes PersistentVolume docs describe PVs as cluster resources and PVCs as users’ requests for storage; claims can request size and access mode, and Kubernetes binds a suitable volume to the claim. ([Kubernetes][2])

---

# 9. StorageClass

A `StorageClass` describes a class of storage offered by the cluster.

Examples:

```text
fast-ssd
standard-hdd
encrypted-gp3
nfs-shared
local-path
backup-enabled
```

Kubernetes says a StorageClass lets administrators describe available storage classes; the exact meaning of a class can map to quality-of-service levels, backup policies, arbitrary admin policies, or cloud storage types. ([Kubernetes][3])

Check StorageClasses:

```bash
kubectl get storageclass
```

Short form:

```bash
kubectl get sc
```

In kind, you commonly see a default StorageClass named:

```text
standard
```

Check details:

```bash
kubectl describe storageclass standard
```

If your cluster has a default StorageClass, PVCs can dynamically provision PVs without you manually creating PV objects.

---

# 10. Dynamic Provisioning

Dynamic provisioning means:

```text
You create a PVC.
The StorageClass provisions storage automatically.
Kubernetes creates/binds a PV.
```

This is the common production pattern.

Example:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
```

Production example:

```text
EKS + EBS CSI driver:
  PVC requests 20Gi
  StorageClass provisions EBS volume
  Pod mounts volume
```

---

# 11. Access Modes

PVCs request access modes.

Common modes:

```text
ReadWriteOnce
ReadOnlyMany
ReadWriteMany
ReadWriteOncePod
```

Simple meaning:

```text
ReadWriteOnce:
  mounted read-write by one node

ReadOnlyMany:
  mounted read-only by many nodes

ReadWriteMany:
  mounted read-write by many nodes

ReadWriteOncePod:
  mounted read-write by only one Pod
```

Access modes describe how a volume can be mounted; actual support depends on the storage provider or CSI driver. ([Kubernetes][2])

Production examples:

```text
EBS:
  usually ReadWriteOnce

EFS/NFS:
  can support ReadWriteMany

database disk:
  usually ReadWriteOnce

shared uploads:
  maybe ReadWriteMany through EFS/NFS/object storage pattern
```

---

# 12. Reclaim Policies

A PV reclaim policy decides what happens to the underlying volume after the PVC is deleted or released.

Common reclaim policies:

```text
Retain
Delete
Recycle deprecated
```

Kubernetes documents that a PersistentVolume reclaim policy tells the cluster what to do with the volume after the claim is released; current supported policies include `Retain` and `Delete`, while `Recycle` is deprecated. ([Kubernetes][2])

Meaning:

```text
Delete:
  delete the underlying storage when PVC is deleted

Retain:
  keep the underlying storage for manual recovery or reuse
```

Production rule:

```text
For disposable dev data, Delete can be fine.
For important production data, understand Retain/Delete before using it.
```

---

# 13. Volume Binding Modes

StorageClasses can have volume binding modes.

Common modes:

```text
Immediate
WaitForFirstConsumer
```

Meaning:

```text
Immediate:
  provision/bind volume immediately when PVC is created

WaitForFirstConsumer:
  wait until a Pod using the PVC is scheduled
```

Why `WaitForFirstConsumer` matters:

```text
Storage may be zone-specific.
The scheduler needs to know which node/zone the Pod will use before provisioning the disk.
```

This prevents a bad situation:

```text
PVC creates disk in zone-a.
Pod schedules to zone-b.
Volume cannot attach.
```

StorageClass documentation covers `volumeBindingMode` and explains that delayed binding can account for Pod scheduling constraints such as node selectors, affinity, and topology. ([Kubernetes][3])

---

# 14. Create PVC Demo

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/pvc-demo.yaml
```

Paste:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-demo-data
  namespace: dev
  labels:
    app: pvc-demo
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 1Gi
```

Apply:

```bash
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo.yaml
```

Check:

```bash
kubectl get pvc -n dev
kubectl describe pvc pvc-demo-data -n dev
kubectl get pv
```

Expected:

```text
PVC should become Bound.
A PV should be dynamically created or bound.
```

If PVC stays Pending:

```bash
kubectl describe pvc pvc-demo-data -n dev
kubectl get storageclass
kubectl get events -n dev --sort-by=.lastTimestamp
```

Common cause:

```text
No default/proper StorageClass exists.
StorageClass name is wrong.
Provisioner is not working.
```

---

# 15. Deployment Using PVC

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/pvc-demo-deployment.yaml
```

Paste:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pvc-demo
  namespace: dev
  labels:
    app: pvc-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pvc-demo
  template:
    metadata:
      labels:
        app: pvc-demo
    spec:
      containers:
        - name: app
          image: busybox:1.36
          command:
            - sh
            - -c
            - |
              echo "Starting PVC demo"
              while true; do
                echo "$(date) from $HOSTNAME" >> /data/app.log
                sleep 5
              done
          volumeMounts:
            - name: app-data
              mountPath: /data
          resources:
            requests:
              cpu: "25m"
              memory: "32Mi"
            limits:
              cpu: "100m"
              memory: "64Mi"
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: pvc-demo-data
```

Apply:

```bash
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo-deployment.yaml
```

Check:

```bash
kubectl rollout status deployment/pvc-demo -n dev
kubectl get pods -n dev -l app=pvc-demo -o wide
```

Read data:

```bash
POD_NAME="$(kubectl get pod -n dev -l app=pvc-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$POD_NAME" -n dev -- cat /data/app.log
```

Delete the Pod:

```bash
kubectl delete pod "$POD_NAME" -n dev
```

Wait for replacement:

```bash
kubectl get pods -n dev -l app=pvc-demo -w
```

Exit watch:

```text
Ctrl + C
```

Read again:

```bash
NEW_POD="$(kubectl get pod -n dev -l app=pvc-demo -o jsonpath='{.items[0].metadata.name}')"

kubectl exec "$NEW_POD" -n dev -- cat /data/app.log
```

Expected:

```text
Old data should still exist.
```

That is the purpose of the PVC.

---

# 16. Important Deployment + PVC Warning

A Deployment with one replica and a PVC can work for simple single-instance stateful apps.

But be careful.

If you scale this Deployment to 2:

```bash
kubectl scale deployment pvc-demo -n dev --replicas=2
```

With a `ReadWriteOnce` volume, behavior may fail or become unsafe depending on storage provider and scheduling.

Check:

```bash
kubectl get pods -n dev -l app=pvc-demo -o wide
kubectl describe pod -n dev -l app=pvc-demo
```

Scale back:

```bash
kubectl scale deployment pvc-demo -n dev --replicas=1
```

Production rule:

```text
Do not blindly scale a Deployment that writes to one ReadWriteOnce PVC.
```

For stateful replicas, use StatefulSet with one PVC per replica.

---

# 17. StatefulSet Mental Model

A StatefulSet manages stateful applications.

It provides:

```text
stable Pod names
stable network identity
stable storage identity
ordered deployment
ordered scaling
ordered termination
```

Kubernetes documents StatefulSet as the workload API object for managing stateful applications, providing guarantees around ordering and uniqueness, and maintaining sticky identity for Pods. ([Kubernetes][4])

Deployment Pod names look like:

```text
api-7d8b9c7f9d-x2abc
api-7d8b9c7f9d-z9lmn
```

StatefulSet Pod names look like:

```text
mongo-demo-0
mongo-demo-1
mongo-demo-2
```

This matters because many stateful systems care about identity.

---

# 18. StatefulSet Identity

A StatefulSet has stable ordinal identities.

Example:

```text
web-0
web-1
web-2
```

If `web-1` is deleted, Kubernetes recreates:

```text
web-1
```

not:

```text
web-random-abc
```

StatefulSet API documentation says a StatefulSet represents Pods with consistent identities, including stable DNS/hostname and stable storage identity, and that a given network identity maps to the same storage identity. ([Kubernetes][5])

This is essential for:

```text
databases
replication members
message brokers
distributed systems
systems with stable peer identity
```

---

# 19. Headless Service for StatefulSet

StatefulSets usually need a headless Service.

A headless Service has:

```yaml
clusterIP: None
```

Why?

```text
It gives stable DNS records for individual Pods.
```

Example DNS:

```text
stateful-demo-0.stateful-demo.dev.svc.cluster.local
stateful-demo-1.stateful-demo.dev.svc.cluster.local
stateful-demo-2.stateful-demo.dev.svc.cluster.local
```

This is different from a normal Service that gives one stable virtual ClusterIP.

---

# 20. Create StatefulSet with volumeClaimTemplates

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/statefulset-demo.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: stateful-demo
  namespace: dev
  labels:
    app: stateful-demo
spec:
  clusterIP: None
  selector:
    app: stateful-demo
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: stateful-demo
  namespace: dev
  labels:
    app: stateful-demo
spec:
  serviceName: stateful-demo
  replicas: 3
  selector:
    matchLabels:
      app: stateful-demo
  template:
    metadata:
      labels:
        app: stateful-demo
    spec:
      containers:
        - name: app
          image: nginx:1.27-alpine
          ports:
            - name: http
              containerPort: 80
          command:
            - sh
            - -c
            - |
              echo "Pod name: $HOSTNAME" > /usr/share/nginx/html/index.html
              echo "Data file for $HOSTNAME" >> /data/state.txt
              nginx -g 'daemon off;'
          volumeMounts:
            - name: data
              mountPath: /data
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
  volumeClaimTemplates:
    - metadata:
        name: data
        labels:
          app: stateful-demo
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: standard
        resources:
          requests:
            storage: 1Gi
```

Apply:

```bash
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/statefulset-demo.yaml
```

Watch:

```bash
kubectl get pods -n dev -l app=stateful-demo -w
```

You should see ordered creation:

```text
stateful-demo-0
stateful-demo-1
stateful-demo-2
```

Exit:

```text
Ctrl + C
```

Check:

```bash
kubectl get statefulset stateful-demo -n dev
kubectl get pods -n dev -l app=stateful-demo -o wide
kubectl get pvc -n dev -l app=stateful-demo
```

Expected PVCs:

```text
data-stateful-demo-0
data-stateful-demo-1
data-stateful-demo-2
```

Each Pod gets its own PVC.

---

# 21. Test Stable Storage Identity

Check data in each Pod:

```bash
for pod in stateful-demo-0 stateful-demo-1 stateful-demo-2; do
  echo "===== $pod ====="
  kubectl exec "$pod" -n dev -- cat /data/state.txt
done
```

Delete one Pod:

```bash
kubectl delete pod stateful-demo-1 -n dev
```

Wait:

```bash
kubectl get pods -n dev -l app=stateful-demo -w
```

Exit:

```text
Ctrl + C
```

Check again:

```bash
kubectl exec stateful-demo-1 -n dev -- cat /data/state.txt
```

Expected:

```text
The new stateful-demo-1 uses the same PVC data-stateful-demo-1.
```

This is the core StatefulSet value:

```text
same Pod identity
same storage identity
```

---

# 22. Test Stable DNS Identity

Create DNS debug Pod if not already present:

```bash
kubectl run storage-dns-debug \
  -n dev \
  --image=busybox:1.36 \
  --restart=Never \
  -- sleep 3600
```

Exec:

```bash
kubectl exec -it storage-dns-debug -n dev -- sh
```

Inside:

```sh
nslookup stateful-demo
nslookup stateful-demo-0.stateful-demo
nslookup stateful-demo-1.stateful-demo
nslookup stateful-demo-2.stateful-demo
wget -qO- http://stateful-demo-0.stateful-demo
exit
```

Expected:

```text
The individual StatefulSet Pod DNS names should resolve.
```

If DNS is slow immediately after creation, wait a few seconds and retry.

---

# 23. Scale StatefulSet

Scale down:

```bash
kubectl scale statefulset stateful-demo -n dev --replicas=1
```

Watch:

```bash
kubectl get pods -n dev -l app=stateful-demo -w
```

Expected deletion order:

```text
stateful-demo-2 deleted first
stateful-demo-1 deleted next
stateful-demo-0 remains
```

Exit:

```text
Ctrl + C
```

Check PVCs:

```bash
kubectl get pvc -n dev -l app=stateful-demo
```

Important:

```text
PVCs remain even when StatefulSet replicas scale down.
```

Scale back:

```bash
kubectl scale statefulset stateful-demo -n dev --replicas=3
```

Watch:

```bash
kubectl get pods -n dev -l app=stateful-demo -w
```

Expected:

```text
stateful-demo-1 comes back with data-stateful-demo-1
stateful-demo-2 comes back with data-stateful-demo-2
```

StatefulSet documentation describes ordered, graceful deployment and scaling behavior, which is one reason StatefulSets are used for stateful apps. ([Kubernetes][4])

---

# 24. Deployment vs StatefulSet

| Feature         | Deployment                 | StatefulSet                              |
| --------------- | -------------------------- | ---------------------------------------- |
| Best for        | Stateless apps             | Stateful apps                            |
| Pod names       | Random suffix              | Stable ordinal                           |
| Pod identity    | Replaceable                | Sticky                                   |
| Storage         | Shared/manual PVC possible | One PVC per replica with templates       |
| Scaling         | Any order                  | Ordered                                  |
| Rolling updates | Flexible                   | Ordered                                  |
| DNS identity    | Service-level              | Per-Pod stable DNS with headless Service |
| Examples        | APIs, workers, frontend    | databases, brokers, clustered systems    |

Rule:

```text
Use Deployment for stateless apps.
Use StatefulSet for stateful apps that need stable identity or per-replica storage.
```

---

# 25. Why Deployments Are Not Ideal for Databases

A database usually needs:

```text
stable storage
stable identity
safe startup/shutdown ordering
backup and restore
replication identity
careful upgrades
data consistency
volume ownership handling
```

Deployment Pods are designed to be interchangeable.

Database Pods are usually not interchangeable.

Bad pattern:

```text
MongoDB as Deployment with 3 replicas sharing one PVC
```

Problems:

```text
multiple database processes can write same data unsafely
Pod identity is random
replication identity is unclear
PVC sharing may not be supported
recovery is risky
```

Better options:

```text
Managed database service
database operator
StatefulSet with correct storage and replication design
```

Production recommendation:

```text
For serious production databases, prefer managed services or mature operators.
Do not hand-roll complex databases unless you understand backup, restore, replication, failover, and upgrades.
```

---

# 26. Simple MongoDB StatefulSet Lab

This is a **learning lab**, not a production MongoDB architecture.

Create Secret:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/mongodb-secret.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
  namespace: dev
  labels:
    app: mongodb-demo
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: "root"
  MONGO_INITDB_ROOT_PASSWORD: "local-password"
```

Create StatefulSet:

```bash
nano 10.12-persistent-volumes-statefulsets/manifests/mongodb-statefulset.yaml
```

Paste:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-demo
  namespace: dev
  labels:
    app: mongodb-demo
spec:
  clusterIP: None
  selector:
    app: mongodb-demo
  ports:
    - name: mongodb
      port: 27017
      targetPort: mongodb
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb-demo
  namespace: dev
  labels:
    app: mongodb-demo
spec:
  serviceName: mongodb-demo
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-demo
  template:
    metadata:
      labels:
        app: mongodb-demo
    spec:
      containers:
        - name: mongodb
          image: mongo:7
          ports:
            - name: mongodb
              containerPort: 27017
          envFrom:
            - secretRef:
                name: mongodb-secret
          volumeMounts:
            - name: mongodb-data
              mountPath: /data/db
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
  volumeClaimTemplates:
    - metadata:
        name: mongodb-data
        labels:
          app: mongodb-demo
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: standard
        resources:
          requests:
            storage: 2Gi
```

Apply:

```bash
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-secret.yaml
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-statefulset.yaml
```

Check:

```bash
kubectl rollout status statefulset/mongodb-demo -n dev --timeout=180s
kubectl get pods -n dev -l app=mongodb-demo
kubectl get pvc -n dev -l app=mongodb-demo
```

Exec into MongoDB:

```bash
kubectl exec -it mongodb-demo-0 -n dev -- mongosh \
  -u root \
  -p local-password \
  --authenticationDatabase admin
```

Inside Mongo shell:

```javascript
use todo
db.items.insertOne({ title: "persistent data test", createdAt: new Date() })
db.items.find()
exit
```

Delete Pod:

```bash
kubectl delete pod mongodb-demo-0 -n dev
```

Wait:

```bash
kubectl get pod mongodb-demo-0 -n dev -w
```

Exit:

```text
Ctrl + C
```

Check data again:

```bash
kubectl exec -it mongodb-demo-0 -n dev -- mongosh \
  -u root \
  -p local-password \
  --authenticationDatabase admin
```

Inside:

```javascript
use todo
db.items.find()
exit
```

Expected:

```text
The inserted document should still exist.
```

Why?

```text
The Pod was recreated.
The PVC remained.
MongoDB reused the same mounted persistent data.
```

---

# 27. MongoDB Lab Warning

This single-replica MongoDB StatefulSet is useful for learning:

```text
PVC
StatefulSet
stable identity
database persistence
```

But it is not production-grade.

Production MongoDB needs:

```text
replica set configuration
backup and restore
monitoring
resource sizing
security
TLS
authentication policy
upgrade strategy
anti-affinity
PodDisruptionBudget
storage class design
restore testing
operator or managed service
```

For your `demo-node-api` production portfolio, the cleaner architecture is often:

```text
demo-node-api in Kubernetes
MongoDB managed externally
or MongoDB Operator/StatefulSet for lab/internal environment
```

---

# 28. Production Storage Pattern for demo-node-api

Your Node.js backend itself should usually remain stateless.

Good pattern:

```text
demo-node-api:
  Deployment
  no local durable storage
  config from ConfigMap
  secrets from Secret/external secret manager
  connects to MongoDB via Service/DNS/managed endpoint

MongoDB:
  managed database service
  or StatefulSet/operator with PVCs
```

Bad pattern:

```text
demo-node-api writes durable user uploads to container filesystem
```

Better options:

```text
S3/object storage for uploads
MongoDB/PostgreSQL for structured data
Redis for cache
PVC only when app truly needs filesystem persistence
```

Create note:

```bash
nano 10.12-persistent-volumes-statefulsets/notes/demo-node-api-storage-policy.md
```

Paste:

```markdown
# demo-node-api Storage Policy

## App Type

demo-node-api is a stateless Node.js API.

## Rule

The API should not store durable user data inside the container filesystem.

## Runtime State

Allowed:

- temporary files
- request scratch data
- cache that can be rebuilt

Not allowed:

- database data
- uploaded user files
- critical logs as only copy
- long-term business state

## Durable Dependencies

Use:

- MongoDB for Todo data
- S3/object storage for uploaded files
- external logging stack for logs
- managed database where possible

## Kubernetes Pattern

demo-node-api:
  Deployment

MongoDB:
  managed service, operator, or StatefulSet lab

Uploads:
  S3/object storage preferred
```

---

# 29. Storage Debugging Runbook

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/runbooks/storage-debugging-runbook.md
```

Paste:

````markdown
# Kubernetes Storage Debugging Runbook

## Step 1 — Check PVC

```bash
kubectl get pvc -n NAMESPACE
kubectl describe pvc PVC_NAME -n NAMESPACE
````

Look for:

* Status
* StorageClass
* AccessModes
* Capacity
* Events

## Step 2 — Check PV

```bash
kubectl get pv
kubectl describe pv PV_NAME
```

Look for:

* Status
* Claim
* Reclaim Policy
* StorageClass
* Node affinity

## Step 3 — Check StorageClass

```bash
kubectl get storageclass
kubectl describe storageclass STORAGECLASS_NAME
```

Look for:

* provisioner
* reclaimPolicy
* volumeBindingMode
* allowVolumeExpansion

## Step 4 — Check Pod Mount

```bash
kubectl describe pod POD_NAME -n NAMESPACE
```

Look for:

* Volumes
* Mounts
* Events
* FailedMount
* FailedAttachVolume

## Step 5 — Check Events

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
```

## Common Problems

| Symptom                              | Likely Cause                              |
| ------------------------------------ | ----------------------------------------- |
| PVC Pending                          | StorageClass missing or provisioner issue |
| Pod Pending                          | volume binding or node/zone conflict      |
| FailedMount                          | wrong PVC name, permissions, driver issue |
| Data missing                         | using emptyDir or wrong PVC               |
| Cannot scale                         | RWO volume attached to one node           |
| PVC remains after StatefulSet delete | expected behavior                         |

## Golden Rule

For storage issues, debug PVC, PV, StorageClass, Pod events, and mount path.

````

---

# 30. StatefulSet Runbook

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/runbooks/statefulset-runbook.md
````

Paste:

````markdown
# StatefulSet Runbook

## Use StatefulSet When App Needs

- stable Pod names
- stable DNS identity
- stable storage identity
- ordered scaling
- ordered rollout
- one PVC per replica

## Check StatefulSet

```bash
kubectl get statefulset -n NAMESPACE
kubectl describe statefulset NAME -n NAMESPACE
kubectl get pods -n NAMESPACE -l app=APP
kubectl get pvc -n NAMESPACE -l app=APP
````

## Stable DNS

```text
POD_NAME.SERVICE_NAME.NAMESPACE.svc.cluster.local
```

Example:

```text
mongodb-demo-0.mongodb-demo.dev.svc.cluster.local
```

## Important Behavior

* Pod names are stable.
* PVCs are stable.
* Scaling is ordered.
* Deleting a Pod recreates the same ordinal.
* Deleting StatefulSet may not delete PVCs.

## Common Problems

| Symptom              | Likely Cause                       |
| -------------------- | ---------------------------------- |
| Pod Pending          | PVC Pending or scheduling issue    |
| Pod CrashLoopBackOff | app/database config issue          |
| DNS not resolving    | headless Service missing/wrong     |
| data not persistent  | mount path wrong or PVC missing    |
| extra PVCs remain    | StatefulSet PVC retention behavior |

## Golden Rule

StatefulSet gives stable identity.
PVC gives stable storage.
Headless Service gives stable DNS.

````

---

# 31. Database Pattern Runbook

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/runbooks/database-patterns-runbook.md
````

Paste:

```markdown
# Database Patterns on Kubernetes

## Preferred Production Options

1. Managed database service
2. Mature Kubernetes operator
3. Carefully designed StatefulSet

## Use Managed Database When

- team lacks deep database operations experience
- backups and restore are critical
- high availability is required
- upgrades must be safe
- compliance matters
- small team wants reduced ops burden

## Use Operator When

- database must run inside Kubernetes
- operator supports backup, restore, replication, upgrades
- team can operate the operator
- storage class and monitoring are production-ready

## Use Plain StatefulSet When

- learning
- dev/test
- simple internal apps
- you fully understand operational risks

## Never Ignore

- backups
- restore tests
- storage performance
- storage class reclaim policy
- anti-affinity
- PodDisruptionBudget
- monitoring
- security
- upgrades
```

---

# 32. Storage Summary Script

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/scripts/storage-summary.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

echo "===== Kubernetes Storage Summary ====="

echo
echo "StorageClasses:"
kubectl get storageclass

echo
echo "PersistentVolumeClaims in namespace: $NAMESPACE"
kubectl get pvc -n "$NAMESPACE"

echo
echo "PersistentVolumes:"
kubectl get pv

echo
echo "StatefulSets in namespace: $NAMESPACE"
kubectl get statefulset -n "$NAMESPACE" || true

echo
echo "Pods using PVCs in namespace: $NAMESPACE"
kubectl get pods -n "$NAMESPACE" -o json | jq -r '
.items[] |
[
  .metadata.name,
  (.spec.volumes // [] | map(select(.persistentVolumeClaim != null) | .persistentVolumeClaim.claimName) | join(","))
] | @tsv' | column -t -s $'\t'

echo
echo "Recent storage-related events:"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 30
```

Make executable:

```bash
chmod +x 10.12-persistent-volumes-statefulsets/scripts/storage-summary.sh
```

Run:

```bash
./10.12-persistent-volumes-statefulsets/scripts/storage-summary.sh
```

---

# 33. Validation Script

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/scripts/validate-lesson-10-12.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 10.12 ====="

kubectl version --client >/dev/null
kubectl get namespace dev >/dev/null

kubectl get storageclass standard >/dev/null

kubectl get pvc pvc-demo-data -n dev >/dev/null
kubectl get deployment pvc-demo -n dev >/dev/null
kubectl rollout status deployment/pvc-demo -n dev --timeout=120s >/dev/null

PVC_STATUS="$(kubectl get pvc pvc-demo-data -n dev -o jsonpath='{.status.phase}')"
if [ "$PVC_STATUS" != "Bound" ]; then
  echo "ERROR: pvc-demo-data should be Bound, got $PVC_STATUS"
  exit 1
fi

kubectl get statefulset stateful-demo -n dev >/dev/null
kubectl rollout status statefulset/stateful-demo -n dev --timeout=180s >/dev/null

for pod in stateful-demo-0 stateful-demo-1 stateful-demo-2; do
  kubectl get pod "$pod" -n dev >/dev/null
done

for pvc in data-stateful-demo-0 data-stateful-demo-1 data-stateful-demo-2; do
  kubectl get pvc "$pvc" -n dev >/dev/null
  STATUS="$(kubectl get pvc "$pvc" -n dev -o jsonpath='{.status.phase}')"
  if [ "$STATUS" != "Bound" ]; then
    echo "ERROR: $pvc should be Bound, got $STATUS"
    exit 1
  fi
done

kubectl get secret mongodb-secret -n dev >/dev/null
kubectl get statefulset mongodb-demo -n dev >/dev/null
kubectl rollout status statefulset/mongodb-demo -n dev --timeout=180s >/dev/null
kubectl get pvc mongodb-data-mongodb-demo-0 -n dev >/dev/null

test -x 10.12-persistent-volumes-statefulsets/scripts/storage-summary.sh
test -f 10.12-persistent-volumes-statefulsets/notes/storage-mental-model.md
test -f 10.12-persistent-volumes-statefulsets/notes/demo-node-api-storage-policy.md
test -f 10.12-persistent-volumes-statefulsets/runbooks/storage-debugging-runbook.md
test -f 10.12-persistent-volumes-statefulsets/runbooks/statefulset-runbook.md
test -f 10.12-persistent-volumes-statefulsets/runbooks/database-patterns-runbook.md

echo "pvc-demo-data status: $PVC_STATUS"
echo "Lesson 10.12 validation passed."
```

Make executable:

```bash
chmod +x 10.12-persistent-volumes-statefulsets/scripts/validate-lesson-10-12.sh
```

Run:

```bash
./10.12-persistent-volumes-statefulsets/scripts/validate-lesson-10-12.sh
```

---

# 34. Cleanup Script

Create:

```bash
nano 10.12-persistent-volumes-statefulsets/scripts/cleanup-lesson-10-12.sh
```

Paste:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 10.12 ====="

kubectl delete pod storage-dns-debug -n dev --ignore-not-found=true

kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-statefulset.yaml --ignore-not-found=true
kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-secret.yaml --ignore-not-found=true

kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/statefulset-demo.yaml --ignore-not-found=true
kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo-deployment.yaml --ignore-not-found=true
kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo.yaml --ignore-not-found=true
kubectl delete -f 10.12-persistent-volumes-statefulsets/manifests/emptydir-demo-pod.yaml --ignore-not-found=true

echo
echo "Deleting PVCs created by StatefulSets..."
kubectl delete pvc -n dev -l app=stateful-demo --ignore-not-found=true
kubectl delete pvc -n dev -l app=mongodb-demo --ignore-not-found=true

echo "Lesson 10.12 resources cleaned."
echo "Check remaining PVs manually if your StorageClass uses Retain reclaim policy:"
echo "kubectl get pv"
```

Make executable:

```bash
chmod +x 10.12-persistent-volumes-statefulsets/scripts/cleanup-lesson-10-12.sh
```

Run only if you want cleanup:

```bash
./10.12-persistent-volumes-statefulsets/scripts/cleanup-lesson-10-12.sh
```

Important:

```text
StatefulSet deletion does not always delete PVCs automatically.
Always check PVCs and PVs after storage labs.
```

---

# 35. Practical Lab Summary

Run the main lab:

```bash
cd ~/devops-masterclass/10-kubernetes-production-operations

kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/emptydir-demo-pod.yaml

kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo.yaml
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/pvc-demo-deployment.yaml

kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/statefulset-demo.yaml

kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-secret.yaml
kubectl apply -f 10.12-persistent-volumes-statefulsets/manifests/mongodb-statefulset.yaml

./10.12-persistent-volumes-statefulsets/scripts/storage-summary.sh
./10.12-persistent-volumes-statefulsets/scripts/validate-lesson-10-12.sh
```

Useful inspection commands:

```bash
kubectl get pvc -n dev
kubectl get pv
kubectl get statefulset -n dev
kubectl get pods -n dev -o wide
kubectl describe pvc pvc-demo-data -n dev
kubectl describe statefulset stateful-demo -n dev
```

---

# 36. Common Myths and Misconceptions

## Myth 1: Pod data is persistent by default

Wrong.

```text
Container filesystem data is ephemeral.
Use volumes and PVCs for persistence.
```

## Myth 2: emptyDir is persistent

Wrong.

```text
emptyDir survives container restart inside the same Pod.
It does not survive Pod deletion.
```

## Myth 3: PVC is the actual disk

Not exactly.

```text
PVC is the claim/request.
PV is the storage resource.
StorageClass can dynamically provision the backing storage.
```

## Myth 4: StatefulSet automatically makes a database production-ready

Wrong.

```text
StatefulSet gives stable identity and storage.
It does not automatically solve backup, restore, replication, security, monitoring, or failover.
```

## Myth 5: Deployment is fine for every database

Usually wrong.

```text
Databases often require stable network identity, stable storage identity, and careful ordering.
StatefulSet or managed database is usually better.
```

## Myth 6: Deleting StatefulSet always deletes data

Not always.

```text
PVCs may remain.
This is often intentional to protect data.
```

---

# 37. Production Storage Rules

```text
Use emptyDir only for temporary data.
Use PVCs for durable filesystem data.
Understand StorageClass before using it.
Know reclaimPolicy before deleting PVCs.
Use WaitForFirstConsumer for zone-aware disk scheduling when appropriate.
Use StatefulSet for stable identity and per-replica storage.
Use headless Service for StatefulSet network identity.
Use one PVC per stateful replica.
Do not share one RWO PVC across many writer replicas.
Prefer managed databases for serious production.
Test backup and restore before trusting any database platform.
Always monitor disk usage, latency, IOPS, and filesystem errors.
```

---

# 38. Interview Explanation

Use this:

```text
Kubernetes storage separates Pod lifecycle from storage lifecycle. An emptyDir volume is temporary and tied to the Pod, while PersistentVolumes and PersistentVolumeClaims provide durable storage that can survive Pod replacement. A StorageClass defines how storage is dynamically provisioned, including provider behavior, reclaim policy, and binding mode.

For stateful applications, StatefulSets provide stable Pod names, stable DNS identity, and stable storage identity using volumeClaimTemplates. Each StatefulSet replica gets its own PVC, so if a Pod is recreated, the same ordinal gets the same storage again.

For production databases, I prefer managed services or mature operators where possible, because StatefulSet alone does not solve backup, restore, replication, upgrades, monitoring, and failover.
```

Resume version:

```text
Implemented Kubernetes storage and StatefulSet labs covering emptyDir, PVCs, PVs, StorageClasses, dynamic provisioning, access modes, reclaim policies, headless Services, volumeClaimTemplates, stable Pod/storage identity, MongoDB persistence testing, and production database storage runbooks.
```

---

# 39. Today’s Core Rules

```text
Container filesystem is ephemeral.
emptyDir is temporary Pod-level storage.
PVC requests storage.
PV represents storage.
StorageClass defines dynamic provisioning behavior.
Access modes depend on storage provider.
Reclaim policy controls what happens after claim release.
Volume binding mode affects scheduling and zone placement.
StatefulSet provides stable Pod identity.
volumeClaimTemplates create one PVC per replica.
Headless Service supports stable StatefulSet DNS.
Deployment is best for stateless apps.
StatefulSet is best for apps needing stable identity/storage.
Managed databases are often better for production than hand-rolled databases.
```

---

# 40. Commit Lesson 10.12

From repo root:

```bash
cd ~/devops-masterclass

git status

git add 10-kubernetes-production-operations

git commit -m "feat: add Kubernetes persistent volumes StatefulSets and database patterns lesson"

git push
```

---

# Next Lesson

```text
Lesson 10.13 — Helm, Kustomize, Overlays, Release Packaging, and Environment Promotion
```

We will cover:

```text
why raw YAML becomes hard to manage
Helm mental model
Chart.yaml
values.yaml
templates
helm install/upgrade/rollback
Kustomize mental model
base and overlays
dev/staging/production promotion
patches
configMapGenerator
secretGenerator
image tags
demo-node-api packaging pattern
when to use Helm vs Kustomize
```

[1]: https://kubernetes.io/docs/concepts/storage/volumes/?utm_source=chatgpt.com "Volumes"
[2]: https://kubernetes.io/docs/concepts/storage/persistent-volumes/?utm_source=chatgpt.com "Persistent Volumes"
[3]: https://kubernetes.io/docs/concepts/storage/storage-classes/?utm_source=chatgpt.com "Storage Classes"
[4]: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/?utm_source=chatgpt.com "StatefulSets"
[5]: https://kubernetes.io/docs/reference/kubernetes-api/apps/stateful-set-v1/?utm_source=chatgpt.com "StatefulSet"
