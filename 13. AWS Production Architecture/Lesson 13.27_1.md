# AWS Masterclass — Lesson 27 Part 1

# Amazon S3 Fundamentals & Object Storage Architecture

We have now completed two major storage models:

```text
EBS
=
Block Storage

EFS
=
File Storage
```

Now we move to the third major model:

```text
S3
=
Object Storage
```

And this distinction is fundamental.

---

# 1. Where S3 Fits in Our Storage Mental Model

```text
                         AWS STORAGE
                              │
           ┌──────────────────┼──────────────────┐
           │                  │                  │
           ▼                  ▼                  ▼
          EBS                EFS                 S3
           │                  │                  │
         BLOCK               FILE              OBJECT
           │                  │                  │
      EC2 disk          Shared Linux       API-addressed
                         filesystem           objects
```

Think:

```text
EBS
=
"Give my server a disk."


EFS
=
"Give many servers one shared filesystem."


S3
=
"Give my applications an enormous object store."
```

Amazon S3 stores data as **objects inside buckets**. Each object has data, a key that identifies it, and associated metadata. ([AWS Documentation][1])

---

# 2. S3 Does Not Start With Filesystems

This is the first thing to remove from your mind.

With EBS:

```text
Disk
 ↓
partition
 ↓
filesystem
 ↓
directory
 ↓
file
```

With EFS:

```text
NFS filesystem
 ↓
directory
 ↓
file
```

But normal S3:

```text
Bucket
  │
  ├── Object
  ├── Object
  ├── Object
  └── Object
```

There is no requirement to:

```text
mkfs
mount
growpart
xfs_growfs
```

because S3 isn't a block device.

Your application normally interacts with S3 through:

```text
AWS API
AWS CLI
AWS SDK
HTTP requests
presigned URLs
```

S3 itself is a REST-based service, while AWS SDKs provide language-specific abstractions around those APIs. ([AWS Documentation][1])

---

# 3. The Three Core S3 Terms

You need these permanently memorized:

```text
BUCKET
OBJECT
KEY
```

---

# 4. Bucket

A bucket is the container in which S3 stores objects.

Example:

```text
Bucket:

company-prod-assets
```

Inside:

```text
company-prod-assets
│
├── logo.png
├── report.pdf
├── application.zip
└── backup.tar.gz
```

For the ordinary/general S3 use cases we're learning first, we use a:

# General Purpose Bucket

AWS now has multiple S3 bucket types, including general purpose, directory, table, and vector buckets. **General purpose buckets remain the recommended bucket type for most traditional S3 object-storage use cases**, so that's what we'll master first. ([AWS Documentation][1])

---

# 5. Object

An S3 object contains:

```text
Object
 │
 ├── data/value
 ├── key
 ├── metadata
 ├── storage class
 ├── tags
 └── version ID    ← if versioning used
```

Example:

```text
photo.jpg
```

may be:

```text
Value:
actual JPEG bytes

Key:
users/vivek/profile/photo.jpg

Metadata:
Content-Type=image/jpeg
uploaded-by=application

Storage class:
STANDARD

Version:
3HL4k...
```

AWS describes an object as the stored value plus attributes such as its key, metadata, and—when versioning is enabled—a version ID. ([AWS Documentation][2])

---

# 6. Key

The **object key** is the unique identifier of an object within a bucket.

Example:

```text
users/123/profile/photo.jpg
```

The combination:

```text
Bucket
+
Key
```

identifies an object when versioning isn't part of the lookup.

With versioning:

```text
Bucket
+
Key
+
Version ID
```

identifies a particular version. ([AWS Documentation][3])

### Never forget

```text
Bucket
=
container


Key
=
object address inside bucket
```

---

# 7. S3 Doesn't Really Have Traditional Folders

This catches almost everyone initially.

Suppose the console shows:

```text
prod/
└── images/
    └── logo.png
```

You naturally imagine:

```text
folder prod
   ↓
folder images
   ↓
file logo.png
```

But a normal S3 general purpose bucket has a **flat object namespace**.

The real key might simply be:

```text
prod/images/logo.png
```

The slash `/` is part of the key.

The console interprets prefixes ending around delimiters like `/` and visually presents them as folders. AWS explicitly says these folders are represented using key prefixes rather than true filesystem directories. ([AWS Documentation][4])

---

# 8. Prefix

Given:

```text
prod/images/logo.png
```

possible prefixes include:

```text
prod/

prod/images/

prod/images/logo
```

Think:

```text
KEY

prod/images/logo.png
│─────────│
   prefix
```

A prefix is simply characters at the beginning of the key and is useful for organizing and listing groups of objects. ([AWS Documentation][5])

---

# 9. Example Production Key Design

Imagine application uploads.

Bad:

```text
photo1.jpg
photo2.jpg
photo3.jpg
photo4.jpg
```

Better organization:

```text
production/users/123/uploads/photo.jpg

production/users/456/uploads/avatar.jpg

production/orders/2026/08/receipt.pdf

production/logs/2026/08/13/app-01.json
```

Now we can operate against prefixes such as:

```text
production/users/

production/orders/

production/logs/2026/08/
```

That later becomes extremely useful for:

```text
IAM
Lifecycle Rules
Analytics
Replication
Event filtering
Inventory
Cost analysis
```

---

# 10. Prefix ≠ Directory

This distinction becomes especially important programmatically.

A traditional filesystem might have:

```text
mkdir prod
mkdir prod/images
```

In S3, you can directly upload an object with key:

```text
prod/images/logo.png
```

without first creating actual directories.

Conceptually:

```text
PUT Object

Key =
prod/images/logo.png
```

Done.

---

# 11. Object-Key Length

For ordinary general-purpose buckets, an object key can be up to **1,024 bytes** in UTF-8 encoding. ([AWS Documentation][5])

But avoid unnecessarily complex key names.

For production:

```text
meaningful
predictable
machine-friendly
```

is usually better than:

```text
Production Final Folder/New Folder/REAL FINAL!!!/image 001.jpg
```

---

# 12. Object Storage vs File Storage

Now let's compare.

### EFS

Application:

```python
with open("/shared/users/123/photo.jpg", "rb") as f:
    data = f.read()
```

EFS uses normal filesystem semantics.

### S3

Application conceptually asks:

```text
GetObject

Bucket:
company-assets

Key:
users/123/photo.jpg
```

Mental model:

```text
EFS

path
↓
filesystem


S3

bucket + key
↓
API
```

---

# 13. S3 Is Not Normally Mounted Like a Disk

Don't think:

```text
EC2
 ↓
S3
 ↓
/data
```

as the normal architecture.

A cloud-native application normally does:

```text
Application
    │
    ▼
AWS SDK
    │
    ▼
S3 API
    │
    ▼
Bucket
    │
    ▼
Object
```

For example, Node.js:

```text
Node.js API
    │
    ▼
AWS SDK for JavaScript
    │
    ▼
PutObject
    │
    ▼
S3
```

This architectural difference is enormous.

---

# 14. S3 CRUD Mental Model

At the object layer, four operations should become intuitive.

```text
CREATE / UPDATE
       ↓
     PUT


READ
 ↓
GET


DELETE
  ↓
DELETE


DISCOVER
  ↓
LIST
```

Common operations include:

```text
PutObject

GetObject

HeadObject

DeleteObject

ListObjectsV2
```

---

# 15. What Is `HeadObject`?

Sometimes your application doesn't need the object's contents.

It just wants to know:

```text
Does this object exist?

What's its size?

What's its content type?

What's its ETag?

What's its metadata?
```

Instead of:

```text
GET entire 20 GB object
```

you can conceptually use:

```text
HEAD Object
```

That's a common API/HTTP optimization.

---

# 16. S3 URI

You'll frequently see:

```text
s3://my-company-bucket/prod/images/logo.png
```

Break it down:

```text
s3://
    │
    └── S3 URI scheme

my-company-bucket
    │
    └── Bucket

prod/images/logo.png
    │
    └── Key
```

This is useful in:

```text
AWS CLI
Terraform outputs
EMR
Glue
Athena
Data pipelines
CI/CD
```

---

# 17. S3 HTTPS Endpoint Mental Model

An object can also be addressed through S3's HTTP interface using a bucket endpoint and the key.

Conceptually:

```text
https://<bucket>.s3.<region>.amazonaws.com/<key>
```

For example:

```text
https://example-bucket.s3.ap-south-1.amazonaws.com/images/logo.png
```

But knowing an object's URL does **not** mean you're authorized to retrieve it.

Security still decides whether the request succeeds.

---

# 18. Bucket Names

Bucket naming is different from EBS/EFS resource naming.

For globally named general-purpose buckets, the name must be unique across AWS accounts within the AWS partition. AWS also now offers an **account regional namespace**, where bucket names are reserved to your account in that Region. ([AWS Documentation][6])

Classic global bucket example:

```text
vivek-assets
```

If another AWS customer already owns it:

```text
BucketAlreadyExists
```

You cannot create another global bucket with that name.

You've actually encountered this style of problem already with S3/Terraform:

```text
BucketAlreadyOwnedByYou
```

which means the bucket exists and belongs to the same account. ([AWS Documentation][7])

---

# 19. General Purpose Bucket Naming Rules

For global general-purpose bucket names, current rules include:

```text
3–63 characters

lowercase letters
numbers
hyphens
periods
```

They must begin and end with a letter or number, can't contain adjacent periods, and can't be formatted as an IP address. ([AWS Documentation][6])

Valid examples:

```text
vivek-prod-assets-001

company-backups-ap-south-1

datascience-models-2026
```

Invalid:

```text
MyBucket

bucket_name

192.168.1.1
```

---

# 20. Production Bucket Naming

Avoid:

```text
data

backup

prod
```

because they're:

```text
generic
collision-prone
not informative
```

A useful pattern:

```text
<company>-<environment>-<purpose>-<region>-<unique>
```

For example:

```text
acme-prod-app-assets-ap-south-1-73f4c
```

Or infrastructure can append:

```text
AWS account ID
GUID
random suffix
```

AWS explicitly recommends unique suffixes/GUID-style techniques where global namespace uniqueness is needed. ([AWS Documentation][8])

---

# 21. Bucket Name and Region Are Different Concepts

Suppose:

```text
Bucket:

company-prod-data-001
```

Region:

```text
ap-south-1
```

The bucket name identifies it.

The Region determines where the bucket is created and where its objects reside unless you explicitly replicate/transfer them elsewhere. ([AWS Documentation][9])

Mental model:

```text
Name:
WHO/WHAT bucket is this?


Region:
WHERE is its data stored?
```

---

# 22. General Purpose Bucket Data Placement

For ordinary S3 general-purpose storage classes such as Standard, S3 is designed to store data redundantly across multiple Availability Zones.

So this:

```text
S3 Standard
```

is fundamentally different from:

```text
EBS
=
one AZ
```

AWS describes general-purpose buckets as supporting storage classes that redundantly store objects across multiple Availability Zones, with S3 Express One Zone being a notable single-AZ exception used through directory buckets. ([AWS Documentation][1])

Conceptually:

```text
                     ap-south-1
                         │
               ┌─────────┼─────────┐
               │         │         │
              AZ-A      AZ-B      AZ-C
                 \       |       /
                  \      |      /
                   S3 Standard
```

You don't manually create:

```text
S3 replica A
S3 replica B
S3 replica C
```

for ordinary S3 Standard durability within the Region.

---

# 23. Modern S3 Bucket Types

A current AWS point worth knowing:

Amazon S3 now documents four bucket types:

```text
General Purpose
Directory
Table
Vector
```

General Purpose is what most people historically mean when they say:

> “an S3 bucket.”

Directory buckets are used for use cases including low-latency S3 Express One Zone and specialized data-residency patterns; table and vector buckets target newer analytics/AI data models. ([AWS Documentation][1])

For our masterclass:

```text
First:
MASTER General Purpose S3

Later:
specialized modern S3 bucket types
```

Don't mix them prematurely.

---

# 24. Strong Consistency

This is a **very important current S3 fact**.

S3 provides strong read-after-write consistency for object PUT and DELETE operations across AWS Regions, and successful writes are also reflected in subsequent GET and LIST operations. ([AWS Documentation][1])

Suppose:

```text
10:00:00

PUT:
users/123/avatar.jpg

SUCCESS
```

Then:

```text
immediately

GET:
users/123/avatar.jpg
```

returns the newly written object.

And:

```text
LIST:
users/123/
```

includes it.

---

# 25. Old S3 Tutorials May Mislead You

Older S3 material often teaches:

```text
"new objects eventually appear"
```

or talks heavily about eventual consistency for normal object operations.

That's outdated for current S3 object reads/lists.

Today:

```text
PUT succeeds
      ↓
subsequent GET sees it

PUT succeeds
      ↓
subsequent LIST sees it

DELETE succeeds
      ↓
subsequent GET no longer gets it

DELETE succeeds
      ↓
LIST no longer includes it
```

AWS changed S3 to strong read-after-write consistency years ago and still documents this current behavior. ([AWS Documentation][1])

---

# 26. Atomic Update of One Key

Suppose current object:

```text
config.json

version A
```

Application overwrites the same key with:

```text
version B
```

A concurrent reader gets either:

```text
A
```

or:

```text
B
```

—not half of each.

AWS documents updates to a single key as atomic. ([AWS Documentation][1])

That's good.

But there is another important limitation.

---

# 27. No Transaction Across Multiple Keys

Suppose:

```text
order.json

inventory.json
```

You need:

```text
update BOTH or update NEITHER
```

S3 does not give you an ACID-style multi-object transaction simply because those objects are in one bucket. AWS explicitly notes there is no atomic update across multiple keys. ([AWS Documentation][1])

So:

```text
S3
≠
transaction database
```

Again:

```text
Storage service
must match
application semantics.
```

---

# 28. Concurrent Writers

Suppose two clients write the same key concurrently:

```text
Writer A
    \
     \
      users/1/state.json
     /
    /
Writer B
```

S3 doesn't provide a general concurrent-writer object-lock transaction mechanism.

Current S3 behavior uses last-writer-wins semantics for concurrent writes to the same key, and applications needing stronger coordination must implement it themselves. ([AWS Documentation][1])

This resembles our EFS lesson:

```text
storage consistency
≠
application transaction coordination
```

---

# 29. How Large Can an S3 Object Be?

Here's an important **2026 update**.

Many certification notes and old tutorials still say:

```text
Maximum S3 object = 5 TB
```

That became outdated on **December 2, 2025**.

Amazon S3 increased maximum object size from 5 TB to approximately **50 TB**. AWS notes the exact multipart-upload limit as about **48.8 TiB / 53.7 TB decimal**, derived from multipart constraints. ([AWS Documentation][2])

This is exactly why we verify current AWS behavior rather than memorizing old notes.

---

# 30. Single PUT Is Still Much Smaller

Don't confuse:

```text
maximum OBJECT size
```

with:

```text
maximum single-request PUT size
```

AWS currently supports:

```text
Single PUT:
up to 5 GB

Multipart Upload:
up to ~50 TB object
```

The S3 console itself supports individual uploads up to 160 GB; larger objects require CLI, SDK, or REST multipart workflows. ([AWS Documentation][4])

### Never forget

```text
Object can be huge

BUT

huge object
≠
one huge HTTP PUT
```

---

# 31. Multipart Upload

Suppose:

```text
40 GB backup.tar.gz
```

Bad mental model:

```text
one giant upload

0% → 99%

network error

START AGAIN
```

Multipart Upload:

```text
40 GB object
    │
    ├── Part 1
    ├── Part 2
    ├── Part 3
    ├── Part 4
    └── ...
```

Individual parts can be uploaded independently and in parallel; if one part fails, that part can be retransmitted rather than restarting the whole object upload. ([AWS Documentation][10])

---

# 32. Multipart Upload Flow

Under the hood:

```text
CreateMultipartUpload
        │
        ▼
obtain UploadId
        │
        ▼
UploadPart #1
UploadPart #2
UploadPart #3
...
        │
        ▼
CompleteMultipartUpload
        │
        ▼
one S3 object
```

Until completion:

```text
parts
≠
finished object
```

---

# 33. Current Multipart Limits

Current S3 multipart limits include:

```text
Maximum parts:
10,000

Part size:
5 MiB – 5 GiB

Last part:
may be smaller

Maximum complete object:
~50 TB
```

([AWS Documentation][11])

This means an object is not permanently stored as:

```text
part-1
part-2
part-3
```

from your application's perspective.

After completion, it is:

```text
one object
```

---

# 34. Incomplete Multipart Uploads Cost Money

This is a production/FinOps point.

Suppose a CI system repeatedly begins:

```text
50 GB artifact upload
```

and crashes before completion.

Those uploaded parts can remain stored.

AWS states incomplete multipart parts continue incurring storage charges until the multipart upload is completed or aborted. ([AWS Documentation][12])

Therefore later we'll configure Lifecycle rules like:

```text
Abort incomplete multipart uploads
after N days
```

This is an important cost-control pattern.

---

# 35. AWS CLI — First S3 Lab

Let's create our first S3 general-purpose bucket in:

```text
ap-south-1
```

Set:

```bash
export AWS_REGION="ap-south-1"
```

Find your account:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

echo "$ACCOUNT_ID"
```

Generate a unique bucket:

```bash
BUCKET="lesson27-s3-${ACCOUNT_ID}-$(date +%s)"

echo "$BUCKET"
```

---

# 36. Create Bucket

Because we're creating outside `us-east-1`, specify the location constraint:

```bash
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration \
    LocationConstraint="$AWS_REGION"
```

Now inspect:

```bash
aws s3api get-bucket-location \
  --bucket "$BUCKET"
```

You should see:

```text
ap-south-1
```

---

# 37. Verify Public-Access Protection

New general-purpose buckets have all four S3 Block Public Access settings enabled by default. AWS recommends keeping them enabled for buckets that do not intentionally require public access. ([AWS Documentation][9])

Check:

```bash
aws s3api get-public-access-block \
  --bucket "$BUCKET"
```

Conceptually:

```text
BlockPublicAcls              true
IgnorePublicAcls             true
BlockPublicPolicy            true
RestrictPublicBuckets        true
```

We'll study what every one means in the S3 security lesson.

For now:

> **Private first. Public only by deliberate architecture.**

---

# 38. Create a Local Object

```bash
echo "Hello from Lesson 27" > hello.txt
```

Upload:

```bash
aws s3 cp \
  hello.txt \
  "s3://$BUCKET/training/hello.txt"
```

Now our object is:

```text
Bucket:
$BUCKET


Key:
training/hello.txt


Value:
Hello from Lesson 27
```

---

# 39. List Objects

```bash
aws s3api list-objects-v2 \
  --bucket "$BUCKET"
```

Or:

```bash
aws s3 ls "s3://$BUCKET/"
```

Recursive:

```bash
aws s3 ls \
  "s3://$BUCKET/" \
  --recursive
```

Expected:

```text
training/hello.txt
```

Notice again:

```text
training/
```

is a prefix presentation.

The key is:

```text
training/hello.txt
```

---

# 40. Inspect Object Metadata

```bash
aws s3api head-object \
  --bucket "$BUCKET" \
  --key "training/hello.txt"
```

You may see information such as:

```text
ContentLength
ContentType
ETag
LastModified
ServerSideEncryption
Metadata
```

This is:

```text
inspect object
without downloading entire value
```

---

# 41. Download

```bash
aws s3 cp \
  "s3://$BUCKET/training/hello.txt" \
  downloaded.txt
```

Then:

```bash
cat downloaded.txt
```

Expected:

```text
Hello from Lesson 27
```

The logical flow was:

```text
PUT
 ↓
S3 object

GET
 ↓
local file
```

---

# 42. Upload Multiple Prefixes

Create:

```bash
mkdir -p demo
```

```bash
echo "production log" > demo/prod.log
echo "development log" > demo/dev.log
```

Upload:

```bash
aws s3 cp \
  demo/prod.log \
  "s3://$BUCKET/logs/prod/2026/08/app.log"
```

```bash
aws s3 cp \
  demo/dev.log \
  "s3://$BUCKET/logs/dev/2026/08/app.log"
```

Our bucket now logically looks like:

```text
training/hello.txt

logs/prod/2026/08/app.log

logs/dev/2026/08/app.log
```

---

# 43. Prefix Filtering

List only production logs:

```bash
aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --prefix "logs/prod/"
```

S3 returns keys beginning with:

```text
logs/prod/
```

This is how applications can efficiently organize and enumerate groups of logically related objects. ([AWS Documentation][5])

---

# 44. Delete an Object

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key "training/hello.txt"
```

Immediately try:

```bash
aws s3api head-object \
  --bucket "$BUCKET" \
  --key "training/hello.txt"
```

Without versioning complications, you should now receive a not-found style response.

That's strong DELETE consistency in action. ([AWS Documentation][1])

---

# 45. EBS vs EFS vs S3 — Deep Comparison

| Feature               | EBS                      | EFS         | S3                            |
| --------------------- | ------------------------ | ----------- | ----------------------------- |
| Model                 | Block                    | File        | Object                        |
| Normal access         | Block device             | NFS mount   | API/SDK                       |
| Filesystem            | You create/manage        | Managed NFS | Not required                  |
| Multi-client          | Usually one block client | Yes         | Massive client access         |
| Hierarchical dirs     | Filesystem               | Yes         | Prefix illusion in GP buckets |
| EC2 boot volume       | Yes                      | No          | No                            |
| Shared POSIX files    | No/general               | Yes         | No normal POSIX semantics     |
| Object API            | No                       | No          | Yes                           |
| Capacity provisioning | Yes                      | Automatic   | Automatic                     |
| Common web assets     | Possible                 | Possible    | Excellent fit                 |
| Backups/artifacts     | Possible                 | Possible    | Excellent fit                 |
| Data lake             | Poor fit                 | Sometimes   | Excellent fit                 |

---

# 46. Which One Would You Choose?

### PostgreSQL data disk

```text
EBS
```

because:

```text
block device
low-latency random I/O
filesystem/database control
```

---

### 100 EC2 WordPress servers requiring shared POSIX uploads

```text
EFS
```

because:

```text
shared filesystem
NFS
concurrent access
```

---

### CI/CD build artifact

```text
application-v1.4.7.tar.gz
```

Think:

```text
S3
```

because the artifact is naturally one immutable-ish object retrieved through API/CLI.

---

### Static images served to millions of users

Think:

```text
S3
+
CloudFront
```

rather than storing them on an Auto Scaling EC2 instance.

We'll build exactly this architecture later.

---

# 47. Why S3 Is Perfect for Disposable Compute

Recall:

```text
Auto Scaling EC2
=
disposable compute
```

Instead of:

```text
EC2
 │
 └── /uploads
```

we can design:

```text
                      ALB
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
           EC2-A     EC2-B     EC2-C
             \         |         /
              \        |        /
                  S3 Bucket
                      │
                  uploads/
```

Application servers can disappear.

Objects remain independent of the individual EC2 lifecycle.

That is a very cloud-native architecture.

---

# 48. Your Todo/Deployment Project Connection

Our deployment artifact concept can become:

```text
Jenkins
   │
   ▼
Build
   │
   ▼
todo-backend-1.7.4.tar.gz
   │
   ▼
S3 Artifact Bucket
   │
   ▼
Deployment system
   │
   ▼
EC2 fleet
```

Instead of needing:

```text
build artifact
stored only on Jenkins disk
```

S3 can become durable artifact storage for the pipeline.

Likewise:

```text
Terraform plans
logs
backup files
frontend static assets
ML datasets
models
reports
```

are all common S3-shaped workloads.

---

# 49. S3 Is Not a Database

You can store:

```json
{
  "user": 123,
  "name": "Vivek"
}
```

as:

```text
users/123.json
```

But that doesn't magically provide:

```text
SELECT *
FROM users
WHERE age > 30
ORDER BY last_login
```

S3 is object storage.

Other AWS services can query data **stored in S3**, for example:

```text
Athena
Glue
EMR
Redshift integrations
```

but that is a broader analytics architecture.

---

# 50. S3 Is Not a Message Queue

Similarly:

```text
events/event-001.json
events/event-002.json
```

doesn't make S3 equivalent to:

```text
SQS
Kafka
Kinesis
```

Storage and messaging solve different problems.

We'll continually ask:

```text
What is the application's required semantic?
```

not merely:

```text
Can AWS service X technically contain bytes?
```

---

# 51. S3 Security Preview

By default, S3 objects/buckets are private unless access is deliberately granted. Current general-purpose buckets also default to **Bucket owner enforced Object Ownership**, which disables ACLs; AWS recommends keeping ACLs disabled for most modern use cases and using policy-based access instead. ([AWS Documentation][1])

Our security architecture will become:

```text
                    S3 Request
                        │
             ┌──────────┼──────────┐
             │          │          │
             ▼          ▼          ▼
            IAM      Bucket      Block Public
           Policy     Policy       Access
             │          │
             └──────┬───┘
                    ▼
                Authorization
                    │
                    ▼
              Object Ownership
                    │
                    ▼
               Encryption/KMS
```

That is the next major part.

---

# 52. Common Beginner Mistake — Making the Bucket Public

Application can't access object:

```text
403 AccessDenied
```

Beginner:

```text
"Make bucket public."
```

Production engineer:

```text
WHO needs access?

Application role?
CloudFront?
User browser?
Partner?
Another account?
AWS service?
```

Then grant only that principal exactly what it needs.

Most production S3 buckets should **not** be made publicly writable or broadly public merely to solve permissions problems.

---

# 53. Common Beginner Mistake — Treating S3 Like Linux

User asks:

```text
How much free disk space
does my S3 bucket have?
```

Wrong mental model.

S3 does not work like:

```text
/dev/nvme1n1
100 GB total
72 GB free
```

Object-storage capacity scales as objects are added.

You think primarily about:

```text
stored bytes
object count
request rates
storage class
cost
```

rather than:

```text
filesystem free blocks
```

---

# 54. Common Beginner Mistake — Thinking Prefix Is a Security Boundary

Suppose:

```text
bucket

finance/
hr/
engineering/
```

The presence of these prefixes doesn't automatically secure them from each other.

Security must explicitly define permissions.

Later:

```text
Finance role
      │
      └── s3://bucket/finance/*


HR role
      │
      └── s3://bucket/hr/*
```

can be enforced with policy.

But the “folders” themselves don't create authorization.

---

# 55. Cleanup Our Lab

Remove remaining objects:

```bash
aws s3 rm \
  "s3://$BUCKET/" \
  --recursive
```

Verify:

```bash
aws s3 ls "s3://$BUCKET/"
```

Then delete:

```bash
aws s3api delete-bucket \
  --bucket "$BUCKET" \
  --region "$AWS_REGION"
```

S3 requires a bucket to be empty before normal bucket deletion; versioned buckets need additional version/delete-marker cleanup, which we'll learn later.

---

# 56. Certification Scenarios

### Scenario 1

> Application requires scalable object storage accessed through APIs.

Think:

```text
S3
```

---

### Scenario 2

> Application needs Linux POSIX shared filesystem semantics.

Think:

```text
EFS
```

not S3 general-purpose object storage.

---

### Scenario 3

> Database needs low-latency block storage.

Think:

```text
EBS
```

---

### Scenario 4

> You upload a new S3 object successfully and immediately list its prefix.

Will the new object appear?

```text
YES
```

S3 provides strong consistency for successful object writes and subsequent LIST operations. ([AWS Documentation][1])

---

### Scenario 5

> Two clients update two different S3 keys and require one ACID transaction.

S3 alone does **not** provide an atomic multi-key transaction. ([AWS Documentation][1])

---

### Scenario 6

> Need to upload a 20 TB S3 object.

Can S3 store it?

```text
YES
```

Current S3 supports objects around 50 TB maximum, but a 20 TB object must use multipart upload rather than one `PutObject` call. ([AWS Documentation][2])

---

### Scenario 7

> Someone says maximum S3 object size is 5 TB.

As of August 2026:

```text
OUTDATED
```

AWS increased the maximum object size to approximately 50 TB on **December 2, 2025**. ([AWS Documentation][13])

This is exactly the kind of current fact where old SAA study material can be wrong.

---

# 57. Interview Question

> **Explain Amazon S3 to me without saying “it's cloud file storage.”**

Strong answer:

> Amazon S3 is a regional object-storage service. Data is stored as objects inside buckets, and each object is addressed by a key rather than by mounting a normal block or POSIX filesystem. Applications usually interact with S3 through REST APIs, AWS SDKs, the CLI, or HTTP-based access mechanisms. General-purpose buckets provide a flat object namespace where folder-like structures are implemented using key prefixes. S3 provides strong read-after-write consistency for object operations, scales storage automatically, and supports features such as versioning, lifecycle management, encryption, access policies, replication, Object Lock, event integration, and multiple storage classes. ([AWS Documentation][1])

That answer shows you understand the architecture.

---

# 58. Never-Forget S3 Mental Model

```text
                            AMAZON S3
                                │
                             BUCKET
                                │
                   ┌────────────┼────────────┐
                   │            │            │
                   ▼            ▼            ▼
                 Object       Object       Object
                   │
          ┌────────┼──────────┐
          │        │          │
          ▼        ▼          ▼
         Key      Data      Metadata
          │
          ▼
       Prefixes
          │
          ▼
 Logical organization
    NOT filesystem dirs

              APPLICATION ACCESS
                      │
           ┌──────────┼───────────┐
           ▼          ▼           ▼
          CLI        SDK         REST
                      │
                      ▼
               PUT / GET / HEAD
               LIST / DELETE
```

---

# 59. The 12 Rules to Permanently Remember

```text
1. S3 = object storage.

2. Bucket = container.

3. Object = stored value + attributes.

4. Key = unique object identifier inside bucket.

5. General-purpose S3 has a flat namespace.

6. "Folders" are normally prefixes, not directories.

7. S3 is normally consumed through APIs/SDKs,
   not as an EC2 block disk.

8. S3 provides strong object read-after-write consistency.

9. Single-key updates are atomic.

10. Multi-key ACID transactions are not provided.

11. Single PUT max = 5 GB.

12. Current maximum S3 object size ≈ 50 TB
    using multipart upload.
```

The **5 TB maximum-object limit you may see in older courses is no longer current**; AWS increased it in December 2025. ([AWS Documentation][4])

---

# ✅ Lesson 27 Progress

We've established:

```text
✓ Object-storage mental model
✓ S3 vs EBS
✓ S3 vs EFS
✓ Bucket
✓ Object
✓ Key
✓ Prefix
✓ Flat namespace
✓ Folder illusion
✓ Metadata
✓ Version ID concept
✓ General-purpose bucket
✓ Modern S3 bucket types
✓ Bucket naming
✓ Region placement
✓ Strong consistency
✓ Atomic single-key updates
✓ Concurrent writers
✓ PUT / GET / HEAD / LIST / DELETE
✓ S3 URI
✓ CLI hands-on
✓ Prefix filtering
✓ Multipart upload
✓ New ~50-TB object limit
✓ Incomplete multipart cost risk
✓ Production use cases
```

# Next — Lesson 27 Part 2: **S3 Security in Depth**

This is one of the most important AWS/IAM sections in the entire masterclass:

```text
S3 REQUEST
   │
   ▼
Who are you?
   │
   ├── IAM User
   ├── IAM Role
   ├── EC2 Role
   ├── ECS Task Role
   ├── Lambda Role
   ├── Another AWS account
   ├── CloudFront
   └── Anonymous/public
   │
   ▼
IAM Policy
   │
   ▼
Bucket Policy
   │
   ▼
Explicit DENY?
   │
   ▼
S3 Block Public Access
   │
   ▼
Object Ownership
   │
   ▼
ACLs
   │
   ▼
SSE-S3 / SSE-KMS
   │
   ▼
KMS Key Policy
   │
   ▼
VPC Endpoint Policy
   │
   ▼
ALLOW or 403 AccessDenied
```

We'll then deliberately create and troubleshoot the errors you've encountered in real AWS work:

```text
403 AccessDenied
BucketAlreadyExists
BucketAlreadyOwnedByYou
wrong Resource ARN
s3:ListBucket vs s3:GetObject
bucket ARN vs object ARN
IAM Allow + bucket Deny
KMS AccessDenied
Block Public Access
Object Ownership
CloudFront 403
```

Once you understand that authorization chain, **S3 403 errors stop being mysterious**.

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html "What is Amazon S3? - Amazon Simple Storage Service"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingObjects.html?utm_source=chatgpt.com "Amazon S3 objects overview"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html?utm_source=chatgpt.com "What is Amazon S3? - Amazon Simple Storage Service"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/upload-objects.html?utm_source=chatgpt.com "Uploading objects - Amazon Simple Storage Service"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-prefixes.html?utm_source=chatgpt.com "Organizing objects using prefixes"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html?utm_source=chatgpt.com "General purpose bucket naming rules"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/gpbucketnamespaces.html?utm_source=chatgpt.com "Namespaces for general purpose buckets"
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html?utm_source=chatgpt.com "Creating a general purpose bucket - AWS Documentation"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingBucket.html?utm_source=chatgpt.com "General purpose buckets overview"
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html?utm_source=chatgpt.com "Uploading and copying objects using multipart upload in ..."
[11]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html?utm_source=chatgpt.com "Amazon S3 multipart upload limits"
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/empty-bucket.html?utm_source=chatgpt.com "Emptying a general purpose bucket - AWS Documentation"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/WhatsNew.html?utm_source=chatgpt.com "Document history - Amazon Simple Storage Service"
