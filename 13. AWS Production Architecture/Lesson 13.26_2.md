# AWS Masterclass — Lesson 26 Part 2

# EFS Production Lab, IAM Access, Monitoring, DR & Troubleshooting

Now we stop treating EFS as theory and build the full production mental model:

```text id="9h8kbn"
                    ALB
                     │
          ┌──────────┴──────────┐
          │                     │
       EC2-A                 EC2-B
       AZ-A                  AZ-B
          │                     │
          ▼                     ▼
   EFS Mount Target A    EFS Mount Target B
          \                     /
           \                   /
                Regional EFS
                     │
                     ▼
                /shared/app
```

We will validate:

```text id="976v3v"
✓ shared writes
✓ TLS
✓ /etc/fstab
✓ mount targets
✓ security groups
✓ Access Points
✓ IAM authorization
✓ enforced UID/GID
✓ Auto Scaling integration
✓ CloudWatch metrics
✓ throughput troubleshooting
✓ mount failures
✓ ECS/EKS concepts
✓ AWS Backup
✓ EFS replication
✓ DR thinking
```

---

# 1. Lab Architecture

Use:

```text id="46a7jw"
Region:
ap-south-1

VPC:
10.26.0.0/16

Private subnet A:
10.26.11.0/24

Private subnet B:
10.26.12.0/24
```

Production layout:

```text id="odpvti"
                        VPC
                         │
             ┌───────────┴───────────┐
             │                       │
       ap-south-1a              ap-south-1b
             │                       │
       Private Subnet A         Private Subnet B
             │                       │
           EC2-A                   EC2-B
         App-SG                   App-SG
             │                       │
             ▼                       ▼
       Mount Target A          Mount Target B
            EFS-SG                  EFS-SG
             \                       /
              \                     /
                  Regional EFS
                       │
                  Access Point
                       │
                     /app
```

For a Regional EFS file system, creating mount targets in the Availability Zones used by your clients allows instances to connect through an AZ-local mount target. ([AWS Documentation][1])

---

# 2. Terraform File System

Start with:

```hcl id="8bpzu5"
resource "aws_efs_file_system" "app" {
  creation_token = "lesson26-app"

  encrypted = true

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_archive = "AFTER_90_DAYS"
  }

  tags = {
    Name        = "lesson26-app-efs"
    Environment = "lab"
  }
}
```

The current Terraform AWS provider supports `bursting`, `provisioned`, and `elastic` throughput modes for `aws_efs_file_system`. ([Terraform Registry][2])

Our production starting point is:

```text id="3v60fm"
General Purpose
+
Elastic Throughput
```

because Elastic is designed for workloads whose throughput demand varies rather than requiring a fixed provisioned rate. ([AWS Documentation][3])

---

# 3. Security Groups

Create one SG for clients:

```hcl id="gvv599"
resource "aws_security_group" "app" {
  name   = "lesson26-app-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

And one for EFS:

```hcl id="xwlwet"
resource "aws_security_group" "efs" {
  name   = "lesson26-efs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "NFS from application servers"

    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"

    security_groups = [
      aws_security_group.app.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

EFS clients communicate with mount targets over NFS TCP/2049, so the mount-target SG must allow that client traffic. ([AWS Documentation][4])

Mental model:

```text id="e3wyz8"
App-SG
   │
   │ TCP 2049
   ▼
EFS-SG
```

---

# 4. Mount Targets

```hcl id="lp5yhj"
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

Terraform's `aws_efs_mount_target` resource creates the VPC endpoint used by clients to reach EFS. ([Terraform Registry][5])

Architecture:

```text id="0a57l0"
EFS
 │
 ├── Mount Target A
 │      └── subnet A
 │
 └── Mount Target B
        └── subnet B
```

---

# 5. EC2 IAM Role

We want Systems Manager for administration and later IAM-based EFS access.

Example:

```hcl id="wz3mv1"
resource "aws_iam_role" "ec2" {
  name = "lesson26-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}
```

SSM:

```hcl id="db78pz"
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

We'll add EFS client permissions shortly.

---

# 6. Install the EFS Client

On Amazon Linux:

```bash id="4h937k"
sudo dnf install -y amazon-efs-utils
```

AWS recommends the EFS mount helper, which is part of `amazon-efs-utils`, for mounting EFS on supported Linux clients. ([AWS Documentation][6])

Create:

```bash id="m8n4bk"
sudo mkdir -p /shared
```

---

# 7. First TLS Mount

Set:

```bash id="3lp92z"
EFS_ID="fs-0123456789abcdef0"
```

Mount:

```bash id="7u584c"
sudo mount \
  -t efs \
  -o tls \
  "$EFS_ID":/ \
  /shared
```

Verify:

```bash id="m5e3ou"
mount | grep efs
```

and:

```bash id="2d4jmi"
df -hT /shared
```

The EFS mount helper supports TLS encryption in transit with the `tls` mount option. ([AWS Documentation][7])

---

# 8. Prove Shared Storage

On EC2-A:

```bash id="zkqp5x"
echo "hello from EC2-A" \
  | sudo tee /shared/from-a.txt
```

On EC2-B:

```bash id="h2fkiv"
cat /shared/from-a.txt
```

Expected:

```text id="ayqt21"
hello from EC2-A
```

Now reverse it.

EC2-B:

```bash id="ev0fsl"
echo "hello from EC2-B" \
  | sudo tee /shared/from-b.txt
```

EC2-A:

```bash id="qvc29r"
cat /shared/from-b.txt
```

This demonstrates:

```text id="eh7fko"
EC2-A
   \
    \
     EFS namespace
    /
   /
EC2-B
```

Both clients operate against the same managed filesystem. ([AWS Documentation][6])

---

# 9. Persistent Mount with `/etc/fstab`

We learned this lesson from EBS:

```text id="xftnxf"
manual mount
≠
persistent mount
```

For EFS:

```text id="gc01mu"
network must exist
before filesystem mount
```

Use:

```text id="rjm4dz"
_netdev
```

Example:

```bash id="uefcro"
echo "$EFS_ID:/ /shared efs _netdev,tls 0 0" \
  | sudo tee -a /etc/fstab
```

AWS warns that `_netdev` should be used for automatic EFS mounts because the filesystem depends on networking; omitting it can cause boot problems or an unresponsive instance. ([AWS Documentation][7])

Test before reboot:

```bash id="wuxc09"
sudo umount /shared
sudo mount -a
```

Then:

```bash id="gl6859"
mount | grep /shared
```

---

# 10. Never Forget This Boot Chain

```text id="zgugyr"
EC2 boots
   ↓
network initialization
   ↓
DNS
   ↓
EFS mount target
   ↓
NFS/TLS mount
   ↓
application starts
```

If `/shared` is mandatory for your app, do not start the application until the mount is verified.

For example:

```bash id="4e7okk"
mountpoint -q /shared || exit 1
```

This is much safer than allowing:

```text id="eiinnv"
mount fails

BUT

application starts writing to
local /shared directory
```

because then files silently go to local EC2 storage instead of EFS.

---

# 11. Dangerous Production Failure

Imagine `/shared/uploads` should be EFS.

Mount fails.

Linux still has:

```text id="lxak46"
/shared/uploads
```

as a normal directory.

Application writes:

```text id="p0mwps"
customer.jpg
```

there.

Now:

```text id="s1qi97"
EC2-A
/customer.jpg

EC2-B
no customer.jpg
```

You accidentally converted shared storage back into instance-local storage.

### Production guard

Before application startup:

```bash id="pvcjhf"
if ! mountpoint -q /shared; then
  echo "EFS not mounted"
  exit 1
fi
```

This simple check prevents a very nasty class of data-placement errors.

---

# 12. EFS Access Point

Now let's isolate application data.

Create:

```hcl id="ypfb3g"
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

  tags = {
    Name = "lesson26-app-access-point"
  }
}
```

An EFS Access Point can expose a specified path as an application's filesystem root and enforce a POSIX user identity. ([Terraform Registry][8])

Mental model:

```text id="v4dzx2"
Real EFS:

/
├── app
├── backups
├── teams
└── shared


Application sees:

/
```

but that application root actually maps to:

```text id="xwjzvf"
/app
```

inside EFS.

---

# 13. Mount Through the Access Point

Set:

```bash id="419qte"
ACCESS_POINT="fsap-0123456789abcdef0"
```

Then:

```bash id="1jkof4"
sudo mount \
  -t efs \
  -o tls,accesspoint="$ACCESS_POINT" \
  "$EFS_ID": \
  /shared
```

Access-point mounts require the EFS mount helper and include TLS. ([AWS Documentation][9])

---

# 14. Enforced UID/GID

Suppose your local process runs as:

```text id="nn817u"
UID = 5000
GID = 5000
```

but the Access Point defines:

```text id="2oxh2k"
UID = 10001
GID = 10001
```

When requests go through that access point, EFS can enforce the Access Point POSIX identity rather than simply trusting the client's original UID/GID. ([AWS Documentation][10])

This is very useful for containers where host/client UID values can otherwise differ.

---

# 15. IAM Authorization

Now add AWS identity.

IAM client permissions include actions such as:

```text id="x0b5li"
elasticfilesystem:ClientMount
elasticfilesystem:ClientWrite
```

and optionally:

```text id="2a4t5f"
elasticfilesystem:ClientRootAccess
```

when root-level access is actually required. EFS supports IAM client authorization when the EFS mount helper is used. ([AWS Documentation][11])

Example role policy:

```hcl id="6q26d2"
resource "aws_iam_role_policy" "efs_client" {
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ]

      Resource = aws_efs_file_system.app.arn
    }]
  })
}
```

---

# 16. IAM Mount

Mount with:

```bash id="jn3v0n"
sudo mount \
  -t efs \
  -o tls,iam \
  "$EFS_ID":/ \
  /shared
```

AWS requires the EFS mount helper for IAM-authorized NFS access. ([AWS Documentation][12])

Now security has multiple layers:

```text id="gu8deg"
Security Group
      │
      ▼
TCP 2049 allowed?
      │
      ▼
IAM ClientMount?
      │
      ▼
Access Point?
      │
      ▼
POSIX permissions?
```

---

# 17. IAM + Access Point Together

Production mount:

```bash id="jhl6mt"
sudo mount \
  -t efs \
  -o tls,iam,accesspoint="$ACCESS_POINT" \
  "$EFS_ID": \
  /shared
```

This combines:

```text id="0l2qki"
TLS
+
IAM identity
+
Access Point
+
POSIX identity
```

AWS also supports IAM policies that require a specific client to use a particular Access Point through the `elasticfilesystem:AccessPointArn` condition key. ([AWS Documentation][13])

---

# 18. Restrict IAM to One Access Point

Conceptually:

```json id="ym237m"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:ClientMount",
        "elasticfilesystem:ClientWrite"
      ],
      "Resource": "arn:aws:elasticfilesystem:ap-south-1:123456789012:file-system/fs-xxx",
      "Condition": {
        "StringEquals": {
          "elasticfilesystem:AccessPointArn": "arn:aws:elasticfilesystem:ap-south-1:123456789012:access-point/fsap-xxx"
        }
      }
    }
  ]
}
```

That creates:

```text id="cx6sdi"
App-A role
   │
   └── only Access Point A
```

instead of:

```text id="anb8vi"
App-A can mount
the entire EFS namespace
```

AWS documents this AccessPointArn policy-control pattern directly. ([AWS Documentation][13])

---

# 19. File System Policy

EFS also supports a resource policy on the filesystem itself.

Terraform:

```hcl id="5c2zd2"
resource "aws_efs_file_system_policy" "app" {
  file_system_id = aws_efs_file_system.app.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowApplicationRole"
        Effect = "Allow"

        Principal = {
          AWS = aws_iam_role.ec2.arn
        }

        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]

        Resource = aws_efs_file_system.app.arn
      }
    ]
  })
}
```

Terraform provides `aws_efs_file_system_policy` for managing the EFS resource policy. ([Terraform Registry][14])

Think:

```text id="5s4a1t"
Identity Policy
+
File System Policy
```

similarly to:

```text id="lyo6nc"
IAM policy
+
S3 bucket policy
```

which we'll later study deeply.

---

# 20. Auto Scaling + EFS

Now connect Lesson 24.

Launch Template user data:

```bash id="r5emd5"
#!/bin/bash

set -euxo pipefail

dnf install -y amazon-efs-utils nginx

mkdir -p /shared

echo "fs-0123456789abcdef0:/ /shared efs _netdev,tls,iam,accesspoint=fsap-0123456789abcdef0 0 0" \
  >> /etc/fstab

mount -a

if ! mountpoint -q /shared; then
  echo "EFS mount failed"
  exit 1
fi

echo "$(hostname) joined shared storage" \
  >> /shared/instances.log

systemctl enable nginx
systemctl start nginx
```

Each ASG instance now:

```text id="r31y8b"
launch
  ↓
install EFS client
  ↓
mount shared filesystem
  ↓
validate mount
  ↓
start app
  ↓
join ALB
```

---

# 21. Critical Bootstrap Ordering

Bad:

```text id="8niyve"
Start app
   ↓
maybe EFS mounts later
```

Better:

```text id="el6fjd"
Network ready
   ↓
EFS mounted
   ↓
filesystem writable
   ↓
application starts
   ↓
health check passes
```

For a workload where EFS is mandatory, readiness should include EFS dependency health.

Example:

```bash id="cvmvqw"
test -w /shared || exit 1
```

You could even expose:

```text id="760x1r"
/health
```

as unhealthy if required shared storage isn't usable.

---

# 22. Failure Simulation — Security Group

Now deliberately remove:

```text id="vq1myc"
EFS SG:
TCP 2049 from App-SG
```

Then on EC2:

```bash id="irfnpw"
sudo umount /shared
sudo mount -a
```

Expected symptom may be timeout/hanging behavior.

Your thinking should immediately become:

```text id="eezoqu"
Mount timeout
   ↓
network layer
   ↓
mount target?
   ↓
SG TCP 2049?
   ↓
routing?
   ↓
DNS?
```

EFS troubleshooting documentation specifically calls out network connectivity and mount configuration as core causes of mount failures. ([AWS Documentation][4])

Restore the SG rule and retry.

---

# 23. Failure Simulation — POSIX

Set directory permissions:

```bash id="be0wkw"
sudo chmod 500 /shared
```

Then try:

```bash id="139663"
touch /shared/test
```

Expected:

```text id="pol0ez"
Permission denied
```

But:

```bash id="9o574f"
mount | grep /shared
```

still succeeds.

Therefore:

```text id="c8yhuq"
not network
```

It's a filesystem authorization problem.

This is one of the most important troubleshooting distinctions in EFS.

---

# 24. CloudWatch EFS Metrics

Now production monitoring.

Useful metrics include:

```text id="hd54uu"
ClientConnections
DataReadIOBytes
DataWriteIOBytes
MetadataIOBytes
MeteredIOBytes
PermittedThroughput
PercentIOLimit
BurstCreditBalance
StorageBytes
```

EFS publishes CloudWatch metrics that let you examine throughput, I/O, connection activity, permitted throughput, utilization and burst-credit behavior. ([AWS Documentation][15])

---

# 25. `ClientConnections`

This answers:

```text id="vy83jm"
How many clients are connected?
```

If your ASG says:

```text id="er1a5r"
20 InService instances
```

but:

```text id="ppcqer"
ClientConnections = 2
```

you should investigate whether new instances actually mounted EFS.

This can reveal bootstrap problems quickly. EFS exposes client connection count as a CloudWatch metric. ([AWS Documentation][16])

---

# 26. `DataReadIOBytes` / `DataWriteIOBytes`

These show actual data transfer caused by reads and writes.

For example:

```text id="mmfhvn"
DataReadIOBytes Sum
=
60 GiB over 300 seconds
```

Approximate read throughput:

```text id="0h629c"
60 GiB
≈ 61,440 MiB

61,440 / 300

≈ 204.8 MiB/s
```

EFS metrics expose read and write byte totals that can be divided by the observation interval to estimate average throughput. ([AWS Documentation][16])

---

# 27. `MeteredIOBytes`

This is important for throughput behavior and billing-related metering.

AWS recommends comparing:

```text id="wd7tso"
MeteredIOBytes
```

against:

```text id="gq2cm7"
PermittedThroughput
```

to determine whether the filesystem is consuming all the throughput currently available to it. ([AWS Documentation][15])

Conceptually:

```text id="9lu0pf"
Demand
  │
  ▼
Metered throughput

Allowed
  │
  ▼
PermittedThroughput
```

If demand remains against the ceiling:

```text id="o6mol7"
performance constraint
```

may appear.

---

# 28. `PercentIOLimit`

For General Purpose EFS:

```text id="vlcrkw"
PercentIOLimit
```

shows how close the filesystem is to its I/O limit. ([AWS Documentation][17])

Mental model:

```text id="rbyybq"
30%
=
comfortable

70%
=
watch

95–100%
=
very close to I/O ceiling
```

Do not treat those percentages as universal alert thresholds; workload baselines matter.

But sustained:

```text id="47cqwp"
~100%
```

combined with latency/application degradation is a strong signal to investigate filesystem I/O pressure.

---

# 29. `BurstCreditBalance`

Only think strongly about this when using:

```text id="vgrt67"
Bursting throughput mode
```

A shrinking balance means the filesystem is using accumulated burst credits. ([AWS Documentation][17])

Mental flow:

```text id="tnwggd"
Bursting filesystem
        │
        ▼
traffic exceeds baseline
        │
        ▼
credits consumed
        │
        ▼
BurstCreditBalance ↓
```

If your workload is continually consuming all burst credits, reconsider the throughput mode instead of treating the symptom as a random EFS failure. ([AWS Documentation][3])

---

# 30. EFS Performance Troubleshooting Chain

Application slow:

```text id="8hx80q"
Application slow
       │
       ▼
EFS involved?
       │
       ▼
ClientConnections normal?
       │
       ▼
Data throughput high?
       │
       ▼
MeteredIOBytes vs PermittedThroughput?
       │
       ▼
PercentIOLimit near ceiling?
       │
       ▼
Bursting?
       │
       ▼
BurstCreditBalance depleted?
       │
       ▼
network/client issue?
       │
       ▼
metadata-heavy workload?
```

Don't just say:

```text id="baxjn9"
"Increase EFS."
```

Determine **what workload dimension is creating the pressure**.

---

# 31. Metadata-Heavy Workloads

Imagine:

```text id="kyddoi"
1 million tiny files

ls
stat
open
close
find
chmod
```

That workload behaves very differently from:

```text id="pg95uc"
one 50 GiB sequential file
```

EFS exposes metadata-specific metrics such as:

```text id="fwdmvf"
MetadataIOBytes
```

so metadata pressure can be distinguished from normal file-data traffic. ([AWS Documentation][16])

This matters for:

```text id="j459c3"
package repositories
source trees
CMS systems
ML datasets with millions of tiny files
build environments
```

---

# 32. Linux-Level Troubleshooting

Useful commands:

```bash id="afjvma"
mount | grep efs
```

```bash id="b8wwlr"
df -hT
```

```bash id="hqxp8b"
nfsstat -m
```

```bash id="vta8vr"
sudo dmesg | tail -100
```

```bash id="d96b5a"
getent hosts "$EFS_ID".efs.ap-south-1.amazonaws.com
```

```bash id="f412ws"
nc -vz <mount-target-ip> 2049
```

when `nc` is installed.

These help separate:

```text id="rqukxt"
DNS
network
mount options
NFS state
filesystem
```

---

# 33. Mount Timeout Runbook

Symptom:

```text id="op1yy6"
Connection timed out
```

Use:

```text id="o0xco5"
1. Does a mount target exist?

2. Is it in the expected VPC?

3. Is the client subnet routed correctly?

4. Can EFS DNS resolve?

5. Does EFS-SG allow TCP 2049 from App-SG?

6. Does client SG allow outbound?

7. Are NACLs blocking traffic?

8. Is the EFS client installed?

9. Are mount options valid?

10. Is this a cross-VPC/account scenario?
```

AWS's mount troubleshooting guide highlights IAM options, mount helper configuration and network access as important areas to validate. ([AWS Documentation][4])

---

# 34. IAM Failure Runbook

Symptom:

```text id="ev63uf"
access denied
```

when mounting with IAM.

Check:

```text id="tddths"
-o iam present?
   ↓
mount helper used?
   ↓
EC2/task IAM role?
   ↓
ClientMount allowed?
   ↓
ClientWrite allowed?
   ↓
file-system policy?
   ↓
explicit DENY?
   ↓
AccessPointArn condition?
```

AWS specifically recommends reviewing both identity and filesystem policies for applicable ALLOW and DENY statements when IAM-based mounting fails. ([AWS Documentation][4])

---

# 35. Auto Scaling Failure Loop

Imagine all new ASG instances do:

```text id="0e1wk5"
boot
 ↓
mount EFS
 ↓
timeout
 ↓
app never starts
 ↓
ALB unhealthy
 ↓
ASG replaces EC2
 ↓
same config
 ↓
repeat
```

What do you inspect?

Not:

```text id="353of6"
CPU scaling policy
```

Start at:

```text id="hcjpaq"
Cloud-init/user data
      ↓
EFS mount
      ↓
SG 2049
      ↓
mount targets
      ↓
DNS
```

Then correlate with:

```bash id="fxii44"
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name prod-app-asg
```

The ASG is doing its job.

The dependency bootstrap is failing.

---

# 36. ECS + EFS

Now containers.

Architecture:

```text id="84z6m5"
ECS Task A
     │
     ▼
 Access Point A
     │
     ▼
     EFS


ECS Task B
     │
     ▼
 Access Point B
     │
     ▼
     EFS
```

Amazon ECS task definitions can specify EFS volumes and mount points, and AWS recommends combining IAM policies with access points when applications need secure access to specific datasets. ([AWS Documentation][18])

An ECS task definition conceptually contains:

```json id="l9r1x1"
{
  "volumes": [
    {
      "name": "shared",
      "efsVolumeConfiguration": {
        "fileSystemId": "fs-xxx"
      }
    }
  ]
}
```

and the container mounts that volume.

---

# 37. ECS IAM Important Rule

When EFS IAM authorization is enabled for an ECS task, transit encryption must also be enabled. ([AWS Documentation][19])

So think:

```text id="eov6pj"
ECS
+
EFS IAM authorization
=
TLS required
```

---

# 38. EKS + EFS Mental Model

We will cover the Kubernetes storage integration in depth in the EKS/Kubernetes section, but the high-level architecture is:

```text id="ux4o52"
Pod
 │
 ▼
PersistentVolumeClaim
 │
 ▼
EFS CSI Driver
 │
 ▼
EFS
```

This is useful where many Kubernetes pods require shared ReadWriteMany-style filesystem access.

Don't worry about the Kubernetes objects yet; the storage principle is the same:

```text id="o1eg3a"
multiple compute clients
      ↓
shared NFS filesystem
```

---

# 39. AWS Backup for EFS

EFS integrates directly with AWS Backup.

AWS Backup can create policy-controlled backups of EFS file systems, and EFS console-created filesystems have automatic backup behavior enabled by default in certain creation paths; CLI/API creation defaults differ, particularly between Regional and One Zone workflows, so production backup policy should be explicit rather than assumed. ([AWS Documentation][20])

Mental model:

```text id="fmnnp4"
EFS
 │
 ▼
AWS Backup
 │
 ▼
Backup Vault
 │
 ├── schedule
 ├── retention
 ├── copy
 └── restore
```

---

# 40. Backup ≠ Replication

Same rule from EBS:

```text id="dyyein"
Backup
=
historical recovery points


Replication
=
maintain another current copy
```

If someone deletes:

```text id="ct530t"
/shared/customers
```

replication may replicate that deletion.

Backups provide an older recovery point.

You often need:

```text id="iqrz50"
backup
+
replication
```

for different failure modes.

---

# 41. EFS Replication

Amazon EFS supports replication of data and metadata from a source file system to a destination EFS filesystem for additional resilience and DR scenarios. AWS supports failover to the replica and later failback workflows. ([AWS Documentation][21])

Architecture:

```text id="55z39c"
Primary EFS
ap-south-1
      │
      │ replication
      ▼
DR EFS
another Region / destination
```

This gives you a very different recovery profile than:

```text id="dwfjh1"
restore large backup
then start workload
```

---

# 42. EFS Resilience Layers

Think in three layers:

```text id="v4mbmb"
Layer 1
Regional EFS
      │
      └── resilience across AZs


Layer 2
EFS Replication
      │
      └── DR replica


Layer 3
AWS Backup
      │
      └── historical recovery
```

AWS documents Regional EFS as resilient to Availability Zone failures and replication as an additional data-protection mechanism. ([AWS Documentation][1])

---

# 43. Example DR Design

Requirement:

```text id="x5bfaw"
Primary:
Mumbai

DR:
Singapore
```

Architecture:

```text id="211r6q"
                   ap-south-1
                       │
                  Regional EFS
                       │
                replication
                       │
                       ▼
                 ap-southeast-1
                       │
                    DR EFS

and separately

Regional EFS
      │
      ▼
 AWS Backup
      │
      ▼
 recovery points
```

Now:

```text id="d44haf"
AZ outage
→ Regional EFS resilience

Regional disaster
→ replica

accidental deletion/corruption
→ backup
```

Different tools solve different failure classes.

---

# 44. Testing EFS Recovery

Don't say:

```text id="v26lc6"
"We enabled AWS Backup."
```

and stop there.

Recovery test:

```text id="0w2tol"
Backup exists
      ↓
restore EFS data
      ↓
mount recovery destination
      ↓
verify filenames
      ↓
verify ownership
      ↓
verify permissions
      ↓
application test
      ↓
measure recovery time
```

AWS Backup supports restoring EFS recovery points; production teams should verify restore behavior and access controls as part of DR testing. ([AWS Documentation][22])

---

# 45. EFS vs FSx

Now architecture selection.

EFS is excellent when:

```text id="nff0ft"
Linux/NFS
serverless managed filesystem
elastic capacity
shared POSIX filesystem
general cloud-native shared file access
```

But AWS has specialized managed filesystems under the **FSx** family.

Think:

```text id="2gj9iz"
Need generic managed Linux NFS?
        ↓
       EFS


Need Windows SMB / Active Directory integration?
        ↓
FSx for Windows File Server


Need very high-performance HPC-style filesystem?
        ↓
FSx for Lustre


Need NetApp ONTAP features?
        ↓
FSx for NetApp ONTAP


Need OpenZFS semantics/features?
        ↓
FSx for OpenZFS
```

The selection depends on filesystem protocol, performance, operating-system integration and enterprise storage requirements.

---

# 46. EFS vs EBS vs S3 vs FSx

This table should become automatic:

| Requirement                          | First service to evaluate |
| ------------------------------------ | ------------------------- |
| Linux EC2 boot disk                  | EBS                       |
| High-IOPS block DB disk              | EBS                       |
| Shared Linux NFS filesystem          | EFS                       |
| Auto Scaling shared files            | EFS                       |
| Object/media archive                 | S3                        |
| Data lake objects                    | S3                        |
| Windows SMB share                    | FSx for Windows           |
| HPC scratch/parallel file processing | FSx for Lustre            |
| Enterprise NetApp workloads          | FSx for ONTAP             |

Don't memorize only service definitions.

Use:

```text id="g7cfw3"
protocol
+
access model
+
sharing requirement
+
latency
+
throughput
+
durability
+
cost
```

---

# 47. Production Troubleshooting Scenario

User says:

> “EC2-A can mount EFS, but EC2-B can't.”

Your thinking:

```text id="15ye1w"
Same VPC?
     │
     ▼
EC2-B AZ has mount target?
     │
     ▼
EC2-B security group?
     │
     ▼
mount target security group?
     │
     ▼
TCP 2049?
     │
     ▼
DNS?
     │
     ▼
different route/NACL?
```

The fact that EC2-A works proves:

```text id="24ukdi"
EFS itself is not universally unavailable.
```

Focus on differences between the clients.

---

# 48. Scenario — Mount Works, Node.js Gets Permission Denied

Do:

```bash id="crqo46"
id
```

```bash id="8q8thh"
ps aux | grep node
```

```bash id="dsroih"
ls -ld /shared /shared/app
```

Check:

```text id="40mw0i"
Node UID/GID
EFS directory UID/GID
Access Point POSIX identity
IAM ClientWrite
```

Don't change:

```text id="unxzj2"
2049 security group
```

because the mount already succeeded.

---

# 49. Scenario — EFS Is Slow

CloudWatch:

```text id="vc0hgn"
PercentIOLimit ≈ 100%
```

Think:

```text id="88ywhw"
I/O scalability limit
```

If Bursting:

```text id="f2f2ti"
BurstCreditBalance
```

also inspect.

If:

```text id="dqlu5l"
MeteredIOBytes
≈
PermittedThroughput
```

you may be consuming the available throughput ceiling. AWS specifically recommends this comparison when diagnosing throughput pressure. ([AWS Documentation][15])

---

# 50. Scenario — Filesystem “Slow” but Throughput Is Low

Suppose:

```text id="hqu8xp"
throughput low
PercentIOLimit high
metadata operations huge
```

Possible issue:

```text id="hik8i7"
millions of tiny operations
```

rather than:

```text id="w9ms9t"
raw data throughput
```

This is why:

```text id="pnjg8c"
IOPS-like operation rate
metadata behavior
throughput
```

must be distinguished.

Storage engineering is about workload shape, not just MB/s.

---

# 51. Terraform Output Helpers

Useful outputs:

```hcl id="lgyd29"
output "efs_id" {
  value = aws_efs_file_system.app.id
}

output "efs_dns_name" {
  value = aws_efs_file_system.app.dns_name
}

output "access_point_id" {
  value = aws_efs_access_point.app.id
}
```

Then:

```bash id="fs494d"
terraform output -raw efs_id
```

can feed your validation scripts.

---

# 52. Cost Cleanup

This lab can create billable resources.

Destroy test compute, NAT/ALB if used, and the EFS filesystem after you've deleted any files you no longer need.

Terraform:

```bash id="60tajm"
terraform plan -destroy
```

then:

```bash id="qug5wd"
terraform destroy
```

Verify:

```bash id="ybvbzd"
terraform state list
```

and:

```bash id="zti9iw"
aws efs describe-file-systems \
  --region ap-south-1
```

Do not leave storage resources running simply because the EC2 lab is finished.

---

# 53. Interview Question

> An Auto Scaling application needs a persistent shared filesystem. How would you secure and operate EFS?

Strong answer:

> I'd use a Regional EFS filesystem with mount targets in the Availability Zones where the compute fleet runs. I'd restrict NFS TCP/2049 using security-group-to-security-group rules, use the EFS mount helper with TLS for encryption in transit, and enable encryption at rest. For application isolation I'd use EFS Access Points to enforce application-specific root directories and POSIX identities. Where stronger identity control is required I'd use IAM client authorization and restrict the role to the intended Access Point. I'd monitor client connections, I/O, permitted throughput, PercentIOLimit and relevant burst metrics, and I'd protect the filesystem with AWS Backup and, where DR requirements justify it, EFS replication. ([AWS Documentation][10])

That is an architecture answer, not merely:

> “Use EFS.”

---

# 54. Never-Forget Troubleshooting Map

```text id="74tuw7"
                   EFS PROBLEM
                       │
              ┌────────┼────────┐
              │        │        │
              ▼        ▼        ▼
           NETWORK   AUTH     PERFORMANCE
              │        │        │
         Mount target  IAM    PercentIOLimit
         SG 2049       AP     PermittedThroughput
         DNS           POSIX  BurstCreditBalance
         routes        UID    Metadata IO
              │        GID       │
              └────────┼─────────┘
                       ▼
                   APPLICATION
```

---

# 55. The Most Important EFS Rules

```text id="pqbwhy"
1. EFS is shared file storage, not block storage.

2. EFS uses NFS.

3. Regional EFS gives multi-AZ filesystem resilience.

4. Mount Target = network endpoint.

5. Access Point = application filesystem entry point.

6. TCP 2049 = NFS.

7. SG working does not mean POSIX permissions work.

8. Mount success + write denied = usually authorization/permissions.

9. Use _netdev for automatic EFS mounts.

10. Validate the mount before starting a dependent application.

11. IAM mounting requires the EFS mount helper.

12. Access Points can enforce UID/GID and root directory.

13. Elastic throughput fits variable workloads.

14. CloudWatch tells you whether throughput/I/O is constrained.

15. Backup and replication solve different failure problems.
```

And memorize this:

```text id="1e2e0q"
EBS
=
one machine needs a disk


EFS
=
many machines need one filesystem


S3
=
applications need object storage
```

---

# ✅ Lesson 26 Progress

We have now covered almost the entire EFS lifecycle:

```text id="15cupx"
✓ EFS fundamentals
✓ NFS
✓ Regional / One Zone
✓ mount targets
✓ TCP 2049
✓ security groups
✓ shared writes
✓ TLS
✓ /etc/fstab
✓ _netdev
✓ Auto Scaling bootstrap
✓ mount validation
✓ Access Points
✓ POSIX identity
✓ IAM ClientMount
✓ IAM ClientWrite
✓ file-system policies
✓ AccessPointArn restrictions
✓ CloudWatch
✓ ClientConnections
✓ DataReadIOBytes
✓ DataWriteIOBytes
✓ MeteredIOBytes
✓ PermittedThroughput
✓ PercentIOLimit
✓ BurstCreditBalance
✓ metadata-heavy workloads
✓ mount troubleshooting
✓ IAM troubleshooting
✓ ASG replacement loops
✓ ECS integration
✓ EKS mental model
✓ AWS Backup
✓ replication
✓ DR design
✓ EFS vs FSx
✓ production architecture selection
```

# Next — Lesson 26 Part 3

The final EFS section will go into the advanced cases that appear in production and certification scenarios:

```text id="n3rtml"
EFS ADVANCED OPERATIONS

→ NFS caching behavior
→ file locking
→ consistency semantics
→ many-small-files problem
→ client parallelism
→ max throughput considerations
→ cross-VPC mounting
→ VPC peering
→ Transit Gateway
→ on-premises access
→ Direct Connect / VPN
→ Route 53 DNS behavior
→ cross-account EFS
→ EFS file-system policies in depth
→ root squash / ClientRootAccess concepts
→ Lambda + EFS
→ ECS/Fargate detailed architecture
→ Kubernetes ReadWriteMany
→ AWS Backup restore drill
→ replication failover/failback
→ final Terraform architecture
→ final EFS lab
→ SAA-C03 / DOP-C02 revision
```

After that, Lesson 26 will be closed and we'll move to the next AWS storage layer in our masterclass flow.

[1]: https://docs.aws.amazon.com/efs/latest/ug/disaster-recovery-resiliency.html?utm_source=chatgpt.com "Resilience in Amazon EFS - Amazon Elastic File System"
[2]: https://registry.terraform.io/providers/hashicorp/awS/latest/docs/resources/efs_file_system?utm_source=chatgpt.com "aws_efs_file_system | Resources | hashicorp/aws | Terraform"
[3]: https://docs.aws.amazon.com/efs/latest/ug/performance.html?utm_source=chatgpt.com "Amazon EFS performance specifications"
[4]: https://docs.aws.amazon.com/efs/latest/ug/troubleshooting-efs-mounting.html?utm_source=chatgpt.com "Troubleshooting mount issues - Amazon Elastic File System"
[5]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target?utm_source=chatgpt.com "aws_efs_mount_target | Resources | hashicorp/aws | Terraform"
[6]: https://docs.aws.amazon.com/efs/latest/ug/mounting-fs.html?utm_source=chatgpt.com "Mounting EFS file systems"
[7]: https://docs.aws.amazon.com/efs/latest/ug/efs-mount-helper.html?utm_source=chatgpt.com "Mounting EFS file systems using the EFS mount helper"
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point?utm_source=chatgpt.com "aws_efs_access_point | Resources | hashicorp/aws | Terraform"
[9]: https://docs.aws.amazon.com/efs/latest/ug/mounting-access-points.html?utm_source=chatgpt.com "Mounting with EFS access points"
[10]: https://docs.aws.amazon.com/efs/latest/ug/efs-access-points.html?utm_source=chatgpt.com "Working with access points - Amazon Elastic File System"
[11]: https://docs.aws.amazon.com/efs/latest/ug/iam-access-control-nfs-efs.html?utm_source=chatgpt.com "Using IAM to control access to file systems"
[12]: https://docs.aws.amazon.com/efs/latest/ug/mounting-IAM-option.html?utm_source=chatgpt.com "Mounting with IAM authorization"
[13]: https://docs.aws.amazon.com/efs/latest/ug/access-points-iam-policy.html?utm_source=chatgpt.com "Using access points in IAM policies"
[14]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system_policy?utm_source=chatgpt.com "aws_efs_file_system_policy | Resources | hashicorp/aws"
[15]: https://docs.aws.amazon.com/efs/latest/ug/efs-metrics.html?utm_source=chatgpt.com "CloudWatch metrics for Amazon EFS"
[16]: https://docs.aws.amazon.com/ja_jp/efs/latest/ug/efs-metrics.html?utm_source=chatgpt.com "Amazon EFS の CloudWatch メトリクス - Amazon Elastic File System"
[17]: https://docs.aws.amazon.com/es_es/efs/latest/ug/efs-metrics.html?utm_source=chatgpt.com "CloudWatch métricas de Amazon EFS - AWS Documentation"
[18]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html?utm_source=chatgpt.com "Use Amazon EFS volumes with Amazon ECS"
[19]: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html?utm_source=chatgpt.com "Amazon ECS task definition parameters for Fargate"
[20]: https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html?utm_source=chatgpt.com "Backing up EFS file systems"
[21]: https://docs.aws.amazon.com/efs/latest/ug/efs-replication.html?utm_source=chatgpt.com "Replicating EFS file systems"
[22]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restoring-efs.html?utm_source=chatgpt.com "Restore an Amazon EFS file system - AWS Backup"
