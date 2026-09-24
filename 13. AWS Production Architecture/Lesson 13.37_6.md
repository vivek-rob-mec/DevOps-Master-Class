# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 6: AWS Multi-Region Data Layer Deep Dive

Everything we've learned so far eventually reaches one question:

> **Where is the data, how current is the copy, and who is allowed to write to it after a Region fails?**

Compute can often be recreated.

```text
ECS task dies
→ launch another

EC2 dies
→ Auto Scaling

ALB dies
→ AWS-managed service

Region fails
→ run application elsewhere
```

But the business state might contain:

```text
customer orders
payments
user accounts
documents
inventory
audit records
files
sessions
```

If those are wrong or unavailable, having 500 healthy EC2 instances is meaningless.

So the data layer often determines the **real RPO and RTO**.

---

# 37.426 First classify the data technology

Before choosing a DR pattern, identify what kind of state we're protecting.

| Data type                      | Typical AWS example    | Primary DR concern                           |
| ------------------------------ | ---------------------- | -------------------------------------------- |
| Relational transactional DB    | RDS / Aurora           | Writer ownership, replication lag, promotion |
| Globally distributed key-value | DynamoDB Global Tables | Consistency and concurrent writes            |
| Distributed relational         | Aurora DSQL            | Synchronous multi-Region transactions        |
| Object data                    | S3                     | Replication, versioning, deletion, recovery  |
| Shared file system             | EFS                    | Replica freshness and writable failover      |
| Block storage                  | EBS                    | Snapshot/copy/restore time                   |
| Historical backups             | AWS Backup             | Recovery point and restore workflow          |

Don't try to force one recovery architecture onto all seven.

---

# 37.427 The four questions for every data service

Whenever you evaluate a Multi-Region data technology, ask:

```text
1. WHO CAN WRITE?

2. HOW IS DATA REPLICATED?

3. WHAT DATA CAN BE LOST
   IF A REGION FAILS?

4. WHAT MUST HAPPEN
   BEFORE THE DR APPLICATION
   CAN WRITE?
```

Those four questions reveal most of the architecture.

---

# 37.428 Aurora Global Database

Let's start with one of the most important services for AWS architecture interviews.

Conceptually:

```text
                 AURORA GLOBAL DATABASE

                       PRIMARY REGION
                        ap-south-1

                         WRITER
                           │
                           │ asynchronous
                           │ storage replication
                           ▼

                    SECONDARY REGION
                    ap-southeast-1

                        READERS
```

Aurora Global Database consists of one primary Region and one or more secondary Aurora clusters. AWS currently supports up to **10 secondary Regions**, subject to engine/version and Region support. Replication from the primary to secondary Regions is asynchronous. ([AWS Documentation][1])

---

# 37.429 Aurora Global Database is fundamentally single-writer

This should be permanently clear.

```text
Mumbai
PRIMARY

READ  ✓
WRITE ✓


Singapore
SECONDARY

READ  ✓
WRITE ✕ normally
```

The write authority is the primary Aurora cluster.

That means:

> **Aurora Global Database gives us global reads and cross-Region DR, but traditional Aurora Global Database is not arbitrary multi-writer relational SQL.**

([AWS Documentation][1])

---

# 37.430 Aurora replication architecture

Aurora's cross-Region architecture replicates database changes from the primary Region into secondary clusters.

Think:

```text
Transaction
    │
    ▼
Mumbai Writer
    │
    │ asynchronous cross-Region replication
    ▼
Singapore Secondary
```

Because cross-Region replication is asynchronous, the secondary can temporarily lag behind the primary. ([AWS Documentation][2])

And that immediately creates the DR question:

```text
Mumbai committed transaction
        │
        X Region outage
        │
        ▼
Had Singapore received it yet?
```

If not, an unplanned failover can result in some data loss. AWS explicitly warns that a Global Database failover can lose transactions that hadn't yet replicated to the selected secondary. ([AWS Documentation][3])

---

# 37.431 Aurora planned switchover vs unplanned failover

These are different.

### Planned switchover

Imagine:

```text
Mumbai healthy
Singapore healthy
replication healthy
```

You intentionally want Singapore to become primary, perhaps for:

```text
DR testing
planned maintenance
regional migration
```

Aurora supports managed cross-Region switchovers, including zero-data-loss switchover behavior when the required conditions are met. ([AWS Documentation][1])

Mental sequence:

```text
wait for synchronization
       ↓
role switch
       ↓
Singapore = primary
Mumbai    = secondary
```

---

# 37.432 Unplanned Aurora failover

Now Mumbai is impaired:

```text
Mumbai
   X

Singapore
replica available
```

You perform a cross-Region failover.

AWS recommends managed failover for DR when available. With managed failover, Aurora can later add the former primary Region back as a secondary when it becomes available again, helping preserve the global database topology. ([AWS Documentation][4])

But remember:

```text
UNPLANNED FAILOVER
+
ASYNCHRONOUS REPLICATION
=
POSSIBLE RPO > 0
```

That is fundamentally different from a healthy planned switchover.

---

# 37.433 Aurora split-brain consideration

AWS warns that cross-Region failover can be susceptible to split-brain scenarios because the old primary might not immediately be provably dead or fully fenced while another Region becomes authoritative. ([AWS Documentation][3])

Mental picture:

```text
                 PARTITION

Mumbai writer                    Singapore promoted
WRITE ✓                           WRITE ✓
       \                          /
        \                        /
             dangerous
             divergence
```

So remember our Part 5 rule:

> Before creating a new writer, understand what happened to the old writer.

---

# 37.434 Aurora write forwarding

Aurora Global Database can support **write forwarding** for supported engine/configuration combinations.

Singapore application:

```text
Singapore App
      │
      ▼
Singapore Aurora secondary
      │
      │ forward write
      ▼
Mumbai Aurora primary
      │
      ▼
actual modification
      │
      │ replicate
      ▼
Singapore
```

AWS explicitly states that write forwarding sends the operation from a secondary Region to the primary; the data is modified on the primary first and then replicated back. ([AWS Documentation][5])

Therefore:

```text
WRITE FORWARDING
≠
MULTI-WRITER
```

---

# 37.435 Write-forwarding latency

Suppose a Singapore user performs a write.

Without write forwarding architecture:

```text
Singapore
→ application explicitly calls Mumbai DB
```

With write forwarding:

```text
Singapore
→ local Aurora endpoint
→ Aurora forwards to Mumbai
```

This simplifies application routing, but the write still requires cross-Region communication to the primary writer.

So geographic latency still exists.

You improved **application architecture**, not physics.

---

# 37.436 Aurora Global Database fits which workloads?

It is a strong candidate when you need:

```text
relational SQL
+
one authoritative writer
+
global low-latency reads
+
cross-Region DR
```

It is less appropriate if your fundamental requirement is:

```text
Mumbai independently writes
+
Singapore independently writes
+
same relational dataset
```

because that's not the traditional Aurora Global Database write model. ([AWS Documentation][1])

---

# 37.437 Standard Amazon RDS cross-Region replicas

What if you're using:

```text
RDS PostgreSQL
RDS MySQL
RDS MariaDB
RDS Oracle
RDS SQL Server
RDS Db2
```

instead of Aurora?

Amazon RDS supports cross-Region replicas for supported engines and Region/version combinations. AWS lists DR and moving read workloads closer to users as common uses. ([AWS Documentation][6])

Conceptually:

```text
Mumbai RDS PRIMARY
       │
       │ replication
       ▼
Singapore RDS READ REPLICA
```

---

# 37.438 RDS DR requires promotion

For most traditional RDS read-replica DR designs:

```text
Singapore replica
```

is not already the primary database writer.

During disaster:

```text
Mumbai X
   ↓
Promote Singapore replica
   ↓
Singapore becomes standalone DB
   ↓
application writes there
```

AWS's DR guidance specifically notes that a cross-Region RDS read replica must be promoted before it can run the read/write workload. ([AWS Documentation][7])

So:

```text
RDS REPLICA EXISTS
≠
DR WRITE READY
```

---

# 37.439 RDS promotion changes the topology

After promoting:

```text
Singapore Read Replica
      ↓
Singapore Independent DB
```

it is no longer simply:

```text
secondary following Mumbai
```

Your DR procedure must account for:

```text
application cutover
DNS/configuration
new replication topology
failback
```

This is why promotion time plus application cutover time must be included in RTO.

---

# 37.440 RDS automated-backup replication

You don't always need a continuously running cross-Region DB instance.

RDS can also replicate automated backups—snapshots and transaction logs—to another Region for supported configurations. ([AWS Documentation][8])

That pattern looks more like:

```text
Mumbai RDS
   │
snapshots + logs
   │
   ▼
Singapore backup copies
```

Then disaster:

```text
restore DB
    ↓
start application
```

This is closer to:

# Backup & Restore / Pilot Light

rather than Warm Standby.

---

# 37.441 Data-service choice maps directly to DR strategy

Compare:

| Architecture             | DR Region state                  | Relative recovery work       |
| ------------------------ | -------------------------------- | ---------------------------- |
| Cross-Region backup      | Backup files only                | Restore DB                   |
| RDS cross-Region replica | Running replica                  | Promote                      |
| Aurora Global secondary  | Running Aurora secondary         | Managed role switch/failover |
| Multi-active database    | Already writable where supported | Traffic/capacity recovery    |

This is why database selection affects both:

```text
RPO
and
RTO
```

---

# 37.442 DynamoDB Global Tables

Now the architecture changes fundamentally.

With DynamoDB Global Tables:

```text
                  GLOBAL TABLE

           ┌────────────────────┐
           │                    │
           ▼                    ▼

       Mumbai replica      Singapore replica

         READ ✓               READ ✓
         WRITE ✓              WRITE ✓
```

DynamoDB Global Tables are designed as **multi-Region, multi-active** DynamoDB tables. ([AWS Documentation][9])

This is very different from traditional Aurora Global Database.

---

# 37.443 DynamoDB has two current consistency modes

This is important because older learning materials often teach only one model.

Current DynamoDB Global Tables support:

| Mode     | Meaning                           |
| -------- | --------------------------------- |
| **MREC** | Multi-Region Eventual Consistency |
| **MRSC** | Multi-Region Strong Consistency   |

MRSC was introduced after the original eventual-consistency Global Tables model, so saying “all DynamoDB Global Tables are eventually consistent across Regions” is now outdated. ([AWS Documentation][10])

---

# 37.444 MREC — Multi-Region Eventual Consistency

Architecture:

```text
Mumbai
READ / WRITE
    │
    │ asynchronous replication
    ▼
Singapore
READ / WRITE
```

and vice versa.

A write can be accepted locally:

```text
Mumbai WRITE
    ↓
success
```

before the update is necessarily visible in:

```text
Singapore.
```

This gives very attractive local-write latency, but cross-Region reads can temporarily see older data. ([AWS Documentation][10])

---

# 37.445 MREC conflict resolution

Suppose:

```text
Mumbai:

customer.status = GOLD
```

while nearly simultaneously:

```text
Singapore:

customer.status = SILVER
```

In the MREC model, DynamoDB resolves concurrent update conflicts using its last-writer-wins behavior. ([AWS Documentation][9])

Eventually both replicas converge.

But:

```text
eventual convergence
```

does not mean:

```text
both business intentions are preserved.
```

That's the application designer's problem.

---

# 37.446 When MREC is excellent

MREC can be a great fit for data where:

```text
local writes matter
+
temporary staleness is acceptable
+
conflicts are rare or manageable
```

Examples might include appropriately designed:

```text
profiles
preferences
catalog metadata
regional application state
```

depending on business semantics.

It can be dangerous if the application assumes:

```text
every Region instantly sees
the latest globally committed value.
```

---

# 37.447 MRSC — Multi-Region Strong Consistency

Now the stronger model.

MRSC Global Tables provide strong cross-Region consistency and a **zero RPO** architecture according to current AWS documentation. ([AWS Documentation][11])

Conceptually:

```text
Mumbai write
       │
       ▼
distributed coordination
       │
       ▼
commit
       │
 ┌─────┴─────┐
 ▼           ▼
Mumbai     Singapore
consistent committed state
```

This trades some of the purely local asynchronous freedom of MREC for stronger global guarantees.

---

# 37.448 MRSC topology requirement

MRSC is not:

```text
pick any two Regions
and enable strong mode.
```

Current MRSC Global Tables require exactly **three Regions** arranged as either:

```text
3 full replicas
```

or:

```text
2 replicas
+
1 witness
```

The witness participates in the availability/consistency architecture but does not serve normal reads or writes. ([AWS Documentation][12])

Mental picture:

```text
           MRSC GLOBAL TABLE

      Mumbai             Singapore
      REPLICA             REPLICA
         \                 /
          \               /
            WITNESS REGION
          no client reads/writes
```

---

# 37.449 MRSC Region availability matters

MRSC currently uses supported Region sets, so you must verify whether your desired Regions can form an MRSC deployment before designing around it. AWS documentation lists specific Region sets rather than unrestricted Region combinations. ([AWS Documentation][13])

This is a perfect example of why:

> **Current AWS service capabilities must be verified before turning an architecture diagram into a commitment.**

---

# 37.450 MREC vs MRSC

| Property                               | MREC                      | MRSC                                                                     |
| -------------------------------------- | ------------------------- | ------------------------------------------------------------------------ |
| Cross-Region model                     | Eventual                  | Strong                                                                   |
| Multi-active writes                    | Yes                       | Yes                                                                      |
| Temporary stale remote reads           | Possible                  | Strong-consistency model                                                 |
| Conflict semantics                     | Last-writer-wins possible | Stronger coordination avoids normal eventual concurrent divergence model |
| Region topology                        | More flexible             | Exactly 3 Regions in supported sets                                      |
| Cross-Region coordination cost/latency | Lower write coordination  | Stronger coordination                                                    |
| RPO                                    | Replication-lag-dependent | AWS documents zero RPO                                                   |

([AWS Documentation][11])

---

# 37.451 DynamoDB does not remove application design

Even with MRSC you still need:

```text
idempotent APIs

capacity planning

Regional routing

retry logic

safe schema/item design

backup protection
```

Strong consistency solves an important class of data problems.

It doesn't automatically make the entire application:

```text
globally correct
```

or:

```text
immune to bad writes.
```

Remember:

```text
strongly consistent DELETE
```

is still a DELETE.

---

# 37.452 Aurora vs DynamoDB Global Tables

Here's an extremely important interview comparison:

| Question                           | Aurora Global DB                    | DynamoDB Global Tables                   |
| ---------------------------------- | ----------------------------------- | ---------------------------------------- |
| Data model                         | Relational SQL                      | Key-value/document                       |
| Traditional write model            | One primary writer Region           | Multi-active                             |
| Secondary local reads              | Yes                                 | Yes                                      |
| Independent writes in every Region | No, not traditional model           | Yes                                      |
| Write forwarding                   | Supported configurations            | Not needed in same sense                 |
| Replication                        | Asynchronous cross-Region           | MREC eventual or MRSC strong             |
| Conflict issue                     | Primarily writer/failover authority | MREC can have concurrent write conflicts |
| DR operation                       | Switchover/failover                 | Replica already active                   |

([AWS Documentation][1])

If someone says:

> "I need SQL, so I'll use DynamoDB Global Tables."

Wrong data model.

If someone says:

> "I need unrestricted local relational writes in both Regions, so normal Aurora Global DB gives that."

Also wrong.

---

# 37.453 Amazon Aurora DSQL

Now the modern distributed relational option.

Aurora DSQL is a serverless distributed SQL database with an **active-active** architecture. Multi-Region DSQL presents two Regional endpoints that access one logical database; applications can read and write through either Region with strong consistency. ([AWS Documentation][14])

Conceptually:

```text
               AURORA DSQL

      Region A               Region B

      READ ✓                 READ ✓
      WRITE ✓                WRITE ✓

            \               /
             \             /
              STRONGLY
              CONSISTENT
              DATABASE

                    │
                    ▼
              Witness Region
            transaction-log role
            no client endpoint
```

---

# 37.454 DSQL replication model

Aurora DSQL synchronously replicates committed transaction-log data as part of its architecture. AWS states that its multi-Region design avoids replication-lag-based data loss during failure recovery because it doesn't rely on promoting an asynchronously replicated secondary. ([AWS Documentation][14])

That is fundamentally different from:

```text
Aurora Global Database
primary
   ↓ asynchronous
secondary
```

---

# 37.455 DSQL doesn't use traditional primary/secondary failover

AWS describes DSQL single-Region and Multi-Region clusters as active-active by default, with recovery handled by the service rather than requiring customers to perform a conventional primary-to-secondary database promotion. ([AWS Documentation][14])

Mental comparison:

```text
AURORA GLOBAL DATABASE

Primary writer
      │
      ▼
Secondary
      │
failure
      ▼
promote / switch roles
```

versus:

```text
AURORA DSQL

Region A active
Region B active

service manages
distributed recovery
```

---

# 37.456 DSQL witness

A Multi-Region DSQL deployment includes a witness Region.

The witness stores a limited window of encrypted transaction-log information, participates in the availability architecture, and does not expose a database endpoint for normal client reads/writes. ([AWS Documentation][15])

So:

```text
Witness
≠
third application-serving database Region
```

It is part of distributed consensus/availability architecture.

---

# 37.457 DSQL availability target

AWS currently documents DSQL as designed for:

```text
99.99% single-Region availability
```

and:

```text
99.999% multi-Region availability
```

for the supported architectures. ([AWS Documentation][16])

But do not turn that into:

> "My application automatically has five nines."

Your application still has:

```text
traffic routing
IAM
client retries
dependencies
code
networking
```

outside the database service.

---

# 37.458 Aurora Global DB vs Aurora DSQL

These names are similar enough to cause confusion.

| Characteristic               | Aurora Global Database                                 | Aurora DSQL                                                        |
| ---------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| Architecture                 | Primary + secondary Regions                            | Distributed active-active                                          |
| Write endpoints              | Primary writer model                                   | Both data Regions read/write                                       |
| Cross-Region replication     | Asynchronous                                           | Synchronous                                                        |
| Traditional Region promotion | Yes for DR                                             | No traditional primary-secondary promotion                         |
| SQL                          | Aurora MySQL/PostgreSQL compatibility depending engine | Distributed SQL service with PostgreSQL-oriented client experience |
| Main strength                | Existing Aurora apps, global reads, DR                 | Strongly consistent distributed relational transactions            |

([AWS Documentation][1])

Never say:

```text
Aurora DSQL
=
new name for Aurora Global Database.
```

They are distinct services/architectures.

---

# 37.459 S3 Cross-Region Replication

Now move from databases to object storage.

Architecture:

```text
S3 Bucket
Mumbai
   │
   │ CRR
   ▼
S3 Bucket
Singapore
```

Amazon S3 Cross-Region Replication automatically replicates eligible objects from a source bucket into a destination bucket in another AWS Region according to the replication configuration. ([AWS Documentation][17])

---

# 37.460 S3 replication is asynchronous

Think:

```text
PUT object in Mumbai
        │
        ▼
source object exists
        │
        │ replication
        ▼
Singapore copy later
```

So basic CRR is not:

```text
synchronous global object commit.
```

For workloads requiring predictable replication timing, AWS provides:

# S3 Replication Time Control — RTC.

---

# 37.461 S3 RTC

AWS currently documents S3 RTC as replicating **99.99% of new objects within 15 minutes**, backed by an SLA. ([AWS Documentation][17])

Important:

```text
99.99% within 15 min
```

does **not** mean:

```text
every object always replicated
in exactly 15 minutes.
```

It is a service objective/SLA-based replication capability.

---

# 37.462 S3 replication isn't the same as backup

Suppose application does:

```text
PUT corrupted file
```

CRR says:

```text
Excellent.
I will replicate it.
```

Now:

```text
Mumbai = corrupted
Singapore = corrupted
```

Likewise, deletion behavior depends on your configured replication/versioning rules.

So:

```text
CRR
=
availability/geographic copy
```

while:

```text
versioning / backup / protected recovery points
=
historical recovery
```

remain separate concerns.

This is the same rule we've used throughout Lesson 37:

> **Replication is not backup.**

---

# 37.463 S3 existing objects

A standard replication rule is primarily about objects that are eligible after replication is configured according to its rule behavior.

For existing historical datasets, AWS provides mechanisms such as:

```text
S3 Batch Replication
```

to replicate existing objects when appropriate. AWS's S3 replication guidance distinguishes regular replication from Batch Replication workflows. ([AWS Documentation][18])

This matters during migrations.

You don't want:

```text
New files replicated ✓

Previous 10 TB of files
missing in DR ✕
```

---

# 37.464 S3 KMS-encrypted replication

If objects use SSE-KMS, replication requires the appropriate KMS permissions and destination encryption configuration.

AWS documents scenarios requiring decrypt permission for source objects and encrypt permission using the destination-side key. ([AWS Documentation][19])

So again:

```text
S3 replication
+
IAM
+
KMS
```

must all agree.

A replication rule without usable KMS permissions isn't a DR architecture.

---

# 37.465 S3 Multi-Region application pattern

Imagine static assets:

```text
images
reports
customer uploads
```

Architecture:

```text
Application Mumbai
      │
      ▼
Mumbai bucket
      │
      │ CRR
      ▼
Singapore bucket
      ▲
      │
Application Singapore
```

During a Regional outage:

```text
Singapore app
```

uses:

```text
Singapore bucket.
```

That's far cleaner than:

```text
Singapore app
    ↓
Mumbai bucket
```

during a Mumbai outage.

---

# 37.466 EFS Multi-Region replication

Amazon EFS provides native replication that can replicate file data and metadata to an EFS destination file system, including cross-Region configurations. After initial synchronization, AWS states that EFS replication maintains an RPO of **15 minutes for most file systems**, although very large or frequently changing file systems can take longer. ([AWS Documentation][20])

Architecture:

```text
Mumbai EFS
SOURCE
   │
   │ asynchronous replication
   ▼
Singapore EFS
DESTINATION
```

---

# 37.467 EFS replica is read-only during replication

This is very important.

While a file system is serving as an active EFS replication destination, AWS marks it as:

```text
read-only
```

and EFS replication is what modifies it. ([AWS Documentation][21])

So:

```text
Singapore EFS replica exists
```

does not mean:

```text
Singapore application can immediately
write production data into it.
```

---

# 37.468 EFS failover

To use the destination as the writable production file system during failover, AWS documents deleting the replication configuration. The destination then becomes writable and can be used by the DR application. ([AWS Documentation][22])

Concept:

```text
NORMAL

Mumbai EFS
WRITE ✓
   │
   ▼
Singapore EFS
READ-ONLY replication target


DISASTER

Mumbai X

delete/break replication relationship
           ↓
Singapore EFS
WRITE ✓
```

This is conceptually similar to database promotion.

---

# 37.469 EFS failback

Now Singapore has accepted new writes.

Mumbai returns.

You must decide:

```text
Discard Singapore changes?
```

or:

```text
replicate Singapore changes
back toward Mumbai?
```

AWS supports workflows where the replication direction is reversed during failback so changes made on the recovered replica can be copied back. ([AWS Documentation][22])

That's why failback is a data problem, not just DNS.

---

# 37.470 EFS initial synchronization matters

When first establishing replication—or reversing it during certain failback workflows—EFS performs an initial sync. The duration depends on dataset size and number of files. ([AWS Documentation][20])

So don't assume:

```text
Create replication
      ↓
DR EFS ready instantly.
```

Readiness must be monitored.

---

# 37.471 EBS is different again

EBS is block storage tied to EC2-style workloads.

For Regional DR you commonly think:

```text
EBS volume
   │
snapshot
   │
copy
   ▼
another Region
```

AWS supports copying EBS snapshots to another Region; the destination snapshot is a distinct snapshot with its own resource ID. ([AWS Documentation][23])

This isn't continuous active replication in the same sense as DynamoDB Global Tables.

---

# 37.472 EBS DR workflow

Normal:

```text
Mumbai EC2
   │
EBS Volume
   │
snapshot
   │
cross-Region copy
   ▼
Singapore snapshot
```

Disaster:

```text
Singapore snapshot
      ↓
create EBS volume
      ↓
attach to EC2
      ↓
start app
      ↓
validate
```

So the RTO includes:

```text
snapshot availability
+
volume creation
+
instance deployment
+
application startup
```

---

# 37.473 EBS snapshot copies can have predictable timing options

AWS now offers **time-based copies** for EBS snapshots and EBS-backed AMIs, allowing a specified completion duration for supported copy workflows, which can help customers plan DR replication objectives more predictably. ([AWS Documentation][24])

This is useful when the question is not merely:

```text
Will my snapshot eventually copy?
```

but:

```text
How quickly must this copy
reach my recovery Region?
```

---

# 37.474 Cross-account EBS copy protection

EBS snapshot workflows can also be combined with cross-account isolation.

AWS Data Lifecycle Manager supports automated cross-account snapshot-copy architectures specifically to improve protection against account compromise. ([AWS Documentation][25])

So you might have:

```text
PRODUCTION ACCOUNT
Mumbai EBS
    │
snapshot
    ▼
RECOVERY ACCOUNT
Singapore copy
```

Again:

```text
Region separation
+
account separation
```

are distinct layers of resilience.

---

# 37.475 AWS Backup ties multiple technologies together

Rather than managing every resource independently, AWS Backup can centrally orchestrate backups and cross-Region copies for many supported services.

Feature support varies by service; AWS's current feature matrix shows different copy and incremental/full-backup behaviors for RDS, S3, Aurora and other supported resources. ([AWS Documentation][26])

Never assume:

```text
AWS Backup supports feature X
for one service
```

therefore:

```text
AWS Backup supports feature X
identically for every service.
```

---

# 37.476 The critical distinction: replication path vs recovery path

For every service, identify both.

Example Aurora:

```text
REPLICATION PATH

Mumbai writer
    ↓
Singapore secondary


RECOVERY PATH

Singapore secondary
    ↓
role switch/failover
    ↓
Singapore writer
```

Example EFS:

```text
REPLICATION PATH

Mumbai EFS
    ↓
Singapore EFS read-only


RECOVERY PATH

delete replication relationship
    ↓
Singapore writable
```

Example EBS:

```text
REPLICATION PATH

snapshot/copy
    ↓
Singapore snapshot


RECOVERY PATH

create volume
    ↓
launch/attach
```

This distinction is extremely valuable.

---

# 37.477 Replication lag is not uniform across services

Different services have fundamentally different semantics:

```text
Aurora Global DB
→ asynchronous secondary replication

DynamoDB MREC
→ asynchronous multi-active replication

DynamoDB MRSC
→ strongly coordinated multi-Region commits

Aurora DSQL
→ synchronous distributed relational architecture

S3 CRR
→ asynchronous object replication

EFS replication
→ asynchronous file replication

EBS snapshot copy
→ point-in-time copy workflow
```

([AWS Documentation][2])

That is why the phrase:

> "Our data is replicated to Singapore."

is almost useless without specifying the service and replication model.

---

# 37.478 RPO example across services

Suppose Mumbai disappears immediately after a write.

### Aurora Global Database

```text
write committed in primary
    ↓
not yet replicated?
    ↓
possible data loss on failover
```

([AWS Documentation][3])

### DynamoDB MREC

```text
local write committed
    ↓
remote replica may temporarily lag
```

([AWS Documentation][27])

### DynamoDB MRSC

AWS documents a strong-consistency architecture with zero RPO. ([AWS Documentation][11])

### Aurora DSQL

AWS documents synchronous multi-Region replication with no replication-lag loss during database failure recovery. ([AWS Documentation][14])

Do you see why:

```text
"Multi-Region"
```

alone tells us almost nothing about RPO?

---

# 37.479 RTO example across services

Likewise.

### RDS cross-Region replica

Need:

```text
promote
+
application cutover
```

([AWS Documentation][7])

### Aurora Global

Need:

```text
managed failover/switchover
+
application/traffic recovery
```

([AWS Documentation][4])

### DynamoDB Global Tables

Database replica is already active; application traffic/capacity recovery may dominate. ([AWS Documentation][9])

### EBS snapshot

Need:

```text
restore/create volumes
+
recreate compute
```

([AWS Documentation][23])

The storage technology can change the DR strategy from:

```text
Backup & Restore
```

to:

```text
Warm Standby
```

or even:

```text
Active/Active.
```

---

# 37.480 KMS is part of every encrypted DR architecture

For cross-Region encrypted data, ask:

```text
Does the DR Region have
the required KMS key/configuration?

Does the service role have
kms:Decrypt?

Can it encrypt
the destination copy?

Do key policies allow
the DR account/role?
```

For example, AWS explicitly documents KMS permissions for cross-Region S3 replication of KMS-encrypted objects, and RDS/EBS encrypted copy workflows likewise require appropriate destination encryption handling. ([AWS Documentation][19])

So:

```text
DATA COPY ✓
KMS PERMISSIONS ✕
```

means:

```text
DR ✕
```

---

# 37.481 Data endpoint abstraction

Suppose application contains:

```text
DB_HOST =
prod-db.cluster-xyz.ap-south-1.rds.amazonaws.com
```

Failover to Singapore now requires application configuration changes.

Better architecture introduces controlled indirection.

Conceptually:

```text
application
    │
    ▼
database configuration abstraction
    │
    ├── Mumbai endpoint
    └── Singapore endpoint
```

The abstraction could be managed through:

```text
application configuration
secret
service discovery
database-specific global endpoint
```

depending on the data service.

Never hard-code the original Region so deeply that failover requires a new software build.

---

# 37.482 Data authority is the most important concept

During an outage, ask:

> **Which copy is authoritative RIGHT NOW?**

For active/passive Aurora:

```text
before failover:
Mumbai

after failover:
Singapore
```

For EFS:

```text
before failover:
Mumbai source

after replica made writable:
Singapore
```

For DynamoDB Global Tables:

```text
multiple replicas
are active according to
the selected consistency model
```

For DSQL:

```text
both data Regions
participate in one
strongly consistent database.
```

([AWS Documentation][9])

If your incident team cannot answer:

```text
WHO OWNS THE WRITE?
```

stop.

Don't shift application traffic blindly.

---

# 37.483 Database failover runbook example

Suppose we're using Aurora Global Database.

Normal:

```text
Mumbai
PRIMARY WRITER

Singapore
SECONDARY
```

Regional incident:

```text
1. Confirm failure scope

2. Inspect replication/recovery state

3. Choose Singapore recovery cluster

4. Execute managed failover if applicable

5. Verify Singapore writer

6. Verify database connectivity

7. Scale/validate application

8. Shift users

9. Monitor data/application health

10. Recover old Region as secondary
```

Aurora's managed failover model is designed specifically for this cross-Region recovery workflow. ([AWS Documentation][4])

---

# 37.484 Don't route users before writer readiness

Bad:

```text
Mumbai X

Route 53 immediately
→ Singapore app

Singapore app
→ read-only database

ERROR
```

Better:

```text
DATA FIRST

promote/switch data
      ↓
verify writer
      ↓
verify application
      ↓
TRAFFIC
```

This is one of the most important operational sequences from Lesson 37.

---

# 37.485 Data promotion can change your RPO

Suppose Aurora replication lag at the moment of failure contains some unreplicated transactions.

If you promote Singapore:

```text
those transactions may be absent.
```

Your **measured RPO** is therefore determined by actual replicated state, not the marketing phrase:

```text
"global database."
```

AWS explicitly cautions that cross-Region failover can lose unreplicated write transactions. ([AWS Documentation][3])

---

# 37.486 Backups remain essential even for globally replicated databases

Imagine a developer executes:

```sql
DELETE FROM payments;
```

Global replication behaves perfectly:

```text
Mumbai
DELETE

      ↓ replication

Singapore
DELETE
```

Now both Regions agree perfectly on the wrong state.

So even with:

```text
Aurora Global Database
DynamoDB Global Tables
Aurora DSQL
```

you still require an appropriate:

```text
backup / PITR / historical recovery
```

strategy.

Aurora DSQL itself supports backup and restore through AWS Backup, showing that active-active synchronous replication and historical backup address different failure classes. ([AWS Documentation][14])

---

# 37.487 The best mental distinction in this entire part

```text
REPLICATION
protects primarily against
INFRASTRUCTURE / LOCATION FAILURE


BACKUP
protects primarily against
NEEDING AN OLDER STATE
```

Not universally every scenario, but this is a very useful mental rule.

Think:

```text
Region disappeared
→ replica


Bad DELETE propagated
→ backup/PITR
```

---

# 37.488 Data-service decision matrix

| Requirement                                             | Strong candidate to evaluate   |
| ------------------------------------------------------- | ------------------------------ |
| Existing relational Aurora workload + global reads + DR | Aurora Global Database         |
| Traditional RDS database + simple DR                    | Cross-Region read replica      |
| Lower-cost RDS recovery                                 | Cross-Region automated backups |
| Global key-value multi-active writes                    | DynamoDB Global Tables         |
| Strong globally coordinated DynamoDB writes             | DynamoDB MRSC                  |
| Distributed active-active relational SQL                | Aurora DSQL                    |
| Global replicated objects                               | S3 CRR                         |
| Predictable S3 object replication objective             | S3 RTC                         |
| Shared file-system DR                                   | EFS replication                |
| EC2/block-storage recovery                              | EBS snapshots/copies           |

Each option has specific Region, engine, consistency and feature limitations that should be verified during actual solution design. ([AWS Documentation][1])

---

# 37.489 Exam scenario — relational DB with one writer and global reads

Requirement:

```text
Relational SQL

primary writer in Mumbai

low-latency reads
in Singapore

fast cross-Region DR
```

Think:

# Aurora Global Database.

```text
Mumbai Writer
     │
     ▼
Singapore Secondary
local reads
```

([AWS Documentation][1])

---

# 37.490 Exam scenario — write from every Region

Requirement:

```text
NoSQL

local read/write
in multiple Regions

multi-active
```

Think:

# DynamoDB Global Tables.

Then ask:

```text
MREC
or
MRSC?
```

based on consistency requirements and supported topology. ([AWS Documentation][9])

---

# 37.491 Exam scenario — S3 compliance copy target

Requirement:

```text
New objects must replicate
cross-Region with a predictable
replication SLA.
```

Think:

# S3 Replication Time Control.

AWS currently states that S3 RTC replicates 99.99% of new objects within 15 minutes under its SLA. ([AWS Documentation][17])

---

# 37.492 Exam scenario — shared Linux files

Requirement:

```text
Linux application
uses NFS/shared filesystem.

Need cross-Region DR copy.
```

Think:

# EFS replication.

But remember:

```text
destination is read-only
during replication.
```

Failover requires making the destination writable by ending the replication relationship. ([AWS Documentation][21])

---

# 37.493 Exam scenario — EC2 data disks

Requirement:

```text
EC2-based legacy app

RTO measured in hours

periodic Region DR copy
acceptable
```

Think:

```text
EBS snapshots
+
cross-Region copies
+
IaC/AMI
+
restore workflow
```

rather than unnecessarily designing a globally distributed database. ([AWS Documentation][23])

---

# 37.494 Interview trap — Aurora Global DB secondary is another writer

Incorrect.

Traditional Aurora Global Database has one primary Region; secondary clusters provide global reads/DR. Write forwarding still sends writes to the primary rather than turning the secondary into an independent writer. ([AWS Documentation][1])

---

# 37.495 Interview trap — DynamoDB Global Tables are always eventual

Outdated.

Current DynamoDB supports:

```text
MREC
+
MRSC
```

with very different consistency/topology behavior. ([AWS Documentation][11])

---

# 37.496 Interview trap — S3 CRR means RPO 0

No.

S3 CRR is asynchronous.

S3 RTC gives a predictable replication objective for 99.99% of new objects within 15 minutes, not synchronous zero-loss replication. ([AWS Documentation][17])

---

# 37.497 Interview trap — EFS replica can accept writes

Not while it remains an active replication destination.

The destination is read-only during replication and becomes writable after the replication relationship is deleted during failover. ([AWS Documentation][21])

---

# 37.498 Interview trap — replication replaces backup

Never.

A bad mutation can propagate across replicas.

Backups/PITR provide historical recovery capability that replication alone does not.

This principle applies regardless of whether your replication is asynchronous, strongly consistent, or active-active.

---

# 37.499 Interview trap — Active/active means no DR runbook

No.

Even with DynamoDB Global Tables or DSQL, you still need:

```text
traffic evacuation

capacity checks

application health

dependency recovery

backup restoration procedures

bad deployment handling

Region reintegration
```

The data service may eliminate **database promotion**, but it does not eliminate application recovery operations.

---

# 37.500 Terraform architecture mental model

A production Terraform design should make Region/data role explicit.

Conceptually:

```hcl
module "primary_database" {
  source = "./modules/database"

  region = "ap-south-1"
  role   = "primary"
}

module "dr_database" {
  source = "./modules/database"

  region = "ap-southeast-1"
  role   = "secondary"
}
```

Or for multi-active:

```text
Region A replica
+
Region B replica
+
global-table/distributed configuration
```

The important thing is that the code models:

```text
data ownership
replication
recovery
```

not just:

```text
create two databases.
```

---

# 37.501 Monitoring by data technology

Your DR dashboards should reflect the actual replication architecture.

| Technology             | Important recovery observations                                                        |
| ---------------------- | -------------------------------------------------------------------------------------- |
| Aurora Global          | Secondary health, replication state/lag, writer Region                                 |
| RDS replica            | Replica health/lag, promotion readiness                                                |
| DynamoDB Global Tables | Replica health, replication/consistency mode, throttling/capacity                      |
| S3 CRR                 | Replication status/metrics, failed replication, RTC metrics if used                    |
| EFS                    | Last successful replication/RPO status                                                 |
| EBS                    | Snapshot age, cross-Region copy completion                                             |
| DSQL                   | Regional endpoint/application health; service manages synchronous database replication |

([AWS Documentation][28])

---

# 37.502 Data-layer recovery hierarchy

You can now think about Multi-Region data in five maturity levels:

```text
LEVEL 1
BACKUP ONLY

          ↓

LEVEL 2
CROSS-REGION BACKUP

          ↓

LEVEL 3
RUNNING READ REPLICA

          ↓

LEVEL 4
ACTIVE SECONDARY /
FAST ROLE SWITCH

          ↓

LEVEL 5
TRUE MULTI-ACTIVE /
DISTRIBUTED DATA
```

But higher is **not automatically better**.

Higher usually means:

```text
lower potential recovery time
```

but also:

```text
greater distributed-system complexity
higher cost
more consistency decisions
more operational responsibility
```

Choose the level your workload actually needs.

---

# 37.503 One production architecture

Imagine a global e-commerce platform.

```text
                         GLOBAL APP

                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
            ▼                                   ▼

         MUMBAI                             SINGAPORE

        ECS/EKS                              ECS/EKS

            │                                   │
            ├──────────── DATA ─────────────────┤
            │                                   │
```

Different data classes might deliberately use different technologies:

```text
ORDERS
Aurora Global Database
single relational writer

CUSTOMER PREFERENCES
DynamoDB Global Tables
multi-active

STATIC/UPLOAD OBJECTS
S3 CRR

SHARED LEGACY FILES
EFS replication

LEGACY EC2 DISKS
EBS snapshots + cross-Region copy

BACKUPS
AWS Backup
cross-account + cross-Region
```

That is much more realistic than trying to place everything into one global database.

---

# 37.504 The senior-architect question

When someone says:

> "We need zero downtime and zero data loss."

Do not immediately say:

```text
Active/active!
```

Ask:

```text
Zero downtime for what failure?

Zero data loss for which data?

Must both Regions accept writes?

Can writes coordinate synchronously?

What latency is acceptable?

Can data be sharded?

Does the selected AWS service
support those Regions?

What happens under partition?

What happens after logical corruption?
```

Those questions are the difference between:

```text
service selection
```

and:

```text
architecture.
```

---

# 37.505 Never-forget table

| Technology                  | Write mental model              | Cross-Region mental model            |
| --------------------------- | ------------------------------- | ------------------------------------ |
| **Aurora Global DB**        | One primary writer              | Async secondary Regions              |
| **Aurora write forwarding** | Still primary writer            | Secondary forwards write             |
| **RDS read replica**        | Source writer                   | Replica must be promoted             |
| **DynamoDB MREC**           | Multi-writer                    | Eventual replication                 |
| **DynamoDB MRSC**           | Multi-writer                    | Strong multi-Region consistency      |
| **Aurora DSQL**             | Active-active relational writes | Synchronous distributed database     |
| **S3 CRR**                  | Bucket writes                   | Async object replication             |
| **S3 RTC**                  | Same S3 model                   | Predictable replication SLA          |
| **EFS replication**         | Source writable                 | Destination read-only until failover |
| **EBS snapshot copy**       | Volume is live state            | Point-in-time copied snapshot        |

([AWS Documentation][1])

---

# 37.506 The eight rules to remember forever

```text
1. Multi-Region does not tell you the RPO.
   Replication semantics do.

2. Aurora Global Database is normally
   one-writer, multi-Region.

3. Write forwarding does not turn
   Aurora secondary Regions into
   independent writers.

4. DynamoDB Global Tables can be
   genuinely multi-active.

5. DynamoDB now has both
   MREC and MRSC models.

6. Replication protects location
   availability; backups protect
   historical recovery.

7. Failover is unsafe until you know
   which data copy is authoritative.

8. Traffic should move only after
   the destination data layer is
   ready for the operations users
   will perform.
```

---

# 37.507 One diagram to reconstruct from memory

```text
                    MULTI-REGION DATA

                           │
       ┌───────────────────┼────────────────────┐
       │                   │                    │
       ▼                   ▼                    ▼

   RELATIONAL           NOSQL               STORAGE

       │                   │                    │
       ▼                   ▼                    ▼

Aurora Global        DynamoDB             S3
Primary Writer       Global Tables         CRR
   │                 /          \          │
Async                MREC       MRSC       RTC
   │
Secondary

       │
       ├── RDS replica
       │      ↓
       │   promote
       │
       └── Aurora DSQL
              ↓
        active/active
        synchronous

                           │
              ┌────────────┴────────────┐
              ▼                         ▼
             EFS                       EBS
         replication               snapshots
        read-only DR              copy/restore
             │                         │
           promote                    rebuild
           writable

                           │
                           ▼
                       AWS BACKUP

                 historical recovery
```

---

# 37.508 Part 6 complete

Lesson 37 progress:

```text
Part 1
HA vs DR + RTO/RPO                  ✓

Part 2
Backup & Restore                    ✓

Part 3
Pilot Light + Warm Standby          ✓

Part 4
Active/Passive Multi-Region         ✓

Part 5
Active/Active Multi-Region          ✓

Part 6
Multi-Region Data Layer             ✓

Part 7
Application Recovery Controller     NEXT

Part 8
DR Automation / Testing / Chaos

Part 9
Complete Multi-Region DR Capstone

Part 10
Final Revision / Interview Mastery
```

# Next — Lesson 37, Part 7

## Amazon Application Recovery Controller (ARC) Deep Dive

This next part is important because we're going to move beyond the simplistic model:

```text
Route 53 health check
      ↓
automatically change Region
```

and learn how AWS handles **controlled recovery operations**.

We'll cover:

```text
Amazon Application Recovery Controller

Routing Controls
Safety Rules
Readiness Checks
Region Switch
Zonal Shift
Zonal Autoshift

Multi-AZ vs Multi-Region recovery

ARC control-plane independence

Manual vs automated Region recovery

Route 53 integration

Global Accelerator integration patterns

Data-promotion sequencing

Approval workflows

Failover runbooks

Failback orchestration

cross-account applications

recovery plans

testing and game days
```

And we'll answer one of the most important questions in production DR:

> **How do you automate failover without allowing faulty automation, bad health signals, or a human mistake to take down both Regions?**

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.AuroraHighAvailability.html?utm_source=chatgpt.com "High availability for Amazon Aurora"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-connecting.html?utm_source=chatgpt.com "Connecting to Amazon Aurora Global Database"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html?utm_source=chatgpt.com "Using switchover or failover in Amazon Aurora Global Database"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding.html?utm_source=chatgpt.com "Using write forwarding in an Amazon Aurora global database"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.XRgn.html?utm_source=chatgpt.com "Creating a read replica in a different AWS Region"
[7]: https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html?utm_source=chatgpt.com "Disaster recovery options in the cloud"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReplicateBackups.html?utm_source=chatgpt.com "Replicating automated backups to another AWS Region"
[9]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GlobalTables.html?utm_source=chatgpt.com "Global tables - multi-active, multi-Region replication"
[10]: https://docs.aws.amazon.com/prescriptive-guidance/latest/dynamodb-global-tables/overview.html?utm_source=chatgpt.com "Overview - AWS Prescriptive Guidance"
[11]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables-security.html?utm_source=chatgpt.com "DynamoDB global tables security"
[12]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/V2globaltables_HowItWorks.html?utm_source=chatgpt.com "How DynamoDB global tables work"
[13]: https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_CreateGlobalTableWitnessGroupMemberAction.html?utm_source=chatgpt.com "CreateGlobalTableWitnessGroup..."
[14]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/disaster-recovery-resiliency.html?utm_source=chatgpt.com "Resilience in Amazon Aurora DSQL"
[15]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/multi-region-aws-cli.html?utm_source=chatgpt.com "Using AWS CLI - Amazon Aurora DSQL"
[16]: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/what-is-aurora-dsql.html?utm_source=chatgpt.com "Region availability for Aurora DSQL"
[17]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html?utm_source=chatgpt.com "Replicating objects within and across Regions"
[18]: https://docs.aws.amazon.com/hands-on/latest/replicate-data-using-amazon-s3-replication/replicate-data-using-amazon-s3-replication.html?utm_source=chatgpt.com "Replicate Data within and between AWS Regions"
[19]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-config-for-kms-objects.html?utm_source=chatgpt.com "Replicating encrypted objects (SSE-S3, SSE-KMS, DSSE ..."
[20]: https://docs.aws.amazon.com/efs/latest/ug/efs-replication.html?utm_source=chatgpt.com "Replicating EFS file systems"
[21]: https://docs.aws.amazon.com/efs/latest/ug/replicate-existing-destination.html?utm_source=chatgpt.com "Configuring replication to an existing EFS file system"
[22]: https://docs.aws.amazon.com/efs/latest/ug/replication-fail-over.html?utm_source=chatgpt.com "Using the replica - Amazon Elastic File System"
[23]: https://docs.aws.amazon.com/ebs/latest/userguide/ebs-copy-snapshot.html?utm_source=chatgpt.com "Copy an Amazon EBS snapshot"
[24]: https://docs.aws.amazon.com/ebs/latest/userguide/time-based-copies.html?utm_source=chatgpt.com "Time-based copies for Amazon EBS snapshots and EBS-backed AMIs"
[25]: https://docs.aws.amazon.com/ebs/latest/userguide/event-policy.html?utm_source=chatgpt.com "Automate cross-account snapshot copies with Data Lifecycle Manager"
[26]: https://docs.aws.amazon.com/aws-backup/latest/devguide/backup-feature-availability.html?utm_source=chatgpt.com "AWS Backup feature availability"
[27]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/globaltables-CoreConcepts.html?utm_source=chatgpt.com "Global tables core concepts - Amazon DynamoDB"
[28]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-time-control.html?utm_source=chatgpt.com "Meeting compliance requirements with S3 Replication ..."
