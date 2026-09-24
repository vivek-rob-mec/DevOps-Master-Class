# AWS Masterclass — Lesson 31 Part 1

# AWS KMS from First Principles — Encryption, Keys, Envelope Encryption, Policies, Rotation & Multi-Region Keys

IAM answered:

```text
WHO may access the resource?
```

KMS adds another security question:

```text
EVEN IF someone can reach the resource,
can they decrypt the protected data?
```

That distinction is fundamental.

```text
IAM
 │
 ▼
Authorization
 │
 ▼
Resource
 │
 ▼
Encrypted data
 │
 ▼
KMS authorization
 │
 ▼
Plaintext
```

AWS Key Management Service is AWS's managed service for creating and controlling cryptographic keys used for encryption, decryption, signing, verification, and related cryptographic operations. KMS key material managed by AWS KMS is protected in FIPS 140-3 Security Level 3 validated HSMs and does not leave AWS KMS unencrypted. ([AWS Documentation][1])

---

# 1. Start With the Encryption Mental Model

Suppose we have:

```text
password=SuperSecret123
```

That is:

# Plaintext

After encryption:

```text
A6F9C1E3...
```

That becomes:

# Ciphertext

Conceptually:

```text
PLAINTEXT
    │
    │ Encryption algorithm
    │ +
    │ Encryption key
    ▼
CIPHERTEXT
```

To recover it:

```text
CIPHERTEXT
    │
    │ Decryption algorithm
    │ +
    │ appropriate key
    ▼
PLAINTEXT
```

The security problem therefore becomes:

> How do we protect the encryption key?

And then:

> How do we protect the key protecting that key?

That leads directly to **envelope encryption**.

---

# 2. Encryption at Rest vs Encryption in Transit

These solve different problems.

## Encryption at rest

Protects stored data:

```text
EBS volume
S3 object
RDS storage
DynamoDB data
Secrets Manager secret
backup
snapshot
```

Conceptually:

```text
DATA ON STORAGE
      │
      ▼
   ENCRYPTED
```

## Encryption in transit

Protects communication:

```text
Browser
   │ HTTPS/TLS
   ▼
CloudFront / ALB

Application
   │ TLS
   ▼
Database
```

KMS is primarily a **key-management and cryptographic control system**, heavily used by AWS services for encryption at rest. TLS certificates and ACM, which we'll cover later, primarily protect data in transit.

---

# 3. KMS Is Not Just “A Place to Store Passwords”

This misunderstanding is common.

KMS is about:

```text
CRYPTOGRAPHIC KEYS
```

Secrets Manager is about:

```text
SECRETS
passwords
API tokens
credentials
```

Secrets Manager itself can then use:

```text
KMS
```

to protect those secrets.

Architecture:

```text
Database Password
      │
      ▼
Secrets Manager
      │
      ▼
Envelope Encryption
      │
      ▼
AWS KMS
```

Secrets Manager uses AWS KMS envelope encryption and includes secret/version information in the KMS encryption context. ([AWS Documentation][2])

---

# 4. The KMS Key

The central KMS object is:

# KMS key

Think of it as:

```text
KMS Key
 │
 ├── Key material
 ├── Key ID
 ├── ARN
 ├── Key policy
 ├── State
 ├── Rotation configuration
 ├── Tags
 └── Optional aliases
```

Customer managed keys give you lifecycle control including policies, grants, rotation, enable/disable state, aliases, tags, and deletion scheduling. ([AWS Documentation][3])

---

# 5. KMS Key ≠ Raw Key Material

This is subtle but important.

When you interact with:

```text
arn:aws:kms:ap-south-1:123456789012:key/abcd...
```

you are interacting with a managed KMS resource.

You do not normally receive the KMS key material itself.

```text
Application
    │
    ▼
AWS KMS API
    │
    ▼
HSM-protected key material
```

AWS KMS performs the cryptographic operation for you rather than exporting AWS KMS-generated key material in plaintext. ([AWS Documentation][4])

---

# 6. Three Ownership Models

You need to distinguish:

```text
AWS owned key

AWS managed key

Customer managed key
```

These names look similar but give you very different levels of control. ([AWS Documentation][3])

---

# 7. AWS Owned Keys

An AWS owned key is managed in an AWS service-owned account and may be used by an AWS service to protect customer resources.

You generally:

```text
do not create it
do not manage its policy
do not rotate it
do not see it as a KMS key in your account
```

AWS controls its lifecycle. ([AWS Documentation][3])

Think:

```text
Maximum convenience
Minimum customer key control
```

---

# 8. AWS Managed Keys

An AWS managed key exists in **your AWS account** but is created and managed for you by an integrated AWS service.

Common aliases look like:

```text
alias/aws/ebs

alias/aws/s3

alias/aws/rds
```

You can view AWS managed keys and audit their use, but you cannot modify their key policies, manually control their lifecycle, or schedule them for deletion. AWS KMS automatically rotates AWS managed keys approximately every 365 days. ([AWS Documentation][3])

Mental model:

```text
AWS SERVICE
creates/manages key

YOU
use encryption feature
```

---

# 9. Customer Managed Keys

These are the KMS keys **you create and manage**.

You control:

```text
key policy
IAM delegation
grants
rotation
enable/disable
aliases
tags
deletion
```

and can audit cryptographic use through CloudTrail. Customer managed keys incur key-storage and usage charges according to KMS pricing. ([AWS Documentation][3])

Use customer managed keys when you require:

```text
custom authorization

cross-account use

custom rotation controls

audit separation

specific compliance controls

resource-specific keys

organization-specific lifecycle
```

---

# 10. Never-Forget Ownership Comparison

| Capability                            | AWS owned | AWS managed |    Customer managed |
| ------------------------------------- | --------: | ----------: | ------------------: |
| Key visible in your account           |        No |         Yes |                 Yes |
| Customer controls policy              |        No |          No |             **Yes** |
| Customer controls lifecycle           |        No |          No |             **Yes** |
| Customer controls aliases             |        No |          No |             **Yes** |
| Customer-controlled rotation          |        No |          No |             **Yes** |
| Best for custom security architecture |   Limited |    Moderate | **Highest control** |

The current KMS ownership distinctions are documented by AWS. ([AWS Documentation][3])

---

# 11. Symmetric Encryption Keys

The most common KMS key for AWS-service encryption is:

# Symmetric encryption KMS key

Conceptually the **same secret key material** participates in encryption and decryption.

```text
        symmetric key
          /      \
         /        \
   Encrypt       Decrypt
```

AWS services integrated with KMS use symmetric encryption KMS keys for encrypting service-managed data; asymmetric KMS keys are not used for that AWS-service encryption path. ([AWS Documentation][5])

For:

```text
S3
EBS
RDS
Secrets Manager
```

your first KMS mental model should generally be:

```text
SYMMETRIC ENCRYPTION KEY
```

---

# 12. Asymmetric KMS Keys

An asymmetric key has:

```text
PUBLIC KEY
+
PRIVATE KEY
```

Conceptually:

```text
Public key
can be distributed

Private key
stays protected by KMS
```

The private key never leaves AWS KMS unencrypted. The public key can be downloaded and used outside KMS where appropriate. ([AWS Documentation][5])

Use cases include:

```text
encryption/decryption

digital signing/verification

key agreement
```

depending on the key spec and `KeyUsage`. ([AWS Documentation][6])

---

# 13. HMAC KMS Keys

AWS KMS also supports:

# HMAC keys

for:

```text
GenerateMac
VerifyMac
```

HMAC provides integrity and authenticity checks using shared secret key material. HMAC KMS keys are symmetric keys but are not normal symmetric encryption keys. ([AWS Documentation][7])

Mental distinction:

```text
Encryption
=
hide content

HMAC
=
verify authenticity/integrity
```

---

# 14. Key Usage Matters

A KMS key has an intended usage.

Examples include:

```text
ENCRYPT_DECRYPT

SIGN_VERIFY

GENERATE_VERIFY_MAC

KEY_AGREEMENT
```

depending on the key type/spec. AWS KMS uses the key spec and key usage to determine which cryptographic operations and algorithms are valid for the key. ([AWS Documentation][6])

You cannot simply use every KMS key for every cryptographic operation.

---

# 15. Why KMS Does Not Normally Encrypt Your 50-GB File Directly

Consider:

```text
50 GB backup file
```

A naive design would be:

```text
50 GB file
    │
    ▼
kms:Encrypt
```

That is not how KMS is intended to protect large application data.

The KMS `Encrypt` API accepts plaintext of up to **4,096 bytes**. ([AWS Documentation][8])

For large data we use:

# Envelope Encryption

---

# 16. Envelope Encryption

This is one of the most important security concepts in AWS.

Instead of:

```text
KMS Key
   │
   ▼
Encrypt 10 GB object directly
```

we do:

```text
                       KMS KEY
                          │
                          ▼
                   protects DATA KEY
                          │
                          ▼
                     DATA KEY
                          │
                          ▼
                  encrypts actual data
```

AWS defines envelope encryption as encrypting data with a data key and then encrypting that data key under another key. ([AWS Documentation][4])

---

# 17. Data Key

A:

# Data Key

is a cryptographic key used to encrypt the actual application data.

For example:

```text
10 GB file
   │
   ▼
AES-256 Data Key
   │
   ▼
encrypted file
```

Then:

```text
Data Key
   │
   ▼
KMS Key
   │
   ▼
Encrypted Data Key
```

You can safely store:

```text
encrypted file
+
encrypted data key
```

together because the data key itself is encrypted. ([AWS Documentation][4])

---

# 18. The Most Important KMS Diagram

```text
                   AWS KMS
                      │
                      │ KMS key
                      ▼
             ┌─────────────────┐
             │ Encrypt Data Key│
             └────────┬────────┘
                      │
                      ▼
              Encrypted Data Key
                      │
                      │ stored beside
                      ▼
          ┌───────────────────────┐
          │   Encrypted Payload   │
          └───────────────────────┘
                      ▲
                      │
                Plaintext Data Key
                      ▲
                      │
                encrypt payload
```

The KMS key protects the data key.

The data key protects the bulk data.

---

# 19. `GenerateDataKey`

AWS KMS provides:

```text
kms:GenerateDataKey
```

You specify a **symmetric encryption KMS key**.

KMS generates a data key and returns:

```text
Plaintext data key
+
Encrypted data key
```

The `GenerateDataKey` API is specifically designed for envelope-encryption workflows and cannot use an asymmetric KMS key to encrypt the generated data key. ([AWS Documentation][9])

Conceptually:

```text
Application
    │
    ▼
GenerateDataKey
    │
    ▼
KMS
    │
    ├── plaintext data key
    │
    └── encrypted data key
```

---

# 20. Why Return Both Versions?

The application temporarily needs:

```text
PLAINTEXT DATA KEY
```

to encrypt the data.

But it needs to persist:

```text
ENCRYPTED DATA KEY
```

for later decryption.

Workflow:

```text
1. Generate data key

2. Receive plaintext + encrypted copy

3. Encrypt application data with plaintext key

4. Remove plaintext key from memory as soon as practical

5. Store:
   encrypted application data
   +
   encrypted data key
```

This minimizes exposure of plaintext cryptographic key material.

---

# 21. Decryption Workflow

Later:

```text
Encrypted Data
+
Encrypted Data Key
       │
       ▼
send encrypted data key
to KMS
       │
       ▼
kms:Decrypt
       │
       ▼
Plaintext Data Key
       │
       ▼
decrypt data locally
```

KMS does not need to receive your entire 10 GB application object.

Only the protected key material needs the KMS decrypt operation.

---

# 22. Why Envelope Encryption Scales

Imagine one million files.

You do **not** need:

```text
1 million KMS keys
```

You can have:

```text
one KMS key
      │
      ├── protects DataKey-1
      ├── protects DataKey-2
      ├── protects DataKey-3
      └── ...
```

The encrypted data keys can live alongside their corresponding encrypted data. This is one of the benefits AWS explicitly lists for envelope encryption. ([AWS Documentation][4])

---

# 23. KMS Key as a Key-Encryption Key

In envelope-encryption terminology:

```text
DATA KEY
=
Data Encryption Key
```

and:

```text
KMS KEY
=
Key Encryption Key / root key role
```

Think:

```text
KMS key
does NOT usually protect
every byte of application data directly.

It protects the keys
that protect the data.
```

That mental model explains much of AWS encryption.

---

# 24. How S3 SSE-KMS Fits

Conceptually:

```text
S3 object
   │
   ▼
data key
   │
   ▼
encrypted object

data key
   │
   ▼
KMS
   │
   ▼
encrypted data key
```

S3 manages this workflow for you when using SSE-KMS.

Your application sees:

```text
PutObject

GetObject
```

while AWS services coordinate the KMS operations internally according to their service integration.

---

# 25. EBS + KMS

Conceptually:

```text
EC2
 │
 ▼
EBS Volume
 │
 ▼
Data Key
 │
 ▼
KMS Key
```

You don't write application code to call:

```text
kms:Encrypt
```

for every EBS block.

EBS integrates with KMS and handles the encryption workflow.

This is an important distinction:

```text
APPLICATION-DIRECT KMS
vs
AWS SERVICE-INTEGRATED KMS
```

---

# 26. RDS/Aurora + KMS

Similarly:

```text
RDS / Aurora
     │
     ▼
storage encryption
     │
     ▼
KMS
```

KMS participates in protecting the cryptographic keys used by the database storage architecture.

IAM permissions and KMS-key authorization determine who/services may use the key.

---

# 27. DynamoDB + KMS

DynamoDB encryption at rest can use AWS-owned, AWS-managed, or customer-managed key options depending on the selected encryption configuration. Customer-managed KMS keys give you stronger customer control over authorization and lifecycle. The exact encryption-key options are service-specific, which is why AWS recommends consulting each integrating service's encryption-at-rest documentation. ([AWS Documentation][3])

---

# 28. KMS API Operations to Remember

The fundamental APIs include:

```text
Encrypt

Decrypt

GenerateDataKey

ReEncrypt

DescribeKey
```

plus management APIs such as:

```text
CreateKey

EnableKeyRotation

DisableKey

CreateGrant

ScheduleKeyDeletion
```

The exact authorization actions are documented in the KMS permissions reference. ([AWS Documentation][10])

---

# 29. `Encrypt`

For small payloads:

```text
Plaintext
   │
   ▼
kms:Encrypt
   │
   ▼
CiphertextBlob
```

Again, direct KMS encryption accepts plaintext up to 4,096 bytes. ([AWS Documentation][8])

This is suitable for:

```text
small secrets
small cryptographic values
small data items
```

but envelope encryption is the normal pattern for substantial application data.

---

# 30. `Decrypt`

```text
CiphertextBlob
     │
     ▼
kms:Decrypt
     │
     ▼
Plaintext
```

For symmetric KMS ciphertext, AWS KMS embeds metadata that lets it identify the relevant KMS key; asymmetric decryption requires explicitly identifying the KMS key and algorithm. ([AWS Documentation][11])

---

# 31. `ReEncrypt`

Suppose:

```text
Ciphertext
protected by Key-A
```

needs to move to:

```text
Key-B
```

Instead of exposing plaintext to your application:

```text
Key-A ciphertext
      │
      ▼
KMS ReEncrypt
      │
      ▼
Key-B ciphertext
```

`ReEncrypt` can decrypt under the source KMS key and encrypt under the destination KMS key within KMS; authorization can distinguish `kms:ReEncryptFrom` and `kms:ReEncryptTo`. ([AWS Documentation][12])

---

# 32. Encryption Context

This is an advanced feature you should know early.

An encryption context is:

```text
non-secret key/value metadata
```

for example:

```text
Application=TodoAPI

Environment=Production

Tenant=Customer123
```

AWS KMS uses it as **additional authenticated data** for symmetric encryption cryptographic operations. The same encryption context must be supplied when decrypting data that was encrypted with that context. ([AWS Documentation][13])

---

# 33. Why Encryption Context Is Useful

Suppose ciphertext belongs to:

```text
Tenant=123
```

We encrypt using:

```text
Tenant=123
```

as encryption context.

Attempt:

```text
Decrypt
Tenant=999
```

fails.

So encryption context gives cryptographic binding between:

```text
ciphertext
+
application context
```

It also improves authorization and CloudTrail auditability because encryption context can appear in KMS request records. ([AWS Documentation][13])

---

# 34. Encryption Context Is NOT Secret

Do not put:

```text
password=SuperSecret123
```

in the encryption context.

AWS defines encryption-context values as **non-secret** information. ([AWS Documentation][13])

Good:

```text
SecretARN=...
Environment=Prod
Application=Payments
```

Bad:

```text
DatabasePassword=actual-password
```

---

# 35. KMS Key Policy

Now we reach the IAM/KMS intersection.

Every customer-managed KMS key is governed by:

# Key Policy

Think:

```text
KMS Key
   │
   ▼
Key Policy
   │
   ├── who administers key?
   │
   ├── who uses key?
   │
   └── can IAM policies delegate access?
```

KMS key policies are fundamental to KMS authorization; an IAM `Allow kms:Decrypt` alone is not necessarily sufficient unless the key policy permits that authorization path. ([AWS Documentation][12])

---

# 36. Key Policy vs IAM Policy

### IAM identity policy

Answers:

```text
What may this role request?
```

### KMS key policy

Answers:

```text
Who may administer/use
THIS KMS KEY?
```

So:

```text
IAM Role
Allow kms:Decrypt
```

does not automatically mean:

```text
Decrypt succeeds
```

if the key-policy side does not allow the relevant access model.

This was the reason KMS appeared repeatedly in our IAM troubleshooting lesson.

---

# 37. Key Administrators vs Key Users

This separation is excellent security design.

## Key administrator

May be allowed to:

```text
update policy
enable/disable
configure rotation
tag
create aliases
schedule deletion
```

## Key user

May be allowed to:

```text
Encrypt
Decrypt
GenerateDataKey
ReEncrypt
DescribeKey
```

You should not automatically assume:

```text
Can administer key
=
can decrypt protected data
```

AWS's default policy model explicitly distinguishes key administrators from key users. ([AWS Documentation][12])

---

# 38. Separation of Duties

Example:

```text
Security Team
     │
     ▼
Manage KMS Key

Application Role
     │
     ▼
Use KMS Key

Platform Team
     │
     ▼
Deploy infrastructure
```

You don't necessarily want:

```text
Application
```

to be able to:

```text
ScheduleKeyDeletion
PutKeyPolicy
DisableKey
```

And you don't necessarily want:

```text
KMS administrator
```

to automatically decrypt production customer data.

That's separation of duties.

---

# 39. KMS Grants

KMS has another authorization mechanism:

# Grants

A grant delegates specific use of a KMS key to a principal.

Example:

```text
KMS Key
   │
   ▼
Grant
   │
   ▼
Role X
may:
Decrypt
GenerateDataKey
```

AWS services frequently rely on grants as part of service-integrated KMS workflows. Grants can also include encryption-context constraints. ([AWS Documentation][14])

---

# 40. Why Grants Exist

Imagine an AWS service needs controlled permission to use your key on behalf of a resource.

Rather than repeatedly rewriting:

```text
Key Policy
```

for every temporary operational relationship, KMS grants provide delegatable permissions.

Think:

```text
KEY POLICY
=
foundational authorization
```

```text
GRANT
=
delegated operational authorization
```

---

# 41. Grant Eventual Consistency

KMS is distributed.

When you create/revoke/retire a grant, the change might not become effective everywhere immediately. AWS documents a short propagation delay that can in some cases take several minutes. Grant tokens can be used where newly created grants need to be recognized immediately by a subsequent cryptographic request. ([AWS Documentation][15])

This explains errors like:

```text
Create grant
     │
immediately call service
     │
AccessDenied
     │
retry shortly later
     │
works
```

Not every such case is policy syntax.

---

# 42. KMS Is Regional

Normal KMS keys are Regional resources.

Example:

```text
Key ARN:

arn:aws:kms:ap-south-1:
111122223333:
key/abcd...
```

The Region is part of the ARN.

Therefore:

```text
ap-south-1 key
```

and:

```text
us-east-1 key
```

are normally separate cryptographic resources.

But KMS also supports:

# Multi-Region Keys

---

# 43. Multi-Region KMS Keys

A multi-Region key set has:

```text
one PRIMARY
+
zero or more REPLICAS
```

in different Regions within the same AWS partition.

Related multi-Region keys share:

```text
key ID
key material
key spec
key usage
```

and ciphertext produced by one related key can be decrypted by another related key in another Region. ([AWS Documentation][16])

Architecture:

```text
          Multi-Region Key Set

          PRIMARY
        ap-south-1
             │
       shared key material
             │
       ┌─────┴─────────┐
       ▼               ▼
   REPLICA          REPLICA
 Singapore          Frankfurt
```

---

# 44. Multi-Region ≠ One Global KMS Endpoint

This is very important.

A replica is a:

```text
real Regional KMS key
```

not a network pointer back to the primary.

Each replica has its own:

```text
key policy
grants
aliases
tags
enabled/disabled state
```

and can be used independently for cryptographic operations. ([AWS Documentation][16])

So:

```text
Multi-Region key
≠
one global key API endpoint
```

It is a set of interoperable Regional keys.

---

# 45. Primary vs Replica

Only the:

```text
PRIMARY
```

can be replicated to create another replica.

Only the primary controls shared operations such as automatic key rotation configuration.

But cryptographically:

```text
PRIMARY
and
REPLICA
```

are equivalent for supported operations because they share the same cryptographic material. ([AWS Documentation][16])

---

# 46. Multi-Region Key IDs

Multi-Region key IDs have a recognizable prefix:

```text
mrk-
```

for example:

```text
mrk-1234abcd...
```

AWS documents this as a programmatically recognizable characteristic of multi-Region KMS keys. ([AWS Documentation][17])

---

# 47. Multi-Region Use Case

Imagine:

```text
Application
Mumbai
```

encrypts data.

Later DR activates:

```text
Application
Singapore
```

If using related multi-Region KMS keys:

```text
Mumbai key
       │
       ▼
ciphertext
       │
       ▼
Singapore replica
       │
       ▼
decrypt
```

This can simplify applications that need portable encrypted data across Regions. ([AWS Documentation][16])

---

# 48. Do NOT Use Multi-Region Keys Everywhere

AWS explicitly recommends creating multi-Region keys only when your application needs their cross-Region cryptographic properties. Single-Region keys maintain a stronger Regional isolation boundary. ([AWS Documentation][16])

Ask:

```text
Do I truly need
the SAME key material
across Regions?
```

If not:

```text
use independent Regional keys
```

and let your DR architecture re-encrypt or manage service-specific replication as appropriate.

---

# 49. Key Rotation

Cryptographic best practice often includes periodically replacing key material.

With KMS key rotation:

```text
KMS Key identity
remains

but

cryptographic key material
changes
```

The key ARN/key ID does not need to change simply because material rotates.

AWS KMS automatically chooses the correct older key material when decrypting ciphertext encrypted before rotation. ([AWS Documentation][18])

---

# 50. Rotation Does Not Re-Encrypt All Your Data

Very important.

Suppose:

```text
2026 ciphertext
encrypted under
key material version 1
```

Then key rotates:

```text
key material version 2
```

AWS does **not** automatically scan all:

```text
S3 objects
EBS volumes
databases
```

and rewrite every byte.

Instead:

```text
New encryption
→ current key material

Old ciphertext decryption
→ historical key material used automatically
```

AWS KMS retains the necessary historical key material and chooses the appropriate version during decrypt operations. ([AWS Documentation][18])

---

# 51. Customer-Managed Automatic Rotation

For supported customer-managed symmetric KMS keys, current AWS KMS automatic rotation can be configured between:

```text
90 days
and
2560 days
```

The default rotation period when automatic rotation is enabled without a custom period is:

```text
365 days
```

([AWS Documentation][19])

This is a newer capability worth remembering because older AWS material often described customer-managed automatic rotation only as annual.

---

# 52. AWS Managed Key Rotation

AWS managed keys are automatically rotated:

```text
approximately every 365 days
```

and you cannot change that schedule. ([AWS Documentation][18])

AWS owned keys use the rotation strategy chosen by the owning AWS service. ([AWS Documentation][18])

---

# 53. Rotation Is Transparent

AWS documents key-material rotation as transparent to AWS services using customer-managed symmetric keys for server-side encryption, and rotation itself does not interrupt cryptographic operations. ([AWS Documentation][18])

So you do **not** usually have to change:

```text
application key ARN
```

after automatic rotation.

---

# 54. Multi-Region Rotation

For an AWS-KMS-generated multi-Region symmetric encryption key:

```text
enable rotation
on PRIMARY
```

KMS synchronizes the rotation configuration and new material across all related replica keys before the new material is used for encryption. ([AWS Documentation][18])

Conceptually:

```text
Primary
  │
  │ rotate
  ▼
New material
  │
  ├────► Replica A
  │
  └────► Replica B
```

---

# 55. Disabling a KMS Key

Customer-managed keys can be:

```text
Enabled
Disabled
```

If a key becomes disabled, KMS cryptographic operations using that key fail once the change takes effect. Data already encrypted with data keys may continue functioning temporarily in places where plaintext data keys are already cached, but future uses requiring KMS—for example decrypting an encrypted data key—fail. ([AWS Documentation][20])

This can create delayed-looking outages.

---

# 56. Why “I Disabled the Key and the App Still Works” Can Happen

Example:

```text
Application/service
already cached decrypted data key
```

Then:

```text
disable KMS key
```

Some existing operations may still work until the workload/service needs KMS again.

Eventually:

```text
Decrypt encrypted data key
        │
        X
        ▼
KMS key disabled
```

and the workload fails.

AWS explicitly documents this delayed effect with services using data keys. ([AWS Documentation][21])

This is another reason not to test KMS failure casually in production.

---

# 57. Key Deletion Is Extremely Dangerous

Deleting a KMS key can render protected data permanently unrecoverable.

AWS therefore does not instantly delete a customer-managed KMS key.

You schedule deletion with a waiting period from:

```text
7–30 days
```

with 30 days being the default if you do not specify another value. During pending deletion, the KMS key is unusable for cryptographic operations. ([AWS Documentation][22])

---

# 58. Key Deletion Mental Model

```text
Enabled
   │
   ▼
Schedule deletion
   │
   ▼
PendingDeletion
   │
   │ 7–30 days
   ▼
Permanent deletion
```

During the waiting period you can:

```text
CancelKeyDeletion
```

After cancellation, the key returns to:

```text
Disabled
```

and must be enabled again before use. ([AWS Documentation][23])

---

# 59. NEVER Delete a Key Because “No One Recognizes Its Name”

Before deleting:

```text
alias/old-project-key
```

check:

```text
CloudTrail usage

service configuration

snapshots

backups

S3 objects

EBS volumes

RDS snapshots

Secrets Manager

cross-account dependencies

DR copies
```

because the key may still protect historical data.

The absence of current application traffic does **not** prove the key is unnecessary.

---

# 60. Aliases

Instead of applications referring to:

```text
arn:aws:kms:ap-south-1:123:
key/12345678-abcd...
```

you can create:

```text
alias/prod-todo-data
```

An alias is a friendly name that refers to a KMS key.

Customer managed keys support customer-created aliases. ([AWS Documentation][3])

Conceptually:

```text
alias/prod-todo-data
          │
          ▼
KMS Key ID
```

---

# 61. Why Aliases Help

Humans understand:

```text
alias/prod-rds
```

better than:

```text
4d22191d-bcc7-...
```

Aliases can also support controlled key replacement patterns because an alias can be updated to reference a different key.

But don't confuse:

```text
alias change
```

with:

```text
key rotation.
```

Automatic rotation changes the key material **inside the same KMS key**.

Updating an alias can point to an **entirely different KMS key**.

---

# 62. KMS Authorization Using Aliases/Tags

KMS supports authorization conditions involving aliases and tags.

This enables designs such as:

```text
Role can use keys
tagged:

Application=Todo
Environment=Prod
```

or specific alias patterns.

However, authorization based on aliases/tags means:

```text
changing aliases/tags
becomes security-sensitive.
```

AWS also notes that alias/tag changes can take several minutes to affect authorization due to eventual consistency behavior. ([AWS Documentation][24])

---

# 63. KMS and CloudTrail

Cryptographic use of customer-managed and AWS-managed keys can be audited with CloudTrail. AWS also records key-rotation events for managed/customer-managed rotations. ([AWS Documentation][3])

Important events can include:

```text
Decrypt

Encrypt

GenerateDataKey

CreateGrant

PutKeyPolicy

DisableKey

ScheduleKeyDeletion

RotateKey
```

This makes KMS a highly auditable security control.

---

# 64. Production Security Question

Suppose attacker obtains:

```text
s3:GetObject
```

for:

```text
s3://prod-sensitive
```

but the objects are SSE-KMS encrypted.

If the attacker cannot successfully obtain:

```text
kms:Decrypt
```

for the protecting KMS key through the relevant authorization model, encryption provides an additional security boundary.

This is why KMS and IAM should be designed together.

---

# 65. But Encryption Is Not a Replacement for IAM

Do not think:

```text
Everything encrypted
=
permissions don't matter.
```

You still need:

```text
IAM

resource policies

network controls

KMS policies

logging
```

Encryption is **defense in depth**, not permission management.

---

# 66. KMS Troubleshooting — First Mental Model

Error:

```text
AccessDeniedException:
not authorized to perform kms:Decrypt
```

Investigate:

```text
WHO?
      │
      ▼
aws sts get-caller-identity

IAM allow?
      │
      ▼
KMS key policy?

Grant?
      │
      ▼
SCP / RCP?

Boundary/session policy?

Encryption context?

Correct key/Region?

VPC endpoint policy?
```

Do not solve every KMS denial by attaching:

```text
kms:*
Resource: *
```

---

# 67. Failure — Wrong Region

Suppose key exists:

```text
ap-south-1
```

but application requests:

```text
us-east-1
```

A normal single-Region KMS key is not a global object.

Check:

```bash
aws kms describe-key \
  --key-id alias/prod-app \
  --region ap-south-1
```

When using multi-Region keys, you still call the KMS endpoint in the local Region against that Region's related key. Multi-Region keys remain Regional resources. ([AWS Documentation][16])

---

# 68. Failure — IAM Allows, Key Policy Doesn't

Role:

```json
{
  "Effect": "Allow",
  "Action": "kms:Decrypt",
  "Resource": "<key-arn>"
}
```

Still denied.

Next:

```text
Inspect key policy.
```

Because:

```text
IAM Allow
≠
automatic KMS access
```

The key must authorize that role directly or permit the account to delegate through IAM as appropriate. ([AWS Documentation][12])

---

# 69. Failure — Wrong Encryption Context

Encrypted using:

```text
Environment=Production
```

Decrypt request uses:

```text
Environment=Development
```

Result:

```text
Decrypt fails
```

because encryption context participates in authenticated encryption and must match. ([AWS Documentation][13])

---

# 70. Failure — Key Disabled

Error may look like:

```text
DisabledException

KMSInvalidStateException
```

depending on the operation/context.

Check:

```bash
aws kms describe-key \
  --key-id alias/prod-app \
  --region ap-south-1
```

Look at:

```text
KeyState
```

If:

```text
Disabled

PendingDeletion
```

cryptographic use will not proceed normally. ([AWS Documentation][20])

---

# 71. Failure — Resource Works Until Restart

This is a particularly interesting production symptom.

```text
KMS key disabled
```

but app continues for a while.

Then:

```text
instance restart
service restart
cache expiry
```

and suddenly:

```text
decrypt fails.
```

Think:

```text
cached plaintext data key
```

was being used before restart, and the workload later needed KMS again. AWS documents this behavior for services using data keys. ([AWS Documentation][21])

---

# 72. Failure — Newly Created Grant Doesn't Work Immediately

Possible:

```text
eventual consistency
```

KMS grant creation is eventually consistent; use normal retry/backoff, or where required use a grant token with the subsequent request so it can immediately recognize the new grant. ([AWS Documentation][15])

---

# 73. Hands-On Lab — Create a KMS Key

Use our preferred Region:

```bash
export AWS_REGION="ap-south-1"
```

First confirm identity:

```bash
aws sts get-caller-identity
```

Create a customer-managed symmetric encryption key:

```bash
KEY_ID=$(
  aws kms create-key \
    --description "Lesson31 KMS lab key" \
    --key-usage ENCRYPT_DECRYPT \
    --key-spec SYMMETRIC_DEFAULT \
    --region "$AWS_REGION" \
    --query 'KeyMetadata.KeyId' \
    --output text
)

echo "$KEY_ID"
```

`SYMMETRIC_DEFAULT` identifies the standard symmetric encryption KMS key type. ([AWS Documentation][25])

---

# 74. Create an Alias

```bash
aws kms create-alias \
  --alias-name alias/lesson31-kms-lab \
  --target-key-id "$KEY_ID" \
  --region "$AWS_REGION"
```

Validate:

```bash
aws kms describe-key \
  --key-id alias/lesson31-kms-lab \
  --region "$AWS_REGION"
```

Look for:

```text
KeyId
Arn
KeyState
KeyUsage
KeySpec
KeyManager
MultiRegion
```

---

# 75. Enable Automatic Rotation

For this lab:

```bash
aws kms enable-key-rotation \
  --key-id "$KEY_ID" \
  --rotation-period-in-days 365 \
  --region "$AWS_REGION"
```

Validate:

```bash
aws kms get-key-rotation-status \
  --key-id "$KEY_ID" \
  --region "$AWS_REGION"
```

Current AWS KMS supports rotation periods from 90 to 2560 days for applicable customer-managed keys, with 365 days as the default when rotation is enabled without another value. ([AWS Documentation][19])

---

# 76. Direct Encryption Lab

Create a tiny test payload:

```bash
printf 'Lesson 31 secret demo' > plaintext.txt
```

Encrypt:

```bash
aws kms encrypt \
  --key-id alias/lesson31-kms-lab \
  --plaintext fileb://plaintext.txt \
  --region "$AWS_REGION" \
  --query CiphertextBlob \
  --output text \
  | base64 --decode > ciphertext.bin
```

Why tiny?

Because direct `kms:Encrypt` accepts up to 4,096 bytes. ([AWS Documentation][8])

---

# 77. Decrypt It

```bash
aws kms decrypt \
  --ciphertext-blob fileb://ciphertext.bin \
  --region "$AWS_REGION" \
  --query Plaintext \
  --output text \
  | base64 --decode
```

Expected:

```text
Lesson 31 secret demo
```

Flow:

```text
plaintext.txt
     │
     ▼
kms:Encrypt
     │
     ▼
ciphertext.bin
     │
     ▼
kms:Decrypt
     │
     ▼
plaintext
```

---

# 78. Encryption Context Lab

Encrypt:

```bash
aws kms encrypt \
  --key-id alias/lesson31-kms-lab \
  --plaintext fileb://plaintext.txt \
  --encryption-context \
      Application=TodoApp,Environment=Dev \
  --region "$AWS_REGION" \
  --query CiphertextBlob \
  --output text \
  | base64 --decode > context-ciphertext.bin
```

Decrypt correctly:

```bash
aws kms decrypt \
  --ciphertext-blob fileb://context-ciphertext.bin \
  --encryption-context \
      Application=TodoApp,Environment=Dev \
  --region "$AWS_REGION" \
  --query Plaintext \
  --output text \
  | base64 --decode
```

Because the context is authenticated, decryption must provide matching values. ([AWS Documentation][13])

---

# 79. Now Intentionally Use the Wrong Context

```bash
aws kms decrypt \
  --ciphertext-blob fileb://context-ciphertext.bin \
  --encryption-context \
      Application=TodoApp,Environment=Prod \
  --region "$AWS_REGION"
```

Expected:

```text
failure
```

Now you have physically seen that:

```text
KMS key
+
ciphertext
```

are still not enough when the encryption context is part of the cryptographic operation.

---

# 80. Generate a Data Key

Now inspect envelope encryption directly:

```bash
aws kms generate-data-key \
  --key-id alias/lesson31-kms-lab \
  --key-spec AES_256 \
  --region "$AWS_REGION"
```

The result includes:

```text
Plaintext

CiphertextBlob

KeyId
```

`GenerateDataKey` is designed to return both plaintext and encrypted forms of a generated data key for envelope-encryption workflows. ([AWS Documentation][9])

### Production warning

Do not:

```text
log plaintext data keys
commit them
save them to disk
put them in CI logs
```

The plaintext version exists only so your application can perform local encryption.

---

# 81. Envelope Encryption — Complete Flow

```text
APPLICATION
    │
    ▼
GenerateDataKey
    │
    ▼
AWS KMS
    │
    ├──────────────┐
    ▼              ▼
Plaintext       Encrypted
Data Key        Data Key
    │              │
    │              │ store
    ▼              │
Encrypt            │
Application Data   │
    │              │
    ▼              ▼
Encrypted Data + Encrypted Data Key
                │
                ▼
             STORAGE
```

For decryption:

```text
Encrypted Data Key
       │
       ▼
      KMS
       │
       ▼
Plaintext Data Key
       │
       ▼
Decrypt application data
```

That is the **single most important cryptographic diagram in AWS KMS**. ([AWS Documentation][4])

---

# 82. Terraform — Production Baseline

Current HashiCorp AWS provider supports KMS resources such as `aws_kms_key`; `enable_key_rotation` controls automatic rotation and `rotation_period_in_days` can configure the supported rotation interval when rotation is enabled. ([Terraform Registry][26])

Example:

```hcl
resource "aws_kms_key" "application" {
  description = "Production Todo application encryption key"

  enable_key_rotation     = true
  rotation_period_in_days = 365

  deletion_window_in_days = 30

  tags = {
    Environment = "production"
    Application = "todo"
    ManagedBy   = "terraform"
  }
}
```

Alias:

```hcl
resource "aws_kms_alias" "application" {
  name = "alias/prod-todo"

  target_key_id =
    aws_kms_key.application.key_id
}
```

---

# 83. Do Not Put an Empty/Broken Key Policy in Terraform

KMS key policies can lock you out if designed incorrectly.

A production policy normally distinguishes:

```text
Key administrators

Key users

Service integrations
```

and preserves an administrative recovery/delegation path according to your organization's design.

Avoid:

```text
copy random KMS policy
terraform apply
hope
```

because KMS key-policy mistakes can make a valid IAM administrator unable to use/manage the key.

---

# 84. Terraform Key User Policy Example

Conceptually:

```hcl
data "aws_iam_policy_document" "app_kms" {
  statement {
    sid = "UseApplicationKey"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = [
      aws_kms_key.application.arn
    ]
  }
}
```

Attach only to the role that actually needs those operations.

A read-only application may require:

```text
Decrypt
```

but not necessarily:

```text
ScheduleKeyDeletion
PutKeyPolicy
DisableKey
```

---

# 85. Multi-Region Terraform Architecture

Suppose:

```text
Primary:
ap-south-1

DR:
ap-southeast-1
```

Primary:

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "singapore"
  region = "ap-southeast-1"
}

resource "aws_kms_key" "primary" {
  description  = "Production multi-Region application key"
  multi_region = true

  enable_key_rotation     = true
  rotation_period_in_days = 365
}
```

Replica conceptually uses the multi-Region primary ARN in the target Region. Related multi-Region keys share key ID/material but retain independent Regional policies, aliases, tags, and grants. ([AWS Documentation][16])

---

# 86. Production Architecture — Todo Application

Now connect everything:

```text
                         Internet
                            │
                            ▼
                         CloudFront
                            │
                            ▼
                           ALB
                            │
                            ▼
                       EC2 / ECS App
                            │
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
             S3         Secrets Manager   RDS
              │             │              │
              └─────────────┼──────────────┘
                            ▼
                           KMS
                            │
                       Customer Key
                            │
                  ┌─────────┼─────────┐
                  ▼         ▼         ▼
             Key Policy   Grants    CloudTrail
```

IAM answers:

```text
Can AppRole request Decrypt?
```

KMS answers:

```text
Does this key permit that use?
```

Service integration answers:

```text
Is the request valid for this
encrypted resource?
```

---

# 87. Production Pattern — Separate Keys

You could have:

```text
alias/prod-todo-secrets

alias/prod-todo-data

alias/prod-terraform-state

alias/security-logs
```

instead of:

```text
alias/everything-company-wide
```

Advantages include:

```text
smaller blast radius

clearer policies

independent lifecycle

better ownership

better auditability
```

But too many keys also increase operational complexity and cost.

The correct granularity is an architecture decision.

---

# 88. KMS Blast Radius

Suppose one key protects:

```text
S3 production
RDS production
Terraform state
Security logs
Secrets
Backups
```

and someone disables it.

Blast radius:

```text
EVERYTHING
```

Compare with:

```text
App data key
Security logs key
Terraform state key
Secrets key
```

A security architecture often chooses separate keys where:

```text
ownership
risk
lifecycle
policy
compliance
```

differ materially.

---

# 89. Key Administrator Should Not Be Application Runtime

Bad:

```text
EC2AppRole

kms:*
```

Better:

```text
AppRole
     │
     ├── kms:Decrypt
     ├── kms:GenerateDataKey
     └── kms:DescribeKey

SecurityKeyAdmin
     │
     ├── policy administration
     ├── rotation
     └── lifecycle management
```

Apply the same least-privilege principles we learned in IAM.

---

# 90. Certification Scenarios

| Requirement                                        | First thought                           |
| -------------------------------------------------- | --------------------------------------- |
| AWS service needs encryption with customer control | **Customer-managed KMS key**            |
| Large object must be encrypted                     | **Envelope encryption / data key**      |
| Small payload directly encrypted with KMS          | `kms:Encrypt`                           |
| Need plaintext + encrypted data key                | `GenerateDataKey`                       |
| Move ciphertext from Key-A to Key-B                | `ReEncrypt`                             |
| Bind ciphertext to application metadata            | **Encryption context**                  |
| IAM says decrypt but still denied                  | **Check key policy**                    |
| Need temporary service delegation                  | **KMS grant**                           |
| Same key material across Regions                   | **Multi-Region KMS key**                |
| Old ciphertext after rotation                      | **KMS automatically uses old material** |
| Protect encrypted data permanently                 | **Do not delete required KMS key**      |

These behaviors follow the current KMS API and key-management model. ([AWS Documentation][9])

---

# 91. SAA-C03 Scenario

> A company has 20-TB objects that need encryption using KMS.

Wrong answer:

```text
Send the entire 20 TB
to kms:Encrypt.
```

Correct mental model:

```text
KMS key
    │
    ▼
protect data key
    │
    ▼
data key encrypts
bulk data
```

That is:

# Envelope Encryption

Direct KMS `Encrypt` handles only small plaintext input, currently up to 4,096 bytes. ([AWS Documentation][8])

---

# 92. Scenario

> Security requires company-controlled key policies, lifecycle, rotation and deletion.

Choose:

```text
Customer managed KMS key
```

not merely an AWS managed/owned key. Customer-managed keys provide those lifecycle and policy controls. ([AWS Documentation][3])

---

# 93. Scenario

> App has `kms:Decrypt` in IAM but still receives AccessDenied.

First thought:

```text
KEY POLICY
```

Then:

```text
SCP
RCP
boundary
grant
encryption context
key state
Region
endpoint policy
```

Do not immediately add another IAM Allow.

---

# 94. Scenario

> Company wants encrypted data generated in Mumbai to be decrypted in Singapore without using unrelated key material.

Evaluate:

```text
AWS KMS Multi-Region Key
```

because related keys share key ID/material and are interoperable across their configured Regions. ([AWS Documentation][16])

---

# 95. Scenario

> Company rotates a customer-managed key. Must all existing S3 data immediately be decrypted and rewritten?

```text
NO
```

Rotation changes the key material associated with the KMS key. New encryption uses current material; KMS automatically selects historical material needed for old ciphertext. ([AWS Documentation][18])

---

# 96. Scenario

> Engineer schedules production KMS key deletion with a seven-day window by mistake.

If discovered before deletion:

```text
CancelKeyDeletion
```

Then:

```text
EnableKey
```

because cancellation leaves the key disabled. ([AWS Documentation][23])

If the key is permanently deleted after the waiting period:

```text
protected data may become
permanently unrecoverable.
```

([AWS Documentation][27])

---

# 97. Never-Forget KMS Diagram

```text
                       APPLICATION DATA
                              │
                              ▼
                         DATA KEY
                              │
                              ▼
                      ENCRYPTED DATA
                              │
                              +
                              │
                    ENCRYPTED DATA KEY
                              ▲
                              │
                         AWS KMS
                              │
                              ▼
                           KMS KEY
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
           Key Policy       Grants         Rotation
               │                              │
               ▼                              ▼
          Authorization                  New material
                                              │
                                              ▼
                                     Old material retained
                                     for old ciphertext
```

---

# 98. 25 Rules to Burn Into Memory

```text
1. KMS manages cryptographic keys.

2. IAM and KMS authorization are related
   but not identical.

3. Plaintext = readable original data.

4. Ciphertext = encrypted data.

5. KMS-generated key material does not leave
   AWS KMS unencrypted.

6. AWS-owned keys provide the least
   customer key management.

7. AWS-managed keys exist in your account
   but AWS manages them.

8. Customer-managed keys give you
   lifecycle and policy control.

9. Symmetric encryption keys are the normal
   KMS keys used by AWS service encryption.

10. Asymmetric keys have public/private parts.

11. HMAC keys generate/verify authentication codes.

12. Direct kms:Encrypt is for small data;
    current plaintext limit is 4 KiB.

13. Large-data encryption uses envelope encryption.

14. Data key encrypts the real data.

15. KMS key encrypts/protects the data key.

16. GenerateDataKey returns plaintext
    and encrypted forms of a data key.

17. Do not persist plaintext data keys unnecessarily.

18. Encryption context is non-secret authenticated metadata.

19. KMS key policy is fundamental to authorization.

20. A key administrator and a key user
    should be considered separate responsibilities.

21. KMS grants provide delegated key usage.

22. Rotation changes key material,
    not necessarily the key ID/application ARN.

23. Old ciphertext remains decryptable
    after supported KMS rotation.

24. Multi-Region keys share key material
    but remain Regional KMS resources.

25. Deleting a required KMS key can permanently
    destroy access to encrypted data.
```

The single most important KMS rule is:

```text
DO NOT THINK:

"KMS encrypts all my large files directly."
```

Think:

```text
KMS KEY
   │
   ▼
PROTECTS DATA KEY
   │
   ▼
DATA KEY
   │
   ▼
PROTECTS APPLICATION DATA
```

That is **envelope encryption**, and once you understand it, encryption in S3, EBS, RDS, Secrets Manager, and many other AWS services becomes much easier to understand. ([AWS Documentation][4])

---

# ✅ Lesson 31 Part 1 Complete

You now understand:

```text
✓ encryption fundamentals
✓ plaintext
✓ ciphertext
✓ at-rest vs in-transit protection

✓ AWS KMS architecture
✓ HSM-backed key protection
✓ AWS owned keys
✓ AWS managed keys
✓ customer managed keys

✓ symmetric encryption keys
✓ asymmetric keys
✓ HMAC keys
✓ key usage

✓ direct Encrypt
✓ Decrypt
✓ GenerateDataKey
✓ ReEncrypt

✓ envelope encryption
✓ data encryption keys
✓ encrypted data keys
✓ 4-KiB direct Encrypt limit

✓ encryption context
✓ authenticated context
✓ non-secret metadata

✓ key policies
✓ IAM + KMS interaction
✓ key admins vs key users
✓ grants
✓ grant eventual consistency

✓ KMS Regions
✓ multi-Region keys
✓ primary and replicas
✓ shared key material
✓ mrk- identifiers

✓ automatic rotation
✓ custom 90–2560-day rotation periods
✓ old-key-material decryption
✓ AWS-managed annual rotation

✓ enable/disable
✓ delayed service impact from cached data keys

✓ key deletion
✓ 7–30-day waiting period
✓ cancellation
✓ permanent data-loss risk

✓ aliases
✓ CloudTrail
✓ production KMS design
✓ Terraform
✓ CLI lab
✓ KMS troubleshooting
✓ SAA-C03 scenarios
```

# Next — Lesson 31 Part 2

# **AWS Secrets Manager & Systems Manager Parameter Store — Secret Storage, Rotation, Versioning and Application Integration**

Next we'll answer:

```text
WHERE SHOULD THIS GO?

Database password?
API key?
JWT signing secret?
OAuth secret?
TLS private value?
Feature flag?
Application configuration?
```

We'll build the decision tree:

```text
                   APPLICATION VALUE
                          │
             ┌────────────┴─────────────┐
             ▼                          ▼
          SECRET                     CONFIG
             │                          │
             ▼                          ▼
    Secrets Manager            Parameter Store
             │                          │
             ├── KMS                     ├── String
             ├── rotation                ├── StringList
             ├── versions                └── SecureString
             ├── staging labels
             └── cross-account patterns
```

Then we'll cover **automatic database credential rotation, Lambda rotation workflows, `AWSCURRENT` / `AWSPENDING` / `AWSPREVIOUS`, secret resource policies, cross-account access, KMS interaction, VPC endpoints/PrivateLink, caching secrets, ECS/Lambda/EC2 integration, Terraform secret-handling pitfalls, Parameter Store hierarchies, SecureString, standard vs advanced parameters, dynamic references, IAM path permissions, production troubleshooting, and how to stop putting passwords in `.env`, Jenkinsfiles, Terraform source, or Docker images**.

[1]: https://docs.aws.amazon.com/kms/latest/developerguide/overview.html?utm_source=chatgpt.com "AWS Key Management Service"
[2]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html?utm_source=chatgpt.com "Secret encryption and decryption in AWS Secrets Manager"
[3]: https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html "AWS KMS keys - AWS Key Management Service"
[4]: https://docs.aws.amazon.com/kms/latest/developerguide/kms-cryptography.html "AWS KMS cryptography essentials - AWS Key Management Service"
[5]: https://docs.aws.amazon.com/kms/latest/developerguide/symmetric-asymmetric.html "Asymmetric keys in AWS KMS - AWS Key Management Service"
[6]: https://docs.aws.amazon.com/kms/latest/developerguide/symm-asymm-choose-key-spec.html?utm_source=chatgpt.com "Key spec reference - AWS Key Management Service"
[7]: https://docs.aws.amazon.com/kms/latest/developerguide/hmac.html?utm_source=chatgpt.com "HMAC keys in AWS KMS - AWS Key Management Service"
[8]: https://docs.aws.amazon.com/kms/latest/APIReference/API_Encrypt.html?utm_source=chatgpt.com "Encrypt - AWS Key Management Service"
[9]: https://docs.aws.amazon.com/kms/latest/APIReference/API_GenerateDataKey.html?utm_source=chatgpt.com "GenerateDataKey - AWS Key Management Service"
[10]: https://docs.aws.amazon.com/kms/latest/developerguide/kms-api-permissions-reference.html?utm_source=chatgpt.com "AWS KMS permissions - AWS Key Management Service"
[11]: https://docs.aws.amazon.com/kms/latest/APIReference/API_Decrypt.html?utm_source=chatgpt.com "Decrypt - AWS Key Management Service"
[12]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html?utm_source=chatgpt.com "Default key policy - AWS Key Management Service"
[13]: https://docs.aws.amazon.com/kms/latest/developerguide/encrypt_context.html?utm_source=chatgpt.com "Encryption context - AWS Key Management Service"
[14]: https://docs.aws.amazon.com/kms/latest/developerguide/create-grant-overview.html "Creating grants - AWS Key Management Service"
[15]: https://docs.aws.amazon.com/kms/latest/developerguide/using-grant-token.html?utm_source=chatgpt.com "Using a grant token - AWS Key Management Service"
[16]: https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html "Multi-Region keys in AWS KMS - AWS Key Management Service"
[17]: https://docs.aws.amazon.com/kms/latest/developerguide/mrk-how-it-works.html?utm_source=chatgpt.com "How multi-Region keys work"
[18]: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html "Rotate AWS KMS keys - AWS Key Management Service"
[19]: https://docs.aws.amazon.com/kms/latest/developerguide/rotating-keys-enable.html?utm_source=chatgpt.com "Enable automatic key rotation - AWS Key Management Service"
[20]: https://docs.aws.amazon.com/kms/latest/developerguide/enabling-keys.html?utm_source=chatgpt.com "Enable and disable keys - AWS Key Management Service"
[21]: https://docs.aws.amazon.com/kms/latest/developerguide/unusable-kms-keys.html?utm_source=chatgpt.com "How unusable KMS keys affect data keys"
[22]: https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html?utm_source=chatgpt.com "AWS KMS condition keys - AWS Key Management Service"
[23]: https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys-cancelling-key-deletion.html?utm_source=chatgpt.com "Cancel key deletion - AWS Key Management Service"
[24]: https://docs.aws.amazon.com/kms/latest/developerguide/troubleshooting-tags-aliases.html?utm_source=chatgpt.com "Troubleshooting ABAC for AWS KMS"
[25]: https://docs.aws.amazon.com/kms/latest/developerguide/identify-key-types.html?utm_source=chatgpt.com "Identify different key types - AWS Key Management Service"
[26]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key?utm_source=chatgpt.com "aws_kms_key | Resources | hashicorp/aws - Terraform Registry"
[27]: https://docs.aws.amazon.com/kms/latest/developerguide/example_kms_ScheduleKeyDeletion_section.html?utm_source=chatgpt.com "Use ScheduleKeyDeletion with an AWS SDK or CLI"
