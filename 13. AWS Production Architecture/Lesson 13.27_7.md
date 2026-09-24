# AWS Masterclass — Lesson 27 Part 7

# Advanced S3 Architecture, Multi-Region Access, Enterprise Governance & Final Review

We have now covered the S3 features most application teams use every day:

```text
Object model
   ↓
Security
   ↓
Versioning / Object Lock
   ↓
Storage classes / Lifecycle
   ↓
Performance / Presigned URLs / Events
   ↓
CloudFront + OAC
```

Now we move into the enterprise layer:

```text
                     ENTERPRISE S3

                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
     Access Points     Multi-Region     Access Grants
          │             Access Point         │
          │                │                 │
   dataset access      global routing   identity→dataset
          │                │                 │
          └────────────────┼─────────────────┘
                           ▼
                     Batch Operations
                           │
                     Inventory / Lens
                           │
                           ▼
                Governance / Security
                           │
                  Macie / CloudTrail
                           │
                           ▼
                      Data Lake
                           │
               Glue / Athena / Lake Formation
                           │
                           ▼
                S3 Express One Zone
```

---

# 1. Why S3 Access Points Exist

Imagine one enterprise bucket:

```text
company-data

├── finance/
├── hr/
├── engineering/
├── analytics/
├── ml/
├── audit/
└── backups/
```

Now imagine:

```text
Finance App
Analytics Platform
ML Team
HR System
Audit Team
External Partner
```

all need different permissions.

One giant bucket policy can become:

```text
2,000 lines
+
dozens of principals
+
prefix conditions
+
VPC conditions
+
cross-account rules
+
service permissions
```

At some point, one bucket policy becomes an operational liability.

S3 Access Points provide named endpoints attached to an underlying data source and allow each access point to have its own permissions and network controls. ([AWS Documentation][1])

---

# 2. Access Point Mental Model

Instead of:

```text
Finance App ───────────┐
Analytics ─────────────┤
ML ────────────────────┤
HR ────────────────────┼──▶ one bucket endpoint
Partners ──────────────┤        │
Audit ─────────────────┘        ▼
                         giant bucket policy
```

use:

```text
                         S3 Bucket
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
 Finance AP          Analytics AP          ML AP
     │                    │                  │
Finance policy       Analytics policy       ML policy
```

Each Access Point gives you a separate endpoint and policy boundary for requests made through it. ([AWS Documentation][1])

### Never forget

```text
S3 Access Point
=
application-specific
S3 access endpoint
```

This is conceptually similar to what we learned with EFS Access Points—but the implementation and service semantics are completely different.

---

# 3. Access Point Does Not Create Another Copy of the Data

Creating:

```text
finance-access-point
```

does **not** create:

```text
another S3 bucket
another copy
another dataset
```

The access point provides another controlled route into the underlying data source. AWS describes Access Points as named network endpoints attached to a bucket or another supported data source. ([AWS Documentation][2])

Think:

```text
                ONE DATASET
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
    AP-A          AP-B          AP-C
```

---

# 4. Access Point Policy + Bucket Policy

This is important.

An Access Point policy cannot magically override the underlying bucket's permissions. For a general-purpose bucket, permissions granted by the Access Point are effective only when the underlying bucket also permits the access. AWS recommends delegating access control from the bucket to its Access Points when direct bucket access is not required. ([AWS Documentation][3])

Think:

```text
Request
   │
   ▼
Access Point Policy
   │
   ▼
Underlying Bucket Policy
   │
   ▼
IAM / other controls
   │
   ▼
ALLOW / DENY
```

---

# 5. Access Point ARN Is Different

An object through the normal bucket uses:

```text
arn:aws:s3:::company-data/finance/report.pdf
```

An Access Point object resource uses an ARN form containing:

```text
accesspoint/<name>/object/...
```

For object operations through an Access Point, AWS requires the `/object/` component in the resource ARN. ([AWS Documentation][4])

Conceptually:

```text
arn:aws:s3:ap-south-1:123456789012:
accesspoint/finance-ap/object/*
```

This is another place where IAM troubleshooting requires knowing **which kind of S3 resource ARN** you are authorizing.

---

# 6. VPC-Only Access Points

A very powerful design is:

```text
S3 Access Point
Network origin:
VPC
```

Then only requests originating through the specified VPC network path can use that Access Point. AWS explicitly allows Access Points to be restricted to a VPC, and a VPC-origin Access Point is considered non-public. ([AWS Documentation][5])

Architecture:

```text
Internet
   │
   X
   │

Private EC2
   │
   ▼
VPC Endpoint
   │
   ▼
VPC-only S3 Access Point
   │
   ▼
S3
```

This can make the application's intended data path much clearer.

---

# 7. VPC Endpoint Policy Still Matters

Suppose:

```text
Access Point Policy = ALLOW
Bucket Policy       = ALLOW
IAM                 = ALLOW
```

but:

```text
VPC Endpoint Policy = DENY
```

The request still fails.

AWS notes that VPC access to an Access Point requires the endpoint policy to permit access to both the Access Point and the underlying bucket. ([AWS Documentation][5])

So your troubleshooting chain becomes:

```text
IAM
 ↓
Access Point
 ↓
Bucket
 ↓
VPC Endpoint Policy
 ↓
KMS
```

---

# 8. Access Point Example Architecture

Suppose we have:

```text
company-prod-data
```

We create:

```text
finance-ap
analytics-ap
backup-ap
```

Policy intentions:

```text
finance-ap
→ FinanceRole
→ finance/*

analytics-ap
→ AnalyticsRole
→ read selected data

backup-ap
→ BackupRole
→ backup workloads
```

The underlying bucket can delegate access control to Access Points owned by the trusted account, while each AP then expresses application-specific restrictions. AWS recommends delegation through Access Points for workloads that don't need direct bucket access. ([AWS Documentation][3])

---

# 9. Terraform Access Point

The current HashiCorp AWS provider has a dedicated:

```text
aws_s3_access_point
```

resource. ([Terraform Registry][6])

Conceptually:

```hcl
resource "aws_s3_access_point" "analytics" {
  bucket = aws_s3_bucket.data.id
  name   = "analytics-access"

  vpc_configuration {
    vpc_id = aws_vpc.main.id
  }
}
```

This is exactly the sort of resource you would wrap inside an enterprise S3 Terraform module.

---

# 10. Access Point vs Bucket

Memorize this distinction:

```text
BUCKET
=
stores objects
```

```text
ACCESS POINT
=
controlled endpoint
into those objects
```

An Access Point is therefore primarily an **access architecture** feature, not a new storage layer. ([AWS Documentation][1])

---

# 11. Multi-Region Problem

Now imagine:

```text
Users:
India
Europe
North America

Buckets:
Mumbai
Ireland
Virginia
```

Applications could manually implement:

```text
if user == Asia:
    use Mumbai

elif user == Europe:
    use Ireland

else:
    use Virginia
```

But then your application owns:

```text
routing
failure handling
endpoint selection
regional health logic
```

S3 Multi-Region Access Points provide a **global S3 endpoint** across buckets in multiple Regions. ([AWS Documentation][7])

---

# 12. Multi-Region Access Point — MRAP

Architecture:

```text
                        GLOBAL CLIENTS
                              │
                              ▼
                  Multi-Region Access Point
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
          ap-south-1      eu-west-1      us-east-1
              │               │              │
           Bucket A        Bucket B       Bucket C
```

Applications use the Multi-Region Access Point's global endpoint rather than hardcoding an individual regional bucket endpoint. ([AWS Documentation][7])

---

# 13. Request Routing

S3 normally routes requests through a Multi-Region Access Point based on proximity to the available underlying buckets. ([AWS Documentation][8])

Think:

```text
User India
   │
   ▼
MRAP
   │
   ▼
Mumbai bucket
```

```text
User Europe
   │
   ▼
MRAP
   │
   ▼
European bucket
```

But there is a critical catch.

---

# 14. MRAP Does Not Search Buckets for Your Object

Suppose:

```text
Mumbai:
photo.jpg exists

Ireland:
photo.jpg missing
```

Client in Europe requests:

```text
GET photo.jpg
```

The MRAP can route to Ireland because that bucket is closer.

It does **not** first check:

> “Which bucket contains `photo.jpg`?”

If Ireland doesn't contain it, you can receive:

```text
404
```

even though the object exists in Mumbai. AWS explicitly documents this behavior. ([AWS Documentation][8])

### Huge lesson

```text
MRAP
=
routing

NOT
=
replication
```

---

# 15. Therefore MRAP + Replication Usually Go Together

For a consistent multi-region dataset:

```text
                MRAP
                 │
       ┌─────────┴──────────┐
       ▼                    ▼
    Mumbai               Ireland
    Bucket                Bucket
       │                    ▲
       │       CRR          │
       └────────────────────┘
```

AWS recommends configuring Cross-Region Replication when the same dataset must exist in the buckets behind a Multi-Region Access Point. ([AWS Documentation][8])

This connects directly to Part 3.

---

# 16. Multi-Region PUT

Suppose a user in Mumbai performs:

```text
PUT uploads/video.mp4
```

through the MRAP.

S3 routes the creation request to the closest appropriate bucket. If the application needs that new object available through the other Regional buckets, replication must copy it there. ([AWS Documentation][8])

Architecture:

```text
India User
   │
   ▼
MRAP
   │
   ▼
Mumbai Bucket
   │
   │ CRR
   ▼
Europe Bucket
```

---

# 17. Active-Active vs Active-Passive

MRAP failover configuration can operate in:

```text
active-active
```

or:

```text
active-passive
```

routing states. ([AWS Documentation][9])

### Active-active

```text
Region A = active
Region B = active
```

Traffic can use both.

### Active-passive

```text
Region A = active
Region B = passive
```

Traffic normally stays with the active side until you change routing.

---

# 18. MRAP Failover Controls

If a Regional traffic disruption occurs, Multi-Region Access Point failover controls allow you to shift S3 data-request traffic away from the affected Region. AWS also explicitly supports using the controls for DR testing and game days. ([AWS Documentation][7])

Conceptually:

```text
NORMAL

Region A
 ACTIVE

Region B
 PASSIVE


DISASTER

Region A
 PASSIVE

Region B
 ACTIVE
```

This gives the application:

```text
same global endpoint
```

while routing behavior changes underneath.

---

# 19. The Big DR Advantage

Without MRAP:

```text
Application config:
bucket-a.s3...
```

Failover:

```text
update configuration
update DNS/application
deploy
```

With MRAP:

```text
Application
     │
     ▼
same global endpoint
     │
     ▼
routing control changes
```

MRAP is therefore useful when you want multi-Region S3 routing/failover without teaching every client how to select individual regional bucket endpoints. ([AWS Documentation][7])

---

# 20. But MRAP Isn't Magical Active-Active Data Consistency

Remember:

```text
routing
+
replication
```

are separate.

If asynchronous replication hasn't copied an object yet:

```text
Region A:
V10

Region B:
V9
```

then routing to B can expose the older replicated state.

Your RPO is therefore still affected by replication behavior. MRAP routing does not convert S3 CRR into synchronous storage replication. ([AWS Documentation][8])

---

# 21. MRAP Security

A Multi-Region Access Point can have its own resource policy. The underlying bucket policies still matter, and AWS recommends delegating bucket access to the MRAP when you don't need direct bucket access. ([AWS Documentation][10])

Think:

```text
IAM
  │
  ▼
MRAP Policy
  │
  ▼
Bucket Policy
  │
  ▼
Object
```

Again:

```text
more restrictive applicable policy wins.
```

---

# 22. MRAP Block Public Access

Multi-Region Access Points also have their own Block Public Access settings, and AWS enables all of them by default. Those settings cannot be changed after MRAP creation. Account-level public-access restrictions can also continue to apply. ([AWS Documentation][10])

Production lesson:

```text
Decide BPA correctly
BEFORE
creating MRAP.
```

---

# 23. Terraform MRAP

The current Terraform AWS provider provides:

```text
aws_s3control_multi_region_access_point
```

for the MRAP itself, plus separate resources for its policy and routing configuration. ([Terraform Registry][11])

This makes multi-Region failover configuration manageable as infrastructure as code rather than a console-only DR procedure.

---

# 24. Access Points vs Multi-Region Access Points

Never mix these:

```text
S3 Access Point
=
controlled access endpoint
for a dataset
```

```text
Multi-Region Access Point
=
global endpoint
routing across regional buckets
```

Both involve the words “Access Point,” but their architecture purpose is different. ([AWS Documentation][1])

---

# 25. S3 Access Grants

Now imagine:

```text
10 users
```

IAM policies are manageable.

But imagine:

```text
40,000 employees

3,000 datasets

hundreds of groups

many prefixes
```

You don't want to manually construct enormous mappings such as:

```text
Alice → finance/2026/*
Bob → engineering/*
Team A → project-x/*
Team B → analytics/customer/*
...
```

S3 Access Grants provides a scalable model for mapping IAM principals or corporate directory identities to buckets, prefixes, or objects. ([AWS Documentation][12])

---

# 26. Access Grants Mental Model

```text
                    S3 DATA
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
          /hr       /finance   /engineering
            ▲          ▲          ▲
            │          │          │
       Access Grant Access Grant Access Grant
            ▲          ▲          ▲
            │          │          │
         HR Group   Finance     Engineer
```

You can define:

```text
READ
WRITE
READWRITE
```

style dataset access at granular S3 locations for IAM principals and supported corporate-directory identities. ([AWS Documentation][12])

---

# 27. Access Grants Can Vendor Temporary Credentials

One of the most interesting pieces is that S3 Access Grants acts as a credential vending layer.

A caller:

```text
1. asks Access Grants for access
2. Access Grants checks matching grant
3. if authorized:
      returns temporary least-privilege credentials
4. caller uses credentials for S3
```

AWS explicitly describes Access Grants as an S3 credential vendor. ([AWS Documentation][13])

Architecture:

```text
Corporate User
     │
     ▼
S3 Access Grants
     │
  matching grant?
     │
     ▼
temporary credentials
     │
     ▼
S3 dataset
```

---

# 28. Access Grants Locations

An Access Grants **location** maps:

```text
s3://

or

bucket

or

prefix
```

to an IAM role that Access Grants can assume when vending credentials. ([AWS Documentation][14])

For example:

```text
Location:
s3://company-data/engineering/

Role:
S3AccessGrantsEngineeringRole
```

Then individual grants can map identities into portions of that registered location.

---

# 29. Corporate Directory Integration

S3 Access Grants can integrate with IAM Identity Center so that corporate-directory users and groups can receive S3 data access grants rather than requiring each human user to be modeled as a standalone IAM user. ([AWS Documentation][15])

Architecture:

```text
Corporate IdP
     │
     ▼
IAM Identity Center
     │
     ▼
S3 Access Grants
     │
     ▼
S3 prefixes
```

This is much closer to how a large enterprise actually thinks:

```text
Finance Analysts Group
→ finance dataset
```

rather than:

```text
IAM user Alice
IAM user Bob
IAM user Carol
...
```

---

# 30. One Access Grants Instance per Region per Account

S3 Access Grants is a regional construct; AWS currently allows one Access Grants instance per Region per account, and you create it in the Region containing the S3 data you want to manage. ([AWS Documentation][16])

This matters when designing:

```text
Mumbai data
+
Singapore data
+
Ireland data
```

because governance is still Region-aware.

---

# 31. Access Grants vs Access Points

Another critical distinction:

```text
Access Point
=
HOW an application reaches
an S3 dataset
```

```text
Access Grants
=
WHO is entitled
to WHICH S3 dataset
```

They can complement each other, but they solve different scaling problems. ([AWS Documentation][1])

---

# 32. S3 Batch Operations

Now imagine:

```text
500 million objects
```

and management says:

> Add a tag to every object.

Do you write:

```python
for object in objects:
    update_tag(object)
```

and run your laptop for four weeks?

No.

S3 Batch Operations performs one supported action across a large list of S3 objects. ([AWS Documentation][17])

---

# 33. Batch Operations Architecture

```text
Object Manifest
     │
     │ contains object list
     ▼
S3 Batch Operations Job
     │
     ├── IAM Role
     ├── Operation
     ├── Priority
     └── Completion Report
     │
     ▼
Millions/Billions of objects
```

Batch Operations can use a manifest supplied by you or generate an object list based on supported metadata criteria, and jobs can produce completion reports. ([AWS Documentation][18])

---

# 34. Batch Operations Scale

Current S3 documentation states that Batch Operations jobs can process up to **4 billion objects by default** for general operations; selected operation types—including Copy, tagging, Object Lock actions, Lambda invocation, and Batch Replication—can support up to **20 billion objects**. ([AWS Documentation][17])

That immediately tells you its target scale:

```text
not
"update 20 objects"

but

"operate across enormous S3 estates"
```

---

# 35. What Can Batch Operations Do?

Examples include:

```text
Copy objects
Change tags
Restore archive objects
Manage Object Lock retention
Manage legal holds
Invoke Lambda for custom processing
Batch Replication
```

AWS documents all of these as supported Batch Operations patterns. ([AWS Documentation][19])

---

# 36. Example — Update Encryption Across Millions of Objects

Suppose an organization decides:

```text
Old:
SSE-S3

New requirement:
SSE-KMS
```

Instead of manually re-uploading millions of objects, you can use a large-scale copy/update workflow with S3 Batch Operations. Batch Operations supports copy actions and changing object properties such as storage class and metadata during copy. ([AWS Documentation][19])

Conceptually:

```text
Inventory / object list
       │
       ▼
Batch Operations
       │
       ▼
Copy each object
       │
       ▼
new encryption configuration
```

You still need to evaluate KMS permissions, costs, request rate, versioning implications, and compliance requirements.

---

# 37. Example — Apply Legal Hold to Millions of Objects

Requirement:

> Legal department says all investigation objects must be frozen immediately.

You can create a Batch Operations manifest and run an Object Lock legal-hold job across the listed object versions. ([AWS Documentation][20])

Architecture:

```text
Investigation object list
        │
        ▼
Batch Operations
        │
        ▼
LegalHold = ON
        │
        ▼
millions of versions protected
```

That's much more realistic than scripting one API call per object from an engineer's workstation.

---

# 38. S3 Inventory + Batch Operations

These two work extremely well together.

```text
S3 Bucket
    │
    ▼
S3 Inventory
    │
 object list
    ▼
Batch Operations Manifest
    │
    ▼
Bulk job
```

AWS explicitly documents using S3 Inventory reports as manifests for large-scale Batch Operations workflows, including cross-account copies. ([AWS Documentation][21])

---

# 39. Inventory vs ListObjects

Remember:

```text
ListObjectsV2
=
interactive API listing
```

```text
S3 Inventory
=
scheduled catalog/report
```

S3 Inventory provides a scheduled alternative to repeatedly calling the synchronous List API against huge buckets. ([AWS Documentation][21])

Use Inventory for questions such as:

```text
Which objects use SSE-S3?
Which objects failed replication?
Which objects are in Glacier?
Which versions are noncurrent?
Which objects need migration?
```

---

# 40. Storage Lens vs Inventory

This distinction should now be automatic:

```text
STORAGE LENS
=
aggregate estate-level analytics
```

```text
INVENTORY
=
object-level catalog/report
```

Storage Lens gives organization/account/bucket/prefix visibility and contextual recommendations, while Inventory gives scheduled records about individual objects and their metadata. ([AWS Documentation][22])

---

# 41. Example Enterprise Workflow

Management asks:

> Which 50 TB of data should we archive?

Possible workflow:

```text
S3 Storage Lens
      │
      ▼
find large/cold buckets
      │
      ▼
S3 Inventory
      │
      ▼
identify exact objects
      │
      ▼
Athena
      │
      ▼
SQL select candidate objects
      │
      ▼
Batch Operations
      │
      ▼
copy/tag/process selected objects
```

Now cost optimization becomes reproducible engineering rather than guesswork. ([AWS Documentation][22])

---

# 42. S3 Express One Zone

Now we move to a very different S3 workload.

Normal S3 Standard is designed for enormous scale and high throughput.

But some applications need:

```text
extremely latency-sensitive
object access
```

S3 Express One Zone is a high-performance, **single-AZ** S3 storage class designed for consistent single-digit millisecond data access. AWS recommends co-locating compute in the same AZ for best latency. ([AWS Documentation][23])

---

# 43. Directory Buckets

S3 Express One Zone objects are stored in:

# Directory buckets

not ordinary general-purpose buckets. ([AWS Documentation][23])

Architecture:

```text
             ap-south-1
                 │
          ┌──────┴──────┐
          │             │
       AZ-A            AZ-B

        EC2
         │
         ▼
 Directory Bucket
 S3 Express One Zone
       AZ-A
```

To minimize latency, keep the compute and directory bucket in the same Availability Zone whenever possible. ([AWS Documentation][24])

---

# 44. One Zone Means One Zone

Unlike standard multi-AZ S3 storage classes:

```text
S3 Express One Zone
=
single Availability Zone
```

You explicitly choose the AZ containing the directory bucket. ([AWS Documentation][25])

This means the decision is:

```text
lower latency
+
high performance
```

in exchange for a different resilience model than multi-AZ S3 Standard.

Do not choose it merely because:

```text
"Express sounds faster."
```

Choose it because the workload requires it.

---

# 45. Typical S3 Express Workloads

AWS positions S3 Express One Zone for high-performance, latency-sensitive workloads, including analytics and AI/ML workflows. It integrates with services such as Athena, EMR, Glue, and SageMaker workflows. ([AWS Documentation][23])

Think:

```text
ML training intermediate data
high-performance analytics
large-scale data processing
latency-sensitive object access
```

rather than:

```text
7-year archive
```

---

# 46. Directory Bucket Endpoints

Directory buckets have different endpoint behavior from general-purpose buckets.

Bucket management uses Regional APIs, while most data-plane object operations use **Zonal endpoints**. ([AWS Documentation][26])

Mental model:

```text
Create/manage bucket
        │
        ▼
Regional endpoint


PUT/GET objects
        │
        ▼
Zonal endpoint
```

This reinforces the fact that S3 Express One Zone is tied closely to the selected AZ.

---

# 47. Directory Bucket Authorization

The data-plane authorization model also differs.

For most Zonal object APIs, applications use:

```text
CreateSession
```

to obtain session credentials optimized for low-latency requests. The principal needs:

```text
s3express:CreateSession
```

permission. ([AWS Documentation][27])

Architecture:

```text
Application Role
      │
      ▼
s3express:CreateSession
      │
      ▼
short-lived session
      │
      ▼
Zonal S3 Express endpoint
```

Don't assume every IAM pattern from ordinary general-purpose S3 transfers unchanged.

---

# 48. Directory Bucket Limits

AWS currently documents a default quota of up to **100 directory buckets per Region per account**, with no object-count limit within an individual directory bucket; AWS Support can be contacted if a higher bucket quota is required. ([AWS Documentation][28])

Again, this is a specialized resource type—not simply:

```text
aws_s3_bucket
+
fast=true
```

---

# 49. Terraform Directory Bucket

HashiCorp now provides:

```text
aws_s3_directory_bucket
```

specifically for S3 Express directory buckets; ordinary general-purpose S3 still uses `aws_s3_bucket`. ([Terraform Registry][29])

That separation in Terraform reflects the service-level distinction.

---

# 50. S3 Standard vs S3 Express One Zone

| S3 Standard                     | S3 Express One Zone                    |
| ------------------------------- | -------------------------------------- |
| General-purpose bucket          | Directory bucket                       |
| Multi-AZ storage model          | Single selected AZ                     |
| General workloads               | Latency-sensitive workloads            |
| Regional S3 endpoint model      | Zonal object endpoints                 |
| Normal IAM object authorization | Session-based data-plane authorization |
| Broad default starting point    | Specialized performance choice         |

These distinctions follow AWS's current directory-bucket and S3 Express architecture. ([AWS Documentation][25])

---

# 51. S3 as a Data Lake

Now connect S3 with analytics.

A classic AWS data-lake architecture:

```text
               Data Producers
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
     Apps          Logs          IoT
        \            |            /
         \           |           /
                  Amazon S3
                     │
                  raw data
                     │
                     ▼
              AWS Glue Catalog
                     │
             schema / metadata
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
     Athena         Glue         EMR
        │
        ▼
       SQL
```

Lake Formation can add centralized governance and fine-grained permissions for data in S3 and metadata in the Glue Data Catalog. ([AWS Documentation][30])

---

# 52. Glue Data Catalog

Think of the Glue Data Catalog as:

```text
"What data exists?
Where is it?
What schema does it have?"
```

Example:

```text
Database:
prod_logs

Table:
alb_logs

Columns:
timestamp
client_ip
status
request_path

Location:
s3://company-data/logs/alb/
```

Athena can then query the S3-backed dataset using standard SQL based on catalog/schema information. AWS uses Glue Data Catalog integration broadly across its S3 analytics ecosystem. ([AWS Documentation][31])

---

# 53. Lake Formation

IAM alone can become difficult when a data platform needs permissions such as:

```text
Analyst:
SELECT customer_name
but not SSN

Marketing:
selected tables

ML:
training datasets

Finance:
financial tables
```

Lake Formation provides centralized fine-grained access control over data-lake data stored in S3 and its Glue catalog metadata. ([AWS Documentation][30])

Think:

```text
IAM
=
AWS API/service identity permissions
```

```text
Lake Formation
=
data lake/table/data governance
```

They complement rather than replace one another.

---

# 54. Amazon Macie

Now security asks:

> Which S3 objects contain sensitive data?

Examples:

```text
credit-card data
identity information
credentials
personal information
financial records
```

Amazon Macie is AWS's S3-focused data-security service for discovering sensitive data using machine learning and pattern matching. It supports both automated sensitive-data discovery and targeted discovery jobs. ([AWS Documentation][32])

---

# 55. Macie Architecture

```text
               S3 Estate
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
    Bucket A    Bucket B    Bucket C
       \           |           /
        \          |          /
               Amazon Macie
                   │
                   ▼
          Sensitive-data analysis
                   │
                   ▼
                Findings
```

Macie can continually evaluate S3 inventory and sample eligible objects for automated sensitive-data discovery. ([AWS Documentation][33])

---

# 56. What Macie Is Not

Macie is not:

```text
an S3 firewall
```

and not:

```text
automatic encryption for every object
```

Think of it primarily as:

```text
DISCOVER
CLASSIFY
REPORT
```

for sensitive data, so security processes can respond appropriately. Macie generates sensitive-data findings when its analysis detects sensitive content. ([AWS Documentation][34])

---

# 57. CloudTrail + S3 Enterprise Audit

Remember from Part 5:

```text
CloudTrail management events
```

don't automatically mean:

```text
all object GET/PUT/DELETE activity
```

S3 object-level operations can be captured through CloudTrail **data events**, which must be explicitly configured for the relevant S3 resources. ([AWS Documentation][35])

So a high-security S3 environment might use:

```text
CloudTrail
   │
   ├── bucket management events
   └── object data events
             │
             ▼
            S3
             │
             ▼
          Athena
             │
             ▼
security queries
```

Athena can query CloudTrail logs stored in S3 directly. ([AWS Documentation][36])

---

# 58. Enterprise Multi-Account Design

A mature AWS Organization might separate:

```text
Application Accounts
Analytics Accounts
Security Account
Backup Account
Shared Services Account
```

and use S3 controls across account boundaries.

Conceptually:

```text
                 AWS ORGANIZATION
                       │
      ┌────────────────┼────────────────┐
      ▼                ▼                ▼
   App Acct       Analytics Acct     Security
      │                │                │
      ▼                ▼                ▼
     S3      ← Access Grants/APs →     Macie
      │
      │ replication
      ▼
   Backup Account
```

Access Points, cross-account Access Grants, replication, Storage Lens, and Macie can all contribute to these multi-account governance patterns. ([AWS Documentation][37])

---

# 59. Enterprise Guardrail Pattern

You can layer:

```text
AWS Organizations
       │
       ▼
SCPs
       │
       ▼
S3 Block Public Access
       │
       ▼
IAM
       │
       ▼
Access Points / Access Grants
       │
       ▼
Bucket Policies
       │
       ▼
KMS Policies
       │
       ▼
CloudTrail / Macie / Config
```

The important architecture principle is:

```text
NO SINGLE POLICY
should be your only security boundary.
```

S3 itself supports multiple independent policy and public-access controls, while services such as Macie and CloudTrail provide detection and audit capabilities around the data estate. ([AWS Documentation][38])

---

# 60. Final Enterprise Architecture

Let's connect everything from Lesson 27:

```text
                             USERS
                               │
                               ▼
                        Route 53 / DNS
                               │
                               ▼
                         CloudFront + WAF
                               │
                              OAC
                               │
                               ▼
                          Private S3
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
          Versioning       SSE-KMS         Lifecycle
              │                │                │
          Object Lock       KMS Key        Intelligent
              │                              Tiering
              │
              ▼
         Replication
              │
              ▼
          DR Account
              │
              └───────────────┐
                              │
              Applications    │
                   │          │
                   ▼          │
              Access Points   │
                   │          │
                   ▼          │
              VPC Endpoint    │
                              │
            Corporate Users   │
                   │          │
                   ▼          │
              Access Grants   │
                              │
           Multi-Region Apps  │
                   │          │
                   ▼          │
                   MRAP       │
                              │
                Governance ◀──┘
                   │
       ┌───────────┼────────────┐
       ▼           ▼            ▼
    Inventory   Storage Lens   Macie
       │                         │
       ▼                         ▼
 Batch Operations             Findings
       │
       ▼
     Athena
       │
       ▼
 Glue / Lake Formation
```

That is S3 as an **enterprise object-storage platform**, not merely:

```text
"a bucket to upload files."
```

---

# 61. Production Scenario — Bucket Policy Has Become Unmanageable

Problem:

```text
200 applications
one bucket
massive bucket policy
```

Think first:

```text
S3 Access Points
```

because they provide separate named endpoints with application-specific permissions/network controls. ([AWS Documentation][1])

---

# 62. Scenario — 30,000 Employees Need Dataset Access

Problem:

```text
IAM policies becoming
identity × prefix matrix
```

Think:

```text
S3 Access Grants
+
IAM Identity Center
```

when you need scalable mapping of corporate users/groups or IAM principals to S3 datasets. ([AWS Documentation][12])

---

# 63. Scenario — One Global S3 Endpoint Across Regions

Need:

```text
one application endpoint
+
regional routing
+
DR failover controls
```

Think:

```text
Multi-Region Access Point
+
CRR
```

MRAP handles routing; CRR keeps regional datasets synchronized. ([AWS Documentation][8])

---

# 64. Scenario — Region A Must Be Removed From Traffic

Think:

```text
MRAP failover controls
```

rather than changing bucket endpoints throughout every application. ([AWS Documentation][7])

---

# 65. Scenario — Change Tags on 800 Million Objects

Think:

```text
S3 Batch Operations
```

not:

```text
bash for loop
```

Batch Operations is specifically designed for bulk operations across massive object sets. ([AWS Documentation][17])

---

# 66. Scenario — Find Every Object Using Old Encryption

Think:

```text
S3 Inventory
      ↓
query/report
      ↓
Batch Operations
```

Inventory can report encryption state per object, while Batch Operations can act on a selected manifest. ([AWS Documentation][21])

---

# 67. Scenario — Why Is Our S3 Estate Cost Growing?

Think:

```text
Storage Lens
```

to investigate:

```text
growth by account
bucket
prefix
storage class
version accumulation
multipart waste
```

Storage Lens provides organization-wide object-storage usage/activity analytics and recommendations. ([AWS Documentation][22])

---

# 68. Scenario — Find PII Across Hundreds of Buckets

Think:

```text
Amazon Macie
```

for automated or targeted S3 sensitive-data discovery. ([AWS Documentation][39])

---

# 69. Scenario — Ultra-Low-Latency S3 Workload

Requirement:

```text
object storage
+
single-digit millisecond latency
+
compute can be co-located in one AZ
```

Think:

```text
S3 Express One Zone
+
Directory Bucket
```

not immediately:

```text
redesign all S3 buckets
```

because S3 Express uses a distinct single-AZ architecture and authorization/endpoint model. ([AWS Documentation][23])

---

# 70. SAA-C03 / DOP-C02 Rapid-Fire Review

| Requirement                                  | Best first thought                      |
| -------------------------------------------- | --------------------------------------- |
| Application-specific S3 endpoint             | **S3 Access Point**                     |
| S3 endpoint restricted to a VPC              | **VPC-origin Access Point**             |
| Global endpoint across regional buckets      | **Multi-Region Access Point**           |
| Regional traffic failover                    | **MRAP failover controls**              |
| Keep MRAP datasets synchronized              | **CRR**                                 |
| Thousands of users/groups mapped to prefixes | **S3 Access Grants**                    |
| Corporate directory integration              | **IAM Identity Center + Access Grants** |
| Bulk action on billions of objects           | **Batch Operations**                    |
| Scheduled object catalog                     | **S3 Inventory**                        |
| Organization-wide S3 analytics               | **Storage Lens**                        |
| Sensitive-data discovery                     | **Amazon Macie**                        |
| S3 object API auditing                       | **CloudTrail data events**              |
| SQL over data in S3                          | **Athena**                              |
| Dataset metadata/catalog                     | **Glue Data Catalog**                   |
| Fine-grained data-lake governance            | **Lake Formation**                      |
| Lowest-latency specialized S3 class          | **S3 Express One Zone**                 |
| S3 Express storage container                 | **Directory bucket**                    |

These map directly to the current AWS capabilities described above. ([AWS Documentation][1])

---

# 71. Final S3 Troubleshooting Framework

Whenever S3 fails, classify the problem first.

```text
                     S3 PROBLEM
                         │
       ┌─────────────────┼──────────────────┐
       ▼                 ▼                  ▼
    ACCESS            PERFORMANCE          DATA
       │                 │                  │
 IAM/Bucket           503 SlowDown       Version?
 AP/MRAP              concurrency        Deleted?
 BPA                  prefix             Replication?
 VPC Endpoint         multipart          Object Lock?
 KMS                  network            Lifecycle?
       │                 │                  │
       └─────────────────┼──────────────────┘
                         ▼
                     GOVERNANCE
                         │
               Inventory / Lens
               CloudTrail / Macie
```

This lets you troubleshoot systematically rather than changing bucket permissions randomly.

---

# 72. The S3 Master Mental Model

```text
                         AMAZON S3
                            │
                            ▼
                          BUCKET
                            │
                            ▼
                          OBJECT
                            │
                ┌───────────┼───────────┐
                ▼           ▼           ▼
               Key       Metadata      Version
                │
                ▼
             Prefixes

                            │
                            ▼
                         SECURITY
                            │
       IAM ─ Bucket Policy ─ BPA ─ KMS ─ AP/Grants

                            │
                            ▼
                      DATA PROTECTION
                            │
           Versioning ─ Object Lock ─ Replication

                            │
                            ▼
                         STORAGE
                            │
 Standard ─ IA ─ Intelligent Tiering ─ Glacier

                            │
                            ▼
                       PERFORMANCE
                            │
             Parallelism ─ Multipart ─ Range GET

                            │
                            ▼
                     APPLICATION ACCESS
                            │
             SDK ─ Presigned URL ─ CloudFront

                            │
                            ▼
                         EVENTS
                            │
             Lambda ─ SQS ─ SNS ─ EventBridge

                            │
                            ▼
                     ENTERPRISE SCALE
                            │
 Access Points ─ MRAP ─ Access Grants ─ Batch Ops

                            │
                            ▼
                       GOVERNANCE
                            │
        Inventory ─ Storage Lens ─ Macie ─ CloudTrail

                            │
                            ▼
                        ANALYTICS
                            │
                 Glue ─ Athena ─ Lake Formation
```

---

# 73. The 25 S3 Rules to Permanently Remember

```text
1. S3 is object storage.

2. Bucket = container.

3. Key = object identifier.

4. Prefix ≠ real filesystem directory.

5. S3 provides strong object read-after-write consistency.

6. One object can be very large; large transfers use multipart.

7. Bucket ARN and object ARN are different.

8. Explicit Deny wins.

9. Block Public Access should normally stay enabled.

10. BucketOwnerEnforced disables ACLs.

11. SSE-S3 is the baseline server-side encryption.

12. SSE-KMS adds KMS authorization.

13. Versioning preserves previous object versions.

14. DELETE in a versioned bucket usually creates a delete marker.

15. Object Lock provides WORM protection.

16. Replication ≠ backup.

17. Lifecycle controls storage cost over time.

18. Intelligent-Tiering fits unknown/changing access patterns.

19. Glacier class must match the application's restore RTO.

20. Presigned URLs let clients access private S3 temporarily.

21. CORS ≠ authorization.

22. S3 events are at-least-once; consumers must be idempotent.

23. CloudFront + OAC lets public users consume private S3 content.

24. Access Points simplify application-specific access.

25. MRAP, Access Grants, Batch Operations, Inventory,
    Storage Lens and Macie are enterprise-scale S3 tools.
```

---

# ✅ Lesson 27 — Amazon S3 COMPLETE

We have now covered S3 from zero through enterprise architecture:

```text
✓ Object storage fundamentals
✓ buckets
✓ keys
✓ prefixes
✓ strong consistency
✓ APIs / CLI / SDK
✓ multipart uploads
✓ modern large-object limits

✓ IAM
✓ bucket policies
✓ resource ARNs
✓ Block Public Access
✓ Object Ownership
✓ ACLs
✓ SSE-S3
✓ SSE-KMS
✓ KMS policies
✓ VPC endpoints
✓ 403 troubleshooting

✓ Versioning
✓ delete markers
✓ overwrite recovery
✓ MFA Delete
✓ Object Lock
✓ Governance
✓ Compliance
✓ legal holds
✓ CRR / SRR
✓ RTC
✓ Batch Replication

✓ Standard
✓ IA
✓ One Zone-IA
✓ Intelligent-Tiering
✓ Glacier IR
✓ Glacier Flexible
✓ Deep Archive
✓ Lifecycle
✓ noncurrent versions
✓ multipart cleanup
✓ Storage Lens
✓ Inventory

✓ request scaling
✓ multipart performance
✓ Range GET
✓ checksums
✓ Transfer Acceleration
✓ presigned URLs
✓ CORS
✓ event notifications
✓ Lambda
✓ SQS
✓ SNS
✓ EventBridge
✓ idempotency

✓ CloudFront
✓ OAC
✓ private S3
✓ ACM us-east-1
✓ DNS
✓ SPA routing
✓ caching
✓ invalidation
✓ signed URLs/cookies
✓ WAF
✓ Terraform

✓ S3 Access Points
✓ VPC-only Access Points
✓ Multi-Region Access Points
✓ MRAP failover
✓ S3 Access Grants
✓ IAM Identity Center integration
✓ Batch Operations
✓ enterprise Inventory workflows
✓ S3 Express One Zone
✓ directory buckets
✓ Macie
✓ CloudTrail auditing
✓ Athena
✓ Glue Data Catalog
✓ Lake Formation
✓ multi-account governance
```

At this point you should no longer think:

```text
S3
=
"some AWS bucket"
```

You should think:

```text
S3
=
distributed object-storage platform
+
security platform
+
data-protection platform
+
archive platform
+
CDN origin
+
event source
+
data-lake foundation
+
enterprise governance layer
```

---

# Next — Lesson 28: AWS Database Architecture

We will now move from:

```text
FILES / OBJECTS
```

to:

```text
TRANSACTIONAL DATA
```

and build the database decision model:

```text
                   AWS DATABASES
                        │
           ┌────────────┼────────────┐
           ▼            ▼            ▼
       Relational     NoSQL        Cache
           │            │            │
           ▼            ▼            ▼
        Amazon RDS    DynamoDB    ElastiCache
           │
           ├── MySQL
           ├── PostgreSQL
           ├── MariaDB
           ├── Oracle
           ├── SQL Server
           │
           ▼
        Amazon Aurora
           │
           ├── architecture
           ├── writer / readers
           ├── Multi-AZ
           ├── replicas
           ├── failover
           ├── storage architecture
           └── Serverless
```

Then we will answer questions such as:

> **RDS Multi-AZ vs Read Replica — what is the actual difference?**

> **Why doesn't adding a Read Replica automatically make writes scale?**

> **When should I choose Aurora instead of normal RDS PostgreSQL?**

> **When should I use DynamoDB rather than PostgreSQL?**

> **Why should an application use ElastiCache if the database already has memory?**

> **How do RDS backups, snapshots, PITR, replication and DR actually work?**

That begins the next major AWS architecture layer: **production databases**.

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html?utm_source=chatgpt.com "Managing access to shared datasets with access points"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-access-points.html?utm_source=chatgpt.com "Creating an access point - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points-policies.html?utm_source=chatgpt.com "Configuring IAM policies for using access points"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security_iam_service-with-iam.html?utm_source=chatgpt.com "How Amazon S3 works with IAM"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points-vpc.html?utm_source=chatgpt.com "Creating access points restricted to a virtual private cloud"
[6]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_access_point?utm_source=chatgpt.com "aws_s3_access_point | Resources | hashicorp/aws | Terraform"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPoints.html?utm_source=chatgpt.com "Managing multi-Region traffic with Multi-Region Access ..."
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPointRequestRouting.html?utm_source=chatgpt.com "Multi-Region Access Point request routing"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/FailoverConfiguration.html?utm_source=chatgpt.com "Amazon S3 Multi-Region Access Points routing states"
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPointPermissions.html?utm_source=chatgpt.com "Permissions - Amazon Simple Storage Service"
[11]: https://registry.terraform.io/providers/hashicorp/awS/latest/docs/resources/s3control_multi_region_access_point?utm_source=chatgpt.com "aws_s3control_multi_region_acc..."
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants.html?utm_source=chatgpt.com "Managing access with S3 Access Grants"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-get-started.html?utm_source=chatgpt.com "Getting started with S3 Access Grants"
[14]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-location-register.html?utm_source=chatgpt.com "Register a location - Amazon Simple Storage Service"
[15]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-directory-ids.html?utm_source=chatgpt.com "S3 Access Grants and corporate directory identities"
[16]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-instance-create.html?utm_source=chatgpt.com "Create an S3 Access Grants instance - AWS Documentation"
[17]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/batch-ops.html?utm_source=chatgpt.com "Performing object operations in bulk with Batch Operations"
[18]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/batch-ops-create-job.html?utm_source=chatgpt.com "Creating an S3 Batch Operations job - AWS Documentation"
[19]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/batch-ops-copy-object.html?utm_source=chatgpt.com "Copy objects - Amazon Simple Storage Service"
[20]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/batch-ops-legal-hold.html?utm_source=chatgpt.com "S3 Object Lock legal hold - Amazon Simple Storage Service"
[21]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-inventory.html?utm_source=chatgpt.com "Cataloging and analyzing your data with S3 Inventory"
[22]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage_lens.html?utm_source=chatgpt.com "Monitoring your storage activity and usage with Amazon S3 ..."
[23]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/directory-bucket-high-performance.html?utm_source=chatgpt.com "High performance workloads"
[24]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-express-optimizing-performance-design-patterns.html?utm_source=chatgpt.com "Best practices to optimize S3 Express One Zone performance"
[25]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-express-Endpoints.html?utm_source=chatgpt.com "S3 Express One Zone Availability Zones and Regions"
[26]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-express-differences.html?utm_source=chatgpt.com "Differences for directory buckets"
[27]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-express-authenticating-authorizing.html?utm_source=chatgpt.com "Authenticating and authorizing requests"
[28]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/directory-buckets-overview.html?utm_source=chatgpt.com "Working with directory buckets"
[29]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_directory_bucket?utm_source=chatgpt.com "aws_s3_directory_bucket | Resources | hashicorp/aws"
[30]: https://docs.aws.amazon.com/lake-formation/latest/dg/what-is-lake-formation.html?utm_source=chatgpt.com "What is AWS Lake Formation? - AWS Lake Formation"
[31]: https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-aws-service-specific-topics.html?utm_source=chatgpt.com "CloudTrail supported services and integrations"
[32]: https://docs.aws.amazon.com/macie/latest/user/what-is-macie.html?utm_source=chatgpt.com "What is Amazon Macie? - Amazon Macie"
[33]: https://docs.aws.amazon.com/macie/latest/user/discovery-asdd.html?utm_source=chatgpt.com "Performing automated sensitive data discovery"
[34]: https://docs.aws.amazon.com/macie/latest/user/findings-types.html?utm_source=chatgpt.com "Types of Macie findings"
[35]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-cloudtrail-logging-for-s3.html?utm_source=chatgpt.com "Enabling CloudTrail event logging for S3 buckets and objects"
[36]: https://docs.aws.amazon.com/athena/latest/ug/cloudtrail-logs.html?utm_source=chatgpt.com "Query AWS CloudTrail logs - Amazon Athena"
[37]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-grants-cross-accounts.html?utm_source=chatgpt.com "S3 Access Grants cross-account access - AWS Documentation"
[38]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html?utm_source=chatgpt.com "Blocking public access to your Amazon S3 storage"
[39]: https://docs.aws.amazon.com/macie/latest/user/data-classification.html?utm_source=chatgpt.com "Discovering sensitive data with Macie"
