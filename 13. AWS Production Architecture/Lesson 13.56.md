# AWS Masterclass — Phase 3

# Lesson 55: AWS KMS, Secrets Manager, Parameter Store and ACM Production Security Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish encryption keys, credentials, configuration values and certificates.
* Understand symmetric, asymmetric and HMAC KMS keys.
* Design envelope encryption correctly.
* Generate and protect data-encryption keys.
* Use encryption context for authorization and auditing.
* Design KMS key policies, IAM policies and grants.
* Choose between AWS owned, AWS managed and customer managed keys.
* Configure automatic, on-demand and manual key rotation.
* Use multi-Region KMS keys appropriately.
* Understand imported key material, CloudHSM custom key stores and external key stores.
* Protect KMS keys from accidental deletion.
* Store and retrieve credentials from Secrets Manager.
* Rotate database passwords and API credentials.
* Understand `AWSCURRENT`, `AWSPENDING` and `AWSPREVIOUS`.
* Replicate secrets across AWS Regions.
* Share secrets safely across AWS accounts.
* Use Parameter Store hierarchies, versions and labels.
* Choose between standard and advanced parameters.
* Request and validate ACM certificates.
* Understand certificate Region requirements.
* Automate certificate renewal and expiry monitoring.
* Provision these resources with Terraform.
* Troubleshoot production cryptography and secret-access failures.

---

# 2. The four-service mental model

These services solve different problems:

```text
AWS KMS
    → Protects cryptographic keys

AWS Secrets Manager
    → Stores and rotates credentials and secrets

Systems Manager Parameter Store
    → Stores configuration and lightweight encrypted values

AWS Certificate Manager
    → Issues and manages TLS certificates
```

## Never-forget distinction

```text
Encryption key:
Used to cryptographically protect data

Secret:
Credential used to access a system

Parameter:
Application configuration value

Certificate:
Binds a public key to a domain or identity
```

Do not use one service merely because another service’s name sounds similar.

---

# 3. Example TodoApp security architecture

```text
                           AWS KMS
                              |
             ┌────────────────┼─────────────────┐
             |                |                 |
             v                v                 v
      Secrets Manager    Parameter Store    Encrypted AWS
             |                |              resources
             |                |                 |
             v                v                 v
      DB credentials     App configuration   S3/RDS/EBS/SQS
             |
             v
         Todo API
             |
             v
      TLS certificate
           in ACM
```

Example responsibilities:

```text
KMS:
Protect RDS storage, S3 objects, secrets and logs

Secrets Manager:
Store Aurora password and external API credentials

Parameter Store:
Store application environment names and feature settings

ACM:
Provide api.yourdatascientist.tech certificate
```

---

# Part 1 — Cryptography fundamentals

# 4. Encryption at rest versus in transit

## Encryption at rest

Protects stored data:

```text
S3 objects
EBS volumes
RDS databases
DynamoDB tables
CloudWatch Logs
Secrets Manager values
```

## Encryption in transit

Protects network communication:

```text
Browser → CloudFront
API Gateway → backend
Application → database
Service → AWS API
```

Encryption at rest does not automatically protect data while it travels over the network.

TLS does not automatically protect plaintext after it reaches the application.

Production systems need both.

---

# 5. Encryption, hashing and signing

## Encryption

```text
Plaintext
   |
   | Encryption key
   v
Ciphertext
```

It is reversible with the correct key.

Use for:

* Customer information.
* Database fields.
* Files.
* Credentials.
* Backups.

## Hashing

```text
Input
  |
  v
Fixed-length digest
```

Designed as a one-way operation.

Use for:

* Integrity checks.
* Password verification with a suitable password-hashing algorithm.
* Content identification.

## Digital signature

```text
Message
   |
   | Private signing key
   v
Signature

Message + signature
   |
   | Public key
   v
Verified or rejected
```

Use for:

* Software signing.
* Document authenticity.
* Token signing.
* Request authenticity.

Do not use normal encryption as a replacement for secure password hashing.

---

# Part 2 — AWS Key Management Service

# 6. What is AWS KMS?

AWS Key Management Service is a managed service for creating and controlling cryptographic keys used to encrypt, decrypt, sign and verify data. AWS KMS protects key material in FIPS 140-3 Security Level 3 validated hardware security modules, and KMS key material does not leave KMS unencrypted. ([AWS Documentation][1])

```text
Application or AWS service
          |
          | KMS API
          v
       AWS KMS
          |
          v
Protected key material
inside managed HSMs
```

Applications normally request cryptographic operations through the KMS API rather than downloading the KMS private or symmetric key material.

---

# 7. Types of KMS key ownership

AWS uses three broad key-management categories:

```text
AWS owned key
AWS managed key
Customer managed key
```

## AWS owned key

* Owned and managed by an AWS service.
* Often shared across several customer resources.
* Not visible or manageable in your account.

## AWS managed key

* Created in your account for an AWS service.
* Common aliases include `aws/s3`, `aws/rds` and `aws/ssm`.
* Visible in your account.
* Policy and rotation are controlled by AWS.
* Automatically rotated approximately annually.

## Customer managed key

* Created and controlled by you.
* Custom key policy.
* Custom aliases.
* Can be enabled, disabled and scheduled for deletion.
* Supports CloudTrail auditing.
* Supports configurable rotation where eligible.

AWS documents customer managed keys as the option providing direct control over policy, grants, aliases, rotation and deletion. ([AWS Documentation][2])

---

# 8. When to use a customer managed key

Use a customer managed key when you need:

* Cross-account access.
* Custom key policies.
* Explicit separation between applications.
* Rotation control.
* Key-disable capability.
* Detailed key-specific auditing.
* Alias-based governance.
* Encryption-context conditions.
* Regulatory separation.
* Multi-Region keys.
* Imported or externally controlled key material.

Use an AWS managed key when:

* Default service encryption is sufficient.
* You do not need cross-account use.
* You do not need key-policy customization.
* Operational simplicity is more important than direct control.

---

# 9. One KMS key per resource?

Avoid creating one KMS key for every individual object.

Potentially excessive:

```text
One key per S3 object
One key per application user
One key per database row
```

More practical boundaries:

```text
One key per environment and workload
One key per security boundary
One key per regulated data domain
One key per tenant only when strict isolation requires it
```

Example:

```text
alias/todoapp-production-data
alias/todoapp-production-secrets
alias/todoapp-production-logs
```

The correct boundary depends on:

* Required isolation.
* Key policies.
* Cost.
* Quotas.
* Incident blast radius.
* Compliance requirements.

---

# 10. KMS key identifiers

A KMS key can be referenced by:

```text
Key ID
Key ARN
Alias name
Alias ARN
```

Example key ARN:

```text
arn:aws:kms:ap-south-1:123456789012:key/1234abcd-...
```

Example alias:

```text
alias/todoapp-production-data
```

Aliases are independent resources that point to KMS keys and can later be redirected to another compatible key. ([AWS Documentation][2])

---

# 11. Aliases are not secrets

An alias can safely communicate its purpose:

```text
alias/todoapp-production-database
alias/platform-central-logs
alias/customer-backups
```

Do not put sensitive information in an alias:

```text
alias/password-for-customer-vivek
alias/card-number-...
```

KMS aliases are metadata and should not contain secret data. ([AWS Documentation][3])

---

# 12. Symmetric encryption KMS keys

A symmetric KMS key uses the same cryptographic key material for encryption and decryption.

```text
Plaintext
   |
   | Symmetric key
   v
Ciphertext

Ciphertext
   |
   | Same symmetric key
   v
Plaintext
```

Most AWS service integrations use symmetric encryption KMS keys.

Supported operations include:

* `Encrypt`
* `Decrypt`
* `ReEncrypt`
* `GenerateDataKey`
* `GenerateDataKeyWithoutPlaintext`

Symmetric encryption keys are the normal choice for S3, EBS, RDS, Secrets Manager and Parameter Store encryption. ([AWS Documentation][4])

---

# 13. Asymmetric KMS keys

Asymmetric KMS keys contain a public and private key pair.

```text
Public key:
Can be downloaded

Private key:
Remains protected inside KMS
```

Possible purposes:

```text
ENCRYPT_DECRYPT
SIGN_VERIFY
KEY_AGREEMENT
```

Use cases:

* Verify signatures outside AWS.
* Encrypt data outside AWS and decrypt it through KMS.
* Sign software or documents.
* Integrate with systems requiring public-key cryptography.

Do not choose asymmetric keys simply because they sound more secure. They solve a different cryptographic problem.

---

# 14. HMAC KMS keys

HMAC KMS keys generate and verify message authentication codes.

```text
Message + HMAC key
        |
        v
Authentication code
```

Use for:

* Request authentication.
* Message integrity.
* Compatibility with systems that use shared-secret MACs.

HMAC proves that someone with the shared secret produced the MAC.

A digital signature allows verification using a public key without sharing the private signing key.

---

# 15. Why you should not encrypt large files directly with KMS

The KMS `Encrypt` operation supports only small plaintext payloads; for a symmetric KMS key, the direct plaintext limit is 4,096 bytes. ([AWS Documentation][5])

Bad architecture:

```text
500-MB file
    |
    v
KMS Encrypt API
```

Correct architecture:

```text
500-MB file
    |
    | Local data key
    v
Encrypted file

Data key
    |
    | KMS key
    v
Encrypted data key
```

This is envelope encryption.

---

# 16. Envelope encryption

Envelope encryption means:

```text
1. Encrypt application data using a data key.

2. Encrypt the data key using a KMS key.

3. Store:
   encrypted data
   +
   encrypted data key
```

AWS defines envelope encryption as encrypting plaintext data with a data key and then encrypting that data key under another key. ([AWS Documentation][4])

Architecture:

```text
                  KMS key
                     |
                     v
              Encrypt data key
                     |
                     v
Plaintext data → Data key → Ciphertext data
                     |
                     v
             Encrypted data key
```

---

# 17. GenerateDataKey flow

Application calls:

```text
GenerateDataKey
```

KMS returns:

```text
Plaintext data key
Encrypted data key
```

The application:

```text
1. Uses plaintext data key to encrypt data locally.

2. Removes plaintext data key from memory.

3. Stores encrypted data key beside encrypted data.
```

Later:

```text
1. Send encrypted data key to KMS Decrypt.

2. Receive plaintext data key.

3. Decrypt the data locally.

4. Remove plaintext key from memory.
```

KMS never needs to receive the complete large object.

---

# 18. Envelope-encrypted object format

Conceptual structure:

```json
{
  "algorithm": "AES-256-GCM",
  "encryptedDataKey": "base64...",
  "initializationVector": "base64...",
  "authenticationTag": "base64...",
  "ciphertext": "base64...",
  "encryptionContext": {
    "application": "TodoApp",
    "environment": "production"
  }
}
```

The encrypted data key does not need to be hidden.

It is useless without authorization to use the KMS key.

However, the plaintext data key must never be:

* Logged.
* Written to disk.
* Stored in an environment variable.
* Sent to an unrelated service.
* Retained longer than necessary.

---

# 19. Data-key reuse

The strongest isolation model is often:

```text
One data key per object
or
One data key per bounded batch
```

Reusing one data key indefinitely increases the blast radius if that plaintext key is exposed.

AWS services such as S3 commonly request data keys through KMS as part of their server-side encryption implementation. KMS activity such as `GenerateDataKey` is recorded in CloudTrail. ([AWS Documentation][6])

---

# 20. Encryption context

Encryption context is a set of non-secret key-value pairs supplied during symmetric KMS cryptographic operations.

Example:

```json
{
  "Application": "TodoApp",
  "Environment": "production",
  "TenantId": "tenant-38",
  "RecordType": "TodoAttachment"
}
```

KMS uses the encryption context as additional authenticated data. The exact context must be supplied when decrypting, and it can also be enforced in key policies and grants. ([AWS Documentation][7])

---

# 21. Encryption context is not confidential

Encryption context can appear in:

* CloudTrail records.
* Logs.
* Error output.
* Policy evaluation.

Therefore do not use:

```text
Password
API key
Credit-card number
Private customer message
```

as an encryption-context value.

Good values:

```text
Resource ARN
Tenant ID
Application name
Environment
Record classification
```

AWS explicitly notes that encryption context is logged in plaintext for auditing. ([AWS Documentation][7])

---

# 22. Encryption-context authorization

Example key-policy condition:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/TodoApiRole"
  },
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:EncryptionContext:Application": "TodoApp",
      "kms:EncryptionContext:Environment": "production"
    }
  }
}
```

Now the role cannot use the key for data encrypted under unrelated contexts.

KMS supports policy conditions based on specific encryption-context pairs and encryption-context keys. ([AWS Documentation][8])

---

# 23. KMS access-control layers

KMS access can involve:

```text
Key policy
IAM identity policy
KMS grant
VPC endpoint policy
Service control policy
Permissions boundary
```

The key policy is the primary control on a KMS key. No principal—including the key creator—has permissions unless access is explicitly permitted and not otherwise denied. ([AWS Documentation][9])

---

# 24. Key administrators versus key users

## Key administrator

Manages the key:

```text
kms:DescribeKey
kms:EnableKey
kms:DisableKey
kms:PutKeyPolicy
kms:EnableKeyRotation
kms:ScheduleKeyDeletion
```

## Key user

Uses the key cryptographically:

```text
kms:Encrypt
kms:Decrypt
kms:GenerateDataKey
kms:ReEncrypt*
```

Separate these responsibilities.

A developer who needs to decrypt application data usually does not need permission to modify the key policy or schedule the key for deletion.

---

# 25. Enabling IAM policies through the key policy

An IAM policy granting:

```json
{
  "Action": "kms:Decrypt",
  "Resource": "key-arn"
}
```

does not automatically work unless the KMS key policy allows that account to delegate permissions through IAM or directly permits the role.

The common account-enabling key-policy statement is conceptually:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:root"
  },
  "Action": "kms:*",
  "Resource": "*"
}
```

This does not mean only the root user can use the key. It enables the account to delegate permissions through IAM policies.

---

# 26. Cross-account KMS access

For account B to use a KMS key in account A:

```text
Account A key policy:
Allows principal from account B

Account B IAM policy:
Allows KMS action on account A key
```

Both sides are required.

```text
Resource account authorization
+
Principal account authorization
=
Cross-account access
```

Do not grant cross-account access to the complete external account unless that is intentional. Prefer specific roles.

---

# 27. KMS grants

A grant is a permission instrument allowing a principal or AWS service to perform selected operations with a KMS key.

Grants are commonly used for:

* Temporary access.
* AWS service integration.
* Resource lifecycle.
* EBS volume attachments.
* Encrypted snapshots.
* Service-created resources.

Grants can be created, used and retired without permanently modifying the key policy. ([AWS Documentation][10])

---

# 28. Why AWS services use grants

Example:

```text
User starts encrypted EBS volume
        |
        v
EC2/EBS obtains KMS grant
        |
        v
Service uses key for that resource
        |
        v
Grant retired when no longer needed
```

This allows the service to use the key for a bounded purpose without receiving broad permanent key access.

---

# 29. Restricting grants

A grant can restrict operations and encryption context.

Example:

```json
{
  "GranteePrincipal": "arn:aws:iam::123456789012:role/TodoWorker",
  "Operations": [
    "Decrypt",
    "GenerateDataKey"
  ],
  "Constraints": {
    "EncryptionContextSubset": {
      "Application": "TodoApp"
    }
  }
}
```

AWS recommends encryption-context constraints when grants should be limited to a particular purpose. ([AWS Documentation][11])

---

# 30. Grant eventual consistency

Grant creation, retirement and revocation can take a short period to propagate throughout KMS.

For operations that must use a new grant immediately, KMS can return a grant token that is included in the subsequent cryptographic request. ([AWS Documentation][12])

Typical production applications do not manually create grants for every request. AWS service integrations often manage them.

---

# 31. `kms:ViaService`

The `kms:ViaService` condition can restrict key use to calls made through a named AWS service.

Concept:

```json
{
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "s3.ap-south-1.amazonaws.com"
    }
  }
}
```

This can permit:

```text
Role → S3 → KMS
```

while denying:

```text
Role → direct KMS Decrypt
```

Use this to ensure a role can access encrypted data only through the intended AWS service. KMS documents `kms:ViaService` as a least-privilege condition key. ([AWS Documentation][8])

---

# 32. Key rotation

There are two different rotation concepts:

```text
Rotate key material inside the same KMS key

Create a new KMS key and move an alias
```

These are not identical.

---

# 33. Automatic key-material rotation

Eligible customer managed symmetric encryption keys with AWS-generated key material support automatic rotation.

By default, automatic rotation occurs every 365 days. You can configure a custom rotation period from 90 through 2,560 days. The key ID, ARN, policy and aliases remain unchanged, and old key-material versions remain available to decrypt existing ciphertext. ([AWS Documentation][13])

```text
Same key ARN
    |
    ├── Key material version 1
    ├── Key material version 2
    └── Key material version 3
```

New encryption uses the current material.

Old ciphertext continues to decrypt using the appropriate older material.

---

# 34. On-demand rotation

On-demand rotation initiates a new key-material version immediately for supported keys.

Use for:

* Testing rotation procedures.
* Unplanned security rotation.
* Demonstrating compliance controls.
* Responding to potential key-material concerns.

AWS recommends automatic rotation for normal scheduled rotation and on-demand rotation for unplanned needs. ([AWS Documentation][14])

---

# 35. Manual key rotation with aliases

Manual rotation creates a completely new KMS key.

```text
alias/todoapp-production
          |
          v
       Old key
```

Create new key:

```text
alias/todoapp-production
          |
          v
       New key
```

An alias can be updated to target another compatible key without changing the application’s alias configuration. ([AWS Documentation][15])

However:

```text
Old ciphertext
still depends on old key.
```

Do not delete the old key until all old data has been re-encrypted or expired.

---

# 36. Key rotation is not data re-encryption

Automatic key rotation does not rewrite every S3 object, database page or secret.

It means:

```text
New cryptographic operations:
Use new key material

Existing ciphertext:
Decrypts through old retained material
```

If policy requires existing data to be protected under a completely new KMS key, you need a re-encryption or data-migration process.

---

# 37. Multi-Region KMS keys

Multi-Region keys are related KMS keys in different Regions with the same key ID and key material.

```text
Primary:
ap-south-1

Replica:
ap-southeast-1
```

Data encrypted by one related multi-Region key can be decrypted using another related key without a cross-Region KMS request or re-encryption. ([AWS Documentation][16])

---

# 38. Multi-Region key architecture

```text
ap-south-1
┌─────────────────────────────┐
│ Primary MRK                 │
│ mrk-abc123                  │
└──────────────┬──────────────┘
               |
               | Shared key material
               v
ap-southeast-1
┌─────────────────────────────┐
│ Replica MRK                 │
│ mrk-abc123                  │
└─────────────────────────────┘
```

Each Region has:

* Its own key ARN.
* Its own key policy.
* Its own grants.
* Its own aliases.
* Its own enabled/disabled state.
* Its own CloudTrail activity.

Shared properties such as key material are synchronized from the primary. ([AWS Documentation][16])

---

# 39. When to use multi-Region keys

Strong use cases:

* Client-side encrypted data moving across Regions.
* DynamoDB global-table client-side encryption.
* Multi-Region application encryption formats.
* Disaster recovery requiring the same ciphertext to decrypt locally.
* Cross-Region signed or encrypted application data.

Do not use multi-Region keys automatically for every replicated AWS service.

Many AWS services replicate encrypted data and re-encrypt it using independent Regional keys.

Independent Regional keys can provide a smaller cryptographic blast radius.

---

# 40. Single-Region keys versus multi-Region keys

## Independent Regional keys

```text
Mumbai key:
Different material

Singapore key:
Different material
```

Advantages:

* Strong Regional isolation.
* Compromise of one key does not expose both Regions.
* Often sufficient for AWS-managed replication.

## Multi-Region keys

```text
Mumbai and Singapore:
Related key material
```

Advantages:

* Same ciphertext decrypts in either Region.
* No cross-Region KMS dependency.
* Useful for client-side encryption and portable encrypted data.

Choose based on whether ciphertext interoperability is truly required.

---

# 41. Imported key material

Imported key material allows you to provide cryptographic material to a KMS key with origin:

```text
EXTERNAL
```

Use cases:

* Regulatory requirements.
* Existing enterprise keys.
* Requirement to control key-material generation.
* Requirement to delete or expire imported material independently.

Imported material adds responsibility:

* Secure generation.
* Secure backups.
* Import procedure.
* Expiration planning.
* Disaster recovery.
* Rotation management.

Automatic rotation is not supported for imported key material, though eligible symmetric imported keys support on-demand rotation. ([AWS Documentation][17])

---

# 42. Imported-key disaster risk

If imported key material expires or is deleted without a recoverable copy:

```text
KMS key becomes unusable
        |
        v
Encrypted data may become permanently inaccessible
```

AWS warns that losing required imported key material can make the entire KMS key unusable. ([AWS Documentation][18])

Do not import key material without a tested backup and re-import process.

---

# 43. CloudHSM custom key stores

A CloudHSM custom key store stores KMS key material in an AWS CloudHSM cluster that you control.

Use when:

* Dedicated HSM tenancy is required.
* You need operational control of the HSM cluster.
* Compliance requires CloudHSM-backed KMS keys.
* Standard KMS HSM isolation is insufficient for policy reasons.

Tradeoffs:

* CloudHSM cluster cost.
* HSM availability responsibility.
* Cluster administration.
* Backup responsibility.
* Greater operational complexity.

Most applications should use standard KMS unless a concrete requirement justifies a custom key store.

---

# 44. External key stores

An external key store connects KMS to key material maintained outside AWS.

This is often described as hold your own key:

```text
AWS KMS
   |
   v
External key store proxy
   |
   v
External key manager
```

Cryptographic operations depend on the availability and latency of the external key manager. External key stores do not support features such as automatic rotation or multi-Region keys. ([AWS Documentation][19])

Use only when a strict external-key-control requirement outweighs the additional availability and operational risk.

---

# 45. Disabling a key

Disabling a customer managed key makes it unavailable for new cryptographic operations.

```text
Enabled
   |
   v
Disabled
```

Effects can include:

* Applications cannot decrypt data.
* Services cannot generate data keys.
* Encrypted resource operations may fail.
* Secret retrieval may fail.
* Database or volume operations may be affected.

Disabling is reversible.

It is often safer than immediate deletion when investigating whether a key is still used.

---

# 46. Scheduling key deletion

KMS key deletion is permanent and destructive.

Customer managed keys require a waiting period from 7 through 30 days before deletion. During the waiting period the key is in `PendingDeletion`, cannot perform cryptographic operations and can still have deletion cancelled. After deletion, a replacement key cannot decrypt the old ciphertext merely because it uses similar key material. ([AWS Documentation][20])

## Production deletion process

```text
1. Identify all encrypted resources.

2. Check CloudTrail key usage.

3. Disable key first.

4. Monitor failures.

5. Re-enable if required.

6. Re-encrypt or remove dependent data.

7. Schedule deletion with 30-day window.

8. Alarm on attempted use during the window.

9. Require security approval before final deletion.
```

---

# 47. CloudTrail and KMS

CloudTrail records:

* Key creation.
* Policy changes.
* Alias changes.
* Grant creation.
* Key enable/disable.
* Rotation.
* Deletion scheduling.
* `Encrypt`.
* `Decrypt`.
* `GenerateDataKey`.

CloudTrail logs all KMS API operations, including cryptographic operations. ([AWS Documentation][21])

Important investigation fields:

```text
eventName
userIdentity
keyId
encryptionContext
sourceIPAddress
userAgent
errorCode
```

---

# 48. KMS incident indicators

Alert on sensitive actions such as:

```text
DisableKey
ScheduleKeyDeletion
PutKeyPolicy
CreateGrant
RevokeGrant
UpdateAlias
DeleteAlias
DeleteImportedKeyMaterial
ReplicateKey
UpdatePrimaryRegion
```

Potential signals:

* Unexpected high `Decrypt` volume.
* Decrypt calls from an unknown role.
* Policy changes outside CI/CD.
* Key disabled in production.
* Alias redirected unexpectedly.
* Failed decrypt calls after deployment.

Use CloudTrail, EventBridge and your central security monitoring system.

---

# Part 3 — AWS Secrets Manager

# 49. What is Secrets Manager?

Secrets Manager stores sensitive values such as:

* Database usernames and passwords.
* OAuth client secrets.
* API keys.
* Third-party service credentials.
* Private tokens.
* Signing credentials.
* Application secrets.

Secrets are encrypted with KMS and controlled through IAM and optional resource-based policies. ([AWS Documentation][22])

Example:

```json
{
  "username": "todoapp",
  "password": "generated-secret",
  "engine": "postgres",
  "host": "production.cluster-example.ap-south-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "todoapp"
}
```

---

# 50. Secret versus environment variable

Environment variables are useful for:

* Secret ARN.
* Parameter name.
* Region.
* Non-sensitive configuration.

Avoid injecting long-lived plaintext secrets into environment variables when the application can retrieve them securely at runtime.

Better:

```text
Environment variable:
DB_SECRET_ARN

Application:
GetSecretValue(DB_SECRET_ARN)
```

This supports:

* Rotation.
* Central access control.
* Reduced deployment coupling.
* Better auditability.

---

# 51. Secret versioning

Every update creates a new secret version.

Secrets Manager uses staging labels:

```text
AWSCURRENT
AWSPREVIOUS
AWSPENDING
```

A secret always has one version labeled `AWSCURRENT`, and retrieval returns that version by default unless another version or stage is requested. ([AWS Documentation][23])

---

# 52. Version-stage mental model

```text
Version 1:
AWSPREVIOUS

Version 2:
AWSCURRENT

Version 3:
AWSPENDING
```

During a successful rotation:

```text
New version:
AWSPENDING
      |
      v
Tested successfully
      |
      v
AWSCURRENT

Old current:
AWSPREVIOUS
```

The previous version provides a rollback and troubleshooting reference.

---

# 53. Secret retrieval

CLI:

```bash
aws secretsmanager get-secret-value \
  --secret-id "production/todoapp/database" \
  --query SecretString \
  --output text \
  --region ap-south-1
```

Application permissions normally require:

```text
secretsmanager:GetSecretValue
```

When a customer managed KMS key protects the secret, the caller may also require:

```text
kms:Decrypt
```

depending on policy and service access.

---

# 54. Do not print secrets

Avoid commands such as:

```bash
echo "$DATABASE_PASSWORD"
```

inside:

* Jenkins logs.
* GitHub Actions output.
* Cloud-init logs.
* Terraform provisioners.
* Shell history.
* Docker build output.

When testing secret retrieval:

* Avoid shared terminals.
* Avoid `set -x`.
* Avoid copying into tickets.
* Clear temporary files.
* Use redacted output.
* Rotate a secret immediately if exposed.

---

# 55. Runtime retrieval and caching

Calling Secrets Manager for every request adds:

* API latency.
* API cost.
* Throttling risk.
* A runtime dependency for every operation.

Recommended:

```text
Application starts
      |
      v
Retrieve secret
      |
      v
Cache in memory
      |
      v
Refresh periodically or after authentication failure
```

AWS provides client-side caching components for several programming languages and recommends caching secrets where appropriate. ([AWS Documentation][24])

---

# 56. Cache lifetime

A cache must balance:

```text
Short TTL:
Fast rotation adoption
More API calls

Long TTL:
Fewer API calls
Slower rotation adoption
```

A practical pattern:

```text
Normal refresh:
Every 5–30 minutes

On database authentication failure:
Refresh immediately once
and retry safely
```

Do not cache secrets permanently for the lifetime of a server that may run for months.

---

# 57. Node.js secret cache example

```javascript
import {
  GetSecretValueCommand,
  SecretsManagerClient
} from "@aws-sdk/client-secrets-manager";

const client = new SecretsManagerClient({
  region: process.env.AWS_REGION ?? "ap-south-1"
});

let cachedSecret;
let cacheExpiresAt = 0;

export async function getDatabaseSecret() {
  const now = Date.now();

  if (cachedSecret && now < cacheExpiresAt) {
    return cachedSecret;
  }

  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: process.env.DB_SECRET_ARN
    })
  );

  if (!response.SecretString) {
    throw new Error("Database secret does not contain SecretString");
  }

  const parsed = JSON.parse(response.SecretString);

  if (!parsed.username || !parsed.password || !parsed.host) {
    throw new Error("Database secret has an invalid structure");
  }

  cachedSecret = parsed;
  cacheExpiresAt = now + 5 * 60 * 1000;

  return cachedSecret;
}

export function invalidateDatabaseSecretCache() {
  cachedSecret = undefined;
  cacheExpiresAt = 0;
}
```

Do not log the parsed object when errors occur.

---

# 58. Secret rotation

Rotation updates both:

```text
Secret value in Secrets Manager
+
Credential in the target database or service
```

Changing only the stored value would leave the application with a password the database does not recognize.

Secrets Manager supports managed rotation for supported service-managed secrets and Lambda-based rotation for other secret types. ([AWS Documentation][25])

---

# 59. Lambda rotation lifecycle

A Secrets Manager Lambda rotation function implements four steps:

```text
createSecret
setSecret
testSecret
finishSecret
```

AWS documents these as the standard rotation stages. ([AWS Documentation][26])

---

# 60. `createSecret`

Purpose:

```text
Create a new AWSPENDING secret version
```

The function should:

* Check whether the version already exists.
* Generate a cryptographically secure value.
* Preserve required connection metadata.
* Store it with `AWSPENDING`.
* Be idempotent if called again.

---

# 61. `setSecret`

Purpose:

```text
Apply the AWSPENDING credential
to the database or external service
```

Example:

```text
ALTER USER todoapp
WITH PASSWORD '<new-password>';
```

Security checks should confirm:

* Host matches expected system.
* Username is correct.
* Pending and current secret belong together.
* Rotation function is not changing an arbitrary target.
* TLS is used for database connection.

---

# 62. `testSecret`

Purpose:

```text
Verify that AWSPENDING works
```

Test more than TCP connectivity.

Possible checks:

* Authenticate.
* Execute a harmless query.
* Verify expected database name.
* Verify expected permissions.
* Confirm the credential is not overprivileged.

Example:

```sql
SELECT 1;
```

---

# 63. `finishSecret`

Purpose:

```text
Move AWSCURRENT to the tested pending version
```

Secrets Manager then moves the previous current version to `AWSPREVIOUS`. ([AWS Documentation][26])

Application clients that refresh the secret begin using the new credentials.

---

# 64. Rotation strategies

## Single-user rotation

The same database user password is changed.

```text
todoapp user:
old password → new password
```

Advantages:

* Simple.
* Fewer database users.

Risk:

* Brief compatibility issues if applications still use the old password.

## Alternating-users rotation

Two database users alternate.

```text
todoapp_a:
current

todoapp_b:
next
```

Advantages:

* Old user remains valid during transition.
* Safer for some high-availability applications.

Tradeoffs:

* More complex permissions.
* Duplicate database users.
* Rotation-function complexity.

Secrets Manager documents both single-user and alternating-user rotation patterns. ([AWS Documentation][24])

---

# 65. RDS-managed master password

For supported RDS configurations, RDS can manage the database master password in Secrets Manager.

Advantages:

* Password generation managed by AWS.
* Rotation integration.
* Secret association maintained by RDS.
* Reduced manual password handling.

However, application workloads should ideally use a dedicated application database user rather than the database master user.

The master account is too powerful for normal application queries.

---

# 66. Rotation schedule

Rotation can be scheduled:

```text
Every N days
or
with a schedule expression and rotation window
```

The schedule should consider:

* Credential risk.
* Application refresh behavior.
* Database availability.
* Vendor API limits.
* Maintenance windows.
* Rotation-function capacity.
* Compliance requirements.

Secrets Manager runs rotation during the configured rotation window. ([AWS Documentation][27])

---

# 67. Rotation and connection pools

When credentials rotate:

```text
Existing database connections:
May continue temporarily

New connections using old secret:
Fail
```

Application strategy:

```text
1. Retrieve cached secret.

2. Attempt connection.

3. On authentication failure:
   invalidate secret cache.

4. Retrieve AWSCURRENT.

5. Rebuild the connection pool.

6. Retry the operation once safely.
```

Do not retry indefinitely because the failure may have another cause.

---

# 68. Secret cross-Region replication

Secrets Manager can replicate a primary secret to additional Regions.

```text
Primary secret:
ap-south-1
        |
        v
Replica:
ap-southeast-1
```

Secret value and relevant metadata are replicated. When the primary secret rotates, the new value propagates to replicas. ([AWS Documentation][28])

This supports Regional workloads retrieving secrets locally.

---

# 69. Secret replication is not complete DR

Replicating a secret does not replicate:

* Database contents.
* Application deployment.
* IAM roles.
* VPC endpoints.
* Security groups.
* Rotation Lambda configuration in every possible scenario.
* External service availability.

Complete DR requires the secret value and the target resource to be usable in the recovery Region.

---

# 70. Cross-account secret access

For a role in account B to read a secret in account A, you normally need:

```text
Secret resource policy in account A
+
IAM policy on role in account B
+
KMS key policy in account A
+
IAM KMS permission in account B
```

Secrets Manager requires both resource-side and principal-side authorization for cross-account access. A customer managed KMS key is required because the default AWS managed Secrets Manager key cannot be used for this cross-account design. ([AWS Documentation][29])

---

# 71. Cross-account secret resource policy

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowProductionConsumer",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/TodoConsumerRole"
      },
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

Use `BlockPublicPolicy` or Secrets Manager resource-policy validation to prevent broad public access. Secrets Manager uses policy validation to identify overly permissive secret resource policies. ([AWS Documentation][30])

---

# 72. Secrets Manager VPC endpoint

Private workloads can access Secrets Manager through an interface VPC endpoint.

```text
Private ECS task
      |
      v
Secrets Manager VPC endpoint
      |
      v
Secrets Manager
```

Benefits:

* No internet gateway required.
* No NAT gateway dependency for that API.
* Endpoint-policy control.
* Traffic remains on AWS networking.

AWS recommends a Secrets Manager VPC endpoint for rotation functions inside VPCs so their secret API calls do not need public network paths. ([AWS Documentation][31])

---

# 73. Deleting secrets

Secrets Manager normally schedules deletion with a recovery window.

* Minimum recovery window: 7 days.
* Default: 30 days.
* During the window, the secret is inaccessible but can be restored.
* Force deletion without recovery is possible through the API or CLI but is irreversible. ([AWS Documentation][32])

Production recommendation:

```text
Never use force-delete-without-recovery
in normal automation.
```

---

# 74. Secret deletion workflow

```text
1. Search application configuration for secret ARN.

2. Review CloudTrail GetSecretValue usage.

3. Disable or migrate the application.

4. Schedule deletion with 30-day recovery.

5. Alarm on attempted access.

6. Restore immediately if an application still needs it.

7. Permanently delete only after the window.
```

Replica secrets must be removed before deleting a replicated primary secret. ([AWS Documentation][32])

---

# Part 4 — Systems Manager Parameter Store

# 75. What is Parameter Store?

Parameter Store manages configuration values as named parameters.

Supported types:

```text
String
StringList
SecureString
```

It supports hierarchical names, versions, labels, IAM access and integrations with services such as EC2, Lambda and CloudFormation. `SecureString` parameters are encrypted using KMS. ([AWS Documentation][33])

Examples:

```text
/production/todoapp/api/log-level
/production/todoapp/database/host
/production/todoapp/features/new-dashboard
/production/todoapp/vendor/api-key
```

---

# 76. Parameter Store versus Secrets Manager

| Requirement                     |       Parameter Store |          Secrets Manager |
| ------------------------------- | --------------------: | -----------------------: |
| Plain configuration             |             Excellent | Possible but unnecessary |
| Encrypted small configuration   |                  Good |                     Good |
| Automatic credential rotation   |         Manual/custom |                 Built in |
| Secret version stages           | No `AWSCURRENT` model |                      Yes |
| Database rotation templates     |                    No |                      Yes |
| Cross-Region secret replication |  No native equivalent |                      Yes |
| Cross-account sharing           |   Advanced parameters |          Resource policy |
| Hierarchical paths              |             Excellent |               Names/tags |
| Cost-sensitive configuration    |            Strong fit |              Higher cost |
| Secret-specific lifecycle       |               Limited |                   Strong |

AWS recommends Secrets Manager for credentials requiring automatic rotation, cross-account secret access or secret-specific auditing, while Parameter Store is suitable for configuration and lightweight encrypted values. ([AWS Documentation][33])

---

# 77. Example classification

Use Parameter Store:

```text
/production/todoapp/log-level = INFO
/production/todoapp/max-upload-mb = 20
/production/todoapp/search/index = todos-v2
/production/todoapp/feature/new-ui = true
```

Use Secrets Manager:

```text
Database password
Stripe API key
GitHub App private key
OAuth client secret
SMTP credential
```

Never place passwords in plain `String` parameters.

---

# 78. `SecureString`

When creating a `SecureString`, Parameter Store uses KMS to encrypt and decrypt the value.

You can use:

```text
alias/aws/ssm
```

or a customer managed key.

Parameter Store supports only symmetric KMS encryption keys for `SecureString`. ([AWS Documentation][34])

Use a customer managed key when you need:

* Custom key policy.
* Cross-account access.
* Application isolation.
* Key disable or deletion control.
* Explicit auditing boundary.

---

# 79. Parameter hierarchy

Recommended hierarchy:

```text
/<environment>/<application>/<component>/<parameter>
```

Example:

```text
/production/todoapp/api/log-level
/production/todoapp/api/timeout-seconds
/production/todoapp/worker/batch-size
/staging/todoapp/api/log-level
```

Benefits:

* Clear ownership.
* Environment isolation.
* Recursive retrieval.
* IAM path policies.
* Easier automation.

Parameter names are case-sensitive and use `/` to express hierarchy levels. ([AWS Documentation][35])

---

# 80. Recursive-path security caveat

Be careful with:

```text
ssm:GetParametersByPath
```

Granting recursive access to:

```text
/production/todoapp
```

can allow access to every child below that hierarchy, even when an individual nested parameter has a separate explicit deny in some policy arrangements. AWS calls out this recursive hierarchy behavior in its parameter-name guidance. ([AWS Documentation][36])

Design separate top-level paths for different security boundaries:

```text
/production/todoapp/public-config
/production/todoapp/application-secrets
/production/todoapp/admin-only
```

---

# 81. Parameter tiers

Parameter Store has standard and advanced tiers.

| Feature                               |                    Standard | Advanced |
| ------------------------------------- | --------------------------: | -------: |
| Maximum parameters per account/Region |                      10,000 |  100,000 |
| Maximum value size                    |                        4 KB |     8 KB |
| Parameter policies                    |                          No |      Yes |
| Cross-account sharing                 |                          No |      Yes |
| Additional charge                     | No parameter storage charge |      Yes |

A standard parameter can be upgraded to advanced, but it cannot be downgraded directly. ([AWS Documentation][33])

---

# 82. Intelligent-Tiering

Parameter Store supports an intelligent tiering default that creates standard parameters unless the requested features require advanced tier behavior.

Automatic upgrade can occur when:

* Standard quota is exceeded.
* Value exceeds standard size.
* Parameter policies are applied.
* An advanced-only feature is requested.

This can reduce accidental advanced-parameter costs while permitting required upgrades. ([AWS Documentation][37])

---

# 83. Parameter versions

Each update creates a new numbered version:

```text
Version 1:
INFO

Version 2:
DEBUG

Version 3:
WARN
```

Parameter Store retains up to 100 versions per parameter, subject to label-related safeguards. ([AWS Documentation][38])

Retrieve a specific version:

```bash
aws ssm get-parameter \
  --name "/production/todoapp/api/log-level:2" \
  --region ap-south-1
```

Versions help with:

* Audit history.
* Rollback.
* Controlled deployments.
* Comparing configuration changes.

---

# 84. Parameter labels

Labels are user-defined aliases for parameter versions.

Example:

```text
Version 4:
Candidate

Version 3:
Production
```

After validation:

```text
Move Production label:
Version 3 → Version 4
```

A label can be moved between versions, making it useful for controlled configuration promotion. ([AWS Documentation][39])

Retrieve using a label:

```bash
aws ssm get-parameter \
  --name "/production/todoapp/golden-ami:Production" \
  --region ap-south-1
```

---

# 85. Parameter policies

Advanced parameters support:

```text
Expiration
ExpirationNotification
NoChangeNotification
```

* `Expiration` deletes a parameter at a specified time.
* `ExpirationNotification` emits an EventBridge event before expiry.
* `NoChangeNotification` emits an event when a parameter has not changed for a configured period. ([AWS Documentation][40])

These can identify stale configuration or credentials.

They do not automatically rotate a database password.

---

# 86. Parameter Store throughput

Parameter Store applies Regional API-throughput quotas.

A pattern that calls `GetParameter` on every web request can cause:

* Extra latency.
* Throttling.
* Higher advanced throughput cost where enabled.
* An unnecessary runtime dependency.

AWS describes the standard throughput setting as appropriate for low- to moderate-volume access, with higher throughput configurable where required. ([AWS Documentation][41])

Use:

* Application caching.
* Startup retrieval.
* Periodic refresh.
* AppConfig for dynamic configuration.
* Secrets Manager caching for credentials.

---

# 87. Cross-account parameters

Advanced Parameter Store parameters can be shared across AWS accounts using AWS Resource Access Manager.

```text
Central configuration account
          |
          v
Shared advanced parameters
          |
          ├── Development account
          ├── Staging account
          └── Production account
```

Cross-account sharing is an advanced-tier feature, and API-use charges can apply to consuming accounts. ([AWS Documentation][42])

Use for centrally governed non-secret configuration.

---

# 88. Parameter Store CLI

Create a normal parameter:

```bash
aws ssm put-parameter \
  --name "/production/todoapp/api/log-level" \
  --type String \
  --value "INFO" \
  --overwrite \
  --region ap-south-1
```

Create an encrypted parameter:

```bash
aws ssm put-parameter \
  --name "/production/todoapp/vendor/api-key" \
  --type SecureString \
  --key-id "alias/todoapp-production-parameters" \
  --value "$VENDOR_API_KEY" \
  --region ap-south-1
```

Retrieve decrypted:

```bash
aws ssm get-parameter \
  --name "/production/todoapp/vendor/api-key" \
  --with-decryption \
  --region ap-south-1
```

Avoid placing the secret directly in shell history. Prefer file input or a secure interactive mechanism.

---

# Part 5 — AWS Certificate Manager

# 89. What is ACM?

AWS Certificate Manager provisions and manages TLS certificates for supported AWS services.

Common integrations include:

* Elastic Load Balancing.
* CloudFront.
* API Gateway.
* AppSync.
* Cognito custom domains.
* Other integrated AWS services.

ACM supports public certificates, private certificates issued through AWS Private CA and imported certificates. ([AWS Documentation][43])

---

# 90. TLS certificate mental model

A certificate binds:

```text
Domain or identity
        |
        v
Public key
        |
        v
Certificate authority signature
```

When a client connects:

```text
1. Server presents certificate.

2. Client validates trusted issuer.

3. Client checks hostname.

4. Client checks certificate lifetime.

5. TLS session keys are established.

6. Traffic is encrypted.
```

The certificate private key proves control of the certificate identity.

---

# 91. Public versus private certificates

## Public certificate

Trusted by normal browsers and public clients.

Use for:

```text
api.yourdatascientist.tech
app.yourdatascientist.tech
cdn.yourdatascientist.tech
```

## Private certificate

Trusted only by systems configured to trust your private CA.

Use for:

```text
Internal service identity
Private corporate applications
Mutual TLS
Private PKI
Internal devices
```

Private certificates can be issued through AWS Private CA. ([AWS Documentation][44])

---

# 92. Regional nature of ACM certificates

ACM certificates are Regional resources.

For a Regional load balancer in Mumbai:

```text
ALB:
ap-south-1

Certificate:
ap-south-1
```

For an ALB in Singapore:

```text
ALB:
ap-southeast-1

Certificate:
ap-southeast-1
```

The same certificate ARN cannot simply be attached across Regions. Imported certificates must also be imported separately into every required Region. ([AWS Documentation][45])

---

# 93. CloudFront certificate Region

CloudFront requires its ACM certificate in:

```text
us-east-1
```

even when the CloudFront origin is in another Region. ([AWS Documentation][43])

For your architecture:

```text
CloudFront:
Global

ACM certificate:
us-east-1

ALB origin:
ap-south-1
```

---

# 94. Cognito custom-domain certificate Region

A Cognito user-pool custom domain also requires its certificate in:

```text
us-east-1
```

because the Cognito custom-domain frontend uses CloudFront infrastructure.

Remember:

```text
ALB certificate:
Same Region as ALB

API Gateway Regional certificate:
Same Region as API

CloudFront certificate:
us-east-1

Cognito custom-domain certificate:
us-east-1
```

---

# 95. DNS validation

ACM gives you a CNAME validation record.

Example:

```text
Name:
_abcd1234.api.yourdatascientist.tech

Value:
_xyz987.acm-validations.aws
```

You add this CNAME to the domain’s public DNS.

DNS validation proves control of the domain and supports automated certificate renewal while the record remains available. ([AWS Documentation][46])

---

# 96. Keep ACM validation records permanently

Do not delete the validation CNAME after the certificate becomes `ISSUED`.

That CNAME supports:

* Initial validation.
* Automatic renewal.
* Re-creating matching certificates.
* Validation in additional Regions.

The same ACM validation token can be reused when requesting matching certificates in multiple AWS Regions. ([AWS Documentation][46])

---

# 97. DNS validation versus email validation

DNS validation is normally preferred because:

* It can be automated.
* It supports managed renewal.
* It is infrastructure-as-code friendly.
* It does not depend on a person opening renewal email.
* It remains valid while the DNS CNAME exists.

AWS recommends DNS validation for automatic renewal. ([AWS Documentation][47])

Email validation creates a human operational dependency and is easier to miss.

---

# 98. ACM managed renewal

ACM-managed public certificates can renew automatically when:

* The certificate remains eligible.
* It remains associated with a supported AWS service or otherwise meets eligibility requirements.
* Domain ownership can still be validated.
* Required DNS records remain present for DNS validation.

For public certificates, ACM starts renewal attempts before expiry; private ACM certificates use an earlier renewal window. The certificate ARN remains the same after managed renewal. ([AWS Documentation][48])

---

# 99. Renewal monitoring

Monitor:

```text
Certificate status
Renewal eligibility
Renewal status
Days to expiry
AWS Health events
EventBridge ACM events
```

Do not assume:

```text
ACM certificate
=
Impossible to expire
```

Renewal can fail because:

* DNS CNAME was deleted.
* Certificate is no longer in use.
* Domain ownership cannot be validated.
* Email validation was missed.
* DNS provider configuration changed.
* CAA or domain configuration prevents issuance.

---

# 100. Imported certificates

You can import:

```text
Certificate
Private key
Certificate chain
```

into ACM.

Imported certificates:

* Are Regional.
* Are not automatically issued by ACM.
* Require you to monitor expiry.
* Require re-import or replacement when renewed.
* Must use an unencrypted private key in the supported import format.

CloudFront imports must be made in `us-east-1`. ([AWS Documentation][45])

---

# 101. Exportable ACM public certificates

ACM now supports requesting public certificates that are explicitly exportable.

An exportable certificate allows retrieval of:

* Certificate.
* Encrypted private key.
* Certificate chain.

This is useful for infrastructure not directly integrated with ACM, such as certain on-premises systems or customer-managed workloads. Exportable public certificates must be requested as exportable and have separate pricing and security considerations. ([AWS Documentation][49])

Treat the exported private key as highly sensitive.

---

# 102. Standard managed ACM versus exportable

## Standard ACM-managed certificate

```text
Private key:
Managed by ACM

Application operator:
Cannot export it

Use:
Integrated AWS services
```

## Exportable public certificate

```text
Private key:
Can be exported with a passphrase

Application operator:
Responsible for secure storage and deployment

Use:
Customer-managed infrastructure
```

If an AWS service integrates directly with ACM, prefer the normal managed certificate unless you specifically need exportability.

---

# 103. AWS Private CA

AWS Private CA provides managed private certificate authorities.

Possible hierarchy:

```text
Offline enterprise root CA
        |
        v
AWS Private CA subordinate CA
        |
        v
Application certificates
```

Use cases:

* Internal mTLS.
* Device certificates.
* Corporate applications.
* Service identities.
* Private Kubernetes workloads.
* Enterprise PKI integration.

A private certificate is not publicly trusted unless its issuing CA chain is installed in the client trust store.

---

# 104. Private-certificate renewal

Private certificates requested through ACM from AWS Private CA can be eligible for ACM managed renewal.

Certificates issued directly through the AWS Private CA `IssueCertificate` API are not automatically managed by ACM in the same manner. ([AWS Documentation][50])

Choose the issuance path according to whether you need ACM-managed deployment and renewal.

---

# Part 6 — Service-selection guide

# 105. What should store this value?

| Value                                | Recommended service                   |
| ------------------------------------ | ------------------------------------- |
| Database password                    | Secrets Manager                       |
| GitHub App private key               | Secrets Manager                       |
| Stripe API key                       | Secrets Manager                       |
| Application log level                | Parameter Store                       |
| Feature-flag default                 | Parameter Store or AppConfig          |
| Approved AMI ID                      | Parameter Store                       |
| KMS encryption key                   | AWS KMS                               |
| TLS certificate for ALB              | ACM                                   |
| TLS certificate for CloudFront       | ACM in `us-east-1`                    |
| Internal mTLS certificate            | ACM Private CA / private PKI          |
| OAuth client secret                  | Secrets Manager                       |
| Public API base URL                  | Parameter Store                       |
| Large application configuration file | S3, with reference in Parameter Store |

---

# 106. Common architecture mistakes

## Mistake 1

```text
Store database password in Terraform variables
```

The secret can enter Terraform state.

## Mistake 2

```text
Use one KMS key with kms:* for every role
```

This creates a large blast radius.

## Mistake 3

```text
Delete the ACM DNS validation CNAME
```

Renewal can fail later.

## Mistake 4

```text
Call Secrets Manager on every HTTP request
```

This adds cost, latency and throttling risk.

## Mistake 5

```text
Rotate secret value but not database password
```

Application authentication fails.

## Mistake 6

```text
Schedule KMS key deletion before inventorying data
```

Encrypted data can become unrecoverable.

## Mistake 7

```text
Use Parameter Store String for a password
```

It is stored as plaintext.

---

# Part 7 — Terraform implementation

# 107. Terraform KMS key

```hcl
resource "aws_kms_key" "todoapp" {
  description = "TodoApp production application data"

  key_usage = "ENCRYPT_DECRYPT"

  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  enable_key_rotation     = true
  rotation_period_in_days = 180

  deletion_window_in_days = 30

  is_enabled = true

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

A 180-day period is within KMS’s supported automatic-rotation range of 90–2,560 days. ([AWS Documentation][13])

---

# 108. Terraform KMS alias

```hcl
resource "aws_kms_alias" "todoapp" {
  name          = "alias/todoapp-production-data"
  target_key_id = aws_kms_key.todoapp.key_id
}
```

Applications should normally use the alias ARN or key ARN rather than embedding the raw UUID everywhere.

---

# 109. KMS key policy

```hcl
data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "EnableAccountAdministration"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowTodoApiCryptographicUse"
    effect = "Allow"

    principals {
      type = "AWS"

      identifiers = [
        aws_iam_role.todo_api.arn
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"

      values = [
        "secretsmanager.ap-south-1.amazonaws.com"
      ]
    }
  }
}

resource "aws_kms_key" "secrets" {
  description = "TodoApp production secrets"

  policy = data.aws_iam_policy_document.kms.json

  enable_key_rotation     = true
  rotation_period_in_days = 180

  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}
```

Be cautious not to lock the account out by replacing the key policy with a document that omits administrative access.

---

# 110. Terraform Secrets Manager secret

```hcl
resource "aws_secretsmanager_secret" "database" {
  name        = "production/todoapp/database"
  description = "TodoApp database application credentials"

  kms_key_id = aws_kms_key.secrets.arn

  recovery_window_in_days = 30

  tags = {
    Application = "TodoApp"
    Environment = "production"
    Classification = "credential"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

---

# 111. Avoid secret values in Terraform state

This is dangerous:

```hcl
resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = "todoapp"
    password = var.database_password
  })
}
```

Even when the variable is marked `sensitive`, the plaintext value can still be stored in Terraform state.

Safer options:

* Let RDS manage its master secret.
* Create only the secret container with Terraform.
* Populate the secret through a secure deployment step.
* Generate the value outside Terraform state.
* Use a provider or workflow designed for ephemeral secret writes.
* Protect remote state with strong access control and KMS encryption if a secret must enter state.

---

# 112. Populate secret using CLI

Create a JSON file securely:

```bash
umask 077

cat > /tmp/todoapp-database.json <<EOF
{
  "username": "todoapp",
  "password": "${DATABASE_PASSWORD}",
  "engine": "postgres",
  "host": "${DATABASE_HOST}",
  "port": 5432,
  "dbname": "todoapp"
}
EOF
```

Store:

```bash
aws secretsmanager put-secret-value \
  --secret-id "production/todoapp/database" \
  --secret-string file:///tmp/todoapp-database.json \
  --region ap-south-1
```

Remove:

```bash
shred -u /tmp/todoapp-database.json 2>/dev/null \
  || rm -f /tmp/todoapp-database.json
```

Ensure the CI/CD environment itself is trusted and logs are redacted.

---

# 113. Terraform secret rotation

```hcl
resource "aws_secretsmanager_secret_rotation" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  rotation_lambda_arn = aws_lambda_function.rotate_database_secret.arn

  rotation_rules {
    automatically_after_days = 30
    duration                  = "2h"
  }

  depends_on = [
    aws_lambda_permission.allow_secrets_manager_rotation
  ]
}
```

Lambda permission:

```hcl
resource "aws_lambda_permission" "allow_secrets_manager_rotation" {
  statement_id  = "AllowSecretsManagerRotation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_database_secret.function_name
  principal     = "secretsmanager.amazonaws.com"

  source_arn = aws_secretsmanager_secret.database.arn
}
```

---

# 114. Terraform Parameter Store values

Normal configuration:

```hcl
resource "aws_ssm_parameter" "log_level" {
  name  = "/production/todoapp/api/log-level"
  type  = "String"
  value = "INFO"

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

Encrypted parameter:

```hcl
resource "aws_ssm_parameter" "vendor_token" {
  name = "/production/todoapp/vendor/token"
  type = "SecureString"

  key_id = aws_kms_key.parameters.arn

  value = var.vendor_token

  tier = "Advanced"

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
```

The encrypted value can still enter state. Prefer an external secret-write mechanism for sensitive production credentials.

---

# 115. Terraform ACM certificate for ALB

```hcl
resource "aws_acm_certificate" "api" {
  domain_name = "api.yourdatascientist.tech"

  subject_alternative_names = [
    "*.api.yourdatascientist.tech"
  ]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

This provider must use:

```text
ap-south-1
```

when the certificate is attached to an ALB in Mumbai.

---

# 116. Route 53 ACM validation records

```hcl
resource "aws_route53_record" "api_validation" {
  for_each = {
    for option in aws_acm_certificate.api.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]

  ttl = 300

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn = aws_acm_certificate.api.arn

  validation_record_fqdns = [
    for record in aws_route53_record.api_validation :
    record.fqdn
  ]
}
```

Do not destroy the validation records after validation.

---

# 117. CloudFront certificate provider

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name = "cdn.yourdatascientist.tech"

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

CloudFront can reference only the certificate issued or imported in `us-east-1`. ([AWS Documentation][43])

---

# Part 8 — Hands-on lab

# 118. Lab goal

Build a secure configuration foundation:

```text
KMS customer managed key
        |
        ├── Secrets Manager secret
        └── SecureString parameter
```

Region:

```text
ap-south-1
```

Estimated focused time:

```text
45–60 minutes
```

---

# 119. Create a KMS key

```bash
KEY_ID=$(
  aws kms create-key \
    --description "TodoApp security lab" \
    --key-usage ENCRYPT_DECRYPT \
    --key-spec SYMMETRIC_DEFAULT \
    --region ap-south-1 \
    --query KeyMetadata.KeyId \
    --output text
)

echo "$KEY_ID"
```

Create alias:

```bash
aws kms create-alias \
  --alias-name alias/todoapp-security-lab \
  --target-key-id "$KEY_ID" \
  --region ap-south-1
```

---

# 120. Enable rotation

```bash
aws kms enable-key-rotation \
  --key-id "$KEY_ID" \
  --rotation-period-in-days 180 \
  --region ap-south-1
```

Verify:

```bash
aws kms get-key-rotation-status \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

---

# 121. Test direct KMS encryption

Create a small test file:

```bash
printf '%s' 'TodoApp security lab' > /tmp/plaintext.txt
```

Encrypt:

```bash
aws kms encrypt \
  --key-id alias/todoapp-security-lab \
  --plaintext fileb:///tmp/plaintext.txt \
  --encryption-context \
    Application=TodoApp,Environment=lab \
  --region ap-south-1 \
  --query CiphertextBlob \
  --output text \
  | base64 --decode > /tmp/ciphertext.bin
```

Decrypt with matching context:

```bash
aws kms decrypt \
  --ciphertext-blob fileb:///tmp/ciphertext.bin \
  --encryption-context \
    Application=TodoApp,Environment=lab \
  --region ap-south-1 \
  --query Plaintext \
  --output text \
  | base64 --decode
```

Expected:

```text
TodoApp security lab
```

---

# 122. Test encryption-context failure

Use a different context:

```bash
aws kms decrypt \
  --ciphertext-blob fileb:///tmp/ciphertext.bin \
  --encryption-context \
    Application=DifferentApp,Environment=lab \
  --region ap-south-1
```

Expected:

```text
InvalidCiphertextException
```

This demonstrates that encryption context is cryptographically bound to the ciphertext.

---

# 123. Create a secret

```bash
SECRET_ARN=$(
  aws secretsmanager create-secret \
    --name "lab/todoapp/database" \
    --description "TodoApp security lab secret" \
    --kms-key-id "$KEY_ID" \
    --secret-string '{
      "username": "todoapp_lab",
      "password": "replace-this-lab-value"
    }' \
    --region ap-south-1 \
    --query ARN \
    --output text
)

echo "$SECRET_ARN"
```

Retrieve:

```bash
aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString \
  --output text \
  --region ap-south-1
```

Do not use the sample password in a real environment.

---

# 124. Create parameters

Normal parameter:

```bash
aws ssm put-parameter \
  --name "/lab/todoapp/log-level" \
  --type String \
  --value INFO \
  --region ap-south-1
```

Encrypted parameter:

```bash
aws ssm put-parameter \
  --name "/lab/todoapp/vendor-token" \
  --type SecureString \
  --key-id "$KEY_ID" \
  --value "lab-token-value" \
  --region ap-south-1
```

Retrieve:

```bash
aws ssm get-parameters-by-path \
  --path "/lab/todoapp" \
  --recursive \
  --with-decryption \
  --region ap-south-1
```

---

# 125. Cleanup

Delete parameters:

```bash
aws ssm delete-parameters \
  --names \
    "/lab/todoapp/log-level" \
    "/lab/todoapp/vendor-token" \
  --region ap-south-1
```

Schedule secret deletion:

```bash
aws secretsmanager delete-secret \
  --secret-id "$SECRET_ARN" \
  --recovery-window-in-days 7 \
  --region ap-south-1
```

Schedule KMS key deletion:

```bash
aws kms schedule-key-deletion \
  --key-id "$KEY_ID" \
  --pending-window-in-days 7 \
  --region ap-south-1
```

The key enters `PendingDeletion` and becomes unusable immediately. Cancel deletion if other resources still depend on it.

---

# Part 9 — Troubleshooting

# 126. KMS `AccessDeniedException`

Check:

```text
[ ] Caller IAM policy
[ ] KMS key policy
[ ] Explicit deny
[ ] Service control policy
[ ] Permissions boundary
[ ] VPC endpoint policy
[ ] kms:ViaService condition
[ ] Encryption-context condition
[ ] Correct Region
[ ] Correct key ARN
[ ] Cross-account key authorization
```

Common misconception:

```text
AdministratorAccess IAM policy
=
Guaranteed access to every KMS key
```

A restrictive KMS key policy or explicit deny can still block access.

---

# 127. `InvalidCiphertextException`

Common causes:

* Wrong KMS key for asymmetric operations.
* Wrong encryption context.
* Corrupted ciphertext.
* Base64 encoding error.
* Ciphertext was truncated.
* Data came from another encryption format.
* Multi-Region keys are unrelated.
* Encrypted data key does not match the object.

For symmetric KMS ciphertext, you normally do not need to specify the key ID during decrypt because metadata is included in the ciphertext blob.

---

# 128. Key is disabled

Symptoms:

```text
KMSInvalidStateException
DisabledException
Secrets cannot be retrieved
Encrypted resources fail
```

Check:

```bash
aws kms describe-key \
  --key-id "$KEY_ARN" \
  --region ap-south-1
```

Look for:

```text
KeyState:
Disabled
PendingDeletion
PendingImport
Unavailable
```

Do not simply create a new key. Existing ciphertext still requires the original key.

---

# 129. Key pending deletion

If the waiting period has not ended:

```bash
aws kms cancel-key-deletion \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

Then enable:

```bash
aws kms enable-key \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

After permanent deletion, the key and its ability to decrypt old ciphertext cannot be recovered. ([AWS Documentation][51])

---

# 130. Secret retrieval denied

Check two authorization paths:

```text
Secrets Manager:
secretsmanager:GetSecretValue

KMS:
kms:Decrypt
```

Also check:

* Secret resource policy.
* KMS key policy.
* Cross-account role.
* Secret Region.
* Secret ARN suffix.
* VPC endpoint policy.
* Secret scheduled for deletion.
* Service control policy.

---

# 131. Rotation stuck at `AWSPENDING`

Check:

```text
[ ] Rotation Lambda logs
[ ] Lambda invocation permission
[ ] Lambda VPC networking
[ ] Security-group access to database
[ ] Secrets Manager VPC endpoint
[ ] KMS permission
[ ] Secret JSON fields
[ ] Database user exists
[ ] Database accepts new credential
[ ] testSecret succeeds
[ ] Lambda concurrency
```

Secrets Manager specifically recommends verifying `AWSCURRENT`, `AWSPREVIOUS` and `AWSPENDING` credentials and clearing stale pending rotations only after understanding the failure. ([AWS Documentation][52])

---

# 132. Rotation changed the password but application fails

Possible reasons:

* Application caches old secret indefinitely.
* Connection pool never refreshes.
* Rotation updated wrong database user.
* Secret host points to wrong database.
* Application retrieves a replica secret before propagation.
* Application uses an environment-variable password.
* IAM role cannot retrieve new version.
* Database authentication method changed.

Fix the secret-consumption lifecycle—not only the rotation function.

---

# 133. Cross-account secret access denied

All four permissions may be needed:

```text
1. Secret resource policy.

2. Consumer IAM policy for GetSecretValue.

3. KMS key policy permitting consumer role/account.

4. Consumer IAM policy for kms:Decrypt.
```

Also verify that the secret uses a customer managed KMS key.

---

# 134. Parameter Store `AccessDeniedException`

Check:

* `ssm:GetParameter`.
* `ssm:GetParameters`.
* `ssm:GetParametersByPath`.
* Parameter ARN.
* Path hierarchy.
* Recursive access.
* `kms:Decrypt` for `SecureString`.
* KMS key policy.
* Shared advanced-parameter permissions.
* Region.
* VPC endpoint policy.

Remember:

```text
Permission to retrieve parameter metadata
does not necessarily include KMS decryption.
```

---

# 135. Parameter version missing

Parameter Store retains up to 100 historical versions.

If an old version is no longer present:

* It may have been aged out.
* A label may have been moved.
* The parameter may have been deleted and recreated.
* You may be in the wrong Region.
* The requested version may never have existed.

For release-critical configuration, also preserve changes in Git or another audit source.

---

# 136. ACM certificate remains `PENDING_VALIDATION`

Check:

* CNAME name is exact.
* CNAME value is exact.
* Record is in public DNS.
* DNS provider did not append domain twice.
* CNAME flattening did not change the value.
* Record uses the correct hosted zone.
* Names beginning with `_` are supported.
* Domain is publicly resolvable.
* CAA records permit Amazon issuance.
* Certificate is requested in the correct account and Region.

ACM DNS validation searches public DNS, not a Route 53 private hosted zone. ([AWS Documentation][53])

---

# 137. Certificate not visible in ALB or CloudFront

## ALB

Check the certificate in:

```text
Same Region as ALB
```

## CloudFront

Check:

```text
us-east-1
```

## Cognito custom domain

Check:

```text
us-east-1
```

## API Gateway Regional

Check:

```text
Same Region as API
```

Most “certificate not listed” problems are Region mismatches.

---

# 138. ACM renewal is pending

Check:

* Validation CNAME still exists.
* Certificate is associated with an eligible AWS service.
* Domain still resolves.
* Renewal status.
* AWS Health notifications.
* EventBridge certificate events.
* DNS provider changes.
* CAA records.
* Certificate has not been imported manually.

ACM sends Health and EventBridge notifications when DNS validation cannot be completed during renewal. ([AWS Documentation][54])

---

# 139. Imported certificate expired

ACM does not automatically obtain a new external certificate for an imported certificate.

Recovery:

```text
1. Renew certificate with original CA.

2. Obtain new certificate, chain and private key.

3. Re-import into the existing ACM certificate ARN where supported.

4. Verify attached services.

5. Add expiry alarms.
```

Using the same ARN where possible reduces the need to update all service associations.

---

# 140. KMS throttling

Potential causes:

* One application decrypts on every request.
* S3 workload generates large numbers of KMS operations.
* No Secrets Manager caching.
* Excessive `GenerateDataKey` requests.
* Many workloads share one Regional KMS quota.
* Retry storm.

Mitigations:

* Cache secrets.
* Use envelope encryption.
* Use S3 Bucket Keys where appropriate.
* Request KMS quota increases.
* Distribute workloads by Region/account where architecturally correct.
* Use bounded backoff and jitter.
* Monitor KMS request metrics and CloudTrail usage.

---

# Part 10 — Production checklist

# 141. Production readiness checklist

```text
[ ] KMS, Secrets Manager, Parameter Store and ACM roles are documented
[ ] Customer managed keys have clear ownership
[ ] Key administrators and key users are separated
[ ] Key policies do not depend on individual IAM users
[ ] IAM roles are used instead of permanent access keys
[ ] KMS policies follow least privilege
[ ] Encryption-context conditions are used where appropriate
[ ] kms:ViaService is used where appropriate
[ ] Grant creation is restricted to approved services
[ ] KMS aliases follow a naming standard
[ ] Automatic rotation is enabled where supported
[ ] Rotation period is documented
[ ] Multi-Region keys are used only when ciphertext portability is required
[ ] Imported key material has tested backup and re-import procedures
[ ] External key-store availability risk is accepted explicitly
[ ] Key deletion requires security approval
[ ] KMS keys use prevent_destroy in Terraform
[ ] CloudTrail records KMS activity
[ ] Alerts exist for DisableKey and ScheduleKeyDeletion
[ ] Secrets are not committed to Git
[ ] Secrets do not appear in Terraform plans or state unnecessarily
[ ] Secrets do not appear in CI/CD logs
[ ] Applications cache secrets safely
[ ] Secret caches refresh after rotation
[ ] Automatic rotation is configured
[ ] Rotation Lambda is idempotent
[ ] Rotation Lambda has network access to its target
[ ] Rotation failure alarms exist
[ ] Secret deletion uses a recovery window
[ ] Secret force deletion is restricted
[ ] Cross-account secrets use a customer managed KMS key
[ ] Secret resource policies block public access
[ ] Secrets Manager VPC endpoints exist for private workloads where justified
[ ] Secret replicas exist for Regional DR where required
[ ] Parameter paths follow environment/application hierarchy
[ ] Sensitive parameters use SecureString
[ ] Parameter Store recursion permissions are reviewed
[ ] Advanced parameter costs are understood
[ ] Parameter expiration notifications are monitored
[ ] Parameter retrieval is cached
[ ] Public certificates use DNS validation
[ ] ACM validation CNAMEs remain permanently
[ ] ALB certificates are in the ALB Region
[ ] CloudFront certificates are in us-east-1
[ ] Cognito custom-domain certificates are in us-east-1
[ ] Imported certificate expiry alarms exist
[ ] Certificate renewal status is monitored
[ ] Private CA trust distribution is documented
[ ] Incident recovery for exposed credentials is tested
[ ] Key-loss and certificate-expiry runbooks exist
```

---

# 142. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS KMS:
Managed cryptographic keys

Secrets Manager:
Secrets and credential rotation

Parameter Store:
Configuration and encrypted parameters

ACM:
TLS certificate management
```

## Solutions Architect Associate

Understand:

```text
AWS managed versus customer managed keys
Envelope encryption
KMS key policies
Secrets rotation
SecureString
Parameter hierarchy
ACM DNS validation
Certificate Region requirements
```

## DevOps Engineer Professional

Understand:

```text
KMS grants
Encryption context
kms:ViaService
Automatic and manual rotation
Multi-Region keys
Cross-account KMS and secret access
AWSCURRENT/AWSPENDING/AWSPREVIOUS
Rotation Lambda lifecycle
Secret replication
Parameter policies
ACM renewal monitoring
Terraform state secret exposure
```

---

# 143. Interview questions

## Question 1: What is AWS KMS?

**Answer:**

AWS KMS is a managed service for creating and controlling cryptographic keys used for encryption, decryption, signing, verification and related cryptographic operations.

## Question 2: What is envelope encryption?

**Answer:**

Envelope encryption encrypts application data with a data key and then encrypts that data key with a KMS key.

## Question 3: Why not send a large file directly to KMS?

**Answer:**

KMS direct encryption supports only small plaintext payloads. Large data should be encrypted locally using a generated data key.

## Question 4: What is encryption context?

**Answer:**

It is non-secret authenticated metadata supplied during symmetric KMS cryptographic operations. The same context is required for decryption and can be enforced in policies.

## Question 5: What is the difference between a key policy and IAM policy?

**Answer:**

A key policy is the primary resource policy attached to a KMS key. IAM policies grant permissions to identities, but the key policy must permit direct access or allow the account to delegate key permissions through IAM.

## Question 6: What is a KMS grant?

**Answer:**

A grant is a permission mechanism allowing a principal or AWS service to perform selected cryptographic operations with a KMS key, often for a temporary or resource-specific purpose.

## Question 7: What is the difference between an AWS managed and customer managed key?

**Answer:**

AWS manages the policy and lifecycle of an AWS managed key. You control the policy, rotation, aliases, enablement and deletion of a customer managed key.

## Question 8: Does automatic key rotation change the key ARN?

**Answer:**

No. The key ID, ARN, policy and aliases remain the same; KMS creates a new key-material version internally.

## Question 9: Does key rotation re-encrypt all existing data?

**Answer:**

No. Existing ciphertext remains encrypted under older retained key material and is decrypted transparently.

## Question 10: What is a multi-Region KMS key?

**Answer:**

It is one of a related set of KMS keys in different Regions that share the same key ID and key material, allowing the same ciphertext to be decrypted locally in each Region.

## Question 11: What is Secrets Manager?

**Answer:**

It is a managed service for storing, retrieving and rotating credentials and other secret values.

## Question 12: What do `AWSCURRENT`, `AWSPENDING` and `AWSPREVIOUS` mean?

**Answer:**

`AWSCURRENT` is the active version, `AWSPENDING` is the candidate version during rotation and `AWSPREVIOUS` is the prior active version.

## Question 13: What are the four Lambda rotation steps?

**Answer:**

`createSecret`, `setSecret`, `testSecret` and `finishSecret`.

## Question 14: Why should applications cache secrets?

**Answer:**

Caching reduces API latency, request cost, throttling risk and dependence on Secrets Manager for every application request.

## Question 15: What is the difference between Secrets Manager and Parameter Store?

**Answer:**

Secrets Manager is purpose-built for credentials, rotation and secret lifecycle. Parameter Store is primarily for application configuration and lightweight encrypted values.

## Question 16: What is `SecureString`?

**Answer:**

It is a Parameter Store parameter type whose value is encrypted and decrypted using a symmetric KMS key.

## Question 17: What are advanced Parameter Store parameters?

**Answer:**

They support higher quotas, values up to 8 KB, parameter policies and cross-account sharing, with additional charges.

## Question 18: Why should an ACM validation CNAME remain in DNS?

**Answer:**

ACM uses it for ongoing domain validation and automatic certificate renewal.

## Question 19: Where must a CloudFront ACM certificate exist?

**Answer:**

In `us-east-1`.

## Question 20: What happens if a KMS key is permanently deleted?

**Answer:**

Data that depends on that key can become permanently unrecoverable because a replacement KMS key cannot decrypt ciphertext created under the deleted key.

---

# 144. Never-forget revision

```text
KMS key:
Protects cryptographic operations.

Data key:
Encrypts application data locally.

Envelope encryption:
Data key encrypts data;
KMS key encrypts data key.

Encryption context:
Non-secret authenticated metadata.

Key policy:
Primary KMS authorization policy.

Grant:
Temporary or resource-specific KMS permission.

Alias:
Friendly pointer to a KMS key.

Automatic rotation:
New key material, same KMS key ARN.

Multi-Region key:
Related interoperable keys in different Regions.

Secrets Manager:
Credential and secret lifecycle.

AWSCURRENT:
Active secret version.

AWSPENDING:
Rotation candidate.

AWSPREVIOUS:
Previous active secret version.

Parameter Store:
Application configuration.

SecureString:
KMS-encrypted parameter.

Parameter label:
Friendly pointer to a parameter version.

ACM:
TLS certificate management.

DNS validation:
CNAME proves domain ownership.

Private CA:
Internal certificate authority.

Imported certificate:
You manage renewal.

Exportable certificate:
ACM-issued certificate whose private key can be exported.
```

## One-line memory trick

```text
KMS protects keys.
Secrets Manager protects credentials.
Parameter Store protects configuration.
ACM protects TLS identities.
Never delete a key before proving nothing needs it.
Never rotate a secret without rotating the real credential.
Never delete an ACM validation CNAME.
```

## Lesson 55 outcome

You can now design security where:

```text
Large application data requires encryption
    → Envelope encryption uses a local data key.

One role may decrypt only TodoApp data
    → Encryption context restricts KMS use.

An AWS service needs temporary key access
    → A KMS grant provides bounded permission.

Key material must rotate every 180 days
    → Automatic KMS rotation preserves the same ARN.

The same ciphertext must work in two Regions
    → Related multi-Region KMS keys are used.

Aurora credentials must rotate automatically
    → Secrets Manager updates the secret and database.

Applications should survive secret rotation
    → In-memory caching refreshes after authentication failure.

Configuration needs hierarchical management
    → Parameter Store uses environment/application paths.

A production API needs HTTPS
    → ACM issues a DNS-validated certificate.

CloudFront needs a custom domain
    → The ACM certificate is created in us-east-1.

A key appears unused
    → It is disabled and monitored before deletion.

A credential is exposed
    → Rotate the target credential, update the secret and investigate usage.
```

**Next lesson: Lesson 56 — Amazon CloudWatch, CloudTrail, AWS Config and X-Ray production observability and audit architecture: metrics, logs, traces, dashboards, alarms, anomaly detection, audit trails, configuration compliance, incident investigation and cost control.**

[1]: https://docs.aws.amazon.com/kms/latest/developerguide/overview.html?utm_source=chatgpt.com "AWS Key Management Service"
[2]: https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html?utm_source=chatgpt.com "AWS KMS keys - AWS Key Management Service"
[3]: https://docs.aws.amazon.com/kms/latest/developerguide/kms-alias.html?utm_source=chatgpt.com "Aliases in AWS KMS - AWS Key Management Service"
[4]: https://docs.aws.amazon.com/kms/latest/developerguide/kms-cryptography.html?utm_source=chatgpt.com "AWS KMS cryptography essentials - AWS Key Management Service"
[5]: https://docs.aws.amazon.com/kms/latest/developerguide/symm-asymm-choose-key-spec.html?utm_source=chatgpt.com "Key spec reference - AWS Key Management Service"
[6]: https://docs.aws.amazon.com/kms/latest/developerguide/monitoring-keys-determining-usage.html?utm_source=chatgpt.com "Determine past usage of a KMS key - AWS Key Management Service"
[7]: https://docs.aws.amazon.com/kms/latest/developerguide/encrypt_context.html?utm_source=chatgpt.com "Encryption context - AWS Key Management Service"
[8]: https://docs.aws.amazon.com/kms/latest/developerguide/conditions-kms.html?utm_source=chatgpt.com "AWS KMS condition keys - AWS Key Management Service"
[9]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html?utm_source=chatgpt.com "Key policies in AWS KMS - AWS Key Management Service"
[10]: https://docs.aws.amazon.com/kms/latest/developerguide/grants.html?utm_source=chatgpt.com "Grants in AWS KMS - AWS Key Management Service"
[11]: https://docs.aws.amazon.com/kms/latest/developerguide/grant-best-practices.html?utm_source=chatgpt.com "Best practices for AWS KMS grants - AWS Key Management Service"
[12]: https://docs.aws.amazon.com/kms/latest/developerguide/create-grant-overview.html?utm_source=chatgpt.com "Creating grants - AWS Key Management Service"
[13]: https://docs.aws.amazon.com/kms/latest/developerguide/rotating-keys-enable.html?utm_source=chatgpt.com "Enable automatic key rotation - AWS Key Management Service"
[14]: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html?utm_source=chatgpt.com "Rotate AWS KMS keys - AWS Key Management Service"
[15]: https://docs.aws.amazon.com/kms/latest/developerguide/alias-update.html?utm_source=chatgpt.com "Update aliases - AWS Key Management Service"
[16]: https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html?utm_source=chatgpt.com "Multi-Region keys in AWS KMS"
[17]: https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys-considerations.html?utm_source=chatgpt.com "Special considerations for imported key material - AWS Key Management Service"
[18]: https://docs.aws.amazon.com/kms/latest/developerguide/import-keys-protect.html?utm_source=chatgpt.com "Protecting imported key material - AWS Key Management Service"
[19]: https://docs.aws.amazon.com/kms/latest/developerguide/keystore-external-key-manage.html?utm_source=chatgpt.com "KMS keys in external key stores - AWS Key Management Service"
[20]: https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys-scheduling-key-deletion.html?utm_source=chatgpt.com "Schedule key deletion - AWS Key Management Service"
[21]: https://docs.aws.amazon.com/kms/latest/developerguide/logging-using-cloudtrail.html?utm_source=chatgpt.com "Logging AWS KMS API calls with AWS CloudTrail - AWS Key Management Service"
[22]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html?utm_source=chatgpt.com "Create an AWS Secrets Manager secret - AWS Secrets Manager"
[23]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/whats-in-a-secret.html?utm_source=chatgpt.com "What's in a Secrets Manager secret? - AWS Secrets Manager"
[24]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html?utm_source=chatgpt.com "AWS Secrets Manager best practices - AWS Secrets Manager"
[25]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html?utm_source=chatgpt.com "Rotate AWS Secrets Manager secrets"
[26]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda-functions.html?utm_source=chatgpt.com "Lambda rotation functions - AWS Secrets Manager"
[27]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_schedule.html?utm_source=chatgpt.com "Rotation schedules - AWS Secrets Manager"
[28]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html?utm_source=chatgpt.com "Replicate AWS Secrets Manager secrets across Regions - AWS Secrets Manager"
[29]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html?utm_source=chatgpt.com "Access AWS Secrets Manager secrets from a different account - AWS Secrets Manager"
[30]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_resource-policies.html?utm_source=chatgpt.com "Resource-based policies - AWS Secrets Manager"
[31]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html?utm_source=chatgpt.com "Using an AWS Secrets Manager VPC endpoint - AWS Secrets Manager"
[32]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/manage_delete-secret.html?utm_source=chatgpt.com "Delete an AWS Secrets Manager secret - AWS Secrets Manager"
[33]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html?utm_source=chatgpt.com "AWS Systems Manager Parameter Store - AWS Systems Manager"
[34]: https://docs.aws.amazon.com/systems-manager/latest/userguide/secure-string-parameter-kms-encryption.html?utm_source=chatgpt.com "AWS KMS encryption for AWS Systems Manager Parameter Store SecureString parameters - AWS Systems Manager"
[35]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-hierarchies.html?utm_source=chatgpt.com "Working with parameter hierarchies in Parameter Store - AWS Systems Manager"
[36]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-parameter-name-constraints.html?utm_source=chatgpt.com "Understanding parameter name requirements and constraints - AWS Systems Manager"
[37]: https://docs.aws.amazon.com/systems-manager/latest/userguide/ps-default-tier.html?utm_source=chatgpt.com "Specifying a default parameter tier for your AWS account ..."
[38]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-versions.html?utm_source=chatgpt.com "Working with parameter versions in Parameter Store - AWS Systems Manager"
[39]: https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-labels.html?utm_source=chatgpt.com "Working with parameter labels in Parameter Store - AWS Systems Manager"
[40]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-policies.html?utm_source=chatgpt.com "Assigning parameter policies in Parameter Store - AWS Systems Manager"
[41]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-throughput.html?utm_source=chatgpt.com "Managing Parameter Store throughput - AWS Documentation"
[42]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-shared-parameters.html?utm_source=chatgpt.com "Working with shared parameters in Parameter Store"
[43]: https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html?utm_source=chatgpt.com "What is AWS Certificate Manager?"
[44]: https://docs.aws.amazon.com/acm/latest/userguide/gs.html?utm_source=chatgpt.com "Getting started with AWS Certificate Manager certificates - AWS Certificate Manager"
[45]: https://docs.aws.amazon.com/acm/latest/userguide/import-certificate.html?utm_source=chatgpt.com "Import certificates into AWS Certificate Manager"
[46]: https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html?utm_source=chatgpt.com "AWS Certificate Manager DNS validation - AWS Certificate Manager"
[47]: https://docs.aws.amazon.com/acm/latest/userguide/acm-certificate-characteristics.html?utm_source=chatgpt.com "AWS Certificate Manager public certificate characteristics and limitations - AWS Certificate Manager"
[48]: https://docs.aws.amazon.com/acm/latest/userguide/check-certificate-renewal-status.html?utm_source=chatgpt.com "Check a certificate's renewal status - AWS Certificate Manager"
[49]: https://docs.aws.amazon.com/acm/latest/userguide/acm-exportable-certificates.html?utm_source=chatgpt.com "AWS Certificate Manager exportable public certificates - AWS Certificate Manager"
[50]: https://docs.aws.amazon.com/acm/latest/userguide/renew-private-cert.html?utm_source=chatgpt.com "Private certificate renewal in AWS Certificate Manager - AWS Certificate Manager"
[51]: https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html?utm_source=chatgpt.com "Delete an AWS KMS key - AWS Key Management Service"
[52]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/troubleshoot_rotation.html?utm_source=chatgpt.com "Troubleshoot AWS Secrets Manager rotation"
[53]: https://docs.aws.amazon.com/acm/latest/userguide/troubleshooting-DNS-validation.html?utm_source=chatgpt.com "Troubleshoot DNS validation problems - AWS Certificate Manager"
[54]: https://docs.aws.amazon.com/acm/latest/userguide/dns-renewal-validation.html?utm_source=chatgpt.com "Renewal for domains validated by DNS - AWS Certificate Manager"
