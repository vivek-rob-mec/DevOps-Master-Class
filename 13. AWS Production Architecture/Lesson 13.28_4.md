# AWS Masterclass — Lesson 28 Part 4

# Amazon DynamoDB — NoSQL Architecture from First Principles

We have spent the last three parts thinking relationally:

```text
RDS / Aurora

Tables
  ↓
Rows
  ↓
Relationships
  ↓
JOINs
  ↓
Transactions
  ↓
Indexes
  ↓
SQL
```

DynamoDB requires a very different mindset.

The central question changes from:

> **“What tables represent my business entities?”**

to:

> **“What exact access patterns must my application perform at scale?”**

Amazon DynamoDB is a serverless, fully managed, distributed NoSQL database designed for single-digit millisecond performance at scale. It deliberately omits relational features such as server-side joins that don't fit its distributed scaling model. ([AWS Documentation][1])

---

# 1. The DynamoDB Mental Shift

Relational design often looks like:

```text
Understand entities
      │
      ▼
Normalize schema
      │
      ▼
Create tables
      │
      ▼
Create indexes
      │
      ▼
Application queries flexibly
```

DynamoDB design should look more like:

```text
Understand APPLICATION ACCESS PATTERNS
                    │
                    ▼
         Design partition keys
                    │
                    ▼
            Design sort keys
                    │
                    ▼
          Add indexes if needed
                    │
                    ▼
              Store items
```

This sentence should stay with you:

```text
DynamoDB

ACCESS PATTERNS FIRST
SCHEMA SECOND
```

---

# 2. When DynamoDB Fits

DynamoDB is excellent when you need combinations of:

```text
very high scale
predictable access patterns
low latency
serverless infrastructure
automatic partitioning
key-value access
document-style data
event-driven workloads
multi-Region active-active
```

Examples:

```text
shopping carts
user sessions
gaming state
device state
metadata
high-scale APIs
IoT
leaderboards
event state
order status
user preferences
```

DynamoDB is not merely:

```text
"RDS without SQL"
```

It is a different database architecture.

---

# 3. Basic DynamoDB Hierarchy

The important objects are:

```text
DynamoDB
   │
   ▼
TABLE
   │
   ▼
ITEM
   │
   ▼
ATTRIBUTES
```

Example table:

```text
Todos
```

An item:

```json
{
  "userId": "USER#1001",
  "todoId": "TODO#2026-08-14T00:30:00Z#abc123",
  "title": "Learn DynamoDB",
  "completed": false,
  "priority": "HIGH"
}
```

Think:

```text
SQL                DynamoDB

table              table

row                item

column             attribute
```

But DynamoDB items do **not** all need identical non-key attributes. DynamoDB tables are schemaless apart from the primary-key requirements. ([AWS Documentation][2])

---

# 4. Item Size Limit

One DynamoDB item can currently be at most:

# **400 KB**

including attribute names and values. ([AWS Documentation][3])

Therefore this is a bad idea:

```text
DynamoDB item

{
    userId,
    name,
    2-GB-video-file
}
```

Instead:

```text
                 DynamoDB
                    │
              metadata/key
                    │
                    ▼
              S3 object URI
                    │
                    ▼
                    S3
               large payload
```

For example:

```json
{
  "PK": "VIDEO#123",
  "title": "training.mp4",
  "s3Key": "videos/123/training.mp4"
}
```

AWS explicitly recommends S3 as one strategy when data exceeds DynamoDB's 400-KB item limit. ([AWS Documentation][3])

---

# 5. Primary Key

Every DynamoDB item is identified using its primary key.

There are two possible designs:

```text
Simple primary key

Partition Key
```

or:

```text
Composite primary key

Partition Key
+
Sort Key
```

These two attributes are the heart of DynamoDB.

---

# 6. Partition Key

Suppose:

```text
PK = USER#1001
```

DynamoDB takes that value and runs it through an internal hash function.

Conceptually:

```text
USER#1001
    │
    ▼
hash()
    │
    ▼
physical DynamoDB partition
```

AWS uses the partition-key value to determine the physical partition where the data belongs. ([AWS Documentation][4])

### Never forget

```text
Partition Key
=
WHERE data is distributed
```

This is why key design is both:

```text
DATA MODELING
```

and:

```text
PERFORMANCE ENGINEERING
```

---

# 7. Sort Key

Suppose our table uses:

```text
PK = userId

SK = todoId
```

Example:

```text
PK             SK
─────────────────────────────────────────────

USER#1001      TODO#2026-08-01#001

USER#1001      TODO#2026-08-08#002

USER#1001      TODO#2026-08-14#003

USER#2002      TODO#2026-08-11#004
```

Items sharing the same partition-key value are stored together logically and ordered by the sort-key value. ([AWS Documentation][4])

Thus:

```text
USER#1001
   │
   ├── TODO#2026-08-01#001
   ├── TODO#2026-08-08#002
   └── TODO#2026-08-14#003
```

becomes an extremely efficient access pattern.

---

# 8. Composite Key Uniqueness

With:

```text
PK
+
SK
```

the **combination** must be unique.

So this is allowed:

```text
PK            SK

USER#1001     TODO#001
USER#1001     TODO#002
USER#1001     TODO#003
```

But not two items with exactly:

```text
USER#1001
TODO#001
```

because that composite primary key already identifies an item.

---

# 9. Why Sort Keys Are So Powerful

Suppose we design:

```text
PK = USER#1001

SK =
TODO#2026-08-14T00:30:00Z#abc123
```

Now we can efficiently ask:

```text
Give me all todos for user 1001
```

or:

```text
Give me todos between
2026-08-01
and
2026-08-14
```

or:

```text
Give me items whose SK begins with TODO#
```

A DynamoDB `Query` requires an exact partition-key value and can optionally apply sort-key conditions to narrow the result. ([AWS Documentation][5])

---

# 10. Query — The Operation You Want

Suppose:

```text
PK = USER#1001
```

Use:

```text
Query
```

DynamoDB can directly find the partition-key value:

```text
USER#1001
    │
    ▼
its items
```

rather than examining every item in the table.

AWS requires the partition-key equality value for a Query and optionally allows comparisons against the sort key. ([AWS Documentation][5])

---

# 11. Query Example

AWS CLI:

```bash
aws dynamodb query \
  --table-name Todos \
  --key-condition-expression \
    "PK = :pk AND begins_with(SK, :prefix)" \
  --expression-attribute-values '{
    ":pk": {"S": "USER#1001"},
    ":prefix": {"S": "TODO#"}
  }' \
  --region ap-south-1
```

Conceptually:

```text
Find partition:
USER#1001

then:

keep sorted items beginning with:
TODO#
```

This is a DynamoDB-friendly access pattern.

---

# 12. Scan — The Operation to Be Suspicious Of

A Scan says approximately:

```text
Read items across the table
```

then optionally:

```text
filter them
```

Architecture:

```text
TABLE

Item
Item
Item
Item
Item
Item
Item
Item
Item
 │
 ▼
read them
 │
 ▼
apply filter
 │
 ▼
return matching items
```

A Scan reads table/index pages and can consume significant read capacity on large datasets. AWS recommends Query over Scan whenever the access pattern permits it. ([AWS Documentation][6])

---

# 13. The Filter Expression Trap

Imagine:

```text
Table:
100 million items
```

You run:

```text
Scan
WHERE status = "FAILED"
```

and only:

```text
100 items
```

match.

Beginner thought:

```text
I returned only 100 records,
so this was cheap.
```

Wrong.

The filter is applied **after DynamoDB reads the data**.

Both Query and Scan process up to **1 MB per request before filter expressions are applied**. ([AWS Documentation][7])

### Never forget

```text
FilterExpression
reduces returned data

NOT
the data DynamoDB had to read first.
```

That distinction is extremely important for cost and performance.

---

# 14. Query vs Scan

| Query                         | Scan                                |
| ----------------------------- | ----------------------------------- |
| Requires partition-key value  | Walks table/index data              |
| Highly targeted               | Broad                               |
| Can use sort-key conditions   | Filter happens after reading        |
| Preferred application pattern | Often admin/analytics-style pattern |
| Predictable scaling           | Can consume large read capacity     |

The rule:

```text
APPLICATION PATH
      │
      ▼
TRY TO DESIGN FOR Query
```

not:

```text
We'll design whatever schema we like
and Scan our way out later.
```

---

# 15. Access Pattern First Example

Requirements for our Todo application:

```text
1. Get one Todo by ID

2. Get all Todos for a user

3. Get user Todos ordered by creation time

4. Get only incomplete Todos

5. Get all HIGH-priority incomplete Todos
```

We should write those requirements down **before creating the table**.

That is DynamoDB modeling.

---

# 16. Possible Todo Key Design

One approach:

```text
PK = USER#<user-id>

SK = TODO#<timestamp>#<todo-id>
```

Example:

```text
PK             SK
────────────────────────────────────────────

USER#1001      TODO#2026-08-14T00:01#abc

USER#1001      TODO#2026-08-14T00:10#def

USER#1001      TODO#2026-08-14T00:20#ghi
```

Now:

```text
All Todos for user
```

becomes:

```text
Query PK = USER#1001
```

with no table scan.

---

# 17. Hierarchical Sort Keys

Sort keys can encode hierarchy.

For example:

```text
ORG#acme
TEAM#platform
USER#123
TODO#2026-08-14#abc
```

or more commonly as a path-like sortable value:

```text
TODO#2026#08#14#abc
```

This lets operations such as:

```text
begins_with(SK, "TODO#2026#08")
```

retrieve a meaningful subset.

Sort-key design is one of the most important DynamoDB skills.

---

# 18. Hot Partition Problem

Now imagine a table:

```text
PK = status
```

Values:

```text
PENDING
COMPLETE
FAILED
```

Suppose:

```text
90% of new requests
=
PENDING
```

Then huge traffic concentrates on:

```text
PK = PENDING
```

Conceptually:

```text
100,000 requests
     │
     ▼
 PENDING
     │
     ▼
same hot partition area
```

This is bad partition-key cardinality.

DynamoDB adaptive capacity helps redistribute capacity toward hot partitions, but individual partitions still have maximum throughput characteristics; AWS documents up to **3,000 read capacity units and 1,000 write capacity units per second per partition**. ([AWS Documentation][8])

---

# 19. Good Partition Keys

Generally aim for keys with:

```text
high cardinality
```

and:

```text
traffic distributed reasonably evenly
```

Examples:

```text
USER#123456
ORDER#984921
DEVICE#f82ab9
SESSION#uuid
CUSTOMER#uuid
```

Riskier:

```text
ACTIVE
FAILED
2026
INDIA
FREE
```

if enormous portions of traffic hit one value.

---

# 20. Write Sharding

Sometimes the natural access pattern itself is extremely hot.

Imagine:

```text
all events for:
TENANT#MEGA-CUSTOMER
```

You can add a shard suffix:

```text
TENANT#123#0
TENANT#123#1
TENANT#123#2
...
TENANT#123#9
```

Writes distribute:

```text
events
  │
  ├── shard 0
  ├── shard 1
  ├── shard 2
  └── ...
```

Reads then query the shards and merge results in the application.

Tradeoff:

```text
better distribution
        │
        ▼
more complex reads
```

Partition design is always about the application's access patterns.

---

# 21. DynamoDB Capacity Modes

DynamoDB currently supports:

```text
ON-DEMAND
```

and:

```text
PROVISIONED
```

capacity modes.

AWS now describes **on-demand as the default and recommended throughput option for most DynamoDB workloads**. ([AWS Documentation][9])

This is an important modern point—older training material often begins by making you manually calculate provisioned RCUs/WCUs for every table.

You still need to understand that math.

---

# 22. On-Demand Mode

Mental model:

```text
Application traffic

10 req/s
 ↓
500
 ↓
10,000
 ↓
100,000

DynamoDB
manages throughput
```

You pay according to request usage rather than configuring fixed RCUs/WCUs.

On-demand works particularly well for:

```text
unknown traffic
bursty traffic
new applications
serverless systems
unpredictable workloads
```

([AWS Documentation][9])

---

# 23. On-Demand Is Not Infinite Instant Scaling

Important nuance.

DynamoDB can immediately accommodate traffic up to its established **warm throughput**. AWS currently documents that a new on-demand table starts with warm throughput of approximately:

```text
12,000 read units/sec

4,000 write units/sec
```

and that warm throughput grows based on table history. ([AWS Documentation][10])

If a workload suddenly goes beyond **twice its previous peak within roughly 30 minutes**, throttling can occur while DynamoDB adapts. ([AWS Documentation][11])

So:

```text
On-demand
≠
physics no longer exists
```

For massive launches, capacity planning and pre-warming concepts still matter.

---

# 24. Maximum On-Demand Throughput Guardrail

A useful newer capability lets you set maximum throughput targets for an on-demand table or individual GSI.

Example:

```text
Don't let buggy application code
drive unlimited DynamoDB usage/cost.
```

Configure a maximum:

```text
Read throughput max
Write throughput max
```

Requests above that target can be throttled, although AWS notes burst capacity may temporarily allow some requests beyond the configured maximum. ([AWS Documentation][12])

This is useful for:

```text
FinOps
runaway workload protection
protecting downstream consumers
```

---

# 25. Provisioned Mode

Here you tell DynamoDB approximately:

```text
I need:

X read capacity
Y write capacity
```

Conceptually:

```text
RCU = 1000

WCU = 500
```

DynamoDB Auto Scaling can adjust provisioned capacity around target utilization. ([AWS Documentation][13])

Provisioned can be attractive for:

```text
stable predictable workloads
well-understood baseline traffic
cost optimization
reserved capacity strategies
```

---

# 26. RCU — Read Capacity Unit

In provisioned mode, one RCU represents:

```text
1 strongly consistent read/sec
```

for an item up to:

```text
4 KB
```

or:

```text
2 eventually consistent reads/sec
```

for items up to 4 KB. ([AWS Documentation][8])

Example:

```text
4-KB item

100 strongly consistent reads/sec

≈ 100 RCU
```

While:

```text
100 eventually consistent reads/sec

≈ 50 RCU
```

at the basic capacity-unit level.

---

# 27. WCU — Write Capacity Unit

One WCU represents:

```text
1 write/sec
```

for an item up to:

```text
1 KB
```

([AWS Documentation][8])

Therefore:

```text
1-KB item
500 writes/sec
≈ 500 WCU
```

A:

```text
3-KB item
```

requires:

```text
3 WCU per write
```

because capacity rounds according to the write-size unit.

### Never forget the base sizes

```text
READ
=
4 KB
```

```text
WRITE
=
1 KB
```

---

# 28. Eventually Consistent vs Strongly Consistent Reads

Normal DynamoDB table reads default to:

```text
eventually consistent
```

You can request:

```text
ConsistentRead=true
```

for strongly consistent reads on the base table and LSIs.

GSIs support only eventually consistent reads. ([AWS Documentation][14])

Mental model:

```text
Table / LSI
   │
   ├── eventual
   └── strong


GSI
   │
   └── eventual only
```

This becomes important for read-after-write application design.

---

# 29. Secondary Indexes

Eventually your primary-key design doesn't satisfy every access pattern.

Suppose base table:

```text
PK = USER#1001
SK = TODO#...
```

Great for:

```text
Give me Todo items for user 1001.
```

But management asks:

> Give me every Todo assigned to project `PROJECT#777`.

Your current PK doesn't provide that access pattern.

This is why DynamoDB provides:

```text
GSI
LSI
```

---

# 30. Global Secondary Index — GSI

A GSI can define a different:

```text
partition key
```

and optional:

```text
sort key
```

from the base table. ([AWS Documentation][15])

Example:

Base table:

```text
PK = USER#1001

SK = TODO#abc
```

GSI:

```text
GSI1PK = STATUS#INCOMPLETE

GSI1SK = PRIORITY#HIGH#2026-08-14#abc
```

Now you can:

```text
Query GSI1PK = STATUS#INCOMPLETE
```

assuming that partition-key design is sufficiently distributed for your workload.

---

# 31. GSI Is an Alternate Access Pattern

Think:

```text
                    SAME ITEM

Base Table
────────────────────────────
PK  = USER#1001
SK  = TODO#abc


GSI1
────────────────────────────
PK  = PROJECT#777
SK  = CREATED#2026-08-14


GSI2
────────────────────────────
PK  = ASSIGNEE#2002
SK  = STATUS#OPEN#...
```

The underlying business object hasn't changed.

You're providing additional efficient ways to find it.

---

# 32. GSI Facts to Remember

Current default quota:

```text
20 GSIs per table
```

GSIs:

```text
can have different PK/SK
can be added to an existing table
have separate provisioned throughput when using provisioned mode
only support eventually consistent reads
```

([AWS Documentation][16])

Don't create:

```text
20 indexes
"just in case"
```

Each index has:

```text
storage cost
write amplification
capacity implications
operational complexity
```

Design indexes for known access patterns.

---

# 33. Local Secondary Index — LSI

An LSI uses:

```text
SAME partition key
```

as the base table but:

```text
DIFFERENT sort key
```

Example:

Base:

```text
PK = FORUM#AWS
SK = SUBJECT#S3
```

LSI:

```text
PK = FORUM#AWS
SK = LAST_POST#2026-08-14
```

AWS describes LSIs as alternate sort-key views for the same partition-key value. ([AWS Documentation][17])

---

# 34. LSI Important Limitations

You can have at most:

```text
5 LSIs
```

per table. ([AWS Documentation][18])

An LSI must be created:

```text
WHEN THE TABLE IS CREATED
```

—you can't add it later.

And tables with LSIs have a:

```text
10 GB
```

maximum item-collection size for each distinct partition-key value. ([AWS Documentation][17])

That's a big reason GSIs are used more often.

---

# 35. GSI vs LSI

| GSI                                           | LSI                                     |
| --------------------------------------------- | --------------------------------------- |
| Different partition key possible              | Same partition key                      |
| Different sort key possible                   | Different sort key                      |
| Add later                                     | Must create with table                  |
| Up to 20 default                              | Up to 5                                 |
| Eventual reads only                           | Strong reads supported                  |
| Separate provisioned throughput               | Shares base-table throughput            |
| No 10-GB item-collection restriction like LSI | 10 GB per partition-key item collection |

([AWS Documentation][18])

Shortcut:

```text
GSI
=
new access dimension
```

```text
LSI
=
same partition
new sorting dimension
```

---

# 36. Conditional Writes

Suppose two application instances simultaneously update:

```text
inventory = 1
```

Both read:

```text
1 available
```

Both try to purchase.

Without protection:

```text
Customer A succeeds

Customer B succeeds

Inventory becomes invalid
```

DynamoDB supports conditional writes so an update happens only if the expected condition is true. ([AWS Documentation][19])

Example:

```bash
aws dynamodb update-item \
  --table-name Inventory \
  --key '{"PK":{"S":"PRODUCT#123"}}' \
  --update-expression \
    "SET quantity = quantity - :one" \
  --condition-expression \
    "quantity >= :one" \
  --expression-attribute-values '{
    ":one":{"N":"1"}
  }'
```

When quantity reaches zero:

```text
condition fails
```

instead of creating negative stock.

---

# 37. Optimistic Locking

Another common pattern:

```json
{
  "PK": "ORDER#123",
  "status": "PENDING",
  "version": 7
}
```

Application reads:

```text
version = 7
```

Then update condition:

```text
version must still equal 7
```

and write:

```text
version = 8
```

If somebody else changed the record first:

```text
version = 8
```

your update fails rather than silently overwriting their update.

This is:

# optimistic concurrency control

implemented using conditional expressions.

---

# 38. DynamoDB Transactions

DynamoDB isn't relational, but it does provide ACID transaction APIs for cases where multiple items must change together.

`TransactWriteItems` supports up to:

```text
100 write actions
```

against distinct items, with an aggregate limit of:

```text
4 MB
```

and the transaction is all-or-nothing within the same AWS account and Region. ([AWS Documentation][20])

Example:

```text
Transaction

1. Decrease product stock

2. Create order

3. Update user order counter

4. Reserve coupon

ALL succeed

OR

NONE succeed
```

---

# 39. Transactions Cost More

Transactional operations require additional underlying work.

AWS documents a transactional write as consuming two underlying write operations per item—prepare and commit. ([AWS Documentation][21])

Therefore don't build:

```text
every single DynamoDB write
=
giant transaction
```

unless correctness requires it.

Use simpler atomic/conditional operations when they solve the business rule.

---

# 40. TTL — Time To Live

Suppose session:

```json
{
  "PK": "SESSION#abc",
  "userId": "1001",
  "expiresAt": 1786658400
}
```

You can configure:

```text
TTL attribute:
expiresAt
```

DynamoDB eventually deletes the item automatically after that Unix epoch timestamp. TTL deletions don't consume write throughput in the Region where the expiration occurs. ([AWS Documentation][22])

Excellent uses:

```text
sessions
temporary tokens
ephemeral cache records
temporary workflow state
old telemetry
```

---

# 41. TTL Is NOT an Exact Scheduler

This is critical.

If:

```text
expiresAt =
12:00:00
```

don't expect:

```text
12:00:00.001
item definitely gone.
```

TTL deletion is asynchronous. AWS says expired records are typically deleted within a few days, and some guidance explicitly warns that removal can take over 48 hours. ([AWS Documentation][22])

Therefore:

```text
TTL
≠
distributed cron job
```

For authorization tokens, leases, or locks:

```text
Application should check
expiresAt
```

rather than assuming physical deletion already happened.

---

# 42. DynamoDB Streams

DynamoDB Streams provide change-data-capture records when items change.

Architecture:

```text
DynamoDB Table
     │
     ├── INSERT
     ├── MODIFY
     └── REMOVE
           │
           ▼
     DynamoDB Stream
           │
           ▼
        Lambda
           │
           ▼
     downstream work
```

DynamoDB Streams retain stream records for approximately **24 hours**. ([AWS Documentation][23])

---

# 43. Stream Use Cases

Examples:

```text
Order changed
      │
      ▼
Stream
      │
      ▼
Lambda
      │
      └── send notification
```

```text
User record changed
      │
      ▼
Stream
      │
      ▼
update search index
```

```text
Todo completed
      │
      ▼
Stream
      │
      ▼
publish analytics event
```

AWS integrates DynamoDB Streams directly with Lambda triggers. ([AWS Documentation][24])

---

# 44. Streams vs Kinesis Change Capture

If:

```text
24 hours
```

of CDC retention is enough:

```text
DynamoDB Streams
```

can work very well.

If you need:

```text
longer retention
more consumers
Kinesis ecosystem
```

DynamoDB can also capture changes into Kinesis Data Streams, where retention can be extended up to one year. ([AWS Documentation][25])

---

# 45. TTL + Streams

Interesting combination:

```text
Item expires
    │
    ▼
DynamoDB TTL
    │
    ▼
REMOVE event
    │
    ▼
DynamoDB Stream
    │
    ▼
Lambda
```

AWS specifically supports processing TTL deletions through DynamoDB Streams. ([AWS Documentation][26])

Possible use:

```text
archive expired data
to S3
before forgetting it operationally
```

---

# 46. DynamoDB Global Tables

Now imagine:

```text
Users:
India
Europe
United States
```

Single-region:

```text
All users
   │
   ▼
ap-south-1 DynamoDB
```

Global Tables allow DynamoDB replicas across multiple AWS Regions and support multi-Region, multi-active access. ([AWS Documentation][27])

Architecture:

```text
                GLOBAL APPLICATION

       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
   Mumbai         Ireland       Virginia
      │              │              │
 DynamoDB        DynamoDB        DynamoDB
 Replica         Replica         Replica
      └──────── replication ────────┘
```

Applications can operate against a local Regional replica rather than sending every request across the globe.

---

# 47. Major 2026 Update — Two Global Table Consistency Modes

Older courses usually teach Global Tables as only:

```text
eventually consistent
last-writer-wins
```

Current DynamoDB Global Tables support two consistency modes:

```text
MREC
=
Multi-Region Eventual Consistency
```

and:

```text
MRSC
=
Multi-Region Strong Consistency
```

MRSC was introduced in 2025. MREC remains the default if no consistency mode is specified. ([AWS Documentation][27])

This is a major modernization of DynamoDB.

---

# 48. MREC — Multi-Region Eventual Consistency

MREC is the traditional Global Tables model.

```text
Write Mumbai
    │
    ▼
Mumbai committed
    │
    ├────────▶ Ireland
    └────────▶ Virginia
       asynchronous
```

Cross-Region replication is typically very fast but eventually consistent. If concurrent writes conflict, the traditional Global Tables model uses conflict-resolution behavior such as last-writer-wins. ([AWS Documentation][27])

Use cases include:

```text
global active-active apps
local low latency
eventual cross-region consistency acceptable
```

---

# 49. MRSC — Multi-Region Strong Consistency

With MRSC:

```text
write Region A
      │
      ▼
synchronous multi-Region coordination
      │
      ▼
successful write
```

A strongly consistent read against any MRSC replica can return the latest successfully written item version. ([AWS Documentation][28])

AWS currently requires MRSC deployments to use exactly **three Regions**, arranged as either:

```text
3 replicas
```

or:

```text
2 replicas
+
1 witness
```

and documents a zero-RPO architecture for this consistency mode. ([AWS Documentation][29])

That's a major capability.

---

# 50. MRSC Has Important Restrictions

Current MRSC Global Tables do **not** support:

```text
DynamoDB transactions
TTL
```

and have other configuration restrictions compared with MREC. ([AWS Documentation][30])

This is a perfect architecture lesson:

```text
stronger consistency
      │
      ▼
additional coordination
      │
      ▼
different feature/tradeoff set
```

There is no free distributed-system lunch.

---

# 51. Global Tables Are Now Also Multi-Account Capable

Another current development: DynamoDB now documents both:

```text
same-account Global Tables
```

and:

```text
multi-account Global Tables
```

for supported global-table models, while MRSC currently requires same-account configuration. ([AWS Documentation][27])

This is especially useful for architectures with stronger organizational or security boundaries.

---

# 52. Global Tables vs Aurora Global Database

This distinction is excellent for interviews.

### Aurora Global Database

```text
Primary writer Region
        │
        ▼
secondary Regions
```

Normal architecture is primarily:

```text
single write Region
+
global readers/DR
```

### DynamoDB Global Tables MREC

```text
Region A
READ + WRITE

Region B
READ + WRITE

Region C
READ + WRITE
```

This is genuine multi-active data access.

### DynamoDB MRSC

adds:

```text
multi-Region
strongly consistent reads/writes
```

under its specific topology and feature restrictions.

---

# 53. DAX — DynamoDB Accelerator

Normal DynamoDB:

```text
single-digit millisecond
```

responses are already very fast.

But some workloads require:

```text
microseconds
```

DAX is a managed in-memory cache built specifically for DynamoDB and can reduce suitable eventually consistent read latency from milliseconds to microseconds. ([AWS Documentation][31])

Architecture:

```text
Application
    │
    ▼
   DAX
    │
 cache hit?
 ┌──┴───┐
YES    NO
 │      │
 ▼      ▼
return DynamoDB
        │
        ▼
       cache
```

---

# 54. Best DAX Workload

Think:

```text
same items
read repeatedly
```

Examples:

```text
gaming leaderboard data
product metadata
popular profiles
real-time bidding metadata
read-heavy reference data
```

DAX is most attractive when the workload has:

```text
high cache hit ratio
+
eventual consistency acceptable
```

AWS warns that infrequently reused/cold data can produce a poor cache hit ratio and therefore may not justify DAX. ([AWS Documentation][32])

---

# 55. DAX Is Not a Fix for Bad Key Design

If your application does:

```text
Scan 500 million items
```

do not think:

```text
Add DAX
=
problem solved.
```

Fix:

```text
data model
partition key
access pattern
GSI
```

first.

DAX is primarily an acceleration layer for suitable DynamoDB access—not permission to ignore DynamoDB modeling.

---

# 56. DynamoDB Backup

DynamoDB offers:

```text
on-demand backups
```

and:

```text
PITR
```

Point-in-time recovery provides continuous backups with up to **35 days** of recovery points at per-second granularity. ([AWS Documentation][33])

Conceptually:

```text
DynamoDB
    │
    ├── on-demand backup
    │
    └── PITR
         │
         ▼
      up to 35 days
```

---

# 57. PITR Restores a New Table

Same pattern we've learned with RDS:

```text
Production Table
      │
      X bad deletion
      │
      ▼
PITR
      │
      ▼
NEW TABLE
```

DynamoDB PITR does not rewind the existing table in place. ([AWS Documentation][34])

This is safer because you can:

```text
validate
compare
recover selected data
cut over intentionally
```

---

# 58. Encryption at Rest

DynamoDB encrypts table data at rest by default.

Current options include:

```text
AWS owned key
    ← default

AWS managed KMS key
aws/dynamodb

customer-managed KMS key
```

The selected key protects the table and associated resources such as indexes, streams, and backups. ([AWS Documentation][35])

Use customer-managed KMS when business requirements justify:

```text
key-policy control
rotation/control requirements
cross-account governance
auditing
```

rather than assuming every table needs a custom key by default.

---

# 59. Single-Table Design

Now one of DynamoDB's famous concepts.

Relational:

```text
Users table
Todos table
Projects table
Comments table
```

Single-table DynamoDB design might store multiple entity types in:

```text
AppTable
```

using deliberate PK/SK patterns.

Example:

```text
PK             SK
───────────────────────────────────────────

USER#1001      PROFILE

USER#1001      TODO#2026-08-14#001

USER#1001      TODO#2026-08-14#002

PROJECT#77     META

PROJECT#77     TODO#001

PROJECT#77     TODO#002
```

This isn't done because:

```text
fewer tables are always better
```

It is done so related access patterns can be answered efficiently with well-designed key structures.

---

# 60. Single-Table Design Is Not Mandatory

A common beginner mistake is:

```text
"I learned DynamoDB.
Therefore everything must
go into one table."
```

No.

Single-table design is powerful when:

```text
access patterns are understood
relationships can be modeled by keys
high performance matters
```

But multiple tables can be simpler for some systems.

The design goal is:

```text
efficient predictable access
```

not:

```text
winning a contest
for fewest tables.
```

---

# 61. Todo App Single-Table Example

Let's design:

```text
TodoApp
```

Access patterns:

```text
Get user profile

Get all Todos for user

Get one Todo

Get Todos newest first

Find Todos by project
```

Possible records:

```text
PK             SK                              Entity

USER#1001      PROFILE                         User

USER#1001      TODO#20260814T005000#T001        Todo

USER#1001      TODO#20260813T130000#T002        Todo
```

Additional GSI attributes:

```text
GSI1PK = PROJECT#P77

GSI1SK = TODO#20260814#T001
```

Now:

```text
User's Todos
=
Query base table
PK=USER#1001
```

and:

```text
Project Todos
=
Query GSI1
PK=PROJECT#P77
```

No Scan required.

---

# 62. Hands-On DynamoDB Lab

We'll stay in:

```text
ap-south-1
```

Set:

```bash
export AWS_REGION="ap-south-1"
export TABLE="lesson28-todos"
```

Create an **on-demand** table:

```bash
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions \
      AttributeName=PK,AttributeType=S \
      AttributeName=SK,AttributeType=S \
  --key-schema \
      AttributeName=PK,KeyType=HASH \
      AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

Wait:

```bash
aws dynamodb wait table-exists \
  --table-name "$TABLE" \
  --region "$AWS_REGION"
```

Inspect:

```bash
aws dynamodb describe-table \
  --table-name "$TABLE" \
  --region "$AWS_REGION" \
  --query 'Table.{
      Status:TableStatus,
      Billing:BillingModeSummary.BillingMode,
      ItemCount:ItemCount
  }'
```

---

# 63. Insert User Profile

```bash
aws dynamodb put-item \
  --table-name "$TABLE" \
  --item '{
    "PK": {"S": "USER#1001"},
    "SK": {"S": "PROFILE"},
    "name": {"S": "Vivek"},
    "entityType": {"S": "USER"}
  }' \
  --region "$AWS_REGION"
```

---

# 64. Insert Todos

```bash
aws dynamodb put-item \
  --table-name "$TABLE" \
  --item '{
    "PK": {"S": "USER#1001"},
    "SK": {"S": "TODO#20260814T010000#001"},
    "title": {"S": "Learn DynamoDB partition keys"},
    "completed": {"BOOL": false},
    "priority": {"S": "HIGH"},
    "entityType": {"S": "TODO"}
  }' \
  --region "$AWS_REGION"
```

Second:

```bash
aws dynamodb put-item \
  --table-name "$TABLE" \
  --item '{
    "PK": {"S": "USER#1001"},
    "SK": {"S": "TODO#20260814T020000#002"},
    "title": {"S": "Practice Query operation"},
    "completed": {"BOOL": false},
    "priority": {"S": "MEDIUM"},
    "entityType": {"S": "TODO"}
  }' \
  --region "$AWS_REGION"
```

Third:

```bash
aws dynamodb put-item \
  --table-name "$TABLE" \
  --item '{
    "PK": {"S": "USER#2002"},
    "SK": {"S": "TODO#20260814T030000#003"},
    "title": {"S": "Unrelated user todo"},
    "completed": {"BOOL": false},
    "priority": {"S": "LOW"},
    "entityType": {"S": "TODO"}
  }' \
  --region "$AWS_REGION"
```

---

# 65. Query One User's Todos

```bash
aws dynamodb query \
  --table-name "$TABLE" \
  --key-condition-expression \
      "PK = :pk AND begins_with(SK, :todo)" \
  --expression-attribute-values '{
    ":pk":{"S":"USER#1001"},
    ":todo":{"S":"TODO#"}
  }' \
  --region "$AWS_REGION"
```

DynamoDB targets:

```text
USER#1001
```

and doesn't need to examine:

```text
USER#2002
```

for this Query.

That is exactly the access-pattern design we're after.

---

# 66. Reverse Chronological Ordering

Because the sort key contains time:

```text
TODO#20260814T010000

TODO#20260814T020000
```

DynamoDB naturally orders query results by sort key.

To reverse them:

```bash
aws dynamodb query \
  --table-name "$TABLE" \
  --key-condition-expression \
      "PK = :pk AND begins_with(SK, :todo)" \
  --expression-attribute-values '{
    ":pk":{"S":"USER#1001"},
    ":todo":{"S":"TODO#"}
  }' \
  --scan-index-forward false \
  --region "$AWS_REGION"
```

Now newest sorts first.

---

# 67. Compare With Scan

Run:

```bash
aws dynamodb scan \
  --table-name "$TABLE" \
  --filter-expression "priority = :p" \
  --expression-attribute-values '{
    ":p":{"S":"HIGH"}
  }' \
  --return-consumed-capacity TOTAL \
  --region "$AWS_REGION"
```

This is fine for our three-item lab.

But mentally scale it to:

```text
3 items
→ 3 billion items
```

Then the architectural weakness becomes obvious.

If:

```text
priority
```

must be a high-scale application lookup, redesign the key/index rather than relying on Scan.

---

# 68. Conditional Write Lab

Suppose Todo should only transition from:

```text
completed=false
```

to:

```text
completed=true
```

when it is still unfinished.

```bash
aws dynamodb update-item \
  --table-name "$TABLE" \
  --key '{
    "PK":{"S":"USER#1001"},
    "SK":{"S":"TODO#20260814T010000#001"}
  }' \
  --update-expression \
      "SET completed = :true" \
  --condition-expression \
      "completed = :false" \
  --expression-attribute-values '{
    ":true":{"BOOL":true},
    ":false":{"BOOL":false}
  }' \
  --return-values ALL_NEW \
  --region "$AWS_REGION"
```

Run it again.

Now the condition should fail because:

```text
completed
```

is already:

```text
true
```

That is safe concurrency logic.

---

# 69. Add TTL Concept

Suppose Todo reminder metadata should disappear after a week.

Add:

```text
expiresAt
```

containing an epoch timestamp.

Enable:

```bash
aws dynamodb update-time-to-live \
  --table-name "$TABLE" \
  --time-to-live-specification \
    "Enabled=true,AttributeName=expiresAt" \
  --region "$AWS_REGION"
```

Remember:

```text
expiresAt
=
eligibility for asynchronous deletion

NOT
exact deletion time.
```

([AWS Documentation][22])

---

# 70. Enable PITR

Production-oriented baseline:

```bash
aws dynamodb update-continuous-backups \
  --table-name "$TABLE" \
  --point-in-time-recovery-specification \
    PointInTimeRecoveryEnabled=true \
  --region "$AWS_REGION"
```

Verify:

```bash
aws dynamodb describe-continuous-backups \
  --table-name "$TABLE" \
  --region "$AWS_REGION"
```

PITR gives up to 35 days of per-second recovery points. ([AWS Documentation][33])

---

# 71. Terraform Baseline

```hcl
resource "aws_dynamodb_table" "todos" {
  name         = "prod-todos"
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

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Environment = "production"
    Application = "todo"
  }
}
```

An important Terraform detail:

```text
Don't declare every normal DynamoDB
item attribute in Terraform.
```

`attribute` blocks primarily describe attributes used by key/index schemas, not your complete application document schema.

---

# 72. Production Architecture

Combine DynamoDB with what we've already learned:

```text
                         Internet
                            │
                            ▼
                         CloudFront
                            │
                            ▼
                           ALB
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
             EC2-A                     EC2-B
             Node API                   Node API
               │                           │
               └───────────┬───────────────┘
                           │
                    AWS SDK + IAM Role
                           │
                           ▼
                      DynamoDB
                           │
                    ┌──────┼──────┐
                    ▼      ▼      ▼
                   GSI   Streams  PITR
                          │
                          ▼
                        Lambda
                          │
                          ▼
                         SQS
```

No:

```text
database server
OS
storage volume
DB subnet group
connection pool to a DB process
```

is required in the same way as RDS.

That's why DynamoDB fits serverless architectures so naturally.

---

# 73. DynamoDB vs RDS

| RDS/Aurora                      | DynamoDB                                   |
| ------------------------------- | ------------------------------------------ |
| Relational                      | Key-value/document                         |
| SQL                             | API operations / PartiQL available         |
| Joins                           | No traditional server-side joins           |
| Flexible relational querying    | Access-pattern-driven                      |
| DB server/cluster compute       | Serverless managed service                 |
| Connections/pools               | Request API model                          |
| Scale compute/readers           | Automatic distributed partitions           |
| Schema constraints              | Flexible attributes                        |
| Strong transaction model        | Atomic ops + optional transactions         |
| Query plan/index tuning         | Partition/sort/index design                |
| Great for relational complexity | Great for predictable massive-scale access |

Don't ask:

```text
Which one is better?
```

Ask:

```text
Which data model
matches this workload?
```

---

# 74. Example — Choose RDS

Requirement:

```text
Customers
Orders
Products
Payments
Invoices
```

with:

```text
complex joins
ad-hoc reporting
relational constraints
many flexible query combinations
```

Think first:

```text
PostgreSQL / Aurora PostgreSQL
```

not:

```text
DynamoDB because NoSQL scales.
```

---

# 75. Example — Choose DynamoDB

Requirement:

```text
hundreds of millions
of gaming sessions

access:
sessionId → session

very high request rate

simple predictable lookups

automatic expiry
```

Excellent DynamoDB-shaped workload:

```text
PK = SESSION#uuid

TTL = expiresAt
```

---

# 76. Example — Use Both

E-commerce architecture:

```text
Aurora
   │
   ├── orders
   ├── payments
   └── customers


DynamoDB
   │
   ├── shopping carts
   ├── sessions
   └── request idempotency


ElastiCache
   │
   └── hot frequently reused data


S3
   │
   └── product images
```

Production architectures are usually compositions of services rather than one database forced to solve everything.

---

# 77. SAA-C03 Scenario — Query vs Scan

> Need to retrieve all orders for customer `C123`.

Table:

```text
PK = CUSTOMER#123
SK = ORDER#timestamp
```

Choose:

```text
Query
```

not:

```text
Scan + customer filter
```

because Query directly addresses the partition-key value. ([AWS Documentation][5])

---

# 78. Scenario — Access Data by Different Key

Base table supports:

```text
userId → orders
```

but application also needs:

```text
status → orders
```

Think:

```text
GSI
```

provided `status` itself is designed to avoid a hot, low-cardinality access pattern. ([AWS Documentation][15])

---

# 79. Scenario — Need Strong Read From GSI

Answer:

```text
NOT SUPPORTED
```

GSI reads are eventually consistent. ([AWS Documentation][14])

If strong consistency is mandatory, reconsider:

```text
base-table access pattern
LSI
application design
```

depending on the requirement.

---

# 80. Scenario — Unpredictable New Application

Traffic might be:

```text
10 requests/sec today

500,000/sec later
```

with no reliable forecast.

Strong default candidate:

```text
DynamoDB On-Demand
```

AWS currently recommends on-demand for most workloads where you don't want to manage throughput manually. ([AWS Documentation][9])

---

# 81. Scenario — Stable Predictable Workload

Traffic:

```text
50,000 reads/sec
10,000 writes/sec
24×7
predictable
```

Evaluate:

```text
Provisioned
+
Auto Scaling
```

against on-demand pricing.

This becomes a FinOps decision rather than merely a performance decision.

---

# 82. Scenario — One Partition Key Is Being Throttled

Table overall appears to have capacity.

But:

```text
USER#BIG_CUSTOMER
```

receives almost all the requests.

Think:

```text
HOT PARTITION
```

and investigate:

```text
partition-key cardinality
access skew
write sharding
adaptive capacity
```

rather than blindly doubling table capacity forever.

---

# 83. Scenario — Exact Deletion at 12:00 Required

Would you rely only on DynamoDB TTL?

```text
NO
```

TTL deletion is asynchronous and can occur significantly after the timestamp. ([AWS Documentation][22])

The application should enforce expiry based on the attribute value.

---

# 84. Scenario — Need Atomic Order Creation

Must:

```text
create order
decrement stock
claim coupon
```

as one all-or-nothing operation.

Think:

```text
TransactWriteItems
```

if the DynamoDB transaction limits and workload economics fit. ([AWS Documentation][20])

---

# 85. Scenario — Need Microsecond Reads

DynamoDB milliseconds aren't enough.

Reads are:

```text
highly repetitive
eventual consistency acceptable
```

Think:

```text
DAX
```

([AWS Documentation][31])

---

# 86. Scenario — Global Active-Active Application

Users write in:

```text
Mumbai
Frankfurt
Virginia
```

Think:

```text
DynamoDB Global Tables
```

Then explicitly decide whether you need:

```text
MREC
```

or:

```text
MRSC
```

because current DynamoDB supports both models. ([AWS Documentation][27])

---

# 87. Scenario — Zero-RPO Multi-Region DynamoDB

Need:

```text
strongly consistent
multi-Region DynamoDB
+
zero-RPO architecture
```

Evaluate:

```text
MRSC Global Tables
```

with its required three-Region topology and feature restrictions. ([AWS Documentation][29])

This answer did not exist in many older DynamoDB courses.

---

# 88. Common Beginner Mistakes

The most dangerous DynamoDB habits are:

```text
Designing entities before access patterns

Using Scan for application traffic

Choosing low-cardinality partition keys

Assuming on-demand means no throttling ever

Using filters to compensate for bad key design

Creating many unnecessary GSIs

Expecting GSI strong consistency

Treating TTL as exact scheduling

Using giant items

Putting binaries in DynamoDB

Adding DAX before fixing key design

Using transactions where one conditional update is enough
```

These mistakes are much more damaging than forgetting a console setting.

---

# 89. DynamoDB Troubleshooting Chain

Application says:

```text
DynamoDB is slow.
```

Use:

```text
Which API operation?
       │
       ├── GetItem?
       ├── Query?
       ├── Scan?
       └── Transaction?
       │
       ▼
Throttling?
       │
       ▼
Which table/index?
       │
       ▼
Hot partition?
       │
       ▼
Key cardinality?
       │
       ▼
Consumed capacity?
       │
       ▼
GSI under-capacity?
       │
       ▼
Item size?
       │
       ▼
Retry/backoff?
       │
       ▼
Client/network latency?
       │
       ▼
DAX appropriate?
```

Start with the **access pattern**, because the data model is often the root problem.

---

# 90. Never-Forget DynamoDB Mental Model

```text
                         DYNAMODB
                             │
                             ▼
                       ACCESS PATTERN
                             │
                             ▼
                      PARTITION KEY
                             │
                    hash/distribution
                             │
                             ▼
                       SORT KEY
                             │
                  grouping + ordering
                             │
                             ▼
                           ITEMS
                             │
                ┌────────────┼─────────────┐
                ▼            ▼             ▼
              Query        GSI/LSI      Conditions
                │            │             │
                ▼            ▼             ▼
             efficient    alternate       safe
              access       access       concurrent
                                         writes

                             │
                             ▼
                         CAPACITY
                             │
                 ┌───────────┴───────────┐
                 ▼                       ▼
              On-Demand              Provisioned
                                          │
                                          ▼
                                     Auto Scaling

                             │
                             ▼
                       DATA LIFECYCLE
                     ┌───────┼────────┐
                     ▼       ▼        ▼
                    TTL    Streams   PITR

                             │
                             ▼
                      GLOBAL SCALE
                    ┌────────┴────────┐
                    ▼                 ▼
                  MREC               MRSC
```

---

# 91. The 20 Rules to Burn Into Memory

```text
1. DynamoDB is NoSQL, not "RDS without SQL."

2. Design access patterns before keys.

3. Partition key controls data distribution.

4. Sort key groups and orders related items.

5. High-cardinality partition keys usually scale better.

6. Query is preferred over Scan.

7. Filters do not reduce data read before filtering.

8. One item is limited to 400 KB.

9. On-demand is the modern default for most workloads.

10. Provisioned mode still matters for predictable FinOps.

11. One RCU = one strong 4-KB read/sec
    or two eventual 4-KB reads/sec.

12. One WCU = one 1-KB write/sec.

13. GSI gives an alternate partition/sort-key access path.

14. GSI reads are eventually consistent.

15. LSI keeps the same partition key and changes sort key.

16. Conditional writes prevent many concurrency races.

17. Transactions are available when several items
    truly need atomic all-or-nothing updates.

18. TTL is asynchronous, not an exact timer.

19. Streams provide change-data capture.

20. Global Tables provide multi-Region DynamoDB,
    now with MREC and MRSC consistency choices.
```

And the single most important rule:

```text
BAD DYNAMODB KEY DESIGN
cannot be fixed
by buying a larger database server

because there is no larger
database server to buy.
```

You fix it by redesigning:

```text
ACCESS PATTERN
      ↓
PARTITION KEY
      ↓
SORT KEY
      ↓
INDEXES
```

---

# ✅ Lesson 28 Part 4 Complete

You now understand:

```text
✓ DynamoDB fundamentals
✓ NoSQL mental model
✓ tables / items / attributes
✓ 400-KB item limit
✓ partition keys
✓ sort keys
✓ composite primary keys
✓ data distribution
✓ access-pattern-first design
✓ Query
✓ Scan
✓ filter-expression cost trap
✓ sort-key ordering
✓ hierarchical sort keys
✓ hot partitions
✓ adaptive capacity
✓ write sharding
✓ on-demand capacity
✓ warm throughput
✓ provisioned capacity
✓ RCUs / WCUs
✓ eventual consistency
✓ strong consistency
✓ GSI
✓ LSI
✓ index limits
✓ conditional writes
✓ optimistic concurrency
✓ DynamoDB transactions
✓ TTL
✓ DynamoDB Streams
✓ Kinesis CDC
✓ PITR
✓ backups
✓ encryption
✓ DAX
✓ single-table design
✓ Global Tables
✓ MREC
✓ MRSC
✓ multi-account Global Tables
✓ Terraform
✓ hands-on CLI lab
✓ production troubleshooting
```

# Next — Lesson 28 Part 5

# **Amazon ElastiCache — Redis/Valkey, Caching, Sessions & Database Performance**

Now we'll solve a different database problem:

```text
Application
     │
     ▼
Database

same query
same query
same query
same query
same query
```

Why repeatedly make Aurora/RDS calculate the same expensive result?

We'll build:

```text
                    APPLICATION
                         │
                         ▼
                       CACHE
                    ElastiCache
                         │
                 ┌───────┴───────┐
                 │               │
              CACHE HIT       CACHE MISS
                 │               │
                 ▼               ▼
              return         RDS/Aurora
                                │
                                ▼
                            fill cache
```

Next we'll cover **Valkey/Redis OSS/Memcached, cache-aside, write-through, write-behind concepts, TTLs, eviction, cache stampede, hot keys, replication, Multi-AZ failover, cluster mode/sharding, session storage, distributed locks, pub/sub, ElastiCache Serverless, encryption, IAM/authentication, connection management, metrics, Terraform, and exactly when caching helps—or makes your architecture worse.**

[1]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Introduction.html?utm_source=chatgpt.com "What is Amazon DynamoDB? - Amazon DynamoDB"
[2]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/CapacityUnitCalculations.html?utm_source=chatgpt.com "DynamoDB item sizes and formats"
[3]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-use-s3-too.html?utm_source=chatgpt.com "Best practices for storing large items and attributes in ..."
[4]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html?utm_source=chatgpt.com "Core components of Amazon DynamoDB"
[5]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html?utm_source=chatgpt.com "Querying tables in DynamoDB"
[6]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-query-scan.html?utm_source=chatgpt.com "Best practices for querying and scanning data in DynamoDB"
[7]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.KeyConditionExpressions.html?utm_source=chatgpt.com "Key condition expressions for the Query operation in ..."
[8]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html?utm_source=chatgpt.com "Best practices for designing and using partition keys ..."
[9]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/capacity-mode.html?utm_source=chatgpt.com "DynamoDB throughput capacity"
[10]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/warm-throughput.html?utm_source=chatgpt.com "Understanding DynamoDB warm throughput"
[11]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html?utm_source=chatgpt.com "DynamoDB on-demand capacity mode"
[12]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode-max-throughput.html?utm_source=chatgpt.com "DynamoDB maximum throughput for on-demand tables"
[13]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/AutoScaling.html?utm_source=chatgpt.com "Managing throughput capacity automatically with ..."
[14]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadConsistency.html?utm_source=chatgpt.com "DynamoDB read consistency"
[15]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html?utm_source=chatgpt.com "Using Global Secondary Indexes in DynamoDB"
[16]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.OnlineOps.html?utm_source=chatgpt.com "Managing Global Secondary Indexes in DynamoDB"
[17]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/LSI.html?utm_source=chatgpt.com "Local secondary indexes - Amazon DynamoDB"
[18]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-indexes-general.html?utm_source=chatgpt.com "General guidelines for secondary indexes in DynamoDB"
[19]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html?utm_source=chatgpt.com "Working with items and attributes in DynamoDB"
[20]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html?utm_source=chatgpt.com "Amazon DynamoDB Transactions: How it works"
[21]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/read-write-operations.html?utm_source=chatgpt.com "DynamoDB read and write operations"
[22]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/TTL.html?utm_source=chatgpt.com "Using time to live (TTL) in DynamoDB"
[23]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html?utm_source=chatgpt.com "Change data capture for DynamoDB Streams"
[24]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.Lambda.html?utm_source=chatgpt.com "DynamoDB Streams and AWS Lambda triggers"
[25]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/streamsmain.html?utm_source=chatgpt.com "Change data capture with Amazon DynamoDB"
[26]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/time-to-live-ttl-streams.html?utm_source=chatgpt.com "DynamoDB Streams and Time to Live"
[27]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication"
[28]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables.tutorial.html?utm_source=chatgpt.com "Tutorials: Creating global tables - Amazon DynamoDB"
[29]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables-security.html?utm_source=chatgpt.com "DynamoDB global tables security"
[30]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[31]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DAX.html?utm_source=chatgpt.com "In-memory acceleration with DynamoDB Accelerator (DAX)"
[32]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/evaluate-dax-suitability.html?utm_source=chatgpt.com "Evaluating the suitability of DAX for your use cases"
[33]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Point-in-time-recovery.html?utm_source=chatgpt.com "Point-in-time backups for DynamoDB"
[34]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.Tutorial.html?utm_source=chatgpt.com "Restoring a DynamoDB table to a point in time"
[35]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html?utm_source=chatgpt.com "DynamoDB encryption at rest"
