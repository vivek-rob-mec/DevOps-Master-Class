# AWS Masterclass — Phase 3

# Lesson 43: Amazon DynamoDB Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Decide when DynamoDB is the correct database.
* Design tables from application access patterns.
* Choose effective partition and sort keys.
* Avoid hot keys and uneven traffic distribution.
* Model one-to-many and many-to-many relationships.
* Use global and local secondary indexes.
* Choose on-demand or provisioned capacity.
* Calculate read and write capacity consumption.
* Understand warm throughput and adaptive capacity.
* Use eventual, strong and transactional consistency.
* Implement conditional writes and optimistic locking.
* Use DynamoDB transactions correctly.
* Process changes using DynamoDB Streams.
* Configure TTL, backups, PITR and S3 export.
* Design multi-Region applications with global tables.
* Implement single-table designs.
* Secure tables using IAM and KMS.
* Monitor and troubleshoot throttling.
* Deploy production DynamoDB tables using Terraform.

---

# 2. What is Amazon DynamoDB?

Amazon DynamoDB is a:

```text
Serverless
Fully managed
Distributed
NoSQL key-value and document database
```

It is designed for operational applications that need predictable, single-digit millisecond performance at virtually any scale without managing database servers, operating systems, replication software or database maintenance windows. ([AWS Documentation][1])

Basic architecture:

```text
Application
    |
    | DynamoDB API request
    v
Amazon DynamoDB
    |
    ├── Data partitioning
    ├── Replication
    ├── Scaling
    ├── Encryption
    ├── Backup
    └── Failure handling
```

---

# 3. DynamoDB is not a relational database

A relational application often begins with:

```text
Tables
Relationships
Normalization
Foreign keys
Joins
```

A DynamoDB application should begin with:

```text
Access patterns
Expected request rates
Consistency requirements
Item relationships
Key design
```

DynamoDB intentionally avoids expensive relational features such as server-side joins because they are difficult to execute predictably across a distributed database at extreme scale. ([AWS Documentation][1])

## Relational mental model

```sql
SELECT *
FROM todos
WHERE user_id = 'user-104'
  AND status = 'OPEN'
ORDER BY created_at DESC;
```

The database optimizer decides:

* Which index to use.
* How to join tables.
* How to scan.
* How to sort.

## DynamoDB mental model

You design a key structure that directly supports:

```text
Get all open todos for user-104
ordered by creation time
```

Then the application performs one targeted `Query`.

---

# 4. When DynamoDB is a strong choice

DynamoDB is well suited for:

* Serverless applications.
* User profiles.
* Shopping carts.
* Session storage.
* Gaming state.
* Orders.
* Product catalogues.
* IoT device state.
* Metadata.
* Idempotency records.
* Event deduplication.
* High-scale API backends.
* Real-time operational data.
* Multi-Region active-active applications.
* Workloads needing predictable key-based access.

Example:

```text
API Gateway
    |
    v
Lambda
    |
    v
DynamoDB
```

This combination can scale without operating API or database servers.

---

# 5. When DynamoDB may not be the best choice

Evaluate Aurora, RDS, OpenSearch, S3 or a warehouse when you need:

* Complex ad hoc joins.
* Arbitrary analytical queries.
* Heavy relational reporting.
* Large multi-row SQL transformations.
* Existing stored-procedure-heavy applications.
* Full-text search.
* Complex aggregation across many dimensions.
* Unknown query patterns.
* Large objects above DynamoDB’s item-size limit.

DynamoDB’s maximum item size is currently `400 KB`, including attribute names and values. Store large documents, videos or files in S3 and store only their metadata and S3 location in DynamoDB. ([AWS Documentation][2])

---

# 6. Core DynamoDB components

```text
Table
  └── Item
       └── Attribute
```

## Table

A collection of items.

```text
TodoApp
```

## Item

One stored object.

```json
{
  "userId": "user-104",
  "todoId": "todo-501",
  "title": "Learn DynamoDB",
  "status": "OPEN"
}
```

## Attribute

One field inside an item.

```text
title
status
createdAt
```

Items in one DynamoDB table do not need to contain identical attributes. DynamoDB supports scalar, set and document-style attribute values. ([AWS Documentation][3])

---

# 7. DynamoDB data types

Common scalar types:

```text
String
Number
Binary
Boolean
Null
```

Collection types:

```text
String Set
Number Set
Binary Set
List
Map
```

Example:

```json
{
  "PK": "USER#104",
  "SK": "TODO#501",
  "title": "Complete AWS lesson",
  "priority": 1,
  "completed": false,
  "tags": ["aws", "devops"],
  "metadata": {
    "source": "web",
    "version": 2
  }
}
```

---

# 8. Primary keys

Every item is uniquely identified by its primary key.

Two primary-key models are available:

```text
Simple primary key:
Partition key

Composite primary key:
Partition key + sort key
```

DynamoDB hashes the partition-key value to determine the internal physical partition where data is stored. Items sharing a partition key are stored together and ordered by sort-key value. ([AWS Documentation][3])

---

# 9. Simple primary key

Example:

```text
Partition key:
todoId
```

Table:

| `todoId`   | `title`        |
| ---------- | -------------- |
| `todo-501` | Learn DynamoDB |
| `todo-502` | Deploy API     |

Every partition-key value must be unique.

You cannot store:

```text
todoId = todo-501
todoId = todo-501
```

as two separate items in a simple-key table.

---

# 10. Composite primary key

Example:

```text
Partition key:
userId

Sort key:
todoId
```

Items:

| `userId`   | `todoId`   | `title`              |
| ---------- | ---------- | -------------------- |
| `user-104` | `todo-501` | Learn DynamoDB       |
| `user-104` | `todo-502` | Deploy API           |
| `user-205` | `todo-601` | Configure CloudFront |

The combination must be unique:

```text
userId + todoId
```

Multiple items can share the same partition key if their sort keys differ.

---

# 11. Partition key purpose

A partition key serves two related purposes:

```text
Data placement
+
Query grouping
```

A good partition key:

* Has many possible values.
* Distributes traffic broadly.
* Matches important access patterns.
* Avoids concentrating requests on one value.
* Keeps related items together where useful.

AWS recommends partition keys with a large number of distinct values relative to the total item count so data and traffic distribute effectively. ([AWS Documentation][4])

---

# 12. Bad partition-key examples

## Constant value

```text
PK = ALL_TODOS
```

Every item and every request targets the same logical key area.

## Low-cardinality status

```text
PK = OPEN
PK = CLOSED
```

Most active todos may use:

```text
PK = OPEN
```

creating a hot key.

## Current date

```text
PK = 2026-07-28
```

All writes for today target one partition-key value.

## Better choices

```text
PK = USER#104
PK = ORDER#501
PK = DEVICE#204
PK = TENANT#38
```

---

# 13. Physical-partition throughput

A DynamoDB physical partition is designed to support up to approximately:

```text
3,000 strongly consistent read units per second
1,000 write units per second
```

Adaptive capacity can shift available table capacity toward heavily used partitions, but one poorly chosen hot partition key can still encounter key-range throttling. ([AWS Documentation][5])

This is not a statement that every logical partition key receives a guaranteed `3,000 RCU` and `1,000 WCU`.

It means the underlying physical partition has finite capacity.

---

# 14. Hot partitions and hot keys

A hot key receives a disproportionately large share of requests.

Example:

```text
PK = CELEBRITY#104
```

Suppose:

```text
Normal users:
10 reads/second

Celebrity user:
20,000 reads/second
```

Even if total table capacity is sufficient, one key range can become a bottleneck.

Symptoms:

* `ThrottlingException`.
* High `ReadKeyRangeThroughputThrottleEvents`.
* High `WriteKeyRangeThroughputThrottleEvents`.
* Uneven application latency.
* One customer or entity disproportionately affected.

AWS recommends fixing the partition-key design as the long-term solution for key-range throughput throttling. ([AWS Documentation][6])

---

# 15. Write sharding

If all writes naturally target one key, add a controlled shard suffix.

Bad:

```text
PK = DATE#2026-07-28
```

Sharded:

```text
PK = DATE#2026-07-28#00
PK = DATE#2026-07-28#01
PK = DATE#2026-07-28#02
...
PK = DATE#2026-07-28#09
```

Write flow:

```text
Calculate or select shard
        |
        v
Write to one of 10 partition-key values
```

Read flow:

```text
Query all 10 shards
        |
        v
Merge results
```

AWS documents random and calculated suffix sharding as techniques for distributing write-heavy workloads. ([AWS Documentation][7])

Use sharding only when necessary because it increases read complexity.

---

# 16. Sort keys

Sort keys organize related items inside one partition-key value.

Example:

```text
PK = USER#104

SK values:
PROFILE
TODO#2026-07-28T01:00:00Z#501
TODO#2026-07-28T02:00:00Z#502
TODO#2026-07-28T03:00:00Z#503
```

A query can retrieve:

```text
Every item for USER#104
```

or only:

```text
Items whose sort key begins with TODO#
```

Sort keys are valuable for hierarchical relationships, range queries, version history and time ordering. ([AWS Documentation][8])

---

# 17. Sort-key ordering

String sort keys are ordered by UTF-8 byte sequence.

Number sort keys are ordered numerically.

For ISO 8601 timestamps:

```text
2026-07-27T10:00:00Z
2026-07-28T10:00:00Z
2026-07-29T10:00:00Z
```

lexicographical order also matches chronological order.

Example:

```text
SK = TODO#2026-07-28T10:30:00Z#todo-501
```

This enables newest-first or oldest-first queries without server-side sorting.

---

# 18. Sort-key operators

A `Query` can use sort-key conditions such as:

```text
=
<
<=
>
>=
BETWEEN
begins_with
```

Example:

```text
PK = USER#104
AND
SK begins_with TODO#
```

Date range:

```text
PK = USER#104
AND
SK BETWEEN
TODO#2026-07-01
AND
TODO#2026-07-31~
```

The partition-key equality is mandatory for a normal `Query`; the sort-key condition is optional. ([AWS Documentation][9])

---

# 19. Query versus Scan

## Query

```text
Find one partition-key value
and optionally restrict its sort-key range
```

Example:

```text
Get all todos for user-104.
```

## Scan

```text
Read every item or index entry
and optionally discard nonmatching results
```

Example:

```text
Search the entire table for status=OPEN.
```

Use `Query` for production request paths whenever possible.

---

# 20. Why Scan is expensive

A scan reads table data before applying its filter.

```text
Read page of items
      |
      v
Consume read capacity
      |
      v
Apply FilterExpression
      |
      v
Discard nonmatching items
```

A single `Scan` page reads up to `1 MB` before its filter expression is evaluated. ([AWS Documentation][10])

If only one of 10,000 items matches:

```text
DynamoDB still read the items
before discarding the others.
```

---

# 21. Query filters also consume reads first

Suppose a query retrieves:

```text
1,000 items for USER#104
```

Then filters:

```text
status = OPEN
```

If only 20 items remain:

```text
Read capacity was still based on the
1,000 items evaluated before filtering.
```

A `Query` returns up to `1 MB` per page before applying `FilterExpression`. Key attributes must be used in `KeyConditionExpression`, not the filter. ([AWS Documentation][11])

If status is an important access pattern, encode it into a key or index.

---

# 22. Projection expressions do not reduce read capacity

A projection expression can return only selected attributes:

```text
title
status
createdAt
```

But DynamoDB calculates read consumption from item or index-entry size, not merely from the attributes returned to the client. ([AWS Documentation][12])

Projection still helps with:

* Network payload.
* Application parsing.
* Response clarity.
* GSI index size when using index projection.

---

# 23. Pagination

A `Query` or `Scan` can return no more than `1 MB` per page.

If more results exist, the response includes:

```text
LastEvaluatedKey
```

The next request sends:

```text
ExclusiveStartKey = previous LastEvaluatedKey
```

Do not assume one API request retrieves every matching item. ([AWS Documentation][9])

Client-facing pagination token:

```text
LastEvaluatedKey
      |
      v
Encode safely
      |
      v
Return opaque nextToken
```

Do not expose internal database details unnecessarily.

---

# 24. Access-pattern-first design

Before creating a table, write the application questions.

For TodoApp:

```text
1. Get user profile.
2. List todos for one user by creation date.
3. Get one todo by todo ID.
4. List a user's open todos.
5. List todos due on a date.
6. Update todo status safely.
7. Prevent duplicate request processing.
```

Then design keys for those exact operations.

Do not begin with:

```text
What columns should the Todo table contain?
```

Begin with:

```text
Which requests must complete efficiently?
```

---

# 25. Multi-table design

A conventional DynamoDB model might use:

```text
Users table
Todos table
Idempotency table
```

## Users

```text
PK = userId
```

## Todos

```text
PK = userId
SK = todoId
```

## Idempotency

```text
PK = requestId
```

This is simple and valid.

Single-table design is an option—not a universal requirement.

---

# 26. Single-table design

Single-table design stores multiple entity types in one DynamoDB table.

```text
TodoAppTable
├── User profiles
├── Todos
├── Idempotency records
├── Relationships
└── Status projections
```

Items are distinguished through generic key attributes:

```text
PK
SK
GSI1PK
GSI1SK
```

AWS’s data-modeling guidance emphasizes storing related entity types together so multiple related records can be returned through one efficient query. ([AWS Documentation][13])

---

# 27. TodoApp single-table design

## User profile

```json
{
  "PK": "USER#104",
  "SK": "PROFILE",
  "entityType": "USER",
  "name": "Vivek",
  "email": "vivek@example.com"
}
```

## Todo

```json
{
  "PK": "USER#104",
  "SK": "TODO#2026-07-28T01:00:00Z#501",
  "entityType": "TODO",
  "todoId": "501",
  "title": "Learn DynamoDB",
  "status": "OPEN",
  "createdAt": "2026-07-28T01:00:00Z",

  "GSI1PK": "TODO#501",
  "GSI1SK": "TODO#501",

  "GSI2PK": "USER#104#STATUS#OPEN",
  "GSI2SK": "2026-07-28T01:00:00Z#501"
}
```

---

# 28. Access patterns from this design

## Get profile

```text
PK = USER#104
SK = PROFILE
```

Operation:

```text
GetItem
```

## List user todos

```text
PK = USER#104
SK begins_with TODO#
```

Operation:

```text
Query base table
```

## Get todo by global todo ID

```text
GSI1PK = TODO#501
```

Operation:

```text
Query GSI1
```

## List open todos for user

```text
GSI2PK = USER#104#STATUS#OPEN
```

Operation:

```text
Query GSI2
```

---

# 29. Denormalization

When todo status changes from:

```text
OPEN
```

to:

```text
COMPLETED
```

the item’s GSI key changes:

```text
Old:
GSI2PK = USER#104#STATUS#OPEN

New:
GSI2PK = USER#104#STATUS#COMPLETED
```

DynamoDB automatically removes the old index entry and writes the new one.

Denormalization accepts additional writes in exchange for predictable reads.

---

# 30. Single-table benefits

* Related items can be queried together.
* Fewer network round trips.
* Access patterns become explicit.
* Entity relationships can be modeled through item collections.
* Sparse GSIs can support several entity types.
* High-scale workloads can use predictable key operations.

---

# 31. Single-table costs

* Steeper learning curve.
* Generic key names.
* Harder ad hoc inspection.
* More application-side data modeling.
* Index keys can appear cryptic.
* Entity evolution requires care.
* Analytics usually belongs outside the operational table.
* Teams can accidentally create tightly coupled models.

A multi-table design may be clearer when entities have unrelated access patterns, ownership or lifecycle requirements.

---

# 32. Global secondary indexes

A Global Secondary Index, or GSI, provides an alternate partition key and optional sort key.

Base table:

```text
PK = USER#104
SK = TODO#timestamp#501
```

GSI:

```text
GSI1PK = TODO#501
GSI1SK = TODO#501
```

This supports a different query path without scanning the base table.

Each GSI key can differ completely from the base-table key. ([AWS Documentation][14])

---

# 33. GSI synchronization

Applications do not write directly to a GSI.

```text
Write base-table item
        |
        v
DynamoDB asynchronously updates GSI
```

GSI updates are eventually consistent. Under normal operation they propagate quickly, but applications must tolerate an index query temporarily not reflecting a recent base-table write. GSI reads support eventual consistency only. ([AWS Documentation][14])

Therefore:

```text
Write todo
      |
      v
Immediately query GSI
      |
      v
Todo might not appear yet
```

If immediate read-after-write behavior is mandatory, read the base table using its primary key.

---

# 34. GSI projection types

A GSI can project:

```text
KEYS_ONLY
INCLUDE
ALL
```

## `KEYS_ONLY`

Stores only index keys and base-table key attributes.

## `INCLUDE`

Stores selected additional attributes.

## `ALL`

Copies every base-table attribute into the index.

Tradeoff:

```text
More projected attributes
        |
        ├── Faster index-only reads
        ├── More index storage
        └── More write cost
```

A GSI query cannot fetch missing attributes directly from the base table automatically, so project attributes needed frequently by that access pattern. ([AWS Documentation][14])

---

# 35. Sparse GSIs

A GSI contains only items that have its index-key attributes.

Suppose only open todos contain:

```text
GSI2PK
GSI2SK
```

Completed todos remove those attributes.

Then the GSI contains only active todos:

```text
Base table:
Every todo

Sparse GSI:
Only open todos
```

Sparse indexes reduce index storage and write activity while supporting focused access patterns. ([AWS Documentation][15])

---

# 36. GSI write amplification

One base-table write may cause:

```text
Base-table write
+
GSI1 write
+
GSI2 write
+
GSI3 write
```

If an indexed key value changes:

```text
Delete old index entry
+
Create new index entry
```

On provisioned tables, insufficient GSI write capacity can throttle writes to the base table itself. ([AWS Documentation][14])

Monitor every GSI—not only the base table.

---

# 37. Local secondary indexes

A Local Secondary Index, or LSI:

* Uses the same partition key as the base table.
* Uses a different sort key.
* Must be created when the table is created.
* Supports eventually or strongly consistent reads.
* Shares base-table throughput.
* Has stricter item-collection limitations.

DynamoDB permits up to five LSIs per table by default. ([AWS Documentation][16])

Example:

```text
Base table:
PK = USER#104
SK = TODO#todoId

LSI:
PK = USER#104
LSI sort key = createdAt
```

---

# 38. GSI versus LSI

| Characteristic              | GSI                                | LSI               |
| --------------------------- | ---------------------------------- | ----------------- |
| Partition key               | Can differ                         | Same as table     |
| Sort key                    | Optional, can differ               | Must differ       |
| Create after table creation | Yes                                | No                |
| Strongly consistent reads   | No                                 | Yes               |
| Capacity                    | Index-specific in provisioned mode | Shared with table |
| Default quota               | 20                                 | 5                 |
| Most common choice          | Yes                                | Less common       |

GSIs are generally more flexible and are usually preferred unless LSI-specific strong consistency or item-collection behavior is required. ([AWS Documentation][17])

---

# 39. Read consistency

DynamoDB supports:

```text
Eventually consistent reads
Strongly consistent reads
Transactional reads
```

## Eventually consistent

A read might briefly return older data after a successful write.

It consumes half the read capacity of an equivalent strongly consistent read.

## Strongly consistent

Returns the latest successful write from the Region receiving the request.

## Transactional

Reads multiple items with transactional isolation and consumes additional capacity.

For an item up to `4 KB`:

```text
Eventually consistent:
0.5 read unit

Strongly consistent:
1 read unit

Transactional:
2 read units
```

([AWS Documentation][18])

---

# 40. Where strong reads are supported

Strongly consistent reads can be requested from:

```text
Base table GetItem
Base table Query
Local secondary indexes
```

They cannot be requested from:

```text
Global secondary indexes
DynamoDB Streams
```

GSI queries always use eventual consistency. ([AWS Documentation][14])

---

# 41. Choosing consistency

Use eventual consistency for:

* Product lists.
* User activity feeds.
* Noncritical dashboards.
* Content metadata.
* Recently updated values where slight delay is acceptable.

Use strong consistency for:

* Immediate read-after-write confirmation.
* Critical state-machine checks.
* Inventory where stale values cause incorrect decisions.
* Lock records.
* Workflows requiring latest Regional state.

Do not enable strong reads globally by habit. Use them where correctness requires them.

---

# 42. Read capacity calculations

Read capacity is rounded to `4 KB` blocks.

Example item:

```text
Item size:
10 KB
```

Rounded:

```text
12 KB
```

Consumption:

```text
Strongly consistent:
3 read units

Eventually consistent:
1.5 read units

Transactional:
6 read units
```

DynamoDB bases capacity consumption on rounded item size, not the number of attributes returned. ([AWS Documentation][18])

---

# 43. Write capacity calculations

Writes are rounded to `1 KB` blocks.

Example item:

```text
Item size:
2.4 KB
```

Rounded:

```text
3 KB
```

Consumption:

```text
Normal write:
3 write units

Transactional write:
6 write units
```

A `500-byte` item consumes the same normal write capacity as a `1-KB` item. ([AWS Documentation][18])

---

# 44. Capacity modes

DynamoDB provides:

```text
On-demand capacity
Provisioned capacity
```

The selected mode controls how throughput is managed and billed. ([AWS Documentation][19])

---

# 45. On-demand capacity

On-demand mode automatically handles throughput capacity without requiring you to configure RCUs and WCUs.

Use on-demand for:

* New applications.
* Unpredictable traffic.
* Spiky workloads.
* Infrequently used tables.
* Rapidly changing demand.
* Teams that do not want to manage capacity.

AWS currently recommends on-demand mode for most new serverless DynamoDB workloads unless there is a clear reason to use provisioned mode. ([AWS Documentation][20])

---

# 46. On-demand does not mean infinite capacity

On-demand tables can still throttle because of:

* Hot partition keys.
* Account quotas.
* Table maximum-throughput settings.
* Sudden demand beyond current warm throughput.
* GSI hot keys.
* Poor retry behavior.

Correct key design remains mandatory.

---

# 47. Warm throughput

Warm throughput represents the amount of read and write activity that a table or GSI can support immediately based on its scaling history.

```text
Current warm reads:
50,000 operations/second

Current warm writes:
20,000 operations/second
```

For a planned launch expecting much higher traffic, DynamoDB now allows you to proactively increase warm throughput instead of depending only on reactive scaling. Warm throughput is available for tables, GSIs and supported global-table configurations. ([AWS Documentation][21])

Example:

```text
Normal traffic:
5,000 writes/second

Product launch:
Expected 100,000 writes/second

Action:
Pre-warm before launch
```

---

# 48. Maximum throughput for on-demand tables

On-demand tables and individual GSIs can be assigned maximum read and write throughput targets.

Use this for:

* Cost predictability.
* Protection from runaway application loops.
* Limiting an untrusted workload.
* Protecting downstream event consumers.

Requests exceeding the configured target may be throttled, though burst capacity means the configured value should be treated as a best-effort target rather than an absolute hard ceiling. ([AWS Documentation][22])

---

# 49. Provisioned capacity

Provisioned mode configures:

```text
Read capacity units
Write capacity units
```

Example:

```text
Table:
500 RCU
200 WCU

GSI1:
300 RCU
200 WCU
```

Use provisioned mode when:

* Traffic is predictable.
* Capacity is measured accurately.
* You need tighter throughput planning.
* Auto Scaling can follow stable patterns.
* Long-term utilization makes it cost effective.

---

# 50. DynamoDB Auto Scaling

DynamoDB Auto Scaling uses Application Auto Scaling to adjust provisioned table and GSI capacity based on utilization targets. ([AWS Documentation][23])

Example:

```text
Minimum WCU:
100

Maximum WCU:
2,000

Target utilization:
70%
```

If consumption rises:

```text
Auto Scaling increases provisioned WCU
```

If demand falls:

```text
Auto Scaling reduces provisioned WCU
```

Auto Scaling is reactive. It may not respond quickly enough to an instantaneous massive traffic spike, so use scheduled scaling or warm-throughput planning for known events.

---

# 51. Adaptive capacity

Adaptive capacity is automatically enabled for DynamoDB tables.

It redistributes available capacity toward partitions receiving disproportionate traffic when possible. There is no additional charge and no setting to enable manually. ([AWS Documentation][24])

However:

```text
Adaptive capacity
≠
permission to use one constant partition key
```

Good key design remains the foundation.

---

# 52. Burst capacity

DynamoDB can retain unused throughput temporarily and use it to absorb short bursts.

Do not build an application that depends permanently on burst capacity.

A workload might appear healthy during testing:

```text
Unused burst capacity absorbs traffic
```

Then later throttle:

```text
Burst pool exhausted
```

Monitor sustained consumed capacity and key-level throttling rather than assuming a successful short test proves the design.

---

# 53. Conditional writes

A conditional write modifies data only if a condition is true.

Create only if an item does not exist:

```text
attribute_not_exists(PK)
```

Update only if status is open:

```text
status = OPEN
```

Deduct inventory only if enough remains:

```text
quantity >= requestedQuantity
```

DynamoDB condition expressions can be used with `PutItem`, `UpdateItem` and `DeleteItem` to enforce correctness atomically. ([AWS Documentation][25])

---

# 54. Prevent accidental overwrite

A normal `PutItem` replaces an existing item with the same primary key.

Safe create:

```javascript
await client.send(new PutCommand({
  TableName: process.env.TABLE_NAME,

  Item: {
    PK: "USER#104",
    SK: "TODO#501",
    title: "Learn DynamoDB"
  },

  ConditionExpression:
    "attribute_not_exists(PK) AND attribute_not_exists(SK)"
}));
```

If the item exists:

```text
ConditionalCheckFailedException
```

No overwrite occurs.

---

# 55. Atomic counters

DynamoDB can update a numeric field without reading it first.

```text
SET attemptCount = if_not_exists(attemptCount, 0) + 1
```

Advantages:

* One API call.
* Atomic server-side update.
* Reduced race conditions.

But one counter key can become hot under extreme concurrency.

For globally popular counters, consider:

* Sharded counters.
* Event aggregation.
* Streams-based aggregation.
* Approximate metrics.

---

# 56. Optimistic locking

Optimistic locking uses a version attribute.

Existing item:

```json
{
  "PK": "USER#104",
  "SK": "TODO#501",
  "status": "OPEN",
  "version": 7
}
```

Client reads version `7`.

Update:

```text
Set:
status = COMPLETED
version = 8

Only if:
version = 7
```

If another process already changed it to version `8`, the update fails rather than silently overwriting newer data. AWS SDK object mappers and enhanced clients provide version-based optimistic-locking support for selected languages. ([AWS Documentation][26])

---

# 57. Transactions

DynamoDB transactions provide ACID behavior across multiple items and tables in one AWS account and Region.

APIs:

```text
TransactWriteItems
TransactGetItems
```

A transaction can include up to `100` distinct item actions with a combined item size of up to `4 MB`. Every action succeeds, or none succeeds. ([AWS Documentation][27])

---

# 58. Transaction example

Create a todo and update a user counter together:

```text
Transaction
├── Put new todo
├── Increment user's openTodoCount
└── ConditionCheck user exists
```

If any operation fails:

```text
No changes are committed
```

This prevents:

```text
Todo created
but
user counter not updated
```

---

# 59. Batch write is not a transaction

## `BatchWriteItem`

```text
Some actions may succeed
while others remain unprocessed.
```

The application must retry unprocessed items.

## `TransactWriteItems`

```text
All actions succeed
or
all fail.
```

Transactions are for correctness boundaries. Batch operations are for efficiency. ([AWS Documentation][27])

---

# 60. Transaction cost and contention

DynamoDB performs a prepare and commit operation for every transactional item.

Therefore, a transactional read or write consumes approximately twice the equivalent nontransactional capacity. Failed conditional transactions can still consume capacity. ([AWS Documentation][27])

Transactions can also conflict when concurrent requests modify the same items.

Avoid using a transaction merely because several operations happen in the same API request.

Use one only when those changes must succeed or fail together.

---

# 61. Transaction limitations with global tables

DynamoDB transaction guarantees apply only in the Region where the transaction is executed.

Transactions do not form one atomic operation across global-table Regions. Additionally, global tables configured for multi-Region strong consistency do not support transaction APIs. ([AWS Documentation][27])

If global atomic business transactions are required, redesign around:

* Regional ownership.
* A centralized workflow.
* Conditional writes.
* Event-driven reconciliation.
* A different database architecture.

---

# 62. DynamoDB Streams

DynamoDB Streams captures a time-ordered sequence of item-level changes.

Events include:

```text
INSERT
MODIFY
REMOVE
```

Each stream record can include:

* Item keys.
* Old image.
* New image.
* Sequence number.
* Event metadata.

Stream records remain available for up to `24 hours`. ([AWS Documentation][28])

---

# 63. Stream view types

When enabling a stream, choose:

```text
KEYS_ONLY
NEW_IMAGE
OLD_IMAGE
NEW_AND_OLD_IMAGES
```

## `KEYS_ONLY`

Only primary-key attributes.

## `NEW_IMAGE`

Item after modification.

## `OLD_IMAGE`

Item before modification.

## `NEW_AND_OLD_IMAGES`

Both versions.

Choose the smallest stream view that supports the consumer’s requirement.

---

# 64. Streams with Lambda

```text
DynamoDB table
      |
      | Item change
      v
DynamoDB Stream
      |
      v
Lambda event-source mapping
      |
      v
Consumer function
```

Use cases:

* Audit records.
* Search indexing.
* Notifications.
* Materialized views.
* Analytics export.
* Cache invalidation.
* Event publication.
* Data replication.
* Aggregate updates.

DynamoDB integrates directly with Lambda triggers for stream processing. ([AWS Documentation][29])

---

# 65. Stream ordering

Records inside a stream shard are ordered by sequence number.

Shard lineage must be processed in order so a child shard is not processed before its parent. DynamoDB manages shard creation and splitting automatically as table write activity changes. ([AWS Documentation][30])

Lambda stream consumers should still be idempotent because a stored stream record can be processed more than once even though the record itself appears once in the stream. ([AWS Documentation][31])

---

# 66. Stream failure problem

Suppose a stream batch contains:

```text
A → success
B → malformed
C → not processed
D → not processed
```

Without bounded failure handling, record B can block progress until it expires from the 24-hour stream.

Configure:

* Maximum retry attempts.
* Maximum record age.
* Partial batch responses.
* Bisect batch on function error.
* Failure destination.

By default, a failing Lambda stream record can be retried until it expires if no bounded failure settings are applied. ([AWS Documentation][32])

---

# 67. Stream-to-event-bus pattern

Do not dual-write:

```text
Application
├── Write DynamoDB
└── Publish EventBridge event
```

Failure possibility:

```text
Database write succeeds
Event publication fails
```

Better transactional-outbox-style pattern:

```text
Application
    |
    v
Write DynamoDB item
    |
    v
DynamoDB Stream
    |
    v
Lambda
    |
    v
EventBridge
```

The item change becomes the source of event publication.

The publisher must remain idempotent because stream delivery can be retried.

---

# 68. Time to Live

DynamoDB TTL automatically removes expired items based on a per-item Unix epoch timestamp stored as a number.

Example:

```json
{
  "PK": "IDEMPOTENCY#request-104",
  "SK": "RESULT",
  "expiresAt": 1785267902
}
```

TTL deletions typically occur within a few days after expiration and do not consume write throughput in the Region performing the original TTL deletion. TTL is therefore not a precise scheduling mechanism. ([AWS Documentation][33])

---

# 69. TTL use cases

* Expired sessions.
* Idempotency records.
* Temporary locks.
* Event deduplication.
* Short-lived tokens.
* Temporary job state.
* Old telemetry.
* Cached API responses.

Do not use TTL for:

```text
Delete this item exactly at 10:00:00.
```

Use EventBridge Scheduler or an explicit worker when exact timing is required.

---

# 70. Expired items may still appear

An item can remain readable after its TTL timestamp until DynamoDB removes it.

Application logic should check:

```text
expiresAt > currentTime
```

when an expired item must no longer be treated as active.

Filters can suppress expired records, but key-based modeling or application checks may be more reliable for correctness-critical paths. ([AWS Documentation][33])

---

# 71. TTL and Streams

TTL deletions generate DynamoDB Streams records marked as service-initiated deletions.

This can support:

```text
TTL deletion
      |
      v
DynamoDB Stream
      |
      v
Archive expired item to S3
```

([AWS Documentation][34])

Be careful not to recreate the expired item accidentally from the archival consumer.

---

# 72. Point-in-time recovery

Point-in-time recovery provides continuous backups with per-second recovery points.

The recovery period can be configured from:

```text
1 to 35 days
```

([AWS Documentation][35])

Use PITR to protect against:

* Accidental deletion.
* Faulty deployment.
* Mass incorrect update.
* Application corruption.
* Malicious data modification.

---

# 73. PITR restore behavior

A PITR restoration creates:

```text
A new DynamoDB table
```

It does not overwrite the existing table.

After restoration, validate and reconfigure items such as:

* Auto Scaling.
* IAM policies.
* Alarms.
* Tags.
* Streams.
* TTL.
* PITR.
* Deletion protection.

([AWS Documentation][36])

Recovery runbook:

```text
Restore new table
      |
      v
Validate item counts and business data
      |
      v
Apply indexes and operational settings
      |
      v
Switch application configuration
      |
      v
Monitor
```

---

# 74. On-demand backups

On-demand backups create full backup snapshots that remain until deleted according to your backup lifecycle.

Use them for:

* Major releases.
* Compliance retention.
* Migration checkpoints.
* Pre-maintenance backup.
* Long-term recovery points.

AWS Backup can also centrally manage DynamoDB backups across accounts and apply vault, lifecycle and governance policies. ([AWS Documentation][37])

---

# 75. Export to S3

DynamoDB can export a full or incremental table state from the PITR window to S3.

The export:

* Runs asynchronously.
* Does not consume table RCUs.
* Does not affect table availability.
* Supports DynamoDB JSON and Amazon Ion.
* Can export across account or Region boundaries.

([AWS Documentation][38])

Architecture:

```text
DynamoDB PITR state
        |
        v
Export to S3
        |
        ├── Athena
        ├── Glue
        ├── EMR
        └── Data lake
```

This is preferable to repeatedly scanning a large production table for analytics. ([AWS Documentation][39])

---

# 76. Global tables

DynamoDB global tables replicate a table across two or more AWS Regions.

```text
Application users in India
          |
          v
DynamoDB ap-south-1
          |
          | Multi-Region replication
          v
DynamoDB eu-west-1
          |
          v
European application users
```

Each Region exposes its own DynamoDB endpoint; there is no single DynamoDB global endpoint. Application traffic routing must therefore direct requests to the desired Regional application stack. ([AWS Documentation][40])

---

# 77. Global-table consistency modes

DynamoDB global tables support:

```text
MREC:
Multi-Region eventual consistency

MRSC:
Multi-Region strong consistency
```

MREC is the default if no mode is specified. The consistency mode cannot be changed after global-table creation. ([AWS Documentation][41])

---

# 78. MREC global tables

MREC provides:

* Multi-Region active-active reads and writes.
* Asynchronous replication.
* Lower local write latency.
* Eventual cross-Region convergence.
* Last-writer-wins conflict resolution.

Use MREC when:

* Local write latency matters.
* Temporary cross-Region inconsistency is acceptable.
* Applications can handle write conflicts.
* Regional active-active availability is more important than immediate global consistency.

---

# 79. MREC conflict example

Region A:

```text
status = OPEN
timestamp = 10:00:01
```

Region B:

```text
status = COMPLETED
timestamp = 10:00:02
```

Replication resolves the conflict according to last-writer-wins behavior.

This can lose application intent:

```text
A user reopened a todo
while
another user completed it.
```

Prevent or reduce conflicts through:

* Regional write ownership.
* Entity affinity.
* Conditional workflows.
* Conflict-aware data models.
* Append-only events.
* Explicit version semantics.

---

# 80. MRSC global tables

MRSC provides strongly consistent reads across supported global-table Regions and can provide an RPO of zero.

Use MRSC when:

* Every Region must immediately observe consistent state.
* Zero data loss is required for Regional failure.
* Higher write latency is acceptable.
* Supported Region topology and feature restrictions are acceptable.

MRSC has higher write and strongly consistent read latency than MREC and does not support DynamoDB transaction operations. ([AWS Documentation][42])

---

# 81. Current global-table account models

DynamoDB now supports:

```text
Same-account global tables
Multi-account global tables
```

Multi-account global tables can be useful when replica ownership must cross business, security or account boundaries. MRSC currently supports same-account configurations only. ([AWS Documentation][41])

Evaluate carefully:

* KMS ownership.
* IAM permissions.
* Backup responsibility.
* Infrastructure ownership.
* Region failover authority.
* Security monitoring.
* Cost allocation.

---

# 82. Multi-Region application architecture

```text
Route 53 / Global Accelerator
            |
      ┌─────┴─────┐
      |           |
      v           v
ap-south-1     eu-west-1
API stack      API stack
      |           |
      v           v
DynamoDB      DynamoDB
replica       replica
      \           /
       \_________/
       Global table
```

You must plan:

* Health checking.
* Traffic failover.
* Session design.
* DNS or Global Accelerator routing.
* Application deployment in every Region.
* Secret and configuration replication.
* Event-processing ownership.
* Regional dependency failure.
* Conflict behavior.

A global table alone does not create a complete multi-Region application.

---

# 83. Security and encryption

DynamoDB security should include:

* Least-privilege IAM.
* Encryption at rest.
* TLS in transit.
* Customer-managed KMS keys where required.
* VPC endpoints.
* CloudTrail auditing.
* Deletion protection.
* Backup policies.
* Resource tagging.
* Organization guardrails.

Applications should use IAM roles and temporary credentials—not long-lived embedded access keys.

---

# 84. Fine-grained IAM access

DynamoDB supports IAM condition keys such as:

```text
dynamodb:LeadingKeys
dynamodb:Attributes
dynamodb:Select
```

`dynamodb:LeadingKeys` can restrict access to partition-key values belonging to the caller. ([AWS Documentation][43])

Conceptual policy:

```json
{
  "Effect": "Allow",
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:Query",
    "dynamodb:PutItem",
    "dynamodb:UpdateItem"
  ],
  "Resource": "arn:aws:dynamodb:ap-south-1:123456789012:table/TodoApp",
  "Condition": {
    "ForAllValues:StringLike": {
      "dynamodb:LeadingKeys": [
        "USER#${aws:PrincipalTag/UserId}"
      ]
    }
  }
}
```

Application-level authorization is still required when one service role handles requests for many users.

---

# 85. DynamoDB VPC endpoint

DynamoDB supports gateway VPC endpoints.

```text
Private subnet
      |
      v
DynamoDB gateway endpoint
      |
      v
DynamoDB
```

Benefits:

* No NAT gateway needed for DynamoDB traffic.
* Traffic remains on the AWS network.
* Endpoint policies can restrict accessible tables.
* Lower dependency on public egress.

The Lambda, ECS or EC2 execution role still requires DynamoDB IAM permissions.

---

# 86. Terraform production table

```hcl
resource "aws_dynamodb_table" "todoapp" {
  name = "production-todoapp"

  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI2SK"
    type = "S"
  }

  global_secondary_index {
    name = "GSI1"

    hash_key  = "GSI1PK"
    range_key = "GSI1SK"

    projection_type = "ALL"
  }

  global_secondary_index {
    name = "GSI2"

    hash_key  = "GSI2PK"
    range_key = "GSI2SK"

    projection_type = "INCLUDE"

    non_key_attributes = [
      "todoId",
      "title",
      "status",
      "createdAt"
    ]
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  deletion_protection_enabled = true

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

---

# 87. Terraform stream consumer

```hcl
resource "aws_lambda_event_source_mapping" "todo_stream" {
  event_source_arn = aws_dynamodb_table.todoapp.stream_arn
  function_name    = aws_lambda_alias.stream_processor.arn

  starting_position = "LATEST"
  batch_size        = 100

  bisect_batch_on_function_error = true

  maximum_retry_attempts       = 5
  maximum_record_age_in_seconds = 3600

  function_response_types = [
    "ReportBatchItemFailures"
  ]

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.stream_failures.arn
    }
  }

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = [
          "INSERT",
          "MODIFY"
        ]

        dynamodb = {
          NewImage = {
            entityType = {
              S = ["TODO"]
            }
          }
        }
      })
    }
  }
}
```

---

# 88. Terraform throttling alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "write_throttles" {
  alarm_name = "production-todoapp-write-throttles"

  namespace   = "AWS/DynamoDB"
  metric_name = "WriteThrottleEvents"

  statistic = "Sum"
  period    = 60

  evaluation_periods  = 2
  datapoints_to_alarm = 2

  comparison_operator = "GreaterThanThreshold"
  threshold           = 0

  dimensions = {
    TableName = aws_dynamodb_table.todoapp.name
  }

  alarm_actions = [
    aws_sns_topic.operations.arn
  ]

  treat_missing_data = "notBreaching"
}
```

Also create alarms for each important GSI.

---

# 89. AWS CLI operations

Create an item:

```bash
aws dynamodb put-item \
  --table-name production-todoapp \
  --item '{
    "PK": {"S": "USER#104"},
    "SK": {"S": "TODO#2026-07-28T01:00:00Z#501"},
    "entityType": {"S": "TODO"},
    "todoId": {"S": "501"},
    "title": {"S": "Learn DynamoDB"},
    "status": {"S": "OPEN"}
  }' \
  --condition-expression \
    "attribute_not_exists(PK) AND attribute_not_exists(SK)" \
  --region ap-south-1
```

Query user todos:

```bash
aws dynamodb query \
  --table-name production-todoapp \
  --key-condition-expression \
    "PK = :pk AND begins_with(SK, :prefix)" \
  --expression-attribute-values '{
    ":pk": {"S": "USER#104"},
    ":prefix": {"S": "TODO#"}
  }' \
  --scan-index-forward false \
  --region ap-south-1
```

Update status conditionally:

```bash
aws dynamodb update-item \
  --table-name production-todoapp \
  --key '{
    "PK": {"S": "USER#104"},
    "SK": {"S": "TODO#2026-07-28T01:00:00Z#501"}
  }' \
  --update-expression \
    "SET #status = :completed, version = version + :one" \
  --condition-expression \
    "#status = :open AND version = :expectedVersion" \
  --expression-attribute-names '{
    "#status": "status"
  }' \
  --expression-attribute-values '{
    ":completed": {"S": "COMPLETED"},
    ":open": {"S": "OPEN"},
    ":one": {"N": "1"},
    ":expectedVersion": {"N": "7"}
  }' \
  --return-values ALL_NEW \
  --region ap-south-1
```

---

# 90. Monitoring metrics

Important CloudWatch metrics include:

```text
ConsumedReadCapacityUnits
ConsumedWriteCapacityUnits
ProvisionedReadCapacityUnits
ProvisionedWriteCapacityUnits
ReadThrottleEvents
WriteThrottleEvents
ThrottledRequests
SuccessfulRequestLatency
SystemErrors
UserErrors
TransactionConflict
ConditionalCheckFailedRequests
AccountMaxReads
AccountMaxWrites
```

Also monitor throttle-reason metrics that distinguish:

```text
Table capacity exceeded
GSI capacity exceeded
Key-range throughput exceeded
On-demand maximum exceeded
Account quota exceeded
```

DynamoDB now returns detailed throttling reasons to help identify the exact affected resource and limit. ([AWS Documentation][44])

---

# 91. Troubleshooting throttling

First identify:

```text
Which operation?
Read or write?

Which resource?
Table or GSI?

Which limit?
Capacity, hot key, account quota or maximum throughput?
```

Then inspect:

* CloudWatch throttling metrics.
* Exception throttling reason.
* Contributor Insights.
* Partition-key distribution.
* GSI capacity.
* On-demand maximum settings.
* Account quotas.
* Retry behavior.

Do not blindly increase table capacity when one hot partition key is the actual issue.

---

# 92. Retry strategy

For throttled or transient failures:

```text
Exponential backoff
+
Jitter
+
Bounded retries
```

AWS SDKs provide retry support, but application-level configuration must still match the workload.

Bad:

```text
100 clients retry immediately
```

This creates a retry storm.

Better:

```text
Client 1 retries after 100–250 ms
Client 2 retries after 160–400 ms
Client 3 retries after 250–700 ms
```

For asynchronous processing, use SQS to absorb backlog instead of holding thousands of synchronous retry loops.

---

# 93. Contributor Insights

DynamoDB Contributor Insights helps identify the partition keys responsible for the greatest traffic and throttling.

Use it to answer:

```text
Which tenant is consuming most reads?
Which product key is hot?
Which user is responsible for throttles?
```

This is particularly useful when aggregate table metrics look healthy but individual keys experience throttling.

---

# 94. Common DynamoDB mistakes

## Mistake 1: Designing tables before listing access patterns

The resulting table often requires scans.

## Mistake 2: Using status as a base partition key

Low cardinality creates hot keys.

## Mistake 3: Assuming on-demand removes key-design requirements

Hot partitions can still throttle.

## Mistake 4: Filtering large Query results

Filters apply after data has been read.

## Mistake 5: Using Scan in every API request

This becomes slow and expensive as data grows.

## Mistake 6: Creating too many GSIs

Every index increases write and storage cost.

## Mistake 7: Expecting immediate GSI consistency

GSI updates are asynchronous.

## Mistake 8: Ignoring pagination

Only the first `1 MB` is processed.

## Mistake 9: Treating TTL as exact deletion scheduling

Expired items can remain for days.

## Mistake 10: Assuming a global table is a complete DR architecture

The application, secrets, queues and routing also require multi-Region design.

---

# 95. Production readiness checklist

```text
[ ] Every access pattern is documented
[ ] Primary key supports high-cardinality distribution
[ ] Hot-key risks are load tested
[ ] Sort keys support required range queries
[ ] API paths use Query or GetItem
[ ] Production request paths avoid Scan
[ ] Pagination is implemented
[ ] Filters are not used as primary access patterns
[ ] Item size remains below 400 KB
[ ] Large objects are stored in S3
[ ] GSIs support explicit access patterns
[ ] GSI consistency behavior is acceptable
[ ] Sparse indexes are used where beneficial
[ ] GSI write amplification is understood
[ ] Capacity mode is intentionally selected
[ ] Warm throughput is reviewed before major launches
[ ] On-demand maximum throughput is considered
[ ] Adaptive capacity is not treated as a key-design substitute
[ ] Conditional writes protect state changes
[ ] Optimistic locking protects concurrent updates
[ ] Transactions are used only for true atomic boundaries
[ ] Transaction capacity overhead is included
[ ] Streams have bounded retry settings
[ ] Stream consumers are idempotent
[ ] TTL is not used for exact scheduling
[ ] PITR is enabled
[ ] Restore procedure has been tested
[ ] Restored-table settings are documented
[ ] Export to S3 supports analytics
[ ] Deletion protection is enabled
[ ] KMS and IAM permissions are least privilege
[ ] VPC endpoints are configured where appropriate
[ ] Throttling alarms exist for table and GSIs
[ ] Contributor Insights is evaluated
[ ] Global-table conflict behavior is documented
[ ] Multi-Region failover is tested
```

---

# 96. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
DynamoDB:
Serverless managed NoSQL database

Partition key:
Controls item identity and distribution

On-demand:
Automatic throughput management

Global table:
Multi-Region DynamoDB replication
```

## Solutions Architect Associate

Understand:

```text
Simple and composite keys
Query versus Scan
GSI versus LSI
Eventual versus strong consistency
On-demand versus provisioned
DynamoDB Streams
TTL
PITR
Global tables
```

## DevOps Engineer Professional

Understand:

```text
Hot-key mitigation
Write sharding
Adaptive capacity
Warm throughput
On-demand throughput caps
Transactions
Conditional writes
Optimistic locking
Stream retry handling
Terraform deployments
Multi-Region consistency modes
Restore automation
```

---

# 97. Interview questions

## Question 1: What is DynamoDB?

**Answer:**

DynamoDB is a serverless, fully managed, distributed NoSQL key-value and document database designed for predictable performance at scale.

## Question 2: What is a partition key?

**Answer:**

It is the primary-key attribute DynamoDB hashes to determine data placement and logical query grouping.

## Question 3: What is a sort key?

**Answer:**

It is the second part of a composite primary key and orders related items sharing one partition-key value.

## Question 4: What is a hot partition?

**Answer:**

It is an underlying partition receiving more traffic than it can serve, commonly because the workload is concentrated on too few partition-key values.

## Question 5: What is the difference between Query and Scan?

**Answer:**

Query reads items using one partition-key value and an optional sort-key condition. Scan reads every item or index entry before applying filters.

## Question 6: Does a FilterExpression reduce read capacity?

**Answer:**

No. DynamoDB reads the candidate items first and then discards those that do not match.

## Question 7: What is a GSI?

**Answer:**

A Global Secondary Index provides an alternate partition and optional sort key for querying the base-table data.

## Question 8: Can GSI reads be strongly consistent?

**Answer:**

No. GSI reads are eventually consistent.

## Question 9: What is an LSI?

**Answer:**

A Local Secondary Index uses the same partition key as the base table but a different sort key and must be created with the table.

## Question 10: What is on-demand capacity?

**Answer:**

It is a capacity mode in which DynamoDB automatically manages throughput and charges according to request consumption.

## Question 11: What is warm throughput?

**Answer:**

It represents the amount of read and write traffic a DynamoDB table or GSI can support immediately based on its scaling history or proactive pre-warming.

## Question 12: What is adaptive capacity?

**Answer:**

It automatically shifts available capacity toward more heavily used partitions when possible.

## Question 13: What is a conditional write?

**Answer:**

It performs a write only when a server-side condition is true, preventing race conditions and accidental overwrites.

## Question 14: What is optimistic locking?

**Answer:**

It uses a version value and conditional update so an operation fails when another process has changed the item since it was read.

## Question 15: How many items can one DynamoDB transaction target?

**Answer:**

Up to 100 distinct items, with a combined transaction item size of up to 4 MB.

## Question 16: What is DynamoDB Streams?

**Answer:**

It is a 24-hour change-data-capture stream containing item-level insert, modify and remove events.

## Question 17: Is a Lambda stream consumer exactly once?

**Answer:**

No. Stream consumers should be idempotent because processing can be retried.

## Question 18: Is TTL immediate?

**Answer:**

No. Expired items are normally deleted within a few days, so applications may need to ignore expired items before physical deletion.

## Question 19: What does PITR do?

**Answer:**

It provides continuous per-second recovery points for a configurable period of up to 35 days and restores data into a new table.

## Question 20: What are MREC and MRSC?

**Answer:**

MREC provides multi-Region eventual consistency with lower local write latency. MRSC provides strong consistency across supported Regions and zero RPO, with higher latency and additional feature restrictions.

---

# 98. Never-forget revision

```text
Partition key:
Distributes and groups data.

Sort key:
Orders related data.

Query:
Efficient key-based retrieval.

Scan:
Reads everything.

GSI:
Alternate key structure.

LSI:
Alternate sort key with same partition key.

Eventual consistency:
May briefly return stale data.

Strong consistency:
Returns latest successful Regional write.

Conditional write:
Write only if a condition is true.

Optimistic locking:
Version-based concurrent-update protection.

Transaction:
All-or-nothing operation across items.

Stream:
24-hour item-change log.

TTL:
Eventually removes expired items.

PITR:
Continuous recoverability.

On-demand:
Automatic request-based capacity.

Provisioned:
Configured RCUs and WCUs.

Warm throughput:
Instantly available scaling level.

Adaptive capacity:
Automatically helps uneven partitions.

Global table:
Multi-Region DynamoDB table.

MREC:
Multi-Region eventual consistency.

MRSC:
Multi-Region strong consistency.
```

## One-line memory trick

```text
Design the questions first.
Distribute the partition keys.
Sort related data.
Query instead of Scan.
Expect retries.
Protect writes with conditions.
Back up continuously.
Test every Region.
```

## Lesson 43 outcome

You can now design a DynamoDB architecture where:

```text
A user requests their todos
    → One Query retrieves the item collection.

A todo must be found globally
    → A GSI provides an alternate key.

A popular key receives extreme traffic
    → Sharding distributes the workload.

Two clients update the same todo
    → Optimistic locking prevents lost updates.

Several records must change atomically
    → A transaction provides all-or-nothing behavior.

A todo changes status
    → DynamoDB Streams triggers downstream processing.

Temporary idempotency records expire
    → TTL removes them automatically.

A bad deployment corrupts data
    → PITR restores a clean table.

Global users require Regional resilience
    → MREC or MRSC global tables support the chosen consistency model.
```

**Next lesson: Lesson 44 — Amazon ECS and AWS Fargate production architecture: task definitions, services, clusters, capacity providers, networking, autoscaling, deployments, health checks, secrets and observability.**

[1]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html?utm_source=chatgpt.com "What is Amazon DynamoDB? - Amazon DynamoDB"
[2]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/migration-guide.html?utm_source=chatgpt.com "Migrating to DynamoDB from a relational database - Amazon DynamoDB"
[3]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html?utm_source=chatgpt.com "Core components of Amazon DynamoDB"
[4]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.Partitions.html?utm_source=chatgpt.com "Partitions and data distribution in DynamoDB"
[5]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html?utm_source=chatgpt.com "Best practices for designing and using partition keys ..."
[6]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/throttling-key-range-limit-exceeded-mitigation.html?utm_source=chatgpt.com "1- Key range throughput exceeded (hot partitions)"
[7]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-sharding.html?utm_source=chatgpt.com "Using write sharding to distribute workloads evenly in your ..."
[8]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-sort-keys.html?utm_source=chatgpt.com "Best practices for using sort keys to organize data in ..."
[9]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.KeyConditionExpressions.html?utm_source=chatgpt.com "Key condition expressions for the Query operation in ..."
[10]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Scan.html?utm_source=chatgpt.com "Scanning tables in DynamoDB"
[11]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.FilterExpression.html?utm_source=chatgpt.com "Filter expressions for the Query operation in DynamoDB"
[12]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.ProjectionExpressions.html?utm_source=chatgpt.com "Using projection expressions in DynamoDB"
[13]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/data-modeling-foundations.html?utm_source=chatgpt.com "Data Modeling foundations in DynamoDB"
[14]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html "Using Global Secondary Indexes in DynamoDB - Amazon DynamoDB"
[15]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-indexes-general-sparse-indexes.html?utm_source=chatgpt.com "Take advantage of sparse indexes - Amazon DynamoDB"
[16]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LSI.html "Local secondary indexes - Amazon DynamoDB"
[17]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-indexes-general.html?utm_source=chatgpt.com "General guidelines for secondary indexes in DynamoDB"
[18]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/read-write-operations.html?utm_source=chatgpt.com "DynamoDB read and write operations"
[19]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/capacity-mode.html?utm_source=chatgpt.com "DynamoDB throughput capacity"
[20]: https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/capacity.html?utm_source=chatgpt.com "DynamoDB on-demand and provisioned capacity"
[21]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/warm-throughput.html "Understanding DynamoDB warm throughput - Amazon DynamoDB"
[22]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode-max-throughput.html "DynamoDB maximum throughput for on-demand tables - Amazon DynamoDB"
[23]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.html?utm_source=chatgpt.com "Managing throughput capacity automatically with ..."
[24]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/burst-adaptive-capacity.html?utm_source=chatgpt.com "DynamoDB burst and adaptive capacity"
[25]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.OperatorsAndFunctions.html?utm_source=chatgpt.com "Condition and filter expressions, operators, and functions in DynamoDB - Amazon DynamoDB"
[26]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices_OptimisticLocking.html?utm_source=chatgpt.com "Optimistic locking with version number - Amazon DynamoDB"
[27]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html "Amazon DynamoDB Transactions: How it works - Amazon DynamoDB"
[28]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html?utm_source=chatgpt.com "Change data capture for DynamoDB Streams - Amazon DynamoDB"
[29]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.Lambda.html?utm_source=chatgpt.com "DynamoDB Streams and AWS Lambda triggers - Amazon DynamoDB"
[30]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html "Change data capture for DynamoDB Streams - Amazon DynamoDB"
[31]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.Lambda.BestPracticesWithDynamoDB.html?utm_source=chatgpt.com "Best practices using DynamoDB Streams with Lambda - Amazon DynamoDB"
[32]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CostOptimization_StreamsUsage.html?utm_source=chatgpt.com "Evaluate your DynamoDB streams usage - Amazon DynamoDB"
[33]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html?utm_source=chatgpt.com "Using time to live (TTL) in DynamoDB"
[34]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/time-to-live-ttl-streams.html?utm_source=chatgpt.com "DynamoDB Streams and Time to Live"
[35]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery_Howitworks.html?utm_source=chatgpt.com "Enable point-in-time recovery in DynamoDB"
[36]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.Tutorial.html?utm_source=chatgpt.com "Restoring a DynamoDB table to a point in time"
[37]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Backup-and-Restore.html?utm_source=chatgpt.com "Backup and restore for DynamoDB"
[38]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/S3DataExport.HowItWorks.html?utm_source=chatgpt.com "DynamoDB data export to Amazon S3: how it works"
[39]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CostOptimization_TableUsagePatterns.html?utm_source=chatgpt.com "Evaluate your DynamoDB table usage patterns"
[40]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-global-table-design.html?utm_source=chatgpt.com "Using DynamoDB global tables"
[41]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html "Global tables - multi-active, multi-Region replication - Amazon DynamoDB"
[42]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[43]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/specifying-conditions.html?utm_source=chatgpt.com "Using IAM policy conditions for fine-grained access control - Amazon DynamoDB"
[44]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TroubleshootingThrottling.html?utm_source=chatgpt.com "Troubleshooting throttling in Amazon DynamoDB"
