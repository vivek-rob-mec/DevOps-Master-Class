# AWS Masterclass — Lesson 25 Part 4

# Advanced EBS Production Operations, Rescue & Failure Recovery

We have already learned:

```text
EBS fundamentals
      ↓
IOPS / throughput / latency
      ↓
gp3 / io2 / gp2
      ↓
CloudWatch troubleshooting
      ↓
Snapshots
      ↓
RPO / RTO / DR
```

Now we move into the incidents that happen at **2:00 AM in production**:

```text
EC2 will not boot
        │
        ├── /etc/fstab broken
        ├── filesystem corrupted
        ├── wrong EBS device
        ├── root disk damaged
        ├── EBS I/O impaired
        ├── KMS access denied
        └── Auto Scaling cannot launch encrypted instances
```

The goal of this lesson is that when someone says:

> **“The EC2 instance is dead and I can't even SSH into it.”**

you still know how to recover it.

---

# 1. First Principle: EC2 Failure Does Not Necessarily Mean Data Loss

Consider:

```text
              EC2
               X
               │
          Root EBS
               │
               ▼
             DATA
```

If the problem is:

```text
OS misconfiguration
bad fstab
bad SSH configuration
wrong permissions
broken boot configuration
application issue
```

the EBS volume may still be perfectly recoverable.

Because EBS is separate block storage, a common recovery pattern is:

```text
Broken EC2
    │
    ▼
Stop instance
    │
    ▼
Detach root EBS
    │
    ▼
Attach to healthy EC2
    │
    ▼
Mount as DATA disk
    │
    ▼
Repair
    │
    ▼
Detach
    │
    ▼
Reattach as root
    │
    ▼
Start original EC2
```

AWS documents this detach → helper instance → repair → reattach pattern for EBS-backed Linux instances. ([AWS Documentation][1])

---

# 2. Classic Incident: `/etc/fstab` Breaks Boot

Remember `/etc/fstab`?

It controls persistent filesystem mounts.

Example:

```text
UUID=abc123  /data  xfs  defaults  0  2
```

Imagine an administrator enters the wrong UUID:

```text
UUID=THIS-DOES-NOT-EXIST  /data  xfs  defaults  0  2
```

Then reboots.

Result:

```text
Boot
 ↓
Linux reads /etc/fstab
 ↓
tries mounting disk
 ↓
disk not found
 ↓
boot may stall/fail
 ↓
SSH unavailable
```

AWS specifically warns that errors in `/etc/fstab` can make a Linux instance unbootable and recommends validating entries with `mount -a` before rebooting. ([AWS Documentation][2])

### Never forget

Before rebooting after changing `fstab`:

```bash
sudo mount -a
```

If that produces errors:

```text
DO NOT REBOOT YET.
```

Fix them first.

---

# 3. Better `/etc/fstab` for Optional Data Disks

For an optional data volume:

```text
UUID=abc123 /data xfs defaults,nofail 0 2
```

The key option:

```text
nofail
```

means the machine can continue booting even if that noncritical filesystem isn't available.

AWS recommends `nofail` for volumes that might not always be attached. ([AWS Documentation][2])

Think:

```text
Root disk missing
=
serious boot problem


Optional /data disk missing
+
nofail
=
server can still boot
```

Do not blindly use this to hide storage failures for data that is actually mandatory for the application.

---

# 4. Manual Root-Volume Rescue Lab

Use a **test EC2 only** for this exercise.

Assume:

```bash
export AWS_REGION="ap-south-1"
export BROKEN_INSTANCE="i-0123456789abcdef0"
export HELPER_INSTANCE="i-0abcdef1234567890"
```

The helper instance must be in the **same Availability Zone** as the volume because EBS attachment is AZ-scoped. ([AWS Documentation][3])

---

# 5. Find the Root Device

```bash
ROOT_DEVICE=$(aws ec2 describe-instances \
  --instance-ids "$BROKEN_INSTANCE" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].RootDeviceName' \
  --output text)

echo "$ROOT_DEVICE"
```

Example:

```text
/dev/xvda
```

Now find the EBS volume:

```bash
ROOT_VOLUME=$(aws ec2 describe-instances \
  --instance-ids "$BROKEN_INSTANCE" \
  --region "$AWS_REGION" \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='$ROOT_DEVICE'].Ebs.VolumeId | [0]" \
  --output text)

echo "$ROOT_VOLUME"
```

Example:

```text
vol-0123456789abcdef0
```

---

# 6. Snapshot Before Repair

Before modifying a damaged system:

```text
CURRENT BROKEN STATE
       │
       ▼
take snapshot
       │
       ▼
attempt repair
```

Why snapshot something that's already broken?

Because:

```text
broken-but-recoverable
```

can become:

```text
broken-and-now-more-damaged
```

after an incorrect repair.

Create:

```bash
RECOVERY_SNAPSHOT=$(aws ec2 create-snapshot \
  --volume-id "$ROOT_VOLUME" \
  --description "Pre-repair root volume snapshot" \
  --region "$AWS_REGION" \
  --query 'SnapshotId' \
  --output text)

echo "$RECOVERY_SNAPSHOT"
```

This gives you a rollback point.

---

# 7. Stop the Broken Instance

```bash
aws ec2 stop-instances \
  --instance-ids "$BROKEN_INSTANCE" \
  --region "$AWS_REGION"
```

Wait:

```bash
aws ec2 wait instance-stopped \
  --instance-ids "$BROKEN_INSTANCE" \
  --region "$AWS_REGION"
```

For root-volume repair, AWS's standard manual recovery workflow stops the failed EBS-backed instance before detaching its root volume. ([AWS Documentation][1])

---

# 8. Detach Root EBS

```bash
aws ec2 detach-volume \
  --volume-id "$ROOT_VOLUME" \
  --instance-id "$BROKEN_INSTANCE" \
  --region "$AWS_REGION"
```

Wait:

```bash
aws ec2 wait volume-available \
  --volume-ids "$ROOT_VOLUME" \
  --region "$AWS_REGION"
```

---

# 9. Attach to the Rescue EC2

```bash
aws ec2 attach-volume \
  --volume-id "$ROOT_VOLUME" \
  --instance-id "$HELPER_INSTANCE" \
  --device /dev/sdf \
  --region "$AWS_REGION"
```

Important:

```text
AWS API device name:
/dev/sdf

Linux may show:
something completely different
```

especially on Nitro-based instances.

---

# 10. Nitro Device-Name Surprise

On modern Nitro EC2 instances, EBS volumes are exposed to Linux as NVMe devices such as:

```text
/dev/nvme0n1
/dev/nvme1n1
/dev/nvme2n1
```

even though you attached them through EC2 as names such as `/dev/sdf`. AWS explicitly notes that the EC2 attachment name and the operating-system-visible device name can differ, and Nitro exposes EBS through NVMe. ([AWS Documentation][4])

So:

```text
AWS says:
/dev/sdf

Linux says:
/dev/nvme1n1
```

That is normal.

---

# 11. Never Guess Which NVMe Disk Is Which

Run:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS
```

Example:

```text
NAME         SIZE FSTYPE UUID            MOUNTPOINTS
nvme0n1       30G
└─nvme0n1p1   30G xfs    helper-uuid    /

nvme1n1       30G
└─nvme1n1p1   30G xfs    broken-uuid
```

Here:

```text
nvme0n1
=
helper EC2 root

nvme1n1
=
broken EC2 root
```

But don't decide from the number alone.

Verify with:

```bash
sudo blkid
```

and AWS metadata/device information.

### Never run

```bash
mkfs.xfs /dev/nvme1n1
```

on a recovery volume.

That would create a new filesystem over the filesystem you're trying to rescue.

---

# 12. Mount the Broken Root Filesystem

Create a recovery mount:

```bash
sudo mkdir -p /mnt/recovery
```

Suppose the root filesystem is:

```text
/dev/nvme1n1p1
```

Mount:

```bash
sudo mount /dev/nvme1n1p1 /mnt/recovery
```

Then:

```bash
ls /mnt/recovery
```

Expected:

```text
bin
boot
etc
home
opt
root
usr
var
...
```

You are now looking at the broken machine's filesystem while running from a healthy machine.

That's the key rescue concept.

---

# 13. Fix `/etc/fstab`

Broken machine:

```bash
sudo nano /mnt/recovery/etc/fstab
```

Perhaps you find:

```text
UUID=wrong-id /data xfs defaults 0 2
```

Correct the UUID or temporarily comment the invalid line:

```text
# UUID=wrong-id /data xfs defaults 0 2
```

For a genuinely optional data volume, consider:

```text
UUID=correct-id /data xfs defaults,nofail 0 2
```

Validate the underlying UUIDs using:

```bash
sudo blkid
```

Using stable filesystem identifiers such as UUIDs is generally preferable to depending on NVMe enumeration order, which is not something you should treat as permanent. AWS's own boot troubleshooting guidance discusses using filesystem UUIDs for consistent identification. ([AWS Documentation][5])

---

# 14. What Else Can You Repair This Way?

The helper-instance technique can repair much more than `fstab`.

For example:

```text
/etc/ssh/sshd_config
/etc/sudoers
/home/user/.ssh/authorized_keys
/etc/sysconfig/*
/etc/default/*
boot configuration
SELinux configuration
bad startup scripts
broken package configuration
```

AWS even documents restoring access after a lost EC2 SSH key by attaching the root volume to another instance and modifying `authorized_keys`. ([AWS Documentation][6])

Mental model:

```text
Cannot access OS?

Don't require the OS to repair itself.

Mount its disk
from another OS.
```

---

# 15. Filesystem Consistency Repair

Suppose the problem isn't configuration.

Instead:

```text
mount: Structure needs cleaning
```

or:

```text
Input/output error
```

Now we may have a filesystem problem.

The workflow should be conservative:

```text
Snapshot first
      ↓
Unmount filesystem
      ↓
Identify filesystem type
      ↓
Use filesystem-specific checker
      ↓
Repair
      ↓
Mount
      ↓
Validate data
```

AWS recommends isolating an impaired EBS volume on another instance and performing an operating-system consistency check before returning it to service. ([AWS Documentation][7])

---

# 16. ext4 Repair

For ext4, the underlying repair utility is:

```text
e2fsck
```

For example, while the filesystem is **unmounted**:

```bash
sudo e2fsck -f /dev/nvme1n1p1
```

A safer first inspection can use:

```bash
sudo e2fsck -n /dev/nvme1n1p1
```

where:

```text
-n
=
check without modifying
```

Red Hat documents `e2fsck` as the checker/repair tool for ext2/ext3/ext4 filesystems. ([Red Hat Documentation][8])

Do not perform filesystem repair casually against a mounted production filesystem.

---

# 17. XFS Repair

XFS is different.

Use:

```bash
sudo xfs_repair -n /dev/nvme1n1p1
```

for a no-modification check.

If actual repair is required:

```bash
sudo xfs_repair /dev/nvme1n1p1
```

on the unmounted filesystem.

Red Hat documents `xfs_repair` as the repair utility for XFS; unlike ext filesystems, `fsck.xfs` itself doesn't perform the normal XFS repair operation. ([Red Hat Documentation][9])

There is also:

```text
xfs_repair -L
```

but treat it as a **last-resort operation** because it zeroes the log and can discard pending metadata updates. Do not reach for `-L` as your first command. ([Red Hat Documentation][10])

---

# 18. Reattach the Root Volume

After repairs:

```bash
sudo umount /mnt/recovery
```

Detach from helper:

```bash
aws ec2 detach-volume \
  --volume-id "$ROOT_VOLUME" \
  --instance-id "$HELPER_INSTANCE" \
  --region "$AWS_REGION"
```

Wait:

```bash
aws ec2 wait volume-available \
  --volume-ids "$ROOT_VOLUME" \
  --region "$AWS_REGION"
```

Now reattach using the original EC2 root device name:

```bash
aws ec2 attach-volume \
  --volume-id "$ROOT_VOLUME" \
  --instance-id "$BROKEN_INSTANCE" \
  --device "$ROOT_DEVICE" \
  --region "$AWS_REGION"
```

Then:

```bash
aws ec2 start-instances \
  --instance-ids "$BROKEN_INSTANCE" \
  --region "$AWS_REGION"
```

---

# 19. Modern Alternative — EC2Rescue

You don't always have to perform every rescue step manually.

AWS Systems Manager provides EC2Rescue automation workflows that can:

```text
stop original EC2
      ↓
create backup
      ↓
attach root volume to helper instance
      ↓
run EC2Rescue
      ↓
attempt remediation
      ↓
reattach root volume
```

AWS documents this automation specifically for unreachable EC2 instances. ([AWS Documentation][11])

So think:

```text
Manual rescue
=
excellent skill to understand


EC2Rescue automation
=
excellent operational tool
```

You should know both.

---

# 20. Root Volume Replacement

EC2 also supports **root-volume replacement**.

Conceptually:

```text
Current instance
      │
      ├── bad root volume
      │
      ▼
Replace root volume task
      │
      ▼
replacement volume
```

The replacement source can come from supported sources such as a snapshot, while preserving the EC2 instance identity rather than building an entirely separate instance. AWS manages detaching the old root and attaching the replacement through the replacement task. ([AWS Documentation][12])

This can be useful for:

```text
rolling back bad OS changes
restoring a root disk from snapshot
recovering from damaged root state
```

---

# 21. EBS Volume Status Checks

EC2 has status checks.

EBS has status checks too.

AWS EBS volume status checks automatically test volumes every five minutes and can return states including:

```text
ok
warning
impaired
insufficient-data
```

with additional I/O performance status information for supported SSD types. ([AWS Documentation][13])

Check:

```bash
aws ec2 describe-volume-status \
  --volume-ids "$ROOT_VOLUME" \
  --region "$AWS_REGION"
```

Find impaired volumes:

```bash
aws ec2 describe-volume-status \
  --filters Name=volume-status.status,Values=impaired \
  --region "$AWS_REGION"
```

---

# 22. Why Would EBS Disable I/O?

AWS may determine:

```text
data may be inconsistent
```

Rather than continuing to blindly accept I/O and potentially worsen corruption, EBS can disable I/O.

Then:

```text
Volume
   │
   ▼
I/O disabled
   │
   ▼
status check fails
   │
   ▼
impaired
```

AWS deliberately does this to give you the opportunity to evaluate consistency before continuing writes. ([AWS Documentation][13])

This is an important distinction:

```text
Storage stopped responding
```

does not automatically mean:

```text
EBS service is completely dead.
```

It may be a protective consistency action.

---

# 23. Re-Enable EBS I/O

After deciding how to handle the consistency risk:

```bash
aws ec2 enable-volume-io \
  --volume-id "$ROOT_VOLUME" \
  --region "$AWS_REGION"
```

AWS recommends considering an isolated consistency check—such as `fsck` for Linux—before returning an impaired volume to production. ([AWS Documentation][7])

Do not interpret:

```text
enable-volume-io
```

as:

```text
repair my filesystem
```

It only resumes EBS I/O.

Application/filesystem consistency remains your responsibility.

---

# 24. Volume State vs Volume Status

Another subtle distinction.

## State

Examples:

```text
creating
available
in-use
deleting
deleted
error
```

## Status

Examples:

```text
ok
warning
impaired
insufficient-data
```

These answer different questions.

```text
STATE
=
lifecycle state


STATUS
=
operational health
```

AWS specifically notes that EBS volume status checks and the volume's resource state are separate concepts. ([AWS Documentation][13])

---

# 25. CloudWatch Stalled-I/O Detection

A useful modern EBS signal is:

```text
VolumeStalledIOCheck
```

Conceptually:

```text
0
=
volume completing I/O


1
=
volume unable to complete I/O
```

AWS documents this metric for detecting impaired/stalled I/O conditions. ([AWS Documentation][14])

Production alarm concept:

```text
VolumeStalledIOCheck >= 1
          │
          ▼
         ALERT
          │
          ▼
Inspect volume status/events
          │
          ▼
protect workload
          │
          ▼
repair / replace / recover
```

---

# 26. Multi-Attach — Deep Dive

Normally:

```text
EBS
 │
 ▼
EC2
```

Multi-Attach allows eligible Provisioned IOPS volumes:

```text
                 io1 / io2 EBS
                 /    |    \
                /     |     \
             EC2-A  EC2-B  EC2-C
```

within the **same Availability Zone**.

AWS currently allows Multi-Attach-enabled EBS volumes to be attached to multiple Nitro-based EC2 instances, with up to 16 instance attachments supported for a volume. ([AWS Documentation][15])

But Multi-Attach is **not a normal shared filesystem service**.

---

# 27. Why Normal ext4/XFS + Multi-Attach Is Dangerous

Imagine:

```text
EC2-A
  │
  ├── filesystem metadata cached
  │
  ▼
 shared EBS
  ▲
  │
  ├── different filesystem metadata cached
  │
EC2-B
```

Both machines independently think:

```text
"I own this filesystem."
```

Now both write.

Result can be:

```text
filesystem corruption
data corruption
split brain
```

Multi-Attach gives multiple machines block access; your **cluster-aware filesystem/application must coordinate concurrent writes**. AWS specifically says the applications using Multi-Attach must manage concurrent write operations. ([AWS Documentation][15])

So:

```text
Multi-Attach
≠
EFS
```

---

# 28. Storage Fencing

What happens if two cluster nodes both believe they are the active database server?

```text
Node A
"I am primary."

Node B
"I am primary."
```

Both write:

```text
        shared disk
        ▲        ▲
        │        │
      Node A   Node B
```

Disaster.

We need a concept called:

# Fencing

Fencing says:

```text
Only the authorized node
may perform specific storage operations.
```

Think of a physical key to a safe.

Only the node holding the correct reservation can access/write according to the configured policy.

---

# 29. NVMe Reservations

Multi-Attach-enabled `io2` volumes support **NVMe reservations**—industry-standard storage fencing mechanisms used to coordinate access to shared storage. AWS supports operations for registering, acquiring, releasing and managing reservation ownership. ([AWS Documentation][16])

Architecture:

```text
              io2 Multi-Attach
                     │
              NVMe Reservation
                     │
          ┌──────────┴──────────┐
          │                     │
       Node A                Node B
       owns key              standby
          │
       writes
```

Failure:

```text
Node A dies
      │
      ▼
cluster determines failure
      │
      ▼
Node B acquires reservation
      │
      ▼
Node B becomes writer
```

That's a much safer shared-block design than:

```text
mount same ext4 everywhere
and hope.
```

---

# 30. When Multi-Attach Makes Sense

Possible specialized use cases:

```text
clustered applications
cluster-aware filesystems
high-availability database software
applications implementing storage fencing
```

But for:

> “I need web servers to share uploaded files.”

your instinct should usually be:

```text
EFS
S3
shared-file/object architecture
```

not Multi-Attach.

We will cover that next.

---

# 31. RAID on EBS

You can combine several EBS volumes using software RAID.

For example:

```text
EBS A ─┐
       ├── RAID 0 ── filesystem
EBS B ─┘
```

AWS supports OS-level software RAID with EBS. ([AWS Documentation][2])

The most relevant AWS use case is often:

# RAID 0

for performance aggregation.

---

# 32. RAID 0

Suppose:

```text
Volume A:
4,000 IOPS

Volume B:
4,000 IOPS
```

RAID 0 stripes I/O:

```text
              Application
                   │
                   ▼
                RAID 0
               /      \
              ▼        ▼
           EBS-A      EBS-B
```

Potential aggregate capacity:

```text
IOPS:
4,000 + 4,000
≈ 8,000
```

subject to instance EBS bandwidth and workload behavior.

AWS specifically recommends RAID 0 when you need performance beyond what one volume can provide; throughput/IOPS can aggregate across the stripe. ([AWS Documentation][2])

---

# 33. RAID 0 Failure Characteristic

RAID 0 gives:

```text
performance
```

not redundancy.

If:

```text
EBS-A dies
```

then:

```text
entire RAID filesystem
can become unusable
```

because parts of the data were striped across both disks.

AWS explicitly warns that loss of one RAID 0 member results in loss of the array's data. ([AWS Documentation][2])

Therefore:

```text
RAID 0
=
performance architecture

NOT
=
backup architecture
```

---

# 34. Creating RAID 0

Example after attaching two empty test volumes:

```bash
lsblk
```

Suppose:

```text
/dev/nvme1n1
/dev/nvme2n1
```

Install:

```bash
sudo dnf install -y mdadm
```

Create:

```bash
sudo mdadm \
  --create \
  --verbose \
  /dev/md0 \
  --level=0 \
  --raid-devices=2 \
  /dev/nvme1n1 \
  /dev/nvme2n1
```

Check:

```bash
cat /proc/mdstat
```

and:

```bash
sudo mdadm --detail /dev/md0
```

AWS documents this same software-RAID pattern using `mdadm`. ([AWS Documentation][2])

Then:

```bash
sudo mkfs.xfs /dev/md0
```

Mount:

```bash
sudo mkdir -p /data
sudo mount /dev/md0 /data
```

Only run `mkfs` on **new empty lab volumes**.

---

# 35. Why AWS Doesn't Recommend RAID 1 for Normal EBS Redundancy

You might think:

```text
RAID 1
=
two disks
=
safer
```

But EBS itself already replicates a volume within its AZ for protection from single underlying component failures. RAID 1 additionally causes each write to be sent to multiple EBS volumes, consuming extra EC2-to-EBS bandwidth without improving write performance; AWS therefore does not generally recommend RAID 1 as the normal EBS design. ([AWS Documentation][2])

Think:

```text
Need more EBS performance?
→ RAID 0 may be useful.

Need backups?
→ snapshots / AWS Backup.

Need AZ resilience?
→ application/data architecture.

Need shared storage?
→ EFS / specialized cluster storage.
```

Don't use RAID to solve every problem.

---

# 36. RAID 5 / RAID 6

AWS also does not generally recommend RAID 5/6 over EBS because parity operations consume IOPS and create cost/performance overhead. ([AWS Documentation][2])

This is another example of:

```text
Traditional datacenter best practice
≠
automatically AWS best practice
```

Cloud storage already provides capabilities beneath your virtual disk.

Architecture must consider them.

---

# 37. Snapshotting RAID

Suppose:

```text
RAID 0
 │
 ├── EBS-A
 └── EBS-B
```

Do this:

```text
snapshot A
wait 30 seconds
snapshot B
```

and the application is writing continuously.

You can get:

```text
A at time T1
B at time T2
```

which may produce an inconsistent RAID restore.

AWS recommends **multi-volume snapshots** for coordinated, crash-consistent snapshots across the EBS members of a RAID set. ([AWS Documentation][2])

Mental model:

```text
RAID volumes

 A   B   C
 │   │   │
 └───┼───┘
     │
     ▼
Multi-volume snapshot
     │
     ▼
same recovery point
```

---

# 38. EBS Encryption by Default

Production accounts should have an explicit encryption strategy.

AWS supports **EBS encryption by default** at the Region/account level.

Once enabled for a Region:

```text
new EBS volumes
+
snapshot copies
```

are encrypted by default according to that Region's configured EBS encryption settings. Existing volumes are not retroactively encrypted. ([AWS Documentation][17])

AWS CLI:

```bash
aws ec2 enable-ebs-encryption-by-default \
  --region ap-south-1
```

Check:

```bash
aws ec2 get-ebs-encryption-by-default \
  --region ap-south-1
```

Remember:

```text
EBS encryption by default
=
REGION-SPECIFIC setting
```

not one universal switch for every Region.

---

# 39. Terraform Encryption by Default

Terraform provides:

```hcl
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}
```

which manages the account's default EBS encryption setting for the provider Region. ([Terraform Registry][18])

That's a good infrastructure-governance pattern:

```text
Security requirement
        ↓
Terraform
        ↓
encryption default
        ↓
less reliance on engineers
remembering a checkbox
```

---

# 40. Launch Template Encryption

Our Auto Scaling fleet should explicitly define its storage.

Conceptually:

```hcl
resource "aws_launch_template" "app" {

  # ...

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = 30

      iops                   = 3000
      throughput             = 125

      encrypted              = true
      kms_key_id             = aws_kms_key.ebs.arn

      delete_on_termination  = true
    }
  }
}
```

That gives every ASG instance a consistent encrypted root-storage definition.

EC2 Auto Scaling supports encrypted EBS volumes using AWS managed or customer-managed KMS keys; specifying a customer-managed key is done through a launch template rather than the older launch-configuration mechanism. ([AWS Documentation][19])

---

# 41. The Famous ASG + KMS Failure

This one matters a lot.

You configure:

```text
Launch Template
      │
      ▼
Encrypted EBS
      │
      ▼
Customer-managed KMS key
```

Then:

```text
ASG Desired = 4
Current = 2

Scale out required
```

But new instances keep failing.

Scaling activity:

```text
Client.InternalError
```

The EC2 user who created the configuration has KMS permission, so you think:

> “KMS cannot be the problem.”

It still can be.

---

# 42. Why?

Auto Scaling launches instances using its **service-linked role**.

Conceptually:

```text
You
 │
 │ configure ASG
 ▼
Auto Scaling
 │
 │ service-linked role
 ▼
EC2
 │
 ▼
KMS encrypted EBS
```

The relevant Auto Scaling service-linked role must be able to use the customer-managed key.

AWS explicitly documents `Client.InternalError` during encrypted ASG launches when the service-linked role lacks KMS access. ([AWS Documentation][20])

---

# 43. KMS Permissions Needed by Auto Scaling

For a customer-managed EBS key, AWS documents a KMS key policy that permits the Auto Scaling service-linked role operations including:

```text
kms:Encrypt
kms:Decrypt
kms:ReEncrypt*
kms:GenerateDataKey*
kms:DescribeKey
```

and the ability to:

```text
kms:CreateGrant
```

under the appropriate AWS-resource condition. ([AWS Documentation][21])

The architecture is:

```text
Customer-managed KMS key
           │
           ▼
      Key Policy
           │
           ▼
AWSServiceRoleForAutoScaling
           │
           ▼
       launch EC2
           │
           ▼
    encrypted EBS
```

---

# 44. KMS Troubleshooting Chain

When an encrypted ASG refuses to launch:

```text
ASG launch failed
       │
       ▼
describe-scaling-activities
       │
       ▼
Client.InternalError?
       │
       ▼
Launch Template uses encrypted EBS?
       │
       ▼
Which KMS key?
       │
       ▼
AWS managed key?
       │
       └── usually no special CMK authorization needed
       │
Customer-managed key?
       │
       ▼
Auto Scaling service-linked role allowed?
       │
       ▼
CreateGrant permitted?
       │
       ▼
Key enabled?
       │
       ▼
Correct Region/account?
```

AWS notes that the default AWS-managed EBS key doesn't require the additional customer-managed-key authorization that a CMK does. ([AWS Documentation][21])

---

# 45. Your First ASG Troubleshooting Command Again

Remember from Lesson 24:

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name prod-app-asg \
  --region ap-south-1 \
  --max-items 20
```

Notice how topics connect.

Lesson 24 taught:

```text
Auto Scaling troubleshooting
```

Lesson 25 explains one of the reasons it can fail:

```text
EBS encryption / KMS
```

That is exactly why we are learning AWS as a connected system.

---

# 46. Production EBS Terraform Pattern

A standalone data volume might look like:

```hcl
resource "aws_kms_key" "ebs" {
  description         = "Production EBS encryption"
  enable_key_rotation = true
}

resource "aws_ebs_volume" "data" {
  availability_zone = "ap-south-1a"

  type       = "gp3"
  size       = 200
  iops       = 6000
  throughput = 250

  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn

  tags = {
    Name        = "prod-app-data"
    Environment = "production"
    Backup      = "Daily"
  }
}
```

For specialized shared-block workloads, Terraform's EBS-volume resource also exposes Multi-Attach configuration for supported `io1`/`io2` volumes. ([Terraform Registry][22])

---

# 47. Monitoring Every Production EBS Volume

At minimum, think in four categories:

```text
             EBS Monitoring

   ┌────────────┼────────────┐
   │            │            │
Performance   Health       Capacity
   │            │            │
   ▼            ▼            ▼
IOPS         Status       filesystem %
Throughput   Stalled IO   inode usage
Latency      Events
Queue
```

CloudWatch provides volume-level latency, throughput, IOPS and health-related metrics for supported EBS configurations, but filesystem fullness itself usually needs OS-level monitoring because EBS does not know what your ext4/XFS filesystem considers “used.” ([AWS Documentation][23])

---

# 48. Useful Alarm Set

For a serious storage workload, consider alerts around:

```text
VolumeIOPSExceededCheck

VolumeThroughputExceededCheck

VolumeStalledIOCheck

VolumeQueueLength

VolumeAvgReadLatency

VolumeAvgWriteLatency
```

plus OS-level:

```text
filesystem utilization
inode utilization
filesystem read-only state
application disk latency
```

Alarm thresholds must follow workload baselines rather than one universal number.

For example:

```text
QueueLength = 10
```

could be concerning for one volume but completely expected for another.

---

# 49. Final Failure-and-Recovery Lab

Use a disposable EC2.

Architecture:

```text
                 Test EC2
                    │
              Root gp3 EBS
                    │
                    ▼
               /etc/fstab
```

We'll intentionally create a boot problem and recover it.

## Step 1 — Create safety snapshot

```bash
aws ec2 create-snapshot \
  --volume-id "$ROOT_VOLUME" \
  --description "Before EBS rescue lab" \
  --region ap-south-1
```

---

# 50. Simulate a Bad Optional Mount

Create a deliberately invalid test entry:

```text
UUID=00000000-0000-0000-0000-000000000000 /broken xfs defaults 0 2
```

Before rebooting:

```bash
sudo mkdir -p /broken

sudo mount -a
```

You should see an error.

**In production, that is where you stop and fix it.**

For the lab only, the purpose is to understand why an invalid mandatory mount can interfere with boot.

The lesson:

```text
mount -a
before reboot
```

is more valuable than deliberately breaking servers.

AWS explicitly warns not to shut down/reboot systems with unresolved `fstab` errors. ([AWS Documentation][2])

---

# 51. Recovery Drill

Your recovery runbook is:

```text
1. Identify instance.

2. Identify root volume.

3. Snapshot it.

4. Stop instance.

5. Detach root EBS.

6. Attach root EBS to helper EC2.

7. lsblk / blkid.

8. Mount filesystem.

9. Repair /etc/fstab.

10. Unmount.

11. Detach from helper.

12. Reattach to original EC2.

13. Start.

14. Verify EC2 status checks.

15. Verify application.

16. Verify storage.

17. Record incident root cause.
```

If you can execute that without panic, you understand EBS operationally rather than just academically.

---

# 52. Incident Scenario — `df` Shows 100%

Application:

```text
500 errors
```

Linux:

```bash
df -h
```

shows:

```text
/dev/nvme1n1p1  200G  200G  0G  100% /data
```

Troubleshooting:

```text
Disk full
  │
  ├── What is consuming space?
  │
  ▼
du / application logs / DB
  │
  ├── clean unnecessary data?
  │
  ├── retention failure?
  │
  ├── runaway logs?
  │
  └── genuine growth?
           │
           ▼
      increase EBS size
           │
           ▼
      grow partition
           │
           ▼
      grow filesystem
```

Do not merely enlarge storage every month without finding why it fills.

---

# 53. Incident Scenario — Volume `impaired`

You see:

```text
EBS status = impaired
```

Production thought process:

```text
1. Check volume event.

2. Determine whether I/O is disabled.

3. Protect application consistency.

4. Snapshot/recovery decision.

5. Stop workload writes.

6. Isolate volume if needed.

7. Enable I/O deliberately.

8. Filesystem consistency check.

9. Validate data.

10. Return to service or replace volume.
```

AWS's impaired-volume procedure recommends isolating the volume on another EC2 instance for consistency checks when appropriate. ([AWS Documentation][7])

---

# 54. Incident Scenario — ASG Desired 10, Current 0

Launch configuration:

```text
Encrypted EBS
Customer-managed KMS key
```

Scaling activities:

```text
Client.InternalError
```

Your first hypothesis:

```text
Auto Scaling service-linked role
cannot use KMS key
```

Check:

```text
Launch Template
      ↓
KMS Key ARN
      ↓
KMS key enabled?
      ↓
same Region?
      ↓
key policy?
      ↓
service-linked role?
      ↓
CreateGrant?
```

This exact encrypted-volume failure mode is documented by AWS Auto Scaling. ([AWS Documentation][20])

---

# 55. Incident Scenario — RAID Is Slow Despite More Disks

You created:

```text
4 × high-performance EBS
       ↓
RAID 0
```

Expected:

```text
huge throughput
```

But actual result barely improved.

Think:

```text
EBS A ─┐
EBS B ─┤
EBS C ─┤── RAID 0
EBS D ─┘
        │
        ▼
       EC2
        │
        X
 instance EBS bandwidth ceiling
```

RAID can't magically exceed the EC2 instance's EBS interface capability.

AWS specifically recommends ensuring a RAID array doesn't exceed the EBS bandwidth available to the EC2 instance. ([AWS Documentation][2])

---

# 56. SAA-C03 / DOP-C02 Scenarios

### Scenario 1

EC2 cannot boot because `/etc/fstab` is incorrect.

Think:

```text
stop
→ detach root EBS
→ attach to rescue instance
→ repair
→ reattach
→ start
```

---

### Scenario 2

Need multiple EC2 instances to share files using ordinary Linux semantics.

Think first:

```text
EFS
```

not:

```text
Multi-Attach + ext4
```

---

### Scenario 3

A specialist cluster requires multiple nodes accessing the same block device.

Think:

```text
io2 Multi-Attach
+
cluster-aware software
+
NVMe reservations/fencing
```

([AWS Documentation][16])

---

### Scenario 4

Need more IOPS/throughput than one EBS volume can provide.

Think:

```text
multiple identical volumes
+
RAID 0
+
EC2 with sufficient EBS bandwidth
```

([AWS Documentation][2])

---

### Scenario 5

Need EBS redundancy.

Don't automatically answer:

```text
RAID 1
```

EBS already provides internal AZ-level redundancy; application-level HA, snapshots and DR are separate layers. AWS does not generally recommend RAID 1 for EBS because of its extra bandwidth consumption and lack of write-performance gain. ([AWS Documentation][2])

---

### Scenario 6

All new volumes must be encrypted automatically.

Think:

```text
EBS encryption by default
```

([AWS Documentation][17])

---

### Scenario 7

ASG cannot launch instances with a customer-managed KMS key.

Think:

```text
Auto Scaling service-linked role
+
KMS key policy
+
kms:CreateGrant
```

([AWS Documentation][21])

---

# 57. Interview Question

> An EC2 instance is unreachable after someone modified `/etc/fstab`. How would you recover it?

Strong answer:

> First I'd inspect console/status information to confirm it's a boot-level issue. For an EBS-backed instance I'd take a safety snapshot, stop the instance, detach its root EBS volume, attach that volume to a healthy helper EC2 in the same Availability Zone, identify and mount the correct filesystem without formatting it, repair `/etc/fstab`, validate the filesystem/configuration, unmount it, detach it from the helper, reattach it using the original root block-device mapping, and start the original instance. I'd then validate EC2 status checks, application health, and document the root cause. AWS Systems Manager EC2Rescue is also an option for automating parts of this recovery workflow. ([AWS Documentation][1])

That's a genuine operations answer.

---

# 58. EBS Never-Forget Architecture

```text
                         EBS
                          │
       ┌──────────────────┼──────────────────┐
       │                  │                  │
       ▼                  ▼                  ▼
  Performance           Recovery          Security
       │                  │                  │
       ├─ IOPS             ├─ Snapshot        ├─ Encryption
       ├─ Throughput       ├─ Cross-AZ        ├─ KMS
       ├─ Latency          ├─ Cross-Region    └─ Key policy
       ├─ Queue            └─ Rescue
       │
       ▼
  Advanced Storage
       │
       ├─ RAID 0
       ├─ Multi-Attach
       └─ NVMe reservations

                   OPERATIONS
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
         Status     CloudWatch   Linux
         checks      alarms      tools
```

---

# 59. The 15 EBS Rules to Permanently Remember

```text
1. EC2 is compute; EBS is block storage.

2. EBS is Availability-Zone scoped.

3. Stop/start normally preserves EBS.

4. Termination behavior depends on DeleteOnTermination.

5. gp3 is the general-purpose SSD starting point.

6. IOPS ≠ throughput ≠ latency.

7. EC2 EBS bandwidth can bottleneck a fast volume.

8. Snapshots are incremental recovery points.

9. Backup ≠ High Availability.

10. RPO = acceptable data loss.
    RTO = acceptable downtime.

11. Never format a recovery volume.

12. Bad fstab can make Linux unbootable.

13. A broken EC2 can often be repaired by mounting its
    EBS root volume from another instance.

14. Multi-Attach requires cluster-aware coordination.

15. Customer-managed KMS keys require the relevant AWS
    service roles to have access.
```

And add this:

```text
Before destructive repair:

SNAPSHOT FIRST.
```

---

# ✅ Lesson 25 — Amazon EBS Complete

We have now covered EBS from beginner through production troubleshooting:

```text
✓ Block storage mental model
✓ EBS vs S3
✓ EBS vs Instance Store
✓ Root and data volumes
✓ DeleteOnTermination
✓ AZ scope
✓ gp2 / gp3 / io2 / st1 / sc1
✓ IOPS
✓ throughput
✓ latency
✓ queue depth
✓ EBS-optimized EC2
✓ EC2 EBS bandwidth
✓ CloudWatch metrics
✓ fio / iostat troubleshooting
✓ Elastic Volumes
✓ online resizing
✓ growpart
✓ XFS / ext4 expansion
✓ snapshots
✓ incremental backups
✓ crash consistency
✓ application consistency
✓ multi-volume snapshots
✓ cross-AZ restore
✓ cross-Region copy
✓ cross-account protection
✓ encryption / KMS
✓ DLM
✓ AWS Backup
✓ Vault Lock concepts
✓ Recycle Bin
✓ RPO / RTO
✓ root-volume rescue
✓ broken fstab recovery
✓ filesystem consistency checks
✓ NVMe mapping
✓ EBS status checks
✓ impaired-volume recovery
✓ Multi-Attach
✓ NVMe reservations
✓ RAID 0
✓ RAID snapshot consistency
✓ encryption by default
✓ encrypted Auto Scaling fleets
✓ ASG + KMS troubleshooting
✓ production incident workflows
```

We can now distinguish the major EC2 storage problem:

```text
"One server needs its own disk"
                │
                ▼
               EBS
```

from the problem we study **next**:

```text
"20, 100 or 1,000 Linux servers
need access to the SAME filesystem."
                │
                ▼
               ???
```

# Next — Lesson 26: Amazon EFS & Shared File Storage

We will move into:

```text
Amazon EFS
   │
   ├── File storage vs block storage
   ├── NFS fundamentals
   ├── shared filesystem architecture
   ├── EFS mount targets
   ├── Multi-AZ behavior
   ├── Security Groups
   ├── POSIX permissions
   ├── IAM authorization
   ├── EFS Access Points
   ├── encryption
   ├── performance modes
   ├── throughput modes
   ├── bursting
   ├── Elastic Throughput
   ├── storage classes
   ├── lifecycle management
   ├── EC2 + Auto Scaling + EFS
   ├── ECS / EKS shared storage
   ├── WordPress architecture
   ├── EFS vs EBS vs S3
   ├── EFS vs FSx
   ├── Terraform
   ├── mount troubleshooting
   ├── NFS/network-layer debugging
   └── production shared-storage lab
```

That lesson will finally answer one of the most common AWS architecture questions:

> **“If my Auto Scaling instances are disposable, where do I keep files that every instance needs to share?”**

[1]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstances.html "Troubleshoot Amazon EC2 Linux instances with failed status checks - Amazon Elastic Compute Cloud"
[2]: https://docs.aws.amazon.com/ebs/latest/userguide/raid-config.html "Amazon EBS and RAID configuration - Amazon EBS"
[3]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-attaching-volume.html?utm_source=chatgpt.com "Attach an Amazon EBS volume to an Amazon EC2 instance"
[4]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/device_naming.html?utm_source=chatgpt.com "Device names for volumes on Amazon EC2 instances"
[5]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-booting-from-wrong-volume.html?utm_source=chatgpt.com "Troubleshoot an Amazon EC2 Linux instance booting from ..."
[6]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/TroubleshootingInstancesConnecting.html?utm_source=chatgpt.com "Troubleshoot issues connecting to your Amazon EC2 Linux ..."
[7]: https://docs.aws.amazon.com/ebs/latest/userguide/work_volumes_impaired.html?utm_source=chatgpt.com "Work with an impaired Amazon EBS volume"
[8]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/fsck-fs-specific?utm_source=chatgpt.com "12.2. File System-Specific Information for fsck"
[9]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_file_systems/checking-and-repairing-a-file-system__managing-file-systems?utm_source=chatgpt.com "Chapter 15. Checking and repairing a file system"
[10]: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/managing_file_systems/checking-and-repairing-a-file-system_?utm_source=chatgpt.com "Chapter 16. Checking and repairing a file system"
[11]: https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-ec2rescue.html?utm_source=chatgpt.com "Run the EC2Rescue tool on unreachable instances"
[12]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/replace-root.html?utm_source=chatgpt.com "Replace the root volume for an Amazon EC2 instance without ..."
[13]: https://docs.aws.amazon.com/ebs/latest/userguide/monitoring-volume-checks.html "Amazon EBS volume status checks - Amazon EBS"
[14]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-io-characteristics.html?utm_source=chatgpt.com "Amazon EBS I/O characteristics and monitoring"
[15]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes-multi.html?utm_source=chatgpt.com "Attach an EBS volume to multiple EC2 instances using ..."
[16]: https://docs.aws.amazon.com/ebs/latest/userguide/nvme-reservations.html "Use NVMe reservations with Multi-Attach enabled Amazon EBS volumes - Amazon EBS"
[17]: https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html?utm_source=chatgpt.com "Enable Amazon EBS encryption by default"
[18]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default?utm_source=chatgpt.com "aws_ebs_encryption_by_default | Resources | hashicorp/aws"
[19]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-data-protection.html?utm_source=chatgpt.com "Data protection in Amazon EC2 Auto Scaling"
[20]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ts-as-instancelaunchfailure.html "Troubleshoot Amazon EC2 Auto Scaling: EC2 instance launch failures - Amazon EC2 Auto Scaling"
[21]: https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html "Required AWS KMS key policy for use with encrypted volumes - Amazon EC2 Auto Scaling"
[22]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume?utm_source=chatgpt.com "aws_ebs_volume | Resources | hashicorp/aws | Terraform"
[23]: https://docs.aws.amazon.com/ebs/latest/userguide/using_cloudwatch_ebs.html?utm_source=chatgpt.com "Amazon CloudWatch metrics for Amazon EBS"
