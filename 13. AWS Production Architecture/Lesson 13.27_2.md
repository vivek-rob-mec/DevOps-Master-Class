# AWS Masterclass — Lesson 27 Part 2

# Amazon S3 Security in Depth — IAM, Bucket Policies, BPA, ACLs, KMS & 403 Troubleshooting

This is one of the most important AWS security lessons because an S3 request is rarely decided by just one policy.

The production mental model is:

```text
Application / User
        │
        ▼
Who is the caller?
        │
        ▼
IAM Identity Policy
        │
        ▼
Permissions Boundary?
        │
        ▼
SCP / RCP?
        │
        ▼
Bucket Policy
        │
        ▼
S3 Block Public Access
        │
        ▼
Object Ownership / ACLs
        │
        ▼
VPC Endpoint Policy
        │
        ▼
SSE-KMS?
        │
        ▼
KMS Key Policy + IAM
        │
        ▼
ALLOW
or
403 AccessDenied
```

AWS authorization follows a fundamental rule:

> **An applicable explicit `Deny` wins over an `Allow`.**

IAM also considers controls such as permissions boundaries and AWS Organizations policies where applicable. ([AWS Documentation][1])

---

# 1. First Question During Any S3 403

Never begin with:

```text
"Maybe the bucket is private."
```

Begin with:

```text
WHO AM I?
```

Run:

```bash
aws sts get-caller-identity
```

Example:

```json
{
  "UserId": "AROAXXXXXXXXX:my-session",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/AppRole/my-session"
}
```

This tells you the actual AWS principal making the request. AWS explicitly recommends identifying the requester first when troubleshooting S3 `403 AccessDenied`. ([AWS Documentation][2])

### Never forget

```text
Before debugging permission:

WHO
is trying to do
WHAT
to WHICH RESOURCE?
```

Those three questions solve a huge percentage of IAM problems.

---

# 2. The IAM Request Triangle

Every authorization problem has three major pieces:

```text
PRINCIPAL
   │
   │ wants
   ▼
ACTION
   │
   │ on
   ▼
RESOURCE
```

Example:

```text
Principal:
arn:aws:iam::123456789012:role/TodoAppRole

Action:
s3:GetObject

Resource:
arn:aws:s3:::prod-app-assets/images/logo.png
```

Your policy must correctly describe all three.

---

# 3. S3 Has Bucket Actions and Object Actions

This is one of the biggest S3 IAM traps.

These are **bucket-level** operations:

```text
s3:ListBucket
s3:GetBucketLocation
s3:GetBucketPolicy
```

They operate on:

```text
arn:aws:s3:::my-bucket
```

Object operations such as:

```text
s3:GetObject
s3:PutObject
s3:DeleteObject
```

operate on:

```text
arn:aws:s3:::my-bucket/*
```

AWS explicitly distinguishes bucket-resource ARNs from object-resource ARNs. ([AWS Documentation][3])

---

# 4. The Most Common ARN Mistake

Suppose you write:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-prod-bucket"
}
```

Looks reasonable.

But it's wrong.

Why?

Because:

```text
arn:aws:s3:::my-prod-bucket
```

means:

```text
THE BUCKET
```

whereas:

```text
arn:aws:s3:::my-prod-bucket/*
```

means:

```text
OBJECTS INSIDE THE BUCKET
```

For object operations, AWS requires the object ARN form, including the slash after the bucket name. ([AWS Documentation][3])

### Memorize

```text
BUCKET:

arn:aws:s3:::my-bucket


OBJECTS:

arn:aws:s3:::my-bucket/*
```

---

# 5. `ListBucket` Has the Opposite Trap

This is wrong:

```json
{
  "Effect": "Allow",
  "Action": "s3:ListBucket",
  "Resource": "arn:aws:s3:::my-prod-bucket/*"
}
```

`ListBucket` needs:

```text
arn:aws:s3:::my-prod-bucket
```

because listing operates on the bucket resource. AWS maps `ListObjectsV2` authorization to the `s3:ListBucket` permission on the bucket ARN. ([AWS Documentation][3])

---

# 6. Production Read Policy

If an application should:

```text
list bucket
+
download objects
```

you often need two statements:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowBucketListing",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::prod-app-assets"
    },
    {
      "Sid": "AllowObjectReads",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::prod-app-assets/*"
    }
  ]
}
```

This separation is not just style; bucket and object operations use different S3 resource types. ([AWS Documentation][3])

---

# 7. Very Interesting Troubleshooting Scenario

Suppose this works:

```bash
aws s3 cp \
  s3://prod-app-assets/private/report.pdf \
  .
```

but:

```bash
aws s3 ls s3://prod-app-assets/
```

fails with:

```text
AccessDenied
```

Why?

Possible:

```text
s3:GetObject
=
ALLOWED

but

s3:ListBucket
=
NOT ALLOWED
```

So the user can retrieve an object whose exact key they know but can't enumerate the bucket.

That's a perfectly valid least-privilege architecture.

---

# 8. Prefix-Level Permissions

Suppose we have:

```text
prod-company-data
│
├── finance/
├── hr/
└── engineering/
```

Engineering should read only:

```text
engineering/*
```

Object permission:

```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::prod-company-data/engineering/*"
}
```

And controlled listing can use an S3 prefix condition:

```json
{
  "Effect": "Allow",
  "Action": "s3:ListBucket",
  "Resource": "arn:aws:s3:::prod-company-data",
  "Condition": {
    "StringLike": {
      "s3:prefix": [
        "engineering/*"
      ]
    }
  }
}
```

AWS supports restricting bucket listing according to requested key prefixes. ([AWS Documentation][4])

---

# 9. IAM Policy vs Bucket Policy

Now the big distinction.

## IAM identity policy

Attached to:

```text
User
Group
Role
```

It answers:

> **What may this principal do?**

Example:

```text
EC2 Role
   │
   ▼
IAM Policy
   │
   └── GetObject from bucket X
```

## S3 bucket policy

Attached to:

```text
S3 Bucket
```

It answers:

> **Who may access this bucket, under what conditions?**

Example:

```text
Bucket
  │
  ▼
Bucket Policy
  │
  └── Allow role X to GetObject
```

S3 supports both identity-based and resource-based policies. ([AWS Documentation][5])

---

# 10. Same-Account Mental Model

For a straightforward same-account request, identity-based and resource-based permissions are considered together, subject to other controls such as permissions boundaries, session policies, SCPs/RCPs, and explicit denies. An applicable explicit `Deny` always wins. ([AWS Documentation][1])

A simplified learning model is:

```text
IAM Allow
        \
         \
          AUTHORIZATION
         /
Bucket Policy Allow
```

But always remember:

```text
Explicit DENY
=
STOP
```

---

# 11. Explicit Deny Example

IAM role:

```text
Allow:
s3:GetObject
```

Bucket policy:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::prod-secrets/*"
}
```

Final result:

```text
DENY
```

Not:

```text
Allow + Deny
=
some compromise
```

It is simply:

```text
DENY WINS
```

AWS's IAM evaluation logic explicitly prioritizes applicable explicit denies. ([AWS Documentation][6])

---

# 12. This Is Why Admin Access Can Still Fail

Imagine your role has:

```text
AdministratorAccess
```

and you think:

> I am admin; therefore S3 must let me in.

But bucket policy says:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::high-security-data",
    "arn:aws:s3:::high-security-data/*"
  ],
  "Condition": {
    ...
  }
}
```

If your request satisfies that `Deny`, broad identity permissions don't magically override it.

This is why:

```text
AdministratorAccess
≠
ignore AWS authorization controls
```

---

# 13. Cross-Account Is Stricter

Suppose:

```text
Account A
123456789012

owns S3 bucket
```

and:

```text
Account B
999999999999

has AppRole
```

For the normal cross-account IAM + bucket-policy model, Account A must trust Account B's principal through a resource-based policy, and Account B's principal must also be allowed to make the S3 request. AWS describes this as requiring explicit allowance on both sides for cross-account access. ([AWS Documentation][7])

Mental model:

```text
ACCOUNT B

AppRole
  │
  │ Identity Policy
  │ ALLOW
  ▼

        CROSS ACCOUNT

  ▲
  │ Bucket Policy
  │ ALLOW AppRole
  │
ACCOUNT A
S3 Bucket
```

### Never forget

```text
Cross-account

REQUESTER says:
"I am allowed to go."

RESOURCE OWNER says:
"I allow you in."
```

---

# 14. Example Cross-Account Bucket Policy

Account A bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPartnerRead",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::999999999999:role/PartnerReadRole"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::company-shared-data/partner/*"
    }
  ]
}
```

Account B role also needs appropriate S3 permission under the normal cross-account authorization model. ([AWS Documentation][7])

---

# 15. S3 Block Public Access

Now we reach an extremely important guardrail:

# Block Public Access — BPA

This is not another normal `Allow` policy.

Think of it as a **safety barrier against public exposure**.

```text
Bucket Policy / ACL
        │
        │ accidentally says PUBLIC
        ▼
Block Public Access
        │
        X
     BLOCKED
```

S3 Block Public Access can be applied at organization, account, bucket, and access-point levels, and S3 applies the most restrictive applicable combination. AWS recommends enabling all four settings unless public access is specifically required. ([AWS Documentation][8])

---

# 16. Four BPA Settings

You need to know what these actually mean.

| Setting                 | Mental model                                                |
| ----------------------- | ----------------------------------------------------------- |
| `BlockPublicAcls`       | Reject new public ACLs                                      |
| `IgnorePublicAcls`      | Ignore public access granted by ACLs                        |
| `BlockPublicPolicy`     | Reject new public bucket/access-point policies              |
| `RestrictPublicBuckets` | Restrict access when a bucket/access-point policy is public |

AWS defines these four controls independently. ([AWS Documentation][8])

Let's understand the subtle differences.

---

# 17. `BlockPublicAcls`

Suppose someone executes an operation containing a public ACL.

With:

```text
BlockPublicAcls = true
```

S3 rejects operations that attempt to create a public bucket/object ACL. Existing ACLs aren't removed simply by turning the setting on. ([AWS Documentation][8])

Mental model:

```text
"Do not let me CREATE
new public ACL exposure."
```

---

# 18. `IgnorePublicAcls`

Different idea.

```text
IgnorePublicAcls = true
```

means:

```text
Public ACL may exist
        │
        ▼
S3 ignores its
public permission effect
```

AWS states that this does not delete the ACL; it ignores public permissions granted through those ACLs. ([AWS Documentation][8])

Think:

```text
BlockPublicAcls
=
don't let public ACLs be created


IgnorePublicAcls
=
don't trust public ACL permissions
```

---

# 19. `BlockPublicPolicy`

Suppose someone tries to set:

```json
{
  "Effect": "Allow",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

With:

```text
BlockPublicPolicy = true
```

S3 rejects attempts to install a bucket policy that S3 evaluates as public. ([AWS Documentation][8])

Mental model:

```text
"Do not let anyone
turn this bucket public
through its policy."
```

---

# 20. `RestrictPublicBuckets`

This one often confuses engineers.

If S3 detects a bucket policy as public and:

```text
RestrictPublicBuckets = true
```

access derived from that public policy is restricted; AWS also documents effects on cross-account access when a public policy exists. ([AWS Documentation][8])

You don't need to memorize every internal edge case today.

Remember:

```text
BlockPublicPolicy
=
prevent public policy creation


RestrictPublicBuckets
=
restrict access when public policy exists
```

---

# 21. Most Restrictive Wins

Suppose:

```text
Bucket BPA:
OFF
```

but:

```text
Account BPA:
ON
```

You might think:

```text
Bucket setting says public is okay.
```

No.

S3 applies the **more restrictive applicable settings**. Organization/account controls can therefore continue blocking public access even if the bucket-level controls are loosened. ([AWS Documentation][8])

This causes a classic troubleshooting case:

```text
"I disabled Block Public Access
on the bucket...

WHY STILL 403?"
```

Check:

```text
Organization
Account
Bucket
Access Point
```

not only the bucket screen.

---

# 22. New Buckets Are Secure by Default

Current S3 defaults for new general-purpose buckets include Block Public Access protection and `Bucket owner enforced` Object Ownership, which disables ACLs. AWS recommends retaining these settings for most modern workloads. ([AWS Documentation][9])

So modern S3 should usually begin as:

```text
PRIVATE
+
ACLs disabled
+
policy-based authorization
```

not:

```text
public bucket
+
ACL chaos
```

---

# 23. Object Ownership

Historically S3 had a tricky problem:

```text
Account A owns bucket.

Account B uploads object.

Who owns object?
```

Modern S3 solves this for most use cases through:

```text
Object Ownership:
Bucket owner enforced
```

With that default setting:

```text
ACLs = disabled

Bucket owner
=
owns all objects

Permissions
=
policies
```

AWS recommends `Bucket owner enforced` for most use cases, and it is the default for new buckets. ([AWS Documentation][10])

---

# 24. Why Disabling ACLs Is So Helpful

Old world:

```text
Can access come from:

IAM?
Bucket Policy?
Bucket ACL?
Object ACL?
Object owned by someone else?
```

Modern recommended world:

```text
IAM
+
Bucket Policy
+
other policy controls
```

Simpler authorization means fewer mysterious incidents.

AWS explicitly recommends keeping ACLs disabled for the majority of modern S3 workloads. ([AWS Documentation][10])

---

# 25. Interesting ACL Error

Suppose Object Ownership is:

```text
Bucket owner enforced
```

and an old application uploads using:

```text
ACL = public-read
```

The request can fail with:

```text
AccessControlListNotSupported
```

because ACLs are disabled. AWS documents that with Bucket owner enforced, uploads that specify unsupported ACLs fail; requests without an ACL, or with the bucket-owner-full-control compatibility ACL, are accepted. ([AWS Documentation][10])

This is important when migrating old applications.

---

# 26. Modern Rule for ACLs

For our course, use this rule:

```text
NEW APPLICATION
      │
      ▼
Bucket owner enforced
      │
      ▼
ACLs disabled
      │
      ▼
IAM + Bucket Policies
```

Only turn ACLs back on when a genuine requirement specifically demands them.

---

# 27. S3 Encryption — Current Reality

Another old-study-material trap:

> “You should enable encryption on S3 buckets.”

Current S3 already applies server-side encryption to all new uploaded objects by default.

The base default is:

```text
SSE-S3
```

using Amazon S3 managed keys. This has been automatic for new S3 object uploads since January 5, 2023. ([AWS Documentation][11])

So now the design question isn't merely:

```text
Encrypted or not?
```

It's more often:

```text
WHICH encryption/control model?
```

---

# 28. S3 Server-Side Encryption Options

For normal general-purpose S3, important server-side models include:

```text
SSE-S3

SSE-KMS

DSSE-KMS

SSE-C
```

SSE-S3 is the default baseline. SSE-KMS adds AWS KMS key controls and auditing; DSSE-KMS applies two server-side encryption layers for requirements that need multilayer encryption. ([AWS Documentation][12])

---

# 29. SSE-S3 Mental Model

```text
Object
  │
  ▼
S3 managed encryption
  │
  ▼
Encrypted at rest
```

You don't manage the encryption key policy yourself.

S3 manages the keys.

For many workloads:

```text
SSE-S3
```

may be completely appropriate.

---

# 30. SSE-KMS Mental Model

Now:

```text
Object
  │
  ▼
S3
  │
  ▼
AWS KMS
  │
  ▼
KMS Key
```

This gives capabilities such as customer-managed key policies, key disabling, rotation controls, and more detailed KMS audit visibility. ([AWS Documentation][13])

But it introduces another authorization system.

That's where many:

```text
403 AccessDenied
```

errors come from.

---

# 31. The Two Locks Problem

Suppose:

```text
IAM:
s3:GetObject = Allow
```

and:

```text
Bucket policy:
Allow
```

Yet:

```bash
aws s3 cp s3://secure-bucket/report.pdf .
```

returns:

```text
AccessDenied
```

Object encryption:

```text
SSE-KMS
```

Now there are two locks:

```text
LOCK 1:
S3 authorization


LOCK 2:
KMS authorization
```

Both must allow the operation.

---

# 32. KMS Permissions for S3

For SSE-KMS objects, AWS documents:

```text
PUT object
→ kms:GenerateDataKey
```

```text
GET object
→ kms:Decrypt
```

For an SSE-KMS multipart upload, both `kms:GenerateDataKey` and `kms:Decrypt` are required. The KMS key must also be in the same Region as the S3 bucket. ([AWS Documentation][13])

### Memorize

```text
WRITE encrypted object
=
S3 PutObject
+
KMS GenerateDataKey


READ encrypted object
=
S3 GetObject
+
KMS Decrypt
```

---

# 33. Example S3 + KMS Role Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::secure-prod-data/*"
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:ap-south-1:123456789012:key/abcd-..."
    }
  ]
}
```

But with a customer-managed KMS key, its **KMS key policy must also be configured so the required principals can use the key**; an IAM allow alone does not automatically make a restrictive key policy irrelevant. ([AWS Documentation][14])

---

# 34. S3 KMS Troubleshooting Chain

When normal S3 permissions appear correct:

```text
S3 GetObject allowed?
      │
      YES
      ▼
Object SSE-KMS?
      │
      YES
      ▼
Which KMS key?
      │
      ▼
Key enabled?
      │
      ▼
Same Region?
      │
      ▼
IAM kms:Decrypt?
      │
      ▼
KMS key policy?
      │
      ▼
Explicit Deny?
```

Don't keep changing the bucket policy if KMS is actually denying the decrypt.

---

# 35. Cross-Account SSE-KMS

Cross-account encrypted object access is another layer deeper.

AWS states that if you want normal cross-account sharing of SSE-KMS data, use a **customer-managed KMS key** whose policy can grant the other account access; objects encrypted with the AWS managed S3 KMS key are not suitable for this standard cross-account sharing model. ([AWS Documentation][13])

Architecture:

```text
Account A

S3 Object
   │
SSE-KMS
   │
Customer-managed KMS key
   │
   ├──── allow Account B role
   │
   ▼

Account B
AppRole
```

Now both:

```text
S3 authorization
AND
KMS authorization
```

must succeed.

---

# 36. S3 Bucket Keys

For very high-request SSE-KMS workloads, individual KMS interactions can add significant KMS request volume and cost.

S3 Bucket Keys can reduce AWS KMS request traffic and AWS says they can reduce related KMS request costs by up to 99% for supported SSE-KMS workloads. ([AWS Documentation][13])

Mental model:

```text
Without Bucket Key

Object
  ↓
many KMS interactions


With Bucket Key

Bucket-level key mechanism
  ↓
fewer KMS requests
```

This is an important FinOps/security optimization we'll revisit.

---

# 37. DSSE-KMS

For workloads with explicit multilayer encryption requirements, S3 supports:

```text
DSSE-KMS
```

which applies two independent server-side encryption layers. AWS positions this for compliance requirements that need multiple encryption layers. ([AWS Documentation][15])

For normal applications:

```text
SSE-S3
or
SSE-KMS
```

remain far more common starting points.

Don't choose DSSE-KMS just because:

```text
two layers sounds cooler.
```

Use it when the requirement warrants the complexity and cost.

---

# 38. Current 2026 SSE-C Note

This is particularly current.

SSE-C means:

```text
Server-Side Encryption
with Customer-Provided Keys
```

The caller provides the encryption key material with relevant requests.

Starting in **April 2026**, AWS disabled SSE-C write usage by default for all new general-purpose buckets, and also for certain existing buckets/accounts with no SSE-C encrypted objects. AWS recommends keeping SSE-C disabled unless a workload has a specific requirement for it. ([AWS Documentation][16])

This is another example where older AWS material can be outdated.

---

# 39. VPC Endpoint Security

Now connect S3 with our VPC lessons.

Normally a private EC2 instance might reach S3 through:

```text
Private EC2
   │
   ▼
NAT Gateway
   │
   ▼
S3
```

But S3 supports VPC endpoints.

For general S3 access, AWS supports both **gateway endpoints** and **interface endpoints**; gateway endpoints integrate with VPC route tables, while interface endpoints use private IPs through AWS PrivateLink and support additional connectivity patterns. ([AWS Documentation][17])

A classic private architecture:

```text
Private EC2
    │
    ▼
Route Table
    │
    ▼
S3 Gateway Endpoint
    │
    ▼
Amazon S3
```

No NAT Gateway is required for that S3 path.

---

# 40. Endpoint Policy Is Another Authorization Layer

A VPC endpoint can itself have a policy.

Therefore:

```text
IAM = ALLOW

Bucket policy = ALLOW

BUT

Endpoint policy = DENY
```

can still stop a request that uses that endpoint.

S3 endpoint policies can restrict which users, actions, and S3 resources are allowed through the endpoint. ([AWS Documentation][18])

Another potential `403`.

---

# 41. Restrict Bucket to One VPC Endpoint

A bucket policy can enforce:

> Requests must come through my approved S3 VPC endpoint.

Example concept:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::prod-private-data",
    "arn:aws:s3:::prod-private-data/*"
  ],
  "Condition": {
    "StringNotEquals": {
      "aws:SourceVpce": "vpce-0123456789abcdef0"
    }
  }
}
```

AWS documents the `aws:SourceVpce` condition for restricting S3 bucket access to a particular VPC endpoint. ([AWS Documentation][18])

---

# 42. Huge Warning About `aws:SourceVpce`

If you add:

```text
DENY requests
not coming through endpoint X
```

then your normal S3 console access may also stop working because console requests do not originate through that VPC endpoint. AWS explicitly warns about this behavior. ([AWS Documentation][18])

This is a classic production incident:

```text
Engineer adds strong bucket policy.

Seconds later:

"I can't access the bucket
from the console anymore!"
```

The policy may be doing exactly what you asked.

---

# 43. Enforcing HTTPS

Another very useful bucket-policy control:

```text
DENY
if transport isn't secure
```

Conceptually:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": [
    "arn:aws:s3:::prod-secure-data",
    "arn:aws:s3:::prod-secure-data/*"
  ],
  "Condition": {
    "Bool": {
      "aws:SecureTransport": "false"
    }
  }
}
```

S3 bucket policies also support transport-related conditions such as minimum TLS versions. ([AWS Documentation][19])

Think:

```text
Encryption at rest
=
SSE


Encryption in transit
=
TLS / HTTPS
```

Don't confuse them.

---

# 44. S3 Security Layers Together

A strong private application architecture could be:

```text
EC2 App Role
      │
      ▼
IAM least privilege
      │
      ▼
Private subnet
      │
      ▼
S3 VPC Endpoint
      │
      ▼
Endpoint Policy
      │
      ▼
S3 Bucket
      │
      ├── Block Public Access
      ├── Bucket owner enforced
      ├── Bucket Policy
      │      ├── require approved role
      │      ├── require HTTPS
      │      └── require VPCE
      │
      ▼
SSE-KMS
      │
      ▼
KMS Key Policy
```

That's **defense in depth**.

Not:

```text
"Bucket is private, done."
```

---

# 45. Terraform Security Baseline

A production-oriented bucket might begin like this:

```hcl
resource "aws_s3_bucket" "app" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = "production"
  }
}
```

Public access guardrails:

```hcl
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
```

Object Ownership:

```hcl
resource "aws_s3_bucket_ownership_controls" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
```

AWS recommends keeping ACLs disabled with Bucket owner enforced and using policy-based access for most modern workloads. ([AWS Documentation][10])

---

# 46. Explicit SSE-KMS Configuration

```hcl
resource "aws_kms_key" "s3" {
  description         = "Production S3 encryption key"
  enable_key_rotation = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}
```

Remember that even without this resource S3 applies baseline SSE-S3 encryption to new uploads; explicit SSE-KMS is about choosing the KMS control model rather than making an otherwise-unencrypted S3 bucket encrypted. ([AWS Documentation][11])

---

# 47. Hands-On 403 Lab

Let's deliberately build a permissions test.

```bash
export AWS_REGION="ap-south-1"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)

BUCKET="lesson27-security-${ACCOUNT_ID}-$(date +%s)"
```

Create:

```bash
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration \
    LocationConstraint="$AWS_REGION"
```

Create object:

```bash
echo "Highly confidential lesson 27 file" > secret.txt

aws s3 cp \
  secret.txt \
  "s3://$BUCKET/private/secret.txt"
```

---

# 48. Inspect the Security Defaults

Check Block Public Access:

```bash
aws s3api get-public-access-block \
  --bucket "$BUCKET"
```

Check Object Ownership:

```bash
aws s3api get-bucket-ownership-controls \
  --bucket "$BUCKET"
```

Check encryption:

```bash
aws s3api get-bucket-encryption \
  --bucket "$BUCKET"
```

For a normal new bucket today, you should see secure defaults consistent with S3's current baseline: public access protection, Bucket owner enforced ownership controls, and server-side encryption. ([AWS Documentation][10])

---

# 49. Test Anonymous Access

Try:

```bash
curl -I \
  "https://${BUCKET}.s3.${AWS_REGION}.amazonaws.com/private/secret.txt"
```

You should **not** expect anonymous public access simply because the HTTPS URL is known.

The normal security architecture is:

```text
Object exists
≠
Everyone can access it
```

---

# 50. Test Your Current Identity

```bash
aws s3api head-object \
  --bucket "$BUCKET" \
  --key private/secret.txt
```

If your current credentials have appropriate rights, this succeeds.

Now:

```bash
aws sts get-caller-identity
```

Again.

Build the habit:

```text
Request works/fails
     │
     ▼
Which identity made it?
```

---

# 51. Deliberate Deny Policy

For learning only, create `deny-delete.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyObjectDeletion",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*"
    }
  ]
}
```

Replace:

```text
BUCKET_NAME
```

with the actual bucket.

Apply:

```bash
aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy file://deny-delete.json
```

Now attempt:

```bash
aws s3api delete-object \
  --bucket "$BUCKET" \
  --key private/secret.txt
```

Expected:

```text
AccessDenied
```

Even if your identity otherwise has deletion permission, the explicit bucket-policy deny wins. ([AWS Documentation][6])

---

# 52. Troubleshooting 403 — The Production Flow

When you see:

```text
403 AccessDenied
```

walk this exact chain:

```text
1
WHO AM I?
     │
     ▼
aws sts get-caller-identity


2
WHAT ACTION FAILED?
     │
     ├── List?
     ├── Get?
     ├── Put?
     └── Delete?


3
WHICH RESOURCE?
     │
     ├── bucket ARN?
     └── object ARN?


4
IAM identity policy?
     │
     ▼
Allow?


5
Explicit Deny anywhere?
     │
     ├── IAM
     ├── bucket policy
     ├── SCP/RCP
     ├── permission boundary
     └── session policy


6
Block Public Access relevant?
     │


7
Object Ownership / ACL issue?
     │


8
VPC Endpoint policy?
     │


9
Bucket restricted to SourceVpc/SourceVpce?
     │


10
SSE-KMS?
     │
     ├── kms:Decrypt?
     ├── kms:GenerateDataKey?
     └── key policy?


11
Cross-account?
     │
     ▼
Both sides allow?


12
Retest exact API call
```

AWS's own S3 403 troubleshooting guidance emphasizes identifying the caller, checking explicit denies, reviewing applicable IAM/resource policies, and considering controls such as Block Public Access. ([AWS Documentation][2])

---

# 53. Decode the Error by Operation

If this fails:

```bash
aws s3 ls s3://bucket
```

think:

```text
s3:ListBucket
```

If this fails:

```bash
aws s3 cp s3://bucket/file.txt .
```

think:

```text
s3:GetObject

possibly
kms:Decrypt
```

If upload fails:

```bash
aws s3 cp file.txt s3://bucket/
```

think:

```text
s3:PutObject

possibly
kms:GenerateDataKey
```

If delete fails:

```bash
aws s3 rm s3://bucket/file.txt
```

think:

```text
s3:DeleteObject
```

This action-first thinking is far faster than randomly adding:

```text
s3:*
```

to policies.

---

# 54. Why `s3:*` Is a Bad Troubleshooting Habit

Engineer:

> It gives AccessDenied, so I'll add `s3:*`.

That may:

```text
mask the real problem
+
grant unnecessary permissions
+
still fail if KMS/endpoint/explicit deny is the issue
```

Instead:

```text
Identify API operation
       ↓
identify required action
       ↓
identify correct ARN type
       ↓
grant minimum permission
```

AWS's S3 documentation publishes permission requirements for S3 API operations specifically for this purpose. ([AWS Documentation][20])

---

# 55. Example: EC2 App Needs Upload Only

Application should upload:

```text
s3://prod-user-uploads/users/*
```

but should not:

```text
list whole bucket
delete objects
read other data
edit bucket settings
```

Role policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::prod-user-uploads/users/*"
    }
  ]
}
```

That's far better than:

```json
{
  "Action": "s3:*",
  "Resource": "*"
}
```

This is the principle of least privilege.

---

# 56. Our Todo App Production Architecture

Instead of putting uploads on EC2:

```text
Internet
   │
   ▼
CloudFront
   │
   ▼
ALB
   │
   ▼
Auto Scaling
EC2 App Role
   │
   │ s3:PutObject
   │ s3:GetObject if required
   ▼
Private S3 Bucket
   │
   ├── Block Public Access
   ├── Bucket owner enforced
   ├── SSE-KMS
   ├── lifecycle
   └── versioning later
```

No static AWS access keys need to be hardcoded into EC2.

The application can use its EC2 IAM role.

That's production AWS identity design.

---

# 57. CloudFront 403 Preview

Later we'll build:

```text
User
  │
  ▼
CloudFront
  │
  ▼
Private S3
```

with:

```text
Origin Access Control — OAC
```

rather than simply making the S3 bucket public.

So when you see:

```text
CloudFront
403
```

possible causes eventually include:

```text
OAC/bucket policy
wrong origin
wrong object key
KMS permissions
```

We'll troubleshoot those systematically in the CloudFront-S3 integration section.

---

# 58. SAA-C03 Scenarios

### Scenario A

An EC2 application can download an exact S3 object but cannot list the bucket.

Think:

```text
GetObject = allowed

ListBucket = missing
```

Bucket listing requires `s3:ListBucket` on the bucket resource. ([AWS Documentation][3])

---

### Scenario B

Policy grants:

```text
s3:GetObject
```

on:

```text
arn:aws:s3:::bucket
```

but access fails.

Think:

```text
wrong ARN

should be:

arn:aws:s3:::bucket/*
```

for object operations. ([AWS Documentation][3])

---

### Scenario C

IAM role has `s3:GetObject`, but SSE-KMS object download fails.

Think:

```text
kms:Decrypt
+
KMS key policy
```

([AWS Documentation][13])

---

### Scenario D

Developer disabled Block Public Access on one bucket, but public access still doesn't work.

Think:

```text
account/org-level BPA
```

because S3 applies the most restrictive applicable BPA configuration. ([AWS Documentation][8])

---

### Scenario E

Cross-account role should read SSE-KMS data.

Think:

```text
requester identity permission
+
bucket policy
+
customer-managed KMS key
+
KMS authorization
```

([AWS Documentation][2])

---

### Scenario F

New application sends:

```text
x-amz-acl: public-read
```

to a modern Bucket owner enforced bucket.

Think:

```text
ACLs disabled
```

and expect an ACL-related request failure rather than making ACLs part of the new design. ([AWS Documentation][10])

---

### Scenario G

Private EC2 should access S3 without NAT.

Think:

```text
S3 VPC endpoint
```

A gateway endpoint is a common architecture for private VPC-to-S3 routing. ([AWS Documentation][17])

---

# 59. DOP-C02 Incident

Production says:

> The application suddenly cannot download objects after we changed the bucket to SSE-KMS.

Your diagnosis:

```text
Before:

App Role
  │
s3:GetObject
  │
  ▼
S3


After SSE-KMS:

App Role
  │
  ├── s3:GetObject
  │
  └── kms:Decrypt  ← NEW REQUIREMENT
          │
          ▼
       KMS Key
```

So the S3 permission itself may still be perfect.

The newly introduced dependency is:

```text
KMS authorization
```

This is exactly the type of layered troubleshooting expected in production DevOps work. ([AWS Documentation][13])

---

# 60. Never-Forget S3 Security Map

```text
                         S3 REQUEST
                              │
                              ▼
                          PRINCIPAL
                              │
                              ▼
                       Identity Policy
                              │
                              ▼
                    Boundary / SCP / RCP
                              │
                              ▼
                       Bucket Policy
                              │
                              ▼
                   Explicit Deny present?
                              │
                     YES ─────┴─────▶ DENY
                              │
                              NO
                              ▼
                    Block Public Access
                              │
                              ▼
                     Object Ownership
                              │
                       ACLs usually OFF
                              │
                              ▼
                     VPC Endpoint Policy
                              │
                              ▼
                        Object SSE-KMS?
                              │
                              ▼
                      KMS Authorization
                              │
                              ▼
                         ALLOW / DENY
```

---

# 61. Ten S3 Security Rules I Want Burned Into Memory

| Rule                                          | Never-forget meaning                  |
| --------------------------------------------- | ------------------------------------- |
| **1. Identify the caller first**              | `aws sts get-caller-identity`         |
| **2. Explicit Deny wins**                     | An Allow does not override it         |
| **3. `ListBucket` uses bucket ARN**           | `arn:aws:s3:::bucket`                 |
| **4. Object actions use object ARN**          | `arn:aws:s3:::bucket/*`               |
| **5. BPA is a public-access guardrail**       | Check org/account/bucket/access point |
| **6. ACLs are disabled by default**           | Use Bucket owner enforced             |
| **7. All new S3 objects are encrypted**       | SSE-S3 is baseline                    |
| **8. SSE-KMS adds KMS authorization**         | S3 Allow alone may not be enough      |
| **9. VPC endpoint policy can deny access**    | Networking path also has policy       |
| **10. Cross-account means both sides matter** | Requester + resource owner            |

These behaviors reflect the current S3/IAM security model. ([AWS Documentation][8])

---

# 62. The Most Important 403 Formula

When you see:

```text
403 AccessDenied
```

don't think:

```text
S3 is broken.
```

Think:

```text
WHO?
 │
 ▼
WHAT ACTION?
 │
 ▼
WHICH ARN?
 │
 ▼
Identity Allow?
 │
 ▼
Resource Allow?
 │
 ▼
Any explicit Deny?
 │
 ▼
BPA?
 │
 ▼
ACL/Object Ownership?
 │
 ▼
VPC endpoint?
 │
 ▼
KMS?
 │
 ▼
Cross-account?
```

That troubleshooting sequence will also help with:

```text
CloudFront → S3 403

EC2 → S3 403

Lambda → S3 403

ECS → S3 403

Terraform → S3 403

CI/CD → S3 403
```

---

# ✅ Lesson 27 Progress

We now understand the security foundation:

```text
✓ IAM identity policies
✓ Bucket policies
✓ Principal / Action / Resource
✓ Bucket ARN
✓ Object ARN
✓ ListBucket vs GetObject
✓ Prefix authorization
✓ Same-account authorization
✓ Cross-account authorization
✓ Explicit Deny
✓ Block Public Access
✓ all four BPA controls
✓ organization/account/bucket hierarchy
✓ Object Ownership
✓ Bucket owner enforced
✓ ACLs disabled
✓ SSE-S3
✓ SSE-KMS
✓ DSSE-KMS
✓ current SSE-C behavior
✓ KMS permissions
✓ KMS key policies
✓ S3 Bucket Keys
✓ VPC endpoints
✓ endpoint policies
✓ SourceVpce restrictions
✓ TLS policy controls
✓ 403 troubleshooting
✓ Terraform security baseline
```

# Next — Lesson 27 Part 3: S3 Versioning, Object Lock & Data Protection

Next we move from:

```text
"WHO CAN ACCESS MY OBJECT?"
```

to:

```text
"WHAT HAPPENS IF SOMEBODY
OVERWRITES OR DELETES MY OBJECT?"
```

We will cover:

```text
S3 DATA PROTECTION
        │
        ├── Versioning
        ├── Version IDs
        ├── delete markers
        ├── overwrite recovery
        ├── accidental-delete recovery
        ├── versioned-bucket cleanup
        ├── MFA Delete
        ├── Object Lock
        ├── retention modes
        │     ├── Governance
        │     └── Compliance
        ├── Legal Holds
        ├── WORM
        ├── ransomware protection
        ├── replication prerequisites
        ├── CRR
        ├── SRR
        ├── Replication Time Control
        ├── encrypted-object replication
        ├── replication IAM roles
        ├── cross-account DR
        ├── lifecycle with versions
        ├── noncurrent versions
        ├── delete-marker behavior
        ├── Terraform
        └── hands-on recovery lab
```

That section will answer one of the most important S3 questions:

> **“If someone runs `aws s3 rm` against production, is my data actually gone?”**

The answer depends heavily on **Versioning, delete markers, lifecycle, Object Lock, and backup/replication architecture**.

[1]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html?utm_source=chatgpt.com "Policy evaluation logic - AWS Identity and Access ..."
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/troubleshoot-403-errors.html "Troubleshoot access denied (403 Forbidden) errors in Amazon S3 - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/security_iam_service-with-iam.html "How Amazon S3 works with IAM - Amazon Simple Storage Service"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/walkthrough1.html?utm_source=chatgpt.com "Controlling access to a bucket with user policies"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-policy-language-overview.html?utm_source=chatgpt.com "Policies and permissions in Amazon S3"
[6]: https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic_policy-eval-denyallow.html?utm_source=chatgpt.com "How AWS enforcement code logic evaluates requests to ..."
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html?utm_source=chatgpt.com "Examples of Amazon S3 bucket policies"
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html "Blocking public access to your Amazon S3 storage - Amazon Simple Storage Service"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/troubleshoot-403-errors.html?utm_source=chatgpt.com "Troubleshoot access denied (403 Forbidden) errors in ..."
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html "Controlling ownership of objects and disabling ACLs for your bucket - Amazon Simple Storage Service"
[11]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingServerSideEncryption.html?utm_source=chatgpt.com "Using server-side encryption with Amazon S3 managed ..."
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html?utm_source=chatgpt.com "Protecting data with server-side encryption"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html "Using server-side encryption with AWS KMS keys (SSE-KMS) - Amazon Simple Storage Service"
[14]: https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html?utm_source=chatgpt.com "Key policies in AWS KMS - AWS Key Management Service"
[15]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingDSSEncryption.html?utm_source=chatgpt.com "Using dual-layer server-side encryption with AWS KMS ..."
[16]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-s3-c-encryption-setting-faq.html?utm_source=chatgpt.com "Default SSE-C setting for new buckets FAQ"
[17]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/privatelink-interface-endpoints.html?utm_source=chatgpt.com "AWS PrivateLink for Amazon S3"
[18]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies-vpc-endpoint.html "Controlling access from VPC endpoints with bucket policies - Amazon Simple Storage Service"
[19]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html?utm_source=chatgpt.com "Bucket policy examples using condition keys"
[20]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html?utm_source=chatgpt.com "Required permissions for Amazon S3 API operations"
