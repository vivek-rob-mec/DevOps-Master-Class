# AWS Masterclass — Phase 3

# Lesson 59: AWS Backup, Vault Lock and Elastic Disaster Recovery

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish high availability, backups and disaster recovery.
* Define Recovery Point Objective and Recovery Time Objective.
* Select backup-and-restore, pilot-light, warm-standby or active-active strategies.
* Create AWS Backup plans, rules, selections and vaults.
* Design daily, weekly, monthly and continuous backups.
* Use point-in-time recovery.
* Encrypt backups correctly with AWS KMS.
* Protect recovery points using Vault Lock.
* Distinguish governance mode from compliance mode.
* Use logically air-gapped vaults and multi-party approval.
* Copy backups across accounts and Regions.
* Manage backups across AWS Organizations.
* Automate restore testing and application validation.
* Use AWS Backup Audit Manager and legal holds.
* Detect malware in supported recovery points.
* Design Elastic Disaster Recovery staging, replication, drills, recovery and failback.
* Build a DR strategy for your TodoApp.
* Provision backup and DR infrastructure with Terraform.
* Troubleshoot failed backup, copy, restore and DRS replication jobs.

---

# 2. The core mental model

```text
High availability
    → Keep the running service available

Backup
    → Preserve recoverable copies of data

Disaster recovery
    → Restore the complete business service after a major failure
```

These are complementary—not interchangeable.

```text
Multi-AZ deployment
does not replace backups.

Backups
do not automatically provide fast failover.

A second Region
does not help if corrupted data is replicated there.
```

AWS Well-Architected distinguishes normal availability from disaster recovery: availability handles recurring component failures, while DR focuses on recovering a workload after a discrete disaster such as a large technical failure, human error or attack. ([AWS Documentation][1])

---

# 3. Example failure scenarios

## Availability failure

```text
One ECS task crashes
    |
    v
ECS replaces the task
```

## Availability Zone failure

```text
One AZ becomes unavailable
    |
    v
ALB routes to healthy tasks in other AZs
```

## Data corruption

```text
Application bug corrupts 100,000 todo records
    |
    v
Restore database to an earlier point
```

## Account compromise

```text
Attacker deletes:
- Database
- Snapshots
- Application resources
    |
    v
Recover from protected cross-account backups
```

## Regional disaster

```text
Primary Region cannot serve the application
    |
    v
Recover or fail over to secondary Region
```

Each problem requires a different recovery control.

---

# Part 1 — Recovery objectives

# 4. Recovery Point Objective

Recovery Point Objective answers:

```text
How much data can the business afford to lose?
```

Example:

```text
RPO = 15 minutes
```

This means the recovery design should limit acceptable data loss to approximately the last 15 minutes before disruption.

```text
Incident occurs at 14:00
Last recoverable point is 13:50
Data loss = 10 minutes
RPO target met
```

AWS defines RPO as the maximum acceptable time between the latest recovery point and the disruption. ([AWS Documentation][1])

---

# 5. Recovery Time Objective

Recovery Time Objective answers:

```text
How long can the service remain unavailable?
```

Example:

```text
RTO = 2 hours
```

If the incident begins at 14:00, service must be restored by 16:00.

AWS defines RTO as the maximum acceptable delay between service interruption and restoration. ([AWS Documentation][1])

---

# 6. RPO and RTO timeline

```text
Past                                      Future
------------------------------------------------------------>

Last recovery point       Disaster            Service restored
       |                     |                       |
       v                     v                       v
     13:50                 14:00                   15:30

       <----- Data loss ----->
               RPO

                             <----- Downtime ----->
                                      RTO
```

RPO measures potential data loss before the disaster.

RTO measures restoration time after the disaster.

---

# 7. Business tiers

Example classification:

| Tier   | Example                      |          RPO |                 RTO |
| ------ | ---------------------------- | -----------: | ------------------: |
| Tier 0 | Payment or identity platform |      Seconds |             Minutes |
| Tier 1 | Production TodoApp API       | 5–15 minutes |        Under 1 hour |
| Tier 2 | Reporting system             |      4 hours |             8 hours |
| Tier 3 | Development environment      |     24 hours |              2 days |
| Tier 4 | Reproducible test system     |         None | Rebuild when needed |

These targets must come from business impact analysis—not only technical preference.

A lower RPO and RTO normally require:

* More replication.
* More standby capacity.
* More automation.
* More testing.
* Higher cost.

---

# 8. Do not define one RPO for the entire application blindly

A workload contains different components.

```text
TodoApp
├── Source code
├── Terraform configuration
├── Container images
├── Database
├── Uploaded files
├── Cache
├── Logs
└── Secrets
```

Possible recovery requirements:

```text
Source code:
Recover from Git

Container image:
Recover from ECR replication or rebuild

Database:
PITR with 5-minute business RPO

Uploaded files:
S3 versioning and backup

Cache:
Rebuild from database

Application servers:
Recreate from Terraform

Logs:
Recover from central log archive

Secrets:
Restore or recreate through security process
```

Not every resource needs the same backup frequency.

---

# Part 2 — Disaster-recovery strategies

# 9. Four common strategies

```text
1. Backup and restore

2. Pilot light

3. Warm standby

4. Multi-site active-active
```

The strategy should be selected according to business RPO, RTO and cost. AWS guidance describes progressively faster—but generally more expensive—approaches from backup-and-restore through pilot light, warm standby and active-active. ([AWS Documentation][2])

---

# 10. Backup and restore

```text
Primary Region
├── Running application
└── Data backups
        |
        v
Secondary Region/account
└── Stored recovery points
```

During a disaster:

```text
1. Provision infrastructure.

2. Restore data.

3. Deploy application.

4. Validate service.

5. Redirect traffic.
```

Characteristics:

```text
Cost:
Lowest

RTO:
Usually highest

RPO:
Depends on backup frequency

Use:
Noncritical or cost-sensitive workloads
```

AWS guidance commonly associates backup-and-restore with recovery measured in hours, depending heavily on data size and infrastructure automation. ([AWS Documentation][2])

---

# 11. Pilot light

The critical data layer is kept ready or continuously replicated, while most application infrastructure remains stopped or minimally provisioned.

```text
Secondary Region
├── Replicated database/data
├── Network foundation
├── IAM roles
├── Infrastructure templates
└── Application compute not fully running
```

Recovery:

```text
1. Scale or launch compute.

2. Connect to replicated data.

3. Validate.

4. Redirect traffic.
```

Pilot light offers faster recovery than restoring everything from backup, while avoiding the full cost of an always-running secondary environment.

AWS Elastic Disaster Recovery is often used as a pilot-light-style solution because it continuously replicates server data into a low-cost staging area and launches full recovery instances when needed. ([AWS Documentation][3])

---

# 12. Warm standby

A scaled-down but functional copy of the entire application runs in the recovery Region.

```text
Secondary Region
├── Small ECS service
├── Replicated database
├── Load balancer
├── Networking
├── Secrets
└── Monitoring
```

Recovery:

```text
1. Promote or activate data layer.

2. Scale compute.

3. Change DNS or routing.

4. Validate.
```

Characteristics:

```text
RTO:
Minutes

Cost:
Moderate to high

Confidence:
Higher because environment already runs
```

AWS guidance describes warm standby as a complete but reduced-capacity copy that can be scaled after failure. ([AWS Documentation][2])

---

# 13. Multi-site active-active

```text
Users
  |
  v
Global routing
  |
  ├── Region A: active
  └── Region B: active
```

Both Regions serve production traffic.

Characteristics:

```text
RTO:
Potentially near zero

RPO:
Potentially very low

Cost:
Highest

Complexity:
Highest
```

Challenges include:

* Conflict resolution.
* Data consistency.
* Global routing.
* Duplicate message handling.
* Session management.
* Region-independent dependencies.
* Deployment coordination.
* Split-brain protection.

Do not choose active-active only because it sounds most advanced.

---

# 14. Strategy comparison

| Strategy           | Compute in DR Region | Data in DR Region | Relative cost | Typical recovery speed |
| ------------------ | -------------------: | ----------------: | ------------: | ---------------------: |
| Backup and restore |  None until recovery |           Backups |        Lowest |                  Hours |
| Pilot light        |              Minimal |        Replicated |  Low–moderate |        Tens of minutes |
| Warm standby       |     Reduced capacity |        Replicated | Moderate–high |                Minutes |
| Active-active      |        Full capacity | Active/replicated |       Highest |              Very fast |

Actual RPO and RTO depend on service design, data size, automation and testing.

---

# Part 3 — AWS Backup fundamentals

# 15. What is AWS Backup?

AWS Backup provides centralized backup management for supported AWS services.

Core concepts:

```text
Backup plan
Backup rule
Resource assignment
Backup vault
Recovery point
Backup job
Copy job
Restore job
Restore testing plan
```

AWS Backup can retain backups independently of the original resource; deleting the source resource does not automatically delete recovery points stored according to their lifecycle. ([AWS Documentation][4])

---

# 16. AWS Backup architecture

```text
AWS resources
├── EC2/EBS
├── RDS/Aurora
├── DynamoDB
├── EFS
├── S3
├── FSx
└── Other supported services
        |
        v
Backup plan
        |
        v
Backup vault
        |
        v
Recovery points
        |
        ├── Restore
        ├── Cross-Region copy
        ├── Cross-account copy
        ├── Restore testing
        └── Compliance reporting
```

Feature support differs by resource type and Region, so verify AWS Backup’s feature-availability matrix before assuming that a particular service supports continuous backup, cold storage, cross-account copies or restore testing. ([AWS Documentation][5])

---

# 17. Backup plan

A backup plan is a policy defining:

* Schedule.
* Backup window.
* Target vault.
* Retention.
* Cold-storage transition.
* Cross-account copies.
* Cross-Region copies.
* Continuous backup where supported.
* Recovery-point tags.

Example:

```text
Production database plan
├── Continuous PITR: 35 days
├── Daily snapshot: 35 days
├── Monthly copy: 1 year
├── Cross-account copy
└── Cross-Region copy
```

---

# 18. Backup rule

One backup plan can contain several rules.

```text
Plan: TodoApp Production
├── Rule 1: Continuous database backup
├── Rule 2: Daily snapshot
├── Rule 3: Weekly backup
└── Rule 4: Monthly archive
```

Each rule can have an independent:

* Schedule.
* Start window.
* Completion window.
* Vault.
* Lifecycle.
* Copy action.

---

# 19. Start window and completion window

## Start window

How long AWS Backup may wait after the scheduled time to begin the backup.

Example:

```text
Schedule:
01:00

Start window:
60 minutes
```

The job can begin between 01:00 and 02:00.

## Completion window

Maximum time allowed for the job to finish after it begins.

If a backup cannot start or complete inside the configured windows, the job can expire or fail.

Do not make windows so narrow that normal service scheduling causes avoidable failures.

---

# 20. Resource selection

Resources can be assigned using:

```text
Explicit ARNs
Resource types
Tags
Conditions
```

Example tag-based selection:

```text
Backup = Daily
Environment = Production
```

Then every supported resource with those tags is included.

Advantages:

* New resources join automatically.
* Less manual plan maintenance.
* Scales across environments.

Risks:

* Missing tags create backup gaps.
* Incorrect tags include expensive resources.
* Tag changes can silently change protection.

Use AWS Config or Backup Audit Manager to detect resources not assigned to a backup plan.

---

# 21. Recovery point

A recovery point is a backup representing a resource at a specific point in time.

```text
Resource:
Aurora cluster

Recovery points:
2026-08-01 01:00
2026-08-02 01:00
2026-08-03 01:00
```

AWS Backup uses “backup” and “recovery point” broadly for the recoverable artifacts of supported services. ([AWS Documentation][6])

---

# 22. Scheduled versus on-demand backup

## Scheduled

Created automatically by a backup rule.

Use for:

* Normal protection.
* Retention policy.
* Compliance.
* Continuous operations.

## On demand

Created manually or by API.

Use before:

* Major deployment.
* Database migration.
* Destructive schema operation.
* Security remediation.
* Account migration.

Do not use manual backups as the main production strategy because they depend on people remembering to create them.

---

# 23. Snapshot versus continuous backup

## Snapshot backup

```text
01:00 snapshot
02:00 snapshot
03:00 snapshot
```

If failure occurs at 02:59, recovery may return to 02:00.

Potential loss:

```text
59 minutes
```

## Continuous backup

```text
Full backup
+
Ongoing transaction-log capture
```

Supported resources can be restored to a chosen point with one-second precision, within a retention period of up to 35 days. ([AWS Documentation][7])

---

# 24. Point-in-time recovery

Example:

```text
10:02:
Bad deployment begins deleting records

10:07:
Problem detected

Restore target:
10:01:59
```

PITR allows recovery immediately before the destructive operation.

```text
Latest time
or
Specific date and time
```

AWS Backup permits restoring continuous recovery points to the latest restorable time or a specified time inside the retention window. ([AWS Documentation][8])

---

# 25. PITR does not replace long-term snapshots

Continuous recovery normally covers a relatively short operational window.

Use snapshots for:

* Monthly retention.
* Year-end records.
* Legal requirements.
* Long-term rollback.
* Historical audits.
* Ransomware recovery beyond the PITR window.

Recommended database combination:

```text
Continuous:
35 days

Daily snapshot:
35–90 days

Monthly:
1–7 years according to policy
```

---

# 26. Lifecycle

A backup rule can define when a recovery point:

```text
Moves to cold storage
Expires
```

Example:

```text
Warm storage:
30 days

Cold storage:
Day 31 onward

Delete:
After 365 days
```

Cold storage can reduce long-term storage cost, but it may have:

* Minimum retention requirements.
* Restore delays.
* Service-specific support restrictions.

Cross-Region copies cannot be created directly into cold storage; lifecycle transition occurs according to supported destination behavior. ([AWS Documentation][9])

---

# 27. Backup retention calculation

Suppose:

```text
Daily backups retained 35 days:
35 recovery points

Weekly backups retained 12 weeks:
12 recovery points

Monthly backups retained 7 years:
84 recovery points
```

Total approximate recovery points per resource:

```text
35 + 12 + 84 = 131
```

Before enabling long retention across thousands of resources, calculate:

* Number of recovery points.
* Storage growth.
* Cross-Region copies.
* Cross-account copies.
* Cold-storage minimums.
* Restore requirements.
* Locked-vault immutability.

---

# Part 4 — Backup vaults and encryption

# 28. Backup vault

A backup vault is a logical container for recovery points.

```text
AWS Backup vault
├── EBS recovery points
├── RDS recovery points
├── DynamoDB recovery points
└── EFS recovery points
```

Vault-level controls include:

* KMS encryption.
* Access policy.
* Notifications.
* Vault Lock.
* Recovery-point organization.

---

# 29. Vault design

Avoid using one default vault for every purpose.

Better:

```text
production-operational
production-long-term
production-air-gapped
nonproduction
legal-hold
```

Separate vaults by:

* Retention.
* Environment.
* Compliance.
* Access boundary.
* Recovery team.
* Lock mode.

---

# 30. Backup encryption

Encryption behavior depends on the protected resource type and whether AWS Backup fully manages the recovery point.

For cross-account or cross-Region copies:

* The destination copy is encrypted with the destination vault’s key for supported fully managed resources.
* Some resource types require a customer managed key or the owning service’s supported KMS key.
* Cross-account copies of resources encrypted only with immutable AWS managed service keys can fail because those keys cannot be shared across accounts. ([AWS Documentation][10])

---

# 31. Recommended KMS design

```text
Source workload account
├── Workload KMS key
└── Operational backup vault

Backup account
├── Backup KMS key
└── Cross-account backup vault

Recovery Region
├── Regional recovery KMS key
└── DR backup vault
```

Use customer managed keys when you require:

* Cross-account copies.
* Custom key policies.
* Separation of duties.
* Independent disable/delete controls.
* Security-account ownership.
* Cross-Region recovery.

---

# 32. KMS key deletion risk

```text
Recovery point exists
+
KMS key permanently deleted
=
Backup may become unusable
```

Protect backup KMS keys with:

* `prevent_destroy`.
* 30-day deletion window.
* SCP denying unauthorized deletion.
* CloudTrail alarms.
* Security-account ownership.
* Periodic restore testing.

A backup is useful only when both its recovery point and required encryption key remain available.

---

# Part 5 — AWS Backup Vault Lock

# 33. What is Vault Lock?

AWS Backup Vault Lock provides write-once, read-many protection for backups.

It prevents recovery points from being:

* Deleted early.
* Having retention shortened.
* Modified contrary to lock configuration.

Vault Lock supports:

```text
Governance mode
Compliance mode
```

AWS describes it as protection against accidental or malicious deletion and as enforcement of lifecycle retention, including against privileged users. ([AWS Documentation][11])

---

# 34. Governance mode

```text
Vault Lock:
Governance mode
```

Users with sufficient IAM permission can remove or modify the lock.

Use for:

* Testing.
* Operational backup protection.
* Environments where authorized administrators require override capability.
* Preparing before compliance mode.

Governance mode provides protection but is not irreversible.

---

# 35. Compliance mode

```text
Vault Lock:
Compliance mode
```

After the configured cooling-off period expires:

* The lock cannot be removed.
* The configuration cannot be changed.
* Recovery points cannot be deleted before their retention expires.
* Even the account root user cannot override it.
* AWS cannot remove the lock on your behalf.

This is a highly consequential, effectively immutable configuration. ([AWS Documentation][11])

---

# 36. Cooling-off period

Terraform refers to the compliance-lock grace period as:

```text
changeable_for_days
```

During this period:

* Test backup creation.
* Test expected deletion behavior.
* Verify minimum and maximum retention.
* Check legal and compliance requirements.
* Confirm storage-cost estimates.
* Verify restore access.

After the period expires, compliance mode becomes immutable.

---

# 37. Minimum and maximum retention

Vault Lock can define:

```text
Minimum retention:
Backups cannot expire earlier

Maximum retention:
Backups cannot be created with retention longer than allowed
```

Example:

```text
Minimum:
30 days

Maximum:
2,555 days
```

A backup plan attempting 7-day retention would be rejected.

A backup attempting 10-year retention would also be rejected.

This ensures backup plans conform to vault policy.

---

# 38. Vault Lock warning

Before applying compliance mode:

```text
[ ] Retention has legal approval
[ ] Cost has been modelled
[ ] Terraform lifecycle is protected
[ ] Correct vault was selected
[ ] Correct account and Region were selected
[ ] Restore was tested
[ ] Operational access is documented
[ ] Security approval completed
```

A mistake can result in backups and storage costs persisting until lifecycle expiry because the lock cannot be removed after the cooling-off period. ([AWS Documentation][11])

---

# Part 6 — Logically air-gapped vaults

# 39. What is a logically air-gapped vault?

A logically air-gapped vault provides additional separation for backups and includes Vault Lock compliance-mode protection.

It can be:

* Encrypted with an AWS owned key by default.
* Optionally encrypted with a customer managed KMS key.
* Shared through AWS RAM for supported restore workflows.
* Integrated with multi-party approval.

This architecture is intended to make recovery copies more resistant to account compromise and destructive attacks. ([AWS Documentation][12])

---

# 40. Air-gapped backup architecture

```text
Production account
    |
    | Copy recovery point
    v
Backup security account
    |
    v
Logically air-gapped vault
    |
    ├── Compliance-mode lock
    ├── Separate permissions
    ├── Optional customer KMS key
    └── Recovery-account sharing
```

A stronger design separates:

* Production administration.
* Backup ownership.
* Recovery authorization.
* Security approvals.

---

# 41. Normal vault versus logically air-gapped vault

| Capability                                  | Standard vault |     Logically air-gapped vault |
| ------------------------------------------- | -------------: | -----------------------------: |
| Store recovery points                       |            Yes |                            Yes |
| Access policy                               |            Yes |                            Yes |
| Optional Vault Lock                         |            Yes | Compliance protection included |
| Cross-account copy                          |            Yes |             Supported patterns |
| RAM-based restore sharing                   |             No |                            Yes |
| Multi-party approval integration            |             No |                            Yes |
| Designed for isolation/recovery-account use |        Limited |                            Yes |

Feature support differs by resource type, Region and whether the vault is used as a primary target or copy destination.

---

# 42. Primary backups to an air-gapped vault

AWS Backup now supports using a logically air-gapped vault as the primary backup target for supported resources in the same account and Region.

For some resources, AWS Backup may first create a temporary recovery point and then copy it into the air-gapped vault. AWS recommends integrating this model with multi-party approval for stronger recovery capability if the vault-owning account becomes inaccessible. ([AWS Documentation][13])

This is a recent capability, so verify exact resource and Region support before designing around it.

---

# 43. Multi-party approval

Multi-party approval allows a critical recovery operation to require approval from a trusted group rather than one administrator.

Concept:

```text
Recovery requester
       |
       v
Requests access to protected vault
       |
       v
Independent approval team
       |
       ├── Approver 1
       ├── Approver 2
       └── Approver 3
       |
       v
Required approvals reached
       |
       v
Recovery access granted
```

AWS Backup integrates MPA with logically air-gapped vaults so a separate recovery account can request protected access during a destructive incident. ([AWS Documentation][14])

---

# 44. Separation of duties

Avoid allowing one person to be:

```text
Vault administrator
+
Recovery requester
+
Approval-team approver
```

Recommended roles:

```text
Backup administrator:
Creates plans and vaults

Security administrator:
Protects policies and keys

Recovery requester:
Starts emergency recovery request

Approvers:
Independently authorize recovery

Application owner:
Validates restored service
```

---

# 45. Recovery organization

AWS recommends a strong MPA design using:

```text
Primary AWS Organization
    |
    └── Backup vaults

Separate recovery AWS Organization
    |
    ├── Recovery account
    └── Multi-party approval team
```

The approval team is shared through AWS RAM with the necessary vault-owning and recovery accounts. MPA team resources are managed in `us-east-1`, even when protected vaults reside elsewhere. ([AWS Documentation][14])

This protects recovery authorization from compromise of the primary organization.

---

# Part 7 — Cross-account and cross-Region backups

# 46. Why cross-account?

Backups stored only in the workload account remain exposed to:

* Compromised account administrators.
* Malicious automation.
* Incorrect IAM policy.
* Account closure.
* Destructive infrastructure code.
* Ransomware-style deletion.

Better:

```text
Production account
      |
      v
Backup account
```

The backup account should have:

* Different administrators.
* Restrictive SCPs.
* Protected KMS keys.
* Locked vaults.
* No normal workloads.

---

# 47. Cross-account copy

```text
Source account
    |
    | Backup copy
    v
Destination backup account
    |
    v
Destination vault
```

AWS Backup cross-account copies require the accounts to belong to an AWS Organization and require an appropriate destination vault access policy, IAM permission and compatible KMS configuration. ([AWS Documentation][15])

---

# 48. Cross-account restore

A normal cross-account restore is commonly a two-step operation:

```text
1. Copy the recovery point
   into the destination account.

2. Restore the copied recovery point
   inside that account.
```

This differs from RAM-based sharing of logically air-gapped vaults. ([AWS Documentation][16])

---

# 49. Why cross-Region?

Cross-Region backups protect against:

* Regional control-plane disruption.
* Region-wide data loss scenario.
* Regional account configuration errors.
* Regional KMS-key unavailability.
* DR compliance requirements.

Architecture:

```text
ap-south-1
Production resources
      |
      v
Mumbai backup vault
      |
      | Cross-Region copy
      v
ap-southeast-1
DR backup vault
```

The destination copy is encrypted with the destination vault’s supported key configuration. ([AWS Documentation][10])

---

# 50. Cross-account and cross-Region together

Strong architecture:

```text
Production account
ap-south-1
      |
      v
Operational vault
      |
      v
Backup account
ap-south-1
      |
      v
Air-gapped vault
      |
      v
Backup/recovery account
ap-southeast-1
```

This protects against both:

* Workload-account compromise.
* Primary-Region disruption.

---

# 51. Continuous-backup copy caveat

When a continuous recovery point is copied across an account or Region, the destination copy can become a periodic snapshot rather than retaining the original continuous PITR behavior. ([AWS Documentation][5])

Therefore:

```text
Source:
Continuous PITR

Destination:
Potentially snapshot copy
```

Design secondary-region RPO using actual destination-copy behavior—not assumptions.

---

# 52. EBS copy caveat

Cross-Region copies are generally incremental where supported, but copying an EBS snapshot to a destination vault using a different KMS key can result in a full copy rather than an incremental copy. ([AWS Documentation][9])

This affects:

* Copy duration.
* Network transfer.
* Storage cost.
* RPO.
* Large-volume recovery planning.

---

# Part 8 — AWS Organizations backup management

# 53. Organization-wide backup management

AWS Backup integrates with AWS Organizations for:

* Cross-account monitoring.
* Central backup policies.
* Delegated administration.
* Organization-wide backup jobs.
* Copy-job visibility.
* Restore-job monitoring.
* Resource opt-in management.

Accounts must belong to the same organization for AWS Backup cross-account management. ([AWS Documentation][15])

---

# 54. Delegated backup administrator

Recommended:

```text
Organizations management account
      |
      | Delegate AWS Backup administration
      v
Backup/Security account
```

The delegated account can centrally manage supported AWS Backup operations without making the Organizations management account the daily backup operating account.

---

# 55. Backup policy

An Organizations backup policy centrally assigns backup plans to:

* Root.
* OUs.
* Accounts.

Example:

```text
Organization root:
All production databases backed up daily

Production OU:
Cross-account copy and 7-year retention

NonProduction OU:
7-day retention

Sandbox OU:
No central backup unless tagged
```

Policies attached directly and inherited through root and OUs are merged into an effective backup policy for the account. ([AWS Documentation][17])

---

# 56. Backup-policy inheritance

```text
Root policy
    |
    v
Workloads OU policy
    |
    v
Production OU policy
    |
    v
TodoApp production account
```

The effective policy is composed from applicable policy elements.

As with SCPs, test organization backup policies in a staging OU before broad deployment.

---

# 57. Resource opt-in

Some AWS Backup resource types require account or Region-level opt-in.

A central plan alone does not guarantee a resource type is protected if:

* The resource type is not enabled.
* The service is unsupported in that Region.
* The assignment tag is missing.
* The service role cannot access the resource.
* The resource’s encryption key blocks backup.

Monitor actual backup jobs and compliance—not only plan existence.

---

# Part 9 — Restore testing

# 58. A backup is not proven until restored

The statement:

```text
Backup job completed
```

proves only that a backup artifact was created.

It does not prove:

* It can be restored.
* The KMS key works.
* IAM roles are correct.
* The application starts.
* The data is consistent.
* Dependencies are available.
* The RTO can be achieved.

AWS Well-Architected specifically recommends periodic recovery to verify backup integrity and recovery procedures. ([AWS Documentation][18])

---

# 59. AWS Backup restore testing

Restore testing automates scheduled restoration of selected recovery points.

```text
Restore testing plan
       |
       v
Select recent recovery point
       |
       v
Restore temporary resource
       |
       v
Validation window
       |
       v
Delete restored test resource
```

Supported restore-testing selections currently include resource types such as Aurora, DocumentDB, DynamoDB, EBS, EC2, EFS, multiple FSx variants, Neptune, RDS and S3. AWS Backup removes the restored test resource after the validation window finishes. ([AWS Documentation][19])

---

# 60. Restore testing plan

A restore testing plan defines:

* Schedule.
* Start window.
* Recovery-point age.
* Recovery-point selection algorithm.
* Validation window.
* Resource selections.
* Restore IAM role.
* Restore metadata.

Example:

```text
Plan:
Weekly production database restore test

Schedule:
Sunday 03:00

Recovery point:
Most recent eligible

Validation window:
4 hours
```

---

# 61. Restore metadata

Restoring a resource requires configuration such as:

* VPC.
* Subnet.
* Security group.
* Instance type.
* IAM role.
* Database parameter.
* New resource name.

AWS Backup can infer likely restore metadata for supported resources, and the inferred data can be previewed programmatically. Some services still require additional metadata. ([AWS Documentation][20])

Do not assume inferred metadata represents your desired production DR architecture.

---

# 62. Restore validation

A successful AWS restore job means:

```text
AWS resource was created
```

It does not necessarily mean:

```text
Application data is correct
and
service is usable
```

Use EventBridge to detect the restore job reaching `COMPLETED`, then invoke validation using Lambda, Step Functions or another target. ([AWS Documentation][21])

---

# 63. Database validation workflow

```text
Restore job completed
        |
        v
Lambda validator
        |
        ├── Connect using TLS
        ├── Run SELECT 1
        ├── Verify expected tables
        ├── Verify recent records
        ├── Check row-count range
        ├── Check application schema version
        └── Publish validation result
```

Never run destructive tests against the restored database unless it is isolated and explicitly intended for testing.

---

# 64. EC2 validation workflow

```text
Restored EC2 instance
        |
        v
Validation
        |
        ├── Instance reaches running
        ├── SSM agent becomes online
        ├── Required services start
        ├── Health endpoint responds
        ├── Disk is mounted
        ├── Application version is identified
        └── No public exposure exists
```

Restore testing infrastructure should use isolated networking by default.

---

# 65. S3 validation workflow

```text
Restored S3 data
      |
      v
Validation
      |
      ├── Expected object count
      ├── Selected object checksums
      ├── Version metadata
      ├── Required prefixes
      ├── Encryption
      ├── Block Public Access
      └── Sample file readability
```

---

# 66. Restore-test metrics

Track:

```text
Restore success rate
Validation success rate
Restore duration
Validation duration
Resources tested
Oldest untested resource
RTO achieved
RTO missed
Cleanup failures
```

A technically completed restore that exceeds the business RTO should be considered a DR failure.

---

# 67. Test frequency

Example:

```text
Tier 0:
Monthly full DR exercise
Weekly restore test

Tier 1:
Monthly restore test
Quarterly failover exercise

Tier 2:
Quarterly restore test

Tier 3:
Semiannual sample restore
```

Also test after:

* Major architecture change.
* KMS-key policy change.
* Account migration.
* Backup-plan change.
* Database-engine upgrade.
* Network redesign.
* Security incident.

---

# Part 10 — Backup Audit Manager and compliance

# 68. AWS Backup Audit Manager

AWS Backup Audit Manager evaluates backup activity and compliance controls.

Examples:

* Resources belong to backup plans.
* Minimum backup frequency.
* Minimum retention.
* Cross-account copies exist.
* Cross-Region copies exist.
* Vault Lock is used.
* Recovery points are encrypted.
* Restore time meets the target.
* Air-gapped copies exist.

Audit Manager can generate scheduled daily and on-demand reports in S3. ([AWS Documentation][22])

---

# 69. Audit framework

```text
Framework:
Production Data Protection
├── Resources are protected by backup plan
├── Daily recovery point exists
├── Retention is at least 35 days
├── Cross-account copy exists
├── Cross-Region copy exists
├── Vault Lock enabled
└── Restore time meets target
```

Framework compliance is calculated from the compliance states of its controls and evaluated resources. ([AWS Documentation][23])

---

# 70. Audit reports

Report types can provide evidence such as:

* Which backup jobs completed.
* Which copy jobs completed.
* Which restore jobs ran.
* Which resources were protected.
* Which controls passed or failed.
* Cross-account and multi-Region activity.

Reports can be delivered to S3 in CSV or JSON depending on report scope and type. Multi-account or multi-Region reports use CSV. ([AWS Documentation][24])

---

# 71. Compliance is not recoverability

A report can show:

```text
Backup exists:
COMPLIANT
```

while the recovery process still fails because:

* KMS key inaccessible.
* Restore role missing permission.
* Network metadata incorrect.
* Application incompatible.
* Dependency unavailable.

Combine:

```text
Audit controls
+
Restore testing
+
DR exercises
```

---

# Part 11 — Legal holds and backup search

# 72. Legal hold

A legal hold prevents selected recovery points from expiring or being deleted while the hold applies.

Use cases:

* Litigation.
* Regulatory investigation.
* Security incident.
* Internal investigation.
* Data-preservation order.

Legal holds must be created and removed only through an approved legal process. AWS Backup lets administrators view holds, affected resources and recovery points currently held. ([AWS Documentation][25])

---

# 73. Legal hold versus Vault Lock

```text
Vault Lock:
Enforces vault-wide retention policy

Legal hold:
Preserves selected recovery points for a legal matter
```

A legal hold can outlive the normal recovery-point lifecycle.

Do not use legal hold as a general long-retention substitute.

---

# 74. Backup indexing and search

AWS Backup can index supported recovery points to make backup content searchable and allow restore workflows from search results. ([AWS Documentation][26])

This can help locate:

* Specific files.
* Recovery-point content.
* Data required during investigation.
* Recoverable objects without blindly restoring entire datasets.

Because feature support is resource-specific, validate eligible backup types and indexing costs.

---

# Part 12 — Malware protection for backups

# 75. Why scan backups?

A backup can contain:

* Ransomware.
* Malicious executable.
* Compromised web shell.
* Infected user upload.
* Backdoored server file.

Restoring the backup without validation can reintroduce the attack.

```text
Compromised server
    |
    v
Backup created
    |
    v
Incident occurs
    |
    v
Restore infected backup
    |
    v
Recompromise
```

---

# 76. AWS Backup malware scanning

AWS Backup can initiate malware scans for supported EC2, EBS and S3 recovery points through its GuardDuty integration and dedicated scanning permissions. Audit Manager can generate scanning reports for recent AWS Backup-initiated scan jobs. ([AWS Documentation][27])

Use scanning to help identify cleaner recovery points before restoration after a malware incident.

---

# 77. Clean-room recovery

```text
Locked recovery point
      |
      v
Malware scan
      |
      v
Isolated recovery account
      |
      v
Restore into clean VPC
      |
      v
Patch and validate
      |
      v
Business acceptance
      |
      v
Controlled production cutover
```

Do not restore a potentially compromised recovery point directly into the original production network.

---

# Part 13 — AWS Elastic Disaster Recovery

# 78. What is AWS Elastic Disaster Recovery?

AWS Elastic Disaster Recovery, or AWS DRS, continuously replicates block-level server data into a low-cost staging area in a selected AWS Region.

When recovery is required, it launches EC2 recovery instances from the replicated data.

DRS supports protection of:

* On-premises servers.
* EC2 instances.
* Servers in other clouds.
* Supported physical and virtual servers.

AWS describes DRS as minimizing downtime and data loss through continuous replication, point-in-time recovery and on-demand launch of recovery instances. ([AWS Documentation][28])

---

# 79. DRS architecture

```text
Source infrastructure
├── Physical server
├── VMware VM
├── Other cloud VM
└── EC2 instance
        |
        | AWS Replication Agent
        | Continuous block replication
        v
AWS staging-area subnet
├── Replication servers
├── Low-cost EBS volumes
└── Point-in-time snapshots
        |
        v
Recovery launch
        |
        v
EC2 recovery instances
```

---

# 80. Source server

A source server is added to DRS by installing the AWS Replication Agent on the machine. ([AWS Documentation][29])

The agent:

* Reads changed disk blocks.
* Sends data to DRS replication servers.
* Reports replication status.
* Supports ongoing continuous data protection.

---

# 81. Initial synchronization

After agent installation:

```text
Source disks
    |
    | Initial block-level copy
    v
Replication servers
    |
    v
Staging EBS volumes
```

Once initial sync completes and ongoing changes have converged, the source server reaches continuous data protection readiness. ([AWS Documentation][30])

Large servers require planning for:

* Network bandwidth.
* Source write rate.
* Volume count.
* Disk size.
* Replication-server capacity.
* Initial synchronization duration.

---

# 82. Staging-area subnet

AWS recommends using a dedicated subnet for DRS staging resources. Replication servers are automatically launched and managed in that subnet. ([AWS Documentation][31])

Example:

```text
DR VPC
├── Staging subnet
│   ├── Replication servers
│   └── Staging EBS volumes
│
├── Recovery private subnets
│   └── Recovery instances
│
└── Validation subnet
    └── Drill/test systems
```

Do not mix staging replication servers with normal production application subnets unnecessarily.

---

# 83. DRS network requirements

Source agents continuously communicate with replication servers over TCP port `1500`.

Replication servers also require HTTPS connectivity over TCP port `443` to the DRS service endpoint and other required AWS endpoints. ([AWS Documentation][32])

```text
Source server
    |
    | TCP 1500
    v
Replication server

Replication server
    |
    | TCP 443
    v
AWS DRS API
```

Restrict port `1500` to approved source-network CIDRs rather than leaving it broadly open where network design permits.

---

# 84. Private replication

Replication can use private IP routing when connectivity exists through:

* Site-to-Site VPN.
* Direct Connect.
* Transit Gateway.
* VPC peering where supported by design.
* Private routed network.

```text
On-premises
    |
    v
Direct Connect/VPN
    |
    v
Private DRS staging subnet
```

This avoids public-path replication, but requires correct routing, security groups, NACLs and DNS/endpoints.

---

# 85. Replication servers

DRS provisions and manages replication EC2 instances.

The service can:

* Consolidate multiple source servers onto replication servers.
* Add capacity.
* Remove unused capacity.
* Recycle managed replication servers periodically.
* Maintain staging infrastructure.

The default replication instance type is commonly `t3.small`, but workloads with high write rates may require a larger type. Monitor EBS throughput and replication lag. ([AWS Documentation][33])

---

# 86. Staging storage

DRS creates staging EBS volumes corresponding to source volumes.

```text
Source server:
1 TB root
2 TB data

Staging:
1 TB EBS
2 TB EBS
```

DRS uses these staging volumes to maintain replicated block data while avoiding the cost of running a complete standby application server during normal operations. ([AWS Documentation][33])

Enable EBS encryption and ensure DRS roles can use the selected KMS key. ([AWS Documentation][34])

---

# 87. Replication status

Important states and indicators:

```text
Initial sync
Continuous Data Protection
Lag
Backlog
ETA
Stalled
Disconnected
```

## Lag

How far behind the replicated copy is from the current source.

## Backlog

Amount of changed data waiting to replicate.

## ETA

Estimated time until replication catches up.

## Stalled

Data is not flowing and intervention is required.

DRS exposes these values through its recovery dashboard and source-server status. ([AWS Documentation][33])

---

# 88. Healthy replication

A healthy source should normally show:

```text
Data replication status:
Healthy

Lag:
Near zero or within RPO

Backlog:
Low

Agent:
Recently seen

Last launch:
Successful drill
```

Alert when:

* Lag exceeds RPO.
* Backlog continuously grows.
* Agent disconnects.
* Initial sync remains stalled.
* No recent successful drill exists.

---

# 89. DRS point-in-time policy

DRS maintains point-in-time recovery states.

Current PIT schedule includes:

```text
Every 10 minutes:
For the last hour

Hourly:
For the last 24 hours

Daily:
For the configured daily retention
```

The daily retention can be configured from 1 through 365 days. The minute and hourly rules are fixed. ([AWS Documentation][35])

This helps recover to a point before:

* Ransomware encryption.
* Bad deployment.
* Database corruption.
* File deletion.

---

# 90. Crash consistency

DRS replication is crash-consistent.

This means the recovered disk state is similar to a server abruptly losing power.

Applications may still require:

* Database crash recovery.
* Journal replay.
* Application consistency checks.
* Service startup ordering.
* Post-launch scripts.

DRS documentation identifies its replicated data as crash-consistent rather than automatically application-consistent. ([AWS Documentation][33])

---

# 91. Launch settings

Each source server has launch settings that determine the EC2 recovery instance.

These include:

* EC2 launch template.
* Instance type.
* VPC.
* Subnet.
* Security groups.
* Private IP behavior.
* IAM instance profile.
* Tags.
* Licensing settings.
* Post-launch actions.

DRS creates launch-template configuration for source servers and uses it during drill and recovery launches. ([AWS Documentation][36])

---

# 92. Recovery sizing

Source:

```text
On-premises:
8 vCPU
32 GB RAM
4 TB storage
```

Recovery settings might use:

```text
Drill:
Smaller instance type

Production recovery:
Equivalent or approved EC2 type
```

Validate:

* CPU architecture.
* Operating system.
* Driver support.
* EBS performance.
* Network interfaces.
* Licensing.
* EC2 quotas.
* Required Availability Zone.

Do not assume DRS automatically chooses the optimal application instance size.

---

# 93. Post-launch actions

DRS can run post-launch actions using Systems Manager commands or Automation documents.

Examples:

```text
Install CloudWatch Agent
Update hostname
Join Active Directory
Change application configuration
Start services in order
Run connectivity tests
Register monitoring
Execute custom validation
```

DRS supports default and source-specific post-launch actions, including connectivity checks and custom SSM documents. ([AWS Documentation][37])

---

# 94. Recovery drill

A recovery drill launches temporary recovery instances without stopping source replication or affecting the production source servers.

```text
Production source
      |
      | Replication continues
      v
Staging area
      |
      v
Drill instance
      |
      v
Validation
```

DRS recommends regular non-disruptive drills. A drill uses the same source-server launch settings and PIT snapshots as a real recovery. ([AWS Documentation][38])

---

# 95. Drill validation

Test:

```text
[ ] Instance boots
[ ] Network interfaces work
[ ] Required disks mount
[ ] Application services start
[ ] Database recovers
[ ] Secrets are available
[ ] DNS resolves
[ ] Dependent endpoints are reachable
[ ] Monitoring works
[ ] Security tools work
[ ] Business transaction succeeds
[ ] RTO is measured
```

A drill that only verifies `EC2 = running` is insufficient.

---

# 96. Drill isolation

Use separate drill networks.

```text
DR VPC
├── Production recovery subnet
└── Drill subnet
```

Prevent drill systems from:

* Sending real customer emails.
* Processing production queues.
* Charging payment systems.
* Writing to production databases.
* Advertising production routes.
* Publishing duplicate events.

Use:

* Isolated security groups.
* Test DNS.
* Disabled outbound integrations.
* Test credentials.
* Queue isolation.
* Feature flags.

---

# 97. Recovery versus failover

DRS terminology:

## Recovery

```text
Launch EC2 recovery instances
```

## Failover

```text
Redirect production traffic
to those instances
```

DRS performs recovery launches, but traffic redirection is your responsibility, commonly using Route 53 or another traffic-management mechanism. ([AWS Documentation][38])

---

# 98. Recovery process

```text
1. Confirm replicated state and selected PIT.

2. Start recovery job.

3. DRS launches recovery instances.

4. Post-launch actions run.

5. Validate application.

6. Promote recovery environment.

7. Redirect DNS or traffic.

8. Monitor business health.

9. Declare failover complete.
```

DRS can launch using the most recent replicated data or an earlier point-in-time snapshot. ([AWS Documentation][39])

---

# 99. Traffic redirection

Possible mechanisms:

```text
Route 53 failover records
Route 53 weighted records
Global Accelerator
External DNS
Load-balancer endpoint change
Application configuration
```

Before failover, lower DNS TTL according to the runbook if DNS-based redirection is used.

Do not wait for the disaster to discover:

* DNS ownership.
* Certificate requirements.
* Health-check behavior.
* TTL.
* Client-side DNS caching.
* Firewall allow lists.

---

# 100. Failback

Failback returns production from the AWS recovery environment to the original or replacement source environment.

```text
Recovery EC2 instance
      |
      | Reverse replication
      v
Original/rebuilt source infrastructure
      |
      v
Final synchronization
      |
      v
Traffic redirected back
```

DRS supports different failback mechanisms for on-premises, same-account AWS and cross-account AWS scenarios. ([AWS Documentation][38])

---

# 101. Failback is not immediate

Failback includes:

* Reverse replication.
* Synchronization.
* Source validation.
* Planned cutover.
* Traffic redirection.
* Protection re-establishment.

Do not terminate recovery instances immediately after the primary environment becomes available.

First ensure:

```text
[ ] Data is synchronized
[ ] Source application is healthy
[ ] Business owner approves
[ ] Traffic has moved
[ ] Monitoring is normal
[ ] DRS protection resumes
```

---

# 102. Cross-account and cross-Region DRS

DRS supports AWS-to-AWS recovery across accounts and Regions.

```text
Production account
ap-south-1
      |
      v
DR recovery account
ap-southeast-1
```

Cross-account and cross-Region designs provide stronger isolation but add:

* IAM trust.
* Network connectivity.
* KMS requirements.
* Data-transfer cost.
* Failback complexity.
* DNS and certificate planning.

DRS documents cross-account failover/failback and warns that replication, failback resources and cross-Region transfer create additional costs. ([AWS Documentation][40])

---

# 103. Multiple staging accounts

Large environments can distribute source servers across multiple staging accounts or Regions.

Benefits:

* Quota distribution.
* Smaller blast radius.
* Ownership isolation.
* Scale.
* Regional separation.
* Security boundaries.

DRS recommends considering multiple staging accounts or target Regions for larger environments and centralizing replication-health monitoring through APIs and cross-account roles. ([AWS Documentation][41])

---

# Part 14 — TodoApp backup architecture

# 104. TodoApp data classification

```text
TodoApp resources
├── Aurora/PostgreSQL database
├── S3 attachments
├── ECR container images
├── Terraform state
├── Secrets Manager secrets
├── CloudWatch logs
├── Route 53 records
└── Jenkins deployment configuration
```

Recovery method:

| Resource              | Recovery approach                                     |
| --------------------- | ----------------------------------------------------- |
| Aurora database       | PITR + daily snapshots + cross-account/Region copy    |
| S3 attachments        | Versioning + AWS Backup + cross-account copy          |
| ECR images            | Cross-Region replication or rebuild from source       |
| Terraform state       | S3 versioning, backup and protected KMS key           |
| Secrets               | Replication/recreation and secured recovery procedure |
| Application compute   | Recreate through Terraform                            |
| Logs                  | Central log archive                                   |
| DNS                   | Infrastructure as code                                |
| Jenkins configuration | Backup or recreate from configuration-as-code         |

---

# 105. TodoApp backup plan

```text
Plan:
todoapp-production

Rule 1 — Continuous database
Retention:
35 days

Rule 2 — Daily snapshots
Schedule:
01:00 IST
Retention:
35 days

Rule 3 — Weekly
Schedule:
Sunday
Retention:
12 weeks

Rule 4 — Monthly
Schedule:
First day of month
Retention:
7 years

Copy:
Backup account in ap-south-1

Copy:
DR account in ap-southeast-1
```

Retention should be aligned with actual legal and business requirements.

---

# 106. TodoApp backup accounts

```text
TodoApp Production account
      |
      v
Operational backup vault
      |
      v
Backup Security account
      |
      v
Compliance-locked vault
      |
      v
DR Recovery account
      |
      v
Cross-Region recovery vault
```

Production operators should not have permission to delete recovery points in the backup security account.

---

# 107. TodoApp backup IAM roles

Separate:

```text
Backup service role
Restore service role
Restore-testing role
Backup administrator
Recovery operator
Security approver
KMS administrator
Application validator
```

Do not grant one everyday application role:

```text
backup:*
kms:*
iam:PassRole
```

---

# 108. TodoApp restore process

```text
1. Select clean recovery point.

2. Restore database with a new identifier.

3. Restore S3 data into isolated prefix/bucket.

4. Deploy application using Terraform.

5. Inject recovered secret references.

6. Run schema and integrity tests.

7. Run synthetic user journey.

8. Compare expected data.

9. Approve cutover.

10. Redirect Route 53.

11. Monitor.

12. Preserve old environment for rollback.
```

---

# 109. TodoApp warm-standby design

```text
Users
  |
  v
Route 53
  |
  ├── Primary: ap-south-1
  │   ├── CloudFront/API
  │   ├── ECS
  │   ├── Aurora
  │   └── S3
  │
  └── Secondary: ap-southeast-1
      ├── Reduced ECS capacity
      ├── Precreated ALB/API
      ├── Replicated database/data
      └── Recovery secrets/configuration
```

During failover:

```text
Scale secondary ECS
Promote/activate database
Validate
Change routing
```

---

# Part 15 — Terraform implementation

# 110. AWS Backup vault

```hcl
resource "aws_backup_vault" "production" {
  name = "todoapp-production"

  kms_key_arn = aws_kms_key.backup.arn

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

---

# 111. Backup vault access policy

```hcl
data "aws_iam_policy_document" "backup_vault" {
  statement {
    sid    = "DenyDeleteRecoveryPoints"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "backup:DeleteRecoveryPoint",
      "backup:UpdateRecoveryPointLifecycle"
    ]

    resources = [
      "${aws_backup_vault.production.arn}/*"
    ]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"

      values = [
        aws_iam_role.backup_security_admin.arn
      ]
    }
  }
}

resource "aws_backup_vault_policy" "production" {
  backup_vault_name = aws_backup_vault.production.name
  policy            = data.aws_iam_policy_document.backup_vault.json
}
```

Vault access policies complement IAM, SCP and Vault Lock controls.

---

# 112. Vault Lock governance mode

```hcl
resource "aws_backup_vault_lock_configuration" "governance" {
  backup_vault_name = aws_backup_vault.production.name

  min_retention_days = 30
  max_retention_days = 2555
}
```

Without `changeable_for_days`, this configuration provides governance-style lock behavior that sufficiently authorized users can modify.

---

# 113. Vault Lock compliance mode

```hcl
resource "aws_backup_vault_lock_configuration" "compliance" {
  backup_vault_name = aws_backup_vault.compliance.name

  changeable_for_days = 7

  min_retention_days = 30
  max_retention_days = 2555
}
```

The Terraform provider supports `changeable_for_days`, `min_retention_days` and `max_retention_days` for vault-lock configuration. ([Terraform Registry][42])

After the changeable period expires, Terraform cannot remove the compliance lock.

---

# 114. Backup plan

```hcl
resource "aws_backup_plan" "todoapp" {
  name = "todoapp-production"

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
      Application = "TodoApp"
      BackupTier  = "daily"
    }

    copy_action {
      destination_vault_arn = (
        aws_backup_vault.cross_region.arn
      )

      lifecycle {
        delete_after = 365
      }
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

AWS Backup schedules use UTC, so `19:30 UTC` corresponds to `01:00 IST` the following day.

---

# 115. Continuous-backup rule

```hcl
resource "aws_backup_plan" "database" {
  name = "todoapp-database"

  rule {
    rule_name         = "continuous"
    target_vault_name = aws_backup_vault.production.name

    schedule = "cron(0 18 * * ? *)"

    enable_continuous_backup = true

    lifecycle {
      delete_after = 35
    }
  }
}
```

Continuous backup must be supported by the selected resource type. The maximum continuous retention is 35 days. ([AWS Documentation][7])

---

# 116. Backup selection by tags

```hcl
resource "aws_iam_role" "backup" {
  name = "todoapp-backup-service"

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
  name = "todoapp-production-resources"

  plan_id      = aws_backup_plan.todoapp.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "Daily"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = "production"
  }
}
```

The provider supports explicit resource ARNs and tag-based conditions for backup selections. ([Terraform Registry][43])

---

# 117. Cross-Region provider

```hcl
provider "aws" {
  alias  = "dr"
  region = "ap-southeast-1"
}

resource "aws_kms_key" "backup_dr" {
  provider = aws.dr

  description             = "TodoApp DR backups"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_backup_vault" "cross_region" {
  provider = aws.dr

  name        = "todoapp-production-dr"
  kms_key_arn = aws_kms_key.backup_dr.arn

  lifecycle {
    prevent_destroy = true
  }
}
```

---

# 118. Restore testing plan

Conceptual Terraform:

```hcl
resource "aws_backup_restore_testing_plan" "monthly" {
  name = "todoapp_monthly_restore"

  schedule_expression = "cron(0 20 ? * SAT#1 *)"

  schedule_expression_timezone = "Asia/Kolkata"

  start_window_hours = 4

  recovery_point_selection {
    algorithm = "LATEST_WITHIN_WINDOW"

    include_vaults = [
      aws_backup_vault.production.arn
    ]

    recovery_point_types = [
      "SNAPSHOT"
    ]

    selection_window_days = 7
  }
}
```

Then define one or more restore-testing selections for resource types and restore roles. Verify the exact provider version because restore-testing resources and supported arguments evolve.

---

# 119. DRS replication template

```hcl
resource "aws_drs_replication_configuration_template" "production" {
  associate_default_security_group = false

  bandwidth_throttling = 0

  create_public_ip = false

  data_plane_routing = "PRIVATE_IP"

  default_large_staging_disk_type = "GP3"

  ebs_encryption = "CUSTOM"

  ebs_encryption_key_arn = aws_kms_key.drs.arn

  replication_server_instance_type = "t3.small"

  replication_servers_security_groups_ids = [
    aws_security_group.drs_replication.id
  ]

  staging_area_subnet_id = aws_subnet.drs_staging.id

  use_dedicated_replication_server = false

  pit_policy {
    enabled            = true
    interval           = 10
    retention_duration = 60
    rule_id            = 1
    units              = "MINUTE"
  }

  pit_policy {
    enabled            = true
    interval           = 1
    retention_duration = 24
    rule_id            = 2
    units              = "HOUR"
  }

  pit_policy {
    enabled            = true
    interval           = 1
    retention_duration = 14
    rule_id            = 3
    units              = "DAY"
  }

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

The provider supports DRS replication-configuration templates, including staging subnet, encryption and PIT configuration. ([Terraform Registry][44])

---

# 120. DRS security group

```hcl
resource "aws_security_group" "drs_replication" {
  name        = "drs-replication"
  description = "Replication traffic from approved source networks"

  vpc_id = aws_vpc.dr.id

  ingress {
    description = "AWS DRS replication"
    protocol    = "tcp"
    from_port   = 1500
    to_port     = 1500

    cidr_blocks = [
      "10.20.0.0/16"
    ]
  }

  egress {
    description = "HTTPS to AWS endpoints"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "drs-replication"
  }
}
```

Use VPC endpoints, network firewalls or managed prefix controls where appropriate instead of unrestricted internet egress.

---

# Part 16 — Hands-on backup lab

# 121. Lab objective

Create:

```text
Backup vault
Backup plan
Tag-based selection
On-demand backup
Restore metadata inspection
Cleanup
```

Use a disposable EBS volume or test DynamoDB table.

Region:

```text
ap-south-1
```

---

# 122. Create a backup vault

```bash
VAULT_NAME="todoapp-backup-lab"

aws backup create-backup-vault \
  --backup-vault-name "$VAULT_NAME" \
  --region ap-south-1
```

Inspect:

```bash
aws backup describe-backup-vault \
  --backup-vault-name "$VAULT_NAME" \
  --region ap-south-1
```

---

# 123. Create a test EBS volume

```bash
AZ="ap-south-1a"

VOLUME_ID=$(
  aws ec2 create-volume \
    --availability-zone "$AZ" \
    --size 1 \
    --volume-type gp3 \
    --encrypted \
    --tag-specifications \
      'ResourceType=volume,Tags=[
        {Key=Name,Value=backup-lab-volume},
        {Key=Backup,Value=Lab}
      ]' \
    --region ap-south-1 \
    --query VolumeId \
    --output text
)

echo "$VOLUME_ID"
```

Wait:

```bash
aws ec2 wait volume-available \
  --volume-ids "$VOLUME_ID" \
  --region ap-south-1
```

---

# 124. Find the AWS Backup service role

```bash
BACKUP_ROLE_ARN=$(
  aws iam get-role \
    --role-name AWSBackupDefaultServiceRole \
    --query Role.Arn \
    --output text
)
```

If it does not exist, create the AWS Backup default service role through the AWS Backup console or configure a dedicated role with the required backup and restore policies.

AWS documents separate service-role permissions for backup and restore operations. ([AWS Documentation][45])

---

# 125. Start an on-demand backup

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

RESOURCE_ARN="arn:aws:ec2:ap-south-1:${ACCOUNT_ID}:volume/${VOLUME_ID}"

BACKUP_JOB_ID=$(
  aws backup start-backup-job \
    --backup-vault-name "$VAULT_NAME" \
    --resource-arn "$RESOURCE_ARN" \
    --iam-role-arn "$BACKUP_ROLE_ARN" \
    --start-window-minutes 60 \
    --complete-window-minutes 360 \
    --lifecycle DeleteAfterDays=7 \
    --recovery-point-tags Application=TodoApp,Environment=lab \
    --region ap-south-1 \
    --query BackupJobId \
    --output text
)

echo "$BACKUP_JOB_ID"
```

---

# 126. Monitor the backup job

```bash
aws backup describe-backup-job \
  --backup-job-id "$BACKUP_JOB_ID" \
  --region ap-south-1
```

Important fields:

```text
State
StatusMessage
PercentDone
CreationDate
CompletionDate
RecoveryPointArn
```

Wait until:

```text
State = COMPLETED
```

---

# 127. List recovery points

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name "$VAULT_NAME" \
  --region ap-south-1 \
  --output table
```

Capture ARN:

```bash
RECOVERY_POINT_ARN=$(
  aws backup list-recovery-points-by-backup-vault \
    --backup-vault-name "$VAULT_NAME" \
    --region ap-south-1 \
    --query 'RecoveryPoints[0].RecoveryPointArn' \
    --output text
)

echo "$RECOVERY_POINT_ARN"
```

---

# 128. Inspect restore metadata

```bash
aws backup get-recovery-point-restore-metadata \
  --backup-vault-name "$VAULT_NAME" \
  --recovery-point-arn "$RECOVERY_POINT_ARN" \
  --region ap-south-1
```

This returns the metadata required or useful for a programmatic restore. AWS recommends this API when preparing `StartRestoreJob`. ([AWS Documentation][46])

---

# 129. Cleanup

Delete recovery point:

```bash
aws backup delete-recovery-point \
  --backup-vault-name "$VAULT_NAME" \
  --recovery-point-arn "$RECOVERY_POINT_ARN" \
  --region ap-south-1
```

Delete vault:

```bash
aws backup delete-backup-vault \
  --backup-vault-name "$VAULT_NAME" \
  --region ap-south-1
```

Delete EBS volume:

```bash
aws ec2 delete-volume \
  --volume-id "$VOLUME_ID" \
  --region ap-south-1
```

A locked vault or recovery point under retention cannot be deleted early.

---

# Part 17 — Troubleshooting AWS Backup

# 130. Backup job expired

Possible causes:

* Start window too short.
* Service throttling.
* Backup role problem.
* Resource unavailable.
* Concurrent job limit.
* KMS permission.
* Service-specific backup conflict.

Actions:

```text
Increase start window
Check job status message
Check service quotas
Check CloudTrail
Check IAM role
Check KMS grants and policy
```

---

# 131. Backup job failed with access denied

Check:

```text
[ ] Backup service role trust
[ ] AWS Backup managed policies
[ ] Resource-specific permissions
[ ] KMS key policy
[ ] SCP
[ ] Permissions boundary
[ ] Resource policy
[ ] Vault access policy
[ ] Region
```

AWS Backup may require permissions to create KMS grants, generate data keys and decrypt when handling encrypted backup or copy operations. ([AWS Documentation][10])

---

# 132. Cross-account copy failed

Check:

* Both accounts are in the organization.
* Cross-account backup is enabled.
* Destination vault policy allows source.
* Source IAM role permits copy.
* Destination KMS policy permits required principals.
* Resource uses a compatible customer managed key.
* SCP does not block `backup:CopyIntoBackupVault`.
* Resource type supports cross-account copy.
* Destination Region supports the feature.

---

# 133. Copy job stuck in running

Check:

* Source backup size.
* Destination Region.
* EBS full-copy behavior.
* Concurrent copy-job quota.
* Network-transfer volume.
* Destination KMS key.
* Cold-storage limitations.
* Service-specific snapshot copy speed.

Do not calculate DR RPO only from the source backup completion time.

Track when the secondary copy actually completes.

---

# 134. Recovery point cannot be deleted

Possible causes:

```text
Vault Lock governance
Vault Lock compliance
Legal hold
Lifecycle retention
Insufficient IAM permission
Vault access-policy deny
SCP
```

If compliance-mode cooling-off has expired, the backup cannot be deleted before lifecycle expiration—even by root. ([AWS Documentation][11])

---

# 135. Vault cannot be deleted

A vault generally must have no recovery points and no immutable lock preventing deletion.

Check:

```text
Recovery points
Vault Lock status
Legal holds
Copy jobs
Restore jobs
Access policy
Terraform prevent_destroy
```

Do not attempt to solve compliance-lock errors by deleting Terraform state.

---

# 136. Restore job failed

Check:

* Restore metadata.
* Restore role.
* Resource name conflict.
* Subnet and security groups.
* Availability Zone.
* Instance quota.
* Database parameter compatibility.
* KMS key.
* Service-linked role.
* Target account permissions.
* Required tags.

Use:

```bash
aws backup describe-restore-job \
  --restore-job-id "$RESTORE_JOB_ID" \
  --region ap-south-1
```

---

# 137. Restore job completed but application fails

The restored AWS resource may be technically healthy while the business service is not.

Check:

* DNS.
* Application secrets.
* Database endpoint.
* Schema.
* Service startup order.
* Security groups.
* External dependencies.
* Message queues.
* Certificate.
* Application version.
* Data consistency.

This is why functional validation must follow infrastructure restoration.

---

# 138. Restore testing did not clean up

Check:

* Validation window.
* Service-linked restore-testing role.
* Resource deletion protection.
* Dependencies attached after restore.
* Custom validation workflow.
* AWS Backup test status.
* Manually modified test resource.

AWS Backup normally deletes the restored testing resource after the validation window, but resources altered or dependent on other resources may require investigation. ([AWS Documentation][19])

---

# 139. Backup plan misses resources

Check:

* Required tags.
* Case sensitivity.
* Resource opt-in.
* Unsupported resource type.
* Wrong account or Region.
* Organization policy inheritance.
* Selection conditions.
* IAM role.
* Resource was created after the last schedule.

Use Audit Manager controls to identify resources not protected by a plan. ([AWS Documentation][22])

---

# Part 18 — Troubleshooting DRS

# 140. DRS agent disconnected

Check:

* Agent process.
* TCP `1500`.
* TCP `443`.
* Source firewall.
* Staging security group.
* Route table.
* Network ACL.
* DNS.
* DRS endpoint access.
* System time.
* Proxy configuration.
* Source server disk space.

DRS documents agent communication, authentication and connectivity errors as common causes of disconnected replication. ([AWS Documentation][47])

---

# 141. Replication lag is increasing

Possible causes:

* Source write rate exceeds replication bandwidth.
* Replication server too small.
* EBS throughput insufficient.
* Network packet loss.
* Bandwidth throttling.
* Source disk bottleneck.
* Too many source servers consolidated.
* Large backlog after outage.

Monitor:

```text
Lag
Backlog
ETA
Replication server CPU
EBSWriteBytes
EBSWriteOps
Network throughput
```

AWS recommends monitoring replication-server CloudWatch metrics and sizing when lag or backlog frequently grows. ([AWS Documentation][48])

---

# 142. Replication server cannot launch

Check:

* Staging subnet.
* EC2 instance quota.
* Required IAM role.
* EBS quota.
* KMS key policy.
* Security groups.
* Public/private routing.
* Available IP addresses.
* SCP restrictions.
* Required service-linked roles.

EBS-default encryption can cause launch failure when DRS lacks permission to use the selected KMS key. ([AWS Documentation][49])

---

# 143. Recovery instance does not boot

Check:

* EC2 instance-type compatibility.
* CPU architecture.
* Boot mode.
* Drivers.
* Disk mapping.
* Licensing.
* Kernel.
* Network adapter.
* Launch template.
* Availability Zone capacity.
* Conversion logs.
* Unsupported operating system.

Try a recovery drill after every major OS or disk-layout change.

---

# 144. Recovery instance starts but is unreachable

Check:

```text
Subnet route
Security group
NACL
Private/public IP
Bastion or SSM
Route 53
Firewall inside OS
Network interface naming
Default gateway
DNS resolver
```

Use SSM Session Manager where possible rather than opening SSH/RDP publicly.

---

# 145. DRS drill affects production

This usually means the drill environment was not sufficiently isolated.

Potential causes:

* Drill used production DNS.
* Application consumed production queues.
* Same outbound API credentials.
* Same database endpoint.
* Duplicate scheduler ran.
* Email/SMS delivery remained enabled.
* Recovery instance registered in production load balancer.

Build a `DRILL_MODE=true` configuration that disables destructive external actions.

---

# 146. Failback cannot start

Check:

* Recovery instance status.
* DRS agent.
* Reverse-replication role.
* Target source infrastructure.
* Network ports.
* Temporary credentials.
* Cross-account trusted configuration.
* Required source tags.
* Disk space.
* Source compatibility.

Cross-account failback can require specific trusted-account roles and DRS tags such as `AWSDRS:AllowLaunchingIntoThisInstance` in applicable workflows. ([AWS Documentation][50])

---

# Part 19 — Disaster-recovery runbook

# 147. Incident declaration

```text
1. Confirm the incident.

2. Classify scope:
   Resource
   AZ
   Account
   Region
   Security compromise

3. Declare severity.

4. Assign incident commander.

5. Freeze risky changes.

6. Preserve evidence.

7. Select recovery strategy.
```

---

# 148. Recovery decision

```text
Can primary recover inside RTO?
        |
   ┌────┴────┐
   v         v
  Yes        No
   |          |
   v          v
Recover     Activate DR
in place    environment
```

For a security incident:

```text
Is primary account trusted?
        |
   ┌────┴────┐
   v         v
  Yes        No
   |          |
   v          v
Normal      Recovery account/
restore     air-gapped process
```

---

# 149. Recovery-point selection

Choose based on:

* Last known good time.
* Malware scan.
* Corruption start time.
* Backup completion.
* Cross-account copy completion.
* KMS availability.
* Application compatibility.
* Legal hold.

Do not automatically select the newest recovery point during ransomware or delayed corruption.

---

# 150. Recovery execution

```text
1. Establish clean account and Region.

2. Verify identity and break-glass access.

3. Verify KMS keys.

4. Restore infrastructure state.

5. Restore data.

6. Deploy application.

7. Apply security patches.

8. Validate dependencies.

9. Run business tests.

10. Obtain approval.

11. Redirect traffic.

12. Monitor carefully.
```

---

# 151. Recovery validation

Technical validation:

```text
Instances healthy
Database available
Queues available
DNS correct
TLS valid
Logs flowing
Alarms active
```

Business validation:

```text
User can sign in
User can create todo
User can update todo
User can upload attachment
Events are processed
No duplicate transactions
Data is current enough
```

---

# 152. Post-recovery

```text
1. Continue enhanced monitoring.

2. Preserve old environment.

3. Reconcile lost transactions.

4. Re-establish backups.

5. Re-establish replication.

6. Rotate exposed credentials.

7. Perform controlled failback if needed.

8. Document actual RPO and RTO.

9. Conduct post-incident review.

10. Update the DR plan.
```

---

# 153. Production readiness checklist

```text
[ ] Business RPO is documented
[ ] Business RTO is documented
[ ] Every critical resource has an owner
[ ] Backup does not rely on manual actions
[ ] Backup plan uses tags or explicit inventory safely
[ ] Resources missing backup tags are detected
[ ] Continuous backup is enabled where required
[ ] Snapshot retention is documented
[ ] Long-term retention is documented
[ ] Operational backups exist
[ ] Cross-account backups exist
[ ] Cross-Region backups exist
[ ] Backup account has separate administrators
[ ] Backup KMS keys are protected
[ ] Vault access policies are restrictive
[ ] Vault Lock mode is intentional
[ ] Compliance mode was tested before cooling-off expired
[ ] Air-gapped vaults exist for critical data
[ ] Multi-party approval is evaluated
[ ] Legal-hold procedure exists
[ ] Malware scanning is used for incident recovery
[ ] Restore testing runs automatically
[ ] Application-level validation follows restore
[ ] Restore tests measure actual RTO
[ ] Cleanup failures are alarmed
[ ] Backup Audit Manager frameworks exist
[ ] Audit reports are retained securely
[ ] Organization backup policies are tested
[ ] Delegated backup administrator exists
[ ] DRS staging subnet is dedicated
[ ] DRS replication uses encryption
[ ] DRS TCP ports are restricted
[ ] Replication lag is monitored
[ ] Replication backlog is monitored
[ ] Every protected server has launch settings
[ ] Post-launch actions are tested
[ ] Recovery drills occur regularly
[ ] Drill environments are isolated
[ ] Traffic-redirection procedure is documented
[ ] DNS TTL is appropriate
[ ] Failback procedure is tested
[ ] EC2 and EBS quotas are sufficient in DR Region
[ ] Service quotas include failover capacity
[ ] DR Region certificates and secrets exist
[ ] DR account access is tested
[ ] Recovery does not depend on one person
[ ] Runbooks are stored outside the primary environment
[ ] Full DR game days occur regularly
```

---

# 154. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Backup:
Central backup management

Backup vault:
Recovery-point container

RPO:
Acceptable data loss

RTO:
Acceptable downtime

Elastic Disaster Recovery:
Continuous server replication and recovery
```

## Solutions Architect Associate

Understand:

```text
Backup plans
Backup rules
Backup selections
Vaults
Cross-account copies
Cross-Region copies
Vault Lock
PITR
Restore testing
DR strategies
```

## DevOps Engineer Professional

Understand:

```text
Organizations backup policies
Delegated administration
Vault Lock compliance mode
Logically air-gapped vaults
Multi-party approval
KMS cross-account requirements
Restore validation
Audit Manager
Legal holds
DRS staging architecture
PIT policy
Post-launch actions
Drills, recovery and failback
Automated DR runbooks
```

---

# 155. Interview questions

## Question 1: What is the difference between RPO and RTO?

**Answer:**

RPO is the maximum acceptable data loss measured in time. RTO is the maximum acceptable service-restoration time after disruption.

## Question 2: Does Multi-AZ replace backups?

**Answer:**

No. Multi-AZ improves availability, but corruption, accidental deletion or malicious changes can replicate across the highly available system.

## Question 3: What is AWS Backup?

**Answer:**

AWS Backup centrally manages backup schedules, lifecycle, vaults, copies, restores and compliance for supported AWS services.

## Question 4: What is a backup plan?

**Answer:**

A backup plan contains rules defining schedule, retention, vault, lifecycle and copy actions for assigned resources.

## Question 5: What is a recovery point?

**Answer:**

It is a recoverable backup representation of a resource at a particular point in time.

## Question 6: What is continuous backup?

**Answer:**

Continuous backup captures ongoing transaction changes so supported resources can be restored to a selected point within the retention window.

## Question 7: What is Vault Lock?

**Answer:**

Vault Lock protects recovery points with WORM-style retention enforcement and prevents premature deletion.

## Question 8: What is the difference between governance and compliance mode?

**Answer:**

Authorized users can remove governance-mode lock. Compliance-mode lock becomes immutable after the cooling-off period.

## Question 9: What is a logically air-gapped vault?

**Answer:**

It is a specially protected AWS Backup vault with compliance-mode immutability and recovery-sharing capabilities designed for stronger isolation.

## Question 10: Why copy backups to another account?

**Answer:**

It protects recovery points from compromise, accidental deletion or malicious administration in the workload account.

## Question 11: Why copy backups to another Region?

**Answer:**

It provides recovery capability when the primary Region or Regional key and infrastructure are unavailable.

## Question 12: What is restore testing?

**Answer:**

AWS Backup restore testing automatically restores selected recovery points on a schedule, allows validation and later removes the test resources.

## Question 13: Why is backup-job completion insufficient?

**Answer:**

It proves only that the backup was created—not that it can be restored or that the application will function.

## Question 14: What is AWS Backup Audit Manager?

**Answer:**

It evaluates backup compliance controls and creates reports describing backup, copy and restore activity.

## Question 15: What is AWS Elastic Disaster Recovery?

**Answer:**

AWS DRS continuously replicates server disk data into a low-cost AWS staging area and launches EC2 recovery instances when needed.

## Question 16: What is a DRS staging area?

**Answer:**

It is the VPC subnet and managed replication infrastructure where DRS receives and stores continuously replicated source-server blocks.

## Question 17: What is a recovery drill?

**Answer:**

It is a non-disruptive launch of recovery instances used to test DR readiness while source replication continues.

## Question 18: Does DRS redirect production traffic automatically?

**Answer:**

No. DRS launches recovery instances, while DNS or traffic failover must be performed separately.

## Question 19: What is failback?

**Answer:**

Failback replicates data from the recovery environment back to the restored or replacement primary environment and returns production traffic.

## Question 20: What is the most important backup best practice?

**Answer:**

Regularly restore and validate backups against the business RPO and RTO.

---

# 156. Never-forget revision

```text
RPO:
How much data can be lost?

RTO:
How long can the service be down?

Backup plan:
Backup policy and schedule.

Backup rule:
One schedule and lifecycle inside a plan.

Backup selection:
Resources assigned to the plan.

Backup vault:
Container for recovery points.

Recovery point:
Recoverable backup.

PITR:
Restore to a selected time.

Vault Lock:
Immutable backup retention.

Governance mode:
Authorized override possible.

Compliance mode:
Immutable after cooling-off.

Air-gapped vault:
Highly protected isolated backup vault.

Cross-account copy:
Protects against workload-account compromise.

Cross-Region copy:
Protects against Regional disaster.

Restore testing:
Proves recovery technically works.

Validation:
Proves the application works.

AWS Backup Audit Manager:
Backup compliance and evidence.

DRS staging area:
Low-cost replication infrastructure.

Replication lag:
How far recovery data is behind.

Recovery drill:
Non-disruptive recovery test.

Recovery:
Launch recovery instances.

Failover:
Redirect production traffic.

Failback:
Return production to the primary environment.
```

## One-line memory trick

```text
Back up automatically.
Copy outside the workload account.
Lock critical recovery points.
Restore them regularly.
Validate the business service.
Measure RPO and RTO.
A backup that has never been restored is only a hope.
```

## Lesson 59 outcome

You can now design recovery where:

```text
A database record is deleted accidentally
    → PITR restores immediately before deletion.

A workload account is compromised
    → Cross-account locked backups remain protected.

The primary Region fails
    → Cross-Region copies support recovery.

An attacker targets the backup account
    → Air-gapped vault and multi-party approval protect access.

A backup job succeeds
    → Scheduled restore testing proves recoverability.

A restored database exists
    → Application validation proves business usability.

An on-premises server fails
    → DRS launches an EC2 recovery instance.

A disaster is declared
    → Route 53 redirects traffic after validation.

The primary environment is repaired
    → DRS reverse replication supports failback.

Management asks whether DR meets policy
    → Audit reports and measured drills provide evidence.
```

**Next lesson: Lesson 60 — AWS Resilience Hub, Fault Injection Service and Application Recovery Controller: resilience assessments, chaos engineering, zonal shift, routing controls, readiness checks, recovery automation and game-day engineering.**

[1]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/disaster-recovery-dr-objectives.html?utm_source=chatgpt.com "Disaster Recovery (DR) objectives - Reliability Pillar"
[2]: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-database-disaster-recovery/defining.html?utm_source=chatgpt.com "Defining your disaster recovery strategy - AWS Prescriptive Guidance"
[3]: https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the recovery objectives - AWS Well-Architected Framework"
[4]: https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html?utm_source=chatgpt.com "What is AWS Backup? - AWS Backup"
[5]: https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-feature-availability.html?utm_source=chatgpt.com "AWS Backup feature availability - AWS Backup"
[6]: https://docs.aws.amazon.com/aws-backup/latest/devguide/recovery-points.html?utm_source=chatgpt.com "Backup creation, maintenance, and restore"
[7]: https://docs.aws.amazon.com/aws-backup/latest/devguide/point-in-time-recovery.html?utm_source=chatgpt.com "Continuous backups and point-in-time recovery (PITR)"
[8]: https://docs.aws.amazon.com/aws-backup/latest/devguide/point-in-time-recovery-restoring.html?utm_source=chatgpt.com "Restoring a continuous backup"
[9]: https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS Regions - AWS Backup"
[10]: https://docs.aws.amazon.com/aws-backup/latest/devguide/encryption.html?utm_source=chatgpt.com "Encryption for backups in AWS Backup"
[11]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html?utm_source=chatgpt.com "AWS Backup Vault Lock - AWS Documentation"
[12]: https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html?utm_source=chatgpt.com "Logically air-gapped vault - AWS Backup"
[13]: https://docs.aws.amazon.com/aws-backup/latest/devguide/lag-vault-primary-backup.html?utm_source=chatgpt.com "Primary backups to logically air-gapped vaults"
[14]: https://docs.aws.amazon.com/aws-backup/latest/devguide/multipartyapproval.html?utm_source=chatgpt.com "Multi-party approval for logically air-gapped vaults"
[15]: https://docs.aws.amazon.com/aws-backup/latest/devguide/manage-cross-account.html?utm_source=chatgpt.com "Managing AWS Backup resources across multiple AWS accounts - AWS Backup"
[16]: https://docs.aws.amazon.com/aws-backup/latest/devguide/create-cross-account-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS accounts - AWS Backup"
[17]: https://docs.aws.amazon.com/en_en/organizations/latest/userguide/orgs_manage_policies_backup.html?utm_source=chatgpt.com "Backup policies - AWS Organizations"
[18]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/back-up-data.html?utm_source=chatgpt.com "Back up data - Reliability Pillar"
[19]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html?utm_source=chatgpt.com "Restore testing - AWS Backup"
[20]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing-inferred-metadata.html?utm_source=chatgpt.com "Restore testing inferred metadata - AWS Backup"
[21]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing-validation.html?utm_source=chatgpt.com "Restore testing validation - AWS Backup"
[22]: https://docs.aws.amazon.com/aws-backup/latest/devguide/controls-and-remediation.html?utm_source=chatgpt.com "Controls and remediation - AWS Backup"
[23]: https://docs.aws.amazon.com/aws-backup/latest/devguide/viewing-frameworks.html?utm_source=chatgpt.com "Viewing framework compliance status - AWS Backup"
[24]: https://docs.aws.amazon.com/aws-backup/latest/devguide/working-with-audit-reports.html?utm_source=chatgpt.com "Working with audit reports - AWS Backup"
[25]: https://docs.aws.amazon.com/aws-backup/latest/devguide/legalhold.html?utm_source=chatgpt.com "Legal holds and AWS Backup"
[26]: https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-search.html?utm_source=chatgpt.com "Backup search - AWS Documentation - Amazon.com"
[27]: https://docs.aws.amazon.com/aws-backup/latest/devguide/security-iam-awsmanpol.html?utm_source=chatgpt.com "Managed policies for AWS Backup"
[28]: https://docs.aws.amazon.com/drs/?utm_source=chatgpt.com "AWS Elastic Disaster Recovery Documentation"
[29]: https://docs.aws.amazon.com/drs/latest/userguide/source-servers.html?utm_source=chatgpt.com "AWS DRS source servers - AWS Elastic Disaster Recovery"
[30]: https://docs.aws.amazon.com/drs/latest/userguide/getting-started.html?utm_source=chatgpt.com "Getting started with AWS Elastic Disaster Recovery - AWS Elastic Disaster Recovery"
[31]: https://docs.aws.amazon.com/drs/latest/userguide/Network-Settings-Preparations.html?utm_source=chatgpt.com "Elastic Disaster Recovery network setting preparations - AWS Elastic Disaster Recovery"
[32]: https://docs.aws.amazon.com/drs/latest/userguide/Network-Requirements.html?utm_source=chatgpt.com "Elastic Disaster Recovery network requirements - AWS Elastic Disaster Recovery"
[33]: https://docs.aws.amazon.com/drs/latest/userguide/Replication-Related-FAQ.html?utm_source=chatgpt.com "Replication related - AWS Elastic Disaster Recovery"
[34]: https://docs.aws.amazon.com/drs/latest/userguide/infrastructure-security.html?utm_source=chatgpt.com "Infrastructure security in AWS Elastic Disaster Recovery - AWS Elastic Disaster Recovery"
[35]: https://docs.aws.amazon.com/drs/latest/userguide/point-in-time.html?utm_source=chatgpt.com "Point in time (PIT) policy - AWS Elastic Disaster Recovery"
[36]: https://docs.aws.amazon.com/drs/latest/userguide/launch-settings-source.html?utm_source=chatgpt.com "AWS DRS launch settings - AWS Elastic Disaster Recovery"
[37]: https://docs.aws.amazon.com/drs/latest/userguide/post-launch-action-settings-overview.html?utm_source=chatgpt.com "Configuring the default post-launch actions - AWS Elastic Disaster Recovery"
[38]: https://docs.aws.amazon.com/drs/latest/userguide/failback.html?utm_source=chatgpt.com "Using Elastic Disaster Recovery for recovery and failback - AWS Elastic Disaster Recovery"
[39]: https://docs.aws.amazon.com/drs/latest/userguide/failback-preparing-failover.html?utm_source=chatgpt.com "Performing a failover with Elastic Disaster Recovery - AWS Elastic Disaster Recovery"
[40]: https://docs.aws.amazon.com/drs/latest/userguide/failback-failover-cross-account.html?utm_source=chatgpt.com "Performing a cross-account failback - AWS Elastic Disaster Recovery"
[41]: https://docs.aws.amazon.com/drs/latest/userguide/drs-at-scale.html?utm_source=chatgpt.com "Disaster recovery at scale - AWS Elastic Disaster Recovery"
[42]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration?utm_source=chatgpt.com "aws_backup_vault_lock_configuration | Resources | hashicorp/aws | Terraform | Terraform Registry"
[43]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection?utm_source=chatgpt.com "aws_backup_selection | Resources | hashicorp/aws | Terraform | Terraform Registry"
[44]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/drs_replication_configuration_template?utm_source=chatgpt.com "aws_drs_replication_configuration_template | Resources | hashicorp/aws | Terraform | Terraform Registry"
[45]: https://docs.aws.amazon.com/aws-backup/latest/devguide/iam-service-roles.html?utm_source=chatgpt.com "IAM service roles - AWS Backup"
[46]: https://docs.aws.amazon.com/aws-backup/latest/devguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshooting AWS Backup"
[47]: https://docs.aws.amazon.com/drs/latest/userguide/troubleshooting-replication.html?utm_source=chatgpt.com "Troubleshooting replication errors - AWS Elastic Disaster Recovery"
[48]: https://docs.aws.amazon.com/drs/latest/userguide/individual-replication-settings.html?utm_source=chatgpt.com "AWS DRS individual replication settings - AWS Elastic Disaster Recovery"
[49]: https://docs.aws.amazon.com/drs/latest/userguide/replication-server-errors.html?utm_source=chatgpt.com "Replication infrastructure errors - AWS Elastic Disaster Recovery"
[50]: https://docs.aws.amazon.com/drs/latest/userguide/failback-replication-errors.html?utm_source=chatgpt.com "Failback replication errors - AWS Elastic Disaster Recovery"
