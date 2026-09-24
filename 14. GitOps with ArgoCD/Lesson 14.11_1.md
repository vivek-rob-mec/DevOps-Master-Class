# Module 14 — GitOps with Argo CD

## Lesson 14.11 — Sync Phases, Hooks, Sync Waves & Production Deployment Ordering

We’ll continue the **Argo CD module** from the production side rather than repeating the fundamentals we already covered.

This lesson solves a very important enterprise problem:

> **What happens when Kubernetes resources cannot safely be deployed at the same time?**

Imagine this deployment:

```text
New Release v2.4
      │
      ▼
Database migration
      │
      ▼
Config / Secrets
      │
      ▼
Backend API
      │
      ▼
Frontend
      │
      ▼
Smoke Test
      │
      ▼
Release considered successful
```

A normal Git repository only contains YAML. Kubernetes and Argo CD therefore need some mechanism to understand:

```text
"Run this FIRST"
"Deploy this SECOND"
"Wait for this"
"Run this AFTER deployment"
"If deployment fails, execute cleanup"
```

That is where **Argo CD Hooks + Sync Phases + Sync Waves** become extremely important.

---

# 1. The problem with deploying everything together

Suppose Git contains:

```text
production/
├── namespace.yaml
├── configmap.yaml
├── secret.yaml
├── database-migration.yaml
├── deployment.yaml
├── service.yaml
└── smoke-test.yaml
```

You push:

```bash
git push origin main
```

Argo CD detects:

```text
Git
 │
 │ desired state changed
 ▼
Argo CD
 │
 ▼
Kubernetes
```

But consider the dependencies.

```text
Migration must finish
        ↓
Backend must start
        ↓
Service must become available
        ↓
Smoke test should run
```

If the application starts **before the database migration completes**, production can break.

Example:

```text
Application v2 expects:
users.email_verified

Database currently:
users table DOES NOT have email_verified
```

Application starts:

```text
Backend Pod
   ↓
SELECT email_verified FROM users
   ↓
Database
   ↓
ERROR: column does not exist
```

Result:

```text
Deployment
    ↓
CrashLoopBackOff
    ↓
Production outage
```

We need controlled ordering.

---

# 2. Argo CD gives us two major ordering mechanisms

Think of them like this:

```text
SYNC PHASE
    │
    │  WHEN should something execute?
    ▼

SYNC WAVE
    │
    │  In what ORDER inside that phase?
    ▼
```

So:

```text
Phase = stage
Wave  = ordering within stage
```

For example:

```text
PreSync
 ├── Wave -10 → validation
 └── Wave -5  → database migration

Sync
 ├── Wave 0 → ConfigMap
 ├── Wave 1 → Backend
 └── Wave 2 → Frontend

PostSync
 ├── Wave 0 → smoke test
 └── Wave 5 → notification
```

This mental model is extremely important.

---

# 3. Sync Phases

Argo CD currently supports hooks such as:

```text
PreSync
Sync
PostSync
SyncFail
Skip
PreDelete
PostDelete
```

`PreSync` executes before normal application manifests. `PostSync` executes after the sync has succeeded and resources are healthy, while `SyncFail` runs when synchronization fails. Current Argo CD also supports deletion lifecycle hooks such as `PreDelete` and `PostDelete`. ([Argo CD][1])

For everyday deployment engineering, initially remember these four:

```text
             Argo CD Sync

                 START
                   │
                   ▼
              ┌─────────┐
              │ PreSync │
              └────┬────┘
                   │
                   ▼
               ┌──────┐
               │ Sync │
               └───┬──┘
                   │
             ┌─────┴─────┐
             │           │
          SUCCESS       FAILURE
             │           │
             ▼           ▼
       ┌──────────┐ ┌──────────┐
       │ PostSync │ │ SyncFail │
       └──────────┘ └──────────┘
```

---

# 4. PreSync Hook

`PreSync` means:

> Do this **before deploying the application**.

Common production use cases:

```text
Database migrations
Schema checks
Backup jobs
Dependency validation
Pre-deployment checks
Maintenance preparation
```

Example:

```yaml
apiVersion: batch/v1
kind: Job

metadata:
  name: database-migration

  annotations:
    argocd.argoproj.io/hook: PreSync

spec:
  template:
    spec:
      containers:
        - name: migration
          image: mycompany/backend:v2
          command:
            - npm
            - run
            - migrate

      restartPolicy: Never
```

The important part is:

```yaml
annotations:
  argocd.argoproj.io/hook: PreSync
```

Now deployment becomes:

```text
Git change
   │
   ▼
Argo CD
   │
   ▼
PreSync Job
Database Migration
   │
   ├── FAIL ──→ STOP
   │
   └── SUCCESS
          │
          ▼
      Deploy App
```

Argo CD's documented behavior is particularly useful here: if a `PreSync` hook fails, the synchronization stops rather than continuing with the deployment. ([Argo CD][1])

That is exactly what we want.

---

# 5. Why this is safer

Without a hook:

```text
Migration ──────────────┐
                        │ simultaneous
Backend Deployment ─────┤
                        │
Frontend ────────────────┘
```

Race condition.

With PreSync:

```text
Migration
   │
   │ SUCCESS
   ▼
Backend
   │
   ▼
Frontend
```

Deterministic deployment.

---

# 6. PostSync Hook

Now suppose deployment completed.

You don't immediately want to say:

```text
Deployment successful!
```

You may first want to test:

```text
GET /health
GET /ready
Login API
Database connectivity
Critical API workflow
```

That is where:

```text
PostSync
```

becomes useful.

Example:

```yaml
apiVersion: batch/v1
kind: Job

metadata:
  name: production-smoke-test

  annotations:
    argocd.argoproj.io/hook: PostSync

spec:
  template:
    spec:
      containers:

        - name: test
          image: curlimages/curl:latest

          command:
            - sh
            - -c
            - |
              curl --fail \
              http://todo-backend/health

      restartPolicy: Never
```

Flow:

```text
PreSync
Database migration
       │
       ▼
Sync
Application Deployment
       │
       ▼
Pods Healthy
       │
       ▼
PostSync
Smoke Test
       │
       ├── success
       │
       ▼
       ✅ Release validated
```

Argo CD waits until the normal sync succeeds and resources reach healthy state before running `PostSync` hooks. ([Argo CD][1])

This distinction matters.

---

# 7. SyncFail

Suppose deployment fails.

For example:

```text
Deployment
   ↓
ImagePullBackOff
   ↓
Argo CD Sync Failed
```

We may want some cleanup or failure action.

Example:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: SyncFail
```

Possible use:

```text
cleanup
incident integration
failure reporting
temporary-resource removal
```

Conceptually:

```text
                  Sync
                   │
              ┌────┴────┐
              │         │
           SUCCESS     FAILURE
              │         │
              ▼         ▼
          PostSync   SyncFail
```

Argo CD executes `SyncFail` hooks when the sync operation fails. ([Argo CD][1])

---

# 8. Hook lifecycle problem

There is another interesting problem.

Imagine this Job:

```text
database-migration
```

After it completes:

```bash
kubectl get jobs
```

might show:

```text
NAME                   COMPLETIONS
database-migration     1/1
```

Next release comes:

```text
v2.5
```

Argo CD wants to create:

```text
database-migration
```

again.

But the resource may already exist.

We therefore need **hook deletion policies**.

---

# 9. Hook Delete Policy

Example:

```yaml
metadata:

  annotations:

    argocd.argoproj.io/hook: PreSync

    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Important policies include:

```text
HookSucceeded
HookFailed
BeforeHookCreation
```

`HookSucceeded` deletes the hook resource after successful completion, `HookFailed` after failure, while `BeforeHookCreation` removes the previous hook before creating the next one. If no deletion policy is configured, Argo CD currently uses `BeforeHookCreation` behavior by default. ([Argo CD][1])

Typical migration job:

```yaml
apiVersion: batch/v1
kind: Job

metadata:

  name: database-migration

  annotations:

    argocd.argoproj.io/hook: PreSync

    argocd.argoproj.io/hook-delete-policy: HookSucceeded

spec:

  template:

    spec:

      containers:

        - name: migrate
          image: backend:v2

      restartPolicy: Never
```

---

# 10. Now comes Sync Waves

Hooks answer:

```text
WHEN?
```

But sometimes we need:

```text
WHICH RESOURCE FIRST?
```

For example:

```text
Namespace
   ↓
ConfigMap
   ↓
Secret
   ↓
Deployment
   ↓
Service
```

This is where we use:

```text
sync-wave
```

Annotation:

```yaml
argocd.argoproj.io/sync-wave: "1"
```

---

# 11. Basic Sync Wave example

Suppose:

### ConfigMap

```yaml
metadata:

  name: backend-config

  annotations:

    argocd.argoproj.io/sync-wave: "0"
```

Deployment:

```yaml
metadata:

  name: backend

  annotations:

    argocd.argoproj.io/sync-wave: "1"
```

Service:

```yaml
metadata:

  name: backend-service

  annotations:

    argocd.argoproj.io/sync-wave: "2"
```

Argo CD sees:

```text
Wave 0
  ConfigMap
      │
      ▼

Wave 1
  Deployment
      │
      ▼

Wave 2
  Service
```

Lower-numbered waves execute before higher-numbered waves, and resources without an explicit wave are assigned to wave `0`. Negative wave numbers are also supported. ([Argo CD][1])

---

# 12. Negative waves

This is very useful.

You can have:

```text
-20
-10
 -5
  0
  1
  5
 10
```

Example:

```text
Wave -20
Namespace

Wave -10
CRDs

Wave -5
ServiceAccount

Wave 0
ConfigMaps / Secrets

Wave 5
Backend

Wave 10
Frontend
```

Example:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
```

Think:

```text
SMALLER NUMBER
      =
RUN EARLIER
```

### Never-forget trick

```text
-10 → before
  0 → normal
+10 → after
```

---

# 13. Phase vs Wave — do not confuse them

This is one of the most common Argo CD interview questions.

### Phase

Controls the broad lifecycle:

```text
PreSync
Sync
PostSync
```

### Wave

Controls ordering **within that lifecycle**.

Example:

```text
PRE-SYNC PHASE

Wave -10
   │
   ├── Backup Job
   │
Wave -5
   │
   └── Migration Job


SYNC PHASE

Wave 0
   │
   ├── ConfigMap
   │
Wave 5
   │
   ├── Backend
   │
Wave 10
   │
   └── Frontend


POST-SYNC PHASE

Wave 0
   │
   └── Smoke Test
```

Argo CD's ordering precedence is essentially:

```text
Phase
  ↓
Wave
  ↓
Kind
  ↓
Name
```

and it processes lower-numbered waves first. ([Argo CD][1])

---

# 14. Production example

Let's build a deployment resembling something you'd encounter in an enterprise.

```text
                    Git Repository

                         │
                         ▼

                      Argo CD

                         │
           ┌─────────────┴──────────────┐
           │                            │
           ▼                            │

      PRE-SYNC PHASE                    │
                                        │
 Wave -10 → DB Backup                   │
                                        │
 Wave -5  → DB Migration                │
                                        │
           │                            │
           ▼                            │
                                        │
        SYNC PHASE                      │
                                        │
 Wave -10 → Namespace                   │
                                        │
 Wave -5  → Config/Secrets              │
                                        │
 Wave 0   → Backend                     │
                                        │
 Wave 5   → Service                     │
                                        │
 Wave 10  → Frontend                    │
                                        │
           │                            │
           ▼                            │
                                        │
      POST-SYNC PHASE                   │
                                        │
 Wave 0 → Health Check                  │
                                        │
 Wave 5 → Smoke Test                    │
                                        │
           ▼                            │
                                        │
      RELEASE HEALTHY ◄─────────────────┘
```

Now we're getting close to a **real production GitOps pipeline**.

---

# 15. Hands-on lab

Let's imagine our repository:

```text
gitops-repo/

└── apps/
    └── todo/
        └── production/

            ├── namespace.yaml
            ├── migration.yaml
            ├── configmap.yaml
            ├── deployment.yaml
            ├── service.yaml
            └── smoke-test.yaml
```

---

# 16. Namespace — early wave

`namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: todo-production

  annotations:
    argocd.argoproj.io/sync-wave: "-10"
```

---

# 17. ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap

metadata:

  name: todo-config
  namespace: todo-production

  annotations:
    argocd.argoproj.io/sync-wave: "-5"

data:

  NODE_ENV: production
  PORT: "3002"
```

Flow so far:

```text
Wave -10
Namespace
     │
     ▼
Wave -5
ConfigMap
```

---

# 18. Database migration as PreSync

For the lab, we'll simulate migration rather than touching a real production database.

```yaml
apiVersion: batch/v1
kind: Job

metadata:

  name: todo-db-migration
  namespace: todo-production

  annotations:

    argocd.argoproj.io/hook: PreSync

    argocd.argoproj.io/sync-wave: "-5"

    argocd.argoproj.io/hook-delete-policy: HookSucceeded

spec:

  template:

    spec:

      restartPolicy: Never

      containers:

        - name: migration

          image: alpine:3.22

          command:
            - sh
            - -c
            - |
              echo "Starting database migration..."
              sleep 5
              echo "Database migration completed successfully."
```

Notice something important:

```text
Hook:
PreSync

Wave:
-5
```

They're being used **together**.

---

# 19. Backend deployment

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:

  name: todo-backend
  namespace: todo-production

  annotations:
    argocd.argoproj.io/sync-wave: "0"

spec:

  replicas: 2

  selector:

    matchLabels:
      app: todo-backend

  template:

    metadata:
      labels:
        app: todo-backend

    spec:

      containers:

        - name: backend

          image: nginx:alpine

          ports:

            - containerPort: 80
```

Wave:

```text
0
```

---

# 20. Service

```yaml
apiVersion: v1
kind: Service

metadata:

  name: todo-backend
  namespace: todo-production

  annotations:
    argocd.argoproj.io/sync-wave: "5"

spec:

  selector:
    app: todo-backend

  ports:

    - port: 80
      targetPort: 80
```

Now:

```text
PreSync migration
      ↓

Wave -10 Namespace
      ↓
Wave -5 ConfigMap
      ↓
Wave 0 Backend
      ↓
Wave 5 Service
```

---

# 21. PostSync smoke test

Now our release test:

```yaml
apiVersion: batch/v1
kind: Job

metadata:

  name: todo-smoke-test
  namespace: todo-production

  annotations:

    argocd.argoproj.io/hook: PostSync

    argocd.argoproj.io/sync-wave: "10"

    argocd.argoproj.io/hook-delete-policy: HookSucceeded

spec:

  template:

    spec:

      restartPolicy: Never

      containers:

        - name: smoke-test

          image: curlimages/curl:latest

          command:

            - sh
            - -c
            - |
              echo "Running production smoke test..."

              curl --fail \
              http://todo-backend

              echo "Smoke test successful."
```

This is now a proper deployment lifecycle.

---

# 22. Push it using GitOps

Remember the GitOps rule:

```text
Developer
    ↓
changes Git

NOT

Developer
    ↓
changes production cluster directly
```

So:

```bash
git status
```

then:

```bash
git add .
```

Commit:

```bash
git commit -m "add ordered Argo CD production deployment"
```

Push:

```bash
git push origin main
```

Then Argo CD detects the new desired state.

With automated sync enabled, Argo CD can synchronize a Git change without requiring your CI pipeline to directly invoke the Argo CD API; the pipeline's responsibility can simply be updating Git. ([Argo CD][2])

Our architecture remains:

```text
CI

Build
 │
 ▼
Push Image
 │
 ▼
Update Git manifest
 │
 ▼
Git Commit
 │
 ▼


               GITOPS BOUNDARY


Git Repository
 │
 ▼
Argo CD
 │
 ▼
Kubernetes
```

Not:

```text
Jenkins
  │
  └── kubectl apply production.yaml
```

That distinction is one of the foundations of GitOps.

---

# 23. Watch the deployment

CLI:

```bash
argocd app get todo-production
```

Watch:

```bash
argocd app wait todo-production
```

You can also inspect Kubernetes:

```bash
kubectl get all -n todo-production
```

Watch Jobs:

```bash
kubectl get jobs -n todo-production -w
```

Pods:

```bash
kubectl get pods -n todo-production -w
```

---

# 24. What Argo CD is internally doing

Conceptually:

```text
Git changed
     │
     ▼
Application Controller detects OutOfSync
     │
     ▼
Construct sync plan
     │
     ▼
Evaluate phases
     │
     ▼
Evaluate waves
     │
     ▼
PreSync
     │
     ├── migration
     │
     ▼
Sync
     │
     ├── wave -10
     ├── wave -5
     ├── wave 0
     └── wave 5
     │
     ▼
Wait for health
     │
     ▼
PostSync
     │
     └── smoke test
     │
     ▼
Synced + Healthy
```

Argo CD also introduces a short delay between sync waves so Kubernetes controllers can react before Argo CD evaluates the next wave; the documented default is currently **2 seconds**, configurable with `ARGOCD_SYNC_WAVE_DELAY`. ([Argo CD][1])

---

# 25. Important: Healthy and Synced are NOT the same thing

This distinction is critical.

### Synced

Means:

```text
Git desired state
       =
Cluster desired configuration
```

### Healthy

Means roughly:

```text
Resources are functioning/reconciled as expected
```

So you can have:

```text
SYNC STATUS:
Synced

HEALTH STATUS:
Degraded
```

For example:

```text
Git says:

image: backend:v5
```

Cluster says:

```text
image: backend:v5
```

Therefore:

```text
Synced ✅
```

But:

```text
backend:v5
   ↓
CrashLoopBackOff
```

Therefore:

```text
Healthy ❌
```

Argo CD has built-in health assessments for Kubernetes resources such as Deployments, StatefulSets, DaemonSets, Services, Ingresses, Jobs and PVCs. For workload controllers, it evaluates signals including observed generation and updated replica counts. ([Argo CD][3])

### Never forget

```text
SYNCED ≠ HEALTHY

Synced:
Configuration matches Git.

Healthy:
Application/resources are operating correctly.
```

---

# 26. What happens when migration fails?

Let's intentionally change:

```yaml
command:
  - sh
  - -c
  - |
    echo "Migration failed"
    exit 1
```

Commit:

```bash
git add .
git commit -m "test migration failure"
git push
```

Lifecycle:

```text
Argo CD
   │
   ▼
PreSync
   │
   ▼
Migration Job
   │
   ▼
exit 1
   │
   ▼
FAILED
   │
   X

Backend NOT DEPLOYED
Frontend NOT DEPLOYED
PostSync NOT EXECUTED
```

That's exactly why PreSync is so useful for risky migrations. Argo CD stops the sync when a `PreSync` hook fails. ([Argo CD][1])

---

# 27. Production design pattern

A more realistic enterprise application could use:

```text
Wave -100
CRDs

Wave -90
Namespace

Wave -80
ServiceAccounts / RBAC

Wave -50
ConfigMaps

Wave -40
Secrets / ExternalSecret definitions

Wave -20
Database dependencies

Wave 0
Backend API

Wave 10
Worker

Wave 20
Frontend

Wave 30
Ingress

Wave 40
Monitoring

Wave 50
Smoke tests
```

Don't blindly create fifty waves, though.

Use them only when there is a **real dependency**.

Bad:

```text
Wave 1
Wave 2
Wave 3
Wave 4
Wave 5
...
```

for every resource merely because you can.

Better:

```text
Group things by actual dependency.
```

---

# 28. A common mistake

Many beginners try:

```text
Deployment wave 0

Service wave 1
```

because they think:

> The Service cannot exist before the Pod.

That's not generally necessary.

Kubernetes Services can exist even when zero matching Pods currently exist.

So don't use waves to micromanage Kubernetes.

Let Kubernetes's declarative controllers do their work.

Use Argo CD waves when **real application/controller ordering matters**.

---

# 29. Production sync options you should know

Another related concept is:

```yaml
spec:

  syncPolicy:

    syncOptions:
```

For example:

```yaml
syncPolicy:

  syncOptions:

    - CreateNamespace=true
```

Argo CD currently supports sync options for behaviors including namespace creation, pruning controls, server-side apply, validation behavior and shared-resource protection. ([Argo CD][4])

Examples you'll encounter:

```text
CreateNamespace=true

Prune=false

Prune=confirm

ServerSideApply=true

FailOnSharedResource=true

RespectIgnoreDifferences=true

SkipDryRunOnMissingResource=true
```

We'll treat these as a separate production topic because there are important side effects.

---

# 30. Very useful safety control — Prune confirmation

Imagine Git accidentally removes:

```text
production namespace
```

Auto-pruning could be dangerous.

Argo CD supports:

```yaml
argocd.argoproj.io/sync-options: Prune=confirm
```

which can require explicit confirmation before pruning critical resources. ([Argo CD][4])

This is particularly useful to remember for things like:

```text
Namespaces
PVC-related resources
Critical infrastructure
Shared components
```

---

# 31. One major gotcha: selective sync

Suppose someone selects only:

```text
Deployment
```

and runs selective sync.

Do the hooks run?

**No.**

Argo CD's documentation explicitly notes that hooks do not run during selective sync operations. ([Argo CD][1])

This matters enormously.

Imagine:

```text
PreSync:
database migration

Selective sync:
backend Deployment only
```

Then:

```text
Migration may not run
       ↓
Backend starts
       ↓
Schema mismatch
```

### Interview point

> Why can selective sync be dangerous when applications depend on PreSync/PostSync hooks?

Because selective sync bypasses those hooks.

---

# 32. Production troubleshooting

If synchronization is stuck:

```bash
argocd app get todo-production
```

Check operations:

```bash
argocd app history todo-production
```

Check Pods:

```bash
kubectl get pods -n todo-production
```

Jobs:

```bash
kubectl get jobs -n todo-production
```

Describe failed migration:

```bash
kubectl describe job todo-db-migration \
  -n todo-production
```

Logs:

```bash
kubectl logs job/todo-db-migration \
  -n todo-production
```

Argo CD controller:

```bash
kubectl logs \
  -n argocd \
  deployment/argocd-application-controller
```

And inspect events:

```bash
kubectl get events \
  -n todo-production \
  --sort-by=.metadata.creationTimestamp
```

---

# 33. Troubleshooting mental model

When deployment fails, ask:

```text
1. Did Git contain the expected state?

               ↓

2. Did Argo CD detect the commit?

               ↓

3. Is Application OutOfSync?

               ↓

4. Which sync PHASE failed?

               ↓

5. Which sync WAVE failed?

               ↓

6. Which Kubernetes resource failed?

               ↓

7. What does kubectl describe show?

               ↓

8. What do container/job logs show?
```

Don't randomly restart Argo CD.

Follow the chain.

---

# 34. Real enterprise architecture

Now place what we've learned into CI/CD:

```text
Developer
   │
   ▼
GitHub Application Repository
   │
   ▼
Jenkins / GitHub Actions
   │
   ├── Unit Test
   ├── SAST
   ├── Build Docker Image
   ├── Scan Image
   └── Push ECR
           │
           ▼
      ECR
           │

CI updates:

GitOps Repository
      │
      ▼
image:
  repository: todo-backend
  tag: v2.7.14
      │
      ▼
Commit + Push
      │
      ▼

────────────────────────────
        CI / CD boundary
────────────────────────────

      Argo CD
         │
         ▼
      PreSync
         │
     DB Migration
         │
         ▼
    Sync Waves
         │
   ┌─────┼──────┐
   ▼     ▼      ▼
Config Backend Frontend
         │
         ▼
      Healthy
         │
         ▼
     PostSync
         │
     Smoke Test
         │
         ▼
   Production ✅
```

This is a **proper production GitOps deployment architecture**.

---

# 35. Interview questions from this lesson

### Q1. What is a Sync Wave?

A mechanism for controlling the ordering of resources during Argo CD synchronization.

```text
Lower wave
   ↓
Higher wave
```

---

### Q2. What is a Sync Phase?

A deployment lifecycle stage such as:

```text
PreSync
Sync
PostSync
SyncFail
```

---

### Q3. Difference between phase and wave?

```text
Phase
    = WHEN

Wave
    = ORDER
```

---

### Q4. What would you use for database migration?

Usually:

```text
PreSync hook
```

possibly combined with a negative sync wave when multiple PreSync operations have dependencies.

---

### Q5. What would you use for smoke testing?

```text
PostSync hook
```

---

### Q6. What happens when PreSync fails?

The deployment sync stops.

---

### Q7. Do hooks execute during selective sync?

```text
No.
```

([Argo CD][1])

---

### Q8. Is Synced the same as Healthy?

No.

```text
Synced
=
Git state matches cluster configuration

Healthy
=
resource health assessment is successful
```

---

# 36. Never-forget memory map

Memorize this:

```text
                ARGO CD RELEASE

                     │
                     ▼
               ┌──────────┐
               │ PreSync  │
               └────┬─────┘
                    │
              DB Migration
                    │
                    ▼
               ┌──────────┐
               │   Sync   │
               └────┬─────┘
                    │
             Sync Waves
                    │
       ┌────────────┼────────────┐

      -10           0            10
       │            │             │
     Config       Backend       Frontend

                    │
                    ▼
                 Healthy
                    │
                    ▼
              ┌──────────┐
              │ PostSync │
              └────┬─────┘
                   │
              Smoke Tests
                   │
                   ▼
             RELEASE ✅
```

And the shortest trick:

```text
HOOK  = WHAT lifecycle event?

PHASE = WHEN?

WAVE  = WHICH ORDER?

SYNCED = Matches Git

HEALTHY = Works correctly
```

---

## Where we are now

```text
MODULE 14 — GitOps with Argo CD

GitOps mental model                 ✅
Argo CD architecture                ✅
Installation / cluster integration  ✅
Applications                        ✅
Automatic reconciliation            ✅
Git repository patterns             ✅
Helm / Kustomize GitOps concepts    ✅
Application organization            ✅
Production GitOps concepts           ✅

14.11 Sync Phases / Hooks / Waves    ✅  ← TODAY

NEXT
  ↓
14.12 Advanced Argo CD Sync Policies & Sync Options
  ↓
Prune / Self-Heal / PruneLast
Server-Side Apply
IgnoreDifferences
FailOnSharedResource
CreateNamespace
Deletion protection
Production safety patterns
Drift scenarios
Real troubleshooting lab
```

**Next we should go into Lesson 14.12 — Advanced Argo CD Sync Policies, Pruning, Self-Healing, Drift Management & Production-Safe Sync Options.** That lesson is where we'll see what Argo CD does when somebody manually changes production with `kubectl`, when Git deletes a resource, and how to prevent GitOps automation from accidentally deleting critical infrastructure.

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.11.37 Professional Mastery Workbook

This workbook expands **Sync Phases, Hooks, Sync Waves & Production Deployment Ordering** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 36 lesson-specific anchors.
- Progression: beginner, intermediate, expert, professional, industry-ready, certification review, and interview defense.
- Safety: use synthetic data, disposable resources, explicit placeholders, least privilege, and bounded failure experiments.
- Completion: retain commands or configuration, observations, screenshots or query output, decisions, rollback evidence, and a short reflection.
- Quality rule: a passing answer states assumptions, protects a user or business outcome, names ownership, and validates the final result end to end.
- Currency rule: verify current official documentation, versions, limits, pricing, and certification objectives before relying on changing product behavior.

## Seven-stage progression

| Stage | Learner must demonstrate |
|---|---|
| Beginner | Explain the concept in plain language and give one safe example. |
| Intermediate | Connect components, data, control flow, and normal operating behavior. |
| Expert | Analyze trade-offs, edge cases, scaling pressure, and correlated failures. |
| Professional | Make a reviewed decision with owner, evidence, rollout, and rollback. |
| Industry-ready | Operate the design under security, failure, recovery, cost, and compliance constraints. |
| Certification review | Map durable concepts to the latest official objectives without relying on stale wording. |
| Interview defense | Answer concisely, clarify assumptions, draw the model, and defend alternatives. |

## Concept mastery cards

### Concept card 1 - The problem with deploying everything together

- Lesson anchor: Suppose Git contains: production/ ├── namespace.yaml ├── configmap.yaml ├── secret.yaml ├── database-migration.yaml ├── deployment.yaml ├── service.yaml └── smoke-test.yaml You push: git push origin main Argo CD detects:
- Beginner explanation: Restate **The problem with deploying everything together** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The problem with deploying everything together** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **The problem with deploying everything together**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **The problem with deploying everything together**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The problem with deploying everything together** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Argo CD gives us two major ordering mechanisms

- Lesson anchor: Think of them like this: SYNC PHASE │ │  WHEN should something execute? ▼ SYNC WAVE │ │  In what ORDER inside that phase? ▼ So: Phase = stage Wave  = ordering within stage For example: PreSync ├── Wave -10 → validation └── Wave -5  → database migration
- Beginner explanation: Restate **Argo CD gives us two major ordering mechanisms** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo CD gives us two major ordering mechanisms** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Argo CD gives us two major ordering mechanisms**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Argo CD gives us two major ordering mechanisms**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo CD gives us two major ordering mechanisms** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - Sync Phases

- Lesson anchor: Argo CD currently supports hooks such as: PreSync Sync PostSync SyncFail Skip PreDelete PostDelete PreSync executes before normal application manifests. PostSync executes after the sync has succeeded and resources are healthy, while SyncFail runs when synch...
- Beginner explanation: Restate **Sync Phases** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Sync Phases** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Sync Phases**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Sync Phases**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Sync Phases** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - PreSync Hook

- Lesson anchor: PreSync means: Do this before deploying the application. Common production use cases: Database migrations Schema checks Backup jobs Dependency validation Pre-deployment checks Maintenance preparation Example: apiVersion: batch/v1
- Beginner explanation: Restate **PreSync Hook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PreSync Hook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **PreSync Hook**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **PreSync Hook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PreSync Hook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Why this is safer

- Lesson anchor: Without a hook: Migration ──────────────┐ │ simultaneous Backend Deployment ─────┤ │ Frontend ────────────────┘ Race condition. With PreSync: Migration │ │ SUCCESS ▼ Backend │ ▼ Frontend Deterministic deployment. ---
- Beginner explanation: Restate **Why this is safer** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why this is safer** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Why this is safer**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Why this is safer**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why this is safer** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - PostSync Hook

- Lesson anchor: Now suppose deployment completed. You don't immediately want to say: Deployment successful! You may first want to test: GET /health GET /ready Login API Database connectivity Critical API workflow That is where: PostSync
- Beginner explanation: Restate **PostSync Hook** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PostSync Hook** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **PostSync Hook**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **PostSync Hook**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PostSync Hook** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - SyncFail

- Lesson anchor: Suppose deployment fails. For example: Deployment ↓ ImagePullBackOff ↓ Argo CD Sync Failed We may want some cleanup or failure action. Example: metadata: annotations: argocd.argoproj.io/hook: SyncFail Possible use: cleanup
- Beginner explanation: Restate **SyncFail** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SyncFail** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **SyncFail**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **SyncFail**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SyncFail** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Hook lifecycle problem

- Lesson anchor: There is another interesting problem. Imagine this Job: database-migration After it completes: kubectl get jobs might show: NAME                   COMPLETIONS database-migration     1/1 Next release comes: v2.5 Argo CD wants to create:
- Beginner explanation: Restate **Hook lifecycle problem** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook lifecycle problem** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Hook lifecycle problem**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Hook lifecycle problem**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook lifecycle problem** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Hook Delete Policy

- Lesson anchor: Example: metadata: annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/hook-delete-policy: HookSucceeded Important policies include: HookSucceeded HookFailed BeforeHookCreation HookSucceeded deletes the hook resource after successful completion...
- Beginner explanation: Restate **Hook Delete Policy** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hook Delete Policy** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Hook Delete Policy**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Hook Delete Policy**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hook Delete Policy** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Now comes Sync Waves

- Lesson anchor: Hooks answer: WHEN? But sometimes we need: WHICH RESOURCE FIRST? For example: Namespace ↓ ConfigMap ↓ Secret ↓ Deployment ↓ Service This is where we use: sync-wave Annotation: argocd.argoproj.io/sync-wave: "1" ---
- Beginner explanation: Restate **Now comes Sync Waves** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Now comes Sync Waves** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Now comes Sync Waves**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Now comes Sync Waves**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Now comes Sync Waves** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Basic Sync Wave example

- Lesson anchor: Suppose: metadata: name: backend-config annotations: argocd.argoproj.io/sync-wave: "0" Deployment: metadata: name: backend annotations: argocd.argoproj.io/sync-wave: "1" Service: metadata: name: backend-service annotations:
- Beginner explanation: Restate **Basic Sync Wave example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Basic Sync Wave example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Basic Sync Wave example**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Basic Sync Wave example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Basic Sync Wave example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Negative waves

- Lesson anchor: This is very useful. You can have: -20 -10 -5 0 1 5 10 Example: Wave -20 Namespace Wave -10 CRDs Wave -5 ServiceAccount Wave 0 ConfigMaps / Secrets Wave 5 Backend Wave 10 Frontend Example: metadata: annotations: argocd.argoproj.io/sync-wave: "-10"
- Beginner explanation: Restate **Negative waves** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Negative waves** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Negative waves**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Negative waves**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Negative waves** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - Phase vs Wave — do not confuse them

- Lesson anchor: This is one of the most common Argo CD interview questions. Controls the broad lifecycle: PreSync Sync PostSync Controls ordering within that lifecycle. Example: PRE-SYNC PHASE Wave -10 │ ├── Backup Job │ Wave -5 │ └── Migration Job
- Beginner explanation: Restate **Phase vs Wave — do not confuse them** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Phase vs Wave — do not confuse them** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Phase vs Wave — do not confuse them**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Phase vs Wave — do not confuse them**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Phase vs Wave — do not confuse them** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Production example

- Lesson anchor: Let's build a deployment resembling something you'd encounter in an enterprise. Git Repository │ ▼ Argo CD │ ┌─────────────┴──────────────┐ │                            │ ▼                            │ PRE-SYNC PHASE                    │
- Beginner explanation: Restate **Production example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Production example**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Production example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Hands-on lab

- Lesson anchor: Let's imagine our repository: gitops-repo/ └── apps/ └── todo/ └── production/ ├── namespace.yaml ├── migration.yaml ├── configmap.yaml ├── deployment.yaml ├── service.yaml └── smoke-test.yaml ---
- Beginner explanation: Restate **Hands-on lab** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Hands-on lab** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Hands-on lab**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Hands-on lab**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Hands-on lab** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Namespace — early wave

- Lesson anchor: namespace.yaml apiVersion: v1 kind: Namespace metadata: name: todo-production annotations: argocd.argoproj.io/sync-wave: "-10" ---
- Beginner explanation: Restate **Namespace — early wave** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Namespace — early wave** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Namespace — early wave**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Namespace — early wave**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Namespace — early wave** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - ConfigMap

- Lesson anchor: apiVersion: v1 kind: ConfigMap metadata: name: todo-config namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "-5" data: NODEENV: production PORT: "3002" Flow so far: Wave -10 Namespace │ ▼ Wave -5 ConfigMap
- Beginner explanation: Restate **ConfigMap** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **ConfigMap** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **ConfigMap**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **ConfigMap**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **ConfigMap** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Database migration as PreSync

- Lesson anchor: For the lab, we'll simulate migration rather than touching a real production database. apiVersion: batch/v1 kind: Job metadata: name: todo-db-migration namespace: todo-production annotations: argocd.argoproj.io/hook: PreSync
- Beginner explanation: Restate **Database migration as PreSync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Database migration as PreSync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Database migration as PreSync**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Database migration as PreSync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Database migration as PreSync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Backend deployment

- Lesson anchor: apiVersion: apps/v1 kind: Deployment metadata: name: todo-backend namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "0" spec: replicas: 2 selector: matchLabels: app: todo-backend template: metadata: labels:
- Beginner explanation: Restate **Backend deployment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Backend deployment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Backend deployment**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Backend deployment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Backend deployment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - Service

- Lesson anchor: apiVersion: v1 kind: Service metadata: name: todo-backend namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "5" spec: selector: app: todo-backend ports: targetPort: 80 Now: PreSync migration ↓ Wave -10 Namespace
- Beginner explanation: Restate **Service** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Service** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Service**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Service**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Service** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - PostSync smoke test

- Lesson anchor: Now our release test: apiVersion: batch/v1 kind: Job metadata: name: todo-smoke-test namespace: todo-production annotations: argocd.argoproj.io/hook: PostSync argocd.argoproj.io/sync-wave: "10" argocd.argoproj.io/hook-delete-policy: HookSucceeded
- Beginner explanation: Restate **PostSync smoke test** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **PostSync smoke test** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **PostSync smoke test**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **PostSync smoke test**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **PostSync smoke test** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Push it using GitOps

- Lesson anchor: Remember the GitOps rule: Developer ↓ changes Git NOT Developer ↓ changes production cluster directly So: git status then: git add . Commit: git commit -m "add ordered Argo CD production deployment" Push: git push origin main
- Beginner explanation: Restate **Push it using GitOps** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Push it using GitOps** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Push it using GitOps**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Push it using GitOps**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Push it using GitOps** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Watch the deployment

- Lesson anchor: CLI: argocd app get todo-production Watch: argocd app wait todo-production You can also inspect Kubernetes: kubectl get all -n todo-production Watch Jobs: kubectl get jobs -n todo-production -w Pods: kubectl get pods -n todo-production -w
- Beginner explanation: Restate **Watch the deployment** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Watch the deployment** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Watch the deployment**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Watch the deployment**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Watch the deployment** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - What Argo CD is internally doing

- Lesson anchor: Conceptually: Git changed │ ▼ Application Controller detects OutOfSync │ ▼ Construct sync plan │ ▼ Evaluate phases │ ▼ Evaluate waves │ ▼ PreSync │ ├── migration │ ▼ Sync │ ├── wave -10 ├── wave -5 ├── wave 0 └── wave 5 │
- Beginner explanation: Restate **What Argo CD is internally doing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What Argo CD is internally doing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **What Argo CD is internally doing**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **What Argo CD is internally doing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What Argo CD is internally doing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Important: Healthy and Synced are NOT the same thing

- Lesson anchor: This distinction is critical. Means: Git desired state = Cluster desired configuration Means roughly: Resources are functioning/reconciled as expected So you can have: SYNC STATUS: Synced HEALTH STATUS: Degraded For example:
- Beginner explanation: Restate **Important: Healthy and Synced are NOT the same thing** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important: Healthy and Synced are NOT the same thing** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Important: Healthy and Synced are NOT the same thing**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Important: Healthy and Synced are NOT the same thing**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important: Healthy and Synced are NOT the same thing** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - What happens when migration fails?

- Lesson anchor: Let's intentionally change: command: echo "Migration failed" exit 1 Commit: git add . git commit -m "test migration failure" git push Lifecycle: Argo CD │ ▼ PreSync │ ▼ Migration Job │ ▼ exit 1 │ ▼ FAILED │ X Backend NOT DEPLOYED
- Beginner explanation: Restate **What happens when migration fails?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What happens when migration fails?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **What happens when migration fails?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **What happens when migration fails?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What happens when migration fails?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - Production design pattern

- Lesson anchor: A more realistic enterprise application could use: Wave -100 CRDs Wave -90 Namespace Wave -80 ServiceAccounts / RBAC Wave -50 ConfigMaps Wave -40 Secrets / ExternalSecret definitions Wave -20 Database dependencies Wave 0
- Beginner explanation: Restate **Production design pattern** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production design pattern** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Production design pattern**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Production design pattern**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production design pattern** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - A common mistake

- Lesson anchor: Many beginners try: Deployment wave 0 Service wave 1 because they think: The Service cannot exist before the Pod. That's not generally necessary. Kubernetes Services can exist even when zero matching Pods currently exist.
- Beginner explanation: Restate **A common mistake** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **A common mistake** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **A common mistake**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **A common mistake**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **A common mistake** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - Production sync options you should know

- Lesson anchor: Another related concept is: spec: syncPolicy: syncOptions: For example: syncPolicy: syncOptions: Argo CD currently supports sync options for behaviors including namespace creation, pruning controls, server-side apply, validation behavior and shared-resource...
- Beginner explanation: Restate **Production sync options you should know** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production sync options you should know** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Production sync options you should know**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Production sync options you should know**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production sync options you should know** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - Very useful safety control — Prune confirmation

- Lesson anchor: Imagine Git accidentally removes: production namespace Auto-pruning could be dangerous. Argo CD supports: argocd.argoproj.io/sync-options: Prune=confirm which can require explicit confirmation before pruning critical resources. ([Argo CD][4])
- Beginner explanation: Restate **Very useful safety control — Prune confirmation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Very useful safety control — Prune confirmation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Very useful safety control — Prune confirmation**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Very useful safety control — Prune confirmation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Very useful safety control — Prune confirmation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - One major gotcha: selective sync

- Lesson anchor: Suppose someone selects only: Deployment and runs selective sync. Do the hooks run? No. Argo CD's documentation explicitly notes that hooks do not run during selective sync operations. ([Argo CD][1]) This matters enormously.
- Beginner explanation: Restate **One major gotcha: selective sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **One major gotcha: selective sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **One major gotcha: selective sync**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **One major gotcha: selective sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **One major gotcha: selective sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Production troubleshooting

- Lesson anchor: If synchronization is stuck: argocd app get todo-production Check operations: argocd app history todo-production Check Pods: kubectl get pods -n todo-production Jobs: kubectl get jobs -n todo-production Describe failed migration:
- Beginner explanation: Restate **Production troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Production troubleshooting**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Production troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Troubleshooting mental model

- Lesson anchor: When deployment fails, ask: ↓ ↓ ↓ ↓ ↓ ↓ ↓ Don't randomly restart Argo CD. Follow the chain. ---
- Beginner explanation: Restate **Troubleshooting mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Troubleshooting mental model**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Troubleshooting mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - Real enterprise architecture

- Lesson anchor: Now place what we've learned into CI/CD: Developer │ ▼ GitHub Application Repository │ ▼ Jenkins / GitHub Actions │ ├── Unit Test ├── SAST ├── Build Docker Image ├── Scan Image └── Push ECR │ ▼ ECR │ CI updates: GitOps Repository
- Beginner explanation: Restate **Real enterprise architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Real enterprise architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Real enterprise architecture**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Real enterprise architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Real enterprise architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - Interview questions from this lesson

- Lesson anchor: A mechanism for controlling the ordering of resources during Argo CD synchronization. Lower wave ↓ Higher wave --- A deployment lifecycle stage such as: PreSync Sync PostSync SyncFail --- Phase = WHEN Wave = ORDER --- Usually:
- Beginner explanation: Restate **Interview questions from this lesson** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview questions from this lesson** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview questions from this lesson**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview questions from this lesson**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview questions from this lesson** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - Never-forget memory map

- Lesson anchor: Memorize this: ARGO CD RELEASE │ ▼ ┌──────────┐ │ PreSync  │ └────┬─────┘ │ DB Migration │ ▼ ┌──────────┐ │   Sync   │ └────┬─────┘ │ Sync Waves │ ┌────────────┼────────────┐ -10           0            10 │            │             │
- Beginner explanation: Restate **Never-forget memory map** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget memory map** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Never-forget memory map**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Never-forget memory map**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget memory map** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - The problem with deploying everything together x data integrity

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **The problem with deploying everything together** while a change involving **PreSync Hook** places **data integrity** at risk.
- Plain-language question: What problem does **The problem with deploying everything together** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose Git contains: production/ ├── namespace.yaml ├── configmap.yaml ├── secret.yaml ├── database-migration.yaml ├── deployment.yaml ├── service.yaml └── smoke-test.yaml You push: git push origin main Argo CD detects:
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **The problem with deploying everything together** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 002 - Argo CD gives us two major ordering mechanisms x automation safety

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Argo CD gives us two major ordering mechanisms** while a change involving **Basic Sync Wave example** places **automation safety** at risk.
- Plain-language question: What problem does **Argo CD gives us two major ordering mechanisms** solve here, and who notices first when it fails?
- Lesson evidence anchor: Think of them like this: SYNC PHASE │ │  WHEN should something execute? ▼ SYNC WAVE │ │  In what ORDER inside that phase? ▼ So: Phase = stage Wave  = ordering within stage For example: PreSync ├── Wave -10 → validation └── Wave -5  → database migration
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo CD gives us two major ordering mechanisms** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 003 - Sync Phases x governance

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Sync Phases** while a change involving **Database migration as PreSync** places **governance** at risk.
- Plain-language question: What problem does **Sync Phases** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD currently supports hooks such as: PreSync Sync PostSync SyncFail Skip PreDelete PostDelete PreSync executes before normal application manifests. PostSync executes after the sync has succeeded and resources are healthy, while SyncFail runs when synch...
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Sync Phases** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 004 - PreSync Hook x correctness

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **PreSync Hook** while a change involving **Important: Healthy and Synced are NOT the same thing** places **correctness** at risk.
- Plain-language question: What problem does **PreSync Hook** solve here, and who notices first when it fails?
- Lesson evidence anchor: PreSync means: Do this before deploying the application. Common production use cases: Database migrations Schema checks Backup jobs Dependency validation Pre-deployment checks Maintenance preparation Example: apiVersion: batch/v1
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PreSync Hook** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 005 - Why this is safer x capacity

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Why this is safer** while a change involving **Production troubleshooting** places **capacity** at risk.
- Plain-language question: What problem does **Why this is safer** solve here, and who notices first when it fails?
- Lesson evidence anchor: Without a hook: Migration ──────────────┐ │ simultaneous Backend Deployment ─────┤ │ Frontend ────────────────┘ Race condition. With PreSync: Migration │ │ SUCCESS ▼ Backend │ ▼ Frontend Deterministic deployment. ---
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Why this is safer** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 006 - PostSync Hook x cost efficiency

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **PostSync Hook** while a change involving **Sync Phases** places **cost efficiency** at risk.
- Plain-language question: What problem does **PostSync Hook** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now suppose deployment completed. You don't immediately want to say: Deployment successful! You may first want to test: GET /health GET /ready Login API Database connectivity Critical API workflow That is where: PostSync
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PostSync Hook** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 007 - SyncFail x recovery

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **SyncFail** while a change involving **Now comes Sync Waves** places **recovery** at risk.
- Plain-language question: What problem does **SyncFail** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose deployment fails. For example: Deployment ↓ ImagePullBackOff ↓ Argo CD Sync Failed We may want some cleanup or failure action. Example: metadata: annotations: argocd.argoproj.io/hook: SyncFail Possible use: cleanup
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **SyncFail** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 008 - Hook lifecycle problem x change management

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Hook lifecycle problem** while a change involving **ConfigMap** places **change management** at risk.
- Plain-language question: What problem does **Hook lifecycle problem** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is another interesting problem. Imagine this Job: database-migration After it completes: kubectl get jobs might show: NAME                   COMPLETIONS database-migration     1/1 Next release comes: v2.5 Argo CD wants to create:
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Hook lifecycle problem** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 009 - Hook Delete Policy x dependency failure

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Hook Delete Policy** while a change involving **What Argo CD is internally doing** places **dependency failure** at risk.
- Plain-language question: What problem does **Hook Delete Policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: metadata: annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/hook-delete-policy: HookSucceeded Important policies include: HookSucceeded HookFailed BeforeHookCreation HookSucceeded deletes the hook resource after successful completion...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Hook Delete Policy** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 010 - Now comes Sync Waves x developer experience

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Now comes Sync Waves** while a change involving **One major gotcha: selective sync** places **developer experience** at risk.
- Plain-language question: What problem does **Now comes Sync Waves** solve here, and who notices first when it fails?
- Lesson evidence anchor: Hooks answer: WHEN? But sometimes we need: WHICH RESOURCE FIRST? For example: Namespace ↓ ConfigMap ↓ Secret ↓ Deployment ↓ Service This is where we use: sync-wave Annotation: argocd.argoproj.io/sync-wave: "1" ---
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Now comes Sync Waves** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 011 - Basic Sync Wave example x availability

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Basic Sync Wave example** while a change involving **Argo CD gives us two major ordering mechanisms** places **availability** at risk.
- Plain-language question: What problem does **Basic Sync Wave example** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose: metadata: name: backend-config annotations: argocd.argoproj.io/sync-wave: "0" Deployment: metadata: name: backend annotations: argocd.argoproj.io/sync-wave: "1" Service: metadata: name: backend-service annotations:
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Basic Sync Wave example** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 012 - Negative waves x security

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **Negative waves** while a change involving **Hook Delete Policy** places **security** at risk.
- Plain-language question: What problem does **Negative waves** solve here, and who notices first when it fails?
- Lesson evidence anchor: This is very useful. You can have: -20 -10 -5 0 1 5 10 Example: Wave -20 Namespace Wave -10 CRDs Wave -5 ServiceAccount Wave 0 ConfigMaps / Secrets Wave 5 Backend Wave 10 Frontend Example: metadata: annotations: argocd.argoproj.io/sync-wave: "-10"
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Negative waves** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 013 - Phase vs Wave — do not confuse them x delivery safety

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Phase vs Wave — do not confuse them** while a change involving **Namespace — early wave** places **delivery safety** at risk.
- Plain-language question: What problem does **Phase vs Wave — do not confuse them** solve here, and who notices first when it fails?
- Lesson evidence anchor: This is one of the most common Argo CD interview questions. Controls the broad lifecycle: PreSync Sync PostSync Controls ordering within that lifecycle. Example: PRE-SYNC PHASE Wave -10 │ ├── Backup Job │ Wave -5 │ └── Migration Job
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Phase vs Wave — do not confuse them** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 014 - Production example x multi-tenancy

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **Production example** while a change involving **Watch the deployment** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Production example** solve here, and who notices first when it fails?
- Lesson evidence anchor: Let's build a deployment resembling something you'd encounter in an enterprise. Git Repository │ ▼ Argo CD │ ┌─────────────┴──────────────┐ │                            │ ▼                            │ PRE-SYNC PHASE                    │
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production example** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 015 - Hands-on lab x observability

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Hands-on lab** while a change involving **Very useful safety control — Prune confirmation** places **observability** at risk.
- Plain-language question: What problem does **Hands-on lab** solve here, and who notices first when it fails?
- Lesson evidence anchor: Let's imagine our repository: gitops-repo/ └── apps/ └── todo/ └── production/ ├── namespace.yaml ├── migration.yaml ├── configmap.yaml ├── deployment.yaml ├── service.yaml └── smoke-test.yaml ---
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Hands-on lab** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 016 - Namespace — early wave x regional resilience

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Namespace — early wave** while a change involving **The problem with deploying everything together** places **regional resilience** at risk.
- Plain-language question: What problem does **Namespace — early wave** solve here, and who notices first when it fails?
- Lesson evidence anchor: namespace.yaml apiVersion: v1 kind: Namespace metadata: name: todo-production annotations: argocd.argoproj.io/sync-wave: "-10" ---
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Namespace — early wave** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 017 - ConfigMap x business value

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **ConfigMap** while a change involving **Hook lifecycle problem** places **business value** at risk.
- Plain-language question: What problem does **ConfigMap** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: v1 kind: ConfigMap metadata: name: todo-config namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "-5" data: NODEENV: production PORT: "3002" Flow so far: Wave -10 Namespace │ ▼ Wave -5 ConfigMap
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **ConfigMap** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 018 - Database migration as PreSync x latency

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Database migration as PreSync** while a change involving **Hands-on lab** places **latency** at risk.
- Plain-language question: What problem does **Database migration as PreSync** solve here, and who notices first when it fails?
- Lesson evidence anchor: For the lab, we'll simulate migration rather than touching a real production database. apiVersion: batch/v1 kind: Job metadata: name: todo-db-migration namespace: todo-production annotations: argocd.argoproj.io/hook: PreSync
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Database migration as PreSync** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 019 - Backend deployment x privacy

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Backend deployment** while a change involving **Push it using GitOps** places **privacy** at risk.
- Plain-language question: What problem does **Backend deployment** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: apps/v1 kind: Deployment metadata: name: todo-backend namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "0" spec: replicas: 2 selector: matchLabels: app: todo-backend template: metadata: labels:
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Backend deployment** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 020 - Service x operability

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Service** while a change involving **Production sync options you should know** places **operability** at risk.
- Plain-language question: What problem does **Service** solve here, and who notices first when it fails?
- Lesson evidence anchor: apiVersion: v1 kind: Service metadata: name: todo-backend namespace: todo-production annotations: argocd.argoproj.io/sync-wave: "5" spec: selector: app: todo-backend ports: targetPort: 80 Now: PreSync migration ↓ Wave -10 Namespace
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Service** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 021 - PostSync smoke test x data integrity

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **PostSync smoke test** while a change involving **Never-forget memory map** places **data integrity** at risk.
- Plain-language question: What problem does **PostSync smoke test** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now our release test: apiVersion: batch/v1 kind: Job metadata: name: todo-smoke-test namespace: todo-production annotations: argocd.argoproj.io/hook: PostSync argocd.argoproj.io/sync-wave: "10" argocd.argoproj.io/hook-delete-policy: HookSucceeded
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PostSync smoke test** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 022 - Push it using GitOps x automation safety

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Push it using GitOps** while a change involving **SyncFail** places **automation safety** at risk.
- Plain-language question: What problem does **Push it using GitOps** solve here, and who notices first when it fails?
- Lesson evidence anchor: Remember the GitOps rule: Developer ↓ changes Git NOT Developer ↓ changes production cluster directly So: git status then: git add . Commit: git commit -m "add ordered Argo CD production deployment" Push: git push origin main
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Push it using GitOps** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 023 - Watch the deployment x governance

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Watch the deployment** while a change involving **Production example** places **governance** at risk.
- Plain-language question: What problem does **Watch the deployment** solve here, and who notices first when it fails?
- Lesson evidence anchor: CLI: argocd app get todo-production Watch: argocd app wait todo-production You can also inspect Kubernetes: kubectl get all -n todo-production Watch Jobs: kubectl get jobs -n todo-production -w Pods: kubectl get pods -n todo-production -w
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Watch the deployment** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 024 - What Argo CD is internally doing x correctness

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **What Argo CD is internally doing** while a change involving **PostSync smoke test** places **correctness** at risk.
- Plain-language question: What problem does **What Argo CD is internally doing** solve here, and who notices first when it fails?
- Lesson evidence anchor: Conceptually: Git changed │ ▼ Application Controller detects OutOfSync │ ▼ Construct sync plan │ ▼ Evaluate phases │ ▼ Evaluate waves │ ▼ PreSync │ ├── migration │ ▼ Sync │ ├── wave -10 ├── wave -5 ├── wave 0 └── wave 5 │
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **What Argo CD is internally doing** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 025 - Important: Healthy and Synced are NOT the same thing x capacity

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Important: Healthy and Synced are NOT the same thing** while a change involving **A common mistake** places **capacity** at risk.
- Plain-language question: What problem does **Important: Healthy and Synced are NOT the same thing** solve here, and who notices first when it fails?
- Lesson evidence anchor: This distinction is critical. Means: Git desired state = Cluster desired configuration Means roughly: Resources are functioning/reconciled as expected So you can have: SYNC STATUS: Synced HEALTH STATUS: Degraded For example:
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Important: Healthy and Synced are NOT the same thing** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 026 - What happens when migration fails? x cost efficiency

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **What happens when migration fails?** while a change involving **Interview questions from this lesson** places **cost efficiency** at risk.
- Plain-language question: What problem does **What happens when migration fails?** solve here, and who notices first when it fails?
- Lesson evidence anchor: Let's intentionally change: command: echo "Migration failed" exit 1 Commit: git add . git commit -m "test migration failure" git push Lifecycle: Argo CD │ ▼ PreSync │ ▼ Migration Job │ ▼ exit 1 │ ▼ FAILED │ X Backend NOT DEPLOYED
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **What happens when migration fails?** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 027 - Production design pattern x recovery

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Production design pattern** while a change involving **PostSync Hook** places **recovery** at risk.
- Plain-language question: What problem does **Production design pattern** solve here, and who notices first when it fails?
- Lesson evidence anchor: A more realistic enterprise application could use: Wave -100 CRDs Wave -90 Namespace Wave -80 ServiceAccounts / RBAC Wave -50 ConfigMaps Wave -40 Secrets / ExternalSecret definitions Wave -20 Database dependencies Wave 0
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production design pattern** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 028 - A common mistake x change management

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **A common mistake** while a change involving **Phase vs Wave — do not confuse them** places **change management** at risk.
- Plain-language question: What problem does **A common mistake** solve here, and who notices first when it fails?
- Lesson evidence anchor: Many beginners try: Deployment wave 0 Service wave 1 because they think: The Service cannot exist before the Pod. That's not generally necessary. Kubernetes Services can exist even when zero matching Pods currently exist.
- Objective: Preserve a measurable user or business outcome while making the change management decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **A common mistake** against an alternative while protecting change management under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 029 - Production sync options you should know x dependency failure

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Production sync options you should know** while a change involving **Service** places **dependency failure** at risk.
- Plain-language question: What problem does **Production sync options you should know** solve here, and who notices first when it fails?
- Lesson evidence anchor: Another related concept is: spec: syncPolicy: syncOptions: For example: syncPolicy: syncOptions: Argo CD currently supports sync options for behaviors including namespace creation, pruning controls, server-side apply, validation behavior and shared-resource...
- Objective: Preserve a measurable user or business outcome while making the dependency failure decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production sync options you should know** against an alternative while protecting dependency failure under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 030 - Very useful safety control — Prune confirmation x developer experience

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Very useful safety control — Prune confirmation** while a change involving **Production design pattern** places **developer experience** at risk.
- Plain-language question: What problem does **Very useful safety control — Prune confirmation** solve here, and who notices first when it fails?
- Lesson evidence anchor: Imagine Git accidentally removes: production namespace Auto-pruning could be dangerous. Argo CD supports: argocd.argoproj.io/sync-options: Prune=confirm which can require explicit confirmation before pruning critical resources. ([Argo CD][4])
- Objective: Preserve a measurable user or business outcome while making the developer experience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Very useful safety control — Prune confirmation** against an alternative while protecting developer experience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 031 - One major gotcha: selective sync x availability

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **One major gotcha: selective sync** while a change involving **Real enterprise architecture** places **availability** at risk.
- Plain-language question: What problem does **One major gotcha: selective sync** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose someone selects only: Deployment and runs selective sync. Do the hooks run? No. Argo CD's documentation explicitly notes that hooks do not run during selective sync operations. ([Argo CD][1]) This matters enormously.
- Objective: Preserve a measurable user or business outcome while making the availability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **One major gotcha: selective sync** against an alternative while protecting availability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 032 - Production troubleshooting x security

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Production troubleshooting** while a change involving **Why this is safer** places **security** at risk.
- Plain-language question: What problem does **Production troubleshooting** solve here, and who notices first when it fails?
- Lesson evidence anchor: If synchronization is stuck: argocd app get todo-production Check operations: argocd app history todo-production Check Pods: kubectl get pods -n todo-production Jobs: kubectl get jobs -n todo-production Describe failed migration:
- Objective: Preserve a measurable user or business outcome while making the security decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Production troubleshooting** against an alternative while protecting security under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 033 - Troubleshooting mental model x delivery safety

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Troubleshooting mental model** while a change involving **Negative waves** places **delivery safety** at risk.
- Plain-language question: What problem does **Troubleshooting mental model** solve here, and who notices first when it fails?
- Lesson evidence anchor: When deployment fails, ask: ↓ ↓ ↓ ↓ ↓ ↓ ↓ Don't randomly restart Argo CD. Follow the chain. ---
- Objective: Preserve a measurable user or business outcome while making the delivery safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Troubleshooting mental model** against an alternative while protecting delivery safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 034 - Real enterprise architecture x multi-tenancy

- Learning level: Certification review.
- Environment: a disposable local lab.
- Scenario: The team must apply **Real enterprise architecture** while a change involving **Backend deployment** places **multi-tenancy** at risk.
- Plain-language question: What problem does **Real enterprise architecture** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now place what we've learned into CI/CD: Developer │ ▼ GitHub Application Repository │ ▼ Jenkins / GitHub Actions │ ├── Unit Test ├── SAST ├── Build Docker Image ├── Scan Image └── Push ECR │ ▼ ECR │ CI updates: GitOps Repository
- Objective: Preserve a measurable user or business outcome while making the multi-tenancy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Real enterprise architecture** against an alternative while protecting multi-tenancy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 035 - Interview questions from this lesson x observability

- Learning level: Interview defense.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Interview questions from this lesson** while a change involving **What happens when migration fails?** places **observability** at risk.
- Plain-language question: What problem does **Interview questions from this lesson** solve here, and who notices first when it fails?
- Lesson evidence anchor: A mechanism for controlling the ordering of resources during Argo CD synchronization. Lower wave ↓ Higher wave --- A deployment lifecycle stage such as: PreSync Sync PostSync SyncFail --- Phase = WHEN Wave = ORDER --- Usually:
- Objective: Preserve a measurable user or business outcome while making the observability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Interview questions from this lesson** against an alternative while protecting observability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 036 - Never-forget memory map x regional resilience

- Learning level: Beginner.
- Environment: a disposable local lab.
- Scenario: The team must apply **Never-forget memory map** while a change involving **Troubleshooting mental model** places **regional resilience** at risk.
- Plain-language question: What problem does **Never-forget memory map** solve here, and who notices first when it fails?
- Lesson evidence anchor: Memorize this: ARGO CD RELEASE │ ▼ ┌──────────┐ │ PreSync  │ └────┬─────┘ │ DB Migration │ ▼ ┌──────────┐ │   Sync   │ └────┬─────┘ │ Sync Waves │ ┌────────────┼────────────┐ -10           0            10 │            │             │
- Objective: Preserve a measurable user or business outcome while making the regional resilience decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Never-forget memory map** against an alternative while protecting regional resilience under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 037 - The problem with deploying everything together x business value

- Learning level: Intermediate.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **The problem with deploying everything together** while a change involving **PreSync Hook** places **business value** at risk.
- Plain-language question: What problem does **The problem with deploying everything together** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose Git contains: production/ ├── namespace.yaml ├── configmap.yaml ├── secret.yaml ├── database-migration.yaml ├── deployment.yaml ├── service.yaml └── smoke-test.yaml You push: git push origin main Argo CD detects:
- Objective: Preserve a measurable user or business outcome while making the business value decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **The problem with deploying everything together** against an alternative while protecting business value under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 038 - Argo CD gives us two major ordering mechanisms x latency

- Learning level: Expert.
- Environment: a disposable local lab.
- Scenario: The team must apply **Argo CD gives us two major ordering mechanisms** while a change involving **Basic Sync Wave example** places **latency** at risk.
- Plain-language question: What problem does **Argo CD gives us two major ordering mechanisms** solve here, and who notices first when it fails?
- Lesson evidence anchor: Think of them like this: SYNC PHASE │ │  WHEN should something execute? ▼ SYNC WAVE │ │  In what ORDER inside that phase? ▼ So: Phase = stage Wave  = ordering within stage For example: PreSync ├── Wave -10 → validation └── Wave -5  → database migration
- Objective: Preserve a measurable user or business outcome while making the latency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Argo CD gives us two major ordering mechanisms** against an alternative while protecting latency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 039 - Sync Phases x privacy

- Learning level: Professional.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Sync Phases** while a change involving **Database migration as PreSync** places **privacy** at risk.
- Plain-language question: What problem does **Sync Phases** solve here, and who notices first when it fails?
- Lesson evidence anchor: Argo CD currently supports hooks such as: PreSync Sync PostSync SyncFail Skip PreDelete PostDelete PreSync executes before normal application manifests. PostSync executes after the sync has succeeded and resources are healthy, while SyncFail runs when synch...
- Objective: Preserve a measurable user or business outcome while making the privacy decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Sync Phases** against an alternative while protecting privacy under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 040 - PreSync Hook x operability

- Learning level: Industry-ready.
- Environment: a disposable local lab.
- Scenario: The team must apply **PreSync Hook** while a change involving **Important: Healthy and Synced are NOT the same thing** places **operability** at risk.
- Plain-language question: What problem does **PreSync Hook** solve here, and who notices first when it fails?
- Lesson evidence anchor: PreSync means: Do this before deploying the application. Common production use cases: Database migrations Schema checks Backup jobs Dependency validation Pre-deployment checks Maintenance preparation Example: apiVersion: batch/v1
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PreSync Hook** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 041 - Why this is safer x data integrity

- Learning level: Certification review.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Why this is safer** while a change involving **Production troubleshooting** places **data integrity** at risk.
- Plain-language question: What problem does **Why this is safer** solve here, and who notices first when it fails?
- Lesson evidence anchor: Without a hook: Migration ──────────────┐ │ simultaneous Backend Deployment ─────┤ │ Frontend ────────────────┘ Race condition. With PreSync: Migration │ │ SUCCESS ▼ Backend │ ▼ Frontend Deterministic deployment. ---
- Objective: Preserve a measurable user or business outcome while making the data integrity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Why this is safer** against an alternative while protecting data integrity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 042 - PostSync Hook x automation safety

- Learning level: Interview defense.
- Environment: a disposable local lab.
- Scenario: The team must apply **PostSync Hook** while a change involving **Sync Phases** places **automation safety** at risk.
- Plain-language question: What problem does **PostSync Hook** solve here, and who notices first when it fails?
- Lesson evidence anchor: Now suppose deployment completed. You don't immediately want to say: Deployment successful! You may first want to test: GET /health GET /ready Login API Database connectivity Critical API workflow That is where: PostSync
- Objective: Preserve a measurable user or business outcome while making the automation safety decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: make a sync hook, health check, canary analysis, or rollback condition fail safely.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **PostSync Hook** against an alternative while protecting automation safety under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 043 - SyncFail x governance

- Learning level: Beginner.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **SyncFail** while a change involving **Now comes Sync Waves** places **governance** at risk.
- Plain-language question: What problem does **SyncFail** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose deployment fails. For example: Deployment ↓ ImagePullBackOff ↓ Argo CD Sync Failed We may want some cleanup or failure action. Example: metadata: annotations: argocd.argoproj.io/hook: SyncFail Possible use: cleanup
- Objective: Preserve a measurable user or business outcome while making the governance decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: break repository authentication, manifest rendering, a required CRD, or destination selection.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **SyncFail** against an alternative while protecting governance under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 044 - Hook lifecycle problem x correctness

- Learning level: Intermediate.
- Environment: a disposable local lab.
- Scenario: The team must apply **Hook lifecycle problem** while a change involving **ConfigMap** places **correctness** at risk.
- Plain-language question: What problem does **Hook lifecycle problem** solve here, and who notices first when it fails?
- Lesson evidence anchor: There is another interesting problem. Imagine this Job: database-migration After it completes: kubectl get jobs might show: NAME                   COMPLETIONS database-migration     1/1 Next release comes: v2.5 Argo CD wants to create:
- Objective: Preserve a measurable user or business outcome while making the correctness decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Hook lifecycle problem** against an alternative while protecting correctness under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 045 - Hook Delete Policy x capacity

- Learning level: Expert.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Hook Delete Policy** while a change involving **What Argo CD is internally doing** places **capacity** at risk.
- Plain-language question: What problem does **Hook Delete Policy** solve here, and who notices first when it fails?
- Lesson evidence anchor: Example: metadata: annotations: argocd.argoproj.io/hook: PreSync argocd.argoproj.io/hook-delete-policy: HookSucceeded Important policies include: HookSucceeded HookFailed BeforeHookCreation HookSucceeded deletes the hook resource after successful completion...
- Objective: Preserve a measurable user or business outcome while making the capacity decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Hook Delete Policy** against an alternative while protecting capacity under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 046 - Now comes Sync Waves x cost efficiency

- Learning level: Professional.
- Environment: a disposable local lab.
- Scenario: The team must apply **Now comes Sync Waves** while a change involving **One major gotcha: selective sync** places **cost efficiency** at risk.
- Plain-language question: What problem does **Now comes Sync Waves** solve here, and who notices first when it fails?
- Lesson evidence anchor: Hooks answer: WHEN? But sometimes we need: WHICH RESOURCE FIRST? For example: Namespace ↓ ConfigMap ↓ Secret ↓ Deployment ↓ Service This is where we use: sync-wave Annotation: argocd.argoproj.io/sync-wave: "1" ---
- Objective: Preserve a measurable user or business outcome while making the cost efficiency decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Now comes Sync Waves** against an alternative while protecting cost efficiency under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

### Practice case 047 - Basic Sync Wave example x recovery

- Learning level: Industry-ready.
- Environment: a one-zone-loss exercise.
- Scenario: The team must apply **Basic Sync Wave example** while a change involving **Argo CD gives us two major ordering mechanisms** places **recovery** at risk.
- Plain-language question: What problem does **Basic Sync Wave example** solve here, and who notices first when it fails?
- Lesson evidence anchor: Suppose: metadata: name: backend-config annotations: argocd.argoproj.io/sync-wave: "0" Deployment: metadata: name: backend annotations: argocd.argoproj.io/sync-wave: "1" Service: metadata: name: backend-service annotations:
- Objective: Preserve a measurable user or business outcome while making the recovery decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Git promotion commit, pull-request review, sync result, and rollback record and link it to this practice case ID.
- Safe execution rule: use synthetic data, explicit placeholders, a disposable target, least privilege, and a written abort condition.
- Read-only first check: capture current version, configuration, health, recent changes, workload scope, and the exact user signal.
- Failure injection: remove one cluster, API server, repo-server, cache, or controller dependency.
- Expected observation: predict one user signal, one component signal, and one control-plane or change signal before running the test.
- Troubleshooting branch: write two competing hypotheses and the cheapest safe check that distinguishes them.
- Security check: test unauthorized access, unsafe input, secret exposure, excessive privilege, and audit evidence where relevant.
- Reliability check: test timeout, retry, partial success, duplicate work, degraded mode, and recovery within the stated objective.
- Performance and cost check: record demand, latency or queueing, capacity, amplification, paid resources, and one useful unit.
- Rollback or containment: identify the smallest reversible action, its authority, expected result, risk, and stop condition.
- Recovery proof: validate the original user journey, authoritative state, backlog, telemetry, desired-state convergence, and side effects.
- Evidence package: save sanitized configuration or command, query output, UTC timeline, decision, result, and unresolved risk.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Defend **Basic Sync Wave example** against an alternative while protecting recovery under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 47.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/ "Sync Phases and Waves - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/?utm_source=chatgpt.com "Automated Sync Policy - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/health/ "Resource Health - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/ "Sync Options - Argo CD - Declarative GitOps CD for Kubernetes"
