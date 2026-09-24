# AWS Masterclass — Lesson 25

# Amazon EBS & EC2 Storage Architecture

We have completed the EC2 **compute/fleet layer**:

```text
EC2
 ↓
Launch Templates
 ↓
ALB
 ↓
Auto Scaling
 ↓
Health + Scaling + Replacement
 ↓
Spot / Mixed Instances
 ↓
Production fleet operations
```

Now we move underneath the server:

```text
               EC2
                │
                ▼
         ┌─────────────┐
         │   STORAGE   │
         └─────────────┘
                │
       ┌────────┼─────────┐
       ▼        ▼         ▼
      EBS   Instance     EFS
             Store
```

This distinction is extremely important for **SAA-C03, DOP-C02, architecture design, database performance, disaster recovery, and production troubleshooting**.

---

# Part 1 — First Understand What EBS Actually Is

Amazon **Elastic Block Store — EBS** provides persistent block-storage volumes for EC2. When attached to an instance, the volume appears to the operating system as a block device, much like a physical SSD or hard drive. You then partition, format, mount, and use it through the operating system. ([AWS Documentation][1])

Mental model:

```text
Physical server:

CPU
RAM
SSD
 │
 ▼
Filesystem
 │
 ▼
Application


AWS:

EC2
 │
 │ block-storage connection
 ▼
EBS Volume
 │
 ▼
Filesystem
 │
 ▼
/data
```

Think:

> **EC2 is your computer. EBS is one of its disks.**

---

# 1. Block Storage — What Does "Block" Mean?

Suppose you have:

```text
100 GiB disk
```

The operating system doesn't fundamentally see:

```text
photo.jpg
database.sql
video.mp4
```

The storage layer provides addressable **blocks**.

Conceptually:

```text
EBS Volume
──────────────────────────────────────
Block 0
Block 1
Block 2
Block 3
Block 4
...
Block N
──────────────────────────────────────
```

The filesystem then organizes those blocks:

```text
EBS blocks
    ↓
Filesystem
    ↓
directories
    ↓
files
```

For Linux:

```text
EBS
 ↓
/dev/nvme1n1
 ↓
ext4 / xfs
 ↓
/data
 ↓
application files
```

That's why EBS is called:

```text
BLOCK STORAGE
```

rather than object storage.

---

# 2. EBS Is Not S3

This distinction must become automatic.

| EBS                               | S3                                            |
| --------------------------------- | --------------------------------------------- |
| Block storage                     | Object storage                                |
| Behaves like a disk               | Behaves like an object store                  |
| Attached to EC2                   | Accessed through service APIs/endpoints       |
| Filesystem normally created by OS | No normal EC2-style block filesystem required |
| `/dev/nvme...`                    | Bucket/object/key model                       |
| Great for OS disks/databases      | Great for objects, backups, media, logs       |

Mental shortcut:

```text
EBS
=
"Give my server a disk."


S3
=
"Give my application an object store."
```

We'll cover S3 deeply later; don't treat EBS and S3 as interchangeable simply because both store data.

---

# 3. EBS vs Instance Store

This one appears constantly in AWS exams and interviews.

## EBS

```text
EC2
 │
 │ network-accessed block storage
 ▼
EBS
```

EBS data can survive an ordinary stop/start operation. EBS volumes also have their own lifecycle and can be detached and attached to another compatible instance in the same Availability Zone. ([AWS Documentation][2])

## Instance Store

```text
Physical EC2 host
      │
      ▼
 Local disk
      │
      ▼
 Instance Store
```

Instance store is temporary block storage physically associated with the host. AWS positions it for temporary information such as buffers, caches, scratch data, and replicated temporary datasets; the data does not survive stop or termination. ([AWS Documentation][3])

So:

```text
EBS
=
persistent server disk


Instance Store
=
fast/local temporary scratch disk
```

### Never forget

```text
EC2 stopped
    │
    ├── EBS → survives
    │
    └── Instance Store → data lost
```

AWS explicitly documents that instance-store data is ephemeral across stop and termination events. ([AWS Documentation][4])

---

# 4. Why Would Anyone Use Instance Store Then?

You may think:

> If Instance Store can disappear, why use it?

Because not all data needs durability.

Imagine:

```text
Application server
      │
      ├── permanent customer data → durable service
      │
      ├── cache                  → temporary
      │
      ├── scratch processing     → temporary
      │
      └── intermediate files     → temporary
```

Instance store can be appropriate for temporary, high-performance data when the application can reconstruct or replicate it. AWS specifically mentions caches, buffers, scratch data, and replicated temporary content as suitable use cases. ([AWS Documentation][3])

Think:

```text
Redis cache copy?
Maybe temporary.

Video transcoding scratch files?
Temporary.

Critical PostgreSQL database
with its only copy on instance store?
Dangerous architecture.
```

---

# 5. EBS Is Availability-Zone Scoped

This is one of the most important EBS rules.

Suppose:

```text
EC2:
ap-south-1a

EBS:
ap-south-1a
```

Attach:

```text
YES
```

But:

```text
EC2:
ap-south-1a

EBS:
ap-south-1b
```

Attach directly:

```text
NO
```

AWS requires an EBS volume and the EC2 instance to which it is attached to be in the **same Availability Zone**. ([AWS Documentation][5])

Visual:

```text
             ap-south-1
                 │
        ┌────────┴─────────┐
        │                  │
   ap-south-1a        ap-south-1b
        │                  │
       EC2                EC2
        │                  │
       EBS                EBS
        │                  │
        ✓                  ✓


Cross-AZ direct attachment:

EC2 1a ───────X──────▶ EBS 1b
```

---

# 6. But EBS Is Not Just One Physical Disk

When AWS says EBS behaves like a disk, don't imagine:

```text
one cheap SSD
plugged into one physical server
```

AWS automatically replicates an EBS volume within its Availability Zone to protect against failure of a single underlying hardware component. ([AWS Documentation][6])

Conceptually:

```text
          EBS logical volume
                 │
          AWS storage layer
                 │
        internal redundancy
                 │
             AZ scope
```

Important distinction:

```text
EBS redundancy
=
within the AZ

NOT

automatic cross-AZ application replication
```

If your application requires:

```text
AZ-a fails
     ↓
service must continue from AZ-b
```

you still need an architecture for that.

For example:

```text
Database replication
Multi-AZ service
application-level replication
snapshot/restore strategy
```

EBS alone doesn't magically make a single EC2/EBS pair Multi-AZ.

---

# 7. Root Volume vs Data Volume

An EC2 instance commonly looks like:

```text
EC2
 │
 ├── Root EBS
 │     │
 │     └── /
 │         OS
 │         /etc
 │         /var
 │         application binaries
 │
 └── Data EBS
       │
       └── /data
           database
           uploads
           application data
```

Think of a normal laptop:

```text
C: drive
+
D: drive
```

Same idea conceptually.

---

# 8. Root Volume

The root volume contains the operating system.

Linux example:

```text
/
├── boot
├── etc
├── home
├── opt
├── usr
└── var
```

When an EC2 instance uses an EBS-backed root volume, the instance can be stopped and later restarted without losing the attached EBS data merely because of the stop/start operation. ([AWS Documentation][2])

But termination is different.

---

# 9. DeleteOnTermination

This catches many beginners.

Suppose:

```text
EC2
 │
 ├── Root Volume
 └── Data Volume
```

Each EBS block-device mapping can carry:

```text
DeleteOnTermination
```

Typical default behavior is:

```text
Root EBS
DeleteOnTermination = true

Data EBS
DeleteOnTermination = false
```

for conventional block-device mappings, although launch method and AMI settings can affect the final value, so production engineers should verify it explicitly. ([AWS Documentation][7])

Therefore:

```text
Terminate EC2
     │
     ├── root volume → often deleted
     │
     └── data volume → often preserved
```

### Major production trap

Engineer thinks:

> EBS is persistent, therefore terminating EC2 cannot delete my root disk.

Wrong.

Persistence and deletion policy are separate concepts.

---

# 10. Stop vs Terminate

Memorize this distinction.

```text
STOP
 │
 ├── EC2 compute stops
 │
 └── attached EBS remains


TERMINATE
 │
 ├── EC2 permanently removed
 │
 └── EBS behavior depends on
      DeleteOnTermination
```

For ordinary EC2 launch-time EBS root volumes, deletion on termination is normally enabled by default. ([AWS Documentation][8])

This is why before terminating an important EC2 server you should inspect:

```text
Block device mappings
Snapshots/backups
DeleteOnTermination
```

not simply assume storage survives.

---

# 11. EBS Volume Lifecycle

Think of it as an independent resource:

```text
Create volume
     ↓
available
     ↓
attach
     ↓
in-use
     ↓
filesystem / application writes
     ↓
detach
     ↓
available
     ↓
attach elsewhere
     ↓
delete
```

AWS allows a volume to be created empty or from an existing snapshot, and it can subsequently be attached to an EC2 instance in the same AZ. ([AWS Documentation][9])

This has an important consequence.

Your EC2 can die while the data volume survives.

```text
EC2-A
  X
  │
 EBS
  │
  ▼
EC2-B
```

provided the replacement instance can use it and is in the appropriate Availability Zone.

---

# 12. Linux Hands-On Mental Model

Imagine AWS gives your EC2 a new EBS volume.

Attaching it doesn't automatically mean:

```text
/data exists and works
```

At the OS layer the workflow is:

```text
Create EBS
    ↓
Attach EBS
    ↓
Linux sees block device
    ↓
Create filesystem
    ↓
Create mount directory
    ↓
Mount filesystem
    ↓
Persist mount configuration
```

AWS confirms that after attachment, the EBS volume is exposed as a block device that can be formatted with a filesystem and mounted. ([AWS Documentation][10])

---

# 13. Find the New Disk

Linux:

```bash
lsblk
```

You might see:

```text
NAME          SIZE TYPE MOUNTPOINTS
nvme0n1        20G disk
└─nvme0n1p1    20G part /

nvme1n1       100G disk
```

Interpretation:

```text
nvme0n1
=
root EBS


nvme1n1
=
new unformatted EBS
```

Check filesystem signatures:

```bash
sudo file -s /dev/nvme1n1
```

Or:

```bash
sudo blkid /dev/nvme1n1
```

If it's a brand-new empty volume, there may be no filesystem yet.

---

# 14. Create Filesystem

For example:

```bash
sudo mkfs.xfs /dev/nvme1n1
```

or:

```bash
sudo mkfs.ext4 /dev/nvme1n1
```

Then:

```bash
sudo mkdir -p /data
```

Mount:

```bash
sudo mount /dev/nvme1n1 /data
```

Verify:

```bash
df -hT
```

Conceptually:

```text
/dev/nvme1n1
      │
     XFS
      │
      ▼
    /data
```

---

# 15. Important Linux Warning

Never casually run:

```bash
mkfs.xfs /dev/nvme1n1
```

on an existing volume containing data.

`mkfs` means:

```text
MAKE FILESYSTEM
```

and can destroy the filesystem/data layout you were trying to recover.

So production flow is:

```text
lsblk
 ↓
file / blkid
 ↓
identify device
 ↓
only format if genuinely new
```

This is an operations habit worth remembering far beyond AWS.

---

# 16. Mount Persistence

A manual:

```bash
mount /dev/nvme1n1 /data
```

does not by itself guarantee the disk gets mounted automatically after reboot.

Linux commonly uses:

```text
/etc/fstab
```

For reliability, prefer the filesystem UUID rather than relying purely on device enumeration.

Find UUID:

```bash
sudo blkid /dev/nvme1n1
```

Example:

```text
UUID="abcd-1234..."
```

Then conceptually:

```text
UUID=abcd-1234  /data  xfs  defaults,nofail  0  2
```

Now:

```bash
sudo mount -a
```

and validate.

---

# 17. EBS Volume Families

Amazon EBS currently offers SSD and HDD-backed families including:

| Type  | Category                 | Mental model                          |
| ----- | ------------------------ | ------------------------------------- |
| `gp3` | General Purpose SSD      | Default choice for many workloads     |
| `gp2` | General Purpose SSD      | Older general-purpose model           |
| `io2` | Provisioned IOPS SSD     | High-performance/latency-sensitive    |
| `io1` | Provisioned IOPS SSD     | Older provisioned IOPS family         |
| `st1` | Throughput Optimized HDD | Large sequential workloads            |
| `sc1` | Cold HDD                 | Infrequently accessed sequential data |

AWS documents these current volume families and their differing performance/cost characteristics. ([AWS Documentation][11])

Now we'll understand **IOPS vs throughput** before choosing any of them.

---

# 18. What Is IOPS?

IOPS means:

```text
Input/Output
Operations
Per
Second
```

Imagine your application performs tiny random storage requests:

```text
read 16 KB
write 8 KB
read 4 KB
read 16 KB
write 4 KB
...
```

The number of these operations per second matters.

Think:

```text
Many small random operations
        ↓
IOPS matters
```

Typical examples:

```text
database indexes
transaction databases
random reads/writes
small database pages
```

---

# 19. What Is Throughput?

Throughput asks:

> How much data can move per second?

Example:

```text
500 MiB/s
```

Think:

```text
large sequential data
      ↓
throughput matters
```

Examples:

```text
large log processing
ETL
data warehouses
large sequential files
streaming workloads
```

AWS describes `st1` specifically as throughput-oriented storage for large sequential workloads such as ETL, EMR, log processing, and data warehouses. ([AWS Documentation][12])

---

# 20. IOPS vs Throughput — Never Confuse Them

Imagine two highways.

### IOPS

```text
How many cars pass per second?
```

### Throughput

```text
How much total cargo passes per second?
```

A storage system could support:

```text
many tiny operations
```

without enormous MB/s.

Or:

```text
fewer giant sequential transfers
```

with enormous MB/s.

So:

```text
IOPS
≠
Throughput
```

Both matter.

And there is a third dimension:

```text
Latency
```

which asks:

> How long does one I/O request take?

---

# 21. Storage Performance Triangle

```text
                STORAGE
                   │
          ┌────────┼────────┐
          │        │        │
          ▼        ▼        ▼
        IOPS   Throughput  Latency
          │        │        │
          ▼        ▼        ▼
     operations   data     response
     per second  per sec    time
```

Example:

```text
OLTP database
    ↓
small random I/O
    ↓
IOPS + latency


Data warehouse scan
    ↓
large sequential I/O
    ↓
throughput
```

This distinction will become crucial when we diagnose:

```text
"My EC2 CPU is only 20%,
but my application is extremely slow."
```

The bottleneck might actually be storage.

---

# 22. `gp3` — The Volume Type You Should Know Very Well

For many normal production workloads, `gp3` is the starting point.

A major architectural benefit is that storage size, provisioned IOPS, and throughput are not rigidly tied together the way older `gp2` performance behavior was. Current AWS documentation shows `gp3` with baseline performance of **3,000 IOPS and 125 MiB/s**, with higher IOPS and throughput independently provisionable subject to its limits. ([AWS Documentation][13])

Mental model:

```text
gp3
 │
 ├── Size
 │
 ├── IOPS
 │
 └── Throughput

Tune according to workload
```

Current AWS documentation allows `gp3` performance up to **80,000 IOPS and 2,000 MiB/s**, subject to volume sizing and IOPS/throughput ratios. ([AWS Documentation][13])

This is why you shouldn't memorize outdated AWS numbers from an old tutorial.

---

# 23. Example gp3 Design

Suppose your application needs:

```text
Storage:
100 GiB

IOPS:
3,000

Throughput:
125 MiB/s
```

A basic `gp3` configuration can provide that baseline performance.

Later monitoring shows:

```text
storage capacity:
only 40 GiB used

IOPS demand:
8,000

throughput:
250 MiB/s
```

Instead of making the volume giant merely to get performance, with `gp3` you can tune relevant performance settings independently within AWS-supported constraints. ([AWS Documentation][13])

That's an important cost/performance design idea.

---

# 24. `io2` — Provisioned IOPS

Now imagine:

```text
mission-critical transactional database
        │
        ├── predictable IOPS
        ├── demanding latency requirement
        └── high-performance storage
```

This is the domain where Provisioned IOPS SSD such as:

```text
io2
```

becomes relevant.

AWS positions Provisioned IOPS SSD for workloads needing sustained IOPS performance, and `io2` Block Express supports substantially higher provisioned IOPS than normal general-purpose volumes. ([AWS Documentation][14])

Mental shortcut:

```text
gp3
=
general-purpose production SSD


io2
=
serious high-performance provisioned-I/O workload
```

Don't automatically select `io2` simply because:

> expensive = better.

Architecture should follow workload requirements.

---

# 25. `st1`

`st1`:

```text
Throughput Optimized HDD
```

Good mental fit:

```text
large
sequential
frequently accessed
throughput-heavy data
```

Examples AWS provides include ETL, EMR, data warehouses, and log processing. `st1` isn't supported as a boot volume. ([AWS Documentation][12])

Think:

```text
Huge sequential files
       ↓
throughput more important
than tiny random-I/O latency
```

---

# 26. `sc1`

`sc1`:

```text
Cold HDD
```

Designed for:

```text
large sequential data
+
infrequent access
+
very cost-conscious workload
```

AWS describes it as low-cost magnetic block storage for cold sequential workloads, and it also can't be used as a bootable volume. ([AWS Documentation][12])

Mental model:

```text
st1
=
warm-ish big sequential data


sc1
=
cold big sequential data
```

---

# 27. Volume-Type Selection Trick

When asked:

> Which EBS type should I choose?

Don't begin by memorizing product names.

Ask:

```text
What access pattern?
       │
       ├── random?
       │
       └── sequential?
              │
              ▼
How much IOPS?
              │
              ▼
How much throughput?
              │
              ▼
What latency requirement?
              │
              ▼
How much capacity?
              │
              ▼
What cost tolerance?
```

Then choose the technology.

This is the same architectural method we've been building throughout the course:

```text
Requirement
    ↓
Constraint
    ↓
Service capability
    ↓
Architecture choice
```

Not:

```text
Memorize AWS service
      ↓
force every problem
into that service
```

---

# 28. EBS Elastic Volumes

Suppose today:

```text
100 GiB gp3
```

Three months later:

```text
disk 90% full
```

Old-school infrastructure mindset:

```text
shut down
detach disk
create bigger disk
copy
reattach
reboot
```

EBS supports **Elastic Volumes**, which can change supported volume characteristics such as size, type, IOPS, and throughput without requiring detachment or an EC2 restart on supported instances. ([AWS Documentation][15])

Conceptually:

```text
gp3
100 GiB
3000 IOPS

     ↓ modify

gp3
200 GiB
6000 IOPS
```

while the application can remain running.

But there is an important second layer.

---

# 29. AWS Disk Size vs Linux Filesystem Size

Suppose AWS says:

```text
EBS:
100 GiB
↓
200 GiB
```

Does Linux `/data` automatically become 200 GiB?

Not necessarily.

Think:

```text
AWS storage layer
       │
       ▼
Block device
       │
       ▼
Partition
       │
       ▼
Filesystem
```

Increasing:

```text
EBS capacity
```

only solves one layer.

The OS may still require:

```text
partition expansion
+
filesystem expansion
```

This is one of the most common cloud-storage troubleshooting mistakes.

---

# 30. Example Expansion Mental Model

Before:

```text
EBS             100 GiB
 └─ partition   100 GiB
     └─ XFS     100 GiB
         └─ /data
```

AWS modification:

```text
EBS             200 GiB
 └─ partition   100 GiB
     └─ XFS     100 GiB
```

User says:

> I resized EBS but `df -h` still shows 100G!

Because:

```text
Cloud layer increased
but OS layer didn't.
```

After OS expansion:

```text
EBS             200 GiB
 └─ partition   200 GiB
     └─ XFS     200 GiB
```

This will be part of our hands-on lab.

---

# 31. Can EBS Be Made Smaller?

Here's another exam/production point.

EBS Elastic Volumes supports increasing volume size, but it does not provide an in-place shrink operation. AWS's EC2 block-device documentation explicitly notes that an EBS volume's size cannot be decreased through modification. ([AWS Documentation][16])

So:

```text
100 GiB
   ↓
200 GiB
```

supported.

But:

```text
200 GiB
   ↓
100 GiB
```

not as a simple resize.

Typical migration idea:

```text
old 200 GiB
    ↓
create smaller destination
    ↓
filesystem/data migration
    ↓
validate
    ↓
switch
```

This is why careless oversized disks can become an operational/cost nuisance.

---

# 32. EBS Snapshots

Now one of the most important EBS features:

```text
SNAPSHOT
```

An EBS snapshot is a point-in-time backup of an EBS volume.

AWS snapshots are **incremental**: after the first snapshot, subsequent snapshots store changed blocks rather than duplicating the entire volume every time. ([AWS Documentation][17])

Conceptually:

```text
Volume

Blocks:
A B C D E


Snapshot 1
A B C D E


Volume changes:
A B X D Y


Snapshot 2
    X   Y
```

You think of it logically as:

```text
complete restore point
```

even though AWS handles incremental block storage underneath.

---

# 33. Snapshot → New Volume

Recovery:

```text
EBS Volume
    │
    ▼
Snapshot
    │
    ▼
New EBS Volume
    │
    ▼
EC2
```

AWS allows a new volume to be created from a snapshot, producing a copy of the captured block data. ([AWS Documentation][9])

This becomes useful for:

```text
backup
recovery
migration
environment cloning
testing
AMI creation
disaster-recovery workflows
```

---

# 34. Snapshot Encryption

Amazon EBS integrates encryption with AWS KMS. EBS encryption covers data at rest as well as data moving between the EC2 instance and its EBS storage; encrypted snapshots inherit encryption from encrypted source volumes. ([AWS Documentation][18])

Conceptually:

```text
EC2
 │
 │ encrypted storage traffic
 ▼
Encrypted EBS
 │
 ▼
Encrypted Snapshot
       │
       ▼
      KMS
```

AWS also lets an account enable **EBS encryption by default** for newly created EBS volumes and snapshot copies in a Region; it doesn't retroactively encrypt existing resources. ([AWS Documentation][19])

---

# 35. Snapshot Is Not the Same as Filesystem Backup Consistency

Very important production idea.

Suppose your database is actively changing:

```text
write A
write B
transaction pending
cache not flushed
filesystem changing
```

and you take a block-level snapshot.

You need to think about:

```text
crash consistency
vs
application consistency
```

A block-storage snapshot does not automatically understand the semantic transaction state of every application running on it.

For important databases, architecture may involve:

```text
application/database-native backup
+
filesystem/application quiescing
+
EBS snapshots
```

depending on recovery requirements.

We'll cover this in snapshot consistency and DLM later in Lesson 25.

---

# 36. Multi-Attach — Advanced EBS

Normally think:

```text
One EBS
   │
   ▼
One EC2
```

But EBS has an advanced feature:

```text
Multi-Attach
```

AWS supports Multi-Attach for `io1` and `io2` Provisioned IOPS volumes, allowing one eligible volume to be attached to multiple EC2 instances **in the same Availability Zone**. ([AWS Documentation][20])

Conceptually:

```text
        EBS io2
       /   |   \
      /    |    \
   EC2-A EC2-B EC2-C

same Availability Zone
```

But this is not:

```text
"Free EFS!"
```

---

# 37. Critical Multi-Attach Warning

When multiple servers can write to one block device:

```text
EC2-A ───write───┐
                 │
                 ▼
               EBS
                 ▲
                 │
EC2-B ───write───┘
```

Who coordinates writes?

EBS doesn't magically turn a normal ext4 filesystem into a safe distributed filesystem.

The application/filesystem architecture must support concurrent access and write coordination. AWS explicitly warns that applications using Multi-Attach must manage write ordering; `io2` Multi-Attach also supports NVMe reservations for storage fencing. ([AWS Documentation][20])

So never think:

```text
Attach one io2 volume
to 5 web servers

mount ext4 everywhere

DONE
```

That can lead to corruption.

---

# 38. EBS vs EFS Preview

We'll cover EFS properly later, but establish this now.

```text
                  Shared storage needed?
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
          EBS                      EFS
             │                       │
         Block storage           File storage
             │                       │
       Usually server-disk     Shared filesystem
          mental model          mental model
```

So if someone says:

> I need 50 Linux EC2 web servers to mount the same shared `/uploads` filesystem.

Your first instinct shouldn't be:

```text
EBS Multi-Attach!
```

You should investigate:

```text
EFS
S3
application architecture
```

depending on access requirements.

Multi-Attach is a specialized block-storage capability, not the general answer to shared files.

---

# 39. Production Scenario

Imagine:

```text
Node.js application
        │
        ▼
EC2
        │
        ├── /
        │    20 GiB gp3
        │
        └── OS
        │
        └── /data
             200 GiB gp3
             application working data
```

Requirements:

```text
fast normal SSD
moderate database workload
snapshots every day
encrypted storage
volume may need resizing
```

A sensible starting point could be:

```text
gp3
+
KMS encryption
+
snapshot policy
+
CloudWatch monitoring
+
filesystem capacity alerts
```

If later evidence shows:

```text
IOPS demand extremely high
+
latency requirements strict
```

then evaluate:

```text
io2
```

That's capacity planning based on evidence.

---

# 40. Production Troubleshooting Example

User reports:

> My API response time jumped from 150 ms to 3 seconds.

CPU:

```text
25%
```

Memory:

```text
50%
```

Network:

```text
normal
```

Beginner response:

> Increase EC2 size.

Production engineer thinks:

```text
Application latency
      │
      ├── CPU?
      ├── memory?
      ├── network?
      ├── database?
      └── STORAGE?
              │
              ├── IOPS saturation?
              ├── throughput?
              ├── queue depth?
              ├── latency?
              └── instance EBS bandwidth?
```

Remember:

> A fast EBS volume attached to an EC2 type with insufficient EBS bandwidth can still result in a storage bottleneck.

AWS documents EBS-optimized instance performance separately because both the **volume capability** and the **EC2 instance's EBS capability** matter. ([AWS Documentation][21])

---

# 41. Storage Bottleneck Mental Model

Your application path is really:

```text
Application
     │
     ▼
Filesystem
     │
     ▼
Linux block layer
     │
     ▼
EC2 EBS interface
     │
     ▼
EBS volume
```

Performance is limited by the weakest relevant layer.

Think:

```text
EBS can do 10 GB/s
but
EC2 can only send 1 GB/s

effective result
≠ 10 GB/s
```

This principle will matter greatly in our upcoming storage-performance lesson.

---

# 42. Certification Scenarios

### Scenario A

> Database needs persistent block storage attached to EC2.

Think:

```text
EBS
```

### Scenario B

> Temporary high-performance scratch space; loss on instance replacement is acceptable.

Think:

```text
Instance Store
```

### Scenario C

> Large sequential frequently accessed workload.

Think:

```text
st1
```

### Scenario D

> Large sequential infrequently accessed block workload.

Think:

```text
sc1
```

### Scenario E

> Normal SSD workload, customizable IOPS/throughput.

Think:

```text
gp3
```

### Scenario F

> Demanding transactional workload requiring high provisioned IOPS.

Think:

```text
io2
```

### Scenario G

> EBS exists in `ap-south-1a`, EC2 exists in `ap-south-1b`.

Direct attach?

```text
NO
```

EBS volumes attach only to EC2 instances in the same AZ. ([AWS Documentation][5])

---

# 43. Never-Forget EBS Map

```text
                         STORAGE
                            │
            ┌───────────────┼─────────────────┐
            │               │                 │
            ▼               ▼                 ▼
           EBS        Instance Store          EFS
            │               │
            ▼               ▼
       Persistent        Temporary
       block storage     local block
            │
            ▼
       Same-AZ EC2
            │
      ┌─────┼───────────────┐
      │     │               │
      ▼     ▼               ▼
     gp3   io2           HDD types
                         │
                    ┌────┴────┐
                    ▼         ▼
                   st1       sc1

EBS
 │
 ├── snapshots
 ├── KMS encryption
 ├── Elastic Volumes
 ├── performance tuning
 └── optional specialized Multi-Attach
```

---

# The 10 Things I Want You to Retain

```text
1. EC2 = computer.
   EBS = disk.

2. EBS = block storage.

3. EBS is Availability-Zone scoped.

4. EC2 and attached EBS normally need the same AZ.

5. EBS survives stop/start.

6. Termination behavior depends on DeleteOnTermination.

7. Instance Store is temporary.

8. gp3 is the general-purpose SSD starting point.

9. IOPS, throughput and latency are different.

10. Snapshot = point-in-time incremental EBS backup.
```

And the most important design habit:

```text
Never select storage from its name.

Start from:

Access pattern
    ↓
Durability
    ↓
IOPS
    ↓
Throughput
    ↓
Latency
    ↓
Capacity
    ↓
Availability
    ↓
Cost
```

---

# Next — Lesson 25 Part 2

Next we go much deeper into the part that causes real production incidents:

```text
EBS PERFORMANCE ENGINEERING
          │
          ├── IOPS mathematics
          ├── throughput mathematics
          ├── I/O size
          ├── latency
          ├── queue depth
          ├── gp2 burst credits
          ├── gp2 vs gp3 migration
          ├── gp3 sizing
          ├── io2 / Block Express
          ├── EC2 EBS bandwidth limits
          ├── EBS-optimized instances
          ├── CloudWatch EBS metrics
          ├── Linux iostat / ioping / fio
          ├── diagnosing disk bottlenecks
          ├── online resize
          ├── growpart
          ├── resize2fs / xfs_growfs
          └── real production troubleshooting lab
```

That is where you'll learn to answer questions like:

> **“My database is slow — should I increase EC2, IOPS, throughput, disk size, or change the EBS type?”**

Instead of guessing, you'll be able to calculate and diagnose it.

[1]: https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html?utm_source=chatgpt.com "What is Amazon Elastic Block Store? - Amazon EBS"
[2]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/RootDeviceStorage.html?utm_source=chatgpt.com "Root volumes for your Amazon EC2 instances"
[3]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html?utm_source=chatgpt.com "Instance store temporary block storage for EC2 instances"
[4]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-store-lifetime.html?utm_source=chatgpt.com "Data persistence for Amazon EC2 instance store volumes"
[5]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-attaching-volume.html?utm_source=chatgpt.com "Attach an Amazon EBS volume to an Amazon EC2 instance"
[6]: https://docs.aws.amazon.com/ebs/latest/userguide/EBSFeatures.html?utm_source=chatgpt.com "Features and benefits of Amazon EBS volumes"
[7]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/block-device-mapping-concepts.html?utm_source=chatgpt.com "Block device mappings for volumes on Amazon EC2 ..."
[8]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-root-volume-delete-on-termination.html?utm_source=chatgpt.com "Keep an Amazon EBS root volume after an Amazon EC2 ..."
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-creating-volume.html?utm_source=chatgpt.com "Create an Amazon EBS volume"
[10]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html?utm_source=chatgpt.com "Make an Amazon EBS volume available for use"
[11]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes.html?utm_source=chatgpt.com "Amazon EBS volumes"
[12]: https://docs.aws.amazon.com/ebs/latest/userguide/hdd-vols.html?utm_source=chatgpt.com "Amazon EBS Throughput Optimized HDD and Cold HDD ..."
[13]: https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html?utm_source=chatgpt.com "Amazon EBS General Purpose SSD volumes"
[14]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html?utm_source=chatgpt.com "Amazon EBS volume types"
[15]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-modify-volume.html?utm_source=chatgpt.com "Modify an Amazon EBS volume using Elastic ..."
[16]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-block-device-mapping.html?utm_source=chatgpt.com "Add block device mappings to Amazon EC2 instance"
[17]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-snapshots.html?utm_source=chatgpt.com "Amazon EBS snapshots"
[18]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html?utm_source=chatgpt.com "Amazon EBS encryption"
[19]: https://docs.aws.amazon.com/ebs/latest/userguide/encryption-by-default.html?utm_source=chatgpt.com "Enable Amazon EBS encryption by default"
[20]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes-multi.html?utm_source=chatgpt.com "Attach an EBS volume to multiple EC2 instances using ..."
[21]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-optimized.html?utm_source=chatgpt.com "Amazon EBS-optimized instance types"
