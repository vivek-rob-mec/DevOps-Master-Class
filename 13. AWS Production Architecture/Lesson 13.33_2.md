# AWS Masterclass — Lesson 33 Part 2

# Lambda Event Sources, Retries, SQS, Streams, DLQs, Destinations & Idempotency

Part 1 answered:

```text
HOW DOES LAMBDA EXECUTE?
        │
        ▼
Execution Environment
Cold Start
Concurrency
Memory
IAM
VPC
Versions
Aliases
```

Now we answer the more difficult question:

> **What happens to an event when the function succeeds, fails, times out, is throttled, processes only half a batch, receives a duplicate, or encounters one poisonous record?**

This is where Lambda stops being merely “serverless code” and becomes **distributed-systems engineering**.

The master model:

```text
                       EVENT PRODUCERS

          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
         S3                SNS             EventBridge
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                  ASYNCHRONOUS INVOCATION
                             │
                       Lambda queue
                             │
                       retry behavior
                             │
                    ┌────────┴─────────┐
                    ▼                  ▼
                 SUCCESS             FAILURE
                    │                  │
                    ▼                  ▼
             OnSuccess Dest.     OnFailure Dest.
                                   / DLQ


                            SQS
                             │
                             ▼
                   Event Source Mapping
                             │
                         POLLING
                             │
                         BATCHING
                             │
                             ▼
                          Lambda
                             │
                  ┌──────────┴──────────┐
                  ▼                     ▼
              successful              failed
               messages              messages
                  │                     │
                  ▼                     ▼
                delete             retry / DLQ


                  Kinesis / DynamoDB Streams
                             │
                             ▼
                           shards
                             │
                         batches
                             │
                             ▼
                          Lambda
                             │
                 ordered checkpoints
                             │
                  retry / split / discard
```

The biggest lesson today is:

```text
THE EVENT SOURCE
DETERMINES
THE RETRY MODEL.
```

There is no single universal “Lambda retry behavior.” AWS distinguishes synchronous invocations, asynchronous invocations, and event-source mappings, each with different ownership of polling, retries, batching, and failure handling. ([AWS Documentation][1])

---

# Part A — The Three Invocation Models

## 1. Model 1 — Synchronous Invocation

```text
Caller
   │
   ▼
Lambda
   │
   ▼
Function runs
   │
   ▼
Response
   │
   ▼
Caller
```

The caller waits for the function result.

For direct synchronous Lambda invocation, Lambda does **not** automatically retry your function-code failure for you; the caller or invoking service decides whether and how to retry. ([AWS Documentation][1])

Examples:

```text
Application → Lambda Invoke API

API Gateway → Lambda

some service integrations
```

The key question becomes:

```text
WHO IS THE CALLER
AND
WHAT IS ITS RETRY POLICY?
```

---

# 2. Model 2 — Asynchronous Invocation

Here Lambda itself puts the incoming event into an internal asynchronous queue.

```text
Producer
   │
   ▼
Lambda Invoke
   │
   ▼
Internal Lambda Queue
   │
   ▼
Producer receives acceptance
   │
   ▼
Function executes later
```

The producer doesn't wait for your business result. Lambda accepts the event, queues it, and later invokes the function. ([AWS Documentation][2])

Typical integrations include SNS-to-Lambda and EventBridge-to-Lambda; SNS explicitly uses asynchronous Lambda processing, and EventBridge lists Lambda as an asynchronous rule target. ([AWS Documentation][3])

---

# 3. Model 3 — Event Source Mapping

This is different again.

For services such as:

```text
SQS
Kinesis Data Streams
DynamoDB Streams
Amazon MSK
Kafka
Amazon MQ
DocumentDB
```

Lambda can create an:

# Event Source Mapping

The event source mapping contains pollers that read from the queue/stream and invoke your Lambda function with batches. ([AWS Documentation][4])

```text
Queue / Stream
      │
      ▼
Lambda Event Pollers
      │
      ▼
Batch
      │
      ▼
Function
```

Here:

```text
Lambda polls the source.
```

That is fundamentally different from:

```text
S3 pushes event
to Lambda async queue.
```

---

# 4. The Permanent Invocation Decision Table

| Source model                | Who reads the event? | Function invocation          | Typical retry owner                    |
| --------------------------- | -------------------- | ---------------------------- | -------------------------------------- |
| Direct sync                 | Caller               | Synchronous                  | Caller                                 |
| API-style sync              | Service/client       | Synchronous                  | Caller/service                         |
| SNS/EventBridge-style async | Producer pushes      | Asynchronous                 | Lambda + potentially producer delivery |
| SQS                         | Lambda poller        | Synchronous batch invocation | Queue/event source mapping             |
| Kinesis                     | Lambda poller        | Synchronous batch invocation | Event source mapping/stream            |
| DynamoDB Streams            | Lambda poller        | Synchronous batch invocation | Event source mapping/stream            |

AWS explicitly describes SQS and Kinesis event-source mappings as polling the source and then invoking the Lambda function synchronously with a batch. ([AWS Documentation][5])

### Never forget:

```text
ASYNC LAMBDA RETRY RULES
DO NOT AUTOMATICALLY APPLY
TO SQS EVENT SOURCE MAPPINGS.
```

---

# Part B — Asynchronous Lambda Invocation

## 5. Async Invocation Internal Queue

Suppose SNS publishes:

```json
{
  "orderId": "ORD-1001"
}
```

Lambda receives the asynchronous request:

```text
SNS
 │
 ▼
Lambda async queue
 │
 ▼
Function
```

The producer is decoupled from actual execution. Lambda queues the request and returns a success/acceptance response without waiting for the function's processing result. ([AWS Documentation][2])

---

# 6. Default Function-Error Retry

If the function **runs** but returns an error, throws an exception, or times out, Lambda's default asynchronous behavior is:

```text
Attempt 1
   │
 failure
   ▼
wait ~1 minute

Attempt 2
   │
 failure
   ▼
wait ~2 minutes

Attempt 3
```

In other words:

```text
Original attempt
+
2 retries
```

for function/runtime errors by default. ([AWS Documentation][6])

---

# 7. Throttling/System Errors Behave Differently

If Lambda can't execute the event because of:

```text
429 throttling
500-series system error
```

Lambda returns the event to its asynchronous queue and retries for up to:

```text
6 hours
```

by default, using increasing retry intervals. AWS documents exponential retry growth from about one second toward a maximum interval of five minutes for these errors. ([AWS Documentation][6])

So:

```text
FUNCTION ERROR
```

and:

```text
INVOCATION CAPACITY/SYSTEM ERROR
```

are not the same failure path.

---

# 8. Maximum Retry Attempts

You can configure asynchronous invocation retries for function errors from:

```text
0
to
2
```

retries. ([AWS Documentation][7])

Example:

```bash
aws lambda put-function-event-invoke-config \
  --function-name process-order \
  --maximum-retry-attempts 0 \
  --maximum-event-age-in-seconds 3600
```

This says:

```text
Do not retry
function-code errors.

Keep events at most
1 hour.
```

---

# 9. Maximum Event Age

Asynchronous Lambda events can be configured with a maximum age of up to:

```text
6 hours
```

before Lambda discards events that can no longer be processed within the configured lifetime. ([AWS Documentation][7])

This matters during:

```text
concurrency exhaustion

regional disruption

function throttling

backlog accumulation
```

---

# 10. Async Backlog Example

Suppose events arrive:

```text
10,000/sec
```

but Lambda can process:

```text
8,000/sec
```

Backlog growth:

```text
2,000 events/sec
```

After ten minutes:

```text
~1.2 million event deficit
```

Even if individual executions are healthy.

The important CloudWatch async metrics include signals such as:

```text
AsyncEventsReceived
AsyncEventAge
```

which help show queue growth and event processing delay. ([AWS Documentation][8])

---

# 11. Duplicate Async Delivery Is Possible

Even if your function returns success, AWS warns that the same asynchronous event can sometimes be delivered more than once because the internal queue is eventually consistent. ([AWS Documentation][6])

Therefore:

```text
SUCCESS
≠
proof that an event
can never reappear.
```

That immediately leads to:

# Idempotency

which we'll cover deeply shortly.

---

# Part C — Async Destinations

## 12. What Happens After Processing?

For async Lambda invocation, you can configure:

```text
OnSuccess destination

and/or

OnFailure destination
```

Lambda sends an **invocation record** containing request/response details to the configured destination. ([AWS Documentation][9])

Supported async destination types currently include:

```text
SQS standard queue

SNS standard topic

Lambda function

EventBridge event bus

S3 bucket
  └── on failure only
```

([AWS Documentation][9])

---

# 13. OnSuccess

Architecture:

```text
Event
  │
  ▼
Lambda
  │
 success
  ▼
OnSuccess
  │
  ▼
EventBridge
```

Example:

```text
image-processing Lambda
      │
      ▼
success
      │
      ▼
EventBridge
      │
      ├── analytics
      ├── notification
      └── downstream workflow
```

Destinations give you richer invocation context than simply forwarding the original payload. ([AWS Documentation][9])

---

# 14. OnFailure

```text
Event
  │
  ▼
Lambda
  │
 retries exhausted
  │
  ▼
OnFailure destination
```

Possible target:

```text
SQS
SNS
S3
Lambda
EventBridge
```

according to supported destination type and condition. ([AWS Documentation][9])

---

# 15. S3 On-Failure Destination

S3 is particularly interesting because it is currently supported for:

```text
ASYNC
OnFailure
```

but not async success destinations. Lambda stores an invocation record as a JSON object under a path similar to:

```text
aws/lambda/async/
  <function>/
  YYYY/MM/DD/
  ...
```

([AWS Documentation][9])

This is useful for:

```text
large failure archives

forensics

batch reprocessing

durable historical failure storage
```

---

# 16. Destination Delivery Can Fail Too

You aren't done merely because:

```text
OnFailure=SQS
```

was configured.

The destination itself may fail due to:

```text
IAM permissions

resource policy

unsupported FIFO target

payload-size issue
```

Lambda emits:

```text
DestinationDeliveryFailures
```

for destination delivery problems. ([AWS Documentation][9])

Monitor the **failure-handling system itself**.

---

# Part D — Dead-Letter Queue vs Destination

## 17. Lambda Async DLQ

For asynchronous function invocation, you can configure a Lambda function-level dead-letter target using:

```text
SQS standard queue

or

SNS standard topic
```

FIFO variants aren't supported for the Lambda async DLQ configuration. ([AWS Documentation][9])

---

# 18. DLQ Contains Less Context

Lambda async DLQ:

```text
original event
+
error attributes
```

On-failure destination:

```text
full invocation record
+
request
+
response/error context
```

AWS explicitly notes that destinations carry richer invocation information than a traditional dead-letter queue. ([AWS Documentation][9])

---

# 19. Which Should You Prefer?

For new asynchronous designs, I generally favor:

```text
OnFailure Destination
```

when you need rich routing and debugging context.

A classic DLQ remains useful when you simply need:

```text
retain original failed event
for manual/queue-based processing
```

Both remain supported; the choice depends on downstream processing requirements. ([AWS Documentation][9])

---

# 20. Critical Distinction — SQS Event Source

If your Lambda is consuming:

```text
SQS → Lambda
```

AWS explicitly says:

> Configure the DLQ on **the SQS source queue**, not as the Lambda function's asynchronous DLQ.

That's because SQS-Lambda uses an **event source mapping**, not Lambda's async-invocation queue. ([AWS Documentation][9])

This is one of the biggest exam traps.

---

# Part E — Amazon SQS + Lambda

## 21. SQS Architecture

```text
Producer
   │
   ▼
SQS Queue
   │
   │ Lambda polls
   ▼
Event Source Mapping
   │
   ▼
Batch
   │
   ▼
Lambda
```

For SQS event-source mappings, Lambda polls the queue, sends a batch to the function synchronously, and deletes messages after successful processing. ([AWS Documentation][5])

---

# 22. Lambda Does Not “Receive a Push” from SQS

Important:

```text
SQS
does NOT directly
push every message
into your Lambda handler.
```

The:

```text
Lambda event source mapping
```

does the polling. ([AWS Documentation][5])

This matters because:

```text
batching
visibility timeout
polling
scaling
retry behavior
```

all exist between SQS and Lambda.

---

# 23. Visibility Timeout

When Lambda polls an SQS batch:

```text
messages remain in SQS
```

but become invisible for the queue's:

# Visibility Timeout

If processing succeeds:

```text
Lambda deletes them.
```

If processing fails and they aren't deleted:

```text
they become visible again
after visibility timeout.
```

([AWS Documentation][5])

---

# 24. Visibility Timeout Example

Queue:

```text
VisibilityTimeout = 60 sec
```

Lambda receives:

```text
Message A
```

at:

```text
10:00:00
```

It becomes invisible until approximately:

```text
10:01:00
```

If Lambda succeeds before then:

```text
delete message.
```

If Lambda fails:

```text
message eventually becomes
visible again.
```

This is the foundation of SQS retry behavior. ([AWS Documentation][5])

---

# 25. Why Visibility Timeout Must Exceed Processing Time

Suppose:

```text
Lambda duration
=
80 seconds

SQS visibility timeout
=
30 seconds
```

The message can become visible while the first execution is still working.

Now:

```text
Execution A
processing message

        +

Execution B
receives same message
```

You just created duplicate parallel processing.

AWS's SQS/Lambda guidance requires visibility timeout to be sized appropriately relative to function processing and retry behavior. ([AWS Documentation][10])

---

# 26. Production Safety Margin

If normal processing takes:

```text
10 seconds
```

don't automatically configure:

```text
VisibilityTimeout=11 sec
```

You need margin for:

```text
cold starts
slow downstream calls
transient retries
batch variability
```

A common production principle is:

```text
visibility timeout
comfortably greater than
worst reasonable processing time
```

rather than barely larger than average duration.

---

# 27. SQS Batch Size

Current defaults:

```text
BatchSize = 10
```

For:

```text
Standard SQS:
max 10,000

FIFO:
max 10
```

([AWS Documentation][11])

So one Lambda invocation might receive:

```text
10 messages
```

instead of:

```text
1 invocation/message.
```

---

# 28. Why Batch?

Without batching:

```text
1000 messages
=
1000 Lambda invocations
```

With batch size 10:

```text
1000 messages
≈
100 Lambda invocations
```

Potential benefits:

```text
less invocation overhead

higher throughput efficiency

lower compute overhead
```

But larger batches increase the importance of:

```text
partial failures
memory use
processing duration
```

---

# 29. Batch Window

For standard SQS queues, you can configure a batching window so Lambda waits to accumulate a larger batch before invoking the function. The standard-queue batching window can go up to five minutes; FIFO queues don't support a batching window. ([AWS Documentation][5])

Tradeoff:

```text
larger batch window
=
better batch efficiency

but

higher message latency.
```

---

# 30. Low-Traffic Batch Window Surprise

AWS notes that for a very low-traffic SQS queue, Lambda can wait as long as about:

```text
20 seconds
```

before invoking even if you've configured a batching window shorter than 20 seconds. ([AWS Documentation][5])

This is a subtle production behavior.

For ultra-low-latency sparse queues, test real behavior rather than assuming:

```text
BatchWindow=1 second
means guaranteed ≤1 second.
```

---

# Part F — The SQS Whole-Batch Failure Problem

## 31. Batch of Five

Suppose Lambda receives:

```text
Message A
Message B
Message C
Message D
Message E
```

Your code processes:

```text
A ✓
B ✓
C ✗
D ✓
E ✓
```

By default, if your invocation fails while processing the batch:

```text
THE WHOLE BATCH
```

can eventually become visible again. ([AWS Documentation][12])

Therefore:

```text
A B D E
```

may be processed twice.

---

# 32. Why This Is Expensive

Suppose each message triggers:

```text
resize a 1 GB image
```

Batch:

```text
9 success
1 failure
```

Without partial failure reporting:

```text
9 successful images
may be processed again.
```

At scale that creates:

```text
wasted Lambda compute

duplicate downstream work

duplicate writes

cost

latency
```

---

# 33. Partial Batch Responses

Solution:

# `ReportBatchItemFailures`

Your event source mapping is configured so the function can tell Lambda:

```text
Only message C failed.
```

Then successfully processed messages don't all need to be retried merely because one item failed. ([AWS Documentation][12])

---

# 34. Partial Response Shape

Conceptually:

```json
{
  "batchItemFailures": [
    {
      "itemIdentifier": "message-c-id"
    }
  ]
}
```

The failed message identifier tells Lambda which record should become eligible for retry rather than treating every item as failed. ([AWS Documentation][13])

---

# 35. Enable It on the Event Source Mapping

Returning that JSON from your handler is **not enough**.

You must explicitly configure:

```text
FunctionResponseTypes =
ReportBatchItemFailures
```

on the event source mapping. ([AWS Documentation][12])

CLI:

```bash
aws lambda update-event-source-mapping \
  --uuid "<EVENT_SOURCE_MAPPING_UUID>" \
  --function-response-types "ReportBatchItemFailures"
```

---

# 36. Important Exception Handling Rule

When using SQS partial responses:

```text
if your handler throws
an uncaught exception
```

Lambda treats the **entire batch** as failed. ([AWS Documentation][12])

Therefore batch processors should usually catch per-record failures and build the partial failure response deliberately.

---

# 37. Node.js Partial Batch Example

```javascript
export const handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      await processMessage(record);
    } catch (error) {
      console.error("Message failed", {
        messageId: record.messageId,
        error: error.message
      });

      failures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return {
    batchItemFailures: failures
  };
};
```

Architecture:

```text
A ✓
B ✓
C ✗
D ✓
E ✓
   │
   ▼
return C only
   │
   ▼
C retried
```

This follows Lambda's SQS partial-batch response model. ([AWS Documentation][12])

---

# 38. Powertools Batch Processor

AWS recommends considering the:

```text
Powertools for AWS Lambda
Batch Processor
```

to handle partial batch response patterns automatically. Current Lambda documentation lists availability for Python, TypeScript, Java, and .NET. ([AWS Documentation][12])

This reduces custom boilerplate around:

```text
looping

error tracking

batchItemFailures

FIFO behavior
```

---

# Part G — SQS Dead-Letter Queue

## 39. Poison Message

Suppose message:

```json
{
  "orderId": null,
  "brokenData": "..."
}
```

fails **every time**.

Without a maximum receive policy:

```text
receive
fail
visible again
receive
fail
visible again
...
```

This is a:

# Poison Message

---

# 40. Redrive Policy

SQS can define:

```text
source queue
     │
     ▼
maxReceiveCount exceeded
     │
     ▼
DLQ
```

Example:

```text
maxReceiveCount = 5
```

After repeated receives/failures, SQS moves the message to the configured dead-letter queue according to the queue's redrive policy. Lambda documentation recommends an SQS DLQ for repeatedly failing SQS-triggered messages. ([AWS Documentation][9])

---

# 41. The DLQ Is Not a Trash Can

Bad:

```text
DLQ contains 1 million messages
and nobody monitors it.
```

Good:

```text
DLQ
 │
 ├── CloudWatch alarm
 ├── investigation
 ├── root-cause classification
 ├── fix
 └── controlled redrive/reprocessing
```

A DLQ without operational ownership is merely delayed data loss.

---

# 42. Good DLQ Alarm

Monitor:

```text
ApproximateNumberOfMessagesVisible
```

for the DLQ.

If:

```text
> 0
```

unexpectedly:

```text
alert operations.
```

Then correlate:

```text
message ID
receive count
Lambda logs
trace/request ID
business key
```

---

# Part H — Standard vs FIFO SQS

## 43. Standard Queue

Standard SQS prioritizes:

```text
very high throughput
```

with:

```text
at-least-once delivery
```

semantics.

Lambda explicitly warns that SQS event-source mappings can process records more than once, so consumers should be idempotent. ([AWS Documentation][5])

---

# 44. FIFO Queue

FIFO gives ordering semantics based on:

# Message Group ID

Messages belonging to the same group are delivered in order. Lambda preserves ordering for each message group. ([AWS Documentation][14])

Example:

```text
Group:
customer-123

message 1
message 2
message 3
```

must preserve ordering.

---

# 45. FIFO Concurrency Comes from Groups

Suppose queue contains only:

```text
MessageGroupId=customer-123
```

for every message.

You have effectively created:

```text
one ordered lane.
```

Even if Lambda can scale to huge concurrency, the ordering requirement limits parallelism.

AWS states that FIFO Lambda concurrency is limited by either the number of message groups or configured maximum concurrency, whichever is lower. ([AWS Documentation][14])

---

# 46. Example

Message groups:

```text
customer-A
customer-B
customer-C
customer-D
```

Potential parallel ordered lanes:

```text
4
```

If:

```text
MaximumConcurrency=100
```

you still only have up to roughly:

```text
4 concurrent groups
```

given four active message group IDs. ([AWS Documentation][14])

---

# 47. FIFO Partial Failure Rule

AWS says that with FIFO queues and partial batch responses, your function should stop processing after the first failure and return:

```text
failed record
+
remaining unprocessed records
```

as failures so ordering is preserved. ([AWS Documentation][12])

Example:

```text
A ✓
B ✗
C not processed
D not processed
```

Return:

```text
B
C
D
```

not:

```text
B only
```

because processing C/D before B succeeds could violate ordered semantics.

---

# Part I — SQS Scaling

## 48. Standard On-Demand Polling

For standard queues in default scaling mode, Lambda begins with:

```text
5 batches
5 concurrent function invocations
```

when messages are available. ([AWS Documentation][14])

If backlog remains, Lambda can add up to:

```text
300 more concurrent invokes/minute
```

for the event-source mapping, up to the documented event-source mapping scaling limit. ([AWS Documentation][14])

---

# 49. Default Event-Source Mapping Ceiling

AWS currently documents a default maximum of:

```text
1,250
```

simultaneous function invocations from a single standard SQS event source mapping, subject also to the account/function concurrency available. ([AWS Documentation][14])

If your account concurrency quota is only:

```text
1000
```

that account quota may become the earlier constraint.

---

# 50. Low-Traffic Optimization

When traffic becomes low, the standard SQS poller can scale down and optimize as low as:

```text
2 concurrent pollers
```

to reduce SQS receive calls.

AWS notes that this optimization is not available when SQS maximum concurrency is explicitly configured. ([AWS Documentation][14])

---

# 51. SQS Maximum Concurrency

SQS event-source mappings can define:

```text
MaximumConcurrency
```

to limit how many concurrent Lambda executions **this queue mapping** can consume. ([AWS Documentation][14])

Example:

```text
Queue A
MaximumConcurrency=20

Queue B
MaximumConcurrency=100

        │
        ▼
same Lambda function
```

Now Queue A can't monopolize all concurrency.

---

# 52. Reserved vs SQS Maximum Concurrency

These are different controls.

```text
Function Reserved Concurrency
=
whole-function ceiling + reservation


SQS Mapping Maximum Concurrency
=
ceiling for that specific queue mapping
```

AWS warns not to configure the sum of event-source maximum concurrency above the function's reserved concurrency, otherwise throttling may occur. ([AWS Documentation][14])

---

# 53. Example

Function:

```text
ReservedConcurrency = 100
```

Mappings:

```text
Orders queue = max 60

Invoices queue = max 30
```

Total max:

```text
90
```

leaves some room.

Bad configuration:

```text
Orders=80
Invoices=80

Function Reserved=100
```

Both event sources may demand:

```text
160
```

against a function capped at:

```text
100
```

creating throttling. ([AWS Documentation][14])

---

# Part J — 2026 SQS Provisioned Poller Mode

## 54. Newer High-Throughput Mode

Lambda now supports:

# Provisioned Mode

for SQS event-source mappings.

Instead of relying entirely on automatically created standard pollers, you configure dedicated event pollers with minimum and maximum values. AWS says provisioned mode offers faster scaling and substantially higher potential processing capacity than standard mode, at additional cost. ([AWS Documentation][14])

---

# 55. Poller Configuration

Current allowed provisioned values:

```text
MinimumPollers:
2–200

MaximumPollers:
2–2000
```

Each provisioned poller can handle up to:

```text
1 MB/sec

10 concurrent invokes

10 SQS polling API calls/sec
```

subject to workload characteristics. ([AWS Documentation][5])

---

# 56. Provisioned Scaling

AWS currently describes provisioned SQS event-source mappings as scaling up to:

```text
1,000 additional concurrent invokes/minute
```

and supporting up to:

```text
20,000 concurrent invokes
```

through the maximum poller configuration. ([AWS Documentation][5])

This is a major change from older Lambda/SQS training.

---

# 57. Standard vs Provisioned Mode

```text
STANDARD
│
├── Lambda dynamically manages pollers
├── cheaper/simpler
├── up to default ESM scaling range
└── good for most workloads


PROVISIONED
│
├── dedicated pollers
├── min/max poller controls
├── faster scaling
├── much larger throughput potential
└── additional cost
```

AWS recommends provisioned mode for workloads with strict/consistent low-latency throughput requirements. ([AWS Documentation][5])

---

# 58. Provisioned Poller Example

```bash
aws lambda update-event-source-mapping \
  --uuid "<UUID>" \
  --provisioned-poller-config \
  '{"MinimumPollers":5,"MaximumPollers":100}'
```

AWS exposes `ProvisionedPollerConfig` on the event-source mapping for this mode. ([AWS Documentation][5])

---

# 59. Maximum Concurrency and Provisioned Pollers Are Mutually Exclusive

Important:

```text
SQS MaximumConcurrency
```

and:

```text
Provisioned Mode
```

cannot be enabled on the same mapping at the same time. ([AWS Documentation][14])

In provisioned mode, your poller min/max configuration controls scaling instead.

---

# Part K — Event Filtering

## 60. Don't Invoke Lambda for Data You Will Immediately Ignore

Bad:

```text
SQS
 │
 ▼
100 million messages
 │
 ▼
Lambda invoked 100 million times
 │
 ▼
handler:
if type != "PAYMENT":
   return
```

You paid compute overhead to discover:

```text
nothing needs doing.
```

Use:

# Event Filtering

on supported event-source mappings. ([AWS Documentation][15])

---

# 61. Filtering Happens Before Your Function

```text
Source records
      │
      ▼
Lambda event filter
      │
   ┌──┴──────────┐
 matches       no match
   │              │
   ▼              X
Function        discarded
invoked          from ESM
```

AWS evaluates filter patterns before sending matching records to your function. ([AWS Documentation][15])

---

# 62. SQS Filtering

For SQS, event-source filtering operates on:

```text
body
```

of the SQS message. ([AWS Documentation][16])

Example message:

```json
{
  "type": "PAYMENT",
  "amount": 500
}
```

Filter concept:

```json
{
  "body": {
    "type": ["PAYMENT"]
  }
}
```

Now your payment function receives only payment messages.

---

# 63. Multiple Filters

By default, an event-source mapping can define up to:

```text
5
```

filters.

The filters are logically:

```text
OR
```

so matching any filter causes the record to pass. ([AWS Documentation][15])

---

# 64. Filter Criteria Can Be KMS Encrypted

If your filter definition itself contains sensitive information, Lambda allows event-source filter criteria to be encrypted with your own KMS key. Viewing decrypted criteria via API then requires:

```text
kms:Decrypt
```

permission. ([AWS Documentation][15])

Better principle:

```text
avoid sensitive secrets
in filter expressions
when possible.
```

---

# Part L — Idempotency

## 65. What Is Idempotency?

An operation is idempotent when applying the same logical request multiple times has the same intended business result as applying it once.

Example:

```text
Process order ORD-123
```

called three times should result in:

```text
ONE order processed
```

not:

```text
three charges
three shipments
three emails
```

Lambda's SQS and asynchronous documentation both explicitly warn that duplicate delivery can occur and recommend idempotent processing. ([AWS Documentation][5])

---

# 66. Idempotency Key

Choose a stable unique business/event identifier:

```text
orderId

paymentId

eventId

transactionId
```

Example:

```json
{
  "eventId": "EVT-92af...",
  "orderId": "ORD-1001"
}
```

---

# 67. Idempotency Table

A common design:

```text
Lambda
   │
   ▼
DynamoDB
Idempotency table
   │
   ├── eventId
   ├── status
   ├── result
   └── expiration
```

Before processing:

```text
Does eventId exist?
        │
   ┌────┴─────┐
   ▼          ▼
  YES         NO
   │           │
   ▼           ▼
return       lock/create
previous      record
result          │
                ▼
             process
```

---

# 68. Atomicity Matters

Bad:

```text
1. Check DynamoDB:
   event not found

2. Process payment

3. Write idempotency record
```

Two concurrent duplicates could both pass step 1.

Better pattern:

```text
conditional write
```

such as:

```text
insert only if key
does not already exist
```

before performing the side effect.

This is a distributed-systems inference from the at-least-once delivery behavior documented by Lambda/SQS. ([AWS Documentation][5])

---

# 69. Don't Use SQS Message ID Blindly as the Business Key

Sometimes a retried/recreated business event can arrive with:

```text
different SQS message IDs
```

even though it represents the same logical transaction.

Prefer a stable producer/business ID such as:

```text
orderId
transactionId
domain eventId
```

when your architecture provides one.

---

# 70. Idempotency Is Not Just “Duplicate Detection”

It also means:

```text
retrying after partial failure
must be safe.
```

Example:

```text
1. Charge card ✓
2. Save order ✗
```

Retry:

```text
Charge card AGAIN?
```

A robust architecture must make the external effect itself idempotent or record enough state to resume correctly.

---

# Part M — Kinesis Data Streams + Lambda

## 71. Stream Model

Kinesis isn't simply:

```text
queue with messages.
```

It is an ordered stream partitioned into:

# Shards

```text
Kinesis Stream

Shard 1:
A → B → C → D

Shard 2:
E → F → G → H
```

Lambda uses an event-source mapping to read records and invoke your function synchronously with batches. Each batch comes from a shard. ([AWS Documentation][17])

---

# 72. Ordering

Within a shard:

```text
records are ordered.
```

Lambda processes records in a shard in order by default and stops moving forward in that shard when a batch fails. ([AWS Documentation][17])

This is very different from SQS standard queues.

---

# 73. Poison Record in a Stream

Suppose:

```text
Shard:

A ✓
B ✓
C ✗
D
E
F
```

If C keeps failing:

```text
D E F
```

may be blocked behind it because Lambda must preserve ordered shard progress. AWS explicitly notes that errors can halt additional processing of a Kinesis shard. ([AWS Documentation][17])

This is the:

# Poison Pill / Shard Blocking Problem

---

# 74. Stream Batch Checkpoint

By default for a stream batch, Lambda advances the checkpoint only after the entire batch succeeds.

If the batch fails:

```text
batch retried
```

according to configured retry/age behavior. ([AWS Documentation][18])

---

# 75. Kinesis Partial Batch Responses

Kinesis also supports:

```text
ReportBatchItemFailures
```

so you can tell Lambda which record failed and reduce unnecessary reprocessing. ([AWS Documentation][18])

However, AWS notes that partial success doesn't guarantee that every successful record can **never** be retried. ([AWS Documentation][18])

Again:

```text
idempotency remains necessary.
```

---

# 76. Kinesis Batch Size and Window

Lambda reads Kinesis records until:

```text
batch full

or

batch window expires

or

6 MB invocation payload limit reached
```

before invoking. The batch window can be configured up to five minutes. ([AWS Documentation][17])

---

# 77. Kinesis Standard Iterator

With standard polling:

```text
Lambda polls each shard
at a base rate of once/sec
```

and shares shard read throughput with other consumers. ([AWS Documentation][17])

---

# 78. Enhanced Fan-Out

Kinesis Enhanced Fan-Out provides a dedicated consumer connection per shard so the Lambda consumer doesn't share the same read-throughput mechanism with ordinary standard-iterator consumers. AWS uses HTTP/2 long-lived connections for the enhanced consumer path. ([AWS Documentation][17])

Think:

```text
Standard
=
shared read capacity


Enhanced Fan-Out
=
dedicated consumer path
```

---

# Part N — Stream Error Controls

## 79. Maximum Retry Attempts

For Kinesis/DynamoDB event-source mappings, Lambda supports:

```text
MaximumRetryAttempts
```

with default:

```text
-1
=
effectively retry until
record expires from source
```

unless configured otherwise. The parameter can be bounded with a finite retry count. ([AWS Documentation][19])

---

# 80. Maximum Record Age

You can also say:

```text
Don't keep retrying
a record older than X.
```

For DynamoDB Streams, the source itself retains stream records for about:

```text
24 hours
```

and the Lambda mapping can apply `MaximumRecordAgeInSeconds` within the supported bounds. ([AWS Documentation][20])

---

# 81. Why Infinite Retry Can Be Dangerous

Suppose one bad record fails permanently.

Defaults can mean:

```text
retry
retry
retry
retry
...
```

until the stream record expires.

AWS warns that a bad DynamoDB Streams record with default failure behavior can block the affected shard for as long as the source retains it—up to about one day. ([AWS Documentation][21])

Production designs should usually deliberately choose:

```text
retry attempts

record age

failure destination
```

rather than relying blindly on infinite/default retry semantics.

---

# 82. Bisect Batch on Function Error

For Kinesis and DynamoDB Streams, you can enable:

```text
BisectBatchOnFunctionError = true
```

If a batch fails:

```text
[ A B C D E F G H ]
```

Lambda splits:

```text
[ A B C D ]   [ E F G H ]
```

and retries smaller subsets. ([AWS Documentation][22])

---

# 83. Why Bisect?

Suppose only:

```text
F
```

is malformed.

Without bisect:

```text
8 records repeatedly fail together.
```

With bisect:

```text
8
↓
4 + 4
↓
2 + 2
↓
1 + 1
```

You isolate the poison record more efficiently while preserving stream semantics.

---

# 84. Partial Failure vs Bisect

They solve related but different problems.

```text
ReportBatchItemFailures
=
your function tells Lambda
which record failed.


BisectBatchOnFunctionError
=
Lambda automatically splits
failed batches.
```

They can be used as complementary stream error-management tools. ([AWS Documentation][18])

---

# 85. On-Failure Destination for Streams

For Kinesis and DynamoDB event-source mappings, you can configure an:

```text
OnFailure destination
```

after retries/record-age handling is exhausted. AWS currently supports destinations such as SNS, SQS, S3, and—in applicable event-source mapping scenarios—Kafka. ([AWS Documentation][21])

---

# 86. Why S3 Is Powerful for Stream Failures

For DynamoDB stream failures, AWS notes that an S3 destination receives:

```text
metadata
+
the entire invocation record
```

whereas some other destination types primarily receive invocation metadata. ([AWS Documentation][21])

That makes S3 valuable when:

```text
you need original failed data
for later reconstruction/replay.
```

---

# Part O — DynamoDB Streams

## 87. DynamoDB Change Data Capture

When DynamoDB Streams is enabled:

```text
PutItem
UpdateItem
DeleteItem
```

can generate stream records.

```text
DynamoDB
   │
   ▼
DynamoDB Stream
   │
   ▼
Lambda event source mapping
   │
   ▼
Function
```

Lambda uses DynamoDB Streams to trigger work after table changes. ([AWS Documentation][23])

---

# 88. Typical Uses

Examples:

```text
User created
  │
  ▼
send welcome workflow


Order updated
  │
  ▼
update search index


Item deleted
  │
  ▼
audit/archive action
```

This is a classic serverless event-driven architecture.

---

# 89. DynamoDB Stream Batch Defaults

Current Lambda DynamoDB event-source mapping defaults include:

```text
BatchSize = 100

ParallelizationFactor = 1

BisectBatchOnFunctionError = false

MaximumRetryAttempts = -1

MaximumRecordAge = -1
```

with configurable bounds for these options. ([AWS Documentation][20])

---

# 90. Parallelization Factor

Streams normally process a shard with one concurrent batch lane.

You can raise:

```text
ParallelizationFactor
```

up to:

```text
10
```

for DynamoDB Streams, letting Lambda process multiple batches from a shard concurrently while preserving ordering at the appropriate partition-key level. ([AWS Documentation][20])

This can increase throughput when:

```text
one shard becomes a bottleneck.
```

---

# 91. Parallelism Isn't Free

Increasing parallelization can increase:

```text
function concurrency

database/API pressure

out-of-order complexity across independent keys

cost
```

So:

```text
more parallel
≠
automatically better.
```

Choose it based on downstream capacity.

---

# 92. DynamoDB Partial Batch Reporting

Like Kinesis:

```text
DynamoDB Streams
```

supports:

```text
ReportBatchItemFailures
```

but you must explicitly enable it on the event-source mapping. ([AWS Documentation][24])

---

# 93. DynamoDB Event Filtering

For DynamoDB Streams, Lambda event-source filtering evaluates:

```text
dynamodb
```

inside the stream record. ([AWS Documentation][25])

For example:

```text
only invoke function
when Status becomes PAID
```

instead of invoking on every table update.

---

# Part P — S3, SNS and EventBridge Push Sources

## 94. S3 Event

Example:

```text
Object uploaded
     │
     ▼
S3 event notification
     │
     ▼
Lambda
```

Typical use:

```text
image upload
→ thumbnail generation
```

Be careful about recursive designs:

```text
S3 bucket A
→ Lambda
→ writes back to same prefix
→ Lambda
→ writes
→ Lambda
...
```

Use distinct prefixes/buckets or filters to avoid event loops.

---

# 95. SNS → Lambda

SNS invokes Lambda asynchronously, and there are two potential reliability layers:

```text
SNS
│
│ attempts to deliver
▼
Lambda async API
│
▼
Lambda async queue
│
▼
function
```

SNS has its own delivery retry behavior if Lambda can't be reached or rejects delivery, while Lambda performs asynchronous function retry behavior after it accepts the event. ([AWS Documentation][3])

This is important:

```text
PRODUCER DELIVERY RETRY

and

LAMBDA FUNCTION RETRY
```

can both exist.

---

# 96. EventBridge → Lambda

EventBridge invokes Lambda rule targets asynchronously. EventBridge also has target-delivery retries and can use an EventBridge target DLQ if it cannot deliver an event successfully to the target. ([AWS Documentation][26])

Then, once Lambda accepts the asynchronous request:

```text
Lambda's async queue/error model
```

becomes relevant.

Again there can be multiple reliability layers.

---

# 97. Draw the Failure Boundary

For EventBridge:

```text
EventBridge
    │
    │ delivery
    ▼
Lambda service
    │
    │ accepted?
    ▼
Lambda async queue
    │
    ▼
function
```

Failure 1:

```text
EventBridge cannot deliver
to Lambda.
```

Handle through:

```text
EventBridge retry/DLQ.
```

Failure 2:

```text
Lambda accepts event
but handler fails.
```

Handle through:

```text
Lambda async retries
and Lambda destination/DLQ.
```

That difference is essential in production incident response. ([AWS Documentation][27])

---

# Part Q — EventBridge Pipes

## 98. Pipes Can Sometimes Replace Glue Lambda Functions

Suppose architecture:

```text
SQS
 │
 ▼
Lambda
 │
does simple JSON transform
 │
 ▼
EventBridge
```

You may instead evaluate:

```text
EventBridge Pipes
```

which can connect supported sources to targets with optional filtering, transformation, and enrichment. AWS specifically points SQS/Lambda users toward Pipes when the goal is routing/enrichment rather than necessarily executing a dedicated processing Lambda. ([AWS Documentation][5])

---

# 99. Pipes Architecture

```text
Source
  │
  ▼
Filter
  │
  ▼
Transform
  │
  ▼
Optional Enrichment
  │
  ▼
Target
```

Examples:

```text
SQS → Step Functions

Kinesis → EventBridge

DynamoDB Stream → API destination
```

where supported.

---

# Part R — Idempotent Payment Example

## 100. Bad Architecture

```text
SQS
 │
 ▼
Payment Lambda
 │
 ▼
Stripe/payment provider
 │
 ▼
charge customer
```

Message redelivered:

```text
charge again.
```

Catastrophic.

---

# 101. Better Architecture

Event:

```json
{
  "paymentId": "PAY-93a4...",
  "orderId": "ORD-1001",
  "amount": 5000
}
```

Lambda:

```text
1. Conditional create:
   PaymentId=PAY-93a4

2. If already exists:
   return previous result

3. Call provider using
   provider idempotency key

4. Save success/failure

5. Return
```

Now:

```text
duplicate Lambda invocation
```

doesn't automatically create:

```text
duplicate payment.
```

---

# 102. State Machine for Idempotency

```text
                 EVENT

                   │
                   ▼
             Check/claim key
                   │
       ┌───────────┼────────────┐
       ▼           ▼            ▼
    COMPLETED    IN_PROGRESS    NEW
       │           │            │
       ▼           ▼            ▼
 return cached   safely      create lock
 result          defer/        │
                 retry         ▼
                              work
                               │
                       ┌───────┴───────┐
                       ▼               ▼
                    success          failure
                       │               │
                       ▼               ▼
                  COMPLETED      release/expire
```

That is a far more durable model than:

```text
"Hopefully SQS only sends once."
```

---

# Part S — Backpressure

## 103. Serverless Doesn't Mean Infinite Downstream Capacity

Imagine:

```text
SQS backlog:
1 million messages

Lambda:
scales rapidly

Database:
supports 200 connections
```

Bad:

```text
queue backlog
    │
    ▼
Lambda scales huge
    │
    ▼
database overloaded
    │
    ▼
Lambda failures
    │
    ▼
messages retry
    │
    ▼
even more pressure
```

This is a:

# Retry Storm / Positive Feedback Loop

---

# 104. Add Backpressure

Controls:

```text
SQS event source MaximumConcurrency

or

function ReservedConcurrency

batch size

downstream rate limiting

connection pooling

RDS Proxy

queue buffering
```

Architecture:

```text
SQS
 │
 huge backlog
 │
 ▼
MaxConcurrency=50
 │
 ▼
Lambda
 │
≤ 50 parallel
 ▼
Database
stays healthy
```

SQS mapping maximum concurrency exists specifically to constrain how much function concurrency one queue can consume. ([AWS Documentation][14])

---

# 105. Queue Depth Is Often Healthy

People sometimes see:

```text
SQS contains 50,000 messages
```

and think:

```text
DISASTER.
```

Not necessarily.

Queues intentionally buffer load.

The important questions:

```text
How old is oldest message?

Is queue depth growing?

Are consumers keeping up?

Is processing within SLO?
```

The architecture is healthy if:

```text
producer bursts
>
temporary consumer capacity
```

and SQS safely absorbs the burst.

---

# 106. Queue Age Is Often More Important Than Queue Count

Example:

```text
Queue A:
1 million messages
oldest = 4 seconds


Queue B:
100 messages
oldest = 2 hours
```

Which is more concerning?

Probably:

```text
Queue B
```

for most near-real-time workloads.

Monitor backlog in context of:

```text
message age
processing SLO
throughput
```

not count alone.

---

# Part T — Terraform SQS Architecture

## 107. Source Queue + DLQ

```hcl
resource "aws_sqs_queue" "orders_dlq" {
  name = "orders-dlq"
}

resource "aws_sqs_queue" "orders" {
  name = "orders"

  visibility_timeout_seconds = 120

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 5
  })
}
```

The current HashiCorp AWS provider exposes SQS queue visibility timeout and redrive configuration for this pattern. ([Terraform Registry][28])

---

# 108. Event Source Mapping

```hcl
resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.orders.arn

  batch_size = 10

  function_response_types = [
    "ReportBatchItemFailures"
  ]
}
```

The current Terraform AWS provider supports event-source mappings and the `function_response_types` setting used for Lambda checkpointing/partial-batch response behavior. ([Terraform Registry][29])

---

# 109. Event-Source Maximum Concurrency

Conceptual current provider configuration:

```hcl
resource "aws_lambda_event_source_mapping" "orders" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.orders.arn

  batch_size = 10

  scaling_config {
    maximum_concurrency = 50
  }
}
```

AWS's underlying Lambda event-source mapping API exposes this SQS-only maximum concurrency control. ([AWS Documentation][14])

---

# 110. Async Lambda Destination Terraform

For an asynchronously invoked function:

```hcl
resource "aws_lambda_function_event_invoke_config" "processor" {
  function_name = aws_lambda_function.processor.function_name

  maximum_event_age_in_seconds = 3600
  maximum_retry_attempts       = 2

  destination_config {
    on_failure {
      destination = aws_sqs_queue.failure_events.arn
    }

    on_success {
      destination = aws_cloudwatch_event_bus.processed.arn
    }
  }
}
```

The current Terraform AWS provider manages Lambda asynchronous invocation retry/destination settings through `aws_lambda_function_event_invoke_config`. ([Terraform Registry][30])

---

# Part U — SQS CLI Hands-On Lab

## 111. Goal

Build:

```text
Producer
   │
   ▼
orders-queue
   │
   ▼
Lambda
   │
 partial batch response
   │
   ├── good messages → delete
   │
   └── poison message
           │
        retry
           │
           ▼
           DLQ
```

---

# 112. Create DLQ

```bash
aws sqs create-queue \
  --queue-name orders-dlq \
  --region ap-south-1
```

Get ARN:

```bash
aws sqs get-queue-attributes \
  --queue-url "<DLQ_URL>" \
  --attribute-names QueueArn \
  --region ap-south-1
```

---

# 113. Create Source Queue

Create with a visibility timeout that comfortably exceeds Lambda processing duration:

```bash
aws sqs create-queue \
  --queue-name orders \
  --attributes VisibilityTimeout=120 \
  --region ap-south-1
```

SQS visibility timeout controls how long received messages remain hidden from competing consumers while processing occurs. ([AWS Documentation][5])

---

# 114. Configure DLQ Redrive

Conceptually:

```json
{
  "deadLetterTargetArn": "<DLQ_ARN>",
  "maxReceiveCount": "5"
}
```

Apply as the source queue's redrive policy.

Remember:

```text
THIS DLQ BELONGS
TO THE SQS SOURCE.
```

Not to Lambda's asynchronous invocation configuration. ([AWS Documentation][9])

---

# 115. Lambda Code

```javascript
export const handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      const payload = JSON.parse(record.body);

      console.log(JSON.stringify({
        messageId: record.messageId,
        payload
      }));

      if (payload.fail === true) {
        throw new Error("Intentional poison message");
      }

      await processOrder(payload);

    } catch (error) {
      console.error(JSON.stringify({
        messageId: record.messageId,
        error: error.message
      }));

      failures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return {
    batchItemFailures: failures
  };
};

async function processOrder(order) {
  console.log("Processing:", order.orderId);
}
```

---

# 116. Create Event Source Mapping

```bash
aws lambda create-event-source-mapping \
  --function-name orders-processor \
  --event-source-arn "<ORDERS_QUEUE_ARN>" \
  --batch-size 10 \
  --function-response-types ReportBatchItemFailures \
  --region ap-south-1
```

The Lambda/SQS mapping must be configured for `ReportBatchItemFailures` before partial failure responses are honored. ([AWS Documentation][12])

---

# 117. Send Good Messages

```bash
aws sqs send-message \
  --queue-url "<ORDERS_QUEUE_URL>" \
  --message-body \
  '{"orderId":"ORD-001","fail":false}' \
  --region ap-south-1
```

And:

```bash
aws sqs send-message \
  --queue-url "<ORDERS_QUEUE_URL>" \
  --message-body \
  '{"orderId":"ORD-002","fail":false}' \
  --region ap-south-1
```

These should process successfully and be deleted by Lambda's SQS integration after successful batch handling. ([AWS Documentation][5])

---

# 118. Send Poison Message

```bash
aws sqs send-message \
  --queue-url "<ORDERS_QUEUE_URL>" \
  --message-body \
  '{"orderId":"ORD-BROKEN","fail":true}' \
  --region ap-south-1
```

Observe:

```text
receive
fail
hidden
visible
receive
fail
...
```

until the queue redrive threshold causes it to move to the DLQ.

---

# 119. Inspect Receive Count

Inside the Lambda SQS event, AWS includes:

```text
ApproximateReceiveCount
```

among message attributes. ([AWS Documentation][5])

Useful log:

```javascript
console.log({
  messageId: record.messageId,
  receiveCount:
    record.attributes.ApproximateReceiveCount
});
```

This helps determine:

```text
Is this the first failure
or the fifth?
```

---

# 120. Inspect DLQ

```bash
aws sqs receive-message \
  --queue-url "<DLQ_URL>" \
  --attribute-names All \
  --message-attribute-names All \
  --region ap-south-1
```

Don't automatically delete it.

First classify:

```text
bad data?

bug?

dependency outage?

schema mismatch?

old producer version?
```

Fix the root cause before redriving.

---

# Part V — Observability

## 121. Lambda Metrics

For queue/stream consumers, monitor:

```text
Errors

Duration

Throttles

ConcurrentExecutions
```

and Lambda event-source mapping/async signals where applicable. Lambda now also exposes event-source-related metrics such as failed invocation counts and filtered event counts. ([AWS Documentation][8])

---

# 122. SQS Metrics

At minimum observe:

```text
ApproximateNumberOfMessagesVisible

ApproximateNumberOfMessagesNotVisible

ApproximateAgeOfOldestMessage
```

along with DLQ message count.

The combination answers:

```text
Is backlog growing?

Are workers processing?

Are messages becoming stale?

Are poison messages accumulating?
```

---

# 123. Event Filtering Metric

For mappings configured with filters, Lambda provides:

```text
FilteredOutEventCount
```

to show records excluded by the filter. ([AWS Documentation][8])

Useful when:

```text
Lambda suddenly receives zero records.
```

Maybe:

```text
producer stopped
```

or:

```text
filter accidentally excludes everything.
```

---

# 124. Provisioned Poller Metric

When SQS provisioned polling is enabled, AWS documents:

```text
ProvisionedPollers
```

for observing poller usage. ([AWS Documentation][5])

Pair it with:

```text
queue age

queue depth

Lambda duration

concurrency
```

to tune min/max pollers.

---

# Part W — Troubleshooting Scenarios

## 125. SQS Messages Are Processed Twice

Likely possibilities:

```text
normal at-least-once delivery

Lambda processing exceeded visibility timeout

batch failed and entire batch retried

consumer side effect isn't idempotent
```

Lambda explicitly warns duplicate SQS processing can occur and requires consumers to be idempotent. ([AWS Documentation][5])

---

# 126. Good Messages Keep Repeating Because One Message Fails

Cause:

```text
whole batch failure.
```

Fix:

```text
ReportBatchItemFailures

+
per-message error handling.
```

([AWS Documentation][12])

---

# 127. FIFO Queue Stops Moving

Check:

```text
poison message
in active message group.
```

AWS waits for retries on affected FIFO group messages before receiving more from the same group, preserving order. ([AWS Documentation][14])

Inspect:

```text
receive count

DLQ configuration

batch response logic
```

---

# 128. SQS Queue Growing, Lambda Not Scaling Enough

Check:

```text
function reserved concurrency

account concurrency

event-source maximum concurrency

function duration

throttles

provisioned/on-demand poller mode

downstream latency
```

The SQS event-source mapping's own scaling configuration can become a limiter independently of the function's broader concurrency settings. ([AWS Documentation][14])

---

# 129. Lambda Throttling Causes SQS Backlog

Don't just increase Lambda concurrency.

Ask:

```text
Can downstream system
actually accept more load?
```

If not:

```text
increasing concurrency
can make incident worse.
```

The queue is providing useful backpressure.

---

# 130. Async Function Erroring Three Times

That is expected default behavior for asynchronous function errors:

```text
original
+
two retries.
```

([AWS Documentation][6])

Configure:

```text
maximum retry attempts
```

if a different policy is required.

---

# 131. Async Events Are Six Hours Old

Inspect:

```text
concurrency exhaustion

throttling

AsyncEventAge

processing capacity

regional/system failures
```

The default async event retention/retry window for throttling/system errors can extend up to six hours. ([AWS Documentation][6])

---

# 132. EventBridge Says Delivered, Lambda Business Operation Failed

Possible architecture:

```text
EventBridge successfully delivered
to Lambda service

but

Lambda handler later failed.
```

The EventBridge target DLQ does not necessarily represent handler failure after Lambda has accepted the async invocation.

Check:

```text
Lambda async destinations

Lambda errors

function logs

AsyncEventAge
```

because delivery and function execution are separate reliability boundaries. ([AWS Documentation][26])

---

# 133. Kinesis Shard Has Growing Lag

Check:

```text
function errors

slow duration

poison record

parallelization factor

shard count

batch configuration

IteratorAge
```

Kinesis stream processing stops advancing normally on an affected shard when function errors block ordered processing. ([AWS Documentation][17])

Potential fixes:

```text
partial batch responses

bisect-on-error

bounded retries

failure destination

more shards

higher safe parallelization
```

---

# 134. DynamoDB Stream Appears Frozen for Hours

Likely:

```text
bad record
+
default infinite retry behavior.
```

AWS specifically warns a bad DynamoDB stream record can block a shard for up to the stream's approximately one-day retention period with default retry settings. ([AWS Documentation][21])

Configure:

```text
maximum retry attempts

maximum record age

on-failure destination
```

deliberately.

---

# Part X — Certification / Interview Questions

## 135. Question

> SQS invokes Lambda and one record in a batch fails. How do you prevent all successful records being retried?

Answer:

```text
Enable
ReportBatchItemFailures

and return
partial batch responses.
```

([AWS Documentation][12])

---

# 136. Question

> Where should the DLQ be configured for SQS → Lambda?

Answer:

```text
On the SQS source queue
using its redrive policy.
```

Not the Lambda asynchronous DLQ. ([AWS Documentation][9])

---

# 137. Question

> A function is invoked asynchronously and throws an exception. Default retries?

Answer:

```text
Two retries
after the original attempt.
```

([AWS Documentation][6])

---

# 138. Question

> EventBridge cannot deliver an event to its Lambda target. What helps prevent loss?

Answer:

```text
EventBridge target
retry policy

+
EventBridge DLQ
```

([AWS Documentation][27])

---

# 139. Question

> EventBridge delivered to Lambda successfully, but Lambda later fails processing.

Think:

```text
Lambda asynchronous
error handling

destination/DLQ
```

rather than EventBridge's delivery DLQ alone. ([AWS Documentation][9])

---

# 140. Question

> Need to protect RDS from an SQS backlog causing thousands of Lambda connections.

Think:

```text
SQS MaximumConcurrency

and/or

Lambda ReservedConcurrency
```

plus sensible database connection management. ([AWS Documentation][14])

---

# 141. Question

> Need strict ordering per customer but parallel processing across customers.

Think:

```text
SQS FIFO

MessageGroupId
=
customerId
```

Different groups provide parallel ordered lanes; messages within one group remain ordered. ([AWS Documentation][14])

---

# 142. Question

> One malformed Kinesis record is blocking a shard.

Consider:

```text
partial batch response

BisectBatchOnFunctionError

bounded retries

maximum record age

OnFailure destination
```

([AWS Documentation][18])

---

# 143. Question

> Lambda is invoked for millions of SQS events and immediately ignores 90%.

Think:

```text
Event Source Mapping
FilterCriteria
```

so nonmatching records don't need a function invocation. ([AWS Documentation][15])

---

# 144. Question

> High-throughput SQS workload needs much faster, more predictable poller scaling beyond standard mode.

Evaluate:

```text
SQS event-source mapping
Provisioned Mode
```

with dedicated `MinimumPollers`/`MaximumPollers`. ([AWS Documentation][5])

---

# Part Y — The Permanent Failure-Handling Decision Tree

```text
                   LAMBDA FAILED
                        │
                        ▼
              HOW WAS IT INVOKED?
                        │
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
   SYNCHRONOUS      ASYNCHRONOUS      ESM/POLLER
        │               │                │
        ▼               ▼                ▼
Caller decides      Lambda async      SOURCE-specific
retry               queue/retries     retry semantics
                        │                │
                        ▼        ┌───────┼────────┐
                  Destination    ▼       ▼        ▼
                     / DLQ      SQS   Kinesis    DDB
                                 │       │        │
                                 ▼       ▼        ▼
                              visibility shard   shard
                              timeout    retry   retry
                                 │       │        │
                                 ▼       ▼        ▼
                               DLQ    failure   failure
                                      dest      dest
```

Before answering any Lambda failure question:

```text
FIRST IDENTIFY
THE INVOCATION MODEL.
```

---

# 145. The Permanent SQS Model

```text
Producer
   │
   ▼
SQS
   │
   ▼
Lambda poller
   │
   ▼
Message hidden
by visibility timeout
   │
   ▼
Batch invocation
   │
┌──┴─────────────┐
▼                ▼
SUCCESS         FAILURE
│                │
▼                ▼
delete        visible later
                  │
              retry count
                  │
          ┌───────┴────────┐
          ▼                ▼
       eventually       exceeds
       succeeds        maxReceiveCount
                           │
                           ▼
                          DLQ
```

---

# 146. The Permanent Stream Model

```text
Shard

A → B → C → D → E → F
        │
        ▼
     Batch fails
        │
        ▼
ordered progress stalls
        │
        ├── retry
        ├── partial failure
        ├── bisect
        ├── max retry
        ├── max record age
        └── failure destination
```

---

# 147. 40 Rules to Burn Into Memory

```text
1. Lambda does not have one universal retry model.

2. Always identify invocation type first.

3. Synchronous invocation leaves retry decisions
   primarily to the caller/invoking service.

4. Async Lambda puts events into an internal queue.

5. Async function errors default to two retries.

6. Async throttling/system errors can retry for
   up to six hours by default.

7. Async duplicates can still occur.

8. Make event consumers idempotent.

9. Async destinations can handle success and failure.

10. S3 is supported as an async on-failure destination.

11. Lambda async DLQ and destination are not identical.

12. Destinations contain richer invocation context.

13. SQS → Lambda uses an event source mapping.

14. Lambda polls SQS.

15. SQS messages remain in the queue while invisible.

16. Visibility timeout must exceed safe processing time.

17. SQS processing is at least once.

18. Duplicate SQS processing is normal possibility.

19. Standard SQS batch size defaults to 10.

20. Standard SQS can batch up to 10,000 records.

21. FIFO Lambda batches max at 10.

22. A failed SQS batch retries all records by default.

23. Use ReportBatchItemFailures.

24. An uncaught handler exception fails the whole SQS batch.

25. Put the DLQ on the SQS source queue.

26. FIFO ordering is based on message groups.

27. More FIFO message groups allow more concurrency.

28. Stop processing FIFO batch after first failure
    when reporting partial failures.

29. SQS MaximumConcurrency controls one mapping.

30. Lambda ReservedConcurrency controls the function.

31. Provisioned SQS poller mode is separate from
    maximum concurrency mode.

32. Event filtering prevents unnecessary invocation.

33. Kinesis and DynamoDB Streams are ordered by shard.

34. A bad stream record can block shard progress.

35. ReportBatchItemFailures also exists for streams.

36. BisectBatchOnFunctionError helps isolate poison records.

37. Bound retries and record age deliberately.

38. Configure on-failure destinations for discarded stream records.

39. Queues are backpressure mechanisms, not merely buffers.

40. Reliability = retries + idempotency +
    DLQ/destination + monitoring + safe redrive.
```

---

# 148. Production Serverless Reliability Architecture

```text
                              PRODUCERS

               ┌────────────────┼─────────────────┐
               ▼                ▼                 ▼
          API/EventBridge      SNS                S3
               │                │                 │
               └────────────────┼─────────────────┘
                                ▼
                        Async Lambda
                                │
                     bounded retries/age
                                │
                      ┌─────────┴─────────┐
                      ▼                   ▼
                   SUCCESS              FAILURE
                      │                   │
               destination        failure destination
                                          │
                                          ▼
                                        SQS/S3


                            PRODUCERS
                                │
                                ▼
                               SQS
                                │
                          source DLQ
                                │
                                ▼
                       event source mapping
                                │
                  filtering + batching + cap
                                │
                                ▼
                              Lambda
                                │
                     partial batch response
                                │
                                ▼
                          IDEMPOTENT WORK
                                │
                                ▼
                            DynamoDB/RDS


                      Kinesis / DDB Streams
                                │
                                ▼
                              shard
                                │
                             batches
                                │
                                ▼
                              Lambda
                                │
                  ┌─────────────┼─────────────┐
                  ▼             ▼             ▼
             partial batch    bisect      bounded retry
                                               │
                                               ▼
                                      failure destination
```

---

# ✅ Lesson 33 Part 2 Complete

You now understand:

```text
✓ synchronous invocation
✓ asynchronous invocation
✓ event-source mappings
✓ retry ownership

✓ Lambda asynchronous queue
✓ default async retries
✓ throttling/system retries
✓ six-hour event retry window
✓ maximum event age
✓ maximum retry attempts
✓ duplicate async delivery

✓ Lambda destinations
✓ OnSuccess
✓ OnFailure
✓ SQS destinations
✓ SNS destinations
✓ EventBridge destinations
✓ Lambda destinations
✓ S3 failure destinations
✓ DestinationDeliveryFailures

✓ Lambda async DLQs
✓ destination vs DLQ
✓ why SQS source DLQ is different

✓ SQS event-source mappings
✓ pollers
✓ visibility timeout
✓ batch size
✓ batching window
✓ low-traffic batching behavior

✓ whole-batch failure
✓ partial batch response
✓ ReportBatchItemFailures
✓ Node.js partial response code
✓ Powertools Batch Processor

✓ poison messages
✓ SQS redrive policies
✓ maxReceiveCount
✓ DLQ operations

✓ SQS Standard
✓ SQS FIFO
✓ MessageGroupId
✓ ordered processing
✓ FIFO partial failure behavior

✓ standard SQS poller scaling
✓ five initial concurrent batches
✓ scaling growth
✓ 1,250 ESM default ceiling
✓ event-source maximum concurrency
✓ reserved concurrency interaction

✓ 2026 SQS provisioned poller mode
✓ MinimumPollers
✓ MaximumPollers
✓ up to 20,000 concurrency architecture
✓ provisioned poller metrics

✓ event-source filtering
✓ SQS body filters
✓ Kinesis filters
✓ DynamoDB filters
✓ KMS-encrypted filter criteria

✓ idempotency
✓ idempotency keys
✓ conditional writes
✓ business-key design
✓ duplicate-safe payments
✓ atomic side-effect thinking

✓ Kinesis event source mappings
✓ shards
✓ ordering
✓ standard iterator
✓ enhanced fan-out
✓ batch checkpointing
✓ stream partial batch responses

✓ MaximumRetryAttempts
✓ MaximumRecordAge
✓ BisectBatchOnFunctionError
✓ shard blocking
✓ failure destinations
✓ S3 stream-failure retention

✓ DynamoDB Streams
✓ change-data capture
✓ batching
✓ ParallelizationFactor
✓ partial failures
✓ event filtering

✓ S3 push events
✓ SNS asynchronous delivery
✓ EventBridge asynchronous delivery
✓ producer retry vs Lambda retry

✓ EventBridge Pipes concept

✓ backpressure
✓ queue age
✓ queue depth
✓ downstream protection
✓ retry storms

✓ Terraform SQS + DLQ
✓ Terraform event-source mappings
✓ Terraform async invocation config
✓ CLI hands-on lab
✓ production troubleshooting
✓ SAA-C03 / DOP-C02 scenarios
```

# Next — Lesson 33 Part 3

# **Amazon API Gateway from First Principles — REST, HTTP & WebSocket APIs + Lambda Integration**

Next we'll connect Lambda to real clients:

```text
                         INTERNET

                            │
                            ▼
                         Route 53
                            │
                            ▼
                      Custom Domain
                            │
                            ▼
                     API Gateway
                            │
            ┌───────────────┼────────────────┐
            ▼               ▼                ▼
           REST            HTTP          WebSocket
            │               │                │
            ▼               ▼                ▼
         Routes          Routes         Connections
            │               │                │
            └───────────────┼────────────────┘
                            ▼
                          Lambda
                            │
                ┌───────────┼──────────────┐
                ▼           ▼              ▼
            DynamoDB       SQS         EventBridge
```

We'll cover **API Gateway's role as an API front door, REST API vs HTTP API vs WebSocket API, resources/routes/methods/stages/deployments, Lambda proxy integrations, payload format v1 vs v2, request/response transformations, path/query/header parameters, CORS, throttling, quotas, caching, usage plans/API keys, Cognito authorizers, JWT authorizers, Lambda authorizers, IAM/SigV4 authentication, private APIs, VPC Links, custom domains, ACM certificate Region rules, Route 53 mappings, WAF, access logging, CloudWatch metrics, X-Ray/OpenTelemetry, canary deployments, stage variables, binary payloads, request validation, OpenAPI import/export, Terraform, and a complete secure production serverless API capstone.**

[1]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-retries.html?utm_source=chatgpt.com "Understanding retry behavior in Lambda"
[2]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async.html?utm_source=chatgpt.com "Invoking a Lambda function asynchronously"
[3]: https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html?utm_source=chatgpt.com "Invoking Lambda functions with Amazon SNS notifications"
[4]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-eventsourcemapping.html?utm_source=chatgpt.com "How Lambda processes records from stream and queue- ..."
[5]: https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html "Using Lambda with Amazon SQS - AWS Lambda"
[6]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-error-handling.html "How Lambda handles errors and retries with asynchronous invocation - AWS Lambda"
[7]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-configuring.html?utm_source=chatgpt.com "Configuring error handling settings for Lambda ..."
[8]: https://docs.aws.amazon.com/lambda/latest/dg/monitoring-metrics-types.html?utm_source=chatgpt.com "Types of metrics for Lambda functions"
[9]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-async-retain-records.html "Capturing records of Lambda asynchronous invocations - AWS Lambda"
[10]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-configure.html?utm_source=chatgpt.com "Creating and configuring an Amazon SQS event source ..."
[11]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-parameters.html "Lambda parameters for Amazon SQS event source mappings - AWS Lambda"
[12]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-errorhandling.html "Handling errors for an SQS event source in Lambda - AWS Lambda"
[13]: https://docs.aws.amazon.com/lambda/latest/dg/example_serverless_SQS_Lambda_batch_item_failures_section.html?utm_source=chatgpt.com "Reporting batch item failures for Lambda functions with an ..."
[14]: https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-scaling.html "Configuring scaling behavior for SQS event source mappings - AWS Lambda"
[15]: https://docs.aws.amazon.com/lambda/latest/dg/invocation-eventfiltering.html?utm_source=chatgpt.com "Control which events Lambda sends to your function"
[16]: https://docs.aws.amazon.com/lambda/latest/dg/with-sqs-filtering.html?utm_source=chatgpt.com "Using event filtering with an Amazon SQS event source"
[17]: https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html "Using Lambda to process records from Amazon Kinesis Data Streams - AWS Lambda"
[18]: https://docs.aws.amazon.com/lambda/latest/dg/services-kinesis-batchfailurereporting.html "Configuring partial batch response with Kinesis Data Streams and Lambda - AWS Lambda"
[19]: https://docs.aws.amazon.com/cli/latest/reference/lambda/update-event-source-mapping.html?utm_source=chatgpt.com "update-event-source-mapping"
[20]: https://docs.aws.amazon.com/lambda/latest/dg/services-ddb-params.html?utm_source=chatgpt.com "Lambda parameters for Amazon DynamoDB event source ..."
[21]: https://docs.aws.amazon.com/lambda/latest/dg/services-dynamodb-errors.html "Retain discarded records for a DynamoDB event source in Lambda - AWS Lambda"
[22]: https://docs.aws.amazon.com/cli/v1/reference/lambda/create-event-source-mapping.html?utm_source=chatgpt.com "create-event-source-mapping — AWS CLI 1.44.85 Command ..."
[23]: https://docs.aws.amazon.com/lambda/latest/dg/with-ddb.html "Using AWS Lambda with Amazon DynamoDB - AWS Lambda"
[24]: https://docs.aws.amazon.com/lambda/latest/dg/services-ddb-batchfailurereporting.html?utm_source=chatgpt.com "Configuring partial batch response with DynamoDB and ..."
[25]: https://docs.aws.amazon.com/lambda/latest/dg/with-ddb-filtering.html?utm_source=chatgpt.com "Using event filtering with a DynamoDB event source"
[26]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-targets.html?utm_source=chatgpt.com "Event bus targets in Amazon EventBridge"
[27]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-dlq.html?utm_source=chatgpt.com "Using dead-letter queues to process undelivered events in ..."
[28]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue?utm_source=chatgpt.com "aws_sqs_queue | Resources | hashicorp/aws | Terraform"
[29]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping?utm_source=chatgpt.com "aws_lambda_event_source_ma..."
[30]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_event_invoke_config?utm_source=chatgpt.com "aws_lambda_function_event_inv..."
