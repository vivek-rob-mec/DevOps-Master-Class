# AWS Masterclass — Lesson 28 Part 1

# Database Architecture, Amazon RDS, Multi-AZ & Read Replicas

We have finished the major AWS storage models:

```text
EBS
=
block storage

EFS
=
shared file storage

S3
=
object storage
```

Now we enter a fundamentally different problem:

```text
How do applications store
RELATIONSHIPS
TRANSACTIONS
STATE
and
QUERYABLE BUSINESS DATA?
```

That brings us to databases.

---

# 1. Storage Is Not Automatically a Database

Suppose our Todo application stores:

```json
{
  "user_id": 1001,
  "todo": "Learn RDS",
  "completed": false
}
```

We *could* put this JSON in S3:

```text
s3://todo-data/users/1001/todo-001.json
```

But then imagine queries such as:

```text
Give me all incomplete todos

for users created this month

ordered by priority

where subscription = premium
```

S3 object storage isn't designed to provide normal relational query semantics such as joins, indexes, constraints, and transactions.

A database is designed specifically to maintain and query application state.

---

# 2. Our AWS Database Decision Tree

At a high level:

```text
                       APPLICATION DATA
                              │
                              ▼
                    How is data accessed?
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
        RELATIONAL          NoSQL           CACHE
             │                │                │
             ▼                ▼                ▼
       RDS / Aurora       DynamoDB        ElastiCache
```

AWS's current database portfolio includes relational systems such as RDS/Aurora and purpose-built non-relational services such as DynamoDB. ([AWS Documentation][1])

Mental shortcut:

```text
SQL relationships
transactions
joins
constraints
      │
      ▼
RDS / Aurora
```

```text
Known access patterns
massive horizontal scale
key-value/document
      │
      ▼
DynamoDB
```

```text
Very fast temporary copy
of frequently used data
      │
      ▼
ElastiCache
```

These are **not mutually exclusive**.

A production application can use all three.

---

# 3. Example Production Stack

Imagine an e-commerce application:

```text
                           Application
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
          Aurora           DynamoDB          ElastiCache
            │                  │                  │
          orders            sessions             cache
          payments          carts                hot data
          customers         events               API results
```

The correct question isn't:

> Which AWS database is best?

It is:

> **Which database model best matches this specific workload?**

---

# 4. Relational Database Mental Model

A relational database stores data primarily in:

```text
Tables
  │
  ├── Rows
  │
  └── Columns
```

Example:

### users

|  id | name  | email                                         |
| --: | ----- | --------------------------------------------- |
| 101 | Vivek | [vivek@example.com](mailto:vivek@example.com) |
| 102 | Alice | [alice@example.com](mailto:alice@example.com) |

### orders

| order_id | user_id | amount |
| -------: | ------: | -----: |
|     5001 |     101 |   1500 |
|     5002 |     101 |   2100 |
|     5003 |     102 |    900 |

Now:

```text
users.id
      │
      ▼
orders.user_id
```

creates a relationship.

SQL can then do something conceptually like:

```sql
SELECT
    users.name,
    orders.order_id,
    orders.amount
FROM users
JOIN orders
    ON users.id = orders.user_id;
```

This ability to model interconnected structured data is one of the central strengths of relational databases. ([AWS Documentation][1])

---

# 5. Primary Key

A:

```text
PRIMARY KEY
```

uniquely identifies a row.

Example:

```text
users

id
----
101
102
103
```

You should not have:

```text
101
101
```

as two separate primary-key identities.

Think:

```text
Primary Key
=
WHO exactly is this row?
```

---

# 6. Foreign Key

A:

```text
FOREIGN KEY
```

references another table.

Example:

```text
orders.user_id
      │
      ▼
users.id
```

This lets the database model:

```text
User
  │
  └── has many Orders
```

We'll later go deeper into:

```text
constraints
normalization
indexes
transactions
isolation
locks
deadlocks
query plans
```

because database architecture is much more than provisioning an RDS instance.

---

# 7. Why Transactions Matter

Imagine transferring ₹1,000:

```text
Account A
₹10,000
```

to:

```text
Account B
₹5,000
```

The operation conceptually requires:

```text
A:
10,000 → 9,000

AND

B:
5,000 → 6,000
```

You do **not** want:

```text
A decreased

BUT

B never increased
```

because the application crashed halfway through.

Databases solve these problems using transactions.

Conceptually:

```sql
BEGIN;

UPDATE accounts
SET balance = balance - 1000
WHERE id = 'A';

UPDATE accounts
SET balance = balance + 1000
WHERE id = 'B';

COMMIT;
```

Either the transaction commits correctly, or application/database recovery semantics prevent you from treating an incomplete transaction as a successful business operation.

This is part of why relational databases remain important even in cloud-native systems.

---

# 8. Amazon RDS

RDS means:

# Amazon Relational Database Service

Amazon RDS is AWS's managed relational database service.

AWS currently supports familiar RDS engines including:

```text
PostgreSQL
MySQL
MariaDB
Oracle Database
Microsoft SQL Server
IBM Db2
```

AWS manages much of the infrastructure work such as provisioning, hardware maintenance, backups, and software-management tasks depending on engine/configuration. ([AWS Documentation][2])

---

# 9. RDS vs Database on EC2

This distinction is extremely important.

## Database on EC2

```text
EC2
 │
 └── PostgreSQL
```

You manage:

```text
EC2
OS
patching
database installation
storage
replication
backup scripts
failover
monitoring
database process
filesystem
security
upgrades
```

You have:

```text
more control
```

but also:

```text
more responsibility
```

---

# 10. Amazon RDS

With RDS:

```text
                 AWS-managed infrastructure
                           │
                           ▼
                    ┌────────────┐
                    │   RDS      │
                    │ PostgreSQL │
                    └────────────┘
                           ▲
                           │
                        Your app
```

AWS takes on much of the undifferentiated infrastructure management. ([AWS Documentation][2])

But **managed does not mean AWS manages your application database design**.

You still own things like:

```text
schema design
tables
indexes
SQL
query tuning
users
credentials
parameter decisions
database sizing
application connection logic
security rules
backup retention strategy
maintenance choices
cost
```

### Never forget

```text
RDS
=
managed database infrastructure

NOT

managed application database architecture
```

---

# 11. What RDS Does NOT Give You

RDS does not magically fix:

```sql
SELECT *
FROM orders
WHERE LOWER(description) LIKE '%something%';
```

running across:

```text
2 billion rows
```

with no useful indexing.

If the application creates terrible SQL:

```text
RDS
```

can still become slow.

Likewise:

```text
CPU = 100%
```

doesn't automatically mean:

```text
increase instance size
```

It might mean:

```text
missing index
bad join
N+1 queries
connection storm
bad query plan
locking
poor schema
```

Database troubleshooting requires looking **inside the database**, not only at AWS infrastructure.

---

# 12. Basic RDS Architecture

A production application should usually resemble:

```text
                          Internet
                             │
                             ▼
                            ALB
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
             EC2-A                     EC2-B
             App-SG                    App-SG
                │                         │
                └──────────┬──────────────┘
                           │
                       TCP 5432
                           │
                           ▼
                     PostgreSQL RDS
                         DB-SG
                           │
                    Private Subnets
```

For MySQL:

```text
TCP 3306
```

PostgreSQL:

```text
TCP 5432
```

SQL Server often:

```text
TCP 1433
```

The exact port can be configured, but the important security principle is:

```text
Database SG
inbound
FROM App-SG
```

rather than:

```text
5432
0.0.0.0/0
```

---

# 13. Database Should Normally Be Private

Bad architecture:

```text
Internet
   │
   ▼
RDS PostgreSQL
publicly accessible
```

Better:

```text
Internet
   │
   ▼
ALB
   │
   ▼
Application
private subnet
   │
   ▼
RDS
private database subnet
```

The application—not the public internet—should normally be the database client.

---

# 14. DB Subnet Group

RDS introduces an important networking concept:

# DB Subnet Group

Think:

```text
VPC
 │
 ├── DB subnet A
 │       ap-south-1a
 │
 └── DB subnet B
         ap-south-1b
```

Then:

```text
DB Subnet Group
=
[subnet-a, subnet-b]
```

RDS DB subnet groups must cover at least two Availability Zones, which prepares the environment for Multi-AZ placement and failover. ([AWS Documentation][3])

---

# 15. Why Not One DB Subnet?

Because production databases need availability options.

If the only subnet were:

```text
ap-south-1a
```

where should AWS place the standby when you configure:

```text
Multi-AZ?
```

There is no second AZ.

Therefore:

```text
DB Subnet Group

AZ-A subnet
+
AZ-B subnet
```

is a foundational RDS networking design.

---

# 16. Production VPC Architecture

Our standard architecture becomes:

```text
                         VPC 10.28.0.0/16

                   ┌─────────────┴─────────────┐
                   │                           │
             ap-south-1a                 ap-south-1b
                   │                           │
          Public Subnet A              Public Subnet B
                   │                           │
                   └──────── ALB ──────────────┘
                               │
                   ┌───────────┴───────────┐
                   ▼                       ▼
             Private App A            Private App B
                  EC2                       EC2
                   │                         │
                   └──────────┬──────────────┘
                              ▼
                         DB Subnet Group
                   ┌──────────┴──────────┐
                   ▼                     ▼
               DB subnet A           DB subnet B
                   │                     │
                   └────── Amazon RDS ───┘
```

Notice that:

```text
App subnet
```

and:

```text
DB subnet
```

can be separated logically for cleaner routing/security design.

---

# 17. Security Group Pattern

Application:

```text
App-SG
```

Database:

```text
DB-SG
```

Database inbound:

```text
PostgreSQL

TCP 5432
Source:
App-SG
```

Architecture:

```text
EC2
App-SG
   │
   │ TCP 5432
   ▼
RDS
DB-SG
```

This is much more precise than:

```text
5432
10.0.0.0/8
```

or especially:

```text
5432
0.0.0.0/0
```

---

# 18. Applications Connect to an Endpoint

RDS gives you a DNS endpoint such as:

```text
prod-db.xxxxx.ap-south-1.rds.amazonaws.com
```

Your application uses:

```text
DB_HOST=prod-db.xxxxx.ap-south-1.rds.amazonaws.com
```

not:

```text
DB_HOST=10.28.21.74
```

Why?

Because the underlying physical database host can change.

This becomes extremely important during failover.

---

# 19. Do Not Hardcode the Database IP

Imagine:

```text
Primary RDS
10.0.21.50
```

fails.

RDS promotes a standby elsewhere.

Now physical infrastructure has changed.

But your application should continue using:

```text
prod-db.xxxx.rds.amazonaws.com
```

RDS updates DNS during Multi-AZ DB instance failover so that the endpoint points to the new primary. Existing database connections must then be re-established. ([AWS Documentation][4])

### Never forget

```text
RDS Endpoint
=
stable application target

IP
=
implementation detail
```

---

# 20. Single-AZ RDS

Let's start simple.

```text
                    ap-south-1a
                         │
                         ▼
                    Primary RDS
                         │
                 READ + WRITE
```

This is:

```text
Single-AZ
```

There is one active database instance placement.

This can be suitable for:

```text
development
testing
noncritical environments
cost-sensitive workloads
```

when the business can tolerate longer recovery from an AZ/instance failure.

---

# 21. What Happens if Single-AZ Database Fails?

Your application might lose database connectivity until RDS repairs/replaces/restarts resources or you restore/recover according to the failure class.

The important point:

```text
Single-AZ
```

doesn't give you the automatic standby failover architecture we are about to build.

---

# 22. Classic RDS Multi-AZ DB Instance

Now:

```text
                        RDS
                         │
              ┌──────────┴──────────┐
              │                     │
        ap-south-1a            ap-south-1b
              │                     │
              ▼                     ▼
          PRIMARY                STANDBY
        READ + WRITE              HA only
              │                     ▲
              │                     │
              └─ synchronous ───────┘
                 replication
```

For a traditional **Multi-AZ DB instance deployment**, RDS maintains one standby replica in another AZ. Replication to that standby is synchronous, and the standby does **not** serve application read traffic. ([AWS Documentation][5])

This exists primarily for:

# HIGH AVAILABILITY

---

# 23. What Is Synchronous Replication?

Simplified mental model:

```text
Application

INSERT order
    │
    ▼
Primary
    │
    ├── write locally
    │
    └── replicate to standby
             │
             ▼
           standby
             │
             ▼
          acknowledge
             │
             ▼
       transaction success
```

This reduces the risk of the standby being significantly behind when it needs to take over.

But there can be some added write latency because the high-availability path requires synchronous replication. ([AWS Documentation][5])

---

# 24. Standby Is NOT a Read Replica

This is the classic AWS exam trap.

Traditional Multi-AZ:

```text
Primary
READ + WRITE
     │
     ▼
Standby
NO application reads
```

You cannot say:

> “We have Multi-AZ, so let's send SELECT queries to the standby.”

For a classic Multi-AZ DB **instance** deployment, the standby exists for failover—not read scaling. ([AWS Documentation][6])

---

# 25. Multi-AZ Failover

Normal:

```text
Application
     │
     ▼
RDS endpoint
     │
     ▼
Primary AZ-A
```

Failure:

```text
Primary AZ-A
     X
```

RDS:

```text
detects failure
     │
     ▼
promotes standby
     │
     ▼
AZ-B becomes primary
     │
     ▼
updates endpoint DNS
```

Your application:

```text
same endpoint hostname
```

but needs to establish new connections after failover. ([AWS Documentation][4])

---

# 26. Failover Does Not Preserve TCP Connections

Imagine Node.js has:

```text
connection 1
connection 2
connection 3
```

to the old primary.

Failover happens.

Those connections don't magically teleport to another host.

They fail.

Your application/database driver needs:

```text
retry
reconnect
connection pool recovery
```

RDS changes the DNS target, but existing client connections must reconnect. ([AWS Documentation][4])

This is why **application resilience is part of database HA**.

---

# 27. Multi-AZ Does Not Mean Zero Downtime

Another important misconception:

```text
Multi-AZ
=
zero downtime
```

No.

Better mental model:

```text
Multi-AZ
=
automated high availability
+
reduced recovery time
```

There is still a failover period.

Applications should be engineered for transient database connection failures.

---

# 28. What Causes Failover?

Examples can include:

```text
instance infrastructure failure
AZ disruption
some storage/network problems
planned maintenance scenarios
manual failover testing
```

The exact behavior depends on the deployment/engine.

The key lesson isn't memorizing every trigger.

It's:

```text
Primary unavailable
       ↓
RDS detects
       ↓
standby promoted
       ↓
DNS changes
       ↓
clients reconnect
```

---

# 29. Read Replica

Now solve a *different* problem.

Suppose one database handles:

```text
20% writes
80% reads
```

Primary CPU:

```text
90%
```

because millions of:

```sql
SELECT ...
```

queries keep hitting it.

Instead:

```text
                    PRIMARY
                  READ + WRITE
                       │
            asynchronous replication
                       │
           ┌───────────┴───────────┐
           ▼                       ▼
      Read Replica 1          Read Replica 2
          READ                    READ
```

Read replicas are primarily used to **scale read workloads**. RDS asynchronously copies source changes to read replicas. ([AWS Documentation][5])

---

# 30. The Fundamental Difference

Memorize this:

```text
MULTI-AZ
=
availability
```

```text
READ REPLICA
=
read scalability
```

That is the classic mental model.

But later we'll add an important modern nuance because current RDS Multi-AZ **clusters** have readable standby instances.

---

# 31. Read Replica Is Asynchronous

Suppose:

```text
Primary:

balance = ₹10,000
```

write:

```text
balance = ₹9,000
```

Primary commits.

Read replica might temporarily still show:

```text
₹10,000
```

until the replication change arrives/applies.

This is:

```text
replica lag
```

RDS read replicas use asynchronous replication, so applications must account for the possibility of lag. ([AWS Documentation][7])

---

# 32. Read-After-Write Problem

Application:

```text
1. user changes profile

2. app writes PRIMARY

3. app immediately reads REPLICA

4. replica hasn't caught up
```

User sees:

```text
old profile
```

even though the write succeeded.

This is why applications sometimes route:

```text
writes
+
immediately consistent reads
```

to the writer/primary.

And route:

```text
eventually consistent read-heavy work
```

to read replicas.

---

# 33. Example Read Routing

```text
Application
     │
     ├── INSERT
     ├── UPDATE
     ├── DELETE
     │
     ▼
   PRIMARY


Application
     │
     ├── reports
     ├── product browsing
     ├── analytics-like reads
     └── search-like relational queries
     │
     ▼
READ REPLICA
```

The exact split depends on consistency requirements.

---

# 34. Read Replica Has Its Own Endpoint

Example:

```text
Primary:

prod-db.xxxx.rds.amazonaws.com
```

Read replica:

```text
prod-db-read-1.xxxx.rds.amazonaws.com
```

Your application may need explicit routing logic:

```javascript
writerPool.query(
  "UPDATE users SET ..."
);

readerPool.query(
  "SELECT ..."
);
```

Classic RDS DB instance read replicas don't automatically cause your application to start using them just because you created one.

---

# 35. Read Replica Doesn't Scale Writes

Suppose database load is:

```text
90% INSERT/UPDATE

10% SELECT
```

Adding:

```text
5 read replicas
```

doesn't solve your writer bottleneck.

Architecture remains:

```text
ALL writes
   │
   ▼
PRIMARY
```

while replicas receive copies afterward.

### Never forget

```text
Read Replica
=
scale reads OUT

NOT
=
scale writes OUT
```

---

# 36. Read Replica Can Be Cross-Region

RDS supports read replicas in another AWS Region for supported engines/configurations. Typical goals include read locality, migrations, and improving DR options. ([AWS Documentation][8])

Example:

```text
                PRIMARY
              ap-south-1
                  │
          async replication
                  │
                  ▼
             READ REPLICA
            ap-southeast-1
```

Potential use:

```text
India writes
Singapore reads
```

or:

```text
regional DR preparation
```

But remember:

```text
async
=
replication lag possible
```

---

# 37. Can a Read Replica Become a Database?

Yes.

RDS supports promoting a read replica to a standalone DB instance. ([AWS Documentation][9])

Conceptually:

```text
PRIMARY
   │
   ▼
Read Replica
```

then:

```text
Promote
   │
   ▼
Standalone writable database
```

Possible uses:

```text
DR
migration
testing
database branching workflows
```

depending on engine/workload.

---

# 38. But Read Replica Promotion Is Not the Same as Multi-AZ Automatic Failover

Classic Multi-AZ:

```text
failure
 ↓
AWS detects
 ↓
AWS promotes standby
 ↓
endpoint changes automatically
```

Read replica DR:

```text
failure
 ↓
replication state?
 ↓
promote replica
 ↓
change application traffic
```

Read-replica promotion can support recovery, but AWS explicitly calls out the asynchronous-replication implications. ([AWS Documentation][9])

Therefore:

```text
Multi-AZ
=
HA mechanism
```

and:

```text
Read Replica
=
primarily scaling,
potential DR building block
```

---

# 39. Multi-AZ + Read Replica Together

These aren't mutually exclusive.

Architecture:

```text
                           Primary
                              │
                 ┌────────────┴────────────┐
                 │                         │
        synchronous HA              asynchronous
                 │                    replication
                 ▼                         │
              Standby                      ▼
             another AZ              Read Replica
                                        another AZ
```

AWS explicitly supports a read replica sourced from a DB instance that also uses Multi-AZ. ([AWS Documentation][5])

Now:

```text
Standby
=
availability
```

and:

```text
Read Replica
=
read scaling
```

---

# 40. The Modern Nuance: RDS Has TWO Multi-AZ Architectures

This is very important because old tutorials often explain only:

```text
Primary + one standby
```

Current RDS has:

```text
1. Multi-AZ DB instance deployment

2. Multi-AZ DB cluster deployment
```

AWS distinguishes these explicitly. ([AWS Documentation][6])

---

# 41. Multi-AZ DB Instance

Classic:

```text
                 Multi-AZ DB INSTANCE

            AZ-A                  AZ-B
             │                     │
             ▼                     ▼
          PRIMARY               STANDBY
        READ/WRITE              HA ONLY
```

Characteristics:

```text
1 primary
1 standby
2 AZs
standby not readable
```

([AWS Documentation][6])

---

# 42. Multi-AZ DB Cluster

Modern Multi-AZ cluster:

```text
                    Multi-AZ DB CLUSTER

             AZ-A          AZ-B          AZ-C
              │             │             │
              ▼             ▼             ▼
           WRITER        READER        READER
         read/write       read          read
              │             │             │
              └─────────────┼─────────────┘
                         HA cluster
```

Current RDS Multi-AZ DB clusters have:

```text
1 writer
+
2 readable readers
+
3 separate AZs
```

and currently support **MySQL and PostgreSQL** engines. ([AWS Documentation][10])

---

# 43. This Changes the Old Exam Shortcut

Older/simple teaching:

```text
Multi-AZ
=
standby not readable
```

That remains correct for:

# Multi-AZ DB instance deployment

But **not universally for all current RDS Multi-AZ architectures**.

Multi-AZ DB cluster readers:

```text
CAN serve read traffic
```

and can also serve as failover targets. ([AWS Documentation][11])

So the updated mental model is:

```text
Multi-AZ DB INSTANCE
=
HA
standby cannot serve reads


Multi-AZ DB CLUSTER
=
HA
+
two readable standby/readers
```

---

# 44. Multi-AZ Cluster Endpoints

A Multi-AZ DB cluster exposes connection concepts such as:

```text
writer endpoint
```

and:

```text
reader endpoint
```

Writer:

```text
Application writes
       │
       ▼
Writer Endpoint
       │
       ▼
current writer
```

Readers:

```text
Application reads
       │
       ▼
Reader Endpoint
       │
       ▼
reader instance(s)
```

When a writer fails, RDS promotes a reader and the writer endpoint reconnects applications to the new writer. ([AWS Documentation][12])

---

# 45. Updated Multi-AZ vs Read Replica Table

| Feature                | Multi-AZ DB Instance     | Multi-AZ DB Cluster             | Read Replica                        |
| ---------------------- | ------------------------ | ------------------------------- | ----------------------------------- |
| Main purpose           | HA                       | HA + read capacity              | Read scaling                        |
| Replication model      | Synchronous              | HA-oriented cluster replication | Asynchronous                        |
| Standby readable?      | No                       | Yes                             | Yes                                 |
| Automatic failover     | Yes                      | Yes                             | Not the same automatic HA mechanism |
| Separate read endpoint | No standby endpoint      | Reader endpoint                 | Replica endpoint                    |
| Cross-Region           | Not as one Multi-AZ pair | Regional cluster                | Supported in many configurations    |
| Replica lag concern    | Not read-facing          | Cluster readers monitored       | Yes                                 |
| Can promote manually?  | Automatic standby role   | Readers are failover targets    | Yes, to standalone                  |

The first two deployment types and their readable/failover behavior are documented by current RDS guidance; traditional read replicas use asynchronous replication. ([AWS Documentation][6])

---

# 46. Modern Interview Question

Interviewer:

> What's the difference between RDS Multi-AZ and a Read Replica?

A weak answer:

> Multi-AZ is HA and read replicas are scaling.

That's directionally correct but incomplete in 2026.

A stronger answer:

> For the traditional RDS Multi-AZ DB instance deployment, RDS synchronously maintains a standby in another AZ for automatic failover, and that standby doesn't serve application reads. Standard RDS read replicas use asynchronous replication and are primarily used to scale read-heavy workloads, so replication lag is possible. Current RDS also offers Multi-AZ DB clusters for MySQL and PostgreSQL, which use a writer plus two readable instances across three AZs; those readers both serve read traffic and act as automatic failover targets. ([AWS Documentation][5])

That's the current answer.

---

# 47. Which Architecture Would You Choose?

### Development database

```text
Single-AZ
```

may be enough.

---

### Critical production OLTP database

At minimum evaluate:

```text
Multi-AZ
```

because availability matters.

---

### Critical production + heavy read traffic

Evaluate:

```text
Multi-AZ
+
Read Replica
```

or:

```text
Multi-AZ DB Cluster
```

depending on engine, performance, availability, cost, and scaling requirements.

---

### Global read traffic / DR

Evaluate:

```text
Cross-Region Read Replica
```

or, as we'll soon learn:

```text
Aurora Global Database
```

depending on engine/design requirements.

---

# 48. RDS Storage

Your database still needs underlying storage.

For normal RDS DB instances, AWS currently supports General Purpose SSD storage such as:

```text
gp2
gp3
```

and Provisioned IOPS families such as:

```text
io1
io2 Block Express
```

with exact supported ranges depending on engine and configuration. ([AWS Documentation][13])

This connects directly to Lesson 25.

---

# 49. gp3 vs io2 Mental Model for RDS

Think:

```text
General application database
reasonable performance/cost
        │
        ▼
       gp3
```

versus:

```text
mission-critical
IOPS-sensitive database
high consistent storage demand
        │
        ▼
       io2
```

But never size database storage based only on:

```text
GB
```

You must consider:

```text
capacity
IOPS
throughput
latency
working set
query shape
instance class
```

Storage and compute bottlenecks remain separate.

---

# 50. RDS Storage Autoscaling

RDS can automatically increase allocated storage when configured with storage autoscaling.

Current AWS behavior can trigger a storage modification when free space remains at or below 10% for at least five minutes, subject to the autoscaling conditions and configured maximum storage threshold. ([AWS Documentation][14])

Conceptually:

```text
Allocated:
100 GiB

Free:
9 GiB

low storage condition persists
        │
        ▼
RDS Storage Autoscaling
        │
        ▼
increase allocated capacity
```

Very useful.

But:

```text
storage autoscaling
≠
database performance autoscaling
```

---

# 51. Storage Autoscaling Does NOT Fix a Bad Query

Suppose:

```text
FreeStorageSpace
=
500 GB
```

but:

```text
CPU
=
100%
```

because:

```sql
SELECT *
FROM event_history
ORDER BY LOWER(payload);
```

Storage autoscaling won't help.

Likewise:

```text
IO latency huge
```

might be a:

```text
storage performance
```

problem rather than:

```text
storage capacity
```

problem.

Always identify the actual bottleneck.

---

# 52. Cannot Normally Shrink Allocated Storage

A familiar EBS concept returns here.

For RDS DB storage:

```text
increase
=
possible
```

but:

```text
reduce allocated storage directly
=
generally not supported
```

For example, AWS's current gp3 modification guidance explicitly says allocated storage can't be reduced directly. ([AWS Documentation][15])

Shrinking generally requires a migration/rebuild-style strategy rather than modifying the same database downward.

---

# 53. App + DB Architecture

Our production Todo application could become:

```text
                         Internet
                            │
                            ▼
                           ALB
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
           EC2-A                       EC2-B
         Node.js App                 Node.js App
           App-SG                      App-SG
              │                           │
              └────────────┬──────────────┘
                           │
                     DB endpoint
                           │
                           ▼
                    PostgreSQL RDS
                         DB-SG
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
           AZ-A                       AZ-B
        Primary                     Standby
```

And static assets/uploads might separately use:

```text
S3
```

This is how services compose:

```text
EC2
=
compute

RDS
=
transactional database

S3
=
objects

EFS
=
shared POSIX files
```

---

# 54. Database Credentials

Don't hardcode:

```javascript
const password = "ProdPassword123";
```

inside:

```text
Git repository
Dockerfile
AMI
user data
```

Production systems should use a managed secret approach such as:

```text
AWS Secrets Manager
```

or appropriate secure configuration mechanisms.

We'll cover:

```text
Secrets Manager
automatic rotation
IAM authorization
RDS integration
```

in an upcoming database security section.

---

# 55. Connection Storm Problem

Imagine:

```text
ASG

2 instances
→ 100 instances
```

Each Node.js instance creates:

```text
100 DB connections
```

Suddenly:

```text
100 × 100
=
10,000 connections
```

hit RDS.

Database becomes overwhelmed even if:

```text
application CPU
looks fine.
```

This is a very common database architecture problem.

It leads us eventually to:

# Amazon RDS Proxy

```text
Applications
      │
      │ many client connections
      ▼
   RDS Proxy
      │
      │ pooled/reused DB connections
      ▼
      RDS
```

We'll cover it deeply later.

---

# 56. Auto Scaling and Database Scaling Are Different

App tier:

```text
EC2
2 → 20 instances
```

is relatively straightforward.

Database:

```text
1 writer
```

doesn't become:

```text
10 independent writable relational primaries
```

just because application load increases.

Database scaling requires thinking about:

```text
vertical compute scaling
read replicas
caching
query optimization
connection pooling
partitioning
Aurora architecture
sometimes redesigning access patterns
```

This is why databases are often the hardest stateful component to scale.

---

# 57. SAA-C03 Scenario 1

> Critical PostgreSQL database must automatically survive an instance/AZ failure. No requirement to scale reads.

First thought:

```text
RDS Multi-AZ
```

not:

```text
Read Replica only
```

because the requirement is:

```text
availability
```

rather than read scaling. ([AWS Documentation][6])

---

# 58. Scenario 2

> Database handles huge numbers of SELECT queries, but writes are moderate.

Think:

```text
Read Replicas
```

to offload read traffic. ([AWS Documentation][7])

---

# 59. Scenario 3

> An RDS Multi-AZ DB instance standby should handle reporting queries.

Answer:

```text
NO
```

Traditional Multi-AZ DB instance standby doesn't serve reads. ([AWS Documentation][6])

If you need:

```text
HA
+
readable instances
```

evaluate:

```text
Multi-AZ DB Cluster
```

for supported MySQL/PostgreSQL versions/configurations. ([AWS Documentation][10])

---

# 60. Scenario 4

> Application writes a row and immediately reads from a standard read replica but occasionally gets the old value.

Likely:

```text
replication lag
```

because the read replica uses asynchronous replication. ([AWS Documentation][7])

Route consistency-sensitive reads to the writer or design your application around the consistency semantics.

---

# 61. Scenario 5

> Need database read capacity closer to users in another AWS Region.

Consider:

```text
Cross-Region Read Replica
```

for supported RDS engines/configurations. ([AWS Documentation][8])

---

# 62. Scenario 6

> Database IP changed and the application stopped working.

Likely architectural mistake:

```text
hardcoded IP
```

Applications should use the RDS DNS endpoint, especially because Multi-AZ failover changes the endpoint's underlying network destination. ([AWS Documentation][4])

---

# 63. Scenario 7

> RDS storage is 95% full.

Possible:

```text
enable/configure Storage Autoscaling
```

but also ask:

```text
Why is data growing?

logs?
history?
bad retention?
temporary tables?
unexpected ingestion?
```

Storage autoscaling prevents immediate capacity exhaustion; it doesn't replace data lifecycle engineering. ([AWS Documentation][14])

---

# 64. Failure Troubleshooting Chain

Application says:

```text
Database unavailable
```

Don't immediately restart RDS.

Use:

```text
Application
     │
     ▼
DNS endpoint resolves?
     │
     ▼
TCP reachable?
     │
     ▼
Security Groups?
     │
     ▼
RDS status?
     │
     ▼
Failover happening?
     │
     ▼
Credentials valid?
     │
     ▼
DB connections exhausted?
     │
     ▼
Database engine responding?
     │
     ▼
Locks / query issues?
```

This separates:

```text
network
authentication
capacity
availability
database engine
application
```

problems.

---

# 65. `Connection timed out`

Think primarily:

```text
network path
```

Check:

```text
RDS SG
App SG
route/NACL
public/private design
correct endpoint
correct port
```

---

# 66. `password authentication failed`

Don't edit the security group.

Networking already worked well enough to reach PostgreSQL.

Think:

```text
username
password
Secrets Manager value
database user
authentication configuration
```

This parallels our EFS troubleshooting principle:

```text
different symptom
=
different layer
```

---

# 67. `too many connections`

Again, not primarily a subnet problem.

Think:

```text
application connection pool
connection leaks
ASG scale-out
Lambda concurrency
DB connection limit
RDS Proxy
```

---

# 68. Queries Slow but CPU Low

Investigate:

```text
locks
storage latency
query plan
indexes
connection waits
database wait events
```

not merely:

```text
increase instance size
```

We'll learn:

```text
Performance Insights / Database Insights
Enhanced Monitoring
CloudWatch
slow query logs
EXPLAIN
```

in the advanced RDS operations lesson.

---

# 69. Never-Forget RDS Architecture

```text
                         APPLICATION
                              │
                              ▼
                           App-SG
                              │
                         DB endpoint
                              │
                              ▼
                           DB-SG
                              │
                              ▼
                         Amazon RDS
                              │
             ┌────────────────┼────────────────┐
             │                │                │
             ▼                ▼                ▼
          Single-AZ      Multi-AZ         Read Replica
                              │                │
                              ▼                ▼
                         AVAILABILITY       READ SCALE
```

Then modernize it:

```text
             MULTI-AZ OPTIONS

      Multi-AZ DB Instance
               │
        Primary + Standby
               │
          standby HA only


      Multi-AZ DB Cluster
               │
     Writer + Reader + Reader
               │
         3 separate AZs
               │
      HA + readable capacity
```

---

# 70. The Most Important Difference

Burn this into memory:

```text
Traditional
Multi-AZ DB Instance

PRIMARY
   │
synchronous
   ▼
STANDBY

Goal:
HIGH AVAILABILITY
```

versus:

```text
Standard
Read Replica

PRIMARY
   │
asynchronous
   ▼
REPLICA

Goal:
READ SCALABILITY
```

And the modern addition:

```text
Multi-AZ DB Cluster

WRITER
   │
   ├──── READER
   └──── READER

Goal:
HIGH AVAILABILITY
+
READ CAPACITY
```

([AWS Documentation][5])

---

# 71. Fifteen Rules to Permanently Remember

```text
1. RDS is managed relational database infrastructure.

2. RDS does not fix bad SQL or bad schema design.

3. Keep production databases private whenever practical.

4. DB subnet groups span at least two AZs.

5. App-SG → DB-SG is the preferred SG pattern.

6. Applications connect using RDS DNS endpoints.

7. Never depend on an RDS host IP staying fixed.

8. Single-AZ is not the same HA architecture as Multi-AZ.

9. Classic Multi-AZ DB instance has primary + standby.

10. Classic standby does not serve reads.

11. Standard read replicas use asynchronous replication.

12. Read replicas scale reads, not primary writes.

13. Replica lag can create stale reads.

14. Current Multi-AZ DB clusters have writer + two
    readable instances across three AZs.

15. Application retry/reconnection logic is part of HA.
```

And the shortest interview memory trick:

```text
MULTI-AZ
=
SURVIVE
```

```text
READ REPLICA
=
SCALE READS
```

with the modern caveat:

```text
MULTI-AZ CLUSTER
=
SURVIVE
+
READ
```

---

# ✅ Lesson 28 Part 1 Complete

You now understand:

```text
✓ database vs storage
✓ relational mental model
✓ primary keys
✓ foreign keys
✓ transactions
✓ AWS database decision tree
✓ Amazon RDS
✓ RDS vs database on EC2
✓ RDS engines
✓ production VPC architecture
✓ DB subnet groups
✓ security groups
✓ private RDS
✓ RDS endpoints
✓ Single-AZ
✓ Multi-AZ DB instance
✓ synchronous standby replication
✓ automatic failover
✓ DNS failover
✓ application reconnection
✓ read replicas
✓ asynchronous replication
✓ replica lag
✓ read scaling
✓ cross-Region replicas
✓ promotion
✓ Multi-AZ + read replica
✓ Multi-AZ DB cluster
✓ writer / reader endpoints
✓ gp3 / io2 concepts
✓ storage autoscaling
✓ database connection storms
✓ RDS Proxy preview
✓ production troubleshooting
```

# Next — Lesson 28 Part 2: **Amazon Aurora Architecture**

This is where things become especially interesting because Aurora doesn't simply behave like:

```text
"normal RDS PostgreSQL
with a fancy name"
```

We'll dissect:

```text
                   AURORA CLUSTER
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
          Writer        Reader       Reader
             \            |            /
              \           |           /
                 Shared Cluster Volume
                          │
                 six storage copies
                          │
                  across three AZs
```

Current Aurora synchronously replicates database data across **six storage nodes spanning three Availability Zones**, independent of whether you have reader compute instances. Aurora clusters can also have up to **15 Aurora Replicas**. ([AWS Documentation][16])

Next we'll cover:

```text
→ Aurora MySQL vs Aurora PostgreSQL
→ compute vs shared storage separation
→ cluster volume
→ six copies / three AZs
→ writer instance
→ Aurora Replicas
→ cluster endpoint
→ reader endpoint
→ instance endpoints
→ automatic failover
→ failover tiers
→ why Aurora replicas are different from RDS replicas
→ storage auto-growth
→ I/O architecture
→ Aurora Serverless v2
→ ACUs
→ scaling ranges
→ Aurora Global Database
→ cross-Region DR
→ write forwarding concepts
→ RDS Proxy
→ connection storms
→ Secrets Manager
→ backups / PITR
→ cloning
→ Blue/Green strategies
→ Terraform
→ production architecture lab
```

That next lesson will answer one of the most important architect questions:

> **“Why would I pay for Aurora instead of simply running RDS PostgreSQL Multi-AZ?”**

[1]: https://docs.aws.amazon.com/databases-on-aws-how-to-choose/?utm_source=chatgpt.com "Choosing an AWS database service"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html?utm_source=chatgpt.com "What is Amazon Relational Database Service (Amazon RDS)?"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html?utm_source=chatgpt.com "Creating an Amazon RDS DB instance - AWS Documentation"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html?utm_source=chatgpt.com "Failing over a Multi-AZ DB instance for Amazon RDS"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html?utm_source=chatgpt.com "Working with DB instance read replicas"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html?utm_source=chatgpt.com "Configuring and managing a Multi-AZ deployment for ..."
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_MultiAZDBCluster_ReadRepl.html?utm_source=chatgpt.com "Working with Multi-AZ DB cluster read replicas for ..."
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.XRgn.html?utm_source=chatgpt.com "Creating a read replica in a different AWS Region"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.Promote.html?utm_source=chatgpt.com "Promoting a read replica to be a standalone DB instance"
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/create-multi-az-db-cluster.html?utm_source=chatgpt.com "Creating a Multi-AZ DB cluster for Amazon RDS"
[11]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html?utm_source=chatgpt.com "Multi-AZ DB cluster deployments for Amazon RDS"
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts-connection-management.html?utm_source=chatgpt.com "Connecting to a Multi-AZ DB cluster for Amazon RDS"
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html?utm_source=chatgpt.com "Amazon RDS DB instance storage"
[14]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.Autoscaling.html?utm_source=chatgpt.com "Managing capacity automatically with Amazon RDS storage ..."
[15]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.gp3.html?utm_source=chatgpt.com "Modifying settings for General Purpose SSD (gp3) storage"
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.AuroraHighAvailability.html?utm_source=chatgpt.com "High availability for Amazon Aurora"
