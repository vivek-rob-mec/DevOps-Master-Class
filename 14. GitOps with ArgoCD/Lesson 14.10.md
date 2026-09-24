# Module 14 — GitOps with Argo CD

## Lesson 10: App-of-Apps, Cluster Bootstrapping & GitOps Control-Plane Architecture

We now have:

```text
Application
    ↓
Kubernetes resources
```

and:

```text
ApplicationSet
    ↓
Applications
    ↓
Kubernetes resources
```

But a deeper question appears:

> **Who creates the AppProjects, ApplicationSets, cluster add-ons, platform Applications, and even Argo CD's own configuration?**

That is the **bootstrap problem**.

Current Argo CD guidance says there is no single mandatory cluster-bootstrap pattern, but for most typical modern cluster-bootstrap scenarios Argo recommends looking first at **ApplicationSet**, particularly the Cluster generator. App-of-Apps remains supported as an alternative, but Argo explicitly classifies it as an **admin-only** pattern. ([Argo CD][1])

---

# 14.1231 The bootstrap problem

Imagine a completely new EKS cluster.

Initially it contains approximately:

```text
Kubernetes
│
├── kube-system
└── basic cluster components
```

But Production needs:

```text
Argo CD

External Secrets
Ingress Controller
cert-manager
Prometheus
Loki agents
Policy engine
Network policies
ApplicationSets
AppProjects
Todo applications
Payments applications
...
```

How do we go from:

```text
EMPTY CLUSTER
```

to:

```text
FULLY GOVERNED GITOPS CLUSTER
```

without manually running 100 commands?

That transition is:

# **Cluster Bootstrapping**

---

# 14.1232 Bootstrap mental model

There is necessarily some first trusted action.

You cannot say:

```text
"Argo CD will install Argo CD"
```

when Argo CD does not yet exist.

Therefore:

```text
                    OUTSIDE GITOPS
                         │
                         ▼
                 INSTALL ARGO CD
                         │
                         ▼
                   BOOTSTRAP ROOT
                         │
                         ▼
                      GITOPS
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼

         AppProjects  ApplicationSets Platform Apps
             │           │            │
             └───────────┼────────────┘
                         ▼
                    Workloads
```

The goal is not:

```text
zero bootstrap.
```

The goal is:

> **Make the non-GitOps bootstrap step as small, repeatable, auditable, and recoverable as possible.**

---

# 14.1233 Bootstrap boundary

A practical production boundary is:

```text
Terraform / cluster provisioning
        │
        ▼
EKS cluster exists
        │
        ▼
install minimal Argo CD
        │
        ▼
create one bootstrap Application
        │
        ▼
everything else comes from Git
```

Think:

```text
IMPERATIVE BOOTSTRAP

should be

SMALL
```

and:

```text
DECLARATIVE GITOPS OWNERSHIP

should be

LARGE.
```

---

# 14.1234 What is App-of-Apps?

App-of-Apps is conceptually very simple:

```text
Parent Application
       │
       ▼
Git directory containing
Application manifests
       │
       ├── Application A
       ├── Application B
       ├── Application C
       └── Application D
```

The parent Application deploys Kubernetes objects whose:

```yaml
kind: Application
```

means those child Applications then deploy their own workloads.

Argo officially supports creating an Application whose rendered resources are other Argo Applications. ([Argo CD][2])

---

# 14.1235 App-of-Apps hierarchy

```text
ROOT APPLICATION
       │
       ├── Application: cert-manager
       │        │
       │        └── cert-manager resources
       │
       ├── Application: external-secrets
       │        │
       │        └── ESO resources
       │
       ├── Application: monitoring
       │        │
       │        └── Prometheus resources
       │
       └── Application: workloads
                │
                └── application resources
```

Parent manages:

```text
Application CRs
```

Children manage:

```text
actual platform/workload resources.
```

---

# 14.1236 App-of-Apps does not introduce another special CRD

The parent is simply:

```yaml
kind: Application
```

and its desired manifests happen to contain:

```yaml
kind: Application
```

objects.

So:

```text
Application
   │
   ▼
Application
   │
   ▼
Deployment
```

is entirely valid.

---

# 14.1237 Basic repository layout

Example:

```text
platform-gitops/
│
├── bootstrap/
│   ├── kustomization.yaml
│   │
│   ├── projects/
│   │   ├── platform.yaml
│   │   ├── workloads.yaml
│   │   └── security.yaml
│   │
│   ├── applications/
│   │   ├── external-secrets.yaml
│   │   ├── ingress.yaml
│   │   ├── monitoring.yaml
│   │   └── workloads.yaml
│   │
│   └── applicationsets/
│       ├── cluster-addons.yaml
│       └── workloads.yaml
│
├── platform/
└── workloads/
```

Bootstrap Git therefore describes:

```text
the GitOps control-plane structure itself.
```

---

# 14.1238 Root Application example

Create conceptually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: cluster-bootstrap
  namespace: argocd

spec:

  project: bootstrap

  source:

    repoURL: https://git.example.com/company/platform-gitops.git

    targetRevision: main

    path: bootstrap

  destination:

    server: https://kubernetes.default.svc

    namespace: argocd

  syncPolicy:

    automated:
      enabled: true
      prune: true
      selfHeal: true
      allowEmpty: false

    syncOptions:
      - PruneLast=true
```

This one Application becomes:

```text
entry point
into the GitOps hierarchy.
```

---

# 14.1239 Why the parent deploys into `argocd`

Its resources include:

```text
Application

ApplicationSet

AppProject
```

and these control-plane objects normally reside in the Argo CD control-plane namespace unless you have explicitly enabled the newer any-namespace models. Argo declarative setup supports managing Applications, Projects, settings, repository/cluster configuration, and related Argo resources declaratively. ([Argo CD][2])

This is very different from:

```text
Todo workload namespace
=
todo-prod.
```

---

# 14.1240 Root Application is extremely privileged

This is where App-of-Apps becomes dangerous.

Suppose parent Git contains:

```yaml
kind: Application

spec:
  project: platform-admin
  destination:
    namespace: argocd
```

A person able to modify that parent repository could potentially create child Applications across privileged Projects.

Argo therefore explicitly warns:

> App-of-Apps is an **admin-only** tool; only administrators should have push access to the parent Application repository, and reviewers must carefully inspect child `project` fields. ([Argo CD][1])

This is not an ordinary application repository.

---

# 14.1241 Why `project:` is so important

Child:

```yaml
spec:
  project: payments-prod
```

gets one capability set.

Another child:

```yaml
spec:
  project: platform
```

could have:

```text
cluster-scoped permissions
argocd namespace access
system namespace access
```

Therefore changing:

```diff
-project: workload
+project: platform
```

can be a security escalation.

App-of-Apps repository review must treat Project selection as security-sensitive. ([Argo CD][1])

---

# 14.1242 App-of-Apps vs ApplicationSet

They may appear similar:

```text
App-of-Apps
    ↓
Applications
```

and:

```text
ApplicationSet
    ↓
Applications
```

But their creation mechanisms differ dramatically.

---

# 14.1243 App-of-Apps model

You explicitly store child Application YAML:

```text
applications/
├── cert-manager.yaml
├── ingress.yaml
├── external-secrets.yaml
├── monitoring.yaml
└── todo.yaml
```

Parent renders:

```text
exact Application manifests.
```

Strength:

```text
explicit
easy to understand
each child can differ significantly
```

Weakness:

```text
repetition
manual child inventory
admin-level parent trust
```

---

# 14.1244 ApplicationSet model

You store:

```text
generator
+
template
+
structured inventory.
```

For example:

```text
clusters
or
Git directories
```

produce child Applications automatically.

Strength:

```text
scalable
dynamic
multi-cluster
less duplication
structured automation
```

Current Argo cluster-bootstrap guidance recommends ApplicationSet, especially Cluster generator-based patterns, for most typical cluster-bootstrap use cases. ([Argo CD][1])

---

# 14.1245 Decision table

| Requirement                                      | Prefer                           |
| ------------------------------------------------ | -------------------------------- |
| 5 very different child Applications              | App-of-Apps can be simple        |
| Hundreds of similarly structured Applications    | ApplicationSet                   |
| Deploy add-ons to every labeled cluster          | ApplicationSet Cluster Generator |
| Git directories should create apps automatically | ApplicationSet Git Generator     |
| Explicit hand-curated root child list            | App-of-Apps                      |
| Multi-cluster fleet                              | ApplicationSet                   |
| Dynamic cluster inventory                        | ApplicationSet                   |
| Existing legacy root-app structure               | App-of-Apps may remain valid     |

Current Argo does not prohibit App-of-Apps; it simply recommends ApplicationSet for many modern bootstrap scenarios. ([Argo CD][1])

---

# 14.1246 They can also coexist

A mature design may use:

```text
ROOT BOOTSTRAP APPLICATION
           │
           ├── AppProjects
           │
           ├── ApplicationSets
           │
           └── a few special Applications
```

Then ApplicationSets generate:

```text
hundreds of ordinary applications.
```

This is often cleaner than choosing:

```text
App-of-Apps OR ApplicationSet
```

as a religion.

---

# 14.1247 Recommended conceptual hierarchy

```text
                         BOOTSTRAP
                         Application
                             │
        ┌────────────────────┼─────────────────────┐
        ▼                    ▼                     ▼

    AppProjects        ApplicationSets       Special Apps
        │                    │                     │
        │                    ▼                     │
        │               Applications               │
        │                    │                     │
        └────────────────────┼─────────────────────┘
                             ▼
                        Kubernetes
```

This gives:

```text
Bootstrap
=
static control-plane root

ApplicationSet
=
scalable child generation.
```

---

# 14.1248 Platform repository structure

A stronger production repository:

```text
platform-gitops/
│
├── bootstrap/
│   │
│   ├── kustomization.yaml
│   │
│   ├── projects/
│   ├── applicationsets/
│   └── applications/
│
├── argocd/
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
│
├── platform/
│   ├── ingress-nginx/
│   ├── external-secrets/
│   ├── cert-manager/
│   ├── monitoring/
│   └── policy-engine/
│
├── workloads/
│
└── clusters/
    ├── prod-mumbai/
    ├── prod-singapore/
    └── dev-mumbai/
```

Each directory has a specific ownership role.

---

# 14.1249 Bootstrap repository should NOT become company-everything

Avoid:

```text
bootstrap/
├── 500 application Deployments
├── 400 ConfigMaps
├── application code
├── database SQL
├── Terraform
└── secrets
```

Bootstrap should primarily establish:

```text
control-plane declarations
and
application ownership hierarchy.
```

The deeper workload configuration can live in separate paths/repos.

---

# 14.1250 Root Application should remain boring

A good root Application might rarely change.

Its job is:

```text
discover/apply Projects

discover/apply ApplicationSets

discover/apply a few platform Applications.
```

Not:

```text
contain every environment variable
for every microservice.
```

High privilege + low change frequency is a good combination.

---

# 14.1251 Bootstrap with Kustomize

Example:

```yaml
# bootstrap/kustomization.yaml

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:

  - projects/platform.yaml
  - projects/todo-dev.yaml
  - projects/todo-prod.yaml

  - applicationsets/todo.yaml
  - applicationsets/cluster-addons.yaml

  - applications/argocd-self.yaml
```

Now root Application only needs:

```text
path: bootstrap
```

Kustomize composes the control-plane resource set.

---

# 14.1252 Ordering problem

Suppose bootstrap contains:

```text
AppProject/todo-prod
```

and:

```text
ApplicationSet/todo
```

which immediately generates:

```text
Application
project: todo-prod
```

What happens if:

```text
ApplicationSet is reconciled
before AppProject exists?
```

Temporary failures are possible.

This introduces:

# dependency ordering.

---

# 14.1253 Bootstrap dependency layers

A sensible logical sequence:

```text
Wave -20
Namespaces / critical prerequisites

Wave -10
AppProjects

Wave 0
ApplicationSets

Wave 10
Platform Applications

Wave 20
Workload Applications
```

We'll go much deeper into Argo:

```text
hooks
+
sync waves
```

in Lesson 12.

For now, remember:

> **Declarative does not mean dependency-free.**

---

# 14.1254 CRD ordering is particularly important

Imagine installing:

```text
External Secrets Operator CRDs
```

and simultaneously applying:

```yaml
kind: ExternalSecret
```

If Kubernetes sees the custom resource before its CRD exists:

```text
unknown resource kind.
```

Therefore:

```text
CRD provider
must exist
before CR instance.
```

This is a common platform-bootstrap dependency.

---

# 14.1255 Platform dependency chain example

```text
Argo
 │
 ▼
AppProject
 │
 ▼
External Secrets Operator
 │
 ▼
ExternalSecret CRD
 │
 ▼
ExternalSecret resources
 │
 ▼
Kubernetes Secret
 │
 ▼
Todo Deployment
```

That's not merely:

```text
"deploy all YAML."
```

There is a real dependency graph.

---

# 14.1256 App-of-Apps does not automatically solve dependency ordering

Parent creates:

```text
Application A

Application B

Application C
```

but the existence of:

```text
A before B
```

inside a YAML directory isn't a sufficient production dependency model.

You still need mechanisms such as:

```text
sync waves

separate bootstrap stages

health gating

Progressive Syncs

application dependencies expressed through architecture.
```

---

# 14.1257 ApplicationSet also doesn't magically solve all ordering

ApplicationSet's job is:

```text
generate Applications.
```

It does not inherently understand:

```text
cert-manager must exist
before Certificate resource.
```

ApplicationSet Progressive Syncs can order groups of generated Applications when enabled, but that feature is a separate mechanism and is currently Beta in the stable docs. ([Argo CD][3])

We learned that in Lesson 9.

---

# 14.1258 Bootstrap anti-pattern: one root with unlimited power and broad write access

Imagine:

```text
company-root-gitops
```

has:

```text
Project admin powers
```

and:

```text
all 500 developers can merge.
```

That's equivalent to handing broad deployment authority to hundreds of people.

Because App-of-Apps can create Applications in privileged Projects, Argo warns the parent repo should be admin-controlled. ([Argo CD][1])

---

# 14.1259 Better ownership

```text
bootstrap/
       │
       └── Platform CODEOWNERS

applicationsets/
       │
       └── Platform CODEOWNERS

projects/
       │
       └── Platform/Security CODEOWNERS

workloads/todo/
       │
       └── Todo Team

workloads/payments/
       │
       └── Payments Team
```

Git permissions should mirror privilege.

---

# 14.1260 GitOps control-plane tiers

Think:

## Tier 0

```text
Argo installation
Argo CRDs
Argo RBAC
SSO
repository credentials
cluster credentials
```

## Tier 1

```text
AppProjects
ApplicationSets
bootstrap/root Applications
```

## Tier 2

```text
cluster add-ons
Ingress
Secrets operators
policy engines
monitoring
```

## Tier 3

```text
application workloads
```

Higher tier:

```text
greater blast radius
stronger review.
```

---

# 14.1261 Who installs Argo CD initially?

Current official installation options include:

```text
Argo installation manifests

Kustomize

Helm
```

with the official docs describing standard manifests and Kustomize, while noting the Helm chart is community-maintained. Argo provides separate HA manifests for production-style high-availability deployment. ([Argo CD][4])

So our bootstrap might be:

```text
Terraform
   │
   ▼
EKS
   │
   ▼
kubectl/Kustomize/Helm
   │
   ▼
Argo installed
```

then GitOps takes over.

---

# 14.1262 Terraform vs Argo ownership boundary

Excellent production rule:

```text
Terraform

owns:
EKS
VPC
IAM
node infrastructure
load balancers where infra-managed
DNS foundation
cloud prerequisites
```

while:

```text
Argo

owns:
Kubernetes applications
cluster add-ons
workload manifests
GitOps policies
```

Do not let Terraform and Argo simultaneously own:

```text
same Deployment
same ConfigMap
same Namespace
```

without a deliberate lifecycle design.

---

# 14.1263 Bootstrap paradox

We want Argo to own:

```text
Argo configuration.
```

But initially Argo is installed manually/external tooling.

This creates a handoff:

```text
PHASE 1

bootstrap tool creates Argo
```

then:

```text
PHASE 2

Argo adopts its declarative configuration
```

That handoff must be explicit.

---

# 14.1264 Can Argo CD manage itself?

Yes.

Current Argo documentation explicitly supports:

# **Argo CD managing Argo CD.**

Because Argo settings and installation resources are represented as Kubernetes manifests, the docs recommend a Kustomize-based self-managed model that references Argo installation manifests and applies organizational customizations on top. ([Argo CD][2])

Architecture:

```text
Argo CD
   │
   ▼
Git:
argocd/
   │
   ▼
Argo Application:
argocd
   │
   ▼
Argo CD resources
```

That's recursive—but valid.

---

# 14.1265 Self-management mental model

Argo is already running as:

```text
version A.
```

Git says:

```text
Argo should run version B
with these settings.
```

Application:

```text
argocd
```

renders:

```text
Deployments
StatefulSets
ConfigMaps
RBAC
Services
CRDs
...
```

Argo then reconciles its own installation.

---

# 14.1266 Self-management is powerful

Benefits:

```text
Argo configuration versioned

RBAC reviewed in Git

SSO config reviewed

resource sizing reviewed

upgrade history visible

disaster recovery easier to reason about
```

But there is an obvious downside:

```text
bad Argo Git change
can break Argo itself.
```

So self-management is a high-blast-radius GitOps pattern.

---

# 14.1267 Current self-management requirement: Server-Side Apply

This is a very current detail.

The stable Argo declarative-setup documentation says that when Argo manages itself, the self-managed Application must enable:

```yaml
syncOptions:
  - ServerSideApply=true
```

and the current upgrade guidance reinforces SSA for self-managed Argo upgrades because of CRD/application-set field ownership and annotation-size concerns in modern versions. ([Argo CD][2])

So your self-managed Application should include:

```yaml
syncPolicy:

  syncOptions:
    - ServerSideApply=true
```

Do not blindly copy old self-management tutorials that omit this.

---

# 14.1268 Self-managed Argo Application concept

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: argocd
  namespace: argocd

spec:

  project: platform

  source:

    repoURL: https://git.example.com/company/platform-gitops.git

    targetRevision: main

    path: argocd/overlays/prod

  destination:

    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:

    automated:
      enabled: true
      prune: true
      selfHeal: true

    syncOptions:
      - ServerSideApply=true
      - PruneLast=true
```

This is conceptually aligned with current self-management guidance. ([Argo CD][2])

---

# 14.1269 Pin Argo versions deliberately

A self-managed base such as:

```text
... ?ref=stable
```

may be convenient for examples.

For carefully controlled Production, think about whether you want:

```text
moving stable branch
```

or:

```text
specific approved release.
```

The general immutable-dependency principle we learned earlier applies strongly to your **GitOps controller itself**.

A controller upgrade should be:

```text
reviewed
tested
explicit.
```

---

# 14.1270 Do not auto-upgrade Argo blindly

Bad:

```text
Argo installation source:
always latest/stable moving head
```

plus:

```text
auto-sync
```

without release validation.

Now upstream movement may effectively become:

```text
Production control-plane upgrade.
```

Prefer:

```text
approved Argo version
→ test
→ stage
→ prod.
```

---

# 14.1271 Self-management upgrade flow

A safer model:

```text
New Argo release
      │
      ▼
Review changelog / upgrade docs
      │
      ▼
Test cluster
      │
      ▼
NonProd Argo
      │
      ▼
validate Applications
      │
      ▼
Production PR
      │
      ▼
Argo upgrades itself
```

Because Argo is the deployment control plane, controller upgrades deserve stronger testing than an ordinary app version bump.

---

# 14.1272 What if Argo breaks while upgrading itself?

Existing workloads normally continue running because Argo sits in the control plane rather than the application request path.

But:

```text
new reconciliations

drift correction

Git updates

Application operations
```

can stop or degrade until Argo recovers.

Therefore:

```text
Argo outage
≠
immediate workload outage
```

but it is still a major:

```text
deployment/control-plane incident.
```

---

# 14.1273 Argo high availability

Current Argo CD documentation provides HA manifests. Argo is largely stateless in the sense that its persistent configuration/state is stored as Kubernetes objects in the cluster's Kubernetes datastore; Redis is used as a rebuildable cache rather than the authoritative persistent store. The HA deployment runs additional replicas/components and Redis in HA mode. ([Argo CD][5])

Permanent distinction:

```text
Argo HA
=
keep GitOps control plane available
```

not:

```text
application HA.
```

---

# 14.1274 Argo persistence mental model

Important current architecture:

```text
Git
=
desired application configuration

Kubernetes API / etcd
=
Argo CRs, ConfigMaps, Secrets, configuration

Redis
=
cache
```

The official HA documentation explicitly says Redis is disposable/rebuildable and isn't the authoritative durable store. ([Argo CD][5])

That becomes important for disaster recovery.

---

# 14.1275 What Argo control-plane data matters?

Examples:

```text
Applications

ApplicationSets

AppProjects

argocd-cm

argocd-rbac-cm

repository credentials

cluster credentials

SSO configuration

TLS/SSH trust configuration
```

Many of these can and should be represented declaratively where practical. Argo's declarative setup supports applications, projects, settings, repository credentials, cluster credentials, and certificate/trust configuration through Kubernetes resources. ([Argo CD][2])

---

# 14.1276 Git is not the only thing to recover

A common mistake:

> "Everything is GitOps, so Git is the backup."

Not necessarily.

Git might contain:

```text
Application manifests
AppProjects
RBAC configuration
```

but production Argo may also contain runtime/control-plane Secrets for:

```text
private repositories
cluster credentials
webhook secrets
OIDC client secrets
```

depending on how you've integrated secret management.

Recovery design must identify **all** of these.

---

# 14.1277 Argo disaster recovery tooling

Current stable Argo documentation provides:

```text
argocd admin export
```

and:

```text
argocd admin import
```

for exporting/importing Argo CD data for disaster-recovery purposes. ([Argo CD][6])

Conceptually:

```text
Argo Kubernetes state
       │
       ▼
argocd admin export
       │
       ▼
backup.yaml
```

and recovery:

```text
new/recovered Argo
       │
       ▼
argocd admin import
       │
       ▼
restored Argo resources/config
```

---

# 14.1278 Backup is not a DR plan

You still need:

```text
Where is backup stored?

Is it encrypted?

Can we access it during account/cluster outage?

Who can restore?

Which Argo version should restore it?

How quickly can we rebuild EKS?

How do Git/repository credentials recover?

How do cluster credentials recover?

Have we actually tested restoration?
```

Same lesson as AWS DR:

```text
BACKUP
≠
RECOVERY PROOF.
```

---

# 14.1279 DR test

A proper Argo control-plane DR exercise:

```text
1. Provision recovery cluster.

2. Install approved Argo version.

3. Restore/recreate Argo configuration.

4. Restore Git/repository access.

5. Restore/register target cluster credentials.

6. Recreate bootstrap root.

7. Verify AppProjects.

8. Verify ApplicationSets.

9. Verify generated Applications.

10. Verify Git rendering.

11. Verify diff.

12. Perform controlled sync.

13. Confirm workloads remain correct.
```

The official export/import facility gives you a tool; your organization still needs the actual recovery procedure. ([Argo CD][6])

---

# 14.1280 What if the Argo cluster itself is destroyed?

There are two broad architectures.

### Architecture A — Argo lives in workload cluster

```text
EKS Prod
│
├── Argo
├── Todo
├── Payments
└── Platform
```

Cluster destroyed:

```text
Argo
+
workloads
```

are both lost.

---

# 14.1281 Architecture B — central management Argo

```text
Management Cluster
       │
       └── Argo CD
             │
      ┌──────┼───────┐
      ▼      ▼       ▼

    Dev    Stage    Prod
```

Now workload-cluster loss may leave Argo itself alive.

Argo supports adding external clusters using:

```text
argocd cluster add
```

and stores the relevant external cluster connection configuration/credentials in Argo's control-plane namespace. ([Argo CD][7])

Both architectures have tradeoffs.

---

# 14.1282 Central Argo advantages

```text
one control plane

central visibility

standard RBAC

shared SSO

easy fleet ApplicationSets

workload-cluster failure
doesn't necessarily destroy Argo.
```

---

# 14.1283 Central Argo disadvantages

```text
large blast radius

cross-cluster network dependency

central credential concentration

shared platform outage affects
many deployment targets

tenant isolation complexity.
```

No architecture is free.

---

# 14.1284 Per-cluster Argo advantages

```text
strong failure isolation

simpler destination networking

cluster-local ownership

one Argo outage
affects fewer clusters.
```

---

# 14.1285 Per-cluster Argo disadvantages

```text
many Argo installations

many upgrades

many SSO/RBAC configs

more monitoring

harder fleet visibility.
```

ApplicationSet and platform automation can mitigate some of that operational overhead.

---

# 14.1286 Hybrid model

Large organizations often consider:

```text
Argo instance per
environment/security domain/region
```

rather than:

```text
one Argo for entire company
```

or:

```text
one Argo per every cluster.
```

For example:

```text
NonProd Argo

Prod Argo

Security/Platform Argo
```

This reduces blast radius without multiplying installations infinitely.

---

# 14.1287 Control-plane blast radius

Ask:

```text
If this Argo instance is compromised,
which clusters can attacker modify?
```

and:

```text
If this Argo instance fails,
which teams lose deployment capability?
```

Those questions determine the correct Argo tenancy boundary better than:

```text
"centralized is cleaner."
```

---

# 14.1288 Argo cluster credentials

For externally managed clusters, current Argo security docs state that cluster connection data is stored as Kubernetes Secrets in the Argo namespace; depending on configuration this can include bearer-token connection information, TLS settings/certificates, or cloud-role information. ([Argo CD][8])

Therefore:

```text
argocd namespace Secrets
```

are crown-jewel infrastructure data.

---

# 14.1289 Argo does not need unrestricted write everywhere

Current Argo security guidance explicitly notes that Argo requires broad read visibility to reconcile managed clusters, but does **not necessarily require unrestricted write permissions**. Its cluster write privileges can be narrowed to the namespaces/resources Argo should manage. ([Argo CD][8])

This reinforces Lesson 8:

```text
AppProject
+
Kubernetes RBAC
=
defense in depth.
```

---

# 14.1290 Bootstrap security chain

A production bootstrap change may flow:

```text
Platform Engineer
       │
       ▼
Bootstrap PR
       │
       ▼
CODEOWNERS
       │
       ▼
Policy checks
       │
       ▼
Merge
       │
       ▼
Root Application
       │
       ▼
AppProject / ApplicationSet
       │
       ▼
Applications
       │
       ▼
Kubernetes
```

This is one of the highest-privilege change paths in the entire platform.

---

# 14.1291 Bootstrap repo compromise

If attacker can modify:

```text
root Application source
```

they may attempt to create:

```text
new AppProjects

new Applications

new ApplicationSets

privileged platform resources.
```

Therefore protect bootstrap Git like:

```text
cloud root/control-plane infrastructure.
```

Strong controls:

```text
MFA

branch protection

CODEOWNERS

limited writers

signed/verified workflows where appropriate

audit

secret scanning

policy validation.
```

---

# 14.1292 Don't template privileged Project names from untrusted metadata

From Lesson 9:

```text
ApplicationSet
+
untrusted input
```

must not dynamically choose:

```text
admin-level AppProject.
```

Bootstrap templates should normally hardcode privileged control boundaries.

For example:

```yaml
project: todo-preview
```

not:

```yaml
project: '{{.requestedProject}}'
```

from PR-controlled input.

---

# 14.1293 Control-plane application example

We may eventually have:

```text
Application:
argocd
```

which owns:

```text
Argo installation.
```

Then:

```text
Application:
bootstrap
```

which owns:

```text
Projects/ApplicationSets.
```

Then:

```text
ApplicationSet:
cluster-addons
```

which owns:

```text
addon Applications.
```

Hierarchy:

```text
Argo
 │
 ▼
argocd Application
 │
 ▼
Argo itself


Argo
 │
 ▼
bootstrap Application
 │
 ├── Projects
 └── ApplicationSets
          │
          ▼
       Applications
          │
          ▼
       workloads
```

Yes, it is recursive.

But each ownership layer has a clear purpose.

---

# 14.1294 Avoid circular ownership

Bad:

```text
Application A
creates ApplicationSet B

ApplicationSet B
generates Application A
```

Now:

```text
who is authoritative?
```

Avoid circular control graphs.

Prefer:

```text
ROOT
  ↓
CHILD
  ↓
GRANDCHILD
```

not:

```text
A ↔ B.
```

---

# 14.1295 One object, one authoritative parent

Same principle repeated throughout our course:

```text
Terraform resource
→ one state owner

Kubernetes field
→ one controller owner

Argo Application
→ one ApplicationSet/root owner
```

Do not have:

```text
App-of-Apps root
```

and:

```text
ApplicationSet
```

both trying to manage the same:

```text
Application/todo-prod.
```

Controller warfare will follow.

---

# 14.1296 Platform bootstrap sequence

A clean end-to-end cluster sequence:

```text
PHASE 0
Cloud Infrastructure

VPC
EKS
IAM
DNS
KMS
```

then:

```text
PHASE 1
GitOps Engine

Install Argo CD
```

then:

```text
PHASE 2
GitOps Control Plane

AppProjects
Repositories/credentials
ApplicationSets
RBAC/SSO
```

then:

```text
PHASE 3
Core Platform

Ingress
Secrets
Policy
Observability
DNS integrations
```

then:

```text
PHASE 4
Workloads

Todo
Payments
Orders
...
```

---

# 14.1297 Why platform services precede apps

Todo may depend on:

```text
Ingress controller

External Secrets

cert-manager

observability

policy CRDs.
```

So deploying Todo before these exist might produce:

```text
Pending

Missing CRD

Secret not found

Ingress ineffective

admission rejection.
```

Bootstrap must respect service dependencies.

---

# 14.1298 Platform readiness vs resource existence

Don't say:

```text
External Secrets Deployment exists
=
ready.
```

You may need:

```text
controller Pods Ready

CRDs established

webhook ready

cloud IAM configured

Secrets Manager reachable.
```

Only then should dependent workloads assume the platform service is operational.

This is why:

```text
health-aware ordering
```

matters.

---

# 14.1299 Bootstrap validation

After root sync:

```bash
argocd app get cluster-bootstrap
```

Then inspect children:

```bash
argocd app list
```

Then:

```bash
kubectl get appprojects -n argocd
```

and:

```bash
kubectl get applicationsets -n argocd
```

Then:

```bash
kubectl get applications -n argocd
```

You should be able to walk:

```text
Root
→ Projects
→ ApplicationSets
→ Applications
→ Workloads.
```

---

# 14.1300 Resource tree thinking

A bootstrapped platform might conceptually look like:

```text
cluster-bootstrap
│
├── AppProject/platform
├── AppProject/todo-dev
├── AppProject/todo-prod
│
├── ApplicationSet/cluster-addons
│      │
│      ├── Application/external-secrets-prod
│      ├── Application/monitoring-prod
│      └── Application/policy-prod
│
└── ApplicationSet/todo
       │
       ├── Application/todo-dev
       ├── Application/todo-stage
       └── Application/todo-prod
```

Then each child has its own Kubernetes resource tree.

---

# 14.1301 Troubleshooting bootstrap — use the parent chain

Don't start at the Pod.

Use:

# **B → P → S → A → R → D → H**

```text
B
BOOTSTRAP ROOT


P
PROJECTS


S
APPLICATIONSET


A
APPLICATION


R
RENDER


D
DEPLOY/SYNC


H
HEALTH
```

If no Application exists:

```text
don't inspect the application's Pods.
```

---

# 14.1302 Problem: child Application missing

Check:

```text
Did bootstrap render it?

Was ApplicationSet created?

Does generator produce it?

Was Project available?

Is ApplicationSet healthy?

Did Git source load?
```

Use:

```bash
argocd app manifests cluster-bootstrap
```

then:

```bash
kubectl get applicationsets -n argocd
```

then inspect the generator.

---

# 14.1303 Problem: Application exists but InvalidSpec

Likely:

```text
AppProject missing

source repo not allowed

destination not allowed

bad path

bad cluster.
```

Now Bootstrap worked.

Child definition failed.

Different layer.

---

# 14.1304 Problem: root Application OutOfSync forever

Use:

```bash
argocd app diff cluster-bootstrap
```

Check whether:

```text
controller-generated fields

ApplicationSet mutations

Project fields

external controllers
```

are causing drift.

Do not automatically ignore differences.

Understand ownership first.

---

# 14.1305 Problem: deleting child causes it to return

Parent still declares:

```text
Application/todo-prod.
```

You delete:

```bash
kubectl delete application todo-prod -n argocd
```

Root/ApplicationSet says:

```text
desired child exists.
```

It recreates it.

Correct behavior.

Fix the parent desired state.

---

# 14.1306 Problem: deleted bootstrap path destroys children

With prune enabled:

```text
Git removes child Application
       │
       ▼
root sees extraneous Application
       │
       ▼
prune
       │
       ▼
Application deletion
       │
       ▼
possibly workload deletion
```

This is why:

```text
bootstrap deletions
```

deserve extremely strong review.

---

# 14.1307 App-of-Apps deletion chain

Potential chain:

```text
Delete child YAML from root Git
          │
          ▼
Parent prune
          │
          ▼
Application deleted
          │
          ▼
Application finalizer
          │
          ▼
Workload deleted
```

Very similar to ApplicationSet deletion, but the parent mechanism differs.

---

# 14.1308 Application deletion modes

Argo supports deleting an Application with or without cascading into its managed resources. Current docs expose both cascade and non-cascade deletion modes. ([Argo CD][9])

Concept:

```text
CASCADE

Application deleted
      +
managed resources deleted
```

versus:

```text
NON-CASCADE

Application deleted
but
managed resources remain.
```

Never choose by habit.

Choose by lifecycle intent.

---

# 14.1309 "Preserve" can create unmanaged infrastructure

Non-cascade deletion sounds safe:

```text
keep resources.
```

But afterward:

```text
who reconciles them?
```

If no Application adopts them:

```text
they drift.
```

Therefore:

```text
preserving resources
```

is sometimes correct during migration.

It is not automatically correct during decommission.

---

# 14.1310 Migrating App-of-Apps → ApplicationSet

Suppose legacy structure:

```text
root
│
├── todo-dev Application
├── todo-stage Application
└── todo-prod Application
```

We want ApplicationSet to generate them.

Danger:

```text
both controllers temporarily own
same Application names.
```

Migration plan:

```text
1. Inventory child specs.

2. Reproduce them exactly
   with ApplicationSet dry-run.

3. Validate names/projects/sources/destinations.

4. Establish ownership transition.

5. Remove old root ownership carefully.

6. Ensure ApplicationSet adopts/manages intended children.

7. Verify no workload recreation/deletion.

8. Test one nonprod child first.
```

Avoid giant one-step migration.

---

# 14.1311 Bootstrap Git should have policy tests

A PR changing:

```text
AppProject
```

should trigger tests such as:

```text
Did sourceRepos become "*"?

Did destination become "*"?

Was argocd namespace added?

Was kube-system added?

Did clusterResourceWhitelist become */*?

Did ApplicationSet generated count spike?

Will Applications be deleted?

Did auto-prune become enabled globally?
```

This is **policy-as-code for GitOps itself**.

---

# 14.1312 Production bootstrap CI

```text
Bootstrap PR
     │
     ▼
YAML validation
     │
     ▼
Kustomize render
     │
     ▼
ApplicationSet dry-run
     │
     ▼
generated app diff
     │
     ▼
Project policy validation
     │
     ▼
security checks
     │
     ▼
CODEOWNERS
     │
     ▼
merge
```

That is far safer than:

```text
merge
→ hope.
```

---

# 14.1313 Drift in control-plane resources

Suppose engineer manually edits:

```text
AppProject/todo-prod
```

to allow:

```text
namespace: "*"
```

Root Git still says:

```text
todo-prod only.
```

With self-heal:

```text
Argo detects drift
      │
      ▼
restores AppProject.
```

That is GitOps protecting its own policy plane.

---

# 14.1314 Self-healing governance is powerful

A malicious/manual change to:

```text
RBAC

AppProject

ApplicationSet
```

can be restored by the root controller.

But remember:

```text
if attacker compromises Git,
GitOps faithfully deploys
the malicious desired state.
```

Therefore Git security remains foundational.

---

# 14.1315 Control-plane Git is a crown jewel

Application Git compromise:

```text
one service
may be affected.
```

Bootstrap Git compromise:

```text
many Projects

many ApplicationSets

many clusters

possibly Argo itself
```

may be affected.

Treat repository access accordingly.

---

# 14.1316 What should Terraform own in the Argo bootstrap?

Possible minimal external bootstrap:

```text
EKS

Argo namespace

Argo initial installation

initial repository/auth bootstrap
```

Then GitOps owns the rest.

Another organization may let Terraform also manage:

```text
Argo Helm release
```

permanently.

That is also viable.

The critical rule:

```text
Choose one authoritative lifecycle owner
for the Argo installation.
```

---

# 14.1317 Two valid Argo installation ownership models

### Model A — Terraform owns Argo package

```text
Terraform
    │
    ▼
Argo installation/version
```

Argo owns:

```text
Projects
Applications
ApplicationSets
workloads.
```

Advantages:

```text
clear infra/platform separation
Argo cannot break its own installer path
```

---

# 14.1318 Model B — bootstrap then self-managed

```text
Terraform/kubectl
     │
     ▼
first Argo install
     │
     ▼
Argo self-management Application
     │
     ▼
future Argo config/upgrades.
```

Advantages:

```text
more Kubernetes control plane
fully declarative in GitOps.
```

Tradeoff:

```text
self-referential failure mode.
```

Both can be production-grade.

---

# 14.1319 Never dual-own Argo

Bad:

```text
Terraform:
Argo Deployment replicas=2
```

while:

```text
Argo self Application:
Argo Deployment replicas=3.
```

Result:

```text
Terraform apply
2

Argo self-heal
3

Terraform apply
2

Argo self-heal
3
```

Controller warfare.

One resource:

# **one authoritative owner.**

---

# 14.1320 Bootstrap recovery from zero

Imagine catastrophic management-cluster loss.

You should be able to reconstruct the platform from:

```text
Infrastructure IaC

+

approved Argo installation version

+

GitOps bootstrap repo

+

secret/credential recovery

+

Argo backup where required.
```

Ideal flow:

```text
Terraform
   │
   ▼
New EKS management cluster
   │
   ▼
Install Argo
   │
   ▼
restore/recreate credentials
   │
   ▼
create root/bootstrap Application
   │
   ▼
Projects/ApplicationSets recreated
   │
   ▼
Applications recreated
   │
   ▼
reconcile managed clusters
```

Current Argo's `argocd admin export/import` capability can complement this declarative reconstruction strategy where an export is part of your backup design. ([Argo CD][6])

---

# 14.1321 GitOps DR mental model

Do not think:

```text
"Restore Argo Pod."
```

Think:

```text
RESTORE CONTROL PLANE CAPABILITY

=
Argo binaries
+
Argo configuration
+
credentials
+
Git access
+
cluster access
+
bootstrap hierarchy.
```

A Pod is disposable.

The management capability is what matters.

---

# 14.1322 Redis loss

Current Argo HA docs classify Redis as a disposable cache that can be rebuilt rather than the system's authoritative persistent store. ([Argo CD][5])

Therefore:

```text
Redis lost
```

is very different from:

```text
Kubernetes API datastore / Argo config lost.
```

Don't design Argo DR as though Redis were your primary database.

---

# 14.1323 Git outage

Existing Kubernetes workloads keep running.

Argo repo-server cannot properly refresh desired state from unavailable repositories, so:

```text
new deployments

Git refresh

normal reconciliation
```

are affected. The repo-server is the component responsible for cloning/updating repositories and generating manifests. ([Argo CD][10])

Architecture:

```text
Git unavailable
      │
      X
repo-server
      │
      ▼
no fresh desired render
```

---

# 14.1324 Kubernetes API outage

Application controller requires Kubernetes API access to compare live state and perform reconciliation. ([Argo CD][11])

So:

```text
Git available
Argo Pods running
Kubernetes API unavailable
```

still means:

```text
reconciliation impaired.
```

GitOps has dependencies.

---

# 14.1325 Repo-server outage

Application manifests cannot be freshly generated from Git/Helm/Kustomize sources because repo-server is responsible for repository cache and manifest generation. ([Argo CD][10])

Existing workloads:

```text
continue.
```

New render/reconciliation operations:

```text
degrade.
```

---

# 14.1326 Application controller outage

The Application Controller is the component continuously comparing live state against desired Git state and driving reconciliation. ([Argo CD][11])

Controller down:

```text
Git changes may not deploy

self-heal stops

prune stops

status may become stale.
```

Existing workloads continue under Kubernetes controllers.

---

# 14.1327 API server outage

`argocd-server` exposes the API consumed by:

```text
Web UI

CLI

API clients.
```

Its outage can break interactive/API operations while other controllers may still continue their independent reconciliation functions. ([Argo CD][12])

This is why component-level troubleshooting matters.

---

# 14.1328 Control-plane failure matrix

| Failure             | Existing workload traffic         | New Git deployment                           | Self-heal                                   | UI/CLI                  |
| ------------------- | --------------------------------- | -------------------------------------------- | ------------------------------------------- | ----------------------- |
| Git unavailable     | Usually continues                 | Affected                                     | Fresh desired-state reconciliation affected | UI may show repo errors |
| repo-server down    | Continues                         | Affected                                     | Rendering-dependent operations affected     | Partial                 |
| app-controller down | Continues                         | Affected                                     | Stops                                       | UI may remain reachable |
| argocd-server down  | Continues                         | Controllers may continue                     | Controllers may continue                    | Fails                   |
| Kubernetes API down | Runtime impact depends on cluster | Fails                                        | Fails                                       | Operations impaired     |
| Redis loss          | Runtime continues                 | Cache rebuild/temporary control-plane impact | Recoverable cache                           | Temporary impact        |

Argo's component architecture and HA docs support these control-plane distinctions. ([Argo CD][5])

---

# 14.1329 Production bootstrap design for our Todo platform

Let's connect everything we've learned.

```text
                         AWS / Terraform
                              │
                              ▼
                         EKS CLUSTER
                              │
                              ▼
                     INITIAL ARGO INSTALL
                              │
                              ▼
                       ROOT APPLICATION
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼

        APPPROJECTS      APPLICATIONSETS     ARGO SELF
            │                 │                 │
            │                 │                 └── Argo config
            │                 │
            │         ┌───────┴────────┐
            │         ▼                ▼
            │   cluster-addons      todo-apps
            │         │                │
            │         ▼                ▼

            │   External Secrets   todo-dev
            │   Monitoring         todo-stage
            │   Ingress            todo-prod
            │   Policy
            │
            └───────────────────────────────────┐
                                                ▼
                                           Kubernetes
```

This is now a complete GitOps control hierarchy.

---

# 14.1330 Multi-region extension

Management plane:

```text
Argo
 │
 └── ApplicationSet
       │
       ├── prod-mumbai
       └── prod-singapore
```

Cluster add-ons:

```text
ApplicationSet
 │
 ├── monitoring-mumbai
 ├── monitoring-singapore
 ├── external-secrets-mumbai
 └── external-secrets-singapore
```

Workloads:

```text
todo-prod-mumbai

todo-prod-singapore
```

The same ApplicationSet cluster-generation concepts from Lesson 9 scale naturally into our Mumbai/Singapore DR architecture.

---

# 14.1331 DR isolation rule

Do not make Singapore DR require:

```text
a platform component
that exists only in Mumbai.
```

If Singapore must serve independently during regional failover, it needs region-local equivalents of required Kubernetes/platform components such as:

```text
Ingress

Secrets integration

policy dependencies

monitoring agents

runtime configuration.
```

GitOps should encode that parity.

---

# 14.1332 Bootstrap parity

Mumbai cluster metadata:

```text
environment=prod
region=ap-south-1
baseline=production
```

Singapore:

```text
environment=prod
region=ap-southeast-1
baseline=production
```

ApplicationSet can ensure both receive:

```text
production baseline add-ons.
```

Then workload overlays may intentionally differ:

```text
Mumbai:
active capacity

Singapore:
warm capacity.
```

---

# 14.1333 Don't confuse control-plane DR with application DR

Argo DR asks:

```text
Can we restore deployment/reconciliation capability?
```

Application DR asks:

```text
Can customers continue using the service?
```

Your application may fail over:

```text
Mumbai → Singapore
```

even if Argo is temporarily unavailable.

Likewise Argo may be perfectly healthy while your production database is down.

Different systems.

---

# 14.1334 App-of-Apps interview question

### What is the App-of-Apps pattern?

Strong answer:

> **It is an Argo CD bootstrap pattern where a parent `Application` deploys manifests that themselves define other Argo `Application` resources, creating a hierarchy of Applications. It is useful for declaratively bootstrapping groups of applications, but Argo explicitly treats App-of-Apps as an admin-level pattern because the parent repository can create child Applications in privileged Projects.** ([Argo CD][1])

---

# 14.1335 Interview — App-of-Apps vs ApplicationSet

Strong answer:

> **App-of-Apps explicitly stores child Application manifests and is useful for smaller or heterogeneous curated application trees. ApplicationSet generates Applications from structured inventories such as Git directories and registered clusters, making it more scalable for multi-environment and multi-cluster use. Current Argo cluster-bootstrap guidance recommends ApplicationSet, especially the Cluster generator, for most typical bootstrap scenarios.** ([Argo CD][1])

---

# 14.1336 Interview — Can they coexist?

Yes.

Strong architecture:

```text
Root Application
      │
      ├── AppProjects
      ├── ApplicationSets
      └── special Applications
```

Then:

```text
ApplicationSets
→ ordinary workload Applications.
```

The parent is the bootstrap root.

ApplicationSet is the fleet generator.

---

# 14.1337 Interview — why is App-of-Apps admin-only?

Because parent Git can contain arbitrary `Application` objects and those child specs select:

```text
Projects

Git repositories

clusters

namespaces.
```

Argo explicitly warns that creating Applications in arbitrary Projects is admin-level capability and the parent repository must be admin-controlled. ([Argo CD][1])

---

# 14.1338 Interview — Can Argo manage itself?

Yes.

Current Argo documentation explicitly supports self-management and recommends a Kustomize-based model over Argo installation manifests. Modern self-managed Argo must use `ServerSideApply=true` for current upgrade/application behavior. ([Argo CD][2])

---

# 14.1339 Interview — bootstrap paradox

Answer:

> **Some external mechanism must create the first functional Argo installation. After that minimal trusted bootstrap, a self-managed Application can take ownership of future Argo configuration/upgrades, or an external tool such as Terraform can remain the authoritative owner. The important rule is to avoid dual ownership.**

Excellent senior answer.

---

# 14.1340 Interview — should Terraform or Argo install Argo?

There is no universal answer.

Use:

```text
Terraform-owned Argo
```

when you want:

```text
infrastructure tool
to remain authoritative
for GitOps platform installation.
```

Use:

```text
self-managed Argo
```

when you intentionally want:

```text
Argo's own Kubernetes configuration
under GitOps lifecycle.
```

Never let both own the same fields/resources.

---

# 14.1341 Interview — what does `argocd admin export` do?

Current stable Argo DR tooling supports exporting Argo CD data with:

```text
argocd admin export
```

and restoring through the corresponding import workflow. ([Argo CD][6])

Senior addition:

> **I would still test full recovery because an export alone does not prove Git access, cluster connectivity, external secret recovery, or infrastructure reconstruction.**

---

# 14.1342 Interview — is Redis the Argo database?

No.

Current Argo HA documentation says durable Argo state/configuration is represented in Kubernetes resources backed by the Kubernetes data store, while Redis serves as a disposable cache. ([Argo CD][5])

So:

```text
Redis
≠
authoritative Argo database.
```

---

# 14.1343 Interview — what survives Argo outage?

Generally:

```text
already-running Kubernetes workloads
```

continue under Kubernetes controllers.

What you lose/degrade is:

```text
deployment reconciliation
drift correction
Git-driven changes
Argo control-plane interaction.
```

Argo components operate in the delivery/control plane, while Kubernetes continues managing existing resources. ([Argo CD][11])

---

# 14.1344 Interview — central Argo vs per-cluster Argo

Strong answer:

> **Central Argo simplifies visibility, SSO/RBAC, ApplicationSet fleet operations, and management, but increases credential concentration and control-plane blast radius. Per-cluster Argo gives stronger failure isolation and local ownership but multiplies installation, upgrade, monitoring, and policy overhead. I choose the boundary according to security domain, operational ownership, and acceptable blast radius.**

---

# 14.1345 Interview — why minimize bootstrap?

Because bootstrap often uses:

```text
privileged external credentials
```

before normal GitOps guardrails exist.

The less imperative/bootstrap code you have:

```text
the smaller the recovery
and audit surface.
```

After the root Application exists:

```text
Git
```

should become the normal authoritative control plane.

---

# 14.1346 Interview trap — App-of-Apps is the current preferred bootstrap pattern

Not exactly.

It remains supported, but current Argo cluster-bootstrap documentation recommends ApplicationSets, particularly Cluster generator patterns, for typical scenarios and presents App-of-Apps as an alternative. ([Argo CD][1])

This differs from older Argo tutorials where App-of-Apps was often presented as the primary answer.

---

# 14.1347 Interview trap — parent Application is safe for ordinary team write access

Wrong.

Argo explicitly calls App-of-Apps admin-only. ([Argo CD][1])

---

# 14.1348 Interview trap — self-managed Argo requires no special sync configuration

Wrong for current versions.

Current docs require:

```text
ServerSideApply=true
```

when managing/upgrading Argo through an Argo Application. ([Argo CD][2])

---

# 14.1349 Interview trap — Redis loss means restore Argo database backup

Wrong.

Redis is used as a disposable cache in Argo's architecture. ([Argo CD][5])

---

# 14.1350 Interview trap — Git backup alone guarantees Argo recovery

Wrong.

You may additionally need:

```text
Argo installation

repository credentials

cluster connection credentials

SSO configuration

external secret recovery

Kubernetes infrastructure

Argo runtime configuration.
```

Git is central, but your actual recovery dependencies must be inventoried.

---

# 14.1351 Interview trap — deleting parent only deletes parent

Potentially very wrong.

Depending on:

```text
pruning

owner references

Application finalizers

cascade settings
```

parent deletion or removal can cascade through Applications into workloads. Argo supports cascading and non-cascading Application deletion, and ApplicationSet similarly has explicit child/resource lifecycle semantics. ([Argo CD][9])

---

# 14.1352 Interview trap — if parent creates Applications, creation order guarantees application readiness

Wrong.

```text
resource created
```

is not:

```text
application healthy.
```

Dependency ordering and health gates need explicit design.

---

# 14.1353 Interview trap — declarative means no bootstrap

Wrong.

There is always some trust root:

```text
cluster creation

Argo initial installation

initial source trust.
```

The engineering objective is:

```text
small bootstrap
+
large declarative ownership.
```

---

# 14.1354 Interview trap — Argo should always own itself

Not universally.

Self-management is officially supported. ([Argo CD][2])

But:

```text
Terraform-owned installation
```

can also be a clean ownership model.

The wrong design is:

```text
Terraform
and
Argo
fight over same Argo resources.
```

---

# 14.1355 Production bootstrap checklist

Before calling the GitOps bootstrap production-ready:

```text
□ Initial Argo installation is repeatable

□ Approved Argo version is pinned

□ Root/bootstrap Application is declarative

□ Parent repository has platform-only write controls

□ CODEOWNERS protects Projects/ApplicationSets

□ default AppProject is not relied upon broadly

□ AppProjects exist before workload generation

□ ApplicationSet dry-run is validated

□ generated Application deletions are surfaced

□ cluster-add-on dependencies are understood

□ CRD ownership is explicit

□ secrets are not plaintext in bootstrap Git

□ repository credentials have a recovery path

□ cluster credentials have a recovery path

□ Argo RBAC/SSO configuration is versioned appropriately

□ self-management uses ServerSideApply where applicable

□ Argo installation has one lifecycle owner

□ bootstrap deletion behavior is documented

□ Application cascade behavior is understood

□ Argo backups/recovery have been tested

□ Git outage procedure exists

□ management-cluster recovery procedure exists

□ DR cluster can obtain required platform add-ons independently
```

---

# 14.1356 Never-forget Lesson 10 rules

```text
1.

Every GitOps platform
has a bootstrap root.


2.

Keep imperative bootstrap small.


3.

App-of-Apps
=
Application creates Applications.


4.

ApplicationSet
=
generator creates Applications.


5.

Current Argo guidance favors
ApplicationSet for typical
cluster-bootstrap use cases.


6.

App-of-Apps remains supported
as an alternative.


7.

App-of-Apps is admin-only.


8.

Parent Git repository
is highly privileged.


9.

Project selection inside
child Applications
is security-sensitive.


10.

App-of-Apps and ApplicationSet
can coexist.


11.

Root Application should be boring.


12.

Projects generally precede
Applications using them.


13.

CRDs precede
custom resources.


14.

Declarative systems still
have dependency ordering.


15.

Argo can manage itself.


16.

Modern self-management needs
ServerSideApply=true.


17.

Pin Argo versions deliberately.


18.

Don't blindly track moving upstream
for control-plane upgrades.


19.

One resource
=
one lifecycle owner.


20.

Terraform + Argo dual ownership
creates controller warfare.


21.

Argo HA
!=
application HA.


22.

Argo's persistent configuration
lives in Kubernetes objects.


23.

Redis is a cache,
not the durable Argo database.


24.

argocd admin export/import
supports DR workflows.


25.

Backup
!=
tested recovery.


26.

Existing workloads can keep running
during many Argo component failures.


27.

Git, repo-server,
application-controller,
API server and Kubernetes API
are different failure layers.


28.

Central Argo increases
control-plane blast radius.


29.

Per-cluster Argo increases
operational overhead.


30.

Choose Argo tenancy by
security and failure boundaries.


31.

External cluster credentials
are crown-jewel data.


32.

Argo does not inherently need
unrestricted write everywhere.


33.

Bootstrap Git deserves
stronger protection than
ordinary application Git.


34.

Deleting parent declarations
can cascade into workloads.


35.

Preserving resources
can create unmanaged resources.


36.

Recovery needs
Git + credentials + cluster access
+ Argo installation.


37.

GitOps control-plane DR
and application DR
are different concerns.


38.

A good platform can be rebuilt
from IaC + Git + secret recovery.


39.

Avoid circular ownership graphs.


40.

ROOT → CHILD → WORKLOAD
is easier to reason about
than controllers owning one another.
```

---

# 14.1357 Lesson 10 master architecture

```text
                         CLOUD IaC
                            │
                            ▼
                       EKS CLUSTER
                            │
                            ▼
                    MINIMAL ARGO INSTALL
                            │
                            ▼
                      BOOTSTRAP ROOT
                            │
             ┌──────────────┼───────────────┐
             ▼              ▼               ▼

         AppProjects   ApplicationSets    Argo Self-App
             │              │               │
             │        ┌─────┴─────┐         │
             │        ▼           ▼         │
             │     Platform     Workload     │
             │      Apps       Applications  │
             │        │           │          │
             └────────┼───────────┼──────────┘
                      ▼           ▼
                  Kubernetes Resources
```

At multi-cluster scale:

```text
                        ARGO MANAGEMENT
                              │
                              ▼
                        ApplicationSet
                              │
                  ┌───────────┴───────────┐
                  ▼                       ▼

             Mumbai Prod             Singapore Prod
                  │                       │
                  ▼                       ▼

             Platform Apps             Platform Apps
                  │                       │
                  ▼                       ▼

             Todo / Payments           DR Workloads
```

---

# 14.1358 Lesson 10 troubleshooting mnemonic

Remember:

# **I → B → P → G → A → R → S → H**

```text
I
INSTALL

Is Argo itself running?


B
BOOTSTRAP

Is root Application healthy?


P
PROJECT

Does required AppProject exist
and permit the child?


G
GENERATOR

Did ApplicationSet generate it?


A
APPLICATION

Does child spec look correct?


R
RENDER

Can Git/Helm/Kustomize generate manifests?


S
SYNC

Can Argo apply them?


H
HEALTH

Does the workload/platform component work?
```

This gives us an end-to-end troubleshooting hierarchy from:

```text
GitOps platform
```

down to:

```text
Pod runtime.
```

---

# ✅ Module 14 — Lesson 10 Complete

At this point, you can reason about the entire GitOps ownership hierarchy:

```text
Cloud IaC
   │
   ▼
Kubernetes
   │
   ▼
Argo installation
   │
   ▼
Bootstrap Application
   │
   ├── AppProjects
   ├── ApplicationSets
   └── special Applications
            │
            ▼
        Applications
            │
            ▼
        Helm/Kustomize
            │
            ▼
     Kubernetes resources
            │
            ▼
     Kubernetes controllers
            │
            ▼
           Pods
```

That means we've gone from:

```text
"Argo deploys YAML"
```

to understanding:

```text
how an enterprise GitOps control plane
can bootstrap itself,
secure itself,
scale itself,
upgrade itself,
and be recovered after failure.
```

# Next — Module 14, Lesson 11

## Secrets Management with Argo CD — External Secrets, AWS Secrets Manager, Sealed Secrets & Vault

Next we'll solve one of the most important remaining GitOps problems:

> **If Git is the source of truth, where do database passwords, API tokens, private keys, registry credentials, and production secrets live?**

Architecture:

```text
                         GIT
                          │
                          ▼
                    ExternalSecret
                          │
                          ▼
               External Secrets Operator
                          │
                          ▼
                 AWS Secrets Manager
                          │
                          ▼
                   Kubernetes Secret
                          │
                          ▼
                     Application
```

We'll cover **why base64 is not security, native Kubernetes Secrets, External Secrets Operator, SecretStore vs ClusterSecretStore, AWS Secrets Manager, IAM/IRSA or Pod Identity architecture, secret refresh/rotation, Vault integration, Sealed Secrets, SOPS-style approaches conceptually, Git leakage and history, bootstrap secrets, Argo repository credentials, secret ownership, multi-account AWS access, secret rotation without redeploying everything, DR secrets, and real production failure/troubleshooting scenarios.**

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/?utm_source=chatgpt.com "Cluster Bootstrapping - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Controlling-Resource-Modification/?utm_source=chatgpt.com "Controlling Resource Modification - Argo CD - Read the Docs"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/?utm_source=chatgpt.com "Installation - Argo CD - Declarative GitOps CD for Kubernetes"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/?utm_source=chatgpt.com "Overview - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/?utm_source=chatgpt.com "Disaster Recovery - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-management/?utm_source=chatgpt.com "Cluster Management - Argo CD - Declarative GitOps CD for ..."
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/?utm_source=chatgpt.com "Security - Argo CD - Read the Docs"
[9]: https://argo-cd.readthedocs.io/en/latest/user-guide/app_deletion/?utm_source=chatgpt.com "App Deletion - Argo CD - Declarative GitOps CD for Kubernetes"
[10]: https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-repo-server/?utm_source=chatgpt.com "argocd-repo-server Command Reference - Argo CD"
[11]: https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-application-controller/?utm_source=chatgpt.com "argocd-application-controller Command Reference - Argo CD"
[12]: https://argo-cd.readthedocs.io/en/stable/operator-manual/server-commands/argocd-server/?utm_source=chatgpt.com "argocd-server Command Reference - Argo CD - Read the Docs"
