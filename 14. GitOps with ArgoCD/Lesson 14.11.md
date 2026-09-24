# Module 14 — GitOps with Argo CD

## Lesson 11: Secrets Management — External Secrets, AWS Secrets Manager, Sealed Secrets & Vault

We have reached one of the most important GitOps architecture problems.

Our GitOps model says:

```text
Git
=
source of truth
```

But production also needs:

```text
Database passwords

API keys

OAuth client secrets

TLS private keys

Webhook secrets

Third-party tokens

Registry credentials
```

Should those values live in Git?

```text
NO.
```

The correct model is:

```text
Git
=
secret intent/reference

External secret system
=
actual secret value
```

For our AWS production architecture, the primary design will be:

```text
                         GIT
                          │
                          ▼
                   ExternalSecret
                          │
                          ▼
               External Secrets Operator
                          │
                  AWS IAM identity
                          │
                          ▼
                 AWS Secrets Manager
                          │
                          ▼
                  Kubernetes Secret
                          │
                          ▼
                       Pod
```

Current Argo CD guidance strongly recommends this **destination-cluster secret-management model**. Argo specifically lists External Secrets Operator, Sealed Secrets, Kubernetes Secrets Store CSI, and Vault Secrets Operator as examples. It cautions against injecting secrets during Argo manifest generation because that gives Argo access to secret values and can expose generated secret-containing manifests in its Redis cache. ([Argo CD][1])

---

# 14.1359 First: the GitOps secret paradox

Consider:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: todo-db

data:
  password: c3VwZXJzZWNyZXQ=
```

Someone says:

> "It's safe because Kubernetes Secrets use base64."

No.

Decode:

```bash
echo 'c3VwZXJzZWNyZXQ=' | base64 -d
```

Result:

```text
supersecret
```

Base64 is:

```text
ENCODING
```

not:

```text
ENCRYPTION.
```

Kubernetes' own security guidance notes that Secret values use base64 representation and that Secrets should be protected with encryption at rest, least-privilege RBAC, restricted workload access, and—in suitable architectures—external secret stores. ([Kubernetes][2])

Permanent rule:

> **Base64 protects formatting, not confidentiality.**

---

# 14.1360 Why committing a Kubernetes Secret is dangerous

Imagine:

```text
Git commit A
```

contains:

```text
Production DB password:
abc123
```

You later remove it:

```text
Git commit B
```

Does the password disappear from Git history?

```text
NO.
```

It may remain in:

```text
old commits

developer clones

forks

CI caches

pull-request diffs

backup systems

Git provider audit/history systems
```

So:

```text
git rm secret.yaml
```

does not undo credential compromise.

If a real credential is committed:

```text
ROTATE IT.
```

Do not merely delete the file.

---

# 14.1361 Secret leakage response

If a production credential enters Git:

```text
1. Treat credential as compromised.

2. Revoke/rotate it.

3. Update dependent system.

4. Determine exposure window.

5. Remove it from current Git state.

6. Consider history remediation.

7. Review logs/audit activity.

8. Add secret scanning/prevention.

9. Document incident.
```

Never do only:

```text
git commit -m "remove password"
```

and consider the incident resolved.

---

# 14.1362 ConfigMap vs Secret

Permanent distinction:

```text
ConfigMap
=
non-confidential configuration
```

Examples:

```text
LOG_LEVEL=info

ENVIRONMENT=prod

API_TIMEOUT=5
```

while:

```text
Secret
=
confidential information
```

Examples:

```text
DATABASE_PASSWORD

JWT_SIGNING_KEY

API_TOKEN
```

Kubernetes defines ConfigMaps specifically for non-confidential configuration, while Secrets are intended for confidential data. ([Kubernetes][3])

---

# 14.1363 Native Kubernetes Secret flow

Without an external secret manager:

```text
Git / Engineer
       │
       ▼
Kubernetes Secret
       │
       ▼
Kubernetes API
       │
       ▼
etcd / API storage
       │
       ▼
Pod
```

Applications can consume the Secret through:

```text
environment variables

mounted files

imagePullSecrets

other Kubernetes object references.
```

Kubernetes supports these normal Secret-consumption mechanisms. ([Kubernetes][2])

---

# 14.1364 Kubernetes Secret security still matters with External Secrets

External Secrets Operator does **not** eliminate Kubernetes Secrets if you use its normal synchronization model.

It changes:

```text
WHO creates and refreshes the Kubernetes Secret.
```

Flow:

```text
AWS Secrets Manager
        │
        ▼
ESO
        │
        ▼
Kubernetes Secret
        │
        ▼
Pod
```

Therefore you still need:

```text
Kubernetes Secret RBAC

encryption at rest

namespace isolation

Pod security

least privilege
```

Kubernetes explicitly recommends encryption at rest and least-privilege access to Secret objects. ([Kubernetes][2])

---

# 14.1365 Secret ownership mental model

We need to distinguish three objects:

```text
AWS Secrets Manager Secret
```

actual external value.

```text
ExternalSecret
```

instruction saying:

> Fetch this external secret and create/update a Kubernetes Secret.

```text
Kubernetes Secret
```

runtime copy consumed by the Pod.

Architecture:

```text
Secrets Manager
    │
    │ source value
    ▼
ExternalSecret Controller
    │
    │ reconciles
    ▼
Kubernetes Secret
    │
    ▼
Application
```

External Secrets Operator's purpose is precisely to synchronize secret data from external APIs into Kubernetes Secrets. ([External Secrets][4])

---

# 14.1366 What lives in Git?

Good Git:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret

metadata:
  name: todo-backend

spec:

  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore

  target:
    name: todo-backend-secret

  data:

    - secretKey: MONGODB_URI

      remoteRef:
        key: production/todo/backend
        property: mongodb_uri
```

Git knows:

```text
Secret Store:
aws-secretsmanager

Remote secret:
production/todo/backend

Property:
mongodb_uri

Kubernetes target:
todo-backend-secret
```

Git does **not** know:

```text
mongodb://prod-user:actual-password@...
```

That's our goal.

---

# 14.1367 Argo's role in this model

Argo deploys:

```text
ExternalSecret
```

not:

```text
secret value.
```

Flow:

```text
Git
 │
 ▼
Argo
 │
 ▼
ExternalSecret CR
 │
 ▼
ESO
 │
 ▼
AWS Secrets Manager
 │
 ▼
Kubernetes Secret
```

So:

```text
Argo
=
deploys secret request
```

while:

```text
ESO
=
retrieves secret
```

This is exactly the separation current Argo secret-management guidance recommends. ([Argo CD][1])

---

# 14.1368 Why this is better

Argo does not need:

```text
secretsmanager:GetSecretValue
```

for application secrets.

ESO needs that permission.

This dramatically reduces Argo's secret blast radius:

```text
Argo compromise
```

does not automatically imply:

```text
access to every external secret backend
```

through Argo's manifest-generation identity.

Current Argo documentation calls this separation one of the principal security advantages of destination-cluster secret management. ([Argo CD][1])

---

# 14.1369 Manifest-generation secret injection — avoid for new architecture

Another approach is:

```text
Git encrypted/reference data
       │
       ▼
Argo repo-server
       │
       ▼
plugin gets secret
       │
       ▼
render Kubernetes Secret
       │
       ▼
Application Controller
```

Examples historically include:

```text
argocd-vault-plugin
```

and similar CMP approaches.

Current Argo documentation **strongly cautions** against this style for new designs because Argo must access the secret during manifest generation, rendered secret values can exist in its plaintext manifest/cache path, and secret rotation becomes tied more closely to app sync. ([Argo CD][1])

So for our production architecture:

```text
DESTINATION-SIDE SECRET OPERATOR
>
ARGO MANIFEST-TIME SECRET INJECTION
```

unless a specific constraint justifies otherwise.

---

# 14.1370 External Secrets Operator objects

Core ESO objects include:

```text
ExternalSecret

SecretStore

ClusterSecretStore
```

ESO runs inside Kubernetes and reconciles these CRDs into Kubernetes Secrets. ([External Secrets][5])

Mental model:

```text
SecretStore
=
HOW do we access provider?


ExternalSecret
=
WHAT secret do we want?


Kubernetes Secret
=
WHERE does runtime value appear?
```

---

# 14.1371 SecretStore

A `SecretStore` is:

```text
NAMESPACED.
```

It describes access to one external secret provider and is bound to its namespace. A `SecretStore` cannot simply be referenced cross-namespace. ([External Secrets][6])

Example:

```text
namespace:
todo-prod

SecretStore:
aws-todo-prod
```

can be used by ExternalSecrets in:

```text
todo-prod.
```

That is a strong natural tenancy boundary.

---

# 14.1372 ClusterSecretStore

A `ClusterSecretStore` is:

```text
CLUSTER-SCOPED.
```

It can be referenced by ExternalSecrets in multiple namespaces. ([External Secrets][7])

Architecture:

```text
ClusterSecretStore
      │
 ┌────┼─────┐
 ▼    ▼     ▼

Todo Payments Analytics
```

Useful.

But much larger blast radius.

---

# 14.1373 SecretStore vs ClusterSecretStore

Use this mental rule:

```text
SecretStore

=
namespace/team specific
```

while:

```text
ClusterSecretStore

=
shared platform-level provider access.
```

A `ClusterSecretStore` is convenient, but ESO's own security guidance emphasizes restricting access to cluster-scoped ESO resources such as `ClusterSecretStore`, because the operator often has broad abilities over Secrets across namespaces. ([External Secrets][8])

For strongly isolated workloads, prefer:

```text
namespaced SecretStore
+
narrow IAM permissions
```

unless shared infrastructure genuinely requires cluster-wide configuration.

---

# 14.1374 ESO is itself highly privileged

This is easy to overlook.

The operator may need to:

```text
read external secret systems

create/update Kubernetes Secrets

operate across many namespaces.
```

ESO's security best-practices documentation explicitly warns that a cluster-wide deployment has elevated privileges and recommends restricting access to ESO resources and considering scoped deployment/RBAC where appropriate. ([External Secrets][8])

Therefore:

```text
ExternalSecret creation permission
```

can itself become:

```text
secret-read capability.
```

---

# 14.1375 Secret-reference privilege escalation

Suppose Todo developers can create:

```yaml
kind: ExternalSecret
```

and they can reference any key:

```yaml
remoteRef:
  key: finance/root-password
```

If the underlying `SecretStore` IAM identity can read that secret:

```text
Todo developer
      │
      ▼
ExternalSecret
      │
      ▼
ESO
      │
      ▼
finance/root-password
```

you have created a privilege escalation path.

So security requires:

```text
Kubernetes RBAC
+
SecretStore boundaries
+
IAM resource restrictions.
```

Not just:

```text
"Secrets are external now."
```

---

# 14.1376 Three-layer secret authorization

When ESO fetches AWS secrets, ask:

```text
Layer 1:
May this user/team create or modify ExternalSecret?
```

Kubernetes RBAC / AppProject.

```text
Layer 2:
Which SecretStore may that ExternalSecret use?
```

namespace / store architecture.

```text
Layer 3:
Which AWS Secrets Manager ARNs may the IAM role read?
```

AWS IAM.

Permanent rule:

> **The actual secret boundary must exist at the external secret provider too.**

---

# 14.1377 AWS Secrets Manager role

AWS Secrets Manager provides centralized secret storage, IAM-based access control, and configurable automatic rotation. AWS documentation recommends rotation to reduce the usable lifetime of compromised credentials. ([AWS Documentation][9])

Our architecture:

```text
AWS Account
│
└── Secrets Manager
    │
    ├── production/todo/backend
    ├── production/payments/backend
    └── production/analytics/api
```

Then IAM should enforce:

```text
Todo role
→ Todo secrets only
```

not:

```text
Todo role
→ *
```

---

# 14.1378 Bad IAM policy

Avoid:

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:*",
  "Resource": "*"
}
```

for an application secret reader.

That can grant far more than simply:

```text
read Todo database password.
```

---

# 14.1379 Better IAM policy

Conceptually:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-south-1:123456789012:secret:production/todo/*"
      ]
    }
  ]
}
```

Now:

```text
Todo secret reader

can access:
production/todo/*
```

but not:

```text
production/payments/*
```

ESO's AWS provider documentation likewise demonstrates restricting Secrets Manager actions and using role assumption to scope store access rather than relying on one broad credential. ([External Secrets][10])

---

# 14.1380 IAM identity options for ESO on EKS

Current ESO AWS integration supports several authentication approaches, including:

```text
controller Pod identity

IRSA

service-account token/JWT flow

static AWS credentials

STS role assumption
```

ESO's current AWS provider documentation lists these options. ([External Secrets][11])

Our production preference is:

```text
temporary AWS identity
```

rather than:

```text
long-lived AWS access key
stored in Kubernetes.
```

---

# 14.1381 EKS Pod Identity

Current Amazon EKS Pod Identity associates:

```text
Kubernetes ServiceAccount
        │
        ▼
IAM Role
```

at the EKS level.

Pods using that ServiceAccount obtain temporary AWS credentials through EKS Pod Identity rather than receiving static access keys. AWS highlights least privilege, credential isolation, and simpler role reuse as advantages of Pod Identity. ([AWS Documentation][12])

Flow:

```text
ESO Pod
  │
  ▼
ServiceAccount:
external-secrets
  │
  ▼
EKS Pod Identity association
  │
  ▼
IAM Role
  │
  ▼
AWS Secrets Manager
```

---

# 14.1382 Pod Identity Agent

For standard EKS clusters using Pod Identity, the EKS Pod Identity Agent runs on eligible worker nodes and supplies credentials to Pods using the association. EKS Auto Mode includes this capability without requiring you to install the agent separately. ([AWS Documentation][12])

So a normal setup includes:

```text
EKS Pod Identity Agent
+
Pod Identity Association.
```

---

# 14.1383 ESO + Pod Identity

Current ESO documentation supports EKS Pod Identity by associating an IAM role with the ESO controller's ServiceAccount and leaving the `SecretStore` without an explicit `auth` block. ([External Secrets][10])

Concept:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore

metadata:
  name: aws-secretsmanager
  namespace: todo-prod

spec:

  provider:

    aws:
      service: SecretsManager
      region: ap-south-1
```

Authentication comes from:

```text
ESO controller Pod Identity.
```

---

# 14.1384 Important Pod Identity limitation in ESO

Current ESO documentation explicitly notes that:

```yaml
auth:
  jwt:
    serviceAccountRef:
```

cannot be combined with the EKS Pod Identity approach for per-store service-account impersonation. With Pod Identity, ESO uses the controller Pod's associated identity. ([External Secrets][10])

This means:

```text
one ESO controller identity
```

could become too broad if we don't add another isolation layer.

---

# 14.1385 Better Pod Identity architecture

Use:

```text
ESO controller Pod Identity
=
base AWS role
```

with permission primarily to:

```text
sts:AssumeRole
```

into narrower per-store roles.

Then:

```yaml
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1

      role: arn:aws:iam::123456789012:role/todo-prod-secret-reader
```

Current ESO documentation describes the optional `role` field as the recommended way to scope access per store through `sts:AssumeRole`. ([External Secrets][10])

---

# 14.1386 Production AWS identity architecture

```text
                     ESO Controller
                           │
                           ▼
                  EKS Pod Identity Role
                           │
                           │ sts:AssumeRole
                           ▼
              todo-prod-secret-reader
                           │
                           │ GetSecretValue
                           ▼
                 production/todo/*
```

Payments store:

```text
ESO Controller
      │
      ▼
payments-prod-secret-reader
      │
      ▼
production/payments/*
```

Now shared ESO does **not** need one giant:

```text
SecretsManager Resource: *
```

permission.

---

# 14.1387 IRSA alternative

IRSA remains another supported approach for EKS workloads.

ESO can use a ServiceAccount annotated with an IAM role and reference that ServiceAccount from a `SecretStore` through:

```yaml
auth:
  jwt:
    serviceAccountRef:
```

Current ESO documents this EKS service-account credentials model and notes that it lets ESO authenticate using short-lived service-account tokens rather than static AWS credentials. ([External Secrets][10])

Example:

```yaml
apiVersion: v1
kind: ServiceAccount

metadata:
  name: todo-secrets-reader
  namespace: todo-prod

  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/todo-prod-secrets-reader
```

Then:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore

metadata:
  name: aws-secretsmanager
  namespace: todo-prod

spec:

  provider:

    aws:

      service: SecretsManager
      region: ap-south-1

      auth:

        jwt:

          serviceAccountRef:
            name: todo-secrets-reader
```

This provides a natural:

```text
SecretStore
→ ServiceAccount
→ IAM role
```

mapping. ([External Secrets][10])

---

# 14.1388 Pod Identity vs IRSA

At a high level:

```text
EKS Pod Identity

association managed through EKS
no per-cluster IAM OIDC provider requirement
controller Pod identity works naturally
```

while:

```text
IRSA

OIDC federation model
ServiceAccount annotation
ESO can reference per-store SA via JWT auth
```

AWS currently describes Pod Identity as the simpler newer model because it does not require per-cluster OIDC provider configuration and can reuse IAM roles more easily across clusters. ([AWS Documentation][12])

But:

```text
simpler
≠
always better for every ESO tenancy model.
```

Your desired per-store isolation may influence the choice.

---

# 14.1389 Our production teaching design

For our Todo architecture we'll use:

```text
EKS Pod Identity
for ESO controller
```

plus:

```text
per-team IAM role assumption
through SecretStore.role
```

because it gives:

```text
temporary identity

no static AWS keys

simple EKS association

separate Secrets Manager permissions
per store/team.
```

This fits our preferred AWS deployment region of `ap-south-1`.

---

# 14.1390 Step 1 — Create a Todo secret in AWS

Conceptually store:

```text
Secret name:

production/todo/backend
```

with JSON:

```json
{
  "mongodb_uri": "mongodb://...",
  "jwt_secret": "...",
  "third_party_api_key": "..."
}
```

The secret value is maintained in AWS Secrets Manager—not Git.

For a lab, you could use:

```bash
aws secretsmanager create-secret \
  --region ap-south-1 \
  --name production/todo/backend \
  --secret-string file://todo-secret.json
```

But remember:

```text
todo-secret.json
```

now contains plaintext.

For production, don't leave local plaintext files behind or commit them.

---

# 14.1391 Never paste secrets casually into shell history

This:

```bash
aws secretsmanager create-secret \
  --secret-string '{"password":"SuperSecret"}'
```

may expose the value through:

```text
shell history

terminal logging

process tooling

CI logs.
```

Use secure provisioning processes.

Secrets Manager is the destination, but the path used to put the secret there must also be secure.

---

# 14.1392 Step 2 — Install External Secrets Operator

Current ESO installation documentation provides this Helm path:

```bash
helm repo add external-secrets \
  https://charts.external-secrets.io

helm repo update
```

Then:

```bash
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
```

Current ESO installs and manages its CRDs by default through the chart; its latest docs also note CRD size constraints and server-side apply requirements if managing CRDs separately. ([External Secrets][5])

For our final GitOps design, we would normally place this Helm deployment under:

```text
platform GitOps
```

rather than repeatedly installing it manually.

---

# 14.1393 Bootstrap ordering

Remember Lesson 10:

```text
ESO CRDs
     │
     ▼
ESO controller
     │
     ▼
SecretStore
     │
     ▼
ExternalSecret
     │
     ▼
Application requiring Secret
```

Do not blindly deploy:

```text
ExternalSecret
```

before Kubernetes knows the CRD.

This is another reason platform bootstrapping and sync ordering matter.

---

# 14.1394 Validate ESO

```bash
kubectl get pods \
  -n external-secrets
```

Then:

```bash
kubectl get crd | grep external-secrets
```

You should see CRDs conceptually including:

```text
externalsecrets.external-secrets.io

secretstores.external-secrets.io

clustersecretstores.external-secrets.io
```

If CRDs are absent:

```text
ExternalSecret YAML
```

cannot be accepted by Kubernetes.

---

# 14.1395 Step 3 — Pod Identity role

Create an IAM role for the ESO controller with a Pod Identity trust relationship.

The trust principal for EKS Pod Identity is:

```text
pods.eks.amazonaws.com
```

with:

```text
sts:AssumeRole

sts:TagSession
```

in the role trust policy. AWS and ESO both document this Pod Identity trust model. ([AWS Documentation][12])

Conceptual trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

---

# 14.1396 Base ESO role should not read every secret

Instead of:

```text
ESO Pod role
→ secretsmanager:GetSecretValue *
```

we can design:

```text
ESO Pod role
→ sts:AssumeRole
   todo-secret-role
   payments-secret-role
   etc.
```

Then each target role owns secret-specific permissions.

This keeps the controller's base identity narrower.

---

# 14.1397 Create the Pod Identity association

Conceptually:

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --namespace external-secrets \
  --service-account external-secrets \
  --role-arn arn:aws:iam::123456789012:role/eso-controller \
  --region ap-south-1
```

ESO's current AWS documentation shows this association pattern for the operator ServiceAccount. ([External Secrets][10])

Validate:

```bash
aws eks list-pod-identity-associations \
  --cluster-name <CLUSTER_NAME> \
  --region ap-south-1
```

---

# 14.1398 Step 4 — Todo reader role

Create:

```text
todo-prod-secret-reader
```

with access only to:

```text
arn:aws:secretsmanager:ap-south-1:<ACCOUNT>:secret:production/todo/*
```

Then allow:

```text
eso-controller
```

to assume:

```text
todo-prod-secret-reader.
```

This produces:

```text
ESO Controller

      ↓ AssumeRole

Todo Secret Role

      ↓ GetSecretValue

Todo Secrets
```

Current ESO's `role` field is designed for exactly this provider-side scoping. ([External Secrets][10])

---

# 14.1399 Step 5 — create namespace

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: todo-prod
```

Our:

```text
AppProject/todo-prod
```

should already restrict the Application to this namespace.

Secret isolation then aligns with:

```text
Argo Project

Kubernetes Namespace

SecretStore

IAM role

Secrets Manager prefix.
```

Excellent defense in depth.

---

# 14.1400 Step 6 — SecretStore

Create:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore

metadata:
  name: aws-secretsmanager
  namespace: todo-prod

spec:

  provider:

    aws:

      service: SecretsManager

      region: ap-south-1

      role: arn:aws:iam::123456789012:role/todo-prod-secret-reader
```

No secret value.

No AWS access key.

No password.

Current ESO supports this model: use the controller identity and optionally assume a target role before reading Secrets Manager. ([External Secrets][10])

---

# 14.1401 Validate SecretStore

```bash
kubectl get secretstore \
  -n todo-prod
```

Then:

```bash
kubectl describe secretstore \
  aws-secretsmanager \
  -n todo-prod
```

Look for status/conditions indicating the store can authenticate to the provider.

If it fails, don't immediately troubleshoot ExternalSecret.

First fix:

```text
STORE.
```

---

# 14.1402 Step 7 — ExternalSecret

Create:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret

metadata:
  name: todo-backend
  namespace: todo-prod

spec:

  refreshPolicy: Periodic
  refreshInterval: 1h

  secretStoreRef:

    name: aws-secretsmanager
    kind: SecretStore

  target:

    name: todo-backend-secret
    creationPolicy: Owner

  data:

    - secretKey: MONGODB_URI

      remoteRef:

        key: production/todo/backend
        property: mongodb_uri

    - secretKey: JWT_SECRET

      remoteRef:

        key: production/todo/backend
        property: jwt_secret
```

Current ESO `ExternalSecret` API supports a store reference, target Kubernetes Secret, individual `data` mappings, `dataFrom`, refresh policies, and refresh intervals. ([External Secrets][13])

---

# 14.1403 Result

ESO creates:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: todo-backend-secret
  namespace: todo-prod
```

with values equivalent to:

```text
MONGODB_URI
JWT_SECRET
```

but Git still only contains:

```text
remote references.
```

That's exactly what we want.

---

# 14.1404 Validate ExternalSecret

```bash
kubectl get externalsecret \
  -n todo-prod
```

Then:

```bash
kubectl describe externalsecret \
  todo-backend \
  -n todo-prod
```

Then verify the target exists:

```bash
kubectl get secret \
  todo-backend-secret \
  -n todo-prod
```

Do not immediately print the Secret contents in production.

The existence/status is usually enough for a first check.

---

# 14.1405 Avoid debugging by leaking the secret

Bad:

```bash
kubectl get secret todo-backend-secret \
  -n todo-prod \
  -o yaml
```

then copying the output into:

```text
Slack

ticket

GitHub issue

Chat

CI log.
```

Even base64 Secret data is sensitive.

Debug:

```text
metadata

status

key names

events

permissions
```

before revealing values.

---

# 14.1406 Consume it in Todo Deployment

Deployment:

```yaml
env:

  - name: MONGODB_URI

    valueFrom:

      secretKeyRef:

        name: todo-backend-secret

        key: MONGODB_URI

  - name: JWT_SECRET

    valueFrom:

      secretKeyRef:

        name: todo-backend-secret

        key: JWT_SECRET
```

Now:

```text
Todo Pod
```

knows:

```text
todo-backend-secret
```

but knows nothing about:

```text
AWS IAM

Secrets Manager

ESO.
```

This is excellent abstraction.

---

# 14.1407 Application separation

Application developer writes:

```text
valueFrom.secretKeyRef
```

Platform engineer manages:

```text
ESO

IAM

SecretStore.
```

Security/admin manages:

```text
AWS secret value

rotation policy

access policy.
```

Clear responsibilities.

---

# 14.1408 Whole production path

```text
Developer
   │
   ▼
Git:
ExternalSecret
   │
   ▼
Argo CD
   │
   ▼
Kubernetes:
ExternalSecret
   │
   ▼
ESO Controller
   │
   ▼
EKS Pod Identity
   │
   ▼
STS AssumeRole
   │
   ▼
Todo Secret Reader Role
   │
   ▼
AWS Secrets Manager
   │
   ▼
secret value
   │
   ▼
ESO
   │
   ▼
Kubernetes Secret
   │
   ▼
Todo Pod
```

This is our primary production model.

---

# 14.1409 `data` vs `dataFrom`

Use:

```yaml
data:
```

when you explicitly map:

```text
remote field A
→ Kubernetes key X
```

Example:

```yaml
- secretKey: MONGODB_URI
  remoteRef:
    key: production/todo/backend
    property: mongodb_uri
```

Use `dataFrom` when you intentionally want to bring a larger set of provider properties into the target Secret. ESO's API supports both mechanisms. ([External Secrets][14])

For sensitive production workloads, explicit mapping often makes:

```text
what gets imported
```

clearer.

---

# 14.1410 SecretStore naming

Prefer:

```text
aws-todo-prod
```

or:

```text
aws-secretsmanager
```

inside a dedicated namespace.

Avoid:

```text
store1
newstore
store-final.
```

At 3 AM, naming matters.

---

# 14.1411 Secrets Manager version model

AWS Secrets Manager creates versions when a secret is updated.

ESO's AWS provider can reference either:

```text
VersionStage
```

such as:

```text
AWSCURRENT

AWSPREVIOUS
```

or an immutable:

```text
VersionId.
```

ESO documents that `AWSCURRENT` and `AWSPREVIOUS` are common version-stage aliases, while a VersionId identifies a particular version immutably. ([External Secrets][15])

---

# 14.1412 Current vs pinned secret versions

Normal production application:

```text
follow AWSCURRENT
```

so rotation propagates.

Incident troubleshooting might compare:

```text
AWSCURRENT

AWSPREVIOUS.
```

A specific immutable secret version can also be referenced where a fixed value is deliberately required. ([External Secrets][15])

But be careful:

```text
pinning an old password forever
```

can defeat rotation.

---

# 14.1413 ESO refresh policies

Current ExternalSecret supports:

```text
Periodic

CreatedOnce

OnChange
```

`Periodic` is the default behavior. ([External Secrets][13])

Mental model:

```text
Periodic
=
re-fetch according to refreshInterval


CreatedOnce
=
create once and don't keep updating
from provider changes


OnChange
=
refresh when ExternalSecret
metadata/spec changes
```

---

# 14.1414 Typical production secret

For rotating credentials:

```yaml
refreshPolicy: Periodic
refreshInterval: 1h
```

means ESO periodically checks the provider and reconciles the Kubernetes Secret. Current ESO API documents `refreshInterval` as the provider re-read interval; its default is one hour when not otherwise set. ([External Secrets][14])

Choose interval based on:

```text
rotation requirements

provider API load

acceptable propagation delay.
```

---

# 14.1415 Secret rotation flow

Suppose current secret:

```text
password-v1
```

AWS Secrets Manager rotates to:

```text
password-v2.
```

Flow:

```text
Secrets Manager
v1 → v2
     │
     ▼
ESO next reconciliation
     │
     ▼
Kubernetes Secret
v1 → v2
```

No Git commit was required.

That's one of the biggest advantages of destination-side secret management.

---

# 14.1416 But does the Pod automatically use the new value?

Important question.

It depends on **how the application consumes the Secret**.

If injected as:

```text
environment variable
```

existing running processes generally won't magically rewrite their process environment.

You may need:

```text
Pod restart/rollout
```

or application-specific reload logic.

If secret is exposed via a projected/mounted volume, Kubernetes can update mounted Secret content over time, but whether the application rereads the file is application-dependent. Kubernetes documents both Secret environment-variable and volume consumption patterns. ([Kubernetes][2])

Therefore:

```text
SECRET UPDATED
≠
APPLICATION AUTOMATICALLY USING IT.
```

---

# 14.1417 Three rotation layers

For any secret rotation ask:

```text
1.
Did external secret rotate?
```

```text
2.
Did Kubernetes Secret update?
```

```text
3.
Did application reload/restart
and begin using new value?
```

These are three separate states.

---

# 14.1418 Secret rotation with environment variables

Architecture:

```text
Kubernetes Secret changes
       │
       ▼
existing Pod env
does not dynamically change
       │
       ▼
rollout/restart required
```

Options include:

```text
manual controlled rollout

deployment annotation bump

secret-change reloader controller

application-specific hot reload
```

Each has different operational implications.

Do not assume ESO alone restarts your workload.

---

# 14.1419 Database rotation is harder than value rotation

Suppose password changes in:

```text
Secrets Manager
```

but database still expects:

```text
old password.
```

Application breaks.

Proper rotation means coordinating:

```text
secret store value

and

actual external service credential.
```

AWS Secrets Manager defines rotation as updating both the stored secret and the database/service credential; it supports managed rotation for some secret types and Lambda-based rotation for others. ([AWS Documentation][9])

So:

```text
PutSecretValue
```

is not automatically:

```text
complete credential rotation.
```

---

# 14.1420 AWS automatic rotation

Secrets Manager can automatically rotate supported secrets on configured schedules. Current AWS docs support managed rotation for certain managed-secret integrations and Lambda-based rotation where custom rotation logic is needed. ([AWS Documentation][9])

Then:

```text
Secrets Manager rotation

        ↓

ESO synchronization

        ↓

Kubernetes Secret update

        ↓

application reload
```

becomes the complete lifecycle.

---

# 14.1421 Rotation frequency

Don't say:

```text
"All secrets rotate every 90 days"
```

as a universal rule.

Different secret types have different characteristics:

```text
DB credentials

API tokens

TLS certificates

machine credentials

human passwords.
```

AWS Secrets Manager currently supports rotation schedules as frequently as every four hours for supported configurations. ([AWS Documentation][16])

Select rotation based on:

```text
risk

system support

operational behavior

dependency compatibility.
```

---

# 14.1422 Git does not need to change during rotation

This is powerful.

Git:

```yaml
remoteRef:
  key: production/todo/backend
```

remains unchanged.

Secrets Manager:

```text
version 1
→
version 2
```

changes.

Git still truthfully describes:

> Todo should consume the current production Todo backend secret.

The **secret identity** remains stable.

The **secret value** rotates independently.

---

# 14.1423 GitOps reconciliation and secret reconciliation are separate loops

We now have:

```text
ARGO LOOP

Git
 ↓
ExternalSecret spec
 ↓
Kubernetes
```

and:

```text
ESO LOOP

Secrets Manager
 ↓
Kubernetes Secret
```

and:

```text
KUBERNETES LOOP

Deployment
 ↓
Pods
```

One system.

Three controllers.

---

# 14.1424 Why Argo should not own the generated Secret

Argo owns:

```text
ExternalSecret.
```

ESO owns:

```text
Secret.
```

Do not simultaneously commit:

```yaml
kind: Secret
metadata:
  name: todo-backend-secret
```

to the same Argo Application.

Otherwise:

```text
Argo
```

and:

```text
ESO
```

both try to own the same object.

Again:

# **One resource → one authoritative controller.**

---

# 14.1425 Secret generated outside Argo may appear extraneous

Depending on how resources are tracked and Application configuration is designed, operator-generated resources can appear differently in Argo's resource tree.

Don't immediately add:

```text
IgnoreExtraneous
```

everywhere.

Understand:

```text
Who created Secret?

Who should own Secret?

Should Argo prune Secret?

Should ESO own lifecycle?
```

first.

Controller ownership matters more than making the Argo UI look green.

---

# 14.1426 Target creation policy

Our example used:

```yaml
target:
  creationPolicy: Owner
```

which makes the ExternalSecret act as owner of the generated Kubernetes Secret according to ESO's target-management model. Current ESO API supports creation and deletion lifecycle policies for target Secrets. ([External Secrets][17])

That is appropriate when:

```text
ExternalSecret
=
authoritative owner
```

of the generated Secret.

---

# 14.1427 Delete the ExternalSecret — what happens?

You must understand:

```text
creationPolicy

deletionPolicy
```

and your chosen operator semantics before deleting Secret objects in Production.

Do not assume:

```text
delete ExternalSecret
=
secret remains
```

or:

```text
secret always deleted.
```

Review target ownership and deletion policy intentionally. ESO exposes explicit target lifecycle controls precisely for this reason. ([External Secrets][17])

---

# 14.1428 SecretStore deletion can affect many ExternalSecrets

If you delete:

```text
SecretStore/aws-secretsmanager
```

the generated Kubernetes Secrets may not instantly disappear depending on lifecycle policy, but future ESO refreshes lose their provider configuration.

Operational result:

```text
current application may keep working
```

while:

```text
future rotation stops.
```

That is a dangerous silent failure.

Monitoring should include:

```text
ExternalSecret readiness

last refresh

provider errors.
```

---

# 14.1429 Secret freshness matters

Application can be:

```text
Healthy
```

in Argo,

while:

```text
ExternalSecret refresh failed
```

for six hours.

Todo Pods still run using old secret.

Argo sees its declared:

```text
ExternalSecret
```

resource synced.

But ESO cannot update the secret.

Therefore:

```text
ARGO HEALTH
≠
SECRET BACKEND HEALTH.
```

Monitor both controllers.

---

# 14.1430 SecretStore tenancy architecture

A strong multi-team pattern:

```text
todo-prod namespace
│
├── SecretStore/todo-prod
├── ExternalSecret/todo-db
└── Secret/todo-db
```

and:

```text
payments-prod namespace
│
├── SecretStore/payments-prod
├── ExternalSecret/payments-db
└── Secret/payments-db
```

AWS:

```text
todo-prod-secret-reader
→ production/todo/*

payments-prod-secret-reader
→ production/payments/*
```

Now tenancy boundaries align end-to-end.

---

# 14.1431 AppProject should restrict ESO resources

Remember Lesson 8.

If ordinary Todo Application is allowed to deploy:

```text
ExternalSecret
```

that's reasonable.

Should it also deploy:

```text
ClusterSecretStore?
```

Probably not.

Cluster-scoped secret provider configuration should generally be platform-owned.

AppProject can help restrict cluster-scoped resource kinds, while Kubernetes RBAC determines whether the underlying Argo cluster identity can actually create them.

---

# 14.1432 ClusterSecretStore threat

Imagine:

```text
ClusterSecretStore:
aws-global
```

has broad AWS access.

Every namespace can reference it.

Developer creates:

```yaml
remoteRef:
  key: production/payments/root
```

If neither store/provider policy nor IAM restricts access:

```text
secret exfiltration.
```

Therefore:

```text
shared ClusterSecretStore
```

needs exceptional scrutiny.

Convenience and isolation are often in tension.

---

# 14.1433 Cross-account Secrets Manager

Large AWS organizations often place workloads and secrets in separate accounts.

AWS cross-account Secrets Manager access requires appropriate identity-side permissions and resource-side permissions, and if a customer-managed KMS key protects the secret, the cross-account principal must also be authorized to decrypt with that KMS key. ([AWS Documentation][18])

Architecture:

```text
Workload Account
EKS / ESO
      │
      ▼
AssumeRole
      │
      ▼
Security / Secret Account
      │
      ▼
Secrets Manager
      │
      ▼
KMS
```

---

# 14.1434 Cross-account with EKS Pod Identity

Current EKS Pod Identity supports cross-account AWS resource access using role chaining/target roles. The Pod Identity role itself is associated in the cluster's account, and access to another account can be delegated through a target role. ([AWS Documentation][19])

This meshes naturally with:

```text
ESO controller Pod role
→ target secret reader role
→ Secrets Manager account.
```

---

# 14.1435 Cross-account security model

For secret in Account B:

```text
Account A / EKS
ESO
 │
 ▼
Pod Identity Role A
 │
 ▼
Target Role B
 │
 ▼
Secrets Manager Secret B
 │
 ▼
KMS Key B
```

You need to reason through:

```text
Role A trust/access

Role B trust

Secrets Manager resource policy if using direct cross-account resource access

identity policies

KMS permissions.
```

AWS's cross-account Secrets Manager documentation explicitly requires both relevant identity/resource authorization and KMS access where a customer-managed cross-account key is involved. ([AWS Documentation][18])

---

# 14.1436 Multi-region DR secrets

Remember our:

```text
Mumbai
→ ap-south-1

Singapore DR
→ ap-southeast-1
```

A DR environment that cannot retrieve secrets is not ready.

You must decide whether secrets are:

```text
replicated

recreated

region-local

centrally accessed cross-region
```

and understand:

```text
RTO

RPO

rotation

KMS

IAM

regional dependency.
```

GitOps parity without secret parity is incomplete DR.

---

# 14.1437 Warm standby failure example

Singapore cluster exists.

Applications exist.

Ingress works.

But ExternalSecret shows:

```text
SecretSyncedError
```

because:

```text
SecretStore region:
ap-southeast-1
```

and the expected secret exists only in:

```text
ap-south-1.
```

Result:

```text
DR cluster technically running

but application cannot start.
```

This is why DR testing must validate secret retrieval.

---

# 14.1438 SecretStore region should be explicit

Example:

```yaml
provider:
  aws:
    service: SecretsManager
    region: ap-south-1
```

Do not let:

```text
"whatever default region the SDK finds"
```

become your production secret-location strategy.

Region is part of desired provider configuration.

---

# 14.1439 Secret naming convention

Good:

```text
/prod/todo/backend/database

/prod/todo/backend/jwt

/prod/todo/integrations/payment-api
```

or:

```text
production/todo/backend
```

Bad:

```text
secret1

vivek-test-final

password-new-2.
```

Naming helps build:

```text
IAM resource policies

ownership

rotation

audit

DR replication.
```

---

# 14.1440 One secret containing many properties vs many secrets

Pattern A:

```text
production/todo/backend
{
  mongodb_uri,
  jwt_secret,
  api_key
}
```

Pattern B:

```text
production/todo/mongodb

production/todo/jwt

production/todo/api-key
```

Tradeoffs include:

```text
rotation lifecycle

IAM granularity

ownership

access overlap

audit clarity.
```

Do not put unrelated security domains into one giant:

```text
company-prod-secrets
```

JSON object.

---

# 14.1441 Secret granularity rule

Group secret values when they share:

```text
same owner

same consumers

same access policy

same rotation lifecycle.
```

Separate them when those differ.

Same principle we've used throughout:

```text
ownership
+
lifecycle
+
blast radius.
```

---

# 14.1442 AWS secret version stages

During rotation:

```text
AWSCURRENT
```

normally points to the active version.

```text
AWSPREVIOUS
```

can point to the prior version.

ESO supports requesting these version stages explicitly. ([External Secrets][15])

This gives a useful incident tool:

```text
Current credential broken?
```

Compare with previous version.

But don't use:

```text
AWSPREVIOUS
```

as permanent architecture because rotation failed.

Fix rotation.

---

# 14.1443 Secret rollback caveat

Rolling secret backward is not always like rolling image backward.

Suppose DB password rotation completed:

```text
database expects v2
```

and you simply tell Kubernetes:

```text
use previous stored value v1.
```

Application may fail because the external database no longer accepts v1.

Secret rollback requires understanding:

```text
external service state.
```

Again:

```text
desired value rollback
≠
external-state rollback.
```

---

# 14.1444 Sealed Secrets

Now compare a different model.

Sealed Secrets gives:

```text
plaintext Kubernetes Secret
        │
        ▼
kubeseal encryption
        │
        ▼
SealedSecret
        │
        ▼
Git
        │
        ▼
Argo
        │
        ▼
Sealed Secrets Controller
        │
        ▼
Kubernetes Secret
```

Unlike ESO:

```text
secret ciphertext itself
lives in Git.
```

The controller holds the ability to decrypt it.

---

# 14.1445 Sealed Secrets mental model

Git contains:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret

metadata:
  name: todo-db
  namespace: todo-prod

spec:

  encryptedData:

    password: AgB....
```

Someone reading Git sees:

```text
ciphertext.
```

Controller has the private key needed to unseal the secret.

---

# 14.1446 Sealed Secret scopes

Current Sealed Secrets supports three scopes:

```text
strict

namespace-wide

cluster-wide.
```

`strict` is the default: name and namespace are cryptographically bound.

`namespace-wide` allows renaming within the same namespace.

`cluster-wide` allows unsealing into any namespace/name. ([GitHub][20])

Permanent rule:

```text
strict
=
smallest blast radius.
```

---

# 14.1447 Sealed Secrets advantage

Very Git-native:

```text
encrypted artifact
is directly versioned in Git.
```

You can:

```text
PR

review resource metadata

promote ciphertext

restore from Git.
```

No runtime external secret backend is required solely to retrieve the value after sealing.

---

# 14.1448 Sealed Secrets disadvantage

The controller's private key becomes critical.

If you lose the private key:

```text
existing Kubernetes Secret may remain
```

but:

```text
Git ciphertext
cannot necessarily be decrypted
after rebuilding the cluster.
```

Therefore Sealed Secrets key backup/recovery is part of DR.

---

# 14.1449 Key compromise

If the Sealed Secrets controller's private decryption key is compromised:

```text
attacker
+
Git ciphertext
=
potential plaintext recovery
```

depending on scope/key material.

So:

```text
"encrypted in Git"
```

does not remove key-management responsibility.

It moves the problem to:

```text
controller private key.
```

---

# 14.1450 Sealed Secrets vs External Secrets

```text
SEALED SECRETS

Git stores:
encrypted secret value
```

while:

```text
EXTERNAL SECRETS

Git stores:
reference to external secret
```

With ESO:

```text
actual value
=
AWS Secrets Manager.
```

With Sealed Secrets:

```text
actual encrypted payload
=
Git
```

and controller has decryption capability.

---

# 14.1451 When I would prefer Sealed Secrets

Possible fit when:

```text
small/simple cluster

strong Git-centered workflow

no external secret manager

secret rotation frequency modest

controller key backup well understood.
```

It can be particularly convenient in environments where a managed external vault isn't available.

---

# 14.1452 When I prefer External Secrets on AWS

For our AWS architecture:

```text
AWS Secrets Manager already exists

IAM already exists

CloudTrail audit exists

rotation integrations exist

multi-account IAM exists
```

Therefore:

```text
ESO + Secrets Manager
```

is usually the more natural production model.

Secret values remain in the purpose-built AWS service rather than becoming encrypted Git payloads.

---

# 14.1453 Vault

Now consider HashiCorp Vault.

Vault can provide:

```text
static secrets

dynamic secrets

database credentials

PKI certificates

secret leasing

revocation

multiple authentication methods.
```

Current Vault Secrets Operator synchronizes Vault secret data into native Kubernetes Secrets and supports static and dynamic secret use cases. ([HashiCorp Developer][21])

Architecture:

```text
Git
 │
 ▼
VaultStaticSecret /
VaultDynamicSecret
 │
 ▼
Vault Secrets Operator
 │
 ▼
Vault
 │
 ▼
Kubernetes Secret
 │
 ▼
Pod
```

Very similar conceptually to ESO.

---

# 14.1454 Vault dynamic credentials

This is where Vault becomes especially interesting.

Instead of storing:

```text
one long-lived database password
```

Vault can issue:

```text
temporary database credential
```

with:

```text
lease

expiry

revocation.
```

Vault Secrets Operator supports dynamic secret synchronization and HashiCorp's documentation emphasizes the importance of maintaining lease/client-cache state for dynamic secrets through operator restarts/upgrades. ([HashiCorp Developer][21])

---

# 14.1455 Static vs dynamic secret

Static:

```text
username:
todo-prod

password:
abc123
```

exists for potentially long duration.

Dynamic:

```text
username:
v-token-todo-28371

password:
temporary-xyz

TTL:
1h
```

created when required.

After expiry:

```text
credential invalid.
```

Dynamic secrets reduce the useful lifetime of leaked credentials.

---

# 14.1456 Vault Kubernetes authentication

Vault supports authenticating Kubernetes workloads using Kubernetes ServiceAccount tokens through its Kubernetes auth method. ([HashiCorp Developer][22])

Flow:

```text
Kubernetes ServiceAccount token
        │
        ▼
Vault Kubernetes Auth
        │
        ▼
Vault Role
        │
        ▼
Vault Policy
        │
        ▼
Secret path
```

Same principle as AWS IAM:

```text
workload identity
→ least-privilege secret access.
```

---

# 14.1457 Vault integration choices

Current Vault documentation distinguishes several Kubernetes integration models:

```text
Vault Secrets Operator

Secrets Store CSI provider

Vault Agent Injector.
```

VSO synchronizes values into native Kubernetes Secrets.

CSI mounts values as volumes.

Vault Agent can authenticate and render secret templates alongside workloads. ([HashiCorp Developer][23])

This matters because:

```text
Kubernetes Secret
```

is not the only consumption model.

---

# 14.1458 CSI approach

Another architecture is:

```text
Secret Backend
      │
      ▼
Secrets Store CSI Driver
      │
      ▼
ephemeral mounted volume
      │
      ▼
Pod
```

Potential advantage:

```text
secret doesn't need
to persist as a normal Kubernetes Secret
```

depending on the integration/configuration.

Argo lists the Kubernetes Secrets Store CSI Driver as another recommended destination-cluster secret-management approach. ([Argo CD][1])

---

# 14.1459 AWS ASCP

AWS provides the AWS Secrets and Configuration Provider for the Secrets Store CSI Driver.

For EKS, it can retrieve values from:

```text
AWS Secrets Manager

SSM Parameter Store
```

and present them to workloads using the CSI secret-mount model. AWS also supports EKS Pod Identity for this integration. ([AWS Documentation][24])

Architecture:

```text
Pod
 │
 ▼
Secrets Store CSI volume
 │
 ▼
ASCP
 │
 ▼
Pod Identity
 │
 ▼
Secrets Manager
```

---

# 14.1460 ESO vs CSI

ESO:

```text
Secrets Manager
      ↓
Kubernetes Secret
      ↓
Pod
```

CSI:

```text
Secrets Manager
      ↓
mounted secret volume
      ↓
Pod
```

ESO works naturally with applications already designed around:

```text
SecretKeyRef

Kubernetes Secret.
```

CSI can reduce reliance on persistent native Secret objects when applications can consume files.

Neither is universally superior.

---

# 14.1461 Argo's preferred architectural characteristic

The important part from Argo's perspective is not:

```text
ESO vs CSI vs Sealed Secrets vs VSO
```

as much as:

> **Perform secret resolution on the destination cluster rather than requiring Argo manifest generation to handle plaintext secret values.**

That is the direction current Argo documentation strongly recommends. ([Argo CD][1])

---

# 14.1462 Argo's own secrets are a separate category

Even if application secrets live in AWS Secrets Manager, Argo itself may use Kubernetes Secrets for:

```text
Git repository credentials

cluster credentials

SSO/OIDC client secret

webhook secrets

TLS keys.
```

Current Argo declarative setup stores repository and cluster credentials as specifically labeled Kubernetes Secret resources. ([Argo CD][25])

So we need:

```text
application secret architecture
```

and:

```text
Argo control-plane secret architecture.
```

---

# 14.1463 Repository credential Secret

Current Argo repository configuration uses Kubernetes Secrets labeled:

```text
argocd.argoproj.io/secret-type: repository
```

or credential templates using:

```text
repo-creds.
```

Argo's declarative setup documents this model. ([Argo CD][26])

Example structure conceptually:

```yaml
apiVersion: v1
kind: Secret

metadata:
  name: todo-gitops-repo
  namespace: argocd

  labels:
    argocd.argoproj.io/secret-type: repository

stringData:

  type: git

  url: https://git.example.com/company/todo-gitops.git

  username: ...

  password: ...
```

Do **not** commit the plaintext credential block.

---

# 14.1464 How should Argo repo credentials be created?

Options include:

```text
External Secrets Operator

Sealed Secrets

secret management in Terraform/bootstrap

workload identity/provider integrations
where supported.
```

For example:

```text
AWS Secrets Manager
      │
      ▼
ExternalSecret
      │
      ▼
Secret:
argocd repository credential
      │
      ▼
Argo repo-server
```

Now even the GitOps control-plane credentials can be externally sourced.

---

# 14.1465 Bootstrap chicken-and-egg

But notice:

```text
Argo needs Git credential
to read Git
```

while:

```text
Git might contain ExternalSecret
that would create Argo Git credential.
```

That's a bootstrap loop.

Therefore initial repository trust/credential may need:

```text
Terraform

initial bootstrap secret

cloud workload identity

or another external initialization path.
```

After the first GitOps connection exists, Argo can declaratively manage more of its secret configuration.

---

# 14.1466 Bootstrap secrets are special

Examples:

```text
first private Git credential

initial external secret provider identity

OIDC client secret

initial recovery credential.
```

They may need to exist before:

```text
normal GitOps controllers
```

can function.

Treat:

```text
bootstrap secrets
```

as a separate threat/recovery category.

---

# 14.1467 Argo cluster credentials

For remote clusters, Argo stores connection/credential information in Kubernetes Secrets in the Argo namespace. Argo's security documentation treats these as sensitive cluster-management credentials. ([Argo CD][27])

Therefore:

```text
argocd namespace
```

is not a normal application namespace.

It contains:

```text
crown-jewel control-plane Secrets.
```

---

# 14.1468 GitLab/GitHub token vs workload identity

Whenever possible, ask:

```text
Can Argo authenticate
without a long-lived PAT?
```

If a provider supports an appropriate app/workload identity model, that may reduce credential lifetime.

When PATs/SSH keys are unavoidable:

```text
least privilege

rotation

audit

restricted repo access

external secret storage.
```

No single "GitOps" mechanism removes basic credential hygiene.

---

# 14.1469 Argo TLS private keys

Argo's own TLS endpoint can use a dedicated Kubernetes Secret such as:

```text
argocd-server-tls.
```

Current Argo docs explicitly say that this Secret can be managed by third-party controllers such as `cert-manager` or Sealed Secrets, and Argo automatically notices certificate changes. ([Argo CD][28])

Again:

```text
operator/controller owns secret lifecycle
```

rather than:

```text
human pastes TLS key into Git.
```

---

# 14.1470 Secret ownership table

| Secret                         | Preferred owner                              |
| ------------------------------ | -------------------------------------------- |
| Todo DB password               | Secrets Manager/Vault                        |
| Todo K8s Secret copy           | ESO/VSO                                      |
| Argo Git credential            | External secret/bootstrap mechanism          |
| Argo remote-cluster credential | Argo/bootstrap identity flow                 |
| TLS cert/key                   | cert-manager / external secret system        |
| CI AWS credential              | Prefer temporary IAM identity                |
| Human password                 | Corporate IdP                                |
| SealedSecret decryption key    | Sealed Secrets controller + protected backup |

This is the key design exercise:

# **For every secret, name its authoritative owner.**

---

# 14.1471 Don't make Argo the universal secret owner

Bad:

```text
Argo
│
├── knows DB password
├── knows Stripe key
├── knows Vault token
├── knows AWS secret
├── knows everything
└── renders all plaintext
```

Argo is a deployment controller.

Not:

```text
enterprise password manager.
```

Current Argo guidance explicitly seeks to keep secret values out of its manifest-generation path when possible. ([Argo CD][1])

---

# 14.1472 Never put secret values in Helm values

Bad:

```yaml
# values-prod.yaml

mongodb:
  username: admin
  password: SuperSecret123
```

Even if Helm template turns it into a Secret:

```text
Git already leaked the password.
```

Better:

```yaml
secret:
  existingSecret: todo-backend-secret
```

Then ESO creates:

```text
todo-backend-secret.
```

---

# 14.1473 Helm + External Secrets

Chart structure:

```text
templates/
├── deployment.yaml
├── service.yaml
└── external-secret.yaml
```

Values:

```yaml
secrets:

  storeName: aws-secretsmanager

  remoteKey: production/todo/backend

  targetName: todo-backend-secret
```

These are references.

Not values.

Then Helm renders:

```text
ExternalSecret
```

and ESO owns:

```text
Secret.
```

Excellent separation.

---

# 14.1474 Kustomize + External Secrets

Base:

```text
base/
├── deployment.yaml
├── external-secret.yaml
└── service.yaml
```

Prod overlay patches:

```text
remote secret identifier

SecretStore name

namespace.
```

Again:

```text
no plaintext.
```

Kustomize is a great fit because the ExternalSecret itself is ordinary declarative Kubernetes YAML.

---

# 14.1475 Secret promotion across environments

Do not promote:

```text
Dev database password
```

to Prod.

Instead promote:

```text
application artifact
```

while each environment references its own secret identity.

Example:

Dev:

```text
development/todo/backend
```

Stage:

```text
staging/todo/backend
```

Prod:

```text
production/todo/backend.
```

Artifact:

```text
todo:f73ca19
```

can be the same.

Secret:

```text
environment-specific.
```

---

# 14.1476 Build-once principle still applies

```text
same image:
f73ca19
```

runs in:

```text
Dev
Stage
Prod
```

but consumes:

```text
different external configuration/secrets.
```

Promotion is:

```text
artifact identity
```

not:

```text
copy all Dev credentials into Prod.
```

---

# 14.1477 Secret rotation without application release

This is another major benefit.

Old architecture:

```text
change password
      │
      ▼
edit values.yaml
      │
      ▼
Git commit
      │
      ▼
application deployment
```

External secrets architecture:

```text
rotate secret in secret backend
      │
      ▼
secret controller reconciles
      │
      ▼
runtime picks up/reloads
```

Application code/image doesn't have to change merely because a credential rotates.

AWS explicitly notes that externalizing credentials allows rotation without changing application clients themselves. ([AWS Documentation][29])

---

# 14.1478 But changes still need observability

Automated rotation can fail.

Monitor:

```text
Secrets Manager rotation success

ExternalSecret Ready status

last refresh time

ESO controller errors

application authentication errors

Pod restart/reload success.
```

Secret automation without monitoring creates invisible failure.

---

# 14.1479 Secret troubleshooting mnemonic

Use:

# **R → S → I → P → F → K → A**

```text
R
REFERENCE

What external secret/key
does Git request?


S
STORE

Which SecretStore?


I
IDENTITY

Which AWS/Vault identity
does controller use?


P
PROVIDER

Can provider return secret?


F
FETCH / REFRESH

Did ExternalSecret reconcile?


K
KUBERNETES SECRET

Was target Secret created/updated?


A
APPLICATION

Did workload load/use it?
```

---

# 14.1480 R — Reference

Check:

```yaml
remoteRef:
  key: production/todo/backend
  property: mongodb_uri
```

Common mistakes:

```text
wrong key

wrong property

wrong case

wrong environment path

wrong secret version.
```

Do not troubleshoot IAM first if:

```text
secret name is simply wrong.
```

---

# 14.1481 S — Store

```bash
kubectl get secretstore \
  -n todo-prod
```

Then:

```bash
kubectl describe secretstore \
  aws-secretsmanager \
  -n todo-prod
```

Questions:

```text
correct provider?

correct region?

correct role ARN?

store Ready?
```

If Store can't authenticate:

```text
ExternalSecret cannot succeed.
```

---

# 14.1482 I — Identity

Pod Identity architecture:

```text
ESO ServiceAccount
      │
      ▼
Pod Identity association
      │
      ▼
base IAM role
      │
      ▼
AssumeRole target
```

Check:

```bash
aws eks list-pod-identity-associations \
  --cluster-name <CLUSTER> \
  --region ap-south-1
```

Then inspect:

```text
role trust

sts:AssumeRole permission

target role trust.
```

AWS notes Pod Identity associations are eventually consistent, so a newly created association may take several seconds before being usable. ([AWS Documentation][12])

---

# 14.1483 P — Provider

Check Secrets Manager:

```bash
aws secretsmanager describe-secret \
  --secret-id production/todo/backend \
  --region ap-south-1
```

This verifies:

```text
secret exists
```

without printing its value.

Much safer than:

```bash
get-secret-value
```

for first-line diagnostics.

---

# 14.1484 AWS AccessDenied

Potential causes:

```text
wrong Pod Identity association

ESO controller role missing permission

sts:AssumeRole denied

target role trust wrong

GetSecretValue denied

secret ARN pattern wrong

KMS permission missing

cross-account resource policy missing

wrong region.
```

Troubleshoot the chain.

Don't "fix" with:

```json
"Action": "*",
"Resource": "*"
```

unless you enjoy converting outages into security incidents.

---

# 14.1485 F — Fetch

```bash
kubectl describe externalsecret \
  todo-backend \
  -n todo-prod
```

Look at:

```text
Conditions

Events

RefreshTime

Provider errors.
```

Current ESO exposes status including synchronization conditions and refresh information. ([External Secrets][17])

---

# 14.1486 K — Kubernetes Secret

```bash
kubectl get secret \
  todo-backend-secret \
  -n todo-prod
```

Check only keys:

```bash
kubectl get secret \
  todo-backend-secret \
  -n todo-prod \
  -o go-template='{{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'
```

This can show:

```text
JWT_SECRET
MONGODB_URI
```

without intentionally dumping values.

Much safer.

---

# 14.1487 A — Application

If Secret exists but Pod fails:

```bash
kubectl describe pod <POD> \
  -n todo-prod
```

Possible:

```text
secretKeyRef wrong key

wrong Secret name

Pod started before Secret available

application rejects credential

database expects different password

application needs restart after rotation.
```

At this point ESO may be perfectly healthy.

---

# 14.1488 `CreateContainerConfigError`

Typical:

```text
Pod
→ CreateContainerConfigError
```

Check:

```text
Secret does not exist?

key does not exist?

wrong namespace?
```

A Kubernetes Secret is namespace-scoped.

`todo-prod` Pod cannot normally reference:

```text
todo-dev/todo-backend-secret
```

as though Secrets were global.

Namespace boundaries matter.

---

# 14.1489 Wrong namespace

ExternalSecret:

```text
namespace:
todo-dev
```

Deployment:

```text
namespace:
todo-prod
```

Even if both contain:

```text
name:
todo-backend-secret
```

they are different namespace-scoped objects.

Result:

```text
Prod Pod can't find it.
```

Fix environment overlay.

Do not weaken cluster security.

---

# 14.1490 ESO controller logs

For provider problems:

```bash
kubectl logs \
  -n external-secrets \
  deployment/external-secrets
```

Use logs carefully.

A well-designed operator should avoid printing secret values, but production logs themselves are still security-sensitive.

Check:

```text
auth failures

provider errors

reconciliation errors

rate limits

wrong region.
```

---

# 14.1491 Secret rotation incident

Scenario:

```text
Secrets Manager:
v2

Kubernetes Secret:
v2

Pods:
still using v1 env value
```

Diagnosis:

```text
R ✓
S ✓
I ✓
P ✓
F ✓
K ✓
A ✕
```

Solution is application reload/rollout behavior.

Not:

```text
change ESO IAM.
```

This is why layered troubleshooting matters.

---

# 14.1492 IAM incident

Scenario:

```text
ExternalSecret:
SecretSyncedError

AWS:
AccessDenied on sts:AssumeRole
```

Flow:

```text
Reference ✓
Store ✓
Controller Pod Identity ✓
AssumeRole ✕
```

Check:

```text
source role identity policy

target role trust policy.
```

Don't touch:

```text
Todo Deployment.
```

---

# 14.1493 KMS incident

AWS secret exists.

IAM allows:

```text
GetSecretValue.
```

But custom KMS policy denies decrypt.

Result:

```text
Secrets Manager call fails.
```

Particularly cross-account, KMS key permissions become a separate authorization plane. AWS documents this explicitly for cross-account Secrets Manager access. ([AWS Documentation][18])

Mental model:

```text
Secrets Manager authorization
+
KMS authorization.
```

---

# 14.1494 DR incident

Singapore ExternalSecret:

```text
Not Ready.
```

Everything else works.

Check:

```text
region

secret replication/existence

Pod Identity association

target role

cross-account policy

KMS key

network path to AWS APIs.
```

This is why:

```text
DR secret retrieval test
```

belongs in your DR game day.

---

# 14.1495 Private EKS networking

For private EKS environments, secret retrieval also depends on connectivity to AWS service endpoints.

For Pod Identity specifically, AWS notes worker nodes using the Pod Identity Agent must reach the EKS Auth API; in private subnet architectures, an EKS Auth PrivateLink endpoint may be needed. ([AWS Documentation][30])

Similarly, your workloads/controllers need network access to:

```text
Secrets Manager

STS

other required AWS APIs
```

through:

```text
NAT
or
VPC endpoints
```

depending on network design.

Secret failures can therefore be:

```text
NETWORKING.
```

---

# 14.1496 Secret retrieval packet/control path

```text
ESO Pod
   │
   ▼
Pod Identity Agent
   │
   ▼
EKS Auth
   │
   ▼
Temporary IAM credential
   │
   ▼
STS AssumeRole
   │
   ▼
Secrets Manager API
   │
   ▼
KMS decrypt
   │
   ▼
secret response
```

Any broken hop matters.

This is a control-plane/networking problem, not just YAML.

---

# 14.1497 Application secret exposure paths

Even with perfect Secrets Manager architecture, secret may still leak through:

```text
application logs

crash dumps

debug endpoints

environment inspection

kubectl exec

Kubernetes RBAC

CI logs

APM spans

exception messages.
```

A secret manager protects storage/distribution.

It does not protect against:

```text
application printing the secret.
```

---

# 14.1498 Never log environment configuration indiscriminately

Bad Node startup code:

```javascript
console.log(process.env);
```

Now:

```text
MONGODB_URI
JWT_SECRET
API_KEY
```

may enter:

```text
CloudWatch

Loki

ELK

incident tooling.
```

Secret hygiene must continue inside application code.

---

# 14.1499 Secret vs token lifetime

Best security often comes from avoiding long-lived secrets entirely.

Prefer where possible:

```text
workload identity

short-lived credentials

dynamic secrets

federation
```

over:

```text
static access key
that lives for three years.
```

Our Pod Identity design is an example:

```text
ESO doesn't store AWS access-key pair.
```

AWS provides temporary role credentials to the Pod. ([AWS Documentation][12])

---

# 14.1500 Secret-less cloud authentication

For AWS APIs, ideal application architecture often becomes:

```text
Pod
 │
 ▼
ServiceAccount
 │
 ▼
Pod Identity
 │
 ▼
IAM
 │
 ▼
AWS API
```

No:

```text
AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY
```

in Kubernetes at all.

If Todo needs S3 access:

```text
use IAM workload identity
```

rather than storing static AWS keys in Secrets Manager merely to copy them into Kubernetes.

---

# 14.1501 Not every credential belongs in Secrets Manager

Ask first:

> Can this be replaced with workload identity?

Examples:

```text
AWS API access
→ IAM role / Pod Identity

Kubernetes access
→ ServiceAccount

human Git access
→ SSO

cloud CI access
→ OIDC federation / temporary role.
```

Secrets Manager is excellent for secret material that **must actually remain a secret value**, but identity federation can eliminate many static credentials entirely.

---

# 14.1502 Secret design hierarchy

Prefer in this order where practical:

```text
1.
No secret required
(workload identity)


2.
Dynamic/short-lived credential


3.
Externally managed rotating secret


4.
Long-lived externally managed secret


5.
Static secret copied manually
```

The further down the list:

```text
more operational risk.
```

---

# 14.1503 Git secret scanning

Your repositories should still use:

```text
secret scanning

pre-commit detection

CI checks

provider push protection where available

code review.
```

Why?

Because External Secrets architecture does not prevent a developer from accidentally writing:

```yaml
password: hunter2
```

into another file.

Prevention must exist before commit.

---

# 14.1504 `.gitignore` isn't a security boundary

Adding:

```text
.env
```

to `.gitignore` is useful.

But:

```text
.gitignore
```

does not protect a file that was already committed.

Nor does it stop:

```text
copy/paste

another filename

force-add.
```

Use it as hygiene.

Not as your only secret-control mechanism.

---

# 14.1505 `.env` files

Local development often uses:

```text
.env
```

Fine if handled carefully.

Production:

```text
.env committed to Git
```

is not acceptable simply because:

```text
application framework expects .env.
```

At runtime, secret-management tooling can inject environment values without committing the production `.env`.

---

# 14.1506 Secret files in containers

Never bake:

```text
production password
```

into:

```text
Dockerfile

image layer

COPY secret.json

build ARG

image environment metadata.
```

Container image is an artifact distributed across:

```text
registry

nodes

caches

scanners.
```

Secrets belong at runtime whenever possible.

---

# 14.1507 CI secret handling

CI may need credentials for:

```text
Git

artifact registry

signing

deployment promotion.
```

Prefer:

```text
temporary federated credentials
```

where possible.

If static CI secrets exist:

```text
masked output

restricted scope

rotation

no `set -x`

no echo

no artifact inclusion.
```

GitOps does not automatically make CI secret-safe.

---

# 14.1508 Production responsibility model

```text
APPLICATION TEAM

owns:
which secret reference app consumes
```

```text
PLATFORM TEAM

owns:
ESO
SecretStore conventions
Kubernetes secret delivery
```

```text
CLOUD/SECURITY TEAM

owns:
IAM
Secrets Manager
KMS
rotation standards
```

```text
SRE

owns:
availability/monitoring/runbooks
```

Great architecture makes ownership explicit.

---

# 14.1509 AppProject protection

For normal application teams allow:

```text
ExternalSecret
```

perhaps:

```text
SecretStore
```

if namespaced team ownership is intended.

Usually deny them:

```text
ClusterSecretStore

ClusterExternalSecret
```

unless platform policy says otherwise.

Because cluster-scoped secret delivery is a much larger privilege.

ESO itself emphasizes careful RBAC around cluster-scoped store resources. ([External Secrets][8])

---

# 14.1510 Secret backend separation

A very mature organization might use:

```text
Dev Secrets Manager account

Prod Secrets Manager account
```

or at least:

```text
separate KMS keys

separate IAM roles

separate prefixes.
```

Then:

```text
compromised Dev workload
```

should not have a credential path to:

```text
Production secrets.
```

Environment isolation should exist beyond naming conventions.

---

# 14.1511 Never rely on prefix naming alone

Having:

```text
prod/*
```

and:

```text
dev/*
```

is useful.

But if IAM says:

```json
"Resource": "*"
```

prefixes are organizational only.

Security requires policy:

```text
Dev IAM role
→ dev/*
```

not:

```text
Dev role
→ everything
but engineers promise not to ask for prod.
```

---

# 14.1512 Secret audit chain

For an incident, we want:

```text
Who changed secret value?
```

AWS audit.

```text
Which version became current?
```

Secrets Manager version history.

```text
When did ESO refresh?
```

ExternalSecret status/events.

```text
Which Kubernetes Secret version changed?
```

Kubernetes audit/resource history where available.

```text
When did application restart?
```

Kubernetes rollout/event logs.

This creates a usable incident timeline.

---

# 14.1513 Secret promotion audit

Unlike image promotion:

```text
Git PR
→ Prod image change
```

secret rotation may produce:

```text
no Git commit.
```

Therefore your audit source shifts to:

```text
Secrets Manager

CloudTrail

secret operator status

Kubernetes events.
```

Git isn't the only audit system in a GitOps architecture.

That's an important senior-level realization.

---

# 14.1514 Git is desired-state authority, not universal data store

Git is excellent for:

```text
declarations

resource references

policies

versioned application config.
```

It is not automatically the right place for:

```text
password values

binary private keys

ephemeral credentials

dynamic tokens.
```

GitOps means:

> Git describes the desired system.

It does **not** mean:

> Every byte the system uses must live in Git.

---

# 14.1515 Sealed Secrets vs ESO vs Vault comparison

| Question                  | ESO + Secrets Manager                                    | Sealed Secrets                         | Vault/VSO                              |
| ------------------------- | -------------------------------------------------------- | -------------------------------------- | -------------------------------------- |
| Plaintext in Git?         | No                                                       | No                                     | No                                     |
| Ciphertext in Git?        | Usually no                                               | Yes                                    | Usually no                             |
| External secret backend?  | AWS Secrets Manager                                      | Not required for payload               | Vault                                  |
| Dynamic secrets           | Provider-dependent; typically static/rotated AWS secrets | No native dynamic leasing              | Strong                                 |
| Kubernetes Secret created | Yes                                                      | Yes                                    | Usually yes with VSO                   |
| Main credential           | AWS IAM                                                  | Sealing private key                    | Vault auth identity                    |
| Rotation model            | Secrets Manager + ESO refresh                            | Re-seal/update or controller workflows | Vault leases/static refresh            |
| Best fit                  | AWS-native workloads                                     | Git-centric/simple clusters            | Enterprise/multi-cloud/dynamic secrets |
| DR concern                | IAM/KMS/provider availability                            | private sealing key                    | Vault availability/unseal/auth         |

Current docs support ESO synchronization, Sealed Secret scopes, and Vault operator/static/dynamic secret models as described above. ([External Secrets][4])

---

# 14.1516 Our recommended production design

For our AWS/EKS Todo platform:

```text
AWS Secrets Manager
=
authoritative secret store


EKS Pod Identity
=
ESO base cloud identity


Per-store AssumeRole
=
team/application AWS isolation


SecretStore
=
namespace/provider binding


ExternalSecret
=
Git-managed secret reference


Kubernetes Secret
=
runtime delivery object


Pod
=
secret consumer
```

And:

```text
Argo CD
```

never needs the Todo database password itself.

---

# 14.1517 Todo final secret architecture

```text
                     CORPORATE GIT

                    todo-gitops repo
                          │
                          ▼
                   ExternalSecret
                          │
                          ▼
                       Argo CD
                          │
                          ▼
                     EKS Cluster
                          │
                          ▼
              External Secrets Operator
                          │
                          ▼
               EKS Pod Identity Role
                          │
                   sts:AssumeRole
                          │
                          ▼
             Todo Prod Secret Reader
                          │
                          ▼
                AWS Secrets Manager
                          │
                  KMS / IAM policy
                          │
                          ▼
              production/todo/backend
                          │
                          ▼
                Kubernetes Secret
                          │
                          ▼
                  Todo Deployment
                          │
                          ▼
                        Pod
```

That's the production pattern to remember.

---

# 14.1518 Interview — Why shouldn't Kubernetes Secret YAML be committed?

Strong answer:

> **Because the `data` field is base64-encoded, not encrypted. Anyone able to read the repository can decode it, and removing the secret later does not erase it from Git history or existing clones. For GitOps I prefer storing secret references in Git and resolving values from a destination-side secret manager such as AWS Secrets Manager through External Secrets Operator.**

Kubernetes explicitly describes base64 representation and recommends encryption-at-rest and external secret-store considerations. ([Kubernetes][31])

---

# 14.1519 Interview — Why External Secrets with Argo?

Strong answer:

> **Argo manages the `ExternalSecret` declaration while External Secrets Operator retrieves the value from the provider and creates the Kubernetes Secret. This keeps Argo's manifest-generation process away from plaintext values and allows secret rotation to happen independently from application sync. Current Argo documentation strongly recommends this destination-cluster model.** ([Argo CD][1])

---

# 14.1520 Interview — SecretStore vs ClusterSecretStore

```text
SecretStore
=
namespaced

ClusterSecretStore
=
cluster-scoped and reusable
across namespaces.
```

A namespaced SecretStore is often safer for strict multi-team isolation; cluster-scoped stores require stronger RBAC and provider-level restrictions. ([External Secrets][6])

---

# 14.1521 Interview — Does ESO remove Kubernetes Secrets?

Not necessarily.

Normal ESO:

```text
external backend
→ Kubernetes Secret.
```

Therefore Kubernetes Secret protections still matter.

If the goal is to avoid native Kubernetes Secret persistence altogether, investigate CSI-style secret mounts or other provider-specific mechanisms. Argo lists both ESO and CSI as destination-side approaches. ([Argo CD][1])

---

# 14.1522 Interview — IRSA vs EKS Pod Identity for ESO

Strong answer:

> **Both are supported AWS authentication patterns. EKS Pod Identity associates IAM roles with Kubernetes service accounts through EKS without requiring a per-cluster IAM OIDC provider; with ESO it naturally provides the controller Pod's AWS identity. IRSA can also be used, including ESO's JWT/serviceAccountRef model for store-specific service account credentials. The choice depends on cluster standards and the isolation model I need.** ([AWS Documentation][12])

---

# 14.1523 Interview — Why per-store AssumeRole?

> **A shared ESO controller identity can become overly broad. ESO supports assuming a role specified by each SecretStore, so I can use a narrow controller base role and per-team target roles such as `todo-prod-secret-reader` and `payments-prod-secret-reader`, each restricted to its own Secrets Manager resources.** ([External Secrets][10])

---

# 14.1524 Interview — Does secret rotation automatically update the app?

Answer:

> **Not necessarily. The external provider may rotate successfully and ESO may update the Kubernetes Secret, but a running application consuming the Secret through environment variables usually needs a restart or another reload mechanism to use the new value. Rotation must be designed end-to-end: provider → Kubernetes Secret → workload reload.**

---

# 14.1525 Interview — Sealed Secrets vs External Secrets

Strong answer:

> **Sealed Secrets stores encrypted secret ciphertext in Git and relies on the cluster's sealing private key to decrypt it. External Secrets stores only a reference in Git while the actual value remains in an external provider such as AWS Secrets Manager. I generally prefer External Secrets where an enterprise secret manager already exists, while Sealed Secrets can be convenient for a simpler Git-centric model.** ([GitHub][20])

---

# 14.1526 Interview — What happens if Sealed Secrets private key is lost?

Strong answer:

> The Git repository still contains encrypted SealedSecrets, but a rebuilt controller without the appropriate private key may not be able to decrypt those existing ciphertexts. Therefore controller-key backup/recovery is a core part of the Sealed Secrets DR plan.

---

# 14.1527 Interview — Why Vault?

Strong answer:

> **Vault becomes compelling when you need capabilities such as dynamic leased credentials, revocation, PKI, multiple authentication methods, and multi-cloud/on-prem secret management. Vault Secrets Operator can synchronize both static and dynamic Vault secrets into Kubernetes-native Secrets.** ([HashiCorp Developer][21])

---

# 14.1528 Interview — Why not argocd-vault-plugin for everything?

Strong current answer:

> **Manifest-generation plugins can work, but current Argo CD guidance cautions against manifest-generation secret injection for new designs. It requires Argo's rendering path to access secret values, can expose generated values through Argo's manifest/cache path, and couples rotation more closely to application sync. Destination-side secret management is preferred.** ([Argo CD][1])

---

# 14.1529 Interview — Why not give ESO `GetSecretValue *`?

Because:

```text
ExternalSecret
```

then becomes a potential arbitrary secret-reading interface.

Better:

```text
namespace-scoped stores

per-team role assumption

specific Secrets Manager ARN policies

restricted ExternalSecret RBAC.
```

ESO's own security guidance emphasizes restricting access to ESO resources because the controller operates with elevated privileges. ([External Secrets][8])

---

# 14.1530 Interview — How do you manage cross-account AWS secrets?

Strong answer:

> **I use a controlled cross-account IAM model, commonly role chaining from the EKS workload/ESO identity into a target secret-reader role in the secret-owning account. Cross-account Secrets Manager access also requires the appropriate identity/resource authorization and KMS key access when a customer-managed KMS key is used. EKS Pod Identity supports cross-account target-role patterns.** ([AWS Documentation][19])

---

# 14.1531 Interview — what does Git contain?

Answer:

```text
secret identifier

provider reference

target Kubernetes Secret name

key mapping

refresh behavior

metadata
```

not:

```text
plaintext secret value.
```

Excellent concise answer.

---

# 14.1532 Production secret checklist

Before releasing Todo to Production:

```text
□ No plaintext secret in Git

□ No production secret in Helm values

□ No secret baked into image

□ No static AWS access keys for ESO

□ SecretStore scope is intentional

□ ExternalSecret permissions are restricted

□ ClusterSecretStore use is reviewed

□ IAM role accesses only required secrets

□ AssumeRole trust is least privilege

□ KMS permissions are correct

□ Pod Identity association is correct

□ Secret region is explicit

□ ExternalSecret Ready monitored

□ rotation strategy documented

□ application reload behavior tested

□ old secret version behavior understood

□ secret values are not logged

□ Kubernetes Secret RBAC is restricted

□ encryption-at-rest posture is understood

□ cross-account policy tested if used

□ DR secret retrieval is tested

□ bootstrap credentials have recovery path

□ Argo repo/cluster credentials have recovery path
```

---

# 14.1533 Never-forget Lesson 11 rules

```text
1.
Base64 is not encryption.


2.
Do not commit plaintext secrets.


3.
Deleting a leaked Git secret
does not undo compromise.


4.
Rotate leaked credentials.


5.
Git should store secret intent,
not secret value.


6.
Argo should normally deploy
ExternalSecret,
not plaintext Secret values.


7.
Current Argo guidance favors
destination-side secret management.


8.
ESO fetches external values.


9.
SecretStore is namespaced.


10.
ClusterSecretStore is cluster-wide.


11.
Cluster-scoped secret access
has larger blast radius.


12.
ESO itself is privileged.


13.
ExternalSecret RBAC matters.


14.
AWS IAM is the real
external secret boundary.


15.
Use temporary workload identities
instead of static AWS keys.


16.
EKS Pod Identity is supported
for ESO controller identity.


17.
IRSA remains supported.


18.
Pod Identity and per-store
serviceAccountRef are different models.


19.
Use AssumeRole to create
per-store AWS isolation.


20.
SecretStore answers HOW.


21.
ExternalSecret answers WHAT.


22.
Kubernetes Secret is runtime copy.


23.
Pod consumes Kubernetes Secret.


24.
Secrets Manager can rotate values
without Git commits.


25.
ESO refreshes provider values.


26.
Secret refresh does not guarantee
application reload.


27.
Environment-variable secrets
often require Pod restart.


28.
Database rotation must update
the real database credential too.


29.
AWSCURRENT is a moving version stage.


30.
VersionId identifies
an immutable secret version.


31.
ExternalSecret and generated Secret
should not be dual-owned by Argo.


32.
GitOps health
does not prove secret freshness.


33.
Monitor the ESO reconciliation loop.


34.
Cross-account secrets require
IAM + resource + KMS reasoning.


35.
DR must include secret availability.


36.
Sealed Secrets stores ciphertext in Git.


37.
Sealed Secrets key recovery
is part of DR.


38.
Vault is strong for
dynamic credentials and leasing.


39.
CSI can mount secret data
without the ordinary native-Secret model.


40.
Argo's own repo/cluster credentials
are also sensitive Secrets.


41.
Bootstrap secrets need
special recovery design.


42.
Prefer workload identity
over storing cloud credentials.


43.
Secret managers don't prevent
application logging leaks.


44.
One secret/resource
should have one authoritative owner.


45.
GitOps does not mean
every byte belongs in Git.
```

---

# 14.1534 Lesson 11 troubleshooting flow

Memorize:

# **R-S-I-P-F-K-A**

```text
REFERENCE
    │
    ▼
STORE
    │
    ▼
IDENTITY
    │
    ▼
PROVIDER
    │
    ▼
FETCH / REFRESH
    │
    ▼
KUBERNETES SECRET
    │
    ▼
APPLICATION
```

Examples:

```text
Secret key typo
→ R


SecretStore NotReady
→ S


AccessDenied
→ I / P


ExternalSecret not syncing
→ F


Target Secret missing
→ K


Secret correct but app auth fails
→ A
```

This is the secret-management equivalent of our earlier layered troubleshooting methods.

---

# 14.1535 Final production architecture

```text
                           DEVELOPER
                               │
                               ▼
                              GIT
                               │
                     no secret values
                               │
                               ▼
                         ARGO CD
                               │
                               ▼
                      ExternalSecret
                               │
                               ▼
                    External Secrets
                        Operator
                               │
                               ▼
                      EKS Pod Identity
                               │
                               ▼
                         AssumeRole
                               │
                               ▼
                   Todo Secret Reader
                               │
                               ▼
                   AWS Secrets Manager
                               │
                     encrypted / IAM
                               │
                               ▼
                       Secret Version
                               │
                               ▼
                    Kubernetes Secret
                               │
                               ▼
                      Todo Backend Pod
```

And rotation:

```text
Secrets Manager
      │
      ▼
rotate credential
      │
      ▼
ESO refresh
      │
      ▼
Kubernetes Secret changes
      │
      ▼
Pod reload/restart
      │
      ▼
application uses new credential
```

The never-forget sentence is:

> **Git declares which secret the application needs; the secret manager owns the value; the secret operator delivers it; the workload consumes it.**

---

# ✅ Module 14 — Lesson 11 Complete

You now understand:

```text
✓ Kubernetes Secret fundamentals

✓ base64 vs encryption

✓ Git secret leakage

✓ secret ownership

✓ destination-side secret management

✓ Argo secret-management recommendation

✓ External Secrets Operator

✓ SecretStore

✓ ClusterSecretStore

✓ ExternalSecret

✓ data vs dataFrom

✓ target Secret lifecycle

✓ refreshPolicy

✓ refreshInterval

✓ AWS Secrets Manager

✓ Secrets Manager versions

✓ AWSCURRENT / AWSPREVIOUS

✓ automatic rotation

✓ EKS Pod Identity

✓ IRSA

✓ per-store AssumeRole

✓ least-privilege IAM

✓ KMS considerations

✓ cross-account secrets

✓ application reload during rotation

✓ DR secret architecture

✓ Sealed Secrets

✓ SealedSecret scopes

✓ Sealed Secret key recovery

✓ Vault Secrets Operator

✓ Vault dynamic secrets

✓ CSI secret delivery

✓ AWS ASCP

✓ Argo repository credentials

✓ Argo cluster credentials

✓ bootstrap secret problem

✓ secret troubleshooting
```

# Next — Module 14, Lesson 12

## Sync Waves, Resource Hooks, Database Migrations & Dependency Ordering

Now we solve this production deployment problem:

```text
New application release requires:

1. CRD exists
2. database migration runs
3. backend rolls out
4. backend becomes Healthy
5. frontend updates
6. smoke test runs
7. old resources prune
```

We cannot simply say:

```text
"Apply all YAML at once."
```

We'll build:

```text
                   GIT CHANGE
                       │
                       ▼
                    PreSync
                       │
                  migration job
                       │
                       ▼
                   Sync Wave -10
                       │
                    CRDs
                       │
                       ▼
                   Sync Wave 0
                       │
                    backend
                       │
                       ▼
                   Sync Wave 10
                       │
                   frontend
                       │
                       ▼
                    PostSync
                       │
                   smoke test
```

Then we'll go deeply into **Argo hook phases, `PreSync`, `Sync`, `PostSync`, `SyncFail`, `PostDelete`, resource hooks, hook deletion policies, sync-wave ordering, negative waves, CRD/controller dependencies, database migrations, idempotency, migration failures, Helm hook differences, health-gated synchronization, pruning order, and real production zero-downtime deployment patterns.**

[1]: https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/?utm_source=chatgpt.com "Secret Management - Declarative GitOps CD for Kubernetes"
[2]: https://kubernetes.io/docs/concepts/configuration/secret/?utm_source=chatgpt.com "Secrets"
[3]: https://kubernetes.io/docs/concepts/configuration/configmap/?utm_source=chatgpt.com "ConfigMaps"
[4]: https://external-secrets.io/?utm_source=chatgpt.com "External Secrets Operator: Introduction"
[5]: https://external-secrets.io/latest/introduction/getting-started/?utm_source=chatgpt.com "Getting started"
[6]: https://external-secrets.io/latest/api/secretstore/?utm_source=chatgpt.com "SecretStore - External Secrets Operator"
[7]: https://external-secrets.io/latest/api/clustersecretstore/?utm_source=chatgpt.com "ClusterSecretStore - External Secrets Operator"
[8]: https://external-secrets.io/latest/guides/security-best-practices/?utm_source=chatgpt.com "Security Best Practices"
[9]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html?utm_source=chatgpt.com "Rotate AWS Secrets Manager secrets - AWS Documentation"
[10]: https://external-secrets.io/latest/provider/aws-access/ "AWS Access - External Secrets Operator"
[11]: https://external-secrets.io/latest/provider/aws-secrets-manager/?utm_source=chatgpt.com "AWS Secrets Manager"
[12]: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html "Learn how EKS Pod Identity grants pods access to AWS services - Amazon EKS"
[13]: https://external-secrets.io/latest/api/externalsecret/?utm_source=chatgpt.com "ExternalSecret - External Secrets Operator"
[14]: https://external-secrets.io/latest/api/spec/?utm_source=chatgpt.com "API specification"
[15]: https://external-secrets.io/latest/provider/aws-secrets-manager/ "AWS Secrets Manager - External Secrets Operator"
[16]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_schedule.html?utm_source=chatgpt.com "Rotation schedules - AWS Secrets Manager"
[17]: https://external-secrets.io/v0.8.1/api/spec/?utm_source=chatgpt.com "API specification"
[18]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html "Access AWS Secrets Manager secrets from a different account - AWS Secrets Manager"
[19]: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-assign-target-role.html?utm_source=chatgpt.com "Access AWS Resources using EKS Pod Identity Target IAM ..."
[20]: https://github.com/bitnami-labs/sealed-secrets?ref=rpi4cluster.com&utm_source=chatgpt.com "bitnami/sealed-secrets at rpi4cluster.com"
[21]: https://developer.hashicorp.com/vault/tutorials/kubernetes-introduction/vault-secrets-operator?utm_source=chatgpt.com "Manage Kubernetes native secrets with the Vault Secrets ..."
[22]: https://developer.hashicorp.com/vault/docs/auth/kubernetes?utm_source=chatgpt.com "Kubernetes - Auth Methods | Vault"
[23]: https://developer.hashicorp.com/vault/docs/deploy/kubernetes/comparisons?utm_source=chatgpt.com "Kubernetes integrations comparison | Vault"
[24]: https://docs.aws.amazon.com/eks/latest/userguide/manage-secrets.html?utm_source=chatgpt.com "Use AWS Secrets Manager secrets with Amazon EKS Pods"
[25]: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/?utm_source=chatgpt.com "Declarative Setup - Declarative GitOps CD for Kubernetes"
[26]: https://argo-cd.readthedocs.io/en/stable/operator-manual/argocd-repositories-yaml/?utm_source=chatgpt.com "argocd-repositories.yaml example - Argo CD - Read the Docs"
[27]: https://argo-cd.readthedocs.io/en/stable/operator-manual/security/?utm_source=chatgpt.com "Security - Argo CD - Read the Docs"
[28]: https://argo-cd.readthedocs.io/en/stable/operator-manual/tls/?utm_source=chatgpt.com "TLS configuration - Declarative GitOps CD for Kubernetes"
[29]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html?utm_source=chatgpt.com "AWS Secrets Manager - AWS Documentation"
[30]: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html?utm_source=chatgpt.com "Set up the Amazon EKS Pod Identity Agent"
[31]: https://kubernetes.io/docs/concepts/security/secrets-good-practices/?utm_source=chatgpt.com "Good practices for Kubernetes Secrets"
