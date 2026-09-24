# AWS Masterclass — Lesson 28 Part 2

# Amazon Aurora Architecture — Writer, Readers, Distributed Storage, Serverless v2 & Global Database

The question we're answering is:

> **Why would I choose Amazon Aurora instead of simply running RDS PostgreSQL or RDS MySQL Multi-AZ?**

The answer begins with architecture.

A normal relational mental model is:

```text
Application
    │
    ▼
Database instance
    │
    ▼
Database storage
```

Aurora separates the system much more aggressively:

```text
                       AURORA CLUSTER
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
           WRITER         READER-1       READER-2
          Compute          Compute         Compute
              \              |              /
               \             |             /
                └────────────┼─────────────┘
                             │
                             ▼
                    SHARED CLUSTER VOLUME
                             │
                    ┌────────┼────────┐
                    ▼        ▼        ▼
                   AZ-A     AZ-B     AZ-C
                    │        │        │
                   copies   copies   copies
```

Aurora synchronously replicates database data across **six storage nodes spanning three Availability Zones**. This distributed storage exists independently of how many reader DB instances you create. ([AWS Documentation][1])

That one design decision explains much of Aurora.

---

# 1. What Is Amazon Aurora?

Aurora is an AWS-built relational database engine compatible with:

```text
MySQL
```

and:

```text
PostgreSQL
```

protocols and ecosystems.

You don't choose:

```text
Aurora SQL
```

as a new application language.

Instead you choose:

```text
Aurora MySQL-Compatible
```

or:

```text
Aurora PostgreSQL-Compatible
```

AWS has customized those engines to work with Aurora's distributed storage system. ([AWS Documentation][2])

So applications can often continue using familiar:

```text
MySQL drivers
PostgreSQL drivers

SQL
JDBC
ODBC
ORMs
```

subject to Aurora compatibility and feature differences.

---

# 2. The Most Important Aurora Idea

With many conventional database architectures, you mentally connect:

```text
DB server
+
its storage
```

very tightly.

Aurora separates:

```text
COMPUTE
```

from:

```text
DISTRIBUTED STORAGE
```

much more strongly.

Think:

```text
                 COMPUTE LAYER

           Writer          Reader
              │               │
              └───────┬───────┘
                      │
                      ▼
                STORAGE LAYER
                      │
          six copies across 3 AZs
```

This gives Aurora some unusual capabilities:

```text
fast failover
multiple readers
low replica lag
automatic storage growth
fast cloning
cross-Region storage replication
```

that we'll dissect individually.

---

# 3. Aurora Cluster Volume

Every Aurora DB cluster has a:

# Cluster Volume

The writer and Aurora Replicas connect to that distributed cluster storage.

```text
                Writer
                  │
                  │
        ┌─────────┴─────────┐
        │                   │
     Reader 1            Reader 2
        │                   │
        └─────────┬─────────┘
                  │
                  ▼
          Aurora Cluster Volume
```

The readers are not each maintaining a conventional full independent disk copy through standard database-engine replication. Aurora's architecture moves much of the replication work into the storage layer. ([AWS Documentation][3])

That is a major distinction from a conventional RDS read-replica architecture.

---

# 4. Six Storage Copies Across Three AZs

Conceptually:

```text
                   Aurora storage
                         │
         ┌───────────────┼───────────────┐
         │               │               │
       AZ-A            AZ-B            AZ-C
         │               │               │
      Copy 1           Copy 3          Copy 5
      Copy 2           Copy 4          Copy 6
```

Aurora synchronously replicates writes across these distributed storage nodes. AWS describes the storage as capable of tolerating loss of up to two data copies without losing write availability and up to three copies without losing read availability. ([AWS Documentation][4])

You don't configure:

```text
replica disk 1
replica disk 2
replica disk 3
```

yourself.

Aurora manages the storage system.

---

# 5. Important: Storage HA Exists Even With One DB Instance

Suppose your Aurora cluster contains only:

```text
Writer
```

and no Aurora Replica.

You might picture:

```text
one EC2-like DB server
+
one AZ of storage
```

Wrong.

The **compute** might only have one active DB instance, but the Aurora cluster's data is still distributed across three AZs. ([AWS Documentation][1])

So distinguish:

```text
STORAGE HA
```

from:

```text
COMPUTE HA
```

This distinction is essential.

---

# 6. Storage HA Does Not Mean Compute HA

Suppose:

```text
Aurora Cluster

Writer only
```

Storage:

```text
AZ-A
AZ-B
AZ-C
```

is protected.

But if the writer DB instance fails:

```text
Writer
   X
```

there is no existing Aurora Replica ready to be promoted.

Aurora must recreate/recover compute instead.

For stronger compute availability:

```text
Writer
+
at least one Reader in another AZ
```

is a much stronger production design.

AWS recommends locating Aurora Replicas across AZs so one can be promoted if the writer fails. ([AWS Documentation][5])

---

# 7. The Aurora Writer

Every normal Aurora cluster has one:

# Writer DB instance

```text
Application
     │
     ├── INSERT
     ├── UPDATE
     ├── DELETE
     ├── DDL
     └── consistency-sensitive SELECT
             │
             ▼
           Writer
```

The writer handles database modifications.

Your application normally connects using the:

```text
cluster endpoint
```

sometimes called the writer endpoint in architectural discussions.

Example conceptual hostname:

```text
prod.cluster-xxxx.ap-south-1.rds.amazonaws.com
```

The cluster endpoint always targets the current primary/writer. ([AWS Documentation][6])

---

# 8. Never Connect the Application to the Writer's Instance Endpoint Unless You Intend To

Aurora gives each DB instance its own endpoint.

Example:

```text
writer-instance.xxxx.rds.amazonaws.com
```

But for general application writes, use:

```text
CLUSTER ENDPOINT
```

because after failover:

```text
old writer
   X

Reader-1 promoted
```

the cluster endpoint follows the new writer. Instance endpoints instead continue referring to particular DB instances. ([AWS Documentation][7])

### Never forget

```text
Cluster endpoint
=
ROLE-oriented
"give me the current writer"
```

```text
Instance endpoint
=
SERVER-oriented
"give me this exact DB instance"
```

---

# 9. Aurora Replicas

You can add up to:

```text
15 Aurora Replicas
```

to a normal Aurora cluster in addition to the primary writer. ([AWS Documentation][5])

Architecture:

```text
                         Writer
                           │
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
       Reader 1         Reader 2          Reader 3
```

They serve:

```text
SELECT
reporting
read-heavy traffic
```

and can also serve as:

```text
FAILOVER TARGETS
```

---

# 10. Aurora Reader Replication Is Different From Standard RDS Read Replicas

Normal RDS concept:

```text
Primary DB
    │
    │ DB-engine replication
    ▼
Read Replica
    │
    └── its own database storage
```

Aurora:

```text
Writer
  │
  ├───────── Reader 1
  ├───────── Reader 2
  └───────── Reader 3
        │
        ▼
shared distributed cluster volume
```

Aurora replicas typically have much lower lag because much of the replication architecture is built into Aurora's storage system. AWS says Aurora Replica lag is usually **well below 100 ms**, though it can increase under heavy write workloads. ([AWS Documentation][3])

That is a major Aurora advantage for read-heavy workloads.

---

# 11. Reader Endpoint

Aurora provides:

```text
Reader Endpoint
```

Example:

```text
prod.cluster-ro-xxxx.ap-south-1.rds.amazonaws.com
```

Use:

```text
READ queries
      │
      ▼
Reader endpoint
      │
      ├── Reader 1
      ├── Reader 2
      └── Reader 3
```

The reader endpoint distributes **new database connections** across available Aurora Replicas. ([AWS Documentation][8])

Important:

```text
Reader Endpoint
does not load-balance
every individual SQL query.
```

It balances connections.

---

# 12. Connection Balancing ≠ Query Balancing

Suppose your application opens:

```text
Connection A
```

through the reader endpoint.

Aurora selects:

```text
Reader 1
```

Then:

```text
SELECT 1
SELECT 2
SELECT 3
SELECT 4
```

on that same connection continue using Reader 1.

The reader endpoint doesn't do:

```text
SELECT 1 → Reader 1
SELECT 2 → Reader 2
SELECT 3 → Reader 3
```

for every statement. AWS explicitly documents reader-endpoint balancing at the connection level. ([AWS Documentation][8])

This matters enormously with long-lived application connection pools.

---

# 13. Reader Endpoint Without Readers

Interesting edge case.

Suppose:

```text
Aurora cluster
Writer only
No readers
```

The reader endpoint can connect to the writer when no Aurora Replica exists. ([AWS Documentation][8])

So:

```text
Reader endpoint exists
```

doesn't prove:

```text
read capacity is actually separated.
```

Always inspect cluster topology.

---

# 14. Aurora Failover

Normal:

```text
                     cluster endpoint
                           │
                           ▼
                        Writer
                           │
                  ┌────────┴────────┐
                  ▼                 ▼
              Reader 1          Reader 2
```

Failure:

```text
Writer
   X
```

Aurora chooses an eligible replica:

```text
Reader 1
   │
   ▼
PROMOTED
   │
   ▼
New Writer
```

Then:

```text
cluster endpoint
```

is updated to point at the new writer. Aurora automatically fails over to an Aurora Replica when the writer becomes unavailable. ([AWS Documentation][5])

---

# 15. Aurora Failover Priority

You can control which reader should become writer first.

Promotion tiers:

```text
0
1
2
...
15
```

where:

```text
0
=
highest promotion priority
```

and:

```text
15
=
lowest
```

AWS uses these tiers when selecting failover candidates. ([AWS Documentation][9])

Example:

```text
Writer

Reader A
db.r8g.large
Tier 0

Reader B
db.r8g.large
Tier 1

Reader C
smaller reporting instance
Tier 15
```

If writer fails:

```text
Aurora first prefers
Reader A
```

rather than your small reporting reader.

---

# 16. Why Failover Tiers Matter

Imagine:

```text
Writer:
db.r8g.4xlarge
```

Reader A:

```text
db.r8g.4xlarge
```

Reader B:

```text
db.r8g.large
```

If Reader B became writer during peak traffic:

```text
production load
       │
       ▼
much smaller compute
       │
       ▼
CPU/memory pressure
```

Availability technically recovered—

but application performance might collapse.

Use promotion tiers strategically.

---

# 17. Aurora Endpoint Model

You should know four endpoint types:

```text
1. Cluster endpoint
2. Reader endpoint
3. Instance endpoint
4. Custom endpoint
```

Architecture:

```text
                    Aurora Cluster

Cluster Endpoint ───────▶ WRITER


Reader Endpoint ─┬──────▶ Reader A
                 ├──────▶ Reader B
                 └──────▶ Reader C


Instance Endpoint ──────▶ exact instance


Custom Endpoint ────────▶ selected group
```

Aurora recommends cluster and reader endpoints for normal highly available application connectivity because those endpoints adapt as DB instance roles change. ([AWS Documentation][7])

---

# 18. Custom Endpoints

Suppose:

```text
Readers:

R1 = huge memory
R2 = huge memory
R3 = smaller
R4 = smaller
```

Business intelligence needs only:

```text
R1
R2
```

Create:

```text
analytics endpoint
```

that targets those instances.

Application traffic:

```text
API reads
    │
    ▼
standard reader endpoint


Heavy BI
    │
    ▼
analytics custom endpoint
    │
    ├── R1
    └── R2
```

Aurora allows up to five custom endpoints per provisioned or Serverless cluster and uses them to connection-balance across a selected subset of DB instances. ([AWS Documentation][10])

---

# 19. Aurora Storage Automatically Grows

This is another major architectural difference from ordinary RDS allocated-storage thinking.

You don't say:

```text
Create Aurora
with exactly 500 GiB
```

and later manually grow that cluster volume the way you normally reason about allocated RDS storage.

Aurora storage automatically grows as database data grows. Depending on the engine/version, current Aurora cluster volumes support maximum sizes of **128 TiB or 256 TiB**, with newer supported versions reaching 256 TiB. ([AWS Documentation][11])

Mental model:

```text
Data:
1 TB
 ↓
5 TB
 ↓
20 TB
 ↓
100 TB

Aurora cluster storage
expands automatically
```

---

# 20. Very Important 2026 Update — 256 TiB

Old Aurora material often says:

```text
maximum Aurora storage
=
128 TiB
```

That is no longer universally current.

Current AWS size limits include **256 TiB** for newer engine versions—for example newer Aurora PostgreSQL releases and Aurora MySQL 3.10+—while earlier supported versions can remain at 128 TiB. ([AWS Documentation][12])

So don't memorize:

```text
Aurora always = 128 TiB
```

Say:

```text
Aurora maximum volume size
depends on engine version;
newer versions can reach 256 TiB.
```

---

# 21. Storage Can Also Shrink When Data Is Removed

Another improvement in modern Aurora storage behavior is that allocated cluster-volume space can decrease when substantial data is removed, such as when tables or databases are dropped. ([AWS Documentation][11])

This differs from the older mental model that Aurora's high-water-mark allocated storage could only ever grow.

Again:

```text
old AWS study notes
can become outdated.
```

---

# 22. Compute Scaling and Storage Scaling Are Independent

Aurora might have:

```text
Storage:
50 TB
```

but compute:

```text
Writer:
db.r8g.large
```

That does not mean:

```text
50 TB storage
requires massive compute
```

or vice versa.

Think independently:

```text
                    AURORA

            COMPUTE        STORAGE
               │              │
               ▼              ▼
             CPU/RAM         data size
             readers         automatic growth
             Serverless
```

This separation is foundational to Aurora.

---

# 23. Aurora Auto Scaling for Readers

Suppose:

```text
Normal:
2 readers
```

Traffic spike:

```text
reader CPU ↑
connections ↑
```

Aurora Auto Scaling can add Aurora Replicas based on scaling policies. New auto-scaled replicas normally use the writer's instance class and default to promotion tier 15. ([AWS Documentation][13])

Conceptually:

```text
Reader load low

R1
R2


Reader load high

R1
R2
R3
R4
```

This scales:

```text
READ CAPACITY
```

not writer capacity.

---

# 24. Writer Scaling Is Still a Different Problem

If:

```text
Writer CPU = 95%
```

because your workload is:

```text
90% writes
```

adding ten Aurora Replicas will not magically distribute ordinary relational writes across ten independent writers.

You still need to think about:

```text
larger writer
query optimization
schema/index design
connection efficiency
application architecture
Serverless scaling
specialized Aurora capabilities
possibly sharding/Limitless for suitable workloads
```

Readers primarily solve read pressure.

---

# 25. Aurora Serverless v2

Now we make the **compute** layer elastic.

Provisioned Aurora:

```text
Writer:
db.r8g.large

Reader:
db.r8g.large
```

You choose fixed instance classes.

Aurora Serverless v2:

```text
Writer / Reader
      │
      ▼
Aurora Capacity Units
      │
capacity scales
up and down
```

Current Aurora Serverless capacity can range as high as **256 ACUs**, with capacity changing in increments of 0.5 ACU; supported minimums depend on engine/version and can be as low as 0 for versions that support automatic pause. ([AWS Documentation][14])

---

# 26. ACU — Aurora Capacity Unit

ACU means:

# Aurora Capacity Unit

AWS currently describes one ACU as approximately:

```text
2 GiB RAM
+
corresponding CPU/network capacity
```

([AWS Documentation][14])

So:

```text
8 ACU
```

conceptually corresponds to approximately:

```text
16 GiB RAM
```

plus associated compute/network capacity.

Don't treat ACU as:

```text
exactly X vCPU
```

It's a bundled Aurora capacity abstraction.

---

# 27. Define Min and Max Capacity

Example:

```text
minimum:
2 ACU

maximum:
32 ACU
```

Then:

```text
quiet workload
      │
      ▼
~2 ACU
```

traffic increases:

```text
2
4
7.5
12
20
32
```

as workload requires, within your configured range.

Aurora Serverless v2 can make granular capacity changes in 0.5-ACU increments and typically scales without pausing ordinary transaction processing. ([AWS Documentation][15])

---

# 28. Serverless Does Not Mean “No Server Exists”

This is an important AWS vocabulary lesson.

```text
Serverless
```

does not mean:

```text
there is literally no database compute.
```

It means AWS handles much more of:

```text
capacity provisioning
scaling
resource adjustment
```

without you choosing a fixed server class for each workload level.

Your database still has:

```text
connections
memory
CPU
transactions
indexes
locks
queries
```

and can still be overloaded.

---

# 29. Aurora Serverless v2 Can Scale to Zero — Where Supported

Modern Aurora Serverless v2 can support:

```text
minimum ACU = 0
```

on supported engine versions.

When no user activity exists for the configured period:

```text
DB compute
      │
      ▼
0 ACU
      │
      ▼
paused
```

and you aren't charged for instance capacity while paused. ([AWS Documentation][16])

This can be particularly useful for:

```text
development environments
test databases
intermittent workloads
low-frequency internal applications
```

---

# 30. Scale-to-Zero Has a Cold-Resume Tradeoff

If a Serverless v2 instance remains paused for more than 24 hours, Aurora can place it into a deeper sleep state. AWS notes that resume can then take **30 seconds or longer**. ([AWS Documentation][16])

Therefore:

```text
Scale to zero
```

is not automatically correct for:

```text
latency-critical
24×7 production API
```

where the first request must complete immediately.

Architecture always means tradeoffs.

---

# 31. Serverless v2 High Availability

You can also run:

```text
Serverless writer
+
Serverless reader
```

across AZs.

Aurora can align reader scaling behavior with the writer for readers in high failover-priority tiers so the failover target has appropriate capacity if promoted. ([AWS Documentation][17])

Architecture:

```text
             AZ-A                     AZ-B

        Serverless Writer        Serverless Reader
          4 → 20 ACU             ready for failover
               \                       /
                \                     /
                 Shared Aurora Storage
```

This gives:

```text
elastic compute
+
Multi-AZ compute HA
```

when configured appropriately.

---

# 32. When Serverless v2 Is Excellent

Good candidates include:

```text
unpredictable traffic
rapid workload variation
many tenant databases
dev/test
intermittent workloads
applications difficult to size
```

A fixed instance may force you to choose:

```text
too small
→ performance issue

or

too large
→ wasted capacity
```

Serverless can narrow that mismatch.

---

# 33. When Provisioned Aurora Can Still Make Sense

If workload is:

```text
24×7
stable
predictable
```

and capacity requirements are well understood, provisioned instances can still be perfectly sensible.

Don't interpret:

```text
serverless is newer
```

as:

```text
serverless must always be better.
```

Pick based on:

```text
utilization pattern
cost model
latency
availability
capacity predictability
operational complexity
```

---

# 34. Aurora Global Database

Now we leave one Region.

Primary:

```text
ap-south-1
Mumbai
```

Secondary:

```text
ap-southeast-1
Singapore
```

Architecture:

```text
                   Aurora Global Database

                 PRIMARY REGION
                   ap-south-1
                       │
                Aurora Cluster
                    Writer
                       │
             storage-level replication
                       │
                       ▼
                SECONDARY REGION
                ap-southeast-1
                       │
                Aurora Cluster
                    Readers
```

Aurora Global Database uses dedicated cross-Region infrastructure and AWS says cross-Region replication latency is **typically under one second**. ([AWS Documentation][18])

---

# 35. Global Database Is Different From Normal Cross-Region Read Replicas

Traditional engine-level replication concept:

```text
Database engine
     │
     │ binlog/WAL
     ▼
remote database
```

Aurora Global Database moves cross-Region replication into Aurora's storage infrastructure, reducing work on the primary database engine. ([AWS Documentation][19])

Think:

```text
Application writes
      │
      ▼
Aurora primary
      │
      ▼
distributed Aurora storage replication
      │
      ▼
secondary Region
```

This is one of Aurora's flagship capabilities.

---

# 36. Global Database Is Primarily One Writer Region

Normal architecture:

```text
Mumbai
PRIMARY
READ + WRITE
```

Other Regions:

```text
Singapore
READ

Ireland
READ
```

So:

```text
Aurora Global Database
```

should not be confused with:

```text
multi-Region independently writable
active-active database
```

for normal usage.

The primary cluster is the location where writes are committed; secondaries receive replicated changes. ([AWS Documentation][20])

---

# 37. Global Write Forwarding

But Aurora has an advanced capability:

# Global Write Forwarding

Suppose the Singapore application connects locally:

```text
Singapore App
     │
     ▼
Singapore Aurora Secondary
```

and sends:

```sql
UPDATE orders ...
```

With global write forwarding enabled:

```text
Singapore Secondary
       │
       │ forwards write
       ▼
Mumbai Primary Writer
       │
       ▼
COMMIT
       │
       ▼
Aurora replication
       │
       ▼
Singapore receives change
```

Aurora handles the forwarding and transaction/session context so applications don't have to manually send every write to a primary-Region endpoint. ([AWS Documentation][20])

---

# 38. But Write Forwarding Does Not Create Multiple Independent Writers

This:

```text
Singapore sends UPDATE
```

does not mean:

```text
Singapore is an independent primary writer.
```

The actual data modification is still performed at the primary cluster and then replicated back to secondary Regions. ([AWS Documentation][20])

Mental model:

```text
WRITE FORWARDING
=
local endpoint convenience

NOT

multi-master commit architecture
```

---

# 39. Consistency Still Matters With Global Write Forwarding

Suppose Singapore sends:

```text
UPDATE balance=900
```

to primary through forwarding.

Immediately afterward, a local Singapore read might still observe replicated state depending on the configured read-consistency mode and replication timing. Aurora provides consistency controls for write-forwarding scenarios; for example, eventual consistency may return older data before the forwarded write has replicated back. ([AWS Documentation][21])

So distributed-database questions return:

```text
latency
consistency
RPO
```

You never escape physics.

---

# 40. Aurora Global Database DR

Normal:

```text
Mumbai
PRIMARY

Singapore
SECONDARY
```

Regional disaster:

```text
Mumbai
   X
```

You can perform a cross-Region failover so an appropriate secondary becomes the new primary. AWS currently recommends **managed failover** for disaster recovery when available; manual failover remains an alternative for cases where managed failover can't be used. ([AWS Documentation][22])

Architecture:

```text
Before

Mumbai
PRIMARY

Singapore
SECONDARY


After DR failover

Mumbai
unavailable

Singapore
PRIMARY
```

---

# 41. Switchover vs Failover

These terms matter.

### Switchover

Use when:

```text
all Regions healthy
```

and you deliberately move primary responsibility.

Example:

```text
planned Region migration
DR test
maintenance strategy
```

### Failover

Use when:

```text
primary Region unavailable/unhealthy
```

for disaster recovery.

AWS explicitly separates planned Global Database switchovers from unplanned failovers. ([AWS Documentation][22])

---

# 42. Global Database Is About RPO and RTO

Don't say:

> “We have Aurora Global Database, so DR is solved.”

Measure:

```text
RPO
=
how much recent data could be lost?
```

and:

```text
RTO
=
how long to restore service?
```

Aurora exposes metrics such as:

```text
AuroraGlobalDBReplicationLag
```

and RPO lag for Global Database monitoring. ([AWS Documentation][23])

Replication being:

```text
typically <1 second
```

does not mean:

```text
guaranteed zero data loss
```

for every unplanned failure.

---

# 43. RDS Proxy + Aurora

Remember our problem:

```text
ASG/Lambda scales rapidly
      │
      ▼
10,000 application connections
      │
      ▼
Aurora
```

A relational DB can spend large amounts of:

```text
memory
CPU
process/thread resources
authentication overhead
```

handling connection churn.

RDS Proxy adds:

```text
Application connections
       │
       ▼
    RDS Proxy
       │
       │ pooled database connections
       ▼
     Aurora
```

RDS Proxy maintains a connection pool and reuses database connections, helping protect Aurora from connection storms. ([AWS Documentation][24])

---

# 44. Classic Serverless Connection Storm

Imagine Lambda:

```text
0 functions
   ↓
5,000 concurrent invocations
```

Each invocation:

```text
connect DB
query
disconnect
```

Result:

```text
Aurora
      │
      ▼
connection creation storm
```

With Proxy:

```text
5,000 Lambda clients
        │
        ▼
      RDS Proxy
        │
     connection pool
        │
        ▼
      Aurora
```

This can dramatically reduce backend connection churn. AWS specifically calls Lambda a strong RDS Proxy use case because of frequent short-lived database connections. ([AWS Documentation][25])

---

# 45. RDS Proxy Also Helps Failover

Aurora failover normally involves:

```text
writer failure
      ↓
reader promotion
      ↓
DNS endpoint changes
      ↓
applications reconnect
```

RDS Proxy understands database topology and can route connections to the new writer while avoiding some DNS-related failover delays. AWS says RDS Proxy can reduce failover times by up to **66%** for Aurora Multi-AZ databases in applicable scenarios. ([AWS Documentation][25])

That's especially useful for applications with:

```text
bad DNS caching
large connection pools
high connection churn
```

---

# 46. But Proxy Is Not Magic

Some database session behavior causes:

# Connection Pinning

Meaning:

```text
client A
must remain bound to
backend DB connection X
```

instead of the backend connection being freely reusable.

If much of your workload becomes pinned:

```text
connection pooling efficiency ↓
```

AWS recommends minimizing session state patterns that cause excessive pinning. ([AWS Documentation][26])

So again:

```text
adding AWS service
≠
fixing bad application connection behavior.
```

---

# 47. Aurora Backups

Aurora continuously backs up cluster data and supports automated backups with a retention period currently configurable from:

```text
1–35 days
```

([AWS Documentation][27])

Mental model:

```text
Aurora
   │
   ├── continuous automated backups
   │
   ├── PITR
   │
   └── manual snapshots
```

Because backups are continuous/incremental, you don't normally design a cron job like:

```bash
pg_dump entire production DB
every five minutes
```

as your primary managed RDS recovery mechanism.

---

# 48. Point-in-Time Recovery — PITR

Suppose:

```text
12:03
DB correct

12:04
bad migration

12:05
10 million rows corrupted
```

You want:

```text
12:03:30
```

not merely:

```text
last nightly snapshot
```

Aurora can restore the DB cluster to a chosen point within the configured automated-backup retention window. ([AWS Documentation][28])

Conceptually:

```text
Continuous backup history
        │
        ├── 12:00
        ├── 12:01
        ├── 12:02
        ├── 12:03 ← restore
        ├── 12:04 bad
        └── 12:05
```

---

# 49. PITR Does Not Rewind the Existing Production Cluster In Place

Think:

```text
Production cluster
       │
       │ restore to 12:03
       ▼
NEW restored cluster
```

not:

```text
production database clock
magically rewinds.
```

A restore produces another DB cluster that you validate and then use according to your recovery process. ([AWS Documentation][28])

That gives you the chance to:

```text
verify data
compare corruption
copy missing records
switch application
```

instead of destructively modifying the existing environment.

---

# 50. Manual Snapshots

You can also create:

```text
manual DB cluster snapshot
```

for:

```text
release checkpoints
major upgrades
migration safety
longer-term retention
```

Snapshot copies can be made:

```text
same Region
cross-Region
cross-account
```

subject to encryption/share rules. ([AWS Documentation][29])

Again:

```text
HA
≠
backup
```

The six-copy Aurora storage architecture protects availability, but it is not a historical recovery system for:

```text
DROP TABLE customers;
```

---

# 51. Aurora Fast Cloning

Now one of Aurora's coolest features.

Suppose production is:

```text
20 TB
```

and you need:

```text
development clone
```

Traditional thinking:

```text
snapshot
      ↓
restore 20 TB copy
      ↓
wait/pay for full duplicate
```

Aurora supports copy-on-write database cloning.

Initially:

```text
Production
     │
     ├──────── shared unchanged storage
     │
Development clone
```

Aurora only allocates additional storage as either source or clone modifies data. ([AWS Documentation][30])

---

# 52. Copy-on-Write Mental Model

Initially:

```text
Block A
Block B
Block C
Block D

      │
      ├── Production
      └── Clone
```

Clone modifies B:

```text
Original B
   │
   └── Production

New B'
   │
   └── Clone
```

Unchanged blocks remain shared.

That makes initial cloning:

```text
FAST
+
storage-efficient
```

compared with copying the entire database immediately. ([AWS Documentation][30])

---

# 53. Great Clone Use Cases

Think:

```text
production troubleshooting

testing schema changes

QA

analytics experiments

major-version upgrade preparation

development
```

Aurora even supports cross-VPC and cross-account cloning patterns under supported configurations. ([AWS Documentation][31])

But remember:

```text
clone production data
```

can introduce:

```text
PII
secrets
customer data
compliance exposure
```

into dev.

Always sanitize/protect non-production access appropriately.

---

# 54. Blue/Green Deployments

Suppose current production is:

```text
BLUE

Aurora PostgreSQL vX
```

You want:

```text
GREEN

new engine version
new parameters
schema changes
```

Architecture:

```text
                     Production writes
                           │
                           ▼
                         BLUE
                           │
                      replication
                           │
                           ▼
                         GREEN
                           │
                         test
                           │
                           ▼
                       switchover
```

Aurora currently supports Blue/Green Deployments for **Aurora MySQL, Aurora PostgreSQL, and Aurora Global Database** subject to engine/version feature support. ([AWS Documentation][32])

---

# 55. Why Blue/Green Is Valuable

Instead of:

```text
take production down

upgrade in place

hope it works
```

you can:

```text
create green environment
        ↓
perform changes
        ↓
test
        ↓
synchronize
        ↓
controlled switchover
```

AWS recommends thoroughly testing the green environment and avoiding unnecessary writes there before switchover because writes can introduce replication conflicts. ([AWS Documentation][33])

This is much closer to modern deployment engineering.

---

# 56. RDS Proxy + Blue/Green

A very current capability is that RDS Proxy can work with Aurora Blue/Green Deployments to reduce switchover disruption by redirecting connections toward the green environment once it becomes production, reducing reliance on DNS propagation. ([AWS Documentation][34])

Architecture:

```text
Application
     │
     ▼
RDS Proxy
     │
     ▼
BLUE

switch

Application
     │
     ▼
same Proxy
     │
     ▼
GREEN
```

This further separates:

```text
application connection endpoint
```

from:

```text
physical database deployment
```

---

# 57. Terraform — Provisioned Aurora Cluster

Simplified PostgreSQL example:

```hcl
resource "aws_rds_cluster" "app" {
  cluster_identifier = "prod-app"

  engine      = "aurora-postgresql"
  engine_mode = "provisioned"

  database_name   = "appdb"
  master_username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.db.name

  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  backup_retention_period = 7

  storage_encrypted = true

  deletion_protection = true

  skip_final_snapshot = false
}
```

Aurora clusters are managed using Terraform's `aws_rds_cluster` resource. ([Terraform Registry][35])

Notice:

```text
no allocated_storage = 500
```

in the normal Aurora cluster model.

Aurora cluster storage handles growth independently.

---

# 58. Terraform — Aurora Instances

Compute is separate:

```hcl
resource "aws_rds_cluster_instance" "writer" {
  identifier = "prod-app-writer"

  cluster_identifier = aws_rds_cluster.app.id

  instance_class = "db.r7g.large"

  engine = aws_rds_cluster.app.engine
}

resource "aws_rds_cluster_instance" "reader" {
  count = 2

  identifier = "prod-app-reader-${count.index + 1}"

  cluster_identifier = aws_rds_cluster.app.id

  instance_class = "db.r7g.large"

  engine = aws_rds_cluster.app.engine

  promotion_tier = count.index
}
```

Terraform's `aws_rds_cluster_instance` resource represents the individual Aurora compute instances attached to a cluster. ([Terraform Registry][36])

Now the architecture is obvious:

```text
aws_rds_cluster
=
database/storage cluster


aws_rds_cluster_instance
=
compute
```

---

# 59. Terraform — Aurora Serverless v2

Conceptually:

```hcl
resource "aws_rds_cluster" "serverless" {
  cluster_identifier = "app-serverless"

  engine      = "aurora-postgresql"
  engine_mode = "provisioned"

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 32
  }

  storage_encrypted = true
}
```

Then:

```hcl
resource "aws_rds_cluster_instance" "serverless_writer" {
  cluster_identifier =
    aws_rds_cluster.serverless.id

  engine =
    aws_rds_cluster.serverless.engine

  instance_class = "db.serverless"
}
```

Terraform requires the Serverless v2 scaling configuration on the cluster and `db.serverless` for Serverless v2 cluster instances. ([Terraform Registry][35])

The exact supported min/max depends on the selected Aurora engine/version. ([AWS Documentation][14])

---

# 60. Production Aurora Architecture

A mature web application could be:

```text
                              Internet
                                 │
                                 ▼
                                ALB
                                 │
                ┌────────────────┴────────────────┐
                ▼                                 ▼
             EC2-A                             EC2-B
            Node API                          Node API
                │                                 │
                └───────────────┬─────────────────┘
                                │
                           RDS Proxy
                                │
               ┌────────────────┴────────────────┐
               │                                 │
               ▼                                 ▼
         Writer endpoint                    Reader path
               │                                 │
               ▼                                 ▼
          Aurora Writer              ┌─────────┬─────────┐
              AZ-A                   ▼         ▼         ▼
                                  Reader A  Reader B  Reader C
                                    AZ-B      AZ-C      AZ-A
                                      \        |        /
                                       \       |       /
                                        Aurora Storage
                                      6 nodes / 3 AZs
```

Add:

```text
Secrets Manager
CloudWatch / Database Insights
automated backups
PITR
cross-Region backup/Global Database
```

depending on requirements.

---

# 61. When Should I Choose Aurora Over Standard RDS PostgreSQL/MySQL?

Aurora deserves strong consideration when several of these matter:

```text
high availability
multiple low-lag readers
fast reader failover
automatic distributed storage
rapid reader scaling
Aurora Serverless v2
fast copy-on-write cloning
Global Database
storage-level cross-Region replication
high connection scale with RDS Proxy
```

Those capabilities derive from Aurora's distributed storage and cluster architecture. ([AWS Documentation][2])

---

# 62. When Normal RDS Might Be Perfectly Fine

Suppose your system is:

```text
modest workload
stable capacity
one Region
few reads
simple HA requirement
no global database
no rapid cloning
```

Then a standard:

```text
RDS PostgreSQL Multi-AZ
```

might already satisfy the requirement.

Architectural maturity means:

```text
don't choose Aurora
merely because
Aurora sounds more advanced.
```

Use requirements to justify complexity/cost.

---

# 63. Aurora vs RDS Read Replica

### Standard RDS PostgreSQL

```text
Primary
    │
    │ asynchronous DB replication
    ▼
Replica
```

### Aurora PostgreSQL

```text
Writer        Reader
   \            /
    \          /
     shared Aurora storage
```

Aurora's reader architecture normally produces lower replication lag and enables rapid promotion because compute instances share the distributed cluster volume rather than each maintaining an independently replicated database storage stack. ([AWS Documentation][3])

---

# 64. Failure Scenario — Writer Dies

Architecture:

```text
Writer AZ-A
Reader A AZ-B
Reader B AZ-C
```

Writer fails.

Expected chain:

```text
Writer failure
      ↓
Aurora detects
      ↓
choose replica by promotion tier
      ↓
promote replica
      ↓
cluster endpoint updated
      ↓
application reconnects
```

Do not hardcode the writer instance endpoint.

Use:

```text
cluster endpoint
```

and configure application retry/reconnection behavior. ([AWS Documentation][7])

---

# 65. Failure Scenario — Reads Suddenly Overload One Reader

Application uses:

```text
one long-lived DB connection
```

to:

```text
reader endpoint
```

and sends every query through it.

You expected:

```text
R1
R2
R3
```

to split individual queries.

But reader endpoint balances connections—not individual SQL statements. ([AWS Documentation][8])

Fix may require:

```text
appropriate connection pool sizing
more connections
reader auto scaling
custom endpoint strategy
application read-routing design
```

not an IAM change.

---

# 66. Failure Scenario — Serverless Doesn't Scale Enough

Serverless config:

```text
Min = 1 ACU
Max = 4 ACU
```

Traffic now requires:

```text
12 ACU
```

Aurora cannot exceed:

```text
Max = 4
```

just because:

```text
"Serverless should automatically scale."
```

Your configured maximum is still an architectural boundary.

Monitor:

```text
ACU utilization
CPU
connections
latency
database load
```

and choose an appropriate capacity range. Aurora requires you to define the min/max range for Serverless v2. ([AWS Documentation][37])

---

# 67. Failure Scenario — Thousands of Lambda Functions Kill DB Connections

Symptoms:

```text
max_connections
connection latency
CPU spikes
authentication overhead
```

Think:

```text
RDS Proxy
```

before simply increasing the writer forever.

RDS Proxy is explicitly designed to pool/reuse database connections and protect Aurora from unpredictable connection surges. ([AWS Documentation][24])

---

# 68. Failure Scenario — Global Secondary Is Slightly Stale

Primary:

```text
Mumbai
```

Secondary:

```text
Singapore
```

App says:

> We just wrote data in India but Singapore doesn't see it yet.

Think:

```text
cross-Region replication lag
```

not:

```text
database corruption
```

Aurora Global Database replication is asynchronous across Regions, although AWS says the lag is typically under one second. ([AWS Documentation][18])

---

# 69. Failure Scenario — Someone Ran `DROP TABLE`

Does:

```text
six storage copies
```

save you?

No.

Logical command:

```sql
DROP TABLE customers;
```

is a legitimate database change.

It propagates through the database.

Think:

```text
PITR
snapshot
backup
```

not:

```text
Multi-AZ
```

This is the same lesson we learned throughout AWS:

```text
HA
≠
BACKUP
```

Aurora provides PITR from its automated backup history. ([AWS Documentation][28])

---

# 70. SAA-C03 Scenario

> MySQL-compatible relational workload requires high availability and up to many low-lag read replicas.

Strong candidate:

```text
Amazon Aurora MySQL
```

Aurora supports up to 15 Aurora Replicas sharing the cluster storage system. ([AWS Documentation][5])

---

# 71. Scenario

> Unpredictable database load varies significantly throughout the day and we want granular automatic compute scaling.

Think:

```text
Aurora Serverless v2
```

with an appropriate:

```text
min ACU
max ACU
```

range. ([AWS Documentation][17])

---

# 72. Scenario

> Need a relational DR database in another AWS Region with very low replication latency.

Think:

```text
Aurora Global Database
```

AWS says its dedicated cross-Region replication infrastructure typically delivers replication latency below one second. ([AWS Documentation][18])

---

# 73. Scenario

> Need a 20-TB production copy for development quickly without initially copying the full 20 TB.

Think:

```text
Aurora Fast Clone
```

using copy-on-write storage. ([AWS Documentation][30])

---

# 74. Scenario

> 5,000 Lambda invocations suddenly connect to Aurora simultaneously.

Think:

```text
RDS Proxy
```

to pool and reuse database connections. ([AWS Documentation][25])

---

# 75. Scenario

> Need to test a major DB upgrade against a synchronized staging environment and perform controlled switchover.

Think:

```text
Aurora Blue/Green Deployment
```

for supported Aurora engine/version configurations. ([AWS Documentation][32])

---

# 76. Interview Question — Why Aurora?

A strong answer:

> Aurora is not simply a hosted MySQL or PostgreSQL server. It separates database compute from a distributed cluster storage layer that synchronously maintains six storage copies across three Availability Zones. The writer and up to 15 Aurora Replicas share that storage, allowing low-lag readers and fast promotion during compute failure. Aurora also provides cluster and reader endpoints, automatic storage growth, Serverless v2 compute scaling, copy-on-write cloning, RDS Proxy integration, continuous backups with PITR, and Aurora Global Database for storage-level cross-Region replication. I'd choose Aurora when those availability, read-scaling, elasticity or DR characteristics justify it; otherwise standard RDS PostgreSQL or MySQL might be simpler. ([AWS Documentation][1])

That answer demonstrates architecture rather than brand memorization.

---

# 77. Never-Forget Aurora Diagram

```text
                           APPLICATION
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
              Cluster Endpoint        Reader Endpoint
                    │                       │
                    ▼               ┌───────┼───────┐
                 WRITER             ▼       ▼       ▼
                   AZ-A            R1      R2      R3
                                    AZ-B    AZ-C    AZ-A
                    \                |       |      /
                     \               |       |     /
                      └──────────────┼──────┘
                                     ▼
                          AURORA CLUSTER VOLUME
                                     │
                          six storage nodes
                                     │
                       ┌─────────────┼─────────────┐
                       ▼             ▼             ▼
                      AZ-A          AZ-B          AZ-C
```

Then globally:

```text
                         Aurora Global DB

        ap-south-1                           ap-southeast-1
           PRIMARY                               SECONDARY
              │                                      │
           Writer                                 Readers
              │                                      │
              └──── storage-level replication ──────►│
                        typically <1 sec
```

([AWS Documentation][18])

---

# 78. Eighteen Rules to Burn Into Memory

```text
1. Aurora is MySQL- or PostgreSQL-compatible,
   not a completely new SQL language.

2. Aurora separates compute from distributed storage.

3. Storage spans 3 AZs.

4. Aurora synchronously maintains 6 storage-node copies.

5. Storage HA exists even without a reader.

6. Compute HA needs an appropriate reader/failover target.

7. One instance is the writer.

8. Aurora supports up to 15 Aurora Replicas.

9. Readers share Aurora's cluster storage architecture.

10. Cluster endpoint follows the writer.

11. Reader endpoint balances connections, not queries.

12. Promotion tiers control preferred failover targets.

13. Aurora storage grows automatically.

14. Newer Aurora versions can support up to 256 TiB.

15. Serverless v2 scales compute in ACUs.

16. RDS Proxy protects against connection storms.

17. Aurora Global Database handles cross-Region replication.

18. HA, replication, and backup solve different problems.
```

The shortest mental model:

```text
RDS Multi-AZ
=
managed database server
+
standby architecture
```

versus:

```text
AURORA
=
database compute cluster
+
distributed shared storage platform
```

---

# ✅ Lesson 28 Part 2 Complete

You now understand:

```text
✓ Aurora MySQL vs PostgreSQL compatibility
✓ compute/storage separation
✓ cluster volume
✓ six storage nodes / three AZs
✓ storage HA vs compute HA
✓ writer
✓ Aurora Replicas
✓ low replica lag
✓ cluster endpoint
✓ reader endpoint
✓ instance endpoint
✓ custom endpoint
✓ connection-level load balancing
✓ automatic failover
✓ failover tiers
✓ automatic storage growth
✓ current 128/256-TiB limits
✓ reader Auto Scaling
✓ Aurora Serverless v2
✓ ACUs
✓ scale-to-zero behavior
✓ Aurora Global Database
✓ cross-Region replication
✓ switchover vs failover
✓ global write forwarding
✓ RDS Proxy
✓ connection pooling
✓ connection pinning
✓ automated backups
✓ PITR
✓ snapshots
✓ fast cloning
✓ copy-on-write
✓ Blue/Green deployments
✓ Terraform Aurora architecture
✓ production troubleshooting
```

# Next — Lesson 28 Part 3

# **RDS & Aurora Backup, Security, Monitoring and Production Operations**

Next we go from architecture to operating the database at 3 AM:

```text
DATABASE PRODUCTION OPERATIONS
          │
          ├── automated backups
          ├── snapshots
          ├── PITR
          ├── backup retention
          ├── RPO / RTO
          ├── snapshot sharing
          ├── cross-Region backup
          ├── KMS encryption
          ├── encryption limitations
          ├── Secrets Manager
          ├── automatic secret rotation
          ├── IAM database authentication
          ├── TLS
          ├── parameter groups
          ├── maintenance windows
          ├── minor/major upgrades
          ├── Blue/Green
          ├── Performance Insights / Database Insights
          ├── Enhanced Monitoring
          ├── CloudWatch
          ├── slow queries
          ├── locks
          ├── deadlocks
          ├── connection exhaustion
          ├── CPU bottlenecks
          ├── memory pressure
          ├── storage I/O
          ├── replica lag
          ├── failover testing
          ├── Terraform
          └── full production PostgreSQL lab
```

That next part will answer the production question:

> **“The application says the database is slow. How do I determine whether the problem is CPU, memory, storage, connections, locks, SQL, replication, or networking?”**

That is where database operations becomes real DevOps/SRE engineering.

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.AuroraHighAvailability.html?utm_source=chatgpt.com "High availability for Amazon Aurora"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html?utm_source=chatgpt.com "What is Amazon Aurora? - Amazon Aurora"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Replication.html?utm_source=chatgpt.com "Replication with Amazon Aurora"
[4]: https://docs.aws.amazon.com/rds/latest/auroraextendedcontent/aurora-faq-availability-and-durability.html?utm_source=chatgpt.com "Availability and Durability - Amazon Aurora"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.html?utm_source=chatgpt.com "Amazon Aurora DB clusters"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Connecting.html?utm_source=chatgpt.com "Connecting to an Amazon Aurora DB cluster"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.Endpoints.html?utm_source=chatgpt.com "Amazon Aurora endpoint connections"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Endpoints.Reader.html?utm_source=chatgpt.com "Reader endpoints for Amazon Aurora"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.cluster-cache-mgmt.html?utm_source=chatgpt.com "Fast recovery after failover with cluster cache management for ..."
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Endpoints.Custom.html?utm_source=chatgpt.com "Custom endpoints for Amazon Aurora"
[11]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html?utm_source=chatgpt.com "Amazon Aurora storage"
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_Limits.html?utm_source=chatgpt.com "Quotas and constraints for Amazon Aurora"
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Integrating.AutoScaling.html?utm_source=chatgpt.com "Amazon Aurora Auto Scaling with Aurora Replicas"
[14]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.requirements.html?utm_source=chatgpt.com "Requirements and limitations for Aurora serverless"
[15]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html?utm_source=chatgpt.com "Using Aurora serverless - AWS Documentation"
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html?utm_source=chatgpt.com "Scaling to Zero ACUs with automatic pause and resume for Aurora ..."
[17]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.how-it-works.html?utm_source=chatgpt.com "How Aurora serverless works"
[18]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Replication.CrossRegion.html?utm_source=chatgpt.com "Replicating Amazon Aurora MySQL DB clusters across ..."
[20]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding.html?utm_source=chatgpt.com "Using write forwarding in an Amazon Aurora global database"
[21]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding-apg.html?utm_source=chatgpt.com "Using write forwarding in an Aurora PostgreSQL global ..."
[22]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html?utm_source=chatgpt.com "Using switchover or failover in Amazon Aurora Global Database"
[23]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-monitoring.html?utm_source=chatgpt.com "Monitoring an Amazon Aurora global database"
[24]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/rds-proxy.html?utm_source=chatgpt.com "Amazon RDS Proxy for Aurora"
[25]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/rds-proxy-planning.html?utm_source=chatgpt.com "Planning where to use RDS Proxy"
[26]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/rds-proxy-pinning.html?utm_source=chatgpt.com "Avoiding pinning an RDS Proxy - Amazon Aurora"
[27]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Backups.html?utm_source=chatgpt.com "Overview of backing up and restoring an Aurora DB cluster"
[28]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-pitr.html?utm_source=chatgpt.com "Restoring a DB cluster to a specified time - Amazon Aurora"
[29]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-copy-snapshot.html?utm_source=chatgpt.com "DB cluster snapshot copying - Amazon Aurora"
[30]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Clone.html?utm_source=chatgpt.com "Cloning a volume for an Amazon Aurora DB cluster"
[31]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Clone.Cross-Account.html?utm_source=chatgpt.com "Cross-account cloning with AWS RAM and Amazon Aurora"
[32]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/blue-green-deployments-overview.html?utm_source=chatgpt.com "Overview of Amazon Aurora Blue/Green Deployments"
[33]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/blue-green-deployments-best-practices.html?utm_source=chatgpt.com "Best practices for Amazon Aurora blue/green deployments"
[34]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/rds-proxy-blue-green.html?utm_source=chatgpt.com "Using RDS Proxy with Blue/Green Deployments"
[35]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster?utm_source=chatgpt.com "aws_rds_cluster | Resources | hashicorp/aws | Terraform"
[36]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance?utm_source=chatgpt.com "aws_rds_cluster_instance | Resources | hashicorp/aws"
[37]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.setting-capacity.html?utm_source=chatgpt.com "Performance and scaling for Aurora serverless - AWS Documentation"
