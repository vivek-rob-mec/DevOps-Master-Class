# Module 13 — AWS Production Architecture

# Lesson 37 — AWS Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 2: AWS Backup & Restore Deep Dive

In Part 1 we established:

```text
RTO
=
How quickly must service return?


RPO
=
How much data can we afford to lose?
```

Now we address the first classic DR strategy:

# Backup & Restore

At first it sounds simple:

```text
"Take backup.
If disaster happens,
restore backup."
```

Production reality is much deeper:

```text
WHAT is backed up?
       │
       ▼
HOW often?
       │
       ▼
WHERE is it stored?
       │
       ▼
HOW long is it retained?
       │
       ▼
Can an attacker delete it?
       │
       ▼
Is another Region/account protected?
       │
       ▼
Can it ACTUALLY be restored?
       │
       ▼
How long does restore take?
       │
       ▼
Does restored application work?
```

AWS Backup exists to provide centralized backup scheduling, retention, monitoring, encryption, governance, and—in supported combinations—cross-account/cross-Region protection across AWS resource types. Feature support varies by resource type and Region, so production designs must check the current AWS Backup feature matrix rather than assuming every feature works for every service. ([AWS Documentation][1])

---

# 37.83 First distinction — service-native backup vs AWS Backup

Many AWS services have their own backup mechanisms.

For example:

```text
RDS
→ Automated backups
→ DB snapshots
→ PITR

EBS
→ EBS snapshots

S3
→ Versioning
→ native replication capabilities

DynamoDB
→ PITR
→ on-demand backup
```

These native service capabilities continue to exist independently of AWS Backup. AWS Backup is a **central orchestration and governance layer** that can manage supported resources through common plans, policies, vaults, monitoring, and recovery workflows. ([AWS Documentation][2])

Mental model:

```text
SERVICE-NATIVE FEATURE
=
How this service protects its data


AWS BACKUP
=
Central backup control plane
across supported services
```

Don't think:

```text
AWS Backup
replaces
RDS backup technology.
```

Instead:

```text
AWS Backup
orchestrates/governs supported
backup mechanisms.
```

---

# 37.84 The five core AWS Backup objects

You should immediately recognize:

```text
AWS BACKUP

Backup Plan
    │
    ├── Backup Rule
    │
    ├── Schedule
    │
    ├── Lifecycle
    │
    ├── Vault
    │
    └── Copy Actions
    │
    ▼
Resource Assignment
    │
    ▼
Protected Resources
    │
    ▼
Recovery Points
    │
    ▼
Backup Vault
```

Let's separate them.

---

# 37.85 Backup Plan

A:

# Backup Plan

answers:

> **What backup policy should AWS apply?**

For example:

```text
Production database policy

Daily backup
     │
Keep 35 days
     │
Copy to another Region
     │
Keep monthly copy longer
     │
Store in protected vault
```

AWS Backup plans define backup schedules and retention/lifecycle behavior, and they can include copy actions for additional Regions or accounts where the resource supports those features. ([AWS Documentation][3])

---

# 37.86 Backup Rule

A backup plan can contain multiple rules.

Example:

```text
PLAN:
prod-critical

        │
        ├── Rule 1
        │    Daily backup
        │    35-day retention
        │
        └── Rule 2
             Monthly backup
             long-term retention
```

So:

```text
Backup Plan
=
overall policy


Backup Rule
=
one schedule/lifecycle behavior
inside the policy
```

---

# 37.87 Resource Assignment

The plan needs to know:

> Which resources does this policy protect?

You can assign supported resources explicitly or select resources through supported resource-selection mechanisms such as tags. AWS Backup allows plan assignments to target resource types/resources and provides organization-wide management options when AWS Organizations is involved. ([AWS Documentation][4])

Example:

```text
Tag:

Backup = Critical

         │
         ▼
prod-rds
prod-ebs
prod-s3
```

Then:

```text
Backup Plan
      │
      ▼
Backup=Critical
```

becomes much more scalable than manually adding every server one-by-one.

---

# 37.88 Recovery Point

A:

# Recovery Point

is essentially a usable backup representation from which restoration can occur.

Think:

```text
Production Resource
       │
       │ backup
       ▼
Recovery Point
       │
       │ restore
       ▼
Recovered Resource
```

Very important terminology.

During incidents you'll often hear:

> "Which recovery point are we restoring?"

---

# 37.89 Backup Vault

A:

# Backup Vault

is the logical container in AWS Backup that stores and organizes recovery points. Vaults also participate in access policy, encryption, Vault Lock, and other protection mechanisms. ([AWS Documentation][5])

Mental model:

```text
Backup Vault
│
├── recovery point A
├── recovery point B
├── recovery point C
└── recovery point D
```

This is **not the same thing as an S3 bucket you manually manage**.

It's an AWS Backup construct.

---

# 37.90 Periodic backup vs continuous backup

This is one of today's biggest distinctions.

## Periodic

Think:

```text
12:00
SNAPSHOT

        ↓

18:00
SNAPSHOT

        ↓

00:00
SNAPSHOT
```

You recover to one of those recovery points.

---

## Continuous

Think:

```text
Full backup
      │
      ▼
continuous change/transaction tracking
      │
      ▼
restore to a selected point in time
```

AWS Backup continuous backups support PITR for supported resource types; the AWS Backup continuous-backup retention range is currently up to **35 days**, with restore selection down to a specific point in time according to the service's supported recovery semantics. ([AWS Documentation][6])

---

# 37.91 Snapshot recovery mental model

Imagine:

```text
08:00 snapshot

12:00 snapshot

16:00 snapshot
```

Disaster:

```text
17:00
```

If the latest usable snapshot is:

```text
16:00
```

then potential data loss can approach:

```text
1 hour
```

depending on the data workload.

This is why backup frequency affects achievable RPO.

---

# 37.92 PITR mental model

Suppose:

```text
09:00

Database okay


09:47:12

Bad deployment corrupts data


09:48

Team notices
```

Instead of only having:

```text
09:00 snapshot
```

PITR might allow:

```text
restore to

09:47:11
```

just before corruption.

Conceptually:

```text
09:00       09:47:11   09:47:12
  │             │          │
  │             │          X
  │             │      corruption
  └─────────────▲
             recover
               here
```

This is vastly different from merely saying:

> "We take one snapshot every day."

---

# 37.93 RDS automated backups and PITR

Amazon RDS automated backups support point-in-time recovery within the configured retention period. When performing PITR, RDS creates a **new DB instance** rather than overwriting the existing source DB instance. ([AWS Documentation][7])

Think:

```text
CORRUPTED DB
prod-db
     │
     │ PITR
     ▼
NEW DB
prod-db-restored
```

Not:

```text
prod-db
gets magically rewound
in place.
```

This matters operationally.

---

# 37.94 Why restoring to a new DB is important

Suppose production is corrupt.

You restore:

```text
prod-db-recovery
```

Then you need to handle:

```text
Validation
     ↓
Application connection update
     ↓
DNS/secret/configuration
     ↓
Cutover
```

So database restore time isn't necessarily equal to:

# Application RTO.

You must include cutover and validation.

---

# 37.95 RDS manual snapshot vs PITR

Mental comparison:

| Feature                       | Snapshot             | PITR                              |
| ----------------------------- | -------------------- | --------------------------------- |
| Recovery target               | Exact snapshot       | Selected time within retention    |
| Useful for                    | Known checkpoints    | Fine-grained logical recovery     |
| New DB created                | Yes                  | Yes                               |
| Long-term retained checkpoint | Good fit             | Retention-window based            |
| Example                       | Before major upgrade | Before accidental data corruption |

RDS supports both DB snapshots and automated backup/PITR workflows. ([AWS Documentation][8])

---

# 37.96 Pre-change snapshots are extremely useful

Imagine deploying a major database schema migration.

Before:

```text
v1 schema
```

Take:

```text
manual snapshot
```

Then:

```text
migration
      ↓
problem
      ↓
restore known checkpoint
```

This doesn't replace PITR or automated backup.

It gives a deliberate recovery marker.

Think:

```text
Scheduled protection
+
change-specific recovery point
```

---

# 37.97 EBS snapshots

For EC2 block storage, Amazon EBS snapshots are point-in-time backups of EBS volumes.

EBS snapshots are **incremental**: after the first snapshot, subsequent snapshots store changed blocks rather than duplicating the entire volume's unchanged data. ([AWS Documentation][9])

Example:

```text
100 GB volume

Snapshot 1
full logical recovery point

     ↓

10 GB changes

     ↓

Snapshot 2
stores changed blocks required
for incremental history
```

---

# 37.98 Incremental does NOT mean partial restore

This is important.

An incremental snapshot still represents a recoverable state of the volume.

You don't restore:

```text
Snapshot 1
+
manually merge Snapshot 2
+
Snapshot 3
```

AWS manages the snapshot dependency/reference data needed for the restore. AWS Backup likewise maintains required reference data so supported incremental recovery points can still perform full resource restoration even as older recovery points expire according to lifecycle rules. ([AWS Documentation][10])

---

# 37.99 EBS restore performance nuance

A volume created from a normal EBS snapshot may experience first-access initialization behavior for blocks restored from the snapshot.

Amazon EBS **Fast Snapshot Restore (FSR)** can create volumes from enabled snapshots that are fully initialized and immediately deliver provisioned performance, at additional cost. FSR is configured for specific Availability Zones. ([AWS Documentation][11])

This matters for RTO.

---

# 37.100 Why FSR can matter in DR

Imagine:

```text
Database EBS volume
=
2 TB
```

You successfully restore it quickly.

But production workload immediately starts hammering previously untouched blocks.

Without considering initialization behavior, your application may technically be:

```text
UP
```

while performance is:

```text
terrible.
```

So DR needs to consider:

```text
Restore completion
≠
Production-ready performance
```

FSR is one available EBS mechanism for workloads where immediate full snapshot-restored volume performance matters. ([AWS Documentation][11])

---

# 37.101 S3 also needs a backup strategy

Students often think:

> "S3 is durable, so backups are unnecessary."

Durability and logical recovery solve different problems.

You might need to recover from:

```text
accidental deletion
malicious deletion
application overwrite
bad automation
object corruption at application level
```

AWS Backup currently supports both periodic and continuous backup modes for Amazon S3. Continuous AWS Backup for S3 supports point-in-time recovery within the last 35 days, while periodic backups can be retained for longer policy-defined periods. ([AWS Documentation][12])

---

# 37.102 S3 continuous backup dependency

AWS Backup continuous S3 protection relies on Amazon S3 events through EventBridge; AWS documents that disabling the relevant EventBridge setting for the bucket stops continuous backup for that bucket. ([AWS Documentation][12])

This is an excellent production lesson:

```text
Backup feature
has dependencies.
```

Always ask:

```text
What must remain enabled
for this protection mechanism
to keep functioning?
```

---

# 37.103 S3 PITR vs cross-Region copies nuance

AWS Backup supports cross-account and cross-Region copies for S3 backups, but when continuous backups are copied, those copies do **not** retain PITR capability—they become periodic/snapshot-style recovery points. ([AWS Documentation][12])

This is a fantastic example of why we must verify feature combinations.

Don't assume:

```text
Source has PITR
       ↓
every copy also has PITR
```

---

# 37.104 Production backup pattern: local + cross-Region

Primary:

```text
ap-south-1

Production
    │
    ▼
Local Backup Vault
```

Then:

```text
Copy
  │
  ▼
ap-southeast-1

DR Backup Vault
```

AWS Backup supports cross-Region copy for supported resources; backup plans can define destination Region/vault and retention behavior for those copies. ([AWS Documentation][13])

Why?

Because if your recovery strategy protects only the same Region:

```text
Primary Region
       X
```

your recovery architecture may depend on the failure mode and service availability in that Region.

Cross-Region backup adds another recovery boundary.

---

# 37.105 Cross-account backup

Now consider ransomware or credential compromise.

If attacker gains broad control in:

```text
Production Account
```

and backups also live only in:

```text
Production Account
```

the attack may threaten both production and recovery assets depending on permissions/protection controls.

AWS Backup supports cross-account backup copying within supported AWS Organizations configurations, allowing backup copies to be stored in a separate account for operational and security separation. ([AWS Documentation][14])

Architecture:

```text
PRODUCTION ACCOUNT
       │
       │ backup copy
       ▼
BACKUP ACCOUNT
```

That separation is extremely valuable.

---

# 37.106 Cross-account + cross-Region

A mature architecture may become:

```text
                     PRODUCTION

                  ap-south-1
                     │
                     ▼
              Local Backup Vault
                     │
                     │ COPY
                     ▼
          ┌───────────────────────┐
          │ CENTRAL BACKUP       │
          │ ACCOUNT              │
          │                      │
          │ ap-southeast-1       │
          │ DR Backup Vault      │
          └───────────────────────┘
```

Now we have two separations:

```text
ACCOUNT boundary
+
REGION boundary
```

Cross-account and cross-Region copy capabilities depend on the protected resource and feature combination, so always confirm the AWS Backup feature matrix for the exact resource. ([AWS Documentation][1])

---

# 37.107 Encryption of copies

AWS Backup encrypts cross-account or cross-Region copies for most resource types, using the destination-vault key according to the resource's encryption model. The precise key rules differ between resources that are fully managed by AWS Backup and those whose underlying service controls encryption, so KMS planning must be part of the recovery design. ([AWS Documentation][15])

Mental model:

```text
Source backup
     │
     │ COPY
     ▼
Destination vault
     │
     ▼
Destination encryption
configuration
```

Don't treat KMS as an afterthought.

---

# 37.108 Classic DR failure: backup exists, KMS does not

Imagine:

```text
Backup copy ✓

Recovery Region ✓

Terraform ✓

Application image ✓
```

But the restored resource requires encryption/decryption permissions involving KMS and those permissions weren't designed correctly.

Result:

```text
Backup exists.

Restore fails.
```

Therefore:

> **A recovery point without usable recovery permissions is not a complete DR solution.**

---

# 37.109 Backup Vault Lock

Now we enter ransomware-resilience territory.

# AWS Backup Vault Lock

can apply write-once-read-many-style retention controls to recovery points in a backup vault. AWS currently provides two modes:

```text
Governance Mode

Compliance Mode
```

In governance mode, sufficiently privileged IAM identities can remove/manage the lock. In compliance mode, after the configured grace period expires, the lock becomes immutable; even the account/data owner or AWS cannot alter/delete the lock while protected recovery points remain subject to retention. ([AWS Documentation][16])

---

# 37.110 Governance Mode

Mental model:

```text
Normal admin
      X
cannot casually modify/delete

Highly privileged
authorized identity
      │
      ▼
may manage/remove lock
```

Use when you want:

```text
strong organizational guardrail
```

while still preserving an emergency administrative override. AWS documents governance mode as manageable by users with sufficient IAM permissions. ([AWS Documentation][16])

---

# 37.111 Compliance Mode

This is much stronger.

After its grace/cooling-off period:

```text
Vault Lock
    │
    ▼
IMMUTABLE
```

AWS documents that once the compliance-mode grace period expires, the Vault Lock configuration can't be removed or modified, and protected backups can't be deleted before lifecycle retention completes—even by the account's root-level owner or by AWS. ([AWS Documentation][16])

This should make you think:

# Ransomware-resistant retention control.

---

# 37.112 Compliance Mode danger

Immutability is powerful.

It's also unforgiving.

Suppose you accidentally configure:

```text
Retention:
very long / indefinite
```

then permanently lock it.

AWS warns that after compliance mode becomes immutable, those recovery points remain until their defined lifecycle expires, which can lead to persistent storage charges if retention was configured incorrectly. ([AWS Documentation][16])

Never treat:

```text
Compliance Vault Lock
```

as:

```text
"click enable and experiment."
```

Design and test carefully before the grace period ends.

---

# 37.113 Vault Lock WORM

WORM means:

# Write Once, Read Many

Mental picture:

```text
BACKUP CREATED
     │
     ▼
cannot be altered/deleted
during required retention
     │
     ▼
RESTORE allowed
```

Vault Lock's WORM controls exist specifically to add protection against accidental or malicious deletion. ([AWS Documentation][16])

---

# 37.114 Modern AWS Backup concept — Logically Air-Gapped Vault

AWS Backup also supports:

# Logically air-gapped vaults

These are specialized vaults with stronger isolation/recovery characteristics than standard vaults. AWS documents them as coming with compliance-mode Vault Lock, storing backups in an AWS Backup service-owned account, and supporting sharing/recovery patterns through mechanisms such as AWS RAM and Multi-party approval. ([AWS Documentation][17])

Conceptually:

```text
PRODUCTION ACCOUNT
       │
       │ backup
       ▼
LOGICALLY AIR-GAPPED
BACKUP VAULT
       │
       │ isolated recovery path
       ▼
RECOVERY ACCOUNT
```

---

# 37.115 Why "logically air-gapped"?

Traditional physical air gap:

```text
Production system

     X

Offline backup media
```

No normal network relationship.

Cloud environments can't always use literal unplugged tapes for every workload, so logical air-gapping focuses on strong separation, immutability, and controlled access boundaries.

AWS's logically air-gapped vault stores protected backups in an AWS Backup service-owned account while allowing controlled recovery/share capabilities. ([AWS Documentation][17])

---

# 37.116 Modern ransomware-resilience architecture

Think:

```text
                    PRODUCTION ACCOUNT

                     Application
                         │
                         ▼
                    Local Backup
                         │
                         │ copy
                         ▼

              CENTRAL BACKUP ACCOUNT
                         │
                 Backup Vault
                         │
                         │
                         ▼
              Logically Air-Gapped
                    Vault

                         +

                    Vault Lock

                         +

                Cross-Region copy
```

Not every workload requires every layer, but this is the kind of defense-in-depth recovery architecture mature organizations evaluate. Logically air-gapped vault feature support varies by resource and Region. ([AWS Documentation][17])

---

# 37.117 The "3 copies" mindset

A useful architecture concept is to avoid relying on one copy in one failure domain.

Conceptually:

```text
COPY 1
Production data

COPY 2
Backup

COPY 3
Separated backup
different account/Region/
stronger isolation
```

The exact number/placement should follow your regulatory, RTO, RPO, risk, and cost requirements.

The key principle is:

```text
A backup sharing the same
failure/administrative domain
may not protect against
every disaster.
```

---

# 37.118 Lifecycle management

Backups don't need identical storage characteristics forever.

Example:

```text
0–30 days
Frequently recoverable
warm backup storage

       ↓

long-term
cold/archive tier
where supported

       ↓

retention expires
DELETE
```

AWS Backup lifecycle rules can transition supported backup types to cold storage and expire them later. Feature support differs by resource type; backups moved to AWS Backup cold storage must currently remain there for at least **90 days**, with lifecycle constraints based on the transition point. ([AWS Documentation][18])

---

# 37.119 Why lifecycle matters

Without lifecycle:

```text
Daily backup
×
365 days
×
hundreds of resources
```

can create huge:

```text
backup inventory
+
storage bill
```

Too aggressive deletion, however, can violate:

```text
RPO requirements
legal retention
audit requirements
ransomware recovery window
```

So lifecycle is both:

```text
COST CONTROL
+
RECOVERY POLICY
```

---

# 37.120 Example retention strategy

Illustrative only:

```text
Hourly recovery points
→ 48 hours

Daily
→ 35 days

Monthly
→ 12 months

Annual
→ 7 years
```

Whether this is correct depends entirely on:

```text
business
compliance
RPO
RTO
cost
data classification
```

Don't copy another company's retention policy blindly.

---

# 37.121 Critical concept — backup frequency vs retention

These are different.

```text
FREQUENCY
=
How often do I create recovery points?


RETENTION
=
How long do I keep them?
```

Example:

```text
Backup every hour
Keep 7 days
```

means roughly:

```text
frequent recovery options
within a short history.
```

Whereas:

```text
Backup daily
Keep 7 years
```

means:

```text
long history
but coarse short-term recovery points.
```

---

# 37.122 Backup RPO is NOT necessarily restore RTO

Suppose:

```text
Backup every 5 minutes
```

Great potential RPO.

But recovery process requires:

```text
restore 10-TB database
      ↓
recreate compute
      ↓
update DNS
      ↓
validate app
```

and takes:

```text
6 hours.
```

Then:

```text
RPO ≈ very small

RTO ≈ hours
```

They are separate objectives.

This is exactly why we learned RTO and RPO before AWS services.

---

# 37.123 The biggest backup question

Not:

> "Did the backup job succeed?"

The real question:

# "Can I restore it?"

This leads to one of AWS Backup's most important production capabilities:

# Restore Testing.

AWS Backup restore testing can periodically create restore jobs from selected recovery points and measure restore-job completion time, providing automated evidence that recovery points can actually be restored. ([AWS Documentation][19])

---

# 37.124 Restore Testing

Architecture:

```text
Backup Vault
     │
     ▼
Recovery Point
     │
     │ scheduled test
     ▼
AWS Backup
Restore Testing
     │
     ▼
Temporary Restored Resource
     │
     ▼
Validation
```

AWS Backup restore-testing plans let you specify testing schedules and protected-resource selections; AWS Backup then performs restore jobs and records the restore duration. ([AWS Documentation][19])

This is a huge improvement over:

```text
Backup job:
SUCCESS

everyone assumes DR works.
```

---

# 37.125 But restore completion still isn't application validation

Imagine AWS successfully restores:

```text
EC2 instance
```

AWS Backup says:

```text
Restore:
COMPLETED
```

But:

```text
nginx doesn't start

database connection broken

secret missing

application health check fails
```

Your actual application recovery:

```text
FAILED.
```

AWS Backup supports integrating restore-testing completion events with EventBridge-driven validation workflows, for example invoking Lambda or another supported target to perform post-restore validation. ([AWS Documentation][20])

So mature testing becomes:

```text
RESTORE
   ↓
INFRASTRUCTURE VALIDATION
   ↓
APPLICATION VALIDATION
   ↓
RTO MEASUREMENT
```

---

# 37.126 Example validation

Restored EC2:

```text
10.x.x.x
```

Validation might test:

```bash
curl -f http://<restored-host>/health
```

Expected:

```text
HTTP 200
```

For database:

```text
connect
     ↓
run read query
     ↓
verify expected schema/data
```

For S3:

```text
object restored?
metadata?
tags?
expected object count?
```

Don't merely check:

```text
resource exists.
```

Check:

```text
resource is usable.
```

---

# 37.127 Restore testing proves your RTO assumptions

Suppose business requires:

```text
RTO = 60 minutes
```

Restore testing shows:

```text
RDS restore:
52 minutes

Application validation:
18 minutes

DNS/cutover:
5 minutes
```

Total:

```text
75 minutes
```

Then the architecture does:

# NOT meet the RTO.

This is why measured recovery matters more than PowerPoint architecture.

---

# 37.128 Backup account architecture

Now let's design an enterprise structure.

```text
AWS ORGANIZATION
│
├── Production OU
│    │
│    └── Payments Prod Account
│
├── Infrastructure OU
│
└── Security / Recovery OU
     │
     └── Central Backup Account
```

Flow:

```text
Payments Prod
     │
     ▼
Local Recovery Point
     │
     │ cross-account copy
     ▼
Central Backup Account
     │
     ▼
Protected Backup Vault
     │
     │ cross-Region / isolated copy
     ▼
DR Region
```

AWS Backup supports organization-level cross-account management and backup-policy standardization through AWS Organizations for supported environments. ([AWS Documentation][21])

---

# 37.129 Why application admins shouldn't control everything

Imagine one identity has permission to:

```text
delete production DB

delete backups

remove backup policies

delete KMS keys

delete backup vault
```

A compromised credential could destroy:

```text
PRODUCTION
+
RECOVERY
```

You want separation:

```text
Application Team
      │
      ▼
Application resources


Backup/Security Team
      │
      ▼
Backup governance


Separate Backup Account
      │
      ▼
protected recovery points
```

Cross-account backup plus Vault Lock/logical air-gap controls can provide strong defense-in-depth against a single compromised production administrative boundary. ([AWS Documentation][14])

---

# 37.130 Terraform — start building AWS Backup

Let's map the architecture into IaC.

Conceptually:

```hcl
resource "aws_backup_vault" "prod" {
  name = "prod-critical-backups"
}
```

Then a plan:

```hcl
resource "aws_backup_plan" "prod" {
  name = "prod-critical"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.prod.name
    schedule          = "cron(0 1 * * ? *)"

    lifecycle {
      delete_after = 35
    }
  }
}
```

Mental meaning:

```text
Every day
    ↓
create backup
    ↓
store in vault
    ↓
retain according
to lifecycle
```

For production, we'd also handle IAM roles, resource selection, copy actions, encryption, Vault Lock, and tagging rather than stopping at this minimal example.

---

# 37.131 Resource assignment in Terraform

Conceptually:

```hcl
resource "aws_backup_selection" "critical" {
  name         = "critical-resources"
  plan_id      = aws_backup_plan.prod.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_db_instance.prod.arn
  ]
}
```

Or use an architecture based on appropriate tags/resource selection for larger environments.

Think:

```text
Plan
   │
Selection
   │
Resource
```

---

# 37.132 Cross-Region copy rule

Conceptually:

```hcl
rule {
  rule_name         = "daily"
  target_vault_name = aws_backup_vault.prod.name

  copy_action {
    destination_vault_arn = var.dr_vault_arn

    lifecycle {
      delete_after = 90
    }
  }
}
```

Then:

```text
Mumbai
Backup
   │
   │ COPY
   ▼
Singapore
Backup Vault
```

Cross-Region copy availability must be verified for the exact resource type and Regions. ([AWS Documentation][13])

---

# 37.133 Vault Lock Terraform concept

The architecture becomes:

```text
Backup Vault
     │
     ▼
Vault Lock

Min retention
Max retention
Governance/Compliance behavior
```

For compliance mode, the irreversible stage after the grace period is precisely why this should be deployed through reviewed IaC/change control rather than casual console experimentation. ([AWS Documentation][16])

---

# 37.134 Production backup policy example

Imagine:

```text
PAYMENTS DATABASE
```

Business requirement:

```text
RPO:
5 minutes

RTO:
30 minutes

Short-term corruption recovery:
35 days

Long-term audit retention:
7 years

Region disaster protection:
required

Ransomware protection:
required
```

One solution might require **multiple complementary mechanisms**:

```text
Continuous/PITR protection
         │
         ├── fine-grained recent recovery
         │
         ▼
Periodic Recovery Points
         │
         ├── longer-term retention
         │
         ▼
Cross-Region Copies
         │
         ▼
Cross-Account Vault
         │
         ▼
Vault Lock /
Logically Air-Gapped Vault
         │
         ▼
Restore Testing
```

No single snapshot solves every requirement.

---

# 37.135 Backup strategy by failure type

| Failure                       | Useful protection                      |
| ----------------------------- | -------------------------------------- |
| EC2 volume corruption         | EBS snapshot                           |
| Bad DB transaction            | RDS/Aurora PITR                        |
| DB upgrade failure            | Manual snapshot/PITR                   |
| S3 object deletion            | S3 recovery/versioning/backup strategy |
| Production account compromise | Cross-account backup                   |
| Region disaster               | Cross-Region backup                    |
| Ransomware/admin deletion     | Vault Lock / isolated backup design    |
| Backup unusable               | Restore testing                        |
| Very old audit requirement    | Long-term retained recovery points     |

The exact supported mechanism varies by AWS resource; always verify the current AWS Backup feature matrix for resource/Region support. ([AWS Documentation][1])

---

# 37.136 The ransomware scenario

Imagine attacker obtains powerful production credentials.

They execute:

```text
Delete database

Delete EC2

Delete S3 objects

Delete snapshots

Delete backup jobs
```

Bad design:

```text
Production
     │
     └── all backups under
         same administrative
         control
```

Potential catastrophe.

Better defense-in-depth:

```text
PRODUCTION ACCOUNT
      │
      ▼
automated backup
      │
      ▼
BACKUP ACCOUNT
      │
      ▼
Locked/isolated vault
      │
      ▼
Cross-Region recovery
```

AWS's cross-account copies, Vault Lock, and logically air-gapped vault capabilities are specifically useful building blocks for this kind of separated recovery design. ([AWS Documentation][14])

---

# 37.137 Backup success is a chain

Think:

```text
RESOURCE
   ↓
BACKUP JOB
   ↓
RECOVERY POINT
   ↓
VAULT
   ↓
ENCRYPTION
   ↓
RETENTION
   ↓
COPY
   ↓
IMMUTABILITY
   ↓
RESTORE
   ↓
VALIDATION
```

If any critical step fails:

```text
DR readiness
is reduced.
```

---

# 37.138 The three questions about every backup

Whenever someone tells you:

> "We have backups."

Ask:

```text
WHEN was the last valid recovery point?

WHERE is the backup stored?

WHEN did we last successfully restore it?
```

Those three questions reveal an enormous amount.

---

# 37.139 The strongest interview answer

Interview:

> "How would you design backup and recovery for a critical production workload on AWS?"

A strong answer is not:

> "I would enable AWS Backup."

A stronger answer:

> I would begin with the workload's RTO, RPO, retention, security, and compliance requirements. Then I'd choose service-native recovery mechanisms such as PITR or snapshots as appropriate, centrally govern supported resources through AWS Backup, maintain cross-Region and possibly cross-account copies, protect critical recovery points against deletion using Vault Lock or an isolated vault architecture, verify KMS and IAM recovery permissions, and periodically perform automated restore testing plus application-level validation.

Every major component of that answer maps directly to AWS's current backup capabilities. ([AWS Documentation][1])

---

# 37.140 Never-forget backup distinctions

```text
BACKUP
=
historical recoverable copy


REPLICATION
=
copy ongoing changes elsewhere


SNAPSHOT
=
point-in-time recovery point


PITR
=
restore to selected historical time


BACKUP PLAN
=
policy


BACKUP RULE
=
schedule/lifecycle rule


VAULT
=
recovery-point container


VAULT LOCK
=
retention immutability control


CROSS-REGION
=
different regional failure boundary


CROSS-ACCOUNT
=
different administrative boundary


RESTORE TEST
=
prove recovery point can restore
```

---

# 37.141 Most important rule from Part 2

> **A backup is not proven until you restore it.**

And I'd extend it:

> **A restore is not proven until the application works.**

So:

```text
BACKUP SUCCESS
       ↓
is not enough


RESTORE SUCCESS
       ↓
is better


APPLICATION VALIDATION SUCCESS
       ↓
is what the business actually cares about
```

AWS Backup restore testing can automate periodic restore viability and duration measurements, while EventBridge-triggered validation can extend testing into application/resource checks. ([AWS Documentation][19])

---

# 37.142 Part 2 architecture

You should now understand:

```text
                         PRIMARY REGION
                          ap-south-1

                      Production Workload
                      /       |        \
                    EBS      RDS        S3
                     │        │          │
                     └────────┼──────────┘
                              ▼
                         AWS BACKUP
                              │
                        Backup Plan
                              │
                        Recovery Points
                              │
                              ▼
                         Local Vault
                              │
                  ┌───────────┴───────────┐
                  │                       │
             Vault Lock              COPY ACTION
                                          │
                                          ▼
                                CENTRAL BACKUP ACCOUNT
                                          │
                                          ▼
                                     DR REGION
                                  ap-southeast-1
                                          │
                                          ▼
                                 Protected Backup Vault
                                          │
                                          ▼
                                Logically Air-Gapped
                                      Vault
                                          │
                                          ▼
                                   Restore Testing
                                          │
                                          ▼
                               Application Validation
```

That is what **Backup & Restore DR** looks like when treated as a production architecture rather than a checkbox.

---

# Lesson 37 progress

```text
Part 1
HA vs DR + RTO/RPO +
four recovery strategies              ✓

Part 2
AWS Backup & Restore Deep Dive        ✓

Part 3
Pilot Light & Warm Standby            NEXT

Part 4
Active/Passive Multi-Region

Part 5
Active/Active Multi-Region

Part 6
Multi-Region Data Layer

Part 7
Application Recovery Controller

Part 8
DR Automation / Testing / Chaos

Part 9
Complete DR Capstone

Part 10
Final Revision / Interviews
```

# Next — Lesson 37, Part 3

## Pilot Light vs Warm Standby — Production Multi-Region Architecture

Now we'll move from:

```text
DR Region contains
mostly backups
```

to:

```text
DR Region contains
actual running infrastructure.
```

We'll build and compare:

```text
PILOT LIGHT

Mumbai
████████████

Singapore
██


WARM STANDBY

Mumbai
████████████

Singapore
█████
```

Then we'll go component-by-component through **VPCs, ALBs, Auto Scaling/ECS/EKS, container images, AMIs, databases, Secrets Manager, KMS, certificates, Route 53, infrastructure state, scaling during failover, database promotion, DNS cutover, capacity quotas, configuration drift, RTO measurement, failback, and Terraform patterns**.

And we'll answer the key production question:

> **Exactly what must already exist in the DR Region before the disaster occurs?**

[1]: https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-feature-availability.html "AWS Backup feature availability - AWS Backup"
[2]: https://docs.aws.amazon.com/aws-backup/latest/devguide/working-with-supported-services.html?utm_source=chatgpt.com "How AWS Backup works with supported AWS services"
[3]: https://docs.aws.amazon.com/aws-backup/latest/devguide/about-backup-plans.html?utm_source=chatgpt.com "Backup plans"
[4]: https://docs.aws.amazon.com/aws-backup/latest/devguide/assigning-resources.html?utm_source=chatgpt.com "Select AWS services to backup - AWS Documentation"
[5]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vaults.html?utm_source=chatgpt.com "Backup vaults"
[6]: https://docs.aws.amazon.com/aws-backup/latest/devguide/point-in-time-recovery.html?utm_source=chatgpt.com "Continuous backups and point-in-time recovery (PITR)"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html?utm_source=chatgpt.com "Restoring a DB instance to a specified time for Amazon RDS"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html?utm_source=chatgpt.com "Restoring to a DB instance - AWS Documentation - Amazon.com"
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html?utm_source=chatgpt.com "Amazon EBS snapshots"
[10]: https://docs.aws.amazon.com/aws-backup/latest/devguide/creating-a-backup.html?utm_source=chatgpt.com "Backup creation by resource type"
[11]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-fast-snapshot-restore.html?utm_source=chatgpt.com "Amazon EBS fast snapshot restore"
[12]: https://docs.aws.amazon.com/aws-backup/latest/devguide/s3-backups.html "Amazon S3 backups - AWS Backup"
[13]: https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS Regions"
[14]: https://docs.aws.amazon.com/aws-backup/latest/devguide/create-cross-account-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS accounts"
[15]: https://docs.aws.amazon.com/aws-backup/latest/devguide/encryption.html "Encryption for backups in AWS Backup - AWS Backup"
[16]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html "AWS Backup Vault Lock - AWS Backup"
[17]: https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html "Logically air-gapped vault - AWS Backup"
[18]: https://docs.aws.amazon.com/aws-backup/latest/devguide/plan-options-and-configuration.html?utm_source=chatgpt.com "Backup plan options and configuration - AWS Documentation"
[19]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html "Restore testing - AWS Backup"
[20]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing-validation.html?utm_source=chatgpt.com "Restore testing validation - AWS Backup"
[21]: https://docs.aws.amazon.com/aws-backup/latest/devguide/manage-cross-account.html?utm_source=chatgpt.com "Managing AWS Backup resources across multiple AWS ..."
