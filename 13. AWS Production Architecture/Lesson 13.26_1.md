# AWS Masterclass — Lesson 26

# Amazon EFS & Shared File Storage

We have finished the **single-server persistent disk** problem:

```text
EC2
 │
 ▼
EBS
```

Now imagine our Auto Scaling architecture from Lesson 24:

```text
                    ALB
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
        EC2-A      EC2-B      EC2-C
          │          │          │
        /data      /data      /data
```

Suppose a customer uploads:

```text
profile.jpg
```

to:

```text
EC2-A:/data/uploads/profile.jpg
```

The next request goes through the ALB to:

```text
EC2-B
```

EC2-B asks:

```text
Where is profile.jpg?
```

It only exists on EC2-A.

We now have the **shared-storage problem**.

The AWS service designed for this type of Linux shared-file workload is:

# Amazon Elastic File System — EFS

Amazon EFS is a managed NFS file system that can be mounted concurrently by large numbers of AWS compute clients including EC2, ECS, EKS, Lambda, and Fargate. It supports NFSv4.1 and NFSv4.0. ([AWS Documentation][1])

---

# 1. EBS vs EFS — The Fundamental Difference

Remember:

```text
EBS
=
block storage


EFS
=
file storage
```

With EBS:

```text
EC2
 │
 ▼
Block Device
 │
 ▼
Filesystem
 │
 ▼
/data
```

Your Linux machine creates/manages the filesystem.

With EFS:

```text
              Amazon EFS
             Shared File System
                    │
          ┌─────────┼─────────┐
          │         │         │
          ▼         ▼         ▼
        EC2-A     EC2-B     EC2-C
          │         │         │
        /shared   /shared   /shared
```

The clients mount a managed shared filesystem over NFS. EFS provides file-system semantics including directories, POSIX permissions, locking, and strong consistency. ([AWS Documentation][1])

---

# 2. The Laptop Analogy

Think of EBS like:

```text
Your laptop internal SSD
```

and EFS like:

```text
Company network file server
```

For example:

```text
\\company-files\shared
```

in Windows-style thinking, or:

```text
/mnt/shared
```

on Linux.

The major difference is that EFS uses NFS and is designed primarily for Linux-compatible NFS clients; AWS does not support mounting EFS directly from Windows EC2 as a normal Windows file share. ([AWS Documentation][1])

We'll later learn that Windows-style managed shared storage usually pushes us toward services such as:

```text
Amazon FSx for Windows File Server
```

instead.

---

# 3. Why EFS Matters for Auto Scaling

Recall our ASG principle:

```text
EC2 instances should be disposable.
```

Suppose:

```text
ASG desired = 3
```

Current:

```text
i-001
i-002
i-003
```

Traffic drops:

```text
Desired:
3 → 2
```

Auto Scaling terminates:

```text
i-002
```

If customer files lived only on:

```text
i-002 local disk
```

they may disappear with the instance.

Instead:

```text
                    EFS
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
       instance   instance   instance
```

The EC2 fleet remains replaceable while shared files exist independently of any one application server. EFS is designed for concurrent access from multiple compute clients and can grow automatically as data is added. ([AWS Documentation][1])

---

# 4. Production Architecture

Imagine:

```text
                         Internet
                            │
                            ▼
                        CloudFront
                            │
                            ▼
                           ALB
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
         ap-south-1a    ap-south-1b    ap-south-1c
             │              │              │
           EC2-A          EC2-B          EC2-C
             │              │              │
             └──────────────┼──────────────┘
                            │
                           NFS
                            │
                            ▼
                           EFS
                            │
                     Shared content
```

For **Regional EFS**, AWS stores file-system data redundantly across multiple Availability Zones within the Region. AWS recommends Regional as the default choice for higher resilience. ([AWS Documentation][1])

This is fundamentally different from a single EBS volume:

```text
EBS
=
AZ scoped disk
```

versus:

```text
Regional EFS
=
multi-AZ managed filesystem
```

---

# 5. EFS File System Types

Amazon EFS currently offers two availability/storage-placement models:

```text
Regional
One Zone
```

### Regional

```text
             AWS Region
                 │
     ┌───────────┼───────────┐
     │           │           │
    AZ-A        AZ-B        AZ-C
      \           |          /
       \          |         /
          Regional EFS
```

Regional EFS stores data redundantly across multiple geographically separated Availability Zones in the Region and is AWS's recommended option for most workloads. ([AWS Documentation][1])

### One Zone

```text
AWS Region
   │
   └── AZ-A
         │
         ▼
       EFS
```

One Zone keeps the data within a single Availability Zone. It can be appropriate when lower cost matters and the workload can tolerate or independently protect against an AZ-wide failure. AWS warns that complete loss or damage of that AZ could result in loss of One Zone file-system data. ([AWS Documentation][1])

---

# 6. Never Confuse These Terms

```text
Regional EFS
≠
mount target in every region
```

It means:

```text
data durability/availability
spans multiple AZs
inside ONE AWS Region
```

EFS is still a regional service resource.

---

# 7. What Is NFS?

NFS means:

```text
Network File System
```

Instead of a disk attached through a local block-storage interface:

```text
Application
   │
   ▼
local filesystem
   │
   ▼
disk
```

you have:

```text
Application
   │
   ▼
Linux filesystem calls
   │
   ▼
NFS client
   │
   ▼
Network
   │
   ▼
EFS
```

EFS currently supports:

```text
NFSv4.1
NFSv4.0
```

and does not support NFSv2 or NFSv3. ([AWS Documentation][1])

For most modern Linux workloads:

```text
NFSv4.1
```

is the mental default.

---

# 8. EFS Mount Target

Here's the most important EFS networking concept.

Your EC2 does not simply send NFS traffic toward some abstract EFS service.

Inside your VPC, EFS creates:

# Mount Targets

A mount target has:

```text
Subnet
IP address
Elastic network interface
Security Groups
Availability Zone
```

and provides the network endpoint used by clients to access the EFS filesystem. ([AWS Documentation][2])

Think:

```text
EFS
 │
 │ logical filesystem
 │
 ├──── Mount Target AZ-A
 │       └── private IP
 │
 ├──── Mount Target AZ-B
 │       └── private IP
 │
 └──── Mount Target AZ-C
         └── private IP
```

---

# 9. Why Mount Targets Exist

Suppose:

```text
EC2-A
10.0.11.25
AZ-A
```

needs EFS.

Its traffic goes toward the EFS mount target:

```text
Mount Target AZ-A
10.0.11.x
```

Conceptually:

```text
EC2-A
   │
   │ TCP 2049
   ▼
EFS Mount Target
   │
   ▼
Shared EFS filesystem
```

AWS recommends accessing a Regional EFS file system through the mount target in the same Availability Zone when possible for performance and cross-AZ data-transfer considerations. ([AWS Documentation][3])

---

# 10. One Mount Target per AZ

Suppose AZ-A contains:

```text
private-subnet-a1
private-subnet-a2
private-subnet-a3
```

Do you create:

```text
3 mount targets?
```

No.

For one EFS file system in one VPC, you can create **one mount target per Availability Zone**. Instances in other subnets in that same AZ can use that AZ's mount target. ([AWS Documentation][4])

Architecture:

```text
AZ-A

Subnet A1
   │
 EC2
   │

Subnet A2
   │
 EC2
   │

Subnet A3
   │
 EC2
   │

      \    |    /
       \   |   /
        Mount Target
```

---

# 11. Regional Production Layout

For our standard two-AZ VPC:

```text
                  VPC
                   │
        ┌──────────┴──────────┐
        │                     │
      AZ-A                  AZ-B
        │                     │
 Private Subnet A       Private Subnet B
        │                     │
      EC2-A                  EC2-B
        │                     │
        ▼                     ▼
 Mount Target A        Mount Target B
        \                     /
         \                   /
              Amazon EFS
```

For a Regional file system, you can create a mount target in each AZ. AWS recommends this pattern so clients use local-AZ connectivity to EFS. ([AWS Documentation][4])

---

# 12. One Zone EFS Is Different

If you create:

```text
EFS One Zone
```

in:

```text
ap-south-1a
```

you get only a mount target in that same AZ; additional mount targets in other AZs aren't supported for a One Zone file system. ([AWS Documentation][5])

So:

```text
Regional EFS
→ mount target per AZ possible

One Zone EFS
→ one mount target
```

---

# 13. EFS Security Groups

Now connect EFS to our previous networking lessons.

EFS NFS traffic uses:

```text
TCP 2049
```

For production, use two security groups:

```text
App-SG
EFS-SG
```

Architecture:

```text
EC2
App-SG
   │
   │ TCP 2049
   ▼
EFS Mount Target
EFS-SG
```

The EFS mount-target security group must allow inbound TCP/2049 from the client EC2 security group; the client must also be allowed outbound TCP/2049 to the mount target. ([AWS Documentation][6])

---

# 14. Correct Security Rule

### App Security Group

```text
Outbound:

TCP 2049
Destination: EFS-SG
```

### EFS Security Group

```text
Inbound:

TCP 2049
Source: App-SG
```

This is much better than:

```text
EFS SG inbound:

2049
0.0.0.0/0
```

AWS recommends minimal security-group permissions for production EFS deployments. ([AWS Documentation][6])

---

# 15. EFS Is Not Public Internet Storage

EFS mount targets do not receive public IP addresses. NFS clients reach them through VPC connectivity, connected VPCs, or on-premises networks connected through mechanisms such as VPN or Direct Connect. ([AWS Documentation][6])

So don't picture:

```text
Laptop at home
   │
Internet
   ▼
efs.amazonaws.com
```

as a normal public NFS architecture.

Think:

```text
private network connectivity
```

---

# 16. First Mount Example

On Amazon Linux:

```bash
sudo dnf install -y amazon-efs-utils
```

Create mount directory:

```bash
sudo mkdir -p /shared
```

Then with the EFS mount helper:

```bash
sudo mount -t efs fs-12345678:/ /shared
```

A TLS-encrypted mount would use:

```bash
sudo mount -t efs -o tls fs-12345678:/ /shared
```

EFS encryption in transit is enabled at mount time, and the EFS mount helper supports TLS mounting. ([AWS Documentation][1])

Verify:

```bash
df -hT
```

and:

```bash
mount | grep efs
```

---

# 17. Now the Magic of Shared Storage

On EC2-A:

```bash
echo "Created from EC2-A" \
  | sudo tee /shared/test.txt
```

On EC2-B:

```bash
cat /shared/test.txt
```

Expected:

```text
Created from EC2-A
```

Then EC2-C can read the same file.

That's the central EFS concept:

```text
One shared namespace
seen by many clients.
```

---

# 18. Example: Auto Scaling Web Tier

Suppose:

```text
WordPress
```

stores uploaded media under something like:

```text
wp-content/uploads/
```

If each Auto Scaling instance uses only local storage:

```text
EC2-A
uploads:
cat.jpg

EC2-B
uploads:
dog.jpg
```

Requests become inconsistent.

Instead:

```text
                   EFS
                    │
             /wordpress/uploads
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
     WordPress   WordPress   WordPress
       EC2-A       EC2-B       EC2-C
```

All instances see the same shared media.

---

# 19. But Should Everything Go on EFS?

No.

Don't create:

```text
/
everything
→ EFS
```

simply because EFS is shared.

A better production architecture might be:

```text
EC2 root filesystem
        │
        ▼
EBS

Application package
        │
        ▼
AMI / container image

Shared application files
        │
        ▼
EFS

Object/media architecture
        │
        ▼
possibly S3

Database
        │
        ▼
RDS/Aurora/etc.
```

The storage service should match the access pattern.

---

# 20. EFS Automatically Scales Capacity

One major operational difference from EBS:

With EBS:

```text
100 GiB
```

eventually:

```text
95 GiB used
```

you may need:

```text
ModifyVolume
growpart
xfs_growfs
```

With EFS, file-system storage capacity grows and shrinks automatically as files are added or removed; you don't provision a fixed filesystem size up front. AWS describes EFS as capable of scaling to petabyte-scale capacity. ([AWS Documentation][1])

Mental model:

```text
EBS:
choose disk size


EFS:
use filesystem
capacity scales automatically
```

---

# 21. But Automatic Capacity ≠ Unlimited Performance

Very important.

EFS can automatically scale storage capacity.

That does **not** mean:

```text
infinite throughput
infinite IOPS
zero latency
```

EFS performance depends on:

```text
File system type
Performance mode
Throughput mode
Storage class
Workload access pattern
Client parallelism
```

AWS documents latency, IOPS, and throughput as separate EFS performance dimensions. ([AWS Documentation][7])

This parallels what we learned with EBS:

```text
Capacity
≠
Performance
```

---

# 22. EFS Performance Modes

EFS currently has:

```text
General Purpose
Max I/O
```

But there is a very important modern recommendation.

AWS now recommends:

```text
General Purpose
```

for all file systems because Max I/O is a previous-generation performance mode with higher per-operation latency. One Zone also supports General Purpose only, and Elastic throughput is not compatible with Max I/O. ([AWS Documentation][7])

So for modern designs:

```text
General Purpose
```

should be your default mental answer unless you are dealing with an older existing filesystem or a specific legacy scenario.

---

# 23. General Purpose Performance Mode

General Purpose is designed for latency-sensitive workloads such as:

```text
web serving
content-management systems
home directories
general file serving
```

and provides lower per-operation latency than Max I/O. ([AWS Documentation][7])

Think:

```text
modern normal EFS
=
General Purpose
```

---

# 24. EFS Throughput Modes

Do not confuse:

```text
Performance mode
```

with:

```text
Throughput mode
```

Performance mode is:

```text
General Purpose / Max I/O
```

Throughput mode is currently:

```text
Elastic
Provisioned
Bursting
```

AWS recommends Elastic throughput as the default for workloads with spiky or unpredictable throughput needs. ([AWS Documentation][7])

---

# 25. Elastic Throughput

Elastic throughput is the easiest modern mental model:

```text
Workload quiet
      ↓
low throughput usage

Traffic spike
      ↓
EFS automatically scales throughput

Traffic drops
      ↓
throughput scales down
```

You don't provision a fixed throughput capacity. You pay based on metadata and data read/written under the Elastic model, and burst credits are not used. ([AWS Documentation][7])

AWS recommends Elastic when workloads are unpredictable or when average throughput is small relative to occasional peaks. ([AWS Documentation][7])

---

# 26. Elastic Throughput Example

Imagine:

```text
03:00
5 MiB/s

10:00
50 MiB/s

12:00
500 MiB/s

17:00
100 MiB/s

02:00
2 MiB/s
```

Elastic throughput is designed for exactly this:

```text
unpredictable
bursty
variable
```

You don't want to guess:

```text
"Should I provision 600 MiB/s forever?"
```

if high demand only exists briefly.

---

# 27. Provisioned Throughput

With Provisioned throughput:

```text
YOU specify required throughput
```

independently of filesystem size.

Conceptually:

```text
EFS size:
100 GiB

Required throughput:
400 MiB/s

Provision:
400 MiB/s
```

AWS recommends Provisioned when throughput needs are known and relatively sustained rather than highly spiky. ([AWS Documentation][7])

This parallels:

```text
gp3 provisioned performance
```

in our EBS lesson.

---

# 28. Bursting Throughput

Bursting is the older size-linked EFS throughput model.

Think:

```text
More data stored in EFS Standard
        ↓
higher baseline throughput
```

AWS currently defines Bursting baseline throughput at 50 KiB/s per GiB of data stored in Standard, with burst credits accumulated below baseline and spent above baseline. ([AWS Documentation][7])

This is similar conceptually to what we saw with:

```text
gp2 burst credits
```

although the exact system is different.

---

# 29. EFS Burst Credits

Suppose a Bursting file system has:

```text
100 GiB
```

in Standard.

AWS's current example gives it approximately:

```text
5 MiB/s baseline
```

and unused baseline performance accumulates credits that can later support higher burst throughput. ([AWS Documentation][7])

So:

```text
quiet filesystem
      ↓
build credits

spike
      ↓
consume credits

credits depleted
      ↓
performance returns toward baseline
```

---

# 30. Classic Bursting Performance Incident

Application normally:

```text
FAST
```

during a sustained import:

```text
FAST
FAST
FAST
...
SLOW
```

CloudWatch:

```text
BurstCreditBalance
      ↓
      ↓
      ↓
      0
```

The storage itself didn't suddenly break.

The workload consumed the credits supporting its burst rate. EFS exposes `BurstCreditBalance` for Bursting throughput monitoring. ([AWS Documentation][8])

For a consistently throughput-constrained workload, AWS recommends moving from Bursting to Elastic or Provisioned throughput rather than operating perpetually against exhausted credits. ([AWS Documentation][7])

---

# 31. Never-Forget Throughput Selection

```text
Unpredictable/spiky
        │
        ▼
     Elastic
```

```text
Known sustained requirement
        │
        ▼
    Provisioned
```

```text
Want performance linked to
amount of Standard data
        │
        ▼
     Bursting
```

For a new general-purpose architecture:

```text
General Purpose
+
Elastic
```

is currently AWS's recommended default combination for most workloads. ([AWS Documentation][1])

---

# 32. EFS Storage Classes

Now capacity cost optimization.

Current EFS storage classes include:

```text
Standard
Infrequent Access (IA)
Archive
```

Standard is SSD-backed and provides the lowest latency for frequently accessed files. IA and Archive provide lower-cost storage for files accessed less frequently but have higher first-byte latency. ([AWS Documentation][7])

Mental model:

```text
HOT
 │
 ▼
Standard

WARM/COLD
 │
 ▼
IA

VERY COLD
 │
 ▼
Archive
```

---

# 33. EFS Standard

Use for:

```text
frequently accessed
latency-sensitive
active files
```

Examples:

```text
active website content
home directories
application config/data
shared project files
```

AWS currently describes Standard as SSD-based storage with the lowest first-byte latency among EFS storage classes. ([AWS Documentation][7])

---

# 34. EFS Infrequent Access — IA

Imagine:

```text
report-2025.pdf
```

hasn't been touched for months.

Keeping it in the most performance-oriented storage tier may be wasteful.

Lifecycle Management can move infrequently accessed files into:

```text
EFS IA
```

which is optimized for data accessed only a few times per quarter. ([AWS Documentation][9])

---

# 35. EFS Archive

Now imagine:

```text
old project archives
historical records
rare compliance files
```

that are accessed only a few times per year or less.

These can be candidates for:

```text
EFS Archive
```

through lifecycle management. ([AWS Documentation][9])

---

# 36. Lifecycle Management

You don't manually execute:

```text
mv file Standard → IA
```

EFS Lifecycle Management automates tier transitions based on the file's internal last-access tracking. ([AWS Documentation][9])

Typical conceptual configuration:

```text
Standard
   │
30 days not accessed
   ▼
IA
   │
90 days not accessed
   ▼
Archive
```

AWS's current defaults for enabled lifecycle policies are 30 days before IA and 90 days before Archive, though lifecycle configuration is adjustable. ([AWS Documentation][9])

---

# 37. Files Can Return to Standard

You can configure:

```text
Transition into Standard
```

so when a file from IA or Archive is accessed, it moves back to Standard. This is useful for workloads where a cold file becomes active again and future low-latency accesses matter. ([AWS Documentation][9])

Architecture:

```text
Standard
   │
inactive
   ▼
IA
   │
inactive longer
   ▼
Archive
   │
accessed
   ▼
Standard
```

depending on lifecycle policy.

---

# 38. Metadata Stays in Standard

An interesting detail:

Even when a file's contents move into IA or Archive, EFS keeps file metadata such as:

```text
names
ownership
directory structure
```

in Standard so namespace/metadata operations retain consistent behavior. ([AWS Documentation][9])

This means commands like directory listings involve metadata separately from accessing cold file contents.

---

# 39. POSIX Permissions Still Matter

Because EFS is a Linux/NFS filesystem, permissions remain important.

Example:

```text
drwxrwx--- appuser appgroup /shared/uploads
```

and users still have:

```text
UID
GID
```

EFS supports POSIX permission controls, so ordinary Linux ownership and permission mistakes can absolutely cause EFS application failures. ([AWS Documentation][1])

For example:

```text
mount succeeds
```

but:

```text
touch /shared/test
Permission denied
```

may be:

```text
POSIX permission problem
```

rather than:

```text
security-group problem
```

---

# 40. The Four EFS Access Layers

When EFS doesn't work, think in layers:

```text
Layer 1
NETWORK
   │
   ├── VPC
   ├── routes
   ├── mount target
   ├── SG
   └── TCP 2049

Layer 2
MOUNT
   │
   ├── NFS client
   ├── amazon-efs-utils
   ├── DNS
   └── TLS

Layer 3
AUTHORIZATION
   │
   ├── IAM
   ├── file-system policy
   └── access point

Layer 4
FILESYSTEM
   │
   ├── UID/GID
   ├── owner
   └── POSIX permissions
```

This troubleshooting model will save you a lot of confusion.

---

# 41. Mount Success Does Not Mean Write Permission

Suppose:

```bash
mount | grep efs
```

shows:

```text
mounted successfully
```

but:

```bash
touch /shared/test
```

returns:

```text
Permission denied
```

Do not start editing security groups.

If the filesystem mounted, NFS networking is already functioning.

Investigate:

```text
ls -ld /shared
id
UID
GID
ownership
mode bits
access point identity
```

This is the distinction between:

```text
network access
```

and:

```text
filesystem authorization
```

---

# 42. EFS Access Points

Now one of the best EFS production features:

# Access Points

An EFS Access Point provides an application-specific entry point into a filesystem. It can enforce:

```text
specific root directory

POSIX UID

POSIX GID
```

for requests made through that access point. ([AWS Documentation][10])

Imagine one EFS:

```text
/
├── app-a
├── app-b
└── app-c
```

Instead of letting every application see:

```text
/
```

create:

```text
AccessPoint-A
root = /app-a

AccessPoint-B
root = /app-b

AccessPoint-C
root = /app-c
```

---

# 43. Access Point Mental Model

Without Access Point:

```text
Application
    │
    ▼
EFS /
 ├── payroll
 ├── hr
 ├── app
 └── logs
```

With:

```text
Application A
     │
     ▼
Access Point A
     │
     ▼
/app
```

The application sees its assigned root rather than necessarily operating across the entire filesystem. EFS Access Points can enforce both a root directory and POSIX identity. ([AWS Documentation][10])

---

# 44. Container Example

Suppose:

```text
ECS App A
ECS App B
```

share one EFS filesystem.

You might configure:

```text
EFS
/
├── app-a-data
└── app-b-data
```

Then:

```text
ECS App A
   │
   ▼
Access Point A
   │
   ▼
/app-a-data
```

and:

```text
ECS App B
   │
   ▼
Access Point B
   │
   ▼
/app-b-data
```

IAM policies and access points can be combined to restrict individual ECS applications to specific datasets. ([AWS Documentation][11])

---

# 45. Mount Through an Access Point

Example:

```bash
sudo mount \
  -t efs \
  -o tls,iam,accesspoint=fsap-0123456789abcdef0 \
  fs-0123456789abcdef0: \
  /shared
```

Using an access point requires the EFS mount helper, and access-point mounts use TLS. IAM authorization can also be included with the `iam` mount option. ([AWS Documentation][10])

---

# 46. Mount Target vs Access Point

This is an exam/interview trap.

### Mount Target

```text
NETWORK
```

It answers:

> How does my VPC reach EFS?

### Access Point

```text
APPLICATION ACCESS
```

It answers:

> What directory and identity should this application use?

Never confuse:

```text
Mount Target
=
network endpoint
```

with:

```text
Access Point
=
application-specific filesystem entry
```

AWS explicitly states that mount targets provide network connectivity while access points provide application-specific access control/entry points. ([AWS Documentation][10])

---

# 47. Security Groups Attach to Mount Targets

Not Access Points.

Architecture:

```text
                    EFS
                     │
         ┌───────────┼───────────┐
         │                       │
   Access Point A          Access Point B

               NETWORK
                  │
             Mount Target
                  │
                  ▼
                 SG
```

Security groups apply at the mount-target layer. ([AWS Documentation][10])

So you don't create:

```text
AccessPoint-A-SG
AccessPoint-B-SG
```

as an EFS access-point feature.

---

# 48. IAM Authorization for EFS

This is where EFS gets more sophisticated than plain traditional NFS.

Normally NFS relies heavily on:

```text
network access
+
UID/GID
+
POSIX permissions
```

EFS can also use:

```text
AWS IAM
```

for client authorization.

To use IAM authorization for NFS clients, AWS requires using the EFS mount helper. ([AWS Documentation][12])

---

# 49. IAM + EFS Mental Model

```text
EC2 Instance Role
      │
      ▼
IAM Policy
      │
      ▼
EFS authorization
      │
      ▼
Access Point
      │
      ▼
POSIX permissions
```

This gives multiple security layers:

```text
NETWORK
+
AWS IDENTITY
+
FILESYSTEM IDENTITY
```

---

# 50. Example IAM Permissions

Important EFS client actions include concepts such as:

```text
elasticfilesystem:ClientMount
elasticfilesystem:ClientWrite
elasticfilesystem:ClientRootAccess
```

IAM/file-system policies can restrict which clients may mount or write to a filesystem. Access-point-specific policies can additionally enforce use of a particular Access Point through the `elasticfilesystem:AccessPointArn` condition key. ([AWS Documentation][13])

Mental model:

```text
ClientMount
=
can mount


ClientWrite
=
can write


ClientRootAccess
=
root-level client access
```

---

# 51. Encryption

EFS has two encryption dimensions:

```text
Encryption at rest
Encryption in transit
```

### At rest

Configured when the filesystem is created.

```text
files
metadata
   │
   ▼
encrypted
```

### In transit

Configured when mounting:

```bash
-o tls
```

AWS states that EFS supports encryption at rest for data and metadata and encryption in transit during client mounting. ([AWS Documentation][1])

---

# 52. EFS + Auto Scaling Production Pattern

Now combine Lessons 24, 25, and 26.

```text
                       Route 53
                           │
                           ▼
                      CloudFront
                           │
                           ▼
                          ALB
                           │
              ┌────────────┴────────────┐
              │                         │
           AZ-A                       AZ-B
              │                         │
          EC2-ASG                    EC2-ASG
              │                         │
              ▼                         ▼
       EFS Mount Target A       EFS Mount Target B
              \                         /
               \                       /
                    Regional EFS
                         │
                         ▼
                  /shared/uploads
```

Each new ASG instance:

```text
launches
   ↓
boots
   ↓
mounts EFS
   ↓
joins ALB
   ↓
sees existing shared files
```

EFS remains independent of the lifecycle of any individual Auto Scaling instance. Regional EFS provides multi-AZ data placement while clients can connect through local-AZ mount targets. ([AWS Documentation][1])

---

# 53. User Data Example

A Launch Template could contain:

```bash
#!/bin/bash
set -euxo pipefail

dnf install -y amazon-efs-utils

mkdir -p /shared

mount \
  -t efs \
  -o tls \
  fs-0123456789abcdef0:/ \
  /shared
```

Then add a persistent `/etc/fstab` entry such as:

```text
fs-0123456789abcdef0:/ /shared efs _netdev,tls 0 0
```

The `_netdev` concept is important because EFS is network storage and should be treated as requiring networking during the mount process.

---

# 54. But Be Careful With ASG Boot

Imagine:

```text
EC2 launches
   ↓
user data tries EFS mount
   ↓
EFS SG wrong
   ↓
mount hangs/fails
   ↓
application never starts
   ↓
ALB health check fails
   ↓
ASG replaces instance
   ↓
new instance has same problem
   ↓
replacement loop
```

Now remember our Lesson 24 troubleshooting chain:

```text
Launch
 ↓
Bootstrap
 ↓
Application
 ↓
Target Group
 ↓
Health
```

EFS can become the failure point inside:

```text
Bootstrap
```

This is why AWS services must be understood as a connected architecture.

---

# 55. EFS Troubleshooting Chain

When:

```text
mount.nfs4:
Connection timed out
```

think:

```text
EC2
 │
 ▼
Can DNS resolve EFS?
 │
 ▼
Mount target exists in VPC?
 │
 ▼
Correct AZ?
 │
 ▼
Security groups?
 │
 ▼
TCP 2049?
 │
 ▼
NACL?
 │
 ▼
Routing/connectivity?
```

AWS requires client connectivity to TCP/2049 on a mount target, and mount target/client security groups are central to that network authorization. ([AWS Documentation][6])

---

# 56. Different Failure: Permission Denied

If:

```text
mount succeeds

but

write fails
```

think:

```text
POSIX UID/GID
directory owner
permission mode
Access Point identity
IAM ClientWrite
file-system policy
```

not:

```text
port 2049
```

because the network path is already working.

---

# 57. Different Failure: DNS Resolution

The EFS mount helper normally uses EFS DNS names to resolve the appropriate mount-target IP. Cross-VPC/account scenarios can require extra DNS/network handling or explicit mount-target resolution. ([AWS Documentation][14])

So:

```text
mount hangs
```

isn't always:

```text
security group.
```

Could also be:

```text
DNS
VPC DNS settings
cross-VPC resolution
routing
```

---

# 58. EFS vs EBS

Now you should distinguish these instantly.

| Requirement                         | Better starting thought |
| ----------------------------------- | ----------------------- |
| EC2 boot disk                       | EBS                     |
| Database block device               | EBS                     |
| One server needs high IOPS disk     | EBS                     |
| Shared Linux filesystem             | EFS                     |
| Hundreds of EC2 need same files     | EFS                     |
| Auto Scaling shared uploads         | EFS                     |
| NFS-based application               | EFS                     |
| Temporary scratch data              | Instance Store may fit  |
| Objects/images accessed through API | S3 may fit              |

The core distinction is that EBS provides block storage to instances while EFS provides a managed NFS filesystem for concurrent shared access. ([AWS Documentation][1])

---

# 59. EFS vs S3

Suppose you store:

```text
photo.jpg
```

### EFS

Application does:

```python
open("/shared/photo.jpg")
```

because EFS behaves as a filesystem.

### S3

Application conceptually does:

```text
GET object
Bucket: images
Key: photo.jpg
```

because S3 is object storage.

Therefore:

```text
Need POSIX/shared filesystem semantics?
→ EFS

Need massively scalable object storage/API model?
→ S3
```

Don't choose EFS merely because you need to store a lot of files.

---

# 60. Interview Scenario

Interviewer:

> Our application runs on an EC2 Auto Scaling group across three AZs. Users upload files, and every instance needs immediate access to the same uploaded content. How would you design storage?

Strong answer:

> I'd decouple the uploaded files from the lifecycle of individual EC2 instances. If the application requires normal shared Linux filesystem semantics, I'd use a Regional Amazon EFS filesystem, create mount targets in the Availability Zones where the ASG runs, and allow NFS TCP/2049 from the application security group to the EFS mount-target security group. I'd mount EFS on every instance during bootstrap, preferably using TLS, and use Access Points and IAM authorization if applications require isolated directories or enforced POSIX identities. I'd then evaluate whether EFS is genuinely required or whether an S3 object-storage design would better fit the application's access pattern. ([AWS Documentation][1])

That demonstrates:

```text
storage
+
networking
+
security
+
Auto Scaling
+
architecture selection
```

rather than just knowing what EFS stands for.

---

# 61. SAA-C03 / DOP-C02 Scenarios

### Scenario 1

```text
100 Linux EC2 instances
need concurrent access
to the same directories.
```

Think:

```text
EFS
```

EFS supports concurrent NFS access from large numbers of compute clients. ([AWS Documentation][15])

---

### Scenario 2

```text
Low-cost filesystem
AZ-level loss is acceptable
or separately protected.
```

Think:

```text
EFS One Zone
```

while understanding the reduced AZ-failure resilience. ([AWS Documentation][1])

---

### Scenario 3

```text
Highly available shared
filesystem across AZs.
```

Think:

```text
Regional EFS
+
mount target per AZ
```

([AWS Documentation][1])

---

### Scenario 4

Mount times out.

Check first:

```text
mount target
+
security groups
+
TCP 2049
+
routing/DNS
```

([AWS Documentation][6])

---

### Scenario 5

Mount works, but application gets:

```text
Permission denied
```

Think:

```text
POSIX permissions
UID/GID
IAM authorization
Access Point
```

([AWS Documentation][10])

---

### Scenario 6

Application needs its own isolated root directory and enforced POSIX identity.

Think:

```text
EFS Access Point
```

([AWS Documentation][10])

---

### Scenario 7

Unpredictable spiky throughput.

Think:

```text
Elastic throughput
```

which AWS currently recommends as the default throughput mode for this workload profile. ([AWS Documentation][7])

---

### Scenario 8

Known sustained throughput requirement.

Think:

```text
Provisioned throughput
```

([AWS Documentation][7])

---

### Scenario 9

Bursting filesystem is repeatedly running out of credits.

Think:

```text
Elastic
or
Provisioned
```

rather than repeatedly living at an exhausted Bursting limit. ([AWS Documentation][7])

---

# 62. Never-Forget Architecture

```text
                           STORAGE
                              │
              ┌───────────────┼─────────────────┐
              │               │                 │
              ▼               ▼                 ▼
             EBS             EFS               S3
              │               │                 │
             Block           File              Object
              │               │                 │
       Server disk      Shared filesystem     API/object
                              │
                              ▼
                             NFS
                              │
                      ┌───────┴────────┐
                      │                │
                 Mount Targets     Access Points
                      │                │
                    Network       App isolation
                      │                │
                   TCP 2049      UID/GID/root dir
                      │
                      ▼
                   Security
                      │
             ┌────────┼────────┐
             ▼        ▼        ▼
            SG       IAM     POSIX
```

---

# 63. Twelve Things to Permanently Remember

```text
1. EBS = block storage.
   EFS = shared file storage.

2. EFS uses NFS.

3. EFS supports NFSv4.1 and v4.0.

4. Regional EFS stores data across multiple AZs.

5. One Zone EFS stores data in one AZ.

6. Mount Target = network endpoint.

7. One mount target per AZ per file system/VPC.

8. EFS uses TCP 2049.

9. Security Groups control network access.

10. POSIX permissions control filesystem access.

11. Access Point = app-specific root + identity.

12. General Purpose + Elastic is the modern default
    starting point for most EFS workloads.
```

([AWS Documentation][1])

And the biggest mental distinction:

```text
Mount Target
=
HOW YOU REACH EFS


Access Point
=
WHAT AN APPLICATION
SEES/USES INSIDE EFS
```

---

# Lesson 26 Progress

We've now established:

```text
✓ EFS mental model
✓ File vs block storage
✓ EFS vs EBS
✓ EFS vs S3
✓ NFS fundamentals
✓ Regional vs One Zone
✓ Mount Targets
✓ Multi-AZ layout
✓ NFS port 2049
✓ Security Groups
✓ shared Auto Scaling storage
✓ Performance modes
✓ General Purpose vs Max I/O
✓ Elastic throughput
✓ Provisioned throughput
✓ Bursting throughput
✓ Burst credits
✓ Standard
✓ IA
✓ Archive
✓ Lifecycle Management
✓ POSIX permissions
✓ EFS Access Points
✓ IAM authorization
✓ encryption at rest/in transit
✓ production troubleshooting mental model
```

# Next — Lesson 26 Part 2

Next we go hands-on and deeper into **EFS production engineering**:

```text
EFS Production Lab
       │
       ├── Build VPC + two AZs
       ├── EC2 in both AZs
       ├── Regional EFS
       ├── mount target per AZ
       ├── EFS security group
       ├── amazon-efs-utils
       ├── TLS mounting
       ├── /etc/fstab + _netdev
       ├── prove shared writes
       ├── EFS Access Point
       ├── IAM ClientMount / ClientWrite
       ├── enforced UID/GID
       ├── Terraform
       ├── Auto Scaling + EFS
       ├── CloudWatch EFS metrics
       ├── PercentIOLimit
       ├── BurstCreditBalance
       ├── throughput troubleshooting
       ├── mount timeout debugging
       ├── stale NFS / dependency behavior
       ├── ECS/EKS integration
       ├── backup with AWS Backup
       ├── EFS replication / DR concepts
       └── EFS vs FSx architecture decisions
```

That next section will make you able to troubleshoot cases like:

> **“EFS mounted on one EC2 but not another.”**

> **“My mount works, but Node.js gets permission denied.”**

> **“My Auto Scaling instances keep failing health checks because EFS isn't mounting.”**

> **“EFS suddenly became slow even though CPU and network look fine.”**

Those are the production scenarios we tackle next.

[1]: https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html "What is Amazon Elastic File System? - Amazon Elastic File System"
[2]: https://docs.aws.amazon.com/efs/latest/ug/how-it-works-implementation.html?utm_source=chatgpt.com "Implementation summary - Amazon Elastic File System"
[3]: https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html?utm_source=chatgpt.com "How Amazon EFS works - Amazon Elastic File System"
[4]: https://docs.aws.amazon.com/efs/latest/ug/accessing-fs.html?utm_source=chatgpt.com "Managing mount targets - Amazon Elastic File System"
[5]: https://docs.aws.amazon.com/efs/latest/ug/mounting-one-zone.html?utm_source=chatgpt.com "Mounting One Zone file systems"
[6]: https://docs.aws.amazon.com/efs/latest/ug/network-access.html "Using VPC security groups - Amazon Elastic File System"
[7]: https://docs.aws.amazon.com/efs/latest/ug/performance.html "Amazon EFS performance specifications - Amazon Elastic File System"
[8]: https://docs.aws.amazon.com/efs/latest/ug/efs-metrics.html?utm_source=chatgpt.com "CloudWatch metrics for Amazon EFS"
[9]: https://docs.aws.amazon.com/efs/latest/ug/lifecycle-management-efs.html "Managing storage lifecycle - Amazon Elastic File System"
[10]: https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html "Working with access points - Amazon Elastic File System"
[11]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html?utm_source=chatgpt.com "Use Amazon EFS volumes with Amazon ECS"
[12]: https://docs.aws.amazon.com/efs/latest/ug/mounting-IAM-option.html?utm_source=chatgpt.com "Mounting with IAM authorization"
[13]: https://docs.aws.amazon.com/efs/latest/ug/iam-access-control-nfs-efs.html?utm_source=chatgpt.com "Using IAM to control access to file systems"
[14]: https://docs.aws.amazon.com/efs/latest/ug/manage-fs-access-vpc-peering.html?utm_source=chatgpt.com "Mounting EFS file systems from another AWS account or VPC"
[15]: https://docs.aws.amazon.com/efs/latest/ug/performance-tips.html?utm_source=chatgpt.com "Amazon EFS performance tips - Amazon Elastic File System"
