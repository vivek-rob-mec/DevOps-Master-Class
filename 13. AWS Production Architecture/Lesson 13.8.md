# AWS Masterclass — Lesson 7

## Storage From Zero to Production — S3, EBS, EFS, FSx, Glacier, Storage Gateway, AWS Backup, Encryption, Versioning, Lifecycle, and Static Content

Today we learn **AWS storage deeply**.

This is a core AWS topic for **CLF-C02, SAA-C03, DOP-C02**, and real production work. Your uploaded architect course explicitly includes **S3, S3 Glacier, EBS, EFS, FSx, Storage Gateway, and AWS Backup** in the storage section . Your AWS Academy Cloud Developing outline also includes “Developing Storage Solutions with Amazon S3,” including S3 buckets, objects, access protection, object operations like `PUT`, `GET`, `SELECT`, and `DELETE`, and S3 SDK-based labs .

---

# 1. Why storage matters

Every application needs storage.

Examples:

```text id="storage-examples"
Website:
  images, CSS, JavaScript, videos

EC2 server:
  operating system disk, logs, app files

Database:
  persistent data files

Analytics:
  raw data, processed data, reports

Backup:
  snapshots, archives, disaster recovery copies

Hybrid cloud:
  on-prem files copied/synced to AWS
```

Wrong storage choice causes:

```text id="wrong-storage"
high cost
slow app
data loss
bad backup strategy
security exposure
migration failure
scaling problems
```

So the real architect question is not:

```text id="bad-question"
Where can I upload this file?
```

The correct architect question is:

```text id="good-question"
What type of data is this, how is it accessed, how fast must it be retrieved, who needs access, how long must it be retained, and what failure/recovery requirement exists?
```

---

# 2. Three main storage types

AWS storage becomes easy when you understand these three types:

```text id="three-types"
Object storage:
  S3

Block storage:
  EBS

File storage:
  EFS / FSx
```

## Simple comparison

| Storage type   | AWS service | Think of it as                       | Best for                                       |
| -------------- | ----------- | ------------------------------------ | ---------------------------------------------- |
| Object storage | S3          | internet-scale file/object warehouse | images, backups, logs, static files, data lake |
| Block storage  | EBS         | hard disk attached to one EC2        | OS disk, database disk, app disk               |
| File storage   | EFS / FSx   | shared network file system           | shared files across servers                    |

---

# 3. Object storage — Amazon S3

## What is S3?

S3 means:

```text id="s3-full"
Simple Storage Service
```

Simple meaning:

```text id="s3-simple"
S3 is object storage for storing files as objects inside buckets.
```

AWS describes Amazon S3 as an object storage service where data is stored as objects inside buckets; to store data, you create a bucket, choose a bucket name and Region, and upload objects. ([AWS Documentation][1])

Think:

```text id="s3-analogy"
S3 bucket:
  giant storage container

S3 object:
  one file plus metadata

Object key:
  path/name of the object
```

Example:

```text id="s3-example"
Bucket:
  my-app-assets

Object key:
  images/logo.png

Full S3 URI:
  s3://my-app-assets/images/logo.png
```

---

# 4. S3 bucket vs object vs key

## Bucket

A bucket is the top-level container.

```text id="bucket"
Bucket:
  my-company-prod-assets
```

A bucket belongs to:

```text id="bucket-belongs"
one AWS account
one AWS Region
```

## Object

An object is the actual stored item.

```text id="object"
logo.png
invoice.pdf
backup.tar.gz
logs/2026/07/24/app.log
```

## Key

A key is the object’s full name/path inside bucket.

```text id="key"
images/logo.png
reports/2026/july/report.csv
```

Important:

```text id="s3-folder"
S3 does not work like a traditional folder-based file system.
The console shows folder-like paths, but technically they are object keys with prefixes.
```

---

# 5. S3 operations

The main S3 operations are:

```text id="s3-ops"
PUT:
  upload object

GET:
  download/read object

DELETE:
  delete object

LIST:
  list objects

COPY:
  copy object

HEAD:
  read object metadata
```

This aligns with the AWS Academy outline, which specifically mentions S3 object operations such as `PUT`, `GET`, `SELECT`, and `DELETE` as part of S3 learning objectives .

Example:

```bash id="s3-commands"
aws s3 cp file.txt s3://my-bucket/file.txt
aws s3 cp s3://my-bucket/file.txt .
aws s3 ls s3://my-bucket/
aws s3 rm s3://my-bucket/file.txt
```

---

# 6. S3 is not a disk

Never confuse:

```text id="s3-not-disk"
S3 is not EBS.
S3 is not a mounted Linux disk by default.
S3 is object storage.
```

You do not normally do:

```bash id="bad-s3"
cd s3://my-bucket
vim file.txt
```

Instead, applications use:

```text id="s3-access"
AWS SDK
AWS CLI
S3 API
CloudFront
pre-signed URLs
S3 event notifications
```

Good use cases:

```text id="s3-good"
static website assets
images/videos/documents
backups
logs
data lakes
Terraform state
CloudTrail logs
ALB logs
Athena query data
ML datasets
archive data
```

Bad use cases:

```text id="s3-bad"
OS root disk
low-latency database disk
file system requiring POSIX locking
frequently modified tiny random-write files
```

---

# 7. S3 durability and availability idea

S3 is designed for very high durability.

Simple difference:

```text id="durability-availability"
Durability:
  Will my data be lost?

Availability:
  Can I access my data right now?
```

Example:

```text id="durability-example"
Durability problem:
  object disappears forever

Availability problem:
  object exists, but temporarily cannot be accessed
```

Architect mindset:

```text id="durability-mindset"
Backups need durability.
Websites need availability.
Critical systems need both.
```

---

# 8. S3 storage classes

S3 has multiple storage classes. You choose based on access pattern.

AWS documentation says S3 storage classes can be selected when uploading objects, and S3 Lifecycle can transition objects to other storage classes such as Standard-IA, One Zone-IA, Glacier Flexible Retrieval, and Glacier Deep Archive. ([AWS Documentation][2])

| Storage class                 | Simple meaning                   | Use case                                    |
| ----------------------------- | -------------------------------- | ------------------------------------------- |
| S3 Standard                   | frequent access                  | active files, websites, app assets          |
| S3 Intelligent-Tiering        | unknown/changing access          | data with unpredictable access              |
| S3 Standard-IA                | infrequent access                | monthly reports, backups accessed sometimes |
| S3 One Zone-IA                | infrequent, lower resilience     | reproducible/non-critical data              |
| S3 Glacier Instant Retrieval  | archive, milliseconds access     | archive that may need fast reads            |
| S3 Glacier Flexible Retrieval | archive, minutes/hours retrieval | backup/DR archive                           |
| S3 Glacier Deep Archive       | lowest-cost long-term archive    | compliance archive, rarely retrieved        |

Never confuse:

```text id="storage-class-rule"
S3 Standard:
  use now

S3 IA:
  use sometimes

S3 Glacier:
  archive

S3 Glacier Deep Archive:
  long-term cold archive
```

---

# 9. S3 Glacier

S3 Glacier is not for normal website images.

It is for archive.

Examples:

```text id="glacier-examples"
financial records
medical records
compliance archive
old backups
raw footage archive
legal retention data
```

AWS documentation describes S3 Glacier storage classes as long-term data storage options, including Glacier Instant Retrieval, Glacier Flexible Retrieval, and Glacier Deep Archive. ([AWS Documentation][3])

Important:

```text id="glacier-warning"
Glacier Flexible Retrieval and Deep Archive objects may require a restore request before normal access.
```

AWS documentation says that for objects in S3 Glacier Flexible Retrieval and S3 Glacier Deep Archive, you must initiate a restore request and wait until a temporary copy is available. ([AWS Documentation][4])

Exam memory:

```text id="glacier-memory"
Need instant archive access:
  Glacier Instant Retrieval

Can wait minutes/hours:
  Glacier Flexible Retrieval

Can wait longest and want lowest archive cost:
  Glacier Deep Archive
```

---

# 10. S3 lifecycle rules

Lifecycle rules automate object movement or deletion.

Example:

```text id="lifecycle-example"
Day 0:
  upload logs to S3 Standard

After 30 days:
  move to Standard-IA

After 90 days:
  move to Glacier Flexible Retrieval

After 365 days:
  delete
```

AWS says S3 Lifecycle rules can transition objects to less-expensive storage classes, archive them, or delete them. ([AWS Documentation][5])

Use lifecycle rules for:

```text id="lifecycle-use"
logs
backups
reports
old images
compliance retention
cost optimization
```

---

# 11. S3 versioning

Versioning keeps multiple versions of an object.

Example:

```text id="versioning"
You upload:
  config.json

Then overwrite:
  config.json

Without versioning:
  old file gone

With versioning:
  old version still recoverable
```

Use versioning for:

```text id="versioning-use"
important app assets
Terraform state bucket
compliance data
accidental overwrite protection
backup workflows
```

Warning:

```text id="versioning-warning"
Versioning can increase cost because old versions are also stored.
Use lifecycle rules for old versions.
```

---

# 12. S3 encryption

Encryption means data is protected cryptographically.

Two simple states:

```text id="encryption-states"
Encryption at rest:
  stored data encrypted

Encryption in transit:
  data protected over network using HTTPS/TLS
```

S3 server-side encryption options:

```text id="s3-encryption"
SSE-S3:
  S3-managed keys

SSE-KMS:
  AWS KMS-managed keys

SSE-C:
  customer-provided keys
```

Production default:

```text id="s3-prod-encryption"
Use SSE-S3 for simple workloads.
Use SSE-KMS when you need key control, audit, rotation, or compliance.
```

---

# 13. S3 access control

S3 access can be controlled by:

```text id="s3-access"
IAM policies
bucket policies
access point policies
Block Public Access
Object Ownership
KMS key policies
pre-signed URLs
CloudFront OAC
```

For new buckets, AWS says Block Public Access settings are enabled by default, and S3 Block Public Access helps prevent settings that allow public access. ([AWS Documentation][6])

AWS also says S3 Object Ownership is set to **Bucket owner enforced** by default for new buckets, which disables ACLs. ([AWS Documentation][7])

Production rule:

```text id="s3-access-rule"
Keep S3 private by default.
Use CloudFront OAC for public website delivery.
Use pre-signed URLs for temporary private downloads.
Avoid public buckets unless there is a very clear reason.
```

---

# 14. Pre-signed URL

A pre-signed URL gives temporary access to a private S3 object.

Example:

```text id="presigned-example"
Private object:
  invoice.pdf

Generate URL valid for:
  10 minutes

User downloads using temporary URL.
```

Use case:

```text id="presigned-use"
private file download
temporary upload permission
customer invoice download
secure document sharing
```

Architect rule:

```text id="presigned-rule"
Do not make entire bucket public just because one user needs one file.
Use pre-signed URLs.
```

---

# 15. Static website hosting: S3 vs CloudFront

S3 can host static websites, but production public delivery should usually use CloudFront in front.

Two patterns:

## Simple beginner pattern

```text id="simple-static"
User
  ↓
S3 static website endpoint
```

Problem:

```text id="simple-static-problem"
Public bucket access is required.
HTTPS with custom domain is not as clean as CloudFront.
Less control over caching/security.
```

## Production pattern

```text id="prod-static"
User
  ↓ HTTPS
CloudFront
  ↓ OAC
Private S3 bucket
```

Production rule:

```text id="static-rule"
For public static websites:
  CloudFront + private S3 + OAC

For private objects:
  private S3 + IAM/pre-signed URL
```

We will build the CloudFront + S3 version in the CloudFront/domain lesson.

---

# 16. Block storage — Amazon EBS

## What is EBS?

EBS means:

```text id="ebs-full"
Elastic Block Store
```

Simple meaning:

```text id="ebs-simple"
EBS is a virtual disk for EC2.
```

AWS describes Amazon EBS as scalable, high-performance block storage for EC2 instances. ([AWS Documentation][8])

Think:

```text id="ebs-analogy"
EC2:
  computer

EBS:
  hard disk / SSD attached to that computer
```

Examples:

```text id="ebs-examples"
Ubuntu root disk
database data disk
application storage disk
Docker host disk
log processing disk
```

---

# 17. EBS volume types

AWS documentation lists EBS volume types including General Purpose SSD `gp2/gp3`, Provisioned IOPS SSD `io1/io2`, Throughput Optimized HDD `st1`, Cold HDD `sc1`, and older Magnetic `standard`. ([AWS Documentation][9])

| EBS type | Simple meaning      | Use case                    |
| -------- | ------------------- | --------------------------- |
| gp3      | default general SSD | most EC2 workloads          |
| gp2      | older general SSD   | legacy workloads            |
| io2      | high IOPS SSD       | critical database/high IOPS |
| st1      | throughput HDD      | big sequential workloads    |
| sc1      | cold HDD            | low-cost infrequent access  |

Production default:

```text id="ebs-default"
Use gp3 unless workload clearly needs io2, st1, or sc1.
```

---

# 18. EBS snapshots

A snapshot is a backup of an EBS volume.

AWS says EBS snapshots are point-in-time backups that persist independently from the volume. ([AWS Documentation][8])

Use snapshots for:

```text id="snapshot-use"
backup
restore
copy volume to another AZ/Region
create AMI
disaster recovery
before risky changes
```

Important:

```text id="snapshot-note"
Snapshot is not the same as live high availability.
Snapshot helps recovery, not instant failover by itself.
```

---

# 19. EBS vs instance store

Never confuse:

```text id="ebs-vs-instance-store"
EBS:
  persistent block storage

Instance store:
  temporary local storage on certain instance types
```

Use EBS for:

```text id="ebs-use"
OS disk
important data
database disk
persistent app storage
```

Use instance store for:

```text id="instance-store-use"
temporary cache
scratch data
high-speed temporary processing
```

---

# 20. File storage — Amazon EFS

## What is EFS?

EFS means:

```text id="efs-full"
Elastic File System
```

Simple meaning:

```text id="efs-simple"
EFS is shared Linux file storage that multiple EC2 instances can mount at the same time.
```

AWS describes EFS as serverless, fully elastic file storage that lets you share file data without provisioning or managing storage capacity and performance. ([AWS Documentation][10])

Think:

```text id="efs-analogy"
EFS = shared network folder for Linux servers
```

Example:

```text id="efs-example"
EC2 instance A mounts /shared
EC2 instance B mounts /shared
Both see same files
```

Good use cases:

```text id="efs-good"
shared uploads folder
shared CMS files
Linux shared home directories
container shared persistent storage
EKS persistent volumes
multi-instance app shared files
```

Bad use cases:

```text id="efs-bad"
single EC2 root disk
high-performance database disk
Windows SMB workloads
ultra-low-latency local disk workloads
```

---

# 21. EFS mount targets

EFS is accessed through mount targets in subnets.

Production pattern:

```text id="efs-mount-targets"
Create EFS mount target in each AZ
where EC2 instances need access.
```

Security:

```text id="efs-security"
EFS security group allows NFS port 2049
from EC2 app security group.
```

Never open EFS to the internet.

---

# 22. File storage — Amazon FSx

## What is FSx?

FSx is managed file storage for specific file system technologies.

AWS FSx documentation includes managed file systems such as FSx for Windows File Server, FSx for NetApp ONTAP, FSx for OpenZFS, and FSx for Lustre. ([AWS Documentation][11])

Simple meaning:

```text id="fsx-simple"
FSx gives you fully managed specialized file systems.
```

Use cases:

| FSx type                    | Best for                                               |
| --------------------------- | ------------------------------------------------------ |
| FSx for Windows File Server | Windows SMB shares, Active Directory integration       |
| FSx for Lustre              | high-performance compute, ML, HPC                      |
| FSx for NetApp ONTAP        | enterprise NAS, snapshots, replication, hybrid storage |
| FSx for OpenZFS             | managed OpenZFS workloads                              |

Rule:

```text id="fsx-rule"
Linux shared general files:
  EFS

Windows file share:
  FSx for Windows File Server

HPC/ML high-performance file system:
  FSx for Lustre

Enterprise NetApp-style NAS:
  FSx for NetApp ONTAP
```

---

# 23. Hybrid storage — Storage Gateway

Storage Gateway connects on-premises environments to AWS storage.

Simple meaning:

```text id="storage-gateway-simple"
Storage Gateway lets on-premise applications use AWS storage through familiar storage protocols.
```

Use cases:

```text id="storage-gateway-use"
on-prem backup to AWS
file share backed by S3
tape replacement
hybrid migration
gradual cloud adoption
```

We will go deeper during hybrid/migration lessons.

For now, remember:

```text id="gateway-memory"
Storage Gateway is for hybrid storage.
It is not the same as S3, EBS, or EFS.
```

---

# 24. AWS Backup

AWS Backup centralizes backup management.

AWS describes AWS Backup as a fully managed backup service that centralizes and automates backup of data across AWS services and on-premises. ([AWS Documentation][12])

Simple meaning:

```text id="backup-simple"
AWS Backup = central backup policy manager.
```

It helps manage backups for services such as:

```text id="backup-services"
EBS
EFS
RDS
DynamoDB
S3
FSx
Storage Gateway
VMware workloads
```

AWS Backup uses backup plans, which define when and how AWS resources are backed up. ([AWS Documentation][13])

Production backup terms:

```text id="backup-terms"
Backup plan:
  schedule and lifecycle policy

Backup vault:
  storage container for recovery points

Recovery point:
  backup copy you can restore from

Retention:
  how long backup is kept

Cross-Region copy:
  disaster recovery copy in another Region

Cross-account copy:
  protection from account-level issue
```

---

# 25. Main storage decision table

| Requirement                         | Choose                              |
| ----------------------------------- | ----------------------------------- |
| Store images, videos, logs, backups | S3                                  |
| Static website assets               | S3 + CloudFront                     |
| EC2 operating system disk           | EBS                                 |
| EC2 database disk                   | EBS, usually io2/gp3 depending need |
| Shared Linux files across EC2       | EFS                                 |
| Windows file share                  | FSx for Windows File Server         |
| HPC/ML high-performance file system | FSx for Lustre                      |
| Long-term archive                   | S3 Glacier classes                  |
| On-prem file/tape integration       | Storage Gateway                     |
| Centralized backup policy           | AWS Backup                          |

---

# 26. Storage design by application type

## Static website

```text id="static-website"
S3:
  static files

CloudFront:
  HTTPS, caching, global delivery

ACM:
  TLS certificate

Route 53:
  domain DNS
```

## EC2 web app

```text id="ec2-web-storage"
EBS:
  OS and app disk

S3:
  uploaded files, assets, logs

RDS:
  structured database

Backup:
  EBS snapshots / AWS Backup
```

## Multi-EC2 CMS

```text id="cms"
EBS:
  OS disk per instance

EFS:
  shared uploads folder

RDS:
  database

S3:
  backups/static assets
```

## Data lake

```text id="data-lake"
S3:
  raw/processed/curated data

Glue:
  catalog/ETL

Athena:
  query

Lifecycle:
  move old data to Glacier
```

## Hybrid backup

```text id="hybrid-backup"
Storage Gateway:
  on-prem integration

S3:
  storage backend

AWS Backup:
  backup policy

Glacier:
  long-term archive
```

---

# 27. Security rules for storage

## S3

```text id="s3-security"
Block Public Access enabled
bucket private by default
SSE-S3 or SSE-KMS encryption
least-privilege IAM
bucket policy only when needed
access logs / CloudTrail where required
versioning for critical buckets
lifecycle for old versions
CloudFront OAC for public delivery
```

## EBS

```text id="ebs-security"
encrypt volumes
snapshot strategy
restrict EC2 IAM permissions
avoid storing secrets in plain text
monitor disk usage
delete unused volumes
```

## EFS

```text id="efs-security"
mount targets in private subnets
security group allows NFS only from app SG
encryption at rest
encryption in transit where required
access points for app-specific paths/users
```

## FSx

```text id="fsx-security"
private subnet placement
security groups
directory integration if Windows
encryption
backup policy
least-privilege access
```

---

# 28. Cost rules for storage

Storage cost mistakes are very common.

```text id="cost-mistakes"
old S3 versions kept forever
forgotten EBS volumes
forgotten EBS snapshots
NAT cost for S3 access instead of S3 gateway endpoint
EFS left unused
FSx provisioned and forgotten
Glacier retrieval surprises
logs stored forever in Standard
```

Cost optimization:

```text id="cost-optimization"
S3 lifecycle rules
S3 Intelligent-Tiering for unknown access
delete unused EBS volumes
snapshot lifecycle policies
use gp3 instead of older gp2 where appropriate
right-size EFS/FSx
archive old logs
set budgets
tag resources
```

---

# 29. Hands-On Lab 7A — Secure S3 Bucket With Versioning, Encryption, Lifecycle, and Pre-Signed URL

This lab creates a small S3 bucket and uploads one tiny file.

Cost:

```text id="lab-cost"
Very low for a tiny object, but still clean up after the lab.
No EC2, no NAT, no ALB.
```

Region:

```text id="lab-region"
ap-south-1
```

---

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

---

## Step 2 — Create a globally unique bucket name

S3 bucket names must be unique globally, so include your account ID and timestamp.

```bash id="bucket-name"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TS="$(date +%Y%m%d%H%M%S)"

BUCKET="aws-masterclass-storage-${ACCOUNT_ID}-${TS}"

echo "$BUCKET"
```

---

## Step 3 — Create bucket in ap-south-1

```bash id="create-bucket"
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

Tag bucket:

```bash id="tag-bucket"
aws s3api put-bucket-tagging \
  --bucket "$BUCKET" \
  --tagging '{
    "TagSet": [
      {"Key": "Project", "Value": "aws-masterclass"},
      {"Key": "Environment", "Value": "dev"},
      {"Key": "Owner", "Value": "vivek"}
    ]
  }'
```

---

## Step 4 — Block public access

```bash id="block-public"
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

Validate:

```bash id="validate-public-block"
aws s3api get-public-access-block \
  --bucket "$BUCKET"
```

---

## Step 5 — Enable default encryption

Use SSE-S3 for this lab.

```bash id="encryption"
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'
```

Validate:

```bash id="validate-encryption"
aws s3api get-bucket-encryption \
  --bucket "$BUCKET"
```

---

## Step 6 — Enable versioning

```bash id="versioning"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```

Validate:

```bash id="validate-versioning"
aws s3api get-bucket-versioning \
  --bucket "$BUCKET"
```

---

## Step 7 — Create and upload a file

```bash id="upload-file"
mkdir -p /tmp/aws-masterclass-storage

cat > /tmp/aws-masterclass-storage/hello.txt <<'EOF'
Hello from secure Amazon S3.
This object is private, encrypted, and versioned.
EOF

aws s3 cp /tmp/aws-masterclass-storage/hello.txt "s3://$BUCKET/secure/hello.txt"
```

List:

```bash id="list-bucket"
aws s3 ls "s3://$BUCKET/secure/"
```

Get metadata:

```bash id="head-object"
aws s3api head-object \
  --bucket "$BUCKET" \
  --key secure/hello.txt
```

---

## Step 8 — Overwrite file to create another version

```bash id="overwrite-file"
cat > /tmp/aws-masterclass-storage/hello.txt <<'EOF'
Hello from secure Amazon S3.
This is version 2 of the object.
EOF

aws s3 cp /tmp/aws-masterclass-storage/hello.txt "s3://$BUCKET/secure/hello.txt"
```

List versions:

```bash id="list-versions"
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix secure/hello.txt \
  --query 'Versions[].{Key:Key,VersionId:VersionId,IsLatest:IsLatest,LastModified:LastModified,Size:Size}' \
  --output table
```

---

## Step 9 — Create lifecycle rule

This rule deletes noncurrent versions after 7 days and aborts incomplete multipart uploads after 1 day.

```bash id="lifecycle"
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "cleanup-old-versions-and-incomplete-uploads",
        "Status": "Enabled",
        "Filter": {
          "Prefix": ""
        },
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 7
        },
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 1
        }
      }
    ]
  }'
```

Validate:

```bash id="validate-lifecycle"
aws s3api get-bucket-lifecycle-configuration \
  --bucket "$BUCKET"
```

---

## Step 10 — Generate a pre-signed URL

The bucket is private, but we can create temporary access.

```bash id="presign"
aws s3 presign "s3://$BUCKET/secure/hello.txt" \
  --expires-in 300
```

Open the generated URL within 5 minutes.

Meaning:

```text id="presign-meaning"
Object remains private.
Temporary URL gives limited-time access.
```

---

# 30. Validate S3 security

Check that public access is blocked:

```bash id="check-public-access"
aws s3api get-public-access-block \
  --bucket "$BUCKET" \
  --query 'PublicAccessBlockConfiguration' \
  --output table
```

Check encryption:

```bash id="check-encryption"
aws s3api get-bucket-encryption \
  --bucket "$BUCKET" \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault' \
  --output table
```

Check versioning:

```bash id="check-versioning"
aws s3api get-bucket-versioning \
  --bucket "$BUCKET" \
  --output table
```

Check objects:

```bash id="check-objects"
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix secure/
```

---

# 31. Cleanup Lab 7A

Because versioning is enabled, normal delete is not enough. You must delete all object versions and delete markers.

## Step 1 — Remove all versions and delete markers

```bash id="cleanup-versions"
aws s3api delete-objects \
  --bucket "$BUCKET" \
  --delete "$(
    aws s3api list-object-versions \
      --bucket "$BUCKET" \
      --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
      --output json
  )" || true

aws s3api delete-objects \
  --bucket "$BUCKET" \
  --delete "$(
    aws s3api list-object-versions \
      --bucket "$BUCKET" \
      --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
      --output json
  )" || true
```

If the command complains about `null`, run this safer version:

```bash id="safe-cleanup-python"
python3 - <<'PY'
import json
import os
import subprocess

bucket = os.environ["BUCKET"]

versions = subprocess.check_output([
    "aws", "s3api", "list-object-versions",
    "--bucket", bucket
], text=True)

data = json.loads(versions)
objects = []

for item in data.get("Versions", []):
    objects.append({"Key": item["Key"], "VersionId": item["VersionId"]})

for item in data.get("DeleteMarkers", []):
    objects.append({"Key": item["Key"], "VersionId": item["VersionId"]})

if objects:
    payload = json.dumps({"Objects": objects})
    subprocess.run([
        "aws", "s3api", "delete-objects",
        "--bucket", bucket,
        "--delete", payload
    ], check=True)
else:
    print("No versions/delete markers found.")
PY
```

## Step 2 — Delete bucket

```bash id="delete-bucket"
aws s3api delete-bucket \
  --bucket "$BUCKET" \
  --region ap-south-1
```

Verify:

```bash id="verify-delete"
aws s3api list-buckets \
  --query "Buckets[?Name=='$BUCKET']"
```

---

# 32. Common S3 errors and fixes

## Error 1 — BucketAlreadyExists

Meaning:

```text id="bucketexists"
Bucket name is already used globally by another AWS account.
```

Fix:

```text id="bucketexists-fix"
Use a more unique bucket name with account ID and timestamp.
```

---

## Error 2 — AccessDenied

Common causes:

```text id="accessdenied-causes"
IAM policy missing permission
bucket policy denies access
KMS key policy denies encryption/decryption
Block Public Access blocks public policy/ACL
wrong AWS profile/account
```

Debug:

```bash id="debug-identity"
aws sts get-caller-identity
```

---

## Error 3 — Cannot delete bucket

Common causes:

```text id="delete-causes"
bucket not empty
versioned objects still exist
delete markers still exist
multipart uploads exist
```

Fix:

```text id="delete-fix"
Delete all object versions and delete markers before deleting bucket.
```

---

## Error 4 — Website object not public

Cause:

```text id="public-cause"
Bucket is private or Block Public Access is enabled.
```

Production fix:

```text id="public-fix"
Do not make bucket public.
Use CloudFront with OAC.
```

---

## Error 5 — Glacier object cannot download immediately

Cause:

```text id="glacier-cause"
Object is archived in Glacier Flexible Retrieval or Deep Archive.
```

Fix:

```text id="glacier-fix"
Initiate restore request and wait for temporary copy.
```

---

# 33. Storage troubleshooting checklist

When storage fails, ask:

```text id="troubleshooting"
1. What storage type is this: object, block, or file?
2. Is the resource in the expected Region?
3. Is the IAM caller correct?
4. Is there an identity policy allow?
5. Is there a resource policy deny?
6. Is KMS involved?
7. Is public access blocked?
8. Is versioning involved?
9. Is lifecycle involved?
10. Is object archived in Glacier?
11. Is network access required?
12. Is the file system mounted?
13. Is the security group allowing file protocol?
14. Is there a backup/snapshot?
15. Is cost increasing due to old versions/snapshots?
```

---

# 34. Certification angle

## CLF-C02

Know:

```text id="clf"
S3 is object storage.
EBS is block storage for EC2.
EFS is shared file storage.
S3 Glacier is archive storage.
AWS Backup centralizes backups.
S3 storage classes optimize cost.
```

## SAA-C03

Know deeply:

```text id="saa"
when to use S3 vs EBS vs EFS vs FSx
S3 lifecycle rules
S3 versioning
S3 encryption
S3 Block Public Access
CloudFront + private S3 + OAC
EBS volume types
EBS snapshots
EFS mount targets
FSx use cases
backup and restore design
cross-Region backup decisions
```

## DOP-C02

Know operationally:

```text id="dop"
backup automation
snapshot lifecycle
S3 lifecycle policies
Terraform state bucket hardening
log retention
KMS troubleshooting
EBS volume expansion
restore testing
storage monitoring
cost cleanup
```

---

# 35. Interview answer

Memorize this:

```text id="interview-answer"
AWS storage can be divided into object, block, and file storage. Amazon S3 is object storage used for static assets, backups, logs, data lakes, and archives. Amazon EBS is block storage attached to EC2 instances and is used for operating system disks, application disks, and database storage. Amazon EFS is shared Linux file storage that multiple EC2 instances can mount at the same time. Amazon FSx provides managed specialized file systems such as Windows File Server, Lustre, NetApp ONTAP, and OpenZFS.

For production, I keep S3 private by default, enable Block Public Access, use encryption, enable versioning for critical buckets, and use lifecycle rules to move old data to cheaper storage or delete it. For public static content, I prefer CloudFront with a private S3 bucket and Origin Access Control instead of making the bucket public. For EC2 disks, I usually start with encrypted gp3 EBS volumes and use snapshots or AWS Backup for recovery. For shared file workloads, I choose EFS or FSx depending on Linux, Windows, HPC, or enterprise NAS requirements.
```

---

# 36. Quick quiz

```text id="quiz"
1. What is object storage?
2. Which AWS service is object storage?
3. What is block storage?
4. Which AWS service is block storage for EC2?
5. What is file storage?
6. Which AWS service is shared Linux file storage?
7. When should you use FSx for Windows?
8. What is an S3 bucket?
9. What is an S3 object key?
10. What does S3 versioning do?
11. What does S3 lifecycle do?
12. What is S3 Glacier for?
13. What is EBS used for?
14. What is an EBS snapshot?
15. What is EFS used for?
16. What is Storage Gateway?
17. What is AWS Backup?
18. Why should S3 be private by default?
19. Why use CloudFront OAC?
20. What must you delete before deleting a versioned bucket?
```

Answers:

```text id="answers"
1. Storage for data as objects/files with metadata.
2. Amazon S3.
3. Disk-like storage attached to a server.
4. Amazon EBS.
5. Shared file system storage.
6. Amazon EFS.
7. Windows SMB file shares and AD-integrated workloads.
8. Top-level S3 container.
9. Full object name/path inside bucket.
10. Keeps multiple versions of an object.
11. Moves or deletes objects automatically based on rules.
12. Long-term archive storage.
13. EC2 OS/app/database disks.
14. Point-in-time backup of an EBS volume.
15. Shared Linux files across multiple servers.
16. Hybrid storage bridge between on-prem and AWS.
17. Centralized backup automation service.
18. To prevent accidental public data exposure.
19. To deliver private S3 content publicly through CloudFront securely.
20. All object versions and delete markers.
```

---

# Next Lesson

```text id="next"
AWS Lesson 8 — Databases From Zero to Production:
RDS, Aurora, DynamoDB, ElastiCache, Redshift, database subnet groups, Multi-AZ, read replicas, backups, encryption, scaling, and choosing the correct database
```

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html?utm_source=chatgpt.com "What is Amazon S3? - Amazon Simple Storage Service"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html?utm_source=chatgpt.com "Understanding and managing Amazon S3 storage classes - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/glacier-storage-classes.html?utm_source=chatgpt.com "Understanding S3 Glacier storage classes for long-term data storage - Amazon Simple Storage Service"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/archived-objects.html?utm_source=chatgpt.com "Working with archived objects - Amazon Simple Storage Service"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html?utm_source=chatgpt.com "Managing the lifecycle of objects - Amazon Simple Storage Service"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html?utm_source=chatgpt.com "Blocking public access to your Amazon S3 storage - Amazon Simple Storage Service"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html?utm_source=chatgpt.com "Controlling ownership of objects and disabling ACLs for your bucket - Amazon Simple Storage Service"
[8]: https://docs.aws.amazon.com/ebs/latest/userguide/what-is-ebs.html?utm_source=chatgpt.com "What is Amazon Elastic Block Store? - Amazon EBS"
[9]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes.html?utm_source=chatgpt.com "Amazon EBS volumes - Amazon EBS"
[10]: https://docs.aws.amazon.com/efs/latest/ug/whatisefs.html?utm_source=chatgpt.com "What is Amazon Elastic File System? - Amazon Elastic File System"
[11]: https://docs.aws.amazon.com/fsx/?utm_source=chatgpt.com "Amazon FSx Documentation"
[12]: https://docs.aws.amazon.com/aws-backup/?utm_source=chatgpt.com "AWS Backup Documentation"
[13]: https://docs.aws.amazon.com/aws-backup/latest/devguide/about-backup-plans.html?utm_source=chatgpt.com "Backup plans - AWS Backup"
