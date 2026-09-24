# AWS Masterclass — Lesson 28 Part 3

# RDS & Aurora Production Operations, Security, Backup, Monitoring & Troubleshooting

We now know how RDS and Aurora are architected. The next question is what matters to a DevOps/SRE engineer at **3:00 AM**:

```text
"The database is slow."

"The app can't connect."

"CPU is 95%."

"We deleted data."

"ReplicaLag is increasing."

"We changed a parameter and RDS says pending-reboot."

"The DB failed over."

"KMS says AccessDenied."

"Connections are exhausted."
```

The first rule is:

```text
DATABASE PROBLEM
      │
      ├── Availability?
      ├── Networking?
      ├── Authentication?
      ├── Connections?
      ├── CPU?
      ├── Memory?
      ├── Storage/I/O?
      ├── SQL/query?
      ├── Locks?
      ├── Replication?
      └── Data corruption/deletion?
```

Do **not** treat every database problem as “increase the instance size.”

---

# 1. Production Database Protection Has Multiple Layers

A mature RDS/Aurora design uses several independent mechanisms:

```text
                           DATABASE
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
       Multi-AZ            BACKUP             REPLICATION
          │                   │                   │
      availability         PITR             readers/global
          │                   │                   │
          ▼                   ▼                   ▼
   survive compute/AZ   historical restore   another copy
```

The distinction is:

```text
Multi-AZ
=
availability
```

```text
Backup / PITR
=
recover historical state
```

```text
Read replica / Global DB
=
maintain another database copy
```

None is a complete replacement for the others.

---

# 2. Automated Backups

For Aurora, automated backups are **continuous and incremental**, and AWS lets you configure a retention period from **1–35 days**. Aurora stores the backup data in S3 and allows restoration to a point within that retention window. ([AWS Documentation][1])

For ordinary RDS DB instances, backup retention can generally be configured from:

```text
0–35 days
```

where:

```text
0
=
automated backups disabled
```

Multi-AZ DB clusters instead require at least one day of retention. ([AWS Documentation][2])

For production:

```text
BackupRetentionPeriod = 0
```

should therefore trigger a very deliberate discussion.

---

# 3. Backup Window

RDS has a:

```text
Backup Window
```

for automated backup-related operations.

It also has a:

```text
Maintenance Window
```

for maintenance-related work.

AWS doesn't allow the DB instance's backup and maintenance windows to overlap. ([AWS Documentation][3])

Think:

```text
02:00–02:30
Backup window


04:00–04:30
Maintenance window
```

rather than scheduling everything simultaneously during peak business traffic.

---

# 4. Point-in-Time Recovery — PITR

Suppose:

```text
14:00  database healthy

14:11  bad deployment

14:12  UPDATE customers
       SET balance = 0;

14:15  incident discovered
```

A snapshot from midnight may lose:

```text
14 hours
```

of legitimate transactions.

PITR instead lets you restore to a particular point within the automated-backup retention period. RDS and Aurora restore PITR into a **new DB instance or cluster** rather than rewinding the current production database in place. ([AWS Documentation][4])

Conceptually:

```text
Backup timeline

13:58
13:59
14:00
...
14:10:59  ← desired recovery point
14:11
14:12      ← corruption
14:13
```

---

# 5. RPO vs RTO

Recall:

```text
RPO
=
How much data can we afford to lose?
```

and:

```text
RTO
=
How long can recovery take?
```

Example requirement:

```text
RPO <= 5 minutes

RTO <= 30 minutes
```

A nightly manual snapshot cannot satisfy a five-minute RPO.

A Deep Archive-style recovery workflow obviously won't satisfy a five-minute RTO either.

Database recovery architecture starts with these two business requirements.

---

# 6. Restoring Does Not Mean Immediately Repointing Production

A safer recovery workflow:

```text
Production DB
     │
     X corruption
     │
     ▼
PITR
     │
     ▼
New Recovery DB
     │
     ├── validate rows
     ├── validate schema
     ├── run application tests
     ├── inspect user permissions
     └── verify consistency
             │
             ▼
       controlled cutover
```

This avoids turning:

```text
one database incident
```

into:

```text
two database incidents
```

because you rushed the restore.

---

# 7. Manual Snapshots

Manual snapshots are useful for checkpoints such as:

```text
before major upgrade
before risky schema migration
before major application release
before parameter change
before data transformation
```

Unlike automated backups, manual snapshots persist until explicitly deleted. Sharing and copying rules vary based on encryption and engine configuration. ([AWS Documentation][5])

Example:

```bash
aws rds create-db-snapshot \
  --db-instance-identifier prod-postgres \
  --db-snapshot-identifier pre-release-2026-08-14 \
  --region ap-south-1
```

For Aurora:

```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier prod-aurora \
  --db-cluster-snapshot-identifier pre-release-2026-08-14 \
  --region ap-south-1
```

---

# 8. Cross-Region Backup

RDS can replicate automated backup snapshots and transaction logs to another AWS Region for additional DR protection. ([AWS Documentation][6])

Architecture:

```text
ap-south-1
Production RDS
      │
      │ automated backup replication
      ▼
ap-southeast-1
DR backup copies
```

This solves a different problem from:

```text
Cross-Region Read Replica
```

A replica is a running database copy.

Backup replication gives you recovery artifacts.

---

# 9. Snapshot Sharing

A manual RDS snapshot can be shared with other AWS accounts subject to service restrictions. Encrypted snapshots cannot be publicly shared, and snapshots encrypted with the default AWS-managed RDS KMS key can't be shared cross-account in the normal way; a customer-managed KMS key is needed for that pattern. ([AWS Documentation][7])

A security-oriented DR design might therefore be:

```text
Production Account
      │
      ▼
manual/copy snapshot
      │
 customer-managed KMS
      │
      ▼
Backup Account
```

rather than placing every recovery artifact under the same administrator boundary.

---

# 10. Database Encryption at Rest

RDS encryption protects items such as:

```text
database storage
automated backups
snapshots
read replicas
```

under the relevant encrypted resource architecture using AWS KMS. ([AWS Documentation][8])

Think:

```text
Database
   │
   ▼
RDS storage
   │
   ▼
KMS encryption
```

You must consider both:

```text
database authorization
```

and:

```text
KMS authorization
```

just as we learned with S3.

---

# 11. Important KMS Limitation

Once an encrypted RDS DB instance is created, AWS doesn't let you simply change the KMS key attached to that existing instance. A common migration path is:

```text
DB
 ↓
snapshot
 ↓
copy snapshot
with desired KMS key
 ↓
restore new DB
 ↓
cut over
```

AWS also allows an **unencrypted snapshot to be copied as an encrypted snapshot**, which can then be restored as an encrypted DB. ([AWS Documentation][8])

Never think:

```text
aws rds modify-db-instance \
  --kms-key-id new-key
```

will simply re-encrypt an existing database in place.

---

# 12. Encryption Does Not Protect Against SQL Mistakes

Suppose:

```sql
DROP TABLE customers;
```

Database encryption says:

```text
"Yes, I'll securely encrypt
the resulting database state."
```

It doesn't say:

```text
"I'll prevent the DROP."
```

Encryption protects:

```text
confidentiality at rest
```

not:

```text
logical deletion
```

For logical recovery, think:

```text
PITR
snapshot
backup
```

---

# 13. Encryption in Transit — TLS

Applications should also protect the:

```text
Application
   │
   │ network connection
   ▼
Database
```

path with TLS.

RDS publishes CA certificate bundles for clients to verify RDS server certificates. With PostgreSQL, `sslmode=verify-full` verifies both certificate trust and that the endpoint hostname matches the certificate. ([AWS Documentation][9])

Example:

```bash
psql \
  "host=$DB_HOST \
   port=5432 \
   dbname=appdb \
   user=appuser \
   sslmode=verify-full \
   sslrootcert=/path/to/global-bundle.pem"
```

This is stronger than:

```text
encrypt traffic
but never verify
who the server is
```

---

# 14. Secrets Manager

Don't put:

```text
DB_PASSWORD=SuperSecret123
```

inside:

```text
GitHub
Docker image
AMI
Jenkinsfile
Terraform variable committed to Git
user data
```

Amazon RDS integrates with AWS Secrets Manager for managing master database credentials, including automatic management/rotation options and IAM-based access to the secret. ([AWS Documentation][10])

Architecture:

```text
EC2 / ECS / Lambda
       │
       │ IAM Role
       ▼
Secrets Manager
       │
       ▼
DB credentials
       │
       ▼
RDS / Aurora
```

---

# 15. Secret Rotation

Secrets Manager can automatically rotate RDS/Aurora credentials. During rotation, Secrets Manager updates both:

```text
the stored secret

AND

the actual DB credential
```

using its rotation mechanism. ([AWS Documentation][11])

Conceptually:

```text
Password A
    │
    ▼
rotation
    │
    ├── Database → Password B
    │
    └── Secret   → Password B
```

Applications should retrieve credentials dynamically or through appropriate integration rather than expecting one password to remain valid forever.

---

# 16. IAM Database Authentication

For supported RDS/Aurora MySQL, MariaDB, and PostgreSQL configurations, IAM database authentication lets you connect using a temporary SigV4 authentication token instead of storing a long-lived DB password. Tokens are valid for **15 minutes for establishing the connection**; the established DB session doesn't automatically terminate after 15 minutes. ([AWS Documentation][12])

Flow:

```text
Application IAM Role
        │
        ▼
Generate auth token
        │
        ▼
15-minute connection token
        │
        ▼
TLS DB connection
        │
        ▼
RDS / Aurora
```

---

# 17. Generate PostgreSQL IAM Token

Conceptually:

```bash
TOKEN=$(aws rds generate-db-auth-token \
  --hostname "$DB_HOST" \
  --port 5432 \
  --region ap-south-1 \
  --username app_user)
```

Then:

```bash
PGPASSWORD="$TOKEN" psql \
  "host=$DB_HOST \
   port=5432 \
   dbname=appdb \
   user=app_user \
   sslmode=verify-full \
   sslrootcert=/path/to/global-bundle.pem"
```

The IAM principal also needs the appropriate:

```text
rds-db:connect
```

permission and the database user must be configured for IAM authentication. ([AWS Documentation][12])

---

# 18. IAM Auth vs Secrets Manager

These solve similar-looking but different problems.

### Secrets Manager

```text
Application
     │
     ▼
retrieve password
     │
     ▼
traditional DB auth
```

### IAM database authentication

```text
Application
     │
     ▼
IAM
     │
     ▼
short-lived token
```

Neither is always universally superior.

Think about:

```text
connection volume
driver support
operational model
rotation
RDS Proxy
authentication requirements
```

before choosing.

---

# 19. RDS Proxy Authentication

RDS Proxy can operate with database credentials stored in Secrets Manager, and current RDS Proxy also supports end-to-end IAM authentication for supported configurations where both client-to-proxy and proxy-to-database authentication use IAM. ([AWS Documentation][13])

Architecture:

```text
Application
    │
    ▼
RDS Proxy
    │
    ▼
Aurora/RDS
```

with either:

```text
IAM → Proxy
Secrets Manager → DB
```

or:

```text
IAM
all the way through
```

depending on configuration.

---

# 20. Parameter Groups

You don't edit arbitrary operating-system database configuration files on managed RDS like:

```text
/etc/postgresql/postgresql.conf
```

Instead, many engine configuration settings are controlled through:

# DB Parameter Groups

Examples for PostgreSQL include:

```text
max_connections
shared_buffers
statement_timeout
log_statement
autovacuum_*
```

RDS distinguishes **dynamic** parameters, which can take effect without restart, from **static** parameters, which require a DB reboot. ([AWS Documentation][14])

---

# 21. `pending-reboot`

Suppose you change:

```text
max_connections
```

and RDS shows:

```text
pending-reboot
```

That doesn't mean:

```text
RDS is broken.
```

It means the changed static configuration isn't active until the DB instance is rebooted. ([AWS Documentation][14])

Think:

```text
Terraform/API change
       │
       ▼
parameter saved
       │
       ▼
pending-reboot
       │
       ▼
controlled reboot
       │
       ▼
new setting active
```

---

# 22. Dangerous Parameter Changes

Imagine:

```text
Current:
max_connections = 500

Engineer:
"More is better."

New:
max_connections = 100000
```

Each DB connection consumes resources.

AWS specifically warns that PostgreSQL parameters such as `max_connections` and `shared_buffers` can prevent an instance from starting if they are configured beyond what the instance has enough memory to support. ([AWS Documentation][15])

Configuration tuning is therefore:

```text
resource mathematics
```

not:

```text
bigger number = better
```

---

# 23. Maintenance Window

RDS maintenance can include tasks such as:

```text
engine patches
operating-system updates
certificate-related maintenance
pending DB changes
```

depending on the engine/resource and maintenance action. AWS lets you schedule pending modifications for the next maintenance window or choose `Apply immediately`; immediate application can cause an outage for some changes. ([AWS Documentation][16])

Production approach:

```text
change
 ↓
understand outage impact
 ↓
test
 ↓
schedule maintenance
 ↓
monitor
 ↓
validate application
```

---

# 24. `Apply immediately` Does Not Mean “No Downtime”

This button means:

```text
perform modification now
```

not:

```text
perform modification magically
without disruption
```

AWS explicitly notes that choosing Apply immediately can cause outages depending on the modification. ([AWS Documentation][16])

Before clicking it on production, understand exactly what change is being applied.

---

# 25. Minor vs Major Engine Upgrades

Conceptually:

```text
PostgreSQL 16.x
→ newer 16.x

=
minor upgrade
```

versus:

```text
PostgreSQL 16
→ PostgreSQL 17

=
major upgrade
```

Major upgrades require substantially more compatibility testing because database-engine behavior/extensions/features can change. RDS provides engine-specific upgrade workflows and pending-maintenance scheduling. ([AWS Documentation][17])

A production upgrade should include:

```text
extension compatibility
driver compatibility
parameter groups
query regression
schema compatibility
backup
rollback/recovery strategy
application tests
```

---

# 26. Blue/Green Deployment

For supported RDS and Aurora configurations, Blue/Green Deployments allow you to maintain:

```text
BLUE
current production

        │
   replication

GREEN
candidate environment
```

Then test green and perform a controlled switchover. AWS recommends thoroughly testing the green environment and ensuring replication lag is close to zero before switchover. ([AWS Documentation][18])

Architecture:

```text
Application
    │
    ▼
 BLUE
    │
    │ replication
    ▼
 GREEN
    │
 upgrade/test
    │
    ▼
 switchover
```

This is far safer for many upgrade scenarios than:

```text
modify production directly
and hope
```

---

# 27. Current 2026 Monitoring Update: Performance Insights Changed

This is important because many AWS courses are now outdated.

AWS ended the **Performance Insights console experience on July 31, 2026**. As of August 2026, the RDS console experience has moved to **CloudWatch Database Insights**. AWS says the Performance Insights API remains available, while Database Insights now provides the monitoring UI and Standard/Advanced modes. ([AWS Documentation][19])

So if an older course tells you:

```text
Open RDS
→ Performance Insights tab
```

the modern mental model is:

```text
CloudWatch
   │
   ▼
Database Insights
```

---

# 28. CloudWatch Metrics vs Database Insights vs Enhanced Monitoring

These are different layers.

```text
CloudWatch RDS Metrics
=
resource/instance health
```

```text
Database Insights
=
database load + SQL + waits
```

```text
Enhanced Monitoring
=
OS/process-level telemetry
```

Together:

```text
              APPLICATION SLOW
                     │
        ┌────────────┼─────────────┐
        ▼            ▼             ▼
   CloudWatch    DB Insights    Enhanced Monitoring
      │              │                │
 CPU/memory       SQL/waits        OS processes
 storage          DB load          per-process CPU
 connections      blockers         system detail
```

---

# 29. CloudWatch Metrics You Must Know

AWS publishes RDS metrics in the `AWS/RDS` namespace. Important operational metrics include: ([AWS Documentation][20])

| Metric                               | What you ask                     |
| ------------------------------------ | -------------------------------- |
| `CPUUtilization`                     | Is compute saturated?            |
| `FreeableMemory`                     | Is memory pressure rising?       |
| `SwapUsage`                          | Is system using swap?            |
| `FreeStorageSpace`                   | Is normal RDS storage filling?   |
| `DatabaseConnections`                | Are connection counts exploding? |
| `ReadIOPS` / `WriteIOPS`             | How much I/O?                    |
| `ReadLatency` / `WriteLatency`       | Is storage slow?                 |
| `ReadThroughput` / `WriteThroughput` | How much data throughput?        |
| `DiskQueueDepth`                     | Is I/O queueing?                 |
| `NetworkReceiveThroughput`           | Incoming network volume          |
| `NetworkTransmitThroughput`          | Outgoing network volume          |
| `ReplicaLag`                         | Is asynchronous replica behind?  |

Do not monitor one metric in isolation.

---

# 30. Example: CPU 100%

Application latency rises.

CloudWatch:

```text
CPUUtilization
≈ 100%
```

First question:

```text
WHY is CPU high?
```

Possibilities:

```text
bad query
full-table scan
missing index
too much concurrency
query-plan regression
autovacuum work
connection storm
legitimate traffic spike
```

Don't immediately say:

```text
db.r7g.large
→ db.r7g.16xlarge
```

Scaling can hide inefficient SQL temporarily while increasing cost.

---

# 31. Database Insights — DB Load

CloudWatch Database Insights uses:

```text
DB Load
```

as a key database activity metric. AWS defines DB Load in terms of active database sessions and collects it every second. ([AWS Documentation][21])

Conceptually:

```text
vCPU = 4

DB Load = 1
→ comfortable

DB Load = 4
→ roughly all CPUs could be busy

DB Load = 20
→ many sessions waiting/running
```

But the most useful question is:

```text
WHAT ARE THOSE SESSIONS WAITING ON?
```

---

# 32. Wait Events

Database sessions might be waiting on:

```text
CPU

I/O

locks

network

WAL/log flush

buffer contention

transaction synchronization
```

Database Insights can slice DB Load by dimensions such as:

```text
SQL
waits
user
database
host
blocking SQL
blocking session
```

where supported. ([AWS Documentation][21])

This transforms:

```text
"DB is slow"
```

into:

```text
"80% of DB load is blocked
on one transaction holding a lock."
```

That's actionable.

---

# 33. Top SQL

A common workflow:

```text
DB Load high
    │
    ▼
Database Insights
    │
    ▼
Top SQL
    │
    ▼
Which query causes load?
```

Example:

```sql
SELECT *
FROM orders
WHERE LOWER(customer_email) = LOWER($1);
```

If it dominates DB Load:

```text
investigate execution plan
index strategy
query frequency
```

rather than changing security groups.

---

# 34. Execution Plans

Database Insights Advanced mode can expose execution-plan analysis for supported database engines/configurations. ([AWS Documentation][22])

Why does this matter?

Consider:

```sql
SELECT *
FROM orders
WHERE order_id = 12345;
```

Good plan:

```text
Index Scan
```

Bad plan on 800 million rows:

```text
Sequential Scan
```

A query can look harmless syntactically but produce catastrophic work because of its execution plan.

---

# 35. PostgreSQL `EXPLAIN`

Inside PostgreSQL:

```sql
EXPLAIN
SELECT *
FROM orders
WHERE customer_id = 123;
```

For real runtime stats in a safe non-production/test context:

```sql
EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE customer_id = 123;
```

Be careful:

```text
EXPLAIN ANALYZE
```

**executes the query**, so don't casually run it against destructive statements or extremely expensive production workloads.

---

# 36. Lock Contention

Imagine:

```text
Transaction A

BEGIN;
UPDATE accounts
SET balance = ...
WHERE id = 100;

-- transaction remains open
```

Transaction B:

```sql
UPDATE accounts
SET balance = ...
WHERE id = 100;
```

B waits.

Then:

```text
B blocks C
C blocks D
D blocks E
```

One badly managed transaction can create huge application latency without CPU reaching 100%.

Database Insights Advanced mode supports lock analysis and lock trees for supported engines, including Aurora PostgreSQL. ([AWS Documentation][23])

---

# 37. PostgreSQL Active Session Inspection

Useful query:

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    wait_event_type,
    wait_event,
    query_start,
    xact_start,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_start;
```

Look for:

```text
long-running queries
idle in transaction
lock waits
old transactions
unexpected application clients
```

This is often more useful than staring only at `CPUUtilization`.

---

# 38. Find Blocked PostgreSQL Sessions

A starting point:

```sql
SELECT
    pid,
    pg_blocking_pids(pid) AS blocked_by,
    query,
    wait_event_type,
    wait_event
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

Now you can distinguish:

```text
slow because database is computing
```

from:

```text
slow because database is waiting
```

Those require very different fixes.

---

# 39. Long Transactions Are Dangerous

An application can do:

```text
BEGIN
   ↓
UPDATE
   ↓
call external API
   ↓
wait 40 seconds
   ↓
COMMIT
```

while holding locks for the entire external API call.

Better application design often becomes:

```text
perform slow external work
      │
      ▼
open DB transaction
      │
      ▼
make required changes
      │
      ▼
commit quickly
```

Transactions should generally remain as short as business correctness allows.

---

# 40. Deadlocks

A deadlock looks like:

```text
Transaction A

locks Row 1
wants Row 2


Transaction B

locks Row 2
wants Row 1
```

Diagram:

```text
A
│
needs B's lock
│
▼
B
│
needs A's lock
│
└───────► A
```

The database eventually detects the cycle and aborts one participant.

Application code must be prepared to retry appropriate transactions rather than assuming every SQL transaction either immediately succeeds or represents a permanent business failure.

---

# 41. Connection Exhaustion

Symptom:

```text
FATAL:
remaining connection slots are reserved...
```

or:

```text
too many connections
```

Look at:

```text
DatabaseConnections
```

and inspect application pool design. AWS lists DB Connections as one of the core operational RDS metrics. ([AWS Documentation][24])

Potential causes:

```text
connection leak

pool too large

too many application instances

Lambda burst

connections not returned to pool

idle sessions

connection storm
```

---

# 42. Pool Mathematics

Suppose:

```text
ASG max:
50 EC2 instances

Pool per instance:
100 DB connections
```

Worst-case:

```text
50 × 100
=
5,000 DB connections
```

If PostgreSQL safely supports:

```text
500
```

for your chosen instance/workload:

```text
you designed an outage.
```

Always calculate:

```text
maximum application instances
×
maximum pool per instance
```

before deploying.

---

# 43. RDS Proxy

For large numbers of short-lived or bursty connections:

```text
Application
    │
 many connections
    ▼
 RDS Proxy
    │
 pooled DB connections
    ▼
 RDS / Aurora
```

RDS Proxy pools and reuses DB connections and is particularly useful for workloads such as Lambda that can create rapid connection surges. ([AWS Documentation][25])

But Proxy doesn't fix:

```text
bad queries
missing indexes
huge transactions
```

It solves primarily a **connection-management** problem.

---

# 44. Freeable Memory

If:

```text
FreeableMemory
```

continually falls and:

```text
SwapUsage
```

grows significantly, investigate memory pressure. AWS recommends monitoring both metrics as part of RDS operational health. ([AWS Documentation][24])

Potential causes:

```text
too many connections
large working set
sort/hash memory
buffer configuration
instance too small
query concurrency
```

Don't read:

```text
FreeableMemory low
```

as automatically:

```text
memory leak
```

Databases intentionally use RAM aggressively for caching.

Look at workload behavior and trends.

---

# 45. Storage I/O Troubleshooting

Suppose:

```text
CPU = 25%

DB Load high

ReadLatency high

DiskQueueDepth high
```

Likely direction:

```text
storage / I/O pressure
```

not:

```text
CPU bottleneck
```

Check:

```text
ReadIOPS
WriteIOPS
ReadLatency
WriteLatency
ReadThroughput
WriteThroughput
DiskQueueDepth
```

AWS exposes all of these as core RDS operational metrics. ([AWS Documentation][24])

---

# 46. Database Slow Troubleshooting Matrix

| Observation                 | First investigation                       |
| --------------------------- | ----------------------------------------- |
| CPU high                    | Top SQL, query plans, concurrency         |
| CPU low + DB load high      | waits/locks/I/O                           |
| FreeableMemory falling      | pool size, working set, queries           |
| Connections high            | pool/leak/scaling/RDS Proxy               |
| ReadLatency high            | storage/read pattern/query plan           |
| WriteLatency high           | write I/O/checkpoints/storage             |
| DiskQueueDepth high         | I/O saturation                            |
| ReplicaLag high             | replica replay/write load/query conflicts |
| Network throughput maxed    | instance/network/client behavior          |
| One query dominates DB Load | index/query-plan optimization             |

The right fix depends on the **wait resource**, not merely the application symptom.

---

# 47. Enhanced Monitoring

Enhanced Monitoring exposes operating-system-level metrics for RDS and can collect at:

```text
1
5
10
15
30
60
seconds
```

intervals. The underlying metrics are sent to CloudWatch Logs; when configured at one-second granularity, one-second data can be retrieved there even though the RDS console refreshes more slowly. ([AWS Documentation][26])

This is useful when:

```text
CloudWatch says CPU 90%
```

and you want deeper insight into:

```text
which OS/database process
is consuming resources.
```

---

# 48. Why CloudWatch and Enhanced Monitoring Can Differ

CloudWatch metrics reflect RDS service/instance metrics.

Enhanced Monitoring observes metrics from the DB instance operating-system environment at finer granularity.

Therefore numbers can differ slightly because:

```text
measurement source
collection interval
aggregation
```

are different.

That's expected.

---

# 49. Replica Lag

Standard RDS read replicas are asynchronous.

For MySQL read replicas, AWS exposes:

```text
ReplicaLag
```

in CloudWatch, based on the replica's seconds-behind-primary status. ([AWS Documentation][27])

Conceptually:

```text
Primary
  │
  │ writes 10,000 changes/sec
  ▼
Replica
  │
  │ applies only 7,000/sec
  ▼

lag grows
```

---

# 50. Causes of Replica Lag

Common categories include:

```text
heavy source write load

under-sized replica

slow replica storage

long-running queries/conflicts

network/cross-Region delay

replication errors
```

Do not immediately reboot the replica.

First ask:

```text
Is replication receiving changes?

Is it applying them?

Is the replica compute saturated?

Is storage constrained?

Are queries blocking replay?
```

---

# 51. Replica Lag + Application Consistency

Suppose:

```text
Writer:
order = PAID
```

Replica still has:

```text
order = PENDING
```

for a moment.

User pays, then immediately loads:

```text
/orders/123
```

from a replica.

They see:

```text
PENDING
```

The architecture problem isn't necessarily database failure.

It's:

```text
consistency-sensitive read
was routed to asynchronous replica
```

Route read-after-write-sensitive operations appropriately.

---

# 52. Monitoring Aurora Readers

Aurora's shared-storage architecture usually produces lower reader lag than conventional engine-level read replicas, but reader delay can still occur under workload pressure. Aurora exposes replication-related metrics and internal status views for diagnosing those cases. ([AWS Documentation][28])

Again:

```text
low-lag architecture
≠
zero-lag guarantee.
```

---

# 53. Failover Testing

A production HA architecture hasn't been proven until you test:

```text
Can the DB fail over?

AND

Can the APPLICATION survive it?
```

AWS specifically recommends testing failover duration because it varies with engine, instance class, workload, and storage conditions. ([AWS Documentation][24])

For Aurora, you can deliberately trigger cluster failover using the RDS failover operation. ([AWS Documentation][29])

Example:

```bash
aws rds failover-db-cluster \
  --db-cluster-identifier prod-aurora \
  --region ap-south-1
```

Use this only in a controlled environment or planned resilience test.

---

# 54. What You Measure During a Failover Game Day

Record:

```text
T0
failover initiated

T1
old connections fail

T2
reader promoted

T3
cluster/RDS endpoint resolves new writer

T4
application reconnects

T5
health checks recover

T6
user traffic normal
```

Then calculate:

```text
actual DB failover duration

actual application outage

error rate

transaction impact
```

The application outage can be longer than the raw database failover if your application has:

```text
bad DNS caching
slow retry
huge connection timeout
no exponential backoff
```

---

# 55. Application Retry Pattern

Bad:

```javascript
db.query(...);
```

If it fails:

```text
crash process
```

Better architecture:

```text
transient DB error
      │
      ▼
classify error
      │
      ▼
short bounded retry
      │
      ▼
reconnect if required
```

But retries must be carefully designed.

Never blindly retry:

```text
non-idempotent transaction
```

without understanding whether the database already committed it.

---

# 56. RDS Events

RDS generates events for categories including:

```text
failover
failure
maintenance
recovery
read replicas
backups
configuration changes
```

and can deliver notifications through SNS. RDS events can also be matched with EventBridge for automated workflows. ([AWS Documentation][30])

Architecture:

```text
RDS Event
    │
    ▼
EventBridge / SNS
    │
    ├── Slack/incident path
    ├── Lambda automation
    └── alerting
```

This should complement metrics-based alerts.

---

# 57. PostgreSQL Slow-Query Logging

For RDS PostgreSQL, custom parameter groups can control PostgreSQL logging parameters. ([AWS Documentation][15])

A useful pattern is configuring an appropriate:

```text
log_min_duration_statement
```

threshold so expensive statements are logged.

For example, conceptually:

```text
log queries
taking > 1000 ms
```

rather than:

```text
log absolutely every SQL statement forever
```

which can create unnecessary logging volume and overhead.

---

# 58. Database Logs

Depending on engine/configuration, publish useful database logs to CloudWatch Logs, such as:

```text
PostgreSQL logs
MySQL error logs
slow query logs
audit logs
upgrade logs
```

Then your investigation workflow becomes:

```text
CloudWatch metric spike
       │
       ▼
Database Insights
       │
       ▼
DB logs
       │
       ▼
specific query/error
```

rather than SSHing to an RDS host—which managed RDS doesn't normally allow you to do.

---

# 59. Production Monitoring Layers

Memorize:

```text
LAYER 1
APPLICATION
────────────────
request latency
DB error rate
connection timeout
transaction failure


LAYER 2
DATABASE LOAD
────────────────
Database Insights
Top SQL
waits
blocking sessions


LAYER 3
RDS RESOURCE
────────────────
CPU
memory
connections
I/O
network
storage


LAYER 4
DATABASE ENGINE
────────────────
SQL
EXPLAIN
locks
transactions
logs


LAYER 5
AWS CONTROL PLANE
────────────────
RDS events
failover
maintenance
parameter changes
KMS
IAM
```

A good incident investigation moves between these layers.

---

# 60. Complete “Database Is Slow” Runbook

When PagerDuty/monitoring says:

```text
API latency = 8 seconds
```

use this order:

```text
1. Is database really the dependency causing latency?

           ↓

2. DB Load high?

           ↓

3. CPU saturated?

           ↓

4. Connections near capacity?

           ↓

5. Memory pressure?

           ↓

6. Storage latency / queue depth?

           ↓

7. Top SQL?

           ↓

8. Wait events?

           ↓

9. Locks/blockers?

           ↓

10. Replica lag?

           ↓

11. Recent deployment/schema change?

           ↓

12. Recent parameter/maintenance change?
```

This avoids random infrastructure modifications.

---

# 61. Scenario — CPU 95%, One SQL Is 70% of DB Load

Correct first thought:

```text
optimize that SQL
```

Investigate:

```text
execution plan
missing index
cardinality
statistics
join strategy
query frequency
```

Incorrect first thought:

```text
triple the DB size forever.
```

Scaling might be part of the answer, but first understand the work.

---

# 62. Scenario — CPU 20%, DB Load Huge

Database Insights shows:

```text
wait = lock
```

The DB isn't slow because it lacks CPU.

It is slow because sessions are:

```text
WAITING FOR EACH OTHER
```

Find:

```text
blocking session
blocking SQL
long-running transaction
```

Database Insights Advanced mode provides blocking/lock analysis for supported engines. ([AWS Documentation][23])

---

# 63. Scenario — App Cannot Connect

Error:

```text
Connection timed out
```

Start:

```text
NETWORK
```

Check:

```text
correct RDS endpoint?
correct port?
DB status available?
App-SG outbound?
DB-SG inbound from App-SG?
route/NACL?
DNS?
```

Do **not** start by rotating database passwords.

Timeout normally points first to connectivity.

---

# 64. Scenario — `password authentication failed`

Network worked.

The client reached PostgreSQL.

Now investigate:

```text
username
password
secret version
secret rotation
IAM DB auth
database role
```

Don't change:

```text
security group 5432
```

because the server already responded.

---

# 65. Scenario — TLS Certificate Failure

Symptom:

```text
certificate verify failed
```

Check:

```text
correct current RDS CA bundle?
endpoint hostname?
sslmode?
certificate trust?
custom DNS?
```

When using PostgreSQL `verify-full`, hostname validation is intentional and protects against connecting to the wrong server. ([AWS Documentation][31])

Don't “fix” production by automatically switching to:

```text
sslmode=disable
```

---

# 66. Scenario — Application Broke After Secret Rotation

Check:

```text
Does application cache secret forever?

Does it re-fetch after authentication failure?

Did database password rotate successfully?

Is connection pool holding old credentials?

Is rotation Lambda succeeding?
```

Secret rotation is only useful if clients can operationally tolerate credential changes.

---

# 67. Scenario — Parameter Change Not Taking Effect

RDS says:

```text
pending-reboot
```

Check whether the parameter is:

```text
static
```

If yes:

```text
controlled reboot required
```

Dynamic parameters don't require the same restart behavior. ([AWS Documentation][14])

---

# 68. Scenario — ReplicaLag Suddenly Growing

Investigate:

```text
Primary writes increased?
      │
      ▼
Replica CPU?
      │
      ▼
Replica memory?
      │
      ▼
Storage latency?
      │
      ▼
Long read workload?
      │
      ▼
Replication errors?
      │
      ▼
Cross-Region network?
```

Do not use a severely lagging replica for consistency-sensitive traffic.

---

# 69. Scenario — RDS Storage Almost Full

For normal RDS, investigate:

```text
FreeStorageSpace
```

plus:

```text
table/database growth
logs
temporary files
retention
unexpected ingestion
```

RDS storage autoscaling can help prevent storage exhaustion, but it doesn't answer why data grew unexpectedly. AWS recommends monitoring free storage as part of core RDS health. ([AWS Documentation][24])

---

# 70. Scenario — Aurora Storage Alarm

Aurora storage itself grows automatically up to the engine/version limit, so the operational concern is more often:

```text
approaching cluster-volume limit
```

rather than:

```text
forgot to manually increase 500 GiB → 600 GiB
```

Aurora's storage model is different from allocated-storage RDS DB instances.

---

# 71. Terraform Production Baseline — RDS PostgreSQL

Example:

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "prod-postgres"

  engine         = "postgres"
  engine_version = var.postgres_version
  instance_class = var.db_instance_class

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"

  db_name  = "appdb"
  username = var.master_username

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.database.name

  vpc_security_group_ids = [
    aws_security_group.database.id
  ]

  publicly_accessible = false

  multi_az = true

  backup_retention_period = 14

  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn

  deletion_protection = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "prod-postgres-final"

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = [
    "postgresql"
  ]

  auto_minor_version_upgrade = true

  apply_immediately = false

  tags = {
    Environment = "production"
  }
}
```

The exact engine versions, log-export options, monitoring support, and instance classes should always be verified for the selected engine/Region before deployment because these are version-dependent AWS capabilities. ([AWS Documentation][20])

---

# 72. Database Security Group

```hcl
resource "aws_security_group" "database" {
  name   = "prod-db-sg"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_app" {
  security_group_id = aws_security_group.database.id

  referenced_security_group_id =
    aws_security_group.app.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}
```

Architecture:

```text
App-SG
   │
   │ TCP 5432
   ▼
DB-SG
```

not:

```text
0.0.0.0/0
     │
     ▼
PostgreSQL
```

---

# 73. Terraform Parameter Group

```hcl
resource "aws_db_parameter_group" "postgres" {
  name   = "prod-postgres-params"
  family = var.parameter_group_family

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "max_connections"
    value        = "500"
    apply_method = "pending-reboot"
  }
}
```

Don't copy these numbers blindly.

For example:

```text
max_connections = 500
```

must fit:

```text
instance memory
application pool design
RDS Proxy design
query concurrency
```

The example demonstrates **configuration structure**, not a universal performance recommendation.

---

# 74. Production Alert Set

A useful starting monitoring set:

```text
RDS / Aurora

CPUUtilization
FreeableMemory
DatabaseConnections
ReadLatency
WriteLatency
ReadIOPS
WriteIOPS
DiskQueueDepth
FreeStorageSpace      ← normal RDS
ReplicaLag            ← replicas where applicable
DB Load
```

and alert on:

```text
failover events
maintenance failures
backup failures
replication failures
storage pressure
connection pressure
```

RDS metrics and event subscriptions are designed specifically for these monitoring workflows. ([AWS Documentation][20])

Thresholds should come from:

```text
baseline
instance size
SLO
workload
```

rather than one universal percentage.

---

# 75. Example Incident Dashboard

```text
                    DATABASE HEALTH

 Application
 ───────────────────────────────
 p95 API latency
 DB error %
 timeout count

 Database Insights
 ───────────────────────────────
 DB Load
 Top SQL
 Wait events
 Blocking SQL

 CloudWatch
 ───────────────────────────────
 CPU
 FreeableMemory
 Connections
 Read/Write Latency
 IOPS
 Queue depth
 Replica lag

 Events
 ───────────────────────────────
 failover
 maintenance
 reboot
 parameter change
 backup
```

This is far more useful than a dashboard containing:

```text
CPU only.
```

---

# 76. Production Game Day

For a non-production clone/test environment:

```text
1. Run traffic.

2. Record baseline.

3. Trigger Aurora failover.

4. Measure application errors.

5. Measure reconnection time.

6. Confirm writer endpoint moves.

7. Confirm transactions recover correctly.

8. Test reader connections.

9. Review RDS events.

10. Review Database Insights.

11. Verify alerts fired.

12. Document actual RTO.
```

AWS specifically recommends testing failover behavior and application recovery rather than assuming Multi-AZ alone proves resilience. ([AWS Documentation][24])

---

# 77. The Database Troubleshooting Decision Tree

Memorize this:

```text
                       DB INCIDENT
                           │
                           ▼
                  Can app CONNECT?
                    │            │
                   NO           YES
                    │            │
                    ▼            ▼
              NETWORK/AUTH     SLOW/ERROR
                    │            │
           ┌────────┼───┐        ▼
           ▼        ▼   ▼      DB LOAD?
          DNS      SG  TLS      │
          Auth     KMS Secret   │
                                ▼
                         WHICH WAIT?
                ┌───────────────┼──────────────┐
                ▼               ▼              ▼
               CPU             I/O            LOCK
                │               │              │
                ▼               ▼              ▼
             Top SQL       latency/IOPS     blockers
                │               │              │
                ▼               ▼              ▼
              PLAN          storage         transaction
                │
                ▼
             INDEX / SQL
```

Then independently ask:

```text
Connections?
Replica lag?
Recent deploy?
Recent maintenance?
Data loss?
```

---

# 78. Never-Forget Symptom Mapping

```text
TIMEOUT
=
start with network
```

```text
AUTHENTICATION FAILED
=
credentials/IAM
```

```text
CONNECTION LIMIT
=
pool/concurrency
```

```text
HIGH CPU
=
find expensive work
```

```text
HIGH DB LOAD + LOW CPU
=
find waits
```

```text
HIGH I/O LATENCY
=
storage/query access pattern
```

```text
HIGH REPLICA LAG
=
replication pipeline cannot keep up
```

```text
BAD DATA
=
PITR / backup
```

```text
pending-reboot
=
static parameter/config change
```

---

# 79. Twenty Production Rules to Burn Into Memory

```text
1. Multi-AZ is HA, not historical backup.

2. Automated backup retention defines your PITR window.

3. PITR restores into a new DB resource.

4. Manual snapshots are useful release/migration checkpoints.

5. Cross-Region backup replication improves DR protection.

6. Encryption at rest uses KMS.

7. Encryption doesn't protect against DROP TABLE.

8. Use TLS for database connections.

9. Never hardcode database passwords.

10. Secrets Manager can manage/rotate DB credentials.

11. IAM DB auth uses short-lived 15-minute connection tokens.

12. Static parameter changes can require reboot.

13. Apply immediately can cause an outage.

14. As of August 2026, use CloudWatch Database Insights
    rather than the retired Performance Insights console.

15. CloudWatch tells you resource pressure.

16. Database Insights tells you DB load, SQL and waits.

17. Enhanced Monitoring tells you OS/process behavior.

18. A slow database isn't automatically an undersized database.

19. Test failover with the application, not only RDS.

20. HA + backup + security + observability
    must all be designed together.
```

The most important troubleshooting rule is:

```text
DON'T SCALE
UNTIL YOU KNOW
WHAT RESOURCE IS SATURATED
OR WHAT THE DATABASE IS WAITING FOR.
```

---

# ✅ Lesson 28 Part 3 Complete

We have now covered:

```text
✓ automated backups
✓ backup retention
✓ backup windows
✓ PITR
✓ snapshots
✓ RPO/RTO
✓ cross-Region backup
✓ snapshot sharing
✓ encryption
✓ KMS
✓ encrypted snapshot migration
✓ TLS
✓ RDS CA trust
✓ Secrets Manager
✓ secret rotation
✓ IAM DB authentication
✓ 15-minute auth tokens
✓ RDS Proxy authentication
✓ parameter groups
✓ static vs dynamic parameters
✓ pending-reboot
✓ maintenance windows
✓ Apply immediately
✓ minor / major upgrades
✓ Blue/Green
✓ 2026 Performance Insights migration
✓ CloudWatch Database Insights
✓ DB Load
✓ waits
✓ Top SQL
✓ execution plans
✓ CloudWatch RDS metrics
✓ Enhanced Monitoring
✓ locks
✓ blocked sessions
✓ deadlocks
✓ connection exhaustion
✓ pool mathematics
✓ memory pressure
✓ I/O pressure
✓ replica lag
✓ failover testing
✓ RDS events
✓ PostgreSQL diagnostics
✓ Terraform production baseline
✓ complete incident runbook
```

# Next — Lesson 28 Part 4

## **DynamoDB — NoSQL Architecture from First Principles**

We'll now compare our relational model:

```text
RDS / Aurora

table
relations
joins
transactions
SQL
schema
indexes
writer/readers
```

with DynamoDB's completely different model:

```text
                         DYNAMODB
                             │
                    ACCESS PATTERNS FIRST
                             │
                             ▼
                           TABLE
                             │
                   ┌─────────┴─────────┐
                   ▼                   ▼
             Partition Key         Sort Key
                   │                   │
                   └─────────┬─────────┘
                             ▼
                          ITEM
                             │
                  automatic partitioning
                             │
                             ▼
                     massive scale
```

We'll cover **partition keys, sort keys, items, Query vs Scan, hot partitions, RCUs/WCUs, on-demand vs provisioned capacity, GSIs/LSIs, conditional writes, optimistic locking, transactions, TTL, Streams, Global Tables, DAX, DynamoDB Accelerator, point-in-time recovery, backups, encryption, IAM, single-table design, Terraform, and real SAA-C03 architecture questions**.

The biggest conceptual shift will be:

> **In SQL, you often design the schema and then query it flexibly. In DynamoDB, you should understand the application's access patterns before designing the keys and indexes.**

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Backups.html?utm_source=chatgpt.com "Overview of backing up and restoring an Aurora DB cluster"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.BackupRetention.html?utm_source=chatgpt.com "Backup retention period"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.Maintenance.html?utm_source=chatgpt.com "Maintaining a DB instance - AWS Documentation - Amazon.com"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-pitr.html?utm_source=chatgpt.com "Restoring a DB cluster to a specified time - Amazon Aurora"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ShareSnapshot.html?utm_source=chatgpt.com "Sharing a DB snapshot for Amazon RDS - AWS Documentation"
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReplicateBackups.html?utm_source=chatgpt.com "Replicating automated backups to another AWS Region"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/share-encrypted-snapshot.html?utm_source=chatgpt.com "Sharing encrypted snapshots for Amazon RDS"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.Encryption.html?utm_source=chatgpt.com "Encrypting Amazon RDS resources - AWS Documentation"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html?utm_source=chatgpt.com "Using SSL/TLS to encrypt a connection to a DB instance or ..."
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html?utm_source=chatgpt.com "Password management with Amazon RDS and AWS Secrets ..."
[11]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_turn-on-for-db.html?utm_source=chatgpt.com "Set up automatic rotation for Amazon RDS, Amazon Aurora ..."
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html?utm_source=chatgpt.com "IAM database authentication for MariaDB, MySQL, and ..."
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-iam-setup.html?utm_source=chatgpt.com "Configuring IAM authentication for RDS Proxy"
[14]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.Modifying.html?utm_source=chatgpt.com "Modifying parameters in a DB parameter group in Amazon RDS"
[15]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html?utm_source=chatgpt.com "Working with parameters on your RDS for PostgreSQL DB ..."
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.Upgrading.html?utm_source=chatgpt.com "Upgrading a DB instance engine version - AWS Documentation"
[17]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html?utm_source=chatgpt.com "Upgrades of the RDS for PostgreSQL DB engine"
[18]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-switching.html?utm_source=chatgpt.com "Switching a blue/green deployment in Amazon RDS"
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.Overview.html?utm_source=chatgpt.com "Overview of Performance Insights on Amazon RDS"
[20]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html?utm_source=chatgpt.com "Amazon CloudWatch metrics for Amazon RDS"
[21]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights-Database-Instance-Dashboard.html?utm_source=chatgpt.com "Viewing the Database Instance Dashboard for CloudWatch ..."
[22]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights-Execution-Plans.html?utm_source=chatgpt.com "Analyzing execution plans with CloudWatch Database Insights"
[23]: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights-Lock-Analysis.html?utm_source=chatgpt.com "Analyzing lock trees for Amazon Aurora PostgreSQL and ..."
[24]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html?utm_source=chatgpt.com "Best practices for Amazon RDS"
[25]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html?utm_source=chatgpt.com "Amazon RDS Proxy - Amazon Relational Database Service"
[26]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.OS.Enabling.html?utm_source=chatgpt.com "Setting up and enabling Enhanced Monitoring"
[27]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_MySQL.Replication.ReadReplicas.Monitor.html?utm_source=chatgpt.com "Monitoring replication lag for MySQL read replicas"
[28]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora_replica_status.html?utm_source=chatgpt.com "aurora_replica_status - Amazon Aurora"
[29]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/AuroraPostgreSQL.BestPractices.FastFailover.html?utm_source=chatgpt.com "Fast failover with Amazon Aurora PostgreSQL"
[30]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Events.html?utm_source=chatgpt.com "Working with Amazon RDS event notification"
[31]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.AWSCLI.PostgreSQL.html?utm_source=chatgpt.com "Connecting to your DB instance using IAM authentication ..."
