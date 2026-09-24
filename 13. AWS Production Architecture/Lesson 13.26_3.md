# AWS Masterclass — Lesson 26 Part 3

# Advanced EFS Operations, Hybrid Access, Containers & Disaster Recovery

We have already built the normal EFS architecture:

```text
ALB
 │
 ├── EC2-A ── Mount Target A ─┐
 │                            │
 └── EC2-B ── Mount Target B ─┤
                              ▼
                        Regional EFS
                              │
                         Access Point
```

Now we need to understand what happens when applications access the **same files concurrently**, when EFS is consumed from another VPC/account or on-premises, and when the primary filesystem or Region becomes unavailable.

---

# 1. EFS Consistency — What Happens When Two Servers Use the Same File?

Suppose:

```text
EC2-A                     EC2-B
  │                         │
  │ write config.json       │
  ▼                         │
             EFS            │
                              │
                              ▼
                       read config.json
```

The important point is that EFS follows NFS consistency semantics. In particular, EFS provides **close-to-open consistency**: after one application closes a modified file, another client that subsequently opens it can observe the updated data. EFS can provide stronger read-after-write behavior for synchronous, non-appending access patterns. ([AWS Documentation][1])

Think:

```text
Writer
 │
 ├── open
 ├── write
 ├── fsync if needed
 └── close
       │
       ▼
      EFS
       │
       ▼
Reader opens file
       │
       ▼
sees current state
```

This works well for normal shared-file workloads, but an application doing sophisticated concurrent writes still needs to understand NFS semantics.

---

# 2. Client Caching Matters

Network filesystems would be painfully inefficient if every operation always required a completely fresh network round trip.

NFS clients therefore cache things such as file data and metadata.

Conceptually:

```text
Application
     │
     ▼
Linux NFS client
     │
     ├── local cache
     │
     └──── network request when required
                │
                ▼
               EFS
```

This means you should **not** build application synchronization logic around the assumption that every process instantly observes every intermediate mutation made by another client.

A safer mental model is:

```text
open
read/write
synchronize when required
close
reopen
```

rather than:

```text
two servers continuously modify
the same bytes independently
and EFS somehow resolves the logic
```

EFS provides storage consistency; it does not replace application-level concurrency control. ([AWS Documentation][1])

---

# 3. EFS File Locking

EFS supports NFSv4 file locking, including byte-range locking. However, those locks are **advisory**, not mandatory. EFS read/write operations do not themselves reject conflicting I/O merely because another process holds an advisory lock. Applications that depend on locks therefore need to cooperate correctly. ([AWS Documentation][1])

Imagine:

```text
              EFS File
           database.lock
             /      \
            /        \
        App-A        App-B

App-A:
"I own lock"

App-B:
must honor lock
```

The operating principle is:

> **Locking only protects you when participating applications respect the locking protocol.**

---

# 4. EFS Is Not a Distributed Database

Suppose two EC2 servers do:

```text
EC2-A:
read counter = 10

EC2-B:
read counter = 10
```

Then both independently write:

```text
11
```

Expected logical result might have been:

```text
12
```

but you could end up with:

```text
11
```

This is an application race condition.

EFS solves:

```text
shared filesystem
```

not:

```text
distributed transaction management
```

For transactional state, use a database or implement correct application-level locking/transactions.

---

# 5. The Many-Small-Files Problem

Compare two workloads.

```text
Workload A

100 files
each 5 GiB
```

versus:

```text
Workload B

20 million files
each 4 KiB
```

They can occupy similar storage sizes while behaving **very differently**.

Workload B generates enormous numbers of:

```text
lookup
open
stat
close
directory traversal
metadata updates
```

operations.

AWS specifically recommends NFSv4.1 for EFS; among other benefits, it performs significantly better than NFSv4.0 for highly parallel small-file reads. ([AWS Documentation][2])

So:

```text
same number of GiB
≠
same filesystem workload
```

This is why we monitored:

```text
MetadataIOBytes
PercentIOLimit
```

instead of only:

```text
MiB/s
```

in Part 2.

---

# 6. Parallelism Can Improve EFS Performance

Imagine copying one huge directory through one single-threaded process:

```text
Process
  │
  ▼
file
  │
file
  │
file
```

You may not fully exercise the filesystem.

Many EFS workloads benefit from parallel access:

```text
Worker 1 ─┐
Worker 2 ─┤
Worker 3 ─┼──▶ EFS
Worker 4 ─┤
Worker N ─┘
```

But this doesn't mean:

```text
more threads = infinitely faster
```

Eventually you encounter constraints such as filesystem I/O limits, throughput limits, client/network capability, or workload serialization. AWS's EFS performance guidance recommends parallelization where the application's access pattern permits it. ([AWS Documentation][2])

---

# 7. Cross-VPC EFS

Now suppose the architecture is:

```text
Application VPC
10.20.0.0/16

EC2
 │
 │
 ▼

      ???

 │
 ▼

Storage VPC
10.30.0.0/16

EFS
```

EFS can be accessed from another connected VPC. AWS supports this with connectivity such as **VPC peering or AWS Transit Gateway**, including scenarios where the VPCs belong to different AWS accounts. ([AWS Documentation][3])

Architecture:

```text
             Application VPC
                  10.20/16
                      │
                     EC2
                      │
                      ▼
               Transit Gateway
                      │
                      ▼
                Storage VPC
                  10.30/16
                      │
                      ▼
                EFS Mount Target
```

---

# 8. Routing Becomes Part of EFS Troubleshooting

Inside one VPC we mostly thought:

```text
SG
DNS
mount target
2049
```

Cross-VPC changes the chain:

```text
EC2
 │
 ▼
client subnet route
 │
 ▼
peering / Transit Gateway
 │
 ▼
storage VPC route
 │
 ▼
mount target
 │
 ▼
EFS security group
 │
 ▼
TCP 2049
```

Therefore:

```text
Connection timed out
```

might now mean:

```text
route table
Transit Gateway route
peering route
NACL
security group
DNS resolution
```

rather than EFS itself.

---

# 9. Cross-VPC DNS Is an Important Detail

Within the normal VPC configuration, the EFS mount helper can resolve the appropriate mount target using EFS DNS.

For a different VPC/account, AWS notes that you may need to determine and resolve the appropriate EFS mount target explicitly rather than assuming ordinary local EFS DNS resolution works exactly the same way. ([AWS Documentation][4])

So your troubleshooting order becomes:

```text
Network connectivity
       ↓
Mount target IP reachable
       ↓
DNS resolution
       ↓
TCP 2049
       ↓
IAM
       ↓
POSIX
```

---

# 10. Centralized Storage VPC Architecture

Large companies sometimes separate infrastructure into VPCs such as:

```text
              AWS Organization

        ┌──────────┼────────────┐
        │          │            │
        ▼          ▼            ▼
       Dev        Prod        Analytics
       VPC         VPC          VPC
        \           |           /
         \          |          /
             Transit Gateway
                    │
                    ▼
               Storage VPC
                    │
                    ▼
                   EFS
```

Whether this architecture is desirable depends on latency, blast radius, cost, network complexity, account ownership, and security requirements. The fact that EFS *can* be accessed across connected VPCs does not mean every environment should centralize all file systems. AWS supports the network connectivity pattern through peering or Transit Gateway. ([AWS Documentation][3])

---

# 11. Cross-Account Access

EFS can also participate in multi-account architectures.

Examples include:

```text
Account A
Application

        │

shared VPC /
peering /
Transit Gateway

        │
        ▼

Account B
EFS
```

AWS supports EFS access from another account through supported networking arrangements, including shared VPC architectures and connected VPCs. ([AWS Documentation][5])

But now we have two independent questions:

```text
Can the traffic reach EFS?

AND

Is that AWS principal authorized?
```

Which means:

```text
Networking
+
IAM/file-system policy
+
POSIX
```

must all agree.

---

# 12. EFS from On-Premises

This is one of the hybrid-cloud use cases you wanted to understand.

Suppose:

```text
On-premises data center
        │
        │
   Direct Connect
        │
        ▼
       AWS VPC
        │
        ▼
   EFS mount target
```

AWS supports mounting EFS from on-premises Linux servers when the data center has private connectivity into the VPC through **AWS Direct Connect or VPN**. ([AWS Documentation][6])

This means EFS can participate in:

```text
migration
hybrid applications
shared datasets
gradual workload movement
```

provided the network and application latency characteristics are suitable.

---

# 13. Hybrid Mount Path

The data path looks roughly like:

```text
On-prem Linux
     │
     │ NFS
     ▼
Corporate network
     │
     ▼
Direct Connect / VPN
     │
     ▼
AWS VPC
     │
     ▼
Mount Target
     │
     ▼
EFS
```

The EFS mount target still lives inside your VPC. Direct Connect or VPN provides the private path from on-premises infrastructure to that VPC. ([AWS Documentation][6])

So again:

```text
EFS isn't suddenly public storage.
```

---

# 14. Migration Scenario

Suppose a company has:

```text
On-prem NFS
20 TB

/application-data
```

and wants to migrate gradually to AWS.

A migration architecture might involve:

```text
On-prem storage
      │
      ▼
 AWS DataSync
      │
      ▼
     EFS
```

AWS DataSync supports EFS as a source or destination and can use IAM/access points when configured appropriately. ([AWS Documentation][7])

This is usually a much better migration tool than writing:

```bash
scp -r /data ...
```

for a major production filesystem migration.

---

# 15. IAM Root Access — A Subtle EFS Security Topic

Normal Linux root has:

```text
UID = 0
GID = 0
```

Traditional NFS environments often use something called:

```text
root squash
```

which prevents remote root from automatically behaving like unrestricted root on the shared filesystem.

By default, EFS behaves like `no_root_squash`: UID 0 can act as root. With IAM authorization, you can remove `elasticfilesystem:ClientRootAccess` and thereby cause root requests to be squashed to a limited identity. ([AWS Documentation][8])

This is important.

---

# 16. `ClientRootAccess`

Remember our EFS client permissions:

```text
ClientMount
ClientWrite
ClientRootAccess
```

Their mental model is:

```text
ClientMount
=
may connect


ClientWrite
=
may modify data


ClientRootAccess
=
may retain root privileges
```

If IAM authorization is in use and `ClientRootAccess` is not allowed, EFS can apply root squashing to that client. ([AWS Documentation][8])

---

# 17. Production Security Pattern

For ordinary application servers:

```text
App Role

ClientMount
ClientWrite
NO ClientRootAccess
```

For tightly controlled administration:

```text
Storage Admin Role

ClientMount
ClientWrite
ClientRootAccess
```

Conceptually:

```text
Application fleet
      │
      ▼
root squashed


Management instance
      │
      ▼
authorized root
```

This follows least privilege instead of granting every application server full remote-root power over shared storage. AWS specifically documents using IAM policies to prevent root access by default while allowing a designated management principal to retain it. ([AWS Documentation][8])

---

# 18. File-System Policy Hardening

The EFS console supports policy controls conceptually equivalent to:

```text
Prevent root access by default
Enforce read-only access by default
Prevent anonymous access
Require encryption in transit
```

These controls become EFS resource-policy statements. ([AWS Documentation][9])

A strong production pattern could therefore require:

```text
IAM authorization
+
TLS
+
specific principal
+
specific Access Point
```

instead of relying solely on:

```text
"Anyone who can reach port 2049"
```

---

# 19. Important Default-Policy Detail

If you do not configure a custom EFS file-system policy, EFS's default policy does not perform IAM client authentication and allows clients that can connect through a mount target to access the filesystem under the traditional NFS/POSIX model. IAM client authorization only becomes part of the decision when you deliberately configure/use it. ([AWS Documentation][10])

That's why:

```text
Security Group only
```

and:

```text
Security Group + IAM
```

are different security designs.

---

# 20. Lambda + EFS

Now serverless.

Imagine:

```text
Lambda
 │
 ├── execution environment 1
 ├── execution environment 2
 ├── execution environment 3
 │
 └────▶ EFS
```

AWS Lambda supports mounting EFS into a Lambda function. The function uses an **EFS Access Point**, and the function must have VPC connectivity to the filesystem. ([AWS Documentation][11])

This can be useful when Lambda needs:

```text
large shared libraries
ML models
shared files
legacy filesystem-based application data
```

rather than only small ephemeral `/tmp` storage.

---

# 21. Lambda Architecture

```text
                      EFS
                       │
                 Access Point
                       │
                 Mount Targets
                       │
                       ▼
                  Private VPC
                       │
                ┌──────┴──────┐
                ▼             ▼
             Lambda        Lambda
          environment    environment
```

A Lambda function connects to the filesystem over its VPC networking path, so normal EFS networking principles still apply. ([AWS Documentation][11])

---

# 22. Lambda EFS Troubleshooting

AWS distinguishes errors such as:

```text
EFSMountFailureException
EFSMountConnectivityException
EFSMountTimeoutException
```

The troubleshooting meaning is roughly:

```text
Failure
→ permissions/access point/configuration

Connectivity
→ VPC / routing / TCP 2049

Timeout
→ mount operation unable to complete
```

AWS specifically advises checking EFS permissions/access point readiness for mount failures and VPC/security-group routing for connectivity errors. ([AWS Documentation][12])

See how our four-layer EFS troubleshooting model continues to work even for Lambda?

---

# 23. ECS/Fargate + EFS

For ECS, EFS can be defined as a task volume:

```text
ECS Task
   │
Container
   │
mountPoint
   │
   ▼
EFS Access Point
```

ECS supports EFS filesystem IDs, Access Points, IAM authorization, and transit encryption in task definitions. ([AWS Documentation][13])

A production container does **not** need to know:

```text
which EC2 host currently runs me
```

because EFS remains external shared storage.

---

# 24. Critical ECS Rule

If an ECS EFS configuration uses:

```text
IAM authorization
```

then:

```text
transit encryption must be enabled
```

Likewise, using an EFS Access Point in the task configuration requires transit encryption. ([AWS Documentation][13])

Remember:

```text
ECS + EFS IAM
        =
       TLS
```

---

# 25. Container Access Point Pattern

Imagine three services:

```text
EFS
/
├── orders
├── payments
└── reports
```

Then:

```text
Orders ECS task
   │
   ▼
Orders Access Point
   │
   ▼
/orders
```

```text
Payments ECS task
   │
   ▼
Payments Access Point
   │
   ▼
/payments
```

This gives containerized workloads application-specific roots and identities rather than exposing the entire EFS namespace. AWS recommends EFS Access Points as application-specific entry points for ECS shared datasets. ([AWS Documentation][14])

---

# 26. EKS + EFS

For Kubernetes on EKS, AWS provides the **Amazon EFS CSI driver**.

Architecture:

```text
Pod A ─┐
Pod B ─┤
Pod C ─┼── PVC / Persistent Volume
       │
       ▼
  EFS CSI Driver
       │
       ▼
      EFS
```

The CSI driver allows EKS workloads to mount EFS filesystems as Kubernetes persistent volumes. ([AWS Documentation][15])

This is especially useful for shared storage patterns where multiple pods need access to the same filesystem.

---

# 27. EBS vs EFS in Kubernetes

Recall:

```text
EBS
=
block volume
```

versus:

```text
EFS
=
shared NFS filesystem
```

Therefore, very roughly:

```text
One workload needs its own block disk
          ↓
         EBS CSI


Multiple pods need shared file access
          ↓
         EFS CSI
```

The precise Kubernetes decision depends on access modes, workload semantics, availability and performance requirements. AWS maintains separate EBS and EFS CSI integrations for these two storage models. ([AWS Documentation][15])

---

# 28. EFS Backups — Consistency Nuance

AWS Backup can back up EFS while the filesystem remains online.

However, AWS warns that if applications are actively modifying files during the backup—through writes, renames, moves, or deletes—the resulting backup can contain inconsistencies such as skewed, duplicate, or excluded data. ([AWS Documentation][16])

This echoes our EBS lesson:

```text
Backup completed
≠
application-consistent recovery point
```

For critical applications, coordinate backup behavior with the application's own consistency model.

---

# 29. EFS Restore Drill

A real backup process is:

```text
EFS production
      │
      ▼
AWS Backup
      │
      ▼
Recovery point
```

But operational confidence requires:

```text
Recovery point
      │
      ▼
restore
      │
      ▼
mount restored data
      │
      ▼
check directory tree
      │
      ▼
check UID/GID
      │
      ▼
check permissions
      │
      ▼
application test
```

AWS Backup is designed to centralize and automate data protection across AWS resources, including EFS. ([AWS Documentation][17])

The same rule remains:

> **Backup status “Completed” is not the same as a proven recovery process.**

---

# 30. EFS Replication

Now we move from backup into continuous DR replication.

```text
Primary EFS
ap-south-1
      │
      │ managed replication
      ▼
Destination EFS
ap-southeast-1
```

EFS replication automatically copies source filesystem **data and metadata** to a destination filesystem. AWS supports failover to that replica and subsequent failback to the original environment. ([AWS Documentation][18])

---

# 31. Replication Is Asynchronous

Do not think:

```text
write Mumbai
      ↓
Singapore instantly identical
```

EFS replication is asynchronous.

AWS exposes a **Last sync time**, which tells you the point through which source changes are known to have been replicated successfully. Changes after that timestamp might not yet exist on the destination. ([AWS Documentation][18])

Mental model:

```text
Source timeline

10:00
10:05
10:10
10:15
10:20  ← now


Destination Last Sync:

10:15
```

Potential replication exposure:

```text
changes after 10:15
```

---

# 32. Current EFS Replication RPO

After the initial sync, AWS states that EFS replication maintains an RPO of approximately **15 minutes for most filesystems**. Replication can take longer for particular workloads, such as filesystems with more than 100 million highly changing files or individual files larger than 100 GB. AWS exposes `TimeSinceLastSync` for monitoring replication freshness. ([AWS Documentation][18])

Therefore:

```text
Replication
≠
zero-data-loss synchronous storage
```

This distinction is important for SAA-C03 and real DR design.

---

# 33. Replication Failover

Normal:

```text
Mumbai EFS
   READ/WRITE
      │
      ▼
Singapore Replica
   replication destination
```

During disaster, AWS's EFS failover procedure involves deleting the replication configuration, which makes the destination filesystem writable. You can then redirect your application to the former replica. ([AWS Documentation][19])

Conceptually:

```text
Primary unavailable
       │
       ▼
determine replication state
       │
       ▼
stop/disable replication relationship
       │
       ▼
destination becomes writable
       │
       ▼
application switches
       │
       ▼
DR EFS becomes primary
```

This is **not** invisible automatic active/active failover. Your application/infrastructure runbook still matters.

---

# 34. Failback

After Mumbai recovers, you have a decision:

```text
Keep Singapore primary?

OR

return to Mumbai?
```

If returning, the data generated while Singapore was primary must be synchronized back.

EFS supports a failback workflow by establishing replication in the reverse direction and resynchronizing before switching workloads back. ([AWS Documentation][18])

Conceptually:

```text
Original
Mumbai

   X disaster

Singapore becomes writable
       │
       │ new production data
       ▼

Later:

Singapore
   │
   │ reverse replication
   ▼
Mumbai
   │
   ▼
synchronize
   │
   ▼
switch application back
```

---

# 35. Game Day Exercise

Don't discover your failover process for the first time during a regional incident.

A game day should validate:

```text
current replication lag
       ↓
application stop/freeze strategy
       ↓
destination promotion
       ↓
mount configuration
       ↓
DNS/application switch
       ↓
permissions
       ↓
application health
       ↓
actual RPO
       ↓
actual RTO
       ↓
failback
```

AWS explicitly supports using EFS failover for disaster scenarios **and game-day exercises**. ([AWS Documentation][19])

---

# 36. Backup vs Replication — Final Distinction

Imagine at 12:00 someone runs:

```bash
rm -rf /shared/customers
```

Replication may faithfully send that change to the DR EFS.

Then:

```text
Primary:
customers gone

Replica:
customers gone
```

That's where historical backups matter.

Think:

```text
Regional EFS
=
AZ resilience


Replication
=
current DR copy


AWS Backup
=
historical recovery points
```

AWS documents backup and replication as complementary EFS data-protection mechanisms. ([AWS Documentation][20])

---

# 37. Cross-Account Replication

EFS can also replicate to an existing destination filesystem in another AWS account when the required IAM role and file-system resource policies are configured. ([AWS Documentation][21])

This allows designs such as:

```text
Production Account
      │
      │ EFS replication
      ▼
DR Account
```

which can improve administrative isolation.

A mature enterprise architecture might therefore use:

```text
Account A / Region A
Primary EFS

        │
        ├── replication ──▶ Account B / Region B
        │
        └── AWS Backup ───▶ protected backup vault
```

depending on the organization's threat model and RPO/RTO.

---

# 38. EFS Block Public Access

EFS now also has a **Block Public Access** capability that evaluates filesystem resource policies and helps prevent them from granting public access. New EFS filesystems don't allow public access by default, but administrators should still inspect identity, resource, and KMS policies when designing security boundaries. ([AWS Documentation][22])

This is conceptually similar to our broader AWS security rule:

```text
Private networking alone
≠
complete authorization strategy
```

Use multiple layers.

---

# 39. Production EFS Security Stack

A strong design can look like:

```text
                   Application
                       │
                       ▼
                  IAM Role
                       │
                       ▼
           elasticfilesystem:
               ClientMount
               ClientWrite
                       │
                       ▼
               File System Policy
                       │
             require TLS / AP
                       │
                       ▼
                  Access Point
                       │
                  UID / GID
                       │
                       ▼
               POSIX permissions
                       │
                       ▼
                     Files
```

And underneath all of it:

```text
VPC
 │
SG
 │
TCP 2049
 │
Mount Target
```

EFS supports IAM client authorization, Access Point restrictions, POSIX permissions, and filesystem resource policies as separate layers. ([AWS Documentation][10])

---

# 40. Final Terraform Architecture

At this stage, our production EFS module should conceptually manage:

```hcl
resource "aws_efs_file_system" "app" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  tags = {
    Name        = "prod-app"
    Environment = "production"
  }
}
```

Then one mount target for each application AZ:

```hcl
resource "aws_efs_mount_target" "a" {
  file_system_id = aws_efs_file_system.app.id
  subnet_id      = aws_subnet.private_a.id

  security_groups = [
    aws_security_group.efs.id
  ]
}

resource "aws_efs_mount_target" "b" {
  file_system_id = aws_efs_file_system.app.id
  subnet_id      = aws_subnet.private_b.id

  security_groups = [
    aws_security_group.efs.id
  ]
}
```

And an application Access Point:

```hcl
resource "aws_efs_access_point" "app" {
  file_system_id = aws_efs_file_system.app.id

  posix_user {
    uid = 10001
    gid = 10001
  }

  root_directory {
    path = "/app"

    creation_info {
      owner_uid   = 10001
      owner_gid   = 10001
      permissions = "0750"
    }
  }
}
```

EFS Access Points enforce application-specific root directories and POSIX identities, while mount targets provide network connectivity. ([AWS Documentation][23])

---

# 41. Production Mount

For an EC2 application role using IAM:

```bash
sudo mkdir -p /shared

sudo mount \
  -t efs \
  -o tls,iam,accesspoint=fsap-0123456789abcdef0 \
  fs-0123456789abcdef0: \
  /shared
```

AWS requires the EFS mount helper for Access Point and IAM-authorized mounts; Access Point mounts use TLS. ([AWS Documentation][23])

Persistent mount:

```text
fs-0123456789abcdef0:/ /shared efs _netdev,tls,iam,accesspoint=fsap-0123456789abcdef0 0 0
```

---

# 42. Final Production Readiness Test

Before an application becomes healthy:

```bash
set -e

mountpoint -q /shared

test -r /shared
test -w /shared

touch /shared/.healthcheck
rm -f /shared/.healthcheck
```

Then:

```text
EFS mounted?
      ↓
readable?
      ↓
writable?
      ↓
application start
      ↓
ALB target healthy
```

That's better than health checking only:

```text
process exists
```

when EFS is a mandatory dependency.

---

# 43. Final Troubleshooting Scenario

You are paged at 3:00 AM:

> New ASG instances are unhealthy, existing instances work.

Do not randomly recreate EFS.

Use our dependency chain:

```text
New EC2 launched?
      ↓
IAM role correct?
      ↓
amazon-efs-utils installed?
      ↓
DNS resolving?
      ↓
mount target reachable?
      ↓
TCP 2049?
      ↓
IAM ClientMount?
      ↓
file-system policy?
      ↓
Access Point?
      ↓
POSIX permissions?
      ↓
/shared actually mounted?
      ↓
application started?
      ↓
ALB health?
```

The clue:

```text
existing instances work
```

suggests the filesystem itself is probably available.

Investigate what differs in the **new instance configuration**:

```text
new launch template
IAM profile
security group
subnet/AZ
user data
package install
mount configuration
```

That's production troubleshooting, not service guessing.

---

# 44. Final Architecture Decision Table

| Requirement                                | First AWS storage service to evaluate |
| ------------------------------------------ | ------------------------------------- |
| EC2 root disk                              | **EBS**                               |
| High-IOPS block database volume            | **EBS**                               |
| Linux shared NFS filesystem                | **EFS**                               |
| Shared filesystem for EC2 ASG              | **EFS**                               |
| Shared persistent volume for EKS pods      | **EFS / EFS CSI**                     |
| EFS-backed Lambda filesystem dependency    | **EFS + Access Point**                |
| ECS/Fargate shared POSIX data              | **EFS**                               |
| Massive object store/data lake             | **S3**                                |
| Windows SMB / Active Directory file server | **FSx for Windows**                   |
| HPC/parallel filesystem                    | **FSx for Lustre**                    |
| Enterprise ONTAP features                  | **FSx for NetApp ONTAP**              |

The key is not memorizing this table blindly. Always start with:

```text
BLOCK?
FILE?
OBJECT?
      │
      ▼
Shared?
      │
      ▼
Protocol?
      │
      ▼
Latency/IOPS/throughput?
      │
      ▼
HA / DR requirement?
      │
      ▼
Operating system/application?
```

---

# 45. SAA-C03 Scenario

> Hundreds of Linux EC2 instances across AZs must simultaneously access the same files using POSIX filesystem semantics.

Think:

```text
Regional EFS
+
mount targets
+
NFS
```

EFS provides shared NFS filesystem access, POSIX permissions, strong data consistency, and file locking semantics. ([AWS Documentation][24])

---

# 46. DOP-C02 Scenario

> New Auto Scaling instances fail because their EFS dependency never mounts.

Think operationally:

```text
user data / bootstrap logs
      ↓
mount target
      ↓
SG 2049
      ↓
DNS
      ↓
IAM
      ↓
Access Point
      ↓
POSIX
```

Do **not** start by modifying scaling thresholds.

---

# 47. Scenario — Remote Root Must Be Restricted

Requirement:

> Application EC2 instances can write files but remote UID 0 must not retain unrestricted root privileges.

Think:

```text
IAM authorization
+
ClientMount
+
ClientWrite
-
ClientRootAccess
```

which activates EFS root squashing for that connection. ([AWS Documentation][8])

---

# 48. Scenario — Lambda Needs Shared ML Models

Think:

```text
Lambda
+
VPC
+
EFS
+
Access Point
```

Lambda directly supports connecting a function to an EFS Access Point in the same VPC networking environment. ([AWS Documentation][11])

---

# 49. Scenario — Regional Disaster

Requirement:

```text
shared filesystem must
recover in another Region
with low data loss
```

Think:

```text
EFS Replication
+
monitor Last Sync / TimeSinceLastSync
+
tested failover
+
AWS Backup for historical recovery
```

EFS replication provides about a 15-minute RPO for most filesystems after initial synchronization, while backups provide separate historical restore points. ([AWS Documentation][18])

---

# 50. Interview Question

> **How would you build enterprise-grade shared storage for a Linux application running across EC2, containers and possibly on-premises servers?**

A strong answer would be:

> If the applications require POSIX/NFS shared-file semantics, I'd evaluate Regional Amazon EFS. I'd place mount targets in the workload Availability Zones and restrict NFS connectivity through security groups. I'd use TLS for transport encryption, IAM client authorization and filesystem policies where stronger identity controls are required, and EFS Access Points to isolate application directories and enforce POSIX identities. EC2, ECS, EKS and Lambda can all integrate with EFS using their appropriate mechanisms, and on-premises Linux clients can reach mount targets through Direct Connect or VPN. For DR I'd use EFS replication with monitored replication lag, while retaining AWS Backup recovery points because replication doesn't protect against every logical deletion or corruption event. I'd test both failover and restore procedures against the application's RPO and RTO. ([AWS Documentation][6])

---

# Never-Forget EFS Mental Model

```text
                            EFS
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
           NETWORK        SECURITY       STORAGE
              │              │              │
         Mount Target       IAM          NFS files
         TCP 2049         Policy           │
         VPC/Routes       Access Point      │
              │           POSIX            │
              └──────────────┼──────────────┘
                             │
                             ▼
                         COMPUTE
               ┌─────────────┼─────────────┐
               ▼             ▼             ▼
              EC2           ECS           EKS
               │             │             │
               └─────────────┼─────────────┘
                             │
                           Lambda
                             │
                             ▼
                           HYBRID
                             │
                   Direct Connect / VPN
                             │
                             ▼
                         On-premises
                             │
                             ▼
                             DR
                      ┌──────┴──────┐
                      ▼             ▼
                 Replication     AWS Backup
```

The four distinctions I want permanently fixed in your memory are:

```text
Mount Target
=
NETWORK endpoint
```

```text
Access Point
=
APPLICATION filesystem boundary
```

```text
Replication
=
CURRENT DR copy
```

```text
AWS Backup
=
HISTORICAL recovery points
```

And:

```text
EBS
=
a machine needs a disk

EFS
=
many machines need one filesystem

S3
=
applications need object storage
```

---

# ✅ Lesson 26 — Amazon EFS Complete

At this point, you have covered EFS from beginner through advanced production engineering:

```text
EFS fundamentals
        ↓
NFS
        ↓
Mount Targets
        ↓
Regional / One Zone
        ↓
Security Groups
        ↓
TLS
        ↓
POSIX
        ↓
Access Points
        ↓
IAM client authorization
        ↓
Performance / throughput
        ↓
Lifecycle classes
        ↓
Auto Scaling
        ↓
ECS / Fargate
        ↓
EKS CSI
        ↓
Lambda
        ↓
Cross-VPC
        ↓
Cross-account
        ↓
Transit Gateway
        ↓
Hybrid DX/VPN
        ↓
Consistency + locking
        ↓
Root squashing
        ↓
AWS Backup
        ↓
Replication
        ↓
Failover / Failback
        ↓
Production troubleshooting
```

So the shared Linux filesystem layer is now closed.

## Next in our AWS flow: **Lesson 27 — Amazon S3**

And S3 deserves a deep lesson because it is **not merely “AWS file storage.”**

We will build it from first principles:

```text
OBJECT STORAGE
       │
       ├── Bucket
       ├── Object
       ├── Key
       ├── Prefix
       ├── Metadata
       ├── Version ID
       │
       ▼
S3 Request Architecture
       │
       ├── REST/API
       ├── AWS CLI
       ├── SDK
       └── presigned URLs
       │
       ▼
Security
       │
       ├── IAM
       ├── bucket policies
       ├── ACLs
       ├── Block Public Access
       ├── Object Ownership
       ├── encryption
       └── KMS
       │
       ▼
Storage Classes
       │
       ├── Standard
       ├── Intelligent-Tiering
       ├── Standard-IA
       ├── One Zone-IA
       ├── Glacier Instant Retrieval
       ├── Glacier Flexible Retrieval
       └── Deep Archive
       │
       ▼
Production
       │
       ├── lifecycle policies
       ├── versioning
       ├── Object Lock
       ├── replication
       ├── CRR / SRR
       ├── multipart upload
       ├── Transfer Acceleration
       ├── static websites
       ├── CloudFront
       ├── OAC
       ├── VPC endpoints
       ├── event notifications
       ├── Lambda
       ├── S3 Inventory
       ├── Storage Lens
       └── troubleshooting 403s
```

That will connect directly to our earlier **CloudFront, IAM, Terraform, DNS, DevOps artifact storage, backup, data-lake, and static-site** work.

[1]: https://docs.aws.amazon.com/efs/latest/ug/features.html?utm_source=chatgpt.com "Features of Amazon EFS - Amazon Elastic File System"
[2]: https://docs.aws.amazon.com/efs/latest/ug/performance-tips.html?utm_source=chatgpt.com "Amazon EFS performance tips - Amazon Elastic File System"
[3]: https://docs.aws.amazon.com/efs/latest/ug/mount-fs-different-vpc.html?utm_source=chatgpt.com "Mounting EFS file systems from another VPC"
[4]: https://docs.aws.amazon.com/efs/latest/ug/manage-fs-access-vpc-peering.html?utm_source=chatgpt.com "Mounting EFS file systems from another AWS account or VPC"
[5]: https://docs.aws.amazon.com/efs/latest/ug/mount-fs-diff-account-same-vpc.html?utm_source=chatgpt.com "Mounting EFS file systems from another AWS account"
[6]: https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-helper-direct.html?utm_source=chatgpt.com "Tutorial: Mounting with on-premises Linux clients"
[7]: https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html?utm_source=chatgpt.com "Configuring AWS DataSync transfers with Amazon EFS"
[8]: https://docs.aws.amazon.com/efs/latest/ug/accessing-fs-nfs-permissions.html?utm_source=chatgpt.com "Network File System (NFS) level users, groups, and permissions"
[9]: https://docs.aws.amazon.com/efs/latest/ug/create-file-system-policy.html?utm_source=chatgpt.com "Creating file system policies - AWS Documentation"
[10]: https://docs.aws.amazon.com/efs/latest/ug/iam-access-control-nfs-efs.html?utm_source=chatgpt.com "Using IAM to control access to file systems"
[11]: https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem-efs.html?utm_source=chatgpt.com "Configuring Amazon EFS file system access - AWS Lambda"
[12]: https://docs.aws.amazon.com/lambda/latest/dg/troubleshooting-invocation.html?utm_source=chatgpt.com "Troubleshoot invocation issues in Lambda"
[13]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specify-efs-config.html?utm_source=chatgpt.com "Specify an Amazon EFS file system in an Amazon ECS ..."
[14]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html?utm_source=chatgpt.com "Use Amazon EFS volumes with Amazon ECS"
[15]: https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html?utm_source=chatgpt.com "Use elastic file system storage with Amazon EFS - Amazon EKS"
[16]: https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html?utm_source=chatgpt.com "Backing up EFS file systems"
[17]: https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html?utm_source=chatgpt.com "What is AWS Backup? - AWS Backup - AWS Documentation"
[18]: https://docs.aws.amazon.com/efs/latest/ug/efs-replication.html?utm_source=chatgpt.com "Replicating EFS file systems"
[19]: https://docs.aws.amazon.com/efs/latest/ug/replication-fail-over.html?utm_source=chatgpt.com "Using the replica - Amazon Elastic File System"
[20]: https://docs.aws.amazon.com/efs/latest/ug/backup-replication.html?utm_source=chatgpt.com "Backing up and replicating data in Amazon EFS"
[21]: https://docs.aws.amazon.com/efs/latest/ug/replicate-existing-destination.html?utm_source=chatgpt.com "Configuring replication to an existing EFS file system"
[22]: https://docs.aws.amazon.com/efs/latest/ug/access-control-block-public-access.html?utm_source=chatgpt.com "Blocking public access to EFS file systems"
[23]: https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html?utm_source=chatgpt.com "Working with access points - Amazon Elastic File System"
[24]: https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html?utm_source=chatgpt.com "What is Amazon Elastic File System?"
