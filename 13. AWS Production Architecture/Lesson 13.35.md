# AWS Masterclass — Phase 3

# Lesson 34: Amazon EBS, EFS and FSx Production Storage

## 1. Lesson objectives

In this lesson, you will learn how to:

* Choose between block, file and object storage.
* Understand Amazon EBS architecture and performance.
* Select `gp3`, `io2`, `st1` or `sc1` correctly.
* Calculate IOPS, throughput and latency requirements.
* Resize EBS volumes without rebuilding an instance.
* Create, copy, archive and restore EBS snapshots.
* Use Fast Snapshot Restore and Recycle Bin.
* Understand EBS Multi-Attach and its risks.
* Build shared Linux storage using Amazon EFS.
* Select EFS Regional or One Zone storage.
* Configure EFS mount targets, access points and IAM authorization.
* Choose EFS throughput and storage-class settings.
* Understand the Amazon FSx product family.
* Choose FSx for Windows, Lustre, ONTAP or OpenZFS.
* Automate storage with Terraform.
* Monitor and troubleshoot storage failures.
* Design production backup and disaster-recovery strategies.

---

# 2. The most important storage decision

AWS provides several storage models:

```text
Amazon EBS:
Block storage

Amazon EFS:
Managed Linux NFS file storage

Amazon FSx:
Managed specialised file systems

Amazon S3:
Object storage

EC2 instance store:
Temporary local block storage
```

## Selection mental model

```text
Does the application need a disk attached to one server?
    → EBS

Do several Linux servers need one shared filesystem?
    → EFS

Does the workload require SMB, Windows integration,
Lustre, NetApp ONTAP or OpenZFS?
    → FSx

Does the workload store independent files through an API?
    → S3

Does the workload need extremely fast temporary local disks?
    → EC2 instance store
```

---

# 3. High-level comparison

| Requirement                   | EBS                              | EFS                  | FSx                               | S3                          |
| ----------------------------- | -------------------------------- | -------------------- | --------------------------------- | --------------------------- |
| Storage model                 | Block                            | File                 | File/block depending on FSx type  | Object                      |
| Common protocol               | Filesystem created by OS         | NFS                  | SMB, NFS, Lustre, iSCSI, NVMe     | HTTPS API                   |
| Typical attachment            | One EC2 instance                 | Many clients         | Many clients                      | Unlimited API clients       |
| Availability scope            | One AZ                           | Regional or One Zone | Single-AZ or Multi-AZ options     | Regional                    |
| Boot volume                   | Yes                              | No                   | No                                | No                          |
| Shared filesystem             | Limited special cases            | Yes                  | Yes                               | No                          |
| Automatically scales capacity | No                               | Yes                  | Depends on FSx type/configuration | Yes                         |
| Best use                      | OS, databases, application disks | Linux shared storage | Enterprise/HPC filesystems        | Assets, backups, data lakes |

---

# 4. Amazon EBS mental model

Amazon Elastic Block Store provides block devices for EC2.

```text
EC2 instance
     |
     | Attached block device
     v
EBS volume
     |
     v
Filesystem such as ext4, XFS or NTFS
```

An EBS volume behaves like a virtual hard disk.

You can:

* Partition it.
* Format it.
* Mount it.
* Store database files.
* Use it as an operating-system disk.
* Snapshot it.
* Resize it.
* Encrypt it.

EBS volumes and the EC2 instances to which they are attached must normally be in the same Availability Zone. ([AWS Documentation][1])

---

# 5. EBS is Availability Zone–scoped

Suppose an EC2 instance is in:

```text
ap-south-1a
```

The attached EBS volume must also be in:

```text
ap-south-1a
```

You cannot directly attach a volume in:

```text
ap-south-1b
```

to that instance.

## Moving an EBS volume to another AZ

```text
1. Create a snapshot.
2. Create a new volume from the snapshot in the destination AZ.
3. Attach the new volume to an instance in that AZ.
4. Mount and validate the filesystem.
```

## Never-forget rule

```text
EBS volume:
AZ resource

EBS snapshot:
Regional backup resource
```

---

# 6. EBS versus instance store

## EBS

```text
Instance stops:
Volume normally persists

Instance terminates:
Persistence depends on DeleteOnTermination

Hardware failure:
EBS is independent of the individual instance host
```

## Instance store

```text
Physical local storage attached to EC2 host

Instance stops, terminates or host fails:
Data can be lost
```

Use instance store for:

* Temporary caches.
* Scratch space.
* Replicated databases that tolerate node loss.
* Temporary processing data.
* High-performance ephemeral workloads.

Do not use it as the only copy of irreplaceable information.

---

# 7. EBS volume types

Current primary EBS volume families include:

```text
SSD:
gp3
gp2
io2
io1

HDD:
st1
sc1
```

AWS also retains a previous-generation magnetic `standard` type, but new workloads should generally use a modern type. ([AWS Documentation][2])

## Current performance overview

| Type                | Primary purpose            |      Maximum IOPS* | Maximum throughput* |
| ------------------- | -------------------------- | -----------------: | ------------------: |
| `gp3`               | General production SSD     |             80,000 |         2,000 MiB/s |
| `gp2`               | Older general-purpose SSD  |             16,000 |           250 MiB/s |
| `io2` Block Express | Critical high-IOPS storage |            256,000 |         4,000 MiB/s |
| `io1`               | Older provisioned IOPS SSD |             64,000 |         1,000 MiB/s |
| `st1`               | Frequent sequential HDD    | Throughput-focused |           500 MiB/s |
| `sc1`               | Cold sequential HDD        | Throughput-focused |           250 MiB/s |

*Maximums depend on supported volume size, EC2 instance, Region and configuration. `gp3` supports up to 80,000 IOPS and 2,000 MiB/s, while `io2` Block Express supports up to 256,000 IOPS and 4,000 MiB/s on supported configurations. ([AWS Documentation][2])

---

# 8. IOPS, throughput and latency

These three metrics are related but different.

## IOPS

```text
Input/output operations per second
```

Example:

```text
20,000 random database reads per second
```

IOPS matters for:

* Databases.
* Small random file access.
* Transaction systems.
* Metadata-heavy workloads.

## Throughput

```text
Amount of data transferred per second
```

Example:

```text
1,000 MiB/s sequential transfer
```

Throughput matters for:

* Log processing.
* Data warehouses.
* Large media files.
* ETL.
* Backups.
* Sequential scans.

## Latency

```text
Time required to complete one I/O operation
```

Latency matters for:

* Transaction response time.
* Database commit duration.
* Interactive systems.
* Synchronous writes.

---

# 9. IOPS and throughput relationship

The approximate relationship is:

```text
Throughput =
IOPS × I/O size
```

Example:

```text
10,000 IOPS × 16 KiB
≈ 156 MiB/s
```

Another:

```text
2,000 IOPS × 1 MiB
≈ 2,000 MiB/s
```

But the real result is capped by:

* Volume maximum throughput.
* Volume maximum IOPS.
* EC2 EBS bandwidth.
* Filesystem.
* Application queue depth.
* Operating-system limits.

---

# 10. EC2 can limit EBS performance

Provisioning:

```text
gp3:
40,000 IOPS
1,000 MiB/s
```

does not guarantee that an instance can consume it.

The instance may support only:

```text
20,000 IOPS
500 MiB/s
```

The effective performance is approximately:

```text
Minimum of:
- Volume capability
- Instance EBS capability
- Workload demand
- Filesystem capability
```

EBS-optimised instances provide dedicated EBS bandwidth, but each instance type still has documented IOPS and throughput limits. ([AWS Documentation][3])

---

# 11. General Purpose SSD: `gp3`

`gp3` should normally be the starting choice for general-purpose workloads.

Suitable for:

* EC2 boot volumes.
* Web applications.
* Application servers.
* Development databases.
* Container hosts.
* Jenkins servers.
* General filesystem storage.

## Key benefit

`gp3` separates:

```text
Volume size
IOPS
Throughput
```

You can increase performance without increasing storage capacity.

Example:

```text
Size:
100 GiB

IOPS:
6,000

Throughput:
250 MiB/s
```

---

# 12. `gp3` baseline

A `gp3` volume includes baseline performance independent of its size:

```text
3,000 IOPS
125 MiB/s throughput
```

You can provision more IOPS and throughput when required.

This is fundamentally different from `gp2`, where performance is tied more closely to capacity.

---

# 13. `gp2` versus `gp3`

## `gp2`

Performance scales with volume size.

```text
Small volume:
Lower baseline IOPS

Large volume:
Higher baseline IOPS
```

It uses burst credits for smaller volumes.

## `gp3`

```text
Size, IOPS and throughput:
Configured separately
```

This makes performance more predictable and often avoids overprovisioning storage merely to obtain more IOPS.

## Migration pattern

```text
Existing gp2 volume
        ↓
Modify volume
        ↓
Change to gp3
        ↓
Keep equivalent or better performance
        ↓
Monitor application
```

---

# 14. Provisioned IOPS SSD: `io2`

Use `io2` for workloads requiring:

* Sustained high IOPS.
* High durability requirements.
* Consistent sub-millisecond latency.
* Large critical databases.
* SAP HANA.
* Oracle.
* SQL Server.
* High-throughput transactional systems.

`io2` Block Express supports substantially higher IOPS and throughput than general-purpose volumes on supported Nitro instances. ([AWS Documentation][2])

## Design principle

Do not select `io2` only because the application is called “production.”

Select it when measurements show that:

```text
gp3 performance is insufficient
or
the workload requires io2-specific characteristics.
```

---

# 15. HDD EBS types

## `st1`: Throughput Optimized HDD

Use for large, frequently accessed sequential workloads:

* Log processing.
* Big-data workloads.
* ETL.
* Data warehouses.
* Streaming datasets.

`st1` is throughput-oriented and is not supported as a boot volume. ([AWS Documentation][4])

## `sc1`: Cold HDD

Use for:

* Infrequently accessed large files.
* Cold data.
* Low-cost sequential workloads.
* Data that remains online but is rarely read.

## Do not use HDD volumes for

* Boot disks.
* Small random database I/O.
* Transaction-heavy workloads.
* Frequently random metadata access.

SSD-backed volumes handle random and sequential I/O consistently, while `st1` and `sc1` perform best with large sequential I/O. ([AWS Documentation][5])

---

# 16. Root-volume selection

Recommended default:

```text
EC2 root volume:
gp3
```

Examples:

```text
Development server:
20–30 GiB gp3

Jenkins server:
50–100 GiB gp3

Container host:
50–200 GiB gp3 depending on image and log usage

Database:
Separate dedicated data volume
```

Keep operating-system and important application data separated where it improves:

* Backup.
* Rebuild.
* Monitoring.
* Resize operations.
* Performance isolation.

---

# 17. Create and attach an EBS volume

Create:

```bash
aws ec2 create-volume \
  --availability-zone ap-south-1a \
  --volume-type gp3 \
  --size 100 \
  --iops 6000 \
  --throughput 250 \
  --encrypted \
  --tag-specifications \
    'ResourceType=volume,Tags=[
      {Key=Name,Value=production-app-data},
      {Key=Environment,Value=production}
    ]' \
  --region ap-south-1
```

Attach:

```bash
aws ec2 attach-volume \
  --volume-id vol-0123456789abcdef0 \
  --instance-id i-0123456789abcdef0 \
  --device /dev/sdf \
  --region ap-south-1
```

---

# 18. Detect the device

On Nitro-based instances, the actual Linux device may appear as NVMe:

```bash
lsblk
```

Example:

```text
NAME        SIZE TYPE MOUNTPOINT
nvme0n1      30G disk
└─nvme0n1p1  30G part /
nvme1n1     100G disk
```

Do not assume `/dev/sdf` remains the operating-system device name.

Use:

```bash
sudo nvme list
```

or:

```bash
ls -l /dev/disk/by-id/
```

to identify devices safely.

---

# 19. Format and mount a new volume

Check whether it already has a filesystem:

```bash
sudo file -s /dev/nvme1n1
```

Format with XFS:

```bash
sudo mkfs.xfs /dev/nvme1n1
```

Create mount point:

```bash
sudo mkdir -p /data
```

Mount:

```bash
sudo mount /dev/nvme1n1 /data
```

Validate:

```bash
df -hT /data
```

## Warning

Never run `mkfs` on a volume containing required data.

Formatting destroys the existing filesystem structure.

---

# 20. Persistent mounting with UUID

Get UUID:

```bash
sudo blkid /dev/nvme1n1
```

Example:

```text
UUID="abcd-1234" TYPE="xfs"
```

Add to `/etc/fstab`:

```text
UUID=abcd-1234 /data xfs defaults,nofail 0 2
```

Test before rebooting:

```bash
sudo umount /data
sudo mount -a
df -hT /data
```

A malformed `/etc/fstab` entry can delay or prevent normal startup, so always test `mount -a`.

---

# 21. Elastic Volumes

Elastic Volumes lets you modify an existing EBS volume’s:

* Type.
* Size.
* IOPS.
* Throughput.

without detaching it in many normal scenarios.

Example:

```bash
aws ec2 modify-volume \
  --volume-id vol-0123456789abcdef0 \
  --volume-type gp3 \
  --size 200 \
  --iops 10000 \
  --throughput 500 \
  --region ap-south-1
```

EBS supports online modifications for modern volume types, subject to modification rules and instance support. ([AWS Documentation][6])

---

# 22. Increasing the EBS volume is only step one

After increasing EBS storage:

```text
EBS block device:
200 GiB

Filesystem:
Still 100 GiB
```

You must also extend:

```text
Partition, when present
Filesystem
```

## XFS example

```bash
sudo growpart /dev/nvme1n1 1
sudo xfs_growfs /data
```

## ext4 example

```bash
sudo growpart /dev/nvme1n1 1
sudo resize2fs /dev/nvme1n1p1
```

The exact device depends on whether the filesystem is directly on the disk, a partition, LVM or RAID.

---

# 23. EBS Multi-Attach

EBS Multi-Attach allows an `io1` or `io2` volume to be attached to multiple Nitro-based instances in the same Availability Zone.

A Multi-Attach volume can currently be attached to as many as 16 instances. ([AWS Documentation][7])

Architecture:

```text
EC2 instance A ─┐
EC2 instance B ─┼──> Shared io2 volume
EC2 instance C ─┘
```

## Critical warning

Multi-Attach is not the same as EFS.

Every attached instance can issue reads and writes.

Your software must coordinate:

* Concurrent writes.
* Distributed locking.
* Cache consistency.
* Failure fencing.
* Filesystem metadata.

---

# 24. Do not mount an ordinary filesystem from multiple writers

Bad design:

```text
Instance A ─┐
            ├── ext4 filesystem on one Multi-Attach volume
Instance B ─┘
```

Ordinary filesystems such as ext4 and standard XFS are not designed for simultaneous independent mounting by multiple writable hosts.

This can cause:

* Filesystem corruption.
* Lost writes.
* Metadata conflicts.
* Irrecoverable data loss.

Use:

* A cluster-aware filesystem.
* An application explicitly designed for shared block storage.
* NVMe reservations and proper fencing.
* EFS or FSx when shared file semantics are required.

`io2` Multi-Attach supports NVMe reservations for coordinating and fencing shared access. ([AWS Documentation][8])

---

# 25. RAID with EBS

You can combine volumes using software RAID.

## RAID 0

```text
Volume A ─┐
          ├── Striping → higher aggregate performance
Volume B ─┘
```

Advantages:

* Increased throughput.
* Increased aggregate IOPS.

Disadvantage:

```text
One volume fails:
Entire RAID 0 filesystem fails.
```

## RAID 1

```text
Data mirrored to two volumes
```

This adds redundancy at the host level but often provides less benefit because EBS itself is already designed with internal redundancy.

Do not use RAID as a replacement for backups.

---

# 26. EBS snapshots

An EBS snapshot is a point-in-time, incremental backup of a volume.

```text
Initial snapshot:
Copies all used blocks

Later snapshot:
Copies blocks changed since prior snapshots
```

Although snapshots are incremental internally, each snapshot can be used as an independent restore point. ([AWS Documentation][9])

Create:

```bash
aws ec2 create-snapshot \
  --volume-id vol-0123456789abcdef0 \
  --description "Production application backup" \
  --tag-specifications \
    'ResourceType=snapshot,Tags=[
      {Key=Name,Value=production-app-data},
      {Key=Environment,Value=production}
    ]' \
  --region ap-south-1
```

---

# 27. Crash-consistent versus application-consistent backup

## Crash-consistent

Comparable to storage immediately after an unexpected machine shutdown.

Filesystems may recover through their journals, but application buffers may not have been flushed cleanly.

## Application-consistent

The application is coordinated before the snapshot:

```text
Pause writes
Flush buffers
Database checkpoint
Filesystem freeze
Create snapshot
Resume writes
```

For critical databases, use:

* Database-native backups.
* Quiescing scripts.
* AWS Backup application-aware workflows where supported.
* Replication.
* Tested recovery procedures.

AWS Backup can create multi-volume crash-consistent EBS backups for volumes attached to one EC2 instance at the same logical time. ([AWS Documentation][10])

---

# 28. Snapshots and encryption

Snapshots inherit encryption from encrypted volumes.

You can:

* Copy a snapshot.
* Encrypt an unencrypted snapshot during copying.
* Re-encrypt a snapshot with another KMS key.
* Copy it to another Region.
* Share eligible snapshots across accounts.

Copying to another Region or changing its KMS key creates a complete, non-incremental copy at the destination. ([AWS Documentation][11])

---

# 29. Cross-Region snapshot recovery

Architecture:

```text
EBS volume
ap-south-1
     |
     | Snapshot
     v
Regional snapshot
ap-south-1
     |
     | Cross-Region copy
     v
Snapshot
ap-southeast-1
```

Use for:

* Regional disaster recovery.
* Account isolation.
* Compliance.
* Golden AMI distribution.

Amazon Data Lifecycle Manager can automate snapshot creation, retention and cross-Region copy workflows. ([AWS Documentation][12])

---

# 30. Lazy loading after snapshot restore

When creating a volume from a standard snapshot, the volume becomes available before every block has been fetched into the volume.

The first read of an untouched block can therefore have higher latency.

This is called:

```text
Lazy loading
or
First-touch penalty
```

Options:

* Pre-warm by reading every block.
* Use Fast Snapshot Restore.
* Accept temporary reduced performance for noncritical restores.

---

# 31. Fast Snapshot Restore

Fast Snapshot Restore, or FSR, enables volumes created from a selected snapshot in a selected AZ to be fully initialised and deliver provisioned performance immediately. ([AWS Documentation][13])

Use FSR for:

* Critical database recovery.
* Rapid fleet restoration.
* Large-scale launch events.
* Low-RTO systems.

## Important

FSR must be explicitly enabled for each:

```text
Snapshot
+
Availability Zone
```

It is not inherited automatically by copied or newly created snapshots.

---

# 32. EBS Snapshot Archive

EBS Snapshot Archive provides a lower-cost tier for rarely accessed snapshots.

Use for:

* Long-term compliance snapshots.
* Historical backups.
* Old snapshots with low restoration probability.

Archived snapshots:

* Have a 90-day minimum archive period.
* Are stored as full snapshots in the archive tier.
* Must be restored to the standard snapshot tier before normal use.
* Can require up to 72 hours to restore, depending on size. ([AWS Documentation][14])

Do not archive snapshots required for rapid recovery.

---

# 33. EBS Recycle Bin

Recycle Bin can retain deleted:

* EBS volumes.
* EBS snapshots.
* EBS-backed AMIs.

for a defined period before permanent deletion. ([AWS Documentation][15])

Architecture:

```text
Delete protected snapshot
        ↓
Recycle Bin
        ↓
Retention period
        ├── Restore
        └── Permanent deletion after expiry
```

Use retention rules for:

* Production snapshots.
* Golden AMIs.
* Critical data volumes.
* Ransomware and accidental-deletion protection.

---

# 34. Amazon Data Lifecycle Manager versus AWS Backup

## Data Lifecycle Manager

Best suited for:

* EBS snapshots.
* EBS-backed AMIs.
* Tag-based schedules.
* Retention.
* Cross-Region and cross-account snapshot workflows.

## AWS Backup

Best suited for:

* Centralised multi-service backups.
* Multi-account governance.
* Backup vaults.
* Vault Lock.
* Cross-account copies.
* EBS, EFS, FSx, RDS and other supported services.
* Central compliance reporting.

Both can automate EBS snapshot creation and retention. AWS Backup provides a central data-protection service across multiple AWS resources, while Data Lifecycle Manager is EBS/AMI-focused. ([AWS Documentation][16])

---

# 35. Monitor EBS

Important CloudWatch metrics include:

```text
VolumeReadOps
VolumeWriteOps
VolumeReadBytes
VolumeWriteBytes
VolumeTotalReadTime
VolumeTotalWriteTime
VolumeQueueLength
VolumeIdleTime
VolumeThroughputPercentage
BurstBalance
```

Ask:

```text
Is the workload IOPS-bound?
Throughput-bound?
Latency-bound?
Instance-bandwidth-bound?
Burst-credit-bound?
```

Nitro-based instances also expose high-resolution NVMe EBS performance statistics including operation counts, bytes and I/O time. ([AWS Documentation][17])

---

# 36. EBS troubleshooting: high latency

Possible causes:

* Volume IOPS limit reached.
* Volume throughput limit reached.
* EC2 EBS limit reached.
* High queue depth.
* Small `gp2` volume exhausted burst credits.
* Lazy-loaded snapshot blocks.
* Filesystem fragmentation.
* Database checkpoint or backup.
* Application issuing synchronous writes.
* Instance CPU or memory pressure.
* RAID imbalance.

Troubleshooting workflow:

```text
1. Check application latency.
2. Check filesystem and OS latency.
3. Check EBS CloudWatch metrics.
4. Check instance EBS limits.
5. Check I/O size and queue depth.
6. Compare provisioned versus consumed IOPS.
7. Review snapshot-restored volume initialization.
```

---

# 37. EBS troubleshooting: volume is full

Check:

```bash
df -h
```

Check inode exhaustion:

```bash
df -i
```

Check directories:

```bash
sudo du -xhd1 /data | sort -h
```

Possible causes:

* Application logs.
* Docker images and layers.
* Database growth.
* Old releases.
* Temporary files.
* Deleted but still-open files.

Find deleted open files:

```bash
sudo lsof +L1
```

A file can be deleted from the directory while a running process still holds it open, so disk space is not released until the process closes it.

---

# 38. Amazon EFS mental model

Amazon Elastic File System provides scalable shared file storage through NFS.

```text
EC2 A ─┐
EC2 B ─┼──> EFS shared filesystem
ECS   ─┤
EKS   ─┤
Lambda─┘
```

Suitable for:

* Shared web content.
* WordPress uploads.
* Home directories.
* Container-shared storage.
* Build workspaces.
* Machine-learning files.
* Shared application configuration.
* Linux lift-and-shift applications.

EFS is a managed file service whose storage capacity grows and shrinks automatically as files are added and removed. ([AWS Documentation][18])

---

# 39. EFS uses NFS

EFS is primarily accessed by Linux-compatible clients using NFS.

Default port:

```text
TCP 2049
```

Networking:

```text
Client security group:
Outbound TCP 2049

EFS mount-target security group:
Inbound TCP 2049 from client security group
```

EFS mount targets receive security groups, and clients must be allowed to connect to them on NFS port 2049. ([AWS Documentation][19])

---

# 40. EFS Regional architecture

```text
VPC
├── AZ A
│   ├── EC2 application
│   └── EFS mount target
│
├── AZ B
│   ├── EC2 application
│   └── EFS mount target
│
└── AZ C
    ├── EC2 application
    └── EFS mount target
             |
             v
      Regional EFS filesystem
```

For a Regional EFS filesystem, create a mount target in each AZ from which clients need access.

AWS recommends that a client connect through a mount target in its own AZ for performance and network-cost reasons. ([AWS Documentation][20])

---

# 41. EFS Regional versus One Zone

## Regional

```text
Data stored across multiple AZs
```

Use for:

* Production shared applications.
* High availability.
* Workloads that must survive an AZ disruption.

## One Zone

```text
Data stored within one AZ
One mount target
```

Use for:

* Development.
* Reproducible data.
* Secondary copies.
* Lower-cost workloads that tolerate AZ loss.

EFS One Zone storage classes are designed for high durability within one AZ, but data can be lost if the entire AZ is destroyed. ([AWS Documentation][21])

---

# 42. Mount EFS

Install the mount helper:

```bash
sudo apt update
sudo apt install -y amazon-efs-utils
```

Create directory:

```bash
sudo mkdir -p /mnt/shared
```

Mount with TLS:

```bash
sudo mount -t efs \
  -o tls \
  fs-0123456789abcdef0:/ \
  /mnt/shared
```

Validate:

```bash
df -hT /mnt/shared
```

The EFS mount helper establishes encrypted in-transit connectivity using TLS. ([AWS Documentation][22])

---

# 43. Persistent EFS mount

Example `/etc/fstab`:

```text
fs-0123456789abcdef0:/ /mnt/shared efs _netdev,tls 0 0
```

The `_netdev` option indicates that the mount depends on network availability.

Test:

```bash
sudo umount /mnt/shared
sudo mount -a
```

---

# 44. EFS access points

An EFS access point provides an application-specific entry point into a filesystem.

It can enforce:

* Root directory.
* POSIX user ID.
* POSIX group ID.
* Directory ownership.
* Directory permissions.

Architecture:

```text
Shared EFS filesystem
├── Access point: application-A → /apps/a
├── Access point: application-B → /apps/b
└── Access point: uploads       → /uploads
```

Mount targets provide network connectivity, while access points provide logical application entry points and identity enforcement. ([AWS Documentation][23])

---

# 45. Mount through an access point

```bash
sudo mount -t efs \
  -o tls,accesspoint=fsap-0123456789abcdef0 \
  fs-0123456789abcdef0:/ \
  /mnt/application
```

Access-point mounts require the EFS mount helper and configured mount targets. ([AWS Documentation][24])

Use access points for:

* ECS tasks.
* EKS workloads.
* Lambda functions.
* Multi-application shared filesystems.
* Preventing applications from seeing unrelated directories.

---

# 46. EFS IAM authorization

EFS has two access-control layers:

```text
Network and client authorisation:
Security groups, file-system policy and IAM

Filesystem permissions:
POSIX user, group and mode bits
```

Mount with IAM authorization:

```bash
sudo mount -t efs \
  -o tls,iam \
  fs-0123456789abcdef0:/ \
  /mnt/shared
```

IAM authorization requires the EFS mount helper. ([AWS Documentation][25])

## Important

An IAM Allow does not override POSIX filesystem permissions automatically.

Both levels must permit the operation.

---

# 47. EFS performance modes

EFS performance modes include:

```text
General Purpose
Max I/O
```

## General Purpose

Recommended for most workloads:

* Web serving.
* Content management.
* Home directories.
* General file sharing.
* Latency-sensitive applications.

## Max I/O

Designed for workloads that value highly parallel aggregate performance over the lowest per-operation latency.

For modern high-throughput workloads, AWS recommends Regional EFS using General Purpose performance mode with Elastic throughput. ([AWS Documentation][26])

Performance mode cannot be changed after filesystem creation without replacing the filesystem. ([AWS Documentation][27])

---

# 48. EFS throughput modes

EFS currently supports:

```text
Elastic
Provisioned
Bursting
```

([AWS Documentation][28])

## Elastic throughput

Automatically scales throughput according to workload demand.

Good default for:

* Unpredictable activity.
* Spiky applications.
* General shared storage.

## Provisioned throughput

You explicitly provision throughput independent of stored-data size.

Use when:

* Throughput demand is known.
* Workload needs sustained throughput.
* Dataset is small but activity is high.

## Bursting throughput

Throughput scales with stored data and uses burst credits.

Use for:

* Workloads naturally proportional to filesystem size.
* Lower, less unpredictable activity.

---

# 49. EFS storage classes

EFS supports storage classes for frequently and infrequently accessed files, including:

```text
Regional Standard
Regional Infrequent Access
Regional Archive

One Zone
One Zone-Infrequent Access
```

The exact classes available depend on the filesystem type and Region. EFS IA and Archive are intended for less frequently accessed data and have higher access latency/cost characteristics than Standard. ([AWS Documentation][28])

---

# 50. EFS Lifecycle Management

EFS Lifecycle Management automatically transitions files according to access activity.

Example:

```text
New file:
Standard

Not accessed for 30 days:
Infrequent Access

Not accessed for 90 days:
Archive

Accessed again:
Return to Standard when transition-on-access is configured
```

EFS supports lifecycle policies to transition data among storage classes automatically. ([AWS Documentation][29])

## Small-file consideration

IA and Archive billing rounds small files to minimum metered sizes, so workloads containing millions of tiny files may not achieve the expected cost reduction. ([AWS Documentation][30])

---

# 51. EFS replication

EFS replication can maintain a replica filesystem:

```text
Primary EFS
ap-south-1
      |
      | Asynchronous replication
      v
Replica EFS
ap-southeast-1
```

Use for:

* Disaster recovery.
* Regional migration.
* Read-only recovery copy.
* Compliance.

Replication does not automatically redirect application clients.

Your DR process must also handle:

* DNS or configuration changes.
* Mount target creation.
* Security groups.
* IAM.
* Promoting or recreating writable access.
* Application deployment.

---

# 52. EFS backups

EFS can be protected with AWS Backup.

Restore creates data in a recovery target according to the selected restore workflow; restoring a full EFS recovery point can create a new filesystem rather than overwriting the existing one. ([AWS Documentation][31])

Use:

* Daily backup plans.
* Cross-account backup vaults.
* Cross-Region copies.
* Vault Lock for immutable backup controls.
* Tested restores.

Replication and backup are not interchangeable:

```text
Replication:
Low-RPO copy that can replicate unwanted changes

Backup:
Historical recovery points
```

---

# 53. EFS versus EBS

| Requirement                        | EBS            | EFS                  |
| ---------------------------------- | -------------- | -------------------- |
| One server’s operating-system disk | Best           | Not suitable         |
| Database block storage             | Best           | Usually not          |
| Shared Linux files                 | Limited        | Best                 |
| Multiple AZ clients                | Not one volume | Regional EFS         |
| Fixed capacity                     | Yes            | No                   |
| Automatically scales storage       | No             | Yes                  |
| Block-level controls               | Yes            | No                   |
| NFS semantics                      | No             | Yes                  |
| Snapshot backup                    | EBS snapshot   | AWS Backup           |
| Very low block latency             | Better fit     | Network file latency |

---

# 54. Amazon FSx overview

Amazon FSx provides fully managed specialised file systems.

Current primary FSx types are:

```text
FSx for Windows File Server
FSx for Lustre
FSx for NetApp ONTAP
FSx for OpenZFS
```

([AWS Documentation][32])

Use FSx when you need filesystem features or compatibility that EFS does not provide.

---

# 55. FSx selection model

```text
Windows SMB and Active Directory?
    → FSx for Windows File Server

HPC, ML or very high-throughput parallel processing?
    → FSx for Lustre

Existing NetApp, multiprotocol or enterprise storage?
    → FSx for NetApp ONTAP

Existing ZFS/NFS workload, snapshots and clones?
    → FSx for OpenZFS
```

---

# 56. FSx for Windows File Server

FSx for Windows provides managed Windows file storage using SMB.

Suitable for:

* Windows shared drives.
* Microsoft applications.
* User home directories.
* SQL Server file shares where supported by the application.
* Windows lift-and-shift.
* Group Policy–controlled environments.
* Active Directory–integrated applications.

Architecture:

```text
Windows clients
      |
      | SMB
      v
FSx for Windows File Server
      |
      v
AWS Managed Microsoft AD
or self-managed AD
```

---

# 57. Windows Multi-AZ architecture

```text
Preferred AZ:
Active file server + storage

Standby AZ:
Standby file server + replicated storage
```

FSx for Windows Multi-AZ uses a highly available Windows cluster across two AZs and synchronously replicates data between the AZs. ([AWS Documentation][33])

Use Multi-AZ for:

* Business-critical shared drives.
* Production Windows applications.
* Workloads requiring automatic AZ failover.

---

# 58. Active Directory requirement

FSx for Windows integrates with:

* AWS Managed Microsoft AD.
* Self-managed Microsoft Active Directory.

AD provides:

* User authentication.
* Group-based permissions.
* Kerberos.
* DNS integration.
* Windows ACL management.

DNS and network connectivity to domain controllers must function correctly. Internet-gateway routing is not a substitute for direct private connectivity to required directory DNS services. ([AWS Documentation][34])

---

# 59. FSx for Lustre

Lustre is a high-performance parallel filesystem.

Suitable for:

* High-performance computing.
* Machine-learning training.
* Genomics.
* Financial simulations.
* Media processing.
* Large-scale analytics.
* High-throughput data pipelines.

Architecture:

```text
Compute fleet
EC2 / EKS / AWS Batch
       |
       | Parallel Lustre access
       v
FSx for Lustre
       |
       | Data repository association
       v
Amazon S3
```

FSx for Lustre can be linked to S3 so that S3 objects appear as files and changes can be imported or exported. ([AWS Documentation][35])

---

# 60. Lustre Scratch versus Persistent

## Scratch

Designed for:

* Temporary processing.
* Short-lived datasets.
* Reproducible workloads.
* Maximum temporary throughput.

Data is not replicated, and data can be lost if a file server fails. ([AWS Documentation][36])

## Persistent

Designed for:

* Longer-running workloads.
* Data that must survive file-server replacement.
* Consistent ongoing processing.
* Production workloads.

Persistent Lustre data is replicated, and failed file servers are replaced. ([AWS Documentation][37])

## Recommended pattern

```text
S3:
Durable source and result repository

Lustre:
High-performance working filesystem
```

---

# 61. FSx for NetApp ONTAP

FSx for ONTAP provides managed NetApp ONTAP capabilities.

It supports access through:

```text
NFS
SMB
iSCSI
NVMe
```

and can provide multiprotocol access to the same volume. ([AWS Documentation][38])

Suitable for:

* Existing NetApp workloads.
* Enterprise NAS migration.
* VMware-related storage workflows.
* Shared Linux and Windows data.
* Database storage through supported protocols.
* Deduplication and compression.
* Snapshots and clones.
* Storage tiering.
* SnapMirror replication.

---

# 62. ONTAP storage hierarchy

```text
FSx file system
      |
      ├── Storage Virtual Machine
      |       |
      |       ├── NFS endpoint
      |       ├── SMB endpoint
      |       └── iSCSI endpoint
      |
      └── Volumes
              |
              ├── Shares
              ├── Exports
              └── LUNs
```

ONTAP is more feature-rich and complex than EFS.

Select it when its enterprise functionality is required—not merely because it supports NFS.

---

# 63. ONTAP migration

For migrations from existing NetApp ONTAP, SnapMirror provides efficient block-level replication and preserves features such as compression, deduplication and snapshots in supported migration scenarios. ([AWS Documentation][39])

For migration from other file systems, AWS DataSync is commonly recommended. ([AWS Documentation][40])

---

# 64. FSx for OpenZFS

FSx for OpenZFS provides managed OpenZFS-compatible shared storage through NFS.

Suitable for:

* Linux NFS applications.
* ZFS lift-and-shift.
* Databases requiring shared low-latency NFS storage.
* Development clones.
* Media workflows.
* Snapshot-heavy applications.

Features include:

* ZFS snapshots.
* Writable clones.
* Compression.
* NFS access.
* Single-AZ and Multi-AZ deployment options.
* On-demand and scheduled replication options.

---

# 65. OpenZFS snapshots and clones

```text
Production volume
       |
       | Snapshot
       v
Point-in-time image
       |
       | Create clone
       v
Writable test environment
```

OpenZFS clone volumes are created quickly and initially consume no additional storage for unchanged shared data. ([AWS Documentation][41])

Use for:

* Development copies.
* Database testing.
* Analytics.
* Fast rollback experimentation.
* CI environments using representative data.

---

# 66. OpenZFS Multi-AZ

FSx for OpenZFS Multi-AZ uses file servers and storage across two AZs with synchronous replication and automatic failover.

AWS states that failover commonly completes within about 60 seconds, making Multi-AZ appropriate for business-critical production and database workloads. ([AWS Documentation][42])

---

# 67. FSx backup considerations

FSx products provide service-specific backup features and can also integrate with AWS Backup.

Backup support and restrictions vary by filesystem type.

For example:

* FSx for Windows supports automatic and user-initiated backups.
* FSx for OpenZFS supports automatic and user-initiated volume backups.
* Persistent Lustre backup support has conditions, particularly around S3-linked repositories. ([AWS Documentation][43])

Always read the backup restrictions for the selected FSx type rather than assuming every FSx filesystem behaves identically.

---

# 68. Storage-selection examples

## Node.js application server

```text
Root:
gp3 EBS

Application artifacts:
S3

Shared uploads:
EFS or S3 depending on application design

Logs:
CloudWatch Logs or S3
```

## PostgreSQL on EC2

```text
Root:
gp3

Database data:
gp3 for moderate requirements
io2 for sustained critical IOPS

Backups:
Database-native backup + EBS snapshots + S3
```

## WordPress fleet

```text
EC2 Auto Scaling
        |
        ├── EFS for wp-content/uploads
        ├── RDS database
        └── CloudFront for static delivery
```

## Machine-learning training

```text
Dataset:
S3

High-performance training filesystem:
FSx for Lustre

Model checkpoints:
S3 or durable Lustre strategy
```

## Windows enterprise share

```text
FSx for Windows Multi-AZ
+
Microsoft Active Directory
```

## Existing NetApp datacentre migration

```text
FSx for ONTAP
+
SnapMirror
```

---

# 69. Terraform EBS example

```hcl
resource "aws_ebs_volume" "application_data" {
  availability_zone = aws_instance.application.availability_zone

  type       = "gp3"
  size       = 100
  iops       = 6000
  throughput = 250

  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn

  tags = {
    Name        = "production-application-data"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_volume_attachment" "application_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.application_data.id
  instance_id = aws_instance.application.id
}
```

Terraform attaches the block device but does not automatically create and mount the Linux filesystem unless you add bootstrapping or configuration management.

---

# 70. Launch-template EBS example

```hcl
resource "aws_launch_template" "application" {
  name_prefix   = "production-application-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 30
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      kms_key_id            = aws_kms_key.ebs.arn
      delete_on_termination = true
    }
  }
}
```

For Auto Scaling instances, persistent application state should generally live outside the individual root volume.

---

# 71. Terraform EFS example

```hcl
resource "aws_efs_file_system" "shared" {
  encrypted  = true
  kms_key_id = aws_kms_key.efs.arn

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_archive = "AFTER_90_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name        = "production-shared"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 72. Terraform EFS mount targets

```hcl
resource "aws_efs_mount_target" "shared" {
  for_each = {
    for index, subnet_id in var.private_subnet_ids :
    index => subnet_id
  }

  file_system_id  = aws_efs_file_system.shared.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
```

Security group:

```hcl
resource "aws_security_group" "efs" {
  name   = "production-efs"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "NFS from application servers"
    protocol        = "tcp"
    from_port       = 2049
    to_port         = 2049
    security_groups = [aws_security_group.application.id]
  }
}
```

---

# 73. Terraform EFS access point

```hcl
resource "aws_efs_access_point" "application" {
  file_system_id = aws_efs_file_system.shared.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/applications/todoapp"

    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "0750"
    }
  }

  tags = {
    Name = "production-todoapp"
  }
}
```

This prevents the application from automatically using the entire shared filesystem root.

---

# 74. Terraform FSx for Windows concept

```hcl
resource "aws_fsx_windows_file_system" "shared" {
  active_directory_id = aws_directory_service_directory.corporate.id

  storage_capacity    = 1024
  storage_type        = "SSD"
  throughput_capacity = 64

  deployment_type     = "MULTI_AZ_1"
  preferred_subnet_id = var.private_subnet_ids[0]

  subnet_ids = [
    var.private_subnet_ids[0],
    var.private_subnet_ids[1]
  ]

  security_group_ids = [
    aws_security_group.fsx_windows.id
  ]

  automatic_backup_retention_days = 7

  copy_tags_to_backups = true

  tags = {
    Name        = "production-windows-share"
    Environment = "production"
  }
}
```

Exact capacity and throughput values must be chosen from those supported by the deployment type and Region.

---

# 75. Storage backup architecture

A mature design may combine:

```text
EBS snapshots:
Short-term server recovery

AWS Backup:
Central policy, vault and cross-account copy

Application backup:
Database-native logical or physical backup

Cross-Region copy:
Regional disaster recovery

Recycle Bin:
Accidental deletion recovery

Backup Vault Lock:
Backup immutability

Restore testing:
Proof that recovery actually works
```

A backup that has never been restored successfully is only an assumption.

---

# 76. RPO and RTO

## RPO

```text
Recovery Point Objective:
How much data loss is acceptable?
```

Example:

```text
Hourly snapshots:
Potential RPO up to one hour
```

## RTO

```text
Recovery Time Objective:
How quickly must service return?
```

Example:

```text
Archived EBS snapshot:
Poor fit for a 15-minute RTO
```

Your choice of:

* Snapshot frequency.
* Replication.
* FSR.
* Multi-AZ deployment.
* Archive tier.
* Backup vault.

must follow the required RPO and RTO.

---

# 77. Monitoring checklist

## EBS

Monitor:

* IOPS.
* Throughput.
* Queue length.
* Burst balance.
* Filesystem free space.
* Inodes.
* Snapshot age.
* Snapshot failures.
* KMS errors.

## EFS

Monitor:

* Total I/O bytes.
* Metered I/O bytes.
* Percent IO limit.
* Burst credit balance where applicable.
* Client connections.
* Storage in each class.
* Replication state.
* Backup age.

## FSx

Monitor:

* Storage utilisation.
* Free capacity.
* Throughput utilisation.
* IOPS.
* Network throughput.
* Cache performance where applicable.
* File-server health.
* Backup status.
* Replication lag.

---

# 78. Troubleshooting: EFS mount timeout

Symptoms:

```text
mount.nfs:
Connection timed out
```

Check:

```text
1. Mount target exists in reachable VPC.
2. Client and mount-target routing is valid.
3. Mount-target security group allows TCP 2049.
4. Client security group allows outbound TCP 2049.
5. DNS resolution is enabled.
6. Network ACLs permit traffic.
7. Mount helper is installed.
8. Correct filesystem ID is used.
```

EFS mount failures commonly result from mount-target, DNS, security-group or IAM mount configuration problems. ([AWS Documentation][44])

---

# 79. Troubleshooting: EFS permission denied

If the filesystem mounts but file access fails:

```text
Network layer:
Already working

Likely issue:
POSIX permissions, IAM or access-point identity
```

Check:

```bash
id
ls -ln /mnt/shared
```

Review:

* UID and GID.
* Directory owner.
* Mode bits.
* Root squashing.
* Access-point POSIX identity.
* EFS filesystem policy.
* IAM role.
* Mount options `iam` and `tls`.

---

# 80. Troubleshooting: FSx for Windows unavailable

Check:

* Active Directory health.
* DNS resolution.
* Required SMB and AD ports.
* Security groups.
* Routing to domain controllers.
* AD service account permissions.
* Time synchronisation.
* File-system DNS name.
* Client domain membership.
* Windows firewall.
* Multi-AZ preferred/standby status.

FSx for Windows creation and access failures frequently originate from Active Directory or DNS configuration. ([AWS Documentation][45])

---

# 81. Troubleshooting: FSx for Lustre cannot link to S3

Possible causes:

* Caller lacks access to S3 bucket.
* Bucket policy denies FSx.
* KMS key denies access.
* Bucket Region or configuration is unsupported.
* Object naming or repository configuration is invalid.
* Data-repository association role is insufficient.

AWS documents insufficient caller permission to the S3 bucket as a common validation failure when creating a linked Lustre repository. ([AWS Documentation][46])

---

# 82. Common storage mistakes

## Mistake 1: Using EBS for shared Auto Scaling state

```text
One AZ-bound volume
+
Many replaceable instances
=
Poor shared-storage architecture
```

Use EFS, FSx, S3 or an application data service.

## Mistake 2: Selecting `io2` without measurements

High-end storage does not fix:

* Bad queries.
* Insufficient memory.
* Lock contention.
* Poor filesystem configuration.
* Instance EBS bottlenecks.

## Mistake 3: Treating snapshots as application-consistent automatically

Snapshot consistency depends on application write state.

## Mistake 4: Assuming EFS is a faster EBS disk

EFS is a network filesystem with different latency and semantics.

## Mistake 5: Using Lustre Scratch as the only durable copy

Scratch data can be lost after file-server failure. ([AWS Documentation][36])

## Mistake 6: Multi-Attach with ext4 on two writers

This risks filesystem corruption.

## Mistake 7: Backup without restore tests

A successful backup job does not prove application recovery.

---

# 83. Production selection checklist

```text
[ ] Storage model is identified: block, file or object
[ ] Required protocols are identified
[ ] Required Availability Zone resilience is defined
[ ] RPO and RTO are documented
[ ] IOPS requirement is measured
[ ] Throughput requirement is measured
[ ] Latency requirement is measured
[ ] EC2 EBS limits are verified
[ ] gp3 is considered before io2
[ ] HDD is used only for sequential workloads
[ ] EBS volumes and EC2 instances share an AZ
[ ] EBS encryption is enabled
[ ] KMS policies permit recovery operations
[ ] Snapshot schedule is automated
[ ] Cross-Region copies are configured when required
[ ] Recycle Bin protects critical snapshots
[ ] FSR is considered for low-RTO restores
[ ] Archived-snapshot restore time is understood
[ ] EFS uses mount targets in required AZs
[ ] EFS security groups allow only approved clients
[ ] EFS mounts use TLS
[ ] EFS access points isolate applications
[ ] POSIX identities are documented
[ ] EFS lifecycle policy is cost-modelled
[ ] One Zone storage is used only when acceptable
[ ] Correct FSx type is selected
[ ] Windows FSx Active Directory dependency is resilient
[ ] Lustre Scratch data is reproducible
[ ] ONTAP complexity is justified
[ ] OpenZFS deployment type matches availability needs
[ ] Backups are stored in protected vaults
[ ] Restore tests are scheduled
[ ] Monitoring and capacity alarms are configured
```

---

# 84. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
EBS:
Block storage for EC2

EFS:
Shared Linux filesystem

FSx:
Managed specialised file systems

S3:
Object storage
```

## Solutions Architect Associate

Understand:

```text
gp3 versus io2
EBS AZ scope
EBS snapshots
EFS Regional versus One Zone
EFS mount targets
EFS throughput modes
FSx Windows versus Lustre
Multi-AZ storage
Encryption and backups
```

## DevOps Engineer Professional

Understand:

```text
Automated EBS snapshots
Data Lifecycle Manager
AWS Backup
Cross-account and cross-Region recovery
Fast Snapshot Restore
Recycle Bin
EFS IAM authorization
Access points
Lifecycle classes
FSx backup and failover
Terraform storage automation
Monitoring and restore testing
```

---

# 85. Interview questions

## Question 1: What is the difference between EBS and EFS?

**Answer:**

EBS provides block storage normally attached to an EC2 instance in one AZ. EFS provides a managed NFS filesystem that can be mounted by multiple clients and can be Regional across AZs.

## Question 2: Can an EBS volume be attached to an instance in another AZ?

**Answer:**

No. Create a snapshot and restore a new volume in the destination AZ.

## Question 3: When should you use `gp3`?

**Answer:**

Use it as the general default for boot disks, applications and moderate databases because capacity, IOPS and throughput can be configured independently.

## Question 4: When should you use `io2`?

**Answer:**

Use it for critical workloads requiring sustained high IOPS, high throughput, consistent low latency or Multi-Attach.

## Question 5: What is the difference between IOPS and throughput?

**Answer:**

IOPS measures the number of operations per second. Throughput measures the total volume of data transferred per second.

## Question 6: Are EBS snapshots full backups?

**Answer:**

They are incremental internally, but each snapshot serves as an independent restore point.

## Question 7: What is Fast Snapshot Restore?

**Answer:**

It enables volumes created from selected snapshots in selected AZs to be fully initialised and immediately deliver provisioned performance.

## Question 8: What is EBS Multi-Attach?

**Answer:**

It allows an eligible `io1` or `io2` volume to be attached to multiple Nitro instances in the same AZ. The application must coordinate concurrent writes.

## Question 9: Can two instances safely mount one Multi-Attach ext4 filesystem?

**Answer:**

No. An ordinary non-cluster filesystem can become corrupted when mounted by multiple writable hosts.

## Question 10: What is an EFS mount target?

**Answer:**

It is the network endpoint through which resources in a VPC connect to an EFS filesystem.

## Question 11: What is an EFS access point?

**Answer:**

It is an application-specific filesystem entry point that can enforce a root directory and POSIX user identity.

## Question 12: What EFS throughput modes are available?

**Answer:**

Elastic, Provisioned and Bursting.

## Question 13: What is the difference between EFS Regional and One Zone?

**Answer:**

Regional EFS stores data across multiple AZs. One Zone stores it within one AZ and should be used only when AZ-loss risk is acceptable.

## Question 14: When should you use FSx for Windows?

**Answer:**

For managed SMB storage requiring Windows ACLs and Microsoft Active Directory integration.

## Question 15: When should you use FSx for Lustre?

**Answer:**

For high-performance parallel workloads such as machine learning, HPC, analytics and media processing.

## Question 16: What is the difference between Lustre Scratch and Persistent?

**Answer:**

Scratch is temporary and unreplicated. Persistent replicates data and replaces failed file servers.

## Question 17: When should you use FSx for ONTAP?

**Answer:**

When you need enterprise NetApp capabilities, multiprotocol NFS/SMB/iSCSI access, snapshots, tiering, clones or SnapMirror migration.

## Question 18: When should you use FSx for OpenZFS?

**Answer:**

For NFS applications requiring ZFS features such as snapshots, clones, compression and managed Single-AZ or Multi-AZ deployment.

## Question 19: What is the difference between replication and backup?

**Answer:**

Replication provides a current secondary copy and can propagate deletions or corruption. Backups preserve historical recovery points.

## Question 20: How should storage be selected?

**Answer:**

Choose from workload access model, protocol, latency, IOPS, throughput, sharing requirements, AZ resilience, durability, RPO, RTO and cost.

---

# 86. Never-forget revision

```text
EBS:
AZ-scoped block storage.

gp3:
General-purpose SSD and usual default.

io2:
Critical high-performance SSD.

st1:
Frequently accessed sequential HDD.

sc1:
Cold sequential HDD.

IOPS:
Operations per second.

Throughput:
Data transferred per second.

Snapshot:
Incremental point-in-time EBS backup.

FSR:
Fully initialised snapshot restore.

Recycle Bin:
Temporary recovery for deleted EBS resources.

Multi-Attach:
Shared io1/io2 block volume in one AZ.

EFS:
Managed shared NFS storage.

Mount target:
EFS network endpoint in a VPC.

Access point:
Application-specific EFS entry and POSIX identity.

EFS Regional:
Multi-AZ shared filesystem.

EFS One Zone:
Single-AZ shared filesystem.

FSx Windows:
Managed Windows SMB.

FSx Lustre:
High-performance parallel filesystem.

FSx ONTAP:
Managed NetApp multiprotocol storage.

FSx OpenZFS:
Managed NFS with ZFS features.
```

## One-line memory trick

```text
EBS is a disk.
EFS is a shared Linux filesystem.
FSx is a specialised enterprise filesystem.
S3 is object storage.
Snapshots protect block history.
Backups prove recovery only after a restore test.
```

## Lesson 34 outcome

You can now design storage where:

```text
EC2 needs a boot disk
    → gp3 EBS.

A critical database needs sustained high IOPS
    → io2 is evaluated.

Several Linux application instances share uploads
    → Regional EFS with access points.

Windows users need a corporate shared drive
    → FSx for Windows Multi-AZ.

Machine-learning workers process an S3 dataset
    → FSx for Lustre.

NetApp workloads move to AWS
    → FSx for ONTAP and SnapMirror.

A snapshot is deleted accidentally
    → Recycle Bin recovers it.

A Region fails
    → Cross-Region backups and tested restore procedures recover the workload.
```

**Next lesson: Lesson 35 — AWS Backup, DataSync, Storage Gateway, Transfer Family and production hybrid-data migration architecture.**

[1]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes.html?utm_source=chatgpt.com "Amazon EBS volumes"
[2]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html?utm_source=chatgpt.com "Amazon EBS volume types"
[3]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html?utm_source=chatgpt.com "Amazon EBS-optimized instance types"
[4]: https://docs.aws.amazon.com/ebs/latest/userguide/hdd-vols.html?utm_source=chatgpt.com "Amazon EBS Throughput Optimized HDD and Cold HDD ..."
[5]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-io-characteristics.html?utm_source=chatgpt.com "Amazon EBS I/O characteristics and monitoring"
[6]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-modify-volume.html?utm_source=chatgpt.com "Modify an Amazon EBS volume using Elastic ..."
[7]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes-multi.html?utm_source=chatgpt.com "Attach an EBS volume to multiple EC2 instances using ..."
[8]: https://docs.aws.amazon.com/ebs/latest/userguide/nvme-reservations.html?utm_source=chatgpt.com "Use NVMe reservations with Multi-Attach enabled ..."
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html?utm_source=chatgpt.com "Amazon EBS snapshots"
[10]: https://docs.aws.amazon.com/aws-backup/latest/devguide/multi-volume-crash-consistent.html?utm_source=chatgpt.com "Amazon EBS and AWS Backup"
[11]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-copy-snapshot.html?utm_source=chatgpt.com "Copy an Amazon EBS snapshot"
[12]: https://docs.aws.amazon.com/ebs/latest/userguide/dlm-elements.html?utm_source=chatgpt.com "How Amazon Data Lifecycle Manager works - Amazon EBS"
[13]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-fast-snapshot-restore.html?utm_source=chatgpt.com "Amazon EBS fast snapshot restore"
[14]: https://docs.aws.amazon.com/ebs/latest/userguide/snapshot-archive-considerations.html?utm_source=chatgpt.com "Considerations and limitations for archiving Amazon EBS ..."
[15]: https://docs.aws.amazon.com/ebs/latest/userguide/recycle-bin.html?utm_source=chatgpt.com "Recover deleted EBS volumes, EBS snapshots, and EBS- ..."
[16]: https://docs.aws.amazon.com/ebs/latest/userguide/snapshot-lifecycle.html?utm_source=chatgpt.com "Automate backups with Amazon Data Lifecycle Manager"
[17]: https://docs.aws.amazon.com/ebs/latest/userguide/nvme-detailed-performance-stats.html?utm_source=chatgpt.com "Amazon EBS detailed performance statistics"
[18]: https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html?utm_source=chatgpt.com "What is Amazon Elastic File System?"
[19]: https://docs.aws.amazon.com/efs/latest/ug/network-access.html?utm_source=chatgpt.com "Using VPC security groups - Amazon Elastic File System"
[20]: https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html?utm_source=chatgpt.com "How Amazon EFS works - Amazon Elastic File System"
[21]: https://docs.aws.amazon.com/efs/latest/ug/features.html?utm_source=chatgpt.com "Features of Amazon EFS - Amazon Elastic File System"
[22]: https://docs.aws.amazon.com/efs/latest/ug/encryption-in-transit.html?utm_source=chatgpt.com "Encrypting data in transit - Amazon Elastic File System"
[23]: https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html?utm_source=chatgpt.com "Working with access points - Amazon Elastic File System"
[24]: https://docs.aws.amazon.com/efs/latest/ug/mounting-access-points.html?utm_source=chatgpt.com "Mounting with EFS access points"
[25]: https://docs.aws.amazon.com/efs/latest/ug/iam-access-control-nfs-efs.html?utm_source=chatgpt.com "Using IAM to control access to file systems"
[26]: https://docs.aws.amazon.com/efs/latest/ug/performance-tips.html?utm_source=chatgpt.com "Amazon EFS performance tips - Amazon Elastic File System"
[27]: https://docs.aws.amazon.com/cdk/api/v2/dotnet/api/Amazon.CDK.AWS.EFS.FileSystemProps.html?utm_source=chatgpt.com "Class FileSystemProps"
[28]: https://docs.aws.amazon.com/efs/latest/ug/performance.html?utm_source=chatgpt.com "Amazon EFS performance specifications"
[29]: https://docs.aws.amazon.com/efs/latest/ug/lifecycle-management-efs.html?utm_source=chatgpt.com "Managing storage lifecycle - Amazon Elastic File System"
[30]: https://docs.aws.amazon.com/efs/latest/ug/metered-sizes.html?utm_source=chatgpt.com "How Amazon EFS reports file system and object sizes"
[31]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-efs.html?utm_source=chatgpt.com "Restore an Amazon EFS file system - AWS Backup"
[32]: https://docs.aws.amazon.com/fsx/latest/APIReference/API_CreateFileSystem.html?utm_source=chatgpt.com "CreateFileSystem - Amazon FSx"
[33]: https://docs.aws.amazon.com/fsx/latest/WindowsGuide/high-availability-multiAZ.html?utm_source=chatgpt.com "Availability and durability: Single-AZ and Multi-AZ file ..."
[34]: https://docs.aws.amazon.com/fsx/latest/WindowsGuide/getting-started.html?utm_source=chatgpt.com "Getting started with Amazon FSx for Windows File Server"
[35]: https://docs.aws.amazon.com/fsx/latest/LustreGuide/create-dra-linked-data-repo.html?utm_source=chatgpt.com "Linking your file system to an Amazon S3 bucket - FSx for ..."
[36]: https://docs.aws.amazon.com/fsx/latest/LustreGuide/using-fsx-lustre.html?utm_source=chatgpt.com "Deployment and storage class options for FSx for Lustre ..."
[37]: https://docs.aws.amazon.com/fsx/latest/LustreGuide/what-is.html?utm_source=chatgpt.com "What is Amazon FSx for Lustre?"
[38]: https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html?utm_source=chatgpt.com "What is Amazon FSx for NetApp ONTAP?"
[39]: https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/migrating-fsx-ontap-snapmirror.html?utm_source=chatgpt.com "Migrating to FSx for ONTAP using NetApp SnapMirror"
[40]: https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/migrate-files-to-fsx-datasync.html?utm_source=chatgpt.com "Migrating to FSx for ONTAP using AWS DataSync"
[41]: https://docs.aws.amazon.com/fsx/latest/OpenZFSGuide/snapshots-openzfs.html?utm_source=chatgpt.com "Protecting your data with snapshots - FSx for OpenZFS"
[42]: https://docs.aws.amazon.com/fsx/latest/OpenZFSGuide/availability-durability.html?utm_source=chatgpt.com "Availability and durability for Amazon FSx for OpenZFS"
[43]: https://docs.aws.amazon.com/fsx/latest/WindowsGuide/using-backups.html?utm_source=chatgpt.com "Protecting your data with backups - Amazon FSx for ..."
[44]: https://docs.aws.amazon.com/efs/latest/ug/troubleshooting-efs-mounting.html?utm_source=chatgpt.com "Troubleshooting mount issues - Amazon Elastic File System"
[45]: https://docs.aws.amazon.com/fsx/latest/WindowsGuide/unable-to-create-fs.html?utm_source=chatgpt.com "Creating a new Amazon FSx file system fails"
[46]: https://docs.aws.amazon.com/fsx/latest/LustreGuide/s3-validation-error.html?utm_source=chatgpt.com "Unable to validate access to an S3 bucket when creating a ..."
