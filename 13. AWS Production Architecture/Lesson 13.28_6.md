# AWS Masterclass — Lesson 28 Part 6

# AWS Database Decision Architecture — RDS vs Aurora vs DynamoDB vs ElastiCache

This is where everything from Lesson 28 comes together.

Until now, we studied each technology separately:

```text
Part 1 → Amazon RDS
Part 2 → Amazon Aurora
Part 3 → RDS/Aurora production operations
Part 4 → DynamoDB
Part 5 → ElastiCache
```

Now imagine you're the Solutions Architect and a development team asks:

> “We need a database. What should we use?”

The wrong answer is:

```text
Use Aurora.
```

or:

```text
Use DynamoDB.
```

The correct first response is:

```text
Tell me about the DATA
and how the APPLICATION
needs to use it.
```

AWS's current database decision guidance explicitly recommends choosing a purpose-built database based on data model, access patterns, scaling, availability, consistency, operational requirements, and other workload characteristics. AWS's relational family includes RDS and Aurora, while services such as DynamoDB and ElastiCache address different data-access models. ([AWS Documentation][1])

---

# 1. The Master Database Decision Tree

Memorize this before thinking about individual AWS service names:

```text
                         APPLICATION DATA
                                │
                                ▼
                 What kind of problem is this?
                                │
          ┌─────────────────────┼──────────────────────┐
          │                     │                      │
          ▼                     ▼                      ▼
     RELATIONAL             KEY/VALUE              CACHE
     TRANSACTIONAL          DOCUMENT                IN-MEMORY
          │                     │                      │
          ▼                     ▼                      ▼
    RDS / Aurora            DynamoDB               ElastiCache
```

Then go deeper:

```text
RELATIONAL?
     │
     ├── normal managed SQL requirement
     │       │
     │       ▼
     │      RDS
     │
     └── cloud-native relational
         with Aurora capabilities
             │
             ▼
           Aurora


KEY/VALUE?
known access patterns?
huge distributed scale?
     │
     ▼
 DynamoDB


Repeated hot data?
microsecond-ish caching?
sessions/counters?
     │
     ▼
 ElastiCache
```

Amazon RDS remains AWS's managed service for industry-standard relational engines, while Aurora is AWS's cloud-built MySQL/PostgreSQL-compatible relational engine. DynamoDB is a purpose-built NoSQL option, and ElastiCache provides managed in-memory caching/data-store capabilities. ([AWS Documentation][2])

---

# 2. Start With the Data Model

Ask:

```text
Does the data have
strong relationships?
```

Example:

```text
CUSTOMER
   │
   ├── ORDER
   │     │
   │     ├── ORDER_ITEM
   │     │       │
   │     │       └── PRODUCT
   │     │
   │     └── PAYMENT
   │
   └── ADDRESS
```

Your application wants:

```sql
SELECT
    customer.name,
    orders.id,
    products.name,
    order_items.quantity,
    payments.status
FROM ...
JOIN ...
JOIN ...
JOIN ...
```

This is strongly relational.

First thought:

```text
PostgreSQL / MySQL
        │
        ▼
RDS or Aurora
```

RDS and Aurora are relational databases designed around tables, SQL, transactions, constraints, indexes, and relationships. ([AWS Documentation][1])

---

# 3. Now Consider a Different Workload

Requirement:

```text
Session ID
    │
    ▼
Get session

Device ID
    │
    ▼
Get device state

User ID
    │
    ▼
Get preferences
```

Requests might reach:

```text
millions/sec
```

but access patterns are known.

No JOIN requirement.

No arbitrary:

```sql
GROUP BY
JOIN
HAVING
complex relational reporting
```

Think:

```text
DynamoDB
```

DynamoDB's architecture is particularly suited to highly scalable key-value/document access patterns where primary keys and indexes are deliberately designed around application lookups. ([AWS Documentation][1])

---

# 4. Third Workload

Database already contains:

```text
product information
user preferences
expensive query results
```

but application repeatedly reads:

```text
same value
same value
same value
same value
```

Think:

```text
ElastiCache
```

because the problem isn't necessarily database storage.

It's:

```text
repeating expensive work.
```

ElastiCache provides an in-memory layer specifically intended to reduce latency and database workload; AWS documents microsecond-scale cache access for appropriate workloads. ([AWS Documentation][3])

---

# 5. RDS — When Is It the Natural Choice?

Choose RDS first when you need something like:

```text
PostgreSQL
MySQL
MariaDB
Oracle
SQL Server
Db2
```

and the application needs standard relational capabilities without requiring Aurora-specific architecture. RDS currently supports those managed relational engines and handles common infrastructure/database administration tasks. ([AWS Documentation][1])

Examples:

```text
ERP

financial application

CRM

traditional web application

internal enterprise system

existing Oracle/SQL Server application

application requiring extensive SQL relationships
```

---

# 6. Why Not Always Aurora?

Suppose your requirement is:

```text
PostgreSQL

500 GB database

moderate load

few read replicas

one Region

normal Multi-AZ HA

stable traffic
```

RDS PostgreSQL might satisfy everything.

You don't automatically need:

```text
Aurora Global Database

15 readers

Serverless scaling

fast cloning

distributed Aurora storage
```

simply because those features exist.

AWS describes RDS as resizable managed relational capacity and Aurora as a distinct cloud-optimized relational architecture. The right choice therefore depends on which capabilities the workload genuinely needs. ([AWS Documentation][2])

---

# 7. RDS Scaling Model

Think:

```text
                     RDS
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
       WRITES                   READS
          │                       │
          ▼                       ▼
  resize primary             Read Replicas
  optimize SQL               asynchronous
```

RDS provides instance resizing for compute capacity and read replicas for additional read capacity. AWS separately distinguishes scaling from high availability. ([AWS Documentation][4])

---

# 8. Traditional RDS Multi-AZ

For the classic:

```text
Multi-AZ DB Instance
```

architecture:

```text
              AZ-A                 AZ-B

             PRIMARY ───────────▶ STANDBY
           read/write             HA only
```

The standby is for automatic high availability and does **not** serve application read traffic. AWS explicitly recommends read replicas or Multi-AZ DB clusters when you need readable scale-out. ([AWS Documentation][5])

So:

```text
Multi-AZ DB Instance
=
SURVIVE
```

not:

```text
READ SCALE
```

---

# 9. Modern RDS Multi-AZ Cluster

Current RDS also supports:

```text
Multi-AZ DB Cluster
```

with:

```text
        AZ-A              AZ-B              AZ-C

       WRITER            READER            READER
         │                  │                  │
         └──────────────────┼──────────────────┘
                    HA + read capacity
```

AWS currently describes Multi-AZ DB clusters as one writer plus two readable replicas in three separate AZs, with semisynchronous replication. ([AWS Documentation][6])

This means the old shortcut:

```text
Multi-AZ readers are never readable
```

is no longer universally correct.

It is correct for:

```text
Multi-AZ DB INSTANCE standby
```

but not:

```text
Multi-AZ DB CLUSTER readers.
```

---

# 10. RDS Read Replica

A standard read replica solves:

```text
SELECT pressure
```

through:

```text
PRIMARY
    │
    │ asynchronous
    ▼
READ REPLICA
```

AWS documents that read replicas receive changes asynchronously and are distinct from HA standby/readers. ([AWS Documentation][7])

Therefore:

```text
read replica
=
READ SCALE
+
potential lag
```

---

# 11. The RDS Decision

Use RDS when you want:

```text
standard relational engine
+
managed infrastructure
+
familiar SQL ecosystem
+
predictable architecture
```

and don't need enough Aurora-specific capabilities to justify moving away from conventional RDS engine architecture. ([AWS Documentation][2])

---

# 12. Aurora — When Does It Become Attractive?

Aurora becomes especially interesting when requirements include several of:

```text
very high HA expectations

multiple low-lag readers

fast reader promotion

distributed multi-AZ storage

Aurora Serverless

rapid reader scaling

Global Database

fast database cloning

cloud-native MySQL/PostgreSQL architecture
```

Aurora separates compute and cluster storage and provides shared multi-AZ storage that remains available independently of individual DB compute instances. ([AWS Documentation][8])

---

# 13. RDS vs Aurora Architecture

## Traditional RDS PostgreSQL

```text
Primary
   │
   │ replication
   ▼
Replica
   │
   ▼
replica storage
```

## Aurora PostgreSQL

```text
            Writer
              │
      ┌───────┴────────┐
      ▼                ▼
   Reader 1         Reader 2
      \                /
       \              /
        ▼            ▼
        Shared Aurora
        Cluster Volume
             │
       multiple AZs
```

Aurora Replicas work against the cluster's shared distributed storage architecture rather than maintaining the same type of independent DB-storage copy used by conventional RDS read replicas. ([AWS Documentation][9])

---

# 14. Aurora Read Scaling

Aurora can scale reader capacity by adding Aurora Replicas.

AWS currently supports Aurora Auto Scaling for both Aurora MySQL and PostgreSQL, dynamically adjusting the number of Aurora Replicas within configured minimum/maximum values based on CloudWatch-driven policies. ([AWS Documentation][10])

Mental model:

```text
Normal traffic

Writer
Reader
Reader


Read traffic ↑

Writer
Reader
Reader
Reader
Reader
Reader
```

But:

```text
Reader Auto Scaling
≠
automatic multi-writer scaling.
```

---

# 15. Aurora Serverless

If DB compute is difficult to size:

```text
Traffic
 low
 ↓
 high
 ↓
 low
 ↓
 extremely high
```

Aurora Serverless automates Aurora compute-capacity adjustment according to application demand. Recent supported Aurora versions can even scale Serverless writers/readers down to zero ACUs where automatic pause is supported. ([AWS Documentation][11])

Candidate:

```text
unknown / variable relational workload
       │
       ▼
Aurora Serverless
```

---

# 16. Aurora Global Database

For globally distributed relational systems:

```text
                 PRIMARY REGION
                      │
                    Writer
                      │
         cross-Region replication
                      │
         ┌────────────┼─────────────┐
         ▼            ▼             ▼
     Secondary    Secondary     Secondary
```

Current Aurora Global Database supports a primary write Region and up to ten read-only secondary Regions. ([AWS Documentation][12])

So the normal Aurora Global Database model remains:

```text
ONE write Region
+
multiple read Regions
```

not generic multi-master relational writes.

---

# 17. Aurora Global Database vs DynamoDB Global Tables

This is one of the most important architecture distinctions.

### Aurora Global

```text
Mumbai
WRITER

Singapore
READ

Europe
READ
```

### DynamoDB Global Tables

```text
Mumbai
READ + WRITE

Europe
READ + WRITE

Virginia
READ + WRITE
```

DynamoDB Global Tables are designed for multi-Region, multi-active operation. Current Global Tables support both multi-Region eventual consistency (MREC) and multi-Region strong consistency (MRSC). ([AWS Documentation][13])

---

# 18. DynamoDB — When Is It the Better Choice?

Consider DynamoDB when the workload has:

```text
known access patterns

high request volume

key-value/document semantics

horizontal scale

serverless operations

low-latency API access

TTL

event streams

global active-active requirements
```

The service's design is fundamentally different from relational engines, so the decision should be made around access patterns rather than translating relational table design directly. ([AWS Documentation][1])

---

# 19. Example: Session Service

Requirement:

```text
GET session by sessionId

PUT session

DELETE session

expire after 30 minutes

millions of sessions
```

Perfectly natural DynamoDB key:

```text
PK = SESSION#<uuid>
```

with:

```text
TTL = expiresAt
```

No SQL JOIN is required.

No relational schema is adding much value.

---

# 20. Example: Complex Finance Reporting

Requirement:

```text
customers

accounts

transactions

products

regions

currency

reconciliation
```

Queries:

```sql
JOIN
GROUP BY
HAVING
window functions
ad-hoc reporting
```

Don't immediately force that into:

```text
single-table DynamoDB
```

simply because DynamoDB scales.

Start with:

```text
relational database
```

unless other requirements strongly override that model.

---

# 21. DynamoDB Scaling

DynamoDB doesn't expose:

```text
db.r7g.large
```

or:

```text
16 vCPU / 64 GB RAM
```

as your table capacity unit.

You design:

```text
partition key
sort key
indexes
capacity mode
```

and DynamoDB manages physical partitioning.

That fundamentally changes capacity planning.

---

# 22. DynamoDB Server Sizing Question

Interviewer:

> What DynamoDB instance size should we choose?

Answer:

```text
There is no DynamoDB DB instance
for me to size like RDS.

I size:
- access patterns
- partition-key distribution
- capacity mode
- throughput
- indexes
- item sizes
```

That's exactly the conceptual difference from RDS/Aurora.

---

# 23. DynamoDB Global Tables MREC

Traditional Global Tables behavior:

```text
Region A
   │
   │ write
   ▼
local success
   │
   └──── asynchronous replication ───▶ Region B
```

MREC prioritizes lower write latency while cross-Region visibility is eventually consistent. ([AWS Documentation][14])

Think:

```text
GLOBAL LOW-LATENCY ACTIVE-ACTIVE
+
eventual cross-Region consistency
```

---

# 24. DynamoDB Global Tables MRSC

Current DynamoDB also offers MRSC:

```text
Multi-Region Strong Consistency
```

AWS requires an MRSC global table to use exactly three Regions, as either three replicas or two replicas plus a witness. ([AWS Documentation][15])

Conceptually:

```text
             Region A
             Replica
                │
        synchronous coordination
          ┌─────┴─────┐
          ▼           ▼
      Region B     Region C
       Replica     Replica/Witness
```

MRSC offers stronger cross-Region consistency but with different latency and feature tradeoffs than MREC. ([AWS Documentation][14])

---

# 25. ElastiCache — When Does It Belong?

ElastiCache belongs when your actual problem is:

```text
repeated hot reads

temporary session state

leaderboards

counters

rate limits

hot API results

frequently accessed derived data
```

rather than:

```text
"we need somewhere durable
to store all business data."
```

ElastiCache supports Valkey, Redis OSS, and Memcached and can be deployed as Serverless or node-based resources. ([AWS Documentation][16])

---

# 26. ElastiCache Serverless

If you don't want to size:

```text
cache nodes
shards
replicas
```

ElastiCache Serverless automatically handles much of the capacity topology. Current ElastiCache Serverless stores data redundantly across three AZs and AWS publishes a 99.99% availability SLA for the service. ([AWS Documentation][17])

Architecture:

```text
Application
    │
    ▼
ElastiCache Serverless
    │
    ▼
AWS-managed
capacity + multi-AZ
```

---

# 27. ElastiCache Node-Based

If you want:

```text
exact node class

exact shard count

replica count

topology control

scaling policy
```

choose node-based ElastiCache.

AWS supports both Serverless and node-based deployment models for Valkey/Redis OSS/Memcached. ([AWS Documentation][16])

---

# 28. Critical Distinction — DB vs Cache

Suppose application stores:

```text
order status
=
PAID
```

only in ElastiCache.

Cache is lost.

Question:

```text
Can business reconstruct that status?
```

If:

```text
NO
```

you probably shouldn't be treating that value as disposable cache state.

ElastiCache can technically serve as a primary in-memory store for some non-durable use cases, but AWS's own examples distinguish caching/data acceleration from workloads requiring durable authoritative storage. ([AWS Documentation][3])

---

# 29. The Four-Service Comparison

| Characteristic         | RDS                           | Aurora                                       | DynamoDB                   | ElastiCache              |
| ---------------------- | ----------------------------- | -------------------------------------------- | -------------------------- | ------------------------ |
| Model                  | Relational                    | Relational                                   | Key-value/document         | In-memory                |
| SQL                    | Yes                           | Yes                                          | No traditional SQL model   | No                       |
| Joins                  | Yes                           | Yes                                          | No traditional joins       | No                       |
| Primary design concern | schema/query                  | relational + cloud scale                     | access patterns/keys       | reuse/latency            |
| Server sizing          | DB instance                   | Provisioned or Serverless                    | No DB instance             | Node-based or Serverless |
| Read scaling           | Read replicas                 | Aurora Replicas                              | native partition scale     | replicas/shards          |
| Write scaling          | mainly writer/vertical/design | mainly writer/design                         | horizontal partitions      | shards                   |
| Multi-AZ               | Yes                           | Built into cluster storage + compute options | managed regional service   | HA options/serverless    |
| Multi-Region           | replicas/backups              | Global Database                              | Global Tables              | Global Datastore         |
| Multi-Region writes    | not typical                   | primary write Region                         | Yes                        | primary Region           |
| Cache role             | No                            | No                                           | No                         | Yes                      |
| Best at                | traditional relational        | cloud-native relational                      | massive predictable access | hot reusable state       |

RDS scaling/HA, Aurora's cloud-native cluster architecture, DynamoDB multi-active Global Tables, and ElastiCache's serverless/node-based models are documented separately by AWS because they solve materially different workloads. ([AWS Documentation][4])

---

# 30. Consistency Decision

Ask:

> **How fresh must a read be after a write?**

This single question eliminates many bad architectures.

```text
Write
  │
  ▼
immediately read
```

Does the application require:

```text
latest committed value
```

or can it tolerate:

```text
slightly stale value?
```

---

# 31. Strongly Consistent Transactional Workload

Example:

```text
payment authorization

balance = ₹1000
      │
purchase ₹900
      │
      ▼
balance = ₹100
```

Then immediately:

```text
Can another transaction spend ₹900?
```

Correctness dominates latency.

Think first:

```text
relational transaction
```

or a carefully designed DynamoDB conditional/transactional operation, not stale cache/replica reads.

---

# 32. Eventually Consistent Read Workload

Example:

```text
You changed your avatar.

Another Region displays
the old avatar for 500 ms.
```

Maybe completely acceptable.

Then:

```text
replica read
MREC DynamoDB
cache
```

might be reasonable.

Architecture comes from the business impact of staleness.

---

# 33. Availability ≠ Consistency

Imagine:

```text
database reachable everywhere
```

but:

```text
some readers show old state.
```

System is:

```text
AVAILABLE
```

but not necessarily:

```text
STRONGLY CONSISTENT
```

Distributed data systems require you to reason independently about:

```text
availability
consistency
latency
durability
```

---

# 34. HA vs DR

Another distinction:

```text
AZ failure
```

and:

```text
Region failure
```

are different architecture problems.

### High availability

```text
Multi-AZ
```

### Disaster recovery

```text
Cross-Region
backups
replication
global database/table
```

AWS's DR guidance recommends selecting database capabilities according to defined RPO and RTO objectives rather than assuming one replication feature solves every failure class. ([AWS Documentation][18])

---

# 35. Database HA Decision

```text
Need automatic AZ failure recovery?
              │
              ▼
             YES
              │
      ┌───────┼──────────────┐
      ▼       ▼              ▼
     RDS    Aurora        ElastiCache
   Multi-AZ   replicas/HA    Multi-AZ/
                             Serverless
```

DynamoDB already presents itself as a managed regional distributed database rather than exposing individual DB instances/AZ placements for you to build manually.

---

# 36. Database DR Decision

```text
Need Region-level recovery?
              │
              ▼
   Define RPO and RTO
              │
     ┌────────┼─────────┐
     ▼        ▼         ▼
    RDS     Aurora   DynamoDB
 backups/   Global    Global
 replicas   Database  Tables
```

For cache:

```text
ElastiCache
Global Datastore
```

is available for supported Valkey/Redis OSS cross-Region read/DR scenarios. ([AWS Documentation][19])

---

# 37. RPO Mental Model

```text
RPO = 24 hours
```

might allow:

```text
nightly backup
```

But:

```text
RPO < seconds
```

could require:

```text
continuous replication
global data architecture
```

depending on the service and business guarantees.

Don't choose DR technology first.

Choose:

```text
RPO
RTO
```

first.

---

# 38. RTO Mental Model

Imagine:

```text
backup exists
```

but restoring it requires:

```text
4 hours
```

If business says:

```text
RTO = 10 minutes
```

you haven't met the requirement.

That's why:

```text
BACKUP
```

and:

```text
RUNNING REPLICA
```

solve different recovery-time problems.

---

# 39. Connection Model

RDS/Aurora:

```text
Application
    │
    ▼
persistent DB connections
    │
    ▼
database process
```

Connection storms matter.

Potential:

```text
RDS Proxy
```

DynamoDB:

```text
Application
    │
    ▼
HTTPS API requests
    │
    ▼
DynamoDB
```

No traditional database connection pool.

ElastiCache:

```text
Application
    │
    ▼
persistent cache connections
```

but much lighter than relational DB sessions.

This distinction materially affects scaling architecture.

---

# 40. Lambda + RDS

Suppose:

```text
Lambda

0
↓
10,000 concurrent invocations
```

and each does:

```text
open PostgreSQL connection
```

Potential:

```text
database connection storm
```

Think:

```text
RDS Proxy
```

or different connection architecture.

---

# 41. Lambda + DynamoDB

Lambda:

```text
10,000 concurrent invocations
      │
      ▼
DynamoDB API
```

No equivalent PostgreSQL connection pool is required.

You still need:

```text
partition design
throughput
retries
```

but the scaling bottleneck class is different.

---

# 42. Cost Model — Think Beyond $/Hour

Database cost should be considered as:

```text
TOTAL DATABASE COST
        │
        ├── compute
        ├── storage
        ├── I/O
        ├── replicas
        ├── backup
        ├── network
        ├── cache
        ├── KMS
        └── operational engineering
```

Do not compare only:

```text
RDS hourly instance price
```

against:

```text
Aurora hourly compute price.
```

Architecture can change the surrounding resource usage dramatically.

---

# 43. Cheap DB + Expensive Engineering

Imagine self-managed PostgreSQL:

```text
EC2
+
EBS
```

appears cheaper than RDS.

But then you operate:

```text
backup automation
patching
replication
failover
upgrade
OS
storage recovery
monitoring
```

The true cost includes:

```text
engineer time
risk
on-call burden
```

Managed services trade some infrastructure cost for reduced undifferentiated operational work. RDS explicitly manages many common administrative tasks that otherwise belong to the operator. ([AWS Documentation][2])

---

# 44. Server-Sizing Decision — RDS

Start with:

```text
WORKLOAD
   │
   ├── CPU?
   ├── RAM?
   ├── storage?
   ├── IOPS?
   ├── connections?
   └── query complexity?
```

Then:

```text
DB instance class
+
storage type
```

Don't select:

```text
db.r8g.16xlarge
```

because:

```text
"production should be big."
```

Select it from measurements.

---

# 45. Server-Sizing Decision — Aurora

Provisioned Aurora:

```text
writer instance
+
reader instances
```

can be sized independently according to workload and failover design.

Aurora Auto Scaling can change the number of reader DB instances, while Serverless changes Aurora compute capacity according to demand. ([AWS Documentation][10])

---

# 46. Server-Sizing Decision — DynamoDB

No instance.

Think:

```text
item size

requests/sec

partition distribution

read consistency

indexes

on-demand/provisioned
```

The logical schema becomes part of capacity engineering.

---

# 47. Server-Sizing Decision — ElastiCache

Node-based:

```text
memory
+
CPU
+
shards
+
replicas
```

Serverless:

```text
AWS manages underlying cache capacity
```

Current ElastiCache explicitly offers both deployment choices. ([AWS Documentation][17])

---

# 48. The Vertical vs Horizontal Scaling Model

```text
RDS

mostly:
VERTICAL writer scaling
+
read replicas
```

```text
Aurora

writer compute scaling
+
multiple readers
+
Serverless option
```

```text
DynamoDB

horizontal partition scaling
built into service
```

```text
ElastiCache

vertical nodes
+
horizontal shards/replicas
or Serverless
```

Each has a fundamentally different scaling unit.

---

# 49. Why DynamoDB Can Beat RDS at Huge Key-Value Scale

Imagine:

```text
10 billion session records

lookup:
sessionId
```

No:

```text
JOIN

aggregation

complex query
```

needed.

Relational database:

```text
huge indexes
connection management
DB server scaling
```

DynamoDB:

```text
partition key:
SESSION#uuid
```

is naturally aligned to the request.

The benefit doesn't come from DynamoDB being universally “faster.”

It comes from choosing a database whose internal architecture matches the access pattern.

---

# 50. Why PostgreSQL Can Beat DynamoDB for Complex Relational Work

Now requirement:

```text
Give me:

customers
whose rolling 90-day spend
is above regional median
and who purchased products
from suppliers in three categories
but have no unpaid invoice.
```

PostgreSQL:

```text
SQL
JOIN
aggregate
window function
```

DynamoDB:

```text
many precomputed access paths
denormalization
application joins
extra indexes
possibly analytics pipeline
```

Relational flexibility can be far more valuable.

Again:

```text
MATCH DATABASE
TO WORKLOAD.
```

---

# 51. Polyglot Persistence

A mature application often doesn't choose **one** database.

It chooses:

```text
the best database
for each data category.
```

Example:

```text
                         E-COMMERCE

                             │
          ┌──────────────────┼───────────────────┐
          ▼                  ▼                   ▼
       Aurora             DynamoDB           ElastiCache
          │                  │                   │
        Orders             Cart               Cache
        Payments           Session            Rate limits
        Customers          Idempotency        Hot products
```

Then:

```text
S3
=
product images / invoices / exports
```

This is:

# polyglot persistence

---

# 52. Example Complete Architecture

```text
                             USERS
                               │
                               ▼
                          CloudFront
                               │
                               ▼
                              ALB
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
              EC2-A                       EC2-B
              Node.js                     Node.js
                 │                           │
                 └─────────────┬─────────────┘
                               │
           ┌───────────────────┼────────────────────┐
           ▼                   ▼                    ▼
      ElastiCache          RDS Proxy            DynamoDB
        Valkey                 │                    │
           │                   ▼                    │
           │              Aurora PostgreSQL        │
           │                   │                    │
           │                   │                    ▼
           │                   │                Streams
           │                   │                    │
           │                   │                    ▼
           │                   │                  Lambda
           │                   │
           └───────────────────┼────────────────────┐
                               ▼                    ▼
                              S3                 EventBridge
```

Possible responsibilities:

```text
Aurora
→ users, orders, payments

DynamoDB
→ sessions, idempotency, workflow state

ElastiCache
→ cache, counters, rate limiting

S3
→ objects/documents
```

---

# 53. Idempotency Is a Great DynamoDB Workload

Suppose payment API receives:

```text
POST /payments
Idempotency-Key: abc123
```

Network retry sends it again.

Store:

```text
PK = IDEMPOTENCY#abc123
```

with a conditional write.

First request:

```text
key missing
→ create
→ process payment
```

Second request:

```text
key already exists
→ return previous result
```

This is an excellent key-value access pattern.

---

# 54. Why Not ElastiCache for Payment Idempotency Only?

Because ask:

```text
What happens if cache loses the key
while payment is still retryable?
```

Potential:

```text
duplicate payment.
```

That may be unacceptable.

For correctness-critical idempotency:

```text
durable store
```

such as DynamoDB or transactional relational state is typically safer.

Cache can still accelerate other parts.

---

# 55. Database Selection by Failure Consequence

Ask:

> What happens if the data disappears?

### Session

```text
user logs in again
```

Maybe cache is sufficient.

### Homepage recommendation

```text
recalculate
```

Cache definitely reasonable.

### Payment

```text
money disappears
```

Needs durable authoritative storage.

### Shopping cart

Depends:

```text
temporary convenience?
```

or:

```text
business-critical persistent cart?
```

Architecture is driven by consequences.

---

# 56. Scenario — Traditional Enterprise App

Requirements:

```text
Oracle application

stored procedures

existing relational schema

vendor certification
```

First candidate:

```text
Amazon RDS for Oracle
```

not:

```text
rewrite entire application for DynamoDB.
```

Migration complexity matters.

---

# 57. Scenario — New PostgreSQL SaaS

Requirements:

```text
relational

fast growth

many reads

Multi-AZ

potential Serverless

future cross-Region DR
```

Strong candidate:

```text
Aurora PostgreSQL
```

because several Aurora-specific capabilities align with the roadmap. Aurora provides shared multi-AZ cluster storage, reader scaling, Serverless configurations, and Global Database capabilities. ([AWS Documentation][8])

---

# 58. Scenario — Small Internal PostgreSQL App

Requirements:

```text
20 users

50 GB

simple SQL

one Region

moderate availability
```

Don't overengineer.

Candidate:

```text
RDS PostgreSQL
```

Possibly:

```text
Single-AZ dev/test
Multi-AZ production
```

depending on availability requirement.

---

# 59. Scenario — Gaming Session Platform

Requirements:

```text
20 million players

session lookup by ID

huge burst traffic

TTL

multi-Region writes
```

Candidate:

```text
DynamoDB
+
Global Tables
```

with MREC or MRSC selected according to consistency requirements. Current Global Tables support both modes. ([AWS Documentation][13])

---

# 60. Scenario — Product Catalog Is Killing Aurora

Aurora CPU:

```text
90%
```

Top query:

```sql
SELECT product...
```

same products requested continuously.

Before:

```text
double Aurora size
```

evaluate:

```text
ElastiCache
```

with:

```text
cache-aside
TTL
invalidation
```

ElastiCache is explicitly intended to reduce database load and improve response time for frequently reused data. ([AWS Documentation][3])

---

# 61. Scenario — 90% Writes

Application workload:

```text
90% INSERT/UPDATE

10% SELECT
```

Would:

```text
10 RDS Read Replicas
```

solve the primary bottleneck?

No.

The write path still targets the writer.

Read replicas solve read capacity; RDS documents them as asynchronously updated read-scale resources. ([AWS Documentation][20])

Investigate:

```text
query/index optimization
writer sizing
schema design
batching
Aurora/alternative database architecture
partitioning/sharding
workload redesign
```

---

# 62. Scenario — 90% Reads

Now:

```text
90% SELECT

10% writes
```

Options include:

```text
RDS Read Replicas

Aurora Readers

ElastiCache

or combinations
```

Ask:

```text
Do reads require fresh data?

Are they repetitive?

Are they expensive?

Can data be stale?
```

Then choose.

---

# 63. Cache vs Read Replica

This distinction is critical.

### Read Replica

```text
full database copy
```

Can answer:

```text
many arbitrary read queries
```

### Cache

```text
selected hot values
```

Excellent for:

```text
same expensive reads
over and over
```

So:

```text
Read Replica
=
DB READ CAPACITY
```

```text
Cache
=
AVOID DB WORK
```

These solve related but different problems.

---

# 64. Example Using Both

```text
                   Application

               ┌───────┴────────┐
               ▼                ▼
           ElastiCache      Reader Endpoint
               │                │
             miss               ▼
               │          Aurora Readers
               │
               └───────────────▶
```

This could be useful if:

```text
very hot keys
→ cache

less common reads
→ DB readers
```

---

# 65. RDS Proxy vs Read Replica vs Cache

Memorize:

```text
RDS PROXY
=
reduce connection pressure
```

```text
READ REPLICA
=
increase DB read capacity
```

```text
ELASTICACHE
=
avoid repeated DB work
```

These are **three different bottlenecks**.

---

# 66. Diagnose the Bottleneck Before Adding Technology

Application is slow.

Don't randomly deploy:

```text
RDS Proxy
Read Replica
ElastiCache
larger DB
```

Ask:

```text
Why slow?
```

If:

```text
connection exhaustion
→ RDS Proxy
```

If:

```text
SELECT workload
→ reader/read replica
```

If:

```text
same reads repeatedly
→ cache
```

If:

```text
bad query
→ optimize query/index
```

If:

```text
writer CPU
→ writer/query/schema analysis
```

That is production engineering.

---

# 67. RDS vs Aurora Interview Question

> Why choose Aurora instead of RDS PostgreSQL?

Strong answer:

> I would not choose Aurora just because it's more cloud-native. I'd choose it when its architecture provides material value—for example distributed multi-AZ cluster storage, multiple low-lag readers, reader Auto Scaling, Aurora Serverless, fast cloning, or Aurora Global Database. If a conventional RDS PostgreSQL Multi-AZ deployment meets the workload's relational, HA, scale, operational and cost requirements, RDS might be simpler. Aurora separates compute and distributed cluster storage, while traditional RDS follows the conventional DB-instance architecture. ([AWS Documentation][8])

---

# 68. DynamoDB Interview Question

> Why not use DynamoDB for every application if it scales automatically?

Strong answer:

> DynamoDB scales extremely well when the access patterns and key design fit its distributed key-value/document architecture, but it intentionally doesn't provide the same server-side relational joins and flexible ad-hoc SQL access as a relational database. Complex relational workloads can become much harder because relationships often need to be denormalized or modeled into keys and indexes ahead of time. I would choose it when predictable access patterns and horizontal scale are more important than relational query flexibility.

---

# 69. ElastiCache Interview Question

> Why not cache everything?

Strong answer:

> Every cached copy creates invalidation, expiration, consistency and failure questions. I'd cache data when reuse is high enough to materially reduce latency or downstream work and when the application can tolerate the freshness model. A cache shouldn't automatically become the authoritative store for business-critical data simply because memory is fast.

---

# 70. SAA-C03 Rapid-Fire Scenarios

| Requirement                            | First thought                                    |
| -------------------------------------- | ------------------------------------------------ |
| Standard managed PostgreSQL            | **RDS PostgreSQL**                               |
| MySQL/PostgreSQL + Aurora capabilities | **Aurora**                                       |
| Traditional HA standby                 | **RDS Multi-AZ DB instance**                     |
| RDS HA + readable cluster nodes        | **RDS Multi-AZ DB cluster**                      |
| Scale conventional RDS reads           | **Read Replica**                                 |
| Many low-lag Aurora readers            | **Aurora Replicas**                              |
| Variable relational compute            | **Aurora Serverless**                            |
| Global relational readers/DR           | **Aurora Global Database**                       |
| Massive key-value access               | **DynamoDB**                                     |
| Global multi-active NoSQL              | **DynamoDB Global Tables**                       |
| Strong multi-Region DynamoDB           | **MRSC Global Tables**                           |
| Cache expensive DB queries             | **ElastiCache**                                  |
| Database connection storm              | **RDS Proxy**                                    |
| Temporary sessions                     | **DynamoDB or ElastiCache depending durability** |
| Microsecond hot-data access            | **ElastiCache**                                  |

Current RDS/Aurora/DynamoDB/ElastiCache capabilities support these architectural mappings, with details depending on engine, Region, and configuration. ([AWS Documentation][6])

---

# 71. DOP-C02 Incident Scenario

API latency suddenly jumps.

Metrics:

```text
Aurora CPU:
30%

DatabaseConnections:
maximum

DB Load:
mostly connection waits
```

Do you add:

```text
ElastiCache?
```

Probably not first.

Think:

```text
connection architecture
pool size
RDS Proxy
```

because the bottleneck is connections—not repeated query computation.

---

# 72. Another Incident

Metrics:

```text
Aurora CPU:
95%

Connections:
normal

Top SQL:
SELECT product...
70% DB load

same product queries repeated
```

Investigate:

```text
query/index
```

and:

```text
cache opportunity
```

Potential:

```text
ElastiCache
```

---

# 73. Another Incident

DynamoDB:

```text
table overall traffic normal

one partition throttled
```

Do you add:

```text
ElastiCache?
```

Not automatically.

First:

```text
partition-key distribution
hot partition
access pattern
```

because a poor data model is the likely root cause.

---

# 74. Another Incident

Aurora Global Database secondary shows stale data.

Think:

```text
replication lag / consistency
```

before:

```text
database corruption.
```

Aurora Global Database operates with one primary write Region and cross-Region secondary clusters. ([AWS Documentation][12])

---

# 75. Another Incident

DynamoDB MREC application writes in Mumbai and Frankfurt simultaneously to the same logical item.

Now you need to understand:

```text
multi-active conflict semantics
```

not just:

```text
"DynamoDB is global."
```

If the business requires stronger cross-Region correctness, evaluate MRSC and its latency/topology tradeoffs. Current Global Tables explicitly provide MREC and MRSC modes. ([AWS Documentation][13])

---

# 76. Production Database Security Layer

Regardless of database choice:

```text
                   APPLICATION
                        │
                        ▼
                     IAM Role
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▼
         RDS         DynamoDB       ElastiCache
          │             │              │
         TLS          IAM/API         TLS/Auth
          │             │              │
          ▼             ▼              ▼
        KMS           KMS            KMS
```

Then:

```text
CloudTrail
CloudWatch
Secrets Manager
network controls
```

where relevant.

Database choice doesn't remove the need for security architecture.

---

# 77. Secrets Decision

### RDS/Aurora

Often:

```text
Secrets Manager
```

or supported IAM DB authentication.

### DynamoDB

Application normally uses:

```text
IAM role
+
AWS SDK
```

rather than storing a database password.

### ElastiCache

Use supported:

```text
IAM/Auth/RBAC
+
TLS
```

based on chosen deployment/engine.

This changes your credential-management burden dramatically.

---

# 78. Networking Decision

RDS/Aurora:

```text
VPC
private DB subnets
DB-SG
```

ElastiCache:

```text
VPC/private cache
Cache-SG
```

DynamoDB:

```text
regional AWS service endpoint
```

optionally reached privately from a VPC using DynamoDB VPC endpoint capabilities.

Again:

```text
all called "databases"
```

does not mean:

```text
same networking model.
```

---

# 79. Operational Responsibility Comparison

```text
RDS

You think about:
DB instance
storage
connections
queries
parameter groups
maintenance
```

```text
Aurora

You think about:
cluster
writer/readers
endpoints
Serverless/provisioned
DB SQL behavior
```

```text
DynamoDB

You think about:
access patterns
keys
indexes
capacity
hot partitions
```

```text
ElastiCache

You think about:
TTL
memory
shards
replicas
eviction
hit rate
```

Different managed services remove different infrastructure concerns while introducing different architecture concerns.

---

# 80. Anti-Pattern — Choosing by Familiarity

Engineer knows PostgreSQL.

Every workload becomes:

```text
PostgreSQL.
```

Another engineer loves DynamoDB.

Everything becomes:

```text
DynamoDB.
```

Another likes Redis.

Everything becomes:

```text
Redis.
```

This is:

```text
technology-first architecture.
```

Better:

```text
requirement
    ↓
access pattern
    ↓
consistency
    ↓
scale
    ↓
availability
    ↓
cost
    ↓
technology
```

---

# 81. Anti-Pattern — Microservices = One Database Technology

Microservices don't imply:

```text
every service uses DynamoDB
```

or:

```text
every service uses PostgreSQL.
```

Example:

```text
Payment Service
→ Aurora PostgreSQL

Session Service
→ DynamoDB

Recommendation Service
→ DynamoDB + S3

Rate Limit Service
→ ElastiCache

Reporting
→ analytics platform
```

The service boundary allows each workload to select appropriate persistence.

---

# 82. Anti-Pattern — Database Per Feature Without Governance

The opposite extreme:

```text
20 microservices
20 completely different databases
```

creates:

```text
operational skill burden
observability complexity
cost
security complexity
backup complexity
```

Use polyglot persistence intentionally—not randomly.

---

# 83. Migration Decision — RDS → Aurora

Consider migration if your RDS workload needs:

```text
more Aurora-style read scaling

Aurora Serverless

distributed Aurora storage

Global Database

fast cloning
```

But evaluate:

```text
engine compatibility
extensions
SQL behavior
downtime
cost
performance tests
```

before deciding.

Aurora is MySQL/PostgreSQL-compatible, not guaranteed bit-for-bit identical to every behavior/version/plugin in every external engine deployment. ([AWS Documentation][21])

---

# 84. Migration Decision — RDS → DynamoDB

This is not usually:

```text
dump relational tables
       ↓
load DynamoDB
```

and done.

You may need to redesign:

```text
entities
relationships
queries
transactions
indexes
denormalization
```

because DynamoDB modeling starts from access patterns.

Treat it as:

```text
application architecture migration
```

not merely:

```text
database engine migration.
```

---

# 85. Migration Decision — Add ElastiCache

This is often less invasive:

```text
Application
    │
    ▼
existing DB
```

becomes:

```text
Application
   │
   ▼
Cache
   │ miss
   ▼
Existing DB
```

But now you must add:

```text
TTL
invalidation
failure handling
metrics
```

So even “just adding Redis” changes application semantics.

---

# 86. Database Architecture Checklist

Before choosing a database, answer:

```text
DATA
────────────────────────
structured?
relationships?
item/document size?
growth rate?


ACCESS
────────────────────────
lookup patterns?
joins?
ad-hoc queries?
read/write ratio?


CORRECTNESS
────────────────────────
ACID?
strong consistency?
staleness acceptable?


SCALE
────────────────────────
requests/sec?
connections?
data size?
global users?


AVAILABILITY
────────────────────────
Multi-AZ?
Region DR?
RPO?
RTO?


OPERATIONS
────────────────────────
patching?
server sizing?
scaling?
backup?


COST
────────────────────────
compute?
storage?
I/O?
replicas?
engineering effort?
```

Only then select the AWS service.

---

# 87. Full Production Architecture Capstone

Let's design a realistic application:

# `GlobalShop`

Requirements:

```text
5 million users

200k concurrent users

global web traffic

orders/payments strongly relational

shopping carts globally accessible

product catalog read-heavy

images/videos

API rate limiting

session storage

DR

automatic scaling
```

Now solve one data category at a time.

---

# 88. GlobalShop — Object Data

Product images:

```text
images
videos
PDF manuals
```

Use:

```text
S3
+
CloudFront
```

Not:

```text
PostgreSQL bytea
for every 2-GB product video.
```

---

# 89. GlobalShop — Users/Orders/Payments

Data:

```text
Customer
Order
OrderItems
Payment
Invoice
```

Need:

```text
transactions
relationships
constraints
SQL
```

Candidate:

```text
Aurora PostgreSQL
```

Architecture:

```text
               Aurora PostgreSQL

                  Writer AZ-A
                      │
             ┌────────┴────────┐
             ▼                 ▼
          Reader AZ-B       Reader AZ-C
```

Add:

```text
RDS Proxy
```

if application connection scale warrants it.

Aurora's distributed cluster architecture and reader capabilities fit this pattern. ([AWS Documentation][8])

---

# 90. GlobalShop — Shopping Cart

Access:

```text
customerId
   │
   ▼
current cart
```

Potential:

```text
DynamoDB
```

Key:

```text
PK = CUSTOMER#123

SK = CART#ITEM#987
```

Why?

```text
simple known access pattern
huge scale
serverless
```

---

# 91. GlobalShop — Idempotency

Payment API:

```text
Idempotency-Key
```

Use durable:

```text
DynamoDB conditional item
```

rather than cache-only idempotency.

---

# 92. GlobalShop — Product Cache

Aurora contains product master records.

But:

```text
10 million product reads/minute
```

use:

```text
ElastiCache Valkey
```

with:

```text
cache-aside
TTL
event-driven invalidation
```

Now Aurora handles fewer redundant product reads.

---

# 93. GlobalShop — Sessions

If session loss simply forces login again:

```text
ElastiCache
```

can be a strong fit.

If durable sessions across regions are strategically important:

```text
DynamoDB
```

may be attractive.

The difference comes from:

```text
durability + global requirements.
```

---

# 94. GlobalShop — Rate Limiting

Use:

```text
Valkey
```

with:

```text
atomic counters
+
TTL
```

for per-user/API rate-limit state.

---

# 95. GlobalShop — Multi-Region NoSQL

If shopping carts must be writable locally in multiple Regions:

```text
DynamoDB Global Tables
```

could be used.

Choose:

```text
MREC
```

if low-latency multi-active writes with eventual cross-Region consistency fit.

Or evaluate:

```text
MRSC
```

if the application's required Region topology and stronger consistency requirements justify its tradeoffs. ([AWS Documentation][13])

---

# 96. GlobalShop — Relational DR

For orders/payments:

```text
Aurora Global Database
```

can provide secondary Regions for global reads and DR while retaining a primary write Region. Current Aurora Global Database supports up to ten read-only secondary Regions. ([AWS Documentation][12])

---

# 97. GlobalShop Final Data Architecture

```text
                            GLOBAL USERS
                                 │
                                 ▼
                            CloudFront
                                 │
                                 ▼
                               ALB
                                 │
                   ┌─────────────┴─────────────┐
                   ▼                           ▼
                App-A                       App-B
                   │                           │
                   └─────────────┬─────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
          ▼                      ▼                      ▼
     ElastiCache             DynamoDB               RDS Proxy
        Valkey                  │                       │
          │                     │                       ▼
          │                     │                 Aurora PostgreSQL
          │                     │                       │
          │                     │                 Global Database
          │                     │
          │               Global Tables
          │
          ├── sessions
          ├── cache
          ├── rate limits
          └── hot products

DynamoDB
├── carts
├── idempotency
└── workflow state

Aurora
├── users
├── orders
├── payments
└── invoices

S3
├── images
├── exports
└── documents
```

This is a realistic example of **polyglot persistence**.

---

# 98. Terraform Module Architecture

A production repository might be structured:

```text
terraform/
│
├── modules/
│   │
│   ├── vpc/
│   ├── aurora/
│   ├── dynamodb/
│   ├── elasticache/
│   ├── s3/
│   └── security/
│
├── environments/
│   │
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── global/
```

The architecture boundary mirrors the database responsibilities.

---

# 99. Aurora Terraform Concept

```text
module "orders_database"
```

should manage:

```text
cluster
writer/readers
subnet group
security group
parameter group
backup
KMS
monitoring
```

not application tables themselves.

Database schema should normally be managed separately through controlled migration tooling.

---

# 100. DynamoDB Terraform Concept

```text
module "shopping_cart"
```

could manage:

```text
table
PK/SK
GSIs
billing mode
PITR
TTL
KMS
streams
autoscaling
```

The important architecture is in:

```text
key/index design.
```

---

# 101. ElastiCache Terraform Concept

```text
module "application_cache"
```

might choose between:

```text
node-based replication group
```

and:

```text
ElastiCache Serverless.
```

Inputs:

```text
engine
subnets
security groups
KMS
TLS
node/shard topology
```

depending on deployment model. Current ElastiCache supports both node-based and Serverless approaches. ([AWS Documentation][16])

---

# 102. The Ultimate Database Decision Matrix

```text
Need complex SQL / joins?
        │
        YES
        │
        ▼
   RDS / Aurora
        │
        ├── conventional managed relational?
        │       ▼
        │      RDS
        │
        └── Aurora-specific scale/HA/global/serverless?
                ▼
              Aurora


Need predictable massive key-value access?
        │
        YES
        ▼
     DynamoDB


Need temporary hot-data acceleration?
        │
        YES
        ▼
    ElastiCache
```

Then remember:

```text
you can use
ALL OF THEM
in one system.
```

---

# 103. Never-Forget Comparison

```text
RDS
=
MANAGED RELATIONAL DATABASE
```

```text
Aurora
=
CLOUD-NATIVE
MYSQL/POSTGRESQL-COMPATIBLE
RELATIONAL CLUSTER
```

```text
DynamoDB
=
SERVERLESS DISTRIBUTED
KEY-VALUE / DOCUMENT DATABASE
```

```text
ElastiCache
=
MANAGED IN-MEMORY
CACHE / DATA-STRUCTURE LAYER
```

---

# 104. The 25 Database Architecture Rules

1. **Choose the database from the workload, not personal preference.**

2. **Relational relationships and flexible SQL point toward RDS/Aurora.**

3. **Predictable massive key-value access points toward DynamoDB.**

4. **Repeated hot reads point toward ElastiCache.**

5. **RDS Multi-AZ DB instance standby is HA, not read scaling.** ([AWS Documentation][5])

6. **RDS Multi-AZ DB clusters have readable replicas.** ([AWS Documentation][6])

7. **Standard RDS read replicas are asynchronous.** ([AWS Documentation][20])

8. **Aurora separates DB compute from distributed cluster storage.** ([AWS Documentation][8])

9. **Aurora readers scale relational reads.**

10. **Aurora Serverless scales Aurora compute automatically.** ([AWS Documentation][11])

11. **Aurora Global Database normally has one write Region.** ([AWS Documentation][12])

12. **DynamoDB has no DB instance for you to size.**

13. **DynamoDB architecture starts with access patterns and keys.**

14. **DynamoDB Global Tables are multi-active.** ([AWS Documentation][13])

15. **Current Global Tables support MREC and MRSC.** ([AWS Documentation][13])

16. **MRSC requires exactly three Regions.** ([AWS Documentation][15])

17. **ElastiCache usually accelerates authoritative storage rather than replacing it.**

18. **Cache invalidation is part of application correctness.**

19. **Read replicas and caches solve different problems.**

20. **RDS Proxy solves connection pressure—not slow SQL.**

21. **HA is not backup.**

22. **Replication is not historical recovery.**

23. **Always begin DR with RPO and RTO.** ([AWS Documentation][18])

24. **The best architecture can legitimately use several databases.**

25. **Diagnose the bottleneck before adding another AWS service.**

And the most important architecture rule:

```text
DON'T ASK:

"What is the best AWS database?"


ASK:

"What is the best database
FOR THIS ACCESS PATTERN,
CONSISTENCY REQUIREMENT,
SCALE,
FAILURE MODEL
AND BUSINESS CONSTRAINT?"
```

---

# ✅ Lesson 28 — AWS Database Architecture COMPLETE

You have now covered:

```text
✓ relational database fundamentals

✓ Amazon RDS
✓ RDS networking
✓ DB subnet groups
✓ security groups
✓ RDS endpoints
✓ Single-AZ
✓ Multi-AZ DB instances
✓ Multi-AZ DB clusters
✓ read replicas

✓ Amazon Aurora
✓ distributed storage
✓ writer/readers
✓ cluster volume
✓ Aurora endpoints
✓ failover tiers
✓ Serverless v2
✓ Global Database
✓ cloning
✓ RDS Proxy

✓ backups
✓ PITR
✓ snapshots
✓ RPO / RTO
✓ KMS
✓ Secrets Manager
✓ IAM DB auth
✓ TLS
✓ parameter groups
✓ upgrades
✓ Blue/Green

✓ CloudWatch
✓ Database Insights
✓ DB load
✓ waits
✓ locks
✓ deadlocks
✓ connection exhaustion
✓ I/O troubleshooting
✓ failover testing

✓ DynamoDB
✓ PK / SK
✓ Query / Scan
✓ GSIs / LSIs
✓ hot partitions
✓ RCUs / WCUs
✓ conditional writes
✓ transactions
✓ TTL
✓ Streams
✓ Global Tables
✓ MREC / MRSC
✓ DAX
✓ PITR

✓ ElastiCache
✓ Valkey
✓ Redis OSS
✓ Memcached
✓ cache-aside
✓ invalidation
✓ TTL
✓ stampedes
✓ evictions
✓ sessions
✓ counters
✓ rate limiting
✓ replication
✓ Multi-AZ
✓ shards
✓ Serverless
✓ Global Datastore

✓ database decision framework
✓ SQL vs NoSQL
✓ cache vs replica
✓ connection scaling
✓ server sizing
✓ DR selection
✓ polyglot persistence
✓ production architecture
✓ SAA-C03 scenarios
✓ DOP-C02 troubleshooting
✓ Terraform module design
✓ final database capstone
```

You should now be able to look at:

```text
"database requirement"
```

and mentally turn it into:

```text
DATA MODEL
    ↓
ACCESS PATTERNS
    ↓
CONSISTENCY
    ↓
TRANSACTIONS
    ↓
READ/WRITE RATIO
    ↓
SCALE
    ↓
HA
    ↓
RPO/RTO
    ↓
OPERATIONS
    ↓
COST
    ↓
DATABASE CHOICE
```

That is the database decision-making mindset you need for **SAA-C03, DOP-C02, real AWS architecture reviews, interviews, and production incidents**.

# Next — Lesson 29

## **Amazon Route 53 & DNS Architecture — From DNS Fundamentals to Production Traffic Routing**

Next we'll move from:

```text
"Where does my application store data?"
```

to:

```text
"How does a user find my application
in the first place?"
```

We'll build DNS from zero:

```text
Browser
   │
   ▼
www.example.com
   │
   ▼
DNS Resolver
   │
   ▼
Root DNS
   │
   ▼
TLD (.com)
   │
   ▼
Authoritative DNS
   │
   ▼
Route 53 Hosted Zone
   │
   ▼
A / AAAA / CNAME / Alias
   │
   ▼
CloudFront / ALB / EC2 / API
```

and then go deep into **recursive vs authoritative DNS, TTL, DNS caching, hosted zones, registrar vs Route 53, NS/SOA records, A/AAAA/CNAME/Alias, apex domains, MX/TXT/CAA, public/private hosted zones, split-horizon DNS, Resolver inbound/outbound endpoints, hybrid DNS with on-premises networks, weighted routing, latency routing, failover routing, geolocation, geoproximity, multivalue answers, health checks, DNSSEC, CloudFront/ALB aliases, Terraform, DNS troubleshooting, and production DR designs**.

[1]: https://docs.aws.amazon.com/databases-on-aws-how-to-choose/?utm_source=chatgpt.com "Choosing an AWS database service"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html?utm_source=chatgpt.com "What is Amazon Relational Database Service (Amazon RDS)?"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/creating-elasticache-cluster-with-RDS-settings.html?utm_source=chatgpt.com "Creating an Amazon ElastiCache cache using Aurora DB ..."
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/gettingstartedguide/scaling-ha.html?utm_source=chatgpt.com "Scaling and high availability in Amazon RDS"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html?utm_source=chatgpt.com "Multi-AZ DB instance deployments for Amazon RDS"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html?utm_source=chatgpt.com "Multi-AZ DB cluster deployments for Amazon RDS"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-create-instance-read-replica.html?utm_source=chatgpt.com "Creating a DB instance read replica from a Multi-AZ DB cluster"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.AuroraHighAvailability.html?utm_source=chatgpt.com "High availability for Amazon Aurora"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Replication.html?utm_source=chatgpt.com "Replication with Amazon Aurora"
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Integrating.AutoScaling.html?utm_source=chatgpt.com "Amazon Aurora Auto Scaling with Aurora Replicas"
[11]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html?utm_source=chatgpt.com "Using Aurora serverless"
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[13]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication"
[14]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables.tutorial.html?utm_source=chatgpt.com "Tutorials: Creating global tables - Amazon DynamoDB"
[15]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[16]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.corecomponents.html?utm_source=chatgpt.com "How ElastiCache works"
[17]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.deployment.html?utm_source=chatgpt.com "Choosing between deployment options"
[18]: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-database-disaster-recovery/choosing-database.html?utm_source=chatgpt.com "Choosing the right database for your RTO and RPO ..."
[19]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Redis-Global-Datastores-Getting-Started.html?utm_source=chatgpt.com "Prerequisites and limitations - Amazon ElastiCache"
[20]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html?utm_source=chatgpt.com "Working with DB instance read replicas"
[21]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html?utm_source=chatgpt.com "What is Amazon Aurora? - Amazon Aurora"
