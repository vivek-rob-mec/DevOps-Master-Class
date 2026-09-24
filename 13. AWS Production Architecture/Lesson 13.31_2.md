# AWS Masterclass — Lesson 31 Part 2

# AWS Secrets Manager vs Systems Manager Parameter Store

## Secrets, Configuration, Rotation, Versioning, KMS, Private Access & Production Integration

In Part 1, we learned:

```text
KMS
=
cryptographic key management
```

Now we answer:

```text
WHERE SHOULD APPLICATION
PASSWORDS, API KEYS,
DATABASE CREDENTIALS,
TOKENS AND CONFIGURATION
ACTUALLY LIVE?
```

The two AWS services engineers most often compare are:

```text
AWS Secrets Manager
```

and:

```text
AWS Systems Manager Parameter Store
```

The simplest mental model is:

```text
                        APPLICATION VALUE
                               │
                 Is it sensitive credential material?
                               │
                    ┌──────────┴──────────┐
                   YES                   NO
                    │                     │
                    ▼                     ▼
             Does it need           Parameter Store
           managed rotation?
                    │
              ┌─────┴─────┐
             YES           NO
              │             │
              ▼             ▼
      Secrets Manager   Either may fit,
                        but Parameter Store
                        is often simpler
```

The key rule:

```text
Secrets Manager
=
SECRET LIFECYCLE

Parameter Store
=
CONFIGURATION HIERARCHY
+
OPTIONAL SECURE VALUES
```

---

# 1. What Exactly Is a Secret?

Examples:

```text
Database password

API token

OAuth client secret

JWT signing secret

third-party API key

SMTP password

GitHub token

service credentials
```

These values create authority.

If stolen, an attacker may be able to authenticate or impersonate something.

That makes them different from configuration such as:

```text
APP_ENV=production

LOG_LEVEL=info

API_TIMEOUT=30

FEATURE_X=true

BACKEND_URL=https://api.example.com
```

---

# 2. Secrets vs Configuration

Use this distinction:

```text
CONFIGURATION
=
How should application behave?
```

```text
SECRET
=
What proves application identity
or grants privileged access?
```

Example:

```text
DB_HOST
=
configuration

DB_PORT
=
configuration

DB_NAME
=
configuration

DB_USERNAME
=
possibly sensitive

DB_PASSWORD
=
SECRET
```

---

# 3. Bad Secret Management

You have probably seen this:

```env
DB_HOST=prod-db.example.com
DB_USER=admin
DB_PASSWORD=SuperSecret123
STRIPE_SECRET_KEY=sk_live_...
JWT_SECRET=abcdef...
```

stored in:

```text
.env
```

Then copied into:

```text
Git repository

Docker image

Jenkinsfile

EC2 user-data

Terraform tfvars

Slack message

deployment script
```

The problem is not merely encryption.

The real problem is lifecycle:

```text
Who can retrieve it?

Who changed it?

Can it rotate?

Can old credentials be invalidated?

Can applications retrieve it dynamically?

Can access be audited?
```

---

# 4. Secrets Manager Mental Model

AWS Secrets Manager is designed around:

```text
Secret
 │
 ├── encrypted secret value
 ├── metadata
 ├── versions
 ├── staging labels
 ├── rotation configuration
 ├── resource policy
 ├── tags
 └── regional replicas
```

Secret values are protected using envelope encryption with AWS KMS. Secrets Manager requests a data key from KMS, encrypts the secret value with that data key, and stores the encrypted data key with the secret metadata. ([AWS Documentation][1])

---

# 5. Secrets Manager Uses Envelope Encryption

This should now look familiar from Part 1:

```text
                   KMS KEY
                      │
                      ▼
               GenerateDataKey
                      │
              ┌───────┴────────┐
              ▼                ▼
       plaintext data key   encrypted data key
              │                │
              ▼                │
        encrypt secret         │
              │                │
              ▼                ▼
        encrypted secret + encrypted data key
```

Secrets Manager uses a 256-bit AES data key for the secret value and removes the plaintext data key from memory after use. ([AWS Documentation][1])

---

# 6. Default KMS Key

When creating a secret, you can use:

```text
AWS managed KMS key:
aws/secretsmanager
```

or:

```text
your own customer managed symmetric KMS key
```

Secrets Manager supports symmetric encryption KMS keys for this encryption workflow. ([AWS Documentation][1])

For many simple same-account workloads:

```text
aws/secretsmanager
```

is operationally easy.

For stronger enterprise control:

```text
customer managed KMS key
```

gives you custom:

```text
key policies
cross-account permissions
lifecycle control
audit separation
```

---

# 7. The Secret Name Is Not Encrypted

This is a subtle security point.

Secrets Manager encrypts:

```text
secret VALUE
```

but metadata such as:

```text
secret name
description
rotation settings
KMS key ARN
tags
```

is not part of the encrypted secret value. ([AWS Documentation][1])

Therefore avoid names like:

```text
/prod/customer-vip-john-smith-credit-card-password
```

A better name:

```text
/prod/payments/database
```

---

# 8. Secret Size

A Secrets Manager secret value can currently contain up to:

```text
65,536 bytes
```

of text or binary secret data. ([AWS Documentation][2])

So Secrets Manager is appropriate for credentials and secret documents—not:

```text
500 MB certificate archive

database backup

large binary blob
```

Use services such as S3 for large encrypted objects.

---

# 9. Store Structured Secrets

Instead of:

```text
Secret:
SuperPassword123
```

you can store JSON:

```json
{
  "username": "todo_app",
  "password": "SuperPassword123",
  "host": "prod-db.xxxxxx.ap-south-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "todo"
}
```

This is particularly useful for database rotation because rotation logic may need the connection information as well as the credential. AWS rotation templates expect specific JSON structures for supported secret types. ([AWS Documentation][3])

---

# 10. Secrets Have Versions

Every time you change or rotate the secret value, Secrets Manager can create another:

```text
SECRET VERSION
```

Conceptually:

```text
Secret:
prod/todo/database
        │
        ├── version 1
        ├── version 2
        └── version 3
```

AWS uses **staging labels** rather than forcing your application to track version IDs directly. ([AWS Documentation][4])

---

# 11. `AWSCURRENT`

This label means:

```text
THIS IS THE CURRENT
APPLICATION SECRET
```

Example:

```text
version-a
AWSPREVIOUS

version-b
AWSCURRENT
```

When an application calls:

```text
GetSecretValue
```

without specifying a version, Secrets Manager returns the version labeled:

```text
AWSCURRENT
```

by default. ([AWS Documentation][4])

---

# 12. `AWSPREVIOUS`

After current secret changes:

```text
old AWSCURRENT
      │
      ▼
AWSPREVIOUS
```

Secrets Manager automatically moves `AWSPREVIOUS` to the version that previously carried `AWSCURRENT` when the current stage is moved. ([AWS Documentation][5])

This gives you an extremely useful rollback/reference point:

```text
CURRENT
=
new credential

PREVIOUS
=
last known credential
```

---

# 13. `AWSPENDING`

During rotation:

```text
AWSPENDING
```

represents the candidate new secret version.

Mental model:

```text
AWSCURRENT
=
production credential

AWSPENDING
=
credential being prepared/tested

AWSPREVIOUS
=
previous production credential
```

AWS uses these staging labels during its rotation workflow. ([AWS Documentation][4])

---

# 14. Rotation Is More Than Changing the Stored Value

This is a huge distinction.

Bad “rotation”:

```text
Secrets Manager password
changes

BUT

database password does not
```

Result:

```text
Application retrieves new password
        │
        ▼
Database still expects old password
        │
        ▼
AUTHENTICATION FAILURE
```

Real credential rotation means:

```text
SECRET STORE
+
TARGET SYSTEM
```

must agree.

AWS defines Secrets Manager rotation as updating both the stored secret and the credentials in the database/service. ([AWS Documentation][6])

---

# 15. Secrets Manager Rotation Models

Current Secrets Manager supports multiple rotation approaches.

Broadly:

```text
Managed Rotation

Lambda Rotation

Managed External Secret Rotation
```

For many secrets managed directly by AWS services, managed rotation handles the lifecycle without your own rotation Lambda. Other secret types can use a Lambda rotation function. ([AWS Documentation][6])

---

# 16. Managed Rotation

Conceptually:

```text
AWS service
    │
    ▼
manages credential lifecycle
    │
    ▼
Secrets Manager
```

This removes the operational burden of maintaining a custom rotation Lambda where the integrated AWS service supports the managed model. ([AWS Documentation][6])

Always prefer the simplest supported native integration that meets the requirement.

---

# 17. Lambda Rotation

For many database or custom secrets:

```text
Secrets Manager
      │
      ▼
Rotation Lambda
      │
      ├── create new credential
      ├── update service/database
      ├── test credential
      └── promote secret
```

AWS provides rotation templates for supported systems including RDS/Aurora database engines, DocumentDB, Redshift, ElastiCache, and others, plus a generic starting template for custom secret types. ([AWS Documentation][7])

---

# 18. Rotation Function — Four-Step Mental Model

For Lambda-based rotation, memorize:

```text
createSecret
     │
     ▼
setSecret
     │
     ▼
testSecret
     │
     ▼
finishSecret
```

Conceptually:

```text
CREATE
generate candidate secret

SET
apply candidate to database/service

TEST
verify candidate works

FINISH
move AWSCURRENT to candidate
```

The final step promotes the pending version and moves the previous current version to `AWSPREVIOUS`. ([AWS Documentation][8])

---

# 19. Rotation Timeline

```text
Before rotation:

Version A
AWSCURRENT


During:

Version A
AWSCURRENT

Version B
AWSPENDING


After success:

Version A
AWSPREVIOUS

Version B
AWSCURRENT
```

This staging-label design lets the new credential exist and be tested before it becomes the normal application credential. ([AWS Documentation][4])

---

# 20. Rotation Can Be Frequent

Secrets Manager currently allows scheduled rotation as often as:

```text
every 4 hours
```

with rotation windows as short as one hour, depending on the schedule design. ([AWS Documentation][9])

That does **not** mean every secret should rotate every four hours.

Choose rotation frequency according to:

```text
risk

system compatibility

credential lifetime

database behavior

operational cost

application refresh behavior
```

---

# 21. Single-User Rotation

Single-user rotation means:

```text
same database user
```

gets its password changed.

Example:

```text
todo_app
password=A
```

becomes:

```text
todo_app
password=B
```

This is straightforward.

But during the password transition, clients still using the old credential may temporarily fail if they haven't refreshed quickly enough.

---

# 22. Alternating-Users Rotation

Alternative:

```text
todo_app_a
todo_app_b
```

Secrets Manager alternates which user's credential is current.

Conceptually:

```text
Rotation 1

A = active
B = being updated


Rotation 2

B = active
A = being updated
```

AWS recommends alternating-user rotation where improved availability during credential changes is important because one valid user can remain available while the other is updated. ([AWS Documentation][10])

---

# 23. Why Application Secret Caching Matters

Imagine:

```text
10,000 requests/second
```

and every HTTP request does:

```text
GetSecretValue
```

That creates unnecessary:

```text
latency
API requests
cost
dependency pressure
```

AWS recommends client-side caching for Secrets Manager secret retrieval. Supported caching options exist for multiple SDK languages and for Lambda through the Parameters and Secrets extension. ([AWS Documentation][11])

---

# 24. Correct Application Pattern

Bad:

```text
HTTP request
    │
    ▼
Secrets Manager
    │
    ▼
DB password
    │
    ▼
Database
```

for every request.

Better:

```text
Application
    │
    ▼
secret cache
    │
 ┌──┴───┐
 HIT    MISS/expired
 │         │
 ▼         ▼
use     Secrets Manager
           │
           ▼
      refresh cache
```

You want:

```text
cached secret
+
controlled refresh
```

not an AWS API call for every business request.

---

# 25. Rotation + Cache Interaction

Caching introduces an important problem:

```text
Secret rotates
     │
     ▼
Application cache
still holds previous secret
```

Therefore cache TTL must be designed so applications refresh credentials in a safe period.

Applications should also handle authentication failure gracefully:

```text
DB auth failed
     │
     ▼
invalidate cached secret
     │
     ▼
fetch AWSCURRENT
     │
     ▼
retry safely
```

This is a stronger pattern than simply caching the credential forever.

---

# 26. AWS Parameters and Secrets Lambda Extension

For Lambda, AWS provides the:

```text
AWS Parameters and Secrets Lambda Extension
```

It works with:

```text
Secrets Manager
+
Parameter Store
```

and locally caches retrieved values. Your Lambda calls a localhost endpoint rather than requiring your application code to call the remote service every invocation. ([AWS Documentation][12])

Conceptually:

```text
Lambda Function
      │
      ▼
localhost extension
      │
      ▼
local cache
      │
      ▼
Secrets Manager / Parameter Store
```

---

# 27. IAM for Secrets Retrieval

A workload normally needs:

```text
secretsmanager:GetSecretValue
```

for the specific secret.

Example:

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:ap-south-1:111122223333:secret:prod/todo/database-*"
}
```

If a customer-managed KMS key protects the secret, KMS authorization also becomes part of the retrieval path because Secrets Manager calls KMS on behalf of the requesting principal. ([AWS Documentation][1])

---

# 28. Secret Access Architecture

```text
Application Role
       │
       ├── secretsmanager:GetSecretValue
       │
       ▼
Secrets Manager
       │
       ▼
KMS Decrypt
       │
       ▼
Customer KMS Key
```

Think:

```text
Secrets Manager authorization
+
KMS authorization
```

not merely one IAM permission.

---

# 29. Restrict KMS Use to Secrets Manager

An advanced key policy/IAM control can use:

```text
kms:ViaService
```

to restrict key use so cryptographic requests occur through:

```text
secretsmanager.<region>.amazonaws.com
```

Secrets Manager documents this as a way to constrain the KMS key to service-mediated use. ([AWS Documentation][1])

That gives:

```text
Application
   │
   ▼
Secrets Manager
   │
   ▼
KMS
```

while reducing direct use of the key outside the intended service path.

---

# 30. Secrets Manager Resource Policies

Secrets Manager supports:

```text
RESOURCE-BASED POLICIES
```

on individual secrets.

That means a secret itself can specify:

```text
WHO may call which actions
against this secret?
```

Resource policies can also support cross-account access. ([AWS Documentation][13])

---

# 31. Cross-Account Secret Access

Suppose:

```text
Account A
owns secret

Account B
ApplicationRole
needs secret
```

AWS's documented cross-account pattern requires coordinated authorization:

```text
Account A
secret resource policy
        +
Account A
KMS key policy
        +
Account B
ApplicationRole identity policy
```

The caller generally needs access both to `secretsmanager:GetSecretValue` and to the customer-managed KMS key protecting the cross-account secret. ([AWS Documentation][14])

---

# 32. Cross-Account Diagram

```text
ACCOUNT B
ApplicationRole
      │
      │ identity policy
      ▼
────────────────────────────
ACCOUNT A
      │
      ▼
Secret resource policy
      │
      ▼
Secrets Manager secret
      │
      ▼
Customer-managed KMS key
      │
      ▼
KMS key policy
```

All layers must line up.

This is exactly the same multi-layer authorization thinking we developed during IAM.

---

# 33. Secrets Manager Private Access

Workloads inside a private VPC do **not** need a public IP or NAT gateway simply to access Secrets Manager.

You can create an:

```text
Interface VPC Endpoint
```

powered by AWS PrivateLink. Traffic can then reach Secrets Manager privately over the AWS network. ([AWS Documentation][15])

Architecture:

```text
Private EC2 / ECS / Lambda
           │
           ▼
Secrets Manager
Interface Endpoint
           │
           ▼
AWS PrivateLink
           │
           ▼
Secrets Manager API
```

---

# 34. Endpoint Private DNS

With private DNS enabled on the interface endpoint, applications can continue to call the normal Regional Secrets Manager hostname while DNS resolves it to the private endpoint path. ([AWS Documentation][15])

This means your application code does not need:

```text
special endpoint URL
```

just because you made the access private.

---

# 35. Rotation Lambda Networking

Suppose database lives in:

```text
private subnet
```

Rotation Lambda needs to reach:

```text
database
+
Secrets Manager
```

AWS recommends providing the appropriate VPC connectivity and, where appropriate, a Secrets Manager VPC endpoint so the rotation function can reach the service privately. ([AWS Documentation][15])

A common failure chain is:

```text
Rotation Lambda
      │
      X
      ▼
RDS
```

because of:

```text
security group
subnet
route
DNS
endpoint
```

not because Secrets Manager rotation logic itself is wrong. AWS's rotation troubleshooting guidance specifically calls out network connectivity between rotation Lambda and database/service. ([AWS Documentation][16])

---

# 36. Multi-Region Secrets

Secrets Manager supports:

```text
PRIMARY SECRET
+
REGIONAL REPLICA SECRETS
```

A replica remains linked to the primary. ([AWS Documentation][4])

Example:

```text
Primary
ap-south-1
    │
    ├──────────────► ap-southeast-1
    │
    └──────────────► eu-central-1
```

---

# 37. Rotation With Replicas

When rotation is enabled on the primary secret:

```text
Primary rotates
      │
      ▼
new secret value
      │
      ├── replica Singapore
      └── replica Frankfurt
```

AWS propagates the new secret value to associated regional replicas; you don't separately configure independent rotation for each replica. ([AWS Documentation][17])

---

# 38. Replica Secret Is the Same Secret Value

Replication is not:

```text
Mumbai secret
=
Mumbai DB password

Singapore secret
=
Singapore DB password
```

by default.

A replica is a copy of the primary secret value.

If regional environments require different hostnames or credentials, you must design those values intentionally rather than assuming replication changes them automatically. ([AWS Documentation][18])

---

# 39. Parameter Store Mental Model

Now switch services.

Parameter Store is part of:

```text
AWS Systems Manager
```

and provides hierarchical storage for configuration data.

Think:

```text
Parameter Store
    │
    ├── /todo/dev/api-url
    ├── /todo/dev/log-level
    ├── /todo/prod/api-url
    └── /todo/prod/db/password
```

Values can use parameter types including:

```text
String

StringList

SecureString
```

for appropriate configuration requirements. ([AWS Documentation][19])

---

# 40. Parameter Store Hierarchies

This is one of Parameter Store's strongest features.

Instead of:

```text
DBPASSWORD_PROD
APIURL_PROD
LOGLEVEL_PROD
```

use:

```text
/todo/prod/database/password

/todo/prod/database/host

/todo/prod/api/url

/todo/prod/log/level
```

Parameter names can use hierarchical paths up to 15 levels deep. ([AWS Documentation][20])

This makes configuration easier to organize by:

```text
application
environment
service
component
```

---

# 41. Example Hierarchy

```text
/todo
│
├── dev
│   ├── api
│   │   └── url
│   └── log
│       └── level
│
├── staging
│   └── ...
│
└── prod
    ├── api
    │   └── url
    ├── database
    │   ├── host
    │   └── password
    └── feature
        └── new-ui
```

Now application IAM can potentially be scoped to:

```text
/todo/prod/*
```

rather than every parameter in the account.

---

# 42. Parameter Types

## `String`

Example:

```text
/todo/prod/log-level
=
INFO
```

## `StringList`

Example:

```text
/todo/prod/allowed-regions
=
ap-south-1,ap-southeast-1
```

## `SecureString`

Example:

```text
/todo/prod/vendor/api-key
```

encrypted using AWS KMS. Parameter Store supports only symmetric KMS keys for `SecureString` encryption. ([AWS Documentation][21])

---

# 43. Standard vs Advanced Parameters

Current Parameter Store provides:

```text
STANDARD

ADVANCED
```

tiers. ([AWS Documentation][22])

The key differences are:

| Feature                         | Standard | Advanced |
| ------------------------------- | -------: | -------: |
| Max parameters/account/Region   |   10,000 |  100,000 |
| Max parameter size              |     4 KB |     8 KB |
| Parameter policies              |       No |      Yes |
| Cross-account sharing           |       No |      Yes |
| Additional parameter charge     |       No |      Yes |
| Can upgrade Standard → Advanced |      Yes |        — |
| Advanced → Standard directly    |       No |       No |

These are the current AWS-documented tier characteristics. ([AWS Documentation][22])

---

# 44. Standard Parameter Encryption Is Surprisingly Different

Remember Part 1:

```text
KMS direct Encrypt
```

has a 4-KiB plaintext limit.

Parameter Store standard `SecureString` values also max out at:

```text
4 KB
```

and AWS encrypts them by calling KMS `Encrypt` directly. ([AWS Documentation][21])

Architecture:

```text
SecureString
<= 4 KB
    │
    ▼
KMS Encrypt
    │
    ▼
ciphertext
```

No separate data key is needed for a standard SecureString.

---

# 45. Advanced SecureString Uses Envelope Encryption

Advanced `SecureString` behaves differently.

AWS uses:

```text
AWS Encryption SDK
+
KMS GenerateDataKey
```

Conceptually:

```text
Advanced SecureString
      │
      ▼
unique data key
      │
      ▼
encrypt parameter
      │
      ▼
KMS encrypts data key
```

This is **envelope encryption**, exactly what we learned in Part 1. ([AWS Documentation][21])

---

# 46. This Is a Great Interview Detail

Standard SecureString:

```text
KMS Encrypt directly
```

Advanced SecureString:

```text
Envelope Encryption
+
AWS Encryption SDK
+
GenerateDataKey
```

AWS explicitly documents this difference. ([AWS Documentation][21])

You now understand **why** the encryption implementation differs rather than memorizing two arbitrary tiers.

---

# 47. Default Parameter Store KMS Key

If you do not choose a customer-managed KMS key for SecureString, Parameter Store can use the AWS managed key:

```text
alias/aws/ssm
```

for the account. ([AWS Documentation][21])

For stronger policy control, use a:

```text
customer-managed symmetric KMS key
```

---

# 48. Retrieve SecureString

Without decrypting:

```bash
aws ssm get-parameter \
  --name /todo/prod/database/password \
  --region ap-south-1
```

To receive plaintext:

```bash
aws ssm get-parameter \
  --name /todo/prod/database/password \
  --with-decryption \
  --region ap-south-1
```

When `--with-decryption` is used, Parameter Store calls KMS decrypt on behalf of the caller. ([AWS Documentation][21])

---

# 49. Parameter IAM

For ordinary retrieval:

```text
ssm:GetParameter
```

For paths:

```text
ssm:GetParametersByPath
```

For SecureString using a customer-managed key:

```text
kms:Decrypt
```

is also required as part of the retrieval path. AWS documents those permissions for direct and Lambda-extension retrieval. ([AWS Documentation][23])

---

# 50. Parameter Store Path Permission Trap

Suppose a role can recursively retrieve:

```text
/todo/prod
```

with:

```text
GetParametersByPath
```

That can expose children beneath that path.

Therefore design hierarchies intentionally.

Do not put:

```text
/todo/prod/public-config
```

and:

```text
/todo/prod/admin-master-password
```

under the same broad permission root if different identities require different access.

---

# 51. Parameter Policies

Advanced parameters support policies such as:

```text
Expiration

ExpirationNotification

NoChangeNotification
```

These policies are enforced asynchronously by Parameter Store and can generate events/notifications around parameter lifecycle conditions. ([AWS Documentation][24])

---

# 52. `Expiration`

Example:

```text
Temporary vendor token
expires:
2026-09-01
```

Parameter policy can automatically delete the parameter after the configured expiration time. ([AWS Documentation][24])

Use cases:

```text
temporary configuration

short-lived migration values

one-time integration data
```

But remember:

```text
deleting parameter
≠
revoking a third-party credential
```

if that credential exists in another system.

---

# 53. `ExpirationNotification`

Instead of discovering expiration after outage:

```text
Parameter approaching expiration
        │
        ▼
EventBridge event
        │
        ▼
notification / automation
```

Parameter Store parameter policies can generate expiration-notification events before deletion. ([AWS Documentation][24])

---

# 54. `NoChangeNotification`

This is particularly useful for secret-like values.

Example:

```text
/vendor/api-key
```

has not changed in:

```text
90 days
```

Parameter Store can trigger a:

```text
NoChangeNotification
```

policy event. ([AWS Documentation][24])

Important distinction:

```text
NoChangeNotification
=
"this value has not changed"
```

not:

```text
automatic credential rotation
```

---

# 55. Parameter Policies Are Not Secrets Manager Rotation

This is one of the most important comparison points.

Parameter Store can say:

```text
"This parameter has not changed
for 90 days."
```

But it does not inherently know how to:

```text
change PostgreSQL password
+
update stored parameter
+
test new credential
+
switch production safely
```

Secrets Manager's rotation system is designed for this kind of secret lifecycle. ([AWS Documentation][6])

So:

```text
Parameter Store policy
≠
credential rotation engine
```

---

# 56. Cross-Account Parameter Store

Current Parameter Store supports sharing **advanced parameters** across AWS accounts using:

```text
AWS Resource Access Manager
```

You can share with:

```text
specific accounts

OUs

the Organization
```

depending on the AWS RAM resource share. ([AWS Documentation][25])

Standard parameters do not have this advanced-parameter cross-account sharing model. ([AWS Documentation][22])

---

# 57. Cross-Account SecureString Parameters

For a shared `SecureString`, the parameter must use:

```text
customer-managed KMS key
```

and the KMS key must be shared/authorized separately because the AWS-managed `aws/ssm` key cannot serve that cross-account sharing use case. ([AWS Documentation][26])

Again:

```text
Parameter access
+
KMS access
```

both matter.

---

# 58. Parameter Store vs Secrets Manager — Master Comparison

| Requirement                   | Secrets Manager                  | Parameter Store                |
| ----------------------------- | -------------------------------- | ------------------------------ |
| Plain configuration           | Possible but usually unnecessary | **Excellent**                  |
| Password/API credential       | **Excellent**                    | Possible with SecureString     |
| Native secret lifecycle       | **Strong**                       | Limited                        |
| Automatic credential rotation | **Yes**                          | Not a native equivalent        |
| Version staging labels        | `AWSCURRENT`, etc.               | Parameter versions/labels      |
| Hierarchical config paths     | Limited naming patterns          | **Excellent**                  |
| KMS encryption                | Yes                              | SecureString                   |
| Secret size                   | up to ~64 KiB                    | 4 KB / 8 KB tier-dependent     |
| Cross-account                 | Resource policy + KMS            | Advanced sharing via RAM       |
| Client caching guidance       | Strong                           | Available/application driven   |
| Best fit                      | Credentials/secrets              | Config + simpler secure values |

The current service limits and sharing/rotation models are documented by AWS. ([AWS Documentation][2])

---

# 59. The 5-Second Decision Rule

Use:

```text
Secrets Manager
```

when you hear:

```text
database credentials

automatic rotation

credential lifecycle

AWSCURRENT/AWSPREVIOUS

managed secret

cross-account secret policy
```

Use:

```text
Parameter Store
```

when you hear:

```text
configuration hierarchy

application settings

feature flags

environment values

simple SecureString

many low-cost parameters
```

---

# 60. What About Database Passwords?

Preferred production thought process:

```text
Database password
      │
      ▼
Does it need rotation?
      │
     YES
      │
      ▼
Secrets Manager
```

Especially for:

```text
RDS
Aurora
DocumentDB
Redshift
```

where Secrets Manager has supported rotation patterns/templates. ([AWS Documentation][27])

---

# 61. What About API Keys?

Example:

```text
Stripe API key
```

If:

```text
highly sensitive
needs controlled rotation
needs resource policy
needs central secret auditing
```

prefer:

```text
Secrets Manager
```

If:

```text
simple secure parameter
rotation handled externally
small value
lower complexity
```

Parameter Store `SecureString` can be reasonable.

The service choice depends on **lifecycle requirements**, not merely “is encrypted?”

---

# 62. What About Feature Flags?

Example:

```text
/new-checkout/enabled=true
```

This is not a secret.

Use:

```text
Parameter Store
```

or a purpose-built feature-flag/configuration service if richer behavior is required.

Do not put every configuration value into Secrets Manager simply because it exists.

---

# 63. What About Database Hostname?

```text
prod-db.xxxxx.rds.amazonaws.com
```

Usually:

```text
CONFIGURATION
```

not:

```text
SECRET
```

A clean design might be:

```text
Parameter Store
/todo/prod/db/host

Secrets Manager
/prod/todo/db-credentials
```

Then each service solves the problem it is best at.

---

# 64. What About JWT Signing Keys?

If the JWT system uses a:

```text
shared symmetric secret
```

that is credential-grade material.

Secrets Manager can be appropriate.

If using:

```text
asymmetric signing
```

you may instead evaluate KMS asymmetric signing APIs depending on your architecture, because private key material can remain protected inside KMS.

That connects directly to Part 1's:

```text
SIGN_VERIFY
```

key usage.

---

# 65. EC2 Application Pattern

Production architecture:

```text
EC2
 │
 ▼
Instance Profile
 │
 ▼
AppRole
 │
 ├── secretsmanager:GetSecretValue
 │
 └── kms:Decrypt
 │
 ▼
Secrets Manager
```

Application code does **not** need:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

stored in `.env`.

The EC2 role supplies temporary AWS credentials.

---

# 66. ECS Application Pattern

Conceptually:

```text
ECS Task
   │
   ▼
Task Role
   │
   ▼
Secrets Manager
```

Do not confuse:

```text
Task Execution Role
```

with:

```text
Application Task Role
```

The application should receive only the permission it actually needs.

We'll go much deeper during ECS/Fargate.

---

# 67. Lambda Pattern

```text
Lambda
  │
  ▼
Execution Role
  │
  ▼
Parameters & Secrets Extension
  │
  ▼
local cache
  │
  ▼
Secrets Manager / Parameter Store
```

The extension uses the Lambda execution role's permissions; for SecureString Parameter Store retrieval, the role also needs appropriate KMS decrypt permission. ([AWS Documentation][12])

---

# 68. Node.js Secrets Manager Example

A simple runtime retrieval pattern:

```javascript
import {
  SecretsManagerClient,
  GetSecretValueCommand
} from "@aws-sdk/client-secrets-manager";

const client = new SecretsManagerClient({
  region: "ap-south-1"
});

export async function getDbSecret() {
  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: "prod/todo/database"
    })
  );

  return JSON.parse(response.SecretString);
}
```

Do not hardcode AWS credentials in this client.

Let the standard SDK credential provider chain use the workload's IAM role.

---

# 69. Add Application Caching

Conceptually:

```javascript
let cachedSecret;
let expiresAt = 0;

export async function getDbSecret() {
  const now = Date.now();

  if (cachedSecret && now < expiresAt) {
    return cachedSecret;
  }

  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: "prod/todo/database"
    })
  );

  cachedSecret = JSON.parse(response.SecretString);

  expiresAt = now + 5 * 60 * 1000;

  return cachedSecret;
}
```

Production caching libraries/extensions are preferable when available because AWS specifically recommends caching secret values to reduce latency and API calls. ([AWS Documentation][11])

---

# 70. Do Not Log Secrets

Bad:

```javascript
console.log("Database credentials:", secret);
```

Also bad:

```text
logger.info(JSON.stringify(process.env))
```

because this may include:

```text
passwords
tokens
AWS credentials
API keys
```

Your logging architecture should log:

```text
secret ARN/name
retrieval success/failure
version metadata where appropriate
```

but never the actual credential.

---

# 71. Environment Variables Are Not a Secret Manager

A common architecture:

```text
Secrets Manager
      │
      ▼
deployment pipeline
      │
      ▼
inject secret permanently
into environment
```

can be acceptable in some systems, but it weakens runtime rotation because the application may need:

```text
restart/redeployment
```

to obtain a new value.

Dynamic retrieval allows the application to refresh credentials after rotation.

Choose deliberately.

---

# 72. Docker Image Anti-Pattern

Never do:

```dockerfile
ENV DB_PASSWORD=SuperSecret123
```

or:

```dockerfile
COPY .env /app/.env
```

for production secrets.

Why?

The value can become embedded in:

```text
image layers
registry
build cache
CI logs
developer machines
```

Secret injection should occur at runtime through the workload's identity/secrets integration.

---

# 73. Jenkins Anti-Pattern

Bad:

```groovy
environment {
    AWS_SECRET_ACCESS_KEY = "..."
    DB_PASSWORD = "..."
}
```

especially if hardcoded in source.

Better:

```text
Jenkins workload identity
      │
      ▼
AWS role
      │
      ▼
Secrets Manager
```

and retrieve only the secret required for the deployment/runtime operation.

---

# 74. Terraform Secret Trap

Consider:

```hcl
variable "database_password" {
  type      = string
  sensitive = true
}
```

Many engineers think:

```text
sensitive = true
```

means:

```text
encrypted and absent from state
```

It does **not**.

HashiCorp documents that sensitive values are normally still stored in Terraform plan/state; the sensitive flag primarily redacts them from normal display. ([HashiCorp Developer][28])

### Never forget

```text
Terraform sensitive
=
hide from normal UI

NOT
=
remove from state
```

---

# 75. This Is Why Terraform State Is Sensitive

If Terraform creates a Secrets Manager secret version using:

```hcl
secret_string = var.database_password
```

the sensitive value may become part of Terraform state depending on the provider/resource argument behavior.

Therefore:

```text
secure backend
access controls
state encryption
versioning
audit
```

are essential. HashiCorp explicitly warns that state can contain sensitive values and must be protected. ([HashiCorp Developer][29])

---

# 76. Modern Terraform Improvement — Ephemeral / Write-Only Values

Modern Terraform supports:

```text
ephemeral values

write-only resource arguments
```

for supported Terraform/provider versions and resources, allowing sensitive values to be used during an operation without persisting the actual value into plan/state. HashiCorp specifically demonstrates this with Secrets Manager and RDS write-only secret/password arguments. ([HashiCorp Developer][30])

This is a major improvement over older secret-handling patterns.

---

# 77. Terraform Secrets Manager Metadata

The AWS provider resource:

```text
aws_secretsmanager_secret
```

manages the secret metadata, while secret values are managed separately through secret-version resources. ([Terraform Registry][31])

Conceptually:

```hcl
resource "aws_secretsmanager_secret" "db" {
  name = "prod/todo/database"

  kms_key_id = aws_kms_key.secrets.arn
}
```

The key lesson is to separate:

```text
secret object/metadata
```

from:

```text
secret VALUE lifecycle
```

---

# 78. Terraform Parameter Store

The AWS provider exposes:

```text
aws_ssm_parameter
```

for Systems Manager Parameter Store values. ([Terraform Registry][32])

Example configuration value:

```hcl
resource "aws_ssm_parameter" "api_url" {
  name  = "/todo/prod/api/url"
  type  = "String"
  value = "https://api.example.com"
}
```

Secure values require more care because the actual secret value may interact with Terraform state.

---

# 79. Better Terraform Secret Principle

Where possible:

```text
Terraform
creates:

secret container
KMS key
IAM policy
rotation infrastructure
```

while:

```text
runtime secret value
```

is generated/managed through a mechanism that doesn't unnecessarily expose it in long-lived Terraform artifacts.

Modern Terraform's ephemeral/write-only features can help when the supported resource/provider path allows it. ([HashiCorp Developer][30])

---

# 80. Hands-On Lab — Create a Secret

Use:

```bash
export AWS_REGION=ap-south-1
```

First:

```bash
aws sts get-caller-identity
```

Create:

```bash
aws secretsmanager create-secret \
  --name prod/todo/database-demo \
  --description "Lesson 31 database secret" \
  --secret-string '{
    "username":"todo_app",
    "password":"DemoPassword123",
    "host":"db.internal.example.com",
    "port":5432,
    "dbname":"todo"
  }' \
  --region "$AWS_REGION"
```

For a real production secret, don't place the value directly in shell history as shown in a teaching demonstration; use safer input mechanisms and secure secret generation.

---

# 81. Retrieve the Secret

```bash
aws secretsmanager get-secret-value \
  --secret-id prod/todo/database-demo \
  --region "$AWS_REGION"
```

You'll see metadata including the version stages, and the current secret value if authorized.

Use query filtering carefully:

```bash
aws secretsmanager get-secret-value \
  --secret-id prod/todo/database-demo \
  --query SecretString \
  --output text \
  --region "$AWS_REGION"
```

Again:

```text
terminal output
=
potential secret exposure
```

so avoid putting these commands into publicly captured CI logs.

---

# 82. Inspect Versions

```bash
aws secretsmanager list-secret-version-ids \
  --secret-id prod/todo/database-demo \
  --region "$AWS_REGION"
```

Look for:

```text
AWSCURRENT
AWSPREVIOUS
AWSPENDING
```

depending on lifecycle/rotation state.

Secrets Manager always maintains an `AWSCURRENT` version; rotation uses the pending/previous staging labels as described earlier. ([AWS Documentation][4])

---

# 83. Update the Secret

```bash
aws secretsmanager put-secret-value \
  --secret-id prod/todo/database-demo \
  --secret-string '{
    "username":"todo_app",
    "password":"DemoPassword456",
    "host":"db.internal.example.com",
    "port":5432,
    "dbname":"todo"
  }' \
  --region "$AWS_REGION"
```

This creates another version and moves `AWSCURRENT` to the newly stored value. ([AWS Documentation][33])

Again, this alone does not change a real database user's password—that is why rotation orchestration matters.

---

# 84. Hands-On Parameter Store

Create ordinary config:

```bash
aws ssm put-parameter \
  --name "/todo/prod/log-level" \
  --type String \
  --value "INFO" \
  --region "$AWS_REGION"
```

Retrieve:

```bash
aws ssm get-parameter \
  --name "/todo/prod/log-level" \
  --region "$AWS_REGION"
```

---

# 85. Create SecureString

```bash
aws ssm put-parameter \
  --name "/todo/prod/vendor/api-key" \
  --type SecureString \
  --value "demo-secret-value" \
  --region "$AWS_REGION"
```

Without specifying a key, the standard SecureString path uses the account's AWS-managed Systems Manager key `aws/ssm`. ([AWS Documentation][21])

---

# 86. Retrieve Without Decryption

```bash
aws ssm get-parameter \
  --name "/todo/prod/vendor/api-key" \
  --region "$AWS_REGION"
```

Retrieve plaintext:

```bash
aws ssm get-parameter \
  --name "/todo/prod/vendor/api-key" \
  --with-decryption \
  --region "$AWS_REGION"
```

The decrypt path requires appropriate KMS authorization. ([AWS Documentation][21])

---

# 87. Retrieve a Hierarchy

```bash
aws ssm get-parameters-by-path \
  --path "/todo/prod" \
  --recursive \
  --with-decryption \
  --region "$AWS_REGION"
```

This is extremely useful for loading application configuration.

But it also illustrates why:

```text
hierarchy design
=
security design
```

because recursive access can expose multiple values beneath a path.

---

# 88. Production Architecture

A good configuration split:

```text
                         Todo API
                            │
                            ▼
                         AppRole
                            │
             ┌──────────────┴───────────────┐
             ▼                              ▼
      Parameter Store                 Secrets Manager
             │                              │
      /todo/prod/api/url             DB credentials
      /todo/prod/log-level           OAuth secret
      /todo/prod/feature/*           API keys
             │                              │
             │                              ▼
             │                             KMS
             └───────────────┬──────────────┘
                             ▼
                       Application cache
```

This is often cleaner than forcing every value into one service.

---

# 89. Secrets Manager AccessDenied Runbook

Error:

```text
AccessDeniedException
GetSecretValue
```

Troubleshoot:

```text
1. aws sts get-caller-identity

2. secretsmanager:GetSecretValue?

3. correct secret ARN?

4. secret resource policy?

5. permissions boundary?

6. SCP/RCP?

7. KMS key policy?

8. kms:Decrypt?

9. VPC endpoint policy?

10. cross-account trust?
```

Secrets Manager access and KMS access are separate applicable authorization layers when a customer-managed key is involved. ([AWS Documentation][1])

---

# 90. Rotation Failure Runbook

Rotation stuck at:

```text
AWSPENDING
```

Check:

```text
Rotation Lambda invocation

Lambda execution role

Secrets Manager API permission

database connectivity

security group

database credential validity

KMS permission

VPC endpoint/DNS

rotation step logs

AWSCURRENT/AWSPREVIOUS validity
```

AWS's rotation troubleshooting guidance specifically recommends checking network connectivity and validating the `AWSCURRENT`, `AWSPREVIOUS`, and pending credential states when rotation fails. ([AWS Documentation][16])

---

# 91. Database Rotation Failure Example

Symptom:

```text
setSecret:
Unable to log into database
```

Possible causes:

```text
Lambda cannot reach DB

DB SG rejects Lambda

secret contains wrong credential

rotation networking is broken
```

AWS specifically identifies network/security-group and credential problems as common causes of database rotation failure. ([AWS Documentation][16])

---

# 92. Parameter Store AccessDenied

Error:

```text
AccessDeniedException
ssm:GetParameter
```

Check:

```text
ssm:GetParameter
```

If SecureString:

```text
kms:Decrypt
```

also check:

```text
correct KMS key

key policy

SCP/boundary

parameter ARN/path
```

The Lambda extension documentation explicitly calls out both `ssm:GetParameter` and `kms:Decrypt` for SecureString retrieval. ([AWS Documentation][12])

---

# 93. Parameter Store KMS Error

Standard SecureString creation requires:

```text
kms:Encrypt
```

for the chosen KMS key.

Advanced SecureString creation uses envelope encryption and requires:

```text
kms:GenerateDataKey
```

while retrieval of either encrypted form requires:

```text
kms:Decrypt
```

according to the current Parameter Store encryption architecture. ([AWS Documentation][21])

This is an excellent troubleshooting detail.

---

# 94. SAA-C03 Scenario

> Application configuration includes API URL, log level, and feature flag. No credential rotation required.

Best fit:

```text
Systems Manager Parameter Store
```

especially with hierarchical naming.

---

# 95. SAA-C03 Scenario

> RDS password must automatically rotate periodically without embedding credentials in application source.

Best fit:

```text
Secrets Manager
+
supported rotation
```

The application retrieves the current credential using the secret's `AWSCURRENT` version. ([AWS Documentation][6])

---

# 96. SAA-C03 Scenario

> Secret needs cross-account access.

Think:

```text
Secrets Manager resource policy
+
customer-managed KMS key policy
+
caller IAM policy
```

AWS documents this three-part cross-account model. ([AWS Documentation][14])

---

# 97. Scenario

> Organization wants to share common configuration across AWS accounts.

Current Parameter Store option:

```text
Advanced Parameter
+
AWS RAM
```

to share centrally managed parameters with accounts/OUs/Organization as appropriate. ([AWS Documentation][25])

---

# 98. Scenario

> Private EC2 has no NAT gateway but needs Secrets Manager.

Use:

```text
Secrets Manager
Interface VPC Endpoint
```

powered by PrivateLink. ([AWS Documentation][15])

---

# 99. Scenario

> Secret rotates but application continues using old credential for six hours.

Likely:

```text
application cache
```

or:

```text
secret injected only at process start
```

needs redesign.

Think:

```text
rotation frequency
+
cache TTL
+
refresh/retry behavior
```

as one system.

---

# 100. Scenario

> Engineer changed secret value in Secrets Manager manually but DB logins now fail.

Why?

Because:

```text
secret storage
was updated

BUT

database credential
was not
```

Manual `PutSecretValue` is not equivalent to a coordinated rotation workflow. Secrets Manager rotation specifically updates both the stored secret and target database/service. ([AWS Documentation][6])

---

# 101. Scenario

> Need notification if a parameter hasn't changed for 90 days.

Use:

```text
Advanced Parameter
+
NoChangeNotification
```

and EventBridge integration as needed. ([AWS Documentation][24])

---

# 102. Scenario

> Need AWS to actually change the database password every 30 days.

Do **not** answer:

```text
Parameter Store NoChangeNotification
```

Use:

```text
Secrets Manager rotation
```

because detecting stale configuration is not the same as credential rotation.

---

# 103. The Terraform State Trap — Certification/Interview Version

Question:

> Terraform variable is marked `sensitive = true`. Is the secret guaranteed absent from state?

Answer:

```text
NO
```

`sensitive` normally hides display but does not automatically prevent persistence in plan/state. Modern Terraform offers ephemeral/write-only mechanisms for supported workflows when values must stay out of state. ([HashiCorp Developer][28])

---

# 104. Never-Forget Decision Tree

```text
                     VALUE
                       │
            Does it grant authority?
                       │
             ┌─────────┴─────────┐
            NO                  YES
             │                   │
             ▼                   ▼
      Parameter Store      Does it need
                         managed rotation?
                              │
                       ┌──────┴──────┐
                      YES            NO
                       │              │
                       ▼              ▼
              Secrets Manager     Is simple
                                 SecureString
                                good enough?
                                    │
                              ┌─────┴─────┐
                             YES          NO
                              │            │
                              ▼            ▼
                       Parameter Store   Secrets
                         SecureString    Manager
```

---

# 105. Never-Forget Version Model

```text
                  SECRET

                Version A
              AWSPREVIOUS

                Version B
               AWSCURRENT

                Version C
               AWSPENDING
              during rotation
```

Application normally asks:

```text
AWSCURRENT
```

Rotation prepares:

```text
AWSPENDING
```

Previous current becomes:

```text
AWSPREVIOUS
```

after successful promotion. ([AWS Documentation][4])

---

# 106. Never-Forget Configuration Model

```text
/todo
 ├── dev
 │    ├── api/url
 │    └── log/level
 │
 └── prod
      ├── api/url
      ├── log/level
      └── feature/new-ui
```

That is:

```text
Parameter Store hierarchy
```

Use the hierarchy itself as part of your:

```text
organization
IAM design
environment isolation
```

---

# 107. 30 Rules to Burn Into Memory

```text
1. A secret grants authority.

2. Configuration controls behavior.

3. Secrets Manager is designed for
   secret lifecycle management.

4. Parameter Store is excellent for
   hierarchical application configuration.

5. Secrets Manager protects secret values
   with KMS envelope encryption.

6. Secret metadata such as names/tags
   is not the encrypted secret value.

7. Secrets Manager values can currently
   be up to 65,536 bytes.

8. AWSCURRENT = current secret version.

9. AWSPREVIOUS = prior current version.

10. AWSPENDING = candidate during rotation.

11. Rotation must update both the secret
    and the target system.

12. Managed rotation is preferred when
    the integrated service supports it.

13. Lambda rotation can implement custom rotation.

14. Rotation can currently run as often
    as every four hours.

15. Alternating-user rotation improves
    credential-transition availability.

16. Do not call GetSecretValue
    for every application request.

17. Cache secrets with controlled TTL.

18. VPC workloads can privately reach
    Secrets Manager using PrivateLink.

19. Cross-account Secrets Manager access
    involves secret policy + KMS + caller IAM.

20. Parameter Store supports String,
    StringList and SecureString.

21. Standard parameters currently max at 4 KB.

22. Advanced parameters currently max at 8 KB.

23. Standard SecureString uses direct KMS Encrypt.

24. Advanced SecureString uses envelope encryption.

25. Advanced parameters support lifecycle policies.

26. NoChangeNotification is not credential rotation.

27. Advanced parameters can be shared with AWS RAM.

28. `sensitive = true` in Terraform does not
    automatically remove secrets from state.

29. Never bake secrets into Docker images,
    Git repositories or Jenkinsfiles.

30. Workloads should retrieve secrets through
    IAM roles and temporary AWS credentials.
```

The strongest rule from this lesson:

```text
DO NOT ASK ONLY:

"IS THIS VALUE ENCRYPTED?"
```

Ask:

```text
WHO CAN READ IT?

HOW IS IT ROTATED?

WHAT HAPPENS WHEN IT CHANGES?

HOW DOES THE APP REFRESH IT?

CAN ACCESS BE AUDITED?

CAN THE TARGET CREDENTIAL BE REVOKED?

WHAT IS THE BLAST RADIUS?
```

That is **production secret management**.

---

# ✅ Lesson 31 Part 2 Complete

You now understand:

```text
✓ secret vs configuration
✓ Secrets Manager architecture
✓ KMS envelope encryption
✓ aws/secretsmanager
✓ customer-managed keys
✓ secret metadata vs values
✓ 65,536-byte secret limit

✓ secret versions
✓ AWSCURRENT
✓ AWSPREVIOUS
✓ AWSPENDING

✓ managed rotation
✓ Lambda rotation
✓ createSecret
✓ setSecret
✓ testSecret
✓ finishSecret
✓ single-user rotation
✓ alternating-user rotation
✓ 4-hour minimum rotation cadence

✓ secret caching
✓ refresh behavior
✓ rotation/cache interaction
✓ Lambda Parameters and Secrets extension

✓ IAM secret retrieval
✓ KMS interaction
✓ kms:ViaService
✓ secret resource policies
✓ cross-account secrets
✓ VPC endpoints
✓ PrivateLink
✓ multi-Region secret replication

✓ Parameter Store
✓ hierarchical configuration
✓ String
✓ StringList
✓ SecureString
✓ standard vs advanced tiers
✓ 10k vs 100k parameters
✓ 4-KB vs 8-KB value sizes
✓ parameter policies
✓ Expiration
✓ ExpirationNotification
✓ NoChangeNotification
✓ AWS RAM sharing

✓ standard SecureString direct KMS encryption
✓ advanced SecureString envelope encryption
✓ aws/ssm KMS key

✓ EC2 integration
✓ ECS mental model
✓ Lambda integration
✓ Node.js retrieval
✓ runtime caching

✓ Docker secret anti-patterns
✓ Jenkins secret anti-patterns
✓ Terraform state risks
✓ Terraform sensitive values
✓ ephemeral/write-only Terraform patterns

✓ CLI labs
✓ rotation troubleshooting
✓ KMS troubleshooting
✓ SAA-C03 / DOP-C02 scenarios
```

# Next — Lesson 31 Part 3

# **AWS Certificate Manager, TLS/HTTPS & Production Certificate Architecture**

Next we'll move from:

```text
SECRET PROTECTION AT REST
```

to:

```text
IDENTITY + ENCRYPTION IN TRANSIT
```

We’ll build TLS from first principles:

```text
Browser
   │
   │ HTTPS
   ▼
CloudFront / ALB / API Gateway
   │
   ▼
ACM Certificate
   │
   ├── public key
   ├── private key
   ├── certificate chain
   ├── CA
   ├── SAN
   ├── wildcard certificate
   └── validation
```

Then we'll cover:

```text
✓ HTTP vs HTTPS
✓ TLS handshake
✓ symmetric + asymmetric cryptography together
✓ public/private keys
✓ certificate authorities
✓ certificate chain of trust
✓ CN vs SAN
✓ wildcard certificates
✓ DNS validation
✓ email validation
✓ automatic renewal
✓ CloudFront certificate us-east-1 rule
✓ ALB Regional certificate rule
✓ API Gateway certificate placement
✓ ACM public vs private certificates
✓ AWS Private CA
✓ certificate export capabilities
✓ mTLS
✓ SNI
✓ multiple certificates on an ALB
✓ TLS policies/ciphers
✓ TLS 1.2 / TLS 1.3
✓ Route 53 + ACM integration
✓ Terraform multi-provider architecture
✓ certificate renewal failures
✓ CAA/DNS validation problems
✓ production HTTPS troubleshooting
✓ full CloudFront + ALB + Route 53 + ACM capstone
```

This will connect directly to the certificate work you've already done for **`yourdatascientist.tech`**, including why CloudFront's certificate belongs in **`us-east-1`** while your Mumbai ALB uses its certificate in **`ap-south-1`**.

[1]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html "Secret encryption and decryption in AWS Secrets Manager - AWS Secrets Manager"
[2]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_limits.html?utm_source=chatgpt.com "AWS Secrets Manager quotas"
[3]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_secret_json_structure.html?utm_source=chatgpt.com "JSON structure of AWS Secrets Manager secrets"
[4]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/whats-in-a-secret.html "What's in a Secrets Manager secret? - AWS Secrets Manager"
[5]: https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_UpdateSecretVersionStage.html?utm_source=chatgpt.com "UpdateSecretVersionStage - AWS Secrets Manager"
[6]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html "Rotate AWS Secrets Manager secrets - AWS Secrets Manager"
[7]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_available-rotation-templates.html?utm_source=chatgpt.com "AWS Secrets Manager rotation function templates"
[8]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda-functions.html?utm_source=chatgpt.com "Lambda rotation functions - AWS Secrets Manager"
[9]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_schedule.html?utm_source=chatgpt.com "Rotation schedules - AWS Secrets Manager"
[10]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/tutorials_rotation-alternating.html?utm_source=chatgpt.com "Set up alternating users rotation for AWS Secrets Manager"
[11]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html "AWS Secrets Manager best practices - AWS Secrets Manager"
[12]: https://docs.aws.amazon.com/systems-manager/latest/userguide/ps-integration-lambda-extensions.html "Using Parameter Store parameters in AWS Lambda functions - AWS Systems Manager"
[13]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_resource-policies.html?utm_source=chatgpt.com "Resource-based policies - AWS Secrets Manager"
[14]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html "Access AWS Secrets Manager secrets from a different account - AWS Secrets Manager"
[15]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html "Using an AWS Secrets Manager VPC endpoint - AWS Secrets Manager"
[16]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot_rotation.html?utm_source=chatgpt.com "Troubleshoot AWS Secrets Manager rotation"
[17]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html?utm_source=chatgpt.com "Replicate AWS Secrets Manager secrets across Regions"
[18]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets_jdbc.html?utm_source=chatgpt.com "Connect to a SQL database using JDBC with credentials in ..."
[19]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-create-console.html?utm_source=chatgpt.com "Creating a Parameter Store parameter using the console"
[20]: https://docs.aws.amazon.com/systems-manager/latest/userguide/security_iam_service-with-iam.html?utm_source=chatgpt.com "How AWS Systems Manager works with IAM"
[21]: https://docs.aws.amazon.com/systems-manager/latest/userguide/secure-string-parameter-kms-encryption.html "AWS KMS encryption for AWS Systems Manager Parameter Store SecureString parameters - AWS Systems Manager"
[22]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html "Choosing parameter tiers in Parameter Store - AWS Systems Manager"
[23]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-how-to-retrieve.html?utm_source=chatgpt.com "Getting started with Parameter Store - AWS Systems Manager"
[24]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-policies.html "Assigning parameter policies in Parameter Store - AWS Systems Manager"
[25]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-shared-parameters.html "Working with shared parameters in Parameter Store - AWS Systems Manager"
[26]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-shared-parameters.html?utm_source=chatgpt.com "Working with shared parameters in Parameter Store"
[27]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_turn-on-for-db.html?utm_source=chatgpt.com "Set up automatic rotation for Amazon RDS, Amazon Aurora ..."
[28]: https://developer.hashicorp.com/terraform/language/manage-sensitive-data?utm_source=chatgpt.com "Manage sensitive data in your configuration | Terraform"
[29]: https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables?utm_source=chatgpt.com "Protect sensitive input variables | Terraform"
[30]: https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral?utm_source=chatgpt.com "Ephemeral values in resources | Terraform"
[31]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret?utm_source=chatgpt.com "aws_secretsmanager_secret | Resources | hashicorp/aws"
[32]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter?utm_source=chatgpt.com "aws_ssm_parameter | Resources | hashicorp/aws | Terraform"
[33]: https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_UpdateSecret.html?utm_source=chatgpt.com "UpdateSecret - AWS Secrets Manager"
