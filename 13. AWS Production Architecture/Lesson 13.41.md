# AWS Masterclass — Phase 3

# Lesson 40: EventBridge, SNS, SQS and Step Functions

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Design asynchronous, event-driven applications.
* Choose correctly between SQS, SNS and EventBridge.
* Decouple producers from consumers.
* Use standard and FIFO queues.
* Configure visibility timeouts and long polling.
* Design dead-letter queues and safe redrive workflows.
* Prevent duplicate business operations through idempotency.
* Build SNS fan-out architectures.
* Filter messages for individual subscribers.
* Route business and AWS service events using EventBridge.
* Use EventBridge Pipes and Scheduler.
* Archive and replay events.
* Orchestrate multi-step workflows with Step Functions.
* Choose Standard or Express workflows.
* Implement retries, catches, timeouts and compensation.
* Build production messaging infrastructure using Terraform.
* Monitor backlog, failures, retries and workflow executions.

---

# 2. Event-driven architecture mental model

In a synchronous architecture:

```text
Client
   |
   v
Service A
   |
   v
Service B
   |
   v
Service C
   |
   v
Response
```

Every component must usually remain available until the request finishes.

If Service C becomes slow:

```text
Service C slow
      ↓
Service B waits
      ↓
Service A waits
      ↓
Client waits
```

In an asynchronous architecture:

```text
Client
   |
   v
API
   |
   v
Queue or event bus
   |
   +------------------------+
   |                        |
   v                        v
Consumer A              Consumer B
```

The producer records work or publishes an event without waiting for every downstream operation to finish.

---

# 3. Synchronous versus asynchronous processing

## Synchronous

```text
Request
   ↓
Process immediately
   ↓
Return final result
```

Suitable for:

* User login.
* Reading account data.
* Validating a payment before confirmation.
* Simple database queries.
* Operations where the caller needs an immediate answer.

## Asynchronous

```text
Request
   ↓
Accept work
   ↓
Place message on queue
   ↓
Return accepted response
   ↓
Process later
```

Suitable for:

* Email sending.
* Image resizing.
* Video processing.
* Report generation.
* Order fulfilment.
* Log processing.
* Background AI jobs.
* Notifications.
* Long-running workflows.

## Hybrid example

```text
POST /documents
        |
        v
Validate request synchronously
        |
        v
Store original file
        |
        v
Publish processing message
        |
        v
Return HTTP 202 Accepted
```

The user does not wait for virus scanning, text extraction, indexing and notifications to finish.

---

# 4. The four-service mental model

```text
Amazon SQS:
Store work until a consumer processes it.

Amazon SNS:
Broadcast one message to multiple subscribers.

Amazon EventBridge:
Match events by content and route them to targets.

AWS Step Functions:
Coordinate a multi-step workflow over time.
```

## One-line decision guide

```text
Need a durable work backlog?
    → SQS

Need one message delivered to many subscribers?
    → SNS

Need content-based event routing among services?
    → EventBridge

Need visible workflow state, branching and retries?
    → Step Functions
```

AWS’s current messaging decision guide distinguishes SQS as durable queued messaging, SNS as real-time pub/sub fan-out and EventBridge as rule-based event routing. ([AWS Documentation][1])

---

# 5. Queue, topic, event bus and workflow

## Queue

```text
Producer
   |
   v
Messages waiting
   |
   v
One or more competing consumers
```

Messages remain until processed, deleted or expired.

## Topic

```text
Publisher
   |
   v
Topic
 ├── Subscriber A
 ├── Subscriber B
 └── Subscriber C
```

Each matching subscriber receives its own delivery attempt.

## Event bus

```text
Producer
   |
   v
Event bus
 ├── Rule: type=OrderCreated → Fulfilment
 ├── Rule: amount>10000      → Fraud
 └── Rule: region=EU         → Compliance
```

Rules evaluate event content.

## Workflow

```text
Start
  ↓
Validate
  ↓
Charge payment
  ↓
Reserve inventory
  ↓
Ship
  ↓
Complete
```

The workflow retains execution state and coordinates each step.

---

# 6. Amazon SQS

Amazon Simple Queue Service provides managed message queues for decoupling application components.

```text
Producer
   |
   | SendMessage
   v
SQS queue
   |
   | ReceiveMessage
   v
Consumer
   |
   | DeleteMessage
   v
Message removed
```

A queue buffers work when producers and consumers operate at different speeds.

---

# 7. Why use SQS?

Without a queue:

```text
API
 |
 | Direct request
 v
Image processor
```

If the processor is unavailable:

```text
API request fails
```

With SQS:

```text
API
 |
 v
SQS
 |
 v
Image processor
```

If the processor is unavailable:

```text
Messages remain queued
        ↓
Processor returns
        ↓
Processing continues
```

Use SQS for:

* Load buffering.
* Worker decoupling.
* Retry isolation.
* Batch processing.
* Back-pressure management.
* Asynchronous jobs.
* Leveling traffic spikes.

---

# 8. Standard and FIFO queues

SQS provides two principal queue types:

```text
Standard
FIFO
```

## Standard queue

Characteristics:

* Very high scalable throughput.
* At-least-once delivery.
* Messages may occasionally be duplicated.
* Messages may occasionally arrive out of order.

Standard queues are the default queue type and are suitable when consumers are idempotent and strict ordering is unnecessary. ([AWS Documentation][2])

## FIFO queue

FIFO means:

```text
First In, First Out
```

Characteristics:

* Ordered processing within a message group.
* Message deduplication.
* Message group IDs.
* Queue name ends in `.fifo`.
* More ordering constraints than standard queues.

SQS FIFO queues provide ordering and deduplication features, but correct consumer behavior remains necessary to avoid reprocessing after visibility-timeout expiration. ([AWS Documentation][3])

---

# 9. Standard-queue example

```text
Sent:
A → B → C

Possible delivery:
A → C → B

Possible delivery:
A → B → B → C
```

The application must tolerate:

```text
Duplicate messages
+
Occasional ordering differences
```

Use standard queues for:

* Email jobs.
* Image processing.
* Independent log records.
* Stateless tasks.
* Notifications where order is unimportant.
* High-volume work distribution.

---

# 10. FIFO ordering

FIFO ordering is managed with:

```text
MessageGroupId
```

Example:

```text
Customer 101:
MessageGroupId = customer-101

Customer 202:
MessageGroupId = customer-202
```

Messages for one group remain ordered:

```text
customer-101:
CreateOrder → PayOrder → ShipOrder
```

Different message groups can be processed concurrently:

```text
customer-101 ──> Worker A
customer-202 ──> Worker B
customer-303 ──> Worker C
```

This lets you preserve per-entity ordering without globally serializing the complete queue. ([AWS Documentation][4])

---

# 11. Bad FIFO message grouping

Bad:

```text
MessageGroupId = all-orders
```

Every message belongs to one group:

```text
All messages processed sequentially
```

This can reduce concurrency severely.

Better:

```text
MessageGroupId = order-customer-id
```

or:

```text
MessageGroupId = account-id
```

Choose the business entity whose operations must remain ordered.

---

# 12. FIFO deduplication

FIFO messages use:

```text
MessageDeduplicationId
```

Within the FIFO deduplication interval, retries with the same deduplication ID are not introduced as additional queue messages. The documented deduplication interval is five minutes. ([AWS Documentation][5])

Example:

```text
MessageDeduplicationId:
payment-attempt-104
```

Publisher retries:

```text
Send payment-attempt-104
Send payment-attempt-104
Send payment-attempt-104
```

SQS accepts the initial message and suppresses duplicate sends within the deduplication interval.

Content-based deduplication can generate the ID from a SHA-256 hash of the message body, but message attributes are not included in that body hash. ([AWS Documentation][6])

---

# 13. “Exactly once” does not remove idempotency

Imagine:

```text
1. Consumer receives message.
2. Consumer charges customer.
3. Consumer crashes before DeleteMessage.
4. Visibility timeout expires.
5. Message becomes visible.
6. Another consumer receives it.
```

The customer could be charged twice unless the business operation is idempotent.

Therefore:

```text
FIFO deduplication:
Protects producer-side duplicate sends within its window.

Idempotency:
Protects the business operation from repeated processing.
```

---

# 14. Message lifecycle

```text
1. Producer sends message.

2. Message becomes available.

3. Consumer receives message.

4. Message becomes invisible temporarily.

5. Consumer processes message.

6. Consumer deletes message.

7. SQS permanently removes it.
```

If step 6 does not happen:

```text
Visibility timeout expires
        ↓
Message becomes visible again
        ↓
Another processing attempt occurs
```

---

# 15. Visibility timeout

Visibility timeout hides a received message from other consumers while it is being processed.

```text
Consumer A receives message
        ↓
Message invisible
        ↓
Consumer A processes
```

The default queue visibility timeout is 30 seconds. It can be adjusted to match processing time, with a maximum of 12 hours measured from the original `ReceiveMessage` request. ([AWS Documentation][7])

## Example problem

```text
Processing duration:
90 seconds

Visibility timeout:
30 seconds
```

Timeline:

```text
0 seconds:
Worker A receives message.

30 seconds:
Message becomes visible again.

31 seconds:
Worker B receives same message.

90 seconds:
Worker A finishes.

121 seconds:
Worker B also finishes.
```

The job may run twice concurrently.

---

# 16. Visibility-timeout strategy

Use:

```text
Visibility timeout
>
Expected maximum normal processing time
```

Example:

```text
Typical processing:
30 seconds

p99 processing:
90 seconds

Visibility timeout:
120 seconds
```

For unpredictable long jobs, extend visibility while processing:

```text
Receive message
      ↓
Start heartbeat
      ↓
ChangeMessageVisibility periodically
      ↓
Processing completes
      ↓
Delete message
```

Do not set every queue to a 12-hour timeout. A failed message would remain hidden for too long before retrying.

---

# 17. Delete after success

Correct consumer logic:

```python
message = receive_message()

try:
    process(message)
    delete_message(message.receipt_handle)
except Exception:
    log_failure()
    # Do not delete.
```

Do not delete the message before the business operation succeeds.

Bad:

```text
Receive
  ↓
Delete
  ↓
Process
  ↓
Consumer crashes
```

The work is lost.

Correct:

```text
Receive
  ↓
Process successfully
  ↓
Commit business result
  ↓
Delete
```

---

# 18. Idempotent consumer design

Suppose the event contains:

```json
{
  "eventId": "evt-104",
  "type": "TodoCreated",
  "todoId": "todo-501"
}
```

Consumer flow:

```text
Receive evt-104
      ↓
Check idempotency table
      |
      ├── Already completed → Delete message
      |
      └── Not completed
              ↓
          Process event
              ↓
        Record evt-104 completed
              ↓
          Delete message
```

DynamoDB conditional writes are often suitable:

```text
PutItem only if eventId does not exist
```

The idempotency record should generally be written atomically with, or carefully coordinated around, the business effect.

---

# 19. Long polling

Short polling can repeatedly return empty responses even when no work exists.

```text
Consumer:
ReceiveMessage
ReceiveMessage
ReceiveMessage
ReceiveMessage
```

Long polling allows a receive request to wait for a message.

```text
ReceiveMessage wait up to 20 seconds
```

The maximum SQS long-poll wait is 20 seconds. Long polling reduces empty responses and unnecessary polling requests. ([AWS Documentation][8])

Recommended queue setting:

```text
ReceiveMessageWaitTimeSeconds = 20
```

---

# 20. Message retention

SQS retains unconsumed messages for a configurable period.

Current limits:

```text
Default:
4 days

Minimum:
60 seconds

Maximum:
14 days
```

Messages that exceed the configured retention period are deleted automatically. ([AWS Documentation][9])

Retention is not a substitute for permanent storage.

For long-term event history:

```text
Store business records in:
Database, S3 or event store

Use SQS for:
Temporary delivery and buffering
```

---

# 21. Message size

The current maximum SQS message size is:

```text
1 MiB
```

Message attributes count toward this size. For larger payloads, store the data in S3 and place a reference in SQS; the SQS Extended Client Libraries can offload payloads to S3, supporting substantially larger logical payloads. ([AWS Documentation][6])

Recommended message:

```json
{
  "jobId": "job-104",
  "bucket": "production-documents",
  "key": "uploads/job-104/document.pdf",
  "versionId": "..."
}
```

Not:

```text
Entire 700 MB document inside queue message
```

---

# 22. Delay queues and message timers

A delay queue hides newly sent messages temporarily.

Example:

```text
Send message now
        ↓
Available after 5 minutes
```

SQS queue delays can be configured from zero seconds to 15 minutes. ([AWS Documentation][10])

Use cases:

* Short retry delay.
* Delayed notification.
* Waiting before a follow-up check.
* Temporary cooling period.

For long-duration or calendar-based scheduling, use EventBridge Scheduler instead of repeatedly delaying SQS messages.

---

# 23. SQS batching

SQS supports batch operations for:

* Sending messages.
* Receiving messages.
* Deleting messages.
* Changing message visibility.

Batching reduces API requests and can improve throughput.

The total payload for one `SendMessageBatch` operation cannot exceed 1 MiB. ([AWS Documentation][11])

Consumer pattern:

```text
Receive batch of 10
        ↓
Process independently
        ↓
Delete successful messages
        ↓
Leave failed messages for retry
```

Do not fail an entire successful batch because one item failed when the integration supports partial-batch responses.

---

# 24. Dead-letter queues

A dead-letter queue receives messages that could not be processed successfully after repeated receives.

```text
Source queue
     |
     | Processing fails repeatedly
     v
Dead-letter queue
```

SQS does not automatically create the DLQ. You create it and configure a redrive policy on the source queue. The queue types must match: standard source to standard DLQ, FIFO source to FIFO DLQ. ([AWS Documentation][12])

---

# 25. `maxReceiveCount`

A redrive policy defines:

```text
maxReceiveCount
```

Example:

```text
maxReceiveCount = 5
```

Message flow:

```text
Attempt 1 → fail
Attempt 2 → fail
Attempt 3 → fail
Attempt 4 → fail
Attempt 5 → fail
        ↓
Moved to DLQ
```

Do not set it to `1` without a strong reason. Temporary failures would immediately quarantine valid messages. AWS recommends allowing enough receives for the application’s retry behavior. ([AWS Documentation][13])

---

# 26. DLQ retention

Set:

```text
DLQ retention
>
Source queue retention
```

For standard queues, the message’s original enqueue timestamp continues to affect expiration after movement to the DLQ. For FIFO queues, the enqueue timestamp resets when moved. AWS therefore recommends longer retention on the DLQ than on the source queue. ([AWS Documentation][13])

Example:

```text
Source retention:
4 days

DLQ retention:
14 days
```

---

# 27. A DLQ is not a solution by itself

Bad architecture:

```text
Messages enter DLQ
        ↓
Nobody monitors it
        ↓
Messages expire
```

A production DLQ needs:

```text
Alarm
Owner
Runbook
Root-cause process
Redrive process
Retention
Access controls
```

Monitor:

```text
ApproximateNumberOfMessagesVisible
ApproximateAgeOfOldestMessage
```

---

# 28. Safe DLQ redrive

Do not immediately move every DLQ message back.

Correct process:

```text
1. Stop or contain the failure.

2. Inspect representative messages.

3. Determine whether the message is valid.

4. Fix consumer code or dependency.

5. Verify idempotency.

6. Redrive a small batch.

7. Observe results.

8. Gradually redrive remaining messages.
```

A malformed poison message can loop forever:

```text
Source → Consumer failure → DLQ → Redrive → Source → Failure
```

---

# 29. Poison messages

A poison message always fails because its contents are invalid or incompatible.

Examples:

```text
Missing mandatory field
Invalid schema version
Corrupt object reference
Unsupported event type
Invalid character encoding
```

Consumer design:

```text
Transient error:
Retry

Permanent validation error:
Quarantine quickly

Unknown error:
Retry according to policy, then DLQ
```

Do not treat every error identically.

---

# 30. SQS monitoring

Important CloudWatch metrics include:

```text
ApproximateNumberOfMessagesVisible
ApproximateNumberOfMessagesNotVisible
ApproximateAgeOfOldestMessage
NumberOfMessagesSent
NumberOfMessagesReceived
NumberOfMessagesDeleted
NumberOfEmptyReceives
```

A growing visible backlog or oldest-message age can indicate insufficient consumer capacity or failed processing logic. ([AWS Documentation][14])

## Best backlog alarm

Queue depth alone can be misleading.

Example:

```text
Queue depth:
100,000

Consumer rate:
50,000/minute
```

This may be healthy.

More meaningful:

```text
ApproximateAgeOfOldestMessage
```

because it represents how long work is waiting.

---

# 31. Back-pressure

Back-pressure occurs when producers create work faster than consumers process it.

```text
Producer:
10,000 messages/minute

Consumers:
6,000 messages/minute

Backlog growth:
4,000 messages/minute
```

Responses include:

* Scale consumers.
* Increase batch size.
* Improve processing speed.
* Reduce producer rate.
* Apply admission control.
* Separate slow job types.
* Introduce priority queues.
* Investigate dependency throttling.

A queue absorbs a spike temporarily; it does not provide infinite processing capacity.

---

# 32. Multiple queue priorities

SQS has no universal automatic priority ordering for standard queues.

Use separate queues:

```text
critical-jobs
normal-jobs
bulk-jobs
```

Consumers can allocate capacity:

```text
Critical:
10 workers

Normal:
5 workers

Bulk:
2 workers
```

This prevents bulk work from delaying urgent operations.

---

# 33. SQS security

Security controls include:

* IAM identity policies.
* Queue resource policies.
* KMS encryption.
* TLS.
* VPC endpoints.
* Cross-account permissions.
* Organization policies.

Example queue policy objective:

```text
Allow only:
Order API role to SendMessage

Allow only:
Worker role to ReceiveMessage and DeleteMessage
```

Do not give producers:

```text
sqs:ReceiveMessage
sqs:DeleteMessage
```

unless they genuinely consume messages.

---

# 34. Amazon SNS

Amazon Simple Notification Service provides managed publish/subscribe messaging.

```text
Publisher
   |
   v
SNS topic
 ├── SQS queue
 ├── Lambda
 ├── HTTPS endpoint
 ├── Email
 └── Mobile notification
```

SNS is useful when one business event must reach several independent subscribers.

---

# 35. SNS fan-out

Example:

```text
OrderCreated
      |
      v
SNS topic
 ├── Fulfilment SQS queue
 ├── Billing SQS queue
 ├── Analytics SQS queue
 └── Notification SQS queue
```

Each subscriber receives its own copy.

If Billing is unavailable:

```text
Billing queue stores its copy
```

Fulfilment and Analytics can continue independently.

---

# 36. Why SNS plus SQS?

Direct SNS-to-consumer:

```text
SNS
 |
 v
HTTP service
```

The consumer must be available when SNS delivers, subject to retry behavior.

SNS-to-SQS:

```text
SNS
 |
 v
SQS
 |
 v
Consumer
```

Benefits:

* Durable buffering.
* Independent consumer scaling.
* Consumer-controlled processing.
* Queue-level DLQ.
* Visibility timeout.
* Backlog monitoring.
* Replay through controlled redrive.

This is one of the most common AWS fan-out patterns.

---

# 37. SNS standard and FIFO topics

SNS provides:

```text
Standard topics
FIFO topics
```

## Standard topics

Suitable for broad pub/sub with high scalability where strict ordering is not required.

## FIFO topics

Suitable when:

* Ordered publication matters.
* Duplicate suppression matters.
* Subscribers use compatible queue endpoints.
* Message groups represent ordered entities.

SNS FIFO topics integrate with SQS FIFO queues for ordered, deduplicated application-to-application messaging. ([AWS Documentation][15])

---

# 38. SNS FIFO fan-out

```text
SNS FIFO topic
      |
      ├── SQS FIFO queue A
      └── SQS FIFO queue B
```

Publish:

```text
MessageGroupId = customer-104
MessageDeduplicationId = order-event-501
```

Each FIFO queue preserves the relevant message-group ordering.

The subscriber consumer still needs correct visibility, deletion and idempotency handling.

---

# 39. SNS message filtering

Without filtering:

```text
Topic message
    |
    ├── Every subscriber
    ├── Every subscriber
    └── Every subscriber
```

With subscription filter policies:

```text
OrderCreated, region=IN
    |
    ├── India fulfilment queue
    └── Global analytics queue
```

SNS filter policies can evaluate message attributes or the message body for each subscription. ([AWS Documentation][16])

Example filter:

```json
{
  "eventType": ["OrderCreated"],
  "region": ["IN"],
  "amount": [
    {
      "numeric": [">=", 1000]
    }
  ]
}
```

---

# 40. Filtering reduces unnecessary work

Bad:

```text
All subscribers receive all messages
        ↓
Each consumer discards 95%
```

Better:

```text
SNS subscription filter
        ↓
Only relevant messages delivered
```

Benefits:

* Fewer requests.
* Less consumer code.
* Lower cost.
* Smaller queue backlog.
* Clearer service boundaries.

Do not make filter policies so complex that nobody understands which subscriber receives an event.

---

# 41. SNS message size

The normal maximum SNS message size is:

```text
256 KB
```

Message attributes count toward the limit. Extended Client support can offload larger payloads to S3 and carry references through SNS/SQS-compatible workflows. ([AWS Documentation][17])

Recommended event:

```json
{
  "eventId": "evt-501",
  "bucket": "documents",
  "key": "processed/evt-501.json"
}
```

---

# 42. SNS delivery retries and DLQs

SNS applies endpoint-specific retry behavior when delivery fails. If retries are exhausted, the message is discarded unless a dead-letter queue is attached to that subscription. ([AWS Documentation][18])

Important distinction:

```text
SNS subscription DLQ:
SNS could not deliver to subscriber.

SQS consumer DLQ:
Subscriber queue received the message,
but its consumer could not process it.
```

A production SNS-to-SQS path may use both:

```text
SNS subscription DLQ
+
Consumer queue DLQ
```

They diagnose different failure stages.

---

# 43. SNS FIFO archive and replay

SNS FIFO topics can archive messages within the topic for one to 365 days and replay selected time ranges to subscribers. Replayed messages retain their original message ID, timestamp and content, with metadata indicating replay. ([AWS Documentation][19])

Use cases:

* Recover after subscriber outage.
* Populate a new subscriber.
* Rebuild downstream state.
* Reprocess corrected business logic.
* Synchronize another environment.

Standard topics do not provide the same built-in in-place replay capability; standard-topic archival is commonly implemented through destinations such as Firehose and S3. ([AWS Documentation][20])

---

# 44. Amazon EventBridge

Amazon EventBridge is an event-routing service that matches events against rules and delivers matching events to targets.

```text
Event producers
      |
      v
Event bus
      |
      ├── Rule A → Lambda
      ├── Rule B → Step Functions
      ├── Rule C → SQS
      └── Rule D → Another event bus
```

EventBridge is suitable when routing depends on:

* Event source.
* Event type.
* Resource attributes.
* Business fields.
* Account.
* Region.
* Event metadata.

---

# 45. Event structure

A typical EventBridge event looks like:

```json
{
  "version": "0",
  "id": "evt-104",
  "detail-type": "Todo Created",
  "source": "com.example.todoapp",
  "account": "123456789012",
  "time": "2026-07-28T01:15:00Z",
  "region": "ap-south-1",
  "resources": [
    "arn:aws:todoapp:ap-south-1:123456789012:todo/todo-501"
  ],
  "detail": {
    "todoId": "todo-501",
    "userId": "user-104",
    "priority": "HIGH"
  }
}
```

EventBridge uses fields such as `source`, `detail-type`, metadata and `detail` content for pattern matching. ([AWS Documentation][21])

---

# 46. Event bus types

Common EventBridge event-bus categories are:

```text
Default event bus
Custom event bus
Partner event bus
```

## Default event bus

Receives events from many AWS services.

## Custom event bus

Receives application or organization-defined events.

## Partner event bus

Receives events from supported SaaS partners and integrations.

Recommended separation:

```text
default:
AWS service events

todoapp-production:
Application domain events

security:
Security events
```

---

# 47. Event patterns

A rule contains an event pattern.

Example:

```json
{
  "source": [
    "com.example.todoapp"
  ],
  "detail-type": [
    "Todo Created"
  ],
  "detail": {
    "priority": [
      "HIGH"
    ]
  }
}
```

Matching event:

```json
{
  "source": "com.example.todoapp",
  "detail-type": "Todo Created",
  "detail": {
    "priority": "HIGH"
  }
}
```

EventBridge compares events against each relevant rule and routes matched events to the configured targets. ([AWS Documentation][22])

---

# 48. Avoid overly broad rules

Bad:

```json
{
  "source": [
    {
      "prefix": ""
    }
  ]
}
```

This can route enormous numbers of events or create loops.

Better:

```json
{
  "source": ["com.example.todoapp"],
  "detail-type": ["Todo Created"],
  "detail": {
    "environment": ["production"]
  }
}
```

AWS warns that imprecise event patterns can create recursive loops, excessive invocations and unexpected charges. ([AWS Documentation][22])

---

# 49. EventBridge delivery behavior

EventBridge uses at-least-once delivery semantics for target delivery. Your targets must therefore tolerate duplicate events. ([AWS Documentation][23])

EventBridge does not provide FIFO ordering guarantees like SQS FIFO or SNS FIFO.

If strict ordering is required:

```text
EventBridge
     |
     v
SQS FIFO
     |
     v
Ordered consumer
```

The event must include a suitable message group when the integration requires it.

---

# 50. EventBridge retries

For retriable target failures, EventBridge’s default retry behavior is:

```text
Up to 24 hours
Up to 185 attempts
Exponential backoff with jitter
```

If all attempts are exhausted, EventBridge drops the event unless a DLQ is configured. ([AWS Documentation][24])

Configure target-level:

```text
Maximum event age
Maximum retry attempts
Dead-letter queue
```

---

# 51. EventBridge DLQ

An EventBridge rule target can use an SQS queue as a DLQ.

Failed-event metadata can include:

* Error code.
* Error message.
* Retry attempts.
* Rule ARN.
* Target ARN.
* Retry-exhaustion condition.

This makes target-delivery failures easier to investigate. ([AWS Documentation][25])

Again, distinguish:

```text
EventBridge DLQ:
Event could not reach target.

Target service DLQ:
Target received work but processing failed.
```

---

# 52. EventBridge archive and replay

EventBridge can archive matching events from an event bus and later replay them to the same source bus. ([AWS Documentation][26])

```text
Event bus
    |
    ├── Rules and targets
    |
    └── Archive
           |
           v
        Replay later
           |
           v
      Original event bus
```

Use cases:

* Recover after downstream outage.
* Test corrected event consumers.
* Rebuild derived data.
* Reprocess a selected time range.
* Populate a new projection.

Replay republishes events; consumers must remain idempotent.

---

# 53. EventBridge Schema Registry

A schema defines an event’s structure.

EventBridge provides schemas for AWS service events and allows custom schemas to be uploaded or inferred from events. Schema discovery can create new schema versions when event structures change. ([AWS Documentation][27])

Benefits:

* Shared event contracts.
* Generated code bindings.
* Easier producer-consumer coordination.
* Schema-version visibility.
* Reduced manual JSON handling.

---

# 54. Event versioning

Recommended event:

```json
{
  "source": "com.example.todoapp",
  "detail-type": "Todo Created",
  "detail": {
    "schemaVersion": "2",
    "todoId": "todo-501",
    "title": "Deploy application",
    "priority": "HIGH"
  }
}
```

Do not change meaning silently.

Bad:

```text
Version 1:
priority = HIGH | LOW

Later silently changed:
priority = integer 1–10
```

Prefer:

* Backward-compatible field addition.
* Explicit schema versions.
* Consumer support for transition periods.
* New event types for incompatible semantic changes.

---

# 55. Cross-account EventBridge

A central or workload event bus can accept events from other AWS accounts using resource policies.

Example:

```text
Production accounts
      |
      v
Central security event bus
      |
      v
Security automation
```

Controls should restrict:

* Allowed principal accounts.
* Organization ID.
* Event source.
* Detail type.
* Target roles.

Cross-account event routing is useful for centralized security, governance and operational automation.

---

# 56. EventBridge Pipes

EventBridge Pipes provides point-to-point integration:

```text
One source
    |
    v
Optional filtering
    |
    v
Optional enrichment
    |
    v
One target
```

Event buses provide many-to-many routing through rules, whereas each pipe connects one source to one target. ([AWS Documentation][28])

Example:

```text
SQS
 |
 v
Filter only HIGH priority
 |
 v
Lambda enrichment
 |
 v
Step Functions
```

---

# 57. EventBridge Pipes sources and processing

For an SQS source, a pipe polls messages, can batch them, filter or enrich them and then invoke the target. Pipes support standard and FIFO SQS queues. ([AWS Documentation][29])

Use Pipes when you would otherwise write a “glue Lambda” only to:

```text
Poll source
Filter event
Transform event
Call target
```

Retain Lambda when the transformation requires substantial business logic.

---

# 58. EventBridge Scheduler

EventBridge Scheduler invokes targets according to:

* One-time schedules.
* Rate schedules.
* Cron schedules.
* Time zones.
* Flexible time windows.

Scheduler supports retry policies and SQS DLQs and provides at-least-once delivery to targets. ([AWS Documentation][30])

Use cases:

```text
Send reminder tomorrow
Run report monthly
Close expired orders
Start Step Functions workflow
Publish SQS job at a future time
```

---

# 59. Scheduler versus scheduled event rules

Recommended modern pattern:

```text
EventBridge Scheduler:
Large-scale and flexible schedules

EventBridge scheduled rules:
Existing rule-based scheduled workloads
```

Scheduler is particularly useful for:

* Millions of independent schedules.
* One-time future events.
* Customer-specific time zones.
* Flexible delivery windows.
* Configurable retry and DLQ behavior.

---

# 60. AWS Step Functions

AWS Step Functions orchestrates distributed applications as state machines.

```text
Start
  ↓
Validate request
  ↓
Process payment
  ↓
Reserve inventory
  ↓
Wait for fulfilment
  ↓
Send notification
  ↓
Complete
```

The workflow definition makes:

* Current state visible.
* Branching explicit.
* Retry policy explicit.
* Failure handling explicit.
* Execution history inspectable.

---

# 61. Step Functions state types

Common state types include:

```text
Task
Choice
Wait
Parallel
Map
Pass
Succeed
Fail
```

## Task

Invokes work.

## Choice

Branches based on data.

## Wait

Waits for a period or timestamp.

## Parallel

Runs branches concurrently.

## Map

Processes a collection.

## Pass

Transforms or forwards data.

## Succeed and Fail

Finish the workflow explicitly.

---

# 62. Standard versus Express workflows

## Standard workflows

Suitable for:

* Long-running workflows.
* Auditable execution history.
* Non-idempotent orchestration.
* Human approval.
* Callback tokens.
* External jobs.
* Workflows lasting up to one year.

Standard workflows use an exactly-once workflow-execution model. ([AWS Documentation][31])

## Express workflows

Suitable for:

* High-volume short workflows.
* Streaming-event processing.
* IoT processing.
* Lightweight transformations.
* Very frequent executions.

Asynchronous Express workflows use at-least-once execution; synchronous Express workflows use at-most-once execution. Express workflows do not support `.sync` job-running or `.waitForTaskToken` callback patterns. ([AWS Documentation][31])

---

# 63. Workflow selection

```text
Payment workflow?
    → Standard

Human approval?
    → Standard

Long-running ECS or Batch job?
    → Standard

High-volume event transformation?
    → Express

Short API composition?
    → Synchronous Express may fit

Need callback token?
    → Standard
```

Do not choose Express merely because it sounds faster.

Choose based on:

* Execution semantics.
* Duration.
* Audit history.
* Integration pattern.
* Volume.
* Cost model.

---

# 64. Service integration patterns

Step Functions supports three principal service-integration patterns:

```text
Request Response
Run a Job (.sync)
Wait for Callback (.waitForTaskToken)
```

Support depends on the workflow type and integrated service. Standard supports all three where available; Express supports request-response but not `.sync` or callback-token patterns. ([AWS Documentation][32])

---

# 65. Request-response pattern

```text
Step Functions
      |
      | Invoke API
      v
AWS service
      |
      | Immediate API response
      v
Next state
```

Example:

```text
SendMessage to SQS
PutItem to DynamoDB
Invoke Lambda
Publish SNS message
```

The workflow waits for the API response, not for all downstream business processing.

---

# 66. Run-a-job pattern

```text
Step Functions
      |
      | Start job
      v
AWS Batch / ECS / EMR
      |
      | Job runs
      |
      v
Job completes
      |
      v
Workflow continues
```

Resource pattern:

```text
arn:aws:states:::batch:submitJob.sync
```

The `.sync` pattern is useful for managed jobs whose completion Step Functions can monitor.

---

# 67. Callback-token pattern

```text
Step Functions
      |
      | Task token
      v
External worker or human approval
      |
      | SendTaskSuccess / SendTaskFailure
      v
Workflow continues
```

Use cases:

* Human approval.
* External partner response.
* Manual security review.
* Long-running legacy process.
* Asynchronous worker completion.

Never expose task tokens publicly. Possession of the token can authorize completion of that task.

---

# 68. Retries

A Step Functions task can define `Retry`.

```json
"Retry": [
  {
    "ErrorEquals": [
      "Lambda.ServiceException",
      "Lambda.TooManyRequestsException"
    ],
    "IntervalSeconds": 2,
    "BackoffRate": 2,
    "MaxAttempts": 5
  }
]
```

Retry timing:

```text
Attempt 1:
Immediate

Attempt 2:
2 seconds

Attempt 3:
4 seconds

Attempt 4:
8 seconds

Attempt 5:
16 seconds
```

Use exponential backoff for transient errors.

Do not retry permanent validation errors indefinitely.

---

# 69. Catch

A `Catch` transition handles errors after retries are exhausted.

```json
"Catch": [
  {
    "ErrorEquals": [
      "States.ALL"
    ],
    "ResultPath": "$.failure",
    "Next": "CompensateOrder"
  }
]
```

Flow:

```text
Task
 |
 ├── Success → Next normal state
 |
 └── Failure → Retry
                  |
                  └── Exhausted → Catch
                                      |
                                      v
                                 Recovery state
```

---

# 70. Error classification

## Transient

Examples:

```text
Throttling
Temporary network failure
Dependency unavailable
Service internal error
```

Response:

```text
Retry with backoff and jitter
```

## Permanent

Examples:

```text
Invalid account number
Unsupported file format
Missing required field
Business policy rejection
```

Response:

```text
Do not repeatedly retry
Route to failure handling
```

## Unknown

Response:

```text
Limited retries
Capture context
Fail safely
Alert owner
```

---

# 71. Timeouts and heartbeats

Every long-running task should have a bounded timeout.

```json
"TimeoutSeconds": 900
```

For activities or callback-style work:

```json
"HeartbeatSeconds": 60
```

Without timeouts, a workflow may remain stuck waiting for work that will never finish. AWS Step Functions best practices recommend configuring timeouts to prevent stuck executions. ([AWS Documentation][33])

---

# 72. Step Functions payload size

The maximum input or output size for a task, state or execution is:

```text
256 KiB
```

Store large documents in S3 and pass references rather than carrying them through every state. ([AWS Documentation][34])

Good:

```json
{
  "bucket": "production-processing",
  "key": "jobs/job-104/input.json"
}
```

Bad:

```text
A 50 MB dataset carried in workflow state
```

---

# 73. Inline Map

Inline Map processes a list inside the workflow payload.

```text
Items:
[A, B, C, D]
   |
   v
Map
├── Process A
├── Process B
├── Process C
└── Process D
```

Use when:

* Input fits within workflow payload limits.
* Concurrency is moderate.
* Execution-history size remains manageable.

---

# 74. Distributed Map

Distributed Map supports large-scale parallel processing using child workflow executions and can read datasets directly from S3 sources.

It can overcome the normal 256 KiB input limitation for the dataset and support up to 10,000 parallel child executions in one Map Run, subject to quotas and target capacity. ([AWS Documentation][35])

Use cases:

* Process millions of S3 objects.
* Transform CSV records.
* Run batch AI inference.
* Validate a large object inventory.
* Generate thumbnails for a large media collection.

---

# 75. Do not overwhelm downstream systems

Bad:

```text
Distributed Map concurrency:
10,000

Database supports:
200 connections
```

Result:

```text
Database overload
Throttling
Failures
Retries
Larger overload
```

Set concurrency according to:

* Lambda concurrency.
* API rate limits.
* Database capacity.
* Queue throughput.
* Third-party limits.
* Cost limits.

---

# 76. Saga pattern

A distributed transaction cannot usually roll back with a single database transaction.

Example:

```text
1. Charge payment.
2. Reserve inventory.
3. Book shipment.
```

If shipment fails:

```text
Compensate:
Release inventory.
Refund payment.
```

Workflow:

```text
ChargePayment
      ↓
ReserveInventory
      ↓
BookShipment
      |
      ├── Success → Complete
      |
      └── Failure
              ↓
       ReleaseInventory
              ↓
        RefundPayment
              ↓
          OrderFailed
```

This is a saga-style compensation pattern.

---

# 77. Compensation is not database rollback

```text
Database rollback:
Erases an uncommitted local transaction.

Compensating transaction:
Creates a new business action that logically reverses
a previously completed distributed action.
```

Examples:

```text
Charge:
Refund

Reserve:
Release

Ship:
Cannot truly reverse after delivery;
may require return workflow
```

Define compensation during workflow design—not after production failure.

---

# 78. Idempotency in Step Functions tasks

Even a Standard workflow should call idempotent task implementations where practical.

Example payment request:

```json
{
  "idempotencyKey": "order-501-payment",
  "amount": 125.50
}
```

Payment service:

```text
Key does not exist:
Charge and store result.

Key exists:
Return original result.
```

This protects against:

* Client retries.
* Task retries.
* Manual workflow restart.
* Operator replay.
* Network uncertainty.

---

# 79. Nested workflows

Large workflows can be split into reusable child state machines.

```text
OrderWorkflow
├── PaymentWorkflow
├── InventoryWorkflow
├── FulfilmentWorkflow
└── NotificationWorkflow
```

Nested workflows reduce main-state-machine complexity and allow common processes to be reused. AWS recommends nested executions for reusable workflow components. ([AWS Documentation][36])

---

# 80. Choreography versus orchestration

## Choreography

```text
OrderCreated
    |
    ├── Payment listens
    ├── Inventory listens
    └── Notification listens
```

No central coordinator.

Benefits:

* Loose coupling.
* Independent consumers.
* Easy event fan-out.

Risks:

* Harder to understand full process.
* Complex failure recovery.
* Hidden event dependencies.
* Difficult business-state visibility.

## Orchestration

```text
Step Functions
    |
    ├── Payment
    ├── Inventory
    └── Notification
```

A central workflow controls sequence.

Benefits:

* Explicit process.
* Visible state.
* Central error handling.
* Easier compensation.

Risks:

* More central workflow coupling.
* State-machine design required.

---

# 81. Choosing choreography or orchestration

Use choreography when:

* Consumers are independent.
* Event order is loose.
* No central business transaction is needed.
* New subscribers should be easy to add.

Use orchestration when:

* Sequence is mandatory.
* Compensation is needed.
* A central execution status is required.
* Human approval is involved.
* The process has complex branching.

Production systems frequently use both:

```text
Step Functions orchestrates order processing
        ↓
Publishes OrderCompleted event
        ↓
SNS/EventBridge choreographs analytics and notifications
```

---

# 82. Production TodoApp architecture

```text
User
 |
 v
CloudFront
 |
 v
ALB / API Gateway
 |
 v
Todo API
 |
 ├── Store todo in database
 |
 ├── Publish TodoCreated to EventBridge
 |
 └── Send long-running AI job to SQS
```

Event path:

```text
EventBridge custom bus
├── Rule: TodoCreated
│      └── SNS notification topic
│
├── Rule: Priority=HIGH
│      └── Step Functions workflow
│
└── Rule: Audit event
       └── Firehose/S3 archive
```

AI processing:

```text
SQS processing queue
      |
      v
Worker fleet
      |
      ├── Success → update database
      |
      └── Repeated failure → DLQ
```

---

# 83. TodoApp high-priority workflow

```text
HighPriorityTodoCreated
          |
          v
Step Functions Standard
          |
          v
Validate todo
          |
          v
Generate execution plan
          |
          v
Assign operator
          |
          v
Wait for approval
          |
       ┌──┴───┐
       |      |
    Approved Rejected
       |      |
       v      v
   Schedule  Notify owner
       |
       v
Publish TodoScheduled event
```

Use Standard because:

* The workflow may wait.
* Human approval may be involved.
* Full execution history matters.
* Callback tokens may be required.

---

# 84. Terraform SQS queue and DLQ

```hcl
resource "aws_sqs_queue" "todo_processing_dlq" {
  name = "production-todo-processing-dlq"

  message_retention_seconds = 1209600

  kms_master_key_id = aws_kms_key.messaging.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue" "todo_processing" {
  name = "production-todo-processing"

  visibility_timeout_seconds = 180
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  kms_master_key_id = aws_kms_key.messaging.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.todo_processing_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 85. Redrive allow policy

```hcl
resource "aws_sqs_queue_redrive_allow_policy" "todo_processing_dlq" {
  queue_url = aws_sqs_queue.todo_processing_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"

    sourceQueueArns = [
      aws_sqs_queue.todo_processing.arn
    ]
  })
}
```

A redrive allow policy controls which source queues are permitted to use the queue as a DLQ. ([AWS Documentation][13])

---

# 86. Terraform FIFO queue

```hcl
resource "aws_sqs_queue" "ordered_events" {
  name = "production-ordered-events.fifo"

  fifo_queue                  = true
  content_based_deduplication = false

  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  kms_master_key_id = aws_kms_key.messaging.arn
}
```

Publisher must include:

```text
MessageGroupId
MessageDeduplicationId
```

unless content-based deduplication is enabled for the deduplication ID.

---

# 87. Terraform SNS to SQS fan-out

```hcl
resource "aws_sns_topic" "todo_events" {
  name = "production-todo-events"

  kms_master_key_id = aws_kms_key.messaging.id
}

resource "aws_sns_topic_subscription" "processing_queue" {
  topic_arn = aws_sns_topic.todo_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.todo_processing.arn

  raw_message_delivery = true

  filter_policy_scope = "MessageBody"

  filter_policy = jsonencode({
    eventType = ["TodoCreated"]
  })
}
```

Queue policy:

```hcl
data "aws_iam_policy_document" "todo_processing" {
  statement {
    sid    = "AllowSNSDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.todo_processing.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        aws_sns_topic.todo_events.arn
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "todo_processing" {
  queue_url = aws_sqs_queue.todo_processing.id
  policy    = data.aws_iam_policy_document.todo_processing.json
}
```

---

# 88. Terraform EventBridge bus and rule

```hcl
resource "aws_cloudwatch_event_bus" "todoapp" {
  name = "production-todoapp"
}

resource "aws_cloudwatch_event_rule" "high_priority_todos" {
  name           = "production-high-priority-todos"
  event_bus_name = aws_cloudwatch_event_bus.todoapp.name

  event_pattern = jsonencode({
    source = [
      "com.example.todoapp"
    ]

    detail-type = [
      "Todo Created"
    ]

    detail = {
      priority = [
        "HIGH"
      ]
    }
  })
}
```

Target:

```hcl
resource "aws_cloudwatch_event_target" "high_priority_workflow" {
  rule           = aws_cloudwatch_event_rule.high_priority_todos.name
  event_bus_name = aws_cloudwatch_event_bus.todoapp.name

  arn      = aws_sfn_state_machine.high_priority_todo.arn
  role_arn = aws_iam_role.eventbridge_step_functions.arn

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_dlq.arn
  }

  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }
}
```

---

# 89. Terraform EventBridge archive

```hcl
resource "aws_cloudwatch_event_archive" "todoapp" {
  name             = "production-todoapp-archive"
  event_source_arn = aws_cloudwatch_event_bus.todoapp.arn

  retention_days = 30

  event_pattern = jsonencode({
    source = [
      "com.example.todoapp"
    ]
  })
}
```

Archive only events with genuine replay value rather than every high-volume low-value event.

---

# 90. Step Functions state-machine example

```json
{
  "Comment": "High-priority Todo workflow",
  "StartAt": "ValidateTodo",
  "States": {
    "ValidateTodo": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Arguments": {
        "FunctionName": "validate-todo",
        "Payload": "{% $states.input %}"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 2,
          "BackoffRate": 2,
          "MaxAttempts": 4
        }
      ],
      "Catch": [
        {
          "ErrorEquals": [
            "States.ALL"
          ],
          "Next": "ValidationFailed"
        }
      ],
      "Next": "IsValid"
    },
    "IsValid": {
      "Type": "Choice",
      "Choices": [
        {
          "Condition": "{% $states.input.Payload.valid = true %}",
          "Next": "PublishValidatedEvent"
        }
      ],
      "Default": "ValidationFailed"
    },
    "PublishValidatedEvent": {
      "Type": "Task",
      "Resource": "arn:aws:states:::events:putEvents",
      "Arguments": {
        "Entries": [
          {
            "Source": "com.example.todoapp",
            "DetailType": "Todo Validated",
            "Detail": "{% $string($states.input.Payload) %}",
            "EventBusName": "production-todoapp"
          }
        ]
      },
      "End": true
    },
    "ValidationFailed": {
      "Type": "Fail",
      "Error": "TodoValidationFailed"
    }
  }
}
```

Exact Amazon States Language fields depend on whether the workflow uses JSONPath or JSONata query language.

---

# 91. CLI lab: create an SQS queue

Generate names:

```bash
QUEUE_NAME="todo-processing-$(date +%s)"
DLQ_NAME="${QUEUE_NAME}-dlq"
```

Create DLQ:

```bash
DLQ_URL=$(
  aws sqs create-queue \
    --queue-name "$DLQ_NAME" \
    --attributes \
      MessageRetentionPeriod=1209600 \
    --query QueueUrl \
    --output text \
    --region ap-south-1
)
```

Get ARN:

```bash
DLQ_ARN=$(
  aws sqs get-queue-attributes \
    --queue-url "$DLQ_URL" \
    --attribute-names QueueArn \
    --query Attributes.QueueArn \
    --output text \
    --region ap-south-1
)
```

Create source queue:

```bash
QUEUE_URL=$(
  aws sqs create-queue \
    --queue-name "$QUEUE_NAME" \
    --attributes \
      VisibilityTimeout=60,\
ReceiveMessageWaitTimeSeconds=20,\
MessageRetentionPeriod=345600,\
RedrivePolicy="{\"deadLetterTargetArn\":\"$DLQ_ARN\",\"maxReceiveCount\":\"3\"}" \
    --query QueueUrl \
    --output text \
    --region ap-south-1
)
```

---

# 92. Send and receive a message

Send:

```bash
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{
    "eventId":"evt-104",
    "type":"TodoCreated",
    "todoId":"todo-501"
  }' \
  --region ap-south-1
```

Receive:

```bash
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --wait-time-seconds 20 \
  --visibility-timeout 60 \
  --attribute-names All \
  --message-attribute-names All \
  --region ap-south-1
```

Delete after success:

```bash
aws sqs delete-message \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE" \
  --region ap-south-1
```

---

# 93. Simulate DLQ behavior

Receive without deleting:

```bash
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --visibility-timeout 1 \
  --wait-time-seconds 1 \
  --region ap-south-1
```

Repeat enough times to exceed `maxReceiveCount`.

Then inspect DLQ:

```bash
aws sqs receive-message \
  --queue-url "$DLQ_URL" \
  --wait-time-seconds 5 \
  --attribute-names All \
  --region ap-south-1
```

Do this only in a lab queue.

---

# 94. Monitoring checklist

## SQS

Monitor:

```text
Oldest message age
Visible backlog
In-flight messages
Message send rate
Delete rate
Empty receives
DLQ depth
```

## SNS

Monitor:

```text
Messages published
Delivery successes
Delivery failures
Filtered messages
DLQ messages
Archive and replay status
```

## EventBridge

Monitor:

```text
Matched events
Invocations
Failed invocations
Throttled rules
DLQ depth
Archive health
Pipe execution failures
Scheduler target failures
```

## Step Functions

Monitor:

```text
Executions started
Executions succeeded
Executions failed
Executions timed out
Executions aborted
Execution throttling
Task failures
Map Run failures
Execution duration
```

---

# 95. Troubleshooting: SQS messages are processed repeatedly

Check:

```text
Visibility timeout too short
Consumer crashes before delete
DeleteMessage failing
Wrong receipt handle
Consumer processing not idempotent
Long processing without visibility extension
```

Fix:

```text
Set appropriate timeout
Extend while processing
Delete only after success
Store idempotency state
Monitor processing duration
```

---

# 96. Troubleshooting: queue backlog grows

Possible causes:

* Too few consumers.
* Consumer failures.
* Downstream database slow.
* Dependency throttling.
* Messages take longer than expected.
* Poison messages.
* Lambda concurrency limits.
* Worker deployment failure.
* Network outage.
* Producer traffic spike.

Calculate:

```text
Arrival rate
versus
Processing rate
```

If:

```text
Arrival rate > Processing rate
```

the backlog will continue growing even when consumers are technically healthy.

---

# 97. Troubleshooting: FIFO queue throughput is low

Check:

```text
All messages use one MessageGroupId
Consumer waits serially
Batching disabled
Downstream service slow
Visibility timeout blocks same group
Queue or account quota
```

Messages from the same FIFO group are processed in sequence.

Increase concurrency by using more legitimate business message groups—not by choosing random groups that violate ordering requirements.

---

# 98. Troubleshooting: SNS message not in SQS

Check:

```text
Subscription confirmed
Queue policy allows sns.amazonaws.com
aws:SourceArn matches topic
Filter policy matches
FilterPolicyScope is correct
Topic and queue types are compatible
KMS key policy permits SNS
Subscription DLQ
CloudWatch delivery metrics
```

A correctly configured IAM identity policy does not replace the SQS queue resource policy required for SNS delivery.

---

# 99. Troubleshooting: EventBridge rule does not invoke target

Check:

```text
Event reached correct event bus
Rule enabled
Event pattern matches exact field names
Detail type and source correct
Target role has permission
Target resource policy permits EventBridge
Target Region correct
Retry metrics
DLQ
```

Test pattern:

```bash
aws events test-event-pattern \
  --event-pattern file://pattern.json \
  --event file://event.json
```

Remember:

```text
detail-type
```

is different from:

```text
detailType
```

inside an EventBridge envelope.

---

# 100. Troubleshooting: EventBridge loop

Example:

```text
Rule detects security-group change
        ↓
Lambda updates security group
        ↓
Update creates another event
        ↓
Rule invokes Lambda again
```

Fix with:

* More precise event pattern.
* Idempotency.
* Tag identifying remediated resources.
* State comparison before changing.
* Dedicated event type for remediation.
* Maximum recursion or workflow guard.

AWS explicitly warns that event rules can create recursive event loops if target actions create events that match the same rule. ([AWS Documentation][22])

---

# 101. Troubleshooting: Step Functions execution failed

Inspect:

```text
Failed state
Error name
Cause
Input entering state
Retry history
Catch configuration
IAM execution role
Target service logs
Payload size
Timeout
```

Common errors:

```text
States.Timeout
States.TaskFailed
States.Permissions
States.DataLimitExceeded
Lambda.TooManyRequestsException
```

`States.DataLimitExceeded` cannot be solved by repeatedly retrying the same oversized payload. Store data externally and pass a reference.

---

# 102. Cost considerations

## SQS

Cost drivers:

* API requests.
* Message payload chunks.
* KMS requests.
* Empty polling requests.
* Data transfer where applicable.

Use:

* Long polling.
* Batch actions.
* Appropriate message size.
* Reasonable encryption-key strategy.

## SNS

Cost drivers:

* Published requests.
* Subscriber deliveries.
* Data transfer.
* SMS/email/mobile delivery categories.
* Archive and replay.
* KMS requests.

## EventBridge

Cost drivers:

* Custom or partner events.
* Rule invocations.
* Pipes.
* Scheduler invocations.
* Archives and replay.
* API destinations.

## Step Functions

Cost drivers differ by workflow type:

```text
Standard:
State transitions

Express:
Executions, duration and memory usage
```

Do not replace simple one-step processing with a 100-state workflow without understanding operational and cost value.

---

# 103. Production messaging checklist

```text
[ ] Synchronous and asynchronous operations are separated
[ ] Correct service is selected
[ ] Queue type is intentional
[ ] FIFO message groups match business ordering
[ ] Deduplication IDs are stable
[ ] Consumers are idempotent
[ ] Visibility timeout exceeds normal processing time
[ ] Long jobs extend message visibility
[ ] Messages are deleted only after success
[ ] Long polling is enabled
[ ] Retention is intentional
[ ] Large payloads are stored in S3
[ ] Batching is enabled where appropriate
[ ] Source queues have DLQs
[ ] DLQ retention exceeds source retention
[ ] DLQ alarms exist
[ ] Safe redrive runbook exists
[ ] Poison-message strategy exists
[ ] Backlog-age alarms exist
[ ] SNS subscriptions use filters where useful
[ ] SNS subscription DLQs are considered
[ ] EventBridge rules are narrowly scoped
[ ] EventBridge targets have retries and DLQs
[ ] Event archives exist where replay is required
[ ] Event schemas are versioned
[ ] Step Functions workflow type is intentional
[ ] Tasks have retries for transient failures
[ ] Permanent failures are caught correctly
[ ] Timeouts and heartbeats are configured
[ ] Compensation logic is documented
[ ] Workflow payloads remain below limits
[ ] Distributed Map concurrency protects dependencies
[ ] KMS and queue policies are least privilege
[ ] CloudWatch metrics and alarms are configured
```

---

# 104. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
SQS:
Managed queues

SNS:
Managed pub/sub topics

EventBridge:
Event routing

Step Functions:
Workflow orchestration
```

## Solutions Architect Associate

Understand:

```text
Standard versus FIFO queues
Visibility timeout
Long polling
DLQs
SNS fan-out
Message filtering
EventBridge rules
Archive and replay
Standard versus Express workflows
Retries and catches
```

## DevOps Engineer Professional

Understand:

```text
Idempotency
Back-pressure
Safe DLQ redrive
Cross-account event routing
EventBridge Pipes
Scheduler
Schema governance
Step Functions service integrations
Distributed Map
Saga compensation
Rate and concurrency controls
Terraform messaging infrastructure
```

---

# 105. Interview questions

## Question 1: What is the difference between SQS and SNS?

**Answer:**

SQS stores messages until a consumer retrieves and deletes them. SNS publishes one message to multiple subscribers in a pub/sub model.

## Question 2: What is the difference between SNS and EventBridge?

**Answer:**

SNS primarily performs topic-based fan-out. EventBridge performs content-based event matching and routing through event buses and rules.

## Question 3: What is a visibility timeout?

**Answer:**

It is the period during which a received SQS message is hidden from other consumers while being processed.

## Question 4: What happens if the consumer does not delete a message?

**Answer:**

After the visibility timeout, the message becomes visible and can be processed again.

## Question 5: Why must an SQS consumer be idempotent?

**Answer:**

Standard queues use at-least-once delivery, and even FIFO consumers can reprocess a message when processing succeeds but deletion does not.

## Question 6: What is long polling?

**Answer:**

It lets an SQS receive request wait for messages instead of immediately returning an empty response, reducing unnecessary polling.

## Question 7: What is a dead-letter queue?

**Answer:**

It stores messages that exceeded the configured processing-attempt threshold so they can be investigated and redriven safely.

## Question 8: What is `maxReceiveCount`?

**Answer:**

It is the number of times an SQS message may be received before SQS moves it to the configured DLQ.

## Question 9: What is a FIFO message group?

**Answer:**

It is an identifier that defines the set of messages whose processing order must be preserved.

## Question 10: What is SNS message filtering?

**Answer:**

It allows each subscription to receive only messages matching its message-attribute or message-body filter policy.

## Question 11: Why place SQS behind SNS?

**Answer:**

It combines SNS fan-out with durable buffering, independent consumer scaling, queue retries and backlog monitoring.

## Question 12: Does EventBridge preserve ordering?

**Answer:**

No general FIFO ordering guarantee exists. Use SQS FIFO or SNS FIFO where strict ordered processing is required.

## Question 13: What is an EventBridge event pattern?

**Answer:**

It is a JSON structure that specifies which events match a rule and should be sent to its targets.

## Question 14: What is EventBridge Pipes?

**Answer:**

It connects one supported source to one target with optional filtering, batching, transformation and enrichment.

## Question 15: What is EventBridge Scheduler?

**Answer:**

It invokes AWS targets using one-time, rate or cron schedules with time-zone, retry and DLQ support.

## Question 16: What is the difference between Step Functions Standard and Express?

**Answer:**

Standard supports long-running, auditable, exactly-once workflow execution and advanced integration patterns. Express is optimized for high-volume short executions and uses at-least-once or at-most-once semantics depending on invocation mode.

## Question 17: What is a callback task?

**Answer:**

It pauses a Standard workflow until an external worker returns the provided task token through `SendTaskSuccess` or `SendTaskFailure`.

## Question 18: What is a saga?

**Answer:**

It is a distributed transaction pattern that uses compensating business operations to reverse previously completed steps after a later failure.

## Question 19: What is Distributed Map?

**Answer:**

It is a Step Functions Map mode for processing large datasets through highly parallel child workflow executions, including data read from S3.

## Question 20: How should messaging failures be handled?

**Answer:**

Classify transient and permanent errors, retry transient failures with backoff, make consumers idempotent, route exhausted failures to DLQs, alert owners and redrive only after fixing the root cause.

---

# 106. Never-forget revision

```text
SQS:
Durable message queue.

Standard queue:
At-least-once, highly scalable, unordered.

FIFO queue:
Ordered per message group with deduplication.

Visibility timeout:
Temporary message-processing lock.

Long polling:
Waits for messages and reduces empty receives.

DLQ:
Stores repeatedly failed messages.

Idempotency:
Repeated processing has one logical effect.

SNS:
Topic-based pub/sub fan-out.

SNS filter:
Routes only matching messages to a subscription.

EventBridge:
Content-based event routing.

Event bus:
Receives events.

Rule:
Matches events and invokes targets.

Archive:
Stores events for replay.

Pipe:
One source to one target.

Scheduler:
Time-based target invocation.

Step Functions:
Stateful workflow orchestration.

Standard workflow:
Long-running and auditable.

Express workflow:
High-volume and short-running.

Retry:
Repeats transiently failed work.

Catch:
Routes failed work to recovery handling.

Callback:
Waits for external completion.

Saga:
Distributed workflow with compensation.

Distributed Map:
Large-scale parallel workflow processing.
```

## One-line memory trick

```text
SQS stores work.
SNS broadcasts messages.
EventBridge routes events.
Step Functions controls the journey.
DLQs preserve failure.
Idempotency makes retries safe.
```

## Lesson 40 outcome

You can now design an architecture where:

```text
Traffic suddenly increases
    → SQS buffers the backlog.

A message is delivered twice
    → Idempotency prevents duplicate business effects.

One event has many consumers
    → SNS fans it out to separate queues.

Only selected consumers need an event
    → SNS filters route the correct messages.

Business events require content-based routing
    → EventBridge rules select targets.

A target is unavailable
    → EventBridge retries and sends exhausted events to a DLQ.

Events need reprocessing
    → EventBridge or SNS FIFO archives support replay.

A long business process needs sequencing
    → Step Functions orchestrates every state.

A later step fails
    → Saga compensation reverses earlier operations.
```

**Next lesson: Lesson 41 — AWS Lambda production architecture: execution environments, cold starts, concurrency, versions, aliases, layers, event-source mappings, destinations, retries, VPC networking, security and deployment strategies.**

[1]: https://docs.aws.amazon.com/pdfs/decision-guides/latest/sns-or-sqs-or-eventbridge/sns-or-sqs-or-eventbridge.pdf?utm_source=chatgpt.com "Amazon SQS, Amazon SNS, or EventBridge? - AWS Decision guide"
[2]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html?utm_source=chatgpt.com "Amazon SQS standard queues - Amazon Simple Queue Service"
[3]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fifo-queues.html?utm_source=chatgpt.com "Amazon SQS FIFO queues - Amazon Simple Queue Service"
[4]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fifo-queue-message-identifiers.html?utm_source=chatgpt.com "FIFO queue and message identifiers in Amazon SQS - Amazon Simple Queue Service"
[5]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html?utm_source=chatgpt.com "Exactly-once processing in Amazon SQS - Amazon Simple Queue Service"
[6]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_SendMessage.html?utm_source=chatgpt.com "SendMessage - Amazon Simple Queue Service"
[7]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html?utm_source=chatgpt.com "Amazon SQS visibility timeout"
[8]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-short-and-long-polling.html?utm_source=chatgpt.com "Amazon SQS short and long polling"
[9]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html?utm_source=chatgpt.com "Amazon SQS message quotas"
[10]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-queues.html?utm_source=chatgpt.com "Amazon SQS standard queue quotas"
[11]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-batch-api-actions.html?utm_source=chatgpt.com "Amazon SQS batch actions - Amazon Simple Queue Service"
[12]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-dead-letter-queue.html?utm_source=chatgpt.com "Configure a dead-letter queue using the Amazon SQS console"
[13]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html?utm_source=chatgpt.com "Using dead-letter queues in Amazon SQS"
[14]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-available-cloudwatch-metrics.html?utm_source=chatgpt.com "Available CloudWatch metrics for Amazon SQS"
[15]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-delivery.html?utm_source=chatgpt.com "Amazon SNS message delivery for FIFO topics - Amazon Simple Notification Service"
[16]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html?utm_source=chatgpt.com "Amazon SNS message filtering - Amazon Simple Notification Service"
[17]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html?utm_source=chatgpt.com "Amazon SNS message attributes - Amazon Simple Notification Service"
[18]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-delivery-retries.html?utm_source=chatgpt.com "Amazon SNS message delivery retries - Amazon Simple Notification Service"
[19]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-archiving-replay.html?utm_source=chatgpt.com "Amazon SNS message archiving and replay for FIFO topics - Amazon Simple Notification Service"
[20]: https://docs.aws.amazon.com/sns/latest/dg/message-archiving-and-analytics.html?utm_source=chatgpt.com "Amazon SNS message archiving, replay, and analytics - Amazon Simple Notification Service"
[21]: https://docs.aws.amazon.com/eventbridge/latest/userguide/event-reference.html?utm_source=chatgpt.com "Amazon EventBridge events detail reference"
[22]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html?utm_source=chatgpt.com "Creating Amazon EventBridge event patterns"
[23]: https://docs.aws.amazon.com/eventbridge/latest/ref/event-delivery-level.html?utm_source=chatgpt.com "Delivery level for AWS service events - Amazon EventBridge"
[24]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html?utm_source=chatgpt.com "How EventBridge retries delivering events - Amazon EventBridge"
[25]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-dlq.html?utm_source=chatgpt.com "Using dead-letter queues to process undelivered events in EventBridge - Amazon EventBridge"
[26]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-archive.html?utm_source=chatgpt.com "Archiving and replaying events in Amazon EventBridge - Amazon EventBridge"
[27]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-schema.html?utm_source=chatgpt.com "Amazon EventBridge schemas"
[28]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-bus.html?utm_source=chatgpt.com "Event buses in Amazon EventBridge"
[29]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-sqs.html?utm_source=chatgpt.com "Amazon Simple Queue Service as a source in EventBridge ..."
[30]: https://docs.aws.amazon.com/eventbridge/latest/userguide/using-eventbridge-scheduler.html?utm_source=chatgpt.com "Amazon EventBridge Scheduler - Amazon EventBridge"
[31]: https://docs.aws.amazon.com/step-functions/latest/dg/choosing-workflow-type.html?utm_source=chatgpt.com "Choosing workflow type in Step Functions - AWS Step Functions"
[32]: https://docs.aws.amazon.com/step-functions/latest/dg/integrate-optimized.html?utm_source=chatgpt.com "Integrating optimized services with Step Functions - AWS Step Functions"
[33]: https://docs.aws.amazon.com/step-functions/latest/dg/sfn-best-practices.html?utm_source=chatgpt.com "Best practices for Step Functions - AWS Step Functions"
[34]: https://docs.aws.amazon.com/step-functions/latest/dg/service-quotas.html?utm_source=chatgpt.com "Step Functions service quotas - AWS Step Functions"
[35]: https://docs.aws.amazon.com/step-functions/latest/dg/state-map.html?utm_source=chatgpt.com "Map workflow state - AWS Step Functions"
[36]: https://docs.aws.amazon.com/step-functions/latest/dg/connect-stepfunctions.html?utm_source=chatgpt.com "Start a new AWS Step Functions state machine from a running execution - AWS Step Functions"
