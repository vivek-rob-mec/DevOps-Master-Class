# AWS Masterclass — Lesson 27 Part 5

# S3 Performance Engineering, Presigned URLs & Event-Driven Architecture

Now we connect S3 to the application layer.

So far:

```text
Object Storage
      ↓
Security
      ↓
Versioning / Object Lock
      ↓
Lifecycle / Cost
```

Now:

```text
                    APPLICATION
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
         Upload       Download       Events
            │            │            │
            ▼            ▼            ▼
       Multipart      Range GET     S3 Event
            │            │            │
            ▼            ▼            ▼
        Parallel       Parallel    Lambda/SQS/
        transfer       transfer    SNS/EventBridge
            │                         │
            ▼                         ▼
     Presigned URL                Processing
            │                         │
            └────────────┬────────────┘
                         ▼
                     Amazon S3
```

---

# 1. S3 Is a Distributed System — Treat It Like One

A common beginner architecture is:

```text
Application
    │
    │ one request
    ▼
   S3
```

and then:

> “Why isn't one connection giving me massive throughput?”

AWS recommends thinking of S3 as a very large distributed system. High-performance applications should use multiple concurrent requests and connections rather than relying on one serialized connection. S3 itself doesn't impose a bucket connection-count limit. ([AWS Documentation][1])

Think:

```text
BAD

Request
   ↓
wait
   ↓
Request
   ↓
wait
```

versus:

```text
BETTER

Req 1 ─────┐
Req 2 ─────┤
Req 3 ─────┼──▶ S3
Req 4 ─────┤
Req N ─────┘
```

This principle applies to:

```text
uploads
downloads
data processing
backup
analytics
media systems
```

---

# 2. Current S3 Request-Rate Baseline

For general-purpose S3, AWS currently documents at least:

```text
3,500
PUT / COPY / POST / DELETE
requests per second
per partitioned prefix
```

and:

```text
5,500
GET / HEAD
requests per second
per partitioned prefix
```

with no fixed limit on how many prefixes a bucket can have. ([AWS Documentation][2])

For example:

```text
10 independently active prefixes

×
5,500 GET/HEAD per prefix

≈
55,000 read requests/second
```

is the example AWS itself uses to illustrate horizontal request scaling. ([AWS Documentation][3])

---

# 3. Prefixes Are Now a Performance Tool Too

Suppose all high-rate workload traffic hits:

```text
uploads/current/...
```

If the workload becomes extremely request-heavy, spreading requests across multiple active prefixes can provide more scaling headroom.

Conceptually:

```text
uploads/00/
uploads/01/
uploads/02/
uploads/03/
...
```

or a business-oriented partition:

```text
uploads/customer-a/
uploads/customer-b/
uploads/customer-c/
...
```

For ordinary workloads, don't prematurely build elaborate sharding. But when your application consistently moves beyond the documented per-prefix request rates, AWS recommends distributing traffic across multiple prefixes and parallelizing requests. S3 scales up to new request levels gradually rather than instantaneously. ([AWS Documentation][4])

---

# 4. What Is `503 Slow Down`?

Imagine traffic suddenly jumps:

```text
10 requests/sec
      ↓
50,000 requests/sec
```

You may temporarily encounter:

```text
HTTP 503
Slow Down
```

while S3 adapts to the higher request rate. AWS recommends gradual ramp-up plus retries with backoff; AWS SDKs already provide retry mechanisms that can be tuned for the application. ([AWS Documentation][2])

The production lesson is:

```text
503
≠
immediately assume S3 outage
```

Investigate:

```text
request-rate spike
prefix distribution
retry strategy
concurrency
client network
KMS quotas if SSE-KMS
```

SSE-KMS workloads can also introduce a separate AWS KMS request-rate dependency, so S3 capacity and KMS capacity must both be considered. ([AWS Documentation][2])

---

# 5. Large Objects — Multipart Upload Again, But Now for Performance

Suppose a user uploads:

```text
20 GiB video
```

One giant stream means:

```text
Client
  │
  │ one long request
  ▼
 S3

19.7 GiB transferred
       │
       X network error
```

Restarting the whole operation would be wasteful.

Multipart upload divides the object:

```text
20 GiB

├── Part 1
├── Part 2
├── Part 3
├── Part 4
├── ...
└── Part N
```

Parts can be uploaded independently and in parallel, and a failed part can be retried without retransmitting successful parts. ([AWS Documentation][5])

---

# 6. Multipart Upload Flow

The API workflow is:

```text
CreateMultipartUpload
        │
        ▼
     UploadId
        │
   ┌────┼────┬────┐
   ▼    ▼    ▼    ▼
Part1 Part2 Part3 Part4
   │    │    │    │
   └────┴────┴────┘
        │
        ▼
CompleteMultipartUpload
        │
        ▼
    ONE S3 object
```

The parts can arrive independently and out of order before completion. ([AWS Documentation][5])

---

# 7. Part Size Is an Engineering Decision

Imagine:

```text
Object = 100 GiB
```

Using:

```text
5 MiB parts
```

would create far too many parts.

Using:

```text
5 GiB parts
```

gives relatively little parallelism.

A practical transfer system selects part size based on:

```text
object size
network speed
available memory
parallel workers
retry cost
10,000-part ceiling
```

S3 currently permits up to 10,000 multipart parts, with normal part sizes between 5 MiB and 5 GiB except that the last part can be smaller. ([AWS Documentation][6])

The deeper lesson:

```text
SMALLER PARTS
=
cheap retries
+
more parallelism
+
more requests
```

while:

```text
LARGER PARTS
=
fewer requests
+
more data lost on retry
+
less parallelism
```

So the optimum is workload-specific.

---

# 8. Parallel Downloads — Byte-Range GET

Parallelism isn't only for uploads.

Suppose:

```text
Object:
50 GiB
```

Instead of:

```text
one GET
0–50 GiB
```

you can issue byte-range requests:

```text
Worker 1:
bytes 0–499MB

Worker 2:
bytes 500–999MB

Worker 3:
bytes 1GB–1.49GB

Worker 4:
...
```

S3 supports the HTTP `Range` header, and AWS specifically recommends concurrent ranged GETs as a way to improve aggregate throughput and reduce retry cost for large objects. ([AWS Documentation][1])

Example:

```bash
curl \
  -H "Range: bytes=0-1048575" \
  "$PRESIGNED_URL"
```

would request roughly the first MiB.

---

# 9. Multipart-Aware Downloads

If an object was created using multipart upload, AWS recommends, when practical, retrieving aligned ranges similar to the upload part boundaries. S3 can also address a specific uploaded part using the `partNumber` parameter. ([AWS Documentation][1])

Conceptually:

```text
UPLOAD

Part 1  100 MB
Part 2  100 MB
Part 3  100 MB


DOWNLOAD

GET Part 1
GET Part 2
GET Part 3

parallel
```

This becomes important for:

```text
ML datasets
large backups
video processing
data lakes
scientific datasets
```

---

# 10. Checksums — Don't Trust the ETag as Universal MD5

This is an important modern S3 rule.

Old tutorials often say:

```text
ETag = MD5
```

That is **not universally true**.

For multipart objects, the final ETag is not the MD5 hash of the entire object. AWS constructs multipart ETags using the per-part hashes plus multipart information. ([AWS Documentation][7])

Therefore:

```text
ETag
≠
universal integrity checksum
```

Use S3's supported checksum mechanisms when you need explicit object-integrity validation.

---

# 11. Modern S3 Checksums

Current S3 supports several checksum algorithms, including CRC-based algorithms and cryptographic hashes. Updated AWS SDKs can automatically calculate and send checksums, and S3 can reject uploads when a supplied checksum doesn't match with a `BadDigest` response. If neither client nor SDK selects a checksum, current S3 can default to CRC64NVME. ([AWS Documentation][7])

For production, the mental model is:

```text
Client calculates checksum
       │
       ▼
Upload data + checksum
       │
       ▼
S3 calculates checksum
       │
       ▼
MATCH?
 ┌─────┴─────┐
 │           │
YES         NO
 │           │
store      reject
           BadDigest
```

That is far stronger than:

```text
"Upload returned HTTP 200,
so I assume every byte is perfect."
```

---

# 12. Transfer Acceleration

Now imagine:

```text
User:
Brazil

Bucket:
ap-south-1
Mumbai
```

The user's traffic normally has a large geographical distance to travel.

S3 Transfer Acceleration lets clients connect through globally distributed AWS edge locations and then uses AWS's network path toward the S3 bucket. It is a bucket-level feature for general-purpose buckets and is especially relevant for long-distance transfers. ([AWS Documentation][8])

Architecture:

```text
Remote user
     │
     ▼
AWS Edge Location
     │
     │ optimized AWS network path
     ▼
S3 Bucket
ap-south-1
```

---

# 13. When Transfer Acceleration Helps

The strongest candidates are workloads with:

```text
globally distributed uploaders
large objects
good client internet connectivity
long geographic distance to S3 Region
```

AWS recommends measuring rather than assuming benefit and provides a Transfer Acceleration speed-comparison tool. ([AWS Documentation][4])

So:

```text
Client in Mumbai
Bucket in Mumbai
```

may see little value.

But:

```text
Clients worldwide
Bucket in Mumbai
```

is much more interesting.

One naming gotcha: globally named general-purpose buckets used with Transfer Acceleration can't contain periods in their bucket names. ([AWS Documentation][9])

---

# 14. CloudFront vs Transfer Acceleration

These are easy to confuse.

```text
CloudFront
=
cache/distribute content
closer to readers
```

while:

```text
S3 Transfer Acceleration
=
accelerate long-distance
transfer to/from S3
```

CloudFront is especially powerful for repeated downloads because the same content can be cached near users. Transfer Acceleration instead optimizes the transfer path to the underlying bucket through edge locations. AWS explicitly positions Transfer Acceleration for long-distance S3 transport. ([AWS Documentation][8])

We'll reconnect this distinction when we return to CloudFront + private S3 origins.

---

# 15. The Traditional Upload Architecture

Suppose a user uploads:

```text
5 GiB video
```

Traditional architecture:

```text
Browser
   │
   │ 5 GiB
   ▼
Internet
   │
   ▼
ALB
   │
   ▼
EC2
   │
   │ 5 GiB again
   ▼
S3
```

Think about what your EC2 application must now handle:

```text
5 GiB request body
timeouts
memory/buffering
network bandwidth
ALB connection
application connection
scaling
retry logic
```

But the EC2 application does not actually need to process every byte merely to authorize an upload.

---

# 16. Better Architecture — Presigned URL

Cloud-native pattern:

```text
Browser
   │
   │ "May I upload photo.jpg?"
   ▼
Application API
   │
   │ authenticate user
   │ authorize upload
   │ generate safe key
   ▼
Presigned URL
   │
   ▼
Browser
   │
   │ DIRECT UPLOAD
   ▼
S3
```

The backend handles:

```text
identity
authorization
business rules
object key generation
```

while S3 handles:

```text
the object bytes
```

A presigned URL grants time-limited access to a specific S3 operation without giving the browser permanent AWS credentials. The permissions available through the URL cannot exceed those of the principal that generated it. ([AWS Documentation][10])

---

# 17. Presigned URLs Are Bearer Tokens

This is security-critical.

Anyone possessing a valid presigned URL can potentially use it for the signed operation until it expires or the underlying credential becomes invalid.

AWS explicitly describes presigned URLs as bearer-token-style access and recommends protecting them accordingly. ([AWS Documentation][10])

Never:

```text
log presigned URLs
everywhere
```

or:

```text
send a 7-day upload URL
when 5 minutes is enough
```

Prefer short expirations.

---

# 18. Presigned URL Expiration

Using SigV4 and long-lived IAM user credentials, CLI/SDK-generated presigned URLs can be valid for up to seven days. But when the URL is signed using temporary credentials—such as an EC2 IAM role—the URL cannot outlive those credentials and expires when the underlying session expires. ([AWS Documentation][10])

For a production browser upload, something like:

```text
5 minutes
```

or:

```text
15 minutes
```

is generally much safer than using the maximum.

---

# 19. Presigned URL Does Not Mean Public Bucket

This architecture:

```text
Browser
     │
Presigned URL
     │
     ▼
Private S3
```

is completely valid.

You can keep:

```text
Block Public Access = ON
```

because the browser request is authorized using the signature embedded in the presigned URL.

The bucket does not have to be publicly readable or writable. Presigned URLs are specifically designed to grant controlled temporary object access without updating the bucket policy to public access. ([AWS Documentation][10])

---

# 20. Node.js Backend — AWS SDK v3

Install:

```bash
npm install \
  @aws-sdk/client-s3 \
  @aws-sdk/s3-request-presigner
```

AWS's current JavaScript SDK v3 uses `S3Client`, `PutObjectCommand`, and `getSignedUrl` for this pattern. ([AWS Documentation][11])

Example:

```javascript
import crypto from "node:crypto";

import {
  S3Client,
  PutObjectCommand
} from "@aws-sdk/client-s3";

import {
  getSignedUrl
} from "@aws-sdk/s3-request-presigner";

const s3 = new S3Client({
  region: "ap-south-1"
});

export async function createUploadUrl(req, res) {
  const { fileName, contentType } = req.body;

  // In production:
  // authenticate req.user first

  const safeId = crypto.randomUUID();

  const key =
    `uploads/${req.user.id}/${safeId}-${fileName}`;

  const command = new PutObjectCommand({
    Bucket: process.env.UPLOAD_BUCKET,
    Key: key,
    ContentType: contentType
  });

  const uploadUrl = await getSignedUrl(
    s3,
    command,
    {
      expiresIn: 300
    }
  );

  res.json({
    key,
    uploadUrl,
    expiresIn: 300
  });
}
```

The backend's IAM role needs permission for the S3 operation being signed; a presigned URL cannot grant more access than the signer already possesses. ([AWS Documentation][10])

---

# 21. Browser Upload

Frontend:

```javascript
const authResponse = await fetch(
  "/api/uploads/presign",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      fileName: file.name,
      contentType: file.type
    })
  }
);

const {
  uploadUrl,
  key
} = await authResponse.json();

const uploadResponse = await fetch(
  uploadUrl,
  {
    method: "PUT",
    headers: {
      "Content-Type": file.type
    },
    body: file
  }
);

if (!uploadResponse.ok) {
  throw new Error(
    `Upload failed: ${uploadResponse.status}`
  );
}

console.log("Uploaded:", key);
```

Now the bytes follow:

```text
Browser
   │
   └─────────────▶ S3
```

not:

```text
Browser
   ↓
Node
   ↓
S3
```

---

# 22. Never Let the Browser Choose Arbitrary S3 Keys

Bad API:

```text
Client:
"Give me permission to upload to:

production/database-backup.tar.gz"
```

Better:

```text
Server authenticates user
        │
        ▼
Server generates key
        │
        ▼
uploads/<user-id>/<uuid>
```

Why?

Because presigned URLs inherit authority from the signer. You should ensure your API decides what object key the caller is allowed to create rather than letting an untrusted browser arbitrarily choose sensitive keys. That is a security-design inference from how presigned URLs inherit the signing principal's permissions. ([AWS Documentation][10])

---

# 23. Another Important Gotcha — Same Key Can Overwrite

If you generate a presigned PUT for:

```text
uploads/user1/photo.jpg
```

and that key already exists, a successful upload can replace the current object at that key; in a versioned bucket this would instead create a new version. AWS explicitly notes that a presigned upload to an existing key replaces the current object. ([AWS Documentation][10])

Production pattern:

```text
use generated UUID keys
```

instead of:

```text
profile.jpg
```

when collisions are undesirable.

---

# 24. Presigned Download

The same architecture works for private downloads.

```text
Browser
   │
   │ asks API
   ▼
API checks:
"May this user read invoice 123?"
   │
   ▼
Presigned GET
   │
   ▼
Browser ─────────▶ S3
```

No need to stream a 5-GB file through Node.js merely because the application has to authorize it.

Presigned URLs support operations such as GET, PUT, and HEAD depending on what was signed. ([AWS Documentation][10])

---

# 25. CORS — Why Browser Uploads Suddenly Fail

Suppose:

```text
Frontend:
https://app.example.com
```

and request goes to:

```text
https://bucket.s3...
```

Those are different origins.

The browser applies:

# CORS

```text
Cross-Origin Resource Sharing
```

S3 supports a bucket CORS configuration defining which origins, methods, and request headers are permitted for cross-origin browser requests. ([AWS Documentation][12])

---

# 26. CORS Does NOT Grant S3 Permission

This is one of the most important distinctions.

CORS answers:

> “May browser JavaScript make/read this cross-origin response?”

It does **not** answer:

> “Is this caller authorized to S3?”

AWS states that normal S3 access controls and policies still apply when CORS is configured. ([AWS Documentation][12])

So:

```text
CORS Allow
+
no S3 authorization
=
still fail
```

and:

```text
S3 authorization
+
CORS mismatch
=
browser may still fail
```

Two different layers.

---

# 27. Production CORS Example

For:

```text
https://app.example.com
```

you might use:

```json
[
  {
    "AllowedOrigins": [
      "https://app.example.com"
    ],
    "AllowedMethods": [
      "GET",
      "PUT",
      "HEAD"
    ],
    "AllowedHeaders": [
      "Content-Type",
      "x-amz-*"
    ],
    "ExposeHeaders": [
      "ETag"
    ],
    "MaxAgeSeconds": 3000
  }
]
```

S3 CORS rules support allowed origins, methods such as GET/PUT/POST/DELETE/HEAD, allowed request headers, exposed response headers, and preflight caching. ([AWS Documentation][13])

Avoid:

```json
"AllowedOrigins": ["*"]
```

unless the business requirement really intends all origins.

---

# 28. CORS 403 Troubleshooting

If browser console says:

```text
CORS error
```

or S3 returns:

```text
403 Forbidden
```

check three main things:

```text
Origin
Method
Headers
```

The browser's origin must match `AllowedOrigins`, its method must be in `AllowedMethods`, and requested headers from the preflight must match `AllowedHeaders`. ([AWS Documentation][14])

Example:

```text
Allowed:

GET

Actual:

PUT

↓

403 / CORS failure
```

---

# 29. Direct Upload Architecture Is Only Half the Story

Once the browser uploads:

```text
uploads/raw/video.mp4
```

something usually needs to happen next:

```text
virus scan
thumbnail creation
metadata extraction
video transcoding
database update
ML inference
audit
notification
```

You don't want the browser to manually tell five backend services.

Instead:

```text
S3 Object Created
       │
       ▼
      EVENT
```

---

# 30. S3 Event Notifications

S3 can emit notifications for events such as:

```text
object creation
object deletion
restore
replication
Lifecycle events
tagging
```

and can deliver notifications to:

```text
Lambda
SQS
SNS
EventBridge
```

depending on the configuration. ([AWS Documentation][15])

Architecture:

```text
Browser
   │
   ▼
S3
   │
ObjectCreated
   │
   ▼
EVENT
   │
   ├──▶ Lambda
   ├──▶ SQS
   ├──▶ SNS
   └──▶ EventBridge
```

---

# 31. When to Use Lambda Directly

Simple pipeline:

```text
S3
 │
 ▼
Lambda
```

Great for:

```text
short processing
thumbnail generation
metadata extraction
simple automation
```

S3 invokes Lambda asynchronously, and the Lambda resource policy must grant S3 permission to invoke the function. ([AWS Documentation][16])

But direct Lambda invocation has less buffering control than putting a queue between storage and processing.

---

# 32. Why SQS Is Often Better for Heavy Pipelines

For heavy or bursty workloads:

```text
S3
 │
 ▼
SQS
 │
 ▼
Workers / Lambda
```

gives you a buffer.

Imagine:

```text
10,000 files arrive
within 30 seconds
```

Without buffering:

```text
10,000 events
        │
        ▼
processing tier immediately
```

With SQS:

```text
10,000 events
        │
        ▼
      QUEUE
        │
        ▼
consumer scales at controlled rate
```

This decoupling is a general architectural benefit of SQS's pull-based queue model and is particularly useful when event arrival rate and processing capacity differ. ([AWS Documentation][17])

---

# 33. S3 Cannot Directly Target SQS FIFO

This is a current exam/interview detail.

Direct S3 event notifications support SQS queues, but **SQS FIFO queues are not supported as a direct S3 event-notification destination**. AWS recommends routing the S3 event through EventBridge when a FIFO queue is required. ([AWS Documentation][18])

Architecture:

```text
S3
 │
 ▼
EventBridge
 │
 ▼
SQS FIFO
```

---

# 34. When SNS Fits

SNS is useful when one S3 event should fan out:

```text
                 S3
                  │
                  ▼
                 SNS
             ┌────┼────┐
             ▼    ▼    ▼
          Queue  Queue Email/
                         other subscriber
```

SNS is a publish/subscribe model, whereas SQS is a queue where consumers pull messages. ([AWS Documentation][17])

For robust application processing, a common fanout design is:

```text
S3
 ↓
SNS
 ↓
multiple SQS queues
 ↓
independent consumers
```

---

# 35. When EventBridge Fits

EventBridge becomes valuable when:

```text
many consumers
complex routing rules
cross-service events
rich event filtering
FIFO downstream routing
```

matter.

When EventBridge delivery is enabled on an S3 bucket, S3 sends the bucket's events to EventBridge; EventBridge rules then decide what targets receive the events. ([AWS Documentation][19])

Think:

```text
S3
 │
 ▼
EventBridge
 │
 ├── image event → Lambda
 ├── archive event → Step Functions
 ├── audit event → Firehose
 └── priority event → SQS FIFO
```

---

# 36. Direct Event Destinations Need Permission Too

Creating:

```text
S3 → Lambda
```

isn't just an S3 configuration issue.

The destination must authorize S3.

AWS requires the destination policy to permit the S3 service to invoke Lambda or publish to the configured SNS/SQS destination. ([AWS Documentation][20])

So if notification configuration fails or no events arrive:

```text
S3 config?
      ↓
destination resource policy?
      ↓
correct source bucket?
      ↓
correct ARN?
```

---

# 37. S3 Events Are At-Least-Once

This is the most important event-processing rule.

S3 Event Notifications are designed for:

```text
AT LEAST ONCE
```

delivery. AWS also explicitly states that notifications are not guaranteed to arrive in event order and that duplicate notifications can occur. ([AWS Documentation][15])

Therefore:

```text
one uploaded object
```

can theoretically produce:

```text
event
event
```

to your processing system.

Your code must handle this safely.

---

# 38. Idempotency

Suppose event says:

```text
process payment-receipt.pdf
```

and Lambda receives the event twice.

Bad:

```text
event 1
↓
charge customer

event 2
↓
charge customer again
```

An idempotent design ensures replaying the same event doesn't create a second unwanted side effect.

Mental model:

```text
Event ID/Object Version
       │
       ▼
Already processed?
   ┌───┴────┐
   │        │
  YES       NO
   │        │
return    process
           │
           ▼
      record completion
```

AWS recommends idempotent consumers anywhere at-least-once processing can produce duplicate invocations. ([AWS Documentation][21])

---

# 39. Use Object Version IDs When Versioning Is Enabled

For a versioned bucket, a strong processing identity can often include:

```text
bucket
+
key
+
versionId
```

rather than only:

```text
key
```

because:

```text
uploads/photo.jpg
```

may be uploaded repeatedly.

Conceptually store:

```text
processed:
bucket/key/versionId
```

in DynamoDB or another durable state store.

That lets:

```text
same exact version event arrives twice
```

be recognized as already processed.

This is an architectural inference built on S3's at-least-once delivery and object-version semantics. ([AWS Documentation][22])

---

# 40. Event Ordering Is Not Guaranteed

Suppose the same object changes:

```text
V1
↓
V2
↓
V3
```

Notification arrival could theoretically be:

```text
V1 event
V3 event
V2 event
```

because S3 Event Notifications are not guaranteed to arrive in occurrence order. ([AWS Documentation][22])

For create/delete events, the S3 event contains a:

```text
sequencer
```

value that can help determine ordering for events involving the **same object key**. ([AWS Documentation][23])

Never use it as a global bucket-wide ordering number.

---

# 41. Event Filtering

Suppose bucket contains:

```text
uploads/raw/
processed/
logs/
backups/
```

but Lambda only processes new JPEGs.

Configure:

```text
Prefix:
uploads/raw/

Suffix:
.jpg
```

Then S3 can emit the relevant notifications without invoking your consumer for unrelated objects. S3 event notifications support key-prefix and suffix filtering. ([AWS Documentation][24])

Conceptually:

```text
uploads/raw/a.jpg
       ↓
      EVENT


logs/a.log
       ↓
      NONE
```

This saves:

```text
invocations
cost
noise
consumer logic
```

---

# 42. Overlapping Filter Trap

S3 doesn't allow arbitrary overlapping prefix/suffix configurations for the same event type.

For example, configurations involving:

```text
all objects

AND

images/
```

for the same event type can conflict because the filters overlap.

AWS validates notification filters and rejects invalid overlapping rules; overlapping prefixes can be valid when paired with non-overlapping suffixes such as `.jpg` versus `.png`. ([AWS Documentation][24])

This is a common Terraform:

```text
InvalidArgument
Configuration is ambiguously defined
```

style failure.

---

# 43. The Infinite Lambda Loop

This is a famous production mistake.

Configuration:

```text
S3 ObjectCreated
      │
      ▼
Lambda
      │
      ▼
writes result
back to SAME bucket
      │
      ▼
ObjectCreated
      │
      ▼
Lambda
      │
      ▼
...
```

AWS explicitly warns that using the same bucket for input and output can recursively trigger the function. Use separate buckets or restrict the trigger to an incoming prefix that the Lambda does not write back into. ([AWS Documentation][16])

Safe:

```text
uploads/raw/
      │
      ▼
Lambda
      │
      ▼
processed/
```

with event filter:

```text
prefix = uploads/raw/
```

---

# 44. Recommended Production Upload Pipeline

Now combine everything:

```text
                       User
                        │
                        ▼
                 Frontend / Browser
                        │
             request upload permission
                        │
                        ▼
                    API / ALB
                        │
                        ▼
                    Node API
                        │
                 auth + validation
                        │
                        ▼
                Presigned PUT URL
                        │
                        ▼
Browser ─────────────────────────▶ S3
                                  │
                            uploads/raw/
                                  │
                             ObjectCreated
                                  │
                                  ▼
                                 SQS
                                  │
                                  ▼
                               Lambda
                                  │
                         ┌────────┼─────────┐
                         ▼        ▼         ▼
                      validate  process   metadata
                         │
                         ▼
                    processed/
```

This architecture removes large request bodies from your API tier while providing buffering and asynchronous processing.

---

# 45. Why This Scales Better Than Proxying Uploads Through EC2

Traditional:

```text
10,000 users
    │
    ▼
10,000 large HTTP uploads
    │
    ▼
ALB
    │
    ▼
EC2 fleet
```

Your compute fleet scales because users are moving bytes.

With presigning:

```text
10,000 users
    │
small API requests
    ▼
application
    │
presigned URLs
    ▼

10,000 users
    │
large files
    ▼
S3
```

The application scales primarily with:

```text
authorization requests
business logic
metadata
```

rather than raw file size.

That separation of control plane and data plane is the core architecture improvement.

---

# 46. Large Browser Uploads Need Multipart Presigning

For a 50-MB image:

```text
Presigned PUT
```

may be enough.

For:

```text
50 GiB video
```

you should evaluate presigned multipart upload:

```text
Browser
   │
   ▼
API
   │
CreateMultipartUpload
   │
   ▼
UploadId
   │
   ├── signed Part 1 URL
   ├── signed Part 2 URL
   ├── signed Part 3 URL
   └── ...
```

Browser uploads parts in parallel:

```text
Part1 ──▶
Part2 ──▶ S3
Part3 ──▶
Part4 ──▶
```

Then the backend or authorized client completes the multipart upload.

Multipart's independent parallel parts and retry behavior make it the correct building block for large transfers. ([AWS Documentation][5])

---

# 47. Private EC2 → S3 Without NAT

Now reconnect networking.

Private application:

```text
Private EC2
    │
    ▼
S3
```

doesn't necessarily need:

```text
NAT Gateway
```

for S3 traffic.

For normal VPC S3 access, a **gateway endpoint** can add S3 routing to your route tables and keep the traffic on the AWS network. S3 also supports interface endpoints through PrivateLink when private IP-based access from other network contexts is required. ([AWS Documentation][25])

Architecture:

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

That is useful both for private connectivity and cost architecture.

---

# 48. Gateway vs Interface Endpoint

A useful shortcut:

| Gateway endpoint                                                   | Interface endpoint                      |
| ------------------------------------------------------------------ | --------------------------------------- |
| Route-table integration                                            | ENIs/private IPs                        |
| Common S3 VPC pattern                                              | PrivateLink                             |
| No endpoint hourly/data processing charge from the endpoint itself | Billed                                  |
| Not for direct on-prem access                                      | Can support on-prem/private-IP patterns |
| Traffic stays on AWS network                                       | Traffic stays on AWS network            |

AWS explicitly supports both endpoint types for S3 and notes that interface endpoints extend to on-premises and connected-VPC use cases. ([AWS Documentation][25])

---

# 49. Monitoring S3 Performance

For performance diagnosis, useful request metrics include concepts such as:

```text
AllRequests
GetRequests
PutRequests
4xxErrors
5xxErrors
FirstByteLatency
TotalRequestLatency
BytesDownloaded
BytesUploaded
```

S3 CloudWatch request metrics provide near-real-time operational visibility, but AWS warns they are not guaranteed to be complete enough to serve as authoritative request accounting. ([AWS Documentation][26])

So:

```text
CloudWatch metrics
=
operations/performance monitoring
```

not necessarily:

```text
perfect audit ledger
```

---

# 50. Performance Incident — 503s

Application reports:

```text
upload failure rate rising
```

Metrics:

```text
5xxErrors rising
```

Request volume:

```text
suddenly 20× higher
```

Investigate:

```text
prefix concentration
concurrency
retry behavior
client-side timeouts
request ramp rate
KMS throttling if SSE-KMS
```

S3 can temporarily return `503 Slow Down` while scaling to a new high request rate, so clients need retries with appropriate backoff. ([AWS Documentation][2])

---

# 51. Performance Incident — Downloads Are Slow

Do not immediately say:

```text
"S3 is slow."
```

Check:

```text
client network
geographic distance
single vs parallel connection
object size
Range GET
CloudFront caching opportunity
Transfer Acceleration
EC2 network bandwidth
```

AWS explicitly recommends multiple connections and ranged retrievals for large-object throughput, while Transfer Acceleration targets long-distance transfer paths. ([AWS Documentation][1])

---

# 52. Audit Logging — CloudTrail

If you need to answer:

> **“Who deleted `customer-data.csv`?”**

you need an audit trail, not just performance metrics.

CloudTrail supports S3 object-level data events such as:

```text
GetObject
PutObject
DeleteObject
```

but object-level S3 data events are **not logged by default** in a normal trail; you must configure them. Additional charges apply. ([AWS Documentation][27])

This is important:

```text
CloudTrail management events
≠
automatically all S3 object activity
```

---

# 53. Server Access Logging

S3 server access logs provide request-level information useful for:

```text
security analysis
traffic analysis
billing analysis
request timing
authentication failures
```

AWS currently supports traditional delivery to an S3 general-purpose bucket and a newer delivery path through CloudWatch Logs with additional structured-query and aggregation capabilities. ([AWS Documentation][28])

AWS currently recommends CloudTrail for bucket/object API action logging when identifying who performed requests, while server access logging remains useful for additional S3-specific request detail. ([AWS Documentation][29])

---

# 54. Logs vs Metrics vs Events

These three are very different.

```text
METRIC
=
How is the system behaving?
```

Example:

```text
5xx rate
latency
request count
```

```text
LOG
=
What request happened?
Who made it?
What did S3 return?
```

```text
EVENT
=
Something happened;
trigger workflow.
```

Example:

```text
ObjectCreated
→ process file
```

Do not build:

```text
security auditing
```

using event notifications alone.

And don't build:

```text
business processing
```

by periodically parsing server access logs.

Use the right signal.

---

# 55. End-to-End Troubleshooting — Browser Upload 403

Architecture:

```text
Browser
 ↓
Presigned URL
 ↓
S3
```

Request returns:

```text
403
```

Check in this order:

```text
Did URL expire?
      ↓
Did signing credential expire?
      ↓
correct bucket?
      ↓
correct key?
      ↓
correct HTTP method?
      ↓
required signed headers identical?
      ↓
backend signer has s3:PutObject?
      ↓
bucket policy explicit Deny?
      ↓
KMS permissions?
      ↓
CORS only if browser/preflight problem
```

Presigned URLs are tied to the operation, object, expiration, and signing principal's permissions. ([AWS Documentation][10])

---

# 56. CORS Failure vs S3 Authorization Failure

This distinction will save hours.

### Browser reports CORS

Check:

```text
AllowedOrigin
AllowedMethod
AllowedHeaders
```

### AWS CLI using same object fails too

Then CORS is irrelevant.

CLI isn't subject to browser CORS enforcement.

Investigate:

```text
IAM
bucket policy
KMS
VPC endpoint
signature
```

CORS is a browser cross-origin control layer, while S3 access policies remain independently enforced. ([AWS Documentation][12])

---

# 57. Event Notification Missing

Object uploaded, but consumer never receives event.

Troubleshoot:

```text
Correct event type?
      ↓
Prefix/suffix matches?
      ↓
Destination configured?
      ↓
Destination policy allows S3?
      ↓
Same SQS destination requirements?
      ↓
Consumer actually reading queue?
```

Direct notification destinations need permissions allowing S3 to invoke/publish to them. ([AWS Documentation][20])

For SQS specifically, the direct notification queue must be in the same Region as the S3 bucket, and direct S3 notification does not support FIFO queues. ([AWS Documentation][22])

---

# 58. Duplicate Processing Incident

You see two rows in your database for one uploaded image.

Don't conclude:

```text
"S3 bug."
```

First check whether your consumer assumed:

```text
exactly once
```

when S3 Event Notifications guarantee only:

```text
at least once
```

and duplicates can occur. ([AWS Documentation][22])

Correct the consumer:

```text
event arrives
    │
    ▼
derive idempotency key
    │
    ▼
conditional insert/check
    │
    ├── already processed → return
    │
    └── new → process
```

---

# 59. Final Production Architecture

Let's connect everything we've learned from Lessons 24–27:

```text
                           Internet
                              │
                              ▼
                         CloudFront
                              │
                              ▼
                         Web Frontend
                              │
                request upload permission
                              │
                              ▼
                             ALB
                              │
                              ▼
                     EC2 Auto Scaling
                         Node.js API
                              │
                    IAM Instance Role
                              │
                      generate short-lived
                       Presigned URL
                              │
                              ▼
                            Browser
                              │
                         direct upload
                              ▼
                     ┌────────────────┐
                     │   Private S3   │
                     │                │
                     │ Versioning     │
                     │ SSE-KMS        │
                     │ BPA            │
                     │ Lifecycle      │
                     └───────┬────────┘
                             │
                         ObjectCreated
                             │
                             ▼
                            SQS
                             │
                             ▼
                           Lambda
                             │
                  ┌──────────┼──────────┐
                  ▼          ▼          ▼
               validate   thumbnail   metadata
                  │
                  ▼
             processed/
```

Private EC2 instances can separately access S3 through:

```text
S3 Gateway Endpoint
```

instead of requiring NAT solely for S3 traffic. ([AWS Documentation][25])

---

# 60. Resume-Ready Explanation

You can now describe this architecture as:

> Designed a scalable S3 upload pipeline using short-lived presigned URLs to offload large file transfers from EC2 application servers, with browser CORS controls, private S3 access, multipart upload support, checksum validation, SQS-buffered S3 event processing, idempotent Lambda consumers, versioning and lifecycle management, and CloudWatch/CloudTrail observability.

That combines:

```text
performance
security
availability
cost
event-driven design
DevOps
```

instead of merely:

```text
"I know how to upload a file to S3."
```

---

# 61. SAA-C03 / DOP-C02 Scenarios

| Scenario                                | Best first thought              |
| --------------------------------------- | ------------------------------- |
| Millions of S3 requests                 | concurrency + prefixes          |
| Large upload                            | multipart upload                |
| Large download                          | parallel Range GET              |
| Global user uploads far from bucket     | Transfer Acceleration           |
| Browser needs temporary private upload  | presigned PUT/POST              |
| Browser gets cross-origin error         | CORS                            |
| Heavy upload processing pipeline        | S3 → SQS → consumers            |
| Simple small processor                  | S3 → Lambda                     |
| Multiple downstream consumers           | SNS/EventBridge                 |
| Need FIFO downstream                    | S3 → EventBridge → SQS FIFO     |
| Duplicate event caused duplicate DB row | missing idempotency             |
| Lambda recursively invokes itself       | same input/output trigger scope |
| Private EC2 needs S3 without NAT        | gateway endpoint                |
| Need object API audit                   | CloudTrail data events          |
| Need S3 operational request detail      | CloudWatch/request logs         |

These patterns align with AWS's current S3 performance, event-notification, private-connectivity and logging guidance. ([AWS Documentation][2])

---

# 62. Never-Forget Performance Model

```text
S3 PERFORMANCE
      │
      ├── CONCURRENCY
      │
      ├── PREFIX DISTRIBUTION
      │
      ├── MULTIPART UPLOAD
      │
      ├── RANGE GET
      │
      ├── RETRIES
      │
      ├── CLIENT NETWORK
      │
      └── GEOGRAPHIC DISTANCE
```

And:

```text
Large upload
=
Multipart
```

```text
Large download
=
Range GET + concurrency
```

```text
Global long-distance transfer
=
consider Transfer Acceleration
```

---

# 63. Never-Forget Application Model

```text
APP
 │
 │ authorize only
 ▼
Presigned URL
 │
 ▼
Browser
 │
 │ bytes go direct
 ▼
S3
```

not:

```text
Browser
  │
  │ giant file
  ▼
EC2
  │
  │ same giant file
  ▼
S3
```

unless your application genuinely needs to inspect/transform the bytes synchronously.

---

# 64. Never-Forget Event Model

```text
S3 EVENT
   │
   ▼
AT LEAST ONCE
   │
   ├── duplicates possible
   │
   └── ordering not guaranteed
             │
             ▼
        IDEMPOTENT
         CONSUMER
```

That rule is more important than memorizing which console button creates the notification. ([AWS Documentation][22])

---

# 65. Fifteen Rules to Permanently Remember

```text
1. Scale S3 horizontally with concurrency.

2. General-purpose S3 provides thousands of
   requests/sec per active partitioned prefix.

3. Scaling to a sudden new request rate is gradual.

4. 503 Slow Down means retry/backoff and inspect workload.

5. Multipart upload is for large resilient parallel uploads.

6. Range GET enables parallel partial downloads.

7. ETag is not a universal whole-object MD5.

8. Use checksums when integrity matters.

9. Transfer Acceleration targets long-distance transfers.

10. Presigned URLs are temporary bearer-style authorization.

11. CORS does not grant S3 permission.

12. Send file bytes directly to S3 when your API
    only needs to authorize the upload.

13. S3 events are at-least-once and not ordered.

14. Event consumers must be idempotent.

15. Use SQS when you need buffering between
    upload bursts and processing capacity.
```

---

# ✅ Lesson 27 Part 5 Complete

You now understand:

```text
✓ S3 request scaling
✓ per-prefix request performance
✓ concurrency
✓ 503 Slow Down
✓ retries
✓ multipart performance
✓ part sizing
✓ Range GET
✓ parallel downloads
✓ checksums
✓ ETag limitations
✓ Transfer Acceleration
✓ presigned GET
✓ presigned PUT
✓ temporary credentials
✓ browser direct upload
✓ Node.js SDK v3
✓ CORS
✓ S3 Event Notifications
✓ Lambda
✓ SQS
✓ SNS
✓ EventBridge
✓ FIFO limitation
✓ at-least-once delivery
✓ event ordering
✓ sequencer
✓ idempotency
✓ prefix/suffix filtering
✓ recursive Lambda prevention
✓ S3 VPC endpoints
✓ CloudWatch metrics
✓ CloudTrail data events
✓ server access logging
✓ production troubleshooting
```

## Next — Lesson 27 Part 6: **S3 Static Websites, CloudFront, OAC, DNS & Production Delivery**

This next part connects directly into the infrastructure work we've already been doing:

```text
User
 │
 ▼
Route 53
 │
 ▼
CloudFront
 │
 ├── ACM certificate
 │      us-east-1
 │
 ├── WAF
 │
 ├── caching
 │
 └── HTTPS
 │
 ▼
PRIVATE S3
 │
 ├── Block Public Access ON
 │
 ├── OAC
 │
 ├── bucket policy
 │
 └── static assets
```

We'll cover **S3 website endpoints vs S3 REST origins, why OAC cannot use the website endpoint, private S3 + CloudFront, OAC replacing legacy OAI, ACM in `us-east-1`, custom domains, Route 53 aliases, cache policies, invalidations, SPA routing, 403/404 troubleshooting, signed URLs/cookies, WAF, Terraform, and a complete production static-site lab**.

[1]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance-guidelines.html "Performance guidelines for Amazon S3 - Amazon Simple Storage Service"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html?utm_source=chatgpt.com "Best practices design patterns: optimizing Amazon S3 ..."
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html "Best practices design patterns: optimizing Amazon S3 performance - Amazon Simple Storage Service"
[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance-design-patterns.html?utm_source=chatgpt.com "Performance design patterns for Amazon S3"
[5]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html "Uploading and copying objects using multipart upload in Amazon S3 - Amazon Simple Storage Service"
[6]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html?utm_source=chatgpt.com "Amazon S3 multipart upload limits"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity-upload.html "Checking object integrity for data uploads in Amazon S3 - Amazon Simple Storage Service"
[8]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/transfer-acceleration.html "Configuring fast, secure file transfers using Amazon S3 Transfer Acceleration - Amazon Simple Storage Service"
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html?utm_source=chatgpt.com "General purpose bucket naming rules"
[10]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html "Download and upload objects with presigned URLs - Amazon Simple Storage Service"
[11]: https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/javascript_s3_code_examples.html "Amazon S3 examples using SDK for JavaScript (v3) - AWS SDK for JavaScript"
[12]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enabling-cors-examples.html "Configuring cross-origin resource sharing (CORS) - Amazon Simple Storage Service"
[13]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/ManageCorsUsing.html?utm_source=chatgpt.com "Elements of a CORS configuration"
[14]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/cors-troubleshooting.html?utm_source=chatgpt.com "Troubleshooting CORS - Amazon Simple Storage Service"
[15]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html "Amazon S3 Event Notifications - Amazon Simple Storage Service"
[16]: https://docs.aws.amazon.com/lambda/latest/dg/with-s3.html "Process Amazon S3 event notifications with Lambda - AWS Lambda"
[17]: https://docs.aws.amazon.com/decision-guides/latest/sns-or-sqs-or-eventbridge/sns-or-sqs-or-eventbridge.html?utm_source=chatgpt.com "Amazon SQS, Amazon SNS, or EventBridge?"
[18]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-how-to-event-types-and-destinations.html?utm_source=chatgpt.com "Event notification types and destinations"
[19]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-event-notifications-eventbridge.html?utm_source=chatgpt.com "Enabling Amazon EventBridge - AWS Documentation"
[20]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/grant-destinations-permissions-to-s3.html "Granting permissions to publish event notification messages to a destination - Amazon Simple Storage Service"
[21]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-eventsourcemapping.html?utm_source=chatgpt.com "How Lambda processes records from stream and queue- ..."
[22]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-how-to-event-types-and-destinations.html "Event notification types and destinations - Amazon Simple Storage Service"
[23]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-content-structure.html?utm_source=chatgpt.com "Event message structure - Amazon Simple Storage Service"
[24]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/notification-how-to-filtering.html "Configuring event notifications using object key name filtering - Amazon Simple Storage Service"
[25]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/privatelink-interface-endpoints.html "AWS PrivateLink for Amazon S3 - Amazon Simple Storage Service"
[26]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/metrics-dimensions.html "Metrics and dimensions - Amazon Simple Storage Service"
[27]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-cloudtrail-logging-for-s3.html "Enabling CloudTrail event logging for S3 buckets and objects - Amazon Simple Storage Service"
[28]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html "Enabling Amazon S3 server access logging - Amazon Simple Storage Service"
[29]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-s3-access-logs-to-identify-requests.html?utm_source=chatgpt.com "Using Amazon S3 server access logs to identify requests"
