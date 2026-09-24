# AWS Masterclass — Phase 3

# Lesson 32: AWS KMS, Envelope Encryption, Secrets Manager and Parameter Store

## 1. Lesson objectives

In this lesson, you will learn how to:

* Understand encryption at rest and in transit.
* Distinguish plaintext, ciphertext and cryptographic keys.
* Understand AWS KMS keys and key material.
* Use symmetric, asymmetric and HMAC KMS keys.
* Understand envelope encryption and data keys.
* Write secure KMS key policies.
* Distinguish key administrators from key users.
* Use IAM policies, key policies and KMS grants together.
* Use encryption context as authenticated data and an authorization control.
* Rotate KMS keys safely.
* Use aliases for controlled key replacement.
* Design multi-Region KMS architectures.
* Understand imported key material, CloudHSM key stores and external key stores.
* Protect secrets using AWS Secrets Manager.
* Configure automatic secret rotation.
* Replicate secrets across Regions.
* Use Systems Manager Parameter Store for application configuration.
* Choose between Secrets Manager and Parameter Store.
* Troubleshoot `AccessDenied`, `InvalidCiphertextException` and key-state failures.
* Build the architecture using Terraform and AWS CLI.

---

# 2. Production security architecture

A production architecture may use all three services together:

```text id="kms-architecture"
                         Application workload
                         EC2 / ECS / Lambda
                                  |
                       IAM workload role
                                  |
            ┌─────────────────────┼─────────────────────┐
            |                     |                     |
            v                     v                     v
     Secrets Manager       Parameter Store        Encrypted AWS data
            |                     |                     |
       DB password          App configuration      S3 / EBS / RDS
       API tokens           Feature settings       DynamoDB / Logs
            |                     |                     |
            └─────────────────────┼─────────────────────┘
                                  |
                                  v
                              AWS KMS
                                  |
                         Customer managed key
                                  |
                    Key policy + IAM + grants
```

The responsibilities are different:

```text id="service-responsibility"
AWS KMS:
Controls cryptographic keys and cryptographic operations.

Secrets Manager:
Stores, retrieves, versions and rotates secrets.

Parameter Store:
Stores hierarchical configuration and optional encrypted values.

IAM:
Controls which principals may call each service.
```

AWS KMS is a managed service for creating and controlling keys used to encrypt, decrypt, sign and verify data. KMS keys created in the standard AWS KMS service are protected in AWS-managed hardware security modules and do not leave KMS unencrypted. ([AWS Documentation][1])

---

# 3. Encryption mental model

Suppose your application has this plaintext:

```text id="plaintext-example"
Database password:
ProductionPassword123
```

After encryption:

```text id="ciphertext-example"
AQICAHh7...encrypted-binary-content...
```

The original readable value is:

```text id="plaintext-definition"
Plaintext
```

The protected output is:

```text id="ciphertext-definition"
Ciphertext
```

A cryptographic key controls the transformation:

```text id="encryption-process"
Plaintext
    |
    | Encrypt using key
    v
Ciphertext
```

Decryption reverses it:

```text id="decryption-process"
Ciphertext
    |
    | Decrypt using authorised key
    v
Plaintext
```

## Never-forget rule

```text id="encryption-access"
Encrypting data does not automatically make it secure.

Security depends on:
- Who can use the key
- Who can change the key policy
- Who can access the encrypted data
- How applications handle decrypted plaintext
```

---

# 4. Encryption at rest versus in transit

## Encryption at rest

Protects data stored in:

```text id="at-rest"
S3 objects
EBS volumes
RDS storage
DynamoDB tables
Snapshots
Backups
Logs
Secrets
```

Example:

```text id="s3-at-rest"
Application
    |
    v
S3 object encrypted with a KMS key
```

## Encryption in transit

Protects data moving between systems:

```text id="in-transit"
Browser → CloudFront
CloudFront → ALB
Application → RDS
Application → AWS APIs
```

This normally uses TLS.

## Important distinction

```text id="both-encryption"
TLS protects data while moving.

KMS-backed encryption protects data while stored.

Most production systems need both.
```

---

# 5. What is a KMS key?

A KMS key is a logical AWS resource representing cryptographic key material and its associated configuration.

It includes:

```text id="kms-key-parts"
Key ID
Key ARN
Key material
Key specification
Key usage
Key state
Key policy
Creation date
Rotation configuration
Tags
Regional location
Origin
```

The actual cryptographic material is not the same thing as the KMS key resource.

## Mental model

```text id="key-resource"
KMS key:
Logical AWS resource and access-control object

Key material:
Cryptographic secret used by the algorithms
```

---

# 6. KMS key ownership categories

You will encounter three main ownership models.

## AWS owned keys

Created, owned and managed entirely by an AWS service.

You normally cannot:

* View them.
* Manage their policy.
* Enable or disable them.
* Configure their rotation.

They are used transparently by the AWS service.

## AWS managed keys

Created in your account by an AWS service.

Aliases normally look like:

```text id="aws-managed-alias"
alias/aws/s3
alias/aws/ebs
alias/aws/rds
alias/aws/secretsmanager
alias/aws/ssm
```

AWS manages their policy and rotation.

## Customer managed keys

Created and controlled by your organisation.

You can manage:

```text id="customer-key-control"
Key policy
IAM access
Aliases
Tags
Enable and disable state
Rotation
Deletion
Grants
Multi-Region configuration
Imported key material where selected
```

Customer managed keys provide greater control but also create more operational responsibility.

---

# 7. When should you use a customer managed key?

Use a customer managed key when you need:

* A custom key policy.
* Cross-account access.
* Independent key administration.
* Audit separation.
* Explicit disable or deletion control.
* Custom rotation requirements.
* Encryption-context restrictions.
* Multi-Region interoperable keys.
* Imported or externally controlled key material.
* Separate keys for data classifications or environments.

An AWS managed key may be sufficient when:

* Default encryption is adequate.
* No cross-account key access is needed.
* You do not require a custom policy.
* Simplicity matters more than detailed control.

---

# 8. Symmetric encryption KMS keys

A symmetric encryption KMS key uses the same cryptographic key material for encryption and decryption.

```text id="symmetric"
Same secret key:
Encrypt
Decrypt
```

This is the most common KMS key type for AWS service integrations.

Use cases:

```text id="symmetric-uses"
S3 server-side encryption
EBS volume encryption
RDS encryption
Secrets Manager
Parameter Store SecureString
DynamoDB
CloudWatch Logs
Application envelope encryption
```

Symmetric KMS ciphertext includes metadata that allows KMS to identify the key needed for decryption.

---

# 9. Asymmetric KMS keys

An asymmetric key consists of a mathematically related pair:

```text id="asymmetric-pair"
Public key
Private key
```

The public key can be shared.

The private key remains protected inside KMS.

Depending on the key configuration, it can support:

```text id="asymmetric-uses"
Encrypt and decrypt
Sign and verify
Key agreement
```

AWS KMS allows downloading the public key, but the private key is not exported from a standard KMS asymmetric key. ([AWS Documentation][2])

## Example: signing

```text id="signing"
Application hash
      |
      | kms:Sign using private key
      v
Digital signature

Other party
      |
      | Verify using public key
      v
Valid or invalid
```

---

# 10. HMAC KMS keys

HMAC stands for:

```text id="hmac"
Hash-based Message Authentication Code
```

An HMAC key can be used to:

```text id="hmac-actions"
Generate a MAC
Verify a MAC
```

It proves message integrity and authenticity when both parties share trust in the HMAC key.

HMAC is not encryption:

```text id="hmac-not-encryption"
HMAC does not hide the message.

It proves that:
- The message was not modified
- An authorised party generated the MAC
```

---

# 11. Why KMS does not encrypt every large object directly

Directly encrypting a multi-gigabyte file through the KMS `Encrypt` API would be inefficient and inappropriate.

Instead, AWS commonly uses:

```text id="envelope-title"
Envelope encryption
```

Envelope encryption uses two key levels:

```text id="envelope-levels"
KMS key:
Protects data keys

Data key:
Encrypts the actual application data
```

AWS services such as S3 and RDS use envelope-encryption patterns when integrating with KMS. ([AWS Documentation][3])

---

# 12. Envelope encryption

The encryption flow is:

```text id="envelope-encrypt"
1. Request a data key from KMS.

2. KMS returns:
   - Plaintext data key
   - Encrypted data key

3. Application encrypts data using plaintext data key.

4. Application removes plaintext data key from memory.

5. Application stores:
   - Encrypted data
   - Encrypted data key
```

Architecture:

```text id="envelope-diagram"
                    AWS KMS key
                         |
                         | Encrypts
                         v
                  Encrypted data key
                         |
                         | Stored beside
                         v
Plaintext data → Data key → Encrypted application data
```

The `GenerateDataKey` API returns a plaintext copy of the data key and a copy encrypted under the specified symmetric KMS key. ([AWS Documentation][4])

---

# 13. Envelope decryption

To decrypt:

```text id="envelope-decrypt"
1. Read encrypted data.
2. Read encrypted data key.
3. Send encrypted data key to KMS Decrypt.
4. KMS returns plaintext data key.
5. Use plaintext data key to decrypt data.
6. Remove plaintext data key from memory.
```

Diagram:

```text id="decrypt-diagram"
Encrypted data key
        |
        | kms:Decrypt
        v
Plaintext data key
        |
        | Decrypts
        v
Encrypted application data
        |
        v
Plaintext data
```

## Why this scales

KMS normally protects small data keys, not every byte of a large dataset.

Your application or AWS service performs bulk encryption locally using the data key.

---

# 14. Never store the plaintext data key

After using a plaintext data key:

```text id="plaintext-key-handling"
Do not:
- Write it to disk
- Log it
- Store it in a database
- Put it in environment variables
- Send it to another untrusted service
```

Keep it in memory only for the shortest practical duration and overwrite or release it after use.

The encrypted data key can be stored safely beside the encrypted data because it cannot be decrypted without authorised KMS access.

---

# 15. `GenerateDataKeyWithoutPlaintext`

Some workflows do not need the plaintext key immediately.

Use:

```text id="without-plaintext"
GenerateDataKeyWithoutPlaintext
```

This returns only the encrypted data-key material.

It can be useful when:

* Preparing encrypted resources.
* Separating key-generation and data-encryption stages.
* Avoiding plaintext key exposure in one component.
* Another component will decrypt and use the key later.

---

# 16. KMS key policy

A KMS key policy is a resource-based policy attached directly to a KMS key.

Every KMS key has exactly one key policy, and the key policy is the primary access-control mechanism for the key. IAM policies and grants can supplement it, but a usable KMS authorization design must account for the key policy. ([AWS Documentation][5])

## Critical difference from many AWS services

With many services, an IAM administrator can simply attach an IAM policy that grants access.

With KMS:

```text id="kms-iam-enablement"
The key policy must permit IAM-based delegation.

Without that:
An IAM Allow may have no effect.
```

The default key policy normally contains a statement that enables the account to delegate KMS access through IAM policies. ([AWS Documentation][5])

---

# 17. Default account-enablement statement

A common foundational key-policy statement is:

```json id="enable-account-policy"
{
  "Sid": "EnableIAMUserPermissions",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:root"
  },
  "Action": "kms:*",
  "Resource": "*"
}
```

This does not mean that every identity automatically receives full KMS access.

It means the AWS account may delegate access through IAM policies.

The account principal represented by `arn:aws:iam::<account-id>:root` enables account-level delegation and helps prevent the key from becoming unmanageable. ([AWS Documentation][6])

---

# 18. Key administrators versus key users

Separate these responsibilities.

## Key administrators

May perform management operations such as:

```text id="key-admin-actions"
View key configuration
Change key policy
Enable or disable key
Manage rotation
Manage aliases
Manage grants
Schedule deletion
Tag the key
```

They should not automatically receive permission to decrypt application data.

## Key users

May perform cryptographic operations such as:

```text id="key-user-actions"
Encrypt
Decrypt
GenerateDataKey
ReEncrypt
Sign
Verify
GenerateMac
VerifyMac
```

The exact actions depend on the KMS key type.

AWS’s console-generated default policy separates key-administration statements from key-usage statements, although administrators who can modify the key policy can potentially grant themselves additional permissions. ([AWS Documentation][6])

---

# 19. Separation-of-duties architecture

```text id="separation"
Security administrator:
Can manage the KMS key
Cannot read application secrets

Application role:
Can decrypt selected application data
Cannot change the key policy

Auditor:
Can inspect configuration and CloudTrail
Cannot administer or decrypt

Incident role:
Can disable the key under controlled approval
```

## Important warning

Someone with:

```text id="key-admin-risk"
kms:PutKeyPolicy
```

can potentially modify the key policy and grant themselves usage access.

Therefore, key-administrator permissions are highly privileged.

---

# 20. Key-user policy example

Key policy:

```json id="key-user-policy"
{
  "Sid": "AllowApplicationKeyUse",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/ProductionApplicationRole"
  },
  "Action": [
    "kms:Decrypt",
    "kms:Encrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

In a key policy, the resource is normally:

```json id="kms-resource-star"
"Resource": "*"
```

because the policy is already attached to one specific KMS key.

---

# 21. IAM policy for KMS use

You may also give the application an IAM policy:

```json id="iam-kms-policy"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "UseProductionApplicationKey",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:ap-south-1:123456789012:key/11111111-2222-3333-4444-555555555555"
    }
  ]
}
```

Effective access may require both:

```text id="kms-policy-combination"
Key policy allows or enables the principal
+
IAM policy allows the requested operation
+
No explicit denial applies
```

---

# 22. Cross-account KMS access

Cross-account KMS access normally requires permission on both sides.

```text id="cross-account-kms"
Account A:
Owns KMS key

Account B:
Application role needs decrypt access
```

## Account A key policy

```json id="cross-account-key-policy"
{
  "Sid": "AllowExternalApplicationRole",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::222222222222:role/ApplicationRole"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

## Account B IAM policy

```json id="cross-account-iam"
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:ap-south-1:111111111111:key/KEY-ID"
}
```

Cross-account secret access also requires consideration of the secret resource policy, the caller’s IAM policy and the KMS key policy. ([AWS Documentation][7])

---

# 23. KMS grants

A KMS grant is another mechanism that allows a principal or AWS service to use a KMS key.

A grant can permit operations such as:

```text id="grant-operations"
Encrypt
Decrypt
GenerateDataKey
ReEncrypt
DescribeKey
CreateGrant
RetireGrant
```

Grants are often used by integrated AWS services to receive narrowly scoped, temporary or resource-associated key access without repeatedly editing the key policy. ([AWS Documentation][8])

## Examples

AWS services may use grants for:

* Encrypted EBS volumes.
* Auto Scaling instances.
* RDS resources.
* Redshift clusters.
* AWS Backup.
* Other persistent encrypted resources.

---

# 24. Grant policy condition

A common key-policy statement is:

```json id="grant-policy"
{
  "Sid": "AllowAWSServiceGrants",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789012:role/InfrastructureDeploymentRole"
  },
  "Action": [
    "kms:CreateGrant",
    "kms:ListGrants",
    "kms:RevokeGrant"
  ],
  "Resource": "*",
  "Condition": {
    "Bool": {
      "kms:GrantIsForAWSResource": "true"
    }
  }
}
```

This helps restrict grant creation to grants created for integrated AWS resources. AWS includes a similar statement in console-generated key-user policies for persistent AWS service resources. ([AWS Documentation][6])

---

# 25. Grant eventual consistency

KMS grants are eventually consistent.

After creating a grant, there can be a short delay before all KMS systems recognise it.

Symptoms:

```text id="grant-delay"
CreateGrant succeeds
Immediately use encrypted resource
AccessDeniedException occurs
Retry later succeeds
```

Use a grant token when the grant’s permissions must be used immediately. AWS documents that grant changes usually propagate quickly but can occasionally take several minutes. ([AWS Documentation][8])

---

# 26. Encryption context

Encryption context is an optional set of non-secret key-value pairs included in symmetric KMS cryptographic operations.

Example:

```json id="encryption-context"
{
  "Application": "TodoApp",
  "Environment": "Production",
  "TenantId": "tenant-104"
}
```

KMS uses encryption context as additional authenticated data.

The exact same context must normally be supplied when decrypting.

Encryption context improves:

* Integrity.
* Auditability.
* Authorisation precision.
* Separation between applications or tenants.

Encryption context is not encrypted and can appear in CloudTrail, so it must not contain secrets. ([AWS Documentation][9])

---

# 27. Encryption-context flow

Encrypt:

```text id="context-encrypt"
Plaintext
+
Encryption context:
Application=TodoApp
Environment=Production
        |
        v
Ciphertext
```

Decrypt:

```text id="context-decrypt"
Ciphertext
+
Application=TodoApp
Environment=Production
        |
        v
Plaintext
```

Incorrect context:

```text id="context-fail"
Ciphertext
+
Application=OtherApp
        |
        v
InvalidCiphertextException
```

---

# 28. Restrict decrypt using encryption context

IAM or key policy:

```json id="context-policy"
{
  "Effect": "Allow",
  "Action": "kms:Decrypt",
  "Resource": "arn:aws:kms:ap-south-1:123456789012:key/KEY-ID",
  "Condition": {
    "StringEquals": {
      "kms:EncryptionContext:Application": "TodoApp",
      "kms:EncryptionContext:Environment": "Production"
    }
  }
}
```

This means the role cannot use the key for arbitrary ciphertext.

It may decrypt only ciphertext requests containing the approved context.

AWS KMS provides `kms:EncryptionContext:<key>` and related condition keys for controlling symmetric-key operations. ([AWS Documentation][9])

---

# 29. Encryption-context security benefit

Without context restriction:

```text id="without-context"
Application role can call kms:Decrypt
on any ciphertext encrypted by that KMS key.
```

With context restriction:

```text id="with-context"
Application role may decrypt only data
labelled for its application and environment.
```

This helps prevent a role from using the same key to decrypt data belonging to another workload.

---

# 30. KMS aliases

An alias is a friendly name pointing to a KMS key.

Example:

```text id="alias-example"
alias/production/todoapp
```

Instead of using:

```text id="key-id-example"
11111111-2222-3333-4444-555555555555
```

applications can refer to:

```text id="alias-use"
alias/production/todoapp
```

Aliases are Regional, must be unique within an account and Region, and can be updated to point to another KMS key. Alias names are not secret and may appear in logs. ([AWS Documentation][10])

---

# 31. Alias-based manual key rotation

```text id="alias-rotation"
Before:
alias/production/todoapp → Key A

Create and validate:
Key B

After:
alias/production/todoapp → Key B
```

New encryption operations use Key B.

Existing ciphertext encrypted under Key A still requires Key A for decryption.

Therefore:

```text id="manual-rotation-rule"
Do not delete Key A
until every old ciphertext has been re-encrypted
or is no longer required.
```

---

# 32. Alias limitations

An alias is a separate KMS resource.

Important:

```text id="alias-limitations"
Alias policy ARN is not the same as the KMS key ARN.

An alias name cannot be used as the Resource
in an IAM policy to identify the underlying KMS key.
```

To authorise based on aliases, use KMS condition keys such as:

```text id="alias-condition-keys"
kms:RequestAlias
kms:ResourceAliases
```

AWS explicitly notes that alias identifiers cannot replace the key ARN in IAM policy resources. ([AWS Documentation][10])

---

# 33. Key rotation

KMS rotation changes the cryptographic material associated with a logical KMS key while preserving the same:

```text id="rotation-preserves"
Key ID
Key ARN
Alias
Key policy
Permissions
Application integration
```

When decrypting old ciphertext, KMS automatically selects the historical key-material version that originally encrypted it. Applications do not need to specify the key-material version. ([AWS Documentation][11])

---

# 34. Automatic rotation

Automatic rotation is supported for eligible symmetric customer managed keys whose key material was generated by AWS KMS.

The default automatic rotation period is 365 days, and KMS now allows a custom rotation period for eligible keys. AWS managed keys are rotated by AWS every year. ([AWS Documentation][11])

Terraform:

```hcl id="rotation-terraform"
resource "aws_kms_key" "application" {
  description         = "Production TodoApp encryption key"
  enable_key_rotation = true
}
```

---

# 35. On-demand rotation

On-demand rotation lets an administrator immediately rotate eligible key material without changing the automatic-rotation schedule.

It is useful for:

* Testing rotation procedures.
* Unplanned security rotation.
* Compliance demonstrations.
* Responding to a possible key-material concern.

On-demand rotation is supported for eligible symmetric KMS keys with AWS-generated material and also for eligible symmetric keys with imported material, subject to the imported-key workflow. ([AWS Documentation][11])

---

# 36. Manual rotation

Manual rotation means:

```text id="manual-rotation"
1. Create a new KMS key.
2. Configure its policy.
3. Test it.
4. Change aliases or application configuration.
5. Use the new key for new encryption.
6. Retain the old key for old ciphertext.
7. Re-encrypt data if required.
```

Use manual rotation for key types that do not support automatic rotation, such as:

* Asymmetric KMS keys.
* HMAC KMS keys.
* Keys in custom key stores.

AWS recommends manual replacement when automatic or on-demand rotation is not supported. ([AWS Documentation][11])

---

# 37. Rotation does not re-encrypt your data

This is one of the most important KMS concepts.

```text id="rotation-not-reencrypt"
KMS key rotation:
Changes the backing key material used for future operations.

It does not:
- Re-encrypt S3 objects
- Re-encrypt EBS volumes
- Replace data keys
- Change ciphertext stored by your applications
```

Old ciphertext remains decryptable through historical KMS key material.

KMS rotation also does not fix the compromise of a plaintext data key already exposed outside KMS. ([AWS Documentation][11])

---

# 38. Disabling a KMS key

When a KMS key is disabled:

```text id="disabled-key"
New cryptographic operations fail.

AWS resources depending on the key may become unusable.
```

Possible impact:

* Encrypted EBS volume cannot attach.
* Application cannot decrypt secret.
* RDS operations may fail.
* S3 object cannot be read.
* Log delivery can fail.
* Backups may become unusable.
* Auto Scaling may fail to launch encrypted instances.

## Safe emergency use

Disabling can be useful during a security incident, but it should be treated as a high-impact containment action.

Before disabling:

```text id="disable-checks"
Identify dependent resources
Confirm business impact
Obtain incident approval
Prepare rollback
Monitor CloudTrail
```

---

# 39. Scheduling key deletion

KMS keys are not deleted immediately.

AWS KMS requires a deletion waiting period between:

```text id="deletion-period"
7 and 30 days
```

The default is 30 days. During that period, the key is in a pending-deletion state and can be recovered by cancelling deletion. ([AWS Documentation][12])

## Critical warning

```text id="key-deletion-warning"
Deleting a KMS key can permanently destroy access
to every ciphertext protected by that key.
```

This can include:

* Snapshots.
* Archived S3 objects.
* Backups.
* Secrets.
* EBS volumes.
* Log archives.
* Cross-account encrypted resources.

---

# 40. Safe deletion process

```text id="safe-delete"
1. Disable the key.
2. Monitor failures and CloudTrail.
3. Inventory encrypted resources.
4. Confirm backups do not depend on the key.
5. Re-encrypt required data under a replacement key.
6. Wait through an observation period.
7. Schedule deletion using the maximum practical waiting period.
8. Monitor pending deletion.
9. Cancel if unexpected dependency appears.
```

Do not schedule deletion merely because a key appears unused in one console view.

---

# 41. Multi-Region KMS keys

Multi-Region keys are related KMS keys in different Regions with the same:

```text id="mrk-shared"
Key ID
Key material
Key specification
Key usage
Rotation material
```

This allows data encrypted in one Region to be decrypted using a related key in another Region without making a cross-Region KMS request or re-encrypting the ciphertext. ([AWS Documentation][13])

Architecture:

```text id="mrk-architecture"
ap-south-1
Multi-Region primary key
        |
        | Replication
        v
ap-southeast-1
Multi-Region replica key
```

---

# 42. Multi-Region primary and replica

Each related key set has:

```text id="mrk-primary"
Exactly one primary key
```

and may have:

```text id="mrk-replicas"
Replica key in other Regions
```

Only the primary can:

* Be replicated.
* Control shared rotation properties.
* Initiate automatic or on-demand rotation.

However, both primary and replica keys can independently encrypt and decrypt data.

Each replica has its own:

```text id="replica-independent"
Key policy
Aliases
Tags
Grants
Enabled or disabled state
```

Multi-Region replicas are fully functional Regional keys, not network pointers to the primary. ([AWS Documentation][13])

---

# 43. Multi-Region disaster-recovery example

```text id="mrk-dr"
Primary application:
ap-south-1

Secondary application:
ap-southeast-1

Encrypted application package:
Created in Mumbai

Regional disaster:
Singapore application reads package
using related replica KMS key
```

Benefits:

* No dependency on the failed Region’s KMS endpoint.
* No cross-Region KMS API call.
* Same ciphertext can be decrypted.
* Faster Regional recovery.

---

# 44. Multi-Region key warning

A multi-Region key is not automatically better.

It changes the security boundary:

```text id="mrk-risk"
Single-Region key:
Cryptographic use constrained to one Region.

Multi-Region key:
Equivalent key material exists in multiple Regions.
```

Use it only when:

* Cross-Region decryption is an actual requirement.
* Disaster-recovery design requires ciphertext portability.
* Client-side encrypted data moves between Regions.
* Global applications need interoperable key material.

AWS recommends creating multi-Region keys only when you intend to replicate and use them for a genuine multi-Region scenario. ([AWS Documentation][13])

---

# 45. Single-Region key cannot be converted

You cannot convert:

```text id="key-conversion"
Single-Region key → Multi-Region key

or

Multi-Region key → Single-Region key
```

To migrate, create a new key design and re-encrypt or recreate the protected cryptographic material. ([AWS Documentation][13])

---

# 46. Imported key material

By default, AWS KMS generates the key material.

With imported key material:

```text id="byok"
Your organisation generates key material
        ↓
Wraps it using KMS-provided import parameters
        ↓
Imports it into a KMS key
```

This is commonly called:

```text id="byok-title"
Bring Your Own Key — BYOK
```

You create a KMS key with origin:

```text id="external-origin"
EXTERNAL
```

and then import your key material. The origin cannot later be changed to AWS-generated material. ([AWS Documentation][14])

---

# 47. Imported-key responsibilities

You become responsible for:

* Secure original key generation.
* Key backup.
* Retaining recoverable copies.
* Import procedures.
* Expiration configuration.
* Reimporting expired or deleted material.
* Multi-Region imported-material consistency.
* Incident recovery.

AWS KMS cannot restore imported key material on your behalf. You must retain a protected external copy. ([AWS Documentation][15])

## Critical risk

```text id="imported-risk"
Imported material expires or is deleted
        ↓
KMS key becomes unusable
        ↓
Encrypted data may become permanently inaccessible
unless you can reimport the exact required material.
```

---

# 48. AWS CloudHSM custom key store

A CloudHSM custom key store allows KMS to use key material inside a CloudHSM cluster you control.

Use it when requirements include:

* Dedicated single-tenant HSMs.
* Direct HSM ownership and administration.
* Specific compliance controls.
* Greater control of HSM users and key material.
* KMS API integration combined with CloudHSM-backed keys.

This creates greater operational responsibility for:

* HSM cluster availability.
* Backup.
* Networking.
* HSM administration.
* Capacity.
* Key-store connectivity.

---

# 49. External key store

An external key store lets AWS KMS use key material maintained in an external key manager outside AWS.

This is also described as:

```text id="hyok"
Hold Your Own Keys — HYOK
```

Architecture:

```text id="xks-architecture"
AWS service
    |
    v
AWS KMS
    |
    v
Customer-managed XKS proxy
    |
    v
External key manager / HSM outside AWS
```

External key stores are designed for specialised regulatory situations where keys must remain under external customer control. AWS warns that, for most workloads, the added availability, latency and operational risks may outweigh the security benefit. ([AWS Documentation][16])

---

# 50. External-key-store availability risk

With a standard KMS key, AWS manages key availability.

With an external key store, you are responsible for:

```text id="xks-responsibility"
External key-manager availability
Network connectivity
Proxy availability
Latency
Key durability
Key backups
Vendor operations
Monitoring
```

If KMS cannot reach the external key manager:

```text id="xks-outage"
Decrypt operations fail
        ↓
Dependent AWS resources may fail
```

If the external key is permanently lost or removed, ciphertext can become unrecoverable. ([AWS Documentation][16])

---

# 51. External-key-store double encryption

KMS external key stores use double encryption:

```text id="double-encryption"
Plaintext/data key
    |
    | Encrypted by AWS KMS key material
    v
KMS ciphertext
    |
    | Encrypted again by external key
    v
Double-encrypted ciphertext
```

Neither AWS KMS alone nor the external-key owner alone can decrypt the final ciphertext without the other side’s cryptographic contribution. ([AWS Documentation][16])

---

# 52. Secrets versus encryption keys

Do not confuse application secrets with KMS keys.

## Application secret

Examples:

```text id="application-secrets"
Database password
API token
OAuth client secret
SSH private key
Webhook signing secret
Third-party service credential
```

## KMS key

Used to cryptographically protect data, including application secrets.

Architecture:

```text id="secret-kms"
Database password
        |
        | Encrypted by Secrets Manager using KMS
        v
Encrypted secret value
```

The application receives permission to retrieve the secret, and Secrets Manager uses KMS to decrypt it.

---

# 53. AWS Secrets Manager

Secrets Manager provides:

* Encrypted secret storage.
* Secret versions.
* Version staging labels.
* IAM access control.
* Resource policies.
* KMS integration.
* Automatic rotation.
* Managed database-secret integration.
* Cross-Region replication.
* CloudTrail audit events.
* SDK and CLI retrieval.

Secrets Manager encrypts secret values using KMS and requests data keys when creating, updating or replicating secret values. ([AWS Documentation][17])

---

# 54. Secret structure

A database secret may be JSON:

```json id="secret-json"
{
  "username": "todoapp_user",
  "password": "generated-password",
  "engine": "postgres",
  "host": "production-db.example.ap-south-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "todoapp"
}
```

Other secrets may contain:

```json id="api-secret"
{
  "apiKey": "value",
  "apiSecret": "value",
  "endpoint": "https://provider.example.com"
}
```

Do not place unrelated secrets in one huge secret merely to reduce resource count.

Separate them according to:

* Owner.
* Rotation schedule.
* Access policy.
* Application.
* Environment.
* Blast radius.

---

# 55. Secret versions

Secrets Manager maintains versions.

Common staging labels:

```text id="secret-stages"
AWSCURRENT
AWSPENDING
AWSPREVIOUS
```

## `AWSCURRENT`

The version applications normally retrieve.

## `AWSPENDING`

The new version being prepared during rotation.

## `AWSPREVIOUS`

The prior version after successful rotation.

This version model supports safe rotation and rollback.

---

# 56. Retrieve a secret

CLI:

```bash id="get-secret"
aws secretsmanager get-secret-value \
  --secret-id production/todoapp/database \
  --region ap-south-1
```

Retrieve only the secret string:

```bash id="get-secret-query"
aws secretsmanager get-secret-value \
  --secret-id production/todoapp/database \
  --region ap-south-1 \
  --query SecretString \
  --output text
```

## Logging warning

Do not run commands that print production secrets into:

* CI/CD logs.
* Shared terminals.
* Chat systems.
* Shell history.
* Monitoring systems.

---

# 57. Application secret retrieval

Node.js example:

```javascript id="node-secret"
import {
  SecretsManagerClient,
  GetSecretValueCommand
} from "@aws-sdk/client-secrets-manager";

const client = new SecretsManagerClient({
  region: "ap-south-1"
});

export async function getDatabaseSecret() {
  const response = await client.send(
    new GetSecretValueCommand({
      SecretId: "production/todoapp/database"
    })
  );

  if (!response.SecretString) {
    throw new Error("Secret does not contain SecretString");
  }

  return JSON.parse(response.SecretString);
}
```

Use the EC2, ECS or Lambda role rather than static AWS access keys.

---

# 58. Secret caching

Calling Secrets Manager for every application request is inefficient.

Better:

```text id="secret-cache"
Application starts
    ↓
Retrieves secret
    ↓
Caches it securely in memory
    ↓
Reuses it
    ↓
Refreshes after rotation or cache expiry
```

You must balance:

* Reduced API calls.
* Faster application access.
* Secret-rotation responsiveness.
* Memory exposure.
* Multi-process consistency.

Do not cache a rotated secret indefinitely.

---

# 59. Secrets Manager IAM policy

```json id="secret-iam-policy"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadTodoAppDatabaseSecret",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-south-1:123456789012:secret:production/todoapp/database-*"
    }
  ]
}
```

If the secret uses a customer managed KMS key, the role also needs appropriate KMS decrypt authorisation through the key policy and IAM policy.

---

# 60. Secret resource policy

Secrets Manager supports resource-based policies.

Example cross-account policy:

```json id="secret-resource-policy"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAnalyticsAccount",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/AnalyticsApplicationRole"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }
  ]
}
```

For cross-account retrieval, also configure:

* Caller identity policy.
* Secret resource policy.
* Customer-managed KMS key policy.
* Network connectivity where applicable.

---

# 61. Block public or overly broad secret policies

Use Secrets Manager resource-policy validation to prevent policies that expose secrets too broadly.

Avoid:

```json id="public-secret-policy"
{
  "Principal": "*",
  "Action": "secretsmanager:GetSecretValue",
  "Effect": "Allow"
}
```

Even when a condition is present, carefully validate the effective trust boundary.

Secrets Manager uses IAM and resource policies to define access to secret resources. ([AWS Documentation][18])

---

# 62. Secret rotation

Rotation changes both:

```text id="secret-rotation"
Stored secret value
+
Credential in the target database or service
```

Changing only Secrets Manager would break the application because the target would still expect the old credential.

Changing only the database would break the application because Secrets Manager would still return the old credential.

Secrets Manager supports managed rotation for supported managed secrets and Lambda-based rotation for other workflows. ([AWS Documentation][19])

---

# 63. Lambda rotation steps

A Lambda rotation function implements four logical steps:

```text id="rotation-steps"
create_secret
set_secret
test_secret
finish_secret
```

## `create_secret`

Generate or prepare the new credential and store it as `AWSPENDING`.

## `set_secret`

Apply the new credential to the target service.

## `test_secret`

Verify the new credential works.

## `finish_secret`

Move `AWSCURRENT` to the new version and complete the rotation.

Secrets Manager calls the rotation Lambda multiple times with step-specific parameters and a unique client request token for idempotency. ([AWS Documentation][20])

---

# 64. Rotation architecture

```text id="rotation-architecture"
Secrets Manager
      |
      | Invoke
      v
Rotation Lambda
      |
      | Connect using current/admin credential
      v
RDS database
      |
      | Change password
      v
Test new password
      |
      v
Mark new secret AWSCURRENT
```

The Lambda needs:

* Permission to read and update the secret.
* KMS permissions.
* Network access to the database.
* Database privileges to change credentials.
* Permission for Secrets Manager to invoke it.
* Logging permissions.

---

# 65. Single-user rotation

Single-user rotation updates the password for the same database user.

```text id="single-user"
Before:
todoapp_user / password-A

After:
todoapp_user / password-B
```

Risk:

There may be a short window where connections using the old credential and clients using the new credential behave differently.

Applications need connection refresh logic.

---

# 66. Alternating-user rotation

Alternating-user rotation switches between two database users.

```text id="alternating"
Rotation 1:
todoapp_user_A active

Rotation 2:
todoapp_user_B active

Rotation 3:
todoapp_user_A active again
```

This can reduce downtime because one credential remains valid while the other is updated and tested.

It is more complex and requires appropriate database-user privileges.

Secrets Manager documents single-user and alternating-user rotation strategies, and rotation can be scheduled as frequently as every four hours. ([AWS Documentation][21])

---

# 67. Application behaviour after rotation

A rotating secret is useless if the application never reloads it.

After rotation:

```text id="post-rotation"
Old database connections:
May continue until closed

New connections using cached old password:
May fail

Application:
Must retrieve current secret and recreate connections
```

Recommended pattern:

```text id="retry-rotation"
Connection authentication fails
        ↓
Invalidate cached secret
        ↓
Retrieve AWSCURRENT
        ↓
Create new connection pool
        ↓
Retry safe operation
```

Avoid retrying indefinitely.

---

# 68. Multi-Region secret replication

Secrets Manager can replicate a primary secret into additional AWS Regions.

It replicates:

```text id="secret-replication"
Encrypted secret data
Metadata
Tags
Resource policies
```

A replica can later be promoted into a standalone secret for disaster recovery. ([AWS Documentation][22])

Architecture:

```text id="secret-mr"
Primary secret:
ap-south-1
      |
      | Replication
      v
Replica secret:
ap-southeast-1
```

---

# 69. Secret replication and KMS

Each replica Region requires encryption using a KMS key in that Region.

You may use:

* Regional customer managed keys.
* Related multi-Region KMS keys.
* Region-specific policies.

Do not assume the primary Region’s single-Region KMS key can directly encrypt the replica secret in another Region.

Secrets Manager requests a data key from the KMS key selected in the replica Region. ([AWS Documentation][17])

---

# 70. Parameter Store

Systems Manager Parameter Store is designed for storing and retrieving application configuration in a hierarchical structure.

Supported parameter types include:

```text id="parameter-types"
String
StringList
SecureString
```

Typical values:

```text id="parameter-examples"
Application environment
API endpoint
Feature flag
AMI ID
Log level
Database hostname
Port number
Configuration path
Encrypted small credential
```

Parameter Store is intended for secure, scalable configuration management without hardcoding configuration into application code. ([AWS Documentation][23])

---

# 71. Hierarchical parameter naming

Example:

```text id="parameter-hierarchy"
/production/todoapp/database/host
/production/todoapp/database/port
/production/todoapp/logging/level
/production/todoapp/features/new-ui
/production/todoapp/external-api/token
```

Benefits:

* Environment separation.
* Project separation.
* Path-based IAM policies.
* Bulk retrieval by path.
* Easier organisation.
* Consistent naming.

---

# 72. Parameter types

## `String`

```text id="parameter-string"
/production/todoapp/log-level = INFO
```

## `StringList`

```text id="parameter-list"
/production/todoapp/allowed-regions =
ap-south-1,ap-southeast-1
```

## `SecureString`

```text id="parameter-secure"
/production/todoapp/api-token =
encrypted value
```

Parameter Store uses symmetric KMS keys to encrypt and decrypt `SecureString` values. Asymmetric KMS keys are not supported for SecureString parameters. ([AWS Documentation][24])

---

# 73. Standard versus advanced parameters

Current Parameter Store tiers include:

| Feature                                   | Standard | Advanced |
| ----------------------------------------- | -------: | -------: |
| Maximum parameters per account and Region |   10,000 |  100,000 |
| Maximum value size                        |     4 KB |     8 KB |
| Parameter policies                        |       No |      Yes |
| Cross-account sharing                     |       No |      Yes |

A standard parameter can be promoted to advanced, but an advanced parameter cannot be converted back to standard. ([AWS Documentation][25])

---

# 74. Standard SecureString encryption

A standard SecureString value can be up to 4 KB.

Parameter Store calls KMS `Encrypt` directly using the selected symmetric KMS key.

If no key is specified, Parameter Store can use the AWS managed key:

```text id="ssm-key"
alias/aws/ssm
```

AWS documents that standard SecureString values are directly encrypted under the selected KMS key, while advanced values use envelope encryption. ([AWS Documentation][24])

---

# 75. Advanced SecureString encryption

Advanced SecureString parameters can be up to 8 KB.

Parameter Store uses:

```text id="advanced-encryption"
AWS Encryption SDK
+
AWS KMS
+
Envelope encryption
```

This is because the advanced value can exceed the size appropriate for direct KMS encryption.

Advanced Parameter Store SecureString values use the AWS Encryption SDK and KMS data-key workflow. ([AWS Documentation][24])

---

# 76. Parameter policies

Advanced parameters support policies such as:

* Expiration.
* Expiration notification.
* No-change notification.

Example use:

```text id="parameter-policy-use"
API token should expire on a date
Configuration has not changed for 90 days
Certificate reference needs review
```

Parameter policies provide lifecycle notifications but do not automatically rotate a target credential like Secrets Manager rotation.

---

# 77. Retrieve a parameter

```bash id="get-parameter"
aws ssm get-parameter \
  --name /production/todoapp/database/host \
  --region ap-south-1
```

Decrypt SecureString:

```bash id="get-secure-parameter"
aws ssm get-parameter \
  --name /production/todoapp/external-api/token \
  --with-decryption \
  --region ap-south-1
```

Retrieve by path:

```bash id="get-parameters-path"
aws ssm get-parameters-by-path \
  --path /production/todoapp \
  --recursive \
  --with-decryption \
  --region ap-south-1
```

---

# 78. Path-based IAM policy

```json id="parameter-policy-iam"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadTodoAppProductionParameters",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:ap-south-1:123456789012:parameter/production/todoapp/*"
    }
  ]
}
```

For SecureString values encrypted with a customer managed key, also provide controlled `kms:Decrypt` access.

---

# 79. Parameter hierarchy access warning

If an identity has permission to recursively read a parent path:

```text id="parameter-parent"
/production/todoapp
```

it may read all descendants:

```text id="parameter-descendants"
/production/todoapp/database/password
/production/todoapp/admin/token
/production/todoapp/private/key
```

Design paths according to access boundaries.

Better:

```text id="separate-parameter-paths"
/production/todoapp/config/*
/production/todoapp/secrets/*
/production/todoapp/admin/*
```

with different IAM roles.

---

# 80. Secrets Manager versus Parameter Store

| Requirement                     | Secrets Manager | Parameter Store           |
| ------------------------------- | --------------- | ------------------------- |
| Database password               | Best fit        | Possible                  |
| Automatic credential rotation   | Yes             | No native target rotation |
| Version staging labels          | Yes             | Basic parameter versions  |
| Hierarchical config             | Limited naming  | Strong fit                |
| Plain configuration             | Overkill        | Best fit                  |
| API token needing rotation      | Best fit        | Possible                  |
| Feature flags                   | Not ideal       | Best fit                  |
| Small encrypted setting         | Yes             | SecureString              |
| Cross-Region secret replication | Native          | Build separately          |
| Cross-account sharing           | Resource policy | Advanced parameters       |
| Lower-cost simple config        | Less ideal      | Common fit                |

## Memory trick

```text id="secret-vs-parameter"
Needs rotation and secret lifecycle?
Use Secrets Manager.

Needs hierarchical application configuration?
Use Parameter Store.
```

---

# 81. Do not use KMS as a secret store

Bad pattern:

```text id="kms-secret-store"
Encrypt database password with KMS
Store ciphertext manually in source code
Decrypt during application startup
```

This can work cryptographically, but now you must build:

* Storage.
* Versioning.
* Rotation.
* Auditing.
* Replication.
* Access workflows.
* Deployment integration.

Use Secrets Manager when you need full secret lifecycle management.

KMS should protect the encryption keys; it should not replace a secret-management service.

---

# 82. Do not put secrets in Terraform source

Bad:

```hcl id="bad-secret"
resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = "admin"
    password = "Password123"
  })
}
```

Even with:

```hcl id="sensitive-variable"
sensitive = true
```

the secret may still be stored in Terraform state.

## Better options

* Generate the secret securely during deployment.
* Use Secrets Manager-managed passwords.
* Use an external secret-injection system.
* Keep Terraform state strictly protected.
* Separate infrastructure creation from secret-value population.
* Avoid printing secret values in plan output.

---

# 83. Terraform KMS key

```hcl id="terraform-kms"
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "application" {
  description = "Production TodoApp application encryption key"

  enable_key_rotation = true

  deletion_window_in_days = 30

  policy = data.aws_iam_policy_document.application_key.json

  tags = {
    Name        = "production-todoapp"
    Environment = "production"
    Application = "TodoApp"
    ManagedBy   = "Terraform"
  }
}
```

Alias:

```hcl id="terraform-alias"
resource "aws_kms_alias" "application" {
  name          = "alias/production/todoapp"
  target_key_id = aws_kms_key.application.key_id
}
```

---

# 84. Terraform key policy

```hcl id="terraform-key-policy"
data "aws_iam_policy_document" "application_key" {
  statement {
    sid = "EnableAccountIAMPermissions"

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
    sid = "AllowSecurityKeyAdministration"

    principals {
      type = "AWS"

      identifiers = [
        aws_iam_role.security_key_admin.arn
      ]
    }

    actions = [
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "kms:Enable*",
      "kms:Disable*",
      "kms:PutKeyPolicy",
      "kms:Update*",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:RotateKeyOnDemand"
    ]

    resources = ["*"]
  }

  statement {
    sid = "AllowApplicationCryptographicUse"

    principals {
      type = "AWS"

      identifiers = [
        aws_iam_role.application.arn
      ]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:Application"
      values   = ["TodoApp"]
    }
  }
}
```

---

# 85. Terraform Secrets Manager secret

```hcl id="terraform-secret"
resource "aws_secretsmanager_secret" "database" {
  name        = "production/todoapp/database"
  description = "TodoApp production database credentials"

  kms_key_id = aws_kms_key.application.arn

  recovery_window_in_days = 30

  tags = {
    Environment = "production"
    Application = "TodoApp"
    ManagedBy   = "Terraform"
  }
}
```

Avoid defining the production secret value directly in Terraform when possible.

---

# 86. Terraform secret rotation

```hcl id="terraform-rotation"
resource "aws_secretsmanager_secret_rotation" "database" {
  secret_id           = aws_secretsmanager_secret.database.id
  rotation_lambda_arn = aws_lambda_function.database_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

The rotation Lambda also needs:

* Execution role.
* Secret permissions.
* KMS permissions.
* Database network connectivity.
* Lambda invocation permission for Secrets Manager.

---

# 87. Terraform Parameter Store

Normal string:

```hcl id="terraform-parameter-string"
resource "aws_ssm_parameter" "log_level" {
  name  = "/production/todoapp/logging/level"
  type  = "String"
  value = "INFO"

  tags = {
    Environment = "production"
    Application = "TodoApp"
  }
}
```

SecureString:

```hcl id="terraform-parameter-secure"
resource "aws_ssm_parameter" "external_api_token" {
  name   = "/production/todoapp/external-api/token"
  type   = "SecureString"
  key_id = aws_kms_key.application.arn

  value = var.external_api_token

  tags = {
    Environment = "production"
    Application = "TodoApp"
  }
}
```

Again, the SecureString value can enter Terraform state.

---

# 88. Create a KMS key with AWS CLI

```bash id="create-key"
KEY_ID=$(aws kms create-key \
  --description "Production TodoApp encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --region ap-south-1 \
  --query KeyMetadata.KeyId \
  --output text)
```

Create alias:

```bash id="create-alias"
aws kms create-alias \
  --alias-name alias/production/todoapp \
  --target-key-id "$KEY_ID" \
  --region ap-south-1
```

Enable automatic rotation:

```bash id="enable-rotation"
aws kms enable-key-rotation \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

---

# 89. Basic KMS encryption lab

Create plaintext:

```bash id="create-plaintext"
printf 'production-sensitive-value' > plaintext.txt
```

Encrypt:

```bash id="kms-encrypt"
aws kms encrypt \
  --key-id alias/production/todoapp \
  --plaintext fileb://plaintext.txt \
  --encryption-context Application=TodoApp,Environment=Production \
  --region ap-south-1 \
  --query CiphertextBlob \
  --output text |
base64 --decode > ciphertext.bin
```

Decrypt:

```bash id="kms-decrypt"
aws kms decrypt \
  --ciphertext-blob fileb://ciphertext.bin \
  --encryption-context Application=TodoApp,Environment=Production \
  --region ap-south-1 \
  --query Plaintext \
  --output text |
base64 --decode
```

Expected:

```text id="decrypt-result"
production-sensitive-value
```

---

# 90. Test incorrect encryption context

```bash id="wrong-context"
aws kms decrypt \
  --ciphertext-blob fileb://ciphertext.bin \
  --encryption-context Application=OtherApp,Environment=Production \
  --region ap-south-1
```

Expected failure:

```text id="invalid-ciphertext"
InvalidCiphertextException
```

This demonstrates that encryption context is cryptographically bound to the ciphertext.

---

# 91. Generate a data key

```bash id="generate-data-key"
aws kms generate-data-key \
  --key-id alias/production/todoapp \
  --key-spec AES_256 \
  --encryption-context Application=TodoApp \
  --region ap-south-1
```

The response includes:

```text id="data-key-response"
Plaintext
CiphertextBlob
KeyId
```

Do not run this against production and print the plaintext data key to shared logs.

---

# 92. Monitoring KMS

Use:

```text id="kms-monitoring"
AWS CloudTrail
CloudWatch metrics
EventBridge events
AWS Config
Security Hub findings
Access Analyzer policy validation
```

CloudTrail records KMS management and cryptographic activity, subject to event configuration and service behaviour.

Useful events:

```text id="kms-events"
Encrypt
Decrypt
GenerateDataKey
CreateGrant
PutKeyPolicy
DisableKey
ScheduleKeyDeletion
CancelKeyDeletion
EnableKeyRotation
RotateKeyOnDemand
ReplicateKey
```

---

# 93. Recommended KMS alerts

Create alerts for:

```text id="kms-alerts"
ScheduleKeyDeletion
DisableKey
PutKeyPolicy
CreateGrant by unexpected principals
DeleteImportedKeyMaterial
Failed decrypt spikes
External key-store disconnect
Key policy changes
Key rotation disabled
Replica or primary Region changes
```

High-risk changes should trigger immediate security review.

---

# 94. Troubleshooting: `AccessDeniedException`

Example:

```text id="kms-access-denied"
User is not authorized to perform kms:Decrypt
```

Check in order:

```text id="kms-troubleshoot-order"
1. aws sts get-caller-identity
2. Correct KMS key ARN and Region
3. IAM policy
4. KMS key policy
5. Permission boundary
6. Session policy
7. SCP or RCP
8. KMS grant
9. Encryption-context conditions
10. ViaService or source conditions
11. VPC endpoint policy
12. Resource service policy
```

KMS access failures frequently occur because an IAM Allow exists but the key policy does not enable or permit the caller.

---

# 95. Troubleshooting: wrong Region

KMS keys are Regional.

Error scenario:

```text id="wrong-region"
Ciphertext encrypted with:
KMS key in ap-south-1

Application calls:
KMS endpoint in us-east-1

Result:
Key or ciphertext failure
```

Check:

```bash id="key-describe"
aws kms describe-key \
  --key-id "$KEY_ARN" \
  --region ap-south-1
```

For a single-Region KMS key, use the KMS endpoint in the key’s Region.

---

# 96. Troubleshooting: key disabled

Symptoms:

```text id="key-disabled"
KMSInvalidStateException
DisabledException
Secrets cannot be retrieved
Encrypted EBS launch fails
```

Check:

```bash id="check-key-state"
aws kms describe-key \
  --key-id alias/production/todoapp \
  --region ap-south-1 \
  --query 'KeyMetadata.{
    KeyState:KeyState,
    Enabled:Enabled,
    Origin:Origin,
    MultiRegion:MultiRegion
  }'
```

Possible states include:

```text id="key-states"
Enabled
Disabled
PendingDeletion
PendingImport
Unavailable
Updating
```

---

# 97. Troubleshooting: pending deletion

If a key is pending deletion:

```text id="pending-deletion"
Cryptographic operations stop.
Rotation stops.
Dependent resources fail.
```

Cancel deletion:

```bash id="cancel-deletion"
aws kms cancel-key-deletion \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

Then enable:

```bash id="enable-key"
aws kms enable-key \
  --key-id "$KEY_ID" \
  --region ap-south-1
```

Do this only after confirming that cancellation is authorised by your operational process.

---

# 98. Troubleshooting: `InvalidCiphertextException`

Possible causes:

```text id="invalid-ciphertext-causes"
Wrong encryption context
Corrupted ciphertext
Ciphertext truncated during base64 processing
Wrong asymmetric algorithm
Wrong key or incompatible ciphertext
Ciphertext was created outside KMS incorrectly
Application altered associated authenticated data
```

For symmetric KMS ciphertext, KMS normally identifies the key from the ciphertext metadata, but the encryption context must match exactly when one was used.

---

# 99. Troubleshooting: S3 access denied with SSE-KMS

An S3 read requires multiple permissions:

```text id="s3-kms-permissions"
s3:GetObject
+
kms:Decrypt
+
Bucket policy permits access
+
KMS key policy permits access
+
No SCP or endpoint denial
```

For upload:

```text id="s3-kms-upload"
s3:PutObject
+
kms:GenerateDataKey
+
KMS key policy access
```

Also check:

* S3 bucket default encryption.
* KMS key Region.
* KMS encryption-context conditions.
* Cross-account ownership.
* `kms:ViaService` conditions.

---

# 100. Troubleshooting: encrypted EBS or Auto Scaling launch fails

Possible causes:

```text id="ebs-kms-fail"
Launch role lacks KMS permission
Auto Scaling service-linked role cannot use key
Grant creation denied
Key is disabled
Key policy excludes service-linked role
Snapshot encrypted by inaccessible key
Cross-account snapshot key access missing
```

AWS services often create KMS grants for persistent encrypted resources, so restrictive `kms:CreateGrant` policies can break otherwise valid infrastructure provisioning.

---

# 101. Troubleshooting: Secrets Manager access denied

Check:

```text id="secret-access-checks"
secretsmanager:GetSecretValue
Secret ARN suffix included in policy
Secret resource policy
kms:Decrypt
KMS key policy
Correct Region
Secret not scheduled for deletion
VPC endpoint policy
SCP
```

Secret ARNs contain a generated suffix.

Policy example:

```text id="secret-arn-pattern"
arn:aws:secretsmanager:ap-south-1:123456789012:
secret:production/todoapp/database-*
```

Using the friendly name without the suffix in an exact ARN policy can cause mismatches.

---

# 102. Troubleshooting: secret rotation fails

Check the rotation workflow:

```text id="rotation-failure"
create_secret
set_secret
test_secret
finish_secret
```

Common causes:

* Rotation Lambda cannot reach database.
* Security group blocks database port.
* Lambda is in wrong VPC.
* NAT or endpoint access missing.
* Lambda lacks secret permissions.
* KMS decrypt denied.
* Database admin credential incorrect.
* Secret JSON format unexpected.
* New password violates database rules.
* Test step uses wrong username.
* Rotation token or version labels inconsistent.

Secrets Manager retries failed Lambda-based rotation during the open rotation window, but you should fix the cause rather than rely on repeated retries. ([AWS Documentation][20])

---

# 103. Troubleshooting: application fails after rotation

Symptoms:

```text id="app-rotation-failure"
Rotation succeeds
Database accepts new password
Application starts returning authentication errors
```

Likely cause:

```text id="cached-old-secret"
Application cached AWSPREVIOUS or old AWSCURRENT
and never refreshed its pool.
```

Fix:

* Set a secret-cache lifetime.
* Refresh on authentication failure.
* Rebuild the connection pool.
* Use RDS Proxy where appropriate.
* Monitor secret version IDs.
* Test rotation regularly.

---

# 104. Troubleshooting: SecureString cannot decrypt

Check:

```text id="ssm-decrypt-check"
ssm:GetParameter
Request includes --with-decryption
kms:Decrypt
Correct customer managed key policy
Parameter Region
Parameter path
Encryption context restrictions
Parameter tier
```

Parameter Store uses KMS for SecureString encryption and decryption, and advanced SecureString values use envelope encryption. ([AWS Documentation][24])

---

# 105. Key compromise response

If a KMS key might be compromised:

```text id="kms-incident"
1. Determine what was compromised:
   - IAM access
   - Key policy
   - Data key
   - Imported key material
   - External key
   - Plaintext data

2. Remove unauthorised IAM sessions.
3. Correct key and IAM policies.
4. Revoke suspicious grants.
5. Consider disabling key with impact approval.
6. Create a replacement key.
7. Redirect aliases and new encryption.
8. Re-encrypt sensitive data where required.
9. Rotate dependent secrets.
10. Review CloudTrail.
11. Preserve evidence.
12. Monitor for continued misuse.
```

Rotating a KMS key does not address a compromised plaintext data key or already exposed plaintext.

---

# 106. Production KMS checklist

```text id="kms-checklist"
[ ] Customer managed key is justified
[ ] Key purpose and data classification are documented
[ ] Key policy enables controlled account recovery
[ ] Key administrators and users are separated
[ ] Application receives only required cryptographic actions
[ ] Encryption context is used where useful
[ ] Cross-account principals are explicit
[ ] CreateGrant is restricted to AWS resources
[ ] Automatic rotation is enabled where supported
[ ] Alias naming is standardised
[ ] Old keys are retained until data is migrated
[ ] Key deletion uses a controlled workflow
[ ] Key-disable impact is documented
[ ] Multi-Region keys are used only when required
[ ] Imported key material has secure external backups
[ ] External key-store availability is monitored
[ ] CloudTrail records KMS activity
[ ] High-risk KMS events generate alerts
[ ] Terraform key policies are peer-reviewed
[ ] SCPs protect key deletion and policy changes
[ ] KMS grants are reviewed
```

---

# 107. Production secrets checklist

```text id="secrets-checklist"
[ ] Secrets are not stored in source code
[ ] Secrets are not stored in container images
[ ] Workloads use IAM roles
[ ] Secret ARNs are narrowly scoped
[ ] Customer managed KMS access is configured
[ ] Resource policies are validated
[ ] Secret rotation is configured where appropriate
[ ] Application reloads rotated values
[ ] Rotation failure alarms exist
[ ] Secret values are not printed in logs
[ ] Recovery window is configured
[ ] Cross-Region replication matches DR design
[ ] Replica KMS keys are configured
[ ] Cross-account access includes all three policy layers
[ ] Secret caching has a defined expiry
[ ] Old secret versions are monitored
```

---

# 108. Production Parameter Store checklist

```text id="parameter-checklist"
[ ] Parameter names follow a hierarchy
[ ] Environments use separate paths
[ ] Sensitive values use SecureString
[ ] Customer managed KMS keys are used when control is required
[ ] Path permissions do not expose unrelated parameters
[ ] Standard versus advanced tier is deliberate
[ ] Advanced-parameter cost is understood
[ ] Parameter policies are configured where useful
[ ] Parameter values are not hardcoded in Terraform state unnecessarily
[ ] Applications cache configuration appropriately
[ ] Changes are audited
[ ] Cross-account sharing uses advanced parameters when required
```

---

# 109. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text id="clf-kms"
AWS KMS manages encryption keys.
Secrets Manager stores and rotates secrets.
Parameter Store stores configuration.
Encryption at rest protects stored data.
TLS protects data in transit.
```

## Solutions Architect Associate

Understand:

```text id="saa-kms"
Customer managed versus AWS managed keys
Key policies
Envelope encryption
Data keys
Automatic rotation
Key deletion
Multi-Region keys
Secrets Manager rotation
Parameter Store SecureString
Secrets Manager versus Parameter Store
```

## DevOps Engineer Professional

Understand:

```text id="dop-kms"
Key-policy automation
Cross-account KMS
KMS grants
Encryption context
Rotation and re-encryption
Multi-Region DR
Imported key material
Secret rotation Lambda
Regional secret replication
Terraform state protection
CloudTrail monitoring
Incident response
```

---

# 110. Interview questions

## Question 1: What is AWS KMS?

**Answer:**

AWS KMS is a managed service for creating and controlling cryptographic keys used to encrypt, decrypt, sign, verify and generate or verify MACs.

## Question 2: What is envelope encryption?

**Answer:**

Envelope encryption encrypts application data with a data key and then encrypts that data key with a KMS key. The encrypted data key is stored beside the encrypted data.

## Question 3: Why not encrypt a large file directly with KMS?

**Answer:**

KMS is designed to protect small pieces of key material. Bulk data should be encrypted locally using a data key generated or protected by KMS.

## Question 4: What is the difference between a KMS key and a data key?

**Answer:**

A KMS key is a managed key resource that protects key material and controls cryptographic operations. A data key is a symmetric key used directly to encrypt application data.

## Question 5: What is a key policy?

**Answer:**

It is the resource policy attached to a KMS key. It is the primary mechanism controlling who can administer and use that key.

## Question 6: Can an IAM policy alone always grant KMS access?

**Answer:**

No. The KMS key policy must permit the principal directly or enable the account to delegate access through IAM policies.

## Question 7: What is the difference between a key administrator and a key user?

**Answer:**

A key administrator manages the key’s configuration and policy. A key user performs cryptographic operations. These responsibilities should be separated.

## Question 8: What is a KMS grant?

**Answer:**

A grant provides specified KMS permissions to a principal, often temporarily or for an integrated AWS resource, without modifying the main key policy.

## Question 9: What is encryption context?

**Answer:**

It is a non-secret set of key-value pairs cryptographically bound to symmetric KMS operations. It improves integrity, auditability and policy control.

## Question 10: Does KMS key rotation re-encrypt existing data?

**Answer:**

No. It changes the backing key material used for future encryption. KMS retains old key material so existing ciphertext remains decryptable.

## Question 11: What happens if a KMS key is deleted?

**Answer:**

Data encrypted under the key may become permanently unrecoverable. KMS therefore requires a waiting period before deletion.

## Question 12: What is a multi-Region KMS key?

**Answer:**

It is one of a related set of KMS keys in different Regions that share the same key ID and key material, allowing interoperable encryption and decryption across those Regions.

## Question 13: What is BYOK?

**Answer:**

Bring Your Own Key means importing externally generated key material into a KMS key.

## Question 14: What is an external key store?

**Answer:**

It allows KMS operations to depend on key material held in an external customer-controlled key manager outside AWS.

## Question 15: What is the difference between Secrets Manager and Parameter Store?

**Answer:**

Secrets Manager is designed for secrets that need lifecycle management and rotation. Parameter Store is designed primarily for hierarchical application configuration, with optional SecureString encryption.

## Question 16: How does Secrets Manager rotate a database password?

**Answer:**

It generates or prepares a new credential, applies it to the database, tests it and marks the new secret version as current.

## Question 17: What are `AWSCURRENT` and `AWSPENDING`?

**Answer:**

They are staging labels for secret versions. `AWSCURRENT` identifies the active version, while `AWSPENDING` identifies a version being prepared during rotation.

## Question 18: Does Parameter Store rotate credentials?

**Answer:**

Parameter Store can store encrypted values but does not provide the same automatic target credential-rotation workflow as Secrets Manager.

## Question 19: Why might an application fail after a successful secret rotation?

**Answer:**

The application may still be using a cached old secret or existing connection pool and may not have refreshed its credentials.

## Question 20: How would you troubleshoot KMS `AccessDenied`?

**Answer:**

Identify the caller and Region, inspect the IAM policy, key policy, grants, encryption-context conditions, SCPs, session policies, endpoint policies and the policy of the service using the key.

---

# 111. Never-forget revision

```text id="kms-revision"
AWS KMS:
Manages cryptographic keys and operations.

KMS key:
Logical key resource with policy and key material.

Data key:
Encrypts actual application data.

Envelope encryption:
Data key encrypts data; KMS key encrypts the data key.

Key policy:
Primary resource policy for a KMS key.

Key administrator:
Manages key configuration.

Key user:
Performs cryptographic operations.

Grant:
Temporary or resource-linked KMS permission.

Encryption context:
Non-secret authenticated metadata bound to ciphertext.

Alias:
Friendly Regional name pointing to a KMS key.

Automatic rotation:
Changes backing key material without changing key ARN.

Manual rotation:
Create a new key and redirect new encryption to it.

Multi-Region key:
Related keys in multiple Regions with shared key material.

BYOK:
Import your own key material.

HYOK:
Keep key material in an external key manager.

Secrets Manager:
Stores, versions and rotates secrets.

Parameter Store:
Stores hierarchical configuration and SecureString values.

AWSCURRENT:
Active secret version.

AWSPENDING:
Version being prepared during rotation.
```

## One-line memory trick

```text id="kms-memory"
KMS protects keys.
Data keys protect data.
Secrets Manager protects rotating credentials.
Parameter Store organises configuration.
IAM and key policies decide who may decrypt.
```

## Lesson 32 outcome

You can now design an architecture where:

```text id="kms-outcome"
Large application data needs encryption
    → Envelope encryption uses a data key.

Application needs database credentials
    → Secrets Manager stores and rotates them.

Application needs configuration
    → Parameter Store provides hierarchical values.

Production role needs decrypt access
    → IAM policy and KMS key policy permit only that role.

Ciphertext must remain tenant-specific
    → Encryption context restricts decryption.

A Region fails
    → Multi-Region KMS key and replicated secret support recovery.

A key must be replaced
    → Alias moves new encryption to a new key while old key remains available.

A key appears compromised
    → Grants, policies, aliases, secrets and encrypted data are rotated through a controlled incident process.
```

**Next lesson: Lesson 33 — Amazon S3 production architecture: storage classes, versioning, lifecycle policies, replication, Object Lock, access points, event notifications, multipart uploads, encryption and advanced troubleshooting.**

[1]: https://docs.aws.amazon.com/kms/latest/developerguide/overview.html?utm_source=chatgpt.com "AWS Key Management Service"
[2]: https://docs.aws.amazon.com/kms/latest/developerguide/symmetric-asymmetric.html?utm_source=chatgpt.com "Asymmetric keys in AWS KMS"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html?utm_source=chatgpt.com "Using server-side encryption with AWS KMS keys (SSE-KMS)"
[4]: https://docs.aws.amazon.com/kms/latest/developerguide/data-keys.html?utm_source=chatgpt.com "Generate data keys - AWS Key Management Service"
[5]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html "Key policies in AWS KMS - AWS Key Management Service"
[6]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html "Default key policy - AWS Key Management Service"
[7]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html?utm_source=chatgpt.com "Access AWS Secrets Manager secrets from a different ..."
[8]: https://docs.aws.amazon.com/kms/latest/developerguide/grants.html?utm_source=chatgpt.com "Grants in AWS KMS - AWS Key Management Service"
[9]: https://docs.aws.amazon.com/kms/latest/developerguide/encrypt_context.html "Encryption context - AWS Key Management Service"
[10]: https://docs.aws.amazon.com/kms/latest/developerguide/kms-alias.html "Aliases in AWS KMS - AWS Key Management Service"
[11]: https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html "Rotate AWS KMS keys - AWS Key Management Service"
[12]: https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html "Delete an AWS KMS key - AWS Key Management Service"
[13]: https://docs.aws.amazon.com/kms/latest/developerguide/multi-region-keys-overview.html "Multi-Region keys in AWS KMS - AWS Key Management Service"
[14]: https://docs.aws.amazon.com/kms/latest/developerguide/importing-keys.html?utm_source=chatgpt.com "Importing key material for AWS KMS keys"
[15]: https://docs.aws.amazon.com/kms/latest/developerguide/import-keys-protect.html?utm_source=chatgpt.com "Protecting imported key material"
[16]: https://docs.aws.amazon.com/kms/latest/developerguide/keystore-external.html "External key stores - AWS Key Management Service"
[17]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html?utm_source=chatgpt.com "Secret encryption and decryption in AWS Secrets Manager"
[18]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access.html?utm_source=chatgpt.com "Authentication and access control for AWS Secrets Manager"
[19]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html "Rotate AWS Secrets Manager secrets - AWS Secrets Manager"
[20]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda.html "Rotation by Lambda function - AWS Secrets Manager"
[21]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html "AWS Secrets Manager best practices - AWS Secrets Manager"
[22]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html "Replicate AWS Secrets Manager secrets across Regions - AWS Secrets Manager"
[23]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html?utm_source=chatgpt.com "AWS Systems Manager Parameter Store"
[24]: https://docs.aws.amazon.com/systems-manager/latest/userguide/secure-string-parameter-kms-encryption.html "AWS KMS encryption for AWS Systems Manager Parameter Store SecureString parameters - AWS Systems Manager"
[25]: https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html "Managing tiers - AWS Systems Manager"
