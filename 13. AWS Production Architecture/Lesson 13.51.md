# AWS Masterclass — Phase 3

# Lesson 50: Amazon Kinesis Data Streams and Amazon MSK Production Streaming Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Design real-time event-streaming systems.
* Distinguish streams from queues and databases.
* Choose between Kinesis Data Streams and Amazon MSK.
* Partition events while preserving required ordering.
* Calculate Kinesis shard capacity.
* Choose Kinesis provisioned, On-demand Standard or On-demand Advantage mode.
* Build reliable Kinesis producers and consumers.
* Use enhanced fan-out and the Kinesis Client Library.
* Process Kinesis streams safely using Lambda.
* Handle retries, duplicates, poison records and consumer lag.
* Design Kafka topics, partitions, replication and consumer groups.
* Choose MSK Serverless, Standard brokers or Express brokers.
* Configure Kafka durability using replication, ISR and acknowledgements.
* Understand at-most-once, at-least-once and exactly-once processing.
* Use retention, replay and log compaction.
* Implement MSK security using IAM, TLS, SCRAM or mutual TLS.
* Use MSK Connect, MSK Replicator and tiered storage.
* Monitor and troubleshoot production streaming systems.
* Provision Kinesis and MSK with Terraform.

---

# 2. Streaming mental model

A streaming system stores an ordered sequence of events.

```text
Producer
   |
   | Event
   v
Stream
   |
   ├── Consumer A
   ├── Consumer B
   └── Consumer C
```

Example event:

```json
{
  "eventId": "event-9382",
  "eventType": "TODO_COMPLETED",
  "todoId": "501",
  "userId": "104",
  "occurredAt": "2026-07-31T02:10:00+05:30"
}
```

The event describes something that happened.

```text
Command:
Complete todo 501.

Event:
Todo 501 was completed.
```

Events should normally be treated as immutable historical facts.

---

# 3. Stream versus queue

## Queue

A queue usually distributes work among competing workers.

```text
SQS queue
    |
    ├── Worker A receives message 1
    ├── Worker B receives message 2
    └── Worker C receives message 3
```

After successful processing, the message is removed.

## Stream

A stream keeps events for a retention period.

```text
Event stream
    |
    ├── Billing consumer reads every event
    ├── Analytics consumer reads every event
    ├── Notification consumer reads every event
    └── Audit consumer reads every event
```

Each independent consumer can maintain its own position.

## Memory trick

```text
Queue:
Who should process this work?

Stream:
What happened, and who wants to observe it?
```

---

# 4. Stream versus database

A database stores current state:

```json
{
  "todoId": "501",
  "status": "COMPLETED"
}
```

An event stream can store the history:

```text
TODO_CREATED
TODO_TITLE_CHANGED
TODO_ASSIGNED
TODO_COMPLETED
```

The database answers:

```text
What is the current state?
```

The stream answers:

```text
How did the state change over time?
```

A common architecture uses both:

```text
Application
    |
    ├── Database:
    |      Current authoritative state
    |
    └── Stream:
           Change events
```

---

# 5. Kinesis Data Streams versus Amazon MSK

| Requirement                     | Kinesis Data Streams           | Amazon MSK                                   |
| ------------------------------- | ------------------------------ | -------------------------------------------- |
| API model                       | AWS-native stream API          | Apache Kafka API                             |
| Infrastructure control          | Very low                       | Low to moderate                              |
| Capacity unit                   | Shards or on-demand throughput | Brokers, partitions or serverless throughput |
| Ordering boundary               | Shard/partition key            | Topic partition                              |
| Consumer position               | Sequence/checkpoint            | Offset                                       |
| Consumer coordination           | KCL, Lambda or custom          | Kafka consumer groups                        |
| Retention                       | 24 hours to 365 days           | Topic retention configuration                |
| Ecosystem                       | AWS-native                     | Apache Kafka ecosystem                       |
| Log compaction                  | No Kafka-style compaction      | Yes                                          |
| Kafka Connect support           | No                             | MSK Connect                                  |
| Kafka Streams support           | No                             | Yes                                          |
| Cross-cluster Kafka replication | No                             | MSK Replicator                               |
| Operational simplicity          | Higher                         | Depends on MSK type                          |
| Existing Kafka application      | Requires adaptation            | Usually compatible                           |

Amazon Kinesis Data Streams is an AWS-managed streaming service based on streams and shards. Amazon MSK runs open-source Apache Kafka and supports Kafka-compatible clients, tools and plugins. ([AWS Documentation][1])

## Selection rule

```text
Need the simplest AWS-native event stream?
    → Kinesis Data Streams

Already use Kafka clients and ecosystem?
    → Amazon MSK

Need Kafka log compaction or Kafka Streams?
    → Amazon MSK

Need Lambda-first event processing?
    → Kinesis is often simpler

Need several teams using standard Kafka tooling?
    → Amazon MSK
```

---

# Part 1 — Amazon Kinesis Data Streams

# 6. Kinesis architecture

```text
Producers
├── Application
├── IoT devices
├── Agents
└── AWS services
        |
        v
Kinesis data stream
├── Shard 0
├── Shard 1
└── Shard 2
        |
        v
Consumers
├── Lambda
├── KCL application
├── Data Firehose
├── Flink
└── Custom SDK consumer
```

A Kinesis stream consists of shards, and each shard contains an ordered sequence of records with Kinesis-assigned sequence numbers. ([AWS Documentation][2])

---

# 7. Kinesis record

A Kinesis record contains:

```text
Partition key
Sequence number
Data blob
Approximate arrival timestamp
```

Producer input:

```json
{
  "PartitionKey": "USER#104",
  "Data": {
    "eventType": "TODO_COMPLETED",
    "todoId": "501"
  }
}
```

Kinesis calculates which shard receives the record by hashing the partition key. ([AWS Documentation][3])

---

# 8. Partition key

The partition key controls:

```text
Shard placement
+
Ordering scope
+
Traffic distribution
```

Example:

```text
Partition key:
USER#104
```

All events for user 104 are normally routed consistently based on that partition key while the relevant hash range remains assigned to a shard.

Events:

```text
USER_CREATED
TODO_CREATED
TODO_COMPLETED
```

can therefore be processed in order for that user.

---

# 9. Partition-key design

## Good high-cardinality keys

```text
USER#104
DEVICE#84923
ORDER#583902
TENANT#38#ACCOUNT#501
```

## Dangerous keys

```text
ALL_EVENTS
PRODUCTION
TODAY
TODO_COMPLETED
```

A constant or low-cardinality partition key concentrates traffic on too few shards.

AWS recommends having substantially more distinct partition keys than shards so traffic can be distributed effectively. ([AWS Documentation][4])

---

# 10. Ordering guarantee

Kinesis ordering exists inside a shard.

```text
Shard 0:
Event A → Event B → Event C
```

There is no universal ordering between separate shards:

```text
Shard 0:
A → C

Shard 1:
B → D
```

You cannot reliably claim:

```text
A happened before B
```

from shard sequence numbers belonging to different shards.

## Business rule

```text
Events requiring relative order
must use the same logical partitioning strategy.
```

---

# 11. `PutRecord` versus `PutRecords`

## `PutRecord`

Writes one record.

Advantages:

* Simpler failure handling.
* Can use `SequenceNumberForOrdering`.
* Stronger control when strict producer ordering is required.

## `PutRecords`

Writes several records in one request.

Advantages:

* Fewer network calls.
* Higher producer efficiency.
* Better batching.

Risks:

* Partial success.
* Strict ordering is harder.
* Failed records need selective retries.

AWS recommends `PutRecord` when records must be read in exactly the same order they were written to one shard. `PutRecords` can return a mixture of successful and failed records in one response. ([AWS Documentation][5])

---

# 12. Partial `PutRecords` failure

Request:

```text
Record A
Record B
Record C
Record D
```

Response:

```text
A → Success
B → ProvisionedThroughputExceededException
C → Success
D → InternalFailure
```

Correct producer:

```text
Retry B and D only
```

Incorrect producer:

```text
Retry A, B, C and D
```

Retrying successful records creates duplicates.

---

# 13. Duplicate producer records

Consider:

```text
1. Producer sends PutRecord.
2. Kinesis accepts the event.
3. Network response is lost.
4. Producer cannot determine success.
5. Producer retries.
6. The event exists twice.
```

Kinesis consumers must therefore be designed for duplicates. AWS recommends embedding a unique business identifier in each event when duplicate elimination matters. ([AWS Documentation][6])

Example:

```json
{
  "eventId": "01JAXY84M63V",
  "aggregateId": "TODO#501",
  "eventType": "TODO_COMPLETED"
}
```

Consumer deduplication:

```text
Check eventId
    |
    ├── Already processed → Ignore
    └── New event         → Process and record eventId
```

---

# 14. Shard capacity

A Kinesis shard supports sustained capacity of approximately:

```text
Writes:
1 MiB per second
or
1,000 records per second

Reads:
2 MiB per second
and limited read API transactions
```

The first limit reached causes throttling. These shard-level limits apply to both provisioned and on-demand stream internals. ([AWS Documentation][2])

Example:

```text
Record size:
2 KiB

Records per second:
800

Bandwidth:
1.6 MiB/s
```

Although record count is below 1,000:

```text
Bandwidth exceeds 1 MiB/s
```

One shard is insufficient.

---

# 15. Provisioned shard calculation

Approximate write shards:

```text
Write bandwidth shards =
ceil(incoming MiB/s ÷ 1 MiB/s)

Record-count shards =
ceil(records/s ÷ 1,000)

Required write shards =
max(bandwidth shards, record-count shards)
```

Example:

```text
Records:
3,500 per second

Average size:
0.5 KiB

Record-count requirement:
ceil(3,500 / 1,000) = 4 shards

Bandwidth:
1.71 MiB/s

Bandwidth requirement:
ceil(1.71 / 1) = 2 shards

Required:
4 shards
```

Read requirements also need to account for shared-throughput consumers. AWS provides a sizing formula based on incoming write bandwidth and outgoing read bandwidth. ([AWS Documentation][7])

---

# 16. Capacity modes

Kinesis currently offers:

```text
Provisioned
On-demand Standard
On-demand Advantage
```

All support core stream capabilities, including retention, encryption and standard or enhanced-fan-out consumers. ([AWS Documentation][7])

---

# 17. Provisioned mode

In provisioned mode, you specify shard capacity.

Use when:

* Traffic is predictable.
* Throughput is well measured.
* You want explicit shard control.
* Partition distribution needs direct analysis.
* You want predictable provisioned capacity.

```text
Stream:
8 provisioned shards
```

You can scale shard capacity using resharding or `UpdateShardCount` while producers and consumers continue operating. ([AWS Documentation][7])

---

# 18. On-demand Standard

On-demand Standard automatically manages stream capacity based on observed traffic.

Use when:

* Traffic is unpredictable.
* Workload is new.
* Spikes are common.
* You do not want to manage shard counts.
* Operational simplicity is the priority.

On-demand mode can adapt to uneven distribution, but one individual partition key can still exceed the equivalent single-shard write boundary of 1 MiB/s or 1,000 records per second. ([AWS Documentation][8])

```text
On-demand
≠
One hot partition key has infinite capacity
```

---

# 19. On-demand Advantage

On-demand Advantage is an account-level regional option for on-demand streams.

It adds features such as:

* Proactive warm throughput.
* Explicit scale-down following temporary bursts.
* Up to 50 enhanced-fan-out consumers per stream.
* A different usage-based pricing structure.

It currently commits the account to at least 25 MiB/s of ingest and 25 MiB/s of retrieval usage across on-demand streams in that Region and requires at least 24 hours before it can be disabled. ([AWS Documentation][7])

Example:

```text
Normal traffic:
40 MiB/s

Planned launch:
200 MiB/s

Action:
Configure 200 MiB/s warm throughput
before the launch
```

On-demand Advantage is more suitable for organisations already operating substantial Kinesis volume than for a tiny development stream.

---

# 20. Switching capacity modes

A stream can switch between provisioned and on-demand modes without interrupting producers and consumers.

AWS currently limits each stream to two provisioned/on-demand mode switches within 24 hours. ([AWS Documentation][7])

Do not use mode switching as a minute-by-minute autoscaling mechanism.

---

# 21. Large records

The default maximum Kinesis record size remains:

```text
1 MiB
```

Eligible streams can now be configured for records up to:

```text
10 MiB
```

The larger-record feature is intended for intermittent large payloads. Shard sustained throughput remains 1 MiB/s for writes and 2 MiB/s for reads, so frequent large records can consume burst capacity and throttle subsequent traffic. Mumbai (`ap-south-1`) is currently one of the supported Regions. ([AWS Documentation][9])

## Recommended large-payload pattern

For continuous large payloads:

```text
Large body
    |
    v
Amazon S3
    |
    v
Kinesis event containing:
bucket
object key
version
checksum
metadata
```

Example:

```json
{
  "eventId": "event-9382",
  "payload": {
    "bucket": "production-event-payloads",
    "key": "events/2026/07/31/event-9382.json",
    "sha256": "..."
  }
}
```

---

# 22. Downstream large-record compatibility

Increasing the Kinesis record limit does not increase every downstream service limit.

For example:

* Lambda synchronous event payload processing has lower practical boundaries after base64 encoding and event-source metadata.
* Some Firehose destinations do not support large records.
* Redshift Kinesis streaming ingestion has smaller supported record constraints.

AWS specifically recommends configuring an event-source on-failure destination for Lambda and testing every downstream component before raising a stream’s record size. ([AWS Documentation][9])

---

# 23. Kinesis Producer Library

The Kinesis Producer Library improves producer throughput by:

* Buffering records.
* Batching requests.
* Aggregating several user records into one Kinesis record.
* Retrying failures.
* Managing connections.

Concept:

```text
User records:
A B C D E
    |
    v
KPL aggregation
    |
    v
One Kinesis record
```

Aggregation is especially useful when many records are small because the shard record-count limit may otherwise be reached before the bandwidth limit. ([AWS Documentation][10])

Tradeoff:

```text
Higher batching delay
for
Better throughput efficiency
```

---

# 24. Record retention

Kinesis stores records for:

```text
Minimum:
24 hours

Maximum:
365 days
```

Increasing retention supports:

* Replaying events.
* Recovering from consumer outages.
* Reprocessing after a bug.
* Backfilling new consumers.
* Maintaining a longer recovery buffer.

Extended retention increases storage cost. ([AWS Documentation][2])

---

# 25. Replay

Suppose a consumer introduced a bug at 10:00.

```text
10:00–11:00:
Events processed incorrectly

11:15:
Bug fixed
```

If records remain inside retention:

```text
Start a new consumer
at timestamp 10:00
    |
    v
Reprocess events
```

Replay is one of the major differences between a stream and a delete-after-processing queue.

Consumers must remain idempotent because replay intentionally processes old events again.

---

# 26. Shared-throughput consumers

Traditional consumers use polling operations such as `GetRecords`.

Per shard, shared consumers collectively use the shard’s read throughput.

```text
Shard read capacity
      |
      ├── Consumer A
      ├── Consumer B
      └── Consumer C
```

As independent consumers increase, they compete for the same shared read capacity.

---

# 27. Enhanced fan-out

Enhanced fan-out gives each registered consumer dedicated throughput of up to:

```text
2 MiB/s per shard per consumer
```

Kinesis pushes records to enhanced-fan-out consumers using `SubscribeToShard`, preventing them from competing with other registered consumers for ordinary read throughput. ([AWS Documentation][11])

Example:

```text
10 shards
×
2 MiB/s
=
20 MiB/s dedicated read capacity
per enhanced consumer
```

Use enhanced fan-out when:

* Several independent consumers need low latency.
* Shared read capacity is insufficient.
* Consumer lag is caused by read contention.
* Event processing is time-sensitive.

---

# 28. Kinesis Client Library

The Kinesis Client Library simplifies distributed consumer applications.

KCL handles:

* Discovering shards.
* Assigning shards to workers.
* Balancing leases.
* Handling resharding.
* Tracking checkpoints.
* Recovering from worker failure.

KCL provides at-least-once processing semantics. KCL 3.x creates DynamoDB metadata tables for leases, worker metrics and coordinator state by default. ([AWS Documentation][12])

---

# 29. KCL lease model

```text
Stream shards:
Shard A
Shard B
Shard C

Workers:
Worker 1 owns A and B
Worker 2 owns C
```

KCL uses a DynamoDB lease table to coordinate shard ownership.

If worker 1 fails:

```text
Lease expires
    |
    v
Worker 2 or worker 3
takes over the shard
```

KCL tries to ensure each shard is actively processed by one worker within one KCL application. Separate application names represent independent consumers. ([AWS Documentation][13])

---

# 30. Checkpointing

A checkpoint records the last successfully processed sequence position.

```text
Read records:
100, 101, 102, 103

Process successfully:
100, 101, 102

Checkpoint:
102
```

After restart:

```text
Resume after 102
```

Checkpointing too frequently:

* Increases DynamoDB activity.
* Adds processing overhead.

Checkpointing too rarely:

* Causes more duplicate processing after failure.
* Increases replay work.

---

# 31. At-least-once processing

Kinesis and KCL can deliver or process a record more than once.

```text
Process event
    |
    v
Write output
    |
    v
Worker fails before checkpoint
    |
    v
Record is processed again
```

Therefore:

```text
At-least-once delivery
requires idempotent consumers.
```

KCL documentation explicitly describes at-least-once semantics. ([AWS Documentation][14])

---

# 32. Idempotent consumer

Bad:

```text
TODO_COMPLETED event
    |
    v
Increment completedTodoCount
```

If processed twice:

```text
Counter becomes incorrect
```

Better:

```text
Transaction:
If eventId not processed:
    apply business change
    record eventId
else:
    do nothing
```

Possible stores:

* DynamoDB conditional write.
* Relational unique constraint.
* Idempotency table.
* Transactional outbox/inbox design.

---

# 33. Lambda Kinesis consumer

```text
Kinesis stream
      |
      v
Lambda event-source mapping
      |
      v
Lambda invocation with a batch
```

Lambda polls Kinesis shards, invokes functions with batches and checkpoints successful progress.

By default, processing is ordered at the shard level. A configurable parallelization factor can process multiple batches from one shard concurrently while preserving ordering at the partition-key level under supported conditions. ([AWS Documentation][15])

---

# 34. Lambda parallelization factor

Example:

```text
100 shards
Parallelization factor = 2

Potential shard batch concurrency:
Up to 200
```

Use when:

* `IteratorAge` is increasing.
* Function duration is significant.
* One invocation per shard is insufficient.
* Partition keys are well distributed.

Do not increase it blindly if:

* Downstream database capacity is limited.
* Processing requires strict total shard order.
* The function is already throttled.
* The same partition key is hot.

---

# 35. Lambda batch failure

Default behaviour:

```text
Batch:
A B C D

A succeeds
B succeeds
C fails
D not safely checkpointed

Whole batch retried
```

This creates duplicates for A and B.

Enable:

```text
ReportBatchItemFailures
```

to return the failed sequence position and reduce unnecessary retries. ([AWS Documentation][16])

---

# 36. Poison records

A poison record repeatedly fails.

```text
Valid event A
Valid event B
Malformed event C
Valid event D
```

Without bounded handling, C can block progress in that shard.

Configure:

* Maximum retry attempts.
* Maximum record age.
* Bisect batch on function error.
* Partial batch response.
* On-failure destination.
* Alerting.
* Replay tooling.

Lambda supports retaining failed Kinesis batch metadata through an event-source-mapping failure destination. ([AWS Documentation][17])

---

# 37. Kinesis monitoring

Important CloudWatch metrics include:

```text
IncomingBytes
IncomingRecords
OutgoingBytes
OutgoingRecords
WriteProvisionedThroughputExceeded
ReadProvisionedThroughputExceeded
GetRecords.IteratorAgeMilliseconds
SubscribeToShardEvent.MillisBehindLatest
PutRecord.Latency
GetRecords.Latency
```

The most important consumer-health signal is usually:

```text
How far behind the consumer is
```

Kinesis exposes iterator-age and enhanced-fan-out lag metrics for this purpose. ([AWS Documentation][18])

---

# 38. Kinesis hot-shard symptoms

Symptoms:

* Write throttling despite low aggregate throughput.
* One partition key dominates traffic.
* Some shards idle while another is overloaded.
* Consumer lag affects only part of the stream.
* Producer retries increase.

Long-term fixes:

* Improve partition-key cardinality.
* Add a controlled shard suffix.
* Split the hot logical aggregate.
* Reshard the stream.
* Move oversized payloads to S3.

---

# 39. Kinesis security

Production controls should include:

* IAM least privilege.
* KMS encryption.
* TLS.
* VPC interface endpoints where required.
* CloudTrail auditing.
* Resource tagging.
* Stream-level policies where appropriate.

Producer permissions:

```text
kinesis:PutRecord
kinesis:PutRecords
```

Consumer permissions:

```text
kinesis:DescribeStreamSummary
kinesis:GetRecords
kinesis:GetShardIterator
kinesis:ListShards
```

Enhanced consumers additionally need consumer-registration and subscription permissions.

---

# 40. Terraform Kinesis stream

```hcl
resource "aws_kinesis_stream" "todo_events" {
  name = "production-todo-events"

  shard_count = 4

  retention_period = 168

  encryption_type = "KMS"
  kms_key_id       = aws_kms_key.streaming.arn

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds"
  ]

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

For on-demand mode:

```hcl
stream_mode_details {
  stream_mode = "ON_DEMAND"
}
```

Remove incompatible provisioned-shard settings according to the AWS provider version.

---

# 41. Terraform Lambda event-source mapping

```hcl
resource "aws_lambda_event_source_mapping" "todo_events" {
  event_source_arn = aws_kinesis_stream.todo_events.arn
  function_name    = aws_lambda_alias.todo_event_processor.arn

  starting_position = "LATEST"

  batch_size                         = 100
  maximum_batching_window_in_seconds = 1

  parallelization_factor = 2

  maximum_retry_attempts       = 5
  maximum_record_age_in_seconds = 3600

  bisect_batch_on_function_error = true

  function_response_types = [
    "ReportBatchItemFailures"
  ]

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.failed_stream_records.arn
    }
  }

  filter_criteria {
    filter {
      pattern = jsonencode({
        data = {
          eventType = [
            "TODO_CREATED",
            "TODO_COMPLETED"
          ]
        }
      })
    }
  }
}
```

---

# Part 2 — Amazon Managed Streaming for Apache Kafka

# 42. What is Amazon MSK?

Amazon MSK is a managed service for running Apache Kafka.

AWS manages:

* Broker provisioning.
* Broker replacement.
* Infrastructure patching.
* Control-plane operations.
* AWS integrations.
* Supported monitoring.
* Storage integrations.
* Cluster updates.

You still manage:

* Topics.
* Partitions.
* Keys.
* Retention.
* Consumer groups.
* Producer settings.
* Schemas.
* Application delivery semantics.
* Capacity planning for provisioned clusters.

Existing Kafka clients and tools can normally work with MSK without application-code changes. ([AWS Documentation][19])

---

# 43. Kafka mental model

```text
Producer
    |
    v
Topic
├── Partition 0
├── Partition 1
└── Partition 2
    |
    v
Consumer group
├── Consumer A
├── Consumer B
└── Consumer C
```

## Topic

Named event stream.

```text
todo-events
```

## Partition

Ordered append-only log inside a topic.

## Offset

Position of a record inside one partition.

## Broker

Kafka server holding partitions.

## Consumer group

A set of consumers cooperating to process topic partitions.

---

# 44. Kafka record

A Kafka record commonly contains:

```text
Key
Value
Headers
Timestamp
Topic
Partition
Offset
```

Example:

```json
{
  "key": "TODO#501",
  "value": {
    "eventId": "event-9382",
    "eventType": "TODO_COMPLETED"
  }
}
```

Kafka uses the key through a partitioner to select a topic partition.

---

# 45. Kafka ordering

Kafka guarantees order inside one partition:

```text
Partition 2:
Offset 98  → Event A
Offset 99  → Event B
Offset 100 → Event C
```

Kafka does not provide one total order across all partitions.

```text
Partition 0 offset 50
and
Partition 1 offset 70
```

cannot be compared as one universal sequence.

## Key design rule

```text
Events requiring ordering
must be assigned to the same partition.
```

Example:

```text
Key = TODO#501
```

All events for todo 501 follow the same partition route.

---

# 46. Kafka topics and partitions

Example:

```text
Topic:
todo-events

Partitions:
12

Replication factor:
3
```

Logical records:

```text
Partition 0:
TODO#100, TODO#381

Partition 1:
TODO#501, TODO#816

Partition 2:
TODO#222, TODO#438
```

Partitions provide:

* Storage distribution.
* Producer parallelism.
* Consumer parallelism.
* Ordering boundaries.

---

# 47. Consumer groups

Within one consumer group:

```text
One partition
is assigned to at most one active consumer
at a time.
```

Example:

```text
Topic partitions:
P0 P1 P2 P3

Consumer group:
C1 owns P0 and P1
C2 owns P2 and P3
```

If C3 joins:

```text
Rebalance:
C1 owns P0
C2 owns P1
C3 owns P2 and P3
```

Kafka tracks committed consumer-group offsets so consumers can restart and resume processing. ([Apache Kafka][20])

---

# 48. Consumer parallelism limit

Suppose:

```text
Topic partitions:
6

Consumers in one group:
10
```

At most six consumers can actively process partitions.

```text
Six active
Four idle
```

To increase one consumer group’s processing parallelism:

```text
Increase partitions
```

Adding consumers beyond partition count does not increase throughput.

---

# 49. Independent consumer groups

```text
todo-events
    |
    ├── notification-service group
    ├── analytics-service group
    ├── search-indexer group
    └── audit-service group
```

Each group reads the topic independently and maintains separate offsets.

Inside one group:

```text
Consumers share work.
```

Across groups:

```text
Every group receives the event stream.
```

---

# 50. Rebalancing

A consumer-group rebalance can occur when:

* Consumer joins.
* Consumer leaves.
* Consumer crashes.
* Partition count changes.
* Session timeout expires.
* Subscription changes.

During rebalance:

```text
Partition processing can pause
while ownership changes.
```

Long processing without correct polling or heartbeat configuration can cause repeated rebalances.

Monitor:

* Consumer-group state.
* Rebalance frequency.
* Consumer lag.
* Processing duration.
* Session and poll timeouts.

---

# 51. MSK deployment choices

Amazon MSK provides:

```text
MSK Provisioned
├── Standard brokers
└── Express brokers

MSK Serverless
```

Standard brokers provide the most configuration and storage control. Express brokers are provisioned compute with fully managed elastic storage and preconfigured operational defaults. MSK Serverless automatically manages cluster capacity and partitions. ([AWS Documentation][21])

---

# 52. MSK Serverless

Use MSK Serverless when:

* Traffic is unpredictable.
* You want Kafka APIs without broker sizing.
* Automatic capacity management is important.
* IAM-only access control is acceptable.
* Its quotas and configuration limits fit the workload.

MSK Serverless automatically provisions capacity and manages partitions. It requires IAM access control; Apache Kafka ACLs are not supported for Serverless clusters. Mumbai is currently a supported Region. ([AWS Documentation][22])

---

# 53. MSK Provisioned with Standard brokers

Standard brokers provide control over:

* Broker instance family.
* Broker count.
* EBS storage.
* Provisioned storage throughput.
* Storage autoscaling.
* Tiered storage.
* Kafka configuration.
* Monitoring level.

Use when:

* Workload is predictable.
* Detailed Kafka configuration is required.
* Tiered storage is required.
* You need the widest feature flexibility.
* Your team is comfortable managing Kafka capacity.

---

# 54. MSK Provisioned with Express brokers

Express brokers provide:

* Managed elastic pay-as-you-go storage.
* Preconfigured availability and durability settings.
* Faster scaling and recovery than Standard brokers.
* Higher throughput potential per broker.
* Reduced storage-management work.

Express brokers distribute data across three Availability Zones by default, enforce replication factor 3 and minimum in-sync replicas 2. ([AWS Documentation][23])

Use Express when:

* High throughput is required.
* You want broker-based Kafka with less storage administration.
* Enforced production durability defaults are desirable.
* Supported Kafka features fit the workload.

---

# 55. MSK Provisioned architecture

```text
Availability Zone A
└── Broker 1

Availability Zone B
└── Broker 2

Availability Zone C
└── Broker 3
```

Topic:

```text
Partition 0:
Leader on broker 1
Followers on brokers 2 and 3

Partition 1:
Leader on broker 2
Followers on brokers 1 and 3

Partition 2:
Leader on broker 3
Followers on brokers 1 and 2
```

Clients connect to bootstrap broker endpoints and discover the complete Kafka topology.

---

# 56. Leader and follower replicas

Each partition has one leader.

```text
Partition 0
├── Broker A: leader
├── Broker B: follower
└── Broker C: follower
```

Producers and consumers normally interact with the leader.

Followers replicate the leader’s log.

If the leader broker fails:

```text
Eligible follower
    |
    v
Promoted to leader
```

Kafka clients must refresh metadata and retry against the new leader.

---

# 57. In-sync replicas

ISR means:

```text
In-Sync Replica set
```

These are replicas sufficiently caught up with the leader to participate in durability and leadership decisions.

Example:

```text
Replication factor:
3

ISR:
Broker A
Broker B
Broker C
```

After broker C falls behind:

```text
ISR:
Broker A
Broker B
```

Monitor under-replicated and out-of-sync partitions carefully.

---

# 58. Producer acknowledgements

Kafka producer `acks` controls what must happen before a send is considered successful.

## `acks=0`

```text
Producer sends
and does not wait
```

Lowest durability.

## `acks=1`

```text
Leader acknowledges
without requiring follower acknowledgement
```

The message can be lost if the leader fails before replication.

## `acks=all`

```text
All required in-sync replicas acknowledge
```

Strongest normal durability option.

---

# 59. Replication factor and minimum ISR

Recommended production pattern:

```text
Replication factor = 3
min.insync.replicas = 2
producer acks = all
```

This ensures the write fails rather than being accepted when the required replication level cannot be met. Apache Kafka documents this combination as the typical majority durability configuration. 

Availability tradeoff:

```text
Only one replica available
    |
    v
Writes rejected
```

This protects durability but temporarily reduces write availability.

---

# 60. Idempotent Kafka producer

Producer retries can create duplicates:

```text
Broker accepts batch
    |
    v
Acknowledgement lost
    |
    v
Producer retries
    |
    v
Duplicate batch
```

Kafka’s idempotent producer uses producer identity and sequence tracking to prevent duplicate writes caused by producer retries.

Current Kafka producer requirements for idempotence include compatible settings such as:

```text
enable.idempotence = true
acks = all
retries > 0
max.in.flight.requests.per.connection <= 5
```

with ordering preserved under those supported settings. 

---

# 61. At-most-once processing

```text
Commit offset
    |
    v
Process event
```

If processing fails after the commit:

```text
Event is lost
```

Characteristics:

```text
No duplicate processing
Possible lost processing
```

Use only where losing events is acceptable.

---

# 62. At-least-once processing

```text
Process event
    |
    v
Write result
    |
    v
Commit offset
```

If failure occurs after writing but before committing:

```text
Event is processed again
```

Characteristics:

```text
No intentional event loss
Possible duplicates
```

This is the most common delivery model.

---

# 63. Exactly-once processing

“Exactly once” must be scoped carefully.

Kafka can atomically coordinate:

* Writes to Kafka output topics.
* Consumer offsets.
* Transactional producer operations.

Kafka Streams can use Kafka transactions to provide end-to-end exactly-once processing for Kafka state stores, offsets and Kafka output topics. ([Apache Kafka][24])

However:

```text
Kafka transaction
does not automatically make
an external HTTP API, email or arbitrary database write
exactly once.
```

External side effects still require:

* Idempotency keys.
* Database transactions.
* Outbox/inbox patterns.
* Deduplication.
* Compensating actions.

---

# 64. Kafka offsets

Each partition record has an offset.

```text
Partition 2

Offset 100
Offset 101
Offset 102
Offset 103
```

Consumer group commits:

```text
Next offset to consume:
103
```

After restart, the consumer uses its committed offset to resume. ([Apache Kafka][20])

Offset commit strategy determines duplicate and loss behaviour.

---

# 65. Kafka retention

Kafka retains records independently of whether consumers have processed them.

Retention can be based on:

```text
Time
Size
or both
```

Example:

```text
retention.ms = 604800000
```

Meaning:

```text
Seven days
```

A slow consumer can replay records as long as the required offsets remain inside retention.

If lag exceeds retention:

```text
Required old records are deleted
    |
    v
Consumer cannot resume from them
```

---

# 66. Delete retention

Default cleanup policy:

```text
cleanup.policy = delete
```

Old log segments are removed according to retention time or size.

Good for:

* Events.
* Logs.
* Telemetry.
* Clickstreams.
* Audit streams with finite retention.

Kafka retention operates at the segment level rather than deleting one individual record immediately when it reaches the age threshold. ([Apache Kafka][25])

---

# 67. Log compaction

Compaction retains the latest value for each key.

Events:

```text
USER#104 → email=a@example.com
USER#104 → email=b@example.com
USER#104 → email=c@example.com
```

After compaction, the log eventually retains:

```text
USER#104 → email=c@example.com
```

Configuration:

```text
cleanup.policy = compact
```

Use for:

* Current entity state.
* Configuration.
* CDC state.
* Lookup tables.
* Rebuilding a materialized view.
* Connector offsets.

Kafka also supports combining `delete,compact`. ([Apache Kafka][25])

---

# 68. Tombstones

In a compacted topic:

```text
Key:
USER#104

Value:
null
```

represents a tombstone.

It means:

```text
Delete the key from the compacted state.
```

Tombstones remain for a configured time before log cleanup removes them.

Consumers rebuilding state must understand tombstone semantics.

---

# 69. Topic partition count

Too few partitions:

* Limits consumer parallelism.
* Concentrates throughput.
* Creates large partitions.
* Limits leader distribution.

Too many partitions:

* Increase broker metadata.
* Increase file handles.
* Increase leader-election work.
* Increase consumer rebalance time.
* Increase recovery overhead.
* Increase monitoring complexity.

Choose partition count from:

```text
Required producer throughput
Required consumer parallelism
Broker partition guidance
Expected growth
Ordering requirements
```

Increasing partitions later can change key-to-partition mapping for new records.

---

# 70. Partition increase and ordering

Suppose a topic has four partitions.

```text
hash(TODO#501) % 4 = partition 1
```

After increasing to eight:

```text
hash(TODO#501) % 8 = partition 5
```

Old events remain in partition 1.

New events may enter partition 5.

This can break per-key historical ordering across the partition-count change depending on the partitioner.

Plan partition expansion carefully for keyed ordered streams.

---

# 71. MSK Standard storage

Standard brokers use customer-managed EBS sizing.

You manage:

* EBS capacity.
* Storage growth.
* Provisioned throughput.
* Storage autoscaling.
* Disk alerts.
* Broker and partition relationship.

Storage exhaustion can cause:

* Produce failures.
* Partition unavailability.
* Broker instability.
* Replication problems.

MSK provides storage-capacity metrics and alerts for Standard clusters. ([AWS Documentation][26])

---

# 72. MSK tiered storage

MSK tiered storage moves older Kafka log segments from performance-oriented broker storage to a lower-cost remote storage tier.

Benefits:

* Much longer retention.
* Lower local broker-storage requirements.
* Replay using normal Kafka APIs.
* Reduced broker-disk pressure.
* Faster partition movement because old remote data need not be copied between broker disks.

Tiered storage is currently available for supported MSK Provisioned Standard configurations and does not support compacted topics. ([AWS Documentation][27])

```text
Recent records:
Local broker storage

Older records:
Tiered storage

Consumer replay:
Uses normal Kafka APIs
```

---

# 73. Tiered-storage latency

When a consumer reads older remote data:

```text
First remote bytes:
Higher latency

Sequential continuation:
Can approach primary-tier behaviour
```

Use tiered storage for:

* Long replay windows.
* Audit streams.
* Consumers that may be offline for days.
* Historical reprocessing.
* CDC safety buffers.

Do not assume historical reads have exactly the same first-byte latency as local storage. ([AWS Documentation][27])

---

# 74. Scaling MSK Standard

## Vertical scaling

```text
kafka.m7g.large
    |
    v
kafka.m7g.xlarge
```

Improves broker:

* CPU.
* Network.
* Memory.
* Connection capacity.

## Horizontal scaling

```text
3 brokers
    |
    v
6 brokers
```

Adding brokers creates capacity, but existing partitions do not automatically rebalance perfectly simply because new brokers exist.

Partition reassignment may be required to move partition replicas and leaders.

---

# 75. MSK CPU headroom

AWS recommends keeping Standard-broker combined user and system CPU below approximately:

```text
60%
```

This leaves headroom for broker failures, maintenance, upgrades and partition movement. ([AWS Documentation][28])

A broker cluster operating constantly at 90% CPU may appear functional until:

```text
One broker is removed for maintenance
    |
    v
Remaining brokers overload
```

Design for failure capacity, not only normal capacity.

---

# 76. Producer batching

Kafka producers batch records for efficiency.

Important settings include:

```text
batch.size
linger.ms
compression.type
buffer.memory
```

Tradeoff:

```text
Higher linger
    → Larger batches
    → Better throughput
    → Slightly higher latency
```

Compression choices such as `lz4`, `snappy` or `zstd` can reduce network and storage use at the cost of producer and broker CPU.

Test with realistic record sizes.

---

# 77. Consumer fetch tuning

Important consumer settings include:

```text
fetch.min.bytes
fetch.max.bytes
max.partition.fetch.bytes
max.poll.records
max.poll.interval.ms
session.timeout.ms
```

Large fetches improve throughput but increase:

* Memory use.
* Processing time.
* Retry batch size.
* Rebalance risk if processing takes too long.

Use bounded processing and pause partitions if downstream systems become overloaded.

---

# 78. MSK security

Production MSK should use:

* Private VPC connectivity.
* Encryption between clients and brokers.
* In-cluster encryption.
* Encryption at rest.
* Authentication.
* Authorization.
* Least-privilege topic access.
* Broker and audit logging.
* CloudTrail for management operations.

MSK supports authentication models including:

```text
IAM
SASL/SCRAM
Mutual TLS
```

for supported cluster types and configurations. ([AWS Documentation][29])

---

# 79. IAM access control

IAM access control handles both authentication and Kafka authorization.

Example policy concepts:

```text
kafka-cluster:Connect
kafka-cluster:DescribeTopic
kafka-cluster:WriteData
kafka-cluster:ReadData
kafka-cluster:AlterGroup
```

IAM can scope access to:

* Cluster.
* Topic.
* Consumer group.

MSK IAM access control verifies both the AWS identity and whether it is authorised for the Kafka operation. ([AWS Documentation][30])

---

# 80. MSK Serverless security

MSK Serverless requires IAM access control.

```text
ECS task role
      |
      | SigV4/IAM Kafka authentication
      v
MSK Serverless
```

Kafka ACLs are not supported with MSK Serverless. ([AWS Documentation][22])

This simplifies AWS identity integration but may require updating traditional Kafka client authentication configuration.

---

# 81. SASL/SCRAM

SASL/SCRAM uses usernames and passwords managed through AWS Secrets Manager integrations.

Use when:

* Existing Kafka clients already support SCRAM.
* Non-AWS identity integration is needed.
* Kafka ACL workflows are preferred.
* IAM plugins are unsuitable.

Rotate credentials and restrict each user to necessary topics and consumer groups.

---

# 82. Mutual TLS

Mutual TLS authenticates clients with certificates.

```text
Client certificate
      |
      v
MSK broker validates certificate
      |
      v
Kafka ACL authorizes identity
```

Use when:

* Certificate identity is required.
* Existing PKI systems are available.
* Workloads operate across organisational boundaries.
* IAM authentication is not suitable.

Certificate lifecycle and revocation must be operationally managed.

---

# 83. MSK networking

MSK clusters run inside VPC subnets.

```text
ECS / EC2 / Lambda
       |
       v
Private MSK broker endpoints
```

Options include:

* Same-VPC access.
* VPC peering.
* Transit Gateway.
* Multi-VPC private connectivity.
* PrivateLink-based connectivity.
* Public access for supported provisioned designs.

Multi-VPC private connectivity supports IAM, TLS and SASL/SCRAM authentication, but not unauthenticated clusters. ([AWS Documentation][29])

Prefer private connectivity for production.

---

# 84. Schema management

Streaming producers and consumers are loosely coupled.

Without schema governance:

```json
Producer version 1:
{
  "todoId": "501"
}
```

Later:

```json
Producer version 2:
{
  "id": 501
}
```

Old consumers break.

Use:

* AWS Glue Schema Registry.
* Avro.
* Protobuf.
* JSON Schema.
* Compatibility checks.
* Schema versioning.

A schema registry can enforce rules such as:

```text
Backward compatibility
Forward compatibility
Full compatibility
```

---

# 85. Event schema recommendations

Every event should commonly include:

```json
{
  "eventId": "event-9382",
  "eventType": "TODO_COMPLETED",
  "eventVersion": 2,
  "aggregateId": "TODO#501",
  "occurredAt": "2026-07-31T02:10:00+05:30",
  "producer": "todo-api",
  "correlationId": "request-8392",
  "payload": {}
}
```

Benefits:

* Deduplication.
* Traceability.
* Versioning.
* Replay.
* Ownership.
* Troubleshooting.
* Schema evolution.

---

# 86. MSK Connect

MSK Connect is a managed Kafka Connect service.

It can run connectors that move data:

```text
Into Kafka:
Database CDC
S3 source
External system source

Out of Kafka:
S3 sink
OpenSearch sink
Database sink
Data warehouse sink
```

MSK Connect supports third-party connectors such as Debezium and automatically manages connector capacity. ([AWS Documentation][31])

---

# 87. Change-data-capture architecture

```text
Aurora PostgreSQL
      |
      v
Debezium on MSK Connect
      |
      v
Kafka topic:
todoapp.public.todos
      |
      ├── OpenSearch indexer
      ├── Analytics
      └── Audit processor
```

CDC captures database changes without modifying every application code path to publish an event manually.

Still consider:

* Initial snapshot.
* Schema changes.
* DDL handling.
* Connector offsets.
* Tombstones.
* Ordering.
* Database-log retention.

---

# 88. MSK Connect offsets

Connectors maintain offsets so they can resume after restart.

For source connectors such as CDC:

```text
Offset:
Last database-log position processed
```

MSK Connect supports custom offset-storage topics for preserving continuity when recreating eligible connectors. Such offset topics must use compaction. ([AWS Documentation][32])

Deleting and recreating a connector without preserving offsets can cause:

* Duplicate ingestion.
* Skipped data.
* Complete resnapshot.

---

# 89. Kafka Streams

Kafka Streams is a Java library for processing Kafka data.

Architecture:

```text
Input topic
    |
    v
Kafka Streams application
    |
    ├── Filter
    ├── Join
    ├── Aggregate
    ├── Window
    └── Transform
    |
    v
Output topic
```

Use for:

* Real-time aggregation.
* Windowed metrics.
* Stream-table joins.
* Materialized views.
* Exactly-once Kafka-to-Kafka processing.

---

# 90. Managed Service for Apache Flink

For complex stream processing:

```text
Kinesis or MSK
      |
      v
Managed Service for Apache Flink
      |
      ├── Windows
      ├── Event-time processing
      ├── Stateful computation
      ├── Checkpoints
      └── Complex joins
      |
      v
Destination systems
```

Use Flink when processing needs advanced state, event time, watermarks or sophisticated windowing beyond simple Lambda functions.

---

# 91. Lambda with MSK

Lambda can consume from:

* Amazon MSK.
* Self-managed Kafka.

Lambda manages Kafka polling and invokes functions in batches.

Use for:

* Moderate event processing.
* Serverless transformations.
* Notifications.
* Database writes.
* Event routing.

Evaluate:

* Poller scaling.
* Batch size.
* Consumer lag.
* Function concurrency.
* Downstream capacity.
* Retry and poison-record behaviour.

For very high-throughput stateful Kafka processing, Kafka Streams or Flink may be a stronger fit.

---

# 92. MSK monitoring

Important CloudWatch and Kafka metrics include:

```text
CPU User
CPU System
KafkaDataLogsDiskUsed
BytesInPerSec
BytesOutPerSec
MessagesInPerSec
UnderReplicatedPartitions
OfflinePartitionsCount
ActiveControllerCount
ZooKeeperSessionState where relevant
RequestTime
RequestQueueTime
NetworkProcessorAvgIdlePercent
RequestHandlerAvgIdlePercent
ProduceTotalTimeMsMean
FetchConsumerTotalTimeMsMean
Consumer lag
```

MSK publishes CloudWatch metrics, and provisioned clusters can expose Prometheus-compatible broker and JMX metrics through Open Monitoring. ([AWS Documentation][33])

---

# 93. Critical Kafka alarms

```text
OfflinePartitionsCount > 0
UnderReplicatedPartitions > 0
ActiveControllerCount != 1
CPU User + CPU System approaching limit
Disk usage high
Consumer lag growing
Produce or fetch latency high
Broker connection errors
Authentication failures increasing
```

A consumer-lag alarm should consider:

```text
Current lag
+
Lag growth rate
+
Business processing deadline
```

A lag of one million events may be harmless if consumers process ten million per minute.

A lag of 10,000 may be critical if events must be processed within five seconds.

---

# 94. Consumer lag

```text
Latest partition offset:
10,000

Consumer committed offset:
8,000

Lag:
2,000 records
```

Lag increases when:

* Producer rate exceeds consumer rate.
* Consumer is down.
* Rebalances are frequent.
* Downstream dependency is slow.
* A partition is hot.
* Processing has poison records.
* Consumer concurrency is too low.

Fix the constrained component rather than only adding consumers.

---

# 95. MSK Replicator

MSK Replicator provides managed asynchronous replication between MSK clusters.

It can replicate:

* Topic records.
* Topic configurations.
* Selected ACL metadata.
* Consumer-group offsets.

It supports same-Region and cross-Region replication. For replication between MSK clusters, source and destination currently need to be in the same AWS account. ([AWS Documentation][34])

```text
MSK Mumbai
    |
    | MSK Replicator
    v
MSK Singapore
```

---

# 96. Consumer-offset replication

Offsets in the destination cluster differ from source offsets because Replicator consumes and republishes records.

When offset synchronization is enabled, MSK Replicator translates source consumer positions so consumers can resume near the correct target position after failover. Consumers far behind the source tip may reprocess more duplicates after failover. ([AWS Documentation][35])

Consumers must therefore remain idempotent after regional failover.

---

# 97. Active-passive Kafka DR

```text
Primary Region
├── Producers active
└── Consumers active
        |
        v
MSK Replicator
        |
        v
DR Region
├── Replicated topics
└── Consumers stopped or passive
```

Failover:

```text
1. Stop or isolate primary producers.

2. Confirm replication position.

3. Redirect producers.

4. Start target consumers.

5. Use synchronized group offsets.

6. Monitor duplicates and lag.
```

This is usually simpler than active-active writes.

---

# 98. Active-active replication

Active-active Kafka is significantly more complex.

```text
Region A producers
    |
    v
Topic A
    |
    ↕
Replication
    |
    v
Topic B
    ^
    |
Region B producers
```

Risks:

* Replication loops.
* Topic naming conflicts.
* Duplicate events.
* Concurrent updates.
* Consumer-group offset conflicts.
* Ordering differences across Regions.

MSK Replicator active-active guidance requires distinct consumer-group IDs across regional consumer sets to prevent replicated offsets from overwriting one another. ([AWS Documentation][36])

Use active-active only when the application data model can handle regional concurrency explicitly.

---

# 99. Terraform MSK configuration

```hcl
resource "aws_msk_configuration" "production" {
  name = "production-todo-streaming"

  kafka_versions = [
    var.kafka_version
  ]

  server_properties = <<PROPERTIES
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
unclean.leader.election.enable=false
num.partitions=12
log.retention.hours=168
PROPERTIES
}
```

Production recommendations:

```text
Disable automatic topic creation.
Create topics explicitly.
Set replication factor intentionally.
Set minimum ISR intentionally.
Version configuration changes.
```

---

# 100. Terraform MSK provisioned cluster

```hcl
resource "aws_msk_cluster" "production" {
  cluster_name = "production-todo-streaming"

  kafka_version = var.kafka_version

  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type = "kafka.m7g.large"

    client_subnets = [
      aws_subnet.streaming_a.id,
      aws_subnet.streaming_b.id,
      aws_subnet.streaming_c.id
    ]

    security_groups = [
      aws_security_group.msk.id
    ]

    storage_info {
      ebs_storage_info {
        volume_size = 500

        provisioned_throughput {
          enabled           = true
          volume_throughput = 250
        }
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.production.arn
    revision = aws_msk_configuration.production.latest_revision
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk.arn

    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  enhanced_monitoring = "PER_BROKER"

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }

      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
    }
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Validate broker types, Kafka versions and provider fields against the installed AWS provider and selected Region.

---

# 101. Kafka topic creation

```bash
kafka-topics.sh \
  --bootstrap-server "$BOOTSTRAP_BROKERS" \
  --command-config client.properties \
  --create \
  --topic todo-events \
  --partitions 12 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete
```

Describe:

```bash
kafka-topics.sh \
  --bootstrap-server "$BOOTSTRAP_BROKERS" \
  --command-config client.properties \
  --describe \
  --topic todo-events
```

---

# 102. Producer configuration

```properties
bootstrap.servers=BOOTSTRAP_BROKERS

security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler

acks=all
enable.idempotence=true
retries=2147483647
max.in.flight.requests.per.connection=5

compression.type=zstd
linger.ms=10
batch.size=65536
delivery.timeout.ms=120000
```

Tune batching only after measuring:

* Event latency.
* Compression ratio.
* Throughput.
* Producer memory.
* Broker CPU.

---

# 103. Consumer configuration

```properties
bootstrap.servers=BOOTSTRAP_BROKERS

security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler

group.id=todo-search-indexer
enable.auto.commit=false
auto.offset.reset=earliest

max.poll.records=500
max.poll.interval.ms=300000
session.timeout.ms=45000
```

Processing:

```text
Poll batch
    |
    v
Process idempotently
    |
    v
Commit offsets
```

---

# 104. TodoApp streaming architecture

```text
Todo API
   |
   | TODO_CREATED / TODO_UPDATED / TODO_COMPLETED
   v
Kinesis or MSK
   |
   ├── Notification consumer
   ├── OpenSearch indexer
   ├── Analytics consumer
   ├── Audit consumer
   └── Data-lake sink
```

Authoritative state:

```text
Aurora or DynamoDB
```

Search state:

```text
OpenSearch
```

Historical analytics:

```text
S3 data lake
```

Real-time notifications:

```text
Lambda / ECS consumer
```

---

# 105. Outbox pattern

Problem:

```text
Application writes database
        |
        v
Application publishes event
```

Possible result:

```text
Database commit succeeds
Event publication fails
```

Outbox pattern:

```text
Database transaction
├── Update todo
└── Insert outbox event
        |
        v
CDC or outbox publisher
        |
        v
Kinesis / MSK
```

This prevents a business change from being committed without a durable event record.

---

# 106. Kinesis troubleshooting: producer throttling

Symptoms:

```text
ProvisionedThroughputExceededException
WriteProvisionedThroughputExceeded increases
Producer retry latency increases
```

Check:

* Records per second.
* Bytes per second.
* Partition-key distribution.
* Large records.
* Current capacity mode.
* Number of provisioned shards.
* Planned traffic increase.

Fix:

* Increase shards.
* Switch to on-demand where suitable.
* Improve partition-key distribution.
* Batch small records.
* Store large payloads in S3.
* Use exponential backoff and jitter.

---

# 107. Kinesis troubleshooting: consumer lag

Check:

```text
IteratorAgeMilliseconds
Function duration
Function errors
Function throttles
Parallelization factor
Shard count
Downstream latency
Poison records
```

Possible actions:

* Increase Lambda concurrency.
* Increase parallelization factor.
* Add KCL workers.
* Use enhanced fan-out.
* Increase stream shards if one worker-per-shard is insufficient.
* Batch downstream writes.
* Repair poison-record handling.

---

# 108. Kinesis troubleshooting: records out of order

Possible causes:

* Different partition keys.
* `PutRecords` retries.
* Producer concurrency.
* Resharding assumptions.
* KPL aggregation/deaggregation issue.
* Parallel consumer processing.
* Business records arrived in a different order upstream.

If strict ordering is required:

* Use one stable partition key per aggregate.
* Use idempotent version numbers.
* Reject older aggregate versions.
* Use `PutRecord` ordering support where needed.
* Avoid cross-shard ordering assumptions.

---

# 109. MSK troubleshooting: producer cannot connect

Check:

* Bootstrap broker type.
* Client VPC connectivity.
* Security groups.
* DNS.
* TLS trust.
* IAM, SCRAM or certificate configuration.
* Authentication plugin.
* Correct Kafka port.
* Multi-VPC connectivity.
* Public access settings.
* Broker state.

A cluster can be `ACTIVE` while clients still cannot connect because application networking or authentication is incorrect. ([AWS Documentation][37])

---

# 110. MSK troubleshooting: under-replicated partitions

Symptoms:

```text
UnderReplicatedPartitions > 0
```

Possible causes:

* Broker failure.
* Disk throughput saturation.
* Network pressure.
* Replica fetcher delay.
* Broker CPU saturation.
* Partition movement.
* Large replication backlog.

Check:

* Broker health.
* CPU.
* Disk usage.
* Storage throughput.
* Network.
* Replica lag.
* Recent maintenance.
* Broker logs.

Sustained under-replication reduces durability and failover safety.

---

# 111. MSK troubleshooting: offline partitions

```text
OfflinePartitionsCount > 0
```

means one or more partitions have no active leader.

Impact:

* Producers cannot write affected partitions.
* Consumers cannot read affected partitions.

Treat this as a production incident.

Investigate:

* Broker availability.
* ISR.
* Leader-election state.
* Minimum ISR.
* Storage.
* Cluster controller.
* KMS and networking.
* Broker logs.

---

# 112. MSK troubleshooting: consumer lag

Check:

* Consumer-group member count.
* Topic partition count.
* Hot partitions.
* Processing duration.
* Rebalances.
* Downstream dependency.
* Batch size.
* Fetch configuration.
* Failed records.
* Consumer CPU and memory.

Adding more consumers only helps when:

```text
Unused partitions are available
```

If one partition holds most traffic, that partition remains assigned to one consumer.

---

# 113. MSK troubleshooting: disk running low

For Standard brokers:

* Increase EBS capacity.
* Enable storage autoscaling.
* Reduce retention.
* Delete obsolete topics.
* Enable tiered storage where supported.
* Correct partition imbalance.
* Add brokers and reassign partitions.
* Investigate unexpected producer growth.

Do not wait for disk exhaustion. MSK publishes storage metrics and operational alerts for Standard clusters. ([AWS Documentation][38])

---

# 114. MSK troubleshooting: `NotLeaderForPartition`

This commonly means:

* Partition leadership changed.
* Client metadata is stale.
* Broker is undergoing maintenance.
* Leader election occurred.

Correct clients should:

```text
Refresh metadata
Retry with backoff
Connect to the new leader
```

If persistent:

* Inspect offline partitions.
* Inspect under-replicated partitions.
* Check broker health.
* Check client and broker compatibility.
* Check network access to all brokers.

---

# 115. Kinesis versus MSK decision table

| Situation                               | Recommended starting point   |
| --------------------------------------- | ---------------------------- |
| Simple AWS-native event processing      | Kinesis                      |
| Lambda-first architecture               | Kinesis                      |
| No Kafka skills in team                 | Kinesis                      |
| Need 24-hour to 365-day replay          | Kinesis                      |
| Existing Kafka application              | MSK                          |
| Need Kafka Streams                      | MSK                          |
| Need log compaction                     | MSK                          |
| Need Kafka Connect ecosystem            | MSK                          |
| Need managed Kafka CDC connectors       | MSK Connect                  |
| Unpredictable Kafka traffic             | MSK Serverless               |
| High-performance managed Kafka storage  | Express brokers              |
| Maximum Kafka configuration control     | Standard brokers             |
| Long Kafka retention                    | Standard with tiered storage |
| Managed cross-cluster Kafka replication | MSK Replicator               |

---

# 116. Production readiness checklist

```text
[ ] Stream or topic purpose is documented
[ ] Events have unique event IDs
[ ] Event schema is versioned
[ ] Partition key supports ordering requirements
[ ] Partition key has enough cardinality
[ ] Hot-key risks are load tested
[ ] Producers use bounded retries
[ ] Producer partial failures are handled
[ ] Consumers are idempotent
[ ] Replay has been tested
[ ] Retention exceeds maximum recovery window
[ ] Consumer-lag alarms exist
[ ] Poison-record handling exists
[ ] Failure destinations or dead-letter paths exist
[ ] Large payloads use S3 references where appropriate
[ ] Encryption is enabled
[ ] IAM is least privilege
[ ] VPC endpoints or private connectivity are configured
[ ] Kinesis capacity mode is intentional
[ ] Provisioned shard count handles peak traffic
[ ] Enhanced fan-out is used only where justified
[ ] KCL DynamoDB metadata is monitored
[ ] Lambda parallelization protects downstream systems
[ ] Kafka topic partition count is planned
[ ] Kafka replication factor is at least production appropriate
[ ] min.insync.replicas is configured
[ ] Producers use acks=all for critical events
[ ] Idempotent producers are enabled
[ ] Offset-commit strategy is documented
[ ] Consumer-group rebalance behaviour is tested
[ ] Kafka schemas have compatibility rules
[ ] Auto topic creation is disabled in production
[ ] Broker CPU has failure headroom
[ ] Broker disk and storage throughput are monitored
[ ] Under-replicated partitions are alarmed
[ ] Offline partitions are alarmed
[ ] Cross-Region recovery is tested
[ ] Replicated consumer offsets are validated
[ ] Database/event dual writes use an outbox or CDC pattern
```

---

# 117. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Kinesis Data Streams:
Managed real-time event stream.

Amazon MSK:
Managed Apache Kafka.

Shard:
Kinesis capacity and ordering unit.

Partition:
Kafka ordering and parallelism unit.
```

## Solutions Architect Associate

Understand:

```text
Kinesis provisioned versus on-demand
Shard capacity
Partition keys
Enhanced fan-out
Retention and replay
Lambda event-source mappings
MSK topics and partitions
Consumer groups
Replication factor
Multi-AZ Kafka brokers
MSK Serverless
```

## DevOps Engineer Professional

Understand:

```text
Hot-shard troubleshooting
KCL checkpointing
Partial batch failures
Idempotent consumers
Poison-record handling
Kafka ISR and min.insync.replicas
Producer acknowledgements
Idempotent Kafka producers
Consumer lag and rebalances
MSK Express brokers
Tiered storage
MSK Connect
MSK Replicator
Cross-Region failover
```

---

# 118. Interview questions

## Question 1: What is Kinesis Data Streams?

**Answer:**

It is an AWS-managed real-time streaming service that stores ordered event records across shards for multiple independent consumers.

## Question 2: What is a Kinesis shard?

**Answer:**

It is a stream-capacity and ordering unit that stores a sequence of records and provides bounded read and write throughput.

## Question 3: What does a Kinesis partition key do?

**Answer:**

It is hashed to select a shard and therefore affects traffic distribution and ordering.

## Question 4: What is the sustained write capacity of one Kinesis shard?

**Answer:**

Approximately 1 MiB per second or 1,000 records per second, whichever limit is reached first.

## Question 5: What is enhanced fan-out?

**Answer:**

It gives each registered consumer dedicated read throughput of up to 2 MiB per second per shard.

## Question 6: What is KCL?

**Answer:**

The Kinesis Client Library coordinates distributed consumers using shard leases and checkpoints stored through DynamoDB metadata.

## Question 7: Is Kinesis exactly once?

**Answer:**

No. Kinesis consumer processing should generally be treated as at least once, so consumers must be idempotent.

## Question 8: How long can Kinesis retain records?

**Answer:**

From 24 hours to 365 days.

## Question 9: What is Amazon MSK?

**Answer:**

It is AWS’s managed service for running Apache Kafka.

## Question 10: What is a Kafka partition?

**Answer:**

It is an ordered append-only log inside a topic and is the unit of producer routing and consumer parallelism.

## Question 11: What is a consumer group?

**Answer:**

It is a set of Kafka consumers cooperating to process partitions, with each partition assigned to at most one active consumer within the group.

## Question 12: Does Kafka preserve ordering across a topic?

**Answer:**

Only inside each partition, not across all topic partitions.

## Question 13: What is replication factor?

**Answer:**

It is the number of broker copies maintained for each Kafka partition.

## Question 14: What is ISR?

**Answer:**

The in-sync replica set contains partition replicas sufficiently caught up with the leader.

## Question 15: What is `min.insync.replicas`?

**Answer:**

With `acks=all`, it defines the minimum replication condition required before a write can succeed.

## Question 16: What is an idempotent Kafka producer?

**Answer:**

It prevents duplicate records caused by producer retries using producer identity and sequence tracking.

## Question 17: What is log compaction?

**Answer:**

It retains the latest value for each record key rather than retaining every historical update indefinitely.

## Question 18: What is MSK Serverless?

**Answer:**

It is an MSK mode that automatically manages Kafka compute and partition capacity using a throughput-based model.

## Question 19: What are Express brokers?

**Answer:**

They are MSK Provisioned brokers with managed elastic storage and enforced high-availability defaults, designed for higher elasticity and reduced storage operations.

## Question 20: What is MSK Replicator?

**Answer:**

It is a managed feature that asynchronously replicates records and selected Kafka metadata, including consumer-group offsets, between MSK clusters.

---

# 119. Never-forget revision

```text
Event:
Immutable description of something that happened.

Stream:
Retained ordered event log.

Kinesis shard:
Capacity and ordering unit.

Partition key:
Controls Kinesis shard placement.

Sequence number:
Kinesis record position inside a shard.

Enhanced fan-out:
Dedicated consumer read throughput.

KCL:
Distributed Kinesis consumer coordination.

Checkpoint:
Last successfully processed stream position.

Kafka topic:
Named event stream.

Kafka partition:
Ordered log and parallelism unit.

Kafka offset:
Record position inside one partition.

Consumer group:
Consumers sharing topic partitions.

Broker:
Kafka server.

Leader:
Partition replica serving normal requests.

Follower:
Partition replica copying the leader.

ISR:
In-sync replicas.

Replication factor:
Total partition copies.

acks=all:
Require acknowledgement from required ISR members.

Idempotent producer:
Prevents retry-created Kafka duplicates.

Retention:
How long records remain replayable.

Compaction:
Keep latest value per key.

MSK Serverless:
Automatically scaled managed Kafka.

Standard broker:
Most configuration and storage control.

Express broker:
Managed elastic storage and enforced HA defaults.

MSK Connect:
Managed Kafka Connect.

MSK Replicator:
Managed cluster-to-cluster replication.
```

## One-line memory trick

```text
Choose a key for ordering.
Choose partitions for parallelism.
Retain enough history for recovery.
Expect duplicate delivery.
Monitor consumer lag.
Protect every downstream system.
```

## Lesson 50 outcome

You can now design streaming systems where:

```text
Todo events require simple AWS processing
    → Kinesis Data Streams provides shards and replay.

Traffic is unpredictable
    → Kinesis on-demand manages capacity.

Many independent consumers need low latency
    → Enhanced fan-out gives dedicated reads.

A consumer crashes before checkpointing
    → Idempotency prevents duplicate business changes.

A malformed event blocks Lambda
    → Partial failures and a failure destination isolate it.

Existing services use Kafka clients
    → Amazon MSK preserves the Kafka ecosystem.

Kafka producers require durable writes
    → Replication factor 3, minimum ISR 2 and acks=all are used.

Consumer throughput needs to increase
    → Topic partitions and consumer-group members scale together.

Historical data must remain replayable
    → Kafka retention or MSK tiered storage preserves it.

A database must publish reliable changes
    → CDC or an outbox sends events to the stream.

A Region becomes unavailable
    → MSK Replicator and synchronized offsets support failover.
```

**Next lesson: Lesson 51 — AWS Step Functions and production workflow orchestration: Standard versus Express workflows, states, retries, catches, compensation, callbacks, distributed maps, human approvals, idempotency and observability.**

[1]: https://docs.aws.amazon.com/streams/latest/dev/introduction.html?utm_source=chatgpt.com "What is Amazon Kinesis Data Streams?"
[2]: https://docs.aws.amazon.com/streams/latest/dev/key-concepts.html?utm_source=chatgpt.com "Amazon Kinesis Data Streams Terminology and concepts"
[3]: https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecord.html?utm_source=chatgpt.com "PutRecord - Amazon Kinesis Data Streams Service"
[4]: https://docs.aws.amazon.com/streams/latest/dev/building-producers.html?utm_source=chatgpt.com "Write data to Amazon Kinesis Data Streams - Amazon Kinesis Data Streams"
[5]: https://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html?utm_source=chatgpt.com "PutRecords - Amazon Kinesis Data Streams Service"
[6]: https://docs.aws.amazon.com/streams/latest/dev/kinesis-record-processor-duplicates.html?utm_source=chatgpt.com "Handle duplicate records - Amazon Kinesis Data Streams"
[7]: https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html "Choose the right mode to stream in - Amazon Kinesis Data Streams"
[8]: https://docs.aws.amazon.com/streams/latest/dev/how-do-i-size-a-stream.html?utm_source=chatgpt.com "Choose the right mode to stream in - Amazon Kinesis Data Streams"
[9]: https://docs.aws.amazon.com/streams/latest/dev/large-records.html "Handle large records - Amazon Kinesis Data Streams"
[10]: https://docs.aws.amazon.com/streams/latest/dev/kinesis-kpl-concepts.html?utm_source=chatgpt.com "KPL key concepts - Amazon Kinesis Data Streams"
[11]: https://docs.aws.amazon.com/streams/latest/dev/enhanced-consumers.html?utm_source=chatgpt.com "Develop enhanced fan-out consumers with dedicated ..."
[12]: https://docs.aws.amazon.com/streams/latest/dev/kcl.html?utm_source=chatgpt.com "Use Kinesis Client Library - Amazon Kinesis Data Streams"
[13]: https://docs.aws.amazon.com/streams/latest/dev/kcl-concepts.html?utm_source=chatgpt.com "KCL concepts - Amazon Kinesis Data Streams"
[14]: https://docs.aws.amazon.com/streams/latest/dev/kinesis-record-processor-implementation-app-dotnet.html?utm_source=chatgpt.com "Develop a Kinesis Client Library consumer in .NET - Amazon Kinesis Data Streams"
[15]: https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html?utm_source=chatgpt.com "Using Lambda to process records from Amazon Kinesis ..."
[16]: https://docs.aws.amazon.com/lambda/latest/dg/services-kinesis-batchfailurereporting.html?utm_source=chatgpt.com "Configuring partial batch response with Kinesis Data Streams ..."
[17]: https://docs.aws.amazon.com/lambda/latest/dg/kinesis-on-failure-destination.html?utm_source=chatgpt.com "Retain discarded batch records for a Kinesis Data Streams ..."
[18]: https://docs.aws.amazon.com/streams/latest/dev/monitoring-with-cloudwatch.html?utm_source=chatgpt.com "Monitor the Amazon Kinesis Data Streams service with Amazon CloudWatch - Amazon Kinesis Data Streams"
[19]: https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html?utm_source=chatgpt.com "Welcome to the Amazon MSK Developer Guide"
[20]: https://kafka.apache.org/40/implementation/distribution/?utm_source=chatgpt.com "Distribution | Apache Kafka"
[21]: https://docs.aws.amazon.com/msk/latest/developerguide/broker-instance-types.html "Amazon MSK broker types - Amazon Managed Streaming for Apache Kafka"
[22]: https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html "What is MSK Serverless? - Amazon Managed Streaming for Apache Kafka"
[23]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-broker-types-express.html "Amazon MSK Express brokers - Amazon Managed Streaming for Apache Kafka"
[24]: https://kafka.apache.org/41/design/design/?utm_source=chatgpt.com "Design | Apache Kafka"
[25]: https://kafka.apache.org/40/configuration/topic-level-configs/?utm_source=chatgpt.com "Topic-Level Configs | Apache Kafka"
[26]: https://docs.aws.amazon.com/msk/latest/developerguide/monitoring.html?utm_source=chatgpt.com "Monitor an Amazon MSK Provisioned cluster"
[27]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-tiered-storage.html "Tiered storage for Standard brokers - Amazon Managed Streaming for Apache Kafka"
[28]: https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html?utm_source=chatgpt.com "Best practices for Standard brokers"
[29]: https://docs.aws.amazon.com/msk/latest/developerguide/aws-access-mult-vpc.html?utm_source=chatgpt.com "Amazon MSK multi-VPC private connectivity in a single ..."
[30]: https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html?utm_source=chatgpt.com "IAM access control"
[31]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-connect.html?utm_source=chatgpt.com "Understand MSK Connect"
[32]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-connect-set-offset-storage-topic.html?utm_source=chatgpt.com "Use custom offset storage topic - AWS Documentation"
[33]: https://docs.aws.amazon.com/msk/latest/developerguide/open-monitoring.html?utm_source=chatgpt.com "Monitor an MSK Provisioned cluster with Prometheus - Amazon Managed Streaming for Apache Kafka"
[34]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator.html "Amazon MSK Replicator - Amazon Managed Streaming for Apache Kafka"
[35]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-bidirectional-offset-sync.html?utm_source=chatgpt.com "Consumer group offset synchronization"
[36]: https://docs.aws.amazon.com/msk/latest/developerguide/msk-replicator-active-active.html?utm_source=chatgpt.com "Active-active replication"
[37]: https://docs.aws.amazon.com/msk/latest/developerguide/troubleshooting.html?utm_source=chatgpt.com "Troubleshoot your Amazon MSK cluster - Amazon Managed Streaming for Apache Kafka"
[38]: https://docs.aws.amazon.com/msk/latest/developerguide/cluster-alerts.html?utm_source=chatgpt.com "Use Amazon MSK storage capacity alerts - Amazon Managed Streaming for Apache Kafka"
