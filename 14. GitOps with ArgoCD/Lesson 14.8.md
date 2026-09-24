# Module 14 — GitOps with Argo CD

## Lesson 8: AppProject, RBAC, SSO & Multi-Team Isolation

We now have enough GitOps knowledge to expose a dangerous question.

Imagine one Argo CD installation manages:

```text
Payments Dev
Payments Prod
Todo Dev
Todo Prod
Observability
Ingress
cert-manager
Security tooling
Platform services
```

And 100 engineers can log in.

If every engineer can deploy:

```yaml
kind: ClusterRole
```

from:

```text
any Git repository
```

to:

```text
any cluster
any namespace
```

then we have built a very efficient privilege-escalation platform.

That is exactly the problem `AppProject`, Argo RBAC, SSO groups, and Kubernetes RBAC are meant to solve. Current Argo CD Projects can restrict source repositories, destination clusters/namespaces, resource kinds, and project-level application access. ([Argo CD][1])

---

# 14.967 The four authorization layers

Keep this architecture permanently:

```text
                    HUMAN / CI
                        │
                        ▼
                ┌──────────────┐
                │ Identity/SSO │
                └──────┬───────┘
                       │
                    WHO ARE YOU?
                       │
                       ▼
                 ┌──────────┐
                 │ Argo RBAC│
                 └────┬─────┘
                      │
              WHAT MAY YOU DO?
                      │
                      ▼
                ┌────────────┐
                │ AppProject │
                └─────┬──────┘
                      │
       WHAT MAY THIS APPLICATION DEPLOY?
                      │
                      ▼
              ┌────────────────┐
              │ Kubernetes RBAC│
              │ + Admission    │
              └───────┬────────┘
                      │
             WILL CLUSTER ACCEPT?
                      │
                      ▼
                  Kubernetes
```

These controls protect different boundaries.

---

# 14.968 Authentication vs authorization

Authentication answers:

```text
WHO ARE YOU?
```

For example:

```text
Vivek
Todo Developer
Platform Engineer
SRE
CI automation
```

Authorization answers:

```text
WHAT MAY YOU DO?
```

For example:

```text
view todo-dev

sync todo-dev

view todo-prod

sync todo-prod

modify AppProjects

register clusters

modify repositories
```

Argo CD supports SSO either through its bundled Dex component or directly against an existing OIDC provider; groups/claims from the identity provider can then participate in Argo RBAC. ([Argo CD][2])

---

# 14.969 AppProject vs Argo RBAC

This distinction is extremely important.

Suppose a developer asks:

> Can I click **SYNC** on `todo-prod`?

That is mainly:

```text
ARGO RBAC
```

But suppose the application itself says:

```yaml
source:
  repoURL: attacker.example/malicious.git

destination:
  namespace: kube-system
```

The question:

> Is this Application configuration itself allowed?

is:

```text
AppProject
```

So:

```text
RBAC
=
USER → ARGO OPERATION


AppProject
=
APPLICATION → DEPLOYMENT BOUNDARY
```

---

# 14.970 What does an AppProject actually protect?

Current Argo CD Projects provide four major security boundaries:

```text
Trusted source repositories

Destination clusters

Destination namespaces

Allowed/denied Kubernetes resource kinds
```

They can also contain project roles and Sync Windows. ([Argo CD][1])

Think:

```text
AppProject
=
deployment sandbox
```

for a team/application group.

---

# 14.971 Our current `default` Project is dangerous for production

Remember our guestbook Application:

```yaml
spec:
  project: default
```

Argo automatically creates:

```text
default
```

and by default it allows:

```text
sourceRepos:
*

destinations:
*

clusterResourceWhitelist:
*/*
```

meaning essentially any repository, destination, and resource kind. Argo's current documentation explicitly describes the default Project as the most permissive project and recommends dedicated Projects for real environments. ([Argo CD][1])

So:

```text
default
=
good learning project

not
=
good enterprise security boundary.
```

---

# 14.972 Build our first restricted AppProject

Let's improve the guestbook lab first.

Create:

```bash
cd ~/argocd-labs/lesson-3
nano guestbook-project.yaml
```

Use:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: guestbook-lab
  namespace: argocd

spec:

  description: Restricted project for Guestbook lab

  sourceRepos:

    - https://github.com/argoproj/argocd-example-apps.git

  destinations:

    - server: https://kubernetes.default.svc
      namespace: guestbook

  clusterResourceWhitelist:

    - group: ""
      kind: Namespace
      name: guestbook
```

Current AppProjects support source restrictions, destination restrictions, and even name-level restrictions for certain cluster-scoped resources such as Namespaces. ([Argo CD][1])

---

# 14.973 Read this Project as English

It says:

```text
Applications in guestbook-lab

MAY read manifests from:

argoproj/argocd-example-apps


MAY deploy to:

this cluster


MAY deploy namespaced resources into:

guestbook


MAY create cluster-scoped:

Namespace/guestbook


Everything else cluster-scoped:
not granted.
```

This is much more interesting than:

```yaml
"*"
```

everywhere.

---

# 14.974 Apply the Project

```bash
kubectl apply -f guestbook-project.yaml
```

Then:

```bash
kubectl get appprojects -n argocd
```

You should see:

```text
default

guestbook-lab
```

Inspect:

```bash
kubectl get appproject guestbook-lab \
  -n argocd \
  -o yaml
```

---

# 14.975 Move guestbook into the Project

Our current Application still says:

```yaml
project: default
```

Patch it:

```bash
kubectl patch application guestbook \
  -n argocd \
  --type merge \
  -p '{
    "spec": {
      "project": "guestbook-lab"
    }
  }'
```

Then:

```bash
argocd app get guestbook
```

You should now see:

```text
Project:
guestbook-lab
```

Current Argo CD allows an Application to be reassigned to another Project, assuming the operation itself is authorized. ([Argo CD][1])

---

# 14.976 Update your local Application YAML too

Change:

```yaml
spec:
  project: default
```

to:

```yaml
spec:
  project: guestbook-lab
```

This avoids our usual anti-pattern:

```text
Live configuration
!=
declarative configuration.
```

---

# 14.977 Test that the normal deployment still works

Run:

```bash
argocd app get guestbook --refresh
```

Then:

```bash
argocd app sync guestbook
```

And:

```bash
argocd app wait guestbook \
  --sync \
  --health
```

The Application should continue working because:

```text
Repo                  ✓ allowed

Cluster               ✓ allowed

Namespace             ✓ allowed

Deployment            ✓ namespaced

Service               ✓ namespaced
```

while `CreateNamespace=true` can use the explicitly permitted `guestbook` Namespace resource.

---

# 14.978 Now imagine an attack

Developer modifies the Application to:

```yaml
destination:

  server: https://kubernetes.default.svc

  namespace: kube-system
```

Application still belongs to:

```text
guestbook-lab.
```

The Project only allows:

```text
guestbook
```

Therefore Argo's Project policy rejects that destination instead of treating the Application specification as universally trusted. Destination allow and deny rules are enforced by AppProjects. ([Argo CD][1])

Architecture:

```text
Application
     │
     ▼
"Deploy to kube-system"
     │
     ▼
AppProject
     │
     X
DENIED
```

---

# 14.979 This is why Git access alone is not enough

Suppose someone manages to alter:

```text
guestbook Git
```

and adds:

```yaml
kind: ClusterRole
```

If our AppProject only permits:

```text
Namespace/guestbook
```

as a cluster-scoped kind/name, that new `ClusterRole` does not become permitted simply because it appeared in Git. Argo Projects use an allow-list model for cluster-scoped resources, while namespaced resources can be constrained with allow/deny rules as well. ([Argo CD][1])

So:

```text
Git trust
+
Project restriction
```

is stronger than Git trust alone.

---

# 14.980 Why cluster-scoped resources are especially dangerous

Consider:

```text
ClusterRole

ClusterRoleBinding

CustomResourceDefinition

Namespace

StorageClass

ClusterIssuer
```

These are not confined to:

```text
todo-prod
```

the way an ordinary namespaced Deployment is.

A compromised application allowed to create powerful cluster-scoped RBAC objects may escape its intended namespace boundary.

That is why production AppProjects should treat cluster-scoped permissions very carefully.

---

# 14.981 Namespaced resources also require thought

Even inside one namespace, powerful resources may exist.

For example:

```text
Role

RoleBinding

Secret

NetworkPolicy

ResourceQuota
```

Current AppProject specifications support both namespace-resource allowlists and blacklists. ([Argo CD][3])

For some teams:

```text
Deployment
Service
ConfigMap
HPA
PDB
```

may be self-service.

But:

```text
Role
RoleBinding
```

may remain platform-owned.

That's an architectural choice.

---

# 14.982 Example production Todo Project

Conceptually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: todo-prod
  namespace: argocd

spec:

  description: Todo production workloads

  sourceRepos:

    - https://git.example.com/company/todo-gitops.git

  destinations:

    - server: https://prod-cluster.example.com
      namespace: todo-prod

  clusterResourceWhitelist:

    - group: ""
      kind: Namespace
      name: todo-prod

  namespaceResourceBlacklist:

    - group: rbac.authorization.k8s.io
      kind: Role

    - group: rbac.authorization.k8s.io
      kind: RoleBinding
```

This communicates:

```text
Todo application team:

may deploy Todo workload config

may not invent arbitrary
namespaced RBAC roles.
```

AppProject resource-kind restrictions are explicitly designed for this sort of multi-team control. ([Argo CD][1])

---

# 14.983 Project source repository allowlist

Suppose:

```yaml
sourceRepos:

  - https://git.example.com/company/todo-gitops.git
```

Developer changes Application to:

```yaml
repoURL:
  https://evil.example.com/rootkit.git
```

Project decision:

```text
Is repo on approved source list?

NO

        ↓

Application rejected
```

Argo Projects support both positive repository rules and explicit negated repository patterns. A repository is valid only when an allow rule matches and no matching deny rule rejects it. ([Argo CD][1])

---

# 14.984 Source negation

For example:

```yaml
sourceRepos:

  - "https://git.example.com/company/**"

  - "!https://git.example.com/company/experimental/**"
```

means conceptually:

```text
company/*
=
generally allowed


company/experimental/*
=
explicitly denied.
```

Argo supports negated source rules beginning with `!`. ([Argo CD][1])

---

# 14.985 Destination negation

Likewise:

```yaml
destinations:

  - namespace: "!kube-system"
    server: "*"

  - namespace: "*"
    server: "*"
```

conceptually means:

```text
any namespace
EXCEPT
kube-system.
```

Argo evaluates destination rules using the same basic idea: an allowed rule must match and no matching deny rule may reject the destination. ([Argo CD][1])

---

# 14.986 But explicit positive allowlists are often easier to reason about

Compare:

```text
anything except kube-system
```

with:

```text
only todo-prod.
```

For a dedicated Todo Production Project, the second model has a much smaller blast radius.

Security principle:

```text
Production least privilege

usually prefers:

known allowed destinations
```

over:

```text
everything except
the things we remembered to deny.
```

---

# 14.987 Important AppProject limitation: transitive repositories

Here's a senior-level security nuance.

Suppose the Project allows only:

```text
company/todo-gitops
```

but that trusted repo contains a Kustomize remote base:

```text
https://unknown.example.com/base.git
```

or a Helm dependency from another repository.

Argo's security documentation warns that the repository allowlist applies to the **initial repository Argo clones**, while Helm dependencies and Kustomize remote bases may reference additional repositories beyond that initial allowlist. ([Argo CD][4])

Therefore:

```text
AppProject sourceRepos
≠
complete transitive dependency firewall.
```

---

# 14.988 Never-forget dependency trust

Security review must include:

```text
Git repository
       │
       ▼
Helm dependencies
       │
       ▼
Kustomize remote bases
       │
       ▼
Config-management plugins
```

because a trusted repository can pull additional configuration into its rendered manifests. ([Argo CD][4])

This directly connects to our Helm/Kustomize lessons.

---

# 14.989 Now move to Argo RBAC

AppProject says:

```text
todo-prod is allowed
to deploy from X to Y.
```

But we still need to answer:

```text
Who can SEE todo-prod?

Who can SYNC it?

Who can MODIFY it?

Who can DELETE it?

Who can access logs?

Who can exec into Pods?

Who can administer Projects?
```

That's:

# Argo RBAC.

---

# 14.990 Argo's built-in roles

Current Argo CD has two built-in roles:

```text
role:readonly

role:admin
```

`role:readonly` has read-only access across Argo resources, while `role:admin` is unrestricted. The built-in `admin` user itself is a superuser. ([Argo CD][5])

This means:

```text
role:readonly
```

may still be broader than what you want in a strict multi-tenant enterprise.

---

# 14.991 Avoid this production mistake

```yaml
policy.default: role:readonly
```

looks harmless.

But that means every authenticated user gets the default role's permissions.

Even more importantly, current Argo documentation warns that permissions granted by `policy.default` cannot later be removed by a subject-specific `deny`. Argo therefore recommends making the default authenticated role as minimal as possible and granting additional permissions through explicit roles. ([Argo CD][5])

This is an extremely important rule.

---

# 14.992 Think of `policy.default` as the floor

If:

```text
policy.default
=
read everything
```

then:

```text
specific deny
```

cannot reduce that floor in the way many engineers expect.

Therefore design:

```text
DEFAULT
=
almost nothing
```

and then add:

```text
team-specific privileges.
```

---

# 14.993 RBAC policy syntax

Argo uses a Casbin-based policy structure.

Permission rule:

```text
p, SUBJECT, RESOURCE, ACTION, OBJECT, EFFECT
```

For example:

```text
p, role:todo-dev, applications, get, todo-dev/*, allow
```

Current Argo RBAC syntax uses exactly those policy elements, with `allow` or `deny` as effects. ([Argo CD][5])

Read that as:

```text
ROLE:
todo-dev

RESOURCE:
applications

ACTION:
get

OBJECT:
all applications in todo-dev project

EFFECT:
allow
```

---

# 14.994 Group mapping syntax

Role binding:

```text
g, USER_OR_GROUP, ROLE
```

Example:

```text
g, argocd-todo-developers, role:todo-dev
```

means:

```text
SSO group
argocd-todo-developers

        ↓

Argo role
role:todo-dev
```

Argo RBAC consumes user/group information from configured SSO claims/scopes and can bind those identities to roles. ([Argo CD][5])

---

# 14.995 Example global RBAC design

Conceptual `argocd-rbac-cm`:

```yaml
apiVersion: v1
kind: ConfigMap

metadata:
  name: argocd-rbac-cm
  namespace: argocd

data:

  policy.default: role:authenticated

  scopes: '[groups, email]'

  policy.csv: |

    p, role:authenticated, projects, get, *, allow


    p, role:todo-dev, applications, get, todo-dev/*, allow
    p, role:todo-dev, applications, sync, todo-dev/*, allow
    p, role:todo-dev, logs, get, todo-dev/*, allow

    g, argocd-todo-developers, role:todo-dev


    p, role:todo-prod-readonly, applications, get, todo-prod/*, allow
    p, role:todo-prod-readonly, logs, get, todo-prod/*, allow

    g, argocd-todo-developers, role:todo-prod-readonly


    p, role:todo-prod-operator, applications, get, todo-prod/*, allow
    p, role:todo-prod-operator, applications, sync, todo-prod/*, allow
    p, role:todo-prod-operator, logs, get, todo-prod/*, allow

    g, argocd-sre, role:todo-prod-operator
```

Argo's current RBAC resource/action matrix supports application operations such as `get`, `create`, `update`, `delete`, `sync`, `action`, and `override`, plus separate permissions for logs, exec, repositories, Projects, clusters and other Argo resources. ([Argo CD][5])

---

# 14.996 What this design achieves

Developers:

```text
Todo Dev

view      ✓
sync      ✓
logs      ✓
```

Production:

```text
view      ✓
logs      ✓
sync      ✕
```

SRE:

```text
Todo Prod

view      ✓
sync      ✓
logs      ✓
```

Now:

```text
being able to see Production
```

does not automatically imply:

```text
being able to deploy Production.
```

That's good separation of duties.

---

# 14.997 AppProject roles

Instead of defining every application permission globally, AppProjects can contain:

```yaml
spec:
  roles:
```

Current Argo Projects support project-scoped roles whose policies operate on Applications associated with that Project and which can map directly to SSO groups. ([Argo CD][1])

Example:

```yaml
roles:

  - name: developers

    description: Todo Dev application operators

    groups:
      - argocd-todo-developers

    policies:

      - >-
        p, proj:todo-dev:developers,
        applications,
        get,
        todo-dev/*,
        allow

      - >-
        p, proj:todo-dev:developers,
        applications,
        sync,
        todo-dev/*,
        allow
```

---

# 14.998 Project-role naming is strict

Current Argo expects project role subjects in the form:

```text
proj:<project-name>:<role-name>
```

for those project-role policies to participate correctly in authorization. ([Argo CD][1])

Example:

```text
proj:todo-dev:developers
```

not:

```text
todo-developers-whatever
```

inside the project policy subject.

---

# 14.999 Global RBAC vs Project roles

Use this mental model:

```text
GLOBAL RBAC
=
Argo-wide privileges

clusters
repositories
projects
accounts
applications across projects
administrative operations


PROJECT ROLE
=
permissions concerning
Applications inside that Project
```

This keeps team-specific application permissions close to the Project boundary while platform-wide privileges remain centralized.

---

# 14.1000 A CI role example

Suppose automation actually needs Argo sync permission.

A Project role can be limited to:

```text
one project
one application
one action
```

For example:

```yaml
roles:

  - name: ci-sync

    policies:

      - >-
        p, proj:todo-dev:ci-sync,
        applications,
        sync,
        todo-dev/todo-backend-dev,
        allow
```

Argo supports project-role JWTs for automation, including revocation metadata and configurable expiry. ([Argo CD][3])

But remember our preferred GitOps architecture:

```text
CI
→ Git

Argo
→ cluster
```

so routine CI often does **not need an Argo token at all**.

---

# 14.1001 `sync` permission is narrower than `update`

This is important.

A user with:

```text
applications, sync
```

can tell Argo:

> Reconcile this Application to the desired state already defined.

But:

```text
applications, update
```

can modify the Application specification itself.

That could alter:

```text
source

revision

path

destination

sync policy
```

These are different powers.

---

# 14.1002 `override` is especially dangerous

Current Argo RBAC has an:

```text
override
```

action which can allow a user to synchronize arbitrary manifests or a different revision instead of the normal configured source for a sync operation. Argo explicitly warns that this can completely change or delete the resources deployed by an Application. ([Argo CD][5])

Therefore:

```text
Production developer role:

override
=
NO
```

unless you have a highly specific reason.

---

# 14.1003 GitOps principle behind that restriction

Normally:

```text
Git
=
desired state.
```

An override says:

```text
For this sync,
use something other than
normal Git desired state.
```

That's effectively an escape hatch from your usual GitOps control path.

Treat it as privileged.

---

# 14.1004 `exec` is also privileged

Argo RBAC includes:

```text
exec
```

permissions.

That can provide terminal-style access into application Pods through Argo when enabled/configured.

Ask yourself:

```text
Does a developer who may deploy
also need interactive shell access
inside Production containers?
```

Those are separate permissions.

Current Argo's RBAC model treats `exec` as its own resource/action boundary. ([Argo CD][5])

---

# 14.1005 Logs vs exec

A useful production separation might be:

```text
Developer:

logs   ✓
exec   ✕
```

SRE:

```text
logs   ✓
exec   ✓
```

depending on your operational and compliance model.

Debugging visibility does not automatically require interactive execution privilege.

---

# 14.1006 Fine-grained resource RBAC

Modern Argo CD also supports fine-grained application-resource update/delete actions.

For example, current docs show patterns like:

```text
delete/*/Pod/*/*
```

to authorize deletion of Pods belonging to an Application without granting permission to delete the Application itself. Since Argo CD 3.0, Application-level update/delete and sub-resource permissions can be separated more precisely. ([Argo CD][5])

Concept:

```text
SRE may:

delete a broken Pod
```

without necessarily being able to:

```text
delete Application/todo-prod.
```

---

# 14.1007 Fine-grained example

Conceptually:

```text
p, role:sre,
applications,
delete/*/Pod/*/*,
todo-prod/*,
allow
```

but:

```text
p, role:sre,
applications,
delete,
todo-prod/*,
deny
```

This says:

```text
Delete child Pod:
YES


Delete Argo Application:
NO
```

Argo warns that glob matching does not treat `/` as a path separator, so fine-grained resource patterns should include all expected segments carefully. ([Argo CD][5])

---

# 14.1008 `deny` usually wins

For ordinary matched RBAC rules:

```text
ALLOW
+
DENY
```

results in:

```text
DENY
```

and policy ordering does not change that result. ([Argo CD][5])

But remember the special caveat:

```text
policy.default
```

is evaluated first, and privileges granted by it cannot simply be taken away through later per-user deny rules. ([Argo CD][5])

So permanent mental model:

```text
NORMAL RULES:
DENY wins


DEFAULT ROLE:
keep minimal because
later deny cannot undo its floor.
```

---

# 14.1009 RBAC object format

For Applications stored in the normal:

```text
argocd
```

control-plane namespace, policy objects usually follow:

```text
<project>/<application>
```

Example:

```text
todo-prod/todo-backend-prod
```

Current Argo RBAC uses this application-specific object format. ([Argo CD][5])

---

# 14.1010 Applications in any namespace

Modern Argo can optionally allow `Application` CRs outside:

```text
argocd
```

for stronger self-service/multi-tenancy patterns.

This feature must be explicitly enabled, and Argo requires both a globally allowed application namespace and that the selected AppProject include that namespace under:

```yaml
sourceNamespaces:
```

before it will process that Application. ([Argo CD][6])

Then RBAC objects use:

```text
<project>/<namespace>/<application>
```

for those Applications. ([Argo CD][6])

---

# 14.1011 Why Applications in any namespace exists

Without this feature, application teams that want to manage Application CRs declaratively often need write access to:

```text
argocd namespace.
```

That's dangerous.

Current Argo documentation explicitly states that people with Kubernetes permissions to create/update Applications in the control-plane `argocd` namespace should effectively be considered Argo administrators. ([Argo CD][6])

Why?

Because:

```text
Application spec
```

can control:

```text
Git source

Project

cluster

namespace

resources.
```

---

# 14.1012 Very important control-plane rule

Do not casually grant ordinary application teams:

```text
write access to namespace:
argocd
```

The control-plane namespace contains powerful objects such as:

```text
Applications

AppProjects

repository credentials

cluster credentials

Argo configuration
```

and is therefore a high-trust boundary. Argo's current application-in-any-namespace guidance explicitly warns about this privilege boundary. ([Argo CD][6])

---

# 14.1013 `sourceNamespaces`

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: todo-dev
  namespace: argocd

spec:

  sourceNamespaces:

    - todo-team-gitops
```

Now an `Application` residing in:

```text
todo-team-gitops
```

may use:

```text
project: todo-dev
```

assuming that namespace is also globally enabled for Applications. ([Argo CD][6])

---

# 14.1014 Never attach a user-controlled namespace to a privileged Project

Current Argo documentation explicitly warns not to add user-controlled namespaces to `sourceNamespaces` of privileged Projects such as an unrestricted/default-style Project, and not to grant the `argocd` control-plane namespace through this mechanism. ([Argo CD][6])

Otherwise:

```text
Team-controlled namespace
       │
       ▼
Application CR
       │
       ▼
Privileged AppProject
       │
       ▼
Privilege escalation
```

---

# 14.1015 Now introduce SSO

So far our lab uses:

```text
admin
```

with a local password.

That is fine for bootstrapping.

Production should usually become:

```text
Corporate Identity Provider
          │
          ▼
       Argo CD
          │
          ▼
      SSO groups
          │
          ▼
       Argo RBAC
```

Argo currently supports two main SSO patterns: bundled Dex, which can bridge providers/protocols such as SAML or LDAP and provide additional connector behavior, or direct use of an existing OIDC provider such as Okta, Microsoft Entra ID, Keycloak, Google, Auth0, and others. ([Argo CD][2])

---

# 14.1016 Direct OIDC architecture

```text
Employee
   │
   ▼
Corporate OIDC IdP
   │
   ▼
ID token
   │
   ├── subject
   ├── email
   └── groups
          │
          ▼
       Argo CD
          │
          ▼
         RBAC
```

Argo can request OIDC scopes/claims such as groups and email and use configured scopes during RBAC enforcement. ([Argo CD][7])

---

# 14.1017 Dex architecture

When the corporate provider doesn't fit direct OIDC requirements—or you need one of Dex's connector capabilities—the flow can be:

```text
Employee
    │
    ▼
Corporate IdP
    │
    ▼
    Dex
    │
    ▼
 Argo CD
    │
    ▼
 RBAC
```

Dex is bundled with Argo CD specifically to delegate authentication to external providers and supports connector types including OIDC, SAML, LDAP and GitHub. ([Argo CD][2])

---

# 14.1018 OIDC groups become authorization input

Identity provider returns:

```text
groups:

argocd-todo-developers
argocd-prod-readers
```

Argo RBAC:

```text
g, argocd-todo-developers, role:todo-dev

g, argocd-prod-readers, role:todo-prod-readonly
```

Therefore:

```text
Identity group membership

        ↓

Argo authorization.
```

Current Argo allows the RBAC scope configuration to examine group claims and optionally other claims such as email. ([Argo CD][5])

---

# 14.1019 Why group-based authorization is better

Do not build production RBAC primarily as:

```text
vivek@example.com
→ role A

alice@example.com
→ role A

bob@example.com
→ role A
```

Prefer:

```text
argocd-todo-developers
→ role A
```

Then corporate identity lifecycle owns:

```text
joiner
mover
leaver
```

membership.

It keeps Argo policy focused on roles rather than individual employees.

---

# 14.1020 AWS IAM Identity Center connection

Since we already learned IAM Identity Center in Module 13, here's the connection.

Current Argo documentation demonstrates AWS IAM Identity Center integration through:

```text
IAM Identity Center
       │
      SAML
       │
       ▼
      Dex
       │
       ▼
    Argo CD
```

and then maps Identity Center group information into Argo roles. However, the current Argo page explicitly notes that its demonstrated Identity Center group-attribute workaround is not officially supported in AWS's own documentation, so this specific mapping should be validated carefully in your environment rather than assumed as a universal production contract. ([Argo CD][8])

That's an important current-version nuance.

---

# 14.1021 Identity Center + Argo mental model

From Module 13:

```text
IAM Identity Center
=
enterprise workforce identity/access
```

Now:

```text
Identity Center group
        │
        ▼
       Dex
        │
        ▼
    Argo SSO identity
        │
        ▼
    Argo RBAC role
        │
        ▼
    AppProject boundary
        │
        ▼
      Kubernetes
```

So the workforce identity plane connects into the GitOps authorization plane. ([Argo CD][8])

---

# 14.1022 Built-in admin should become bootstrap-only

Current Argo guidance recommends using the built-in:

```text
admin
```

only for initial configuration and then switching to SSO or appropriately configured local users. Once alternative access is established, Argo recommends disabling the admin account with:

```yaml
admin.enabled: "false"
```

in `argocd-cm`. ([Argo CD][7])

Production should not be:

```text
Everyone shares:

username:
admin

password:
company123
```

---

# 14.1023 Don't disable admin before validating SSO

Operational sequence:

```text
Configure SSO
      │
      ▼
Test login
      │
      ▼
Test admin-equivalent group
      │
      ▼
Test ordinary roles
      │
      ▼
Test emergency recovery
      │
      ▼
THEN disable normal admin login
```

Otherwise you can lock yourself out of Argo's API/UI control plane.

---

# 14.1024 Production identity groups

A clean enterprise model might contain:

```text
argocd-platform-admins

argocd-sre

argocd-security-readers

argocd-todo-developers

argocd-todo-prod-readers

argocd-payments-developers

argocd-payments-prod-operators
```

Then Argo RBAC maps groups to capabilities.

Avoid:

```text
argocd-everyone-admin.
```

---

# 14.1025 Three teams example

Imagine:

```text
Todo Team

Payments Team

Platform Team
```

Todo Project permits:

```text
todo-gitops

todo-* namespaces
```

Payments Project permits:

```text
payments-gitops

payments-* namespaces
```

Platform Project permits:

```text
platform-gitops

platform namespaces

selected cluster resources.
```

Then SSO groups map humans into Argo roles for those respective Projects.

This is genuine multi-tenancy.

---

# 14.1026 Developer attack scenario #1

Todo developer changes:

```yaml
destination:
  namespace: payments-prod
```

AppProject:

```text
Todo destinations:

todo-prod only
```

Result:

```text
DENIED.
```

Even though:

```text
developer can edit Todo Git.
```

---

# 14.1027 Attack scenario #2

Todo developer changes:

```yaml
repoURL:
  attacker.example.com/malicious.git
```

AppProject:

```text
Approved source:

company/todo-gitops
```

Result:

```text
DENIED.
```

---

# 14.1028 Attack scenario #3

Todo Git adds:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
...
```

Todo Project:

```text
Cluster-scoped allowlist:

Namespace/todo-prod only
```

Result:

```text
DENIED.
```

This demonstrates why AppProject isn't simply an organizational label.

It's a security control.

---

# 14.1029 Attack scenario #4

Developer can:

```text
applications, sync
```

but not:

```text
applications, update
```

They can deploy the already-reviewed desired state.

They cannot change the Argo Application to point at:

```text
another source
another destination
another Project
```

through Argo's API.

This can be a strong operator model.

---

# 14.1030 Attack scenario #5 — CI compromise

Our CI bot can:

```text
write Dev Git
```

but has:

```text
no Argo admin credential
no Kubernetes credential
no production merge privilege.
```

Even if compromised, the attacker must cross additional controls before Production.

This is why our CI → Git → Argo separation from Lesson 5 matters.

---

# 14.1031 Attack scenario #6 — user has Kubernetes access directly

Important:

```text
AppProject
```

only governs deployment **through Argo**.

If an engineer separately has:

```text
kubectl cluster-admin
```

they can bypass Argo and modify Kubernetes directly.

Argo Projects do not replace Kubernetes RBAC.

That's why we need:

```text
Argo RBAC
+
AppProject
+
Kubernetes RBAC.
```

---

# 14.1032 Kubernetes RBAC is the final authority

Suppose AppProject says:

```text
Deployment allowed.
```

But Argo's cluster credential lacks:

```text
create deployments
```

Kubernetes says:

```text
Forbidden.
```

Result:

```text
SYNC FAILED.
```

AppProject permission does not grant Kubernetes API permissions.

Argo's own security guidance notes that Argo does not necessarily require unrestricted write access and that Kubernetes permissions can be restricted to the namespaces/resources it needs to manage. ([Argo CD][4])

---

# 14.1033 Defense-in-depth model

Suppose an AppProject is accidentally too broad.

Kubernetes RBAC can still restrict:

```text
what Argo's ServiceAccount
may actually write.
```

Likewise, if Kubernetes RBAC is broad:

```text
AppProject
```

can still restrict what legitimate Argo Applications are permitted to request.

Two independent controls are stronger than one.

---

# 14.1034 Example Argo cluster privilege model

Instead of:

```text
Argo:

cluster-admin
everywhere
```

a mature setup may have:

```text
Cluster-wide read
as required for reconciliation

+

write only
to managed namespaces/resources
```

depending on architecture.

Argo's current security documentation explicitly notes that full cluster-wide write privileges are not inherently required and external-cluster roles can be narrowed. ([Argo CD][4])

---

# 14.1035 AppProject does not protect repository writes

Project says:

```text
todo-gitops is trusted.
```

It does not answer:

```text
Who may push to todo-gitops?
```

That's Git provider security.

So our security chain is:

```text
Git Authorization
        │
        ▼
AppProject
        │
        ▼
Argo RBAC
        │
        ▼
Kubernetes Authorization
```

Every layer matters.

---

# 14.1036 Production privilege matrix

| Persona          |         Dev view |         Dev sync | Prod view | Prod sync | Project admin | Cluster admin |
| ---------------- | ---------------: | ---------------: | --------: | --------: | ------------: | ------------: |
| Developer        |                ✓ |                ✓ |         ✓ |         ✕ |             ✕ |             ✕ |
| QA               |                ✓ |         optional |         ✓ |         ✕ |             ✕ |             ✕ |
| SRE              |                ✓ |                ✓ |         ✓ |         ✓ |       limited |             ✕ |
| Platform         |                ✓ |                ✓ |         ✓ |         ✓ |             ✓ | limited/admin |
| Security auditor |                ✓ |                ✕ |         ✓ |         ✕ |          read |             ✕ |
| CI promotion bot | usually Git only | usually Git only |         ✕ |         ✕ |             ✕ |             ✕ |

This isn't a universal policy. It's a useful separation-of-duties starting point.

---

# 14.1037 Lock down the default Project later

Once all real Applications have been moved to dedicated Projects, current Argo docs show that the default Project can be reduced to essentially no useful deployment permissions. ([Argo CD][1])

Conceptually:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject

metadata:
  name: default
  namespace: argocd

spec:

  sourceRepos: []

  sourceNamespaces: []

  destinations: []

  namespaceResourceBlacklist:

    - group: "*"
      kind: "*"
```

Do **not** apply this blindly while applications still depend on:

```text
project: default.
```

Move them first.

---

# 14.1038 Why default lockdown matters

Otherwise future engineer creates:

```yaml
spec:
  project: default
```

and accidentally falls back into:

```text
unrestricted project.
```

If `default` is locked down:

```text
forgetting to choose
a proper Project
```

fails safely.

This is:

# secure by default.

---

# 14.1039 Project-scoped cluster boundaries

Current AppProject specifications also expose:

```yaml
permitOnlyProjectScopedClusters: true
```

for architectures where Applications in a Project should only use clusters specifically scoped to that Project rather than any globally registered destination that happens to match. ([Argo CD][3])

This becomes useful when one central Argo manages many tenants and clusters.

We'll revisit this in the multi-cluster lesson.

---

# 14.1040 SSO scopes

Argo RBAC's:

```yaml
scopes:
```

controls which OIDC claims, beyond the subject, participate in authorization. If omitted, current Argo defaults to examining the `groups` scope; configurations can also include things such as email. ([Argo CD][5])

Example:

```yaml
scopes: '[groups, email]'
```

But group-based role mappings are usually cleaner than binding many individual emails.

---

# 14.1041 Group claims troubleshooting

Engineer logs in but gets:

```text
PermissionDenied.
```

Do not immediately edit RBAC.

Check this path:

```text
IdP user
   │
   ▼
IdP group membership
   │
   ▼
OIDC/SAML claim
   │
   ▼
Argo scope configuration
   │
   ▼
group → role mapping
   │
   ▼
role policy
   │
   ▼
AppProject
```

If:

```text
groups claim
```

never reaches Argo, perfect RBAC policy still won't work.

---

# 14.1042 SSO authentication troubleshooting

For SSO login failures, separate:

```text
Authentication failure
```

from:

```text
Authorization failure.
```

Authentication failure:

```text
cannot log in
callback error
issuer error
client issue
token validation issue
```

Authorization failure:

```text
login works

but operation returns
PermissionDenied.
```

Different layers.

---

# 14.1043 RBAC troubleshooting mnemonic

Use:

# **I → C → G → R → P → A → K**

```text
I
IDENTITY

Who logged in?


C
CLAIMS

Which groups/email/sub
did Argo receive?


G
GROUP

Does group map to role?


R
ROLE

Which Argo role?


P
POLICY

Does policy allow action?


A
APP PROJECT

Is Application itself permitted?


K
KUBERNETES

Can Argo actually perform API action?
```

This will save you a huge amount of debugging time.

---

# 14.1044 Example: user can view but not sync

User:

```text
login ✓

application visible ✓

sync ✕
```

This strongly suggests:

```text
authentication works.
```

Then inspect:

```text
applications, sync
```

RBAC permission.

Not:

```text
OIDC client secret.
```

---

# 14.1045 Example: user can sync Dev but not Prod

That's often exactly correct.

Check:

```text
Dev:
role mapping contains sync

Prod:
role mapping contains get only.
```

Do not "fix" intentional least privilege.

---

# 14.1046 Example: Project says destination invalid

Application:

```text
Permission denied?
```

No.

If Argo says the Application destination/source is not permitted by Project, your human RBAC might be completely fine.

This is:

```text
AppProject policy failure
```

not:

```text
user authorization failure.
```

Always identify the control layer first.

---

# 14.1047 Example: sync returns Kubernetes forbidden

Application:

```text
source valid       ✓

destination valid  ✓

Project valid      ✓

Argo user sync     ✓
```

but Kubernetes responds:

```text
forbidden:
cannot create resource
```

Now inspect:

```text
Argo cluster credentials

ServiceAccount

Role

ClusterRole

RoleBinding

ClusterRoleBinding
```

This is Kubernetes RBAC.

---

# 14.1048 Example: manifests contain forbidden ClusterRole

Repository renders correctly.

Human can sync.

Kubernetes credentials might even have permission.

But AppProject says:

```text
ClusterRole not allowed.
```

That's exactly what we want:

```text
Project policy
stops the request
before broad Kubernetes authority
is exercised.
```

---

# 14.1049 Example: hidden remote dependency bypasses source expectation

Todo Project trusts:

```text
company/todo-gitops.
```

Application passes Project source validation.

But that Git repo references:

```text
Kustomize remote base:
unknown/privileged-base
```

The initial repository allowlist does not automatically block every transitive Kustomize/Helm source. ([Argo CD][4])

Therefore security review must inspect:

```text
rendering dependencies.
```

This is a more advanced threat model.

---

# 14.1050 Git repository write access is deployment privilege

Argo's current security guide explicitly warns that unauthorized write access to a trusted Git repository can be used to alter images, resources, or delete manifests that Argo may then prune. ([Argo CD][4])

So:

```text
GitOps Repo Writer
```

should be considered a privileged production identity.

This ties directly back to our:

```text
CODEOWNERS
branch protection
PR approvals
```

from Lesson 5.

---

# 14.1051 Production Argo security architecture

A strong design looks like:

```text
                   CORPORATE IdP
                        │
                MFA / workforce policy
                        │
                        ▼
                    ARGO SSO
                        │
                        ▼
                     GROUPS
                        │
                        ▼
                   ARGO RBAC
                        │
                        ▼
                    AppProject
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼

     Source Repos   Destinations   Resource Kinds
          │             │             │
          └─────────────┼─────────────┘
                        ▼
                  Application
                        │
                        ▼
              Kubernetes credentials
                        │
                        ▼
                Kubernetes RBAC
                        │
                        ▼
                 Admission policy
                        │
                        ▼
                    Workload
```

No single control is carrying the entire security burden.

---

# 14.1052 What we should eventually do with our Todo architecture

We will end up with Projects like:

```text
todo-dev
todo-prod
platform
```

instead of putting everything under:

```text
default.
```

Then:

```text
Todo Developers
        │
        ├── Dev get/sync/logs
        └── Prod get/logs


SRE
        │
        └── Prod get/sync/logs


Platform
        │
        └── Project/cluster/repository administration
```

That gives us separation between:

```text
application development

production operations

platform administration.
```

---

# 14.1053 Interview — AppProject vs Argo RBAC

Strong answer:

> **Argo RBAC controls what authenticated users or groups may do through Argo CD, such as viewing, syncing, updating, or deleting Applications. AppProject constrains the Applications themselves by defining which source repositories, destination clusters/namespaces, and Kubernetes resource kinds they may use. I use both because user authorization and application deployment boundaries solve different problems.** ([Argo CD][1])

---

# 14.1054 Interview — AppProject vs Kubernetes RBAC

Strong answer:

> **AppProject is an Argo policy layer; it does not grant Kubernetes API permissions. Kubernetes RBAC remains the actual cluster authorization mechanism for Argo's credentials. Therefore a Project can permit an operation while Kubernetes still rejects it, and production deployments should use both layers for defense in depth.** ([Argo CD][4])

---

# 14.1055 Interview — What does `sourceRepos` do?

It restricts which initial source repositories Applications in the Project may use. Argo supports allow and negated deny patterns. ([Argo CD][1])

But the senior addition is:

> **It does not by itself constrain every transitive Helm dependency or Kustomize remote base.** ([Argo CD][4])

That second sentence is the difference between a basic and advanced answer.

---

# 14.1056 Interview — Why lock down `default`?

Because Argo's default Project begins broadly permissive. Once dedicated Projects exist, reducing the default Project's permissions prevents accidentally unclassified Applications from inheriting broad deployment authority. ([Argo CD][1])

---

# 14.1057 Interview — `role:readonly` vs custom default role

`role:readonly` is an Argo-wide built-in read-only role. In strict multi-tenancy, even global read access may be too broad, so a custom minimal `policy.default` role is often preferable. Additionally, permissions inherited from `policy.default` cannot be removed through later deny rules. ([Argo CD][5])

---

# 14.1058 Interview — Does deny win?

For ordinary matched policies:

```text
yes.
```

A matching `deny` has priority over matching `allow`, regardless of ordering. ([Argo CD][5])

But mention:

```text
policy.default
```

as the special caveat.

That's a strong interview answer.

---

# 14.1059 Interview — Why is `override` dangerous?

Because it permits synchronization using arbitrary manifests or revisions outside the normal configured desired source for that operation. Argo explicitly warns it can completely change/delete deployed resources. ([Argo CD][5])

Production:

```text
override
=
privileged escape hatch.
```

---

# 14.1060 Interview — Why SSO groups instead of local users?

Argo supports local accounts, but its own user-management guidance recommends SSO when you need richer identity features such as groups and centralized identity management. SSO group claims can be mapped directly into Argo RBAC roles. ([Argo CD][7])

---

# 14.1061 Interview — Dex vs direct OIDC

Strong answer:

> **Use direct OIDC when the organization's identity provider already provides the OIDC integration and claims Argo needs. Dex is useful when bridging protocols/providers such as SAML or LDAP, or when Dex-specific connector capabilities are useful.** ([Argo CD][2])

---

# 14.1062 Interview — Should normal engineers use `admin`?

No.

Argo recommends using the built-in admin for initial configuration and switching to SSO or scoped accounts afterward; the built-in admin can then be disabled. ([Argo CD][7])

---

# 14.1063 Interview — Why is write access to `argocd` namespace dangerous?

Because declarative Application/AppProject access there can give users control over Argo's own high-privilege control-plane resources. Current Argo documentation says users able to create/update Applications in the `argocd` control-plane namespace should effectively be considered Argo administrators. ([Argo CD][6])

---

# 14.1064 Interview — Applications in any namespace

Strong answer:

> **Argo can optionally reconcile Application CRs outside its control-plane namespace. The namespace must be globally enabled and also allowed by the chosen AppProject's `sourceNamespaces`. This enables safer application-team self-service without giving teams write access to the `argocd` namespace.** ([Argo CD][6])

---

# 14.1065 Production checklist

Before calling a shared Argo installation multi-tenant, verify all of the following:

* Dedicated AppProjects exist instead of relying on permissive `default`; source repos, destination namespaces/clusters, and cluster-scoped resource permissions are explicit; SSO groups map to least-privilege Argo roles; `policy.default` is minimal; ordinary users do not use built-in admin; Production `sync`, `update`, `override`, and `exec` privileges are separated; Git repository writes are protected; access to the `argocd` namespace is tightly controlled; Argo's Kubernetes write permissions are limited appropriately; transitive Helm/Kustomize dependencies are reviewed; and if Applications-in-any-namespace is enabled, `sourceNamespaces` is configured only on suitably restricted Projects. ([Argo CD][1])

---

# 14.1066 Never-forget security model

Memorize:

```text
IDENTITY
=
Who are you?


ARGO RBAC
=
What can YOU do?


APP PROJECT
=
What can the APPLICATION do?


KUBERNETES RBAC
=
What can ARGO actually do?


GIT SECURITY
=
Who can change desired state?
```

And the most important equation:

```text
PRODUCTION GITOPS SECURITY

=

Git authorization

+

SSO

+

Argo RBAC

+

AppProject

+

Kubernetes RBAC

+

Admission controls
```

---

# 14.1067 AppProject never-forget rules

```text
AppProject
does NOT grant access.

It constrains deployment.


sourceRepos
=
where manifests may originate.


destinations
=
where they may run.


clusterResourceWhitelist
=
which cluster-wide resources
may be created.


namespaceResourceBlacklist /
Whitelist
=
resource-kind boundary
inside namespaces.


default Project
=
lab-friendly,
production-dangerous unless restricted.
```

Current Argo Projects are explicitly built around these source, destination, resource and project-role controls. ([Argo CD][1])

---

# 14.1068 RBAC never-forget rules

```text
p
=
POLICY


g
=
GROUP / ROLE MAPPING


role:admin
=
unrestricted


role:readonly
=
global read-only


policy.default
=
permission floor


normal deny
>
normal allow


sync
!=
update


update
!=
override


logs
!=
exec
```

Current Argo RBAC separates these resources/actions explicitly. ([Argo CD][5])

---

# 14.1069 SSO never-forget rules

```text
SSO
=
authentication


Group claims
=
authorization input


OIDC provider
or
Dex
=
identity bridge


Argo RBAC
=
final Argo role decision
```

And:

```text
SSO success
does NOT automatically mean
authorization success.
```

Argo separates external identity integration from its RBAC policy evaluation. ([Argo CD][2])

---

# 14.1070 Troubleshooting flow

Use:

```text
IDENTITY
   │
   ▼
CLAIMS
   │
   ▼
GROUP
   │
   ▼
ROLE
   │
   ▼
POLICY
   │
   ▼
APP PROJECT
   │
   ▼
KUBERNETES RBAC
```

or:

# **I-C-G-R-P-A-K**

Examples:

```text
Can't log in
→ I / C


Logged in but PermissionDenied
→ G / R / P


Destination not permitted
→ A


Kubernetes says forbidden
→ K
```

That distinction is one of the biggest things to master before operating shared Argo CD.

---

# ✅ Module 14 — Lesson 8 Complete

At this point we have moved far beyond:

```text
"Install Argo and give everyone admin."
```

We now have a production model:

```text
Corporate IdP
      │
      ▼
     SSO
      │
      ▼
 Argo Groups
      │
      ▼
  Argo RBAC
      │
      ▼
  AppProject
      │
      ▼
 Application
      │
      ▼
Kubernetes RBAC
      │
      ▼
   Workload
```

And alongside it:

```text
Git permissions
      │
      ▼
PR / CODEOWNERS
      │
      ▼
trusted desired state
```

That is how a shared GitOps control plane becomes governable rather than simply powerful. ([Argo CD][4])

# Next — Module 14, Lesson 9

## ApplicationSet — Multi-Environment & Multi-Cluster Application Generation

Next we solve this problem:

```text
30 applications
×
3 environments
×
10 clusters

=

900 Application objects
```

We absolutely do **not** want to maintain 900 nearly identical YAML files manually.

We'll move from:

```text
todo-dev.yaml
todo-stage.yaml
todo-prod.yaml
payments-dev.yaml
payments-stage.yaml
payments-prod.yaml
...
```

to:

```text
                    ApplicationSet
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼

           Git          Clusters       Matrix
        Generator      Generator      Generator
            │             │             │
            └─────────────┼─────────────┘
                          ▼
                 Generated Applications
```

Then we'll go deeply into **List Generator, Git Directory Generator, Git File Generator, Cluster Generator, Matrix Generator, Merge Generator, Pull Request Generator, Go templating, generated Application ownership, auto-sync interaction, deletion behavior, multi-cluster rollout, environment directory discovery, production safety, and automatically generating our Todo Dev/Staging/Prod Applications from the GitOps repository structure we just designed.**

<!-- GENERATED-MASTERY-WORKBOOK:START -->

# 14.8.1071 Professional Mastery Workbook

This workbook expands **AppProject, RBAC, SSO & Multi-Team Isolation** into deliberate practice without replacing the authored tutorial above.

Use it after reading the core explanation. The goal is not to memorize thousands of lines; the goal is to repeatedly explain, build, break, secure, observe, recover, and defend the lesson in different conditions.

## Workbook learning contract

- Concepts covered: 104 lesson-specific anchors.
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

### Concept card 1 - The four authorization layers

- Lesson anchor: Keep this architecture permanently: HUMAN / CI │ ▼ ┌──────────────┐ │ Identity/SSO │ └──────┬───────┘ │ WHO ARE YOU? │ ▼ ┌──────────┐ │ Argo RBAC│ └────┬─────┘ │ WHAT MAY YOU DO? │ ▼ ┌────────────┐ │ AppProject │ └─────┬──────┘
- Beginner explanation: Restate **The four authorization layers** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **The four authorization layers** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **The four authorization layers**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **The four authorization layers**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **The four authorization layers** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 2 - Authentication vs authorization

- Lesson anchor: Authentication answers: WHO ARE YOU? For example: Vivek Todo Developer Platform Engineer SRE CI automation Authorization answers: WHAT MAY YOU DO? For example: view todo-dev sync todo-dev view todo-prod sync todo-prod modify AppProjects
- Beginner explanation: Restate **Authentication vs authorization** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Authentication vs authorization** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Authentication vs authorization**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Authentication vs authorization**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Authentication vs authorization** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 3 - AppProject vs Argo RBAC

- Lesson anchor: This distinction is extremely important. Suppose a developer asks: Can I click SYNC on todo-prod? That is mainly: ARGO RBAC But suppose the application itself says: source: repoURL: attacker.example/malicious.git destination:
- Beginner explanation: Restate **AppProject vs Argo RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AppProject vs Argo RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **AppProject vs Argo RBAC**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **AppProject vs Argo RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AppProject vs Argo RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 4 - What does an AppProject actually protect?

- Lesson anchor: Current Argo CD Projects provide four major security boundaries: Trusted source repositories Destination clusters Destination namespaces Allowed/denied Kubernetes resource kinds They can also contain project roles and Sync Windows. ([Argo CD][1])
- Beginner explanation: Restate **What does an AppProject actually protect?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What does an AppProject actually protect?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **What does an AppProject actually protect?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **What does an AppProject actually protect?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What does an AppProject actually protect?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 5 - Our current `default` Project is dangerous for production

- Lesson anchor: Remember our guestbook Application: spec: project: default Argo automatically creates: default and by default it allows: sourceRepos:  destinations:  clusterResourceWhitelist: / meaning essentially any repository, destination, and resource kind. Argo's curr...
- Beginner explanation: Restate **Our current `default` Project is dangerous for production** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Our current `default` Project is dangerous for production** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Our current `default` Project is dangerous for production**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Our current `default` Project is dangerous for production**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Our current `default` Project is dangerous for production** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 6 - Build our first restricted AppProject

- Lesson anchor: Let's improve the guestbook lab first. Create: cd ~/argocd-labs/lesson-3 nano guestbook-project.yaml Use: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: guestbook-lab namespace: argocd spec: description: Restricted project for Guestbook lab
- Beginner explanation: Restate **Build our first restricted AppProject** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Build our first restricted AppProject** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Build our first restricted AppProject**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Build our first restricted AppProject**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Build our first restricted AppProject** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 7 - Read this Project as English

- Lesson anchor: It says: Applications in guestbook-lab MAY read manifests from: argoproj/argocd-example-apps MAY deploy to: this cluster MAY deploy namespaced resources into: guestbook MAY create cluster-scoped: Namespace/guestbook Everything else cluster-scoped:
- Beginner explanation: Restate **Read this Project as English** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Read this Project as English** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Read this Project as English**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Read this Project as English**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Read this Project as English** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 8 - Apply the Project

- Lesson anchor: kubectl apply -f guestbook-project.yaml Then: kubectl get appprojects -n argocd You should see: default guestbook-lab Inspect: kubectl get appproject guestbook-lab \ -n argocd \ -o yaml ---
- Beginner explanation: Restate **Apply the Project** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Apply the Project** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Apply the Project**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Apply the Project**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Apply the Project** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 9 - Move guestbook into the Project

- Lesson anchor: Our current Application still says: project: default Patch it: kubectl patch application guestbook \ -n argocd \ --type merge \ -p '{ "spec": { "project": "guestbook-lab" } }' Then: argocd app get guestbook You should now see:
- Beginner explanation: Restate **Move guestbook into the Project** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Move guestbook into the Project** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Move guestbook into the Project**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Move guestbook into the Project**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Move guestbook into the Project** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 10 - Update your local Application YAML too

- Lesson anchor: Change: spec: project: default to: spec: project: guestbook-lab This avoids our usual anti-pattern: Live configuration != declarative configuration. ---
- Beginner explanation: Restate **Update your local Application YAML too** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Update your local Application YAML too** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Update your local Application YAML too**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Update your local Application YAML too**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Update your local Application YAML too** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 11 - Test that the normal deployment still works

- Lesson anchor: Run: argocd app get guestbook --refresh Then: argocd app sync guestbook And: argocd app wait guestbook \ --sync \ --health The Application should continue working because: Repo                  ✓ allowed Cluster               ✓ allowed
- Beginner explanation: Restate **Test that the normal deployment still works** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Test that the normal deployment still works** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Test that the normal deployment still works**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Test that the normal deployment still works**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Test that the normal deployment still works** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 12 - Now imagine an attack

- Lesson anchor: Developer modifies the Application to: destination: server: https://kubernetes.default.svc namespace: kube-system Application still belongs to: guestbook-lab. The Project only allows: guestbook Therefore Argo's Project policy rejects that destination instea...
- Beginner explanation: Restate **Now imagine an attack** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Now imagine an attack** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Now imagine an attack**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Now imagine an attack**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Now imagine an attack** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 13 - This is why Git access alone is not enough

- Lesson anchor: Suppose someone manages to alter: guestbook Git and adds: kind: ClusterRole If our AppProject only permits: Namespace/guestbook as a cluster-scoped kind/name, that new ClusterRole does not become permitted simply because it appeared in Git. Argo Projects us...
- Beginner explanation: Restate **This is why Git access alone is not enough** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **This is why Git access alone is not enough** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **This is why Git access alone is not enough**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **This is why Git access alone is not enough**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **This is why Git access alone is not enough** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 14 - Why cluster-scoped resources are especially dangerous

- Lesson anchor: Consider: ClusterRole ClusterRoleBinding CustomResourceDefinition Namespace StorageClass ClusterIssuer These are not confined to: todo-prod the way an ordinary namespaced Deployment is. A compromised application allowed to create powerful cluster-scoped RBA...
- Beginner explanation: Restate **Why cluster-scoped resources are especially dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why cluster-scoped resources are especially dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Why cluster-scoped resources are especially dangerous**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Why cluster-scoped resources are especially dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why cluster-scoped resources are especially dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 15 - Namespaced resources also require thought

- Lesson anchor: Even inside one namespace, powerful resources may exist. For example: Role RoleBinding Secret NetworkPolicy ResourceQuota Current AppProject specifications support both namespace-resource allowlists and blacklists. ([Argo CD][3])
- Beginner explanation: Restate **Namespaced resources also require thought** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Namespaced resources also require thought** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Namespaced resources also require thought**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Namespaced resources also require thought**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Namespaced resources also require thought** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 16 - Example production Todo Project

- Lesson anchor: Conceptually: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: todo-prod namespace: argocd spec: description: Todo production workloads sourceRepos: destinations: namespace: todo-prod clusterResourceWhitelist:
- Beginner explanation: Restate **Example production Todo Project** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example production Todo Project** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Example production Todo Project**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Example production Todo Project**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example production Todo Project** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 17 - Project source repository allowlist

- Lesson anchor: Suppose: sourceRepos: Developer changes Application to: repoURL: https://evil.example.com/rootkit.git Project decision: Is repo on approved source list? NO ↓ Application rejected Argo Projects support both positive repository rules and explicit negated repo...
- Beginner explanation: Restate **Project source repository allowlist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Project source repository allowlist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Project source repository allowlist**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Project source repository allowlist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Project source repository allowlist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 18 - Source negation

- Lesson anchor: For example: sourceRepos: means conceptually: company/ = generally allowed company/experimental/ = explicitly denied. Argo supports negated source rules beginning with !. ([Argo CD][1]) ---
- Beginner explanation: Restate **Source negation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Source negation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Source negation**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Source negation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Source negation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 19 - Destination negation

- Lesson anchor: Likewise: destinations: server: "" server: "" conceptually means: any namespace EXCEPT kube-system. Argo evaluates destination rules using the same basic idea: an allowed rule must match and no matching deny rule may reject the destination. ([Argo CD][1])
- Beginner explanation: Restate **Destination negation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Destination negation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Destination negation**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Destination negation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Destination negation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 20 - But explicit positive allowlists are often easier to reason about

- Lesson anchor: Compare: anything except kube-system with: only todo-prod. For a dedicated Todo Production Project, the second model has a much smaller blast radius. Security principle: Production least privilege usually prefers: known allowed destinations
- Beginner explanation: Restate **But explicit positive allowlists are often easier to reason about** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **But explicit positive allowlists are often easier to reason about** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **But explicit positive allowlists are often easier to reason about**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **But explicit positive allowlists are often easier to reason about**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **But explicit positive allowlists are often easier to reason about** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 21 - Important AppProject limitation: transitive repositories

- Lesson anchor: Here's a senior-level security nuance. Suppose the Project allows only: company/todo-gitops but that trusted repo contains a Kustomize remote base: https://unknown.example.com/base.git or a Helm dependency from another repository.
- Beginner explanation: Restate **Important AppProject limitation: transitive repositories** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Important AppProject limitation: transitive repositories** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Important AppProject limitation: transitive repositories**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Important AppProject limitation: transitive repositories**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Important AppProject limitation: transitive repositories** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 22 - Never-forget dependency trust

- Lesson anchor: Security review must include: Git repository │ ▼ Helm dependencies │ ▼ Kustomize remote bases │ ▼ Config-management plugins because a trusted repository can pull additional configuration into its rendered manifests. ([Argo CD][4])
- Beginner explanation: Restate **Never-forget dependency trust** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget dependency trust** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Never-forget dependency trust**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Never-forget dependency trust**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget dependency trust** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 23 - Now move to Argo RBAC

- Lesson anchor: AppProject says: todo-prod is allowed to deploy from X to Y. But we still need to answer: Who can SEE todo-prod? Who can SYNC it? Who can MODIFY it? Who can DELETE it? Who can access logs? Who can exec into Pods? Who can administer Projects?
- Beginner explanation: Restate **Now move to Argo RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Now move to Argo RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Now move to Argo RBAC**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Now move to Argo RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Now move to Argo RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 24 - Argo's built-in roles

- Lesson anchor: Current Argo CD has two built-in roles: role:readonly role:admin role:readonly has read-only access across Argo resources, while role:admin is unrestricted. The built-in admin user itself is a superuser. ([Argo CD][5]) This means:
- Beginner explanation: Restate **Argo's built-in roles** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Argo's built-in roles** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Argo's built-in roles**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Argo's built-in roles**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Argo's built-in roles** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 25 - Avoid this production mistake

- Lesson anchor: policy.default: role:readonly looks harmless. But that means every authenticated user gets the default role's permissions. Even more importantly, current Argo documentation warns that permissions granted by policy.default cannot later be removed by a subjec...
- Beginner explanation: Restate **Avoid this production mistake** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Avoid this production mistake** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Avoid this production mistake**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Avoid this production mistake**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Avoid this production mistake** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 26 - Think of `policy.default` as the floor

- Lesson anchor: If: policy.default = read everything then: specific deny cannot reduce that floor in the way many engineers expect. Therefore design: DEFAULT = almost nothing and then add: team-specific privileges. ---
- Beginner explanation: Restate **Think of `policy.default` as the floor** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Think of `policy.default` as the floor** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Think of `policy.default` as the floor**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Think of `policy.default` as the floor**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Think of `policy.default` as the floor** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 27 - RBAC policy syntax

- Lesson anchor: Argo uses a Casbin-based policy structure. Permission rule: p, SUBJECT, RESOURCE, ACTION, OBJECT, EFFECT For example: p, role:todo-dev, applications, get, todo-dev/, allow Current Argo RBAC syntax uses exactly those policy elements, with allow or deny as ef...
- Beginner explanation: Restate **RBAC policy syntax** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RBAC policy syntax** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **RBAC policy syntax**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **RBAC policy syntax**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RBAC policy syntax** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 28 - Group mapping syntax

- Lesson anchor: Role binding: g, USERORGROUP, ROLE Example: g, argocd-todo-developers, role:todo-dev means: SSO group argocd-todo-developers ↓ Argo role role:todo-dev Argo RBAC consumes user/group information from configured SSO claims/scopes and can bind those identities...
- Beginner explanation: Restate **Group mapping syntax** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Group mapping syntax** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Group mapping syntax**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Group mapping syntax**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Group mapping syntax** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 29 - Example global RBAC design

- Lesson anchor: Conceptual argocd-rbac-cm: apiVersion: v1 kind: ConfigMap metadata: name: argocd-rbac-cm namespace: argocd data: policy.default: role:authenticated scopes: '[groups, email]' policy.csv: | p, role:authenticated, projects, get, , allow
- Beginner explanation: Restate **Example global RBAC design** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example global RBAC design** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Example global RBAC design**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Example global RBAC design**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example global RBAC design** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 30 - What this design achieves

- Lesson anchor: Developers: Todo Dev view      ✓ sync      ✓ logs      ✓ Production: view      ✓ logs      ✓ sync      ✕ SRE: Todo Prod view      ✓ sync      ✓ logs      ✓ Now: being able to see Production does not automatically imply: being able to deploy Production.
- Beginner explanation: Restate **What this design achieves** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What this design achieves** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **What this design achieves**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **What this design achieves**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What this design achieves** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 31 - AppProject roles

- Lesson anchor: Instead of defining every application permission globally, AppProjects can contain: spec: roles: Current Argo Projects support project-scoped roles whose policies operate on Applications associated with that Project and which can map directly to SSO groups....
- Beginner explanation: Restate **AppProject roles** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AppProject roles** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **AppProject roles**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **AppProject roles**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AppProject roles** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 32 - Project-role naming is strict

- Lesson anchor: Current Argo expects project role subjects in the form: proj:<project-name:<role-name for those project-role policies to participate correctly in authorization. ([Argo CD][1]) Example: proj:todo-dev:developers not: todo-developers-whatever
- Beginner explanation: Restate **Project-role naming is strict** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Project-role naming is strict** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Project-role naming is strict**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Project-role naming is strict**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Project-role naming is strict** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 33 - Global RBAC vs Project roles

- Lesson anchor: Use this mental model: GLOBAL RBAC = Argo-wide privileges clusters repositories projects accounts applications across projects administrative operations PROJECT ROLE = permissions concerning Applications inside that Project
- Beginner explanation: Restate **Global RBAC vs Project roles** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Global RBAC vs Project roles** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Global RBAC vs Project roles**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Global RBAC vs Project roles**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Global RBAC vs Project roles** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 34 - A CI role example

- Lesson anchor: Suppose automation actually needs Argo sync permission. A Project role can be limited to: one project one application one action For example: roles: policies: p, proj:todo-dev:ci-sync, applications, sync, todo-dev/todo-backend-dev,
- Beginner explanation: Restate **A CI role example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **A CI role example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **A CI role example**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **A CI role example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **A CI role example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 35 - `sync` permission is narrower than `update`

- Lesson anchor: This is important. A user with: applications, sync can tell Argo: Reconcile this Application to the desired state already defined. But: applications, update can modify the Application specification itself. That could alter:
- Beginner explanation: Restate **`sync` permission is narrower than `update`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`sync` permission is narrower than `update`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **`sync` permission is narrower than `update`**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **`sync` permission is narrower than `update`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`sync` permission is narrower than `update`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 36 - `override` is especially dangerous

- Lesson anchor: Current Argo RBAC has an: override action which can allow a user to synchronize arbitrary manifests or a different revision instead of the normal configured source for a sync operation. Argo explicitly warns that this can completely change or delete the res...
- Beginner explanation: Restate **`override` is especially dangerous** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`override` is especially dangerous** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`override` is especially dangerous**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`override` is especially dangerous**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`override` is especially dangerous** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 37 - GitOps principle behind that restriction

- Lesson anchor: Normally: Git = desired state. An override says: For this sync, use something other than normal Git desired state. That's effectively an escape hatch from your usual GitOps control path. Treat it as privileged. ---
- Beginner explanation: Restate **GitOps principle behind that restriction** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **GitOps principle behind that restriction** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **GitOps principle behind that restriction**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **GitOps principle behind that restriction**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **GitOps principle behind that restriction** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 38 - `exec` is also privileged

- Lesson anchor: Argo RBAC includes: exec permissions. That can provide terminal-style access into application Pods through Argo when enabled/configured. Ask yourself: Does a developer who may deploy also need interactive shell access inside Production containers?
- Beginner explanation: Restate **`exec` is also privileged** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`exec` is also privileged** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **`exec` is also privileged**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **`exec` is also privileged**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`exec` is also privileged** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 39 - Logs vs exec

- Lesson anchor: A useful production separation might be: Developer: logs   ✓ exec   ✕ SRE: logs   ✓ exec   ✓ depending on your operational and compliance model. Debugging visibility does not automatically require interactive execution privilege.
- Beginner explanation: Restate **Logs vs exec** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Logs vs exec** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Logs vs exec**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Logs vs exec**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Logs vs exec** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 40 - Fine-grained resource RBAC

- Lesson anchor: Modern Argo CD also supports fine-grained application-resource update/delete actions. For example, current docs show patterns like: delete//Pod// to authorize deletion of Pods belonging to an Application without granting permission to delete the Application...
- Beginner explanation: Restate **Fine-grained resource RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Fine-grained resource RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Fine-grained resource RBAC**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Fine-grained resource RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Fine-grained resource RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 41 - Fine-grained example

- Lesson anchor: Conceptually: p, role:sre, applications, delete//Pod//, todo-prod/, allow but: p, role:sre, applications, delete, todo-prod/, deny This says: Delete child Pod: YES Delete Argo Application: NO Argo warns that glob matching does not treat / as a path separato...
- Beginner explanation: Restate **Fine-grained example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Fine-grained example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Fine-grained example**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Fine-grained example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Fine-grained example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 42 - `deny` usually wins

- Lesson anchor: For ordinary matched RBAC rules: ALLOW + DENY results in: DENY and policy ordering does not change that result. ([Argo CD][5]) But remember the special caveat: policy.default is evaluated first, and privileges granted by it cannot simply be taken away throu...
- Beginner explanation: Restate **`deny` usually wins** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`deny` usually wins** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **`deny` usually wins**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **`deny` usually wins**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`deny` usually wins** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 43 - RBAC object format

- Lesson anchor: For Applications stored in the normal: argocd control-plane namespace, policy objects usually follow: <project/<application Example: todo-prod/todo-backend-prod Current Argo RBAC uses this application-specific object format. ([Argo CD][5])
- Beginner explanation: Restate **RBAC object format** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RBAC object format** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **RBAC object format**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **RBAC object format**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RBAC object format** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 44 - Applications in any namespace

- Lesson anchor: Modern Argo can optionally allow Application CRs outside: argocd for stronger self-service/multi-tenancy patterns. This feature must be explicitly enabled, and Argo requires both a globally allowed application namespace and that the selected AppProject incl...
- Beginner explanation: Restate **Applications in any namespace** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Applications in any namespace** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Applications in any namespace**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Applications in any namespace**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Applications in any namespace** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 45 - Why Applications in any namespace exists

- Lesson anchor: Without this feature, application teams that want to manage Application CRs declaratively often need write access to: argocd namespace. That's dangerous. Current Argo documentation explicitly states that people with Kubernetes permissions to create/update A...
- Beginner explanation: Restate **Why Applications in any namespace exists** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why Applications in any namespace exists** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Why Applications in any namespace exists**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Why Applications in any namespace exists**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why Applications in any namespace exists** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 46 - Very important control-plane rule

- Lesson anchor: Do not casually grant ordinary application teams: write access to namespace: argocd The control-plane namespace contains powerful objects such as: Applications AppProjects repository credentials cluster credentials Argo configuration
- Beginner explanation: Restate **Very important control-plane rule** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Very important control-plane rule** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Very important control-plane rule**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Very important control-plane rule**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Very important control-plane rule** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 47 - `sourceNamespaces`

- Lesson anchor: Example: apiVersion: argoproj.io/v1alpha1 kind: AppProject metadata: name: todo-dev namespace: argocd spec: sourceNamespaces: Now an Application residing in: todo-team-gitops may use: project: todo-dev assuming that namespace is also globally enabled for Ap...
- Beginner explanation: Restate **`sourceNamespaces`** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **`sourceNamespaces`** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **`sourceNamespaces`**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **`sourceNamespaces`**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **`sourceNamespaces`** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 48 - Never attach a user-controlled namespace to a privileged Project

- Lesson anchor: Current Argo documentation explicitly warns not to add user-controlled namespaces to sourceNamespaces of privileged Projects such as an unrestricted/default-style Project, and not to grant the argocd control-plane namespace through this mechanism. ([Argo CD...
- Beginner explanation: Restate **Never attach a user-controlled namespace to a privileged Project** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never attach a user-controlled namespace to a privileged Project** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Never attach a user-controlled namespace to a privileged Project**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Never attach a user-controlled namespace to a privileged Project**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never attach a user-controlled namespace to a privileged Project** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 49 - Now introduce SSO

- Lesson anchor: So far our lab uses: admin with a local password. That is fine for bootstrapping. Production should usually become: Corporate Identity Provider │ ▼ Argo CD │ ▼ SSO groups │ ▼ Argo RBAC Argo currently supports two main SSO patterns: bundled Dex, which can br...
- Beginner explanation: Restate **Now introduce SSO** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Now introduce SSO** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Now introduce SSO**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Now introduce SSO**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Now introduce SSO** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 50 - Direct OIDC architecture

- Lesson anchor: Employee │ ▼ Corporate OIDC IdP │ ▼ ID token │ ├── subject ├── email └── groups │ ▼ Argo CD │ ▼ RBAC Argo can request OIDC scopes/claims such as groups and email and use configured scopes during RBAC enforcement. ([Argo CD][7])
- Beginner explanation: Restate **Direct OIDC architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Direct OIDC architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Direct OIDC architecture**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Direct OIDC architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Direct OIDC architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 51 - Dex architecture

- Lesson anchor: When the corporate provider doesn't fit direct OIDC requirements—or you need one of Dex's connector capabilities—the flow can be: Employee │ ▼ Corporate IdP │ ▼ Dex │ ▼ Argo CD │ ▼ RBAC Dex is bundled with Argo CD specifically to delegate authentication to...
- Beginner explanation: Restate **Dex architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Dex architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Dex architecture**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Dex architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Dex architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 52 - OIDC groups become authorization input

- Lesson anchor: Identity provider returns: groups: argocd-todo-developers argocd-prod-readers Argo RBAC: g, argocd-todo-developers, role:todo-dev g, argocd-prod-readers, role:todo-prod-readonly Therefore: Identity group membership ↓ Argo authorization.
- Beginner explanation: Restate **OIDC groups become authorization input** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **OIDC groups become authorization input** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **OIDC groups become authorization input**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **OIDC groups become authorization input**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **OIDC groups become authorization input** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 53 - Why group-based authorization is better

- Lesson anchor: Do not build production RBAC primarily as: vivek@example.com → role A alice@example.com → role A bob@example.com → role A Prefer: argocd-todo-developers → role A Then corporate identity lifecycle owns: joiner mover leaver
- Beginner explanation: Restate **Why group-based authorization is better** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why group-based authorization is better** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Why group-based authorization is better**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Why group-based authorization is better**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why group-based authorization is better** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 54 - AWS IAM Identity Center connection

- Lesson anchor: Since we already learned IAM Identity Center in Module 13, here's the connection. Current Argo documentation demonstrates AWS IAM Identity Center integration through: IAM Identity Center │ SAML │ ▼ Dex │ ▼ Argo CD and then maps Identity Center group informa...
- Beginner explanation: Restate **AWS IAM Identity Center connection** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AWS IAM Identity Center connection** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **AWS IAM Identity Center connection**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **AWS IAM Identity Center connection**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AWS IAM Identity Center connection** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 55 - Identity Center + Argo mental model

- Lesson anchor: From Module 13: IAM Identity Center = enterprise workforce identity/access Now: Identity Center group │ ▼ Dex │ ▼ Argo SSO identity │ ▼ Argo RBAC role │ ▼ AppProject boundary │ ▼ Kubernetes So the workforce identity plane connects into the GitOps authorizat...
- Beginner explanation: Restate **Identity Center + Argo mental model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Identity Center + Argo mental model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Identity Center + Argo mental model**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Identity Center + Argo mental model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Identity Center + Argo mental model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 56 - Built-in admin should become bootstrap-only

- Lesson anchor: Current Argo guidance recommends using the built-in: admin only for initial configuration and then switching to SSO or appropriately configured local users. Once alternative access is established, Argo recommends disabling the admin account with:
- Beginner explanation: Restate **Built-in admin should become bootstrap-only** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Built-in admin should become bootstrap-only** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Built-in admin should become bootstrap-only**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Built-in admin should become bootstrap-only**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Built-in admin should become bootstrap-only** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 57 - Don't disable admin before validating SSO

- Lesson anchor: Operational sequence: Configure SSO │ ▼ Test login │ ▼ Test admin-equivalent group │ ▼ Test ordinary roles │ ▼ Test emergency recovery │ ▼ THEN disable normal admin login Otherwise you can lock yourself out of Argo's API/UI control plane.
- Beginner explanation: Restate **Don't disable admin before validating SSO** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Don't disable admin before validating SSO** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Don't disable admin before validating SSO**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Don't disable admin before validating SSO**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Don't disable admin before validating SSO** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 58 - Production identity groups

- Lesson anchor: A clean enterprise model might contain: argocd-platform-admins argocd-sre argocd-security-readers argocd-todo-developers argocd-todo-prod-readers argocd-payments-developers argocd-payments-prod-operators Then Argo RBAC maps groups to capabilities.
- Beginner explanation: Restate **Production identity groups** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production identity groups** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Production identity groups**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Production identity groups**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production identity groups** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 59 - Three teams example

- Lesson anchor: Imagine: Todo Team Payments Team Platform Team Todo Project permits: todo-gitops todo- namespaces Payments Project permits: payments-gitops payments- namespaces Platform Project permits: platform-gitops platform namespaces
- Beginner explanation: Restate **Three teams example** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Three teams example** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Three teams example**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Three teams example**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Three teams example** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 60 - Developer attack scenario #1

- Lesson anchor: Todo developer changes: destination: namespace: payments-prod AppProject: Todo destinations: todo-prod only Result: DENIED. Even though: developer can edit Todo Git. ---
- Beginner explanation: Restate **Developer attack scenario #1** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Developer attack scenario #1** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Developer attack scenario #1**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Developer attack scenario #1**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Developer attack scenario #1** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 61 - Attack scenario #2

- Lesson anchor: Todo developer changes: repoURL: attacker.example.com/malicious.git AppProject: Approved source: company/todo-gitops Result: DENIED. ---
- Beginner explanation: Restate **Attack scenario #2** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Attack scenario #2** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Attack scenario #2**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Attack scenario #2**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Attack scenario #2** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 62 - Attack scenario #3

- Lesson anchor: Todo Git adds: apiVersion: rbac.authorization.k8s.io/v1 kind: ClusterRole ... Todo Project: Cluster-scoped allowlist: Namespace/todo-prod only Result: DENIED. This demonstrates why AppProject isn't simply an organizational label.
- Beginner explanation: Restate **Attack scenario #3** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Attack scenario #3** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Attack scenario #3**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Attack scenario #3**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Attack scenario #3** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 63 - Attack scenario #4

- Lesson anchor: Developer can: applications, sync but not: applications, update They can deploy the already-reviewed desired state. They cannot change the Argo Application to point at: another source another destination another Project through Argo's API.
- Beginner explanation: Restate **Attack scenario #4** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Attack scenario #4** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Attack scenario #4**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Attack scenario #4**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Attack scenario #4** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 64 - Attack scenario #5 — CI compromise

- Lesson anchor: Our CI bot can: write Dev Git but has: no Argo admin credential no Kubernetes credential no production merge privilege. Even if compromised, the attacker must cross additional controls before Production. This is why our CI → Git → Argo separation from Lesso...
- Beginner explanation: Restate **Attack scenario #5 — CI compromise** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Attack scenario #5 — CI compromise** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Attack scenario #5 — CI compromise**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Attack scenario #5 — CI compromise**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Attack scenario #5 — CI compromise** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 65 - Attack scenario #6 — user has Kubernetes access directly

- Lesson anchor: Important: AppProject only governs deployment through Argo. If an engineer separately has: kubectl cluster-admin they can bypass Argo and modify Kubernetes directly. Argo Projects do not replace Kubernetes RBAC. That's why we need:
- Beginner explanation: Restate **Attack scenario #6 — user has Kubernetes access directly** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Attack scenario #6 — user has Kubernetes access directly** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Attack scenario #6 — user has Kubernetes access directly**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Attack scenario #6 — user has Kubernetes access directly**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Attack scenario #6 — user has Kubernetes access directly** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 66 - Kubernetes RBAC is the final authority

- Lesson anchor: Suppose AppProject says: Deployment allowed. But Argo's cluster credential lacks: create deployments Kubernetes says: Forbidden. Result: SYNC FAILED. AppProject permission does not grant Kubernetes API permissions. Argo's own security guidance notes that Ar...
- Beginner explanation: Restate **Kubernetes RBAC is the final authority** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Kubernetes RBAC is the final authority** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Kubernetes RBAC is the final authority**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Kubernetes RBAC is the final authority**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Kubernetes RBAC is the final authority** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 67 - Defense-in-depth model

- Lesson anchor: Suppose an AppProject is accidentally too broad. Kubernetes RBAC can still restrict: what Argo's ServiceAccount may actually write. Likewise, if Kubernetes RBAC is broad: AppProject can still restrict what legitimate Argo Applications are permitted to request.
- Beginner explanation: Restate **Defense-in-depth model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Defense-in-depth model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Defense-in-depth model**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Defense-in-depth model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Defense-in-depth model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 68 - Example Argo cluster privilege model

- Lesson anchor: Instead of: Argo: cluster-admin everywhere a mature setup may have: Cluster-wide read as required for reconciliation + write only to managed namespaces/resources depending on architecture. Argo's current security documentation explicitly notes that full clu...
- Beginner explanation: Restate **Example Argo cluster privilege model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example Argo cluster privilege model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Example Argo cluster privilege model**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Example Argo cluster privilege model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example Argo cluster privilege model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 69 - AppProject does not protect repository writes

- Lesson anchor: Project says: todo-gitops is trusted. It does not answer: Who may push to todo-gitops? That's Git provider security. So our security chain is: Git Authorization │ ▼ AppProject │ ▼ Argo RBAC │ ▼ Kubernetes Authorization Every layer matters.
- Beginner explanation: Restate **AppProject does not protect repository writes** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AppProject does not protect repository writes** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **AppProject does not protect repository writes**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **AppProject does not protect repository writes**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AppProject does not protect repository writes** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 70 - Production privilege matrix

- Lesson anchor: This isn't a universal policy. It's a useful separation-of-duties starting point. ---
- Beginner explanation: Restate **Production privilege matrix** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production privilege matrix** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Production privilege matrix**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Production privilege matrix**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production privilege matrix** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 71 - Lock down the default Project later

- Lesson anchor: Once all real Applications have been moved to dedicated Projects, current Argo docs show that the default Project can be reduced to essentially no useful deployment permissions. ([Argo CD][1]) Conceptually: apiVersion: argoproj.io/v1alpha1
- Beginner explanation: Restate **Lock down the default Project later** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Lock down the default Project later** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Lock down the default Project later**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Lock down the default Project later**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Lock down the default Project later** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 72 - Why default lockdown matters

- Lesson anchor: Otherwise future engineer creates: spec: project: default and accidentally falls back into: unrestricted project. If default is locked down: forgetting to choose a proper Project fails safely. This is: ---
- Beginner explanation: Restate **Why default lockdown matters** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Why default lockdown matters** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Why default lockdown matters**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Why default lockdown matters**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Why default lockdown matters** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 73 - Project-scoped cluster boundaries

- Lesson anchor: Current AppProject specifications also expose: permitOnlyProjectScopedClusters: true for architectures where Applications in a Project should only use clusters specifically scoped to that Project rather than any globally registered destination that happens...
- Beginner explanation: Restate **Project-scoped cluster boundaries** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Project-scoped cluster boundaries** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Project-scoped cluster boundaries**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Project-scoped cluster boundaries**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Project-scoped cluster boundaries** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 74 - SSO scopes

- Lesson anchor: Argo RBAC's: scopes: controls which OIDC claims, beyond the subject, participate in authorization. If omitted, current Argo defaults to examining the groups scope; configurations can also include things such as email. ([Argo CD][5])
- Beginner explanation: Restate **SSO scopes** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SSO scopes** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **SSO scopes**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **SSO scopes**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SSO scopes** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 75 - Group claims troubleshooting

- Lesson anchor: Engineer logs in but gets: PermissionDenied. Do not immediately edit RBAC. Check this path: IdP user │ ▼ IdP group membership │ ▼ OIDC/SAML claim │ ▼ Argo scope configuration │ ▼ group → role mapping │ ▼ role policy │ ▼ AppProject
- Beginner explanation: Restate **Group claims troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Group claims troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Group claims troubleshooting**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Group claims troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Group claims troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 76 - SSO authentication troubleshooting

- Lesson anchor: For SSO login failures, separate: Authentication failure from: Authorization failure. Authentication failure: cannot log in callback error issuer error client issue token validation issue Authorization failure: login works
- Beginner explanation: Restate **SSO authentication troubleshooting** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SSO authentication troubleshooting** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **SSO authentication troubleshooting**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **SSO authentication troubleshooting**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SSO authentication troubleshooting** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 77 - RBAC troubleshooting mnemonic

- Lesson anchor: Use: I IDENTITY Who logged in? C CLAIMS Which groups/email/sub did Argo receive? G GROUP Does group map to role? R ROLE Which Argo role? P POLICY Does policy allow action? A APP PROJECT Is Application itself permitted? K
- Beginner explanation: Restate **RBAC troubleshooting mnemonic** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RBAC troubleshooting mnemonic** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **RBAC troubleshooting mnemonic**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **RBAC troubleshooting mnemonic**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RBAC troubleshooting mnemonic** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 78 - Example: user can view but not sync

- Lesson anchor: User: login ✓ application visible ✓ sync ✕ This strongly suggests: authentication works. Then inspect: applications, sync RBAC permission. Not: OIDC client secret. ---
- Beginner explanation: Restate **Example: user can view but not sync** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: user can view but not sync** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Example: user can view but not sync**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Example: user can view but not sync**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: user can view but not sync** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 79 - Example: user can sync Dev but not Prod

- Lesson anchor: That's often exactly correct. Check: Dev: role mapping contains sync Prod: role mapping contains get only. Do not "fix" intentional least privilege. ---
- Beginner explanation: Restate **Example: user can sync Dev but not Prod** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: user can sync Dev but not Prod** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Example: user can sync Dev but not Prod**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Example: user can sync Dev but not Prod**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: user can sync Dev but not Prod** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 80 - Example: Project says destination invalid

- Lesson anchor: Application: Permission denied? No. If Argo says the Application destination/source is not permitted by Project, your human RBAC might be completely fine. This is: AppProject policy failure not: user authorization failure.
- Beginner explanation: Restate **Example: Project says destination invalid** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: Project says destination invalid** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Example: Project says destination invalid**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Example: Project says destination invalid**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: Project says destination invalid** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 81 - Example: sync returns Kubernetes forbidden

- Lesson anchor: Application: source valid       ✓ destination valid  ✓ Project valid      ✓ Argo user sync     ✓ but Kubernetes responds: forbidden: cannot create resource Now inspect: Argo cluster credentials ServiceAccount Role ClusterRole
- Beginner explanation: Restate **Example: sync returns Kubernetes forbidden** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: sync returns Kubernetes forbidden** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Example: sync returns Kubernetes forbidden**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Example: sync returns Kubernetes forbidden**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: sync returns Kubernetes forbidden** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 82 - Example: manifests contain forbidden ClusterRole

- Lesson anchor: Repository renders correctly. Human can sync. Kubernetes credentials might even have permission. But AppProject says: ClusterRole not allowed. That's exactly what we want: Project policy stops the request before broad Kubernetes authority
- Beginner explanation: Restate **Example: manifests contain forbidden ClusterRole** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: manifests contain forbidden ClusterRole** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Example: manifests contain forbidden ClusterRole**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Example: manifests contain forbidden ClusterRole**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: manifests contain forbidden ClusterRole** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 83 - Example: hidden remote dependency bypasses source expectation

- Lesson anchor: Todo Project trusts: company/todo-gitops. Application passes Project source validation. But that Git repo references: Kustomize remote base: unknown/privileged-base The initial repository allowlist does not automatically block every transitive Kustomize/Hel...
- Beginner explanation: Restate **Example: hidden remote dependency bypasses source expectation** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Example: hidden remote dependency bypasses source expectation** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Example: hidden remote dependency bypasses source expectation**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Example: hidden remote dependency bypasses source expectation**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Example: hidden remote dependency bypasses source expectation** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 84 - Git repository write access is deployment privilege

- Lesson anchor: Argo's current security guide explicitly warns that unauthorized write access to a trusted Git repository can be used to alter images, resources, or delete manifests that Argo may then prune. ([Argo CD][4]) So: GitOps Repo Writer
- Beginner explanation: Restate **Git repository write access is deployment privilege** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Git repository write access is deployment privilege** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Git repository write access is deployment privilege**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Git repository write access is deployment privilege**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Git repository write access is deployment privilege** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 85 - Production Argo security architecture

- Lesson anchor: A strong design looks like: CORPORATE IdP │ MFA / workforce policy │ ▼ ARGO SSO │ ▼ GROUPS │ ▼ ARGO RBAC │ ▼ AppProject │ ┌─────────────┼─────────────┐ ▼             ▼             ▼ Source Repos   Destinations   Resource Kinds
- Beginner explanation: Restate **Production Argo security architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production Argo security architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Production Argo security architecture**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Production Argo security architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production Argo security architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 86 - What we should eventually do with our Todo architecture

- Lesson anchor: We will end up with Projects like: todo-dev todo-prod platform instead of putting everything under: default. Then: Todo Developers │ ├── Dev get/sync/logs └── Prod get/logs SRE │ └── Prod get/sync/logs Platform │ └── Project/cluster/repository administration
- Beginner explanation: Restate **What we should eventually do with our Todo architecture** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **What we should eventually do with our Todo architecture** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **What we should eventually do with our Todo architecture**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **What we should eventually do with our Todo architecture**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **What we should eventually do with our Todo architecture** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 87 - Interview — AppProject vs Argo RBAC

- Lesson anchor: Strong answer: Argo RBAC controls what authenticated users or groups may do through Argo CD, such as viewing, syncing, updating, or deleting Applications. AppProject constrains the Applications themselves by defining which source repositories, destination c...
- Beginner explanation: Restate **Interview — AppProject vs Argo RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — AppProject vs Argo RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — AppProject vs Argo RBAC**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — AppProject vs Argo RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — AppProject vs Argo RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 88 - Interview — AppProject vs Kubernetes RBAC

- Lesson anchor: Strong answer: AppProject is an Argo policy layer; it does not grant Kubernetes API permissions. Kubernetes RBAC remains the actual cluster authorization mechanism for Argo's credentials. Therefore a Project can permit an operation while Kubernetes still re...
- Beginner explanation: Restate **Interview — AppProject vs Kubernetes RBAC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — AppProject vs Kubernetes RBAC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — AppProject vs Kubernetes RBAC**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — AppProject vs Kubernetes RBAC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — AppProject vs Kubernetes RBAC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 89 - Interview — What does `sourceRepos` do?

- Lesson anchor: It restricts which initial source repositories Applications in the Project may use. Argo supports allow and negated deny patterns. ([Argo CD][1]) But the senior addition is: It does not by itself constrain every transitive Helm dependency or Kustomize remot...
- Beginner explanation: Restate **Interview — What does `sourceRepos` do?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — What does `sourceRepos` do?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — What does `sourceRepos` do?**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — What does `sourceRepos` do?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — What does `sourceRepos` do?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 90 - Interview — Why lock down `default`?

- Lesson anchor: Because Argo's default Project begins broadly permissive. Once dedicated Projects exist, reducing the default Project's permissions prevents accidentally unclassified Applications from inheriting broad deployment authority. ([Argo CD][1])
- Beginner explanation: Restate **Interview — Why lock down `default`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Why lock down `default`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — Why lock down `default`?**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — Why lock down `default`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Why lock down `default`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 91 - Interview — `role:readonly` vs custom default role

- Lesson anchor: role:readonly is an Argo-wide built-in read-only role. In strict multi-tenancy, even global read access may be too broad, so a custom minimal policy.default role is often preferable. Additionally, permissions inherited from policy.default cannot be removed...
- Beginner explanation: Restate **Interview — `role:readonly` vs custom default role** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — `role:readonly` vs custom default role** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — `role:readonly` vs custom default role**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — `role:readonly` vs custom default role**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — `role:readonly` vs custom default role** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 92 - Interview — Does deny win?

- Lesson anchor: For ordinary matched policies: yes. A matching deny has priority over matching allow, regardless of ordering. ([Argo CD][5]) But mention: policy.default as the special caveat. That's a strong interview answer. ---
- Beginner explanation: Restate **Interview — Does deny win?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Does deny win?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Does deny win?**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Does deny win?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Does deny win?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 93 - Interview — Why is `override` dangerous?

- Lesson anchor: Because it permits synchronization using arbitrary manifests or revisions outside the normal configured desired source for that operation. Argo explicitly warns it can completely change/delete deployed resources. ([Argo CD][5])
- Beginner explanation: Restate **Interview — Why is `override` dangerous?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Why is `override` dangerous?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Interview — Why is `override` dangerous?**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Interview — Why is `override` dangerous?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Why is `override` dangerous?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 94 - Interview — Why SSO groups instead of local users?

- Lesson anchor: Argo supports local accounts, but its own user-management guidance recommends SSO when you need richer identity features such as groups and centralized identity management. SSO group claims can be mapped directly into Argo RBAC roles. ([Argo CD][7])
- Beginner explanation: Restate **Interview — Why SSO groups instead of local users?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Why SSO groups instead of local users?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Interview — Why SSO groups instead of local users?**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Interview — Why SSO groups instead of local users?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Why SSO groups instead of local users?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 95 - Interview — Dex vs direct OIDC

- Lesson anchor: Strong answer: Use direct OIDC when the organization's identity provider already provides the OIDC integration and claims Argo needs. Dex is useful when bridging protocols/providers such as SAML or LDAP, or when Dex-specific connector capabilities are usefu...
- Beginner explanation: Restate **Interview — Dex vs direct OIDC** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Dex vs direct OIDC** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **Interview — Dex vs direct OIDC**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **Interview — Dex vs direct OIDC**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Dex vs direct OIDC** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 96 - Interview — Should normal engineers use `admin`?

- Lesson anchor: No. Argo recommends using the built-in admin for initial configuration and switching to SSO or scoped accounts afterward; the built-in admin can then be disabled. ([Argo CD][7]) ---
- Beginner explanation: Restate **Interview — Should normal engineers use `admin`?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Should normal engineers use `admin`?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **Interview — Should normal engineers use `admin`?**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **Interview — Should normal engineers use `admin`?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Should normal engineers use `admin`?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 97 - Interview — Why is write access to `argocd` namespace dangerous?

- Lesson anchor: Because declarative Application/AppProject access there can give users control over Argo's own high-privilege control-plane resources. Current Argo documentation says users able to create/update Applications in the argocd control-plane namespace should effe...
- Beginner explanation: Restate **Interview — Why is write access to `argocd` namespace dangerous?** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Why is write access to `argocd` namespace dangerous?** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **Interview — Why is write access to `argocd` namespace dangerous?**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **Interview — Why is write access to `argocd` namespace dangerous?**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Why is write access to `argocd` namespace dangerous?** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 98 - Interview — Applications in any namespace

- Lesson anchor: Strong answer: Argo can optionally reconcile Application CRs outside its control-plane namespace. The namespace must be globally enabled and also allowed by the chosen AppProject's sourceNamespaces. This enables safer application-team self-service without g...
- Beginner explanation: Restate **Interview — Applications in any namespace** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Interview — Applications in any namespace** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Interview — Applications in any namespace**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Interview — Applications in any namespace**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Interview — Applications in any namespace** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 99 - Production checklist

- Lesson anchor: Before calling a shared Argo installation multi-tenant, verify all of the following: ---
- Beginner explanation: Restate **Production checklist** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Production checklist** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison focused on **Production checklist**.
- Failure exercise: In an isolated environment, break repository authentication, manifest rendering, a required CRD, or destination selection while observing the boundaries around **Production checklist**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Production checklist** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 100 - Never-forget security model

- Lesson anchor: Memorize: IDENTITY = Who are you? ARGO RBAC = What can YOU do? APP PROJECT = What can the APPLICATION do? KUBERNETES RBAC = What can ARGO actually do? GIT SECURITY = Who can change desired state? And the most important equation:
- Beginner explanation: Restate **Never-forget security model** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Never-forget security model** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a sync-wave, resource-hook, or progressive-delivery execution and health report focused on **Never-forget security model**.
- Failure exercise: In an isolated environment, make a sync hook, health check, canary analysis, or rollback condition fail safely while observing the boundaries around **Never-forget security model**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Never-forget security model** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 101 - AppProject never-forget rules

- Lesson anchor: AppProject does NOT grant access. It constrains deployment. sourceRepos = where manifests may originate. destinations = where they may run. clusterResourceWhitelist = which cluster-wide resources may be created. namespaceResourceBlacklist /
- Beginner explanation: Restate **AppProject never-forget rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **AppProject never-forget rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a multi-cluster, RBAC, SSO, secret-delivery, backup, or recovery validation bundle focused on **AppProject never-forget rules**.
- Failure exercise: In an isolated environment, remove one cluster, API server, repo-server, cache, or controller dependency while observing the boundaries around **AppProject never-forget rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **AppProject never-forget rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 102 - RBAC never-forget rules

- Lesson anchor: p = POLICY g = GROUP / ROLE MAPPING role:admin = unrestricted role:readonly = global read-only policy.default = permission floor normal deny  normal allow sync != update update != override logs != exec Current Argo RBAC separates these resources/actions exp...
- Beginner explanation: Restate **RBAC never-forget rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **RBAC never-forget rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD metrics, notification, incident timeline, and troubleshooting record focused on **RBAC never-forget rules**.
- Failure exercise: In an isolated environment, test a secret, RBAC, promotion, project-boundary, or target-cluster misconfiguration while observing the boundaries around **RBAC never-forget rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **RBAC never-forget rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 103 - SSO never-forget rules

- Lesson anchor: SSO = authentication Group claims = authorization input OIDC provider or Dex = identity bridge Argo RBAC = final Argo role decision And: SSO success does NOT automatically mean authorization success. Argo separates external identity integration from its RBA...
- Beginner explanation: Restate **SSO never-forget rules** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **SSO never-forget rules** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce an Argo CD Application, AppProject, or ApplicationSet manifest with rendered-output evidence focused on **SSO never-forget rules**.
- Failure exercise: In an isolated environment, introduce controlled out-of-band drift and observe detection, reconciliation, and audit evidence while observing the boundaries around **SSO never-forget rules**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **SSO never-forget rules** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Concept card 104 - Troubleshooting flow

- Lesson anchor: Use: IDENTITY │ ▼ CLAIMS │ ▼ GROUP │ ▼ ROLE │ ▼ POLICY │ ▼ APP PROJECT │ ▼ KUBERNETES RBAC or: Examples: Can't log in → I / C Logged in but PermissionDenied → G / R / P Destination not permitted → A Kubernetes says forbidden
- Beginner explanation: Restate **Troubleshooting flow** using a household, workplace, or public-service analogy without hiding the technical truth.
- Terminology check: Define every important noun, state, actor, and boundary before using abbreviations.
- Concrete example: Apply **Troubleshooting flow** to a small todo, checkout, or platform service and name the expected outcome.
- Intermediate connection: Draw the request, data, identity, and control flow that reaches this concept.
- Trade-off question: Compare at least two valid alternatives and state when each becomes the better choice.
- Expert edge case: Describe concurrency, retry, partial failure, scale, or stale-state behavior that a happy-path explanation misses.
- Hands-on artifact: Produce a Git promotion commit, pull-request review, sync result, and rollback record focused on **Troubleshooting flow**.
- Failure exercise: In an isolated environment, simulate an unsafe prune, rename, or orphaned resource and exercise the documented containment path while observing the boundaries around **Troubleshooting flow**.
- Security review: Identify identity, authorization, sensitive-data, supply-chain, and abuse assumptions.
- Reliability review: Define the user-visible failure, containment, degraded mode, recovery, and final validation.
- Performance and cost review: Name the load driver, capacity limit, useful unit, and waste or amplification risk.
- Observability review: Specify the metric, structured event, trace boundary, change marker, and missing-data behavior.
- Professional decision: Record context, options, decision, consequences, owner, evidence, and revisit trigger.
- Certification checkpoint: Map the evidence to current Argo CD, GitOps, Kubernetes, CNCF, or cloud certification objectives, and verify changing behavior in official documentation.
- Interview prompt: Explain **Troubleshooting flow** first in 30 seconds, then defend it in a five-minute system scenario.
- Strong-answer rubric: lead with outcome, state assumptions, explain mechanism, discuss failure and security, then validate with evidence.
- Completion evidence: retain the artifact, commands or query, observed failure, safe recovery, and one improvement.

### Practice case 001 - The four authorization layers x operability

- Learning level: Beginner.
- Environment: a shared nonproduction cluster.
- Scenario: The team must apply **The four authorization layers** while a change involving **What does an AppProject actually protect?** places **operability** at risk.
- Plain-language question: What problem does **The four authorization layers** solve here, and who notices first when it fails?
- Lesson evidence anchor: Keep this architecture permanently: HUMAN / CI │ ▼ ┌──────────────┐ │ Identity/SSO │ └──────┬───────┘ │ WHO ARE YOU? │ ▼ ┌──────────┐ │ Argo RBAC│ └────┬─────┘ │ WHAT MAY YOU DO? │ ▼ ┌────────────┐ │ AppProject │ └─────┬──────┘
- Objective: Preserve a measurable user or business outcome while making the operability decision explicit.
- Assumptions to write first: traffic or work volume, data sensitivity, ownership, environment, failure domain, and acceptable risk.
- Diagram task: Mark actors, source of truth, synchronous and asynchronous paths, identity, data, control plane, and recovery boundary.
- Hands-on build: Produce a Helm or Kustomize render, schema validation, diff, and environment comparison and link it to this practice case ID.
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
- Interview prompt: Defend **The four authorization layers** against an alternative while protecting operability under this scenario.
- Strong-answer outline: clarify requirements; draw the mechanism; quantify scale; cover security and failure; choose; validate; state limitation.
- Common mistake to avoid: naming a tool, replica count, dashboard, or discount as proof without demonstrating the end-to-end outcome.
- Completion rule: another learner can reproduce the safe test, explain the evidence, and reach the same conclusion without private coaching.

## Workbook completion review

- Practice cases generated for this lesson: 1.
- Select at least one case at every learning level and one case for every concept card.
- Complete at least one controlled failure, one security review, one recovery proof, one cost or capacity analysis, and one oral defense.
- Revisit any case where the result depended on an unstated assumption, unverified documentation, unsafe access, or a dashboard without authoritative evidence.
- The workbook is complete only when explanations remain correct in plain language and decisions remain defensible under realistic production constraints.

<!-- GENERATED-MASTERY-WORKBOOK:END -->

[1]: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/ "Projects - Argo CD - Declarative GitOps CD for Kubernetes"
[2]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/ "Overview - Argo CD - Declarative GitOps CD for Kubernetes"
[3]: https://argo-cd.readthedocs.io/en/stable/operator-manual/project-specification/ "Project Specification Reference - Argo CD - Declarative GitOps CD for Kubernetes"
[4]: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/?utm_source=chatgpt.com "Security - Argo CD - Read the Docs"
[5]: https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/ "RBAC Configuration - Argo CD - Declarative GitOps CD for Kubernetes"
[6]: https://argo-cd.readthedocs.io/en/latest/operator-manual/app-any-namespace/ "Applications in any namespace - Argo CD - Declarative GitOps CD for Kubernetes"
[7]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/?utm_source=chatgpt.com "Overview - Argo CD - Declarative GitOps CD for Kubernetes"
[8]: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/identity-center/ "Identity Center (AWS SSO) - Argo CD - Declarative GitOps CD for Kubernetes"
