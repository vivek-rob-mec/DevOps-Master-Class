# AWS Masterclass — Phase 3

# Lesson 47: Amazon RDS and Amazon Aurora Production Architecture

## 1. Lesson objectives

By the end of this lesson, you will understand how to:

* Choose between Amazon RDS and Amazon Aurora.
* Select an appropriate relational database engine.
* Distinguish Single-AZ, Multi-AZ and read-replica deployments.
* Separate high availability, read scaling and disaster recovery.
* Understand Aurora’s shared distributed storage architecture.
* Use writer, reader, instance and global endpoints correctly.
* Manage application database connections safely.
* Protect databases from Lambda and container connection storms.
* Implement RDS Proxy.
* Configure automated backups, snapshots and point-in-time recovery.
* Design cross-Region recovery.
* Use Aurora Global Database.
* Encrypt databases, backups and snapshots.
* Manage credentials using Secrets Manager and IAM authentication.
* Plan database maintenance and engine upgrades.
* Use RDS and Aurora Blue/Green Deployments.
* Monitor database performance using CloudWatch Database Insights.
* Troubleshoot CPU, connections, storage, replication lag and failover.
* Provision production databases using Terraform.

---

# 2. Amazon RDS mental model

Amazon Relational Database Service manages relational database infrastructure.

```text
Application
    |
    v
Amazon RDS endpoint
    |
    v
Managed database engine
    |
    ├── Compute
    ├── Storage
    ├── Backups
    ├── Monitoring
    ├── Patching
    ├── Replication
    └── Failover
```

AWS manages much of the database infrastructure, while you still manage schemas, SQL, indexes, application connections, user permissions and query performance.

---

# 3. Managed does not mean administration-free

## AWS manages

```text
Physical database servers
Operating-system installation
Infrastructure replacement
Storage attachment
Automated backups
Monitoring integration
Multi-AZ replication
Failover orchestration
Engine patch delivery
```

## You manage

```text
Database schema
Tables and relationships
Indexes
Queries
Transactions
Database users
Application connection pools
Database parameters
Backup retention
Maintenance timing
Performance tuning
Cost
Business recovery procedures
```

RDS reduces infrastructure administration. It does not design your database or optimize your SQL automatically.

---

# 4. Supported relational engines

Amazon RDS supports managed deployments for:

```text
PostgreSQL
MySQL
MariaDB
Microsoft SQL Server
Oracle Database
IBM Db2
```

Amazon Aurora provides AWS-designed MySQL-compatible and PostgreSQL-compatible relational database engines. Engine and feature availability varies by AWS Region, engine version and instance class. ([AWS Documentation][1])

---

# 5. Choosing a database engine

## PostgreSQL

Strong choice for:

* Standards-compliant SQL.
* Complex data types.
* JSONB.
* Geospatial extensions.
* Advanced indexing.
* Extensibility.
* General-purpose transactional applications.

## MySQL

Strong choice for:

* Common web applications.
* Large ecosystem support.
* Widely available application frameworks.
* Teams with existing MySQL knowledge.

## MariaDB

Strong choice when:

* You require MariaDB compatibility.
* Existing applications use MariaDB-specific features.
* You want an open-source MySQL-family engine.

## SQL Server

Strong choice for:

* Microsoft application stacks.
* Existing SQL Server workloads.
* SQL Server-specific tools and features.
* Applications requiring SQL Server compatibility.

## Oracle

Strong choice for:

* Existing enterprise Oracle applications.
* Vendor software requiring Oracle.
* Oracle-specific database features.

## Db2

Strong choice for:

* Existing IBM enterprise workloads.
* Applications specifically requiring Db2 compatibility.

Do not choose an engine only because it is familiar. Consider licensing, migration effort, operational skills, application compatibility and long-term cost.

---

# 6. RDS versus a database on EC2

## Database on Amazon EC2

You manage:

```text
Operating system
Database installation
Patching
Backups
Replication
Failover
Storage
Monitoring agents
Database process recovery
```

## Amazon RDS

AWS manages much of that infrastructure.

Use EC2-hosted databases when you require:

* Operating-system access.
* Unsupported extensions.
* Custom database binaries.
* Specialised agents.
* Host-level configuration.
* Features unavailable in RDS.
* Complete control over replication or storage.

Use RDS when supported managed features meet the application requirements.

---

# 7. Core RDS components

```text
DB instance or DB cluster
DB subnet group
Security group
Parameter group
Option group where applicable
KMS key
Backup configuration
Monitoring configuration
Endpoint
```

## DB instance

Database compute running one supported relational engine.

## DB cluster

A coordinated group of writer and reader instances sharing or replicating database data, depending on the deployment type.

## DB subnet group

The VPC subnets where RDS may place database resources.

## Endpoint

DNS name applications use to connect.

---

# 8. Production subnet architecture

A production database should normally run in private subnets.

```text
Internet
   |
   v
ALB / API Gateway
   |
   v
ECS / Lambda / EC2 application
   |
   v
Private RDS database
```

Recommended layout:

```text
Availability Zone A
└── Private database subnet A

Availability Zone B
└── Private database subnet B

Availability Zone C
└── Private database subnet C
```

A DB subnet group should span enough Availability Zones for the selected high-availability architecture.

---

# 9. Publicly accessible databases

Production setting:

```text
Publicly accessible:
false
```

Security flow:

```text
Application security group
        |
        | Database port
        v
Database security group
```

Example for PostgreSQL:

```text
Database inbound:
TCP 5432
Source: application security group
```

Avoid:

```text
TCP 5432
Source: 0.0.0.0/0
```

A private database still requires authentication and encryption. Private networking alone is not sufficient security.

---

# 10. Single-AZ RDS

Single-AZ deployment:

```text
Availability Zone A
└── Primary DB instance
```

Advantages:

* Lower cost.
* Simpler architecture.
* Suitable for development or disposable workloads.

Risks:

* Infrastructure failure can cause longer interruption.
* Maintenance can create downtime.
* No synchronously maintained standby.
* Recovery may require instance repair or restoration.

Use Single-AZ carefully for production systems with low availability requirements.

---

# 11. Multi-AZ DB instance deployment

A traditional Multi-AZ DB instance deployment contains:

```text
Availability Zone A
└── Primary DB instance

Availability Zone B
└── Synchronous standby DB instance
```

RDS synchronously replicates the primary to a standby in another Availability Zone. If the primary becomes unavailable, RDS can automatically fail over to the standby. ([AWS Documentation][2])

---

# 12. The Multi-AZ standby is not a read replica

For a traditional Multi-AZ DB instance:

```text
Primary:
Read and write traffic

Standby:
Failover only
```

The standby does not normally serve application read queries. Use a read replica or a Multi-AZ DB cluster when additional read capacity is required. ([AWS Documentation][2])

## Never-forget distinction

```text
Multi-AZ standby:
High availability

Read replica:
Read scaling
```

---

# 13. Multi-AZ failover

Potential failover causes include:

* Primary infrastructure failure.
* Availability Zone problem.
* Database instance failure.
* Storage issue.
* Certain maintenance operations.
* Manual reboot with failover.

During failover:

```text
Primary becomes unavailable
        |
        v
RDS detects failure
        |
        v
Standby promoted
        |
        v
Database endpoint resolves to new primary
        |
        v
Application reconnects
```

The duration depends on engine activity, transaction state, DNS behaviour and the conditions that caused the failover. ([AWS Documentation][3])

---

# 14. Endpoint and DNS failover behaviour

Applications connect to an RDS DNS endpoint:

```text
production-db.abc123.ap-south-1.rds.amazonaws.com
```

The application should not store the database instance’s resolved IP address permanently.

Bad:

```text
Resolve endpoint once
Cache IP forever
```

Correct:

```text
Use database hostname
Respect DNS changes
Reconnect after connection failure
```

Long DNS caching can delay application recovery after failover.

---

# 15. Application failover handling

A highly available database does not automatically create a highly available application.

The application must handle:

```text
Connection reset
Broken transaction
Database restart
DNS target change
Temporary connection refusal
Connection-pool invalidation
```

Recommended behaviour:

```text
Database connection fails
        |
        v
Discard broken connection
        |
        v
Resolve endpoint again
        |
        v
Reconnect with bounded retry
        |
        v
Retry transaction only when safe
```

Do not automatically retry non-idempotent transactions without understanding whether the database committed them before the connection failed.

---

# 16. Multi-AZ DB cluster

An RDS Multi-AZ DB cluster is different from a traditional Multi-AZ DB instance.

Architecture:

```text
Availability Zone A
└── Writer instance

Availability Zone B
└── Readable reader instance

Availability Zone C
└── Readable reader instance
```

The two reader instances can serve read traffic and act as automatic failover targets. Data replication uses the database engine’s native replication capabilities. Multi-AZ DB cluster support depends on engine, Region and instance class. ([AWS Documentation][4])

---

# 17. Multi-AZ instance versus Multi-AZ cluster

| Characteristic       | Multi-AZ DB instance    | Multi-AZ DB cluster   |
| -------------------- | ----------------------- | --------------------- |
| Primary/writer       | One                     | One                   |
| Standby/readers      | One standby             | Two readable replicas |
| Standby serves reads | No                      | Yes                   |
| Number of AZs        | Usually two             | Three                 |
| Read scaling         | Separate replica needed | Built-in readers      |
| Automatic failover   | Yes                     | Yes                   |
| Engine support       | Broader                 | More limited          |

Use a Multi-AZ cluster when its supported engine and instance choices fit and you need both availability and read capacity.

---

# 18. Read replicas

Read replicas use asynchronous replication.

```text
Primary database
      |
      | Asynchronous replication
      v
Read replica
```

Use read replicas for:

* Read-heavy queries.
* Reporting.
* Analytics queries.
* Isolating dashboard traffic.
* Regional read locality.
* Disaster-recovery preparation.
* Offloading some backup or operational tasks where supported.

Because replication is asynchronous, read replicas may lag behind the primary. ([AWS Documentation][5])

---

# 19. Read/write splitting

Architecture:

```text
Application
├── Writes → Primary endpoint
└── Reads  → Read replica endpoint
```

Example:

```text
POST /orders
    → Writer

GET /reports
    → Read replica
```

The application or database-aware driver usually decides whether a query uses the writer or reader.

Do not route correctness-critical reads to a lagging replica immediately after a write.

---

# 20. Read-after-write consistency problem

Timeline:

```text
1. Application writes order to primary.
2. Primary commits.
3. Application immediately queries replica.
4. Replication has not applied write yet.
5. Application reports "order not found."
```

Solutions include:

* Read the writer after writes.
* Use session-level writer affinity.
* Wait for replication position where supported.
* Design the user experience for eventual consistency.
* Use Aurora reader-selection features carefully.
* Route critical reads to the primary.

---

# 21. Read-replica promotion

A read replica can be promoted into an independent database.

```text
Primary
   |
   v
Read replica
   |
   | Promote
   v
Independent writable database
```

Promotion stops replication. The promoted database becomes an independent DB instance, and applications must be redirected to its endpoint. AWS recommends understanding asynchronous-replication lag before using promotion as a recovery mechanism. ([AWS Documentation][6])

---

# 22. Read replica is not automatic Multi-AZ failover

A normal read replica:

```text
Does not automatically become primary
during standard source failure
```

Promotion is an explicit operational action unless a larger orchestration mechanism performs it.

Multi-AZ:

```text
Automatic failover
```

Read replica:

```text
Read scaling
or manually orchestrated DR
```

---

# 23. Multi-AZ read replicas

For supported engines, a read replica can itself use Multi-AZ deployment.

```text
Primary database
      |
      v
Read replica primary
      |
      v
Read replica standby
```

This provides high availability for the read replica independently of whether the source is Multi-AZ. ([AWS Documentation][7])

This can be useful for a critical reporting or disaster-recovery database.

---

# 24. Cross-Region read replicas

Cross-Region replicas provide:

* Regional read locality.
* Disaster-recovery preparation.
* Geographic data copies.
* Migration support.

Cross-Region replication is asynchronous and incurs data-transfer and replica infrastructure cost. Support varies by database engine and Region. ([AWS Documentation][8])

Architecture:

```text
ap-south-1 primary
        |
        | Cross-Region replication
        v
ap-southeast-1 read replica
```

---

# 25. Four different database problems

Do not confuse these requirements:

```text
High availability:
Multi-AZ

Read scaling:
Read replicas

Connection scaling:
RDS Proxy

Disaster recovery:
Cross-Region replica, backup or global database
```

One feature does not necessarily solve the others.

---

# 26. Amazon Aurora

Amazon Aurora is an AWS-designed relational database compatible with MySQL or PostgreSQL.

Aurora separates:

```text
Database compute
from
Distributed cluster storage
```

Architecture:

```text
Writer instance
Reader instances
       |
       v
Shared distributed Aurora storage
```

Aurora storage is replicated across three Availability Zones and is independent of individual database compute instances. ([AWS Documentation][9])

---

# 27. Aurora storage architecture

Aurora’s cluster volume stores multiple copies of data across three Availability Zones.

```text
Availability Zone A
├── Storage copy
└── Storage copy

Availability Zone B
├── Storage copy
└── Storage copy

Availability Zone C
├── Storage copy
└── Storage copy
```

Aurora documentation describes six-way replication across three Availability Zones. The storage system can tolerate losing copies while continuing database operations, and storage repairs occur automatically. ([AWS Documentation][10])

---

# 28. Aurora compute and storage separation

```text
Aurora writer fails
        |
        v
Reader promoted
        |
        v
Same shared cluster storage
```

The promoted reader does not need to copy the complete database storage before becoming writer because the cluster’s storage is already shared.

This architecture generally enables faster recovery than rebuilding a traditional database standby from storage.

---

# 29. Aurora cluster instances

An Aurora cluster can contain:

```text
One writer
+
Zero or more readers
```

## Writer

Handles:

* Writes.
* Transactions.
* Reads sent to writer endpoint.

## Readers

Handle:

* Read-only queries.
* Read scaling.
* Failover promotion.

For production high availability, add at least one reader in another Availability Zone.

---

# 30. Aurora endpoints

Aurora provides several endpoint types.

```text
Cluster/writer endpoint
Reader endpoint
Instance endpoint
Custom endpoint
Global writer endpoint where applicable
```

## Writer endpoint

Connects to the current writer.

## Reader endpoint

Balances new read connections across available Aurora readers.

## Instance endpoint

Connects to one specific DB instance.

Aurora endpoints allow applications to connect according to workload role without hardcoding individual instance identities. ([AWS Documentation][11])

---

# 31. Aurora reader endpoint

```text
Application read pool
        |
        v
Reader endpoint
        |
        ├── Reader A
        ├── Reader B
        └── Reader C
```

The reader endpoint balances connections, not individual SQL statements.

A long-lived connection remains attached to the reader selected when that connection was created.

For effective balancing:

* Maintain sensible connection lifetimes.
* Avoid one permanent connection for all reads.
* Use an application connection pool.
* Monitor replica utilisation individually.

---

# 32. Aurora failover

During failover:

```text
Writer becomes unavailable
        |
        v
Aurora selects a reader
        |
        v
Reader promoted to writer
        |
        v
Cluster writer endpoint points to new writer
```

Other readers can continue serving read traffic. Promotion priority can influence which reader becomes the failover target. ([AWS Documentation][12])

For faster failover:

* Create at least one reader.
* Use similar instance sizes.
* Configure failover priorities.
* Use cluster endpoints.
* Handle reconnects correctly.
* Avoid long DNS caching.

---

# 33. RDS versus Aurora

## Choose standard RDS when

* You need Oracle, SQL Server, Db2 or MariaDB.
* Existing engine compatibility must be exact.
* Aurora’s features are unnecessary.
* A traditional instance/storage model is preferred.
* Workload economics favour RDS.
* Unsupported Aurora extensions are required.

## Choose Aurora when

* MySQL or PostgreSQL compatibility is acceptable.
* You need rapid read scaling.
* You want shared distributed storage.
* Fast instance failover matters.
* Aurora Global Database is required.
* Aurora Serverless is useful.
* Aurora-specific performance features are valuable.

Always benchmark your workload. Compatibility does not guarantee identical performance or extension support.

---

# 34. Aurora storage configurations

Aurora currently offers:

```text
Aurora Standard
Aurora I/O-Optimized
```

## Aurora Standard

You pay for database instances, storage and database I/O operations.

## Aurora I/O-Optimized

Database I/O charges are included differently, improving price predictability for I/O-intensive workloads.

AWS suggests evaluating I/O-Optimized when I/O cost is a significant portion of total Aurora database spend. ([AWS Documentation][13])

Do not select solely based on workload name. Compare actual database I/O and compute cost.

---

# 35. Aurora Serverless v2

Aurora Serverless v2 dynamically adjusts database compute capacity.

```text
Low demand
   |
   v
Lower Aurora Capacity Units

High demand
   |
   v
Higher Aurora Capacity Units
```

It uses the same Aurora cluster storage model and can include serverless writers and readers. Capacity is configured using a minimum and maximum Aurora Capacity Unit range. ([AWS Documentation][14])

---

# 36. Aurora Capacity Units

Aurora Serverless capacity is measured in:

```text
ACUs
```

Current supported configuration can range from zero to 256 ACUs for eligible versions and platforms, in increments of 0.5 ACU. Each ACU corresponds to approximately 2 GiB of memory with associated CPU and networking resources. Exact supported minimums and maximums depend on engine and platform version. ([AWS Documentation][15])

Example:

```text
Minimum:
2 ACUs

Maximum:
32 ACUs
```

---

# 37. Aurora Serverless auto-pause

Eligible Aurora Serverless versions can use:

```text
Minimum capacity = 0 ACUs
```

This permits automatic pause after a configured idle period and automatic resume when a new connection arrives. ([AWS Documentation][16])

Good for:

* Development.
* Test environments.
* Infrequently used tools.
* Workloads tolerant of resume latency.

Be cautious for:

* Low-latency customer APIs.
* Persistent connection workloads.
* Services requiring immediate availability.
* Workloads with frequent short idle periods.

---

# 38. Serverless does not remove capacity planning

You still need to choose:

```text
Minimum ACU
Maximum ACU
Reader scaling configuration
Auto-pause behaviour
```

A low minimum may cause:

* Greater scale-up distance.
* Reduced cache size.
* Higher latency after quiet periods.

A low maximum may cause:

* Capacity saturation.
* Increased query latency.
* Connection pressure.

Monitor:

```text
ServerlessDatabaseCapacity
ACUUtilization
DatabaseConnections
DBLoad
CPU
Latency
```

Scaling speed is affected by the selected range and the distance between minimum and maximum capacity. ([AWS Documentation][14])

---

# 39. Database connection problem

Relational databases have finite connection capacity.

Suppose:

```text
ECS tasks:
50

Connections per task:
20

Potential connections:
1,000
```

If the database supports only 500 safe application connections:

```text
Connection exhaustion
```

Serverless and autoscaling applications can make this worse:

```text
Traffic spike
    |
    v
More Lambda invocations or ECS tasks
    |
    v
More database connections
    |
    v
Database overload
```

---

# 40. Application connection pools

Each application instance should normally use a bounded connection pool.

Example:

```text
Minimum connections:
2

Maximum connections:
10

Connection timeout:
3 seconds

Idle timeout:
5 minutes

Maximum lifetime:
30 minutes
```

Do not set:

```text
Maximum pool size = database max_connections
```

on every task.

Total possible pool capacity matters:

```text
Maximum application instances
×
Maximum pool connections
```

---

# 41. Connection budget

Example:

```text
Database safe application connections:
400

Reserved for administration:
40

Reserved for migrations and monitoring:
20

Available to application:
340
```

ECS service:

```text
Maximum tasks:
20
```

Connection pool:

```text
340 / 20 = 17
```

Choose a pool maximum below that value, leaving safety margin.

---

# 42. Amazon RDS Proxy

RDS Proxy is a managed database proxy that pools and shares database connections.

```text
Lambda / ECS / EC2
        |
        v
RDS Proxy
        |
        v
Connection pool
        |
        v
RDS or Aurora database
```

It can improve application scalability and resilience by reducing the number of direct database connections and reusing backend database connections. ([AWS Documentation][17])

---

# 43. RDS Proxy benefits

* Connection pooling.
* Connection reuse.
* Reduced database connection churn.
* Better handling of sudden connection spikes.
* Central proxy endpoint.
* Integration with Secrets Manager.
* IAM client authentication.
* Improved behaviour during failover.
* Separate read/write proxy endpoints in supported designs.

RDS Proxy is especially useful for Lambda and highly elastic container workloads.

---

# 44. RDS Proxy does not make the database infinitely scalable

RDS Proxy protects connection management.

It does not fix:

* Slow queries.
* Missing indexes.
* Table locks.
* High transaction volume.
* Low CPU capacity.
* Insufficient IOPS.
* Poor schema design.
* Long-running transactions.
* Hot rows.

```text
RDS Proxy solves:
Connection pressure

It does not solve:
Every database performance problem
```

---

# 45. RDS Proxy authentication modes

RDS Proxy can:

* Authenticate clients using database credentials.
* Require IAM authentication from clients.
* Connect to the database using Secrets Manager credentials.
* Use supported end-to-end IAM authentication configurations.

AWS documents both standard IAM authentication and end-to-end IAM authentication configurations. ([AWS Documentation][18])

---

# 46. Standard proxy authentication

```text
Application
    |
    | IAM authentication
    v
RDS Proxy
    |
    | Username/password from Secrets Manager
    v
Database
```

The proxy retrieves credentials from Secrets Manager using its IAM role.

This removes database passwords from application configuration while still using password authentication between proxy and database.

---

# 47. End-to-end IAM authentication

```text
Application
    |
    | IAM
    v
RDS Proxy
    |
    | IAM
    v
Database
```

Where supported, this avoids storing database credentials for proxy-to-database authentication.

The complete engine, Region and configuration support must be verified before selecting it.

---

# 48. Connection multiplexing

RDS Proxy can reuse one backend database connection among multiple client sessions when session state permits it.

```text
Client A ─┐
Client B ─┼──> Proxy connection pool ──> Database
Client C ─┘
```

But certain session behaviour can pin a client to one database connection.

---

# 49. Connection pinning

Pinning can occur when a client session uses features requiring dedicated session state, such as:

* Certain temporary tables.
* Session-level variables.
* Long transactions.
* Prepared-statement behaviour.
* Session locks.
* Large statements depending on engine and configuration.

Pinned connections reduce multiplexing efficiency.

Monitor proxy metrics and application SQL behaviour rather than assuming every 1,000 client connections will use only a few database connections.

---

# 50. RDS Proxy and failover

RDS Proxy can help applications recover from database failover by maintaining a stable proxy endpoint and redirecting backend connections to the new database target.

Applications must still:

* Handle interrupted transactions.
* Retry connections.
* Use sensible connection timeouts.
* Make business operations idempotent.
* Avoid indefinite retries.

RDS Proxy is also supported with eligible RDS and Aurora Blue/Green Deployments and can reduce switchover impact. ([AWS Documentation][19])

---

# 51. Connection timeouts

Use several bounded timeouts:

```text
Connection acquisition timeout
TCP connection timeout
TLS handshake timeout
Query timeout
Transaction timeout
Socket read timeout
```

Example:

```text
API request timeout:
15 seconds

Database connection timeout:
2 seconds

Query timeout:
5 seconds
```

The database call should fail before the entire customer request exhausts its timeout.

---

# 52. Long transactions

Long transactions can cause:

* Locks.
* MVCC storage growth.
* Replica lag.
* Failover delays.
* Connection pinning.
* Increased recovery work.
* Blue/green switchover delay.

Keep transactions:

```text
Short
Focused
Bounded
Retryable where appropriate
```

Do not open a transaction before calling a slow external API.

Bad:

```text
BEGIN
Update database
Call payment provider for 30 seconds
COMMIT
```

Better:

```text
Persist state
Commit
Perform external workflow
Use idempotent follow-up transaction
```

---

# 53. Automated backups

RDS automated backups enable point-in-time recovery during the configured backup-retention period.

For RDS DB instances, backup retention can be configured between zero and 35 days. A zero-day retention disables automated backups and point-in-time recovery, while production databases should normally use a positive retention period. ([AWS Documentation][20])

Recommended production starting point:

```text
Retention:
7–35 days
```

Choose based on compliance, recovery requirements and cost.

---

# 54. Point-in-time recovery

PITR lets you restore a database to a selected time within the retained backup window.

```text
Production database
      |
      | Automated backups and transaction logs
      v
Restore point
      |
      v
New DB instance or cluster
```

The restore creates a new database resource; it does not rewind the existing production database in place. ([AWS Documentation][21])

---

# 55. PITR incident example

At:

```text
10:00:
Deployment starts

10:05:
Bug deletes customer records

10:15:
Incident detected
```

Recovery:

```text
Restore to 10:04
        |
        v
New database created
        |
        v
Validate restored data
        |
        v
Reconcile valid writes after 10:04
        |
        v
Redirect application
```

PITR restores database state. It does not automatically reconcile legitimate transactions written after the chosen restore point.

---

# 56. Backup window

RDS takes automated backups during a preferred backup window.

Select a window with:

* Lower database activity.
* Reduced batch processing.
* Fewer long transactions.
* Minimal maintenance overlap.
* Operational team awareness.

Backups are managed, but workload and engine behaviour can still affect perceived performance.

---

# 57. Manual snapshots

Manual snapshots remain until explicitly deleted.

Use for:

* Pre-upgrade protection.
* Release checkpoints.
* Compliance retention.
* Migration milestones.
* Long-term recovery.
* Cross-account sharing.
* Cross-Region copies.

Automated backups follow retention policy. Manual snapshots require their own lifecycle and cost management.

---

# 58. Retained automated backups

When deleting eligible RDS resources, you can choose to retain automated backups.

The retained backups can remain available according to the configured backup-retention period and can support point-in-time recovery after the original database is deleted. ([AWS Documentation][22])

This is not a substitute for taking a final snapshot before planned deletion.

---

# 59. AWS Backup

AWS Backup can centrally manage RDS and Aurora backup policies.

Use it for:

* Cross-account backup vaults.
* Organisation-wide backup policies.
* Backup retention.
* Vault lock.
* Compliance reporting.
* Cross-Region copies.
* Centralised recovery governance.

Native RDS automated backups remain important for operational PITR, while AWS Backup can provide broader governance.

---

# 60. Restore testing

A backup is not proven until it has been restored.

Test:

```text
Can the snapshot restore?
How long does restoration take?
Can the application connect?
Are users and permissions present?
Are parameter groups correct?
Are alarms attached?
Is data logically consistent?
```

Create scheduled restore tests for critical databases.

---

# 61. Snapshot sharing

Manual RDS snapshots can be shared with other accounts.

For encrypted snapshots:

* Use a customer-managed KMS key.
* Grant the target account KMS access.
* Share the snapshot.
* Let the target account copy it with its own KMS key.

Snapshots encrypted using the source account’s default AWS-managed RDS KMS key cannot be shared directly in the same way as customer-managed-key snapshots. ([AWS Documentation][23])

---

# 62. Encryption at rest

RDS and Aurora support encryption using AWS KMS.

Encryption covers:

* Database storage.
* Automated backups.
* Snapshots.
* Logs stored as part of the encrypted resource.
* Read replicas created from encrypted sources.

For RDS, an encrypted source produces encrypted replicas and backups. Adding encryption to an existing unencrypted database generally requires snapshot-copy and restore or migration into a new encrypted database. ([AWS Documentation][24])

---

# 63. KMS key design

Use customer-managed KMS keys when you need:

* Cross-account snapshot sharing.
* Custom key policy.
* Independent key rotation controls.
* Centralised security ownership.
* Audit separation.
* Regulatory control.

Key policy must allow:

* RDS service usage.
* Database provisioning roles.
* Backup roles.
* Snapshot-copy roles.
* Disaster-recovery accounts.

A disabled or deleted KMS key can make encrypted database resources inaccessible.

---

# 64. Encryption in transit

Applications should connect using TLS.

```text
Application
    |
    | TLS-encrypted database connection
    v
RDS / Aurora
```

Configure:

* Current CA certificate bundle.
* Certificate verification.
* Hostname verification.
* Required TLS mode.
* Secure driver settings.
* Certificate-rotation procedures.

Avoid configurations that encrypt traffic but skip server identity validation.

---

# 65. Credentials

Recommended credential sources:

```text
AWS Secrets Manager
IAM database authentication where supported
RDS Proxy authentication
```

Avoid:

* Passwords in Docker images.
* Passwords committed to Git.
* Plain Terraform variables.
* Shared administrator credentials.
* Passwords printed in logs.

Applications should normally use a dedicated database user with only required permissions.

---

# 66. Secrets Manager rotation

Secrets Manager can rotate supported database credentials.

Rotation design must account for:

* Application connection pools.
* Old active connections.
* Proxy behaviour.
* User permissions.
* Failed rotation recovery.
* Rotation Lambda networking.
* Multi-Region secrets where required.

A rotated password does not automatically update credentials hardcoded inside a running container.

---

# 67. Database parameter groups

A DB parameter group controls engine runtime settings.

Examples:

```text
max_connections
log_min_duration_statement
work_mem
shared_buffers-related settings where exposed
character set
timeouts
replication parameters
```

Parameters can be:

```text
Dynamic:
Applied without restart

Static:
Require database restart
```

Use separate parameter groups for:

```text
development
staging
production
```

Version parameter groups through infrastructure as code.

---

# 68. Option groups

For engines such as Oracle and SQL Server, option groups enable selected engine-specific capabilities.

Examples may include:

* Native backup integration.
* Auditing.
* Transparent data encryption integration.
* Engine-specific extensions.
* Network or feature options.

Option-group availability varies by engine, edition and version.

---

# 69. Maintenance windows

RDS uses maintenance windows for eligible operations such as:

* Engine patching.
* Operating-system maintenance.
* Hardware maintenance.
* Instance changes requiring restart.
* Certain configuration changes.

Choose a window that:

* Matches operational staffing.
* Avoids backup overlap.
* Avoids peak traffic.
* Is included in customer communication plans.
* Is tested in staging first.

Multi-AZ reduces downtime risk but does not guarantee zero impact during every maintenance operation.

---

# 70. Minor and major engine upgrades

## Minor upgrades

Often include:

* Security fixes.
* Bug fixes.
* Compatibility updates.

## Major upgrades

Can include:

* Behaviour changes.
* Removed features.
* Extension incompatibilities.
* Query-plan changes.
* Application-driver changes.
* Longer upgrade time.

Always test:

```text
Application queries
ORM
Database extensions
Stored procedures
Drivers
Monitoring
Backup/restore
Failover
```

before production upgrade.

---

# 71. RDS Blue/Green Deployments

RDS Blue/Green Deployments create a synchronised staging environment from the production database.

```text
Blue:
Current production database

Green:
Synchronized staging database
```

You can make changes in green, such as:

* Engine upgrades.
* Parameter-group changes.
* Instance-class changes.
* Database configuration changes.

When ready, RDS switches production to green. Support currently includes eligible RDS for MariaDB, MySQL and PostgreSQL deployments and eligible Aurora MySQL/PostgreSQL configurations. ([AWS Documentation][19])

---

# 72. Blue/green workflow

```text
Production blue database
        |
        v
Create synchronized green environment
        |
        v
Upgrade and test green
        |
        v
Verify replication lag
        |
        v
Start switchover
        |
        v
Block writes briefly
        |
        v
Synchronize final changes
        |
        v
Green becomes production
```

Applications should still be designed to reconnect after endpoint or topology changes.

---

# 73. Blue/green advantages

* Production-like upgrade testing.
* Reduced upgrade risk.
* Lower switchover downtime.
* Engine-version validation.
* Parameter validation.
* Easier rollback planning before switchover.
* Compatibility with RDS Proxy for supported designs.

RDS Proxy and database-aware drivers can reduce downtime by responding more quickly to writer topology changes than clients waiting only for DNS propagation. ([AWS Documentation][19])

---

# 74. Blue/green limitations

Current limitations vary by engine and deployment type. Examples include restrictions involving:

* Multi-AZ DB clusters.
* Cross-Region and cascading replicas.
* Some Global Database combinations.
* Encryption-state changes.
* Specific engine features.
* CloudFormation support for certain blue/green operations.
* Secrets Manager-managed master-password configurations.

Review current engine-specific documentation before making blue/green your upgrade strategy. ([AWS Documentation][25])

---

# 75. Database monitoring layers

Use several monitoring layers:

```text
CloudWatch infrastructure metrics
Enhanced Monitoring
CloudWatch Database Insights
Database logs
Application telemetry
Query statistics
RDS events
```

No single metric provides the complete database state.

---

# 76. Important CloudWatch metrics

Monitor:

```text
CPUUtilization
DatabaseConnections
FreeableMemory
FreeStorageSpace
ReadLatency
WriteLatency
ReadIOPS
WriteIOPS
DiskQueueDepth
NetworkReceiveThroughput
NetworkTransmitThroughput
ReplicaLag
BurstBalance where applicable
Deadlocks
CommitLatency where available
```

For Aurora also monitor:

```text
AuroraReplicaLag
AuroraReplicaLagMaximum
VolumeReadIOPs
VolumeWriteIOPs
ServerlessDatabaseCapacity
ACUUtilization
```

---

# 77. CloudWatch Database Insights transition

A critical current operational change applies in **July 2026**.

AWS announced the end of the standalone Performance Insights console experience on **July 31, 2026**. Database monitoring is moving to CloudWatch Database Insights. After that date, capabilities such as execution plans and on-demand analysis require the Advanced mode of Database Insights. Teams should review their RDS and Aurora monitoring configuration now rather than waiting until after the transition. ([AWS Documentation][26])

Current date:

```text
July 28, 2026
```

This transition is therefore only days away.

---

# 78. Database Insights

CloudWatch Database Insights provides fleet-level database observability for supported RDS and Aurora engines.

It can help analyse:

* Database load.
* Top SQL.
* Wait events.
* Hosts.
* Users.
* Applications.
* Execution plans in supported Advanced mode.
* On-demand performance analysis.
* Database fleet health.

Standard and Advanced modes provide different retention and diagnostic capabilities. ([AWS Documentation][27])

---

# 79. Database load mental model

Database load is often represented as:

```text
Average Active Sessions
```

A session may be:

```text
Running on CPU
or
Waiting
```

Example:

```text
DB load:
20 active sessions

Database vCPUs:
4
```

If most sessions wait on CPU:

```text
Possible CPU saturation
```

If most wait on locks:

```text
Concurrency or transaction problem
```

If most wait on storage:

```text
I/O or query-access problem
```

CPU utilisation alone does not reveal why SQL is slow.

---

# 80. Enhanced Monitoring

Enhanced Monitoring provides operating-system-level metrics from the database host, including more granular CPU, memory, process and filesystem information.

Use it to distinguish:

```text
Database process CPU
Operating-system CPU
Memory pressure
Swap activity
Process utilisation
```

It is especially useful when CloudWatch’s standard one-minute instance metrics are too coarse for investigation.

---

# 81. Database logs

Export supported database logs to CloudWatch Logs.

Examples:

```text
PostgreSQL logs
MySQL error logs
MySQL slow-query logs
General logs where justified
Audit logs
Upgrade logs
```

Configure retention.

Do not enable extremely verbose logs permanently without considering:

* Database overhead.
* Storage.
* CloudWatch cost.
* Sensitive values.
* Query-text exposure.

---

# 82. Slow-query monitoring

Slow queries often result from:

* Missing indexes.
* Wrong indexes.
* Table scans.
* Large result sets.
* Lock waits.
* Bad joins.
* Stale statistics.
* Parameter-sensitive query plans.
* Excessive application queries.
* N+1 ORM behaviour.

Workflow:

```text
Find high-load SQL
        |
        v
Examine execution plan
        |
        v
Check rows examined
        |
        v
Check indexes
        |
        v
Test change in staging
        |
        v
Deploy and measure
```

Do not scale the database instance before investigating the SQL consuming the capacity.

---

# 83. Database alarms

Recommended alarms:

```text
CPU above sustained threshold
FreeableMemory too low
FreeStorageSpace too low
DatabaseConnections near safe maximum
ReplicaLag above RPO/read threshold
ReadLatency or WriteLatency high
Deadlocks increasing
Failover event
Backup failure
Database restart
Storage autoscaling approaching limit
Database Insights DB load above capacity
```

Use dynamic thresholds or anomaly detection where fixed thresholds create excessive noise.

---

# 84. Freeable memory

Low freeable memory does not always mean failure because databases intentionally use memory for caching.

Investigate:

```text
FreeableMemory trend
Swap usage
Query latency
Database load
Cache hit ratio
OOM or restart events
Connection count
```

A stable database using most memory for cache may be healthy.

Rapidly falling memory with increasing swap and latency indicates a problem.

---

# 85. High CPU troubleshooting

Check:

1. Top SQL by CPU.
2. Query execution plans.
3. Missing indexes.
4. Increased traffic.
5. Background maintenance.
6. Autovacuum behaviour for PostgreSQL.
7. Large batch jobs.
8. Connection explosion.
9. Lock contention.
10. Instance size.

Possible fixes:

* Query optimisation.
* Index creation.
* Caching.
* Read replica.
* Workload scheduling.
* Connection control.
* Instance scaling.

---

# 86. High connection troubleshooting

Symptoms:

```text
Too many connections
Connection timeout
Remaining connection slots reserved
DatabaseConnections near maximum
```

Check:

* Maximum ECS tasks or Lambda concurrency.
* Per-instance connection-pool size.
* Idle connections.
* Connection leaks.
* Long transactions.
* Proxy use.
* Administrative connection reserve.
* Database `max_connections`.

Correct architecture:

```text
Elastic application
        |
        v
Bounded application pools
        |
        v
RDS Proxy
        |
        v
Bounded database connections
```

---

# 87. Replica lag troubleshooting

Possible causes:

* Heavy write rate.
* Long transactions.
* Large DDL operation.
* Replica under-sized.
* Storage pressure.
* Network transfer.
* Query conflicts.
* Replica executing expensive reads.
* Replication worker configuration.

Impact:

```text
Stale reads
Delayed DR recovery point
Promotion data loss risk
Blue/green switchover delay
```

Monitor lag in time and replication position where supported.

---

# 88. Storage-full incident

When storage approaches exhaustion:

```text
Writes slow or fail
Transactions fail
Database may become unavailable
Logs cannot expand
Replication can stop
```

Prevent with:

* Storage autoscaling where supported.
* Free-storage alarms.
* Log retention.
* Table and index maintenance.
* Data archiving.
* Capacity forecasting.
* Removal of unused indexes.
* Partitioning large data sets.

Do not wait until storage reaches zero.

---

# 89. Storage autoscaling

RDS storage autoscaling can increase allocated storage when free space becomes low, subject to configuration and engine support.

It does not automatically shrink storage later.

Configure:

```text
Initial allocated storage
Maximum storage threshold
Free-storage alarms
Cost alerts
```

Storage autoscaling protects availability, but an unbounded data-growth bug can still increase cost significantly.

---

# 90. Disaster-recovery terminology

## Recovery Point Objective

```text
How much data can the business lose?
```

Example:

```text
RPO = 5 minutes
```

## Recovery Time Objective

```text
How long can the service remain unavailable?
```

Example:

```text
RTO = 30 minutes
```

Choose the architecture from the required RPO and RTO—not from the service name.

---

# 91. Backup-and-restore DR

```text
Primary Region
└── Snapshots copied to DR Region

Disaster
    |
    v
Restore database
    |
    v
Deploy or activate application
```

Characteristics:

```text
Cost:
Lower

RTO:
Higher

RPO:
Depends on snapshot-copy frequency
```

Suitable for less critical systems.

---

# 92. Cross-Region replica DR

```text
Primary Region
└── Writable database
        |
        v
DR Region
└── Asynchronous read replica
```

During disaster:

```text
Promote read replica
      |
      v
Update application routing
      |
      v
Enable backups and monitoring
```

Characteristics:

```text
Cost:
Medium

RTO:
Lower than restore

RPO:
Depends on replication lag
```

---

# 93. Aurora Global Database

Aurora Global Database links Aurora clusters across Regions.

```text
Primary Region
└── Writer cluster

Secondary Region A
└── Read-only cluster

Secondary Region B
└── Read-only cluster
```

It uses Aurora’s storage-based cross-Region replication architecture and provides local read capability in secondary Regions. ([AWS Documentation][28])

---

# 94. Global Database writer endpoint

Aurora Global Database can provide a global writer endpoint that points to the primary cluster’s writer.

After a managed switchover or failover, the endpoint can follow the new primary, reducing application connection-string changes. ([AWS Documentation][10])

Applications still need:

* Multi-Region compute.
* Credential replication.
* Network routing.
* Reconnection handling.
* Regional dependency design.
* Failover testing.

---

# 95. Global Database switchover versus failover

## Switchover

Used for planned operations.

```text
Primary healthy
Secondary healthy
Controlled role change
```

Goal:

* Minimal or no data loss.
* Planned regional maintenance.
* DR testing.
* Regional migration.

## Failover

Used when the primary Region is unavailable.

```text
Primary unavailable
        |
        v
Promote secondary
```

Potential data loss depends on the latest replicated state and the chosen recovery procedure.

---

# 96. Multi-Region is more than the database

A complete multi-Region architecture needs:

```text
Application compute
Load balancing
DNS or Global Accelerator
Secrets
KMS keys
Container images
Configuration
Queues
Event consumers
Observability
Certificates
Database
```

A global database with only one application Region does not provide complete application-region resilience.

---

# 97. RDS Blue/Green versus DR

Blue/green deployments solve:

```text
Database upgrade and configuration risk
```

They do not primarily solve:

```text
Regional disaster recovery
```

Cross-Region replica or Global Database solves:

```text
Regional database resilience
```

Use each for its intended problem.

---

# 98. Migration strategies

Migration options include:

```text
Native dump and restore
Native replication
AWS Database Migration Service
Snapshot migration
Read replica migration
Blue/green migration
Application dual-write, used cautiously
```

Selection depends on:

* Source engine.
* Target engine.
* Database size.
* Allowed downtime.
* Network bandwidth.
* Change rate.
* Schema compatibility.
* Validation requirements.

---

# 99. Homogeneous migration

Example:

```text
PostgreSQL on-premises
        |
        v
RDS for PostgreSQL
```

Possible tools:

* Native logical dump and restore.
* Streaming or logical replication.
* AWS DMS.
* Snapshot where source supports it.
* Database-specific replication.

Homogeneous migration usually requires fewer schema changes.

---

# 100. Heterogeneous migration

Example:

```text
Oracle
   |
   v
Aurora PostgreSQL
```

Requires:

* Schema conversion.
* Data-type conversion.
* Stored-procedure conversion.
* SQL rewrites.
* Application testing.
* Data migration.
* Functional validation.
* Performance testing.

Do not estimate heterogeneous migration only from database size. Application SQL compatibility is often the larger effort.

---

# 101. Low-downtime migration pattern

```text
1. Create target database.

2. Load historical data.

3. Start continuous replication.

4. Validate row counts and checksums.

5. Test application against target.

6. Stop or reduce source writes.

7. Allow replication to catch up.

8. Switch application.

9. Monitor.

10. Retain source for controlled rollback.
```

Define exactly when the source becomes read-only and which system is authoritative.

---

# 102. Database cutover

Before cutover:

```text
Target replication lag:
Near zero

Application configuration:
Ready

Secrets:
Ready

Network:
Ready

Monitoring:
Ready

Rollback:
Defined
```

During cutover:

```text
Pause writes
      |
      v
Apply remaining changes
      |
      v
Switch endpoint or secret
      |
      v
Restart or recycle connection pools
      |
      v
Validate writes and reads
```

Do not switch DNS without considering application DNS and connection caching.

---

# 103. Terraform RDS PostgreSQL example

```hcl
resource "aws_db_subnet_group" "production" {
  name = "production-database"

  subnet_ids = [
    aws_subnet.database_a.id,
    aws_subnet.database_b.id,
    aws_subnet.database_c.id
  ]

  tags = {
    Environment = "production"
  }
}

resource "aws_security_group" "database" {
  name   = "production-database"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from application tasks"

    protocol  = "tcp"
    from_port = 5432
    to_port   = 5432

    security_groups = [
      aws_security_group.todo_api.id
    ]
  }

  egress {
    protocol  = "-1"
    from_port = 0
    to_port   = 0

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}
```

---

# 104. Terraform database parameter group

```hcl
resource "aws_db_parameter_group" "postgres" {
  name   = "production-postgres"
  family = "postgres17"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "300000"
  }

  tags = {
    Environment = "production"
  }
}
```

Confirm parameter family and supported settings against the exact engine version.

---

# 105. Terraform RDS instance

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "production-todoapp"

  engine         = "postgres"
  engine_version = var.postgres_engine_version

  instance_class = var.database_instance_class

  allocated_storage     = 100
  max_allocated_storage = 500

  storage_type = "gp3"

  db_name  = "todoapp"
  username = "database_admin"

  manage_master_user_password = true

  port = 5432

  multi_az = true

  db_subnet_group_name = aws_db_subnet_group.production.name

  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  parameter_group_name = aws_db_parameter_group.postgres.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  backup_retention_period = 14
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  copy_tags_to_snapshot = true

  deletion_protection = true
  skip_final_snapshot = false

  final_snapshot_identifier = (
    "production-todoapp-final"
  )

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled = true

  auto_minor_version_upgrade = true

  publicly_accessible = false

  apply_immediately = false

  tags = {
    Application = "TodoApp"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

Because of the July 31, 2026 monitoring transition, evaluate Database Insights settings rather than relying only on the legacy Performance Insights configuration.

---

# 106. Terraform Aurora cluster

```hcl
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "production-todoapp"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_postgres_version

  database_name   = "todoapp"
  master_username = "database_admin"

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.production.name

  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  backup_retention_period = 14
  preferred_backup_window = "18:00-19:00"

  preferred_maintenance_window = (
    "sun:19:00-sun:20:00"
  )

  deletion_protection = true
  skip_final_snapshot = false

  final_snapshot_identifier = (
    "production-todoapp-aurora-final"
  )

  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  storage_type = "aurora-iopt1"

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

The exact Terraform storage-type value and engine compatibility should be verified against the current AWS provider version.

---

# 107. Terraform Aurora instances

```hcl
resource "aws_rds_cluster_instance" "aurora" {
  count = 3

  identifier = (
    "production-todoapp-${count.index + 1}"
  )

  cluster_identifier = aws_rds_cluster.aurora.id

  instance_class = var.aurora_instance_class

  engine         = aws_rds_cluster.aurora.engine
  engine_version = aws_rds_cluster.aurora.engine_version

  publicly_accessible = false

  performance_insights_enabled = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  promotion_tier = count.index

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

This creates one writer and two readers after cluster placement and role assignment.

---

# 108. Terraform Aurora Serverless v2

```hcl
resource "aws_rds_cluster" "serverless" {
  cluster_identifier = "production-todoapp-serverless"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_postgres_version

  database_name   = "todoapp"
  master_username = "database_admin"

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.production.name

  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  serverlessv2_scaling_configuration {
    min_capacity = 2
    max_capacity = 32
  }

  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  backup_retention_period = 14

  deletion_protection = true
  skip_final_snapshot = false

  final_snapshot_identifier = (
    "production-todoapp-serverless-final"
  )
}

resource "aws_rds_cluster_instance" "serverless_writer" {
  identifier = "production-todoapp-serverless-writer"

  cluster_identifier = aws_rds_cluster.serverless.id

  instance_class = "db.serverless"

  engine         = aws_rds_cluster.serverless.engine
  engine_version = aws_rds_cluster.serverless.engine_version
}
```

---

# 109. Terraform Secrets Manager retrieval

When `manage_master_user_password` is enabled, RDS manages the master credential in Secrets Manager.

Application workloads should not usually use the master account.

Create separate application users:

```text
todoapp_runtime
todoapp_migration
todoapp_readonly
```

with different permissions.

---

# 110. Terraform RDS Proxy

```hcl
resource "aws_iam_role" "rds_proxy" {
  name = "production-todoapp-rds-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "rds.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_db_proxy" "todoapp" {
  name = "production-todoapp"

  engine_family = "POSTGRESQL"

  role_arn = aws_iam_role.rds_proxy.arn

  vpc_subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]

  vpc_security_group_ids = [
    aws_security_group.rds_proxy.id
  ]

  require_tls = true

  idle_client_timeout = 1800

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.app_database.arn
    iam_auth    = "REQUIRED"
  }

  tags = {
    Application = "TodoApp"
    Environment = "production"
  }
}
```

---

# 111. Terraform proxy target group

```hcl
resource "aws_db_proxy_default_target_group" "todoapp" {
  db_proxy_name = aws_db_proxy.todoapp.name

  connection_pool_config {
    max_connections_percent      = 80
    max_idle_connections_percent = 40

    connection_borrow_timeout = 5

    session_pinning_filters = [
      "EXCLUDE_VARIABLE_SETS"
    ]
  }
}

resource "aws_db_proxy_target" "todoapp" {
  db_proxy_name = aws_db_proxy.todoapp.name

  target_group_name = (
    aws_db_proxy_default_target_group.todoapp.name
  )

  db_instance_identifier = aws_db_instance.postgres.identifier
}
```

Session-pinning filters must be evaluated carefully against actual application behaviour.

---

# 112. CLI database inspection

List DB instances:

```bash
aws rds describe-db-instances \
  --region ap-south-1
```

Inspect one instance:

```bash
aws rds describe-db-instances \
  --db-instance-identifier production-todoapp \
  --query 'DBInstances[0].{
    Status:DBInstanceStatus,
    Endpoint:Endpoint.Address,
    Port:Endpoint.Port,
    MultiAZ:MultiAZ,
    Engine:Engine,
    Version:EngineVersion,
    Storage:AllocatedStorage,
    BackupRetention:BackupRetentionPeriod
  }' \
  --region ap-south-1
```

---

# 113. CLI Aurora inspection

```bash
aws rds describe-db-clusters \
  --db-cluster-identifier production-todoapp \
  --query 'DBClusters[0].{
    Status:Status,
    WriterEndpoint:Endpoint,
    ReaderEndpoint:ReaderEndpoint,
    Engine:Engine,
    Version:EngineVersion,
    Members:DBClusterMembers
  }' \
  --region ap-south-1
```

---

# 114. Test Multi-AZ failover

For an approved test environment:

```bash
aws rds reboot-db-instance \
  --db-instance-identifier staging-todoapp \
  --force-failover \
  --region ap-south-1
```

During the test, measure:

* Connection interruption.
* DNS update behaviour.
* Connection-pool recovery.
* API error rate.
* Transaction retry behaviour.
* Total recovery time.
* Monitoring alerts.

Do not run an unplanned failover test in production.

---

# 115. Aurora manual failover

For a test cluster:

```bash
aws rds failover-db-cluster \
  --db-cluster-identifier staging-todoapp \
  --region ap-south-1
```

Validate that:

* Writer endpoint follows the new writer.
* Application reconnects.
* Reader traffic remains available.
* Alerts fire.
* Transaction behaviour is safe.

---

# 116. TodoApp production architecture

```text
Users
  |
  v
CloudFront
  |
  v
ALB / API Gateway
  |
  v
ECS Fargate Todo API
  |
  v
RDS Proxy
  |
  v
Aurora PostgreSQL
├── Writer in AZ-A
├── Reader in AZ-B
└── Reader in AZ-C
```

Supporting services:

```text
Secrets Manager
KMS
CloudWatch Database Insights
Enhanced Monitoring
CloudWatch Logs
AWS Backup
EventBridge RDS events
SNS operational alerts
```

---

# 117. TodoApp connection architecture

Write operations:

```text
Todo API
    |
    v
RDS Proxy writer endpoint
    |
    v
Aurora writer
```

Reporting reads:

```text
Reporting service
    |
    v
Aurora reader endpoint
    |
    ├── Reader A
    └── Reader B
```

Do not route a request requiring immediate read-after-write consistency to an asynchronous reader automatically.

---

# 118. Production database checklist

```text
[ ] Correct database engine selected
[ ] RDS versus Aurora decision documented
[ ] Database runs in private subnets
[ ] Public accessibility is disabled
[ ] Subnet group spans multiple AZs
[ ] Security groups reference application groups
[ ] Multi-AZ or cluster HA is enabled
[ ] Failover has been tested
[ ] Application uses DNS endpoints
[ ] DNS caching is controlled
[ ] Application reconnect logic is tested
[ ] Transactions are bounded
[ ] Connection pools are limited
[ ] Maximum application scale fits connection budget
[ ] RDS Proxy is evaluated
[ ] Read replicas are used only for acceptable consistency
[ ] Replica lag alarms exist
[ ] Automated backups are enabled
[ ] Backup retention meets RPO
[ ] Final snapshots are required
[ ] PITR restore has been tested
[ ] Cross-account backup is evaluated
[ ] Cross-Region DR is documented
[ ] RTO and RPO are approved
[ ] Storage encryption uses approved KMS key
[ ] TLS is required
[ ] Credentials use Secrets Manager or IAM
[ ] Application does not use master account
[ ] Parameter groups are version controlled
[ ] Maintenance window is intentional
[ ] Major upgrades are tested
[ ] Blue/green upgrades are evaluated
[ ] Database Insights migration is completed
[ ] Enhanced Monitoring is enabled where useful
[ ] Database logs are exported
[ ] Slow queries are monitored
[ ] CPU and connection alarms exist
[ ] Free storage alarms exist
[ ] Cost and instance sizing are reviewed
[ ] Rollback and restore procedures are tested
```

---

# 119. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
Amazon RDS:
Managed relational databases

Multi-AZ:
High availability

Read replica:
Read scaling

Automated backups:
Point-in-time recovery
```

## Solutions Architect Associate

Understand:

```text
Single-AZ versus Multi-AZ
Multi-AZ standby versus read replica
Cross-Region read replicas
Aurora writer and readers
Aurora endpoints
RDS Proxy
Automated backups
Manual snapshots
PITR
Encryption
```

## DevOps Engineer Professional

Understand:

```text
Failover testing
Connection-pool design
Proxy pinning
Database Insights
Parameter groups
Blue/green database upgrades
Cross-account backups
KMS snapshot sharing
Aurora Global Database
Switchover and failover
Terraform database lifecycle
Automated monitoring and rollback
```

---

# 120. Interview questions

## Question 1: What is Amazon RDS?

**Answer:**

Amazon RDS is a managed relational database service that automates infrastructure tasks such as provisioning, backups, patching, monitoring and high-availability replication.

## Question 2: What is the difference between Single-AZ and Multi-AZ?

**Answer:**

Single-AZ has one primary deployment. Multi-AZ maintains synchronously replicated capacity in another Availability Zone and supports automatic failover.

## Question 3: Can the standby in a traditional Multi-AZ deployment serve reads?

**Answer:**

No. It is maintained for high availability. Use a read replica or Multi-AZ DB cluster for read traffic.

## Question 4: What is a read replica?

**Answer:**

It is an asynchronously replicated database copy used mainly for read scaling, reporting or disaster-recovery preparation.

## Question 5: Is read-replica promotion automatic?

**Answer:**

Not for an ordinary read replica. It must be explicitly promoted or orchestrated by a recovery system.

## Question 6: What is an RDS Multi-AZ DB cluster?

**Answer:**

It is a three-instance deployment with one writer and two readable replicas across three Availability Zones. The readers also act as automatic failover targets.

## Question 7: What is Amazon Aurora?

**Answer:**

Aurora is an AWS-designed MySQL-compatible or PostgreSQL-compatible relational database using distributed storage across multiple Availability Zones.

## Question 8: What is the Aurora writer endpoint?

**Answer:**

It connects to the current writer instance and follows the writer when failover changes the writer instance.

## Question 9: What is the Aurora reader endpoint?

**Answer:**

It balances new read-only connections across available Aurora reader instances.

## Question 10: Does the Aurora reader endpoint balance every query?

**Answer:**

No. It balances connections. Queries on one existing connection continue using that connection’s selected reader.

## Question 11: What is Aurora Serverless v2?

**Answer:**

It is an Aurora compute mode that dynamically adjusts instance capacity within a configured minimum and maximum ACU range.

## Question 12: What problem does RDS Proxy solve?

**Answer:**

It pools and reuses database connections, reducing connection churn and protecting the database from highly elastic application connection spikes.

## Question 13: Does RDS Proxy fix slow SQL?

**Answer:**

No. It improves connection management but does not fix queries, locks, schema design or insufficient database compute.

## Question 14: What is connection pinning?

**Answer:**

It occurs when session behaviour requires a client to retain a dedicated backend database connection, reducing proxy multiplexing.

## Question 15: What is point-in-time recovery?

**Answer:**

It restores a new database to a selected moment within the automated-backup retention window.

## Question 16: Does PITR modify the existing production database?

**Answer:**

No. It creates a new database instance or cluster.

## Question 17: What is an RDS Blue/Green Deployment?

**Answer:**

It creates a synchronised green staging database where upgrades and changes can be tested before a controlled production switchover.

## Question 18: What is Aurora Global Database?

**Answer:**

It replicates Aurora cluster data across AWS Regions for low-latency regional reads and cross-Region recovery.

## Question 19: What is the difference between RPO and RTO?

**Answer:**

RPO is the acceptable amount of data loss. RTO is the acceptable duration of service unavailability.

## Question 20: How would you protect RDS from Lambda scale?

**Answer:**

Use bounded Lambda concurrency, RDS Proxy, small connection pools, short transactions and database-capacity monitoring.

---

# 121. Never-forget revision

```text
RDS:
Managed relational database service.

Single-AZ:
One primary deployment.

Multi-AZ:
Synchronous high availability.

Standby:
Failover target, not normal read target.

Read replica:
Asynchronous read-scaling copy.

Multi-AZ DB cluster:
Writer plus two readable failover replicas.

Aurora:
Distributed MySQL/PostgreSQL-compatible database.

Writer endpoint:
Current Aurora writer.

Reader endpoint:
Balances new reader connections.

RDS Proxy:
Managed database connection pool.

Connection pinning:
Client requires dedicated backend connection.

Automated backup:
Supports point-in-time recovery.

Snapshot:
Manual long-lived backup.

PITR:
Restore a new database to a selected time.

Parameter group:
Database runtime configuration.

Blue/green:
Synchronised upgrade staging environment.

Global Database:
Aurora cross-Region architecture.

RPO:
Acceptable data loss.

RTO:
Acceptable recovery time.

Database Insights:
CloudWatch database performance observability.
```

## One-line memory trick

```text
Multi-AZ protects availability.
Replicas scale reads.
Proxy controls connections.
Backups recover mistakes.
Global databases protect Regions.
Indexes and SQL determine performance.
```

## Lesson 47 outcome

You can now design a relational architecture where:

```text
A database instance fails
    → Multi-AZ promotes another instance.

Read traffic increases
    → Read replicas absorb reporting queries.

Application containers scale rapidly
    → RDS Proxy pools database connections.

An Aurora writer fails
    → A reader is promoted over shared storage.

Database demand varies
    → Aurora Serverless adjusts ACUs.

A deployment corrupts data
    → PITR restores a clean database.

An engine upgrade is required
    → Blue/green validates it before switchover.

A Region becomes unavailable
    → Cross-Region replica or Global Database supports recovery.

Queries become slow
    → Database Insights identifies SQL and wait events.

Credentials rotate
    → Secrets Manager and controlled connection recycling keep access current.
```

**Next lesson: Lesson 48 — Amazon ElastiCache and MemoryDB production architecture: Redis/Valkey caching, cluster modes, replication, failover, TTLs, cache-aside, write-through, eviction, session storage, distributed locks and database protection.**

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/gettingstartedguide/concepts.html?utm_source=chatgpt.com "Key concepts and architecture of Amazon RDS - Amazon Relational Database Service"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html?utm_source=chatgpt.com "Configuring and managing a Multi-AZ deployment for Amazon RDS - Amazon Relational Database Service"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html?utm_source=chatgpt.com "Failing over a Multi-AZ DB instance for Amazon RDS - Amazon Relational Database Service"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html?utm_source=chatgpt.com "Multi-AZ DB cluster deployments for Amazon RDS - Amazon Relational Database Service"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html?utm_source=chatgpt.com "Working with DB instance read replicas - Amazon Relational Database Service"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.Promote.html?utm_source=chatgpt.com "Promoting a read replica to be a standalone DB instance - Amazon Relational Database Service"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_MySQL.Replication.ReadReplicas.MultiAZ.html?utm_source=chatgpt.com "Working with Multi-AZ read replica deployments with MySQL - Amazon Relational Database Service"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RDS_Fea_Regions_DB-eng.Feature.CrossRegionReadReplicas.html?utm_source=chatgpt.com "Supported Regions and DB engines for cross-Region read replicas in Amazon RDS - Amazon Relational Database Service"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html?utm_source=chatgpt.com "Amazon Aurora storage - Amazon Aurora"
[10]: https://docs.aws.amazon.com/rds/latest/auroraextendedcontent/aurora-faq-availability-and-durability.html?utm_source=chatgpt.com "Availability and Durability - Amazon Aurora"
[11]: https://docs.aws.amazon.com/en_en/AmazonRDS/latest/AuroraUserGuide/Aurora.Endpoints.Reader.html?utm_source=chatgpt.com "Reader endpoints for Amazon Aurora - Amazon Aurora"
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.AuroraHighAvailability.html?utm_source=chatgpt.com "High availability for Amazon Aurora - Amazon Aurora"
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Concepts.Aurora_Fea_Regions_DB-eng.Feature.storage-type.html?utm_source=chatgpt.com "Supported Regions and Aurora DB engines for cluster storage configurations - Amazon Aurora"
[14]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.how-it-works.html?utm_source=chatgpt.com "How Aurora serverless works - Amazon Aurora"
[15]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.requirements.html?utm_source=chatgpt.com "Requirements and limitations for Aurora serverless - Amazon Aurora"
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html?utm_source=chatgpt.com "Scaling to Zero ACUs with automatic pause and resume for Aurora serverless - Amazon Aurora"
[17]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html?utm_source=chatgpt.com "Amazon RDS Proxy - Amazon Relational Database Service"
[18]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-iam-setup.html?utm_source=chatgpt.com "Configuring IAM authentication for RDS Proxy - Amazon Relational Database Service"
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-overview.html?utm_source=chatgpt.com "Overview of Amazon RDS Blue/Green Deployments - Amazon Relational Database Service"
[20]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.BackupRetention.html?utm_source=chatgpt.com "Backup retention period - Amazon Relational Database Service"
[21]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html?utm_source=chatgpt.com "Restoring a DB instance to a specified time for Amazon RDS - Amazon Relational Database Service"
[22]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.Retaining.html?utm_source=chatgpt.com "Retaining automated backups - Amazon Relational Database Service"
[23]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/share-encrypted-snapshot.html?utm_source=chatgpt.com "Sharing encrypted snapshots for Amazon RDS - Amazon Relational Database Service"
[24]: https://docs.aws.amazon.com/prescriptive-guidance/latest/encryption-best-practices/rds.html?utm_source=chatgpt.com "Amazon Relational Database Service - AWS Prescriptive Guidance"
[25]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-considerations.html?utm_source=chatgpt.com "Limitations and considerations for Amazon RDS blue/green deployments - Amazon Relational Database Service"
[26]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.Overview.html?utm_source=chatgpt.com "Overview of Performance Insights on Amazon RDS - Amazon Relational Database Service"
[27]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights.html?utm_source=chatgpt.com "CloudWatch Database Insights - Amazon CloudWatch"
[28]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database - Amazon Aurora"
