# AWS Masterclass — Phase 3

# Lesson 25: Amazon RDS Production Architecture

## 1. Lesson objective

In this lesson, you will learn how to design and operate a production relational database using Amazon RDS.

We will cover:

* Amazon RDS fundamentals.
* RDS compared with databases installed on EC2.
* Single-AZ and Multi-AZ deployments.
* Multi-AZ DB instances versus Multi-AZ DB clusters.
* Read replicas and replication lag.
* Automatic failover.
* Automated backups, snapshots and point-in-time recovery.
* Database subnet groups and security groups.
* Encryption, authentication and secret management.
* RDS Proxy and connection pooling.
* Storage types and storage autoscaling.
* Monitoring and database troubleshooting.
* Terraform implementation.
* Production incidents, validation and interview questions.

---

# 2. Production architecture

A common production architecture looks like this:

```text
                            Internet
                                |
                         Route 53 / DNS
                                |
                           CloudFront
                                |
                    Application Load Balancer
                       /                  \
              Private App Subnet A   Private App Subnet B
                     EC2                  EC2
                       \                  /
                        \                /
                           RDS Proxy
                               |
                    RDS writer endpoint
                               |
                ┌──────────────────────────┐
                │ Amazon RDS Multi-AZ      │
                │                          │
                │ Primary DB — AZ-A        │
                │ Standby DB — AZ-B        │
                └──────────────────────────┘
                               |
                    Automated backups
                               |
                         Backup storage
```

Important security rule:

```text
Internet
   ↓
ALB
   ↓
Application servers
   ↓
RDS

Internet ─────X─────> RDS
```

The database should normally be located in private subnets and should accept connections only from trusted application resources.

---

# 3. What is Amazon RDS?

Amazon RDS stands for:

```text
Amazon Relational Database Service
```

It is a managed service for operating relational database engines.

RDS manages many infrastructure-level database tasks such as:

* Provisioning.
* Infrastructure maintenance.
* Automated backups.
* Database software patching.
* Storage management.
* Monitoring integration.
* High-availability failover.
* Replacing failed database infrastructure.

You remain responsible for:

* Database schema.
* Tables and indexes.
* SQL queries.
* Database users and privileges.
* Application connection management.
* Data correctness.
* Query optimisation.
* Capacity planning.
* Backup-retention requirements.
* Testing restores.
* Application-level retry logic.

AWS describes RDS as a managed relational database service that automates tasks such as provisioning, configuration, backups and patching. ([Amazon Web Services, Inc.][1])

## Mental model

```text
Amazon RDS manages the database infrastructure.

You manage the data, schema, queries and application behaviour.
```

---

# 4. RDS versus database on EC2

You can run PostgreSQL or MySQL in two major ways:

```text
Option 1: Install the database yourself on EC2
Option 2: Use Amazon RDS
```

## Database on EC2

You manage:

```text
EC2 operating system
Database installation
Database patching
Replication
Backups
Failover
Storage configuration
Monitoring agents
Database recovery
High-availability scripts
Security hardening
```

Advantages:

* Full operating-system access.
* Full database-engine control.
* Support for unusual extensions or custom configurations.
* Greater freedom for legacy requirements.

Disadvantages:

* More operational responsibility.
* You must design failover yourself.
* You must test replication and backups.
* More difficult patching.
* Greater risk of configuration drift.
* More DevOps and DBA effort.

## Amazon RDS

AWS manages:

```text
Underlying host
Database infrastructure
Automated backup mechanism
Multi-AZ replication infrastructure
Infrastructure failure detection
Managed failover
Engine maintenance automation
```

Advantages:

* Easier high availability.
* Managed backups.
* Managed patching.
* CloudWatch integration.
* Faster production setup.
* Less operational overhead.

Limitations:

* No normal operating-system access.
* Some database parameters are restricted.
* Some extensions or privileges may be unavailable.
* Certain maintenance decisions remain controlled by AWS.
* It can cost more than a self-managed EC2 database for some workloads.

## Decision guideline

Use RDS when:

```text
You need a normal relational database.
You prefer managed operations.
You need Multi-AZ availability.
You do not require operating-system-level access.
```

Consider EC2 when:

```text
You need root-level database control.
You require unsupported database plugins.
You have a complex legacy database.
You need a configuration that RDS doesn't permit.
```

---

# 5. Core RDS resources

A typical RDS deployment includes:

```text
DB instance or DB cluster
DB subnet group
Security group
Parameter group
Option group where applicable
KMS key
Backup configuration
Monitoring role
Secrets Manager secret
CloudWatch alarms
```

## DB instance

The compute and memory resource running the database engine.

Example:

```text
Engine:          PostgreSQL
Instance class:  db.m7g.large
Storage:         100 GiB gp3
Deployment:      Multi-AZ
```

## DB subnet group

A collection of subnets where RDS is allowed to place database resources.

## Parameter group

A managed collection of database-engine configuration settings.

Examples:

```text
max_connections
log_statement
slow_query_log
work_mem
shared_buffers
innodb_buffer_pool_size
```

## Option group

Used by some engines to enable additional database features.

## DB endpoint

A DNS hostname used by applications to connect to the database.

Example:

```text
production-db.abcdefghijkl.ap-south-1.rds.amazonaws.com
```

Applications should use the endpoint, not a database IP address.

---

# 6. Database subnet group

RDS needs a DB subnet group containing subnets from multiple Availability Zones.

Example:

```text
VPC: 10.0.0.0/16

Private DB Subnet A
10.0.21.0/24
ap-south-1a

Private DB Subnet B
10.0.22.0/24
ap-south-1b
```

Architecture:

```text
VPC
├── Public Subnet A
│   └── ALB
│
├── Public Subnet B
│   └── ALB
│
├── Private App Subnet A
│   └── EC2
│
├── Private App Subnet B
│   └── EC2
│
├── Private DB Subnet A
│   └── RDS primary or cluster member
│
└── Private DB Subnet B
    └── RDS standby or cluster member
```

Terraform:

```hcl
resource "aws_db_subnet_group" "database" {
  name = "${var.environment}-database-subnet-group"

  subnet_ids = [
    aws_subnet.private_db_a.id,
    aws_subnet.private_db_b.id
  ]

  tags = {
    Name        = "${var.environment}-database-subnet-group"
    Environment = var.environment
  }
}
```

---

# 7. Publicly accessible setting

RDS has a setting named:

```text
Publicly accessible
```

For a normal production application, use:

```hcl
publicly_accessible = false
```

This does not mean that network security is handled automatically. You still need:

* Private subnets.
* Correct route tables.
* Restrictive security groups.
* Controlled administrative access.
* No open database ports from the internet.

A public database with the following rule is dangerous:

```text
PostgreSQL port 5432 from 0.0.0.0/0
```

A better rule is:

```text
PostgreSQL port 5432 from application-security-group
```

---

# 8. RDS security-group design

Use different security groups for each layer.

## Application security group

```text
Name: application-sg

Inbound:
Application traffic from ALB security group

Outbound:
PostgreSQL 5432 to database security group
HTTPS 443 where required
```

## Database security group

```text
Name: database-sg

Inbound:
PostgreSQL 5432 from application-sg

Outbound:
Default or restricted according to architecture
```

Terraform example:

```hcl
resource "aws_security_group" "database" {
  name        = "${var.environment}-database-sg"
  description = "Allow database access from application servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application instances"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-database-sg"
  }
}
```

## Never-forget rule

```text
Do not trust an EC2 IP address when a security-group reference can be used.

Application SG → Database SG
```

EC2 private IP addresses may change when instances are replaced. Security-group relationships continue to work as fleet membership changes.

---

# 9. Single-AZ deployment

A Single-AZ RDS deployment has one database instance in one Availability Zone.

```text
Availability Zone A
┌──────────────────────────────┐
│ Primary RDS DB instance      │
│                              │
│ Reads + writes               │
└──────────────────────────────┘
```

Suitable for:

* Development.
* Learning.
* Temporary testing.
* Noncritical internal workloads.
* Cost-sensitive environments that tolerate downtime.

Risks:

```text
Host failure
AZ disruption
Storage problem
Maintenance reboot
Database recovery event
```

If the instance becomes unavailable, the application remains unavailable until the database recovers or is restored.

Single-AZ should not normally be the default for an important production system.

---

# 10. Multi-AZ DB instance deployment

A traditional Multi-AZ DB instance deployment contains:

```text
One primary DB instance
One synchronous standby DB instance
```

Architecture:

```text
Availability Zone A                 Availability Zone B

┌─────────────────────┐           ┌─────────────────────┐
│ Primary DB          │           │ Standby DB          │
│                     │ Sync      │                     │
│ Reads and writes    │──────────>│ Failover only       │
│ Application traffic│ replication│ No read traffic     │
└─────────────────────┘           └─────────────────────┘
```

The standby exists for high availability.

It is not a normal read replica.

In a traditional Multi-AZ DB instance deployment, the standby uses synchronous replication and does not serve read traffic. ([AWS Documentation][2])

## What Multi-AZ provides

* Automatic failover.
* Infrastructure redundancy.
* Availability Zone isolation.
* Reduced recovery time after infrastructure failure.
* Managed standby replication.

## What Multi-AZ does not provide

* Automatic read scaling from the standby.
* Protection from application bugs.
* Protection from accidental `DELETE` statements.
* Protection from incorrect schema migrations.
* Protection from stolen database credentials.
* A replacement for backups.

### Critical distinction

```text
Multi-AZ protects availability.

Backups protect recoverability.
```

You usually need both.

---

# 11. How Multi-AZ failover works

The application connects using an RDS DNS endpoint:

```text
production-db.abcdefghijkl.ap-south-1.rds.amazonaws.com
```

Before failover:

```text
RDS endpoint
     ↓
Primary in AZ-A
```

After failover:

```text
RDS endpoint
     ↓
Former standby in AZ-B
```

AWS updates the DNS record so that the same database endpoint directs connections to the new primary.

Possible failover triggers include:

* Primary infrastructure failure.
* Availability Zone issue.
* Database instance failure.
* Storage problems.
* Some maintenance activities.
* A manually requested failover.

AWS states that traditional Multi-AZ DB instance failover typically takes approximately 60–120 seconds, although large transactions and recovery work can increase the duration. ([AWS Documentation][3])

## Application behaviour during failover

Existing connections may fail:

```text
connection reset
connection timeout
broken pipe
server closed the connection
```

Your application must:

1. Detect the failed connection.
2. Discard it from the pool.
3. Resolve the database endpoint again where necessary.
4. Reconnect.
5. Retry safe operations.
6. Avoid duplicating non-idempotent transactions.

Multi-AZ does not mean:

```text
The application will never see an error.
```

It means:

```text
AWS manages the infrastructure failover,
but the application must recover its connections.
```

---

# 12. Test your failover

A Multi-AZ configuration should be tested before production.

For a Multi-AZ DB instance, you can reboot and request a failover:

```bash
aws rds reboot-db-instance \
  --db-instance-identifier production-postgres \
  --force-failover \
  --region ap-south-1
```

AWS documents reboot-with-failover as a method for simulating a database instance failure and validating application behaviour. ([AWS Documentation][4])

During the test, observe:

```text
Application error rate
Database connection failures
Recovery time
DNS behaviour
Retry logic
Background jobs
Transaction failures
User-facing errors
```

Useful event command:

```bash
aws rds describe-events \
  --source-type db-instance \
  --source-identifier production-postgres \
  --duration 120 \
  --region ap-south-1
```

---

# 13. Multi-AZ DB cluster

Do not confuse a Multi-AZ DB cluster with the traditional Multi-AZ DB instance deployment.

A Multi-AZ DB cluster contains:

```text
One writer
Two readable standby instances
Three Availability Zones
```

Conceptual architecture:

```text
AZ-A                     AZ-B                     AZ-C

┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│ Writer       │        │ Reader       │        │ Reader       │
│ Reads/writes │───────>│ Read traffic │        │ Read traffic │
│              │───────>│ Failover     │        │ Failover     │
└──────────────┘        └──────────────┘        └──────────────┘
```

Unlike a single-standby Multi-AZ DB instance, the two standby instances in a Multi-AZ DB cluster can also serve read traffic. ([AWS Documentation][5])

Multi-AZ DB clusters generally provide:

* One writer endpoint.
* A reader endpoint.
* Two readable standbys.
* Faster failover than traditional single-standby Multi-AZ.
* Read scaling through cluster readers.

AWS states that Multi-AZ DB cluster failovers are typically under 35 seconds, although actual recovery depends on workload and replication conditions. ([AWS Documentation][6])

## Comparison

| Feature                 | Multi-AZ DB instance | Multi-AZ DB cluster                |
| ----------------------- | -------------------- | ---------------------------------- |
| Writer                  | One                  | One                                |
| Standby instances       | One                  | Two                                |
| Standby can serve reads | No                   | Yes                                |
| Availability Zones      | Two                  | Three                              |
| Typical failover        | 60–120 seconds       | Often under 35 seconds             |
| Primary purpose         | High availability    | High availability and read scaling |

---

# 14. Read replicas

A read replica is a copy of the source database primarily used to serve read traffic.

Architecture:

```text
                    Application
                   /           \
            Write requests    Read requests
                  |                 |
                  v                 v
             Primary DB       Read replica
                  |
                  └── asynchronous replication ──>
```

Common read-replica workloads:

* Reports.
* Dashboards.
* Analytics queries.
* Product catalogue reads.
* Search-supporting queries.
* Read-heavy API endpoints.
* Backup or migration workflows.

## Important property: asynchronous replication

Read replicas commonly use asynchronous replication.

This means:

```text
Write happens on primary
        ↓
Primary confirms transaction
        ↓
Change is later replayed on read replica
```

Therefore, a read replica may temporarily contain older data.

This delay is called:

```text
Replication lag
```

---

# 15. Read-after-write consistency problem

Imagine a user updates their profile:

```text
1. Application writes new name to primary.
2. Application immediately reads from replica.
3. Replica has not received the change yet.
4. User sees the old name.
```

This is expected behaviour with asynchronous replication.

Solutions include:

* Read from the primary after a write.
* Keep the session on the writer temporarily.
* Use replica lag-aware routing.
* Accept eventual consistency for noncritical screens.
* Avoid using replicas for operations requiring immediate consistency.

## Good workload for a replica

```text
Homepage product listing
Historical reports
Dashboard metrics
Monthly reports
```

## Risky workload for a lagging replica

```text
Payment confirmation
Account balance after transfer
Inventory confirmation
Security permission checks
Password-change verification
```

---

# 16. Multi-AZ standby versus read replica

This distinction is heavily tested in AWS certification exams.

| Feature                     | Multi-AZ standby                      | Read replica                      |
| --------------------------- | ------------------------------------- | --------------------------------- |
| Main purpose                | High availability                     | Read scaling                      |
| Replication                 | Synchronous in traditional Multi-AZ   | Generally asynchronous            |
| Serves application reads    | No                                    | Yes                               |
| Automatic failover          | Yes                                   | Not normally as source failover   |
| Can be promoted             | Managed automatically during failover | Can be manually promoted          |
| Protects against AZ failure | Yes                                   | Only if architected appropriately |
| Can be cross-Region         | Not traditional standby               | Common use case                   |

## Never-forget sentence

```text
Multi-AZ is for availability.

Read replicas are for read scalability.
```

A Multi-AZ source database can also have read replicas. ([AWS Documentation][7])

---

# 17. Read-replica promotion

A read replica can be promoted into an independent database.

Before promotion:

```text
Primary
   |
   └── replication ──> Read replica
```

After promotion:

```text
Primary                    Independent database

Replication stopped
```

Promotion use cases:

* Disaster recovery.
* Migration.
* Creating a separate reporting database.
* Breaking a replica into an independent environment.
* Regional recovery.
* Major testing activity.

When a read replica is promoted, replication stops and RDS reboots it before making it available as an independent DB instance. ([AWS Documentation][8])

Promotion is not the same as traditional automatic Multi-AZ failover.

---

# 18. Cross-Region read replicas

A read replica may be placed in another AWS Region for supported engines and configurations.

Example:

```text
Primary Region: ap-south-1
Mumbai

Read replica Region: ap-southeast-1
Singapore
```

Potential uses:

* Disaster-recovery preparation.
* Regional read traffic.
* Data migration.
* Lower-latency regional reporting.
* Recovery from a Regional incident.

Important considerations:

```text
Replication lag
Cross-Region data-transfer cost
KMS encryption configuration
Recovery runbooks
DNS switching
Application configuration
Data sovereignty
```

A cross-Region replica does not automatically give you a complete disaster-recovery process.

You still need to define:

```text
Who promotes the replica?
How is the application redirected?
How are secrets updated?
What is the accepted data-loss window?
How is the old primary handled?
How is replication rebuilt?
```

---

# 19. Scaling database compute

Application servers can usually scale horizontally:

```text
2 EC2 instances → 10 EC2 instances
```

A relational database often scales vertically first:

```text
db.t4g.medium
      ↓
db.m7g.large
      ↓
db.m7g.xlarge
```

Increasing the instance class can provide more:

* CPU.
* Memory.
* Network throughput.
* Storage bandwidth.
* Database connections.

## Vertical scaling risk

Changing the DB instance class can require an interruption or failover depending on the deployment and operation.

Plan compute changes during:

* Maintenance windows.
* Controlled production changes.
* Blue/green deployments.
* Tested failover procedures.

## Horizontal scaling

Read replicas provide horizontal scaling for reads:

```text
One writer
Three readers
```

However, normal RDS read replicas are not automatically added and removed by EC2 Auto Scaling. AWS documentation states that read replicas must be manually created or removed according to load requirements. ([AWS Documentation][9])

---

# 20. The database-connection problem

Suppose your Auto Scaling group contains:

```text
2 EC2 instances
50 connections per instance
```

Total potential connections:

```text
2 × 50 = 100
```

Traffic increases and the group scales to 20 instances:

```text
20 × 50 = 1,000 connections
```

But the database may safely support only 500 connections.

Result:

```text
too many connections
connection timeout
database memory pressure
application failures
```

Database connections consume memory, and the maximum varies according to the engine and database instance class. AWS warns that excessive connection configuration can create low-memory conditions. ([AWS Documentation][10])

## Wrong assumption

```text
More application servers always increase capacity.
```

## Correct understanding

```text
More application servers can overload the database.
```

---

# 21. RDS Proxy

RDS Proxy sits between the application and the database.

```text
Application servers
       |
       | Thousands of client connections
       v
    RDS Proxy
       |
       | Controlled reusable DB connections
       v
    Amazon RDS
```

RDS Proxy:

* Pools database connections.
* Reuses existing database connections.
* Reduces connection creation overhead.
* Protects the database from sudden connection surges.
* Helps applications recover from database failover.
* Allows limits to be placed on backend database connections.

AWS describes RDS Proxy as a managed connection pool that reuses database connections and helps protect databases from unpredictable connection surges. ([AWS Documentation][11])

## RDS Proxy is useful for

```text
AWS Lambda
EC2 Auto Scaling
ECS services
Kubernetes applications
Applications opening frequent short connections
Traffic with unpredictable bursts
```

## RDS Proxy is not

```text
A database
A read replica
A SQL query cache
A replacement for indexes
A replacement for query optimisation
```

---

# 22. Connection-pool design

Even with RDS Proxy, application-level connection behaviour matters.

Example:

```javascript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,

  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000
});
```

Do not blindly configure:

```javascript
max: 500
```

Pool size should be based on:

* Number of application instances.
* Database `max_connections`.
* Number of application processes per server.
* Background workers.
* Administrative connections.
* Monitoring connections.
* Failover and maintenance headroom.

Example calculation:

```text
Database safe connections:          600
Reserved for administration:         50
Reserved for maintenance:            50
Available to applications:          500

Maximum application instances:       20

Maximum pool per instance:
500 / 20 = 25 connections
```

Then use a more conservative value:

```text
15–20 connections per application instance
```

RDS Proxy provides settings such as maximum connection percentage, maximum idle connection percentage and connection-borrow timeout. ([AWS Documentation][12])

---

# 23. Backups are different from high availability

Consider an accidental command:

```sql
DELETE FROM customers;
```

Multi-AZ immediately replicates the operation:

```text
Primary: rows deleted
Standby: rows deleted
```

Multi-AZ cannot recover the deleted records.

You need:

* Automated backups.
* Point-in-time recovery.
* Manual snapshots.
* Logical backups where appropriate.
* Tested restoration procedures.

## Mental model

```text
Multi-AZ:
Keeps the database running during infrastructure failure.

Backup:
Lets you recover data from an earlier point.
```

---

# 24. Automated backups

When automated backups are enabled, RDS maintains backup data and transaction logs that support point-in-time recovery.

You configure a retention period.

For a DB instance:

```text
0–35 days
```

For a Multi-AZ DB cluster:

```text
1–35 days
```

Setting a DB instance retention period to `0` disables automated backups.

The default is:

```text
AWS Console: 7 days
AWS CLI/API: 1 day when not explicitly specified
```

Changing retention from `0` to a nonzero value, or from nonzero to `0`, causes an outage according to the RDS documentation. ([AWS Documentation][13])

## Production example

```hcl
backup_retention_period = 14
backup_window           = "18:30-19:00"
```

Remember that AWS backup windows are expressed in UTC.

For India:

```text
18:30 UTC = 00:00 IST next day
```

Select a backup window based on your workload’s quiet period.

---

# 25. Point-in-time recovery

Point-in-time recovery allows you to restore the database to a specific time within the backup-retention window.

Example:

```text
Accidental deletion: 10:35:00
Restore target:      10:34:50
```

Restoration does not normally rewind the existing production database in place.

Instead:

```text
Existing production DB
          |
          | restore
          v
New RDS DB instance
```

Then you validate the restored instance and decide how to recover:

* Point the application to the restored database.
* Export specific lost data.
* Compare old and restored databases.
* Merge recovered records.
* Perform controlled cutover.

RDS point-in-time recovery can restore to a selected point within the configured retention period and creates a restored database resource. ([AWS Documentation][14])

---

# 26. Manual snapshots

A manual snapshot is created explicitly by you or your automation.

```bash
aws rds create-db-snapshot \
  --db-instance-identifier production-postgres \
  --db-snapshot-identifier production-postgres-before-migration \
  --region ap-south-1
```

Use manual snapshots:

* Before major schema changes.
* Before database upgrades.
* Before risky application releases.
* Before data migrations.
* Before destructive maintenance.
* For long-term retention requirements.

Example naming convention:

```text
production-postgres-before-v2-8-migration-2026-07-27
```

## Snapshot warning

A snapshot is not useful until restore has been tested.

You should periodically perform:

```text
Snapshot restore
Database connection test
Row-count validation
Application smoke test
Recovery-time measurement
Cleanup
```

---

# 27. RPO and RTO

These are two fundamental disaster-recovery concepts.

## Recovery Point Objective — RPO

How much data loss can the business accept?

Example:

```text
RPO = 5 minutes
```

This means the business may accept losing at most approximately five minutes of recent data.

## Recovery Time Objective — RTO

How long can the system remain unavailable?

Example:

```text
RTO = 30 minutes
```

This means database service should be recovered within approximately 30 minutes.

## Mapping architecture to objectives

| Requirement                 | Possible design                        |
| --------------------------- | -------------------------------------- |
| Low RTO for AZ failure      | Multi-AZ                               |
| Read scaling                | Read replicas                          |
| Recovery from deletion      | PITR                                   |
| Regional recovery           | Cross-Region replica or copied backups |
| Connection-surge protection | RDS Proxy                              |
| Long-term recovery          | Manual snapshots or AWS Backup         |

---

# 28. Deletion protection

For production databases:

```hcl
deletion_protection = true
```

This helps prevent accidental deletion through ordinary RDS deletion workflows.

Also consider:

```hcl
skip_final_snapshot = false
```

Terraform example:

```hcl
deletion_protection       = true
skip_final_snapshot       = false
final_snapshot_identifier = "production-postgres-final"
```

## Important Terraform warning

The following is dangerous for production:

```hcl
skip_final_snapshot = true
deletion_protection = false
```

If the resource is destroyed, you may lose the database without a final snapshot.

---

# 29. Encryption at rest

RDS encryption at rest uses AWS KMS.

Encryption can cover resources associated with the encrypted database, including:

* Database storage.
* Automated backups.
* Snapshots.
* Read replicas created from the encrypted source where supported.
* Transaction logs.

Terraform:

```hcl
storage_encrypted = true
kms_key_id        = aws_kms_key.database.arn
```

AWS documents RDS encryption for database resources and snapshots at rest and SSL/TLS for data travelling between clients and databases. ([AWS Documentation][15])

## KMS design

Possible choices:

```text
AWS-managed RDS KMS key
Customer-managed KMS key
```

Use a customer-managed key when you require:

* Key-policy control.
* Cross-account controls.
* Defined key rotation governance.
* Detailed separation of duties.
* Specific compliance requirements.

Be careful:

```text
Disabling or deleting the KMS key can make encrypted data inaccessible.
```

---

# 30. Encryption in transit

Use TLS between the application and RDS.

PostgreSQL example:

```text
sslmode=require
```

Stronger certificate validation:

```text
sslmode=verify-full
```

Node.js example:

```javascript
const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,

  ssl: {
    rejectUnauthorized: true,
    ca: process.env.RDS_CA_CERT
  }
});
```

TLS protects database traffic from interception and tampering. ([AWS Documentation][16])

Do not disable certificate validation in production merely to make connectivity easier.

---

# 31. Database passwords and Secrets Manager

Do not put database credentials directly into:

```text
Git repositories
Docker images
Terraform source code
EC2 user data
Jenkinsfiles
Plain environment files
AMI images
```

Bad Terraform:

```hcl
username = "admin"
password = "Password123"
```

Better design:

```text
AWS Secrets Manager
       ↓
IAM role authorises retrieval
       ↓
Application loads secret
       ↓
Application connects to RDS
```

Example secret structure:

```json
{
  "username": "app_user",
  "password": "generated-secret",
  "host": "production-db.example.rds.amazonaws.com",
  "port": 5432,
  "dbname": "todoapp"
}
```

Important:

```text
Retrieving a secret securely does not automatically rotate
existing application connections.

The application must support reconnection after rotation.
```

---

# 32. IAM database authentication

Supported RDS engine and Region combinations can use IAM database authentication.

Instead of storing a long-lived database password, an application generates a temporary authentication token using an IAM identity.

Flow:

```text
EC2 or Lambda IAM role
          |
          | generates authentication token
          v
    Database connection
          |
          v
     RDS DB user
```

AWS documents IAM database authentication for supported MariaDB, MySQL and PostgreSQL configurations. ([AWS Documentation][17])

Generate a token:

```bash
TOKEN=$(aws rds generate-db-auth-token \
  --hostname production-db.example.ap-south-1.rds.amazonaws.com \
  --port 5432 \
  --region ap-south-1 \
  --username application_user)
```

IAM policy concept:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:ap-south-1:123456789012:dbuser:db-RESOURCE-ID/application_user"
    }
  ]
}
```

IAM database authentication does not replace database authorisation.

You still need to create the database user and grant appropriate database privileges.

```text
IAM:
May this identity connect as this DB user?

Database permissions:
What may this DB user read or modify?
```

---

# 33. Master user versus application user

Do not let the application normally connect using the master database user.

Bad design:

```text
Application → database master account
```

Better design:

```text
Master account:
Database administration only

Migration account:
Schema migrations

Application read/write account:
Normal API operations

Reporting account:
Read-only queries

Monitoring account:
Monitoring queries
```

PostgreSQL concept:

```sql
CREATE ROLE application_user LOGIN PASSWORD 'managed-secret';

GRANT CONNECT ON DATABASE todoapp TO application_user;
GRANT USAGE ON SCHEMA public TO application_user;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO application_user;
```

Apply least privilege at both layers:

```text
IAM permissions
Database privileges
```

---

# 34. Storage options

RDS supports different storage types according to engine and configuration.

Common categories include:

```text
General Purpose SSD
Provisioned IOPS SSD
```

## General-purpose SSD

Suitable for:

* Normal web applications.
* Development databases.
* Moderate production workloads.
* Cost-sensitive transactional systems.

## Provisioned IOPS

Suitable for:

* I/O-intensive databases.
* Consistent low-latency requirements.
* High transaction rates.
* Important enterprise databases.
* Workloads where storage performance must be explicitly provisioned.

Do not choose storage based only on database size.

Evaluate:

```text
IOPS
Throughput
Latency
Read/write ratio
Transaction rate
Working-set size
Checkpoint behaviour
Query patterns
```

---

# 35. Storage autoscaling

RDS storage autoscaling increases allocated storage when available space becomes low.

You configure:

```text
Initial allocated storage
Maximum allocated storage
```

Terraform:

```hcl
allocated_storage     = 100
max_allocated_storage = 500
storage_type          = "gp3"
```

RDS can initiate storage autoscaling when:

* Free space is at or below 10% of allocated storage.
* The condition lasts at least five minutes.
* Previous storage-modification conditions permit another modification.

AWS determines the increase using the largest of specified increments, including 10 GiB, 10% of current allocation or predicted growth. ([AWS Documentation][9])

## Critical limitation

Storage autoscaling increases storage.

It does not automatically decrease it.

```text
100 GiB → 200 GiB: possible

200 GiB → 100 GiB: not an ordinary in-place reduction
```

AWS explicitly states that allocated RDS storage cannot be reduced directly after it has been increased. ([AWS Documentation][9])

## Storage-autoscaling warning

Storage autoscaling cannot fully protect against every sudden bulk load.

Example:

```text
Available storage: 50 GiB
Imported data:     500 GiB
```

The database may still enter a storage-full condition before scaling operations complete.

Always monitor:

```text
FreeStorageSpace
Storage growth rate
Maximum storage threshold
```

---

# 36. RDS parameter groups

A parameter group controls engine configuration.

Parameters may be:

```text
Dynamic
Static
```

## Dynamic parameter

Takes effect without a database reboot.

## Static parameter

Requires a reboot before taking effect.

AWS documentation notes that static parameter changes do not become active until the associated DB instance is rebooted. ([AWS Documentation][18])

Terraform example:

```hcl
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.environment}-postgres-parameters"
  family = "postgres17"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name         = "max_connections"
    value        = "300"
    apply_method = "pending-reboot"
  }
}
```

Do not copy parameter values from a large production database to a small instance.

Example danger:

```text
max_connections = 2,000
DB class         = small-memory instance
```

Each connection consumes memory. Excessive connection limits may lead to memory exhaustion.

---

# 37. Maintenance windows

RDS uses maintenance windows for eligible maintenance operations.

Examples:

* Database-engine patching.
* Operating-system maintenance.
* Required instance modifications.
* Pending configuration changes.

Example Terraform:

```hcl
maintenance_window = "sun:19:00-sun:20:00"
backup_window      = "18:00-18:30"
```

Avoid overlapping maintenance and backup windows.

Use an operationally quiet time, but remember:

```text
A maintenance window is a preferred period,
not a guarantee that every incident waits for that period.
```

Urgent infrastructure recovery can occur outside it.

---

# 38. Blue/green database deployments

Database upgrades and major changes are risky.

A blue/green deployment conceptually creates:

```text
Blue environment:
Current production database

Green environment:
Synchronised copy for testing and change
```

Workflow:

```text
1. Create green environment.
2. Apply engine or parameter changes.
3. Validate application.
4. Test queries and migrations.
5. Switch production to green.
6. Monitor.
7. Retain rollback plan.
```

AWS RDS Blue/Green Deployments copy important topology features from the production environment, including supported read replicas, backup configuration and monitoring settings. ([AWS Documentation][19])

Use cases:

* Major engine upgrades.
* Parameter-group changes.
* Storage changes.
* Schema migration validation.
* Lower-risk production cutover.

---

# 39. RDS monitoring layers

You should monitor the database at several levels.

## Layer 1: CloudWatch infrastructure metrics

Common metrics:

```text
CPUUtilization
DatabaseConnections
FreeableMemory
FreeStorageSpace
ReadLatency
WriteLatency
ReadIOPS
WriteIOPS
NetworkReceiveThroughput
NetworkTransmitThroughput
ReplicaLag
DiskQueueDepth
```

## Layer 2: Enhanced Monitoring

Enhanced Monitoring provides operating-system-level information such as:

* CPU breakdown.
* Memory.
* Processes.
* File system.
* Disk I/O.
* Swap usage.

RDS sends Enhanced Monitoring data to CloudWatch Logs and can provide metrics at intervals down to one second. ([AWS Documentation][20])

## Layer 3: Database Insights

Use database-level performance analysis to inspect:

* Database load.
* Wait events.
* Expensive SQL.
* Users.
* Hosts.
* Lock contention.
* Resource bottlenecks.

As of July 27, 2026, AWS has announced that the Performance Insights console experience reaches end of life on **July 31, 2026** and redirects to CloudWatch Database Insights. The Performance Insights API remains available, but new operational designs should account for the Database Insights experience. ([AWS Documentation][21])

## Layer 4: Database logs

Depending on the engine:

```text
PostgreSQL logs
MySQL slow-query log
Error log
General log where appropriate
Audit logs
Upgrade logs
```

Export relevant logs to CloudWatch Logs.

---

# 40. Essential CloudWatch alarms

A production RDS database should normally have alarms for:

```text
High CPU utilisation
Low freeable memory
Low free storage
High database connections
High read latency
High write latency
Replica lag
Database failover events
Database restart events
Deadlocks where observable
Database load saturation
```

Example alarm:

```hcl
resource "aws_cloudwatch_metric_alarm" "low_storage" {
  alarm_name          = "${var.environment}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 21474836480

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.identifier
  }

  alarm_description = "RDS free storage is below 20 GiB"
  alarm_actions     = [aws_sns_topic.operations.arn]
}
```

---

# 41. Understanding important metrics

## CPUUtilization

High CPU might mean:

* Expensive SQL.
* Missing indexes.
* Too many queries.
* Large sorting operations.
* Database instance too small.
* Excessive connection activity.

Do not immediately resize without checking SQL behaviour.

## FreeableMemory

Low memory might mean:

* Too many connections.
* Large working sets.
* Large query operations.
* Poor parameter configuration.
* Instance class too small.

## DatabaseConnections

Compare against:

```text
Configured max_connections
Normal baseline
Peak connection count
Connection-pool settings
```

## ReadLatency and WriteLatency

High latency may indicate:

* Storage saturation.
* Excessive I/O.
* Poor queries.
* Checkpoint pressure.
* Insufficient IOPS.
* Database contention.

## ReplicaLag

High lag means the replica is not applying source changes quickly enough.

Possible causes:

* Heavy writes on the primary.
* Large transactions.
* Slow replica compute.
* Expensive queries on the replica.
* Network delay for cross-Region replication.
* Lock or engine-specific replication problems.

---

# 42. Terraform production example

The following is an illustrative PostgreSQL Multi-AZ DB instance:

```hcl
resource "aws_db_instance" "postgres" {
  identifier = "${var.environment}-postgres"

  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.db_instance_class

  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  port = 5432

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.database.arn

  multi_az = true

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible = false

  parameter_group_name = aws_db_parameter_group.postgres.name

  backup_retention_period = 14
  backup_window           = "18:00-18:30"
  maintenance_window      = "sun:19:00-sun:20:00"

  auto_minor_version_upgrade = true

  deletion_protection = true
  skip_final_snapshot = false

  final_snapshot_identifier = (
    "${var.environment}-postgres-final-snapshot"
  )

  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  performance_insights_enabled = true

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  apply_immediately = false

  tags = {
    Name        = "${var.environment}-postgres"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

## Sensitive-value warning

Do not commit `master_password` to Git.

Prefer:

* Secrets Manager.
* Managed master-user password features where suitable.
* A protected CI/CD secret.
* Sensitive Terraform variables.
* Encrypted remote Terraform state.

Mark the variable:

```hcl
variable "master_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
}
```

However:

```text
sensitive = true
```

only hides the value from normal Terraform output. It does not automatically prevent the value from being stored in Terraform state.

Protect the remote state with:

* S3 encryption.
* Strict IAM access.
* State locking.
* Versioning.
* Logging.
* Separate production accounts.

---

# 43. Create an RDS instance with AWS CLI

Illustrative PostgreSQL example:

```bash
aws rds create-db-instance \
  --db-instance-identifier production-postgres \
  --db-instance-class db.t4g.medium \
  --engine postgres \
  --allocated-storage 100 \
  --max-allocated-storage 500 \
  --storage-type gp3 \
  --storage-encrypted \
  --master-username postgres_admin \
  --manage-master-user-password \
  --db-subnet-group-name production-db-subnet-group \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --backup-retention-period 14 \
  --multi-az \
  --no-publicly-accessible \
  --deletion-protection \
  --region ap-south-1
```

Check status:

```bash
aws rds describe-db-instances \
  --db-instance-identifier production-postgres \
  --region ap-south-1 \
  --query 'DBInstances[0].{
    Status:DBInstanceStatus,
    Engine:Engine,
    Class:DBInstanceClass,
    MultiAZ:MultiAZ,
    Public:PubliclyAccessible,
    Endpoint:Endpoint.Address,
    Port:Endpoint.Port
  }'
```

---

# 44. Connect from EC2

Install PostgreSQL client:

```bash
sudo apt update
sudo apt install -y postgresql-client
```

Set variables:

```bash
export DB_HOST="production-postgres.example.ap-south-1.rds.amazonaws.com"
export DB_PORT="5432"
export DB_NAME="todoapp"
export DB_USER="application_user"
```

Connect:

```bash
psql \
  "host=$DB_HOST \
   port=$DB_PORT \
   dbname=$DB_NAME \
   user=$DB_USER \
   sslmode=require"
```

Validation SQL:

```sql
SELECT version();

SELECT current_database();

SELECT current_user;

SELECT now();
```

Test table:

```sql
CREATE TABLE health_validation (
    id BIGSERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO health_validation(message)
VALUES ('RDS connection successful');

SELECT * FROM health_validation;
```

---

# 45. Troubleshooting: connection timeout

Symptom:

```text
Connection timed out
```

Likely causes:

* Database security group blocks the application.
* Wrong port.
* Incorrect VPC.
* Missing peering or Transit Gateway routing.
* Application is outside the permitted network.
* Network ACL blocks traffic.
* RDS endpoint is incorrect.
* Database is not in `available` state.

Test DNS:

```bash
getent hosts "$DB_HOST"
```

Test TCP connectivity:

```bash
nc -vz "$DB_HOST" 5432
```

Interpretation:

```text
DNS fails:
Check endpoint and DNS settings.

TCP times out:
Check routes, SGs, NACLs and network placement.

TCP succeeds but login fails:
Check credentials, TLS, DB user and privileges.
```

---

# 46. Troubleshooting: password authentication failed

Symptom:

```text
password authentication failed for user
```

Possible causes:

* Wrong password.
* Wrong username.
* Connecting to the wrong database.
* Secret was rotated but the application still uses an old value.
* Database user does not exist.
* IAM authentication is being used incorrectly.
* Special characters were parsed incorrectly.

Validate the Secrets Manager value and application configuration.

Do not print the password into deployment logs.

---

# 47. Troubleshooting: too many connections

Symptom:

```text
FATAL: too many connections
```

Immediate actions:

1. Identify the clients opening connections.
2. Check application pool configuration.
3. Reduce unnecessary pool sizes.
4. Terminate abandoned sessions carefully.
5. Add RDS Proxy where appropriate.
6. Scale the DB instance if memory is truly insufficient.
7. Investigate connection leaks.

PostgreSQL query:

```sql
SELECT
    application_name,
    client_addr,
    state,
    COUNT(*) AS connection_count
FROM pg_stat_activity
GROUP BY application_name, client_addr, state
ORDER BY connection_count DESC;
```

Inspect total:

```sql
SELECT COUNT(*) FROM pg_stat_activity;

SHOW max_connections;
```

A larger `max_connections` value is not always the correct fix.

More connections can consume more memory and reduce performance.

---

# 48. Troubleshooting: high CPU

Investigate:

```text
Top SQL statements
Query frequency
Execution time
Wait events
Missing indexes
Sequential scans
Locks
Vacuum activity
Connection count
Recent deployments
```

PostgreSQL example:

```sql
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    query_start,
    query
FROM pg_stat_activity
WHERE state <> 'idle'
ORDER BY query_start;
```

Do not immediately reboot the database.

A reboot may temporarily stop the symptom but does not fix:

* Missing indexes.
* Bad queries.
* Excessive application traffic.
* Lock contention.
* Poor schema design.

---

# 49. Troubleshooting: replication lag

Symptoms:

```text
Replica returns old data
ReplicaLag metric increases
Reporting queries become inconsistent
```

Possible fixes:

* Increase replica instance size.
* Optimise heavy read queries.
* Reduce extremely large write transactions.
* Avoid long-running replica queries that interfere with recovery.
* Add additional replicas.
* Direct consistency-sensitive reads to the writer.
* Review network and regional architecture.

Remember:

```text
A replica being available does not guarantee that it is current.
```

---

# 50. Troubleshooting: storage-full condition

Symptoms:

```text
Database becomes unavailable
Writes fail
FreeStorageSpace approaches zero
Storage autoscaling event appears
```

Check:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=production-postgres \
  --statistics Minimum \
  --period 300 \
  --start-time "$(date -u -d '6 hours ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --region ap-south-1
```

Investigate:

* Unexpected table growth.
* Audit or application logs stored in DB.
* Temporary files.
* Large migrations.
* Index growth.
* Failed cleanup jobs.
* Data-retention policy.
* Maximum autoscaling threshold.

AWS recommends continuously monitoring `FreeStorageSpace` because running out of storage can make an RDS instance unavailable. ([AWS Documentation][18])

---

# 51. Production migration pattern

When moving an application database into RDS:

```text
1. Discover existing database.
2. Measure database size and growth.
3. Analyse extensions and features.
4. Select RDS engine and version.
5. Build subnet and security configuration.
6. Create target database.
7. Configure encryption and backups.
8. Migrate schema.
9. Perform initial data load.
10. Replicate ongoing changes.
11. Validate data.
12. Run application tests.
13. Stop writes or perform controlled cutover.
14. Redirect application.
15. Monitor.
16. Retain rollback period.
```

Migration tools may include:

* Native database dump and restore.
* Logical replication.
* AWS Database Migration Service.
* Read-replica-based migration.
* Engine-specific replication tools.

Never perform a production migration without:

```text
Rollback conditions
Data-validation method
Downtime estimate
DNS or connection change plan
Owner for final decision
```

---

# 52. Production RDS checklist

```text
[ ] Database is not publicly accessible
[ ] DB subnet group contains multiple AZs
[ ] Security group permits only trusted application resources
[ ] Multi-AZ is enabled for critical production workloads
[ ] Automated backups are enabled
[ ] Backup retention matches business requirements
[ ] Point-in-time recovery has been tested
[ ] Manual snapshots are taken before risky changes
[ ] Deletion protection is enabled
[ ] Final snapshot is required on deletion
[ ] Storage encryption is enabled
[ ] TLS is required for connections
[ ] Secrets are stored outside source code
[ ] Application does not use the master DB account
[ ] Database users follow least privilege
[ ] Connection pools are correctly sized
[ ] RDS Proxy is considered for connection-heavy workloads
[ ] Free storage is alarmed
[ ] Database connections are alarmed
[ ] CPU, memory and latency are monitored
[ ] Replica lag is monitored
[ ] Failover has been tested
[ ] Application retries failed connections
[ ] Maintenance and backup windows are selected
[ ] Parameter changes are tested
[ ] Database restore runbook exists
[ ] RPO and RTO are documented
[ ] Regional disaster recovery is considered
```

---

# 53. Certification-focused understanding

## Cloud Practitioner

Understand:

```text
RDS is a managed relational database service.
Multi-AZ provides high availability.
Read replicas provide read scaling.
Automated backups support recovery.
```

## Solutions Architect Associate

Understand:

```text
Single-AZ versus Multi-AZ
Standby versus read replica
Synchronous versus asynchronous replication
Automatic failover
DB subnet groups
Security groups
Backups and PITR
RDS Proxy
Storage autoscaling
Encryption
```

## DevOps Engineer Professional

Understand:

```text
Automated database deployment
Failover testing
Backup validation
Blue/green database changes
CloudWatch alarms
Database event automation
Secrets rotation
RDS Proxy
Cross-Region recovery
Terraform lifecycle safety
Maintenance and rollback
```

---

# 54. Interview questions

## Question 1: What is the difference between Multi-AZ and a read replica?

**Answer:**

Multi-AZ is mainly for high availability and automatic failover. A traditional Multi-AZ standby does not serve application reads. A read replica primarily provides read scaling and usually receives changes asynchronously.

## Question 2: Does Multi-AZ protect against accidental data deletion?

**Answer:**

No. The deletion is replicated to the standby. Automated backups, point-in-time recovery or snapshots are needed to recover older data.

## Question 3: What happens during RDS failover?

**Answer:**

RDS promotes a standby or reader to become the new primary and updates the database endpoint. Existing application connections may fail, so applications must reconnect and retry appropriate operations.

## Question 4: Why should RDS normally be private?

**Answer:**

Only the application tier should access the database. Private placement and restrictive security groups reduce direct internet exposure and limit the attack surface.

## Question 5: What is replication lag?

**Answer:**

It is the delay between a change being committed on the source database and that change being applied to a read replica.

## Question 6: Why use RDS Proxy?

**Answer:**

RDS Proxy pools and reuses database connections, reducing connection overhead and protecting the database from connection surges, especially with Lambda or autoscaled applications.

## Question 7: What is point-in-time recovery?

**Answer:**

It restores a new database to a selected time within the configured backup-retention period by using backup data and transaction logs.

## Question 8: Can RDS storage autoscaling reduce storage?

**Answer:**

No. It increases allocated storage up to the configured threshold. It does not automatically scale storage down.

## Question 9: What is the purpose of a DB subnet group?

**Answer:**

It identifies the VPC subnets in which RDS can place database resources, including resources across multiple Availability Zones.

## Question 10: Should an application use the master database user?

**Answer:**

No. The application should use a limited database account with only the privileges necessary for its normal operations.

---

# 55. Never-forget revision

```text
RDS:
Managed relational database infrastructure.

Single-AZ:
One database in one Availability Zone.

Multi-AZ DB instance:
One primary plus one non-readable synchronous standby.

Multi-AZ DB cluster:
One writer plus two readable standby instances.

Read replica:
Asynchronous copy used mainly for read scaling.

Replication lag:
Delay before replica receives source changes.

Failover:
Standby or reader becomes the new primary.

Automated backup:
Maintains recovery data for a retention period.

PITR:
Restores a new database to a selected time.

Manual snapshot:
Explicit backup retained according to your management.

RDS Proxy:
Pools and reuses database connections.

DB subnet group:
Subnets where RDS may place database resources.

Parameter group:
Database-engine configuration.

RPO:
Maximum acceptable data loss.

RTO:
Maximum acceptable recovery time.
```

## One-line memory trick

```text
Multi-AZ keeps the database available.
Read replicas scale reads.
Backups recover old data.
RDS Proxy protects connections.
```

## Lesson 25 outcome

You can now design a database architecture where:

```text
Primary infrastructure fails
        → Multi-AZ failover occurs.

Read traffic increases
        → Read replicas serve additional reads.

Application instances scale rapidly
        → RDS Proxy controls database connections.

A table is accidentally deleted
        → PITR restores an earlier database state.

Storage grows unexpectedly
        → Storage autoscaling increases capacity.

A password must be protected
        → Secrets Manager or IAM authentication is used.
```

**Next lesson: Lesson 26 — Amazon ElastiCache with Redis/Valkey, caching patterns, session storage, cache invalidation, replication, failover and production performance architecture.**

[1]: https://aws.amazon.com/rds/?utm_source=chatgpt.com "Fully Managed Relational Database – Amazon RDS"
[2]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZSingleStandby.html?utm_source=chatgpt.com "Multi-AZ DB instance deployments for Amazon RDS"
[3]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.Failover.html?utm_source=chatgpt.com "Failing over a Multi-AZ DB instance for Amazon RDS"
[4]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RebootInstance.html?utm_source=chatgpt.com "Rebooting a DB instance - Amazon Relational Database Service"
[5]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html?utm_source=chatgpt.com "Configuring and managing a Multi-AZ deployment for ..."
[6]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts-failover.html?utm_source=chatgpt.com "Failing over a Multi-AZ DB cluster for Amazon RDS"
[7]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html?utm_source=chatgpt.com "Working with DB instance read replicas"
[8]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.Promote.html?utm_source=chatgpt.com "Promoting a read replica to be a standalone DB instance"
[9]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIOPS.Autoscaling.html "Managing capacity automatically with Amazon RDS storage autoscaling - Amazon Relational Database Service"
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html?utm_source=chatgpt.com "Quotas and constraints for Amazon RDS"
[11]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html?utm_source=chatgpt.com "Amazon RDS Proxy - Amazon Relational Database Service"
[12]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-connections.html?utm_source=chatgpt.com "RDS Proxy connection considerations"
[13]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.BackupRetention.html "Backup retention period - Amazon Relational Database Service"
[14]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html?utm_source=chatgpt.com "Introduction to backups - Amazon Relational Database Service"
[15]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Encryption.html?utm_source=chatgpt.com "Protecting data using encryption - Amazon Relational Database Service"
[16]: https://docs.aws.amazon.com/AmazonRDS/latest/gettingstartedguide/advanced-security.html?utm_source=chatgpt.com "Advanced security options in Amazon RDS - Amazon Relational Database Service"
[17]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/database-authentication.html?utm_source=chatgpt.com "Database authentication with Amazon RDS - Amazon Relational Database Service"
[18]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Troubleshooting.html?utm_source=chatgpt.com "Troubleshooting for Amazon RDS - AWS Documentation"
[19]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-overview.html?utm_source=chatgpt.com "Overview of Amazon RDS Blue/Green Deployments"
[20]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Monitoring.OS.html?utm_source=chatgpt.com "Monitoring OS metrics with Enhanced Monitoring"
[21]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.Enabling.html?utm_source=chatgpt.com "Turning Performance Insights on and off for Amazon RDS"
