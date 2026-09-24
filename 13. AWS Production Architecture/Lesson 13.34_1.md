# AWS Masterclass — Lesson 34 Part 1

# Amazon SQS from First Principles

## Decoupling, Standard vs FIFO, Visibility Timeout, Long Polling, DLQs, Fair Queues, Encryption & Production Queue Design

We already used SQS with Lambda.

Now we stop thinking:

```text
SQS
=
"something that triggers Lambda"
```

and start thinking like a distributed-systems engineer:

```text
SQS
=
DURABLE ASYNCHRONOUS BUFFER
BETWEEN PRODUCERS AND CONSUMERS
```

Amazon SQS is a fully managed message-queue service designed to decouple distributed application components and let producers and consumers scale independently. ([AWS Documentation][1])

---

# 1. Why Do We Need a Queue?

Imagine:

```text
User
 │
 ▼
Order API
 │
 ├── charge payment
 ├── send email
 ├── create invoice
 ├── update analytics
 ├── update warehouse
 └── call CRM
```

If every dependency is synchronous:

```text
Order API
   │
   ├── Payment  400 ms
   ├── Email    900 ms
   ├── CRM      2 sec
   ├── Invoice  500 ms
   └── Analytics 300 ms
```

the user waits for everything.

Worse:

```text
CRM DOWN
   │
   ▼
Order API DOWN
   │
   ▼
CUSTOMER CANNOT ORDER
```

This is:

# Tight Coupling

---

# 2. Add SQS

Better:

```text
                 CUSTOMER
                    │
                    ▼
                Order API
                    │
              save order
                    │
                    ▼
                   SQS
                    │
        ┌───────────┼────────────┐
        ▼           ▼            ▼
     Email       Invoice      Warehouse
     Worker       Worker        Worker
```

Now the API can often respond after the critical transaction is accepted rather than waiting for every background activity.

SQS gives us:

```text
time decoupling

failure decoupling

scaling decoupling
```

---

# 3. Producer → Queue → Consumer

The permanent SQS mental model:

```text
PRODUCER
   │
   │ SendMessage
   ▼
┌─────────────────┐
│      SQS        │
│                 │
│  message        │
│  message        │
│  message        │
└─────────────────┘
   │
   │ ReceiveMessage
   ▼
CONSUMER
   │
   │ successful work
   ▼
DeleteMessage
```

There are three operations you should always visualize:

```text
SEND

RECEIVE

DELETE
```

---

# 4. Receiving Does NOT Delete the Message

This is one of the most important SQS rules.

When a consumer receives a message:

```text
message
   │
   ▼
consumer receives it
   │
   ▼
message REMAINS in SQS
```

It simply becomes temporarily:

```text
INVISIBLE
```

to other consumers.

The default visibility timeout is currently **30 seconds**, configurable from `0` seconds up to **12 hours**. ([AWS Documentation][2])

---

# 5. Visibility Timeout

Suppose:

```text
10:00:00
Consumer A receives message
```

Queue:

```text
Message exists
but becomes invisible
```

Consumer A now processes it.

### If successful

```text
Consumer A
    │
    ▼
DeleteMessage
```

The message is permanently removed.

### If Consumer A crashes

```text
Consumer A
    X
```

and never deletes it.

After visibility timeout:

```text
message becomes visible
        │
        ▼
Consumer B can receive it
```

That's the reliability mechanism.

---

# 6. Why Visibility Timeout Is Necessary

Without it:

```text
Consumer receives message
        │
        X crashes
```

and if SQS had already deleted it:

```text
MESSAGE LOST
```

Instead:

```text
receive
   │
hide
   │
process
   │
delete only after success
```

This gives you safe retry behavior.

---

# 7. Visibility Timeout Too Short

Suppose:

```text
processing time
=
60 sec

visibility timeout
=
20 sec
```

Timeline:

```text
00 sec
Consumer A starts

20 sec
message visible again

22 sec
Consumer B starts same message

60 sec
Consumer A finishes
```

Now:

```text
A + B
```

may process the same business event.

AWS specifically warns that too-short visibility timeouts can cause duplicate concurrent processing. ([AWS Documentation][3])

---

# 8. Visibility Timeout Too Long

Opposite problem:

```text
processing time
=
5 sec

visibility timeout
=
30 minutes
```

Consumer crashes after 2 seconds.

Now the message may wait a long time before being retried.

Therefore:

```text
Visibility timeout
should reflect
worst reasonable processing time
```

not:

```text
maximum possible number
```

---

# 9. Heartbeat Pattern

What if job duration is unpredictable?

For example:

```text
video processing
=
30 seconds
to
2 hours
```

Use:

```text
initial visibility
        │
        ▼
consumer working
        │
        ▼
ChangeMessageVisibility
        │
        ▼
extend
        │
        ▼
continue
```

AWS recommends this heartbeat-style approach when processing duration cannot be accurately predicted. The total visibility window cannot exceed 12 hours from the original receive operation. ([AWS Documentation][3])

---

# 10. Important Lambda Rule

For:

```text
SQS
 │
 ▼
Lambda
```

AWS currently recommends setting the SQS visibility timeout to at least:

```text
6 × Lambda function timeout
```

to leave room for throttling/retry behavior. ([AWS Documentation][4])

Example:

```text
Lambda timeout
=
30 sec


SQS visibility
≥
180 sec
```

This is a very useful certification rule.

---

# PART A — MESSAGE RETENTION

# 11. Messages Don't Stay Forever

Current SQS retention:

```text
minimum:
1 minute

default:
4 days

maximum:
14 days
```

([AWS Documentation][2])

After the retention period expires:

```text
message
   │
   ▼
automatically deleted
```

even if nobody ever successfully processed it.

---

# 12. Retention Is Not a Retry Policy

Do not confuse:

```text
Retention period
```

with:

```text
Visibility timeout
```

### Retention

```text
How long can message exist
in the queue?
```

### Visibility

```text
After a consumer receives it,
how long is it hidden?
```

Mental model:

```text
                    MESSAGE LIFETIME

Send
 │
 ▼
Visible
 │
 ▼
Receive
 │
 ▼
Invisible ← visibility timeout
 │
 ├── Delete → gone
 │
 └── timeout → visible again
                   │
                   ▼
               retries...
                   │
                   ▼
           retention expires
                   │
                   ▼
                  gone
```

---

# PART B — DELAY QUEUES

# 13. Sometimes You Don't Want Immediate Delivery

Example:

```text
Customer creates account
        │
        ▼
wait 5 minutes
        │
        ▼
send onboarding reminder
```

SQS supports delayed delivery of up to:

```text
15 minutes.
```

([AWS Documentation][2])

---

# 14. Delay vs Visibility Timeout

These sound similar but happen at different times.

### Delay

```text
SEND
 │
 ▼
message hidden initially
 │
 ▼
delay expires
 │
 ▼
message visible
```

### Visibility

```text
message visible
 │
 ▼
RECEIVE
 │
 ▼
message hidden
 │
 ▼
consumer processes
```

AWS explicitly describes this distinction. ([AWS Documentation][5])

---

# 15. Queue Delay

Configure:

```text
DelaySeconds=300
```

Then every newly sent message waits:

```text
5 minutes
```

before consumers can receive it.

Maximum:

```text
900 seconds
=
15 minutes.
```

([AWS Documentation][6])

---

# 16. Individual Message Timer

For standard queues you can override delay per message.

Example:

```bash
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{"orderId":"123"}' \
  --delay-seconds 120
```

Individual message timers support up to 15 minutes; FIFO queues do **not** support per-message timers. ([AWS Documentation][7])

---

# 17. Need “Run Tomorrow at 9 AM”?

Do **not** abuse SQS delay for:

```text
24 hours

3 days

next month

specific calendar time
```

AWS recommends:

```text
EventBridge Scheduler
```

for more advanced scheduling beyond SQS's 15-minute delay capability. ([AWS Documentation][7])

We'll study Scheduler deeply later in this module.

---

# PART C — POLLING

# 18. Consumers Must Receive Messages

A traditional SQS consumer repeatedly calls:

```text
ReceiveMessage
```

Two polling modes matter:

```text
Short polling

Long polling
```

---

# 19. Short Polling

Short polling:

```text
Consumer
   │
   ▼
ReceiveMessage
   │
   ▼
SQS checks subset of servers
   │
   ▼
immediate response
```

This can produce:

```text
EMPTY RESPONSE
```

even though messages still exist elsewhere in the distributed queue infrastructure.

AWS calls this a possible:

```text
false empty response.
```

([AWS Documentation][8])

---

# 20. Long Polling

With:

```text
WaitTimeSeconds > 0
```

long polling is enabled.

Current maximum:

```text
20 seconds.
```

([AWS Documentation][8])

Architecture:

```text
Consumer
   │
   ▼
ReceiveMessage
WaitTime=20
   │
   ▼
SQS waits
   │
 ┌─┴───────────────┐
 ▼                 ▼
message arrives   20 sec expires
 ▼                 ▼
return             empty
immediately
```

---

# 21. Why Long Polling Is Usually Better

Long polling reduces:

```text
empty responses

false empty responses

unnecessary API requests
```

and therefore can reduce polling cost and wasted work. ([AWS Documentation][9])

For ordinary worker architectures:

```text
prefer long polling
```

unless you have a specific reason not to.

---

# PART D — STANDARD QUEUES

# 22. Standard Queue Properties

Standard SQS gives:

```text
very high / nearly unlimited throughput

at-least-once delivery

best-effort ordering

multi-AZ durability
```

([AWS Documentation][10])

The critical two are:

```text
AT LEAST ONCE

BEST EFFORT ORDERING
```

---

# 23. At-Least-Once Delivery

SQS guarantees:

```text
message delivered
at least once
```

but it may occasionally deliver:

```text
same logical message
more than once.
```

([AWS Documentation][10])

Therefore the consumer must be:

# Idempotent

---

# 24. Idempotency Again

Message:

```json
{
  "paymentId": "PAY-123",
  "amount": 5000
}
```

Consumer receives it twice.

Bad:

```text
receive 1
→ charge ₹5000

receive 2
→ charge ₹5000 again
```

Correct:

```text
paymentId PAY-123
already completed?
       │
   ┌───┴───┐
   YES     NO
    │       │
    ▼       ▼
 return   process
```

This principle is not optional with Standard SQS.

AWS explicitly recommends idempotent consumer operations because duplicates can occur. ([AWS Documentation][10])

---

# 25. Best-Effort Ordering

Producer sends:

```text
A
B
C
D
```

Standard queue may normally return them similarly, but it does **not** guarantee strict order. ([AWS Documentation][10])

If order matters:

```text
Account created

then

Account upgraded

then

Account deleted
```

you should evaluate FIFO.

---

# PART E — FIFO QUEUES

# 26. FIFO

FIFO stands for:

```text
First In
First Out
```

FIFO queues provide ordering within message groups and queue-side duplicate suppression designed for workloads where order and duplicate introduction matter. ([AWS Documentation][11])

---

# 27. Message Groups

FIFO messages require:

```text
MessageGroupId
```

([AWS Documentation][2])

Example:

```text
MessageGroupId=customer-101

A
B
C
```

SQS preserves:

```text
A → B → C
```

for that group.

---

# 28. Parallel FIFO Ordering

You do **not** need one queue per customer.

Use multiple groups:

```text
FIFO Queue
│
├── customer-A
│    A1 → A2 → A3
│
├── customer-B
│    B1 → B2
│
└── customer-C
     C1 → C2
```

Within each group:

```text
ordered
```

Across groups:

```text
parallel processing possible.
```

FIFO queues support an unbounded number of message groups conceptually for distributing ordered workloads. ([AWS Documentation][11])

---

# 29. One Message Group Can Destroy Throughput

Bad:

```text
MessageGroupId="everything"
```

for 10 million messages.

You effectively created:

```text
ONE SERIAL PROCESSING LANE.
```

Better:

```text
customerId

accountId

orderId

deviceId
```

depending on the ordering boundary.

Your MessageGroupId should represent:

> “What must remain ordered relative to what?”

---

# 30. FIFO Deduplication ID

FIFO also uses:

```text
MessageDeduplicationId
```

to suppress duplicate sends.

The deduplication interval is currently:

```text
5 minutes.
```

If a producer retries the same deduplication ID during that window, SQS accepts the request semantics without introducing a duplicate message into the queue. ([AWS Documentation][12])

---

# 31. Important “Exactly Once” Nuance

AWS describes FIFO queues as providing:

```text
exactly-once processing
```

at the SQS queue/deduplication level. ([AWS Documentation][11])

But don't misinterpret that as:

```text
My business side effect
can never happen twice.
```

A consumer can still:

```text
receive message
      │
      ▼
charge payment
      │
      X crash before DeleteMessage
```

Then after visibility timeout, processing may be attempted again.

Therefore:

```text
FIFO
does NOT remove the need
for idempotent business logic.
```

That follows directly from SQS's visibility/delete processing model. ([AWS Documentation][13])

---

# 32. Standard or FIFO?

Use:

### Standard

when:

```text
massive throughput

ordering not critical

duplicates manageable

independent tasks
```

Examples:

```text
image resizing

email jobs

analytics events

background processing
```

### FIFO

when:

```text
ordering is business critical
```

Examples:

```text
financial ledger commands

inventory adjustments

device commands

ordered account updates
```

---

# PART F — HIGH-THROUGHPUT FIFO

# 33. FIFO Is No Longer Necessarily “Slow”

Older AWS training often teaches:

```text
FIFO
=
300 TPS forever.
```

That is outdated.

Standard FIFO without high-throughput mode still uses the familiar per-partition limits, including up to **300 API transactions/sec per action**, or **3,000 messages/sec with batches of 10**. High-throughput FIFO raises those quotas substantially. ([AWS Documentation][2])

---

# 34. Mumbai High-Throughput FIFO

For `ap-south-1`, AWS currently documents high-throughput FIFO quotas of up to:

```text
9,000 TPS
per non-batched API action
```

and, with batches of 10:

```text
90,000 messages/sec
```

per API action, subject to the published FIFO throughput model and account quotas. ([AWS Documentation][2])

That's directly relevant to our preferred Mumbai architecture.

---

# 35. Batching Matters

SQS batch APIs handle up to:

```text
10 messages
```

per request. ([AWS Documentation][2])

Instead of:

```text
SendMessage × 10
```

you can use:

```text
SendMessageBatch
```

Likewise:

```text
DeleteMessageBatch
```

This can substantially improve effective message throughput and reduce API calls.

---

# PART G — FAIR QUEUES

# 36. A Very Important Modern SQS Feature

Suppose you operate a SaaS platform:

```text
Shared Standard Queue

Tenant A
Tenant B
Tenant C
Tenant D
```

Normally everything is fine.

Then Tenant A generates:

```text
10 million jobs.
```

Consumers become occupied with A's backlog.

Now tenants:

```text
B
C
D
```

experience longer queue dwell times even though they did nothing wrong.

This is the:

# Noisy Neighbor Problem

---

# 37. Amazon SQS Fair Queues

SQS now supports:

# Fair Queues

on **standard queues**.

Fair queues monitor how message groups consume in-flight capacity and prioritize quieter groups when one group is dominating processing, helping reduce dwell-time impact on other tenants. ([AWS Documentation][14])

---

# 38. How Do You Enable Fairness?

Producer sets:

```text
MessageGroupId
```

even though the queue is:

```text
STANDARD
```

Example:

```text
tenant-A
tenant-B
tenant-C
```

AWS applies fair-queue behavior automatically to standard-queue messages carrying `MessageGroupId`; consumers do not need special fair-queue code. ([AWS Documentation][14])

---

# 39. Critical Difference

On FIFO:

```text
MessageGroupId
=
ORDERING boundary
```

On Standard Fair Queue:

```text
MessageGroupId
=
TENANT / FAIRNESS identifier
```

It does **not** provide FIFO ordering for a standard queue. ([AWS Documentation][14])

This is a very good 2026 interview point.

---

# 40. SaaS Example

```text
              STANDARD FAIR QUEUE

 Tenant A ─────┐
 Tenant B ─────┤
 Tenant C ─────┤
 Tenant D ─────┘
               │
        MessageGroupId
               │
               ▼
              SQS
               │
      detects noisy tenant
               │
               ▼
    protects quieter tenants'
          dwell times
               │
               ▼
            Workers
```

This lets you retain:

```text
standard-queue throughput
```

without letting one noisy tenant dominate other tenants' queue experience. ([AWS Documentation][14])

---

# 41. Fair Queue Metrics

Current CloudWatch fair-queue metrics include:

```text
ApproximateNumberOfNoisyGroups

ApproximateNumberOfMessagesVisibleInQuietGroups

ApproximateNumberOfMessagesNotVisibleInQuietGroups

ApproximateAgeOfOldestMessageInQuietGroups
```

among related quiet-group metrics. ([AWS Documentation][15])

That lets a SaaS operator distinguish:

```text
whole queue overloaded
```

from:

```text
one tenant is noisy,
quiet tenants still healthy.
```

---

# PART H — MESSAGE SIZE

# 42. Important Current Limit

Older AWS courses frequently say:

```text
SQS message max
=
256 KB
```

That is outdated.

The current maximum SQS message size is:

```text
1,048,576 bytes
=
1 MiB
```

and minimum is 1 byte. ([AWS Documentation][2])

---

# 43. Still Don't Put Huge Files into SQS

Bad:

```text
SQS message:
900 KB video blob
```

Better:

```text
S3
 │
 │ object
 ▼
video.mp4


SQS message:
{
  "bucket": "...",
  "key": "video.mp4"
}
```

Think:

```text
SQS
=
message/control plane

S3
=
large object/data plane
```

---

# 44. Large Payload Pattern

For very large payloads:

```text
Producer
   │
   ├── upload payload → S3
   │
   └── send pointer → SQS
```

AWS's SQS extended client libraries support an S3-backed message-pointer pattern for payloads larger than 1 MiB, up to 2 GB in the documented library model. ([AWS Documentation][2])

---

# PART I — IN-FLIGHT MESSAGES

# 45. What Does “In Flight” Mean?

A message becomes:

```text
IN FLIGHT
```

when:

```text
consumer has received it
```

but:

```text
consumer has not deleted it
```

and visibility timeout is still active.

---

# 46. Standard Queue In-Flight Limit

For most standard queues, AWS documents approximately:

```text
120,000
```

in-flight messages, depending on queue traffic and backlog. ([AWS Documentation][16])

If you hit this limit:

### Short polling

can return:

```text
OverLimit
```

### Long polling

may simply stop returning new messages until in-flight volume decreases. ([AWS Documentation][16])

---

# 47. Why In-Flight Messages Grow

Common causes:

```text
consumers too slow

visibility timeout huge

consumer crashes

DeleteMessage not executed

downstream system hanging

too much concurrency with long processing
```

Monitor:

```text
ApproximateNumberOfMessagesNotVisible
```

to understand approximate in-flight volume. ([AWS Documentation][15])

---

# PART J — DEAD-LETTER QUEUES

# 48. Poison Message

Suppose:

```json
{
  "orderId": null,
  "schema": "broken"
}
```

Worker:

```text
receive
fail

receive
fail

receive
fail

receive
fail
```

Without isolation it wastes compute forever until retention expires.

Solution:

# Dead-Letter Queue — DLQ

---

# 49. Source Queue → DLQ

```text
Source Queue
     │
     ▼
Receive attempt 1
     X
     ▼
Receive attempt 2
     X
     ▼
Receive attempt 3
     X
     ▼
maxReceiveCount exceeded
     │
     ▼
     DLQ
```

The source queue's:

```text
RedrivePolicy
```

defines:

```text
deadLetterTargetArn

maxReceiveCount
```

([AWS Documentation][17])

---

# 50. Queue Types Must Match

Current requirement:

```text
Standard source
→ Standard DLQ


FIFO source
→ FIFO DLQ
```

([AWS Documentation][18])

---

# 51. Do Not Set `maxReceiveCount=1` Casually

If:

```text
maxReceiveCount = 1
```

one transient failure can send a healthy message immediately into the DLQ.

AWS recommends allowing enough receive attempts to tolerate temporary processing failures. ([AWS Documentation][17])

Example:

```text
maxReceiveCount = 5
```

may be more reasonable, depending on the application's retry model.

---

# 52. DLQ Retention

Best practice:

```text
DLQ retention
>
source queue retention
```

because you want enough time to investigate failed messages. ([AWS Documentation][19])

Example:

```text
Source:
4 days

DLQ:
14 days
```

---

# 53. Subtle Standard vs FIFO DLQ Difference

For a **standard** source queue, the original enqueue timestamp is preserved when a message moves to the DLQ, so its remaining retention reflects time already spent in the source queue.

For a **FIFO** source queue, the enqueue timestamp resets when the message moves to the DLQ. ([AWS Documentation][17])

Advanced detail—but extremely useful during DLQ investigations.

---

# 54. Redrive Allow Policy

The DLQ can also control:

```text
WHICH queues
are allowed to use me
as a DLQ.
```

Current choices include:

```text
allow all

allow selected queues

deny all
```

and the `byQueue` mode can specify up to 10 source queue ARNs. ([AWS Documentation][17])

This is:

```text
RedriveAllowPolicy
```

and is different from the source queue's:

```text
RedrivePolicy.
```

---

# 55. Redrive Messages After Fix

A good DLQ workflow:

```text
DLQ
 │
 ▼
investigate
 │
 ▼
fix application/data
 │
 ▼
test
 │
 ▼
redrive
 │
 ▼
source queue
 │
 ▼
normal processing
```

Do **not**:

```text
redrive first
and hope
```

because you'll simply produce:

```text
DLQ
→ source
→ failure
→ DLQ
→ source
→ ...
```

AWS provides DLQ redrive capabilities to move retained failed messages back toward a destination after remediation. ([AWS Documentation][20])

---

# PART K — QUEUE SECURITY

# 56. SQS Has IAM and Resource Policies

Access involves:

```text
IAM identity policy
        │
        +
SQS queue resource policy
```

depending on the architecture.

Example producer role:

```text
sqs:SendMessage
```

Consumer role:

```text
sqs:ReceiveMessage
sqs:DeleteMessage
sqs:GetQueueAttributes
```

For Lambda SQS consumers, AWS explicitly requires those receive/delete/get-attribute permissions in the function's execution role. ([AWS Documentation][4])

---

# 57. Least Privilege

Bad:

```json
{
  "Effect": "Allow",
  "Action": "sqs:*",
  "Resource": "*"
}
```

Better:

```json
{
  "Effect": "Allow",
  "Action": [
    "sqs:SendMessage"
  ],
  "Resource":
    "arn:aws:sqs:ap-south-1:123456789012:orders"
}
```

Producer needs:

```text
SEND
```

not:

```text
purge
delete queue
change policy
receive everything.
```

---

# 58. Queue Policies Matter for Service Integrations

Architecture:

```text
SNS
 │
 ▼
SQS
```

or:

```text
S3
 │
 ▼
SQS
```

often requires an SQS resource policy permitting the producing AWS service while constraining the source resource/account.

When encryption with a customer-managed KMS key is involved, both SQS queue access and KMS key permissions may become relevant. ([AWS Documentation][21])

---

# PART L — ENCRYPTION

# 59. SQS Encryption at Rest

SQS supports server-side encryption using:

```text
SSE-SQS

or

SSE-KMS
```

([AWS Documentation][22])

---

# 60. SSE-SQS

```text
SQS-managed key
```

No KMS key administration required.

Current AWS documentation states that server-side encryption is enabled by default on newly created queues, with the default SQS-managed encryption path unless you configure otherwise. ([AWS Documentation][23])

---

# 61. SSE-KMS

Use:

```text
AWS KMS key
```

when you need more explicit:

```text
key policies

auditability

customer-managed key control

cross-service key permissions
```

SQS uses KMS to protect data keys used to encrypt/decrypt message contents. ([AWS Documentation][24])

This connects directly to our KMS lesson:

```text
SQS
 │
 ▼
KMS
 │
 ▼
data key
 │
 ▼
encrypted message
```

---

# 62. Encrypted Queue Troubleshooting

For:

```text
SQS
 │
 ▼
Lambda
```

using a KMS-encrypted queue, the Lambda execution role may also need:

```text
kms:Decrypt
```

AWS explicitly calls this out for encrypted SQS Lambda triggers. ([AWS Documentation][4])

So:

```text
sqs:ReceiveMessage allowed
```

doesn't guarantee:

```text
encrypted queue consumption works.
```

---

# PART M — CLOUDWATCH

# 63. Four Metrics You Should Know Immediately

Start with:

```text
ApproximateNumberOfMessagesVisible

ApproximateNumberOfMessagesNotVisible

ApproximateNumberOfMessagesDelayed

ApproximateAgeOfOldestMessage
```

SQS publishes these approximate queue-state metrics to CloudWatch. ([AWS Documentation][15])

---

# 64. Visible Messages

```text
ApproximateNumberOfMessagesVisible
```

means:

```text
backlog currently available
for consumers.
```

If steadily rising:

```text
producer rate
>
consumer throughput
```

or consumers may be unhealthy.

---

# 65. Not Visible

```text
ApproximateNumberOfMessagesNotVisible
```

≈

```text
in-flight messages.
```

High value can mean:

```text
lots of active work
```

or:

```text
slow/stuck consumers.
```

Context matters.

---

# 66. Delayed

```text
ApproximateNumberOfMessagesDelayed
```

shows messages intentionally unavailable due to:

```text
queue delay

or
message timer
```

rather than consumer processing. ([AWS Documentation][25])

---

# 67. Age of Oldest Message

This is often your most important queue SLO metric:

```text
ApproximateAgeOfOldestMessage
```

Suppose:

```text
Queue depth
=
1,000,000

oldest
=
3 seconds
```

Maybe healthy high-throughput processing.

But:

```text
Queue depth
=
100

oldest
=
2 hours
```

probably concerning.

### Never forget

```text
BACKLOG SIZE
without
BACKLOG AGE
can mislead you.
```

---

# 68. Good Alarm

For an order-processing queue:

```text
ApproximateAgeOfOldestMessage
>
120 seconds
```

for several periods:

```text
ALARM
```

because your business SLO might say:

```text
orders processed
within 2 minutes.
```

This is more meaningful than:

```text
queue > 1000
```

when traffic varies heavily.

---

# PART N — QUEUEING & BACKPRESSURE

# 69. A Queue Is Not a Problem by Itself

Imagine:

```text
Producer:
10,000 jobs/sec

Consumer:
8,000 jobs/sec
```

Queue growth:

```text
2,000/sec
```

After:

```text
60 sec
```

backlog:

```text
120,000 jobs.
```

SQS is doing exactly what it should:

```text
BUFFERING LOAD.
```

---

# 70. But Infinite Growth Is Unsustainable

If:

```text
arrival rate
>
processing rate
```

for a sustained period:

```text
backlog
    │
    ▼
age
    │
    ▼
SLO breach
```

Eventually retention can become relevant.

A queue buys:

```text
TIME
```

not:

```text
INFINITE CONSUMER CAPACITY.
```

---

# 71. Scale Consumers from Queue Demand

A common worker architecture:

```text
                     SQS

                      │
       CloudWatch queue metrics
                      │
                      ▼
              Auto Scaling Policy
                      │
                      ▼
            ECS / EC2 worker fleet
```

Scaling should consider:

```text
backlog

oldest message age

processing time

desired drain time
```

rather than CPU alone.

---

# 72. Backlog-per-Worker Mental Model

Suppose:

```text
100,000 messages

100 workers
```

Then:

```text
1000 messages / worker.
```

If each worker processes:

```text
10 messages/sec
```

approximate drain time:

```text
100 seconds
```

This gives a much better scaling discussion than:

```text
CPU = 30%.
```

---

# PART O — MULTIPLE CONSUMERS

# 73. Queue Is Work Distribution

Suppose:

```text
SQS
 │
 ├── Worker A
 ├── Worker B
 ├── Worker C
 └── Worker D
```

Consumers compete for available messages.

A message is normally consumed as a:

```text
WORK ITEM
```

rather than broadcast to every worker.

---

# 74. Need Every Subscriber to Receive a Copy?

Then ordinary:

```text
one SQS queue
```

is not fan-out.

Suppose you need:

```text
Order Created
    │
    ├── email
    ├── analytics
    └── inventory
```

Use:

```text
SNS
 │
 ├── SQS Email Queue
 ├── SQS Analytics Queue
 └── SQS Inventory Queue
```

That is:

# Fan-Out

which we'll cover in Lesson 34 Part 2.

---

# PART P — SQS + LAMBDA RECAP

# 75. Architecture

```text
Producer
   │
   ▼
SQS
   │
   ▼
Lambda Event Source Mapping
   │
   │ polls
   ▼
Batch
   │
   ▼
Lambda
   │
 ┌─┴────────────┐
 ▼              ▼
success       failure
 │              │
 ▼              ▼
delete       visibility
messages      expires
                │
                ▼
              retry
                │
                ▼
               DLQ
```

Lambda polls SQS and invokes the function synchronously with batches. ([AWS Documentation][4])

---

# 76. Lambda IAM

Execution role needs at least operations such as:

```text
sqs:ReceiveMessage

sqs:DeleteMessage

sqs:GetQueueAttributes
```

and:

```text
kms:Decrypt
```

when required for applicable encrypted queues. ([AWS Documentation][4])

---

# 77. Same Region Requirement

For the direct SQS Lambda trigger architecture:

```text
SQS queue
and
Lambda function
```

must be in the same AWS Region. ([AWS Documentation][4])

For us:

```text
SQS:
ap-south-1

Lambda:
ap-south-1
```

---

# PART Q — CLI LAB

# 78. Create Queue

```bash
export AWS_REGION=ap-south-1

aws sqs create-queue \
  --queue-name todo-jobs \
  --attributes \
    VisibilityTimeout=60,\
MessageRetentionPeriod=345600,\
ReceiveMessageWaitTimeSeconds=20 \
  --region "$AWS_REGION"
```

This configures:

```text
visibility:
60 sec

retention:
4 days

long polling:
20 sec
```

within the current SQS ranges. ([AWS Documentation][6])

---

# 79. Get Queue URL

```bash
QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name todo-jobs \
  --region "$AWS_REGION" \
  --query QueueUrl \
  --output text)

echo "$QUEUE_URL"
```

---

# 80. Send Message

```bash
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body \
  '{"jobId":"JOB-001","action":"send-email"}' \
  --region "$AWS_REGION"
```

---

# 81. Receive with Long Poll

```bash
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --wait-time-seconds 20 \
  --max-number-of-messages 10 \
  --attribute-names All \
  --message-attribute-names All \
  --region "$AWS_REGION"
```

---

# 82. Receipt Handle

The response includes something like:

```text
MessageId

ReceiptHandle

Body
```

The important delete token is:

```text
ReceiptHandle.
```

Delete:

```bash
aws sqs delete-message \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE" \
  --region "$AWS_REGION"
```

The consumer should delete only **after successful processing**.

---

# 83. Change Visibility

Long-running processing:

```bash
aws sqs change-message-visibility \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE" \
  --visibility-timeout 300 \
  --region "$AWS_REGION"
```

Now that in-flight message receives additional processing time subject to SQS's total 12-hour visibility limit. ([AWS Documentation][3])

---

# PART R — FIFO LAB

# 84. Create FIFO Queue

```bash
aws sqs create-queue \
  --queue-name orders.fifo \
  --attributes \
    FifoQueue=true,\
ContentBasedDeduplication=true \
  --region "$AWS_REGION"
```

---

# 85. Send Ordered Messages

```bash
aws sqs send-message \
  --queue-url "$FIFO_URL" \
  --message-group-id customer-101 \
  --message-body '{"sequence":1}' \
  --region "$AWS_REGION"
```

Then:

```bash
aws sqs send-message \
  --queue-url "$FIFO_URL" \
  --message-group-id customer-101 \
  --message-body '{"sequence":2}' \
  --region "$AWS_REGION"
```

Those messages belong to the same ordered group.

---

# 86. Better Parallelism

```text
customer-101
customer-102
customer-103
```

instead of:

```text
all-customers
```

because different FIFO message groups can progress in parallel while preserving ordering inside each group. ([AWS Documentation][11])

---

# PART S — TERRAFORM

# 87. Standard Queue

```hcl
resource "aws_sqs_queue" "jobs" {
  name = "todo-jobs"

  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600

  receive_wait_time_seconds = 20

  sqs_managed_sse_enabled = true

  tags = {
    Environment = "production"
    Application = "todo"
    ManagedBy   = "terraform"
  }
}
```

Mental model:

```text
Terraform
   │
   ▼
consistent queue settings
   │
   ▼
no mystery console configuration
```

---

# 88. DLQ

```hcl
resource "aws_sqs_queue" "jobs_dlq" {
  name = "todo-jobs-dlq"

  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true
}
```

Here:

```text
14-day DLQ retention
```

gives more investigation time than the four-day source retention, following AWS's DLQ guidance. ([AWS Documentation][17])

---

# 89. Redrive Policy

```hcl
resource "aws_sqs_queue" "jobs" {
  name = "todo-jobs"

  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = 5
  })
}
```

---

# PART T — PRODUCTION TROUBLESHOOTING

# 90. “Messages Keep Reappearing”

Check:

```text
consumer successfully calling DeleteMessage?

visibility timeout too short?

consumer crashing?

processing taking too long?

wrong receipt handle?

Lambda batch failing?
```

Remember:

```text
Receive
≠
Delete.
```

---

# 91. “Queue Depth Keeps Growing”

Ask:

```text
Are producers sending faster?

Are consumers alive?

Did processing duration increase?

Downstream database slow?

Consumer scaling capped?

IAM errors?

Messages poisonous?

Is oldest message age rising?
```

Do not immediately:

```text
add 1000 consumers.
```

The downstream system may not survive it.

---

# 92. “ReceiveMessage Returns Nothing”

Possible causes:

```text
queue genuinely empty

message delayed

messages currently invisible

in-flight quota reached

short-poll false-empty behavior

wrong queue/Region

permissions
```

Long polling reduces false empty responses. ([AWS Documentation][8])

---

# 93. “Lambda Doesn't Poll Encrypted Queue”

Check:

```text
sqs:ReceiveMessage

sqs:DeleteMessage

sqs:GetQueueAttributes

kms:Decrypt
```

plus queue/key policies. AWS explicitly identifies `kms:Decrypt` as required where applicable. ([AWS Documentation][4])

---

# 94. “DLQ Fills Immediately”

Check:

```text
maxReceiveCount too low?

consumer code broken?

schema changed?

dependency unavailable?

visibility timeout wrong?

IAM/KMS failures?
```

A DLQ growing is:

```text
SYMPTOM
```

not:

```text
ROOT CAUSE.
```

---

# 95. “FIFO Throughput Is Terrible”

Check:

```text
Only one MessageGroupId?

Batch APIs used?

High-throughput FIFO enabled?

Processing time too high?

Lambda concurrency constrained?

Message groups badly distributed?
```

FIFO throughput depends heavily on distributing work across message groups. ([AWS Documentation][2])

---

# 96. “One SaaS Customer Makes Everyone Slow”

If you intentionally share a standard queue among tenants, consider:

```text
SQS Fair Queues
```

and use a meaningful tenant ID as:

```text
MessageGroupId
```

for each producer message. ([AWS Documentation][14])

---

# PART U — CERTIFICATION / INTERVIEW SCENARIOS

# 97. Scenario

> Need very high throughput; ordering doesn't matter.

Think:

```text
SQS Standard Queue
```

because standard queues provide very high throughput with at-least-once and best-effort ordering semantics. ([AWS Documentation][10])

---

# 98. Scenario

> Banking account commands must remain ordered per account.

Think:

```text
SQS FIFO

MessageGroupId
=
accountId
```

not one global group for every account.

---

# 99. Scenario

> Consumer crashes before deleting message.

Expected:

```text
visibility timeout expires

message becomes visible

another consumer can retry.
```

([AWS Documentation][13])

---

# 100. Scenario

> Consumer takes variable amounts of time, possibly hours.

Think:

```text
ChangeMessageVisibility heartbeat
```

subject to the 12-hour total visibility limit. ([AWS Documentation][3])

For work exceeding that model regularly, reassess whether SQS's single-message processing semantics are the right abstraction.

---

# 101. Scenario

> Need message available exactly 3 days later.

Not SQS delay.

Use:

```text
EventBridge Scheduler
```

because SQS delay/timers max out at 15 minutes. ([AWS Documentation][7])

---

# 102. Scenario

> One bad message repeatedly fails.

Think:

```text
DLQ

redrive policy

maxReceiveCount
```

([AWS Documentation][17])

---

# 103. Scenario

> Lambda processes SQS queue. Function timeout = 60 sec.

AWS recommended starting rule:

```text
SQS visibility
≥
6 × 60
=
360 sec
```

([AWS Documentation][4])

---

# 104. Scenario

> Need every one of four downstream systems to receive an OrderCreated event.

One SQS queue is not enough.

Think:

```text
SNS
     │
 ┌───┼────┬────┐
 ▼   ▼    ▼    ▼
SQS SQS  SQS  SQS
```

That is our next lesson.

---

# 105. Scenario

> Multi-tenant Standard queue. Tenant A floods the queue and hurts everyone else's latency.

Modern answer:

```text
SQS Fair Queues
+
MessageGroupId=tenantId
```

without changing to FIFO purely for fairness. ([AWS Documentation][14])

---

# 106. Scenario

> Old design says SQS max payload is 256 KB.

Current answer:

```text
maximum SQS message size
=
1 MiB.
```

([AWS Documentation][2])

This is another current AWS fact older certification notes may miss.

---

# 107. The Permanent Queue Selection Model

```text
                    NEED ASYNC BUFFER
                           │
                           ▼
                          SQS
                           │
               Does strict ordering matter?
                       │          │
                      NO         YES
                       │          │
                       ▼          ▼
                  STANDARD      FIFO
                       │          │
                       │       MessageGroupId
                       │          │
                       ▼          ▼
               Need multi-tenant
                 fairness?
                    │
                   YES
                    │
                    ▼
              MessageGroupId
              on STANDARD
                    │
                    ▼
                Fair Queue
```

---

# 108. The Permanent Message Lifecycle

```text
                    PRODUCER

                       │
                       ▼
                   SendMessage
                       │
                       ▼
                     SQS
                       │
                  message visible
                       │
                       ▼
                 ReceiveMessage
                       │
                       ▼
                  IN FLIGHT
             visibility timeout
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
       SUCCESS                    FAILURE
          │                         │
          ▼                         ▼
    DeleteMessage          visibility expires
          │                         │
          ▼                         ▼
        GONE                    RETRY
                                    │
                       receive count increases
                                    │
                         ┌──────────┴──────────┐
                         ▼                     ▼
                      success           maxReceiveCount
                         │                     │
                         ▼                     ▼
                       delete                 DLQ
```

If you truly understand that picture:

```text
you understand
most of SQS.
```

---

# 109. 35 Rules to Burn Into Memory

```text
1. SQS decouples producers and consumers.

2. Producer sends; consumer receives and deletes.

3. ReceiveMessage does not delete the message.

4. Received messages become temporarily invisible.

5. Default visibility timeout is 30 seconds.

6. Visibility timeout can be up to 12 hours.

7. Too-short visibility creates duplicate processing risk.

8. Too-long visibility delays failure recovery.

9. ChangeMessageVisibility supports heartbeat patterns.

10. Lambda/SQS guidance recommends visibility
    at least 6× function timeout.

11. Default message retention is 4 days.

12. Maximum retention is 14 days.

13. Delay occurs before first delivery.

14. Visibility occurs after receive.

15. SQS delay/timers max at 15 minutes.

16. Use EventBridge Scheduler for longer scheduling.

17. Long polling can wait up to 20 seconds.

18. Long polling usually reduces empty receives.

19. Standard queue = very high throughput.

20. Standard delivery = at least once.

21. Standard ordering = best effort.

22. Standard consumers must be idempotent.

23. FIFO preserves ordering within message groups.

24. MessageGroupId defines FIFO ordering boundaries.

25. More message groups allow more parallelism.

26. FIFO deduplication window is 5 minutes.

27. FIFO does not remove the need for
    idempotent business side effects.

28. Current SQS message max is 1 MiB.

29. Use S3 pointers for genuinely large payloads.

30. Poison messages belong in a DLQ.

31. DLQ retention should generally exceed source retention.

32. Monitor oldest message age, not queue size alone.

33. Queue backlog is controlled backpressure.

34. Standard queues now support Fair Queues
    using MessageGroupId for tenant fairness.

35. MessageGroupId on Standard Fair Queue
    does NOT imply FIFO ordering.
```

---

# ✅ Lesson 34 Part 1 Complete — Amazon SQS

You now understand:

```text
✓ messaging mental model
✓ producer / consumer decoupling
✓ send / receive / delete
✓ receipt handles

✓ visibility timeout
✓ processing retries
✓ heartbeat extensions
✓ 12-hour limit
✓ Lambda 6× timeout guideline

✓ message retention
✓ 1 minute–14 days
✓ default 4 days

✓ delay queues
✓ message timers
✓ delay vs visibility
✓ EventBridge Scheduler distinction

✓ short polling
✓ long polling
✓ 20-second maximum
✓ false-empty responses

✓ Standard SQS
✓ at-least-once delivery
✓ best-effort ordering
✓ idempotency

✓ FIFO
✓ strict group ordering
✓ MessageGroupId
✓ MessageDeduplicationId
✓ 5-minute dedup window
✓ exact-once nuance
✓ parallel ordered groups

✓ high-throughput FIFO
✓ ap-south-1 throughput model
✓ batching

✓ SQS Fair Queues
✓ multi-tenant noisy-neighbor protection
✓ Standard Queue MessageGroupId semantics
✓ quiet-group CloudWatch metrics

✓ 1-MiB messages
✓ S3 pointer architecture
✓ extended payload pattern

✓ in-flight messages
✓ standard ~120k in-flight quota

✓ DLQs
✓ redrive policies
✓ maxReceiveCount
✓ redrive allow policy
✓ DLQ retention
✓ standard vs FIFO DLQ timestamp behavior

✓ IAM
✓ queue policies
✓ SSE-SQS
✓ SSE-KMS
✓ KMS troubleshooting

✓ CloudWatch metrics
✓ visible
✓ not visible
✓ delayed
✓ oldest message age

✓ backpressure
✓ queue-driven scaling
✓ CLI labs
✓ Terraform architecture
✓ production troubleshooting
✓ certification scenarios
```

# Next — Lesson 34 Part 2

# **Amazon SNS in Depth — Pub/Sub, Fan-Out, Filtering, FIFO Topics, DLQs & Multi-Channel Notifications**

Now we'll solve the limitation of one queue:

```text
OrderCreated
     │
     ▼
Who receives it?
```

With one SQS queue:

```text
Email Worker   \
Inventory Worker ─► compete for ONE message
Analytics Worker /
```

but what we actually want is:

```text
                    OrderCreated
                         │
                         ▼
                        SNS
                         │
       ┌─────────────────┼─────────────────┐
       ▼                 ▼                 ▼
     SQS Email        SQS Inventory    SQS Analytics
       │                 │                 │
       ▼                 ▼                 ▼
     Worker            Worker            Worker
```

We'll cover **publish/subscribe, topics, subscriptions, push vs pull, SNS Standard vs FIFO topics, SNS→SQS fan-out, subscription filter policies, message-body filtering, raw message delivery, HTTP/S endpoints, Lambda subscriptions, email/SMS/mobile push, retry policies, subscription DLQs, KMS encryption, cross-account subscriptions, FIFO deduplication/message groups, high-throughput SNS FIFO, SNS vs SQS decision rules, EventBridge comparison, Terraform, and a production OrderCreated fan-out architecture.**

[1]: https://docs.aws.amazon.com/sqs/?utm_source=chatgpt.com "Amazon Simple Queue Service Documentation"
[2]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html "Amazon SQS message quotas - Amazon Simple Queue Service"
[3]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/best-practices-processing-messages-timely-manner.html?utm_source=chatgpt.com "Processing messages in a timely manner in Amazon SQS"
[4]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-lambda-function-trigger.html "Configuring an Amazon SQS queue to trigger an AWS Lambda function - Amazon Simple Queue Service"
[5]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-delay-queues.html?utm_source=chatgpt.com "Amazon SQS delay queues - Amazon Simple Queue Service"
[6]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-queue-parameters.html?utm_source=chatgpt.com "Configuring queue parameters using the Amazon SQS console"
[7]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-message-timers.html?utm_source=chatgpt.com "Amazon SQS message timers"
[8]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-short-and-long-polling.html?utm_source=chatgpt.com "Amazon SQS short and long polling"
[9]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/best-practices-setting-up-long-polling.html?utm_source=chatgpt.com "Setting-up long polling in Amazon SQS"
[10]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html "Amazon SQS queue types - Amazon Simple Queue Service"
[11]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fifo-queues.html "Amazon SQS FIFO queues - Amazon Simple Queue Service"
[12]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html?utm_source=chatgpt.com "Exactly-once processing in Amazon SQS"
[13]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html?utm_source=chatgpt.com "Amazon SQS visibility timeout"
[14]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fair-queues.html?utm_source=chatgpt.com "Amazon SQS fair queues - Amazon Simple Queue Service"
[15]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-available-cloudwatch-metrics.html?utm_source=chatgpt.com "Available CloudWatch metrics for Amazon SQS"
[16]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-queues.html?utm_source=chatgpt.com "Amazon SQS standard queue quotas"
[17]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html?utm_source=chatgpt.com "Using dead-letter queues in Amazon SQS"
[18]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-dead-letter-queue.html?utm_source=chatgpt.com "Configure a dead-letter queue using the Amazon SQS console"
[19]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/setting-up-dead-letter-queue-retention.html?utm_source=chatgpt.com "Setting-up dead-letter queue retention in Amazon SQS"
[20]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-dead-letter-queue-redrive.html?utm_source=chatgpt.com "Learn how to configure a dead-letter queue redrive in Amazon ..."
[21]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-least-privilege-policy.html?utm_source=chatgpt.com "Access management for encrypted Amazon SQS queues ..."
[22]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-server-side-encryption.html?utm_source=chatgpt.com "Encryption at rest in Amazon SQS"
[23]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-sqs-sse-queue.html?utm_source=chatgpt.com "Configuring server-side encryption for a queue using SQS ..."
[24]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-key-management.html?utm_source=chatgpt.com "Amazon SQS Key management"
[25]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/troubleshooting-messages-not-returned-ReceiveMessage.html?utm_source=chatgpt.com "Troubleshoot messages not returned for an Amazon SQS ..."
