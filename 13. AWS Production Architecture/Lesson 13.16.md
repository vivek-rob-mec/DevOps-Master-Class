# AWS Masterclass — Lesson 15

## Hybrid Cloud and Migration — VPN, Direct Connect, Transit Gateway, Hybrid DNS, Storage Gateway, DataSync, DMS, MGN, Snow Family, CIDR Planning, and Migration Strategy

Today we learn how companies connect their existing data center to AWS and migrate workloads safely.

This lesson is very important for **Solution Architect Associate**, **DevOps Engineer Professional**, and real enterprise work because many companies do not move everything to AWS in one day.

They usually start with:

```text id="hybrid-start"
on-premises data center
existing servers
existing databases
existing DNS
existing users
existing network
existing firewall
existing compliance rules
```

Then they gradually move to:

```text id="cloud-target"
AWS VPCs
private subnets
managed databases
S3 storage
CloudFront
ECS/EKS/Lambda
centralized monitoring
automated deployments
```

---

# 1. What is hybrid cloud?

Hybrid cloud means:

```text id="hybrid-simple"
Some systems run on-premises.
Some systems run in AWS.
Both environments communicate securely.
```

Example:

```text id="hybrid-example"
Company data center:
  Oracle database
  Active Directory
  internal DNS
  legacy application

AWS:
  new web app
  S3 storage
  ECS backend
  analytics system
```

Hybrid cloud is not only networking. It includes:

```text id="hybrid-parts"
network connectivity
routing
DNS resolution
identity integration
data transfer
database migration
security controls
monitoring
backup
disaster recovery
cutover planning
rollback planning
```

---

# 2. The first hybrid rule: CIDR must not overlap

This is the rule you must never forget:

```text id="cidr-rule"
AWS VPC CIDR must not overlap with on-premises CIDR.
```

Bad design:

```text id="bad-cidr"
On-premises:
  10.0.0.0/16

AWS VPC:
  10.0.0.0/16
```

Why bad?

```text id="cidr-problem"
When a packet is going to 10.0.5.10,
the router cannot clearly know whether that IP is on-premises or in AWS.
```

Good design:

```text id="good-cidr"
On-premises:
  172.16.0.0/16

AWS dev:
  10.10.0.0/16

AWS staging:
  10.20.0.0/16

AWS prod:
  10.30.0.0/16

AWS shared services:
  10.40.0.0/16
```

AWS explicitly recommends non-overlapping CIDR blocks when connecting VPCs to a common on-premises network with Site-to-Site VPN. ([AWS Documentation][1])

---

# 3. Hybrid architecture mental model

A simple hybrid architecture:

```text id="hybrid-arch"
On-premises data center
  ├── users
  ├── DNS
  ├── Active Directory
  ├── legacy apps
  └── databases

      ↓ secure connectivity

AWS
  ├── VPC
  ├── public subnets
  ├── private app subnets
  ├── private database subnets
  ├── Route 53 Resolver endpoints
  ├── S3
  ├── RDS
  ├── ECS/EKS/EC2
  └── CloudWatch/CloudTrail
```

Production flow example:

```text id="hybrid-prod-flow"
On-prem user
  ↓
corporate network
  ↓
VPN / Direct Connect
  ↓
AWS Transit Gateway
  ↓
AWS VPC private app subnet
  ↓
internal application
```

---

# 4. AWS Site-to-Site VPN

AWS Site-to-Site VPN creates an encrypted connection between your on-premises network and AWS.

Simple meaning:

```text id="vpn-simple"
VPN = secure encrypted tunnel over the internet.
```

AWS Site-to-Site VPN supports IPsec VPN connections. AWS describes a VPN connection as the connection between your VPC and your on-premises network, and each VPN connection includes two VPN tunnels that can be used for high availability. ([AWS Documentation][1])

VPN components:

```text id="vpn-components"
Customer gateway:
  AWS representation of your on-prem router/firewall

Customer gateway device:
  actual router/firewall on your side

Target gateway:
  AWS-side VPN endpoint

Virtual private gateway:
  AWS VPN endpoint attached to one VPC

Transit gateway:
  central hub that can also terminate VPN for multiple VPCs
```

---

# 5. VPN static routing vs dynamic routing

## Static routing

You manually define routes.

Example:

```text id="static-route"
AWS route:
  172.16.0.0/16 → VPN

On-prem route:
  10.30.0.0/16 → VPN
```

Good for:

```text id="static-good"
small environments
few networks
simple labs
predictable routing
```

Bad for:

```text id="static-bad"
many VPCs
frequent network changes
large enterprise routing
```

---

## Dynamic routing with BGP

BGP means:

```text id="bgp"
Border Gateway Protocol
```

Simple meaning:

```text id="bgp-simple"
Routers exchange route information automatically.
```

Good for:

```text id="bgp-good"
enterprise networks
failover
many routes
VPN + Direct Connect
Transit Gateway designs
```

AWS Site-to-Site VPN supports BGP-related options such as custom private ASN for the Amazon side of a BGP session, and Transit Gateway VPN route propagation uses BGP for on-premises routing. ([AWS Documentation][1])

---

# 6. VPN high availability

Each Site-to-Site VPN connection has two tunnels.

Production rule:

```text id="vpn-ha-rule"
Configure both VPN tunnels on your customer gateway device.
Monitor both tunnels.
Do not rely on only one tunnel.
```

Bad:

```text id="bad-vpn-ha"
Tunnel 1 configured
Tunnel 2 ignored
No CloudWatch alarm
```

Good:

```text id="good-vpn-ha"
Tunnel 1 active
Tunnel 2 standby/active depending router
CloudWatch tunnel state alarm
documented failover test
```

Use VPN when:

```text id="vpn-use"
you need quick hybrid connectivity
you need encrypted connectivity over internet
traffic is moderate
you are starting migration
you need backup path for Direct Connect
```

---

# 7. AWS Direct Connect

Direct Connect is a dedicated network connection from your environment to AWS.

Simple meaning:

```text id="dx-simple"
Direct Connect = private dedicated network link to AWS.
```

AWS Direct Connect links your internal network to a Direct Connect location over Ethernet fiber, lets you create virtual interfaces to AWS public services or Amazon VPC, and bypasses internet service providers in your network path. ([AWS Documentation][2])

Direct Connect components:

```text id="dx-components"
Direct Connect connection:
  physical/network connection at DX location

Virtual interface:
  logical interface over the connection

Private VIF:
  private IP access to VPC

Public VIF:
  public AWS service access such as S3 public endpoints

Transit VIF:
  access to Transit Gateway through Direct Connect gateway

Direct Connect gateway:
  global DX construct to connect DX to VPCs/TGWs across regions/accounts
```

AWS Direct Connect documentation lists private, public, and transit virtual interface types; private VIF accesses a VPC using private IPs, public VIF accesses public AWS services, and transit VIF connects to Transit Gateways associated with Direct Connect gateways. ([AWS Documentation][2])

---

# 8. VPN vs Direct Connect

| Requirement    | Site-to-Site VPN                      | Direct Connect                                                           |
| -------------- | ------------------------------------- | ------------------------------------------------------------------------ |
| Network path   | internet encrypted tunnel             | dedicated private link                                                   |
| Setup speed    | faster                                | slower due physical/provider process                                     |
| Cost           | usually lower to start                | higher, port-hour/data-related                                           |
| Predictability | depends on internet path              | more predictable                                                         |
| Encryption     | IPsec encryption                      | not inherently same as VPN; can combine with VPN/MACsec where applicable |
| Good for       | quick start, backup, moderate traffic | enterprise production, high-volume predictable traffic                   |

Direct Connect has billing elements such as port hours and outbound data transfer, so it should be planned deliberately. ([AWS Documentation][2])

Production pattern:

```text id="vpn-dx-prod"
Use Direct Connect as primary private connectivity.
Use Site-to-Site VPN as backup.
Use BGP for route failover.
Use Transit Gateway for multi-VPC routing.
```

---

# 9. Transit Gateway

Transit Gateway is a central network hub.

Simple meaning:

```text id="tgw-simple"
Transit Gateway = cloud router connecting many VPCs and on-prem networks.
```

Without Transit Gateway:

```text id="without-tgw"
VPC A peers with VPC B
VPC A peers with VPC C
VPC B peers with VPC C
VPN connects separately to many VPCs
routing becomes messy
```

With Transit Gateway:

```text id="with-tgw"
VPC A
VPC B
VPC C
VPN
Direct Connect
  ↓
Transit Gateway central hub
```

AWS describes Transit Gateway as a network transit hub used to interconnect VPCs and on-premises networks. Transit Gateway supports attachments such as VPCs, Direct Connect gateways, VPN connections, peering connections, and more. ([AWS Documentation][3])

---

# 10. Transit Gateway route tables

Transit Gateway has its own route tables.

Do not confuse:

```text id="route-table-confuse"
VPC route table:
  subnet-level routing inside VPC

Transit Gateway route table:
  routing between TGW attachments
```

Example:

```text id="tgw-route-example"
TGW route table:
  10.10.0.0/16 → dev VPC attachment
  10.20.0.0/16 → staging VPC attachment
  10.30.0.0/16 → prod VPC attachment
  172.16.0.0/16 → VPN attachment
```

Transit Gateway route tables can include dynamic and static routes that decide the next hop based on destination IP, and VPC, VPN, or Direct Connect gateway attachments can propagate routes. ([AWS Documentation][3])

Production design:

```text id="tgw-segmentation"
TGW route table for prod
TGW route table for non-prod
TGW route table for shared services
TGW route table for inspection/security
```

This allows segmentation:

```text id="segmentation-example"
dev can reach shared services
staging can reach shared services
prod can reach shared services
dev cannot directly reach prod
```

---

# 11. Hybrid DNS with Route 53 Resolver

Networking connects IPs.

DNS connects names.

Hybrid DNS problem:

```text id="dns-problem"
AWS app needs to resolve:
  db.corp.local

On-prem app needs to resolve:
  service.internal.yourdatascientist.tech
```

Route 53 Resolver endpoints solve this.

AWS Route 53 Resolver supports inbound and outbound endpoints for forwarding DNS queries between VPC Resolver and DNS resolvers on connected networks. Inbound endpoints allow on-prem DNS resolvers to forward queries to Route 53 Resolver, while outbound endpoints let VPC Resolver forward selected queries to on-prem resolvers through Resolver rules. ([AWS Documentation][4])

---

## Inbound Resolver endpoint

Direction:

```text id="inbound-direction"
On-prem DNS
  ↓
Route 53 Resolver inbound endpoint
  ↓
AWS private hosted zone / VPC DNS
```

Use when:

```text id="inbound-use"
on-prem systems need to resolve AWS private names
```

Example:

```text id="inbound-example"
On-prem server resolves:
  app.internal.yourdatascientist.tech
```

---

## Outbound Resolver endpoint

Direction:

```text id="outbound-direction"
AWS VPC
  ↓
Route 53 Resolver outbound endpoint
  ↓
on-prem DNS
```

Use when:

```text id="outbound-use"
AWS systems need to resolve on-prem names
```

Example:

```text id="outbound-example"
EC2 resolves:
  oracle01.corp.local
```

---

# 12. Hybrid DNS design pattern

```text id="hybrid-dns-arch"
On-prem DNS servers
  ↑                         ↓
  |                         |
Resolver inbound        Resolver outbound
endpoint                endpoint
  |                         |
AWS VPC Resolver + private hosted zones
```

Production DNS rules:

```text id="dns-rules"
Do not hardcode IP addresses.
Use conditional forwarding.
Use private hosted zones for AWS internal names.
Use Route 53 Resolver rules for on-prem domains.
Allow TCP/UDP 53 only from trusted DNS servers.
Monitor endpoint health and query behavior.
```

AWS notes that forwarding private DNS queries directly to a VPC CIDR + 2 resolver address from on-premises is not supported, and recommends Resolver inbound endpoints instead. ([AWS Documentation][4])

---

# 13. Storage Gateway

Storage Gateway connects on-premises storage workflows to AWS storage.

Simple meaning:

```text id="sgw-simple"
Storage Gateway lets on-premises apps use AWS storage through familiar storage interfaces.
```

AWS Storage Gateway connects an on-premises software appliance with cloud-based storage and provides secure integration between on-premises IT environments and AWS storage infrastructure, including use cases like backup and disaster recovery. ([AWS Documentation][5])

Use cases:

```text id="sgw-use"
on-prem backup to AWS
file shares backed by S3
tape replacement
low-latency local cache with cloud-backed storage
gradual storage migration
```

Gateway types to remember:

```text id="sgw-types"
Amazon S3 File Gateway:
  file interface to S3 objects

Amazon FSx File Gateway:
  access FSx for Windows File Server from on-prem

Volume Gateway:
  block storage volumes backed by cloud snapshots

Tape Gateway:
  virtual tape library replacement for backup software
```

---

# 14. DataSync

DataSync moves file and object data.

Simple meaning:

```text id="datasync-simple"
DataSync = managed data transfer service for moving files/objects between storage systems.
```

AWS DataSync is an online data movement service for transferring file or object data to, from, and between AWS storage services. ([AWS Documentation][6])

Use cases:

```text id="datasync-use"
on-prem NFS/SMB to S3
on-prem file system to EFS
on-prem file system to FSx
S3 to EFS
EFS to EFS
migration waves
periodic sync
data lake ingestion
```

DataSync mental model:

```text id="datasync-flow"
Source location
  ↓
DataSync task
  ↓
Destination location
```

For on-prem transfers, you usually deploy a DataSync agent near the source storage.

---

# 15. Storage Gateway vs DataSync

| Requirement                                         | Use Storage Gateway       | Use DataSync |
| --------------------------------------------------- | ------------------------- | ------------ |
| On-prem app keeps using file/tape/storage interface | yes                       | no           |
| Ongoing hybrid access with local cache              | yes                       | sometimes    |
| One-time/periodic bulk data migration               | possible, but not primary | yes          |
| Move NFS/SMB/object data to AWS                     | not mainly migration task | yes          |
| Backup software virtual tape replacement            | yes                       | no           |
| File share backed by S3                             | yes                       | no           |

Simple rule:

```text id="sgw-datasync-rule"
Storage Gateway:
  hybrid access pattern

DataSync:
  data movement/migration pattern
```

---

# 16. Database Migration Service — DMS

DMS migrates databases.

Simple meaning:

```text id="dms-simple"
DMS moves data from source database to target database.
```

AWS DMS can migrate relational databases, data warehouses, NoSQL databases, and other data stores into AWS or between cloud and on-premises combinations. It supports one-time migrations and ongoing change replication to keep source and target in sync. ([AWS Documentation][7])

DMS components:

```text id="dms-components"
Source endpoint:
  old database

Target endpoint:
  new database

Replication instance:
  migration worker

Migration task:
  rules for what data/tables to move

Full load:
  copy existing data

CDC:
  change data capture, keeps syncing ongoing changes
```

Use DMS for:

```text id="dms-use"
Oracle to RDS PostgreSQL
MySQL on EC2 to RDS MySQL
on-prem PostgreSQL to Aurora PostgreSQL
SQL Server to RDS SQL Server
database modernization with schema conversion planning
minimal-downtime migration patterns
```

---

# 17. DMS vs backup/restore

| Requirement                     | Backup/restore | DMS                                 |
| ------------------------------- | -------------- | ----------------------------------- |
| Simple same-engine move         | good           | also possible                       |
| Minimal downtime                | harder         | better with CDC                     |
| Ongoing replication             | no             | yes                                 |
| Cross-engine migration          | limited        | yes, usually with schema conversion |
| Table filtering/transformation  | limited        | yes                                 |
| Large enterprise migration wave | manual-heavy   | designed for migration tasks        |

Important:

```text id="dms-important"
DMS moves data.
Schema conversion and application compatibility still need planning.
```

AWS DMS can discover source stores, convert schemas, and migrate data, but migrations still require careful validation of schemas, code, cutover, and application behavior. ([AWS Documentation][7])

---

# 18. Application Migration Service / AWS Transform MGN

You may see both names:

```text id="mgn-names"
Older/common name:
  AWS Application Migration Service

Current AWS branding:
  AWS Transform MGN
```

AWS release notes say AWS Application Migration Service was rebranded to AWS Transform MGN in June 2026, with MGN capabilities unchanged. ([AWS Documentation][8])

Simple meaning:

```text id="mgn-simple"
MGN migrates servers by replicating their block storage to AWS,
then launching test/cutover EC2 instances.
```

AWS Prescriptive Guidance describes MGN as a common tool for large lift-and-shift migrations that moves data from directly attached block storage to corresponding EBS storage in AWS, using continuous data protection with near-seconds RPO and minutes RTO. ([AWS Documentation][9])

Use MGN for:

```text id="mgn-use"
physical server to EC2
VMware VM to EC2
Hyper-V VM to EC2
large lift-and-shift migration
server rehost strategy
fast migration with minimal app changes
```

MGN is not ideal for:

```text id="mgn-not"
NAS/shared file storage migration
deep application modernization
non-x86 platforms
apps that should be rewritten instead of lifted
```

AWS guidance notes that the block-level replication method does not support NAS/shared drives like NFS or SMB shares and focuses on directly attached block-level storage. ([AWS Documentation][9])

---

# 19. AWS Snow Family

Snow Family is for physical data transport and edge use cases.

Simple meaning:

```text id="snow-simple"
When the network is too slow, ship a secure AWS device.
```

AWS Snow Family includes devices such as Snowcone, Snowball Edge, and Snowmobile, and AWS documentation describes them as physical devices for transferring very large amounts of data into and out of AWS, often with built-in compute capabilities. ([AWS Documentation][10])

Use Snow Family when:

```text id="snow-use"
internet transfer would take too long
bandwidth is limited/unreliable
data volume is huge
edge location has poor connectivity
you need local compute/storage in rugged environment
```

Simple selection:

```text id="snow-selection"
Small portable edge/migration:
  Snowcone

Large data transfer and edge compute:
  Snowball Edge

Very large exabyte-scale transfer:
  Snowmobile
```

---

# 20. Migration strategies — the 7 Rs

Before migrating, choose the right strategy.

AWS Prescriptive Guidance lists seven migration strategies, known as the **7 Rs**: Retire, Retain, Rehost, Relocate, Repurchase, Replatform, and Refactor/re-architect. ([AWS Documentation][11])

| Strategy   | Simple meaning                    | Example                              |
| ---------- | --------------------------------- | ------------------------------------ |
| Retire     | remove app                        | unused internal tool                 |
| Retain     | keep as-is for now                | compliance-bound legacy system       |
| Rehost     | lift and shift                    | VM to EC2 using MGN                  |
| Relocate   | move platform with minimal change | VMware workload relocation pattern   |
| Repurchase | replace with SaaS                 | move CRM to SaaS                     |
| Replatform | small optimization                | app to EC2, DB to RDS                |
| Refactor   | redesign                          | monolith to microservices/serverless |

---

# 21. Rehost vs Replatform vs Refactor

These three confuse many beginners.

## Rehost

```text id="rehost"
Move with minimal change.
```

Example:

```text id="rehost-example"
On-prem VM
  ↓ MGN
EC2 instance
```

Good when:

```text id="rehost-good"
deadline is tight
many servers
unknown app internals
first migration wave
data center exit
```

---

## Replatform

```text id="replatform"
Move with small cloud improvements.
```

Example:

```text id="replatform-example"
App server:
  EC2

Database:
  on-prem MySQL → Amazon RDS MySQL
```

Good when:

```text id="replatform-good"
you can improve operations without rewriting app
managed database makes sense
reduce patching burden
improve backup/failover
```

---

## Refactor / re-architect

```text id="refactor"
Change application architecture significantly.
```

Example:

```text id="refactor-example"
Legacy monolith
  ↓
ECS microservices + SQS + DynamoDB + Lambda
```

Good when:

```text id="refactor-good"
app needs scale
business is investing in modernization
legacy architecture blocks change
cloud-native features create value
```

---

# 22. Migration phases

A real migration is usually:

```text id="migration-phases"
1. Assess
2. Mobilize
3. Migrate and modernize
4. Operate and optimize
```

Practical version:

```text id="practical-phases"
Discover:
  inventory apps, servers, DBs, dependencies

Assess:
  choose 7R strategy and target architecture

Prepare:
  landing zone, networking, IAM, logging, backups

Pilot:
  migrate low-risk workload first

Wave planning:
  group related apps and dependencies

Replicate:
  sync data/servers

Test:
  functional, performance, security, DR

Cutover:
  switch traffic/users

Stabilize:
  monitor, fix, optimize

Decommission:
  remove old servers/contracts safely
```

---

# 23. Migration dependency mapping

Never migrate randomly.

Bad:

```text id="bad-migration"
Move app server to AWS
but database and DNS dependency are forgotten.
```

Good:

```text id="good-migration"
Map:
  app server
  database
  file shares
  DNS names
  firewall rules
  LDAP/AD
  batch jobs
  reporting jobs
  external integrations
  backup tools
  monitoring
```

Dependency example:

```text id="dependency-example"
WebApp01 depends on:
  OracleDB01:1521
  FileShare01:445
  SMTP relay:25
  AD DNS:53
  payment API:443
```

This mapping decides migration waves.

---

# 24. Cutover strategy

Cutover means switching users/traffic from old system to new system.

Common cutover methods:

```text id="cutover-methods"
DNS cutover:
  lower TTL, switch record

Load balancer cutover:
  shift traffic target

Database cutover:
  stop writes, sync final changes, point app to new DB

Blue/green cutover:
  run old and new side by side, switch routing

Phased migration:
  move users/regions/tenants gradually
```

Production cutover checklist:

```text id="cutover-checklist"
lower DNS TTL before migration
freeze risky changes
confirm replication healthy
take final backup/snapshot
validate new app
switch traffic
monitor errors/latency
keep rollback window
communicate status
document exact timeline
```

---

# 25. Rollback strategy

Rollback means returning to old system if migration fails.

Never migrate without rollback.

Questions:

```text id="rollback-questions"
Can old system still accept traffic?
Did new system write data that old system does not have?
Can database writes be reversed?
How long is rollback safe?
Who approves rollback?
What metric triggers rollback?
```

Database rollback is hardest because data changes after cutover.

Safer pattern:

```text id="rollback-safe"
Before cutover:
  old DB primary
  new DB replicating

During cutover:
  short write freeze
  final sync
  app points to new DB

After cutover:
  monitor carefully
  limit rollback window
```

---

# 26. Hybrid security design

Security in hybrid architecture:

```text id="hybrid-security"
Network:
  restrict routes
  security groups
  NACLs
  firewalls
  segmentation

Identity:
  IAM roles
  federation
  least privilege
  SSO/Identity Center
  AD integration where required

Encryption:
  VPN IPsec
  TLS
  KMS
  encrypted storage

Detection:
  CloudTrail
  GuardDuty
  VPC Flow Logs
  firewall logs
  DNS logs

Governance:
  SCPs
  Config
  tagging
  change management
```

Production rule:

```text id="hybrid-security-rule"
Hybrid connectivity should not mean every on-prem server can reach every AWS subnet.
Use segmentation and explicit routing.
```

---

# 27. Hybrid monitoring

Monitor:

```text id="hybrid-monitor"
VPN tunnel status
Direct Connect virtual interface state
BGP route status
Transit Gateway route tables
Resolver endpoint health
DNS query behavior
VPC Flow Logs
application latency between on-prem and AWS
DMS replication lag
DataSync task status
MGN replication status
```

Operational question:

```text id="operational-question"
Is the problem:
  network route?
  DNS resolution?
  firewall/security group?
  database replication?
  application config?
  IAM permission?
```

---

# 28. Decision table: which migration/connectivity service?

| Need                                       | Choose                                            |
| ------------------------------------------ | ------------------------------------------------- |
| Quick encrypted network connection         | Site-to-Site VPN                                  |
| Dedicated private predictable network link | Direct Connect                                    |
| Connect many VPCs and on-prem networks     | Transit Gateway                                   |
| Hybrid private DNS                         | Route 53 Resolver inbound/outbound endpoints      |
| On-prem file/tape/storage access to AWS    | Storage Gateway                                   |
| Move files/objects online                  | DataSync                                          |
| Move databases with CDC                    | DMS                                               |
| Lift-and-shift servers to EC2              | AWS Transform MGN / Application Migration Service |
| Ship huge data physically                  | Snow Family                                       |
| Replace app with SaaS                      | Repurchase                                        |
| Small cloud optimization                   | Replatform                                        |
| Full modernization                         | Refactor                                          |

---

# 29. Hands-On Lab 15A — No-Cost Hybrid Architecture Design Pack

This lab creates local architecture documents and validation scripts. It creates **no AWS billable resources**.

Goal:

```text id="lab-goal"
Build a reusable hybrid migration design pack for interviews and real projects.
```

Create folders:

```bash id="lab-folder"
mkdir -p ~/aws-masterclass/hybrid-migration/{notes,diagrams,runbooks,scripts,reports}
cd ~/aws-masterclass/hybrid-migration
```

---

## Step 1 — Create CIDR plan

```bash id="cidr-plan"
cat > notes/cidr-plan.md <<'EOF'
# Hybrid CIDR Plan

## Rule

No CIDR overlap between on-premises, AWS VPCs, Docker networks, VPN clients, or partner networks.

## Current/planned ranges

| Environment | CIDR | Notes |
|---|---|---|
| On-premises data center | 172.16.0.0/16 | Existing corporate network |
| AWS dev VPC | 10.10.0.0/16 | Dev workloads |
| AWS staging VPC | 10.20.0.0/16 | Pre-prod workloads |
| AWS prod VPC | 10.30.0.0/16 | Production workloads |
| AWS shared services VPC | 10.40.0.0/16 | AD/DNS/tools/security |
| VPN client pool | 10.250.0.0/22 | Remote admin/user VPN |
| Docker default avoid list | 172.17.0.0/16 | Avoid overlap with common Docker bridge |

## Subnet pattern per VPC

public:
  10.x.1.0/24
  10.x.2.0/24

private app:
  10.x.11.0/24
  10.x.12.0/24

private database:
  10.x.21.0/24
  10.x.22.0/24

inspection/security:
  10.x.31.0/24
  10.x.32.0/24

## Validation checklist

- No overlap with on-premises.
- No overlap with other AWS VPCs.
- No overlap with VPN client range.
- Enough spare CIDR space for future accounts/regions.
- CIDR documented before VPN/DX/TGW creation.
EOF
```

---

## Step 2 — Create hybrid architecture diagram

```bash id="diagram"
cat > diagrams/hybrid-architecture.mmd <<'EOF'
flowchart TD
  Users[Corporate Users] --> OnPrem[On-Premises Network]
  OnPrem --> CorpDNS[On-Prem DNS]
  OnPrem --> LegacyDB[Legacy Database]
  OnPrem --> VPN[Site-to-Site VPN]
  OnPrem --> DX[Direct Connect]

  VPN --> TGW[AWS Transit Gateway]
  DX --> DXGW[Direct Connect Gateway]
  DXGW --> TGW

  TGW --> ProdVPC[Prod VPC 10.30.0.0/16]
  TGW --> SharedVPC[Shared Services VPC 10.40.0.0/16]

  ProdVPC --> Public[Public Subnets: ALB/NAT]
  ProdVPC --> App[Private App Subnets: ECS/EC2]
  ProdVPC --> DB[Private DB Subnets: RDS/Aurora]

  SharedVPC --> Inbound[Route 53 Resolver Inbound Endpoint]
  SharedVPC --> Outbound[Route 53 Resolver Outbound Endpoint]

  CorpDNS --> Inbound
  Outbound --> CorpDNS

  App --> S3[(S3)]
  App --> RDS[(RDS)]
  LegacyDB --> DMS[AWS DMS]
  DMS --> RDS

  OnPrem --> DataSync[AWS DataSync]
  DataSync --> S3
EOF
```

---

## Step 3 — Create migration inventory template

```bash id="inventory"
cat > notes/migration-inventory.csv <<'EOF'
app_name,business_owner,technical_owner,environment,server_names,os,database,file_shares,dns_names,ports,inbound_dependencies,outbound_dependencies,data_size_gb,rpo,rto,criticality,compliance,proposed_7r,target_aws_service,wave,rollback_plan
todo-app,Vivek,DevOps,dev,app01,Ubuntu,MongoDB,None,todo.internal,80/443,users,db:27017,10,15m,1h,medium,none,replatform,ECS+DocumentDB,1,restore DNS to old ALB
legacy-crm,TBD,TBD,prod,crm01;crmdb01,Windows/SQLServer,SQL Server,SMB,crm.corp.local,443;1433,AD/DNS,email;payment,500,5m,30m,high,PII,retain,TBD,TBD,TBD
EOF
```

---

## Step 4 — Create 7R decision notes

```bash id="seven-r"
cat > notes/7r-decision-guide.md <<'EOF'
# 7R Migration Decision Guide

## Retire
Use when the app is unused or no longer provides business value.

## Retain
Use when the app must stay on-premises for now because of compliance, risk, dependencies, hardware, or no business case.

## Rehost
Use when you need a fast lift-and-shift migration with minimal application changes.
Typical tool: AWS Transform MGN / Application Migration Service.

## Relocate
Use when moving an existing platform with minimal changes.

## Repurchase
Use when replacing the application with SaaS.

## Replatform
Use when making small cloud optimizations without rewriting the app.
Example: app on EC2/ECS, database moved to RDS.

## Refactor / Re-architect
Use when the app needs cloud-native modernization.
Example: monolith to ECS/Lambda/SQS/DynamoDB.

## Decision questions

1. Is the app still used?
2. Does the app have business value?
3. Is there a SaaS replacement?
4. Does it have hardware/local dependencies?
5. What are RPO/RTO requirements?
6. What is the app complexity?
7. Is fast data center exit more important than modernization?
8. Can the database be moved to RDS/Aurora?
9. Does the app need redesign for scale/reliability?
10. What is the rollback path?
EOF
```

---

## Step 5 — Create cutover runbook

```bash id="cutover-runbook"
cat > runbooks/migration-cutover-runbook.md <<'EOF'
# Migration Cutover Runbook

## Workload

Application:
Environment:
Migration strategy:
Migration wave:
Cutover date:

## Pre-cutover

- Confirm source health.
- Confirm target health.
- Confirm backups/snapshots.
- Confirm replication status.
- Confirm DNS TTL lowered.
- Confirm firewall/security group rules.
- Confirm monitoring dashboards.
- Confirm rollback owner and decision time.
- Notify stakeholders.

## Cutover steps

1. Freeze risky changes.
2. Stop writes if required.
3. Run final sync/replication check.
4. Validate target database/data.
5. Update application configuration.
6. Switch DNS/load balancer routing.
7. Run smoke tests.
8. Monitor errors, latency, logs, and business KPIs.

## Validation

- Login works.
- Core API works.
- Database writes work.
- File uploads/downloads work.
- Background jobs work.
- Monitoring is green.
- No unexpected 5xx spike.
- No replication lag if still syncing.

## Rollback trigger

- Error rate above agreed threshold.
- Data write failure.
- Critical business flow broken.
- Latency above SLO for agreed period.
- Security issue detected.

## Rollback steps

1. Stop new writes to target if needed.
2. Restore DNS/load balancer route to source.
3. Confirm source app health.
4. Preserve target logs/data for investigation.
5. Communicate rollback complete.
6. Document timeline and root cause.

## Post-cutover

- Keep heightened monitoring.
- Decommission old system only after approval.
- Update CMDB/inventory.
- Update backup and runbook.
- Record lessons learned.
EOF
```

---

## Step 6 — Create CIDR overlap checker

```bash id="cidr-checker"
cat > scripts/check-cidr-overlap.py <<'EOF'
#!/usr/bin/env python3
import ipaddress

networks = {
    "on-prem": "172.16.0.0/16",
    "aws-dev": "10.10.0.0/16",
    "aws-staging": "10.20.0.0/16",
    "aws-prod": "10.30.0.0/16",
    "aws-shared": "10.40.0.0/16",
    "vpn-client": "10.250.0.0/22",
    "docker-default-avoid": "172.17.0.0/16",
}

parsed = {name: ipaddress.ip_network(cidr) for name, cidr in networks.items()}

errors = []

items = list(parsed.items())
for i, (name_a, net_a) in enumerate(items):
    for name_b, net_b in items[i + 1:]:
        if net_a.overlaps(net_b):
            errors.append(f"OVERLAP: {name_a} {net_a} overlaps {name_b} {net_b}")

if errors:
    print("CIDR overlap detected:")
    for error in errors:
        print(f"  - {error}")
    raise SystemExit(1)

print("OK: no CIDR overlaps detected.")
for name, net in parsed.items():
    print(f"{name}: {net}")
EOF

chmod +x scripts/check-cidr-overlap.py

./scripts/check-cidr-overlap.py
```

---

## Step 7 — Create migration readiness checklist

```bash id="readiness"
cat > reports/migration-readiness-checklist.md <<'EOF'
# Migration Readiness Checklist

## Foundation

- [ ] AWS account structure ready
- [ ] IAM federation/roles ready
- [ ] CloudTrail enabled
- [ ] GuardDuty/Config decision made
- [ ] Budgets configured
- [ ] Tagging standard defined

## Network

- [ ] CIDR plan approved
- [ ] VPC design approved
- [ ] VPN/DX/TGW design approved
- [ ] Route tables documented
- [ ] Firewall rules documented
- [ ] DNS resolver design approved
- [ ] VPC Flow Logs decision made

## Data

- [ ] Database inventory complete
- [ ] File share inventory complete
- [ ] Data size measured
- [ ] RPO/RTO defined
- [ ] Migration tool selected: DMS/DataSync/MGN/Snow/backup-restore
- [ ] Backup and restore tested

## Application

- [ ] Dependency map complete
- [ ] Ports/protocols documented
- [ ] Secrets/config mapped
- [ ] Target AWS architecture approved
- [ ] Smoke tests ready
- [ ] Performance tests ready

## Cutover

- [ ] DNS TTL plan
- [ ] Replication validation
- [ ] Freeze window
- [ ] Communication plan
- [ ] Rollback plan
- [ ] On-call coverage
- [ ] Post-cutover monitoring
EOF
```

---

# 30. Optional AWS CLI discovery commands

These commands only list existing resources.

```bash id="cli-discovery"
export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1

aws sts get-caller-identity

aws ec2 describe-vpcs \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,IsDefault:IsDefault}' \
  --output table

aws ec2 describe-vpn-connections \
  --query 'VpnConnections[].{VpnId:VpnConnectionId,State:State,Type:Type}' \
  --output table

aws ec2 describe-transit-gateways \
  --query 'TransitGateways[].{TgwId:TransitGatewayId,State:State,Description:Description}' \
  --output table

aws route53resolver list-resolver-endpoints \
  --query 'ResolverEndpoints[].{Id:Id,Name:Name,Direction:Direction,Status:Status}' \
  --output table || true

aws datasync list-tasks \
  --query 'Tasks[].{TaskArn:TaskArn,Name:Name,Status:Status}' \
  --output table || true

aws dms describe-replication-tasks \
  --query 'ReplicationTasks[].{TaskId:ReplicationTaskIdentifier,Status:Status,MigrationType:MigrationType}' \
  --output table || true
```

---

# 31. Common hybrid/migration errors and fixes

## Error 1 — VPN tunnel down

Check:

```text id="vpn-down-check"
customer gateway public IP
pre-shared key
IKE/IPsec parameters
firewall allows required VPN traffic
BGP ASN and neighbor config
route propagation/static routes
both tunnels configured
```

Fix:

```text id="vpn-fix"
Download AWS VPN config for your vendor.
Configure both tunnels.
Check CloudWatch tunnel metrics.
Verify on-prem firewall/NAT.
```

---

## Error 2 — AWS can ping on-prem, but app cannot connect

Possible causes:

```text id="app-connect-causes"
security group missing outbound/inbound
on-prem firewall blocks port
NACL blocks ephemeral response
route table missing route
DNS resolves wrong IP
app uses hardcoded hostname/IP
```

Debug order:

```text id="debug-order"
route
security group
NACL
on-prem firewall
DNS
application listener
```

---

## Error 3 — DNS fails in hybrid setup

Possible causes:

```text id="dns-fails"
Resolver inbound endpoint missing
Resolver outbound endpoint missing
forwarding rule missing
security group blocks TCP/UDP 53
on-prem DNS points to wrong endpoint IP
private hosted zone not associated with VPC
wrong domain suffix
```

Fix:

```text id="dns-fix"
Check resolver endpoints.
Check resolver rules.
Check DNS SG port 53.
Use dig/nslookup from both sides.
```

---

## Error 4 — DMS replication lag high

Possible causes:

```text id="dms-lag-causes"
replication instance too small
source database overloaded
network latency
large transactions
target database bottleneck
missing indexes/constraints strategy
LOB settings too heavy
```

Fix:

```text id="dms-lag-fix"
Right-size replication instance.
Check source/target DB metrics.
Review task settings.
Schedule migration during lower load.
Tune target database.
```

---

## Error 5 — DataSync task slow

Possible causes:

```text id="datasync-slow"
network bandwidth limit
too many small files
source storage slow
agent placement poor
destination throttling
security/firewall bottleneck
```

Fix:

```text id="datasync-fix"
Place agent near source.
Test bandwidth.
Split tasks by directory.
Use includes/excludes.
Monitor task metrics.
```

---

## Error 6 — Migration cutover fails

Possible causes:

```text id="cutover-fails"
DNS TTL not lowered
data replication not caught up
application config points to old dependency
security group/firewall missing rule
secret not migrated
certificate/domain mismatch
rollback not tested
```

Fix:

```text id="cutover-fix"
Use cutover checklist.
Run smoke tests before switch.
Keep rollback window.
Document exact dependency map.
```

---

# 32. Production hybrid checklist

Before hybrid go-live:

```text id="prod-hybrid-checklist"
1. CIDR plan approved.
2. No IP overlap.
3. VPN/DX design reviewed.
4. Transit Gateway route tables documented.
5. Route propagation understood.
6. On-prem firewall rules approved.
7. AWS security groups least-privilege.
8. Hybrid DNS endpoints configured.
9. DNS forwarding tested both directions.
10. CloudTrail/VPC Flow Logs/monitoring enabled.
11. Data migration tool selected.
12. RPO/RTO defined.
13. Backup and restore tested.
14. Cutover runbook written.
15. Rollback runbook written.
16. Stakeholders notified.
17. Maintenance window approved.
18. Monitoring dashboard ready.
19. Decommission plan ready.
20. Cost tracking tags applied.
```

---

# 33. Certification angle

## CLF-C02

Know:

```text id="clf"
Site-to-Site VPN connects on-premises to AWS over encrypted VPN.
Direct Connect provides dedicated network connectivity.
Transit Gateway connects multiple VPCs and on-prem networks.
Storage Gateway supports hybrid storage.
DataSync moves file/object data.
DMS migrates databases.
Snow Family moves huge data physically.
```

## SAA-C03

Know deeply:

```text id="saa"
CIDR overlap avoidance
VPN vs Direct Connect
Transit Gateway hub-and-spoke design
TGW route tables and propagation
hybrid DNS with Route 53 Resolver endpoints
private hosted zones
Storage Gateway vs DataSync
DMS full load plus CDC
MGN lift-and-shift server migration
Snow Family for limited bandwidth/huge data
multi-account/multi-VPC network design
cutover and rollback planning
```

## DOP-C02

Know operationally:

```text id="dop"
VPN tunnel monitoring
BGP route troubleshooting
Direct Connect VIF status
Transit Gateway route debugging
VPC Flow Logs for hybrid traffic
DataSync task monitoring
DMS replication lag troubleshooting
MGN cutover waves
automation/runbooks
migration rollback
post-cutover incident response
```

---

# 34. Interview answer

Memorize this:

```text id="interview-answer"
Hybrid cloud means some systems run on-premises and some run in AWS, with secure connectivity, routing, DNS, identity, monitoring, and data movement between both environments. The first rule is to avoid CIDR overlap between on-premises networks, AWS VPCs, VPN client pools, and partner networks.

For connectivity, I use Site-to-Site VPN when I need a fast encrypted connection over the internet, and Direct Connect when I need dedicated, more predictable private connectivity. In larger environments, I use Transit Gateway as a central hub to connect multiple VPCs, VPNs, and Direct Connect gateways, with route tables for segmentation between prod, non-prod, shared services, and inspection networks.

For hybrid DNS, I use Route 53 Resolver inbound endpoints when on-premises DNS needs to resolve AWS private names, and outbound endpoints with forwarding rules when AWS workloads need to resolve on-premises names. For storage and migration, I use Storage Gateway for ongoing hybrid storage access, DataSync for file/object movement, DMS for database migration with full load and CDC, AWS Transform MGN/Application Migration Service for lift-and-shift server migration, and Snow Family when data volume is too large for network transfer.

For migration strategy, I classify workloads using the 7 Rs: retire, retain, rehost, relocate, repurchase, replatform, and refactor. I do not migrate randomly. I build inventory, dependency maps, RPO/RTO requirements, target architecture, cutover runbooks, rollback plans, validation tests, and monitoring dashboards before moving production workloads.
```

---

# 35. Quick quiz

```text id="quiz"
1. What is hybrid cloud?
2. What is the first CIDR rule for hybrid connectivity?
3. What is Site-to-Site VPN?
4. How many tunnels does an AWS Site-to-Site VPN connection include?
5. What is a customer gateway?
6. What is Direct Connect?
7. What is a private VIF?
8. What is a public VIF?
9. What is a transit VIF?
10. What is Transit Gateway?
11. What is the difference between VPC route table and TGW route table?
12. What is Route 53 Resolver inbound endpoint used for?
13. What is Route 53 Resolver outbound endpoint used for?
14. What is Storage Gateway?
15. What is DataSync?
16. What is DMS?
17. What is CDC in migration?
18. What is AWS Transform MGN/Application Migration Service used for?
19. When should Snow Family be considered?
20. What are the 7 Rs?
```

Answers:

```text id="answers"
1. A setup where some workloads run on-premises and some in AWS.
2. Do not overlap CIDR ranges.
3. Encrypted IPsec VPN between on-premises network and AWS.
4. Two tunnels.
5. AWS resource representing your on-premises router/firewall information.
6. Dedicated private network connectivity to AWS.
7. Direct Connect virtual interface for private VPC access.
8. Direct Connect virtual interface for public AWS service access.
9. Direct Connect virtual interface for Transit Gateway access.
10. Central network hub connecting VPCs and on-premises networks.
11. VPC route table controls subnet routing; TGW route table controls routing between TGW attachments.
12. On-premises DNS forwarding queries into AWS/VPC Resolver.
13. AWS/VPC Resolver forwarding selected queries to on-premises DNS.
14. Hybrid storage service connecting on-premises storage workflows to AWS storage.
15. Managed online data transfer service for file/object data.
16. Database Migration Service for migrating databases.
17. Change Data Capture, ongoing replication of changes after initial load.
18. Lift-and-shift server migration to AWS using block-level replication.
19. When data is too large or connectivity too limited for network transfer.
20. Retire, retain, rehost, relocate, repurchase, replatform, refactor/re-architect.
```

# Next Lesson

```text id="next"
AWS Lesson 16 — DevOps on AWS:
CodePipeline, CodeBuild, CodeDeploy, ECR, ECS blue/green deployments, CloudFormation, Terraform integration, deployment strategies, rollback, artifact handling, and CI/CD security
```

[1]: https://docs.aws.amazon.com/vpn/latest/s2svpn/VPC_VPN.html "What is AWS Site-to-Site VPN? - AWS Site-to-Site VPN"
[2]: https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html "What is Direct Connect? - AWS Direct Connect"
[3]: https://docs.aws.amazon.com/vpc/latest/tgw/what-is-transit-gateway.html "What is AWS Transit Gateway for Amazon VPC? - Amazon VPC"
[4]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-overview-DSN-queries-to-vpc.html "Resolving DNS queries between VPCs and your network - Amazon Route 53"
[5]: https://docs.aws.amazon.com/storagegateway/latest/APIReference/Welcome.html "Welcome - Storage Gateway"
[6]: https://docs.aws.amazon.com/cli/latest/reference/datasync/ "datasync — AWS CLI 2.35.19 Command Reference"
[7]: https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html "What is AWS Database Migration Service? - AWS Database Migration Service"
[8]: https://docs.aws.amazon.com/mgn/latest/ug/mgn-release-notes.html "Release notes - AWS Transform MGN"
[9]: https://docs.aws.amazon.com/prescriptive-guidance/latest/migration-database-rehost-tools/mgn.html "Migration with AWS Application Migration Service - AWS Prescriptive Guidance"
[10]: https://docs.aws.amazon.com/whitepapers/latest/security-at-the-edge/appendix-aws-services-for-edge-computing.html?utm_source=chatgpt.com "Appendix: AWS services for edge computing - Security at the Edge: Core Principles"
[11]: https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/migration-strategies.html "About the migration strategies - AWS Prescriptive Guidance"
