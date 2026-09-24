# AWS Masterclass — Phase 3

# Lesson 33: Amazon S3 Production Architecture

## 1. Lesson objectives

In this lesson, you will learn how to:

* Understand S3 object-storage architecture.
* Distinguish general-purpose, directory, table and vector buckets.
* Select the correct S3 storage class.
* Configure versioning and lifecycle management.
* Recover deleted or overwritten objects.
* Use Same-Region and Cross-Region Replication.
* Understand S3 Replication Time Control.
* Build multi-Region storage with Multi-Region Access Points.
* Protect immutable data using S3 Object Lock.
* Secure buckets with Block Public Access, Object Ownership and bucket policies.
* Use SSE-S3, SSE-KMS and DSSE-KMS encryption.
* Use S3 Bucket Keys to reduce KMS request volume.
* Upload large files using multipart upload.
* Create event-driven workflows.
* Use S3 Access Points, Inventory, Batch Operations and Storage Lens.
* Troubleshoot production S3 failures.
* Build a production bucket using Terraform.

---

# 2. Production architecture

A production S3 architecture might look like:

```text
                              Users
                                |
                                v
                         Route 53 DNS
                                |
                                v
                           CloudFront
                                |
                       Origin Access Control
                                |
                                v
                     Private application bucket
                          ap-south-1
                                |
                 Versioning + SSE-KMS + Lifecycle
                                |
           ┌────────────────────┼────────────────────┐
           |                    |                    |
           v                    v                    v
   EventBridge/SQS       Cross-Region          Inventory reports
           |              Replication                 |
           v                    |                     v
    Processing Lambda           v              Batch Operations
                         DR bucket
                      ap-southeast-1
```

A different bucket might be used for immutable audit records:

```text
CloudTrail / application audit events
                  |
                  v
          S3 audit-log bucket
                  |
        Versioning + Object Lock
                  |
        Compliance retention mode
                  |
           Glacier lifecycle
```

---

# 3. What is Amazon S3?

Amazon Simple Storage Service is an object-storage service for storing data such as application files, backups, data-lake objects, website assets, logs, archives and analytics datasets. S3 manages storage capacity automatically; you do not provision disks or storage servers. ([AWS Documentation][1])

## Basic mental model

```text
Bucket:
Top-level data container

Object:
File plus metadata

Object key:
Unique name inside the bucket

Version ID:
Identifies one version when versioning is enabled
```

Example:

```text
Bucket:
production-todo-assets

Object key:
images/users/104/profile.jpg

Full object identity:
bucket + key + optional version ID
```

---

# 4. Object storage versus block and file storage

## Object storage: S3

```text
Application
    |
    | S3 API
    v
Bucket → Object
```

Suitable for:

* Images.
* Videos.
* Backups.
* Logs.
* Build artifacts.
* Data lakes.
* Static frontend files.
* Machine-learning datasets.

Objects are accessed through APIs rather than being treated as ordinary disk blocks.

## Block storage: EBS

```text
EC2
  |
  v
Virtual disk volume
```

Suitable for:

* Operating-system disks.
* Databases.
* Filesystems.
* Low-level block access.

## File storage: EFS or FSx

```text
Multiple servers
      |
      v
Shared filesystem
```

Suitable for applications that require directories, file locking and filesystem semantics.

## Never-forget distinction

```text
S3:
Object API

EBS:
Block device

EFS/FSx:
Shared filesystem
```

---

# 5. Current S3 bucket types

Amazon S3 currently has several specialised bucket types:

```text
General-purpose buckets
Directory buckets
Table buckets
Vector buckets
```

General-purpose buckets are suitable for most standard object-storage workloads. Directory buckets are designed for specialised low-latency or data-residency workloads. Table buckets are designed around Apache Iceberg tabular data, while vector buckets are designed for storing and querying vector embeddings. ([AWS Documentation][1])

This lesson concentrates primarily on:

```text
General-purpose buckets
+
S3 Express One Zone directory buckets
```

---

# 6. General-purpose buckets

General-purpose buckets support the broadest S3 feature set and most S3 storage classes.

Typical uses:

```text
Static website origin
Application uploads
Backup storage
Data lakes
Log archives
CI/CD artifacts
Cross-Region Replication
Object Lock
Lifecycle management
```

General-purpose buckets ordinarily store data redundantly across multiple Availability Zones, except when an explicitly single-zone storage class is selected. ([AWS Documentation][1])

---

# 7. Directory buckets

Directory buckets organise objects hierarchically and are used with specialised storage such as S3 Express One Zone.

For high-performance workloads, a directory bucket can be placed in a specific Availability Zone near the application’s compute resources. S3 Express One Zone provides consistent single-digit millisecond access and stores data redundantly across multiple devices within that selected Availability Zone. ([AWS Documentation][1])

Architecture:

```text
EC2 compute in AZ-A
        |
        v
Directory bucket in AZ-A
        |
        v
S3 Express One Zone
```

## Important risk

```text
General-purpose multi-AZ storage:
Designed to tolerate an AZ loss.

S3 Express One Zone:
Stored within one selected AZ.
```

Use Express One Zone when performance matters and the data can be recreated, replicated or otherwise recovered.

---

# 8. Bucket Region

When creating a bucket, you select its AWS Region.

Example:

```text
Region:
ap-south-1
```

After the bucket is created:

```text
Bucket name:
Cannot be changed directly

Bucket Region:
Cannot be changed directly
```

Moving to another name or Region normally means creating a new bucket and copying or replicating the objects. S3 objects remain in the selected Region unless you explicitly copy or replicate them elsewhere. ([AWS Documentation][1])

---

# 9. Bucket naming and namespaces

Traditional general-purpose bucket names exist within an S3 namespace and must satisfy S3 naming requirements.

Example:

```text
Valid concept:
vivek-production-todo-assets-123456789012

Invalid concepts:
My_Bucket
Production Bucket
```

Because bucket names frequently appear in DNS hostnames, use:

```text
Lowercase letters
Numbers
Hyphens
Meaningful environment names
Account identifiers where useful
```

Never assume a short generic bucket name will be available.

---

# 10. Object keys and prefixes

S3 object storage is logically flat, but `/` characters in object keys create a folder-like experience.

Example keys:

```text
production/images/logo.png
production/images/users/104.jpg
production/logs/2026/07/27/app.log
```

S3 interprets these as object-key strings:

```text
production/images/logo.png
```

not as a traditional filesystem inode structure.

## Prefix

A prefix is the beginning portion of a key.

Example:

```text
Prefix:
production/logs/

Matching objects:
production/logs/app.log
production/logs/api.log
production/logs/2026/07/27.log
```

Prefixes are used in:

* IAM policies.
* Lifecycle rules.
* Replication rules.
* Event filters.
* Inventory.
* Batch Operations.

---

# 11. S3 consistency

S3 provides strong read-after-write consistency for object PUT, overwrite and DELETE operations in every AWS Region.

After a successful write:

```text
PUT object succeeds
        ↓
Immediate GET returns new object
        ↓
Immediate LIST includes new object
```

After a successful delete:

```text
DELETE succeeds
        ↓
Immediate GET no longer returns object
        ↓
Immediate LIST excludes object
```

S3 updates to one key are atomic, meaning readers see either the previous complete object or the new complete object—not a partially written object. ([AWS Documentation][1])

---

# 12. Concurrent writes

Suppose two applications write to the same key:

```text
Writer A:
PUT config.json version A

Writer B:
PUT config.json version B
```

For concurrent writes, S3 uses last-writer-wins semantics for the current object value.

```text
Final current object:
Whichever write S3 considers latest
```

S3 does not provide application-level locking across concurrent writers, nor does it provide atomic transactions across multiple object keys. Your application must implement coordination when that is required. ([AWS Documentation][1])

## Safer designs

* Use unique versioned object keys.
* Use conditional requests.
* Maintain state in DynamoDB.
* Use application locks.
* Enable S3 Versioning.
* Avoid several systems overwriting the same key.

---

# 13. Durability versus availability

These terms are different.

## Durability

```text
Will my stored object be lost?
```

## Availability

```text
Can I access the object right now?
```

A service can preserve your data but temporarily be unavailable.

Many S3 storage classes are designed for `99.999999999%` annual durability, but their designed availability and Availability Zone resiliency differ. S3 One Zone-IA and S3 Express One Zone intentionally store data in one Availability Zone, while the main multi-AZ classes are designed to tolerate an Availability Zone loss. ([AWS Documentation][2])

---

# 14. Storage-class decision model

Choose a storage class using:

```text
How frequently is the object accessed?
How quickly must it be retrieved?
Can it be recreated?
How long will it be retained?
Is retrieval latency acceptable?
Is one-AZ storage acceptable?
Are access patterns predictable?
```

## Decision flow

```text
Frequently accessed?
    → S3 Standard

Unknown or changing access?
    → S3 Intelligent-Tiering

Infrequently accessed but immediate retrieval needed?
    → Standard-IA

Recreatable and one-AZ acceptable?
    → One Zone-IA

Rarely accessed but immediate retrieval needed?
    → Glacier Instant Retrieval

Archive with minutes-to-hours restore?
    → Glacier Flexible Retrieval

Very long archive with hours-to-days restore?
    → Glacier Deep Archive

Extremely low-latency, single-AZ workload?
    → S3 Express One Zone
```

---

# 15. S3 Standard

Use S3 Standard for:

* Active application data.
* Frequently requested assets.
* Current data-lake objects.
* Frequently downloaded files.
* Primary production datasets.

Characteristics include:

```text
Multi-AZ
Millisecond access
No minimum storage duration
No minimum billable object size
```

It is the default storage class when another class is not specified. ([AWS Documentation][2])

---

# 16. S3 Intelligent-Tiering

S3 Intelligent-Tiering monitors object-access patterns and moves eligible objects between access tiers.

Core automatic tiers include:

```text
Frequent Access
Infrequent Access
Archive Instant Access
```

Optional asynchronous archive tiers include:

```text
Archive Access
Deep Archive Access
```

Objects not accessed for 30 consecutive days can move to the Infrequent Access tier, and objects not accessed for 90 days can move to Archive Instant Access. Optional archive tiers can be configured for longer-inactive data. ([AWS Documentation][2])

## Suitable when

* Access patterns are unpredictable.
* Some objects become cold over time.
* Manual lifecycle estimates are unreliable.
* You want millisecond access for normal tiers.

## Small-object warning

Objects smaller than 128 KB are not monitored for automatic tiering and remain in the Frequent Access tier. Intelligent-Tiering also has per-object monitoring charges. ([AWS Documentation][2])

---

# 17. S3 Standard-IA

IA means:

```text
Infrequent Access
```

Use Standard-IA for:

* Backups.
* Older application files.
* Disaster-recovery copies.
* Data accessed roughly monthly.
* Objects requiring millisecond retrieval.

Characteristics:

```text
Multi-AZ
Millisecond access
Retrieval fee
30-day minimum storage duration
128 KB minimum billable size
```

Deleting or transitioning an object earlier than 30 days can result in charges for the remaining minimum-duration period. ([AWS Documentation][2])

---

# 18. S3 One Zone-IA

One Zone-IA is designed for infrequently accessed data stored in a single Availability Zone.

Use it for:

* Reproducible data.
* Secondary copies.
* Replication destinations when another authoritative copy exists.
* Data that can be regenerated after an AZ disaster.

Characteristics:

```text
One Availability Zone
Millisecond retrieval
30-day minimum duration
128 KB minimum billable size
Retrieval fee
```

It is not resilient to the physical loss of its Availability Zone. ([AWS Documentation][2])

---

# 19. S3 Glacier Instant Retrieval

Use Glacier Instant Retrieval when:

```text
Data is rarely accessed
but must be available immediately.
```

Examples:

* Medical-image archives occasionally viewed.
* Historical media assets.
* Old customer records with immediate retrieval requirements.

Characteristics:

```text
Millisecond access
90-day minimum duration
128 KB minimum billable size
Retrieval charges
```

Unlike Glacier Flexible Retrieval and Deep Archive, it does not require a restore operation before reading the object. ([AWS Documentation][2])

---

# 20. S3 Glacier Flexible Retrieval

Use Glacier Flexible Retrieval for archives accessed infrequently where minutes-to-hours restoration is acceptable.

Typical use cases:

* Backup archives.
* Disaster-recovery datasets.
* Historical records.
* Media archives.
* Compliance data.

Characteristics:

```text
90-day minimum duration
Restore required
Retrieval from minutes to hours
```

Depending on the retrieval option, Flexible Retrieval can provide expedited, standard or bulk retrieval behavior. Standard retrieval commonly takes several hours, while expedited retrieval is available for eligible cases. ([AWS Documentation][3])

---

# 21. S3 Glacier Deep Archive

Use Deep Archive for data accessed less than once a year.

Examples:

* Long-term financial records.
* Regulatory archives.
* Historical backups.
* Data that must be preserved but rarely read.

Characteristics:

```text
180-day minimum duration
Restore required
Standard restore measured in hours
Bulk restore may take considerably longer
```

Deep Archive provides the lowest-cost long-term S3 archive tier but has the slowest retrieval. ([AWS Documentation][3])

---

# 22. S3 Express One Zone

S3 Express One Zone is intended for workloads requiring extremely low latency and very high request performance within one Availability Zone.

Suitable examples:

* Machine-learning training checkpoints.
* High-performance analytics.
* Media processing.
* Frequently accessed temporary datasets.
* Data colocated with compute.

It uses directory buckets and stores data on multiple devices within one selected Availability Zone. It is therefore not a multi-AZ replacement for S3 Standard. ([AWS Documentation][2])

---

# 23. S3 Lifecycle

S3 Lifecycle automatically manages objects as they age.

It supports two broad actions:

```text
Transition:
Move an object to another storage class.

Expiration:
Delete an object or version after a specified period.
```

Example:

```text
Day 0:
S3 Standard

Day 30:
S3 Standard-IA

Day 90:
Glacier Flexible Retrieval

Day 365:
Glacier Deep Archive

Day 2,555:
Delete
```

Lifecycle rules can apply to objects selected by prefix, tags, object size and other supported filters. ([AWS Documentation][4])

---

# 24. Lifecycle design example

For application logs:

```text
Prefix:
logs/

0–30 days:
S3 Standard

31–90 days:
S3 Standard-IA

91–365 days:
Glacier Flexible Retrieval

After 7 years:
Expire
```

Before creating this rule, determine:

* Compliance-retention requirements.
* Restore-time requirements.
* Minimum-storage-duration charges.
* Whether Object Lock applies.
* Whether old versions must also be managed.

---

# 25. Lifecycle and minimum durations

Lifecycle transition does not remove minimum-duration economics.

For example:

```text
Object enters Standard-IA
        ↓
Deleted after 5 days
        ↓
30-day minimum charge may still apply
```

Minimum durations include:

```text
Standard-IA:
30 days

One Zone-IA:
30 days

Glacier Instant Retrieval:
90 days

Glacier Flexible Retrieval:
90 days

Glacier Deep Archive:
180 days
```

Design lifecycle timelines so objects are not repeatedly transitioned or deleted before the target class’s minimum duration. ([AWS Documentation][2])

---

# 26. Versioning

S3 Versioning preserves multiple complete versions of an object.

Example:

```text
config.json
├── Version 1
├── Version 2
└── Version 3 — current
```

When an object is overwritten:

```text
Old object:
Remains as noncurrent version

New object:
Becomes current version
```

Each version is stored and billed as a complete object, not merely as the difference from the previous version. ([AWS Documentation][5])

---

# 27. Delete markers

In a versioning-enabled bucket, a normal delete does not immediately remove every version.

```text
DELETE reports/app.csv
        ↓
S3 creates delete marker
        ↓
Delete marker becomes current version
        ↓
Normal GET appears as though object is deleted
```

Older versions remain and can be restored by removing the delete marker or copying an earlier version into a new current version. ([AWS Documentation][5])

---

# 28. Restore an accidentally deleted object

List versions:

```bash
aws s3api list-object-versions \
  --bucket production-data \
  --prefix reports/app.csv
```

Delete the current delete marker:

```bash
aws s3api delete-object \
  --bucket production-data \
  --key reports/app.csv \
  --version-id DELETE_MARKER_VERSION_ID
```

The previous object version becomes visible again.

Alternatively, copy a selected old version to the current key.

---

# 29. Versioning cost problem

Suppose a 5 GiB backup file is overwritten daily:

```text
Day 1:
5 GiB

Day 2:
Another complete 5 GiB version

After 30 days:
Approximately 150 GiB stored
```

Versioning is powerful, but without lifecycle management, noncurrent versions can produce unexpectedly high storage costs.

Configure rules for:

* Noncurrent-version transition.
* Noncurrent-version expiration.
* Expired-object delete markers.
* Incomplete multipart uploads.

---

# 30. Versioning cannot be completely disabled again

Versioning states are conceptually:

```text
Unversioned
Enabled
Suspended
```

After enabling versioning, you can suspend creation of new version IDs, but old versions remain stored until explicitly deleted.

Suspending versioning is not the same as returning the bucket to its original unversioned history.

---

# 31. S3 Object Lock

S3 Object Lock provides WORM protection:

```text
Write Once
Read Many
```

It prevents protected object versions from being overwritten or permanently deleted for a defined retention period or while a legal hold exists. Object Lock works with versioned buckets and applies to specific object versions. ([AWS Documentation][6])

Use cases:

* Financial records.
* Audit logs.
* Legal evidence.
* Backup-ransomware protection.
* Regulatory archives.
* Immutable system records.

---

# 32. Governance mode

Governance mode prevents ordinary users from deleting or changing protected object versions.

However, specially authorised identities can bypass retention when they have:

```text
s3:BypassGovernanceRetention
```

and explicitly request the bypass.

Use Governance mode for:

* Testing retention.
* Internal operational protection.
* Cases requiring controlled emergency override.

([AWS Documentation][6])

---

# 33. Compliance mode

Compliance mode provides stronger protection.

During the retention period:

```text
Object version cannot be deleted.
Retention cannot be shortened.
Retention mode cannot be changed.
Root user cannot bypass it.
```

AWS documentation states that deleting the AWS account is the only way to eliminate an object locked in Compliance mode before its retention date. ([AWS Documentation][6])

## Warning

Never deploy Compliance mode without:

* Legal review.
* Retention-policy approval.
* Cost review.
* Test environment validation.
* Separate lifecycle planning.

A mistaken ten-year retention can become a ten-year storage obligation.

---

# 34. Legal hold

A legal hold protects an object version without a fixed expiry time.

```text
Retention period:
Ends at a defined date.

Legal hold:
Continues until explicitly removed.
```

An object version can have both:

```text
Retention period
+
Legal hold
```

Removing one does not remove the other. ([AWS Documentation][6])

---

# 35. Object Lock does not prevent new versions

Suppose:

```text
audit.log version 1:
Compliance locked

PUT audit.log again:
Creates version 2
```

The original version remains protected, while the new version has its own independent retention configuration.

A normal delete can still place a delete marker above a protected version, but the protected version cannot be permanently deleted before its retention allows it. ([AWS Documentation][6])

---

# 36. Same-Region Replication

Same-Region Replication copies eligible objects to another bucket in the same AWS Region.

Use cases:

* Replicate data into another account.
* Aggregate logs.
* Separate production and analytics ownership.
* Meet same-country data-residency requirements.
* Maintain an independently controlled copy.

Example:

```text
Application account bucket
        |
        | SRR
        v
Security account archive bucket
```

([AWS Documentation][7])

---

# 37. Cross-Region Replication

Cross-Region Replication copies objects asynchronously between buckets in different AWS Regions.

Example:

```text
Source:
ap-south-1

Destination:
ap-southeast-1
```

Use cases:

* Disaster recovery.
* Geographic separation.
* Regional access latency.
* Regulatory copies.
* Multi-Region data processing.

Source and destination buckets must be configured for versioning, and the replication role must have appropriate source, destination and KMS permissions. ([AWS Documentation][8])

---

# 38. Replication is asynchronous

A successful source upload does not mean the destination replica already exists.

```text
PUT source object succeeds
        ↓
Replication queued
        ↓
Destination copy created later
```

Therefore, ordinary replication alone does not guarantee:

```text
RPO = 0
```

Applications must monitor replication status and define an acceptable recovery-point objective.

---

# 39. S3 Replication Time Control

S3 Replication Time Control adds predictable replication behavior.

AWS provides an SLA for replicating `99.99%` of new objects within 15 minutes when RTC is configured. RTC can be used with same-Region or cross-Region replication and has additional charges. ([AWS Documentation][9])

Use RTC when:

* Compliance requires predictable replication.
* DR RPO must be measured.
* Replication latency must be monitored.
* A 15-minute replication target is acceptable.

---

# 40. Batch Replication

Live replication primarily handles newly created or updated objects after replication is configured.

Batch Replication handles existing objects on demand.

Use it to:

* Replicate objects created before the live rule.
* Retry failed replication.
* Replicate previously replicated objects.
* Populate a newly added destination.
* Perform controlled migration.

Batch Replication is run through S3 Batch Operations and is not covered by the RTC 15-minute SLA. ([AWS Documentation][10])

---

# 41. Replication and KMS encryption

For SSE-KMS objects, the replication role may need:

```text
Source KMS:
kms:Decrypt

Destination KMS:
kms:Encrypt
kms:GenerateDataKey
```

The KMS key policies must also permit the replication role.

Cross-account encryption requires coordinating:

* Source bucket policy.
* Destination bucket policy.
* IAM replication role.
* Source KMS key policy.
* Destination KMS key policy.

([AWS Documentation][11])

---

# 42. Two-way replication

Two-way replication allows objects and supported metadata changes to be synchronised in both directions.

```text
Bucket A
   ⇄
Bucket B
```

Use it carefully for multi-Region active-active storage.

Without two-way replication during Regional failover:

```text
Application writes to DR bucket
        ↓
Primary Region returns
        ↓
Primary bucket may not contain DR writes
```

AWS recommends two-way replication when using Multi-Region Access Point failover controls and expecting writes in both Regions. ([AWS Documentation][7])

---

# 43. Multi-Region Access Points

An S3 Multi-Region Access Point provides one global endpoint in front of buckets in multiple AWS Regions.

```text
Application
     |
     | Global S3 endpoint
     v
Multi-Region Access Point
     |
     ├── Bucket in ap-south-1
     └── Bucket in ap-southeast-1
```

Requests are routed using the AWS global network toward an active bucket with close proximity, and failover controls can shift request traffic between Regions. Replication remains a separate configuration that synchronises the underlying bucket data. ([AWS Documentation][12])

## Important distinction

```text
Multi-Region Access Point:
Routes requests.

Replication:
Copies objects.
```

One does not replace the other.

---

# 44. S3 Access Points

An S3 Access Point is a named endpoint with its own access policy.

Example:

```text
Shared data bucket
├── analytics-access-point
├── application-read-access-point
├── partner-upload-access-point
└── security-audit-access-point
```

Each access point can present a different permission model for the same underlying bucket.

Access points simplify large shared-dataset policies and can be restricted to requests originating from a selected VPC. ([AWS Documentation][1])

---

# 45. Why use Access Points?

Without access points:

```text
One large bucket policy
containing rules for:
- Analytics
- Application
- Security
- Partners
- Data science
```

With access points:

```text
Each use case:
Dedicated endpoint
+
Dedicated policy
+
Optional VPC restriction
```

This reduces the complexity and blast radius of one extremely large bucket policy.

---

# 46. VPC-restricted Access Point

Architecture:

```text
EC2 in production VPC
        |
        v
VPC-only S3 Access Point
        |
        v
Private S3 bucket
```

Use this when S3 data should be accessible only through a trusted VPC network path.

Also evaluate:

* S3 gateway endpoint.
* Endpoint policy.
* Bucket policy.
* Access-point policy.
* IAM identity policy.

All applicable policy layers must allow access.

---

# 47. Object Ownership

S3 Object Ownership determines how uploaded objects are owned and whether ACLs are used.

The default setting for new buckets is:

```text
Bucket owner enforced
```

With this setting:

* ACLs are disabled.
* Bucket owner owns all objects.
* Access is controlled using policies.
* Uploads attempting unsupported ACLs fail.

AWS recommends keeping ACLs disabled for most modern workloads. ([AWS Documentation][13])

---

# 48. Why disable ACLs?

ACLs create additional permission complexity:

```text
IAM policy
+
Bucket policy
+
Object ACL
+
Bucket ACL
```

With Bucket owner enforced:

```text
IAM policies
+
Bucket policies
+
Access point policies
+
Organization and endpoint policies
```

This makes ownership and authorization easier to reason about.

---

# 49. `AccessControlListNotSupported`

Error:

```text
AccessControlListNotSupported
```

Typical cause:

```text
Bucket owner enforced is enabled,
but uploader sends an ACL such as public-read.
```

Bad:

```bash
aws s3 cp file.txt s3://production-bucket/ \
  --acl public-read
```

Better:

```bash
aws s3 cp file.txt s3://production-bucket/
```

With ACLs disabled, permissions must come from policies instead. ([AWS Documentation][13])

---

# 50. Block Public Access

S3 Block Public Access provides settings at:

```text
Organization
Account
Bucket
Access point
```

It prevents public access granted through policies or ACLs according to the enabled settings.

AWS recommends keeping Block Public Access enabled unless public access is an intentional, reviewed requirement. New buckets and access points are private by default. ([AWS Documentation][14])

## Production rule

```text
Private bucket:
Block Public Access enabled.

Public website:
Prefer private bucket + CloudFront OAC.

Direct public S3:
Exceptional, documented requirement.
```

---

# 51. Bucket policy resource ARNs

Bucket-level actions use the bucket ARN:

```text
arn:aws:s3:::production-data
```

Object-level actions use:

```text
arn:aws:s3:::production-data/*
```

Example:

```json
{
  "Effect": "Allow",
  "Action": "s3:ListBucket",
  "Resource": "arn:aws:s3:::production-data"
}
```

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::production-data/*"
}
```

Mixing these resources incorrectly is a common cause of `AccessDenied`.

---

# 52. Deny non-TLS access

Bucket policy:

```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::production-data",
    "arn:aws:s3:::production-data/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

This explicitly denies requests sent without TLS.

---

# 53. Restrict access to your AWS Organization

```json
{
  "Sid": "DenyOutsideOrganization",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::production-data",
    "arn:aws:s3:::production-data/*"
  ],
  "Condition": {
    "StringNotEquals": {
      "aws:PrincipalOrgID": "o-exampleorgid"
    }
  }
}
```

This type of control must be reviewed for AWS services or external integrations that legitimately need access.

---

# 54. S3 default encryption

All new S3 objects are encrypted by default using server-side encryption with Amazon S3 managed keys, SSE-S3, even if you do not configure another default encryption option. ([AWS Documentation][15])

You can instead configure:

```text
SSE-S3
SSE-KMS
DSSE-KMS
```

at the bucket level for new objects.

---

# 55. SSE-S3

With SSE-S3:

```text
S3 manages the encryption key.
```

Advantages:

* Simple.
* Automatic.
* No separate KMS permissions.
* No direct KMS request charges.
* Appropriate for many general workloads.

Limitations:

* No customer-controlled key policy.
* No independent KMS key disablement.
* Less detailed key-level audit and separation.

---

# 56. SSE-KMS

With SSE-KMS:

```text
S3 encrypts object data
using a data key protected by AWS KMS.
```

Advantages:

* Customer managed key option.
* KMS key policy.
* CloudTrail KMS activity.
* Cross-account control.
* Key disablement.
* Rotation and compliance controls.

Access requires both:

```text
S3 permission
+
KMS permission
```

([AWS Documentation][16])

---

# 57. DSSE-KMS

DSSE-KMS means:

```text
Dual-layer server-side encryption
with AWS KMS keys
```

It applies two independent encryption layers for workloads with regulatory or compliance requirements for dual-layer encryption.

Use it when explicitly required by:

* Compliance.
* Data-classification policy.
* Contractual encryption requirements.

Do not select it merely because “more encryption sounds better”; it adds cost and operational considerations.

---

# 58. S3 Bucket Keys

For ordinary SSE-KMS without a Bucket Key, large object-access workloads can generate many KMS requests.

S3 Bucket Keys introduce a temporary bucket-level key used by S3 to derive object data keys, reducing direct request volume to KMS.

AWS states that S3 Bucket Keys can reduce KMS request costs by up to 99% for suitable workloads. They are supported for SSE-KMS but not DSSE-KMS. ([AWS Documentation][17])

Enable them when:

* Many objects use the same KMS key.
* Request volume is high.
* KMS request cost or quota pressure matters.

---

# 59. Bucket Key policy consideration

After S3 obtains and caches an S3 Bucket Key for a requester, subsequent object operations using that Bucket Key may not produce a separate KMS API call for every S3 request.

This reduces cost but changes the granularity of KMS CloudTrail activity.

Do not assume:

```text
Every GetObject
=
One KMS Decrypt event
```

when Bucket Keys are enabled. ([AWS Documentation][17])

---

# 60. Client-side encryption

With client-side encryption:

```text
Application encrypts data before sending it to S3.
```

S3 stores ciphertext and may have no ability to interpret the plaintext.

Use cases:

* End-to-end encryption.
* Customer-controlled cryptography.
* Sensitive multi-tenant applications.
* Requirements preventing plaintext exposure to the storage service.

Responsibilities increase:

* Key management.
* Encryption metadata.
* Data-key handling.
* Rotation.
* Recovery.
* Application compatibility.

---

# 61. Presigned URLs

A presigned URL grants temporary access to one S3 operation using the permissions of the signing principal.

Common uses:

```text
Temporary download
Browser upload
Mobile upload
Customer file delivery
```

Architecture:

```text
1. User authenticates with application.
2. Application authorises upload.
3. Application generates presigned URL.
4. Browser uploads directly to S3.
```

This avoids routing large files through the application server.

## Security warning

A presigned URL is a bearer capability.

Anyone who obtains it may use it until:

* It expires.
* The underlying credentials expire.
* The operation is otherwise denied.

Never log long-lived presigned URLs containing sensitive access.

---

# 62. Multipart upload

Multipart upload divides one large object into independently uploadable parts.

```text
Large file
├── Part 1
├── Part 2
├── Part 3
└── Part N
```

Advantages:

* Upload parts in parallel.
* Retry only failed parts.
* Resume a failed workflow.
* Improve large-file throughput.
* Upload before total object creation completes.

AWS recommends considering multipart upload around 100 MB and larger. A multipart object can currently contain up to 10,000 parts; each normal part must be between 5 MiB and 5 GiB, except the final part, which can be smaller. The current maximum object size documented for multipart upload is 48.8 TiB. ([AWS Documentation][18])

---

# 63. Multipart upload lifecycle

Flow:

```text
1. CreateMultipartUpload
2. UploadPart repeatedly
3. CompleteMultipartUpload
```

If the upload is abandoned:

```text
Uploaded parts remain stored
and continue generating storage charges
until completed or aborted.
```

Always configure a lifecycle rule such as:

```text
Abort incomplete multipart uploads after 7 days.
```

---

# 64. Multipart part-size planning

Suppose the object size is:

```text
1 TiB
```

If each part were only 5 MiB:

```text
Too many parts
```

Since the maximum is 10,000 parts, part size must increase for larger objects.

Simple planning:

```text
Minimum practical part size
≈ total object size / 10,000
```

Use larger part sizes such as:

```text
64 MiB
128 MiB
256 MiB
512 MiB
```

according to file size, memory, network reliability and concurrency.

---

# 65. Checksums

Checksums help verify that object contents were not corrupted during transfer or storage workflows.

Common algorithms supported in modern S3 workflows include:

```text
CRC variants
SHA-1
SHA-256
MD5-related ETag behavior in limited cases
```

Do not assume the S3 ETag is always the MD5 checksum.

For example, multipart-upload ETags are not generally a simple whole-object MD5 value.

Use explicit checksum features when end-to-end integrity validation is important.

---

# 66. Event notifications

S3 can publish events for activities such as:

* Object creation.
* Object deletion.
* Restore events.
* Replication events.
* Lifecycle transitions and expirations.
* Object tagging.
* Intelligent-Tiering archival events.

Destinations include:

```text
SNS
SQS
Lambda
EventBridge
```

S3 event notifications are designed for at-least-once delivery and are usually delivered quickly, but they can occasionally take longer. ([AWS Documentation][19])

---

# 67. At-least-once means duplicates

At-least-once delivery means:

```text
An event should arrive,
but the same event may arrive more than once.
```

Your consumer must be idempotent.

Bad:

```text
Every event:
Charge customer $10
```

A duplicate event could create a duplicate charge.

Better:

```text
Store event or object version ID
        ↓
Check whether already processed
        ↓
Process once logically
```

Use idempotency keys such as:

* Bucket.
* Object key.
* Version ID.
* Event name.
* S3 sequencer where applicable.
* Application transaction ID.

---

# 68. Event-driven processing architecture

```text
User uploads image
        |
        v
S3 incoming/ prefix
        |
        v
S3 event
        |
        v
SQS queue
        |
        v
Lambda or container workers
        |
        v
Resize and scan image
        |
        v
S3 processed/ prefix
```

Why include SQS?

* Buffers traffic.
* Provides retries.
* Supports dead-letter queues.
* Separates upload rate from processing capacity.
* Prevents Lambda concurrency spikes from directly matching every upload spike.

---

# 69. Avoid notification loops

Dangerous architecture:

```text
Upload object to bucket
        ↓
Lambda triggered
        ↓
Lambda writes result into same matching prefix
        ↓
Lambda triggered again
        ↓
Infinite loop
```

Safer options:

```text
Input:
incoming/

Output:
processed/
```

Configure event filtering only for:

```text
incoming/
```

Or use separate source and destination buckets. AWS explicitly warns that writing to the same trigger scope can create an execution loop. ([AWS Documentation][19])

---

# 70. SQS FIFO event delivery

S3 native event notifications do not directly support SQS FIFO queues.

When FIFO behavior is required:

```text
S3
  ↓
EventBridge
  ↓
SQS FIFO
```

([AWS Documentation][19])

Even with FIFO, you must still design carefully around event ordering, object versions and idempotency.

---

# 71. Object metadata

Objects can contain system metadata such as:

```text
Content-Type
Content-Length
Last-Modified
ETag
Storage class
Encryption type
```

Custom metadata can be added during upload:

```text
x-amz-meta-uploaded-by
x-amz-meta-customer-id
x-amz-meta-document-type
```

Custom metadata is generally set when the object is written. Changing metadata commonly requires copying or replacing the object.

---

# 72. Object tags

Object tags are key-value labels associated with an object.

Example:

```text
Environment = Production
Classification = Confidential
Retention = SevenYears
Project = TodoApp
```

Tags can be used for:

* Lifecycle rules.
* Replication selection.
* IAM conditions.
* Cost allocation.
* Batch Operations.
* Governance.

Do not put secrets into tags because tag values can appear in logs and management APIs.

---

# 73. S3 Inventory

S3 Inventory generates scheduled reports containing object metadata.

Possible report fields include:

* Object key.
* Version ID.
* Size.
* Storage class.
* Encryption status.
* Replication status.
* Object Lock status.
* ETag.
* Last modified date.

Use Inventory for:

* Compliance evidence.
* Finding unencrypted objects.
* Identifying old versions.
* Preparing Batch Operations.
* Replication analysis.
* Storage-class auditing.

S3 Inventory is generally better than repeatedly performing huge object listings for large-scale auditing. ([AWS Documentation][1])

---

# 74. S3 Batch Operations

S3 Batch Operations performs actions across very large object sets.

Supported examples include:

* Copy objects.
* Restore archived objects.
* Invoke Lambda.
* Apply tags.
* Modify Object Lock retention.
* Replicate existing objects.

Input commonly comes from:

```text
S3 Inventory report
or
Custom manifest
```

S3 Batch Operations is designed to manage millions or billions of objects through one managed job. ([AWS Documentation][1])

---

# 75. S3 Storage Lens

S3 Storage Lens provides organisation-wide storage analytics.

It can aggregate usage and activity across:

```text
Organizations
Accounts
Regions
Buckets
Prefixes
```

Use it to identify:

* Unused storage.
* Old versions.
* Incomplete multipart uploads.
* Encryption posture.
* Public-access posture.
* Storage-class distribution.
* Cost-optimisation opportunities.

S3 Storage Lens provides dozens of metrics and dashboards for storage analysis. ([AWS Documentation][1])

---

# 76. S3 logging options

## CloudTrail management events

Tracks bucket-management actions such as:

```text
CreateBucket
PutBucketPolicy
PutBucketVersioning
DeleteBucket
```

## CloudTrail data events

Tracks object-level operations such as:

```text
GetObject
PutObject
DeleteObject
```

Data events must be explicitly configured for continuous detailed object-level tracking and can generate significant event volume.

## Server access logging

Produces detailed request logs delivered to another S3 location.

## CloudWatch request metrics

Provides operational request and error metrics.

S3 supports CloudTrail, server access logging and CloudWatch-based monitoring for different audit and operational needs. ([AWS Documentation][1])

---

# 77. Security monitoring

Monitor high-risk S3 events:

```text
PutBucketPolicy
DeleteBucketPolicy
PutBucketPublicAccessBlock
DeletePublicAccessBlock
PutBucketAcl
PutObjectAcl
DeleteBucketEncryption
PutBucketVersioning
PutObjectRetention
BypassGovernanceRetention
DeleteObject
DeleteObjects
```

Combine:

```text
CloudTrail
EventBridge
SNS
Security Hub
AWS Config
IAM Access Analyzer
Macie
```

---

# 78. Cost model

S3 costs can include:

```text
Stored data
Requests
Retrievals
Data transfer
Lifecycle transitions
Replication
Inventory
Storage Lens advanced metrics
KMS requests
Object monitoring
Early deletion
Restore copies
Multipart parts
```

Do not optimise only storage cost per GiB.

Example:

```text
Very small objects in an archive class
```

may generate:

* Minimum billable-size charges.
* Per-object request charges.
* Metadata overhead.
* Retrieval charges.

Cost optimisation must consider object size, access rate and retention period together.

---

# 79. Production Terraform bucket

```hcl
resource "aws_s3_bucket" "application_data" {
  bucket = "${var.account_id}-${var.environment}-todoapp-data"

  tags = {
    Name        = "${var.environment}-todoapp-data"
    Environment = var.environment
    Application = "TodoApp"
    ManagedBy   = "Terraform"
  }
}
```

---

# 80. Block Public Access

```hcl
resource "aws_s3_bucket_public_access_block" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

---

# 81. Object Ownership

```hcl
resource "aws_s3_bucket_ownership_controls" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
```

This disables ACL-based permission management.

---

# 82. Versioning

```hcl
resource "aws_s3_bucket_versioning" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

---

# 83. SSE-KMS encryption

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}
```

---

# 84. Lifecycle configuration

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "application_data" {
  bucket = aws_s3_bucket.application_data.id

  depends_on = [
    aws_s3_bucket_versioning.application_data
  ]

  rule {
    id     = "application-data-lifecycle"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

Verify lifecycle transitions against the object-size and minimum-duration economics of the selected storage classes.

---

# 85. TLS-only bucket policy

```hcl
data "aws_iam_policy_document" "application_data" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.application_data.arn,
      "${aws_s3_bucket.application_data.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "application_data" {
  bucket = aws_s3_bucket.application_data.id
  policy = data.aws_iam_policy_document.application_data.json
}
```

---

# 86. Cross-Region Replication Terraform concept

Source bucket role:

```hcl
resource "aws_iam_role" "replication" {
  name = "${var.environment}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "s3.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

Replication configuration:

```hcl
resource "aws_s3_bucket_replication_configuration" "application_data" {
  bucket = aws_s3_bucket.application_data.id
  role   = aws_iam_role.replication.arn

  depends_on = [
    aws_s3_bucket_versioning.application_data,
    aws_s3_bucket_versioning.dr
  ]

  rule {
    id     = "replicate-to-dr"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.dr.arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }
}
```

The full IAM and KMS policies must permit reading source versions, decrypting source data, writing destination versions and encrypting under the destination key.

---

# 87. Event notification Terraform

```hcl
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.application_data.id

  queue {
    queue_arn = aws_sqs_queue.image_processing.arn

    events = [
      "s3:ObjectCreated:*"
    ]

    filter_prefix = "incoming/"
    filter_suffix = ".jpg"
  }

  depends_on = [
    aws_sqs_queue_policy.image_processing
  ]
}
```

Consumer design must remain idempotent because notifications are delivered at least once.

---

# 88. AWS CLI validation

Check bucket Region:

```bash
aws s3api get-bucket-location \
  --bucket production-data
```

Check versioning:

```bash
aws s3api get-bucket-versioning \
  --bucket production-data
```

Check encryption:

```bash
aws s3api get-bucket-encryption \
  --bucket production-data
```

Check public-access protection:

```bash
aws s3api get-public-access-block \
  --bucket production-data
```

Check ownership:

```bash
aws s3api get-bucket-ownership-controls \
  --bucket production-data
```

Check lifecycle:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket production-data
```

Check replication:

```bash
aws s3api get-bucket-replication \
  --bucket production-data
```

---

# 89. Troubleshooting: `AccessDenied`

An S3 `403 AccessDenied` can come from several layers:

```text
IAM identity policy
Bucket policy
Access point policy
Object ACL
Permissions boundary
Session policy
SCP
RCP
VPC endpoint policy
KMS key policy
Block Public Access
Object Lock
```

Troubleshooting sequence:

```text
1. aws sts get-caller-identity
2. Confirm exact bucket, key and Region.
3. Identify the exact API action.
4. Review IAM policy.
5. Review bucket or access-point policy.
6. Review Block Public Access.
7. Review Object Ownership.
8. Review endpoint policy.
9. Review KMS permissions.
10. Review SCP/RCP.
11. Inspect CloudTrail.
```

---

# 90. Troubleshooting: bucket exists but Terraform cannot create it

Errors:

```text
BucketAlreadyExists
BucketAlreadyOwnedByYou
```

## `BucketAlreadyExists`

Another AWS account owns the globally named bucket.

Fix:

```text
Choose another bucket name.
```

## `BucketAlreadyOwnedByYou`

Your account already owns the bucket.

Fix options:

```text
Import it into Terraform.
Use the existing state resource.
Remove duplicate configuration.
```

Import:

```bash
terraform import \
  aws_s3_bucket.application_data \
  existing-bucket-name
```

---

# 91. Troubleshooting: wrong Region

Symptoms may include:

```text
PermanentRedirect
AuthorizationHeaderMalformed
Incorrect endpoint
```

Cause:

```text
Bucket is in ap-south-1
but request is signed for us-east-1.
```

Check:

```bash
aws s3api get-bucket-location \
  --bucket production-data
```

Then configure the SDK or CLI with the correct Region.

---

# 92. Troubleshooting: SSE-KMS access denied

Requirements for `GetObject`:

```text
s3:GetObject
+
kms:Decrypt
+
Bucket policy permits access
+
KMS key policy permits access
```

Requirements for upload can include:

```text
s3:PutObject
+
kms:GenerateDataKey
+
kms:Encrypt-related access
```

Also check:

* Key Region.
* Key enabled state.
* Encryption-context conditions.
* Cross-account key policy.
* VPC endpoint policy.

---

# 93. Troubleshooting: replication status failed

Possible causes:

* Replication role missing permission.
* Destination policy rejects role.
* Destination bucket versioning disabled.
* KMS source decrypt denied.
* KMS destination encrypt denied.
* Object existed before rule creation.
* Replication rule filter does not match.
* Object is owned or encrypted differently than expected.
* Object Lock destination configuration is incompatible.
* Destination storage class is invalid.

Check object replication status:

```bash
aws s3api head-object \
  --bucket source-bucket \
  --key path/object.txt
```

Review:

```text
ReplicationStatus
```

Use Batch Replication for eligible older or failed objects.

---

# 94. Troubleshooting: lifecycle did not transition

Possible causes:

* Rule status disabled.
* Prefix or tag filter does not match.
* Object is too small for the configured transition behavior.
* Minimum transition rules prevent movement.
* Object is already in another class.
* Noncurrent rule used for a current object.
* Object Lock prevents expiration.
* Lifecycle processing has not completed yet.

Lifecycle is an asynchronous managed process; do not expect a transition at the exact second an object reaches the specified age.

---

# 95. Troubleshooting: Glacier object cannot be downloaded

Error:

```text
InvalidObjectState
```

Cause:

```text
Object is archived in Glacier Flexible Retrieval
or Glacier Deep Archive.
```

Restore:

```bash
aws s3api restore-object \
  --bucket archive-bucket \
  --key records/2020/report.zip \
  --restore-request '{
    "Days": 7,
    "GlacierJobParameters": {
      "Tier": "Standard"
    }
  }'
```

The restore creates a temporary accessible copy while the archived object remains in its archive storage class. ([AWS Documentation][20])

---

# 96. Troubleshooting: duplicate event processing

Symptoms:

```text
Same image processed twice
Duplicate database rows
Repeated notifications
```

Cause:

```text
S3 events are delivered at least once.
```

Fix:

```text
Create idempotency record using:
bucket + key + version ID + event type
```

For example:

```text
DynamoDB conditional PutItem
        ↓
If record already exists:
Skip processing
```

---

# 97. Troubleshooting: incomplete multipart-upload cost

Symptoms:

```text
Bucket appears to contain little completed data
but storage usage continues growing.
```

Possible cause:

```text
Abandoned multipart-upload parts
```

List:

```bash
aws s3api list-multipart-uploads \
  --bucket production-data
```

Abort one:

```bash
aws s3api abort-multipart-upload \
  --bucket production-data \
  --key large-file.bin \
  --upload-id UPLOAD_ID
```

Prevent recurrence using a lifecycle abort rule.

---

# 98. Troubleshooting: CloudFront returns S3 403

Check:

```text
CloudFront uses S3 REST endpoint, not website endpoint
OAC is attached
Bucket policy references correct distribution ARN
Object key exists with exact case
SSE-KMS key policy allows CloudFront
Block Public Access remains enabled
CloudFront origin path is correct
```

S3 object keys are case-sensitive:

```text
Index.html
```

is different from:

```text
index.html
```

---

# 99. Production checklist

```text
[ ] Correct bucket type is selected
[ ] Bucket Region is documented
[ ] Bucket naming convention is standardised
[ ] Block Public Access is enabled
[ ] Object Ownership is Bucket owner enforced
[ ] ACLs are disabled
[ ] Bucket policy denies non-TLS requests
[ ] IAM permissions are least privilege
[ ] Access points are used for complex shared access
[ ] VPC endpoint policies are reviewed
[ ] Default encryption is configured intentionally
[ ] Customer managed KMS key is used where required
[ ] S3 Bucket Keys are considered for SSE-KMS
[ ] KMS key policy is tested
[ ] Versioning is enabled for critical data
[ ] Noncurrent versions have lifecycle rules
[ ] Delete-marker cleanup is configured
[ ] Incomplete multipart uploads are aborted
[ ] Lifecycle transitions respect minimum durations
[ ] Object Lock requirements are legally reviewed
[ ] Governance and Compliance modes are understood
[ ] Replication role is least privilege
[ ] Replication metrics are enabled
[ ] RTC is used when predictable RPO is required
[ ] Existing objects use Batch Replication where required
[ ] Multi-Region failover is tested
[ ] Event consumers are idempotent
[ ] Event-trigger loops are prevented
[ ] Inventory reports are configured
[ ] CloudTrail data events are enabled for sensitive buckets
[ ] Server access logs are protected
[ ] Storage Lens is reviewed
[ ] Presigned URL expiry is short
[ ] Large uploads use multipart upload
[ ] Restore procedures are tested
[ ] Key-deletion and bucket-deletion controls exist
```

---

# 100. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
S3 is managed object storage.

Buckets contain objects.

Storage classes optimise cost.

S3 can store backups, websites, logs and archives.
```

## Solutions Architect Associate

Understand:

```text
S3 Standard versus IA and Glacier
Versioning and delete markers
Lifecycle policies
CRR and SRR
Object Lock
SSE-S3 versus SSE-KMS
Block Public Access
Bucket policies
Presigned URLs
Multipart upload
Event notifications
```

## DevOps Engineer Professional

Understand:

```text
Replication Time Control
Batch Replication
Multi-Region Access Points
KMS policy troubleshooting
Object Lock retention automation
S3 Inventory and Batch Operations
Event-driven idempotency
Cross-account logging buckets
CloudTrail data events
Infrastructure as Code
Cost and lifecycle governance
```

---

# 101. Interview questions

## Question 1: What is Amazon S3?

**Answer:**

Amazon S3 is a managed object-storage service that stores files and associated metadata as objects inside buckets.

## Question 2: What is the difference between a bucket and an object?

**Answer:**

A bucket is the top-level S3 container. An object is the stored data, metadata and key inside the bucket.

## Question 3: Does S3 provide strong consistency?

**Answer:**

Yes. S3 provides strong read-after-write consistency for object PUT, overwrite, DELETE, GET and LIST behavior after successful object operations.

## Question 4: What happens when two clients overwrite the same key?

**Answer:**

S3 uses last-writer-wins semantics for the current value. It does not provide application-level write locking.

## Question 5: What is S3 Versioning?

**Answer:**

Versioning stores multiple complete versions of an object so accidental overwrites and deletes can be recovered.

## Question 6: What is a delete marker?

**Answer:**

It is a special current version created by a normal DELETE in a versioned bucket. It makes the object appear deleted while older versions remain.

## Question 7: What is S3 Lifecycle?

**Answer:**

Lifecycle is a managed rules engine that transitions objects between storage classes or expires objects and versions as they age.

## Question 8: What is the difference between S3 Standard-IA and One Zone-IA?

**Answer:**

Standard-IA stores data across multiple Availability Zones. One Zone-IA stores it in one Availability Zone and is appropriate only when the data can be recreated or exists elsewhere.

## Question 9: What is the difference between Glacier Instant and Glacier Flexible Retrieval?

**Answer:**

Glacier Instant supports immediate millisecond access. Glacier Flexible Retrieval is an archived class that requires a restore operation taking minutes to hours.

## Question 10: What is S3 Object Lock?

**Answer:**

Object Lock provides WORM protection for object versions using retention periods or legal holds.

## Question 11: What is the difference between Governance and Compliance mode?

**Answer:**

Governance mode can be bypassed by specially authorised users. Compliance mode cannot be shortened or bypassed, including by the root user, during the retention period.

## Question 12: What is CRR?

**Answer:**

Cross-Region Replication asynchronously copies eligible objects between versioned buckets in different AWS Regions.

## Question 13: What is S3 RTC?

**Answer:**

Replication Time Control provides an SLA for replicating 99.99% of newly replicated objects within 15 minutes.

## Question 14: What is Batch Replication?

**Answer:**

It is an on-demand process for replicating existing, failed or previously replicated objects using S3 Batch Operations.

## Question 15: What is an S3 Access Point?

**Answer:**

It is a dedicated S3 endpoint with its own access policy, optionally restricted to a VPC, for managing access to a shared bucket.

## Question 16: Why disable S3 ACLs?

**Answer:**

Disabling ACLs simplifies ownership and access by making the bucket owner own all objects and using IAM, bucket and access-point policies for authorization.

## Question 17: What is an S3 Bucket Key?

**Answer:**

It is a temporary bucket-level key used with SSE-KMS to reduce the number of direct KMS requests required for object encryption and decryption.

## Question 18: What is multipart upload?

**Answer:**

It uploads one large object as independently transferable parts that S3 assembles after completion.

## Question 19: Are S3 events delivered exactly once?

**Answer:**

No. They are designed for at-least-once delivery, so consumers must handle duplicates idempotently.

## Question 20: What is a Multi-Region Access Point?

**Answer:**

It provides one global endpoint that routes S3 requests across buckets in multiple AWS Regions. Replication must still be configured separately.

---

# 102. Never-forget revision

```text
S3:
Managed object storage.

Bucket:
Top-level object container.

Object:
Data plus metadata.

Key:
Unique object name.

Versioning:
Stores complete object versions.

Delete marker:
Makes a versioned object appear deleted.

Lifecycle:
Transitions or expires objects.

Standard:
Frequently accessed multi-AZ storage.

Intelligent-Tiering:
Automatically adapts to changing access.

Standard-IA:
Infrequent multi-AZ storage.

One Zone-IA:
Recreatable single-AZ storage.

Glacier Instant:
Rare access with immediate retrieval.

Glacier Flexible:
Archive with minutes-to-hours restore.

Deep Archive:
Longest-term archive.

Express One Zone:
High-performance directory-bucket storage in one AZ.

Object Lock:
WORM protection.

Governance mode:
Privileged bypass is possible.

Compliance mode:
No bypass before retention expiry.

SRR:
Same-Region replication.

CRR:
Cross-Region replication.

RTC:
Predictable replication with a 15-minute SLA.

Batch Replication:
On-demand replication of existing objects.

Access Point:
Dedicated endpoint and policy.

Block Public Access:
Prevents accidental public exposure.

Bucket owner enforced:
Disables ACLs.

SSE-S3:
S3-managed encryption.

SSE-KMS:
KMS-backed encryption.

Bucket Key:
Reduces KMS request volume.

Multipart upload:
Uploads one object as separate parts.

Event notification:
At-least-once change event.
```

## One-line memory trick

```text
Versioning protects history.
Lifecycle controls cost.
Object Lock protects immutability.
Replication protects location.
Encryption protects data.
Policies protect access.
```

## Lesson 33 outcome

You can now design S3 storage where:

```text
Application stores uploads
    → Private, versioned and encrypted bucket.

Old objects become cold
    → Lifecycle moves them to cheaper storage.

User accidentally deletes a file
    → Previous version is restored.

Audit records must remain immutable
    → Object Lock protects them.

Primary Region fails
    → Replicated bucket and Multi-Region Access Point support recovery.

Millions of old objects need migration
    → Inventory and Batch Operations process them.

Large user upload begins
    → Presigned multipart upload sends it directly to S3.

Object arrives
    → EventBridge or SQS starts idempotent processing.
```

**Next lesson: Lesson 34 — AWS storage beyond S3: Amazon EBS, EFS and FSx, volume types, IOPS, throughput, snapshots, Multi-AZ file storage, backups and production storage selection.**

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html "What is Amazon S3? - Amazon Simple Storage Service"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html "Understanding and managing Amazon S3 storage classes - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/glacier-storage-classes.html?utm_source=chatgpt.com "Understanding S3 Glacier storage classes for long-term data ..."
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html "Managing the lifecycle of objects - Amazon Simple Storage Service"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html "Retaining multiple versions of objects with S3 Versioning - Amazon Simple Storage Service"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html "Locking objects with Object Lock - Amazon Simple Storage Service"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html "Replicating objects within and across Regions - Amazon Simple Storage Service"
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-requirements.html?utm_source=chatgpt.com "Requirements and considerations for replication"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPointBucketReplication.html?utm_source=chatgpt.com "Configuring replication for use with Multi-Region Access ..."
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-batch-replication-batch.html?utm_source=chatgpt.com "Replicating existing objects with Batch Replication"
[11]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-config-for-kms-objects.html?utm_source=chatgpt.com "Replicating encrypted objects (SSE-S3, SSE-KMS, DSSE ..."
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPoints.html "Managing multi-Region traffic with Multi-Region Access Points - Amazon Simple Storage Service"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html "Controlling ownership of objects and disabling ACLs for your bucket - Amazon Simple Storage Service"
[14]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html?utm_source=chatgpt.com "Blocking public access to your Amazon S3 storage"
[15]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/update-sse-encryption.html?utm_source=chatgpt.com "Updating server-side encryption for existing data"
[16]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html?utm_source=chatgpt.com "Using server-side encryption with AWS KMS keys (SSE-KMS)"
[17]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html "Reducing the cost of SSE-KMS with Amazon S3 Bucket Keys - Amazon Simple Storage Service"
[18]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html "Amazon S3 multipart upload limits - Amazon Simple Storage Service"
[19]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html "Amazon S3 Event Notifications - Amazon Simple Storage Service"
[20]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/restoring-objects.html?utm_source=chatgpt.com "Restoring an archived object - Amazon Simple Storage Service"
