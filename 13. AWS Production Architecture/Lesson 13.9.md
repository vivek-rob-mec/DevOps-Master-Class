# AWS Masterclass — Lesson 8

## Databases From Zero to Production — RDS, Aurora, DynamoDB, ElastiCache, Redshift, DB Subnet Groups, Multi-AZ, Read Replicas, Backups, Encryption, Scaling, and Database Selection

Today we learn **AWS databases deeply**.

Your architect course outline explicitly includes **AWS DynamoDB, AWS RDS, AWS Aurora, AWS ElastiCache, DocumentDB, Aurora Serverless, Keyspaces, Redshift, Timestream, QLDB, and Neptune** in the database section . Your AWS Academy developing outline also has a full DynamoDB module covering key concepts, partitions, data distribution, secondary indexes, throughput, streams, global tables, backup/restore, RCUs/WCUs, and DynamoDB labs .

---

# 1. Why databases matter

An application is usually made of:

```text id="app-parts"
frontend:
  what user sees

backend:
  business logic

database:
  permanent data storage
```

Example Todo app:

```text id="todo-example"
Frontend:
  React page

Backend:
  Node.js API

Database:
  stores todos
```

Without database:

```text id="without-db"
User adds todo
server restarts
todo disappears
```

With database:

```text id="with-db"
User adds todo
data is saved
server can restart
todo still exists
```

Database is where your application remembers things.

---

# 2. First database mental model

There are many database types, but start with this:

```text id="db-types"
Relational database:
  structured tables and SQL

NoSQL database:
  flexible key-value/document style

Cache:
  very fast temporary data layer

Data warehouse:
  analytics and reporting database

Graph database:
  relationship-heavy data

Time-series database:
  metrics/events over time

Ledger database:
  immutable history/audit records
```

Simple examples:

| Need                            | Database type  | AWS service  |
| ------------------------------- | -------------- | ------------ |
| User accounts, orders, payments | Relational     | RDS / Aurora |
| High-scale key-value app data   | NoSQL          | DynamoDB     |
| Fast repeated reads             | Cache          | ElastiCache  |
| Analytics over huge data        | Data warehouse | Redshift     |
| Social graph/fraud links        | Graph          | Neptune      |
| IoT metrics over time           | Time-series    | Timestream   |
| Immutable transaction history   | Ledger         | QLDB         |

---

# 3. Relational database from zero

A relational database stores data in tables.

Example:

```text id="relational-example"
users table

+---------+---------+------------------+
| user_id | name    | email            |
+---------+---------+------------------+
| 1       | Vivek   | vivek@example.com|
| 2       | Rahul   | rahul@example.com|
+---------+---------+------------------+
```

Another table:

```text id="orders-table"
orders table

+----------+---------+--------+
| order_id | user_id | amount |
+----------+---------+--------+
| 101      | 1       | 500    |
| 102      | 1       | 700    |
+----------+---------+--------+
```

Relationship:

```text id="relationship"
orders.user_id connects to users.user_id
```

This is why it is called relational.

---

# 4. SQL

SQL means:

```text id="sql"
Structured Query Language
```

SQL is used to ask questions from relational databases.

Example:

```sql id="sql-example"
SELECT *
FROM users
WHERE user_id = 1;
```

Meaning:

```text id="sql-meaning"
Give me all columns
from users table
where user_id is 1.
```

Join example:

```sql id="join-example"
SELECT users.name, orders.amount
FROM users
JOIN orders ON users.user_id = orders.user_id;
```

Relational databases are good when:

```text id="relational-good"
data is structured
relationships matter
transactions matter
data consistency matters
SQL queries are important
reporting joins are needed
```

Examples:

```text id="relational-use"
banking
orders
payments
inventory
employee management
booking systems
ERP/CRM systems
```

---

# 5. Amazon RDS

RDS means:

```text id="rds-full"
Relational Database Service
```

Simple meaning:

```text id="rds-simple"
RDS is AWS-managed relational database service.
```

Without RDS, if you install MySQL on EC2, you manage:

```text id="self-managed"
OS patching
database installation
database backups
replication setup
failover scripts
storage growth
monitoring
database upgrades
security hardening
```

With RDS, AWS helps manage many database administration tasks such as provisioning, patching, backup, monitoring, and storage management. Amazon RDS supports familiar engines such as MySQL, PostgreSQL, MariaDB, Oracle, Microsoft SQL Server, and Db2; Aurora is covered separately under the Aurora guide. ([AWS Documentation][1])

Think:

```text id="rds-analogy"
EC2 database:
  you manage the whole restaurant kitchen

RDS:
  AWS manages kitchen infrastructure
  you manage recipes, users, schema, queries, and data
```

---

# 6. RDS database engines

RDS supports multiple engines.

```text id="rds-engines"
MySQL
PostgreSQL
MariaDB
Oracle
SQL Server
Db2
```

Decision:

| Requirement                        | Engine             |
| ---------------------------------- | ------------------ |
| Open-source, common web apps       | MySQL / PostgreSQL |
| Strong SQL features, extensions    | PostgreSQL         |
| Existing Oracle workloads          | Oracle on RDS      |
| Existing Microsoft stack           | SQL Server on RDS  |
| MySQL-compatible cloud-native      | Aurora MySQL       |
| PostgreSQL-compatible cloud-native | Aurora PostgreSQL  |

Beginner recommendation:

```text id="beginner-rds"
For learning:
  PostgreSQL or MySQL

For production:
  choose based on application compatibility, team skill, licensing, cost, HA, and performance.
```

---

# 7. What is a DB instance?

An RDS DB instance is the running database server.

It has:

```text id="db-instance-parts"
DB engine:
  PostgreSQL/MySQL/etc.

DB instance class:
  CPU/RAM capacity

Storage:
  allocated disk

VPC/subnet:
  network placement

Security group:
  database firewall

Parameter group:
  database settings

Option group:
  engine-specific features

Backup settings:
  retention and snapshots

Maintenance window:
  patch/upgrade time

Monitoring:
  CloudWatch metrics/logs
```

RDS creates a master user account when you create a DB instance, and RDS DB instances are managed resources inside AWS rather than EC2 instances that you directly administer at OS level. ([AWS Documentation][2])

---

# 8. DB instance class

DB instance class is like EC2 instance type for RDS.

Example:

```text id="db-class"
db.t4g.micro
db.t4g.small
db.m7g.large
db.r7g.large
```

Meaning:

```text id="db-class-meaning"
CPU
RAM
network capacity
database workload capacity
```

Selection rule:

```text id="db-size-rule"
Small dev:
  db.t4g.micro / db.t4g.small

Small production:
  start around db.t4g.medium or db.m family depending workload

Memory-heavy database:
  r family

High throughput:
  larger m/r family or Aurora
```

Do not choose randomly. Ask:

```text id="db-sizing-questions"
How many connections?
How many reads/writes per second?
How large is the data?
How complex are queries?
How much RAM is needed for cache?
What is expected growth?
What is availability requirement?
What is backup requirement?
```

---

# 9. RDS storage

RDS uses managed database storage.

Important storage concepts:

```text id="rds-storage"
allocated storage:
  initial database disk size

storage autoscaling:
  RDS can increase storage when needed

storage type:
  gp3/gp2/io1/io2 depending engine/support

IOPS:
  input/output operations per second

encryption:
  protect data at rest
```

Production rule:

```text id="rds-storage-rule"
Enable encryption.
Monitor free storage.
Enable storage autoscaling when appropriate.
Take backups.
```

---

# 10. DB subnet group

A DB subnet group tells RDS which subnets it can use.

Simple meaning:

```text id="db-subnet-simple"
DB subnet group = list of subnets where RDS is allowed to place database network interfaces.
```

Production pattern:

```text id="db-subnet-pattern"
DB subnet group:
  private database subnet in AZ-a
  private database subnet in AZ-b
```

When RDS creates a DB instance in a VPC, it assigns a network interface using an IP address from the DB subnet group; AWS documentation also points you to create VPC security groups for private DB instances. ([AWS Documentation][3])

Never place production database in public subnet.

```text id="db-placement"
Good:
  RDS in private database subnets

Bad:
  RDS publicly accessible in public subnet
```

---

# 11. RDS security group

Database security group should allow traffic only from application security group.

Example:

```text id="db-sg"
App SG:
  sg-app

DB SG:
  inbound PostgreSQL 5432 from sg-app only
```

Bad:

```text id="bad-db-sg"
5432 from 0.0.0.0/0
3306 from 0.0.0.0/0
```

Good:

```text id="good-db-sg"
5432 from App Security Group only
```

Production flow:

```text id="prod-flow"
User
  ↓
CloudFront
  ↓
ALB
  ↓
App SG
  ↓
DB SG
```

---

# 12. Publicly accessible database

RDS has a setting:

```text id="publicly-accessible"
Publicly accessible:
  Yes / No
```

For production:

```text id="prod-public"
Usually:
  No
```

Why?

```text id="why-no-public"
database should not be reachable directly from internet
database should only be reachable from application layer
security groups should be narrow
private routing should protect data tier
```

Exception:

```text id="exception"
temporary lab/testing access
controlled IP
short-lived
not production
```

But for industry-ready architecture:

```text id="industry-rule"
Keep databases private.
```

---

# 13. Multi-AZ

Multi-AZ means high availability across Availability Zones.

Simple meaning:

```text id="multi-az-simple"
RDS keeps a standby copy in another AZ for failover.
```

If primary database fails:

```text id="multi-az-failover"
RDS fails over to standby.
Application reconnects to same database endpoint.
```

For traditional RDS Multi-AZ DB instance deployments, Amazon RDS provisions and maintains a synchronous standby replica in a different Availability Zone; AWS notes that this standby is for high availability, and for read-only traffic you should use a Multi-AZ DB cluster or read replica instead. ([AWS Documentation][4])

Never confuse:

```text id="multi-az-vs-read"
Multi-AZ:
  high availability / failover

Read replica:
  read scaling
```

This is exam-critical.

---

# 14. Read replica

A read replica is an extra database copy used for read traffic.

Example:

```text id="read-replica"
Primary DB:
  writes and reads

Read replica:
  reads only
```

Use case:

```text id="replica-use"
App has many SELECT queries.
Move reporting/read-heavy queries to read replica.
Reduce load on primary database.
```

Amazon RDS uses the built-in replication features of the DB engine to create read replicas from a source DB instance. ([AWS Documentation][5])

Never confuse:

```text id="replica-confuse"
Read replica:
  performance/read scaling

Multi-AZ:
  high availability/failover
```

---

# 15. Backup, snapshot, point-in-time recovery

RDS backup options:

```text id="backup-options"
automated backups
manual snapshots
point-in-time recovery
cross-Region backups/copies
AWS Backup integration
```

## Automated backup

RDS automatically backs up database within retention period.

```text id="auto-backup"
Good for:
  restore to recent time
  accidental delete/corruption recovery
```

## Manual snapshot

You manually create backup at a point.

```text id="snapshot"
Good for:
  before major changes
  before upgrade
  long-term backup
  migration/testing copy
```

## PITR

PITR means:

```text id="pitr"
Point-In-Time Recovery
```

Example:

```text id="pitr-example"
Someone dropped a table at 10:30.
Restore database to 10:29.
```

Production rule:

```text id="backup-rule"
Backups are not enough.
You must test restore.
```

---

# 16. Amazon Aurora

Aurora is AWS’s cloud-native relational database engine.

Simple meaning:

```text id="aurora-simple"
Aurora is AWS-built relational database compatible with MySQL and PostgreSQL.
```

Amazon Aurora is part of Amazon RDS and is compatible with MySQL and PostgreSQL; it uses a distributed, fault-tolerant, self-healing storage system that automatically scales up to 128 TiB per DB cluster. ([AWS Documentation][6])

Aurora architecture is different from normal RDS:

```text id="aurora-arch"
Aurora cluster:
  shared distributed storage

Writer instance:
  handles writes

Reader instances:
  handle reads

Cluster endpoint:
  writer endpoint

Reader endpoint:
  load-balanced reads
```

Good use cases:

```text id="aurora-use"
high-performance relational workloads
MySQL/PostgreSQL compatibility
read scaling
high availability
cloud-native database architecture
production SaaS/apps
```

RDS vs Aurora:

| Feature       | RDS MySQL/PostgreSQL                 | Aurora                                    |
| ------------- | ------------------------------------ | ----------------------------------------- |
| Engine        | standard engine managed by RDS       | AWS cloud-native engine                   |
| Compatibility | MySQL/PostgreSQL/etc.                | MySQL/PostgreSQL compatible               |
| Storage       | instance-related managed storage     | distributed cluster storage               |
| Read scaling  | read replicas                        | Aurora replicas + reader endpoint         |
| Cost          | often simpler/cheaper for small apps | can be higher, more powerful              |
| Best for      | normal relational workloads          | demanding production relational workloads |

---

# 17. Aurora Serverless

Aurora Serverless is for variable or intermittent database workloads.

Simple meaning:

```text id="aurora-serverless"
Aurora Serverless can automatically adjust capacity based on demand.
```

Use for:

```text id="serverless-use"
development databases
unpredictable traffic
spiky applications
low-management workloads
apps that do not need fixed DB capacity all the time
```

Be careful:

```text id="serverless-careful"
Understand cold/warm behavior, scaling limits, connection behavior, and cost model before using in production.
```

---

# 18. DynamoDB

DynamoDB is AWS managed NoSQL database.

Simple meaning:

```text id="dynamodb-simple"
DynamoDB is a serverless NoSQL key-value and document database.
```

Amazon DynamoDB is a fully managed serverless NoSQL database service designed to run high-performance applications at any scale. ([AWS Documentation][7])

DynamoDB does not work like SQL tables with joins.

It works around:

```text id="dynamodb-concepts"
table
item
attribute
partition key
sort key
index
capacity mode
access pattern
```

---

# 19. DynamoDB table, item, attribute

Example table:

```text id="ddb-table"
Table:
  Orders
```

Item:

```json id="ddb-item"
{
  "OrderId": "order-1001",
  "CustomerId": "cust-123",
  "Amount": 500,
  "Status": "PAID"
}
```

Attributes:

```text id="attributes"
OrderId
CustomerId
Amount
Status
```

Think:

```text id="ddb-analogy"
DynamoDB table:
  huge distributed map

Item:
  one record

Attribute:
  field inside record
```

---

# 20. Partition key and sort key

## Partition key

Partition key decides where data is stored and how it is looked up.

Example:

```text id="partition-key"
OrderId
```

Query:

```text id="partition-query"
Get order where OrderId = order-1001
```

## Sort key

Sort key allows multiple related items under same partition key and sorted/ranged queries.

Example:

```text id="sort-key"
CustomerId = cust-123
OrderDate = 2026-07-24
```

Possible key design:

```text id="key-design"
Partition key:
  CustomerId

Sort key:
  OrderDate
```

This lets you query:

```text id="key-query"
Get all orders for customer cust-123
between two dates.
```

---

# 21. DynamoDB access pattern thinking

This is the most important DynamoDB lesson:

```text id="ddb-rule"
In DynamoDB, design table based on access patterns first.
```

Do not start with:

```text id="wrong-ddb"
What tables should I create?
```

Start with:

```text id="right-ddb"
How will the application query the data?
```

Example access patterns:

```text id="access-patterns"
Get order by OrderId
List orders by CustomerId
List unpaid orders by Status
Get latest orders by date
```

Then design keys and indexes.

If you need many flexible ad-hoc joins:

```text id="ddb-warning"
DynamoDB may not be the right first choice.
Use relational database or analytics system.
```

---

# 22. RCU and WCU

The AWS Academy outline specifically includes calculating RCUs and WCUs for DynamoDB .

RCU means:

```text id="rcu"
Read Capacity Unit
```

WCU means:

```text id="wcu"
Write Capacity Unit
```

Simple meaning:

```text id="capacity-simple"
RCU:
  read capacity

WCU:
  write capacity
```

DynamoDB capacity modes:

```text id="capacity-modes"
On-demand:
  pay per request, easier for unpredictable traffic

Provisioned:
  you configure read/write capacity, can use auto scaling
```

Beginner recommendation:

```text id="ddb-beginner"
Use on-demand for learning and unpredictable workloads.
Learn provisioned capacity for exams and cost optimization.
```

---

# 23. DynamoDB indexes

Indexes allow alternative query patterns.

## LSI — Local Secondary Index

```text id="lsi"
Same partition key as table
different sort key
created with table
```

## GSI — Global Secondary Index

```text id="gsi"
Different partition key and/or sort key
can be created later
used for alternate access patterns
```

Example:

Main table key:

```text id="main-key"
OrderId
```

GSI:

```text id="gsi-example"
CustomerId + OrderDate
```

Then you can query orders by customer.

Never confuse:

```text id="index-never"
DynamoDB index is not a SQL join.
It is another access path for queries.
```

---

# 24. DynamoDB Streams

DynamoDB Streams capture table item changes.

Example events:

```text id="stream-events"
new item inserted
item updated
item deleted
```

Use cases:

```text id="stream-use"
trigger Lambda
event-driven processing
audit pipeline
replicate data
update search index
send notification
```

Architecture:

```text id="stream-arch"
DynamoDB table
  ↓ stream
Lambda
  ↓
send email / update cache / publish event
```

---

# 25. DynamoDB Global Tables

Global Tables replicate DynamoDB data across regions.

Use cases:

```text id="global-table-use"
global low-latency app
multi-region active-active pattern
disaster recovery
users across continents
```

Be careful:

```text id="global-table-careful"
Understand conflict handling, replication delay, data model, and cost.
```

---

# 26. ElastiCache

ElastiCache is managed caching.

Simple meaning:

```text id="elasticache-simple"
ElastiCache is AWS-managed in-memory cache.
```

Amazon ElastiCache is a fully managed in-memory caching service that supports Redis OSS, Valkey, and Memcached. ([AWS Documentation][8])

Why cache?

```text id="cache-why"
Database query takes 200 ms.
Cache read takes a few ms.
Repeated requests become much faster.
```

Example:

```text id="cache-example"
User profile requested 1000 times.
Instead of querying RDS 1000 times,
store profile in Redis for 5 minutes.
```

Use cases:

```text id="cache-use"
session store
frequently read data
leaderboards
rate limiting
temporary tokens
API response cache
database query cache
```

Never use cache as your only permanent database unless the design explicitly supports it.

```text id="cache-rule"
Cache improves speed.
Database remains source of truth.
```

---

# 27. Redis/Valkey vs Memcached

| Feature             | Redis/Valkey style                       | Memcached        |
| ------------------- | ---------------------------------------- | ---------------- |
| Data structures     | rich                                     | simple key-value |
| Persistence options | yes                                      | no/limited       |
| Pub/sub             | yes                                      | no               |
| Sorted sets         | yes                                      | no               |
| Common use          | sessions, queues, counters, leaderboards | simple caching   |
| Complexity          | more features                            | simpler          |

Beginner rule:

```text id="cache-beginner"
For most modern app caching:
  choose Redis/Valkey-compatible ElastiCache

For very simple temporary cache:
  Memcached can be enough
```

---

# 28. Redshift

Redshift is for analytics, not normal app transactions.

Simple meaning:

```text id="redshift-simple"
Redshift is AWS managed data warehouse.
```

Amazon Redshift is a fully managed, petabyte-scale data warehouse service in the cloud. ([AWS Documentation][9])

Use Redshift for:

```text id="redshift-use"
business intelligence
analytics dashboards
large SQL queries
reporting over huge datasets
data warehouse workloads
```

Do not use Redshift for:

```text id="redshift-not"
user login table
shopping cart transactions
low-latency OLTP app writes
simple small application database
```

OLTP vs OLAP:

```text id="oltp-olap"
OLTP:
  online transactions
  small fast reads/writes
  RDS/Aurora/DynamoDB

OLAP:
  analytics
  large scans/aggregations
  Redshift/Athena
```

---

# 29. Other AWS databases you must recognize

## DocumentDB

```text id="documentdb"
MongoDB-compatible document database service.
```

Use for:

```text id="documentdb-use"
document-style JSON workloads
MongoDB-compatible application migration
```

## Neptune

```text id="neptune"
Graph database.
```

Use for:

```text id="neptune-use"
relationships
fraud detection
recommendation graph
social network graph
knowledge graph
```

## Timestream

```text id="timestream"
Time-series database.
```

Use for:

```text id="timestream-use"
IoT metrics
application metrics
time-based events
monitoring data
```

## Keyspaces

```text id="keyspaces"
Managed Cassandra-compatible database.
```

Use for:

```text id="keyspaces-use"
Cassandra workloads
wide-column data models
```

## QLDB

```text id="qldb"
Ledger database with immutable transaction history.
```

Use for:

```text id="qldb-use"
audit trails
verifiable history
ledger-like systems
```

---

# 30. Database Migration Service — DMS

DMS means:

```text id="dms"
Database Migration Service
```

Simple meaning:

```text id="dms-simple"
DMS helps migrate data from one database to another.
```

AWS DMS can migrate relational databases, data warehouses, NoSQL databases, and other data stores; it supports sources and targets across AWS, on-premises, and common database engines. ([AWS Documentation][10])

Use cases:

```text id="dms-use"
on-prem Oracle to RDS PostgreSQL
EC2 MySQL to RDS MySQL
RDS MySQL to Aurora MySQL
database modernization
minimal-downtime migration
```

DMS concepts:

```text id="dms-concepts"
source endpoint:
  old database

target endpoint:
  new database

replication instance:
  migration worker

migration task:
  what tables/data to move

CDC:
  change data capture for ongoing changes
```

DMS is important for hybrid and migration lessons later.

---

# 31. Database selection table

Use this table in interviews.

| Requirement                                                 | Choose      |
| ----------------------------------------------------------- | ----------- |
| SQL, transactions, joins                                    | RDS         |
| MySQL/PostgreSQL compatible but cloud-native HA/performance | Aurora      |
| Serverless key-value/document at massive scale              | DynamoDB    |
| High-speed temporary data/cache                             | ElastiCache |
| Analytics warehouse                                         | Redshift    |
| MongoDB-compatible document workload                        | DocumentDB  |
| Graph relationships                                         | Neptune     |
| Time-series metrics/events                                  | Timestream  |
| Cassandra-compatible workload                               | Keyspaces   |
| Immutable ledger history                                    | QLDB        |
| Database migration                                          | DMS         |

---

# 32. Multi-AZ vs Read Replica vs Backup

This is exam-critical.

| Concept                   | Main purpose              | Helps with                         |
| ------------------------- | ------------------------- | ---------------------------------- |
| Multi-AZ                  | high availability         | failover                           |
| Read replica              | read scaling              | performance                        |
| Backup                    | recovery                  | restore after data loss/corruption |
| Snapshot                  | point-in-time backup copy | manual restore/migration           |
| Cross-Region replica/copy | disaster recovery/global  | regional failure planning          |

Never say:

```text id="wrong"
Read replica is same as Multi-AZ.
```

Correct:

```text id="correct"
Multi-AZ protects availability.
Read replica improves read scaling.
Backup protects recovery.
```

---

# 33. Database high availability architecture

Production RDS pattern:

```text id="rds-prod"
VPC
  ├── private app subnet AZ-a
  ├── private app subnet AZ-b
  ├── private DB subnet AZ-a
  └── private DB subnet AZ-b

ALB:
  public subnets

App:
  private app subnets

RDS:
  private DB subnet group across AZ-a and AZ-b

Security:
  DB SG allows app SG only
```

Architecture:

```text id="db-arch"
User
  ↓
CloudFront
  ↓
ALB
  ↓
App instances / containers
  ↓
RDS/Aurora in private DB subnets
```

---

# 34. Database connection pooling

Common mistake:

```text id="connection-mistake"
Every request opens a new database connection.
```

Problem:

```text id="connection-problem"
Database connection limit reached.
App slows down or fails.
```

Fix:

```text id="connection-fix"
Use connection pooling.
Tune max connections.
Use RDS Proxy for supported workloads.
```

RDS Proxy helps applications pool and share established database connections, improving scalability and resilience for compatible RDS/Aurora engines.

Production rule:

```text id="connection-rule"
Database connection count is a scaling limit.
Monitor it.
```

---

# 35. Database monitoring

Minimum metrics to watch:

```text id="db-monitoring"
CPUUtilization
DatabaseConnections
FreeStorageSpace
ReadIOPS
WriteIOPS
ReadLatency
WriteLatency
ReplicaLag
Deadlocks
FreeableMemory
DiskQueueDepth
```

For DynamoDB:

```text id="ddb-monitoring"
ConsumedReadCapacityUnits
ConsumedWriteCapacityUnits
ThrottledRequests
SuccessfulRequestLatency
SystemErrors
UserErrors
```

For ElastiCache:

```text id="cache-monitoring"
CPUUtilization
DatabaseMemoryUsagePercentage
Evictions
CacheHitRate
CurrConnections
ReplicationLag
```

---

# 36. Database security checklist

For production:

```text id="security-checklist"
RDS/Aurora:
  private subnets
  publicly accessible = false
  DB SG allows app SG only
  encryption enabled
  backups enabled
  deletion protection for prod
  strong credentials
  Secrets Manager for password
  IAM auth where useful
  CloudWatch logs exported
  patching/maintenance window defined

DynamoDB:
  IAM least privilege
  encryption enabled
  point-in-time recovery for critical tables
  backup strategy
  access patterns reviewed
  no hot partitions
  CloudWatch alarms

ElastiCache:
  private subnets
  SG allows app SG only
  encryption in transit where needed
  auth/token where supported
  not source of truth
  eviction monitored
```

---

# 37. Cost rules for databases

Database cost mistakes are painful.

```text id="db-cost-mistakes"
oversized RDS instances
idle dev RDS running 24/7
Multi-AZ enabled unnecessarily in dev
forgotten read replicas
too many Aurora replicas
DynamoDB provisioned capacity too high
DynamoDB bad partition key causing hot partitions
ElastiCache left running
Redshift cluster left idle
snapshots retained forever
cross-region data transfer surprises
```

Cost optimization:

```text id="db-cost-optimization"
use small instances for dev
stop eligible dev RDS when not needed
use on-demand DynamoDB for unpredictable workloads
use lifecycle/retention for snapshots
right-size using CloudWatch
use reserved instances/savings where stable
use Aurora Serverless for variable workloads where appropriate
destroy lab databases quickly
```

---

# 38. Hands-On Lab 8A — DynamoDB Orders Table

This lab is low-cost for tiny usage. Still clean up.

We will create:

```text id="lab-create"
DynamoDB table
on-demand billing
partition key OrderId
sample item
query/get item
update item
delete table
```

Region:

```text id="lab-region"
ap-south-1
```

---

## Step 1 — Set region

```bash id="set-region"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity
```

---

## Step 2 — Create table name

```bash id="table-name"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TS="$(date +%Y%m%d%H%M%S)"

TABLE_NAME="aws-masterclass-orders-${TS}"

echo "$TABLE_NAME"
```

---

## Step 3 — Create DynamoDB table

```bash id="create-table"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=OrderId,AttributeType=S \
  --key-schema AttributeName=OrderId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Wait:

```bash id="wait-table"
aws dynamodb wait table-exists \
  --table-name "$TABLE_NAME"
```

Describe:

```bash id="describe-table"
aws dynamodb describe-table \
  --table-name "$TABLE_NAME" \
  --query 'Table.{TableName:TableName,Status:TableStatus,BillingMode:BillingModeSummary.BillingMode,ItemCount:ItemCount}'
```

---

## Step 4 — Insert item

```bash id="put-item"
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "OrderId": {"S": "order-1001"},
    "CustomerId": {"S": "cust-101"},
    "Amount": {"N": "1500"},
    "Status": {"S": "CREATED"}
  }'
```

---

## Step 5 — Get item by primary key

```bash id="get-item"
aws dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "OrderId": {"S": "order-1001"}
  }'
```

This is DynamoDB’s strength:

```text id="ddb-strength"
Fast key-based lookup.
```

---

## Step 6 — Update item

```bash id="update-item"
aws dynamodb update-item \
  --table-name "$TABLE_NAME" \
  --key '{
    "OrderId": {"S": "order-1001"}
  }' \
  --update-expression "SET #s = :status" \
  --expression-attribute-names '{"#s":"Status"}' \
  --expression-attribute-values '{":status":{"S":"PAID"}}' \
  --return-values ALL_NEW
```

---

## Step 7 — Add another item

```bash id="put-second"
aws dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{
    "OrderId": {"S": "order-1002"},
    "CustomerId": {"S": "cust-101"},
    "Amount": {"N": "2500"},
    "Status": {"S": "CREATED"}
  }'
```

Scan table:

```bash id="scan"
aws dynamodb scan \
  --table-name "$TABLE_NAME"
```

Important:

```text id="scan-warning"
Scan reads through table items.
For large production tables, avoid scan for normal app access.
Design keys/indexes for queries.
```

---

## Step 8 — Cleanup

Delete table:

```bash id="delete-table"
aws dynamodb delete-table \
  --table-name "$TABLE_NAME"

aws dynamodb wait table-not-exists \
  --table-name "$TABLE_NAME"
```

Verify:

```bash id="verify-delete"
aws dynamodb list-tables \
  --query "TableNames[?@=='$TABLE_NAME']"
```

---

# 39. Hands-On Lab 8B — RDS Network Design Without Creating Database

This lab creates no RDS database instance. We only design the safe network pieces.

It creates:

```text id="rds-network-create"
DB security group
DB subnet group if you provide two private subnet IDs
```

No DB instance means no database hourly cost.

## Required inputs

You need:

```text id="inputs"
VPC_ID
APP_SG_ID
PRIVATE_DB_SUBNET_1
PRIVATE_DB_SUBNET_2
```

If you do not have them now, just read this lab. We will run it later inside the full production VPC project.

---

## Create DB security group

```bash id="create-db-sg"
DB_SG_ID="$(aws ec2 create-security-group \
  --group-name aws-masterclass-rds-db-sg \
  --description "RDS database SG allowing app SG only" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)"

aws ec2 create-tags \
  --resources "$DB_SG_ID" \
  --tags Key=Name,Value=aws-masterclass-rds-db-sg Key=Project,Value=aws-masterclass
```

Allow PostgreSQL only from app SG:

```bash id="allow-postgres"
aws ec2 authorize-security-group-ingress \
  --group-id "$DB_SG_ID" \
  --ip-permissions "[
    {
      \"IpProtocol\": \"tcp\",
      \"FromPort\": 5432,
      \"ToPort\": 5432,
      \"UserIdGroupPairs\": [
        {
          \"GroupId\": \"$APP_SG_ID\",
          \"Description\": \"PostgreSQL from application SG only\"
        }
      ]
    }
  ]"
```

Create DB subnet group:

```bash id="create-db-subnet-group"
aws rds create-db-subnet-group \
  --db-subnet-group-name aws-masterclass-db-subnet-group \
  --db-subnet-group-description "Private DB subnets for AWS Masterclass" \
  --subnet-ids "$PRIVATE_DB_SUBNET_1" "$PRIVATE_DB_SUBNET_2" \
  --tags Key=Project,Value=aws-masterclass Key=Environment,Value=dev
```

Validate:

```bash id="validate-db-subnet"
aws rds describe-db-subnet-groups \
  --db-subnet-group-name aws-masterclass-db-subnet-group
```

Cleanup:

```bash id="cleanup-rds-network"
aws rds delete-db-subnet-group \
  --db-subnet-group-name aws-masterclass-db-subnet-group

aws ec2 delete-security-group \
  --group-id "$DB_SG_ID"
```

---

# 40. Common database errors and fixes

## Error 1 — App cannot connect to RDS

Check:

```text id="app-cannot-connect"
RDS publicly accessible?
DB in correct VPC?
DB subnet group correct?
DB SG allows app SG?
App uses correct endpoint?
App uses correct port?
Username/password correct?
NACL allows traffic?
DNS resolving?
```

Debug:

```bash id="rds-debug"
aws rds describe-db-instances \
  --db-instance-identifier YOUR_DB_ID \
  --query 'DBInstances[0].{Endpoint:Endpoint.Address,Port:Endpoint.Port,PubliclyAccessible:PubliclyAccessible,Status:DBInstanceStatus,VpcSecurityGroups:VpcSecurityGroups}'
```

---

## Error 2 — Too many database connections

Cause:

```text id="too-many-connections"
app opens too many DB connections
no pooling
too many containers/instances
DB instance too small
```

Fix:

```text id="connection-fix"
use connection pooling
tune pool size
use RDS Proxy where appropriate
scale DB class
optimize app behavior
```

---

## Error 3 — DynamoDB throttling

Cause:

```text id="ddb-throttle"
traffic exceeds provisioned/on-demand adaptive capacity behavior
hot partition key
bad table design
```

Fix:

```text id="ddb-throttle-fix"
choose better partition key
distribute writes
use on-demand mode
increase provisioned capacity
add alarms
review access patterns
```

---

## Error 4 — Slow database queries

Cause:

```text id="slow-queries"
missing indexes
bad query design
large table scans
insufficient memory
disk I/O bottleneck
locking
network latency
```

Fix:

```text id="slow-query-fix"
add indexes
optimize SQL
use query plan analysis
scale instance
use read replica for reads
cache repeated reads
partition/archive old data
```

---

## Error 5 — ElastiCache evictions

Cause:

```text id="evictions"
cache memory is full
keys are evicted
cache node too small
TTL policy too aggressive or missing
```

Fix:

```text id="eviction-fix"
increase node size
scale out cluster
set proper TTL
monitor memory and evictions
cache only useful data
```

---

# 41. Production database design checklist

Before choosing a database, answer:

```text id="db-checklist"
1. Is data relational or key-value/document?
2. Do I need SQL joins?
3. Do I need strong transactions?
4. What are the access patterns?
5. How many reads/writes per second?
6. What is latency requirement?
7. What is data size now and after one year?
8. Do I need Multi-AZ?
9. Do I need read scaling?
10. Do I need global/multi-region?
11. What is backup retention?
12. What is RPO?
13. What is RTO?
14. Is encryption required?
15. How will app store DB credentials?
16. How will connections be pooled?
17. How will schema changes be deployed?
18. How will monitoring/alerting work?
19. What is cost limit?
20. What is cleanup plan for dev?
```

RPO/RTO:

```text id="rpo-rto"
RPO:
  how much data loss is acceptable?

RTO:
  how much downtime is acceptable?
```

Example:

```text id="rpo-example"
RPO 5 minutes:
  can lose max 5 minutes of data

RTO 30 minutes:
  must recover service within 30 minutes
```

---

# 42. Certification angle

## CLF-C02

Know:

```text id="clf"
RDS is managed relational database.
Aurora is AWS cloud-native relational database.
DynamoDB is serverless NoSQL database.
ElastiCache is in-memory cache.
Redshift is data warehouse.
DMS is database migration service.
```

## SAA-C03

Know deeply:

```text id="saa"
RDS Multi-AZ vs read replica
Aurora writer/reader endpoints
DB subnet groups
private database subnets
security group chaining
backup and PITR
DynamoDB partition key and sort key
DynamoDB GSI/LSI
DynamoDB on-demand vs provisioned
ElastiCache caching strategies
Redshift for analytics
DMS migration patterns
database selection by workload
```

## DOP-C02

Know operationally:

```text id="dop"
database monitoring
CloudWatch alarms
backup/restore automation
schema migration pipelines
RDS blue/green or replica migration patterns
DynamoDB stream processing
cache invalidation
connection exhaustion troubleshooting
DMS migration troubleshooting
Secrets Manager rotation
incident response for data tier
```

---

# 43. Interview answer

Memorize this:

```text id="interview-answer"
AWS provides different databases for different workload types. For relational workloads that need SQL, transactions, joins, and structured schemas, I use Amazon RDS or Aurora. RDS is managed relational database service for engines like MySQL and PostgreSQL, while Aurora is AWS’s cloud-native MySQL/PostgreSQL-compatible database with distributed storage and strong production features.

For NoSQL key-value or document workloads at very large scale, I use DynamoDB. With DynamoDB, table design starts from access patterns, and key design is critical because partition keys, sort keys, and indexes decide how the application queries data. For repeated fast reads or sessions, I use ElastiCache with Redis/Valkey-compatible caching, but I do not treat cache as the source of truth. For analytics and reporting over huge datasets, I use Redshift as a data warehouse.

In production, databases should normally run in private database subnets, not public subnets. The database security group should allow traffic only from the application security group. I enable encryption, backups, monitoring, and Multi-AZ where availability matters. I use read replicas for read scaling, not as a replacement for Multi-AZ. I also define RPO and RTO, test restores, and use Secrets Manager or IAM-based patterns instead of hardcoding credentials.
```

---

# 44. Quick quiz

```text id="quiz"
1. What is a relational database?
2. What is SQL?
3. What is RDS?
4. What is Aurora?
5. What is DynamoDB?
6. What is ElastiCache?
7. What is Redshift?
8. What is a DB subnet group?
9. Where should production RDS live?
10. What should DB security group allow?
11. What is Multi-AZ for?
12. What is read replica for?
13. What is backup for?
14. What is PITR?
15. What is DynamoDB partition key?
16. What is DynamoDB sort key?
17. What is GSI?
18. What is RCU/WCU?
19. What is DMS?
20. What is the difference between OLTP and OLAP?
```

Answers:

```text id="answers"
1. Database with structured tables and relationships.
2. Language for querying relational databases.
3. AWS managed relational database service.
4. AWS cloud-native MySQL/PostgreSQL-compatible relational database.
5. Serverless NoSQL key-value/document database.
6. Managed in-memory cache.
7. Managed data warehouse for analytics.
8. List of subnets where RDS can place DB network interfaces.
9. Private database subnets.
10. App security group only.
11. High availability and failover.
12. Read scaling.
13. Recovery from data loss/corruption.
14. Restore to a specific point in time.
15. Key used to distribute and look up data.
16. Optional key for ordering/range queries under same partition.
17. Global Secondary Index for alternate query pattern.
18. DynamoDB read/write capacity units.
19. Database Migration Service.
20. OLTP is transaction workload; OLAP is analytics workload.
```

---

# Next Lesson

```text id="next"
AWS Lesson 9 — Route 53, DNS, Domain Setup, ACM Certificates, and CloudFront Foundation:
A, CNAME, Alias, NS, TXT, TTL, hosted zones, domain verification, certificate validation, propagation timing, and how users reach your AWS application
```

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html?utm_source=chatgpt.com "What is Amazon Relational Database Service (Amazon RDS)? - Amazon Relational Database Service"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.html?utm_source=chatgpt.com "Amazon RDS DB instances - Amazon Relational Database Service"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html?utm_source=chatgpt.com "Working with a DB instance in a VPC - Amazon Relational Database Service"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html?utm_source=chatgpt.com "Multi-AZ DB instance deployments for Amazon RDS - Amazon Relational Database Service"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html?utm_source=chatgpt.com "Working with DB instance read replicas - Amazon Relational Database Service"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_AuroraOverview.html?utm_source=chatgpt.com "What is Amazon Aurora? - Amazon Aurora"
[7]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/getting-started-NextSteps.html?utm_source=chatgpt.com "Continue learning about DynamoDB - Amazon DynamoDB"
[8]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/WhatIs.html?utm_source=chatgpt.com "What is Amazon ElastiCache? - Amazon ElastiCache"
[9]: https://docs.aws.amazon.com/redshift/latest/mgmt/welcome.html?utm_source=chatgpt.com "What is Amazon Redshift? - Amazon Redshift"
[10]: https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html?utm_source=chatgpt.com "What is AWS Database Migration Service? - AWS Database Migration Service"
