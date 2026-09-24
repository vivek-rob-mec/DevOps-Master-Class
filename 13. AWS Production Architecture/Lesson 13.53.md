# AWS Masterclass — Phase 3

# Lesson 52: Amazon SQS, SNS and EventBridge Production Messaging Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Distinguish queues, topics, event buses and schedules.
* Choose between Amazon SQS, Amazon SNS and Amazon EventBridge.
* Decouple application components safely.
* Design competing-consumer and publish/subscribe systems.
* Choose between SQS Standard and FIFO queues.
* Configure visibility timeouts, long polling, retention and delivery delays.
* Design message-group and deduplication strategies.
* Use dead-letter queues without turning them into permanent message storage.
* Process SQS safely using Lambda partial-batch responses.
* Build SNS fan-out architectures.
* Filter SNS messages by attributes or message body.
* Use SNS FIFO topics for ordered fan-out.
* Archive and replay SNS FIFO messages.
* Design EventBridge event buses, rules and event patterns.
* Handle EventBridge partial `PutEvents` failures.
* Configure target retries and dead-letter queues.
* Archive and replay EventBridge events.
* Use EventBridge Pipes for point-to-point integration.
* Use EventBridge Scheduler for one-time and recurring work.
* Design idempotent consumers and transactional outbox patterns.
* Secure messaging systems using IAM, KMS, resource policies and VPC endpoints.
* Monitor queue depth, message age, delivery failures and event latency.
* Provision production messaging infrastructure using Terraform.

---

# 2. The messaging mental model

Distributed applications should not require every component to be online at the same time.

Without messaging:

```text
Todo API
   |
   | Synchronous request
   v
Notification service
   |
   | Synchronous request
   v
Analytics service
```

If analytics fails:

```text
User request may fail
```

With messaging:

```text
Todo API
   |
   v
Message or event
   |
   ├── Notification consumer
   ├── Analytics consumer
   └── Search-index consumer
```

The API records or publishes work, and downstream systems process it independently.

---

# 3. The three-service memory model

```text
Amazon SQS
    = Store work until a consumer processes it

Amazon SNS
    = Broadcast one message to multiple subscribers

Amazon EventBridge
    = Route events according to their content
```

## Never-forget trick

```text
SQS:
Queue

SNS:
Topic

EventBridge:
Event bus
```

---

# 4. Queue versus topic versus event bus

## Queue

```text
Producer
    |
    v
Queue
    |
    v
One of several competing consumers
```

One message is normally processed by one consumer.

Use for:

* Background jobs.
* Work distribution.
* Buffering traffic.
* Retryable processing.
* Protecting downstream capacity.

## Topic

```text
Publisher
    |
    v
Topic
    |
    ├── Subscriber A
    ├── Subscriber B
    └── Subscriber C
```

Every subscribed destination can receive a copy.

Use for:

* Fan-out.
* Notifications.
* Broadcasting domain events.
* Delivering to several queues.

## Event bus

```text
Event producer
      |
      v
Event bus
      |
      ├── Rule: completed todos
      ├── Rule: high-priority todos
      └── Rule: security events
```

EventBridge evaluates the event’s structure and routes matching events to configured targets. It is a serverless event-routing service designed for loosely coupled event-driven applications. ([AWS Documentation][1])

---

# 5. SQS, SNS and EventBridge together

These services are complementary rather than mutually exclusive.

```text
Todo API
   |
   v
EventBridge
   |
   ├── Rule: TodoCompleted
   |        |
   |        v
   |       SNS
   |        |
   |        ├── Email queue
   |        └── Mobile notification queue
   |
   └── Rule: SearchableTodoChanged
            |
            v
           SQS
            |
            v
       Search indexer
```

Here:

* EventBridge performs content-based routing.
* SNS performs fan-out.
* SQS buffers processing for individual consumers.

---

# Part 1 — Amazon SQS

# 6. What is Amazon SQS?

Amazon Simple Queue Service is a managed message queue used to decouple distributed application components.

```text
Producer
    |
    v
SQS queue
    |
    v
Consumer
```

Messages remain in the queue until:

* A consumer receives and deletes them.
* Their retention period expires.
* They are moved to a dead-letter queue.
* An administrator deletes or purges them.

SQS is a durable hosted queue that exposes a managed API and integrates with AWS services and SDKs. ([AWS Documentation][2])

---

# 7. Competing-consumer model

Suppose the queue contains:

```text
Message 1
Message 2
Message 3
Message 4
```

Workers:

```text
Worker A
Worker B
Worker C
```

Possible distribution:

```text
Worker A → Message 1
Worker B → Message 2
Worker C → Message 3
Worker A → Message 4
```

Each worker shares the queue workload.

This allows horizontal scaling:

```text
Queue backlog increases
        |
        v
Add more consumers
        |
        v
Messages processed faster
```

---

# 8. SQS queue types

SQS provides:

```text
Standard queues
FIFO queues
```

You cannot change a queue’s type after it has been created, so the ordering and throughput requirements should be established before provisioning it. ([AWS Documentation][3])

---

# 9. Standard queues

Standard queues provide:

* Very high throughput.
* At-least-once delivery.
* Best-effort ordering.
* Horizontal consumer scaling.
* Low operational overhead.

Possible deliveries:

```text
Sent:
A B C

Received:
A C B
```

A message may occasionally be delivered more than once:

```text
A B B C
```

Therefore:

```text
Standard-queue consumers must be idempotent.
```

Use Standard queues when absolute ordering is not required and duplicates can be handled safely. ([AWS Documentation][4])

---

# 10. FIFO queues

FIFO means:

```text
First In, First Out
```

FIFO queues provide:

* Ordered delivery within a message group.
* Producer deduplication.
* Message-group-based parallelism.
* High-throughput FIFO configuration.
* The same fundamental durability and queue capabilities as Standard queues.

Messages with the same `MessageGroupId` are received in order, while separate groups can be processed concurrently. ([AWS Documentation][5])

Example:

```text
MessageGroupId = TODO#501

TODO_CREATED
TODO_ASSIGNED
TODO_COMPLETED
```

These events are processed sequentially for todo 501.

---

# 11. Choosing Standard or FIFO

```text
Does strict ordering matter?
    |
    ├── No → Standard queue
    |
    └── Yes
          |
          v
Can ordering be scoped to an entity or group?
          |
          ├── Yes → FIFO with several message groups
          └── No  → FIFO with one group, but low parallelism
```

Use FIFO when:

* Commands must be processed in order.
* Inventory updates must remain sequential per product.
* Account events require per-account ordering.
* Duplicate producer submissions must be suppressed.

Use Standard when:

* Image processing jobs are independent.
* Email jobs can be processed in any order.
* Logs or analytics events are independently handled.
* Maximum throughput and easy parallelism matter more than ordering.

---

# 12. Message structure

An SQS message can contain:

```text
Message body
Message attributes
System attributes
Message ID
Receipt handle after receiving
```

Example body:

```json
{
  "eventId": "event-9382",
  "eventType": "TODO_COMPLETED",
  "todoId": "501",
  "userId": "104",
  "occurredAt": "2026-08-02T02:45:00+05:30"
}
```

Example attributes:

```text
environment = production
tenantId    = tenant-38
schema      = todo-event-v2
```

The receipt handle identifies one particular receive operation and is required when deleting or changing visibility for the received message.

---

# 13. Message-size limits

SQS currently supports message bodies from 1 KiB through 1,024 KiB, with a default maximum of 1,024 KiB for newly configured queues. SNS remains limited to 256 KiB for normal non-SMS publish payloads, while EventBridge `PutEvents` requests can contain up to 1 MiB in total. ([AWS Documentation][6])

For large payloads, a safer architecture is:

```text
Large payload
     |
     v
Amazon S3
     |
     v
SQS message:
{
  "bucket": "...",
  "key": "...",
  "versionId": "...",
  "checksum": "..."
}
```

Benefits:

* Smaller messages.
* Lower transfer overhead.
* Easier retry handling.
* Independent payload lifecycle.
* Integrity checking.

Delete the S3 payload only after all required consumers are finished with it.

---

# 14. Sending a message

```bash
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{
    "eventId": "event-9382",
    "eventType": "TODO_COMPLETED",
    "todoId": "501"
  }' \
  --region ap-south-1
```

FIFO example:

```bash
aws sqs send-message \
  --queue-url "$FIFO_QUEUE_URL" \
  --message-body '{
    "eventId": "event-9382",
    "eventType": "TODO_COMPLETED",
    "todoId": "501"
  }' \
  --message-group-id "TODO#501" \
  --message-deduplication-id "event-9382" \
  --region ap-south-1
```

---

# 15. Receive, process and delete

Consumer flow:

```text
Receive message
      |
      v
Message becomes invisible
      |
      v
Process message
      |
      ├── Success → Delete message
      └── Failure → Do not delete
```

Example:

```bash
aws sqs receive-message \
  --queue-url "$QUEUE_URL" \
  --max-number-of-messages 10 \
  --wait-time-seconds 20 \
  --message-system-attribute-names All \
  --message-attribute-names All \
  --region ap-south-1
```

Delete after successful processing:

```bash
aws sqs delete-message \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE" \
  --region ap-south-1
```

Receiving a message does not remove it permanently.

---

# 16. Visibility timeout

When a consumer receives a message, SQS hides it from other consumers for the visibility-timeout period.

```text
Message received
      |
      v
Invisible for 60 seconds
      |
      ├── Deleted before timeout → Completed
      └── Not deleted            → Visible again
```

The default visibility timeout is 30 seconds and can be configured up to 12 hours. ([AWS Documentation][7])

## Correct sizing

```text
Visibility timeout
>
Normal maximum processing duration
```

Example:

```text
p99 processing duration:
45 seconds

Visibility timeout:
90 seconds
```

---

# 17. Visibility timeout that is too short

Suppose processing takes 60 seconds:

```text
Visibility timeout:
30 seconds
```

Timeline:

```text
0s:
Worker A receives message

30s:
Message becomes visible

31s:
Worker B receives same message

60s:
Worker A completes
```

Now two workers may execute the same business operation.

Consumer idempotency is still required even with a FIFO queue because an accepted message can be redelivered when processing is not completed and deleted before visibility expires. ([AWS Documentation][7])

---

# 18. Extending visibility

For variable-duration work:

```text
Receive message
      |
      v
Start processing
      |
      v
Periodically extend visibility
      |
      v
Delete after completion
```

Example:

```bash
aws sqs change-message-visibility \
  --queue-url "$QUEUE_URL" \
  --receipt-handle "$RECEIPT_HANDLE" \
  --visibility-timeout 120 \
  --region ap-south-1
```

Use a heartbeat-style extension only while the worker is genuinely active.

Do not continually extend a poisoned message forever.

---

# 19. Delivery delay

A delay queue hides a message when it first enters the queue.

```text
Message sent
      |
      v
Hidden for 5 minutes
      |
      v
Available to consumers
```

Queue-level delivery delay can be configured from zero through 15 minutes. Delay is different from visibility timeout: delay applies before the first delivery, while visibility applies after a message has been received. ([AWS Documentation][8])

Use for:

* Brief deferred processing.
* Retry cooldown.
* Delayed notification.
* Allowing eventual consistency to settle.

For longer or precise scheduling, use EventBridge Scheduler rather than chaining repeated SQS delays.

---

# 20. Message retention

SQS message retention can be configured from:

```text
Minimum:
1 minute

Default:
4 days

Maximum:
14 days
```

Messages not deleted before retention expires are removed automatically. ([AWS Documentation][6])

Retention should exceed:

```text
Longest expected outage
+
Recovery time
+
Safety margin
```

Example:

```text
Maximum acceptable consumer outage:
3 days

Recovery and backlog processing:
2 days

Retention:
7 days
```

---

# 21. Short polling versus long polling

## Short polling

```text
ReceiveMessage returns immediately
```

It may return no messages even when messages exist on another queue partition.

## Long polling

```text
ReceiveMessage waits for messages
for up to 20 seconds
```

Long polling:

* Reduces empty responses.
* Reduces API calls.
* Reduces consumer cost.
* Reduces tight polling loops.
* Usually provides more efficient message retrieval.

SQS supports a receive wait time from zero to 20 seconds; a nonzero value enables long polling. ([AWS Documentation][6])

Production default:

```text
WaitTimeSeconds = 20
```

unless the consumer has a specific low-latency reason to use a shorter wait.

---

# 22. Batch operations

SQS supports batch operations for up to ten messages per request, including:

* Sending.
* Deleting.
* Changing visibility.

Batching:

```text
10 API calls
    |
    v
1 batch API call
```

Benefits:

* Lower request cost.
* Higher throughput.
* Fewer network round trips.

Batch responses can contain partial failures.

Correct handling:

```text
Retry only failed entries
```

Do not resend successful batch entries automatically.

---

# 23. Standard-queue idempotency

Example message:

```json
{
  "eventId": "event-9382",
  "eventType": "TODO_COMPLETED",
  "todoId": "501"
}
```

DynamoDB idempotency record:

```text
PK = EVENT#event-9382
```

Consumer flow:

```text
Conditional PutItem:
attribute_not_exists(PK)
        |
        ├── Succeeds → Process event
        └── Fails    → Event already processed
```

For relational databases:

```sql
CREATE TABLE processed_events (
    event_id VARCHAR(128) PRIMARY KEY,
    processed_at TIMESTAMP NOT NULL
);
```

Perform the idempotency insert and business update inside one transaction where possible.

---

# 24. FIFO deduplication

FIFO queues support:

```text
Explicit MessageDeduplicationId
or
Content-based deduplication
```

SQS tracks deduplication IDs for five minutes. If the producer retries the same message with the same deduplication ID during that window, SQS acknowledges the send but does not introduce another copy into the queue. ([AWS Documentation][9])

Example:

```text
MessageDeduplicationId:
event-9382
```

Content-based deduplication calculates a hash from the message body, but message attributes are not the main business identity.

Use explicit business IDs when possible.

---

# 25. FIFO “exactly once” clarification

AWS describes FIFO queues as supporting exactly-once processing by preventing duplicate message insertion through deduplication. ([AWS Documentation][4])

However, application code should still be idempotent because:

* Visibility timeout can expire.
* The consumer can crash before deletion.
* A Lambda batch can be retried.
* Processing can succeed before the delete call fails.
* The same business operation can be published later with a different deduplication ID.
* The five-minute deduplication window can expire.

Practical rule:

```text
FIFO improves delivery guarantees.

Idempotency protects business correctness.
```

---

# 26. FIFO message groups

```text
MessageGroupId = TODO#501
```

Messages in that group are processed sequentially.

Different groups can be processed concurrently:

```text
TODO#501 → Worker A
TODO#502 → Worker B
TODO#503 → Worker C
```

The number and distribution of message groups therefore control parallelism. FIFO queues block further messages from one group while an earlier message from that group is invisible and awaiting deletion. ([AWS Documentation][5])

---

# 27. FIFO head-of-line blocking

Queue:

```text
Group TODO#501:
A → B → C
```

If A repeatedly fails:

```text
A blocks B and C
```

Other groups can continue:

```text
TODO#502:
D → E → F
```

Mitigations:

* Short bounded retries.
* Correct visibility timeout.
* Dead-letter queue.
* Alerts on message age.
* A repair or replay process.
* Enough distinct message groups.

---

# 28. FIFO throughput

Default FIFO throughput is limited per API action, while batching increases message throughput. High-throughput FIFO mode increases capacity by distributing messages across internal partitions, and effective throughput depends on having enough distinct `MessageGroupId` values. ([AWS Documentation][10])

Design principle:

```text
One message group:
Strict total order
Low parallelism

Many message groups:
Per-group order
High parallelism
```

Do not use:

```text
MessageGroupId = ALL
```

for a high-volume queue unless every message genuinely requires one total order.

---

# 29. Dead-letter queues

A dead-letter queue stores messages that could not be processed after repeated receives.

```text
Source queue
     |
     | Receive count exceeds maxReceiveCount
     v
Dead-letter queue
```

Example redrive policy:

```json
{
  "deadLetterTargetArn": "arn:aws:sqs:ap-south-1:123456789012:todo-dlq",
  "maxReceiveCount": 5
}
```

SQS DLQs isolate problematic messages for later investigation instead of allowing them to block or repeatedly consume normal processing capacity. ([AWS Documentation][11])

---

# 30. Choosing `maxReceiveCount`

Too low:

```text
Temporary failure
    |
    v
Message moved to DLQ unnecessarily
```

Too high:

```text
Poison message
    |
    v
Retried hundreds of times
    |
    v
Cost and processing waste
```

Example:

```text
maxReceiveCount = 5

Visibility timeout = 60 seconds
```

Theoretical minimum before DLQ:

```text
Approximately five processing attempts
```

Actual timing also depends on consumer polling and processing duration.

---

# 31. DLQ is not permanent storage

A DLQ should have:

* A documented owner.
* CloudWatch alarms.
* Sufficient retention.
* A message-inspection process.
* Root-cause classification.
* A redrive process.
* Message-age monitoring.
* Access controls.

Bad operational model:

```text
Messages enter DLQ
      |
      v
Nobody looks at them
```

Correct model:

```text
DLQ receives message
      |
      v
Alert fires
      |
      v
Operator or automation classifies failure
      |
      v
Fix root cause
      |
      v
Redrive safely
```

---

# 32. DLQ retention behaviour

For Standard queues, message expiration continues to be based on the original enqueue timestamp even after movement to a DLQ. For FIFO queues, the enqueue timestamp resets when the message enters the DLQ. AWS recommends configuring DLQ retention longer than source-queue retention. ([AWS Documentation][11])

Example:

```text
Source retention:
4 days

DLQ retention:
14 days
```

---

# 33. DLQ and strict FIFO order

Moving one failed message out of a FIFO sequence allows later messages in the group to continue.

That is useful operationally, but it means:

```text
Original complete business order
is no longer being processed as one uninterrupted sequence.
```

For workflows where skipping one item makes all following items invalid:

* Stop processing the whole business aggregate.
* Alert immediately.
* Resolve and replay in order.
* Consider a state-machine workflow instead of a simple queue.

---

# 34. Redriving messages

After correcting the underlying problem, messages can be moved from a DLQ back to:

* Their original source queue.
* Another destination queue.
* A controlled repair queue.

Before redrive:

```text
1. Fix the consumer.
2. Confirm permissions.
3. Estimate replay volume.
4. Protect downstream capacity.
5. Confirm idempotency.
6. Enable monitoring.
7. Redrive gradually.
```

Never redrive thousands of messages directly into an unchanged broken consumer.

---

# 35. SQS with Lambda

```text
SQS queue
    |
    v
Lambda event-source mapping
    |
    v
Lambda invocation with batch
```

Lambda:

* Polls the queue.
* Receives batches.
* Invokes the function.
* Deletes successfully processed messages.
* Scales concurrency according to queue and configuration.

Because SQS and Lambda use at-least-once processing, Lambda handlers must be idempotent. ([AWS Documentation][12])

---

# 36. Lambda batch failure

Batch:

```text
A
B
C
D
```

Suppose C fails.

Without partial-batch handling:

```text
A B C D
are returned for retry
```

This repeats successful work for A, B and D.

With partial-batch response:

```text
Only C is retried
```

AWS recommends partial-batch response logic for SQS event-source mappings to avoid retrying successfully processed records. ([AWS Documentation][12])

---

# 37. Lambda partial-batch example

```javascript
export const handler = async (event) => {
  const batchItemFailures = [];

  for (const record of event.Records) {
    try {
      const message = JSON.parse(record.body);

      await processMessageIdempotently(message);
    } catch (error) {
      console.error("Message processing failed", {
        messageId: record.messageId,
        error: error.message
      });

      batchItemFailures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return {
    batchItemFailures
  };
};
```

Configure the event-source mapping with:

```text
ReportBatchItemFailures
```

---

# 38. FIFO Lambda batch behaviour

For FIFO queues, once one message in a group fails, processing later messages from that group may violate required order.

Recommended strategy:

```text
Process messages in batch order.

After first failure in a message group:
mark that message and later unprocessed group messages as failed.
```

Do not report a later same-group message as successful when an earlier group message failed and business ordering matters.

---

# 39. Protecting downstream systems

Suppose:

```text
Queue backlog:
1,000,000 messages

Lambda maximum concurrency:
Unlimited for this workload

RDS safe concurrent connections:
200
```

Uncontrolled scaling can overload RDS.

Use:

* Lambda reserved concurrency.
* Event-source maximum concurrency.
* Small database connection pools.
* RDS Proxy.
* Controlled batch size.
* Application rate limiting.
* SQS visibility appropriate to processing.

The queue absorbs excess traffic; the consumer should drain it at a rate the downstream system can sustain.

---

# 40. Important SQS metrics

Monitor:

```text
ApproximateNumberOfMessagesVisible
ApproximateNumberOfMessagesNotVisible
ApproximateNumberOfMessagesDelayed
ApproximateAgeOfOldestMessage
NumberOfMessagesSent
NumberOfMessagesReceived
NumberOfMessagesDeleted
NumberOfEmptyReceives
SentMessageSize
```

The most important business signal is often:

```text
ApproximateAgeOfOldestMessage
```

Queue depth alone can be misleading.

Example:

```text
Queue depth:
100,000

Processing rate:
50,000 per second

Age:
2 seconds
```

This may be healthy.

Another queue:

```text
Queue depth:
100

Oldest age:
6 hours
```

This may be a serious failure.

---

# 41. SQS security

Use:

* IAM producer and consumer policies.
* Queue resource policies.
* KMS server-side encryption.
* TLS through AWS APIs.
* VPC interface endpoints.
* CloudTrail.
* Separate queues per trust boundary.
* Condition keys for source services.

Producer permissions:

```text
sqs:SendMessage
sqs:SendMessageBatch
```

Consumer permissions:

```text
sqs:ReceiveMessage
sqs:DeleteMessage
sqs:ChangeMessageVisibility
sqs:GetQueueAttributes
```

Avoid:

```json
{
  "Action": "sqs:*",
  "Resource": "*"
}
```

for application roles.

---

# Part 2 — Amazon SNS

# 42. What is Amazon SNS?

Amazon Simple Notification Service is a managed publish/subscribe service.

```text
Publisher
    |
    v
SNS topic
    |
    ├── SQS queue
    ├── Lambda
    ├── HTTPS endpoint
    ├── Email
    ├── SMS
    └── Mobile push
```

Publishers send messages to a logical topic rather than directly managing every subscriber. ([AWS Documentation][13])

---

# 43. SNS fan-out

Without SNS:

```text
Application
├── Send notification queue
├── Send analytics queue
├── Send audit queue
└── Send search queue
```

With SNS:

```text
Application
    |
    | Publish once
    v
SNS topic
    |
    ├── Notification queue
    ├── Analytics queue
    ├── Audit queue
    └── Search queue
```

This reduces coupling between the publisher and subscriber list.

---

# 44. Why SNS plus SQS?

SNS alone pushes messages to subscribers.

Combining SNS with SQS provides:

```text
SNS:
Fan-out

SQS:
Durable buffering and independent retry
```

Architecture:

```text
SNS topic
   |
   ├── SQS queue A → Consumer A
   ├── SQS queue B → Consumer B
   └── SQS queue C → Consumer C
```

If consumer B is offline:

```text
Queue B retains its messages
```

Consumers A and C continue normally.

This is one of the most common production messaging patterns.

---

# 45. SNS Standard topics

Standard topics provide:

* High-throughput fan-out.
* At-least-once delivery.
* Best-effort ordering.
* Many supported endpoint types.
* Subscription filtering.
* Batching support.

Use when:

* Subscribers do not require strict order.
* Consumers are idempotent.
* Broad endpoint flexibility is needed.
* High fan-out throughput matters.

---

# 46. SNS FIFO topics

SNS FIFO topics provide ordered publishing and deduplication semantics for applications requiring ordered fan-out.

```text
SNS FIFO topic
       |
       ├── SQS FIFO queue A
       └── SQS FIFO queue B
```

For end-to-end ordering and deduplication, use:

```text
SNS FIFO
    +
SQS FIFO
```

SNS FIFO topics can also deliver to Standard queues, but the Standard queue does not provide the same end-to-end FIFO processing guarantee. SNS FIFO topics use message groups so different groups can be delivered concurrently while order is maintained within a group. ([AWS Documentation][14])

---

# 47. SNS message size

SNS messages, excluding SMS-specific handling, are limited to 256 KiB. Message attributes count toward that limit. SNS batch publishing supports up to ten messages, but both each individual message and the complete batch payload are subject to the 256-KiB boundary. ([AWS Documentation][15])

For larger payloads:

```text
Payload → S3
SNS message → S3 reference
```

AWS provides payload-offloading libraries for payloads larger than the normal SNS limit, supporting S3-backed messages up to 2 GB in compatible workflows. ([AWS Documentation][16])

---

# 48. Publishing to SNS

```bash
aws sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message '{
    "eventId": "event-9382",
    "eventType": "TODO_COMPLETED",
    "todoId": "501"
  }' \
  --message-attributes '{
    "eventType": {
      "DataType": "String",
      "StringValue": "TODO_COMPLETED"
    },
    "environment": {
      "DataType": "String",
      "StringValue": "production"
    }
  }' \
  --region ap-south-1
```

FIFO publish:

```bash
aws sns publish \
  --topic-arn "$FIFO_TOPIC_ARN" \
  --message '{"eventId":"event-9382","todoId":"501"}' \
  --message-group-id "TODO#501" \
  --message-deduplication-id "event-9382" \
  --region ap-south-1
```

---

# 49. Subscription filtering

By default, each subscriber receives every published message.

A subscription filter policy restricts delivery.

Example:

```json
{
  "eventType": [
    "TODO_COMPLETED",
    "TODO_DELETED"
  ],
  "environment": [
    "production"
  ]
}
```

Now only matching messages are delivered to that subscription.

SNS supports filtering using exact string values, numeric ranges, prefixes, suffixes, IP addresses and other operators. ([AWS Documentation][17])

---

# 50. Attribute versus body filtering

Filter scope can use:

```text
MessageAttributes
or
MessageBody
```

## Attribute filtering

Publisher sends:

```text
eventType = TODO_COMPLETED
tenantId = tenant-38
```

Best when routing values are simple and intentionally exposed as metadata.

## Message-body filtering

Publisher body:

```json
{
  "detail": {
    "eventType": "TODO_COMPLETED",
    "tenantId": "tenant-38"
  }
}
```

Best when routing should use the actual event document and avoid duplicating fields into attributes.

Keep publisher contracts consistent; do not sometimes put `eventType` in an attribute and sometimes only in the body.

---

# 51. Subscription filter example

Notification queue filter:

```json
{
  "eventType": [
    "TODO_ASSIGNED",
    "TODO_DUE_SOON"
  ]
}
```

Analytics queue filter:

```json
{
  "eventType": [
    {
      "prefix": "TODO_"
    }
  ]
}
```

Security queue filter:

```json
{
  "severity": [
    "HIGH",
    "CRITICAL"
  ]
}
```

SNS filtering is applied per subscription, so the publisher remains unaware of the downstream routing policy.

---

# 52. Raw message delivery

By default, an SQS subscription can receive an SNS envelope such as:

```json
{
  "Type": "Notification",
  "MessageId": "...",
  "TopicArn": "...",
  "Message": "{\"eventType\":\"TODO_COMPLETED\"}",
  "Timestamp": "..."
}
```

With raw message delivery enabled:

```json
{
  "eventType": "TODO_COMPLETED"
}
```

is delivered directly.

Use raw delivery when:

* The consumer wants the original body.
* SNS envelope metadata is unnecessary.
* Simpler parsing is preferred.

Do not enable it if the consumer relies on SNS metadata or signatures in the envelope.

---

# 53. SQS subscription queue policy

SNS requires permission to send to the SQS queue.

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowTodoTopic",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "arn:aws:sqs:ap-south-1:123456789012:todo-notifications",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "arn:aws:sns:ap-south-1:123456789012:todo-events"
        }
      }
    }
  ]
}
```

The `aws:SourceArn` condition prevents unrelated SNS topics from sending to the queue.

---

# 54. SNS delivery retries

SNS delivery behaviour depends on the subscription protocol.

Examples:

* SQS delivery uses managed service-to-service delivery.
* Lambda invokes the function asynchronously.
* HTTP/S subscriptions use configurable delivery policies.
* Email and SMS use channel-specific behaviour.

Downstream consumers should still be idempotent because Standard-topic delivery can occur more than once.

---

# 55. SNS subscription DLQ

An SNS subscription can use an SQS dead-letter queue for messages that SNS cannot deliver to that subscriber.

```text
SNS topic
    |
    v
Subscriber target fails
    |
    v
Subscription DLQ
```

Distinguish:

```text
SNS subscription DLQ:
SNS could not deliver to subscriber.

Consumer queue DLQ:
Subscriber queue delivered, but consumer could not process.
```

For SNS-to-SQS architecture, both may exist:

```text
SNS subscription delivery DLQ
+
SQS processing DLQ
```

They represent different failure stages.

---

# 56. SNS FIFO deduplication

SNS FIFO publishing uses:

* `MessageGroupId`.
* `MessageDeduplicationId`.
* Optional content-based deduplication.

Design:

```text
MessageGroupId:
TODO#501

MessageDeduplicationId:
event-9382
```

Different groups can progress concurrently; one group remains ordered. Use a large number of well-distributed groups for higher topic throughput. ([AWS Documentation][18])

---

# 57. SNS FIFO filtering caveat

A filter can intentionally remove messages from a subscriber’s sequence.

Original group:

```text
A B C D
```

Subscriber filter accepts:

```text
A C
```

The subscriber receives A before C, but does not receive B or D.

This is still ordered delivery of the messages selected for that subscription, not a complete copy of the producer’s sequence.

---

# 58. SNS FIFO archive and replay

SNS FIFO topics can archive published messages for up to 365 days. Subscribers can replay a chosen time window to recover from downstream failures or initialize a new subscriber’s state. ([AWS Documentation][19])

```text
SNS FIFO topic
      |
      ├── Current subscribers
      |
      └── Topic archive
             |
             | Replay selected period
             v
         Subscriber
```

Use cases:

* Subscriber outage recovery.
* State replication.
* New subscriber initialization.
* Correcting downstream bugs.
* Controlled reprocessing.

Consumers must be idempotent because replay intentionally resends previously delivered messages.

---

# 59. Important SNS metrics

Monitor:

```text
NumberOfMessagesPublished
NumberOfNotificationsDelivered
NumberOfNotificationsFailed
NumberOfNotificationsFilteredOut
NumberOfNotificationsFilteredOut-NoMessageAttributes
NumberOfNotificationsFilteredOut-InvalidAttributes
PublishSize
```

For SMS or mobile delivery, additional channel-specific metrics apply.

`NumberOfNotificationsFailed` should normally have an alarm for critical application topics. SNS publishes topic metrics to CloudWatch at one-minute intervals for active topics. ([AWS Documentation][20])

---

# Part 3 — Amazon EventBridge

# 60. What is EventBridge?

EventBridge is a managed event-routing service.

```text
Event producers
├── AWS services
├── Custom applications
└── SaaS integrations
        |
        v
Event bus
        |
        v
Rules
        |
        ├── Lambda
        ├── SQS
        ├── SNS
        ├── Step Functions
        ├── Kinesis
        └── API destination
```

EventBridge focuses on describing and routing events rather than storing a worker backlog like SQS. ([AWS Documentation][1])

---

# 61. Event envelope

Example EventBridge event:

```json
{
  "version": "0",
  "id": "event-9382",
  "detail-type": "Todo Completed",
  "source": "com.yourdatascientist.todoapp",
  "account": "123456789012",
  "time": "2026-08-02T02:45:00+05:30",
  "region": "ap-south-1",
  "resources": [
    "arn:aws:dynamodb:ap-south-1:123456789012:table/todos"
  ],
  "detail": {
    "todoId": "501",
    "userId": "104",
    "tenantId": "tenant-38",
    "schemaVersion": 2
  }
}
```

## Recommended fields

```text
id:
Unique event ID

source:
Producer namespace

detail-type:
Human-readable event category

detail:
Business payload

time:
Occurrence time

schemaVersion:
Your event-contract version
```

---

# 62. EventBridge event size

`PutEvents` supports up to ten entries per request. The total request payload must remain below 1 MiB, and one event can use nearly the full 1-MiB request when it is the only entry. AWS recommends placing larger content in S3 and publishing an object reference. ([AWS Documentation][21])

Example:

```json
{
  "detail-type": "Large Export Ready",
  "source": "com.todoapp.export",
  "detail": {
    "bucket": "production-todo-exports",
    "key": "exports/export-104.json",
    "versionId": "...",
    "checksum": "..."
  }
}
```

---

# 63. Event buses

EventBridge supports:

```text
Default event bus
Custom event buses
Partner event buses
```

## Default event bus

Receives many AWS service events.

## Custom event bus

Receives your application and cross-account events.

Example:

```text
todoapp-production
security-production
platform-production
```

## Partner event bus

Receives supported SaaS partner events.

Use separate event buses when boundaries differ by:

* Environment.
* Business domain.
* Security ownership.
* Account.
* Organisational platform.

---

# 64. Event rules

A rule contains:

```text
Event pattern
+
One or more targets
```

Example pattern:

```json
{
  "source": [
    "com.yourdatascientist.todoapp"
  ],
  "detail-type": [
    "Todo Completed"
  ],
  "detail": {
    "tenantId": [
      "tenant-38"
    ],
    "priority": [
      "HIGH"
    ]
  }
}
```

EventBridge compares incoming events with event patterns and invokes targets only for matching events. ([AWS Documentation][22])

---

# 65. Event-pattern operators

Patterns can match:

* Exact values.
* Prefixes.
* Suffixes.
* Numeric comparisons.
* Anything except listed values.
* Field existence.
* Wildcards.
* IP-address ranges.
* Nested fields.

Example:

```json
{
  "detail": {
    "durationMs": [
      {
        "numeric": [
          ">",
          5000
        ]
      }
    ]
  }
}
```

Use filtering at the event bus to avoid invoking targets for irrelevant events.

---

# 66. Publishing events

```bash
aws events put-events \
  --entries '[
    {
      "Source": "com.yourdatascientist.todoapp",
      "DetailType": "Todo Completed",
      "EventBusName": "todoapp-production",
      "Detail": "{\"eventId\":\"event-9382\",\"todoId\":\"501\",\"tenantId\":\"tenant-38\"}"
    }
  ]' \
  --region ap-south-1
```

---

# 67. `PutEvents` partial failures

`PutEvents` can return HTTP 200 while individual entries failed.

Response concept:

```json
{
  "FailedEntryCount": 1,
  "Entries": [
    {
      "EventId": "accepted-event-id"
    },
    {
      "ErrorCode": "InternalFailure",
      "ErrorMessage": "..."
    }
  ]
}
```

Correct producer:

```text
Inspect FailedEntryCount
      |
      v
Retry only failed entries
```

Additionally, publishing to a nonexistent event-bus name can return success without a failed-entry count while no rule matches and the event is effectively dropped, so bus names should be validated and managed as configuration. ([AWS Documentation][21])

---

# 68. EventBridge delivery ordering

Do not treat an EventBridge bus as a FIFO stream.

If strict ordering matters:

* Route events to SQS FIFO.
* Use a message-group key.
* Use Kinesis with a stable partition key.
* Use Kafka/MSK with a stable record key.
* Include aggregate version numbers.

EventBridge is designed for scalable routing and decoupling, not as a global ordered log.

---

# 69. EventBridge targets

Targets can include services such as:

* Lambda.
* SQS.
* SNS.
* Step Functions.
* Kinesis.
* ECS tasks.
* API destinations.
* Other event buses.
* CloudWatch Logs.
* Systems Manager.
* CodePipeline.

A target role may be required depending on the target service.

Use a different IAM role per sensitive target where practical.

---

# 70. Input transformation

The original event:

```json
{
  "detail": {
    "todoId": "501",
    "userId": "104"
  },
  "source": "com.todoapp"
}
```

can be transformed into target input:

```json
{
  "task": "send-completion-email",
  "todoId": "501",
  "recipientUser": "104"
}
```

Benefits:

* Target receives only required fields.
* Event producer remains decoupled from target API format.
* Sensitive or irrelevant fields can be omitted.
* One source event can be transformed differently for each target.

Do not use transformations to hide an unstable event contract. Maintain versioned event schemas.

---

# 71. EventBridge target retries

For retryable failures, EventBridge rules retry target delivery using exponential backoff and jitter.

Default target-delivery policy:

```text
Maximum event age:
24 hours

Maximum retry attempts:
185
```

After retries are exhausted, EventBridge drops the event unless a dead-letter queue is configured. ([AWS Documentation][23])

Production recommendation:

```text
Configure a DLQ for every critical rule target.
```

---

# 72. EventBridge target DLQ

```text
Event bus
    |
    v
Rule
    |
    v
Target delivery fails repeatedly
    |
    v
SQS DLQ
```

The DLQ contains the undelivered event and diagnostic attributes.

EventBridge must have permission to send to the SQS queue. AWS recommends DLQs to avoid losing events after target retries are exhausted. ([AWS Documentation][24])

---

# 73. Producer failure versus target-delivery failure

Two different failure stages exist:

```text
Producer
   |
   | PutEvents
   v
Event bus
   |
   | Rule target delivery
   v
Target
```

## Producer publication failure

Detected from:

```text
PutEvents FailedEntryCount
```

Handled by the producer.

## Target delivery failure

Handled by:

```text
EventBridge retry policy
+
Target DLQ
```

One DLQ does not solve both stages.

---

# 74. EventBridge archive

An EventBridge archive stores selected events from one event bus.

```text
Event bus
    |
    ├── Rules and targets
    |
    └── Archive
```

You can configure:

* An event filter.
* A retention period.
* Indefinite retention.
* AWS-owned or customer-managed encryption.

EventBridge archives can later replay selected time windows to the original event bus. ([AWS Documentation][25])

---

# 75. Event replay

Example incident:

```text
10:00–11:00:
Search-index target was broken

11:30:
Target fixed
```

Replay:

```text
Archive
   |
   | Select 10:00–11:00
   v
Original event bus
   |
   v
Rules execute again
```

Use cases:

* Rebuild a projection.
* Recover after consumer failure.
* Test new functionality.
* Repopulate a new downstream system.
* Correct a processing bug.

Replayed events contain replay metadata, and EventBridge automatically prevents replayed events from being re-archived by the managed archive rule. ([AWS Documentation][25])

Consumers must be idempotent.

---

# 76. EventBridge schema registry

EventBridge Schemas helps discover, create and manage event schemas.

It includes:

* Schemas for AWS service events.
* Custom schema registries.
* Schema versions.
* Event discovery from buses.
* Code-binding generation for supported languages.

EventBridge can infer unique schemas observed on an event bus and add them to a registry. Be cautious because discovered event values may contain sensitive information. ([AWS Documentation][26])

Use schema governance to prevent producer and consumer drift.

---

# 77. Event versioning

Bad evolution:

```json
Version 1:
{
  "userId": "104"
}
```

Later:

```json
Version 2:
{
  "user": {
    "id": "104"
  }
}
```

Old consumers break.

Better:

```json
{
  "schemaVersion": 2,
  "userId": "104",
  "user": {
    "id": "104"
  }
}
```

During migration:

1. Add new fields without removing old fields.
2. Update consumers.
3. Monitor old-field usage.
4. Publish a new event type or major version for breaking changes.
5. Remove old contract only after all consumers migrate.

---

# 78. Cross-account event buses

A central event bus can receive events from application accounts.

```text
Application account A ─┐
Application account B ─┼──> Central event bus
Application account C ─┘
```

Controls:

* Event-bus resource policy.
* AWS Organizations conditions.
* Source-account conditions.
* Event pattern filtering.
* Target roles.
* Separate producer and consumer permissions.

Avoid granting every account unrestricted `events:PutEvents` access to every event bus.

---

# 79. EventBridge global endpoints

Global endpoints can route event publication between primary and secondary Regions using Route 53 health checks.

```text
Publisher
    |
    v
EventBridge global endpoint
    |
    ├── Primary bus: ap-south-1
    └── Secondary bus: ap-southeast-1
```

Matching buses and rules are required in both Regions. Event replication is recommended and is required for automatic recovery back to the primary after failover without manual health-check intervention. ([AWS Documentation][27])

Global endpoints protect event ingestion, but complete regional resilience also requires:

* Targets in both Regions.
* Replicated application data.
* Regional IAM roles.
* Regional queues and state machines.
* Tested failover and recovery.

---

# 80. API destinations

API destinations let EventBridge call external HTTPS endpoints.

```text
EventBridge rule
      |
      v
API destination
      |
      v
External SaaS API
```

Authentication is stored through an EventBridge Connection.

Use for:

* Ticketing systems.
* CRM updates.
* External webhooks.
* Incident platforms.
* Partner APIs.

API destinations require the endpoint to respond within five seconds; timed-out requests are retried according to target retry configuration. ([AWS Documentation][28])

For long-running external work:

```text
API destination starts job
    |
    v
External system returns quickly
    |
    v
Completion arrives later through callback or event
```

---

# Part 4 — EventBridge Pipes

# 81. What is EventBridge Pipes?

An EventBridge Pipe connects:

```text
One source
    |
    v
Optional filter
    |
    v
Optional enrichment
    |
    v
One target
```

A pipe is point-to-point integration, while an event bus supports one-to-many routing through several rules. ([AWS Documentation][29])

---

# 82. Pipe architecture

```text
SQS queue
    |
    v
Filter:
eventType = TODO_COMPLETED
    |
    v
Enrichment Lambda:
add user email
    |
    v
Step Functions workflow
```

A pipe can reduce custom poller and glue code.

---

# 83. Pipe sources

Supported source categories include services such as:

* SQS.
* Kinesis Data Streams.
* DynamoDB Streams.
* Amazon MSK.
* Self-managed Kafka.
* Amazon MQ.

The pipe manages source polling and invocation.

For stream and queue sources, use batching and concurrency controls to protect the target.

---

# 84. Pipe filtering

Pipe filters use EventBridge event-pattern syntax.

Example:

```json
{
  "body": {
    "eventType": [
      "TODO_COMPLETED"
    ],
    "priority": [
      "HIGH"
    ]
  }
}
```

Only matching source records continue through the pipe. ([AWS Documentation][30])

Filter early to avoid:

* Unnecessary enrichment.
* Unnecessary target invocations.
* Target cost.
* Noise.

---

# 85. Pipe enrichment

Enrichment can call a supported service to add or transform information.

```text
Source event:
{
  "userId": "104"
}

Enrichment:
Lookup user information

Output:
{
  "userId": "104",
  "email": "..."
}
```

The enrichment response becomes the payload sent to the target. Returning an empty value or empty collection can suppress target invocation. ([AWS Documentation][31])

Enrichment should be:

* Fast.
* Idempotent.
* Bounded by timeout.
* Free of unnecessary side effects.

---

# 86. Pipe batching

For supported sources:

```text
Source messages
A B C D
    |
    v
Pipe batch
[A, B, C, D]
    |
    v
Target
```

When Lambda or Step Functions is the target, a batch is passed as a JSON array because those services do not provide a native batch API for Pipes. ([AWS Documentation][32])

Effective payload size is determined by the smaller of the Pipes limit and the target limit:

```text
Pipes:
Up to 6 MB

EventBridge bus target:
1 MB

Step Functions target:
256 KiB
```

([AWS Documentation][32])

---

# 87. Pipe partial-batch failure

For SQS and supported stream sources, Pipes can use partial-batch failure reporting so successfully processed items are not needlessly retried.

When part of a batch fails, EventBridge retries the remaining failed items. Enrichment may be invoked again during retry, so enrichment must be idempotent and should not create unsafe repeated side effects. ([AWS Documentation][33])

---

# 88. Pipe error handling

Pipes automatically retry retryable failures involving the source, enrichment, target or EventBridge.

Persistent customer configuration failures such as repeated authorization errors can cause the pipe to back off and eventually become disabled with an explanatory state reason. ([AWS Documentation][34])

Monitor:

```text
Pipe state
Pipe state reason
Execution failures
Target failures
Enrichment failures
Throttling
Concurrency
Age or lag at source
```

---

# 89. Pipe logging

Pipes can log individual execution steps, including:

* Source receipt.
* Filtering.
* Enrichment.
* Target invocation.
* Failures.

Execution data can contain sensitive information, and Pipes does not automatically redact such fields. CloudWatch pipe log records are limited to 256 KiB and may be truncated. ([AWS Documentation][35])

Do not include secrets or sensitive personal data unnecessarily in pipe payloads or logs.

---

# Part 5 — EventBridge Scheduler

# 90. What is EventBridge Scheduler?

EventBridge Scheduler is a managed scheduling service supporting:

* One-time schedules.
* Rate-based schedules.
* Cron schedules.
* Time zones.
* Flexible delivery windows.
* Retry policies.
* Dead-letter queues.
* Large numbers of schedules.

It invokes AWS service targets using an execution role. ([AWS Documentation][36])

---

# 91. Scheduler versus scheduled EventBridge rule

Legacy scheduled rules support cron and rate triggers on the default event bus.

EventBridge Scheduler is generally the preferred service for new scheduling requirements because it provides:

* One-time schedules.
* Schedule groups.
* Time-zone support.
* Flexible windows.
* Per-schedule retry and DLQ.
* Automatic deletion after completion.
* Very high schedule scale.

---

# 92. Scheduler schedule types

## One-time

```text
Run at:
2026-08-10 09:00 Asia/Kolkata
```

## Rate based

```text
rate(15 minutes)
```

## Cron based

```text
cron(0 9 ? * MON-FRI *)
```

Scheduler evaluates cron and one-time schedules in the chosen time zone and handles time-zone concepts such as daylight-saving changes. All schedules provide 60-second invocation precision when no flexible window is used. ([AWS Documentation][37])

---

# 93. One-time schedule

Use one-time schedules for:

* Send reminder tomorrow.
* Close temporary access at a timestamp.
* Start a job after a cooling-off period.
* Re-enable a feature later.
* Delete expired resources.
* Process a deferred business action.

Example:

```bash
aws scheduler create-schedule \
  --name "todo-reminder-501" \
  --schedule-expression "at(2026-08-10T09:00:00)" \
  --schedule-expression-timezone "Asia/Kolkata" \
  --flexible-time-window '{"Mode":"OFF"}' \
  --target "{
    \"Arn\":\"$QUEUE_ARN\",
    \"RoleArn\":\"$SCHEDULER_ROLE_ARN\",
    \"Input\":\"{\\\"todoId\\\":\\\"501\\\",\\\"action\\\":\\\"REMIND\\\"}\"
  }" \
  --action-after-completion DELETE \
  --region ap-south-1
```

Use automatic deletion so completed one-time schedules do not remain counted indefinitely. Scheduler quotas include completed one-time schedules until they are deleted, and AWS recommends `ActionAfterCompletion` for cleanup. ([AWS Documentation][38])

---

# 94. Flexible time windows

A flexible time window allows Scheduler to invoke a target sometime during a defined period.

```text
Nominal schedule:
09:00

Flexible window:
15 minutes

Possible invocation:
09:00–09:15
```

This spreads invocation spikes and improves reliable delivery when exact timing is unnecessary. ([AWS Documentation][39])

Use for:

* Daily maintenance.
* Batch cleanup.
* Nonurgent account checks.
* Large fleets of periodic jobs.

Do not use a flexible window for an action that must occur at an exact business deadline.

---

# 95. Scheduler retries

Scheduler supports configuring:

```text
Maximum event age:
Up to 24 hours

Maximum retries:
Up to 185
```

If target invocation still fails, Scheduler can place the undelivered invocation in an SQS DLQ. ([AWS Documentation][40])

Example policy:

```text
Maximum age:
6 hours

Maximum attempts:
10

DLQ:
todo-scheduler-dlq
```

---

# 96. Scheduler DLQ

Scheduler requires a Standard SQS queue for its DLQ.

```text
Schedule
   |
   v
Target invocation fails
   |
   v
Retries exhausted
   |
   v
Standard SQS DLQ
```

The DLQ records information required to investigate the failed scheduled delivery. ([AWS Documentation][41])

Monitor:

```text
InvocationAttemptCount
TargetErrorCount
InvocationDroppedCount
DLQ queue depth
DLQ oldest message age
```

---

# 97. Scheduler execution role

Scheduler assumes an IAM role to invoke its target.

Trust principal:

```text
scheduler.amazonaws.com
```

The role should include only the target operation required.

Example for SQS:

```json
{
  "Effect": "Allow",
  "Action": "sqs:SendMessage",
  "Resource": "arn:aws:sqs:ap-south-1:123456789012:todo-reminders"
}
```

Use trust-policy source conditions to reduce confused-deputy risk. AWS specifically recommends additional production trust controls for Scheduler execution roles. ([AWS Documentation][42])

---

# 98. Scheduler versus Step Functions Wait

## EventBridge Scheduler

Use when:

* The future action is independent.
* Millions of individual schedules may exist.
* A one-time service invocation is required.
* The process does not need a complete workflow history.
* The action may occur long after the original request.

## Step Functions Wait

Use when:

* Waiting is one state inside a larger business workflow.
* Subsequent steps depend on workflow context.
* Compensation or approvals are involved.
* One execution history should show the complete process.

Example:

```text
Reminder only
    → Scheduler

Request deletion
Wait 7 days
Approval
Export
Delete
    → Step Functions
```

---

# 99. Service-selection table

| Requirement                       |                             SQS |                         SNS |                    EventBridge |
| --------------------------------- | ------------------------------: | --------------------------: | -----------------------------: |
| Competing consumers               |                       Excellent |                          No |                             No |
| Buffer work                       |                       Excellent |                     Limited |                        Limited |
| One-to-many fan-out               |               With extra design |                   Excellent |                      Excellent |
| Complex content routing           |                         Limited |        Subscription filters |                      Excellent |
| Strict ordering                   |                            FIFO |  FIFO with FIFO subscribers |        Route to ordered target |
| Worker back-pressure              |                       Excellent |          Use SQS subscriber |                 Use SQS target |
| Long message retention            |                   Up to 14 days | FIFO archive up to 365 days |           Archive configurable |
| Consumer-controlled polling       |                             Yes |                          No |                             No |
| Direct email/SMS                  |                              No |                         Yes |                             No |
| AWS service events                |                         Limited |                     Limited |                      Excellent |
| SaaS integration                  |                         Limited |                      HTTP/S | Partner buses/API destinations |
| Replay                            | DLQ/redrive or retained message |         FIFO archive replay |           Event archive replay |
| One-time scheduling               |                              No |                          No |                      Scheduler |
| Point-to-point source integration |                              No |                          No |                          Pipes |

---

# 100. Common architecture patterns

## Pattern A: Background work queue

```text
API
 |
 v
SQS
 |
 v
Worker fleet
```

Use for:

* Report generation.
* Image conversion.
* Email jobs.
* Batch processing.

## Pattern B: SNS fan-out

```text
Application
    |
    v
SNS
├── SQS notification queue
├── SQS analytics queue
└── SQS audit queue
```

Use when every consumer receives a copy.

## Pattern C: EventBridge routing

```text
Application event
      |
      v
EventBridge
├── Completed todos → Analytics
├── High priority   → Notification
└── Deleted todo    → Audit workflow
```

Use when event content determines the destination.

## Pattern D: EventBridge plus SQS

```text
EventBridge
    |
    v
SQS queue
    |
    v
Consumer
```

Use when you need:

* Content routing.
* Durable buffering.
* Back-pressure.
* Consumer-controlled retries.

---

# 101. Why EventBridge should often target SQS

Direct target:

```text
EventBridge → Lambda
```

If Lambda or its dependency is unavailable, EventBridge retries within its target retry window.

Buffered target:

```text
EventBridge → SQS → Lambda
```

Benefits:

* Queue retains backlog beyond a transient Lambda issue.
* Consumer concurrency is controlled.
* Processing rate is independent of event arrival rate.
* Visibility and processing DLQ are available.
* Operators can inspect backlog.

Tradeoff:

* Additional service.
* Additional latency.
* More resources and monitoring.

Use SQS when downstream capacity and event-arrival capacity can differ materially.

---

# 102. Delivery semantics summary

## SQS Standard

```text
At least once
Best-effort order
```

## SQS FIFO

```text
Ordered per message group
Producer deduplication
Consumer idempotency still required
```

## SNS Standard

```text
At least once
Best-effort order
```

## SNS FIFO

```text
Ordered per message group
Deduplicated publishing
Use SQS FIFO for ordered buffered consumers
```

## EventBridge

```text
At least-once-style target delivery with retries
No FIFO event-bus ordering guarantee
DLQ recommended
```

The only safe universal rule is:

```text
Every consumer must tolerate repeated delivery.
```

---

# 103. Transactional outbox pattern

Problem:

```text
Application:
1. Update database.
2. Publish message.
```

Failure scenario:

```text
Database commit succeeds
Message publication fails
```

Now business state changed but no event exists.

Outbox pattern:

```text
Database transaction
├── Update todo
└── Insert outbox event
        |
        v
Outbox publisher / CDC
        |
        v
SQS, SNS or EventBridge
```

Example transaction:

```sql
BEGIN;

UPDATE todos
SET status = 'COMPLETED'
WHERE todo_id = '501';

INSERT INTO outbox_events (
    event_id,
    aggregate_id,
    event_type,
    payload,
    created_at
)
VALUES (
    'event-9382',
    'TODO#501',
    'TODO_COMPLETED',
    '{"todoId":"501"}',
    CURRENT_TIMESTAMP
);

COMMIT;
```

A separate publisher sends unsent outbox rows and marks them published.

---

# 104. Outbox publisher duplicates

Suppose:

```text
Publisher sends event successfully
      |
      v
Publisher crashes before marking row sent
      |
      v
Publisher sends same event again
```

Therefore outbox consumers still need:

```text
eventId-based idempotency
```

The outbox prevents lost events caused by database/message dual writes.

It does not automatically eliminate duplicate delivery.

---

# 105. Event-envelope recommendation

```json
{
  "eventId": "event-9382",
  "eventType": "TODO_COMPLETED",
  "schemaVersion": 2,
  "aggregateType": "TODO",
  "aggregateId": "TODO#501",
  "aggregateVersion": 7,
  "tenantId": "tenant-38",
  "occurredAt": "2026-08-02T02:45:00+05:30",
  "producer": "todo-api",
  "correlationId": "request-a621",
  "causationId": "command-3f82",
  "payload": {
    "todoId": "501",
    "userId": "104"
  }
}
```

## Why include `aggregateVersion`?

Consumer receives:

```text
Version 8
then
Version 7
```

It can reject or defer version 7 as stale.

This helps manage out-of-order delivery.

---

# 106. Retry architecture

Use retries at the correct layer.

```text
Producer publication retry
    |
    v
Messaging-service delivery retry
    |
    v
Consumer processing retry
    |
    v
DLQ or repair workflow
```

Avoid stacking huge retry counts at every layer.

Example dangerous configuration:

```text
Producer retries:
10

EventBridge retries:
185

Lambda retries:
several

Consumer application retries:
20
```

One original action can produce an enormous number of attempts.

Define:

* Which failures are transient.
* Maximum attempts.
* Maximum total age.
* Backoff.
* Jitter.
* Final failure destination.
* Owner.

---

# 107. Poison-message strategy

```text
Receive message
      |
      v
Validate schema
      |
      ├── Invalid → DLQ immediately or after minimal retries
      |
      v
Perform business processing
      |
      ├── Temporary failure → Retry
      ├── Permanent business rejection → Record outcome
      └── Unknown failure → Bounded retry then DLQ
```

Do not retry malformed JSON 100 times.

Classify failures:

```text
Transient:
Database unavailable

Permanent technical:
Unsupported schema version

Permanent business:
Account closed

Security:
Signature invalid
```

---

# 108. Observability across the message lifecycle

Track:

```text
eventId
correlationId
causationId
traceId
producer
consumer
queue or topic
publish timestamp
receive timestamp
processing attempts
completion timestamp
```

Derived metrics:

```text
Publication latency
Queue wait duration
Processing duration
End-to-end event latency
Retry count
DLQ count
Duplicate count
Success rate
```

Example:

```text
Event occurred:
02:45:00

Entered queue:
02:45:01

Consumer received:
02:45:04

Processing completed:
02:45:06

End-to-end latency:
6 seconds
```

---

# 109. Monitoring SQS-based consumers

Create alarms for:

```text
OldestMessageAge > SLO
VisibleMessages increasing continuously
NotVisibleMessages stuck
DLQ VisibleMessages > 0
Lambda Errors > 0
Lambda Throttles > 0
Consumer concurrency at maximum
Database saturation
```

Dashboard:

```text
Incoming messages/s
Processed messages/s
Backlog
Oldest age
Failures
DLQ depth
Consumer concurrency
End-to-end latency
```

---

# 110. Monitoring EventBridge

Monitor:

```text
PutEvents failed entries
MatchedEvents
Invocations
FailedInvocations
RetryInvocationAttempts
IngestionToInvocationStartLatency
InvocationsSentToDLQ
InvocationsFailedToBeSentToDLQ
ThrottledRules
```

A successful producer API call does not prove:

```text
Target processed the event successfully.
```

You need producer, bus and consumer telemetry.

---

# 111. Cost considerations

## SQS

Cost drivers:

* API requests.
* Payload size.
* KMS requests.
* Empty polling.
* Cross-Region transfer.
* Repeated retries.

Optimise through:

* Long polling.
* Batch APIs.
* Reasonable message size.
* Bounded retries.
* VPC endpoint cost analysis.

## SNS

Cost drivers:

* Published messages.
* Delivery attempts.
* Protocol type.
* SMS and mobile channel charges.
* Payload size and batching.
* Archive storage and replay for FIFO.

## EventBridge

Cost drivers:

* Custom and partner event ingestion.
* Cross-account event delivery.
* Archive processing and storage.
* Replay.
* Pipes requests.
* Scheduler invocations.
* API destination calls.

Do not combine services mechanically. Use each service where it provides a required reliability or routing capability.

---

# Part 6 — Terraform implementation

# 112. Terraform SQS DLQ

```hcl
resource "aws_sqs_queue" "todo_processing_dlq" {
  name = "production-todo-processing-dlq"

  message_retention_seconds = 1209600

  kms_master_key_id = aws_kms_key.messaging.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
    Purpose     = "dead-letter"
  }
}
```

---

# 113. Terraform Standard queue

```hcl
resource "aws_sqs_queue" "todo_processing" {
  name = "production-todo-processing"

  visibility_timeout_seconds = 120
  message_retention_seconds  = 604800
  receive_wait_time_seconds  = 20

  max_message_size = 1048576

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

# 114. DLQ redrive-allow policy

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

This restricts which source queues may use the DLQ.

---

# 115. Terraform FIFO queue

```hcl
resource "aws_sqs_queue" "todo_commands" {
  name = "production-todo-commands.fifo"

  fifo_queue = true

  content_based_deduplication = false

  deduplication_scope = "messageGroup"
  fifo_throughput_limit = "perMessageGroupId"

  visibility_timeout_seconds = 120
  message_retention_seconds  = 604800
  receive_wait_time_seconds  = 20

  kms_master_key_id = aws_kms_key.messaging.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.todo_commands_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

FIFO queue and FIFO DLQ names must use the `.fifo` suffix.

---

# 116. Terraform SNS topic

```hcl
resource "aws_sns_topic" "todo_events" {
  name = "production-todo-events"

  kms_master_key_id = aws_kms_key.messaging.arn

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 117. SNS-to-SQS subscription

```hcl
resource "aws_sns_topic_subscription" "todo_processing" {
  topic_arn = aws_sns_topic.todo_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.todo_processing.arn

  raw_message_delivery = true

  filter_policy_scope = "MessageBody"

  filter_policy = jsonencode({
    eventType = [
      "TODO_CREATED",
      "TODO_UPDATED",
      "TODO_COMPLETED"
    ]
  })
}
```

---

# 118. Queue policy for SNS

```hcl
data "aws_iam_policy_document" "todo_processing_queue" {
  statement {
    sid    = "AllowTodoTopic"
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
  policy    = data.aws_iam_policy_document.todo_processing_queue.json
}
```

---

# 119. Terraform EventBridge custom bus

```hcl
resource "aws_cloudwatch_event_bus" "todoapp" {
  name = "production-todoapp"

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 120. Terraform EventBridge rule

```hcl
resource "aws_cloudwatch_event_rule" "todo_completed" {
  name           = "production-todo-completed"
  description    = "Routes completed TodoApp events"
  event_bus_name = aws_cloudwatch_event_bus.todoapp.name

  event_pattern = jsonencode({
    source = [
      "com.yourdatascientist.todoapp"
    ]

    detail-type = [
      "Todo Completed"
    ]

    detail = {
      environment = [
        "production"
      ]
    }
  })

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 121. EventBridge target with retry and DLQ

```hcl
resource "aws_cloudwatch_event_target" "todo_completed_queue" {
  rule           = aws_cloudwatch_event_rule.todo_completed.name
  event_bus_name = aws_cloudwatch_event_bus.todoapp.name

  target_id = "TodoCompletedQueue"
  arn       = aws_sqs_queue.todo_processing.arn

  retry_policy {
    maximum_event_age_in_seconds = 21600
    maximum_retry_attempts       = 10
  }

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_delivery_dlq.arn
  }
}
```

The target queue requires a resource policy permitting EventBridge to send messages.

---

# 122. EventBridge archive

```hcl
resource "aws_cloudwatch_event_archive" "todoapp" {
  name             = "production-todoapp"
  event_source_arn = aws_cloudwatch_event_bus.todoapp.arn

  retention_days = 90

  event_pattern = jsonencode({
    source = [
      "com.yourdatascientist.todoapp"
    ]
  })

  kms_key_identifier = aws_kms_key.messaging.arn
}
```

Use archive replay carefully because every matching downstream rule can run again.

---

# 123. Terraform EventBridge Pipe

```hcl
resource "aws_iam_role" "todo_pipe" {
  name = "production-todo-pipe"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "pipes.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_pipes_pipe" "todo_processing" {
  name     = "production-todo-processing"
  role_arn = aws_iam_role.todo_pipe.arn

  source = aws_sqs_queue.todo_processing.arn
  target = aws_sfn_state_machine.todo_processor.arn

  source_parameters {
    sqs_queue_parameters {
      batch_size                         = 10
      maximum_batching_window_in_seconds = 5
    }

    filter_criteria {
      filter {
        pattern = jsonencode({
          body = {
            priority = [
              "HIGH"
            ]
          }
        })
      }
    }
  }

  target_parameters {
    step_function_state_machine_parameters {
      invocation_type = "FIRE_AND_FORGET"
    }
  }

  log_configuration {
    level                  = "ERROR"
    include_execution_data = []
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 124. Terraform Scheduler schedule

```hcl
resource "aws_scheduler_schedule" "todo_reminder" {
  name       = "todo-reminder-501"
  group_name = aws_scheduler_schedule_group.todoapp.name

  schedule_expression          = "at(2026-08-10T09:00:00)"
  schedule_expression_timezone = "Asia/Kolkata"

  flexible_time_window {
    mode = "OFF"
  }

  action_after_completion = "DELETE"

  target {
    arn      = aws_sqs_queue.todo_reminders.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      eventType = "TODO_REMINDER"
      todoId    = "501"
    })

    retry_policy {
      maximum_event_age_in_seconds = 21600
      maximum_retry_attempts       = 10
    }

    dead_letter_config {
      arn = aws_sqs_queue.scheduler_dlq.arn
    }
  }
}
```

---

# Part 7 — Troubleshooting

# 125. SQS backlog keeps increasing

Check:

```text
Producer rate
Consumer rate
Consumer errors
Consumer concurrency
Oldest message age
Visibility timeout
Lambda throttling
Downstream capacity
Poison messages
```

Possible causes:

* Producers exceed processing capacity.
* Consumers are failing.
* Lambda reserved concurrency is too low.
* Database is saturated.
* Batch size is inefficient.
* FIFO has too few message groups.
* One message group is blocked.

Scale only after identifying the bottleneck.

---

# 126. Messages are processed twice

Possible causes:

* Standard queue delivery.
* Visibility timeout too short.
* Consumer completed but failed to delete.
* Lambda batch retried.
* Producer retried with a new deduplication ID.
* Idempotency record expired too early.
* Two different events describe the same business action.

Fix:

* Idempotent consumer.
* Longer visibility timeout.
* Partial-batch responses.
* Stable business event IDs.
* Atomic business write and idempotency record.
* Correct delete handling.

---

# 127. Messages remain not visible

High:

```text
ApproximateNumberOfMessagesNotVisible
```

can mean:

* Many consumers are actively processing.
* Consumers are stuck.
* Visibility timeout is excessive.
* Workers crashed.
* Downstream dependency is slow.
* Messages are repeatedly extended.

Check processing duration and consumer logs.

Do not immediately reduce visibility; that can cause concurrent duplicate processing.

---

# 128. FIFO queue has low throughput

Check:

* Number of distinct message groups.
* One hot group.
* Batch APIs.
* High-throughput FIFO settings.
* Message size.
* Consumer group blocking.
* Visibility timeout.
* One poison message blocking a group.
* Regional FIFO quotas.

More consumers do not help one group:

```text
One message group
=
One sequential processing lane
```

---

# 129. DLQ suddenly fills

Classify errors:

```text
Schema failure
Permission failure
Dependency outage
Application bug
Missing resource
Timeout
Business rejection
```

Check whether a recent deployment changed:

* Message schema.
* Credentials.
* IAM policy.
* Database migrations.
* Environment variables.
* Timeout.
* Dependency endpoint.

Pause redrive until the cause is corrected.

---

# 130. SNS subscriber receives nothing

Check:

* Topic ARN and Region.
* Subscription confirmation.
* Queue resource policy.
* KMS permissions.
* Filter policy.
* Filter-policy scope.
* Message attributes.
* Topic type compatibility.
* SNS delivery-failure metrics.
* Subscription DLQ.

A filter-policy mismatch looks like a successful publish with no subscriber delivery.

---

# 131. SNS filter unexpectedly rejects messages

Check:

```text
String versus numeric type
MessageAttributes versus MessageBody scope
Field name case
Nested JSON structure
Missing field
Prefix or suffix rule
Invalid attribute format
```

Example:

```json
{
  "priority": "5"
}
```

is a string, while:

```json
{
  "priority": 5
}
```

is numeric.

Filter according to the actual published data type.

---

# 132. EventBridge rule does not match

Check:

* Correct event bus.
* Correct `source`.
* Correct `detail-type`.
* JSON nesting.
* Array versus scalar structure.
* Number represented as string.
* Event pattern case sensitivity.
* Rule enabled.
* Producer sent expected event.
* Producer used correct bus name.

Use EventBridge pattern-testing tools before deploying complex rules.

---

# 133. EventBridge target fails

Check:

* Target resource exists.
* Target IAM role.
* Target resource policy.
* KMS key permission.
* Target Region.
* Retry age.
* Target DLQ.
* Event payload size.
* Input transformer.
* Target throttling.
* `FailedInvocations` metric.

Do not assume an event-bus match guarantees successful target delivery.

---

# 134. EventBridge event was silently lost at publish time

Check the event-bus name.

`PutEvents` can return HTTP 200 when a referenced event bus does not exist, without incrementing `FailedEntryCount`, because no event matching occurs. ([AWS Documentation][21])

Protect against this through:

* Infrastructure-defined bus ARNs.
* Configuration validation.
* Deployment tests.
* Event-publication metrics.
* Central publishing libraries.
* IAM scoped to exact bus ARNs.

---

# 135. Pipe is disabled

Check pipe:

```text
CurrentState
DesiredState
StateReason
```

Persistent authorization or missing-resource errors can cause a pipe to disable after repeated failures. ([AWS Documentation][34])

Verify:

* Source permission.
* Enrichment permission.
* Target permission.
* KMS permission.
* Resource existence.
* Network connectivity.
* Target payload limit.

---

# 136. Scheduler did not run at the exact second

Scheduler has 60-second precision.

A schedule configured for:

```text
09:00
```

can invoke between:

```text
09:00:00
and
09:00:59
```

when no flexible window is enabled. ([AWS Documentation][37])

Scheduler is not a real-time subsecond timer.

For strict transactional deadlines, design the target system to enforce the deadline based on timestamps rather than depending only on invocation time.

---

# 137. Scheduler one-time schedules accumulate

Completed one-time schedules remain counted until deleted.

Use:

```text
ActionAfterCompletion = DELETE
```

to clean them up automatically. Scheduler supports millions of schedules per Region, but leaving completed schedules indefinitely creates unnecessary quota and inventory pressure. ([AWS Documentation][38])

---

# 138. TodoApp production messaging architecture

```text
Users
  |
  v
Todo API
  |
  ├── Aurora:
  |      Authoritative state
  |
  └── Transactional outbox
          |
          v
     Outbox publisher
          |
          v
     EventBridge bus
          |
          ├── TodoCompleted
          |       |
          |       v
          |      SNS
          |       |
          |       ├── Email SQS queue
          |       └── Mobile SQS queue
          |
          ├── TodoSearchChanged
          |       |
          |       v
          |      SQS
          |       |
          |       v
          |   OpenSearch indexer
          |
          ├── TodoAuditEvent
          |       |
          |       v
          |      Kinesis/S3
          |
          └── TodoReminderRequested
                  |
                  v
           EventBridge Scheduler
                  |
                  v
             Reminder SQS queue
```

---

# 139. Recommended TodoApp service choices

## Todo command queue

```text
SQS FIFO
MessageGroupId = TODO#todoId
```

Use when commands for one todo must remain ordered.

## Search indexing

```text
EventBridge → SQS Standard → indexer
```

Search updates can be idempotent using event and aggregate versions.

## Email and mobile notification

```text
SNS → separate SQS queues
```

Each channel processes independently.

## Todo reminder

```text
EventBridge Scheduler → SQS
```

Create one-time schedules and delete them automatically after completion.

## Audit trail

```text
EventBridge → Kinesis or durable storage pipeline
```

Do not rely only on a 14-day SQS queue for long-term audit retention.

---

# 140. Production readiness checklist

```text
[ ] Queue, topic and event-bus responsibilities are documented
[ ] Standard versus FIFO decision is documented
[ ] Every event has a stable event ID
[ ] Consumers are idempotent
[ ] Message schemas are versioned
[ ] Large payloads are stored in S3
[ ] Message retention exceeds recovery requirements
[ ] Visibility timeout exceeds normal processing duration
[ ] Long polling is enabled
[ ] Batch APIs are used where appropriate
[ ] Partial-batch failures are handled
[ ] FIFO message groups provide sufficient parallelism
[ ] Deduplication IDs use business identity
[ ] Queue backlog alarms exist
[ ] Oldest-message-age alarms exist
[ ] Every critical source queue has a DLQ
[ ] Every DLQ has an owner
[ ] DLQ retention exceeds source retention
[ ] DLQ redrive has been tested
[ ] SNS queue policies restrict source topics
[ ] SNS subscription filters are tested
[ ] Critical SNS subscribers use DLQs
[ ] FIFO topics use FIFO queues for end-to-end order
[ ] EventBridge PutEvents partial failures are inspected
[ ] EventBridge rules are pattern tested
[ ] Critical EventBridge targets use DLQs
[ ] EventBridge retry policies match business deadlines
[ ] Archives are enabled where replay is required
[ ] Replay procedures are tested
[ ] Event schemas are governed
[ ] Cross-account bus policies are least privilege
[ ] Pipes filters reduce unnecessary invocations
[ ] Pipe enrichment is idempotent
[ ] Pipe source concurrency protects targets
[ ] Scheduler roles are least privilege
[ ] Scheduler retries and DLQ are configured
[ ] One-time schedules delete after completion
[ ] KMS policies permit required services
[ ] CloudTrail is enabled
[ ] End-to-end event latency is measured
[ ] Outbox or CDC prevents database/event dual-write loss
```

---

# 141. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
SQS:
Managed queue

SNS:
Managed topic and notifications

EventBridge:
Managed event bus and routing
```

## Solutions Architect Associate

Understand:

```text
Standard versus FIFO
Visibility timeout
Message retention
Long polling
Dead-letter queues
SNS fan-out
Subscription filtering
EventBridge rules
Event patterns
Scheduler
```

## DevOps Engineer Professional

Understand:

```text
Idempotent processing
Partial-batch failures
DLQ redrive
FIFO message-group design
EventBridge target retry policy
Archive and replay
Cross-account event buses
Global endpoints
EventBridge Pipes
Scheduler retry and DLQ
Transactional outbox
End-to-end observability
```

---

# 142. Interview questions

## Question 1: What is Amazon SQS?

**Answer:**

Amazon SQS is a managed queue service that stores messages until consumers process and delete them.

## Question 2: What is the difference between Standard and FIFO queues?

**Answer:**

Standard queues provide very high throughput with at-least-once delivery and best-effort order. FIFO queues preserve order within message groups and suppress producer duplicates within the deduplication window.

## Question 3: What is visibility timeout?

**Answer:**

It is the period during which a received message is hidden from other consumers while one consumer processes it.

## Question 4: What happens when visibility timeout expires?

**Answer:**

If the message was not deleted, it becomes visible and can be received again.

## Question 5: What is long polling?

**Answer:**

It lets `ReceiveMessage` wait for messages for up to 20 seconds, reducing empty responses and API calls.

## Question 6: How long can SQS retain a message?

**Answer:**

From one minute through 14 days, with four days as the default.

## Question 7: What is an SQS DLQ?

**Answer:**

It is another SQS queue that receives messages after they exceed the configured maximum receive count.

## Question 8: Does an SQS FIFO queue remove the need for idempotency?

**Answer:**

No. Visibility expiration, consumer failure, retry and repeated business requests can still cause the business operation to be attempted more than once.

## Question 9: What is `MessageGroupId`?

**Answer:**

It defines the FIFO ordering boundary. Messages in one group are processed sequentially, while different groups can be processed concurrently.

## Question 10: What is Amazon SNS?

**Answer:**

SNS is a managed publish/subscribe service that broadcasts messages from a topic to multiple subscribers.

## Question 11: Why combine SNS with SQS?

**Answer:**

SNS provides fan-out, while each SQS subscription provides durable buffering, independent processing and back-pressure.

## Question 12: What is SNS subscription filtering?

**Answer:**

It applies a policy to one subscription so the subscriber receives only messages matching specified attributes or message-body values.

## Question 13: What is SNS FIFO?

**Answer:**

It is an ordered and deduplicated SNS topic type intended for ordered fan-out, commonly to SQS FIFO queues.

## Question 14: What is Amazon EventBridge?

**Answer:**

EventBridge is a managed event-routing service that matches events against rules and sends them to configured targets.

## Question 15: What is the difference between SNS and EventBridge?

**Answer:**

SNS primarily broadcasts messages to subscribers. EventBridge performs richer content-based routing of structured events to targets.

## Question 16: What is an EventBridge target DLQ?

**Answer:**

It is a Standard SQS queue receiving events that EventBridge could not deliver after the target retry policy was exhausted.

## Question 17: What is EventBridge archive and replay?

**Answer:**

It stores selected bus events and later republishes a selected historical time range to the original event bus.

## Question 18: What is EventBridge Pipes?

**Answer:**

Pipes provides managed point-to-point integration from one source through optional filtering and enrichment to one target.

## Question 19: What is EventBridge Scheduler?

**Answer:**

It is a managed one-time and recurring scheduling service supporting rate, cron and timestamp schedules, time zones, retries and DLQs.

## Question 20: What is the transactional outbox pattern?

**Answer:**

It writes business state and an outbox event in one database transaction, after which another process reliably publishes the event to the messaging system.

---

# 143. Never-forget revision

```text
SQS:
Durable queue.

Standard queue:
At least once and best-effort order.

FIFO queue:
Ordered per message group with deduplication.

Visibility timeout:
How long a received message is hidden.

Retention:
How long an unprocessed message remains.

Long polling:
Wait for messages instead of repeatedly returning empty.

DLQ:
Isolation for repeatedly failed messages.

MessageGroupId:
FIFO ordering and parallelism boundary.

MessageDeduplicationId:
Suppress duplicate FIFO sends within five minutes.

SNS:
Publish/subscribe fan-out.

SNS filter:
Deliver only matching messages to one subscription.

SNS FIFO:
Ordered fan-out.

EventBridge:
Content-based event router.

Event bus:
Receives events.

Rule:
Matches events.

Target:
Receives matching events.

Archive:
Stores EventBridge events.

Replay:
Resends archived events.

Pipe:
One source, optional filter/enrichment, one target.

Scheduler:
Future one-time or recurring invocation.

Outbox:
Database transaction plus durable event record.

Idempotency:
Safe repeated processing.
```

## One-line memory trick

```text
Use SQS to buffer work.
Use SNS to broadcast.
Use EventBridge to route.
Use Scheduler to invoke later.
Use DLQs to investigate.
Use idempotency everywhere.
```

## Lesson 52 outcome

You can now design messaging where:

```text
A producer outruns a consumer
    → SQS buffers the workload.

Several systems need one event
    → SNS fans it out.

Only specific events should reach a service
    → EventBridge rules filter and route them.

One entity requires ordered commands
    → SQS FIFO uses its ID as MessageGroupId.

A consumer crashes during processing
    → Visibility expiry enables retry.

One message continually fails
    → A DLQ isolates it.

A Lambda batch contains one bad message
    → Partial-batch response retries only that message.

An SNS subscriber is offline
    → Its SQS queue retains messages independently.

A target is unavailable temporarily
    → EventBridge retries with backoff and jitter.

Historical events need reprocessing
    → Archive and replay rebuild downstream state.

A future reminder must run once
    → EventBridge Scheduler invokes the target.

A database write and event publication must agree
    → Transactional outbox prevents lost events.
```

**Next lesson: Lesson 53 — Amazon API Gateway and AWS AppSync production API architecture: REST, HTTP and WebSocket APIs, GraphQL, authentication, throttling, caching, private APIs, custom domains, observability and deployment safety.**

[1]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-what-is.html?utm_source=chatgpt.com "What Is Amazon EventBridge? - Amazon ..."
[2]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/welcome.html?utm_source=chatgpt.com "What is Amazon Simple Queue Service?"
[3]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/creating-sqs-standard-queues.html?utm_source=chatgpt.com "Creating an Amazon SQS standard queue and sending a ..."
[4]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-queue-types.html?utm_source=chatgpt.com "Amazon SQS queue types - Amazon Simple Queue Service"
[5]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-understanding-logic.html?utm_source=chatgpt.com "FIFO queue delivery logic in Amazon SQS"
[6]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-configure-queue-parameters.html?utm_source=chatgpt.com "Configuring queue parameters using the Amazon SQS console"
[7]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html?utm_source=chatgpt.com "Amazon SQS visibility timeout"
[8]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-delay-queues.html?utm_source=chatgpt.com "Amazon SQS delay queues - Amazon Simple Queue Service"
[9]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/FIFO-queues-exactly-once-processing.html?utm_source=chatgpt.com "Exactly-once processing in Amazon SQS"
[10]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/troubleshooting-fifo-throttling-issues.html?utm_source=chatgpt.com "Troubleshoot FIFO throttling issues in Amazon SQS"
[11]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html?utm_source=chatgpt.com "Using dead-letter queues in Amazon SQS"
[12]: https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html?utm_source=chatgpt.com "Using Lambda with Amazon SQS"
[13]: https://docs.aws.amazon.com/sns/latest/dg/welcome.html?utm_source=chatgpt.com "What is Amazon SNS? - Amazon Simple Notification Service"
[14]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-delivery.html?utm_source=chatgpt.com "Amazon SNS message delivery for FIFO topics"
[15]: https://docs.aws.amazon.com/sns/latest/api/API_Publish.html?utm_source=chatgpt.com "Publish - Amazon Simple Notification Service"
[16]: https://docs.aws.amazon.com/sns/latest/dg/large-message-payloads.html?utm_source=chatgpt.com "Publishing large messages with Amazon SNS and Amazon S3 - Amazon Simple Notification Service"
[17]: https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html?utm_source=chatgpt.com "Amazon SNS message filtering"
[18]: https://docs.aws.amazon.com/sns/latest/dg/fifo-message-grouping.html?utm_source=chatgpt.com "Amazon SNS message grouping for FIFO topics"
[19]: https://docs.aws.amazon.com/sns/latest/dg/sns-dg.pdf?utm_source=chatgpt.com "sns-dg.pdf - AWS Documentation"
[20]: https://docs.aws.amazon.com/sns/latest/dg/sns-monitoring-using-cloudwatch.html?utm_source=chatgpt.com "Monitoring Amazon SNS topics using CloudWatch"
[21]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-putevents.html?utm_source=chatgpt.com "Sending events with PutEvents in Amazon EventBridge"
[22]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-event-patterns.html?utm_source=chatgpt.com "Creating Amazon EventBridge event patterns"
[23]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html?utm_source=chatgpt.com "How EventBridge retries delivering events"
[24]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-dlq.html?utm_source=chatgpt.com "Using dead-letter queues to process undelivered events in ..."
[25]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-archive.html?utm_source=chatgpt.com "Archiving and replaying events in Amazon EventBridge - Amazon EventBridge"
[26]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-find-schema.html?utm_source=chatgpt.com "Finding an AWS service event schema in Amazon EventBridge - Amazon EventBridge"
[27]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-global-endpoints.html?utm_source=chatgpt.com "Making applications Regional-fault tolerant with global ..."
[28]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-api-destinations.html?utm_source=chatgpt.com "API destinations as targets in Amazon EventBridge"
[29]: https://docs.aws.amazon.com/eventbridge/latest/userguide/pipes-concepts.html?utm_source=chatgpt.com "Amazon EventBridge Pipes concepts"
[30]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-event-filtering.html?utm_source=chatgpt.com "Event filtering in Amazon EventBridge Pipes"
[31]: https://docs.aws.amazon.com/eventbridge/latest/userguide/pipes-enrichment.html?utm_source=chatgpt.com "Event enrichment in Amazon EventBridge Pipes"
[32]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-event-target.html?utm_source=chatgpt.com "Amazon EventBridge Pipes targets"
[33]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-batching-concurrency.html?utm_source=chatgpt.com "Amazon EventBridge Pipes batching and concurrency"
[34]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-error-troubleshooting.html?utm_source=chatgpt.com "Amazon EventBridge Pipes error handling and ..."
[35]: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes-logs-execution-steps.html?utm_source=chatgpt.com "EventBridge Pipes execution steps"
[36]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/what-is-scheduler.html?utm_source=chatgpt.com "What is Amazon EventBridge Scheduler?"
[37]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html?utm_source=chatgpt.com "Schedule types in EventBridge Scheduler"
[38]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/scheduler-quotas.html?utm_source=chatgpt.com "Quotas for Amazon EventBridge Scheduler"
[39]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/managing-schedule-flexible-time-windows.html?utm_source=chatgpt.com "Configuring flexible time windows in EventBridge Scheduler"
[40]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/getting-started.html?utm_source=chatgpt.com "Getting started with EventBridge Scheduler"
[41]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/configuring-schedule-dlq.html?utm_source=chatgpt.com "Configuring a schedule's dead-letter queue in EventBridge ..."
[42]: https://docs.aws.amazon.com/scheduler/latest/UserGuide/setting-up.html?utm_source=chatgpt.com "Setting up Amazon EventBridge Scheduler"
