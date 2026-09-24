# AWS Masterclass — Lesson 25 Part 3

# EBS Snapshots, Backup Engineering & Disaster Recovery

Now we move from:

```text
"How fast is my disk?"
```

to:

```text
"If this disk, EC2 instance, Availability Zone,
AWS account, or even Region is lost...

HOW DO I GET MY DATA BACK?"
```

That is a completely different engineering problem.

Our mental model becomes:

```text
                 PRODUCTION DATA
                       │
                       ▼
                    EBS Volume
                       │
              ┌────────┴────────┐
              │                 │
              ▼                 ▼
         Performance          Protection
              │                 │
        IOPS/Throughput      Snapshots
                                │
                 ┌──────────────┼──────────────┐
                 ▼              ▼              ▼
             Same Region    Cross-Region   Cross-Account
                 │              │              │
                 └──────────────┼──────────────┘
                                ▼
                         Disaster Recovery
                                │
                           RPO + RTO
```

---

# 1. What Exactly Is an EBS Snapshot?

An EBS snapshot is a **point-in-time backup of an EBS volume**.

Suppose your volume contains:

```text
EBS Volume

Block A
Block B
Block C
Block D
Block E
```

Snapshot 1 captures the data needed to reconstruct the volume at that point:

```text
             EBS Volume
                 │
                 ▼
            Snapshot-001
```

AWS states that each snapshot contains all the information required to restore the volume's data as it existed when that snapshot was taken. ([AWS Documentation][1])

From the snapshot:

```text
Snapshot
   │
   ▼
CreateVolume
   │
   ▼
New EBS
   │
   ▼
Attach to EC2
```

So snapshot is your:

> **restore point**, not another mounted disk.

---

# 2. Snapshots Are Incremental

This is one of the most important EBS concepts.

Imagine the first snapshot:

```text
Volume:

A B C D E

     ↓

Snapshot 1:

A B C D E
```

Later only C and E change:

```text
Volume:

A B X D Y
```

The next snapshot doesn't need to duplicate every unchanged block again.

Conceptually:

```text
Snapshot 1

A B C D E


Snapshot 2

    X   Y
```

Standard-tier EBS snapshots are incremental: after the initial snapshot, AWS stores changed blocks rather than another full physical copy of every unchanged block. ([AWS Documentation][2])

---

# 3. The Incremental Snapshot Myth

People often conclude:

> “If Snapshot 2 only contains changed blocks, I can never delete Snapshot 1.”

That is **wrong**.

Imagine:

```text
S1
 │
 ▼
S2
 │
 ▼
S3
```

You delete:

```text
S1
```

AWS manages the backing blocks required by remaining snapshots.

Therefore:

```text
delete S1

does NOT automatically destroy S2 and S3
```

AWS specifically states that deleting an incremental snapshot removes only blocks that are no longer referenced by another snapshot; blocks required by later snapshots are retained. ([AWS Documentation][3])

### Never forget

```text
Snapshots are incremental
IN STORAGE IMPLEMENTATION,

but each snapshot behaves like
a complete restore point.
```

You don't manually maintain a dependency chain.

---

# 4. Snapshot vs Volume

Do not confuse:

```text
EBS Volume
=
live writable block storage


Snapshot
=
point-in-time backup
```

You don't normally do:

```text
EC2
 │
 ▼
Snapshot
```

Instead:

```text
Snapshot
   │
   ▼
Create Volume
   │
   ▼
Attach Volume
   │
   ▼
EC2
```

---

# 5. Basic Snapshot Hands-On

Suppose:

```bash
export AWS_REGION="ap-south-1"
export VOLUME_ID="vol-0123456789abcdef0"
```

Create the snapshot:

```bash
SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id "$VOLUME_ID" \
  --description "Lesson25 production data backup" \
  --region "$AWS_REGION" \
  --tag-specifications \
    'ResourceType=snapshot,Tags=[{Key=Name,Value=lesson25-data-backup},{Key=Environment,Value=lab}]' \
  --query 'SnapshotId' \
  --output text)

echo "$SNAPSHOT_ID"
```

Check it:

```bash
aws ec2 describe-snapshots \
  --snapshot-ids "$SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --query 'Snapshots[0].{
      SnapshotId:SnapshotId,
      State:State,
      Progress:Progress,
      VolumeSize:VolumeSize,
      Encrypted:Encrypted,
      StartTime:StartTime
  }' \
  --output table
```

Typical progression:

```text
pending
   ↓
completed
```

---

# 6. Can I Continue Using the Volume During Snapshot Creation?

Yes, but consistency needs thought.

AWS recommends pausing writes before snapshot creation where possible. If writes can't be paused, AWS suggests unmounting the volume before taking the snapshot when that is operationally feasible. Once the snapshot enters `pending`, writes can resume. ([AWS Documentation][4])

Why?

Consider:

```text
Database transaction:

Step 1 → update accounts table
Step 2 → update ledger
Step 3 → commit
```

Snapshot happens between:

```text
Step 1
   │
   ▼
SNAPSHOT
   │
   ▼
Step 2
```

The block device may capture a state that requires crash recovery when restored.

That brings us to one of the most important backup concepts.

---

# 7. Crash-Consistent vs Application-Consistent

These are **not the same thing**.

## Crash-consistent

Imagine:

```text
Server suddenly loses power
```

Whatever was safely persisted to storage at that moment is what you recover.

Crash-consistency means the storage state resembles what the machine would have after an abrupt power loss.

```text
Application
     │
 active writes
     │
     X ← sudden crash
     │
 Snapshot state
```

Filesystems and databases designed with journals/WAL may recover from this, but application recovery logic is still involved.

---

# 8. Application-Consistent

Application-consistent backup goes further.

The application participates.

Conceptually:

```text
Application running
       │
       ▼
Stop/flush application writes
       │
       ▼
Flush database buffers
       │
       ▼
Complete transactions
       │
       ▼
Quiesce filesystem/application
       │
       ▼
Create snapshot
       │
       ▼
Resume application
```

Now your recovery point better reflects a logically consistent application state.

For supported Windows workloads, AWS supports VSS-based application-consistent snapshot mechanisms, and Data Lifecycle Manager can integrate application-consistency workflows. ([AWS Documentation][5])

---

# 9. Database Example

Imagine PostgreSQL files are distributed across:

```text
Volume 1
/data/postgres

Volume 2
/wal
```

Taking:

```text
Snapshot Volume 1 at 10:00:00

Snapshot Volume 2 at 10:00:15
```

can be dangerous.

Why?

Because database state across both devices may not represent the same instant.

You want:

```text
          10:00:00
              │
       ┌──────┴──────┐
       ▼             ▼
  Snapshot V1    Snapshot V2

same coordinated recovery point
```

---

# 10. Multi-Volume Snapshots

AWS supports **crash-consistent multi-volume snapshots** for volumes attached to an EC2 instance.

Instead of:

```text
snapshot volume A
wait
snapshot volume B
wait
snapshot volume C
```

you can tell EC2:

```text
Snapshot the volumes
attached to THIS INSTANCE
as one coordinated set.
```

AWS's `CreateSnapshots` operation creates point-in-time, crash-consistent snapshots across the selected EBS volumes attached to an instance. ([AWS Documentation][6])

Architecture:

```text
                 EC2
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
      EBS-A     EBS-B     EBS-C
        │         │         │
        └─────────┼─────────┘
                  │
             same recovery
                moment
```

---

# 11. CLI Multi-Volume Snapshot

Suppose:

```bash
export INSTANCE_ID="i-0123456789abcdef0"
```

Create snapshots for its attached EBS volumes:

```bash
aws ec2 create-snapshots \
  --instance-specification \
    InstanceId="$INSTANCE_ID",ExcludeBootVolume=false \
  --description "Lesson25 multi-volume backup" \
  --region ap-south-1
```

If you want to exclude the root disk:

```bash
aws ec2 create-snapshots \
  --instance-specification \
    InstanceId="$INSTANCE_ID",ExcludeBootVolume=true \
  --description "Lesson25 data-volume backup" \
  --region ap-south-1
```

This gives you a crash-consistent group of EBS snapshots. ([AWS Documentation][6])

---

# 12. AWS Backup and Multi-Volume Consistency

AWS Backup can also coordinate EBS backups for EC2.

For EBS volumes attached to an EC2 instance, AWS Backup produces multi-volume, crash-consistent backups so the associated volumes share the same point-in-time recovery state. ([AWS Documentation][7])

Think:

```text
One EC2

/
├── EBS root
├── EBS database
├── EBS WAL
└── EBS application data

         ↓

      AWS Backup

         ↓

coordinated recovery point
```

---

# 13. Restoring a Snapshot

Suppose our original volume dies.

We don't normally “restore over” that EBS volume.

Instead:

```text
Snapshot
   │
   ▼
Create NEW EBS Volume
```

Example:

```bash
aws ec2 create-volume \
  --snapshot-id "$SNAPSHOT_ID" \
  --availability-zone ap-south-1a \
  --volume-type gp3 \
  --region ap-south-1
```

AWS states that a new EBS volume created from a snapshot starts as a replica of the source volume's captured data. ([AWS Documentation][1])

---

# 14. This Solves the Cross-AZ Problem

Remember the EBS rule:

```text
EBS
=
AZ scoped
```

Suppose:

```text
Original volume:
ap-south-1a

AZ-a becomes unavailable
```

You cannot simply attach that volume to:

```text
EC2 in ap-south-1b
```

But snapshots change the recovery path.

```text
EBS
ap-south-1a
   │
   ▼
Snapshot
   │
   ▼
Create new EBS
ap-south-1b
   │
   ▼
EC2
ap-south-1b
```

That makes snapshots useful for **cross-AZ recovery**.

---

# 15. Snapshot Restore Performance Surprise

Suppose you restore:

```text
1 TiB snapshot
     ↓
1 TiB EBS
```

Volume creation can complete quickly.

You then start the application.

And:

```text
first reads
=
slower than expected
```

Why?

Volumes restored from snapshots can load previously untouched blocks on first access. AWS calls this initialization behavior; accessing blocks before initialization may introduce first-read latency. ([AWS Documentation][8])

Mental model:

```text
Restored volume
      │
      ├── block already loaded
      │      ↓
      │     normal
      │
      └── first access to unloaded block
             ↓
          fetch data
             ↓
       additional latency
```

---

# 16. Volume Initialization

For performance-sensitive recovery, you can initialize the volume by reading its blocks before putting the workload under full production load.

Conceptually:

```text
Create volume from snapshot
          ↓
Read/initialize blocks
          ↓
Validate
          ↓
Start production workload
```

AWS explicitly recommends initialization when you need restored volumes to reach expected performance before workload use. ([AWS Documentation][8])

But there's another option.

---

# 17. Fast Snapshot Restore — FSR

Fast Snapshot Restore allows volumes created from enabled snapshots to be **fully initialized immediately at creation**.

```text
Normal restore:

Snapshot
   ↓
Volume
   ↓
first-read initialization
   ↓
full performance


FSR:

Snapshot
   ↓
fully initialized Volume
   ↓
full performance immediately
```

AWS states that volumes created from FSR-enabled snapshots can immediately deliver their provisioned performance without first-access initialization latency. ([AWS Documentation][9])

This matters for:

```text
critical DR restore
database recovery
large production volumes
rapid scale-out from snapshot-based data
```

FSR has additional cost implications, so it is normally enabled intentionally rather than blindly for every snapshot.

---

# 18. Snapshot Copy

Now imagine:

```text
Production Region

ap-south-1
Mumbai
```

If your disaster definition includes loss of the entire Region, storing every recovery mechanism only inside Mumbai isn't sufficient.

We can copy snapshots.

```text
ap-south-1

Snapshot
   │
   │ CopySnapshot
   ▼

ap-southeast-1
Singapore

Snapshot copy
```

EBS supports copying snapshots into other Regions. ([AWS Documentation][10])

---

# 19. Cross-Region Snapshot Copy

Example:

```bash
SOURCE_REGION="ap-south-1"
DR_REGION="ap-southeast-1"
```

Copy:

```bash
aws ec2 copy-snapshot \
  --source-region "$SOURCE_REGION" \
  --source-snapshot-id "$SNAPSHOT_ID" \
  --description "DR copy from Mumbai" \
  --region "$DR_REGION"
```

Now your DR copy isn't dependent solely on:

```text
ap-south-1
```

Conceptually:

```text
               Primary
             ap-south-1
                  │
                  ▼
               Snapshot
                  │
             copy│
                  ▼
            ap-southeast-1
                  │
                  ▼
            DR Snapshot
```

---

# 20. Incremental Cross-Region Copy Nuance

EBS snapshot copies can be incremental under qualifying conditions.

However, changing encryption keys or copy history can affect whether the copy is full or incremental. AWS documents that copying within the same account/Region using the same KMS key remains incremental, while changing the KMS key causes a full copy; cross-Region and cross-account copies are incremental only when AWS can associate them with a previous qualifying copy. ([AWS Documentation][10])

Don't build cost projections assuming:

```text
"Every snapshot copy is always incremental."
```

Understand the copy conditions.

---

# 21. Cross-Account Protection

Now go one step further.

Suppose production account:

```text
Account A
111111111111
```

gets compromised.

An attacker with enough permissions might attempt:

```text
delete production
delete snapshots
delete backup resources
```

A stronger architecture can maintain recovery copies in:

```text
Account B
222222222222
Dedicated backup account
```

Architecture:

```text
        Production Account
               │
               ▼
           EBS snapshot
               │
          cross-account
               │
               ▼
         Backup Account
               │
               ▼
        protected recovery
              copy
```

AWS supports cross-account snapshot sharing/copy workflows, and AWS Backup supports cross-account backup copies into appropriately configured backup vaults. ([AWS Documentation][11])

---

# 22. Encryption Complicates Cross-Account Sharing

Suppose:

```text
EBS encrypted
    │
    ▼
Snapshot encrypted
```

Encryption uses KMS.

If you share an encrypted EBS snapshot across accounts, the other account also needs permission to the **customer-managed KMS key** used to encrypt it. ([AWS Documentation][12])

Important limitation:

```text
Snapshot encrypted using:

aws/ebs
AWS managed key

      ↓

cannot be shared cross-account
in the normal EBS snapshot-sharing workflow
```

AWS states that snapshots encrypted with the default AWS managed EBS key cannot be shared; sharing encrypted snapshots requires a customer-managed KMS key. ([AWS Documentation][13])

This is an important SAA/DOP scenario.

---

# 23. EBS Encryption Chain

Remember:

```text
Encrypted EBS
     │
     ▼
Encrypted Snapshot
     │
     ▼
Restored EBS
     │
     ▼
Encrypted
```

AWS states that snapshots taken from encrypted EBS volumes are encrypted, and volumes restored from encrypted snapshots remain encrypted. Encryption cannot simply be removed from an encrypted EBS snapshot or restored volume. ([AWS Documentation][14])

KMS options include:

```text
AWS managed:

aws/ebs


or


Customer managed:

alias/company-prod-ebs
```

EBS uses the account's AWS-managed `aws/ebs` key by default unless another appropriate KMS key is specified. ([AWS Documentation][15])

---

# 24. Why Customer-Managed KMS Keys Matter

Customer-managed keys give you more control over:

```text
key policy
cross-account use
key rotation controls
grants
auditability
access boundaries
```

They're particularly relevant where you need controlled cross-account encrypted snapshot workflows.

Conceptually:

```text
Backup account needs snapshot

       │

Snapshot encrypted?

       │
       YES
       ▼

Can backup account use KMS key?

       │
     NO│
       ▼
Restore/copy fails
```

Always troubleshoot:

```text
Snapshot permissions
+
KMS permissions
```

together.

---

# 25. Data Lifecycle Manager — DLM

Manual snapshots are useful for learning.

Production:

```text
Engineer remembers every night
at exactly 01:00
to run create-snapshot
```

is not production architecture.

Amazon Data Lifecycle Manager can automate EBS snapshot and EBS-backed AMI lifecycle operations including creation, retention, deletion and supported copy workflows. ([AWS Documentation][16])

Mental model:

```text
EBS volumes
    │
    │ tags
    ▼
DLM Policy
    │
    ├── schedule
    ├── snapshot
    ├── retain
    ├── copy
    └── expire
```

---

# 26. Tag-Based Backup Selection

Imagine:

```text
Volume A

Backup = true


Volume B

Backup = true


Volume C

Backup = false
```

DLM policy can target resources according to configured tags.

This gives you:

```text
Infrastructure
     +
Backup policy
     +
Tags
     ↓
Automated protection
```

Instead of manually maintaining volume IDs.

---

# 27. Example DLM Policy Architecture

```text
Production volumes

Backup = Daily
       │
       ▼
     DLM
       │
       ├── snapshot every day
       │
       ├── retain 14
       │
       └── copy to DR Region
```

Current DLM custom policies support richer schedules, long retention, cross-Region copy, archive features, application-consistency hooks, and Fast Snapshot Restore configuration, while simpler default policies have a narrower feature set.

---

# 28. Terraform DLM Example

First IAM role:

```hcl
resource "aws_iam_role" "dlm" {
  name = "lesson25-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "dlm.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

Attach appropriate DLM permissions according to your production security model.

Then conceptually:

```hcl
resource "aws_dlm_lifecycle_policy" "ebs_backup" {
  description        = "Daily production EBS backups"
  execution_role_arn = aws_iam_role.dlm.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Backup = "Daily"
    }

    schedule {
      name = "Daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["01:00"]
      }

      retain_rule {
        count = 14
      }

      tags_to_add = {
        ManagedBy = "DLM"
      }
    }
  }
}
```

Concept:

```text
Every 24 hours
       ↓
snapshot tagged volumes
       ↓
retain 14 recovery points
       ↓
automatically remove old snapshots
```

---

# 29. DLM vs AWS Backup

This distinction is important.

## DLM

Think:

```text
EBS / EC2 snapshot lifecycle specialist
```

Good for:

```text
EBS snapshots
EBS-backed AMIs
snapshot schedules
retention
copy/archive workflows
```

## AWS Backup

Think:

```text
centralized backup platform
```

It can protect many supported AWS resource types and centrally manage backup plans, vaults, lifecycle, copies and organizational policies. ([AWS Documentation][16])

Mental shortcut:

```text
DLM
=
EBS/AMI lifecycle automation


AWS Backup
=
organization-level
data protection framework
```

---

# 30. Enterprise Backup Architecture

A mature environment may look like:

```text
                        AWS Organizations
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
          Dev Acct         Prod Acct       Data Acct
             │                │                │
             └────────────────┼────────────────┘
                              │
                              ▼
                         AWS Backup
                              │
                         Backup Plans
                              │
                              ▼
                         Backup Vault
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
           Primary Region             DR Region
                 │                         │
                 └──────────┬──────────────┘
                            ▼
                    Backup Account
```

AWS Backup supports centralized management across AWS Organizations accounts and cross-account backup operations when configured appropriately. ([AWS Documentation][17])

---

# 31. Backup Vault

Think of a Backup Vault as:

```text
controlled container
for backup recovery points
```

```text
AWS Backup
    │
    ▼
Backup Vault
    │
    ├── EBS recovery points
    ├── database backups
    └── other supported resources
```

AWS Backup vaults organize recovery points and support encryption/access-control policies. ([AWS Documentation][18])

---

# 32. Backup Vault Lock

Now consider ransomware or malicious deletion.

Normal backup:

```text
Attacker obtains powerful credentials
           │
           ▼
Delete backups
```

One defense-in-depth capability is:

# AWS Backup Vault Lock

In Compliance mode, once the configured grace period has passed, AWS documents that the lock configuration cannot be changed or deleted while protected recovery points remain, including by the customer/account owner. ([AWS Documentation][19])

Mental model:

```text
Backup
   │
   ▼
Vault
   │
   ▼
Vault Lock
   │
   ▼
Retention protection
```

This is an **immutability-style backup control**.

---

# 33. Logically Air-Gapped Vault

AWS Backup also provides **logically air-gapped vaults**, which come with additional protections including Compliance-mode Vault Lock and controlled vault sharing for recovery scenarios. AWS recommends considering cross-Region copies for additional resilience. ([AWS Documentation][20])

Think:

```text
Production
    │
    ▼
Normal backup
    │
    ▼
Protected copy
    │
    ▼
Logically air-gapped vault
```

This is closer to enterprise ransomware-resilience thinking.

---

# 34. Recycle Bin

Here is another protection mechanism.

Imagine an administrator executes:

```bash
aws ec2 delete-snapshot ...
```

and realizes:

```text
OH NO
```

Amazon EBS integrates with **Recycle Bin** retention rules.

Matching deleted EBS snapshots, volumes, or EBS-backed AMIs can be retained for a defined period instead of being permanently lost immediately. ([AWS Documentation][21])

Architecture:

```text
Snapshot
   │
delete
   ▼
Recycle Bin
   │
   ├── recover
   │
   └── retention expires
           ↓
       permanent deletion
```

A recovered snapshot returns to normal use. ([AWS Documentation][22])

---

# 35. Snapshot Archive Tier

Suppose you need:

```text
7-year retention
```

but expect almost never to restore those snapshots.

Keeping every recovery point in standard snapshot storage may not be the ideal cost strategy.

EBS provides:

```text
Snapshot Archive
```

for low-cost, long-term storage of rarely accessed snapshots. Archived snapshots must first be restored to the standard tier before they can be used to create an EBS volume. ([AWS Documentation][2])

Think:

```text
Recent backups
      │
      ▼
Snapshot Standard
      │
 after months/years
      ▼
Snapshot Archive
```

Good for:

```text
long-term compliance
historical backups
rarely restored data
```

Not ideal for:

```text
"We need this database restored immediately."
```

---

# 36. RPO — Recovery Point Objective

Now we connect snapshots to business requirements.

AWS defines **RPO** as the maximum acceptable amount of time since the last recovery point — effectively how much recent data the business can accept losing after a disaster. ([AWS Documentation][23])

Example:

```text
Snapshots every 24 hours
```

Worst-case conceptual data-loss window:

```text
almost 24 hours
```

If business says:

```text
"We can lose maximum 15 minutes of data."
```

then:

```text
daily EBS snapshot
```

doesn't meet the requirement.

---

# 37. RTO — Recovery Time Objective

AWS defines **RTO** as the maximum acceptable delay between a service interruption and restoration of service. ([AWS Documentation][23])

Example:

```text
Disaster: 14:00

Service must return by: 14:30

RTO = 30 minutes
```

So:

```text
RPO
=
How much DATA can we lose?


RTO
=
How much TIME can we be down?
```

### Never forget

```text
RPO points BACKWARD.

RTO points FORWARD.
```

Diagram:

```text
                Disaster
                   X
                   │
                   │
     <── RPO ──────┼────── RTO ──>
                   │
                   │
Last recovery      │          Service
point               │          restored
```

---

# 38. Business Example

Suppose ecommerce leadership defines:

```text
RPO = 15 minutes
RTO = 1 hour
```

Meaning:

```text
At most:

15 minutes of transactions
may be lost

AND

service must return
within 1 hour
```

Now architecture must be selected around those objectives.

AWS explicitly recommends deriving RPO and RTO from business impact rather than arbitrarily selecting the smallest possible numbers, because shorter objectives generally require more complex and costly recovery architectures. ([AWS Documentation][24])

---

# 39. Daily Snapshots Are Not Enough for Every DR Requirement

Suppose:

```text
Snapshot:
02:00

Disaster:
17:59
```

Potential recoverable state:

```text
02:00
```

Potential data loss:

```text
almost 16 hours
```

If RPO is:

```text
15 minutes
```

this design fails badly.

You may need something else:

```text
database-native replication
continuous replication
transaction-log backups
managed database HA/DR
AWS Elastic Disaster Recovery
or another service-specific mechanism
```

Snapshots are excellent, but **a snapshot is not synonymous with a complete disaster-recovery strategy**.

AWS's broader DR guidance distinguishes backup/restore from lower-RPO strategies such as pilot light, warm standby, active/active, and continuous replication approaches. ([AWS Documentation][25])

---

# 40. Backup ≠ High Availability

This distinction is huge.

## Backup

```text
Something failed
    ↓
recover data
    ↓
rebuild
    ↓
restore service
```

## High Availability

```text
Something failed
    ↓
another healthy component
continues serving
```

Example:

```text
EC2-A + EBS-A
      X

Snapshot available
```

That's great for recovery.

But users still wait while you:

```text
create EBS
launch EC2
attach
mount
configure
validate
route traffic
```

Snapshots provide recovery capability, not automatic instantaneous HA.

---

# 41. Snapshot DR vs Multi-AZ Architecture

Compare:

```text
SINGLE EC2
+
EBS
+
Snapshot
```

with:

```text
ALB
 │
 ├── EC2 AZ-a
 └── EC2 AZ-b
```

The second architecture handles certain infrastructure failures immediately through redundancy.

Snapshots solve a different problem:

```text
data recovery
historical restore points
corruption recovery
disaster recovery
```

You frequently need **both**.

---

# 42. The Corruption Problem

Suppose:

```text
Primary database
      │
      ▼
Replication
      │
      ▼
Replica
```

At 10:02:

```text
DROP TABLE customers;
```

Replication faithfully replicates:

```text
DROP TABLE customers;
```

Now:

```text
primary = damaged
replica = damaged
```

This is why replication alone is not backup.

AWS's DR guidance explicitly recommends point-in-time backups/versioning in addition to replication because corruption or destructive changes can propagate to replicas. ([AWS Documentation][26])

### Never forget

```text
Replication protects availability.

Backups protect recovery history.

You often need both.
```

---

# 43. Production Backup Layers

A strong design might look like:

```text
                    Production Data
                          │
          ┌───────────────┼────────────────┐
          │               │                │
          ▼               ▼                ▼
         HA          Replication        Backups
          │               │                │
       AZ failure     Region/host        historical
                                         recovery
                                            │
                              ┌─────────────┼────────────┐
                              ▼             ▼            ▼
                           Local        Cross-Region  Cross-Account
                          snapshot         copy          copy
```

Different mechanisms solve different failure modes.

---

# 44. Disaster-Recovery Lab

Now let's perform a simplified EBS recovery exercise.

Assume:

```text
Region = ap-south-1
AZ     = ap-south-1a
```

Create a small test volume:

```bash
VOLUME_ID=$(aws ec2 create-volume \
  --availability-zone ap-south-1a \
  --size 8 \
  --volume-type gp3 \
  --encrypted \
  --tag-specifications \
    'ResourceType=volume,Tags=[{Key=Name,Value=lesson25-dr-source}]' \
  --region ap-south-1 \
  --query 'VolumeId' \
  --output text)

echo "$VOLUME_ID"
```

Wait until available:

```bash
aws ec2 wait volume-available \
  --volume-ids "$VOLUME_ID" \
  --region ap-south-1
```

In a real lab, attach it to your test EC2, format it, mount it and create:

```text
/data/important.txt
```

with contents such as:

```text
Lesson 25 disaster recovery test
Version 1
```

---

# 45. Snapshot the Data

Create:

```bash
SNAPSHOT_ID=$(aws ec2 create-snapshot \
  --volume-id "$VOLUME_ID" \
  --description "Lesson25 DR recovery point" \
  --region ap-south-1 \
  --query 'SnapshotId' \
  --output text)

echo "$SNAPSHOT_ID"
```

Wait:

```bash
aws ec2 wait snapshot-completed \
  --snapshot-ids "$SNAPSHOT_ID" \
  --region ap-south-1
```

Validate:

```bash
aws ec2 describe-snapshots \
  --snapshot-ids "$SNAPSHOT_ID" \
  --region ap-south-1 \
  --query 'Snapshots[0].{
     Snapshot:SnapshotId,
     State:State,
     Size:VolumeSize,
     Encrypted:Encrypted
  }' \
  --output table
```

---

# 46. Simulate Data Loss

Pretend the original volume is unavailable.

Do **not** depend on:

```text
original EBS
```

We will recover only from:

```text
Snapshot
```

Create restored volume:

```bash
RESTORED_VOLUME=$(aws ec2 create-volume \
  --snapshot-id "$SNAPSHOT_ID" \
  --availability-zone ap-south-1a \
  --volume-type gp3 \
  --tag-specifications \
    'ResourceType=volume,Tags=[{Key=Name,Value=lesson25-restored}]' \
  --region ap-south-1 \
  --query 'VolumeId' \
  --output text)

echo "$RESTORED_VOLUME"
```

Wait:

```bash
aws ec2 wait volume-available \
  --volume-ids "$RESTORED_VOLUME" \
  --region ap-south-1
```

Then:

```text
attach to recovery EC2
       ↓
lsblk
       ↓
DO NOT mkfs
       ↓
mount existing filesystem
       ↓
verify /data/important.txt
```

### Very important

Do **not** run:

```bash
mkfs.xfs
```

against a restored filesystem.

That would overwrite the filesystem you're trying to recover.

---

# 47. Cross-AZ Recovery Test

Now restore into:

```text
ap-south-1b
```

instead:

```bash
AZ_B_VOLUME=$(aws ec2 create-volume \
  --snapshot-id "$SNAPSHOT_ID" \
  --availability-zone ap-south-1b \
  --volume-type gp3 \
  --region ap-south-1 \
  --query 'VolumeId' \
  --output text)
```

Now you have demonstrated:

```text
Original:
AZ-a

Snapshot:
regional recovery mechanism

Restored EBS:
AZ-b
```

This is a fundamental EBS DR pattern.

---

# 48. Cross-Region DR Exercise

Copy the snapshot:

```bash
DR_SNAPSHOT=$(aws ec2 copy-snapshot \
  --source-region ap-south-1 \
  --source-snapshot-id "$SNAPSHOT_ID" \
  --description "Lesson25 Mumbai to Singapore DR copy" \
  --region ap-southeast-1 \
  --query 'SnapshotId' \
  --output text)

echo "$DR_SNAPSHOT"
```

Then inspect in Singapore:

```bash
aws ec2 describe-snapshots \
  --snapshot-ids "$DR_SNAPSHOT" \
  --region ap-southeast-1 \
  --query 'Snapshots[0].{
      Snapshot:SnapshotId,
      State:State,
      Encrypted:Encrypted
  }' \
  --output table
```

Now your recovery architecture is:

```text
Mumbai
ap-south-1

EBS
 │
 ▼
Snapshot
 │
 │ Copy
 ▼
Singapore
ap-southeast-1

DR Snapshot
```

---

# 49. Test the Recovery, Not Just the Backup

This is a major production rule.

Bad:

```text
Snapshot status:
completed

Therefore:
"We have DR."
```

No.

A backup is useful only if you can restore from it.

Your test should validate:

```text
snapshot exists
       ↓
volume creation works
       ↓
volume attaches
       ↓
filesystem mounts
       ↓
data is readable
       ↓
application starts
       ↓
application validates data
       ↓
RTO measured
       ↓
RPO confirmed
```

AWS Well-Architected guidance explicitly recommends regularly testing disaster-recovery procedures to verify that RPO and RTO can actually be met. ([AWS Documentation][27])

---

# 50. A Production Runbook

When EBS-backed data is lost:

```text
ALERT
  │
  ▼
Identify failure scope
  │
  ├── EC2 only?
  ├── volume?
  ├── AZ?
  ├── Region?
  ├── account?
  └── corruption?
  │
  ▼
Select clean recovery point
  │
  ▼
Restore snapshot
  │
  ▼
Correct AZ / Region
  │
  ▼
Create EBS
  │
  ▼
Attach
  │
  ▼
Mount
  │
  ▼
Initialize if required
  │
  ▼
Validate filesystem
  │
  ▼
Validate application
  │
  ▼
Restore traffic
  │
  ▼
Measure actual RTO/RPO
```

This is how backups become **operational resilience**.

---

# 51. SAA-C03 / DOP-C02 Scenarios

### Scenario 1

A company needs:

```text
daily EBS backups
retain 30 days
automatically delete older snapshots
```

Think:

```text
Amazon Data Lifecycle Manager
```

or:

```text
AWS Backup
```

depending on whether the requirement is EBS-specific lifecycle automation or centralized enterprise backup management. ([AWS Documentation][16])

---

### Scenario 2

A workload has five EBS volumes and they must represent the same crash-consistent recovery point.

Think:

```text
Multi-volume snapshots
```

or coordinated AWS Backup of the EC2 workload. ([AWS Documentation][6])

---

### Scenario 3

A 5-TiB restored volume must deliver full provisioned performance immediately after creation.

Think:

```text
Fast Snapshot Restore
```

rather than waiting for first-access initialization. ([AWS Documentation][9])

---

### Scenario 4

Requirement:

```text
Region-level disaster recovery
```

Think:

```text
Cross-Region snapshot copy
```

as one part of the broader recovery architecture. ([AWS Documentation][10])

---

### Scenario 5

Requirement:

```text
Protection even if production AWS account is compromised
```

Think:

```text
Cross-account backups
+
dedicated backup account
+
Vault controls
```

and potentially immutable/air-gapped backup controls depending on business requirements. ([AWS Documentation][11])

---

### Scenario 6

Encrypted EBS snapshot must be shared with another account.

Think:

```text
Customer-managed KMS key
+
snapshot permissions
+
KMS key permissions
```

because snapshots encrypted with the default AWS-managed EBS key cannot be shared through the normal snapshot-sharing mechanism. ([AWS Documentation][13])

---

### Scenario 7

Administrator accidentally deletes a protected snapshot.

Think:

```text
Recycle Bin
```

provided an appropriate retention rule was configured before deletion. ([AWS Documentation][21])

---

### Scenario 8

Requirement:

```text
RPO = 15 minutes
```

but snapshots run once per day.

Answer:

```text
Architecture does NOT meet RPO.
```

A more frequent or continuous data-protection/replication strategy is required. ([AWS Documentation][23])

---

# 52. Interview Question

> **What's the difference between high availability, replication, snapshots and disaster recovery?**

A strong answer is:

> High availability keeps the workload serving during component failures by using redundant resources. Replication maintains another current copy of data for availability or recovery, but corruption can propagate to replicas. EBS snapshots provide historical point-in-time recovery points. Disaster recovery combines appropriate backups, replication, infrastructure, automation and tested runbooks to restore the entire workload according to business-defined RPO and RTO objectives. ([AWS Documentation][24])

---

# 53. Never-Forget Map

```text
                        EBS DATA
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
        AVAILABILITY                  RECOVERY
             │                           │
         Multi-AZ                     Snapshot
        application                      │
        architecture         ┌───────────┼───────────┐
                             │           │           │
                             ▼           ▼           ▼
                         Same Region Cross-Region Cross-Account
                             │           │           │
                             └───────────┼───────────┘
                                         ▼
                                  Backup Protection
                                         │
                                ┌────────┼────────┐
                                ▼        ▼        ▼
                               DLM   AWS Backup Recycle Bin
                                         │
                                         ▼
                                     Vault Lock
                                         │
                                         ▼
                                   DR Runbook/Test
                                         │
                              ┌──────────┴───────────┐
                              ▼                      ▼
                             RPO                    RTO
                              │                      │
                         Data loss              Downtime
```

---

# 54. Ten Things to Permanently Remember

```text
1. Snapshot = point-in-time EBS recovery point.

2. Standard EBS snapshots are incremental.

3. You can delete an old snapshot without automatically
   destroying later restore points.

4. Crash-consistent ≠ application-consistent.

5. Multi-volume snapshots coordinate volumes from one EC2.

6. Snapshot → create new EBS volume → attach → mount → recover.

7. Restored snapshot data can require initialization.

8. Fast Snapshot Restore removes first-access initialization delay.

9. Cross-Region + cross-account copies improve DR isolation.

10. RPO = acceptable data loss.
    RTO = acceptable downtime.
```

And the biggest rule:

```text
Backup exists
≠
Recovery works.
```

You only know recovery works after you have **restored and tested it**.

---

# Lesson 25 Progress

At this point you understand:

```text
EBS Fundamentals
        ↓
Volume Types
        ↓
IOPS / Throughput / Latency
        ↓
Performance Troubleshooting
        ↓
Elastic Resize
        ↓
Snapshots
        ↓
Crash Consistency
        ↓
Application Consistency
        ↓
Multi-Volume Backup
        ↓
Snapshot Restore
        ↓
Initialization / FSR
        ↓
Cross-AZ Recovery
        ↓
Cross-Region Recovery
        ↓
Cross-Account Protection
        ↓
KMS Encryption
        ↓
DLM
        ↓
AWS Backup
        ↓
Vault Protection
        ↓
Recycle Bin
        ↓
RPO / RTO
        ↓
Disaster Recovery
```

## Next — Lesson 25 Part 4

Next we'll go into the remaining **advanced production EBS operations and architecture**:

```text
EBS + EC2 PRODUCTION ENGINEERING

→ Root-volume rescue when EC2 won't boot
→ Detach → attach to rescue instance
→ Fix broken /etc/fstab
→ filesystem repair concepts
→ NVMe device-name mapping
→ UUID vs device-name mounting
→ EBS volume status checks
→ impaired-volume troubleshooting
→ EBS Multi-Attach in depth
→ NVMe reservations / fencing concepts
→ RAID 0 / RAID 1 across EBS
→ RAID performance vs durability
→ snapshot behavior with RAID sets
→ KMS failure troubleshooting
→ encrypted EBS with Auto Scaling
→ Launch Template encryption
→ EBS encryption by default
→ Terraform production module
→ CloudWatch alarms
→ final EBS failure-and-recovery lab
→ Lesson 25 final interview revision
```

That will finish EBS at the level where you can troubleshoot both **“the disk is slow”** and **“the server won't even boot anymore.”**

[1]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html?utm_source=chatgpt.com "Amazon EBS snapshots"
[2]: https://docs.aws.amazon.com/ebs/latest/userguide/snapshot-archive.html?utm_source=chatgpt.com "Archive Amazon EBS snapshots"
[3]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html?utm_source=chatgpt.com "Delete an Amazon EBS snapshot"
[4]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-creating-snapshot.html?utm_source=chatgpt.com "Create Amazon EBS snapshots"
[5]: https://docs.aws.amazon.com/ebs/latest/userguide/automate-app-consistent-backups.html?utm_source=chatgpt.com "Automate application-consistent snapshots with Data Lifecycle ..."
[6]: https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_CreateSnapshots.html?utm_source=chatgpt.com "CreateSnapshots - Amazon Elastic Compute Cloud"
[7]: https://docs.aws.amazon.com/aws-backup/latest/devguide/multi-volume-crash-consistent.html?utm_source=chatgpt.com "Amazon EBS and AWS Backup"
[8]: https://docs.aws.amazon.com/ebs/latest/userguide/initalize-volume.html?utm_source=chatgpt.com "Initialize Amazon EBS volumes"
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-fast-snapshot-restore.html?utm_source=chatgpt.com "Amazon EBS fast snapshot restore"
[10]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-copy-snapshot.html?utm_source=chatgpt.com "Copy an Amazon EBS snapshot"
[11]: https://docs.aws.amazon.com/aws-backup/latest/devguide/create-cross-account-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS accounts"
[12]: https://docs.aws.amazon.com/ebs/latest/userguide/share-kms-key.html?utm_source=chatgpt.com "Share the KMS key used to encrypt a shared Amazon EBS ..."
[13]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-modifying-snapshot-permissions.html?utm_source=chatgpt.com "Share an Amazon EBS snapshot with other AWS accounts"
[14]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html?utm_source=chatgpt.com "Amazon EBS encryption"
[15]: https://docs.aws.amazon.com/kms/latest/developerguide/services-ebs.html?utm_source=chatgpt.com "How Amazon Elastic Block Store (Amazon EBS) uses AWS ..."
[16]: https://docs.aws.amazon.com/ebs/latest/userguide/snapshot-lifecycle.html?utm_source=chatgpt.com "Automate backups with Amazon Data Lifecycle Manager"
[17]: https://docs.aws.amazon.com/aws-backup/latest/devguide/manage-cross-account.html?utm_source=chatgpt.com "Managing AWS Backup resources across multiple AWS ..."
[18]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vaults.html?utm_source=chatgpt.com "Backup vaults"
[19]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html?utm_source=chatgpt.com "AWS Backup Vault Lock - AWS Documentation"
[20]: https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html?utm_source=chatgpt.com "Logically air-gapped vault - AWS Backup"
[21]: https://docs.aws.amazon.com/ebs/latest/userguide/recycle-bin.html?utm_source=chatgpt.com "Recover deleted EBS volumes, EBS snapshots, and EBS- ..."
[22]: https://docs.aws.amazon.com/ebs/latest/userguide/recycle-bin-working-with-snaps.html?utm_source=chatgpt.com "Recover deleted snapshots from the Recycle Bin - Amazon EBS"
[23]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/disaster-recovery-dr-objectives.html?utm_source=chatgpt.com "Disaster Recovery (DR) objectives - Reliability Pillar"
[24]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/plan-for-disaster-recovery-dr.html?utm_source=chatgpt.com "Plan for Disaster Recovery (DR) - Reliability Pillar"
[25]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html?utm_source=chatgpt.com "Disaster recovery options in the cloud"
[26]: https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_disaster_recovery.html?utm_source=chatgpt.com "REL13-BP02 Use defined recovery strategies to meet the ..."
[27]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/testing-disaster-recovery.html?utm_source=chatgpt.com "Testing disaster recovery"
