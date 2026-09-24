# AWS Masterclass — Lesson 34 Part 2

# Amazon SNS in Depth

## Pub/Sub, Fan-Out, Filtering, Standard vs FIFO Topics, Retry Policies, DLQs, Encryption, Cross-Account Messaging & Production Design

In Part 1, SQS gave us:

```text
Producer
   │
   ▼
Queue
   │
   ▼
ONE consumer/work group
```

Consumers compete for messages.

But imagine:

```text
OrderCreated
```

must trigger:

```text
Email

Inventory

Analytics

Fraud detection

CRM

Billing
```

Putting all six workers on one queue does **not** broadcast the event to all six.

They compete for it.

What we need is:

# Publish / Subscribe

```text
                          OrderCreated
                               │
                               ▼
                              SNS
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
         Email Queue     Inventory Queue   Analytics Queue
              │                │                │
              ▼                ▼                ▼
           Worker           Worker           Worker
```

Amazon SNS is a fully managed publish/subscribe messaging service. Publishers publish to a **topic**, and SNS distributes messages to subscribed endpoints such as SQS queues, Lambda, HTTP/S endpoints, email, SMS, mobile push, and Firehose, depending on topic type and protocol support. ([AWS Documentation][1])

---

# 1. The Core Difference: SQS vs SNS

The shortest mental model:

```text
SQS
=
QUEUE


SNS
=
TOPIC
```

More precisely:

```text
SQS
=
store message until
a consumer pulls it


SNS
=
publish message
to subscribers
```

---

# 2. Work Queue vs Pub/Sub

Imagine:

```text
JOB:
resize-image-001
```

Only one worker should normally perform that job.

Use:

```text
SQS
```

But:

```text
EVENT:
OrderCreated
```

needs to be observed independently by:

```text
Inventory
Email
Analytics
Fraud
```

Use:

```text
SNS
```

or another event-routing system such as EventBridge, depending on routing requirements.

---

# 3. SNS Architecture

```text
                 PUBLISHERS

          Order Service
          Billing Service
          Admin Service
                │
                ▼
             SNS Topic
                │
         ┌──────┼─────────────┐
         ▼      ▼             ▼
        SQS   Lambda        HTTPS
         │      │             │
         ▼      ▼             ▼
      Worker  Function     External API
```

The producer doesn't need to know every consumer.

It knows only:

```text
Publish to topic ARN.
```

That creates:

# Loose Coupling

---

# 4. Topic

A:

# Topic

is the logical channel publishers send notifications to.

Example:

```text
arn:aws:sns:ap-south-1:123456789012:order-events
```

Publisher:

```text
Publish(OrderCreated)
          │
          ▼
      order-events
```

SNS then attempts delivery to each matching subscription. ([AWS Documentation][2])

---

# 5. Subscription

A:

# Subscription

connects:

```text
SNS Topic
    │
    ▼
Endpoint
```

Example:

```text
order-events
    │
    ├── SQS email-orders
    ├── SQS inventory-orders
    ├── Lambda audit-handler
    └── HTTPS webhook
```

Subscriptions are independent.

Failure of one subscriber does not mean all other subscribers must fail.

---

# 6. Fan-Out

This architecture is called:

# Fan-Out

```text
                   One message
                       │
                       ▼
                      SNS
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
         Copy         Copy         Copy
          │            │            │
          ▼            ▼            ▼
        Queue A      Queue B      Queue C
```

SNS → multiple SQS queues is one of the canonical AWS fan-out patterns. ([AWS Documentation][3])

---

# 7. Why SNS + SQS Together Is So Powerful

You may ask:

> If SNS can deliver directly to Lambda, why put SQS between them?

Because:

```text
SNS
=
fan-out / publication


SQS
=
durable independent buffer
```

Together:

```text
Producer
   │
   ▼
SNS
   │
   ├─────────┬───────────┐
   ▼         ▼           ▼
 SQS A     SQS B       SQS C
   │         │           │
   ▼         ▼           ▼
Worker A  Worker B    Worker C
```

Now each subscriber gets:

```text
its own backlog

its own retry behavior

its own DLQ

its own scaling rate

its own maintenance window

its own failure isolation
```

---

# 8. Failure Isolation Example

Suppose Analytics is down for 30 minutes.

Without queues:

```text
SNS
 ├── Email       ✓
 ├── Inventory   ✓
 └── Analytics   X
```

Recovery depends heavily on SNS endpoint-delivery retry semantics.

With SQS buffering:

```text
SNS
 ├── Email Queue      → processing
 ├── Inventory Queue  → processing
 └── Analytics Queue  → backlog
                          │
                          ▼
                    analytics returns
                          │
                          ▼
                    backlog drained
```

That is often a much more resilient A2A architecture.

---

# PART A — SNS STANDARD TOPICS

# 9. Two Topic Types

SNS supports:

```text
Standard Topic

FIFO Topic
```

You choose the type when creating the topic, and AWS says you cannot later convert the topic from one type to the other. ([AWS Documentation][4])

---

# 10. Standard Topic

Think:

```text
high-scale
general-purpose
pub/sub
```

Standard topics are appropriate when:

```text
strict ordering
is not required

possible duplicate delivery
is tolerable

wide protocol support
is desired
```

Standard topics support the broadest set of SNS subscription protocols. ([AWS Documentation][5])

---

# 11. Standard Topic Subscriber Types

Standard topics can deliver to endpoints such as:

```text
Amazon SQS

Lambda

HTTP

HTTPS

Email

Email-JSON

SMS

mobile push

Firehose
```

depending on use case/protocol. ([AWS Documentation][1])

---

# 12. Standard Topic Use Cases

Examples:

```text
application events

notifications

monitoring alerts

fan-out

webhooks

email/SMS notifications

microservice events
```

Example:

```text
EC2 alarm
    │
    ▼
CloudWatch Alarm
    │
    ▼
SNS
    │
    ├── email on-call
    └── incident automation
```

---

# PART B — SNS FIFO TOPICS

# 13. Why FIFO Topics Exist

Suppose price updates are:

```text
₹100
₹110
₹90
```

and consumers receive:

```text
₹90
₹100
₹110
```

Final state becomes wrong.

You need:

```text
strict ordering
+
deduplication
```

SNS FIFO topics are designed for ordered publish/subscribe workflows when combined appropriately with FIFO queue subscribers. ([AWS Documentation][6])

---

# 14. FIFO Topic Naming

FIFO topic names end with:

```text
.fifo
```

Example:

```text
order-events.fifo
```

and must be created explicitly as FIFO topics. ([AWS Documentation][7])

---

# 15. MessageGroupId

Every message published to an SNS FIFO topic requires:

```text
MessageGroupId
```

A group defines an independent ordering stream.

Example:

```text
MessageGroupId=customer-101

OrderCreated
PaymentAuthorized
OrderShipped
```

These messages remain ordered within that group. ([AWS Documentation][2])

---

# 16. Multiple Message Groups

```text
FIFO Topic

customer-A
 A1 → A2 → A3

customer-B
 B1 → B2 → B3

customer-C
 C1 → C2
```

Ordering exists:

```text
WITHIN each group
```

not globally across unrelated groups.

SNS can process different groups in parallel while preserving order inside a group. ([AWS Documentation][8])

---

# 17. One Group = Throughput Bottleneck

If every event uses:

```text
MessageGroupId=all-orders
```

you create one ordered lane.

AWS currently documents a maximum of:

```text
300 messages/sec
per individual SNS FIFO message group
```

so high-throughput FIFO designs need many well-distributed group IDs. ([AWS Documentation][8])

---

# 18. Good Group IDs

Possible keys:

```text
customerId

accountId

orderId

deviceId

productId
```

depending on:

> What must remain ordered relative to what?

Example:

```text
price changes
```

might use:

```text
productId
```

so each product's price sequence remains ordered without serializing all products.

---

# 19. MessageDeduplicationId

FIFO topics also use:

```text
MessageDeduplicationId
```

When the same deduplication ID is successfully published again within the current:

```text
5-minute deduplication interval
```

SNS accepts the request semantics but suppresses duplicate delivery according to its FIFO deduplication rules. ([AWS Documentation][9])

---

# 20. Content-Based Deduplication

Instead of supplying a deduplication ID manually:

```text
ContentBasedDeduplication=true
```

can make SNS compute a SHA-256 hash based on the message body.

Important:

```text
message attributes
are NOT included
in that hash.
```

([AWS Documentation][9])

---

# 21. Important Deduplication Trap

Suppose these events have identical bodies:

```json
{
  "price": 100
}
```

but different attributes:

```text
business=retail
```

and:

```text
business=wholesale
```

Content-based deduplication sees the same body hash.

The attribute differences do not affect the generated deduplication hash. ([AWS Documentation][9])

So sometimes explicit business-event IDs are safer.

---

# 22. FifoThroughputScope

Modern SNS FIFO topics expose:

```text
FifoThroughputScope
```

with important values including:

```text
Topic

MessageGroup
```

The choice controls both throughput behavior and deduplication scope. ([AWS Documentation][9])

---

# 23. Default FIFO Scope

Current default:

```text
FifoThroughputScope=Topic
```

has a per-topic throughput ceiling currently documented as:

```text
3,000 messages/sec
or
20 MB/sec

whichever comes first
```

for that mode. ([AWS Documentation][10])

---

# 24. High-Throughput FIFO Topics

For higher throughput:

```text
FifoThroughputScope=MessageGroup
```

enables the high-throughput FIFO design.

SNS distributes traffic across partitions based on message groups, so using many distinct group IDs is essential to achieving high aggregate throughput. ([AWS Documentation][11])

---

# 25. Permanent FIFO Rule

```text
ORDERING
+
THROUGHPUT
```

comes from good partitioning.

Bad:

```text
MessageGroupId=GLOBAL
```

Better:

```text
MessageGroupId=customerId
```

if each customer's events only need ordering relative to that customer.

---

# PART C — FIFO SUBSCRIBERS

# 26. Important 2026 FIFO Limitation

Do **not** assume an SNS FIFO topic can directly publish to every protocol available to Standard topics.

SNS FIFO topics cannot directly deliver to customer-managed endpoints such as:

```text
email

SMS

mobile apps

HTTP/S
```

because those endpoints cannot preserve the FIFO guarantees SNS needs. ([AWS Documentation][12])

---

# 27. Lambda + FIFO Topic Trap

Lambda SNS triggers currently support:

```text
STANDARD SNS TOPICS
```

only.

You cannot directly attach Lambda as an SNS FIFO trigger. ([AWS Documentation][13])

---

# 28. FIFO Topic → Lambda Pattern

Use:

```text
SNS FIFO
    │
    ▼
SQS FIFO
    │
    ▼
Lambda
```

That preserves the queueing/ordering model while Lambda consumes through its SQS event source mapping. AWS explicitly describes using SQS between an SNS FIFO topic and Lambda. ([AWS Documentation][12])

---

# 29. FIFO Topic Can Also Deliver to Standard SQS

A useful modern feature:

```text
SNS FIFO Topic
     │
     ├── SQS FIFO
     ├── SQS FIFO
     └── SQS Standard
```

AWS explicitly supports both FIFO and Standard SQS subscriptions to FIFO topics. ([AWS Documentation][12])

---

# 30. Why Subscribe Standard SQS to FIFO SNS?

Suppose:

```text
Retail app
needs strict ordering
```

but:

```text
Analytics
doesn't care about order
```

Architecture:

```text
                SNS FIFO
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   SQS FIFO    SQS FIFO   SQS Standard
   retail      wholesale    analytics
```

The FIFO queues preserve strict order; the Standard queue gives analytics cheaper/general best-effort consumption semantics. ([AWS Documentation][12])

---

# PART D — SNS MESSAGE FILTERING

# 31. Fan-Out Can Become Wasteful

Imagine one topic:

```text
order-events
```

contains:

```text
OrderCreated

OrderCancelled

PaymentFailed

OrderShipped

RefundIssued
```

and every subscriber receives every event.

Email worker:

```text
receive everything
discard 80%
```

Analytics:

```text
receive everything
```

Refund worker:

```text
receive everything
discard 95%
```

Wasteful.

---

# 32. Subscription Filter Policy

SNS supports:

# Subscription Filter Policies

A filter tells SNS:

```text
Only deliver messages
matching this subscription.
```

Subscriptions without a filter receive all topic messages; filtered subscriptions only receive events matching their policy. ([AWS Documentation][14])

---

# 33. Example

Publisher sends:

```json
{
  "eventType": "OrderCreated",
  "region": "IN",
  "amount": 2500
}
```

Subscriptions:

```text
Inventory:
eventType=OrderCreated


Refund Worker:
eventType=RefundIssued


Premium Analytics:
amount > 10000
```

SNS routes accordingly.

---

# 34. Two Filtering Scopes

SNS supports:

```text
MessageAttributes
```

and:

```text
MessageBody
```

through:

```text
FilterPolicyScope
```

The default is:

```text
MessageAttributes
```

while `MessageBody` allows payload-based filtering on a valid JSON message body. ([AWS Documentation][15])

---

# 35. Attribute-Based Filtering

Publish:

```bash
aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message '{"orderId":"ORD-101"}' \
  --message-attributes \
    '{"eventType":{"DataType":"String","StringValue":"OrderCreated"}}'
```

Filter:

```json
{
  "eventType": [
    "OrderCreated"
  ]
}
```

Now only matching subscriptions receive it.

---

# 36. Payload-Based Filtering

Message:

```json
{
  "eventType": "OrderCreated",
  "customer": {
    "tier": "premium"
  }
}
```

Subscription:

```text
FilterPolicyScope=MessageBody
```

can evaluate values within the JSON message body, including nested structures under the payload-filtering model. ([AWS Documentation][16])

---

# 37. Supported Filter Logic

SNS filter policies currently support rich matching concepts including:

```text
AND

OR

exact string matching

prefix/suffix-style conditions

anything-but

numeric comparisons

exists / key matching
```

depending on filter type and structure. ([AWS Documentation][17])

---

# 38. Numeric Filter Example

Conceptually:

```json
{
  "amount": [
    {
      "numeric": [
        ">=",
        10000
      ]
    }
  ]
}
```

Now:

```text
amount=500
→ ignored


amount=15000
→ delivered
```

This allows routing without writing a Lambda merely to inspect every message.

---

# 39. Filters Are Per Subscription

This is very important.

```text
SNS Topic
   │
   ├── Subscription A
   │     Filter A
   │
   ├── Subscription B
   │     Filter B
   │
   └── Subscription C
         no filter
```

One published event can therefore be:

```text
delivered to A

not delivered to B

delivered to C
```

independently.

---

# 40. FIFO Topics Also Support Filters

SNS FIFO topics support subscription filtering for SQS subscribers, using either attributes or message-body filtering depending on filter scope. ([AWS Documentation][18])

However, filtering changes the strict end-to-end delivery assumptions—you should not interpret a deliberately filtered-out FIFO message as a delivery failure. AWS notes filtering can result in an at-most-once semantic for that subscriber because nonmatching events are intentionally not delivered. ([AWS Documentation][9])

---

# PART E — RAW MESSAGE DELIVERY

# 41. Default SNS→SQS Message Shape

By default SNS doesn't place only your raw body in SQS.

It wraps the publication in SNS metadata.

Example conceptually:

```json
{
  "Type": "Notification",
  "MessageId": "...",
  "TopicArn": "...",
  "Message": "{\"orderId\":\"ORD-1\"}",
  "Timestamp": "...",
  "Signature": "..."
}
```

AWS documents this SNS envelope for SQS fan-out. ([AWS Documentation][3])

---

# 42. Consumer Then Has to Decode Twice

Your queue consumer may need:

```text
parse SQS body
      │
      ▼
extract Message field
      │
      ▼
parse application JSON
```

Sometimes that metadata is useful.

Sometimes it is annoying.

---

# 43. Raw Message Delivery

Enable:

```text
RawMessageDelivery=true
```

and SNS sends the application message directly to supported endpoints such as SQS or HTTP/S instead of wrapping it with the normal SNS JSON metadata envelope. ([AWS Documentation][19])

Then SQS body may simply be:

```json
{
  "orderId": "ORD-1"
}
```

---

# 44. Raw Delivery Tradeoff

Without raw delivery:

```text
more SNS metadata
```

With raw delivery:

```text
simpler consumer body
```

But you lose normal SNS wrapper metadata such as the topic's metadata envelope; FIFO-specific sequence metadata can also disappear when raw delivery is enabled. ([AWS Documentation][20])

Use deliberately.

---

# PART F — SNS RETRY BEHAVIOR

# 45. Delivery Can Fail

```text
SNS
 │
 ▼
Subscriber
 X
```

Reasons:

```text
endpoint unavailable

network error

throttling

authorization issue

invalid endpoint

server error
```

SNS uses delivery policies to determine how it retries message delivery, and once the applicable retry policy is exhausted the message is discarded unless that subscription has a DLQ configured. ([AWS Documentation][21])

---

# 46. Retry Behavior Depends on Protocol

Do **not** memorize:

```text
SNS retries exactly N times
for every endpoint.
```

Wrong.

SNS delivery policies depend on:

```text
protocol

endpoint type

failure response
```

For HTTP/S endpoints, delivery policies can be customized within SNS-supported limits. ([AWS Documentation][22])

---

# 47. HTTP/S Subscription

Architecture:

```text
SNS
 │
 ▼
https://partner.example.com/webhook
```

If the HTTP service becomes unavailable:

```text
SNS
 │
 ├── retry
 ├── retry
 ├── retry
 └── eventually stop
```

depending on the configured delivery policy.

Your HTTP endpoint must therefore be:

```text
idempotent

retry-safe
```

---

# 48. Delivery Failure vs Consumer Failure

This distinction is critical.

Consider:

```text
SNS
 │
 ▼
SQS
 │
 ▼
Worker
```

SNS's job ends when:

```text
message successfully reaches SQS.
```

If:

```text
worker later crashes
```

that is:

```text
SQS / consumer retry semantics
```

not SNS delivery retry semantics.

---

# 49. Multiple Reliability Layers

```text
SNS
 │
 │ SNS delivery retry
 ▼
SQS
 │
 │ visibility timeout + DLQ
 ▼
Lambda
 │
 │ function handling
 ▼
Database
```

Each layer has its own failure model.

Never say:

```text
"the message retries"
```

without specifying:

```text
WHICH layer?
```

---

# PART G — SNS DEAD-LETTER QUEUES

# 50. Subscription DLQ

SNS subscriptions can configure an SQS queue as a:

# Dead-Letter Queue

for messages SNS could not successfully deliver to that subscriber after its delivery policy is exhausted. ([AWS Documentation][23])

Architecture:

```text
SNS Topic
    │
    ▼
Subscription
    │
    ├────────► Endpoint
    │             X
    │
    │ retries exhausted
    ▼
SNS Subscription DLQ
```

---

# 51. This DLQ Is About SNS DELIVERY

This is not the same thing as:

```text
SQS source queue DLQ
```

from Part 1.

Compare:

### SNS subscription DLQ

```text
SNS
failed to deliver
to subscriber
```

### SQS source DLQ

```text
consumer repeatedly failed
to process SQS message
```

Completely different failure boundary.

---

# 52. Full Fan-Out Failure Architecture

```text
                        SNS

             ┌───────────┼─────────────┐
             ▼           ▼             ▼
        Email SQS    Billing SQS    Analytics SQS
             │           │             │
             ▼           ▼             ▼
          Worker       Worker        Worker
             │
             X
             │
      source-queue DLQ


SNS delivery itself fails
to Billing SQS
             │
             ▼
SNS subscription DLQ
```

There may therefore be **two different DLQs** around the same subscriber pipeline.

---

# 53. DLQ Type Compatibility

Current rules:

```text
Standard topic subscription
→ Standard SQS DLQ


FIFO topic subscription
→ FIFO SQS DLQ
```

and the SNS subscription and its SQS DLQ must be in the same AWS account and Region. ([AWS Documentation][23])

---

# 54. DLQ Retention

AWS recommends setting an SNS subscription DLQ's SQS retention period to:

```text
14 days
```

for stronger investigation/recovery time. ([AWS Documentation][23])

Again:

```text
DLQ
without monitoring
=
silent failure archive
```

---

# PART H — SNS + SQS PERMISSIONS

# 55. Subscription Alone Is Not Enough

You create:

```text
SNS Topic
    │
    ▼
SQS Queue
```

but publishing fails.

Why?

The queue needs a resource policy allowing SNS:

```text
sqs:SendMessage
```

from the intended topic. ([AWS Documentation][24])

---

# 56. Good SQS Policy Pattern

Conceptually:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "sns.amazonaws.com"
  },
  "Action": "sqs:SendMessage",
  "Resource": "QUEUE_ARN",
  "Condition": {
    "ArnEquals": {
      "aws:SourceArn": "TOPIC_ARN"
    }
  }
}
```

This means:

```text
SNS service may send

BUT

only from this topic.
```

Far better than allowing any SNS topic in the world.

---

# 57. Confused Deputy Protection

The useful conditions are typically based on:

```text
aws:SourceArn

aws:SourceAccount
```

depending on the integration.

This connects directly to our IAM confused-deputy lesson.

---

# PART I — CROSS-ACCOUNT SNS → SQS

# 58. Cross-Account Fan-Out

Example:

```text
Account A
Order Platform
     │
     ▼
SNS Topic
     │
     ▼
Account B
Analytics SQS
```

SNS supports cross-account SQS subscriptions with the necessary queue policy and subscription ownership/confirmation workflow. ([AWS Documentation][25])

---

# 59. Which Side Creates the Subscription Matters

Cross-account subscription confirmation behavior differs depending on whether the:

```text
topic owner
```

or:

```text
queue owner
```

initiates subscription creation. AWS documents this explicitly because ownership affects confirmation behavior. ([AWS Documentation][25])

For production IaC, decide clearly:

```text
Who owns topic?

Who owns subscription?

Who owns queue policy?
```

---

# 60. Multi-Account Event Architecture

```text
                    Shared Event Account

                      SNS order-events
                             │
             ┌───────────────┼────────────────┐
             ▼               ▼                ▼
          Account A       Account B        Account C
          Billing         Analytics        Fraud
             │               │                │
             ▼               ▼                ▼
            SQS             SQS              SQS
```

This can work, but once your event landscape becomes large, EventBridge often becomes more attractive for organization-wide event routing.

We'll compare them shortly.

---

# PART J — CROSS-REGION SNS → SQS

# 61. SNS Can Deliver Cross-Region to SQS

SNS can subscribe SQS queues in another Region, with Region-specific queue-policy/service-principal details in some scenarios. AWS documents cross-Region SNS→SQS delivery explicitly. ([AWS Documentation][26])

Example:

```text
SNS
ap-south-1
     │
     ▼
SQS
ap-southeast-1
```

Could be used for:

```text
DR workflows

regional replication pipelines

cross-region event distribution
```

But assess latency, resilience and cost carefully.

---

# PART K — KMS ENCRYPTION

# 62. SNS Server-Side Encryption

SNS supports server-side encryption using:

```text
AWS KMS
```

for topic messages.

SNS encrypts message contents after receiving them, stores them encrypted, then decrypts them for delivery. ([AWS Documentation][27])

---

# 63. SNS Uses Symmetric KMS Keys

SNS server-side encryption supports:

```text
symmetric encryption KMS keys
```

not asymmetric KMS keys. ([AWS Documentation][27])

Possible key:

```text
alias/aws/sns
```

or:

```text
customer-managed KMS key
```

depending on governance needs.

---

# 64. Encryption Scope

SNS KMS SSE encrypts the:

```text
message body
```

but does not treat every topic/message metadata field as encrypted message content.

AWS explicitly lists metadata such as:

```text
topic name/attributes

message ID

timestamp

message attributes
```

outside the message-body SSE scope. ([AWS Documentation][27])

Never put secrets into:

```text
message attributes
```

assuming KMS topic encryption hides them.

---

# 65. KMS Permission Problem

Architecture:

```text
Service
  │
  ▼
Publish
  │
  ▼
Encrypted SNS
```

may require authorization at:

```text
SNS topic policy

IAM identity policy

KMS key policy
```

depending on who publishes and which KMS key is used. ([AWS Documentation][28])

Again:

```text
SNS allowed
≠
KMS allowed.
```

---

# 66. Encrypted SNS + Encrypted SQS

A production pipeline can have:

```text
Publisher
   │
   ▼
SNS
KMS encrypted
   │
   ▼
SQS
KMS encrypted
   │
   ▼
Consumer
```

AWS provides documented configurations for SNS topics faning out to encrypted SQS queues. ([AWS Documentation][29])

You must account for:

```text
SNS KMS permissions

SQS KMS permissions

queue policy

topic permissions
```

---

# 67. Private Connectivity

SNS supports interface VPC endpoints through AWS PrivateLink, including for secure FIFO-topic architectures. ([AWS Documentation][9])

So private workloads can publish to SNS without requiring:

```text
public IP
```

solely for SNS API access.

---

# PART L — MESSAGE SIZE

# 68. Important SNS vs SQS Difference

We learned SQS now supports:

```text
1 MiB
```

messages.

SNS's current native publish maximum remains:

```text
256 KB
```

for ordinary SNS messages. AWS documents extended-client libraries for payloads larger than 256 KB. ([AWS Documentation][30])

### Never mix these limits up

```text
SQS
=
1 MiB current max


SNS
=
256 KB native current max
```

---

# 69. Large SNS Payload Pattern

For payloads larger than SNS's native limit:

```text
Publisher
   │
   ├── large payload → S3
   │
   └── S3 reference → SNS
```

AWS's SNS Extended Client libraries for Java and Python support this S3-backed pattern for larger messages, up to the documented extended-client model limit. ([AWS Documentation][30])

Again:

```text
Messaging
=
control/event plane


S3
=
large data plane
```

---

# PART M — EMAIL, SMS & HUMAN NOTIFICATIONS

# 70. SNS Can Notify Humans

Standard SNS topics can publish to:

```text
Email

SMS

Mobile push
```

among other protocols. ([AWS Documentation][1])

Example:

```text
CloudWatch Alarm
      │
      ▼
SNS
      │
      ▼
Email
      │
      ▼
On-call engineer
```

---

# 71. SNS Email Is Not Marketing Email

AWS explicitly notes SNS email subscription delivery is designed for simple/internal notifications and does not provide customizable marketing-email behavior. Direct email subscriptions are supported for Standard topics only. ([AWS Documentation][31])

For rich customer email campaigns, use a service designed for that purpose rather than treating SNS email like a marketing platform.

---

# PART N — FIFO ARCHIVING & REPLAY

# 72. Important FIFO Capability

SNS FIFO topics support:

# Message Archiving and Replay

Topic owners can archive messages directly in the SNS FIFO topic for:

```text
1 day
to
365 days.
```

([AWS Documentation][32])

---

# 73. Why Archive Messages?

Imagine:

```text
Inventory subscriber
misconfigured
for 2 hours
```

Normally:

```text
events during outage
may become unrecoverable
unless another durable path existed.
```

With FIFO topic archive:

```text
SNS FIFO
   │
   ├── live delivery
   │
   └── archive
          │
          ▼
     retained events
```

Subscriber can later replay appropriate archived messages. ([AWS Documentation][33])

---

# 74. Replay

Subscriber configures:

```text
ReplayPolicy
```

and SNS can redeliver archived events to the subscription. Replayed messages preserve the original message content, MessageId, and Timestamp and include replay indication metadata. ([AWS Documentation][34])

This is powerful for:

```text
disaster recovery

state reconstruction

subscriber resynchronization

downstream recovery
```

---

# 75. Archive Is FIFO-Only

Do not assume:

```text
all SNS Standard topics
store 365 days of history.
```

No.

The in-place SNS message archive/replay feature discussed here is specifically for:

```text
SNS FIFO topics.
```

([AWS Documentation][32])

---

# PART O — SNS MONITORING

# 76. What Should You Monitor?

Operationally, watch areas such as:

```text
messages published

notifications delivered

notifications failed

notifications filtered

DLQ depth

delivery latency/failure
```

depending on protocol and architecture.

The important design mindset:

```text
Publish success

does NOT mean

every subscriber
processed successfully.
```

---

# 77. Three Separate Success Questions

Ask:

```text
1.
Did publisher successfully publish to SNS?


2.
Did SNS successfully deliver
to each subscription?


3.
Did downstream consumer
successfully process the message?
```

Those are:

```text
three different success boundaries.
```

---

# 78. Fan-Out Observability

```text
OrderCreated
     │
     ▼
SNS
     │
 ┌───┼───────────┐
 ▼   ▼           ▼
Q1   Q2          Q3
│    │           │
▼    ▼           ▼
✓    ✓           X
```

A single topic-wide “published” metric tells you nothing about whether:

```text
consumer Q3
is healthy.
```

Monitor subscriber systems independently.

---

# PART P — SNS vs SQS

# 79. Permanent Difference

```text
SQS
=
ONE queue of work


SNS
=
ONE publication
to MANY subscribers
```

---

# 80. SQS Communication Model

```text
Producer
   │
   ▼
SQS
   │
 consumers pull
   ▼
Worker
```

Main use:

```text
work queues

backpressure

durable buffering
```

---

# 81. SNS Communication Model

```text
Publisher
   │
   ▼
SNS
   │
 push fan-out
   ├── subscriber A
   ├── subscriber B
   └── subscriber C
```

Main use:

```text
pub/sub

notifications

fan-out
```

AWS's decision guide makes this same fundamental distinction: SQS is pull-based queueing, whereas SNS is push-oriented pub/sub. ([AWS Documentation][35])

---

# PART Q — SNS vs EVENTBRIDGE

# 82. Both Can Fan Out

You may ask:

> Why not always use EventBridge?

Because the services optimize for different styles.

A useful mental model:

```text
SNS
=
fast/simple pub-sub fan-out


EventBridge
=
event routing fabric
with richer event matching
and integrations
```

AWS's decision guide compares them across communication model, persistence, ordering, filtering, integrations and use cases. ([AWS Documentation][35])

---

# 83. SNS Strength

Choose SNS when you primarily need:

```text
publish to topic

fan out quickly

SQS subscriptions

Lambda standard-topic subscriptions

HTTP/S webhook

email/SMS/mobile delivery

FIFO ordered fan-out to queues
```

---

# 84. EventBridge Strength

Choose EventBridge when you need:

```text
rich event patterns

many AWS service events

custom event buses

cross-account event routing

SaaS event integration

schema-oriented event routing

archive/replay at event-bus level

Pipes/Scheduler ecosystem
```

We'll cover EventBridge fully in Part 3.

---

# 85. Filtering Comparison

SNS filtering is:

```text
subscription-centric
```

The message is published to one topic and each subscription applies its filter policy.

EventBridge:

```text
rule-centric
```

Events arrive on a bus and rules independently pattern-match and route events.

Both are powerful, but the operational model differs.

---

# 86. Simple Decision

```text
Do I need durable one-consumer work queue?
        │
        ▼
       SQS


Do I need simple push fan-out?
        │
        ▼
       SNS


Do I need richer event routing / event bus?
        │
        ▼
   EventBridge
```

---

# PART R — PRODUCTION ORDER ARCHITECTURE

# 87. Bad Architecture

```text
Order API
   │
   ├── Inventory API
   ├── Email API
   ├── Analytics API
   ├── Fraud API
   └── CRM API
```

Every dependency becomes part of order latency and failure surface.

---

# 88. Better Architecture

```text
                         Order API
                             │
                        transaction
                             │
                             ▼
                       OrderCreated
                             │
                             ▼
                            SNS
                             │
         ┌───────────────────┼────────────────────┐
         ▼                   ▼                    ▼
   Inventory Queue      Email Queue         Analytics Queue
         │                   │                    │
         ▼                   ▼                    ▼
     Inventory             Email               Analytics
      Worker               Worker               Worker
         │                   │                    │
         ▼                   ▼                    ▼
    inventory DB          provider             data lake
```

Now each subscriber can scale independently.

---

# 89. Add Fraud

```text
SNS order-events
      │
      ├── inventory SQS
      ├── email SQS
      ├── analytics SQS
      └── fraud SQS
```

The Order API doesn't need to be redeployed merely because a new subscriber appears.

That is one of the biggest benefits of pub/sub.

---

# 90. Add Filtering

Suppose topic contains:

```text
OrderCreated

OrderCancelled

RefundRequested
```

Filter:

```text
Inventory
=
OrderCreated OR OrderCancelled


Refund
=
RefundRequested


Analytics
=
everything
```

Now event routing remains centralized at the subscription boundary.

---

# 91. Add DLQs

```text
                         SNS
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
      Inventory SQS    Email SQS       Fraud SQS
          │               │               │
          ▼               ▼               ▼
        worker           worker          worker
          │               │
          ▼               ▼
      queue DLQ        queue DLQ


SNS cannot deliver
to Inventory SQS
          │
          ▼
subscription DLQ
```

Now delivery failures and processing failures are separated operationally.

---

# PART S — CLI LAB

Region:

```bash
export AWS_REGION=ap-south-1
```

---

# 92. Create Standard Topic

```bash
TOPIC_ARN=$(aws sns create-topic \
  --name order-events \
  --region "$AWS_REGION" \
  --query TopicArn \
  --output text)

echo "$TOPIC_ARN"
```

---

# 93. Create Email Queue

```bash
EMAIL_QUEUE_URL=$(aws sqs create-queue \
  --queue-name order-email \
  --region "$AWS_REGION" \
  --query QueueUrl \
  --output text)
```

Get ARN:

```bash
EMAIL_QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url "$EMAIL_QUEUE_URL" \
  --attribute-names QueueArn \
  --region "$AWS_REGION" \
  --query 'Attributes.QueueArn' \
  --output text)
```

---

# 94. Subscribe SQS to SNS

```bash
aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol sqs \
  --notification-endpoint "$EMAIL_QUEUE_ARN" \
  --region "$AWS_REGION"
```

Remember: the queue must also permit the topic to call `sqs:SendMessage`; simply creating the subscription isn't sufficient authorization. ([AWS Documentation][24])

---

# 95. Publish

```bash
aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message '{
    "eventType":"OrderCreated",
    "orderId":"ORD-1001"
  }' \
  --region "$AWS_REGION"
```

---

# 96. Receive from SQS

```bash
aws sqs receive-message \
  --queue-url "$EMAIL_QUEUE_URL" \
  --wait-time-seconds 20 \
  --attribute-names All \
  --message-attribute-names All \
  --region "$AWS_REGION"
```

Without raw delivery, expect the SNS wrapper structure around your original `Message`. ([AWS Documentation][3])

---

# PART T — FILTERING LAB

# 97. Publish with Attribute

```bash
aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message '{"orderId":"ORD-1002"}' \
  --message-attributes '{
    "eventType": {
      "DataType": "String",
      "StringValue": "OrderCreated"
    }
  }' \
  --region "$AWS_REGION"
```

---

# 98. Subscription Filter

Filter:

```json
{
  "eventType": [
    "OrderCreated"
  ]
}
```

Apply it to the subscription.

Now:

```text
OrderCreated
→ delivered


RefundRequested
→ not delivered
```

SNS compares message attributes or message body properties against each subscription's filter policy. ([AWS Documentation][17])

---

# PART U — FIFO LAB

# 99. Create FIFO Topic

```bash
FIFO_TOPIC_ARN=$(aws sns create-topic \
  --name order-events.fifo \
  --attributes \
    FifoTopic=true,\
ContentBasedDeduplication=true \
  --region "$AWS_REGION" \
  --query TopicArn \
  --output text)
```

---

# 100. Publish FIFO Event

```bash
aws sns publish \
  --topic-arn "$FIFO_TOPIC_ARN" \
  --message-group-id customer-101 \
  --message '{
    "eventType":"OrderCreated",
    "orderId":"ORD-1"
  }' \
  --region "$AWS_REGION"
```

Every FIFO publication requires a `MessageGroupId`; deduplication ID is required unless content-based deduplication generates it for you. ([AWS Documentation][2])

---

# 101. Ordered Sequence

```bash
aws sns publish \
  --topic-arn "$FIFO_TOPIC_ARN" \
  --message-group-id customer-101 \
  --message '{"sequence":1}' \
  --region "$AWS_REGION"

aws sns publish \
  --topic-arn "$FIFO_TOPIC_ARN" \
  --message-group-id customer-101 \
  --message '{"sequence":2}' \
  --region "$AWS_REGION"
```

With an SQS FIFO subscriber, ordering remains preserved for that message group when the pipeline is configured correctly. ([AWS Documentation][20])

---

# PART V — TERRAFORM

# 102. SNS Topic

Current Terraform AWS provider exposes:

```text
aws_sns_topic
```

for SNS topics and:

```text
aws_sns_topic_subscription
```

for subscriptions. ([Terraform Registry][36])

Conceptually:

```hcl
resource "aws_sns_topic" "orders" {
  name = "order-events"

  kms_master_key_id = aws_kms_key.messaging.id
}
```

---

# 103. SQS Subscriber

```hcl
resource "aws_sqs_queue" "email" {
  name = "order-email"

  sqs_managed_sse_enabled = true
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.orders.arn

  protocol = "sqs"

  endpoint = aws_sqs_queue.email.arn
}
```

---

# 104. Queue Policy

```hcl
data "aws_iam_policy_document" "email_queue" {
  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "sns.amazonaws.com"
      ]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.email.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        aws_sns_topic.orders.arn
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "email" {
  queue_url = aws_sqs_queue.email.id

  policy =
    data.aws_iam_policy_document.email_queue.json
}
```

This implements the required queue-side permission for SNS delivery while restricting it to the intended topic. ([AWS Documentation][24])

---

# 105. Subscription Filter

```hcl
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.orders.arn

  protocol = "sqs"

  endpoint = aws_sqs_queue.email.arn

  filter_policy = jsonencode({
    eventType = [
      "OrderCreated"
    ]
  })
}
```

Current Terraform subscription resources support SNS filter-policy configuration. ([Terraform Registry][36])

---

# 106. Raw Delivery

```hcl
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.orders.arn

  protocol = "sqs"

  endpoint = aws_sqs_queue.email.arn

  raw_message_delivery = true
}
```

Now the queue receives the raw message body rather than the SNS JSON envelope. ([AWS Documentation][37])

---

# 107. FIFO Topic Terraform

Conceptually:

```hcl
resource "aws_sns_topic" "orders_fifo" {
  name = "order-events.fifo"

  fifo_topic = true

  content_based_deduplication = true
}
```

When using FIFO subscribers, pair with appropriately configured SQS FIFO queues when strict ordering is required.

---

# PART W — PRODUCTION TROUBLESHOOTING

# 108. SNS Publish Succeeds but SQS Is Empty

Check:

```text
subscription exists?

subscription confirmed?

queue policy allows sns.amazonaws.com?

SourceArn correct?

filter policy accidentally rejects event?

correct Region/account?

KMS key permissions?

SNS delivery failures?
```

A very common cause is missing:

```text
sqs:SendMessage
```

permission on the SQS queue policy. ([AWS Documentation][24])

---

# 109. Only One Subscriber Receives Messages

Inspect each:

```text
subscription filter

endpoint policy

DLQ

protocol

subscription confirmation/status
```

Subscriptions are independent.

Topic publication success doesn't guarantee every subscription delivered successfully.

---

# 110. Lambda Cannot Subscribe to FIFO Topic

Expected.

Direct SNS → Lambda currently supports:

```text
Standard SNS topic
```

not FIFO. ([AWS Documentation][13])

Use:

```text
SNS FIFO
→ SQS
→ Lambda
```

---

# 111. FIFO Messages Out of Order

Check:

```text
subscriber is SQS FIFO?

or Standard SQS?

same MessageGroupId?

consumer processing semantics?

raw/metadata assumptions?
```

An SNS FIFO topic feeding a Standard SQS queue loses strict queue-level ordering guarantees; FIFO SQS preserves them. ([AWS Documentation][20])

---

# 112. FIFO Throughput Is Low

Check:

```text
one MessageGroupId?

FifoThroughputScope=Topic?

high-throughput mode enabled?

subscriber queue high-throughput configured?

bad group distribution?
```

AWS recommends many distinct message groups to optimize high-throughput FIFO delivery. ([AWS Documentation][8])

---

# 113. Messages Being Filtered Unexpectedly

Check:

```text
FilterPolicyScope?

MessageAttributes
or
MessageBody?

correct datatype?

nested policy allowed?

message body valid JSON?

property names match exactly?
```

Attribute-based filtering and body-based filtering have different constraints. ([AWS Documentation][16])

---

# 114. SNS DLQ Is Empty but SQS Consumer Is Failing

Likely expected.

SNS successfully delivered:

```text
SNS
→ SQS
```

so no SNS delivery failure occurred.

The failure happened later:

```text
SQS
→ consumer
```

Check the:

```text
SQS source DLQ
```

rather than SNS subscription DLQ.

---

# 115. Encrypted Topic Gives AccessDenied

Investigate:

```text
publisher IAM

topic policy

KMS key policy

KMS key Region

kms:GenerateDataKey

kms:Decrypt where applicable
```

SNS with KMS introduces KMS authorization in addition to SNS authorization. ([AWS Documentation][28])

---

# 116. Raw Delivery Broke Consumer Metadata

Expected possibility.

Raw delivery removes normal SNS envelope metadata. ([AWS Documentation][19])

If the application needs:

```text
TopicArn

SNS MessageId

Timestamp

SequenceNumber
```

don't blindly enable raw delivery.

---

# PART X — CERTIFICATION / INTERVIEW SCENARIOS

# 117. Scenario

> One order event must reach four independent downstream services.

Think:

```text
SNS
+
one SQS queue per subscriber
```

Fan-out architecture.

---

# 118. Scenario

> Only one worker should process each job.

Think:

```text
SQS
```

not SNS alone.

---

# 119. Scenario

> Need to notify email, SMS and HTTPS endpoints.

Think:

```text
SNS Standard Topic
```

because Standard topics support the broad protocol set. ([AWS Documentation][1])

---

# 120. Scenario

> Need ordered fan-out to multiple applications.

Think:

```text
SNS FIFO
      │
      ├── SQS FIFO
      └── SQS FIFO
```

with:

```text
MessageGroupId
```

designed around the ordering boundary. ([AWS Documentation][8])

---

# 121. Scenario

> Need Lambda to consume events from SNS FIFO.

Think:

```text
SNS FIFO
→ SQS
→ Lambda
```

because direct Lambda subscription to FIFO SNS isn't currently supported. ([AWS Documentation][13])

---

# 122. Scenario

> Topic contains 20 event types, but subscriber needs only PaymentFailed.

Think:

```text
SNS subscription
filter policy.
```

([AWS Documentation][14])

---

# 123. Scenario

> Need filtering based on nested JSON payload fields.

Use:

```text
FilterPolicyScope=MessageBody
```

rather than default attribute filtering. ([AWS Documentation][15])

---

# 124. Scenario

> SNS repeatedly cannot deliver to an endpoint and messages must not disappear.

Use:

```text
SNS subscription DLQ
```

which is an SQS queue attached to the subscription. ([AWS Documentation][38])

---

# 125. Scenario

> SQS consumer fails five times after SNS successfully delivered the event.

Use:

```text
SQS redrive policy / source queue DLQ
```

not the SNS subscription DLQ.

---

# 126. Scenario

> Need to replay six months of ordered SNS events.

SNS FIFO archive/replay can retain messages up to:

```text
365 days.
```

([AWS Documentation][32])

---

# 127. Scenario

> Need native SNS message payload of 900 KB.

Not supported natively.

SNS native message size is currently:

```text
256 KB.
```

Use:

```text
S3 pointer / extended client
```

or redesign the payload path. ([AWS Documentation][30])

---

# 128. Scenario

> Need 900-KB queue message but no SNS involved.

SQS currently supports up to:

```text
1 MiB.
```

Different service, different limit.

---

# 129. Scenario

> Need simple, high-throughput, multi-subscriber notification with SQS consumers.

Think:

```text
SNS Standard
+
SQS fan-out
```

---

# 130. Scenario

> Need complex event bus routing across many accounts and AWS services.

Think:

```text
EventBridge
```

rather than automatically forcing everything through SNS. AWS's decision guide explicitly positions EventBridge differently from SNS/SQS around event routing and integration breadth. ([AWS Documentation][35])

---

# 131. The Permanent SNS/SQS Mental Model

```text
                     PRODUCER

                        │
                        ▼
                       SNS
                 "publish event"
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
        SQS A          SQS B        SQS C
          │             │             │
    "my backlog"   "my backlog"  "my backlog"
          │             │             │
          ▼             ▼             ▼
      Consumer A     Consumer B    Consumer C
```

Remember:

```text
SNS
duplicates the EVENT
across subscriptions.


SQS
duplicates the CAPACITY
across competing consumers.
```

---

# 132. 40 Rules to Burn Into Memory

```text
1. SNS is publish/subscribe messaging.

2. SNS publishers publish to topics.

3. Subscribers attach to topics.

4. One publication can reach many subscriptions.

5. SNS fan-out is different from SQS competing consumers.

6. SNS + SQS is one of AWS's strongest decoupling patterns.

7. Give each independent service its own SQS queue.

8. One subscriber failure shouldn't block other subscribers.

9. SNS supports Standard and FIFO topics.

10. You cannot convert topic type after creation.

11. Standard topics support the widest protocol set.

12. FIFO topics provide ordered message groups.

13. FIFO messages require MessageGroupId.

14. Ordering exists within a group.

15. Different groups process independently.

16. One global group destroys FIFO scalability.

17. FIFO uses MessageDeduplicationId.

18. FIFO deduplication window is five minutes.

19. Content-based dedup uses the message body hash.

20. Message attributes are not part of that hash.

21. FifoThroughputScope controls FIFO throughput/dedup scope.

22. High-throughput FIFO requires good group distribution.

23. FIFO topics cannot directly publish to email/SMS/HTTP endpoints.

24. Direct SNS → Lambda currently requires Standard topic.

25. For FIFO → Lambda, place SQS in the middle.

26. FIFO topics can subscribe FIFO or Standard SQS queues.

27. SNS subscription filters reduce unnecessary delivery.

28. FilterPolicyScope defaults to MessageAttributes.

29. MessageBody supports payload-based filtering.

30. Filters belong to individual subscriptions.

31. Raw delivery removes the SNS wrapper.

32. Raw delivery also removes useful SNS metadata.

33. SNS retries delivery according to endpoint protocol/policy.

34. SNS subscription DLQ handles DELIVERY failure.

35. SQS source DLQ handles PROCESSING failure.

36. SNS→SQS needs queue policy permission.

37. SNS supports KMS server-side encryption.

38. SNS native message max remains 256 KB.

39. SNS FIFO can archive/replay up to 365 days.

40. Choose:
    SQS = work queue
    SNS = fan-out
    EventBridge = rich event routing.
```

---

# 133. Full Production Order Messaging Architecture

```text
                            API Gateway
                                 │
                                 ▼
                            Order Service
                                 │
                                 ▼
                          Create Order DB
                                 │
                                 ▼
                            OrderCreated
                                 │
                                 ▼
                               SNS
                              Topic
                                 │
      ┌──────────────────────────┼──────────────────────────┐
      ▼                          ▼                          ▼
Inventory Subscription      Email Subscription        Analytics Subscription
      │                          │                          │
    Filter                      Filter                     None
OrderCreated                OrderCreated                    │
      │                          │                          │
      ▼                          ▼                          ▼
 Inventory SQS              Email SQS                Analytics SQS
      │                          │                          │
      ▼                          ▼                          ▼
 Inventory Lambda           Email Lambda              Analytics Worker
      │                          │                          │
      ▼                          ▼                          ▼
 Inventory DB             Email provider               Data lake

      │                          │
      ▼                          ▼
 Inventory DLQ             Email DLQ


                SNS delivery failure
                         │
                         ▼
                 Subscription DLQ


SECURITY
────────

IAM
+
queue policies
+
KMS
+
PrivateLink where required


OBSERVABILITY
─────────────

SNS delivery metrics
+
SQS backlog/age
+
consumer errors
+
DLQ alarms
+
CloudTrail
```

That is a production-grade pub/sub architecture.

---

# ✅ Lesson 34 Part 2 Complete — Amazon SNS

You now understand:

```text
✓ SNS mental model
✓ topics
✓ subscriptions
✓ publishers
✓ subscribers
✓ fan-out

✓ SNS + SQS architecture
✓ failure isolation
✓ subscriber independence

✓ Standard topics
✓ Standard subscriber protocols

✓ FIFO topics
✓ MessageGroupId
✓ ordered streams
✓ deduplication IDs
✓ content-based deduplication
✓ five-minute dedup window
✓ FifoThroughputScope
✓ high-throughput FIFO
✓ message-group throughput
✓ FIFO distribution

✓ FIFO endpoint limitations
✓ FIFO → SQS FIFO
✓ FIFO → SQS Standard
✓ FIFO → Lambda via SQS

✓ subscription filters
✓ message attributes
✓ payload filtering
✓ FilterPolicyScope
✓ numeric filters
✓ AND/OR matching
✓ per-subscription routing

✓ raw message delivery
✓ SNS JSON envelope
✓ metadata tradeoffs

✓ protocol-specific retry behavior
✓ delivery policies
✓ HTTP/S retries
✓ multiple reliability layers

✓ SNS subscription DLQ
✓ SNS DLQ vs SQS source DLQ
✓ DLQ type compatibility
✓ DLQ retention

✓ queue resource policies
✓ sqs:SendMessage
✓ SourceArn restrictions
✓ cross-account SNS→SQS
✓ cross-Region delivery

✓ SNS KMS encryption
✓ symmetric KMS keys
✓ message-body encryption
✓ metadata encryption limitations
✓ encrypted SNS→encrypted SQS
✓ PrivateLink

✓ SNS 256-KB native payload limit
✓ S3 pointer pattern

✓ email/SMS/mobile notifications

✓ FIFO archive
✓ FIFO replay
✓ 1–365 day archive retention

✓ SNS vs SQS
✓ SNS vs EventBridge
✓ production fan-out architecture

✓ CLI labs
✓ Terraform
✓ troubleshooting
✓ certification scenarios
```

# Next — Lesson 34 Part 3

# **Amazon EventBridge in Depth — Event Buses, Rules, Patterns, Pipes, Scheduler, Archives & Cross-Account Event Routing**

We already used EventBridge operationally.

Now we'll learn it as a full event-routing platform:

```text
                         EVENT PRODUCERS

          AWS Services    Applications    SaaS
               │              │             │
               └──────────────┼─────────────┘
                              ▼
                         EventBridge
                           Event Bus
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
             Rule A          Rule B         Rule C
               │              │              │
             filter         filter          filter
               │              │              │
               ▼              ▼              ▼
              SQS           Lambda      Step Functions


                         EventBridge Pipes

         SQS / Kinesis / DynamoDB / Kafka
                     │
                     ▼
                   Filter
                     │
                     ▼
                 Enrichment
                     │
                     ▼
                   Target


                         Scheduler

             one-time / cron / rate
                     │
                     ▼
                    Task
```

We'll cover **default vs custom event buses, partner event sources, event structure, event patterns, advanced matching operators, input transformers, target retries/DLQs, archive and replay, cross-account buses, Organizations policies, global endpoints/failover, schema registry concepts, EventBridge Pipes sources/filtering/enrichment/targets, Scheduler one-time/cron/rate schedules, flexible time windows, DLQs, IAM roles, SNS vs EventBridge routing decisions, choreography architecture, Terraform, and a full multi-account event-driven production platform.**

[1]: https://docs.aws.amazon.com/sns/latest/dg/welcome.html?utm_source=chatgpt.com "What is Amazon SNS? - Amazon Simple Notification Service"
[2]: https://docs.aws.amazon.com/sns/latest/api/API_Publish.html?utm_source=chatgpt.com "Publish - Amazon Simple Notification Service"
[3]: https://docs.aws.amazon.com/sns/latest/dg/sns-sqs-as-subscriber.html?utm_source=chatgpt.com "Fanout Amazon SNS notifications to Amazon SQS queues ..."
[4]: https://docs.aws.amazon.com/sns/latest/dg/sns-create-topic.html?utm_source=chatgpt.com "Creating an Amazon SNS topic - Amazon Simple Notification Service"
[5]: https://docs.aws.amazon.com/sns/latest/dg/welcome-features.html?utm_source=chatgpt.com "Amazon SNS features and capabilities - AWS Documentation"
[6]: https://docs.aws.amazon.com/sns/latest/dg/sns-fifo-topics.html?utm_source=chatgpt.com "Message ordering and deduplication strategies using ..."
[7]: https://docs.aws.amazon.com/sns/latest/dg/fifo-topic-code-examples.html?utm_source=chatgpt.com "Amazon SNS code examples for FIFO topics - AWS Documentation"
[8]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-grouping.html?utm_source=chatgpt.com "Amazon SNS message grouping for FIFO topics"
[9]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-dedup.html?utm_source=chatgpt.com "Amazon SNS message deduplication for FIFO topics"
[10]: https://docs.aws.amazon.com/general/latest/gr/sns.html?utm_source=chatgpt.com "Amazon Simple Notification Service endpoints and quotas"
[11]: https://docs.aws.amazon.com/sns/latest/dg/fifo-high-throughput.html?utm_source=chatgpt.com "High throughput FIFO topics in Amazon SNS"
[12]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-delivery.html?utm_source=chatgpt.com "Amazon SNS message delivery for FIFO topics - AWS Documentation"
[13]: https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html?utm_source=chatgpt.com "Invoking Lambda functions with Amazon SNS notifications"
[14]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html?utm_source=chatgpt.com "Amazon SNS message filtering"
[15]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering-scope.html?utm_source=chatgpt.com "Amazon SNS subscription filter policy scope"
[16]: https://docs.aws.amazon.com/sns/latest/dg/subscription-filter-policy-constraints.html?utm_source=chatgpt.com "Filter policy constraints in Amazon SNS"
[17]: https://docs.aws.amazon.com/sns/latest/dg/sns-subscription-filter-policies.html?utm_source=chatgpt.com "Amazon SNS subscription filter policies"
[18]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-filtering.html?utm_source=chatgpt.com "Amazon SNS message filtering for FIFO topics"
[19]: https://docs.aws.amazon.com/sns/latest/dg/sns-large-payload-raw-message-delivery.html?utm_source=chatgpt.com "Amazon SNS raw message delivery"
[20]: https://docs.aws.amazon.com/sns/latest/dg/fifo-topic-message-ordering.html?utm_source=chatgpt.com "Amazon SNS message ordering details for FIFO topics"
[21]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-delivery-retries.html?utm_source=chatgpt.com "Amazon SNS message delivery retries"
[22]: https://docs.aws.amazon.com/sns/latest/dg/SendMessageToHttp.retry.html?utm_source=chatgpt.com "Set the delivery policy for the Amazon SNS subscription"
[23]: https://docs.aws.amazon.com/sns/latest/dg/sns-dead-letter-queues.html?utm_source=chatgpt.com "Amazon SNS dead-letter queues"
[24]: https://docs.aws.amazon.com/sns/latest/dg/subscribe-sqs-queue-to-sns-topic.html?utm_source=chatgpt.com "Subscribing an Amazon SQS queue to an Amazon SNS topic"
[25]: https://docs.aws.amazon.com/sns/latest/dg/sns-send-message-to-sqs-cross-account.html?utm_source=chatgpt.com "Sending Amazon SNS messages to an Amazon SQS ..."
[26]: https://docs.aws.amazon.com/sns/latest/dg/sns-cross-region-delivery.html?utm_source=chatgpt.com "Sending Amazon SNS messages to an Amazon SQS ..."
[27]: https://docs.aws.amazon.com/sns/latest/dg/sns-server-side-encryption.html?utm_source=chatgpt.com "Securing Amazon SNS data with server-side encryption"
[28]: https://docs.aws.amazon.com/sns/latest/dg/sns-key-management.html?utm_source=chatgpt.com "Managing Amazon SNS encryption keys and costs"
[29]: https://docs.aws.amazon.com/sns/latest/dg/sns-enable-encryption-for-topic-sqs-queue-subscriptions.html?utm_source=chatgpt.com "Setting up Amazon SNS topic encryption with ..."
[30]: https://docs.aws.amazon.com/sns/latest/dg/large-message-payloads.html?utm_source=chatgpt.com "Publishing large messages with Amazon SNS and ..."
[31]: https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html?utm_source=chatgpt.com "Amazon SNS email subscription setup and management"
[32]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-archiving-replay.html?utm_source=chatgpt.com "Amazon SNS message archiving and replay for FIFO topics"
[33]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-durability.html?utm_source=chatgpt.com "Amazon SNS message durability for FIFO topics"
[34]: https://docs.aws.amazon.com/sns/latest/dg/message-archiving-and-replay-subscriber.html?utm_source=chatgpt.com "Amazon SNS message replay for FIFO topic subscribers"
[35]: https://docs.aws.amazon.com/decision-guides/latest/sns-or-sqs-or-eventbridge/sns-or-sqs-or-eventbridge.html?utm_source=chatgpt.com "Amazon SQS, Amazon SNS, or EventBridge?"
[36]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription?utm_source=chatgpt.com "aws_sns_topic_subscription | Resources | hashicorp/aws"
[37]: https://docs.aws.amazon.com/boto3/latest/reference/services/sns/topic/subscribe.html?utm_source=chatgpt.com "subscribe - Boto3 1.43.68 documentation"
[38]: https://docs.aws.amazon.com/sns/latest/dg/sns-configure-dead-letter-queue.html?utm_source=chatgpt.com "Configuring an Amazon SNS dead-letter queue for a subscription"
