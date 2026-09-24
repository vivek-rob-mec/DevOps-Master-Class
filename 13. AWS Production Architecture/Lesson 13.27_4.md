# AWS Masterclass — Lesson 27 Part 4

# S3 Storage Classes, Lifecycle & Cost Engineering

We now understand:

```text
Part 1 → What is S3?
Part 2 → Who may access it?
Part 3 → How do we protect versions/data?
```

Now comes the FinOps question:

> **“We have hundreds of terabytes in S3. Why should every byte be stored at the same price and performance level forever?”**

The architecture becomes:

```text
                    DATA CREATED
                         │
                         ▼
                    S3 Standard
                         │
                access pattern?
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      frequent       infrequent        archive
          │              │              │
       Standard       Standard-IA    Glacier family
                         │              │
                         ▼              ▼
                   One Zone-IA       IR / Flexible
                                      / Deep
```

Amazon S3 currently provides storage classes optimized for different combinations of access frequency, latency, resilience, minimum retention, and retrieval cost. ([AWS Documentation][1])

---

# 1. First Rule: Cheapest Storage Is Not Automatically Cheapest Architecture

Imagine two options:

```text
Option A
Storage price = higher
Retrieval cost = low
No minimum retention penalty


Option B
Storage price = much lower
Retrieval charges = higher
Minimum duration = 180 days
Restore can take hours
```

If your application reads every object ten times per day:

```text
Option B
```

could be a terrible choice.

So S3 cost is not simply:

```text
GB × storage price
```

Think:

```text
Total S3 Cost
     │
     ├── stored capacity
     ├── request count
     ├── retrieval
     ├── lifecycle transitions
     ├── minimum-duration charges
     ├── object-size overhead
     ├── replication
     ├── data transfer
     └── KMS/API-related costs where applicable
```

AWS explicitly recommends selecting storage classes based not only on storage price, but also access and performance requirements. ([AWS Documentation][1])

---

# 2. The Main Storage Classes

For our general-purpose S3 learning path, these are the classes you should know extremely well:

| Storage class                  | Best mental use                       | Access                                              | Minimum duration |
| ------------------------------ | ------------------------------------- | --------------------------------------------------- | ---------------: |
| **S3 Standard**                | Hot/frequent data                     | Milliseconds                                        |             None |
| **Intelligent-Tiering**        | Unknown/changing pattern              | Usually milliseconds; optional archive tiers slower |             None |
| **Standard-IA**                | Infrequent but immediately needed     | Milliseconds                                        |          30 days |
| **One Zone-IA**                | Re-creatable infrequent data          | Milliseconds                                        |          30 days |
| **Glacier Instant Retrieval**  | Rare archive requiring instant access | Milliseconds                                        |          90 days |
| **Glacier Flexible Retrieval** | Archive; minutes/hours acceptable     | Restore first                                       |          90 days |
| **Glacier Deep Archive**       | Very cold long-term archive           | Restore first                                       |         180 days |

S3 Standard, Standard-IA, Intelligent-Tiering and the Glacier classes above are designed across at least three AZs, whereas One Zone-IA is intentionally single-AZ. ([AWS Documentation][1])

---

# 3. S3 Standard

S3 Standard is the default general-purpose class.

Think:

```text
Frequently accessed
        │
        ▼
      STANDARD
```

Examples:

```text
website assets
active application uploads
frequently downloaded reports
API objects
active datasets
recent logs
```

It has:

```text
millisecond access
no minimum storage duration
no minimum billable object size
multi-AZ resilience
```

and it is the default storage class when you don't specify another one. ([AWS Documentation][1])

### Mental shortcut

```text
I don't yet know
that this object is cold
        │
        ▼
Start with Standard
or Intelligent-Tiering
```

Don't archive data on day zero merely because archive storage is cheaper.

---

# 4. Standard-IA

`IA` means:

```text
Infrequent Access
```

Use when data is:

```text
long-lived
rarely read

BUT

must be immediately available
```

Example:

```text
monthly backup
old customer report
older application asset
DR data
```

Standard-IA still provides millisecond access, but retrieval charges apply. It also carries a 30-day minimum storage duration and 128-KB minimum billable object size. ([AWS Documentation][1])

---

# 5. Why the 30-Day Minimum Matters

Suppose you put an object into Standard-IA.

Then delete it after:

```text
5 days
```

AWS doesn't simply say:

```text
"You stored it for 5 days,
so pay for 5."
```

Because Standard-IA has:

```text
minimum = 30 days
```

you can incur a prorated charge representing the unused portion of that minimum period. ([AWS Documentation][1])

So:

```text
create
↓
Standard-IA
↓
delete after 3 days
```

can be less economical than:

```text
Standard
for a short-lived object
```

---

# 6. The 128-KB Problem

Suppose you have:

```text
10 million files
```

each:

```text
10 KB
```

Actual data:

```text
≈ 100 GB
```

But Standard-IA has a:

```text
128 KB minimum billable object size
```

so tiny-object economics can become poor. AWS specifically states that objects smaller than 128 KB in Standard-IA and One Zone-IA are charged as 128 KB objects. ([AWS Documentation][1])

This is why:

```text
number of objects
```

can matter just as much as:

```text
total TB
```

---

# 7. Standard-IA vs One Zone-IA

Both provide:

```text
infrequent access
+
millisecond retrieval
+
30-day minimum
+
128-KB minimum billable object size
```

but their resilience differs. ([AWS Documentation][1])

### Standard-IA

```text
      Region
        │
 ┌──────┼──────┐
 ▼      ▼      ▼
AZ-A   AZ-B   AZ-C
```

Designed to survive loss of an AZ.

### One Zone-IA

```text
Region
  │
 AZ-A
  │
 data
```

One Zone-IA intentionally stores data in a single AZ and is not resilient to loss of that AZ. AWS recommends it primarily for re-creatable data or suitable secondary copies. ([AWS Documentation][1])

---

# 8. When One Zone-IA Makes Sense

Good:

```text
Re-creatable thumbnails
      │
source exists elsewhere
```

Potentially:

```text
One Zone-IA
```

Good:

```text
secondary copy
that can be recreated
```

Potentially:

```text
One Zone-IA
```

Bad mental choice:

```text
Only copy
of legally critical
business records
```

and then selecting One Zone-IA merely because:

```text
"it costs less"
```

Storage design always includes failure consequences.

---

# 9. Intelligent-Tiering

This is one of the most useful S3 classes when:

> **“I genuinely don't know which objects will be hot next month.”**

Instead of manually saying:

```text
30 days → IA
90 days → Glacier
```

S3 monitors access patterns and automatically moves eligible objects between internal access tiers. ([AWS Documentation][1])

Think:

```text
                Intelligent-Tiering

new/accessed
     │
     ▼
Frequent Access
     │
 30 days no access
     ▼
Infrequent Access
     │
 90 days no access
     ▼
Archive Instant Access
```

Those three tiers happen automatically. ([AWS Documentation][2])

---

# 10. Intelligent-Tiering Access Tiers

The automatic tiers are:

```text
Frequent Access
        │
        │ 30 consecutive days no access
        ▼
Infrequent Access
        │
        │ 90 consecutive days no access
        ▼
Archive Instant Access
```

All three still offer:

```text
low-latency
high-throughput
millisecond access
```

and accessing an object in the Infrequent or Archive Instant tier can automatically move it back toward Frequent Access. ([AWS Documentation][2])

---

# 11. Optional Intelligent-Tiering Archive Tiers

You can additionally enable:

```text
Archive Access

Deep Archive Access
```

for data that can tolerate asynchronous restore.

Conceptually:

```text
Frequent
   ↓
Infrequent
   ↓
Archive Instant
   ↓
Archive Access
   ↓
Deep Archive Access
```

The optional Archive Access tier can begin after at least 90 days of no access, while Deep Archive Access can begin after at least 180 days; both thresholds can be configured farther out. ([AWS Documentation][2])

---

# 12. Critical Intelligent-Tiering Difference

These:

```text
Frequent
Infrequent
Archive Instant
```

have immediate access.

But:

```text
Archive Access
Deep Archive Access
```

require:

```text
RestoreObject
```

before archived data can be used. ([AWS Documentation][2])

That's a major application-semantic boundary.

---

# 13. Intelligent-Tiering Object <128 KB

Current behavior:

```text
Object size < 128 KB
```

means the object:

```text
is not monitored
is not auto-tiered
remains in Frequent Access
```

within Intelligent-Tiering. ([AWS Documentation][1])

This matters for workloads containing:

```text
millions
of tiny objects
```

because Intelligent-Tiering doesn't magically turn every tiny file into cheaper archival storage.

---

# 14. Intelligent-Tiering Has a Monitoring Fee

For eligible objects, Intelligent-Tiering charges a small per-object monitoring and automation fee.

In exchange, AWS manages the object's access-tier placement automatically, and the class itself has no data retrieval fees for the standard Intelligent-Tiering tiers. ([AWS Documentation][1])

Therefore:

```text
Huge 5-GB objects
with unknown patterns
```

can be a very natural fit.

But:

```text
billions of tiny objects
```

need more careful cost analysis.

---

# 15. Excellent Intelligent-Tiering Scenario

Imagine:

```text
500 TB customer dataset
```

Some objects:

```text
read every day
```

others:

```text
read once every 3 months
```

others:

```text
not read for 2 years
```

and the pattern changes constantly.

Manual lifecycle classification becomes difficult.

Think:

```text
INTELLIGENT_TIERING
```

because the problem is specifically:

```text
unknown/changing access pattern
```

rather than simply:

```text
old = cold
```

---

# 16. Don't Use Intelligent-Tiering Just Because It's “Smart”

Suppose:

```text
all log files are accessed heavily
for exactly 7 days

and NEVER accessed afterward
```

The pattern is perfectly known.

A deterministic Lifecycle rule could be simpler:

```text
Standard
7/30 days
↓
lower-cost class
```

You don't always need automatic learning when the data lifecycle is already predictable.

---

# 17. Glacier Is a Family, Not One Storage Class

The three major S3 Glacier storage classes are:

```text
Glacier Instant Retrieval
Glacier Flexible Retrieval
Glacier Deep Archive
```

They solve very different latency requirements. AWS recommends choosing among them according to access frequency and retrieval-time tolerance. ([AWS Documentation][3])

---

# 18. Glacier Instant Retrieval

Use for:

```text
rarely accessed
long-lived
BUT
must be immediately available
```

Example:

```text
medical image
rarely viewed
but when doctor requests it
it must load immediately
```

Characteristics:

```text
millisecond retrieval
90-day minimum duration
128-KB minimum object size
retrieval fees
```

AWS recommends Glacier Instant Retrieval for roughly quarterly access where millisecond retrieval is still necessary. ([AWS Documentation][3])

---

# 19. Glacier Instant Retrieval Does NOT Require Restore

This distinction is crucial.

```text
Glacier Instant Retrieval
        │
        ▼
GET directly
```

You do **not** first perform the multi-hour restore workflow required by Flexible Retrieval or Deep Archive. ([AWS Documentation][4])

So:

```text
GLACIER_IR
```

still behaves like online object storage from the application's perspective.

---

# 20. Glacier Flexible Retrieval

Now we're entering true archive storage.

Think:

```text
backup/archive
access perhaps
1–2 times per year
```

Objects are not directly available for normal real-time access; a restore request is required first. ([AWS Documentation][3])

Minimum storage duration:

```text
90 days
```

AWS currently offers retrieval choices including Expedited, Standard and Bulk. ([AWS Documentation][3])

---

# 21. Flexible Retrieval Speeds

Typical current retrieval behavior:

```text
Expedited
≈ 1–5 minutes
```

```text
Standard
≈ 3–5 hours
```

```text
Bulk
≈ 5–12 hours
```

Bulk retrieval for Glacier Flexible Retrieval is currently free, while Expedited is premium-priced. ([AWS Documentation][4])

### Mental model

```text
Money ↑
       Expedited

       Standard

Money ↓
       Bulk
          ───────────────▶ Time
```

---

# 22. Glacier Deep Archive

Now think:

```text
"Store this for years.
We almost never need it."
```

Examples:

```text
regulatory records
historical backups
old audit files
long-term retention
disaster archive
```

Glacier Deep Archive has a:

```text
180-day minimum storage duration
```

and is designed for objects accessed less than once per year. ([AWS Documentation][3])

---

# 23. Deep Archive Retrieval

Current options are roughly:

```text
Standard
within ~12 hours
```

and:

```text
Bulk
within ~48 hours
```

There is no Expedited retrieval tier for Deep Archive. ([AWS Documentation][4])

So if your business says:

```text
RTO = 15 minutes
```

and your only copy lives in:

```text
Deep Archive
```

your architecture clearly doesn't meet the recovery-time requirement.

---

# 24. Critical Glacier Mental Model

For Flexible Retrieval and Deep Archive:

```text
Archived Object
       │
       │ RestoreObject
       ▼
   wait
       │
       ▼
temporary accessible copy
       │
       │ expiration days
       ▼
temporary copy disappears
```

The underlying object remains archived; a restore does **not** permanently convert the archive object's storage class to Standard. ([AWS Documentation][5])

---

# 25. Very Important Glacier Cost Detail

During the restore period:

```text
Archived copy
+
Temporary restored copy
```

both exist.

AWS therefore charges for the archived storage plus the temporary restored copy at the applicable Standard rate during that restore window. ([AWS Documentation][5])

So restore duration itself can become a FinOps decision.

---

# 26. Hands-On Glacier Restore

Suppose:

```bash
BUCKET="prod-archive"
KEY="backups/2026/database.tar.gz"
```

Object storage class:

```text
GLACIER
```

Request Standard restore for three days:

```bash
aws s3api restore-object \
  --bucket "$BUCKET" \
  --key "$KEY" \
  --restore-request '{
    "Days": 3,
    "GlacierJobParameters": {
      "Tier": "Standard"
    }
  }'
```

Then monitor:

```bash
aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$KEY"
```

AWS supports restore initiation and restore-status checking through S3 APIs/CLI. ([AWS Documentation][6])

---

# 27. Do NOT Run GET Immediately After Restore Request

The workflow is:

```text
restore-object
      │
      ▼
REQUEST ACCEPTED
      │
      ▼
WAIT FOR RETRIEVAL
      │
      ▼
temporary copy ready
      │
      ▼
GET
```

Not:

```text
restore-object
↓
GET 2 milliseconds later
```

Flexible/Deep Archive are intentionally asynchronous archive classes. ([AWS Documentation][4])

---

# 28. S3 Lifecycle

Now the heart of S3 cost engineering.

S3 Lifecycle lets you define automated rules that:

```text
transition objects
expire objects
manage noncurrent versions
remove delete markers
abort incomplete multipart uploads
```

AWS describes Lifecycle as the mechanism for automatically moving objects to lower-cost classes or expiring data as it ages. ([AWS Documentation][7])

---

# 29. Basic Lifecycle Architecture

Example:

```text
Day 0
S3 Standard
   │
   │ 30 days
   ▼
Standard-IA
   │
   │ 90 days
   ▼
Glacier Flexible Retrieval
   │
   │ 365 days
   ▼
Deep Archive
   │
   │ 7 years
   ▼
Expire
```

This is:

```text
DATA LIFECYCLE
```

instead of:

```text
upload forever
and never manage again
```

---

# 30. Lifecycle Is Policy-Driven

You can target rules using:

```text
prefix
tags
object size
or combinations
```

For example:

```text
logs/
```

can have one lifecycle.

```text
customer-contracts/
```

can have a completely different one.

This lets one bucket contain distinct retention strategies.

---

# 31. Example by Prefix

Bucket:

```text
company-prod
│
├── logs/
├── artifacts/
├── backups/
└── legal/
```

You might design:

```text
logs/
30 days → IA
90 days → expire
```

```text
artifacts/
90 days → Glacier IR
365 days → expire
```

```text
backups/
30 days → Glacier Flexible
365 days → Deep Archive
7 years → expire
```

```text
legal/
Object Lock + long-term retention
```

The bucket is one container, but the business semantics differ by key population.

---

# 32. Current Lifecycle Rule for Small Objects

Current S3 Lifecycle behavior applies a default filter that prevents objects **smaller than 128 KB** from being transitioned to another storage class.

AWS's rationale is that per-object transition request costs can exceed the storage savings for very small objects. ([AWS Documentation][8])

This is a very important modern behavior.

So:

```text
50 KB object
```

doesn't automatically transition simply because your Lifecycle rule says:

```text
after 30 days → IA
```

under the default transition behavior. ([AWS Documentation][8])

---

# 33. Why Many Tiny Objects Can Destroy a Clever Cost Plan

Suppose:

```text
100 million objects
```

each:

```text
20 KB
```

You think:

> “Archive everything and save a fortune.”

But now consider:

```text
100 million lifecycle transitions
```

plus:

```text
per-object metadata
minimum billable sizes
archive metadata overhead
```

For Glacier Flexible Retrieval and Deep Archive, AWS additionally stores 40 KB of archive metadata per archived object, split between archive-class and S3 Standard metadata charges. ([AWS Documentation][3])

Therefore sometimes:

```text
aggregate tiny objects
into larger files
```

is worth evaluating for archive workloads.

---

# 34. Minimum-Duration Trap

Lifecycle doesn't cancel minimum storage requirements.

Suppose:

```text
Day 0
Standard

Day 30
Glacier Instant Retrieval

Day 50
Deep Archive
```

Problem:

Glacier Instant Retrieval requires:

```text
90 days
```

minimum storage.

AWS prevents you from defining a single Lifecycle sequence that violates the required transition timing; moving data early through separate rules can still incur minimum-duration charges. ([AWS Documentation][8])

### Never forget

```text
Lifecycle transition
≠
escape minimum duration fee
```

---

# 35. Versioning + Lifecycle

Remember from Part 3:

```text
report.pdf

V1
V2
V3
V4 ← current
```

Without Lifecycle:

```text
V1
V2
V3
```

might remain stored forever.

Therefore mature versioned buckets often need:

```text
CurrentVersionTransitions
+
NoncurrentVersionTransitions
+
NoncurrentVersionExpiration
```

AWS Storage Lens specifically highlights accumulating noncurrent versions as a common S3 cost-optimization problem. ([AWS Documentation][9])

---

# 36. Example Version Strategy

Production requirement:

```text
Recover accidental change
for 30 days.
```

Policy:

```text
Current
   │
normal lifecycle
   │
   ▼

Noncurrent
   │
retain 30 days
   │
   ▼
permanently expire
```

This gives:

```text
30-day recovery window
```

without:

```text
10 years of obsolete versions
```

---

# 37. Keep Several Previous Versions

Lifecycle also supports logic based on both:

```text
age of noncurrent version
```

and:

```text
number of newer noncurrent versions
```

allowing policies such as:

```text
delete versions older than 30 days
but retain several recent historical versions
```

AWS's current Lifecycle examples demonstrate combining `NoncurrentDays` and `NewerNoncurrentVersions`. ([AWS Documentation][10])

---

# 38. Expired Delete Markers

Remember:

```text
DELETE
in versioned bucket
=
Delete Marker
```

Eventually you can end up with:

```text
file.txt
└── delete marker only
```

after all actual versions have expired.

That is an:

```text
Expired Object Delete Marker
```

Lifecycle can automatically remove it. ([AWS Documentation][11])

This keeps the versioned namespace cleaner.

---

# 39. Multipart Upload Cost Leak

Remember Part 1:

```text
CreateMultipartUpload
       ↓
Part 1
Part 2
Part 3
       X
build crashes
```

Uploaded parts continue consuming storage until you:

```text
CompleteMultipartUpload
```

or:

```text
AbortMultipartUpload
```

Lifecycle can automatically abort uploads that remain incomplete after a configured number of days. ([AWS Documentation][12])

---

# 40. This Lifecycle Rule Should Be Almost Muscle Memory

For buckets receiving large uploads:

```text
Abort incomplete multipart uploads
after 7 days
```

is often a very sensible baseline.

AWS Storage Lens even provides metrics specifically to identify buckets with incomplete multipart uploads older than seven days or missing abort rules. ([AWS Documentation][9])

---

# 41. AWS CLI Lifecycle Example

Create:

`lifecycle.json`

```json
{
  "Rules": [
    {
      "ID": "ProductionDataLifecycle",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "data/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 120,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      },
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    }
  ]
}
```

Apply:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration file://lifecycle.json
```

Inspect:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket "$BUCKET"
```

The lifecycle actions above correspond to supported S3 transition, noncurrent-expiration, and incomplete-multipart cleanup capabilities. ([AWS Documentation][7])

---

# 42. Terraform Lifecycle Configuration

Current HashiCorp AWS provider manages Lifecycle through:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    id     = "production-data"
    status = "Enabled"

    filter {
      prefix = "data/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 120
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

The current Terraform AWS provider exposes these Lifecycle elements through `aws_s3_bucket_lifecycle_configuration`. ([Terraform Registry][13])

---

# 43. Be Careful With Terraform Lifecycle Rules

Don't deploy:

```text
expire after 7 days
```

to:

```text
production-backups/
```

simply because the Terraform syntax validates.

Infrastructure validity:

```text
terraform validate = PASS
```

does **not** mean:

```text
business retention policy = CORRECT
```

Before applying Lifecycle, ask:

```text
What must be recoverable?
For how long?
What is legal retention?
What is backup RPO?
What is restore RTO?
What does Object Lock require?
What happens to noncurrent versions?
```

---

# 44. S3 Storage Lens

When you have:

```text
3 buckets
```

you can inspect them manually.

When you have:

```text
2,000 buckets
across 80 AWS accounts
```

you need centralized visibility.

S3 Storage Lens provides organization/account/bucket/storage-class metrics and recommendations for storage usage, protection, access, and cost optimization. ([AWS Documentation][9])

---

# 45. Storage Lens Cost Opportunities

Storage Lens can help identify:

```text
largest buckets
cold buckets
incomplete multipart uploads
noncurrent-version accumulation
missing Lifecycle rules
```

AWS specifically exposes cost-optimization metrics for these problems. ([AWS Documentation][9])

This is FinOps at scale:

```text
Measure
  ↓
Identify waste
  ↓
Design lifecycle
  ↓
Measure again
```

not:

```text
apply Deep Archive everywhere
and hope
```

---

# 46. S3 Inventory

Storage Lens answers:

```text
"How is my S3 estate behaving?"
```

S3 Inventory answers more like:

```text
"Give me a scheduled catalog
of my objects and metadata."
```

Inventory can produce daily or weekly:

```text
CSV
ORC
Parquet
```

reports for all objects or a prefix, optionally including fields such as:

```text
storage class
encryption
replication status
size
version ID
Object Lock state
```

depending on configuration. It provides a scheduled alternative to repeatedly enumerating huge buckets using synchronous List APIs. ([AWS Documentation][14])

---

# 47. Inventory + Athena

This becomes extremely powerful.

```text
S3 Production Bucket
       │
       ▼
S3 Inventory
       │
       ▼
Parquet reports
       │
       ▼
Athena
       │
       ▼
SQL
```

For example, conceptually:

```sql
SELECT
    storage_class,
    COUNT(*) AS objects,
    SUM(size) AS bytes
FROM inventory
GROUP BY storage_class;
```

AWS documents querying S3 Inventory output with Athena and other analytical tools. ([AWS Documentation][14])

Now FinOps becomes data-driven.

---

# 48. 100-TB Architecture Scenario

Requirement:

```text
100 TB media archive

New data:
accessed often for first 30 days

Days 31–180:
occasionally accessed,
must return immediately

After 180 days:
almost never accessed

Retention:
7 years
```

Possible design:

```text
Day 0
STANDARD
   │
Day 30
   ▼
STANDARD_IA
   │
Day 180
   ▼
GLACIER FLEXIBLE
   │
Later
   ▼
DEEP_ARCHIVE
   │
7 years
   ▼
Expire
```

But you must first verify that retrieval-time requirements after day 180 really permit archive restores, and that minimum-duration rules line up with the transition schedule. ([AWS Documentation][8])

---

# 49. Alternative 100-TB Scenario

Business says:

> “We have no idea which media will suddenly become popular.”

Then:

```text
manually predicting
hot → warm → cold
```

may be the wrong model.

Think:

```text
S3 Intelligent-Tiering
```

because AWS automatically manages eligible objects across Frequent, Infrequent and Archive Instant tiers according to observed access, with optional asynchronous archive tiers if the workload permits them. ([AWS Documentation][2])

---

# 50. 500-TB Backup Scenario

Requirement:

```text
Daily backups
500 TB retained

First 30 days:
occasionally restore

30–365 days:
very rare restore

1–7 years:
compliance only
```

Potential design:

```text
Recent backups
STANDARD / STANDARD_IA
       │
       ▼
Glacier Flexible Retrieval
       │
       ▼
Glacier Deep Archive
```

And combine:

```text
Versioning where appropriate
Object Lock for immutability
Lifecycle
cross-account protection
Inventory / Storage Lens
restore testing
```

Do **not** focus only on:

```text
lowest storage $/GB
```

because a DR system is worthless if its restore time violates the business RTO.

---

# 51. Scenario — Huge Number of Tiny Log Files

Suppose:

```text
2 billion log files
average size:
5 KB
```

Your first instinct should **not** be:

```text
"Move all 2 billion to Glacier!"
```

Investigate:

```text
object-count overhead
transition request cost
minimum billable sizes
archive metadata overhead
query/read pattern
```

Potentially consider batching/compacting records into formats such as:

```text
Parquet
larger compressed objects
```

depending on the analytics architecture.

This is a classic data-lake optimization pattern because **object shape** affects both cost and performance.

---

# 52. Scenario — Build Artifacts

Imagine Jenkins stores:

```text
app-1.0.0.tar.gz
app-1.0.1.tar.gz
...
app-4.8.7.tar.gz
```

Requirements:

```text
last 10 releases:
frequently used

releases <6 months:
rarely needed for rollback

older:
retain 2 years
```

Possible Lifecycle:

```text
new
STANDARD

after 90 days
STANDARD_IA / Glacier IR

after 365 days
Glacier Flexible or Deep Archive

after 730 days
expire
```

Now S3 becomes a controlled DevOps artifact repository rather than an infinite pile of forgotten tarballs.

---

# 53. Scenario — Logs

Application logs:

```text
Today:
incident debugging

1–30 days:
security investigations

31–365 days:
compliance queries

after 1 year:
not required
```

Potential:

```text
Standard
   ↓
IA / Intelligent-Tiering
   ↓
archive if query latency allows
   ↓
expiration
```

But if Athena queries those logs frequently, archiving them into classes requiring restore can make the analytics workflow painful.

Again:

```text
Access pattern
before storage price.
```

---

# 54. SAA-C03 Scenario

> Objects are accessed unpredictably. Some become cold, then suddenly become hot again. Millisecond access must remain available.

Think:

```text
S3 Intelligent-Tiering
```

because the automatic Frequent/Infrequent/Archive Instant tiers respond to access patterns while remaining low-latency. ([AWS Documentation][2])

---

# 55. Scenario

> Objects are accessed once per quarter but must be available immediately.

Think:

```text
S3 Glacier Instant Retrieval
```

AWS specifically positions it for quarterly-style access with millisecond retrieval. ([AWS Documentation][3])

---

# 56. Scenario

> Archive is restored one or two times a year and several hours is acceptable.

Think:

```text
S3 Glacier Flexible Retrieval
```

with an appropriate Expedited, Standard or Bulk retrieval option depending on urgency. ([AWS Documentation][3])

---

# 57. Scenario

> Records must be kept seven years and normally never accessed.

Think:

```text
S3 Glacier Deep Archive
```

possibly combined with:

```text
Object Lock
```

when retention immutability is required.

Deep Archive is designed for multi-year retention and rare access, with a 180-day minimum storage duration. ([AWS Documentation][3])

---

# 58. Scenario

> Backup must be restored within five minutes.

Do **not** choose:

```text
Deep Archive
```

just because it has low storage cost.

Its normal restore characteristics do not meet that RTO. ([AWS Documentation][4])

Could investigate:

```text
Glacier Instant Retrieval

or

different hot/warm recovery architecture
```

depending on cost and recovery requirements.

---

# 59. Scenario

> Millions of abandoned multipart uploads are consuming storage.

Think:

```text
Lifecycle
AbortIncompleteMultipartUpload
```

and use:

```text
Storage Lens
```

to identify the waste. ([AWS Documentation][12])

---

# 60. Scenario

> Versioned bucket is three times larger than expected.

Think:

```text
noncurrent versions
```

Check:

```text
S3 Storage Lens
S3 Inventory
Lifecycle configuration
```

and decide an appropriate:

```text
NoncurrentVersionExpiration
```

window. ([AWS Documentation][9])

---

# 61. Interview Question

> **How would you optimize a 500-TB S3 estate?**

A strong answer:

> I wouldn't start by blindly moving everything to Glacier. I'd first classify the data by access frequency, latency requirement, retention period, object size, recoverability, and RPO/RTO. I'd use S3 Storage Lens to identify cold buckets, incomplete multipart uploads, excessive noncurrent versions, and missing Lifecycle policies, and S3 Inventory for object-level analysis. For predictable access patterns I'd use Lifecycle transitions between appropriate classes; for unknown or changing patterns I'd consider Intelligent-Tiering. I'd account for minimum storage durations, retrieval fees, transition requests, and small-object overhead before archiving. For versioned buckets I'd separately manage noncurrent versions, and for long-term DR archives I'd routinely test Glacier restore procedures rather than only minimizing storage price. ([AWS Documentation][9])

That's a production FinOps answer.

---

# 62. Never-Forget Selection Tree

```text
How often is object accessed?
        │
        ├── frequently
        │       │
        │       ▼
        │    STANDARD
        │
        ├── unknown/changing
        │       │
        │       ▼
        │ INTELLIGENT-TIERING
        │
        └── infrequently
                │
                ▼
       Must access instantly?
          │           │
         YES          NO
          │           │
          ▼           ▼
      IA / Glacier   Can wait?
      Instant          │
                       ├── minutes/hours
                       │        │
                       │        ▼
                       │ Glacier Flexible
                       │
                       └── hours/day
                                │
                                ▼
                         Glacier Deep Archive
```

---

# 63. Minimum-Duration Memory Trick

```text
STANDARD
=
0
```

```text
STANDARD-IA
ONE ZONE-IA
=
30 DAYS
```

```text
GLACIER INSTANT
GLACIER FLEXIBLE
=
90 DAYS
```

```text
DEEP ARCHIVE
=
180 DAYS
```

These are the current minimum storage durations for the primary classes we're studying. ([AWS Documentation][1])

Memory sequence:

```text
0
30
90
180
```

---

# 64. Glacier Retrieval Memory Trick

```text
Instant
=
NOW
```

```text
Flexible

Expedited ≈ minutes
Standard  ≈ hours
Bulk      ≈ many hours
```

```text
Deep Archive

Standard ≈ half-day
Bulk     ≈ up to ~2 days
```

Current AWS documentation gives typical Flexible Retrieval windows of 1–5 minutes / 3–5 hours / 5–12 hours and Deep Archive windows of about 12 hours Standard or 48 hours Bulk. ([AWS Documentation][4])

---

# 65. The Most Important Cost Formula

Don't memorize only:

```text
$/GB/month
```

Think:

```text
S3 Cost
 =
Storage
+
Requests
+
Transitions
+
Retrievals
+
Minimum-duration penalties
+
Small-object overhead
+
Noncurrent versions
+
Incomplete multipart parts
+
Replication
+
Transfer
+
Encryption-related request costs
```

Then optimize the **whole workload**.

---

# 66. Never-Forget Lifecycle Model

```text
             OBJECT CREATED
                    │
                    ▼
                 Current
                    │
              Lifecycle
                    │
      ┌─────────────┼─────────────┐
      ▼             ▼             ▼
 Transition       Expire        Versioning
      │                            │
      ▼                            ▼
Lower-cost               Noncurrent Versions
storage                         │
                                ▼
                       Transition / Expire

Meanwhile:

Incomplete Multipart Upload
            │
            ▼
          Abort

Expired Delete Marker
            │
            ▼
          Remove
```

---

# 67. 12 Rules to Burn Into Memory

```text
1. Cheapest $/GB does not mean cheapest workload.

2. Standard = frequent access.

3. Standard-IA = infrequent + instant access.

4. One Zone-IA sacrifices AZ resilience for lower cost.

5. Intelligent-Tiering = unknown/changing access.

6. Glacier Instant = rare but immediate retrieval.

7. Glacier Flexible = archive, minutes/hours.

8. Deep Archive = very cold, long-term retention.

9. Lifecycle automates transition and expiration.

10. Versioned buckets need noncurrent-version lifecycle.

11. Abort incomplete multipart uploads.

12. Always design storage class around RTO/RPO and access behavior.
```

And especially:

```text
ARCHIVE
≠
BACKUP STRATEGY
```

and:

```text
LOW STORAGE COST
≠
LOW TOTAL COST
```

---

# ✅ Lesson 27 Part 4 Complete

We now understand:

```text
✓ S3 Standard
✓ Intelligent-Tiering
✓ Frequent Access tier
✓ Infrequent Access tier
✓ Archive Instant Access
✓ optional archive tiers
✓ Standard-IA
✓ One Zone-IA
✓ Glacier Instant Retrieval
✓ Glacier Flexible Retrieval
✓ Glacier Deep Archive
✓ minimum storage durations
✓ minimum billable sizes
✓ retrieval costs
✓ Glacier restores
✓ temporary restored copies
✓ Expedited / Standard / Bulk
✓ Lifecycle transitions
✓ object-size transition behavior
✓ lifecycle expiration
✓ noncurrent versions
✓ delete-marker cleanup
✓ incomplete multipart cleanup
✓ versioned-bucket cost control
✓ Terraform lifecycle rules
✓ S3 Storage Lens
✓ S3 Inventory
✓ Athena + Inventory concept
✓ 100-TB / 500-TB architecture design
✓ DevOps artifact lifecycle
✓ backup/archive cost engineering
```

# Next — Lesson 27 Part 5

## **S3 Performance Engineering, Multipart Uploads, Presigned URLs & Event-Driven Architecture**

We'll now move from:

```text
"Where should my object live?"
```

to:

```text
"How do applications upload/download
millions or billions of objects efficiently?"
```

We will cover:

```text
S3 PERFORMANCE & APPLICATION INTEGRATION

→ S3 request-rate scaling
→ key-prefix performance myths
→ GET / PUT concurrency
→ multipart upload sizing
→ parallel upload
→ parallel ranged GET
→ byte-range requests
→ checksums / ETags
→ Transfer Acceleration
→ when Transfer Acceleration helps
→ presigned GET URLs
→ presigned PUT URLs
→ direct browser → S3 uploads
→ avoiding uploads through EC2
→ CORS
→ S3 event notifications
→ S3 → Lambda
→ S3 → SQS
→ S3 → SNS
→ S3 → EventBridge
→ duplicate/out-of-order event design
→ idempotency
→ event filtering by prefix/suffix
→ VPC endpoints
→ private application access
→ CloudWatch S3 metrics
→ request logging
→ performance troubleshooting
→ final application upload architecture
```

This is the section where we'll redesign a traditional application from:

```text
Browser
   ↓
ALB
   ↓
EC2
   ↓
upload 5-GB file
   ↓
EC2 forwards to S3
```

into the much better cloud-native pattern:

```text
Browser
   │
   │ request authorization
   ▼
Application API
   │
   ▼
Presigned S3 URL

Browser
   │
   │ direct upload
   ▼
S3
   │
   ▼
Event
   │
   ▼
Lambda / SQS / processing pipeline
```

That architecture connects **S3, IAM, EC2 Auto Scaling, networking, serverless, event-driven design, performance, and cost optimization** all in one flow.

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html "Understanding and managing Amazon S3 storage classes - Amazon Simple Storage Service"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/intelligent-tiering-overview.html "How S3 Intelligent-Tiering works - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/glacier-storage-classes.html "Understanding S3 Glacier storage classes for long-term data storage - Amazon Simple Storage Service"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/restoring-objects-retrieval-options.html "Understanding archive retrieval options - Amazon Simple Storage Service"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/archival-storage.html "Understanding archival storage in S3 Glacier Flexible Retrieval and S3 Glacier Deep Archive - Amazon Simple Storage Service"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/restoring-objects.html?utm_source=chatgpt.com "Restoring an archived object - Amazon Simple Storage Service"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html?utm_source=chatgpt.com "Managing the lifecycle of objects"
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html "Transitioning objects using Amazon S3 Lifecycle - Amazon Simple Storage Service"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-lens-optimize-storage.html "Using Amazon S3 Storage Lens to optimize your storage costs - Amazon Simple Storage Service"
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html?utm_source=chatgpt.com "Examples of S3 Lifecycle configurations"
[11]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/ManagingDelMarkers.html?utm_source=chatgpt.com "Managing delete markers - Amazon Simple Storage Service"
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpu-abort-incomplete-mpu-lifecycle-config.html?utm_source=chatgpt.com "Configuring a bucket lifecycle configuration to delete ..."
[13]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration?utm_source=chatgpt.com "aws_s3_bucket_lifecycle_config..."
[14]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-inventory.html "Cataloging and analyzing your data with S3 Inventory - Amazon Simple Storage Service"
