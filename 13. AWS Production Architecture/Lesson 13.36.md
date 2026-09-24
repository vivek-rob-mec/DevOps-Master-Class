# AWS Masterclass — Phase 3

# Lesson 35: AWS Backup, DataSync, Storage Gateway and Transfer Family

## 1. Lesson objectives

In this lesson, you will learn how to:

* Design a production backup and recovery strategy.
* Distinguish backup, replication, migration, synchronization and archival.
* Create AWS Backup plans, vaults and resource assignments.
* Use point-in-time recovery and scheduled recovery points.
* Protect backups using Vault Lock and logically air-gapped vaults.
* Copy backups across accounts and Regions.
* Automate restore testing.
* Transfer large datasets using AWS DataSync.
* Select DataSync Basic or Enhanced mode.
* Migrate NFS, SMB, HDFS, object and cloud storage.
* Connect on-premises applications to AWS through Storage Gateway.
* Understand S3 File Gateway, Volume Gateway and Tape Gateway.
* Replace self-managed SFTP and FTP infrastructure with AWS Transfer Family.
* Implement SFTP, FTPS, FTP, AS2 and browser-based transfers.
* Secure identities, storage access and network paths.
* Automate these services with Terraform and the AWS CLI.
* Troubleshoot failed backups and data transfers.

---

# 2. Production hybrid-data architecture

A large organisation may use all four services together:

```text
                           Corporate data center
                  ┌──────────────┼──────────────┐
                  |              |              |
             NFS/SMB NAS    Backup system    Business partners
                  |              |              |
                  v              v              v
             AWS DataSync   Storage Gateway  Transfer Family
                  |         Tape Gateway       SFTP / AS2
                  |              |              |
                  └──────────────┼──────────────┘
                                 |
                                 v
                       AWS storage services
                     S3 / EFS / FSx / EBS / RDS
                                 |
                                 v
                            AWS Backup
                      Plans, vaults and copies
                                 |
                    ┌────────────┴─────────────┐
                    |                          |
                    v                          v
          Cross-account backup       Cross-Region backup
                    |                          |
                    └────────────┬─────────────┘
                                 v
                    Logically air-gapped vault
                                 |
                                 v
                         Tested restoration
```

---

# 3. The four-service mental model

```text
AWS Backup:
Protect AWS resources and restore them later.

AWS DataSync:
Move or synchronise file and object data.

AWS Storage Gateway:
Give on-premises applications an AWS-backed
file, block or tape interface.

AWS Transfer Family:
Provide managed external file-transfer protocols.
```

## One-line distinction

```text
Need historical recovery points?
    → AWS Backup

Need to migrate terabytes of files?
    → AWS DataSync

Need local applications to keep using NFS, SMB,
iSCSI or virtual tape?
    → Storage Gateway

Need partners to send files using SFTP, FTPS,
FTP, AS2 or a browser?
    → Transfer Family
```

---

# 4. Backup versus replication versus migration

These terms must not be confused.

## Backup

A historical recovery copy.

```text
Production database at 10:00
        ↓
Backup at 10:00
        ↓
Database corrupted at 14:00
        ↓
Restore 10:00 state
```

## Replication

Maintains another current or near-current copy.

```text
Primary data changes
        ↓
Change copied to replica
```

Problem:

```text
Malicious deletion
        ↓
Deletion may replicate
```

## Migration

Moves a workload or dataset to a new location.

```text
On-premises NFS
        ↓
DataSync
        ↓
Amazon EFS
```

## Synchronisation

Repeatedly copies new or changed data.

## Archive

Stores data for long-term retention, usually with slower access.

## Never-forget rule

```text
Replication improves availability.

Backup protects historical recoverability.

You usually need both.
```

---

# 5. What is AWS Backup?

AWS Backup centralises and automates data protection across supported AWS resources and selected third-party workloads.

It provides:

* Scheduled backup plans.
* On-demand backups.
* Retention management.
* Backup vaults.
* Cross-account management.
* Cross-Region copies.
* Incremental backups for supported resources.
* Continuous backups for selected services.
* Vault Lock.
* Restore testing.
* Audit and compliance reporting.

Supported resources include services such as Amazon EC2, EBS, EFS, RDS, Aurora, DynamoDB, S3, Redshift and several FSx services, although specific features differ by resource and Region. ([AWS Documentation][1])

---

# 6. AWS Backup core resources

The main AWS Backup components are:

```text
Backup plan
Backup rule
Resource assignment
Backup vault
Recovery point
Restore job
Copy job
```

## Backup plan

Defines the overall policy.

Example:

```text
Plan:
ProductionGoldBackup
```

## Backup rule

Defines:

```text
Schedule
Backup window
Vault
Retention
Cold-storage lifecycle
Cross-account copy
Cross-Region copy
Continuous backup setting
```

## Resource assignment

Determines which AWS resources the plan protects.

## Backup vault

A logical container for recovery points.

## Recovery point

A backup that can be used for restoration.

---

# 7. Backup-plan example

```text
Plan:
ProductionGold

Daily rule:
01:00 Asia/Kolkata
Retain 35 days

Weekly rule:
Sunday 02:00
Retain 12 weeks

Monthly rule:
First day of month
Retain 7 years

Copy:
Security backup account

Second copy:
ap-southeast-1
```

The correct schedule comes from business recovery requirements—not from a universal AWS default.

---

# 8. Resource assignment

Resources can be assigned using:

```text
Explicit resource ARNs
Tags
Resource types
AWS Organizations backup policies
```

## Tag-based assignment

Example resource tags:

```text
Backup = Gold
Environment = Production
```

The plan can select resources matching those tags.

Advantages:

* New matching resources are protected automatically.
* Less manual ARN management.
* Policy can scale across accounts.

## Tagging risk

A production resource created without the correct tag may remain unprotected.

Use:

* Tag policies.
* AWS Config.
* Backup Audit Manager.
* Infrastructure as Code.
* Deployment-policy checks.

---

# 9. Scheduled backups versus continuous backups

## Scheduled backup

Creates recovery points at specific times.

Example:

```text
Every 24 hours
```

Potential data loss:

```text
Up to approximately 24 hours
```

depending on when failure occurs.

## Continuous backup

For supported resources, AWS Backup first creates a full backup and then captures ongoing changes or transaction logs.

Point-in-time recovery can restore supported resources to a chosen point with one-second precision, going back up to 35 days. Availability depends on the resource type; for example, AWS Backup supports PITR for supported RDS/Aurora configurations and selected other resources. ([AWS Documentation][2])

---

# 10. RPO and backup frequency

RPO means:

```text
Recovery Point Objective
```

It answers:

```text
How much recent data can the business lose?
```

Examples:

| Backup method    |                        Approximate potential RPO |
| ---------------- | -----------------------------------------------: |
| Daily backup     |                                   Up to 24 hours |
| Hourly backup    |                                     Up to 1 hour |
| Every 15 minutes |                                 Up to 15 minutes |
| PITR             | Potentially seconds/minutes depending on service |

A one-hour backup schedule cannot satisfy a five-minute RPO.

---

# 11. RTO and restoration

RTO means:

```text
Recovery Time Objective
```

It answers:

```text
How quickly must the workload be restored?
```

Restore time depends on:

* Resource type.
* Backup size.
* Region.
* Infrastructure creation.
* Database recovery.
* Network configuration.
* Capacity availability.
* Application validation.

AWS Backup restores commonly create a new resource rather than overwriting the original, and AWS does not provide one universal restore-time SLA for all restore operations. ([AWS Documentation][3])

---

# 12. Incremental backups

For supported resources:

```text
First backup:
Full data copy

Later backups:
Changed data only
```

This reduces duplicate backup storage while preserving independent recovery points.

AWS Backup handles the underlying dependency chain; deleting one incremental recovery point does not ordinarily require an administrator to manually manage backup block relationships. ([AWS Documentation][1])

---

# 13. Backup vaults

A backup vault is a logical container used to organise and secure recovery points.

Example:

```text
production-standard-vault
production-air-gapped-vault
security-account-vault
long-term-retention-vault
```

Vault-level controls can include:

* KMS encryption.
* Access policies.
* Vault Lock.
* Notifications.
* Tags.
* Retention constraints.

---

# 14. Backup-vault access policy

Vault policies can restrict operations such as:

```text
Delete recovery point
Copy into vault
Copy out of vault
Start restore job
Describe recovery point
```

Example objective:

```text
Application account:
May create backups.

Security account:
Controls backup deletion.

Recovery account:
May restore during disaster.
```

Do not allow the same compromised production administrator to:

```text
Delete production data
+
Delete all backups
+
Disable backup policy
```

---

# 15. Cross-account backup

Cross-account copies place backups into a separate AWS account.

Architecture:

```text
Production account
      |
      | Backup copy
      v
Security backup account
```

Benefits:

* Isolation from production compromise.
* Separate IAM administration.
* Reduced accidental-deletion risk.
* Central security ownership.
* Improved ransomware resilience.

AWS Backup supports scheduled or on-demand cross-account copies for eligible resource types within AWS Organizations. If the source copy is lost, the destination account can copy a recovery point back or use it in a recovery workflow. ([AWS Documentation][4])

---

# 16. Cross-Region backup

```text
Primary:
ap-south-1

Backup copy:
ap-southeast-1
```

Cross-Region copies protect against:

* Regional disruption.
* Regional account configuration error.
* Regional KMS issue.
* Data-residency separation requirements.

AWS Backup stores backups redundantly across Availability Zones within a Region and supports cross-Region copy for additional resilience where the resource type supports it. ([AWS Documentation][5])

---

# 17. Recommended multi-account backup architecture

```text
AWS Organizations
│
├── Production account
│      └── Workloads
│
├── Backup account
│      ├── Locked backup vault
│      └── Cross-account recovery points
│
└── Recovery account
       ├── Minimal standing access
       ├── Recovery networking
       └── Restore permissions
```

Control the backup account using:

* Separate administrators.
* MFA.
* SCPs.
* Restricted role assumption.
* CloudTrail.
* Vault Lock.
* Recovery runbooks.

---

# 18. AWS Backup Vault Lock

Vault Lock applies WORM-style retention controls to recovery points.

```text
WORM:
Write Once, Read Many
```

Once a Compliance-mode Vault Lock passes its grace period, customers, account owners and AWS cannot alter or delete the lock while retained recovery points remain. Even root cannot delete protected backups before their lifecycle retention expires. ([AWS Documentation][6])

## Why it matters

```text
Attacker gains administrator permissions
        ↓
Attempts DeleteRecoveryPoint
        ↓
Vault Lock denies deletion
```

---

# 19. Retention mistakes with Vault Lock

Suppose you configure:

```text
Minimum retention:
7 years
```

but later discover those backups should have been retained for only one year.

With an effective Compliance-mode lock:

```text
You cannot shorten the protected retention.
```

Therefore test:

* Minimum retention.
* Maximum retention.
* Backup lifecycles.
* Legal requirements.
* Storage implications.

before the grace period ends.

---

# 20. Logically air-gapped vault

A logically air-gapped vault provides additional isolation beyond a standard vault.

It includes:

* Vault Lock in Compliance mode.
* Encryption using an AWS-owned or customer-managed key.
* Recovery points held in an AWS Backup service-owned account.
* Sharing through AWS RAM.
* Restore access from an authorised recovery account.
* Support for cross-organisation recovery designs.

AWS positions logically air-gapped vaults as specialised vaults for stronger isolation and flexible recovery. ([AWS Documentation][7])

---

# 21. Air-gapped-vault architecture

```text
Production account
       |
       | Backup or copy
       v
Logically air-gapped vault
       |
       | Stored in AWS Backup service-owned account
       |
       +------------------------------+
       |                              |
       v                              v
Primary account recovery      Separate recovery account
```

This reduces dependence on the continued health or control of the workload account.

---

# 22. Primary backups into air-gapped vaults

AWS Backup now supports using a logically air-gapped vault as the primary target for eligible backups in the same account and Region.

This can avoid keeping both:

```text
Standard-vault primary copy
+
Air-gapped copied recovery point
```

for supported scenarios.

Cross-Region resilience still requires an additional cross-Region copy design. ([AWS Documentation][8])

---

# 23. Multi-party approval

AWS Backup can integrate logically air-gapped vault recovery access with AWS Organizations Multi-party approval.

A recovery request can require approval from a separately managed approval team before creating restore access from a recovery account.

This adds separation between:

```text
Requester
Administrator
Approver
```

AWS recommends keeping these responsibilities distinct. Multi-party approval resources are centrally managed with specific regional and organisational prerequisites. ([AWS Documentation][9])

---

# 24. Restore testing

A backup is not proven until it has been restored and validated.

AWS Backup Restore Testing lets you:

* Create a recurring restore-test plan.
* Select specific or random eligible recovery points.
* Start restore jobs automatically.
* Measure restore duration.
* Run optional validation.
* Remove test resources after completion.

Restore testing plans schedule test restores and record their results for operational and compliance evidence. ([AWS Documentation][10])

---

# 25. Restore-test workflow

```text
Scheduled restore-test plan
        ↓
Select eligible recovery point
        ↓
Restore into isolated environment
        ↓
Run validation
        ↓
Check application/data
        ↓
Record restore duration
        ↓
Delete test resource
```

Validation should test more than resource creation.

For a database:

```text
Can the database start?
Can application credentials connect?
Are expected tables present?
Is recent data present?
Can a sample query complete?
```

---

# 26. Backup Audit Manager

AWS Backup Audit Manager provides controls and reports for evaluating backup compliance.

It can identify:

* Resources not in a backup plan.
* Recovery points with insufficient retention.
* Resources missing cross-account copies.
* Vaults without Vault Lock.
* Backup jobs that did not complete.
* Restore-testing compliance.

Reports provide evidence about backup jobs, protected resources and compliance results and can be delivered to S3. ([AWS Documentation][11])

---

# 27. AWS Organizations backup policies

An AWS Organizations backup policy can apply backup requirements across multiple accounts.

Architecture:

```text
Organization root
      |
      ├── Production OU
      │      ├── Account A
      │      └── Account B
      |
      └── Development OU
             └── Account C
```

Example:

```text
Production OU:
Daily and monthly backup policy

Development OU:
Short-retention daily policy
```

AWS Backup supports centrally applying policies and monitoring jobs across many organisation accounts. ([AWS Documentation][12])

---

# 28. Terraform backup vault

```hcl
resource "aws_backup_vault" "production" {
  name        = "production-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 29. Terraform backup plan

```hcl
resource "aws_backup_plan" "production" {
  name = "production-gold-plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.production.name
    schedule          = "cron(30 19 * * ? *)"

    start_window      = 60
    completion_window = 360

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }

    recovery_point_tags = {
      BackupPlan  = "ProductionGold"
      Environment = "production"
    }
  }

  rule {
    rule_name         = "weekly"
    target_vault_name = aws_backup_vault.production.name
    schedule          = "cron(30 20 ? * SUN *)"

    lifecycle {
      delete_after = 2555
    }
  }

  tags = {
    Environment = "production"
  }
}
```

AWS Backup plans and lifecycle rules are supported by the AWS Terraform provider, but cold-storage eligibility and minimum retention depend on the protected resource. ([Terraform Registry][13])

---

# 30. Terraform resource selection

```hcl
resource "aws_iam_role" "backup" {
  name = "aws-backup-production-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_backup_selection" "production" {
  name         = "production-tag-selection"
  plan_id      = aws_backup_plan.production.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "Gold"
  }
}
```

---

# 31. AWS CLI backup validation

List plans:

```bash
aws backup list-backup-plans \
  --region ap-south-1
```

List vaults:

```bash
aws backup list-backup-vaults \
  --region ap-south-1
```

List recovery points:

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name production-backup-vault \
  --region ap-south-1
```

Start on-demand backup:

```bash
aws backup start-backup-job \
  --backup-vault-name production-backup-vault \
  --resource-arn "$RESOURCE_ARN" \
  --iam-role-arn "$BACKUP_ROLE_ARN" \
  --region ap-south-1
```

---

# 32. Backup failure troubleshooting

Common reasons:

```text
Backup role missing permission
Resource not supported in Region
KMS key policy denial
Backup window too short
Resource deleted before backup
Required service opt-in disabled
Vault policy denial
SCP denial
Service quota reached
```

Troubleshooting sequence:

```text
1. Read backup-job status message.
2. Verify resource ARN and Region.
3. Inspect Backup service role.
4. Inspect source KMS key policy.
5. Inspect vault KMS key.
6. Check SCPs and permission boundaries.
7. Review CloudTrail.
8. Verify resource feature support.
```

---

# 33. Restore failure troubleshooting

Possible causes:

* Restore role lacks permissions.
* VPC, subnet or security-group metadata is invalid.
* Original instance type is unavailable.
* KMS key is disabled or inaccessible.
* Required IAM role no longer exists.
* Name conflicts with an existing resource.
* Capacity is unavailable.
* Cross-account restore policy is incomplete.
* A dependent AMI or network object is unavailable.

Use an explicit restore role rather than giving broad restore privileges to every backup operator.

---

# 34. What is AWS DataSync?

AWS DataSync is a managed high-speed service for transferring file and object data to, from and between AWS storage systems.

Supported source or destination types include:

```text
On-premises:
NFS
SMB
HDFS
Object storage

AWS:
Amazon S3
Amazon EFS
FSx for Windows
FSx for Lustre
FSx for OpenZFS
FSx for ONTAP
```

DataSync performs transfer preparation, data movement and verification, while also supporting scheduling, filtering, encryption and monitoring. ([AWS Documentation][14])

---

# 35. DataSync use cases

Use DataSync for:

* One-time migration.
* Recurring synchronisation.
* Cloud-to-cloud movement.
* On-premises backup ingestion.
* Data-lake population.
* File-server migration.
* Regional storage copy.
* Storage-class transition workflows.
* Disaster-recovery seeding.
* Large dataset processing.

Example:

```text
On-premises NFS
      |
      v
DataSync agent
      |
      v
AWS DataSync service
      |
      v
Amazon EFS
```

---

# 36. DataSync is not a general application replication system

DataSync moves files or objects.

It does not automatically migrate:

* Database transactions.
* Operating-system configuration.
* Running application state.
* User authentication.
* Network dependencies.
* Application servers.

For databases, use:

* Native replication.
* AWS Database Migration Service.
* Database backup and restore.
* Engine-specific migration tools.

---

# 37. DataSync components

```text
Agent
Location
Task
Task execution
```

## Agent

A virtual appliance that reads or writes non-AWS or privately connected storage.

## Location

Represents a source or destination.

Examples:

```text
NFS server
SMB share
S3 bucket
EFS filesystem
FSx filesystem
```

## Task

Defines:

* Source location.
* Destination location.
* Task mode.
* Filters.
* Metadata settings.
* Verification.
* Bandwidth.
* Schedule.

## Task execution

One run of the task.

---

# 38. When is an agent needed?

An agent is generally required when DataSync must access storage such as:

* On-premises NFS.
* On-premises SMB.
* HDFS.
* Generic object storage.
* Certain other-cloud or private storage locations.

An agent is often not required for direct AWS-to-AWS transfers and some S3-related cross-account or cloud-storage scenarios. Basic and Enhanced modes use corresponding agent types for agent-based transfers. ([AWS Documentation][15])

---

# 39. Agent deployment

DataSync agents can be deployed on supported platforms such as:

```text
VMware ESXi
KVM
Microsoft Hyper-V for supported modes
Nutanix AHV for Enhanced mode
Amazon EC2
```

The exact platform availability depends on agent and task mode. Enhanced-mode agents use different deployment images and requirements from Basic-mode agents. ([AWS Documentation][16])

---

# 40. Basic versus Enhanced mode

## Enhanced mode

Enhanced mode:

* Lists, prepares, transfers and verifies in parallel.
* Supports virtually unlimited object counts for eligible transfers.
* Usually provides better performance.
* Produces structured JSON logs.
* Is limited to supported combinations such as S3-to-S3 and selected NFS/SMB-to-S3 transfers.

## Basic mode

Basic mode:

* Supports all DataSync location types.
* Processes preparation, transfer and verification sequentially.
* Has per-execution item quotas.
* Is required for scenarios such as HDFS-to-S3.

([AWS Documentation][17])

---

# 41. DataSync task decision

```text
S3 → S3 with huge object count?
    → Enhanced

NFS → S3 with supported Enhanced agent?
    → Enhanced considered

SMB → EFS?
    → Basic

HDFS → S3?
    → Basic

S3 → FSx?
    → Basic unless current location combination says otherwise
```

Always verify the current supported-location matrix before choosing Enhanced mode.

---

# 42. Initial and incremental transfer

## Initial transfer

Copies the full selected dataset.

```text
Source:
100 TiB

Destination:
Empty

First run:
Transfer selected data
```

## Incremental run

Later execution compares source and destination and transfers changed content according to task settings.

```text
Second run:
New files
Modified files
Selected deletions, when configured
```

Migration cutover pattern:

```text
1. Initial bulk transfer.
2. Run daily incremental tasks.
3. Freeze source writes.
4. Run final incremental transfer.
5. Validate destination.
6. Point applications to destination.
```

---

# 43. Include and exclude filters

Example source:

```text
/data
├── production
├── archives
├── temp
└── cache
```

Transfer only:

```text
/production
/archives
```

Exclude:

```text
/temp
/cache
```

Filters reduce:

* Transfer duration.
* Destination storage.
* Network traffic.
* Agent workload.
* Unnecessary metadata operations.

For very large datasets, partitioning by directory and using multiple tasks can improve manageability and parallelism.

---

# 44. Metadata preservation

Depending on locations, DataSync can preserve metadata such as:

```text
Modification timestamps
User ID
Group ID
POSIX permissions
SMB ACLs
Object tags
Object metadata
```

Do not assume all source metadata maps perfectly to the destination.

Examples:

```text
POSIX ACL → S3:
No direct filesystem ACL equivalent

SMB Windows ACL → EFS:
Different permission model

Sparse file → object:
Different storage representation
```

Test a representative dataset before transferring production data.

---

# 45. Data verification

DataSync verification helps confirm destination data matches the source.

Verification choices depend on task mode.

Enhanced mode verifies transferred data, while Basic mode can perform broader verification according to its task configuration. ([AWS Documentation][17])

## Important

Verification proves transfer correctness.

It does not prove:

* Application compatibility.
* Correct ownership for every workload.
* Database consistency.
* Correct business data.
* Successful application cutover.

---

# 46. Network architecture for DataSync

```text
On-premises storage
       |
       v
DataSync agent
       |
       | HTTPS
       v
AWS DataSync service
       |
       v
S3 / EFS / FSx
```

Connectivity options may include:

* Internet.
* Site-to-Site VPN.
* AWS Direct Connect.
* VPC endpoints where supported.
* Private network paths to AWS storage.

The agent must also connect to the source protocol:

```text
NFS ports
SMB ports
HDFS endpoints
Object-storage endpoint
```

---

# 47. Bandwidth control

DataSync can limit network bandwidth for a task.

Use it when migration shares connectivity with production.

Example:

```text
Office link:
1 Gbps

Maximum DataSync:
300 Mbps

Remaining:
Reserved for business traffic
```

Schedule high-bandwidth transfers during quieter hours.

Do not saturate a shared corporate WAN without testing latency and packet loss effects.

---

# 48. DataSync architecture for millions of files

```text
Dataset
├── department-a
├── department-b
├── department-c
└── department-d
```

Possible strategy:

```text
Task A + agent A:
department-a

Task B + agent B:
department-b

Task C + agent C:
department-c
```

DataSync supports associating multiple agents in selected designs, but increasing agents also increases load on source storage and network capacity. ([AWS Documentation][15])

---

# 49. Terraform DataSync example

```hcl
resource "aws_datasync_location_nfs" "source" {
  server_hostname = var.on_prem_nfs_server
  subdirectory    = "/exports/production"

  on_prem_config {
    agent_arns = [var.datasync_agent_arn]
  }

  tags = {
    Name = "on-prem-production-nfs"
  }
}

resource "aws_datasync_location_s3" "destination" {
  s3_bucket_arn = aws_s3_bucket.migration.arn
  subdirectory  = "/production"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3.arn
  }
}

resource "aws_datasync_task" "migration" {
  name                     = "production-nfs-to-s3"
  source_location_arn      = aws_datasync_location_nfs.source.arn
  destination_location_arn = aws_datasync_location_s3.destination.arn

  options {
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    overwrite_mode         = "ALWAYS"
    preserve_deleted_files = "PRESERVE"
    transfer_mode          = "CHANGED"
    log_level              = "TRANSFER"
  }

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync.arn

  tags = {
    Environment = "production"
  }
}
```

These Terraform resources are supported by the current AWS provider; verify option compatibility with your selected DataSync task mode. ([Terraform Registry][18])

---

# 50. DataSync CLI

List agents:

```bash
aws datasync list-agents \
  --region ap-south-1
```

List tasks:

```bash
aws datasync list-tasks \
  --region ap-south-1
```

Start task:

```bash
aws datasync start-task-execution \
  --task-arn "$TASK_ARN" \
  --region ap-south-1
```

Describe execution:

```bash
aws datasync describe-task-execution \
  --task-execution-arn "$EXECUTION_ARN" \
  --region ap-south-1
```

---

# 51. DataSync troubleshooting

## Agent offline

Check:

* Agent VM is running.
* DNS works.
* Time is synchronised.
* Outbound HTTPS is permitted.
* Proxy configuration.
* Activation Region.
* Agent resource capacity.

## NFS permission denied

Check:

* NFS export policy.
* Agent IP.
* Root squash.
* UID/GID.
* Mount permissions.
* Firewall.

## SMB authentication failed

Check:

* Domain name.
* Username and password.
* Share path.
* SMB version.
* AD/DNS.
* Account lockout.
* Required permissions.

## S3 access denied

Check:

* DataSync role.
* Bucket policy.
* KMS key policy.
* Object ownership.
* VPC endpoint policy.
* SCP.

---

# 52. What is AWS Storage Gateway?

Storage Gateway is a hybrid-cloud storage service providing file, block and tape interfaces that use AWS storage behind the gateway.

The principal gateway models are:

```text
S3 File Gateway
Volume Gateway
Tape Gateway
```

Storage Gateway offers file-based, volume-based and tape-based hybrid storage interfaces. ([AWS Documentation][19])

---

# 53. Storage Gateway deployment

The gateway appliance may run:

* On-premises as a virtual machine.
* On supported hypervisors.
* On a compatible hardware appliance.
* On EC2 for selected gateway types.

Architecture:

```text
On-premises client
        |
        v
Gateway virtual appliance
        |
        | Optimised AWS transfer
        v
AWS storage
```

Local disks are used for:

* Cache.
* Upload buffers.
* Stored volume data.
* Temporary tape data.

---

# 54. S3 File Gateway

S3 File Gateway presents an NFS or SMB file share backed by S3.

```text
On-premises application
        |
        | NFS or SMB
        v
S3 File Gateway
        |
        | Object mapping
        v
Amazon S3 bucket
```

It provides a native one-to-one mapping between files and S3 objects, keeps recently accessed data in a local cache, and transfers data asynchronously to S3 using optimised mechanisms. ([AWS Documentation][20])

---

# 55. S3 File Gateway write flow

```text
Client writes file
        ↓
Gateway writes synchronously to local cache
        ↓
Client receives file-operation response
        ↓
Gateway uploads data to S3 asynchronously
```

Reads:

```text
File in local cache?
    → Serve locally

Not cached?
    → Download from S3
    → Cache locally
    → Serve client
```

([AWS Documentation][21])

---

# 56. File Gateway is not a full NAS replacement

File Gateway emulates a file interface over object storage.

It does not provide every behaviour of:

* NetApp ONTAP.
* Windows file clusters.
* POSIX filesystems.
* Distributed locking systems.
* Enterprise NAS platforms.

Use EFS or FSx when the workload requires native shared-filesystem semantics rather than an S3 object-backed file interface. AWS explicitly notes that S3 File Gateway is not designed as a full enterprise NAS replacement. ([AWS Documentation][22])

---

# 57. External changes to the S3 bucket

File Gateway maintains a cached inventory of files and objects.

If another application writes directly to the S3 bucket:

```text
Direct S3 PUT
      ↓
Gateway cache may not immediately know about it
```

Use cache refresh functionality to update the gateway’s object inventory.

Frequent simultaneous modification through both:

```text
File Gateway
+
Direct S3 clients
```

can create confusing consistency and metadata behaviour. ([AWS Documentation][23])

---

# 58. File Gateway cache sizing

The local cache:

* Stores recently accessed data.
* Buffers pending uploads.
* Uses least-recently-used eviction.
* Is shared by file shares on the same gateway.

Heavy activity on one share can reduce available cache for another share. AWS currently requires at least one local cache disk of the documented minimum size for S3 File Gateway deployments. ([AWS Documentation][24])

Monitor:

```text
CachePercentUsed
CacheHitPercent
CachePercentDirty
CloudBytesUploaded
CloudBytesDownloaded
```

---

# 59. Volume Gateway

Volume Gateway provides iSCSI block volumes to on-premises applications.

```text
Application server
        |
        | iSCSI
        v
Volume Gateway
        |
        v
AWS-backed volume storage
```

It has two main modes:

```text
Cached volumes
Stored volumes
```

---

# 60. Cached volumes

With cached volumes:

```text
Primary data:
Stored in AWS

Recently used data:
Cached locally
```

Architecture:

```text
On-premises server
        |
        | iSCSI
        v
Cached Volume Gateway
        |
        ├── Local cache
        ├── Upload buffer
        └── Full volume data in AWS
```

Cached volumes reduce the need to maintain the entire dataset on-premises while retaining low-latency access to frequently used blocks. ([AWS Documentation][25])

---

# 61. Stored volumes

With stored volumes:

```text
Primary data:
Stored locally

Backup snapshots:
Stored asynchronously in AWS
```

Architecture:

```text
On-premises server
        |
        | iSCSI
        v
Stored Volume Gateway
        |
        ├── Full local volume
        └── Asynchronous EBS snapshots
```

Use stored volumes when:

* The full working dataset must remain on-premises.
* Local latency is critical.
* AWS is primarily the offsite backup destination.

([AWS Documentation][25])

---

# 62. Cached versus stored decision

| Requirement                   | Cached volume           | Stored volume          |
| ----------------------------- | ----------------------- | ---------------------- |
| Primary full dataset          | AWS                     | On-premises            |
| Local storage required        | Cache only              | Full dataset           |
| Reduce local capacity         | Strong fit              | No                     |
| Full local low-latency access | Cached subset           | Entire dataset         |
| AWS role                      | Primary durable storage | Backup/snapshot target |

---

# 63. Volume Gateway recovery

Cached-volume recovery can use:

* Recovery snapshots.
* Volume cloning.
* A replacement gateway.

Stored-volume recovery can use:

* Recent EBS snapshots.
* Preserved local disks.
* A replacement gateway.

The recovery point may not include dirty data that had not yet been uploaded before gateway failure. Monitor upload buffers and cache status carefully. ([AWS Documentation][26])

---

# 64. Tape Gateway

Tape Gateway presents a virtual tape library, or VTL, to existing backup software.

```text
Backup application
        |
        | iSCSI virtual tape drives
        v
Tape Gateway
        |
        ├── Virtual tape library
        └── Virtual tapes
                |
                v
   S3 Glacier Flexible Retrieval
   or S3 Glacier Deep Archive
```

Tape Gateway allows existing tape-oriented backup applications to use cloud-backed virtual tape cartridges without physical tape infrastructure. ([AWS Documentation][27])

---

# 65. Tape lifecycle

```text
1. Create virtual tape.
2. Backup application writes to tape.
3. Backup software ejects tape.
4. Tape is archived.
5. Retrieve tape when restoration is needed.
6. Mount retrieved read-only tape.
```

Depending on the selected tape pool, ejected tapes can be archived into S3 Glacier Flexible Retrieval or S3 Glacier Deep Archive. ([AWS Documentation][28])

---

# 66. Tape retrieval

Archived virtual tapes must be retrieved back to a Tape Gateway before use.

Retrieved archived tapes are write-protected and are used for reading restored data. ([AWS Documentation][29])

Typical retrieval expectations differ by archive pool:

```text
Glacier Flexible Retrieval:
Hours

Glacier Deep Archive:
Longer, typically around half a day
```

Exact retrieval time can vary and should be incorporated into RTO planning. ([AWS Documentation][30])

---

# 67. Tape WORM protection

Tape Gateway supports:

* WORM virtual tapes.
* Tape retention lock.

This protects active tapes from being overwritten or erased according to the configured protection model. ([AWS Documentation][31])

Use it for:

* Regulatory backup retention.
* Ransomware resistance.
* Long-term record immutability.

---

# 68. Storage Gateway monitoring

Monitor:

```text
CachePercentDirty
CachePercentUsed
UploadBufferPercentUsed
QueuedWrites
CloudBytesUploaded
CloudBytesDownloaded
Health notifications
Gateway availability
Volume status
Tape status
```

## Critical condition

```text
Upload buffer nearly full
        ↓
Gateway cannot flush to AWS quickly enough
        ↓
Application writes may slow or fail
```

Investigate:

* WAN bandwidth.
* AWS connectivity.
* Cache/upload-buffer sizing.
* Gateway compute resources.
* Storage latency.
* Packet loss.

---

# 69. What is AWS Transfer Family?

AWS Transfer Family provides managed file-transfer endpoints and workflows for:

```text
SFTP
FTPS
FTP
AS2
Browser-based transfers
```

It transfers data directly into or out of Amazon S3 and, for supported server workflows, Amazon EFS. ([AWS Documentation][32])

---

# 70. Transfer Family architecture

```text
Partner or employee
        |
        | SFTP / FTPS / FTP / AS2 / Browser
        v
AWS Transfer Family
        |
        ├── Identity provider
        ├── IAM role
        ├── Logical directory
        └── Managed workflow
                |
                v
            S3 or EFS
```

You do not manage:

* Operating-system patching.
* SFTP daemon.
* FTP server fleet.
* Protocol scaling.
* Availability of the underlying server infrastructure.

---

# 71. SFTP, FTPS and FTP differences

## SFTP

```text
SSH File Transfer Protocol
Port commonly 22
Encryption through SSH
```

SFTP is not FTP over TLS.

## FTPS

```text
FTP protected by TLS
Control and separate data channels
```

Transfer Family uses a defined passive data-port range for FTP and FTPS data channels. ([AWS Documentation][32])

## FTP

```text
Unencrypted file transfer
```

Use FTP only when required for legacy compatibility and inside a controlled private network design.

---

# 72. AS2

AS2 is commonly used for structured business-to-business exchange.

Examples:

* Electronic data interchange.
* Supply chain.
* Payments.
* Healthcare.
* Retail partner files.

AS2 supports encryption and digital signatures through Cryptographic Message Syntax, and signed Message Disposition Notifications provide receipt verification and non-repudiation evidence. ([AWS Documentation][33])

---

# 73. Transfer Family web apps

Transfer Family web apps provide a managed browser interface for uploading, downloading and browsing S3 data.

They integrate with:

* IAM Identity Center.
* S3 Access Grants.
* S3 storage.
* CloudFront for optional custom URLs.

They do not require provisioning an SFTP or FTP server endpoint. ([AWS Documentation][34])

Suitable for:

* Nontechnical users.
* Client document portals.
* Internal data exchange.
* Partner upload/download interfaces.
* Replacing desktop FTP software.

---

# 74. Transfer Family storage choices

## Amazon S3

Best for:

* Data lakes.
* Partner uploads.
* Immutable file delivery.
* Event-driven processing.
* Archival.
* Very large scale.

## Amazon EFS

Best for:

* Existing file-oriented applications.
* Shared POSIX workloads.
* Applications requiring NFS filesystem semantics.

## Important AS2 note

AS2 workflows use S3 rather than EFS as the backend storage model. ([AWS Documentation][35])

---

# 75. Identity-provider options

Transfer Family supports identity models including:

```text
Service-managed users
AWS Managed Microsoft AD
Custom identity provider through API Gateway
Custom identity provider through Lambda
```

Protocol and authentication support differs by identity-provider type.

For example, service-managed users support SFTP key authentication, while Microsoft AD and custom providers can support password-based authentication for SFTP, FTPS and FTP. ([AWS Documentation][36])

---

# 76. Service-managed SFTP user

A simple architecture is:

```text
SFTP user:
partner-a

SSH public key:
Stored in Transfer Family

IAM role:
Access only partner-a S3 prefix

Home directory:
/partners/partner-a
```

The private SSH key remains with the partner.

Never upload a user’s private key into AWS.

---

# 77. Logical directories

Logical directories provide a virtual view of storage.

Physical S3 location:

```text
s3://partner-data/companies/company-104/incoming/
```

User sees:

```text
/incoming
```

Benefits:

* Hide physical bucket names.
* Prevent directory traversal.
* Simplify user experience.
* Isolate partners.
* Map different virtual directories to different prefixes.

---

# 78. IAM role for Transfer Family

Example role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListPartnerPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::partner-data",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "partners/partner-a",
            "partners/partner-a/*"
          ]
        }
      }
    },
    {
      "Sid": "AccessPartnerObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::partner-data/partners/partner-a/*"
    }
  ]
}
```

Trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

# 79. Public and VPC-hosted endpoints

Depending on protocol and requirement, Transfer Family endpoints can be:

* Publicly reachable.
* VPC-hosted.
* Internet-facing through selected networking.
* Privately accessible through VPC connectivity.

Use a VPC-hosted endpoint when:

* Partners connect over VPN or Direct Connect.
* FTP must not be exposed publicly.
* Private IP addressing is required.
* Security groups and controlled network paths are needed.

---

# 80. Custom domain

Instead of giving users:

```text
s-1234567890.server.transfer.ap-south-1.amazonaws.com
```

use:

```text
sftp.yourdatascientist.tech
```

Components:

```text
Route 53 DNS
Transfer Family endpoint
Stable host key
Protocol security policy
```

When migrating an existing SFTP service, importing or carefully managing the SSH host key can prevent client warnings that the server identity changed.

---

# 81. Security policies

Transfer Family security policies control supported cryptographic algorithms.

For SFTP these can govern:

* Key exchange algorithms.
* Ciphers.
* Message authentication codes.
* Host-key algorithms.

Use a modern policy unless legacy clients require older algorithms. Transfer Family currently supports modern host-key algorithms including RSA SHA-2, ECDSA and Ed25519 under applicable policies. ([AWS Documentation][37])

---

# 82. Managed workflows

Transfer Family managed workflows can process uploaded files through steps such as:

```text
Copy
Tag
Decrypt
Encrypt
Scan
Validate
Move
Notify
```

Example:

```text
Partner uploads CSV
        ↓
Workflow tags original
        ↓
Lambda validates format
        ↓
File copied to accepted/ or rejected/
        ↓
SNS notification sent
```

Transfer Family includes managed file-transfer workflows for automating post-upload processing and auditability. ([AWS Documentation][32])

---

# 83. SFTP connectors

Transfer Family SFTP connectors initiate outbound operations against an external SFTP server.

They can:

* Send S3 files to a partner server.
* Retrieve partner files into S3.
* List remote directories.
* Delete, rename or move remote files.

([AWS Documentation][38])

## Difference

```text
Transfer server:
External user connects into AWS.

SFTP connector:
AWS connects outward to an external SFTP server.
```

---

# 84. Terraform Transfer Family concept

```hcl
resource "aws_transfer_server" "partner_sftp" {
  identity_provider_type = "SERVICE_MANAGED"

  protocols = ["SFTP"]

  endpoint_type = "PUBLIC"

  security_policy_name = "TransferSecurityPolicy-2024-01"

  logging_role = aws_iam_role.transfer_logging.arn

  tags = {
    Name        = "partner-sftp"
    Environment = "production"
  }
}

resource "aws_transfer_user" "partner_a" {
  server_id = aws_transfer_server.partner_sftp.id
  user_name = "partner-a"
  role      = aws_iam_role.partner_a.arn

  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.partner_data.id}/partners/partner-a"
  }
}

resource "aws_transfer_ssh_key" "partner_a" {
  server_id = aws_transfer_server.partner_sftp.id
  user_name = aws_transfer_user.partner_a.user_name
  body      = var.partner_a_public_key
}
```

Check the selected security policy against partner client compatibility before applying it. Transfer Family server, user and host-key resources are supported by the AWS Terraform provider. ([Terraform Registry][39])

---

# 85. Transfer Family logging

Enable logging for:

* User authentication.
* File uploads.
* File downloads.
* Directory operations.
* Protocol errors.
* Workflow execution.
* AS2 messages.
* Connector operations.

Integrate with:

```text
CloudWatch Logs
CloudTrail
S3 event processing
EventBridge
Security monitoring
```

Do not log file content or credentials unnecessarily.

---

# 86. Transfer Family troubleshooting

## SFTP authentication fails

Check:

* Username spelling.
* Public key matches private key.
* Key format.
* User exists on correct server.
* Security policy client compatibility.
* Hostname and port.
* Custom identity provider response.

## Login succeeds but directory listing fails

Check:

* IAM role.
* `s3:ListBucket`.
* Prefix condition.
* Logical directory mapping.
* Bucket policy.
* KMS permissions.
* Home directory path.

## Upload fails

Check:

```text
s3:PutObject
KMS GenerateDataKey permission
Bucket policy
Object Ownership
Storage quota/application rule
Workflow failure
```

## FTPS data connection fails

Check:

* Passive port range.
* Firewall.
* Network Load Balancer configuration.
* TLS certificate.
* Security policy.
* Control versus data channel.

---

# 87. Choosing the correct service

| Requirement                                      | Recommended service        |
| ------------------------------------------------ | -------------------------- |
| Daily EBS and RDS recovery points                | AWS Backup                 |
| Immutable backup retention                       | Backup Vault Lock          |
| Isolated ransomware recovery                     | Logically air-gapped vault |
| Prove backups restore                            | AWS Backup Restore Testing |
| Move NFS to EFS                                  | DataSync                   |
| Move SMB to FSx for Windows                      | DataSync                   |
| Move HDFS to S3                                  | DataSync                   |
| Give local apps NFS access to S3                 | S3 File Gateway            |
| Keep full primary block data locally             | Stored Volume Gateway      |
| Store primary block data in AWS with local cache | Cached Volume Gateway      |
| Replace physical tape infrastructure             | Tape Gateway               |
| Partner sends SFTP files                         | Transfer Family server     |
| AWS sends files to partner SFTP                  | Transfer Family connector  |
| Browser-based partner portal                     | Transfer Family web app    |
| B2B non-repudiation workflow                     | Transfer Family AS2        |

---

# 88. End-to-end migration example

## Scenario

An organisation has:

```text
50 TiB NFS file server
Daily tape backups
External partners using SFTP
```

## Target

```text
Primary shared storage:
Amazon EFS

Archive:
Amazon S3

Backups:
AWS Backup

Partner exchange:
Transfer Family

Legacy tape retention:
Tape Gateway
```

## Migration steps

```text
1. Inventory files and access permissions.
2. Deploy DataSync agent.
3. Perform initial NFS-to-EFS transfer.
4. Schedule incremental transfers.
5. Create Transfer Family SFTP endpoint.
6. Test partner accounts.
7. Configure AWS Backup for EFS.
8. Copy backups to backup account.
9. Apply Vault Lock.
10. Freeze old NFS writes.
11. Run final DataSync transfer.
12. Validate file counts and application access.
13. Change application mount.
14. Retain rollback window.
15. Decommission old NAS after approval.
```

---

# 89. Ransomware-resistant backup architecture

```text
Production account
        |
        | Scheduled backup
        v
Backup vault
        |
        | Cross-account copy
        v
Security backup account
        |
        | Compliance Vault Lock
        v
Immutable recovery points
        |
        | Cross-Region copy
        v
Logically air-gapped vault
        |
        v
Separate recovery account
```

Additional controls:

* Separate credentials.
* SCPs.
* MFA.
* No routine human delete access.
* Backup-job alarms.
* Restore tests.
* Multi-party approval.
* Protected KMS keys.

---

# 90. Common production mistakes

## Mistake 1: Using replication as the only backup

Corruption and deletion can replicate.

## Mistake 2: Keeping every backup in the production account

A compromised administrator may affect both workload and recovery copies.

## Mistake 3: Vault Lock without testing retention

Incorrect retention becomes difficult or impossible to change.

## Mistake 4: Backup success without restore testing

A recovery point may exist while required restore metadata, permissions or application validation remain broken.

## Mistake 5: Running DataSync over an untested WAN

Migration can overwhelm production connectivity or source storage.

## Mistake 6: Assuming DataSync migrates an entire application

It transfers files and objects, not application dependencies.

## Mistake 7: Using File Gateway as a full enterprise NAS

It exposes an S3-backed file interface, not every native filesystem feature.

## Mistake 8: Using cached Volume Gateway without monitoring dirty cache

Unuploaded data can affect recovery-point freshness.

## Mistake 9: Exposing FTP publicly

FTP is not encrypted.

## Mistake 10: Giving all SFTP users one broad S3 role

One partner may access another partner’s prefix.

---

# 91. Production backup checklist

```text
[ ] RPO is documented
[ ] RTO is documented
[ ] Backup schedules match RPO
[ ] Retention satisfies legal requirements
[ ] Resource assignments are automated
[ ] Backup tags are enforced
[ ] Cross-account copies are enabled
[ ] Cross-Region copies are enabled when needed
[ ] Backup account has separate administrators
[ ] KMS policies support backup and restore
[ ] Vault policies restrict deletion
[ ] Vault Lock is tested
[ ] Air-gapped vault is evaluated
[ ] Multi-party approval is evaluated
[ ] Backup-job failures generate alerts
[ ] Restore tests run regularly
[ ] Applications validate restored data
[ ] Audit Manager reports are reviewed
[ ] SCPs protect backup services
[ ] Recovery runbooks are documented
```

---

# 92. Production DataSync checklist

```text
[ ] Source and destination are supported
[ ] Basic or Enhanced mode is intentional
[ ] Agent sizing is validated
[ ] Source storage can handle scan load
[ ] Network bandwidth is measured
[ ] Transfer bandwidth limit is configured
[ ] Metadata mapping is tested
[ ] Filters exclude unnecessary data
[ ] Initial and incremental phases are planned
[ ] Verification mode is configured
[ ] CloudWatch logging is enabled
[ ] Task failures generate alarms
[ ] Final cutover includes a write freeze
[ ] Destination permissions are validated
[ ] Rollback window is documented
```

---

# 93. Production Storage Gateway checklist

```text
[ ] Correct gateway type is selected
[ ] Gateway VM has sufficient CPU and memory
[ ] Cache storage is sized correctly
[ ] Upload buffer is sized correctly
[ ] AWS connectivity is redundant
[ ] DNS and time synchronisation work
[ ] NFS/SMB/iSCSI permissions are tested
[ ] Cache and dirty-data metrics are alarmed
[ ] Recovery snapshots are tested
[ ] External S3 writers are controlled
[ ] Tape retrieval time matches RTO
[ ] WORM retention is documented
[ ] Gateway replacement runbook exists
```

---

# 94. Production Transfer Family checklist

```text
[ ] Correct protocol is selected
[ ] FTP is avoided where possible
[ ] Endpoint exposure is intentional
[ ] Custom DNS is configured
[ ] Modern security policy is used
[ ] Host-key migration is planned
[ ] Every user has a separate role
[ ] Logical directories isolate users
[ ] S3 prefixes are narrowly scoped
[ ] KMS permissions are included
[ ] Identity provider is highly available
[ ] Upload workflows are idempotent
[ ] Malware scanning is configured
[ ] Logging is enabled
[ ] Partner onboarding is documented
[ ] Keys and certificates have rotation plans
[ ] AS2 certificates and MDNs are monitored
```

---

# 95. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Backup:
Centralised backup service

DataSync:
Managed data-transfer service

Storage Gateway:
Hybrid on-premises storage integration

Transfer Family:
Managed SFTP, FTPS, FTP and AS2
```

## Solutions Architect Associate

Understand:

```text
Backup plans and vaults
Cross-account backups
Vault Lock
DataSync agents and tasks
File Gateway
Cached versus stored Volume Gateway
Tape Gateway
Transfer Family SFTP
S3 versus EFS backend
```

## DevOps Engineer Professional

Understand:

```text
Organizations backup policies
Air-gapped vaults
Restore testing
Audit Manager
Cross-Region recovery
DataSync cutover automation
Gateway monitoring and recovery
Transfer Family custom identity providers
Managed workflows
Terraform implementation
Incident and ransomware recovery
```

---

# 96. Interview questions

## Question 1: What is AWS Backup?

**Answer:**

AWS Backup centralises backup scheduling, retention, vault management, cross-account copies, cross-Region copies, restore jobs and compliance reporting for supported AWS resources.

## Question 2: What is the difference between backup and replication?

**Answer:**

Replication maintains another current copy and can replicate corruption or deletion. Backup preserves historical recovery points for restoration.

## Question 3: What is a backup vault?

**Answer:**

A backup vault is a logical container for AWS Backup recovery points with encryption, access policies, retention and optional Vault Lock controls.

## Question 4: What is Vault Lock?

**Answer:**

Vault Lock provides WORM-style protection that prevents protected backups from being deleted or their retention shortened before lifecycle expiry.

## Question 5: What is a logically air-gapped vault?

**Answer:**

It is a specialised AWS Backup vault with Compliance-mode Vault Lock, service-account isolation and controlled sharing for recovery from another account.

## Question 6: What is restore testing?

**Answer:**

It is an AWS Backup feature that automatically restores selected recovery points on a schedule and records restore results and durations.

## Question 7: What is AWS DataSync?

**Answer:**

DataSync is a managed service for high-speed transfer of files and objects between on-premises, other-cloud and AWS storage locations.

## Question 8: When is a DataSync agent required?

**Answer:**

It is usually required to access on-premises or privately hosted NFS, SMB, HDFS or object storage. Many direct AWS-to-AWS transfers do not require one.

## Question 9: What is the difference between DataSync Basic and Enhanced mode?

**Answer:**

Enhanced mode processes transfer stages in parallel and supports very large eligible datasets. Basic mode supports all DataSync location types but processes stages sequentially and has item quotas.

## Question 10: What is S3 File Gateway?

**Answer:**

It presents NFS or SMB shares to clients while storing the files as objects in Amazon S3 and caching recently accessed data locally.

## Question 11: What is the difference between cached and stored Volume Gateway?

**Answer:**

Cached volumes store the full primary dataset in AWS and cache active blocks locally. Stored volumes keep the full primary dataset locally and create asynchronous AWS snapshots.

## Question 12: What is Tape Gateway?

**Answer:**

Tape Gateway presents a virtual tape library to existing backup software and archives virtual tapes into S3 Glacier storage classes.

## Question 13: What is AWS Transfer Family?

**Answer:**

It provides fully managed SFTP, FTPS, FTP, AS2 and browser-based file-transfer capabilities backed by S3 or supported EFS workflows.

## Question 14: What is the difference between SFTP and FTPS?

**Answer:**

SFTP is a file-transfer protocol over SSH. FTPS is traditional FTP protected using TLS.

## Question 15: What is AS2?

**Answer:**

AS2 is a B2B message-transfer protocol that supports encryption, digital signatures and signed delivery receipts.

## Question 16: What is a Transfer Family logical directory?

**Answer:**

It maps a user-visible virtual directory to an S3 prefix or EFS path while hiding the underlying storage structure.

## Question 17: When should you use a Transfer Family connector?

**Answer:**

Use a connector when AWS must initiate file transfers to or from an external SFTP server.

## Question 18: Why use a separate backup account?

**Answer:**

It isolates backup administration and recovery points from a compromise or mistake in the production account.

## Question 19: Why is restore testing essential?

**Answer:**

A successful backup job proves that a recovery point was created, but not that infrastructure, permissions, dependencies and application data can be restored successfully.

## Question 20: How would you migrate a large NFS file server to EFS?

**Answer:**

Deploy a DataSync agent, perform an initial transfer, run incremental tasks, freeze source writes, complete a final sync, validate metadata and application access, then change the application mount point.

---

# 97. Never-forget revision

```text
AWS Backup:
Creates and manages recovery points.

Backup plan:
Schedule and retention policy.

Backup vault:
Container for recovery points.

Vault Lock:
WORM backup retention.

Logically air-gapped vault:
Extra-isolated recovery vault.

Restore testing:
Proves backups can be restored.

DataSync:
High-speed file and object transfer.

DataSync agent:
Connects DataSync to non-AWS or private storage.

Basic mode:
Broad location support.

Enhanced mode:
Parallel high-scale eligible transfers.

S3 File Gateway:
NFS/SMB interface backed by S3.

Cached Volume Gateway:
Primary data in AWS, active blocks cached locally.

Stored Volume Gateway:
Primary data local, snapshots stored in AWS.

Tape Gateway:
Cloud-backed virtual tape library.

Transfer Family:
Managed file-transfer protocols.

SFTP:
File transfer over SSH.

FTPS:
FTP protected by TLS.

AS2:
Secure B2B file/message exchange.

Logical directory:
Virtual user path mapped to AWS storage.
```

## One-line memory trick

```text
Backup protects yesterday.
Replication protects availability.
DataSync moves the dataset.
Storage Gateway connects the data center.
Transfer Family connects partners.
Restore testing proves recovery.
```

## Lesson 35 outcome

You can now design an architecture where:

```text
Production resources need recovery points
    → AWS Backup creates scheduled backups.

An administrator account is compromised
    → Cross-account locked copies remain protected.

The whole organisation is affected
    → An air-gapped vault supports isolated recovery.

A backup exists but may be unusable
    → Restore Testing validates it automatically.

An on-premises NAS must move to AWS
    → DataSync performs bulk and incremental migration.

Legacy applications still require NFS or iSCSI
    → Storage Gateway preserves their interface.

A backup system expects virtual tapes
    → Tape Gateway archives them to Glacier.

Partners require SFTP or AS2
    → Transfer Family provides managed endpoints and workflows.
```

**Next lesson: Lesson 36 — AWS migration services: Migration Hub, Application Migration Service, Database Migration Service, Schema Conversion Tool, Migration Evaluator and production migration-wave planning.**

[1]: https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html "What is AWS Backup? - AWS Backup"
[2]: https://docs.aws.amazon.com/aws-backup/latest/devguide/point-in-time-recovery.html?utm_source=chatgpt.com "Continuous backups and point-in-time recovery (PITR)"
[3]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-a-backup.html?utm_source=chatgpt.com "Restore a backup by resource type"
[4]: https://docs.aws.amazon.com/aws-backup/latest/devguide/create-cross-account-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS accounts"
[5]: https://docs.aws.amazon.com/aws-backup/latest/devguide/disaster-recovery-resiliency.html?utm_source=chatgpt.com "Resilience in AWS Backup"
[6]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html "AWS Backup Vault Lock - AWS Backup"
[7]: https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html "Logically air-gapped vault - AWS Backup"
[8]: https://docs.aws.amazon.com/aws-backup/latest/devguide/lag-vault-primary-backup.html?utm_source=chatgpt.com "Primary backups to logically air-gapped vaults"
[9]: https://docs.aws.amazon.com/aws-backup/latest/devguide/multipartyapproval.html?utm_source=chatgpt.com "Multi-party approval for logically air-gapped vaults"
[10]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html "Restore testing - AWS Backup"
[11]: https://docs.aws.amazon.com/aws-backup/latest/devguide/working-with-audit-reports.html?utm_source=chatgpt.com "Working with audit reports - AWS Backup"
[12]: https://docs.aws.amazon.com/aws-backup/latest/devguide/manage-cross-account.html?utm_source=chatgpt.com "Managing AWS Backup resources across multiple AWS ..."
[13]: https://registry.terraform.io/providers/hashicorp/aws/6.5.0/docs/resources/backup_plan.html?utm_source=chatgpt.com "aws_backup_plan | Resources | hashicorp/aws | Terraform | Terraform Registry"
[14]: https://docs.aws.amazon.com/datasync/latest/userguide/what-is-datasync.html "What is AWS DataSync? - AWS DataSync"
[15]: https://docs.aws.amazon.com/datasync/latest/userguide/do-i-need-datasync-agent.html "Do I need an AWS DataSync agent? - AWS DataSync"
[16]: https://docs.aws.amazon.com/datasync/latest/userguide/deploy-agents.html?utm_source=chatgpt.com "Deploying your AWS DataSync agent"
[17]: https://docs.aws.amazon.com/datasync/latest/userguide/choosing-task-mode.html "Choosing a task mode for your data transfer - AWS DataSync"
[18]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datasync_task.html?utm_source=chatgpt.com "aws_datasync_task | Resources | hashicorp/aws | Terraform | Terraform Registry"
[19]: https://docs.aws.amazon.com/storagegateway/latest/tgw/WhatIsStorageGateway.html?utm_source=chatgpt.com "What is Tape Gateway?"
[20]: https://docs.aws.amazon.com/filegateway/latest/files3/file-gateway-concepts.html?utm_source=chatgpt.com "How Amazon S3 File Gateway works"
[21]: https://docs.aws.amazon.com/filegateway/latest/files3/Requirements.html?utm_source=chatgpt.com "File Gateway setup requirements"
[22]: https://docs.aws.amazon.com/filegateway/latest/files3/Performance-Throughput.html?utm_source=chatgpt.com "Maximizing S3 File Gateway throughput"
[23]: https://docs.aws.amazon.com/filegateway/latest/files3/refresh-cache.html?utm_source=chatgpt.com "Refreshing Amazon S3 bucket object cache"
[24]: https://docs.aws.amazon.com/filegateway/latest/files3/ManagingLocalStorage-common.html?utm_source=chatgpt.com "Managing local disks for your gateway"
[25]: https://docs.aws.amazon.com/storagegateway/latest/vgw/StorageGatewayConcepts.html?utm_source=chatgpt.com "How Volume Gateway works - AWS Storage Gateway"
[26]: https://docs.aws.amazon.com/storagegateway/latest/vgw/troubleshoot-volume-issues.html?utm_source=chatgpt.com "Troubleshooting volume issues - AWS Storage Gateway"
[27]: https://docs.aws.amazon.com/storagegateway/latest/tgw/StorageGatewayConcepts.html?utm_source=chatgpt.com "How Tape Gateway works - AWS Storage Gateway"
[28]: https://docs.aws.amazon.com/storagegateway/latest/tgw/archiving-tapes-vtl.html?utm_source=chatgpt.com "Archiving Virtual Tapes - AWS Storage Gateway"
[29]: https://docs.aws.amazon.com/storagegateway/latest/tgw/retrieving-archived-tapes-vtl.html?utm_source=chatgpt.com "Retrieving Archived Tapes - AWS Storage Gateway"
[30]: https://docs.aws.amazon.com/storagegateway/latest/tgw/CreatingCustomTapePool.html?utm_source=chatgpt.com "Creating a Custom Tape Pool - AWS Storage Gateway"
[31]: https://docs.aws.amazon.com/storagegateway/latest/tgw/GettingStartedCreateTapes.html?utm_source=chatgpt.com "Creating new virtual tapes for Tape Gateway"
[32]: https://docs.aws.amazon.com/transfer/latest/userguide/what-is-aws-transfer-family.html "What is AWS Transfer Family? - AWS Transfer Family"
[33]: https://docs.aws.amazon.com/transfer/latest/userguide/as2-for-transfer-family.html?utm_source=chatgpt.com "AWS Transfer Family for AS2"
[34]: https://docs.aws.amazon.com/transfer/latest/userguide/web-app.html "Transfer Family web apps - AWS Transfer Family"
[35]: https://docs.aws.amazon.com/transfer/latest/userguide/create-b2b-server.html?utm_source=chatgpt.com "Configuring AS2 - AWS Transfer Family"
[36]: https://docs.aws.amazon.com/transfer/latest/userguide/sftp-for-transfer-family.html "Configuring an SFTP, FTPS, or FTP server endpoint - AWS Transfer Family"
[37]: https://docs.aws.amazon.com/transfer/latest/userguide/security-policies.html?utm_source=chatgpt.com "Security policies for AWS Transfer Family servers"
[38]: https://docs.aws.amazon.com/transfer/latest/userguide/creating-connectors.html?utm_source=chatgpt.com "AWS Transfer Family SFTP connectors"
[39]: https://registry.terraform.io/providers/hashicorp/aws/4.67.0/docs/resources/transfer_user?utm_source=chatgpt.com "aws_transfer_user | Resources | hashicorp/aws | Terraform | Terraform Registry"
