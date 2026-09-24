# AWS Masterclass — Phase 3

# Lesson 36: AWS Transform, MGN, DMS and Production Migration-Wave Planning

## 1. Lesson objectives

In this lesson, you will learn how to:

* Understand the complete AWS migration lifecycle.
* Use the seven AWS migration strategies, known as the **7 Rs**.
* Discover servers, databases and application dependencies.
* Build a migration business case and cost assessment.
* Understand the current role of AWS Transform.
* Migrate physical, virtual and cloud servers using AWS Transform MGN.
* Design MGN staging, replication, testing and cutover networking.
* Migrate databases using AWS Database Migration Service.
* Distinguish full load, CDC and full load plus CDC.
* Convert database schemas using DMS Schema Conversion.
* Distinguish homogeneous and heterogeneous migrations.
* Build application dependency groups and migration waves.
* Run pilot, foundation and scale-out migration waves.
* Create detailed cutover and rollback runbooks.
* Validate migrated applications and databases.
* Operate a migration factory.
* Troubleshoot server and database migration failures.

---

# 2. Important 2026 service-name update

AWS Application Migration Service has been renamed:

```text
Old name:
AWS Application Migration Service

Current name:
AWS Transform MGN
```

The underlying service acronym and APIs remain:

```text
MGN
```

The replication engine and existing MGN functionality remain available under the new AWS Transform MGN name. ([Amazon Web Services, Inc.][1])

AWS Migration Hub and AWS Application Discovery Service stopped accepting new customers on **November 7, 2025**. Existing customers can continue using them for ongoing projects, while AWS directs new migration initiatives toward AWS Transform and its assessment, discovery and migration capabilities. ([AWS Documentation][2])

## Modern service map

```text
Discovery and assessment:
AWS Transform discovery tool
AWS Transform migration assessments
Migration Evaluator

Server rehosting:
AWS Transform MGN

Database migration:
AWS Database Migration Service

Schema conversion:
DMS Schema Conversion

Large file migration:
AWS DataSync

Migration planning and wave generation:
AWS Transform
```

---

# 3. Migration is not only copying servers

A production migration includes:

```text
People
Processes
Applications
Data
Networks
Security
Compliance
Operations
Monitoring
Backups
Business cutover
```

A technically successful server copy can still be a failed migration when:

* The application cannot connect to its database.
* DNS still points to the old environment.
* External partners cannot reach the service.
* Monitoring was not configured.
* Backups were never tested.
* Licences are invalid in AWS.
* Performance is worse than before.
* The rollback plan is unusable.
* Application owners did not approve the result.

## Migration success definition

```text
The workload runs in AWS,
meets business and technical requirements,
is operationally supported,
and can be recovered safely.
```

---

# 4. The AWS migration lifecycle

AWS migration programs are commonly divided into:

```text
Assess
Mobilize
Migrate and modernize
```

## Assess

Determine:

* What exists.
* What depends on what.
* What should move.
* What should not move.
* Which AWS services are appropriate.
* Estimated migration cost.
* Estimated future cloud cost.
* Business benefits and risks.

## Mobilize

Build the foundation:

* AWS Organizations.
* Landing zone.
* Accounts.
* VPCs.
* Connectivity.
* Identity.
* Security controls.
* Logging.
* Backup.
* Migration tooling.
* Automation.
* Pilot wave.

## Migrate and modernize

Execute:

* Application waves.
* Database migration.
* Server replication.
* Testing.
* Cutover.
* Validation.
* Decommissioning.
* Optimisation.

AWS guidance describes assessment, mobilization and migration as key stages for large migration programs. ([AWS Documentation][3])

---

# 5. The seven migration strategies

AWS defines seven common migration strategies:

```text
Retire
Retain
Rehost
Relocate
Repurchase
Replatform
Refactor or re-architect
```

These are known as:

```text
The 7 Rs
```

([AWS Documentation][4])

---

# 6. Retire

Retire means:

```text
Stop using the application.
```

Examples:

* An old reporting system has no active users.
* A duplicate application was replaced years ago.
* A server exists only because nobody approved shutdown.
* A legacy database is no longer queried.

## Retire process

```text
Confirm no business dependency
        ↓
Archive required records
        ↓
Obtain application-owner approval
        ↓
Disable application
        ↓
Observe
        ↓
Decommission infrastructure
```

Retiring unnecessary workloads reduces:

* Migration scope.
* Future cloud cost.
* Security exposure.
* Operational burden.

---

# 7. Retain

Retain means:

```text
Keep the workload in its current environment for now.
```

Possible reasons:

* Hardware dependency.
* Regulatory restriction.
* Migration cost exceeds benefit.
* Application will soon be retired.
* Vendor does not support cloud deployment.
* A major upgrade is already scheduled.
* Network latency requirements cannot yet be met.

Retain does not mean:

```text
Ignore forever.
```

Every retained workload should have:

* Business owner.
* Review date.
* Security plan.
* Connectivity plan.
* Long-term strategy.

---

# 8. Rehost

Rehost means:

```text
Move the workload with minimal architectural change.
```

It is also called:

```text
Lift and shift
```

Example:

```text
VMware virtual machine
        ↓
Amazon EC2 instance
```

Typical tool:

```text
AWS Transform MGN
```

Use rehost when:

* Speed is important.
* Application change is risky.
* Source documentation is weak.
* A data-centre exit deadline exists.
* Modernisation will happen after migration.

---

# 9. Relocate

Relocate means moving a platform without redesigning the applications running on it.

Examples:

```text
VMware environment
        ↓
VMware Cloud on AWS
```

or moving an existing platform stack with minimal workload-level changes.

The application remains substantially unchanged while its underlying hosting environment moves.

---

# 10. Repurchase

Repurchase means replacing the application with another product.

Example:

```text
Custom on-premises CRM
        ↓
Software-as-a-Service CRM
```

Other examples:

* Self-managed ticketing system to SaaS.
* Legacy email platform to a managed service.
* Old ERP to a modern commercial platform.

Repurchase often involves:

* Data migration.
* Identity integration.
* User training.
* Contract changes.
* Process redesign.

It is not simply an infrastructure migration.

---

# 11. Replatform

Replatform means:

```text
Move the workload with selected platform improvements,
without fully redesigning the application.
```

It is sometimes called:

```text
Lift, tinker and shift
```

Examples:

```text
MySQL on EC2
        ↓
Amazon RDS for MySQL
```

```text
Java application on virtual machines
        ↓
Amazon ECS containers
```

```text
Self-managed Redis
        ↓
Amazon ElastiCache
```

The application may require configuration changes, but its basic architecture remains recognisable.

---

# 12. Refactor or re-architect

Refactor means significantly redesigning the application to use cloud-native capabilities.

Example:

```text
Large monolithic application
        ↓
API services
Event-driven processing
Managed databases
Serverless functions
Containers
```

Use refactoring when the business needs:

* Faster feature delivery.
* Independent scaling.
* Improved resilience.
* Global architecture.
* Reduced licensing dependence.
* Significant technical-debt removal.

Refactoring is usually the most complex and time-consuming migration strategy.

For a large data-centre exit, it is often safer to migrate first and modernise selected applications afterward rather than trying to transform every workload during the migration. AWS large-migration guidance similarly notes that rehost, replatform, relocate and retire are common at scale, while refactoring during the mass-migration phase adds substantial complexity. ([AWS Documentation][5])

---

# 13. One application may use multiple Rs

Consider an e-commerce platform:

```text
Web servers:
Rehost to EC2

Database:
Replatform to Amazon RDS

Cache:
Repurchase with ElastiCache

Reporting:
Refactor into S3 and analytics services

Old admin tool:
Retire

Mainframe integration:
Retain temporarily
```

Do not force an entire application estate into one strategy.

Evaluate each:

* Application.
* Database.
* Integration.
* Supporting server.
* Commercial product.
* Shared platform.

---

# 14. Discovery phase

You cannot migrate safely when you do not know:

```text
Which servers exist
Who owns them
Which applications run on them
Which databases they use
Which systems communicate
Which ports are required
How much CPU and memory they consume
When peak usage occurs
```

Discovery should collect:

* Hostname.
* IP address.
* Operating system.
* CPU.
* Memory.
* Storage.
* Utilisation.
* Network interfaces.
* Running processes.
* Installed software.
* Database engines.
* Open connections.
* Application owner.
* Business criticality.
* Compliance classification.

---

# 15. AWS Transform discovery tool

The AWS Transform discovery tool can discover server inventory from environments including VMware vCenter, Microsoft Hyper-V and imported server data. It can collect operating-system, storage, process, performance and network-interface details and use network connections to help map dependencies. ([AWS Documentation][6])

Architecture:

```text
VMware / Hyper-V / servers
           |
           v
AWS Transform discovery tool
           |
           v
Inventory and dependency data
           |
           v
Application grouping
           |
           v
Move groups and migration waves
```

The tool can use:

```text
SSH:
Linux discovery

WinRM:
Windows discovery
```

---

# 16. Dependency mapping

Suppose discovery identifies:

```text
web-01 → app-01:8080
web-02 → app-01:8080
app-01 → db-01:5432
app-01 → redis-01:6379
app-01 → smtp.corporate.local:25
```

This reveals:

```text
Application group:
web-01
web-02
app-01
db-01
redis-01
```

and one external dependency:

```text
Corporate SMTP server
```

Migrating only the web servers would fail because they require the application, database and cache layers.

AWS Transform can analyse discovered application dependencies and help group infrastructure into applications, move groups and waves. ([AWS Documentation][7])

---

# 17. Application, move group and wave

## Application

A logical business workload.

Example:

```text
Todo platform
```

## Move group

A collection of tightly dependent infrastructure that should move together.

Example:

```text
web-01
web-02
app-01
db-01
```

## Migration wave

One or more move groups migrated during the same planned time window.

Example:

```text
Wave 3:
Customer portal
Internal reporting
Notification service
```

---

# 18. Discovery-data quality

Bad inventory:

```text
Server:
server-42

Owner:
Unknown

Application:
Unknown

Dependencies:
Unknown
```

This server is not ready for migration.

A production inventory should include:

| Field       | Example                 |
| ----------- | ----------------------- |
| Server      | `todo-app-01`           |
| Owner       | Application Engineering |
| Application | Todo Platform           |
| Environment | Production              |
| OS          | Ubuntu                  |
| CPU         | 8 vCPU                  |
| RAM         | 32 GiB                  |
| Storage     | 500 GiB                 |
| Database    | PostgreSQL              |
| Criticality | Tier 1                  |
| RTO         | 1 hour                  |
| RPO         | 5 minutes               |
| Strategy    | Replatform              |
| Wave        | Wave 4                  |

---

# 19. Migration assessment

AWS Transform assessments evaluate the cost, feasibility and business value of moving infrastructure to AWS. They can provide right-sizing recommendations and estimated costs for services such as EC2, EBS, S3, FSx and selected RDS workloads. ([AWS Documentation][8])

Assessment inputs may include:

* Provisioned capacity.
* Actual utilisation.
* Operating system.
* Database edition.
* Storage type.
* Licensing model.
* Peak usage.
* Growth assumptions.
* Availability requirements.

## Provisioned versus used capacity

Example:

```text
On-premises server provisioned:
16 CPU
64 GiB RAM

Measured peak:
4 CPU
18 GiB RAM
```

Migrating directly to an equivalent 16-vCPU instance may reproduce years of overprovisioning.

A right-sized target could begin smaller while preserving performance headroom.

---

# 20. Migration Evaluator

Migration Evaluator is a guided migration-assessment service that can collect on-premises inventory and utilisation information and help produce a directional business case and projected AWS cost view. AWS Transform can also consume data from Migration Evaluator collectors as part of its discovery and migration workflow. ([Amazon Web Services, Inc.][9])

Typical outputs include:

* Current infrastructure profile.
* Utilisation-based right-sizing.
* Estimated AWS compute and storage costs.
* Licensing scenarios.
* Potential modernisation opportunities.
* Migration business-case inputs.

## Business-case warning

An infrastructure cost comparison is incomplete unless it includes:

```text
Hardware
Software licences
Data-centre facilities
Power
Cooling
Networking
Support contracts
Backup platforms
Operational staff effort
Refresh cycles
Downtime risk
```

---

# 21. Target architecture before migration

Do not begin replication before designing the target environment.

The target should include:

```text
AWS account
VPC
Subnets
Route tables
Internet or private connectivity
DNS
IAM roles
Security groups
KMS keys
Logging
Backups
Monitoring
Patch management
Tagging
Cost controls
```

## Bad approach

```text
Replicate server first
Design networking later
```

## Correct approach

```text
Design landing zone
        ↓
Deploy network and security
        ↓
Test connectivity
        ↓
Configure migration tooling
        ↓
Begin replication
```

---

# 22. AWS Transform MGN

AWS Transform MGN is AWS’s block-level server-rehosting service.

It can migrate supported:

```text
Physical servers
VMware virtual machines
Hyper-V virtual machines
Cloud-hosted servers
Windows servers
Linux servers
```

It continuously replicates source-server block changes into an AWS staging area and converts the replicated server into launchable EC2 infrastructure for test and cutover. AWS describes typical cutover windows as measured in minutes. ([AWS Documentation][10])

---

# 23. MGN architecture

```text
Source server
     |
     | AWS Replication Agent
     | Continuous block-level replication
     v
MGN staging subnet
     |
     ├── Replication server
     ├── Staging EBS volumes
     └── Conversion resources
             |
             v
       Test instance
             |
             v
       Cutover instance
```

The source application continues running while block changes are replicated.

---

# 24. Block-level replication

MGN does not copy files one at a time.

It replicates:

```text
Disk blocks
```

The agent initially reads the attached volumes and sends their blocks to the replication servers. It then captures new writes and continuously synchronises changed blocks. ([AWS Documentation][11])

Advantages:

* Application-independent replication.
* Filesystem contents move together.
* Minimal application redesign.
* Frequent synchronisation.
* Test launches without stopping the source.

---

# 25. MGN staging area

The staging area contains temporary infrastructure used for replication.

AWS recommends a dedicated staging subnet, often shared across migration waves within one AWS account unless scale or isolation requirements justify multiple subnets. ([AWS Documentation][12])

Example:

```text
Migration account or target account
└── VPC
    ├── MGN staging subnet
    │   ├── Replication servers
    │   └── Staging volumes
    │
    ├── Test subnet
    │   └── Test EC2 instances
    │
    └── Production subnet
        └── Cutover EC2 instances
```

## Why separate staging?

* Easier security-group control.
* Easier routing.
* Easier cost identification.
* Reduced accidental access.
* Consistent replication configuration.
* Simpler troubleshooting.

---

# 26. MGN network communication

The source replication agent sends replicated block data to the replication infrastructure. MGN replication servers use inbound TCP port `1500` for the data-replication connection. Staging and conversion resources also require connectivity to AWS service endpoints and current Amazon Linux package repositories used by the managed replication infrastructure. ([AWS Documentation][13])

Conceptual requirements:

```text
Source server
    |
    | HTTPS to MGN service endpoints
    |
    | TCP 1500 to replication server
    v
AWS staging subnet
```

Review:

* Corporate firewall.
* Security groups.
* Network ACLs.
* Route tables.
* Proxy configuration.
* VPN or Direct Connect.
* DNS.
* S3 endpoint access.
* Internet or private service connectivity.

---

# 27. Initial replication

After installing the agent:

```text
Server added
    ↓
Initial block scan
    ↓
Replication server launched
    ↓
Staging volumes created
    ↓
Initial sync
    ↓
Continuous replication
```

Possible lifecycle states include:

```text
Initial sync
Backlog
Healthy
Ready for testing
```

Do not schedule a test launch until initial synchronisation has completed and lag is acceptable.

---

# 28. Replication lag

Replication lag indicates how far the AWS staging copy is behind the source.

Example:

```text
Source latest write:
12:00:00

Staging latest replicated write:
11:59:55

Replication lag:
5 seconds
```

Before cutover, define an acceptable lag:

```text
Web server:
Potentially seconds

Transaction database:
May require additional database-specific consistency controls

File server:
Depends on write freeze and business requirement
```

Near-zero infrastructure replication does not automatically guarantee application-consistent database recovery.

---

# 29. Launch settings

MGN launch configuration determines the EC2 environment for test and cutover.

Configure:

```text
Instance type
Subnet
Security groups
Public or private IP
IAM instance profile
EBS volume type
Encryption
Tags
Tenancy
Licensing options
Host name
Boot mode
```

## Do not copy source sizing blindly

Example:

```text
Source:
16 CPU, 64 GiB RAM

Observed peak:
4 CPU, 20 GiB RAM

Initial target:
m-family instance with suitable headroom
```

Use discovery data, application testing and load testing to select the target.

---

# 30. Test launch

A test launch creates an EC2 instance from replicated staging data while the source server remains active.

```text
Source server:
Still serving production

Test instance:
Isolated AWS copy
```

Use test instances to validate:

* Boot.
* Drivers.
* Filesystems.
* Services.
* Application startup.
* Network access.
* IAM.
* Monitoring.
* Backups.
* Performance.
* Security.
* Licensing.
* DNS behavior.

MGN supports launching test instances and then marking servers as ready for cutover after testing is complete. ([AWS Documentation][14])

---

# 31. Test-environment isolation

Do not let a test copy accidentally behave like production.

A replicated test server may still contain:

* Production API credentials.
* SMTP settings.
* Scheduled jobs.
* Payment integrations.
* Queue consumers.
* Monitoring agents.
* Backup agents.
* Domain membership.
* Production database addresses.

## Isolate test launches

```text
Separate subnet
Restricted security group
No production DNS
Disabled scheduled jobs
Disabled outbound email
Test credentials
Test queue
Test payment endpoint
```

---

# 32. Post-launch actions

MGN supports predefined and custom post-launch actions using Systems Manager–based automation.

Possible actions include:

* Install management agents.
* Update drivers.
* Configure CloudWatch.
* Join a domain.
* Apply tags.
* Install security tooling.
* Run scripts.
* Modify application configuration.
* Perform OS-level modernisation steps.

Post-launch actions can be configured for test instances, cutover instances or both, and their parameters can be protected using Parameter Store and KMS. ([AWS Documentation][15])

---

# 33. MGN testing checklist

```text
[ ] Instance boots without emergency mode
[ ] All expected disks are present
[ ] Filesystems mount correctly
[ ] Application service starts
[ ] Database connectivity works
[ ] DNS resolution works
[ ] Security groups are correct
[ ] Load balancer health check passes
[ ] IAM role works
[ ] CloudWatch Agent reports metrics
[ ] Logs reach the correct destination
[ ] Backup policy includes the instance
[ ] Patch management works
[ ] Antivirus/EDR works
[ ] Licence remains valid
[ ] Performance test passes
[ ] Application owner signs off
```

---

# 34. Cutover preparation

Before cutover:

```text
Testing completed
Replication healthy
Lag acceptable
Change freeze approved
DNS plan approved
Rollback plan approved
Business communication sent
Support team ready
Monitoring dashboard ready
```

A source server should be marked:

```text
Ready for cutover
```

only after testing is formally approved.

---

# 35. MGN cutover

Cutover creates a new EC2 instance from the most recently replicated staging state.

```text
Stop or quiesce source application
        ↓
Wait for final replication
        ↓
Confirm acceptable lag
        ↓
Launch cutover instance
        ↓
Run validation
        ↓
Change DNS or traffic routing
```

MGN can perform cutover for individual servers or waves after testing is finalized. ([AWS Documentation][16])

---

# 36. Critical MGN cutover behavior

After the cutover instance is launched, changes from the source continue replicating into the **staging area**, not into the launched cutover instance. ([AWS Documentation][17])

That means:

```text
Source write after cutover launch
        ↓
Replicated to staging volume

Not automatically applied to:
Existing cutover EC2 instance
```

Therefore:

* Freeze writes before final launch when possible.
* Reconcile any late writes.
* Do not run production independently on both systems.
* Define the authoritative environment.

---

# 37. Finalize cutover

After successful business validation:

```text
Finalize cutover
```

Finalization:

* Marks migration complete.
* Stops data replication.
* Removes replication resources.
* Preserves launched test or cutover instances.
* Disconnects the source server from active migration state.

MGN finalization terminates the service-managed replication infrastructure; the current CLI documents this cleanup occurring after finalization while leaving the launched EC2 instance intact. ([AWS Documentation][14])

## Do not finalize immediately

Keep a defined observation period such as:

```text
2 hours
24 hours
One business day
```

according to business risk.

Once replication is finalised, the easy pre-cutover replication path is gone.

---

# 38. MGN rollback

A rollback could mean:

```text
Return traffic to source
```

But remember:

```text
Writes made only in AWS
are not automatically replicated back to the source.
```

Rollback planning must address data divergence.

## Stateless server rollback

Easy pattern:

```text
Shift DNS/load balancer back to source
```

## Stateful server rollback

Requires:

* Write freeze.
* Database reconciliation.
* File synchronisation.
* Transaction comparison.
* Clear source-of-truth decision.

For stateful applications, database migration should usually have a dedicated rollback design rather than relying only on server-level block replication.

---

# 39. MGN CLI examples

List source servers:

```bash
aws mgn describe-source-servers \
  --region ap-south-1
```

Inspect a launch configuration:

```bash
aws mgn get-launch-configuration \
  --source-server-id s-0123456789abcdef0 \
  --region ap-south-1
```

Launch testing:

```bash
aws mgn start-test \
  --source-server-ids s-0123456789abcdef0 \
  --region ap-south-1
```

Start cutover:

```bash
aws mgn start-cutover \
  --source-server-ids s-0123456789abcdef0 \
  --region ap-south-1
```

Finalize one server:

```bash
aws mgn finalize-cutover \
  --source-server-id s-0123456789abcdef0 \
  --region ap-south-1
```

Current MGN CLI operations include source-server discovery, test launch, cutover, finalization, replication control, wave management and network-migration operations. ([AWS Documentation][18])

---

# 40. Common MGN failures

## Replication agent cannot register

Check:

* IAM installation credentials.
* Service Region.
* Outbound HTTPS.
* Proxy.
* DNS.
* System time.
* Supported operating system.
* Existing conflicting agent.

## Replication server cannot launch

Check:

* EC2 quota.
* Subnet IP capacity.
* IAM service role.
* Security groups.
* KMS key.
* EBS quota.
* Required VPC endpoints.

## Replication stalls

Check:

* TCP 1500.
* Firewall.
* Packet loss.
* Source disk read errors.
* Staging server health.
* S3 package-repository access.
* Low source bandwidth.

## Test instance does not boot

Check:

* Boot mode.
* Drivers.
* Disk mapping.
* Filesystem corruption.
* OS support.
* Conversion logs.
* Windows boot configuration.
* Linux `/etc/fstab`.

MGN documents endpoint access, routing, DNS, firewall and staging-service connectivity as common causes of replication and launch failures. ([AWS Documentation][19])

---

# 41. AWS Database Migration Service

AWS DMS moves database data between supported sources and targets.

It supports:

```text
Homogeneous migration
Heterogeneous migration
Full load
Change Data Capture
Full load plus CDC
Provisioned replication
Serverless replication
```

DMS manages the migration infrastructure, and DMS Serverless can automatically provision and scale replication capacity within configured limits. ([AWS Documentation][20])

---

# 42. Homogeneous database migration

Homogeneous means the source and target use the same or compatible database engine.

Examples:

```text
PostgreSQL → Amazon RDS for PostgreSQL
MySQL → Amazon Aurora MySQL
MongoDB → Amazon DocumentDB-compatible workflow
Oracle → Oracle on Amazon RDS
SQL Server → Amazon RDS for SQL Server
```

Schema changes are typically smaller, although version, extension, privilege and feature differences still require assessment.

---

# 43. Heterogeneous database migration

Heterogeneous means changing database engines.

Examples:

```text
Oracle → Aurora PostgreSQL
SQL Server → PostgreSQL
Oracle → Amazon Redshift
SAP ASE → PostgreSQL
```

This requires two separate problems to be solved:

```text
Schema and code conversion
+
Data movement
```

Use:

```text
DMS Schema Conversion:
Convert schema and database code

AWS DMS:
Move table data and ongoing changes
```

---

# 44. DMS architecture

Provisioned DMS:

```text
Source database
       |
       v
Source endpoint
       |
       v
DMS replication instance
       |
       v
Target endpoint
       |
       v
Target database
```

Serverless DMS:

```text
Source endpoint
       |
       v
DMS Serverless replication configuration
       |
       v
Automatically provisioned replication capacity
       |
       v
Target endpoint
```

---

# 45. DMS Standard versus Serverless

## DMS Standard

You choose and manage:

```text
Replication instance class
Storage
Multi-AZ option
Maintenance
Task placement
Capacity changes
```

## DMS Serverless

You configure:

```text
Source and target endpoints
Minimum capacity units
Maximum capacity units
Networking
Task settings
Table mappings
```

DMS then estimates, provisions and scales replication capacity.

DMS Serverless provides automatic provisioning, scaling, built-in high availability and usage-based capacity billing, although it does not support every source, target or feature available in DMS Standard. ([AWS Documentation][21])

---

# 46. Full-load migration

Full load copies existing source data.

```text
Existing source tables
        ↓
DMS full load
        ↓
Target tables
```

Use when:

* Source can be stopped.
* Downtime is acceptable.
* Data changes do not need to be captured.
* A one-time copy is sufficient.

Potential workflow:

```text
Stop application
        ↓
Full load
        ↓
Validate
        ↓
Start application on target
```

---

# 47. Change Data Capture

CDC means:

```text
Change Data Capture
```

DMS reads ongoing committed changes from source transaction logs.

Examples:

* Inserts.
* Updates.
* Deletes.

```text
Source application remains online
        ↓
Transaction log changes
        ↓
DMS CDC
        ↓
Target remains nearly current
```

DMS can run ongoing CDC independently or after an initial full load. ([AWS Documentation][22])

---

# 48. Full load plus CDC

This is the most common low-downtime pattern.

```text
1. DMS starts capturing changes.

2. Existing tables are copied.

3. Changes occurring during the copy are retained.

4. Full load finishes.

5. Captured changes are applied.

6. Ongoing changes continue.

7. Replication lag approaches zero.

8. Application writes are stopped.

9. Final changes are applied.

10. Application switches to target.
```

DMS supports `full-load-and-cdc`, in which the initial dataset is loaded while ongoing changes are captured and later applied to the target. ([AWS Documentation][23])

---

# 49. Database cutover sequence

```text
1. Confirm full load completed.

2. Monitor CDC lag.

3. Validate row counts and data.

4. Schedule change freeze.

5. Stop source application writes.

6. Allow pending changes to replicate.

7. Confirm source and target are synchronized.

8. Stop or pause DMS at the agreed point.

9. Update application connection string.

10. Start application against target.

11. Run functional validation.

12. Observe.

13. Finalize or rollback.
```

---

# 50. DMS task types

DMS supports:

```text
full-load
cdc
full-load-and-cdc
```

For homogeneous data-migration workflows, AWS similarly presents full load, full load plus CDC and CDC-only options. ([AWS Documentation][24])

---

# 51. DMS endpoints

A DMS endpoint describes a database connection.

It may include:

```text
Engine
Hostname
Port
Database name
Username
Secret
SSL mode
Extra connection attributes
```

## Security recommendation

Store credentials in:

```text
AWS Secrets Manager
```

and grant the DMS role permission to retrieve the secret.

Do not place production passwords directly in Terraform source or shared scripts.

---

# 52. DMS network design

The DMS replication infrastructure must reach:

```text
Source database
Target database
Secrets Manager
KMS
S3, when used
CloudWatch Logs
Other target services
```

Architecture:

```text
On-premises database
        |
        | VPN or Direct Connect
        v
DMS subnet group
        |
        v
Target RDS/Aurora database
```

Check:

* Route tables.
* Security groups.
* Network ACLs.
* DNS.
* Database listener.
* Firewall.
* TLS certificate.
* VPC endpoints.
* Transit Gateway routing.

---

# 53. DMS Schema Conversion

DMS Schema Conversion is the current managed, web-based schema-conversion capability in AWS DMS.

It uses:

```text
Data providers
Instance profile
Migration project
```

It can:

* Assess source schema.
* Generate conversion reports.
* Convert schema objects.
* Display source and target SQL.
* Identify manual action items.
* Apply converted code.
* Export SQL scripts to S3.
* Add extension-pack components for selected unsupported functions.

DMS Schema Conversion is built on the AWS Schema Conversion Tool conversion engine, and AWS now recommends DMS Schema Conversion over the legacy standalone AWS SCT for new supported workflows. ([AWS Documentation][25])

---

# 54. Schema objects that may require conversion

Examples:

```text
Tables
Indexes
Views
Sequences
Stored procedures
Functions
Triggers
Packages
User-defined types
Synonyms
Database links
Materialized views
```

Simple table definitions may convert automatically.

Complex database-specific code often requires manual work.

---

# 55. Assessment report

The schema-conversion assessment report classifies:

```text
Automatically convertible objects
Objects requiring minor changes
Objects requiring manual conversion
Unsupported features
```

Example:

```text
Tables:
100% automatic

Indexes:
98% automatic

Stored procedures:
65% automatic

Oracle packages:
Significant manual work
```

DMS Schema Conversion provides action items and recommendations for objects it cannot convert automatically. ([AWS Documentation][26])

---

# 56. Generative AI schema conversion

DMS Schema Conversion can use generative AI for selected conversion paths and SQL object types to suggest conversions for objects that the rules engine did not fully convert.

Current documented paths include selected migrations such as:

```text
Oracle → PostgreSQL/Aurora PostgreSQL
SQL Server → PostgreSQL/Aurora PostgreSQL
SAP ASE → PostgreSQL/Aurora PostgreSQL
```

Availability is Region- and conversion-path-dependent, and generated output still requires testing and review. ([AWS Documentation][27])

## Never blindly apply generated database code

Review for:

* Transaction behavior.
* Exception handling.
* Data types.
* Locking.
* Performance.
* Security.
* Privileges.
* SQL semantics.
* Edge cases.

---

# 57. Schema-conversion process

```text
1. Create source data provider.

2. Create target data provider.

3. Store credentials securely.

4. Create instance profile.

5. Create migration project.

6. Run assessment.

7. Review action items.

8. Convert schema.

9. Manually fix unsupported code.

10. Apply schema to test target.

11. Run unit and integration tests.

12. Tune indexes and queries.

13. Apply production-ready schema.
```

DMS migration projects are serverless project resources that connect instance profiles and data providers for schema conversion and homogeneous migration workflows. ([AWS Documentation][28])

---

# 58. Data-type conversion risks

Example:

```text
Oracle NUMBER
        ↓
PostgreSQL NUMERIC or INTEGER
```

Questions:

* What is the precision?
* Can negative values occur?
* Can values exceed integer range?
* Are decimals expected?

Other common risks:

```text
Oracle DATE versus PostgreSQL timestamp
SQL Server DATETIME versus timestamp
Character encoding
Boolean representation
Empty string versus NULL
Binary large objects
Timezone conversion
Identity/sequence behavior
```

---

# 59. Large object migration

LOB means:

```text
Large Object
```

Examples:

* CLOB.
* BLOB.
* Images stored in database.
* Large documents.
* XML.
* JSON.

DMS LOB options can trade:

```text
Completeness
Performance
Memory usage
```

Test:

* Maximum LOB size.
* Inline LOB size.
* Truncation.
* Character encoding.
* Transfer speed.
* Target storage growth.

Never assume a standard DMS task setting will handle every large object efficiently.

---

# 60. Primary keys and CDC

CDC works best when tables have stable primary or unique keys.

Without keys:

* DMS may not identify rows efficiently.
* Updates may require broad scans.
* Deletes may be difficult.
* Target application performance may suffer.
* Replication may need engine-specific handling.

Before migration, inventory tables without:

```text
Primary key
Unique key
Reliable row identifier
```

---

# 61. Indexes, constraints and triggers

During full load, indexes and constraints can slow loading or reject rows loaded out of dependency order.

AWS DMS best practices commonly recommend delaying some secondary indexes, referential constraints and triggers until suitable stages of the migration, then ensuring required indexes are present before sustained CDC and enabling triggers at the correct cutover point. ([AWS Documentation][29])

## General sequence

```text
Create target schema
        ↓
Disable or delay selected constraints
        ↓
Run full load
        ↓
Build necessary indexes
        ↓
Apply CDC
        ↓
Enable constraints and triggers
        ↓
Validate
```

Exact handling depends on the database engine and application.

---

# 62. DMS data validation

Validation should include:

```text
Table row counts
Column-level comparisons
Checksums where practical
Null counts
Maximum/minimum values
Referential integrity
LOB completeness
Character encoding
Sequence values
Stored procedure tests
Application transactions
```

## Example

```sql
SELECT COUNT(*) FROM orders;
SELECT MIN(order_date), MAX(order_date) FROM orders;
SELECT SUM(order_total) FROM orders;
```

Run equivalent queries on source and target.

---

# 63. DMS monitoring

Important indicators include:

```text
FullLoadThroughputRowsSource
FullLoadThroughputRowsTarget
CDCIncomingChanges
CDCLatencySource
CDCLatencyTarget
FreeableMemory
CPUUtilization
FreeStorageSpace
NetworkTransmitThroughput
Task errors
Table statistics
```

## Source latency

How far DMS is behind reading the source changes.

## Target latency

How far the target is behind receiving and applying changes.

High target latency can indicate:

* Slow target database.
* Missing indexes.
* Constraints.
* Insufficient DMS capacity.
* Target locking.
* Large transactions.

---

# 64. DMS Serverless capacity

DMS Serverless uses DMS Capacity Units, or DCUs, and scales between configured minimum and maximum capacity levels. It evaluates source metadata and workload characteristics to provision replication resources and can subsequently scale according to utilisation. ([AWS Documentation][30])

Example:

```text
Minimum:
4 DCU

Maximum:
64 DCU
```

Set the minimum high enough to handle normal activity and sudden workload changes while scaling occurs.

---

# 65. DMS CLI example

Create table mappings:

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-public",
      "object-locator": {
        "schema-name": "public",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
}
```

Create task:

```bash
aws dms create-replication-task \
  --replication-task-identifier todoapp-postgres-migration \
  --source-endpoint-arn "$SOURCE_ENDPOINT_ARN" \
  --target-endpoint-arn "$TARGET_ENDPOINT_ARN" \
  --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
  --migration-type full-load-and-cdc \
  --table-mappings file://table-mappings.json \
  --replication-task-settings file://task-settings.json \
  --region ap-south-1
```

The DMS API and CLI support creating tasks with source and target endpoints, migration type, table mappings, replication settings and optional CDC start information. ([AWS Documentation][31])

---

# 66. Terraform DMS network resources

```hcl
resource "aws_dms_replication_subnet_group" "migration" {
  replication_subnet_group_id = "production-dms"

  replication_subnet_group_description = (
    "Private subnets for production database migration"
  )

  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "production-dms"
    Environment = "production"
  }
}

resource "aws_security_group" "dms" {
  name   = "production-dms"
  vpc_id = aws_vpc.main.id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

In a tightly controlled environment, replace broad egress with the exact database, DNS and service-endpoint requirements.

---

# 67. Terraform DMS replication instance

```hcl
resource "aws_dms_replication_instance" "migration" {
  replication_instance_id    = "production-migration"
  replication_instance_class = "dms.r5.large"

  allocated_storage = 100

  replication_subnet_group_id = (
    aws_dms_replication_subnet_group.migration.id
  )

  vpc_security_group_ids = [
    aws_security_group.dms.id
  ]

  publicly_accessible = false

  multi_az = true

  auto_minor_version_upgrade = true

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

For a short migration where availability risk is acceptable, a single-AZ replication instance may reduce cost. For critical long-running CDC, Multi-AZ should be evaluated.

---

# 68. Terraform DMS task concept

```hcl
resource "aws_dms_replication_task" "database" {
  replication_task_id = "todoapp-postgres-migration"

  migration_type = "full-load-and-cdc"

  replication_instance_arn = (
    aws_dms_replication_instance.migration.replication_instance_arn
  )

  source_endpoint_arn = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn = aws_dms_endpoint.target.endpoint_arn

  table_mappings = file("${path.module}/table-mappings.json")

  replication_task_settings = (
    file("${path.module}/task-settings.json")
  )

  tags = {
    Environment = "production"
    Application = "TodoApp"
  }
}
```

Do not store plaintext production database credentials directly inside Terraform configuration or unprotected Terraform state.

---

# 69. Database rollback

Before cutover:

```text
Source remains authoritative.
```

After cutover writes begin on target:

```text
Target begins diverging from source.
```

A rollback may require:

* Reverse replication.
* Application write freeze.
* Export of target-only transactions.
* Dual-write reconciliation.
* Manual business-data correction.
* Engine-specific replication tools.

## Simplest rollback model

```text
Do not allow target writes
until final go/no-go approval.
```

But this may extend downtime.

## Advanced rollback model

Set up reverse replication before cutover where supported and tested.

Do not improvise reverse replication during an incident.

---

# 70. Application and database migration together

Consider:

```text
Web:
Two Windows servers

Application:
Two Linux servers

Database:
Oracle

Files:
Shared NFS
```

Possible plan:

```text
Web and app servers:
MGN rehost to EC2

Database:
DMS Schema Conversion
Oracle → Aurora PostgreSQL

Data:
DMS full load plus CDC

Files:
DataSync to EFS
```

Cutover sequence:

```text
1. Complete server replication.
2. Complete file initial sync.
3. Complete database full load.
4. Maintain database CDC.
5. Test EC2 against test database and EFS.
6. Freeze application writes.
7. Run final file sync.
8. Allow CDC to reach zero lag.
9. Launch MGN cutover instances.
10. Update configuration to Aurora and EFS.
11. Change DNS.
12. Validate.
```

---

# 71. Migration-wave planning

A wave should consider:

```text
Application dependencies
Business criticality
Technical complexity
Data volume
Downtime tolerance
Team capacity
Change windows
Shared infrastructure
Rollback complexity
```

AWS guidance recommends combining 7-R classification with application interdependencies and technical complexity to create iterative wave plans. ([AWS Documentation][32])

---

# 72. Bad wave grouping

```text
Wave 1:
Every Linux server

Wave 2:
Every Windows server
```

This groups by operating system instead of business dependency.

Possible result:

```text
Application server moves in Wave 1
Database server moves in Wave 2
Application fails for two weeks
```

---

# 73. Better wave grouping

```text
Wave 1:
Internal HR portal
- Web
- App
- Database
- File share
- DNS
- Monitoring

Wave 2:
Customer notification platform
- API
- Worker
- Queue
- Database
- SMTP integration
```

Move complete business capabilities together where practical.

---

# 74. Pilot wave

The pilot wave should be:

```text
Real enough to expose problems
but not so critical that failure is disastrous.
```

Good pilot:

* Known owner.
* Moderate complexity.
* Representative technology.
* Small number of users.
* Clear test cases.
* Manageable rollback.

Avoid choosing only a trivial unused server.

A trivial pilot proves very little.

---

# 75. Wave maturity progression

## Wave 0: Foundation

```text
Landing zone
Connectivity
IAM
Security
Logging
Backup
MGN
DMS
Automation
```

## Wave 1: Pilot

```text
Small representative application
```

## Wave 2–3: Learning waves

```text
Moderate complexity
Validate process improvements
```

## Wave 4 onward: Migration factory

```text
Repeatable high-volume waves
```

## Final waves

```text
Most critical
Most complex
Shared infrastructure
```

---

# 76. Migration-wave size

A wave should be limited by:

* Number of servers.
* Number of applications.
* Number of database cutovers.
* Available engineers.
* Available testers.
* Business validation time.
* Rollback capability.
* Change-window duration.

Example:

```text
Wave:
20 servers
3 applications
1 database migration
1 file migration
```

is often more manageable than:

```text
Wave:
200 unrelated servers
```

during an early-stage program.

---

# 77. Migration factory

A migration factory uses repeatable roles, templates and automation.

Typical teams:

```text
Portfolio and assessment team
Landing-zone team
Network team
Security team
Server migration team
Database migration team
Application remediation team
Testing team
Cutover command team
Cloud operations team
```

## Factory principle

```text
Standardise what is repeatable.
Escalate what is exceptional.
```

---

# 78. Migration backlog

Maintain a tracker with:

| Application | Strategy   | Wave | Owner     | Status      | Blocker       |
| ----------- | ---------- | ---: | --------- | ----------- | ------------- |
| Todo App    | Replatform |    2 | DevOps    | Testing     | DB validation |
| HR Portal   | Rehost     |    3 | HR IT     | Replicating | Firewall      |
| Reporting   | Refactor   |    5 | Data Team | Assessment  | Data model    |
| Old CRM     | Retire     |    1 | Sales IT  | Approved    | Archive       |

Statuses might include:

```text
Discovered
Assessed
Planned
Replicating
Testing
Ready for cutover
Cutover
Hypercare
Completed
Retired
Blocked
```

---

# 79. Cutover runbook

Every production cutover should have a minute-by-minute runbook.

Example:

```text
22:00:
Start change freeze.

22:05:
Stop scheduled jobs.

22:10:
Stop application writes.

22:15:
Confirm database CDC lag zero.

22:20:
Run final DataSync task.

22:30:
Launch MGN cutover instances.

22:45:
Run infrastructure checks.

23:00:
Update application configuration.

23:10:
Update Route 53 records.

23:20:
Run smoke tests.

23:40:
Business owner validates.

00:00:
Go/no-go decision.

00:30:
Start hypercare.
```

---

# 80. Go/no-go criteria

## Go criteria

```text
Replication lag accepted
All instances healthy
Database validation passed
Application smoke test passed
Monitoring active
Backup active
Business owner approved
No critical security finding
```

## No-go criteria

```text
Data mismatch
Unknown dependency
Critical application error
Unacceptable performance
Rollback unavailable
Security control missing
Business owner unavailable
```

Go/no-go decisions must be objective, not emotional.

---

# 81. DNS cutover

Migration traffic is often switched using:

* Route 53 record changes.
* Load-balancer target changes.
* Reverse-proxy configuration.
* Global Accelerator.
* Firewall NAT changes.
* Application configuration.

Before migration:

```text
Lower DNS TTL in advance.
```

Example:

```text
Normal TTL:
3600 seconds

Before cutover:
300 seconds
```

Lower the TTL early enough for existing cached records to expire.

DNS rollback is not instantaneous because resolvers may continue caching older values.

---

# 82. Application validation

Validation layers:

## Infrastructure

```text
Instance running
Disks mounted
CPU and memory normal
```

## Network

```text
DNS
Security groups
Ports
External integrations
```

## Application

```text
Login
Create transaction
Update transaction
Read transaction
Delete or cancel
Background processing
```

## Data

```text
Row counts
Recent transactions
Files
Permissions
Reports
```

## Operations

```text
Logs
Metrics
Alarms
Backup
Patch
Security agent
```

## Business

```text
Application owner approves critical workflow.
```

---

# 83. Performance baseline

Measure before migration:

```text
CPU peak
Memory peak
Disk IOPS
Disk latency
Network throughput
Request latency
Database query latency
Concurrent users
Batch duration
```

Measure again after migration.

Without a baseline, teams often argue:

```text
“It feels slower.”
```

with no objective evidence.

---

# 84. Hypercare

Hypercare is the increased-support period after cutover.

During hypercare:

* Monitor dashboards continuously.
* Review errors.
* Watch resource saturation.
* Check DMS or migration cleanup.
* Confirm backups.
* Review security findings.
* Keep application and infrastructure teams available.
* Track every incident.
* Avoid unnecessary changes.

Hypercare may last:

```text
Several hours
Several days
One business cycle
```

depending on application criticality.

---

# 85. Decommissioning source systems

Do not delete source infrastructure immediately after cutover.

Recommended progression:

```text
1. Stop production traffic.

2. Keep source powered on but isolated.

3. Observe AWS workload.

4. Confirm backup and recovery.

5. Archive required data.

6. Remove licences and monitoring.

7. Obtain owner approval.

8. Shut down source.

9. Observe again.

10. Delete after retention period.
```

Decommissioning is part of migration value.

Leaving every source server running indefinitely creates:

* Double cost.
* Security exposure.
* Configuration confusion.
* Licence waste.
* Split-brain risk.

---

# 86. Production migration checklist

```text
[ ] Application inventory is complete
[ ] Every server has an owner
[ ] Dependencies are mapped
[ ] 7-R strategy is assigned
[ ] Target architecture is approved
[ ] Landing zone is ready
[ ] Connectivity is tested
[ ] DNS plan is documented
[ ] IAM roles are ready
[ ] KMS keys are ready
[ ] Monitoring is ready
[ ] Backup is ready
[ ] MGN staging subnet is isolated
[ ] MGN replication is healthy
[ ] Test launches are completed
[ ] Post-launch actions are tested
[ ] DMS assessment is completed
[ ] Schema conversion action items are resolved
[ ] Full-load validation is complete
[ ] CDC lag is monitored
[ ] LOB handling is tested
[ ] Source and target row counts match
[ ] Wave plan reflects dependencies
[ ] Cutover runbook is approved
[ ] Rollback runbook is approved
[ ] Go/no-go criteria are measurable
[ ] Business owner is available
[ ] Source write freeze is planned
[ ] Final synchronization is planned
[ ] DNS TTL is reduced in advance
[ ] Security validation is complete
[ ] Performance baseline exists
[ ] Hypercare staffing is confirmed
[ ] Source decommission date is assigned
```

---

# 87. Certification-focused understanding

## AWS Cloud Practitioner

Understand:

```text
AWS Transform:
Discovery, assessment and transformation experience

AWS Transform MGN:
Server lift-and-shift migration

AWS DMS:
Database migration

DataSync:
File migration
```

## Solutions Architect Associate

Understand:

```text
7 Rs
Rehost versus replatform
MGN block replication
Staging subnet
Test and cutover
DMS full load
CDC
Full load plus CDC
Homogeneous versus heterogeneous
Schema conversion
```

## DevOps Engineer Professional

Understand:

```text
Wave planning
Migration factory
Post-launch actions
MGN CLI automation
DMS task tuning
Serverless capacity
Schema action items
Monitoring and alarms
Cutover runbooks
Rollback
Cross-account migration
Infrastructure as Code
Decommissioning
```

---

# 88. Interview questions

## Question 1: What are the 7 Rs?

**Answer:**

Retire, retain, rehost, relocate, repurchase, replatform and refactor or re-architect.

## Question 2: What is the difference between rehost and replatform?

**Answer:**

Rehost moves the workload with minimal change, commonly to EC2. Replatform introduces selected managed-service or platform improvements without fully redesigning the application.

## Question 3: What is AWS Transform MGN?

**Answer:**

It is AWS’s block-level server-rehosting service for migrating supported physical, virtual and cloud servers to Amazon EC2 with minimal downtime.

## Question 4: What happened to AWS Application Migration Service?

**Answer:**

It was renamed AWS Transform MGN in June 2026. The MGN APIs and replication capabilities remain.

## Question 5: What is the MGN staging area?

**Answer:**

It is the AWS subnet and temporary infrastructure containing replication servers and staging storage used to receive replicated blocks before test and cutover launches.

## Question 6: Does MGN replicate files individually?

**Answer:**

No. It continuously replicates disk blocks.

## Question 7: What is the purpose of an MGN test launch?

**Answer:**

It launches an isolated EC2 copy from replicated data so boot, application, network, security and performance can be tested before production cutover.

## Question 8: What happens when MGN cutover is finalized?

**Answer:**

Replication stops, migration-managed replication resources are cleaned up and the launched cutover EC2 instance remains.

## Question 9: Does MGN replicate AWS cutover changes back on-premises?

**Answer:**

No. A stateful rollback requires a separate data-reconciliation or reverse-replication strategy.

## Question 10: What is AWS DMS?

**Answer:**

AWS Database Migration Service moves database data between supported sources and targets using full load, CDC or full load plus CDC.

## Question 11: What is CDC?

**Answer:**

Change Data Capture reads ongoing committed changes from the source transaction log and applies them to the target.

## Question 12: What is the difference between full load and full load plus CDC?

**Answer:**

Full load copies existing data only. Full load plus CDC copies existing data while also capturing and applying changes made during the migration.

## Question 13: What is a homogeneous migration?

**Answer:**

A migration between the same or compatible database engines, such as PostgreSQL to Amazon RDS for PostgreSQL.

## Question 14: What is a heterogeneous migration?

**Answer:**

A migration that changes database engines, such as Oracle to Aurora PostgreSQL, requiring schema conversion and data movement.

## Question 15: What is DMS Schema Conversion?

**Answer:**

It assesses and converts source database schemas and code into forms compatible with a selected target database.

## Question 16: Why are primary keys important for CDC?

**Answer:**

They let DMS identify the exact target row for updates and deletes efficiently and reliably.

## Question 17: What is a migration wave?

**Answer:**

A planned group of dependent applications or move groups migrated during the same cutover window.

## Question 18: What makes a good pilot wave?

**Answer:**

It should be representative enough to expose real problems but small and low-risk enough to recover safely.

## Question 19: What is hypercare?

**Answer:**

It is a period of heightened monitoring and engineering support immediately after production cutover.

## Question 20: Why should the source not be deleted immediately?

**Answer:**

An observation and recovery period is needed to confirm application stability, data integrity, backups and business approval before final decommissioning.

---

# 89. Never-forget revision

```text
AWS Transform:
Current assessment and transformation experience.

AWS Transform MGN:
Block-level server rehosting.

Migration Hub:
Legacy for existing customers; closed to new customers.

Migration Evaluator:
Business-case and right-sizing assessment.

DMS:
Database data migration.

DMS Schema Conversion:
Database schema and code conversion.

Rehost:
Move with minimal change.

Replatform:
Move with selected platform improvements.

Refactor:
Redesign for cloud-native architecture.

Move group:
Tightly dependent resources that move together.

Wave:
One or more move groups migrated together.

MGN staging area:
Temporary replication infrastructure.

Test launch:
Isolated validation copy.

Cutover launch:
Production migration instance.

Full load:
Copy existing database data.

CDC:
Replicate ongoing changes.

Full load plus CDC:
Initial copy plus continuing replication.

Homogeneous:
Same database engine family.

Heterogeneous:
Different database engines.

Hypercare:
Heightened support after cutover.
```

## One-line memory trick

```text
Discover what exists.
Choose the correct R.
Build the landing zone.
Replicate and test.
Freeze writes.
Cut over.
Validate.
Observe.
Then decommission.
```

## Lesson 36 outcome

You can now design a migration where:

```text
Unknown server estate exists
    → AWS Transform discovery builds inventory and dependencies.

Business needs a cost case
    → AWS Transform assessment or Migration Evaluator rightsizes targets.

Virtual servers must move quickly
    → AWS Transform MGN continuously replicates disk blocks.

Application must be tested safely
    → MGN launches isolated test instances.

Database downtime must be minimal
    → DMS performs full load plus CDC.

Database engine will change
    → DMS Schema Conversion converts schema and code.

Hundreds of workloads must move
    → Applications are grouped into dependency-based waves.

Production cutover fails
    → A tested rollback runbook restores the authoritative environment.

Migration succeeds
    → Hypercare confirms stability before source decommissioning.
```

**Next lesson: Lesson 37 — AWS Organizations, Control Tower, Landing Zone Accelerator, multi-account architecture, SCP guardrails, account vending and enterprise cloud governance.**

[1]: https://aws.amazon.com/about-aws/whats-new/2026/06/aws-transform-mgn-rebrand/?utm_source=chatgpt.com "AWS Application Migration Service is now AWS Transform ..."
[2]: https://docs.aws.amazon.com/migrationhub-strategy/latest/userguide/migrationhub-availability-change.html?utm_source=chatgpt.com "AWS Migration Hub availability change"
[3]: https://docs.aws.amazon.com/prescriptive-guidance/latest/migration-database-rehost-tools/introduction.html?utm_source=chatgpt.com "Choosing a migration tool for rehosting databases"
[4]: https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/migration-strategies.html?utm_source=chatgpt.com "About the migration strategies - AWS Prescriptive Guidance"
[5]: https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-migration-playbook/task-one-pattern-validation.html?utm_source=chatgpt.com "Task 1: Validating the migration patterns and metadata"
[6]: https://docs.aws.amazon.com/transform/latest/userguide/discovery-tool.html?utm_source=chatgpt.com "Discovery tool - AWS Transform"
[7]: https://docs.aws.amazon.com/transform/latest/userguide/transform-vmware-review-groupings-and-waves.html?utm_source=chatgpt.com "Build migration plan - AWS Transform"
[8]: https://docs.aws.amazon.com/transform/latest/userguide/transform-app-assessments.html?utm_source=chatgpt.com "Migration assessments - AWS Transform"
[9]: https://aws.amazon.com/blogs/migration-and-modernization/category/migration/migration-evaluator/?utm_source=chatgpt.com "MIgration Evaluator | Migration & Modernization - AWS"
[10]: https://docs.aws.amazon.com/mgn/latest/ug/what-is-mgn.html?utm_source=chatgpt.com "AWS Transform MGN - AWS Documentation"
[11]: https://docs.aws.amazon.com/mgn/latest/ug/Agent-Related-FAQ.html?utm_source=chatgpt.com "Agent related - AWS Transform MGN"
[12]: https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html?utm_source=chatgpt.com "Network requirements for MGN"
[13]: https://docs.aws.amazon.com/mgn/latest/ug/Replication-Related-FAQ.html?utm_source=chatgpt.com "Replication related - AWS Transform MGN"
[14]: https://docs.aws.amazon.com/mgn/latest/ug/migration-dashboard.html?utm_source=chatgpt.com "Monitor the server in the migration lifecycle"
[15]: https://docs.aws.amazon.com/mgn/latest/ug/post-launch-settings.html?utm_source=chatgpt.com "Post-launch template - AWS Transform MGN"
[16]: https://docs.aws.amazon.com/mgn/latest/ug/launch-cutover-gs.html?utm_source=chatgpt.com "Launching a cutover instance - AWS Transform MGN"
[17]: https://docs.aws.amazon.com/mgn/latest/ug/launch-cutover.html?utm_source=chatgpt.com "Launching cutover instances - AWS Transform MGN"
[18]: https://docs.aws.amazon.com/cli/latest/reference/mgn/ "mgn — AWS CLI 2.36.8 Command Reference"
[19]: https://docs.aws.amazon.com/mgn/latest/ug/Troubleshooting-Communication-Errors.html?utm_source=chatgpt.com "Troubleshooting communication errors"
[20]: https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html?utm_source=chatgpt.com "What is AWS Database Migration Service? - AWS Database Migration Service"
[21]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Serverless.html?utm_source=chatgpt.com "Working with AWS DMS Serverless - AWS Database Migration Service"
[22]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Task.CDC.html?utm_source=chatgpt.com "Creating tasks for ongoing replication using AWS DMS"
[23]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.Creating.html?utm_source=chatgpt.com "Creating a task - AWS Database Migration Service"
[24]: https://docs.aws.amazon.com/dms/latest/userguide/dm-migrating-data-create.html?utm_source=chatgpt.com "Creating a data migration in AWS DMS"
[25]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_SchemaConversion.html?utm_source=chatgpt.com "Converting database schemas using DMS ..."
[26]: https://docs.aws.amazon.com/dms/latest/userguide/assessment-reports-view.html?utm_source=chatgpt.com "Viewing your database migration assessment report for ..."
[27]: https://docs.aws.amazon.com/dms/latest/userguide/schema-conversion-convert.databaseobjects.html?utm_source=chatgpt.com "Converting database objects with generative AI"
[28]: https://docs.aws.amazon.com/dms/latest/userguide/migration-projects.html?utm_source=chatgpt.com "Working with data providers, instance profiles, and migration projects in AWS DMS - AWS Database Migration Service"
[29]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_BestPractices.html?utm_source=chatgpt.com "Best practices for AWS Database Migration Service"
[30]: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Serverless.Components.html?utm_source=chatgpt.com "AWS DMS Serverless components - AWS Database Migration Service"
[31]: https://docs.aws.amazon.com/dms/latest/APIReference/API_CreateReplicationTask.html?utm_source=chatgpt.com "CreateReplicationTask - AWS Database Migration Service"
[32]: https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-migration/detailed-portfolio-discovery.html?utm_source=chatgpt.com "Detailed portfolio discovery - AWS Prescriptive Guidance"
