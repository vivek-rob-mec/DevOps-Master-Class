# Module 13 — AWS Production Architecture

# Lesson 37 — Multi-Region Architecture, Disaster Recovery, RTO/RPO & Failover

## Part 9: Complete Production Multi-Region DR Capstone

This capstone combines almost everything from Lessons **36 + 37** into one realistic architecture.

Our design target:

```text
PRIMARY REGION
ap-south-1
Mumbai

RECOVERY REGION
ap-southeast-1
Singapore

DR MODEL
Warm Standby + Active/Passive

TRAFFIC
Route 53 Failover
+
ARC-controlled recovery workflow

DATABASE
Aurora Global Database

ARTIFACTS
ECR cross-Region replication

SECRETS
Secrets Manager multi-Region replication

OBJECTS
S3 Cross-Region Replication

BACKUPS
AWS Backup cross-Region recovery points

INFRASTRUCTURE
Terraform

TESTING
CloudWatch + ARC + AWS FIS + restore testing
```

We deliberately **do not** make the database arbitrary multi-writer. Aurora Global Database retains a single primary writer Region, which keeps writer authority and failover reasoning much clearer while still providing cross-Region replication and managed failover. AWS recommends managed failover for unplanned Aurora Global Database recovery. ([AWS Documentation][1])

---

# 37.735 Capstone business requirement

Assume we run:

# `payments.example.com`

Business requires:

```text
Availability:
production critical

Primary:
Mumbai

Recovery:
Singapore

Target RTO:
15 minutes

Target RPO:
< 1 minute target

DR strategy:
Warm Standby

Traffic model:
Active / Passive
```

Remember:

```text
RTO
=
how long until the business service works


RPO
=
how much committed data might be lost
```

Because Aurora Global Database cross-Region replication is asynchronous, an unplanned failover can have a non-zero RPO depending on replication lag at the incident moment; AWS's ARC Aurora execution-block documentation similarly describes failover RPO as typically non-zero and measured in seconds. ([AWS Documentation][2])

---

# 37.736 Production architecture

Our complete architecture:

```text
                              INTERNET USERS
                                    │
                                    ▼
                               Route 53
                          payments.example.com
                                    │
                        Failover Routing Policy
                                    │
                   ┌────────────────┴────────────────┐
                   │                                 │
                   ▼                                 ▼

                PRIMARY                           SECONDARY
             ap-south-1                       ap-southeast-1
               MUMBAI                            SINGAPORE

          ┌────────────────┐                ┌────────────────┐
          │      VPC       │                │      VPC       │
          │  10.64.0.0/16  │                │  10.80.0.0/16  │
          └───────┬────────┘                └───────┬────────┘
                  │                                 │
              Multi-AZ                          Multi-AZ
                  │                                 │
                  ▼                                 ▼
                 ALB                               ALB
                  │                                 │
            ECS × 6 tasks                     ECS × 1 task
                  │                                 │
                  │                                 │
                  └────────── application ──────────┘
                                    │
                                    ▼
                        AURORA GLOBAL DATABASE

                       Mumbai = PRIMARY WRITER
                                  │
                                  │ async replication
                                  ▼
                       Singapore = SECONDARY


        ECR Mumbai ──────────────────────────────► ECR Singapore

     Secrets Mumbai ─────────────────────────────► Secret Replica

         S3 Mumbai ──────────────────────────────► S3 Singapore

      AWS Backup ────────────────────────────────► DR Backup Vault

                  │                                 │
                  └───────────────┬─────────────────┘
                                  ▼
                       Amazon ARC Region Switch
                                  │
                             Recovery Plan
                                  │
            ┌─────────────────────┼────────────────────┐
            ▼                     ▼                    ▼
          DATA                  SCALE               TRAFFIC

        Aurora                ECS/ASG          Routing Control/
        failover                                 Route 53

                                  │
                                  ▼
                         CloudWatch / FIS
```

Amazon ECR supports cross-Region replication, Secrets Manager supports replicating secrets to additional Regions, Route 53 supports primary/secondary failover aliases, and ARC Region Switch supports ordered recovery execution blocks. ([AWS Documentation][3])

---

# 37.737 Why Warm Standby?

We're choosing:

```text
Mumbai

6 ECS tasks
full capacity


Singapore

1 ECS task
functional stack
reduced capacity
```

Instead of:

```text
Singapore
0 application stack
```

because we want to be able to continuously test:

```text
ALB            ✓
TLS            ✓
application    ✓
database read  ✓
secret access  ✓
networking     ✓
```

Then failure mainly becomes:

```text
promote database
      ↓
scale Singapore
      ↓
validate
      ↓
shift traffic
```

rather than:

```text
build everything
      ↓
hope
```

---

# 37.738 Normal packet flow

Normal production request:

```text
User
 │
 ▼
payments.example.com
 │
 ▼
Route 53
 │
 ▼
PRIMARY record
 │
 ▼
Mumbai ALB
 │
 ▼
Mumbai ECS
 │
 ▼
Aurora Mumbai Writer
```

Data then replicates:

```text
Aurora Mumbai
     │
     │ async
     ▼
Aurora Singapore
```

---

# 37.739 Failure packet flow

After a regional disaster and completed recovery workflow:

```text
User
 │
 ▼
payments.example.com
 │
 ▼
Route 53
 │
 ▼
SECONDARY record
 │
 ▼
Singapore ALB
 │
 ▼
Singapore ECS
 │
 ▼
Aurora Singapore Writer
```

The critical word is:

# **after**

We do **not** want:

```text
Traffic → Singapore
```

before:

```text
Singapore DB writer ready
Singapore compute ready
application healthy
```

---

# 37.740 CIDR plan

Use non-overlapping VPC space.

| Environment               | Region         |           CIDR |
| ------------------------- | -------------- | -------------: |
| Primary                   | ap-south-1     | `10.64.0.0/16` |
| DR                        | ap-southeast-1 | `10.80.0.0/16` |
| Corporate/on-prem example | —              | `10.10.0.0/16` |

Inside each Region:

```text
Primary VPC
10.64.0.0/16

Public A
10.64.0.0/24

Public B
10.64.1.0/24

App A
10.64.10.0/24

App B
10.64.11.0/24

DB A
10.64.20.0/24

DB B
10.64.21.0/24
```

Singapore:

```text
10.80.0.0/16

same logical subnet pattern
but different CIDR
```

This also leaves us compatible with the hybrid-routing/IPAM principles from Lesson 36.

---

# 37.741 Terraform repository

A strong repository layout:

```text
multi-region-dr/
│
├── modules/
│   │
│   ├── vpc/
│   ├── alb/
│   ├── ecs/
│   ├── aurora/
│   ├── ecr/
│   ├── secrets/
│   ├── s3-replication/
│   ├── backup/
│   ├── monitoring/
│   └── arc/
│
├── environments/
│   │
│   └── production/
│       ├── providers.tf
│       ├── variables.tf
│       ├── locals.tf
│       ├── network.tf
│       ├── compute.tf
│       ├── database.tf
│       ├── ecr.tf
│       ├── secrets.tf
│       ├── storage.tf
│       ├── backup.tf
│       ├── dns.tf
│       ├── monitoring.tf
│       ├── arc.tf
│       └── outputs.tf
│
└── resilience/
    ├── fis/
    │   ├── instance-failure.json
    │   └── network-failure.json
    │
    ├── runbooks/
    │   ├── failover.md
    │   └── failback.md
    │
    └── validation/
        └── smoke-test.sh
```

The current HashiCorp AWS provider includes Terraform resources for Aurora global clusters, ECR replication configuration, Secrets Manager replicas, Route 53 records, and ARC Region Switch plans. ([Terraform Registry][4])

---

# 37.742 Multi-Region Terraform providers

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "payments-dr"
      ManagedBy   = "Terraform"
      Environment = "prod"
    }
  }
}

provider "aws" {
  alias  = "dr"
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project     = "payments-dr"
      ManagedBy   = "Terraform"
      Environment = "prod"
    }
  }
}
```

Now:

```text
aws
```

means:

```text
Mumbai
```

while:

```text
aws.dr
```

means:

```text
Singapore
```

HashiCorp's current AWS provider supports these relevant Multi-Region resources; pin your own approved provider release through your dependency-lock process rather than blindly following whatever becomes `latest`. ([Terraform Registry][4])

---

# 37.743 Variables

```hcl
variable "primary_region" {
  type    = string
  default = "ap-south-1"
}

variable "dr_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "primary_vpc_cidr" {
  default = "10.64.0.0/16"
}

variable "dr_vpc_cidr" {
  default = "10.80.0.0/16"
}

variable "domain_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "aurora_engine_version" {
  type = string
}
```

Notice:

```text
engine version
```

is a variable.

Don't hard-code an old Aurora engine version from a tutorial.

---

# 37.744 Network module instances

```hcl
module "primary_vpc" {
  source = "../../modules/vpc"

  cidr = var.primary_vpc_cidr

  public_subnets = [
    "10.64.0.0/24",
    "10.64.1.0/24"
  ]

  private_app_subnets = [
    "10.64.10.0/24",
    "10.64.11.0/24"
  ]

  private_db_subnets = [
    "10.64.20.0/24",
    "10.64.21.0/24"
  ]
}

module "dr_vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.dr
  }

  cidr = var.dr_vpc_cidr

  public_subnets = [
    "10.80.0.0/24",
    "10.80.1.0/24"
  ]

  private_app_subnets = [
    "10.80.10.0/24",
    "10.80.11.0/24"
  ]

  private_db_subnets = [
    "10.80.20.0/24",
    "10.80.21.0/24"
  ]
}
```

The module should create:

```text
VPC
IGW
public subnets
private app subnets
private DB subnets
route tables
NAT/egress design
DB subnet groups
```

For a real production workload, use at least two AZs per Region for the normal Regional HA layer before relying on Multi-Region recovery.

---

# 37.745 Security-group flow

Use:

```text
Internet
   │
   ▼
ALB SG
443
   │
   ▼
ECS SG
application port
   │
   ▼
DB SG
5432
```

Not:

```text
Internet
→ DB 5432
```

Example:

```hcl
resource "aws_security_group" "primary_db" {
  name   = "payments-primary-db"
  vpc_id = module.primary_vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "primary_db_from_app" {
  security_group_id            = aws_security_group.primary_db.id
  referenced_security_group_id = module.primary_app.service_security_group_id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}
```

Do the same independently in Singapore.

---

# 37.746 ECR — artifact replication

Create application repository:

```hcl
resource "aws_ecr_repository" "payments" {
  name                 = "prod-payments"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
```

Then configure cross-Region replication:

```hcl
data "aws_caller_identity" "current" {}

resource "aws_ecr_replication_configuration" "dr" {
  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      repository_filter {
        filter      = "prod-"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}
```

The AWS provider currently exposes `aws_ecr_replication_configuration`, while ECR itself supports cross-Region and cross-account registry replication. ([Terraform Registry][5])

Mental flow:

```text
CI pushes:

prod-payments:v42
        │
        ▼
Mumbai ECR
        │
        │ automatic replication
        ▼
Singapore ECR
```

---

# 37.747 Why immutable image tags?

Prefer:

```text
payments:v42
```

or:

```text
payments@sha256:...
```

over repeatedly redefining:

```text
payments:latest
```

Your recovery environment should know exactly which application artifact corresponds to the production release.

---

# 37.748 Validate ECR replication

After pushing:

```bash
aws ecr describe-images \
  --region ap-south-1 \
  --repository-name prod-payments
```

Then:

```bash
aws ecr describe-images \
  --region ap-southeast-1 \
  --repository-name prod-payments
```

You should eventually see the intended image in both registries because ECR replication creates destination copies according to the configured rules. ([AWS Documentation][3])

---

# 37.749 Secrets Manager replication

Create primary secret metadata with a Singapore replica:

```hcl
resource "aws_secretsmanager_secret" "app" {
  name = "prod/payments/app"

  replica {
    region = var.dr_region
  }
}
```

Then store the secret value separately:

```hcl
resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    api_key = var.application_api_key
  })
}
```

Use secure CI/CD input or a secret-management workflow rather than committing the actual value to source control.

Secrets Manager supports replicating encrypted secret data and metadata to additional Regions; a replica can later be promoted to a standalone secret if required. The current Terraform AWS provider exposes replica configuration on `aws_secretsmanager_secret`. ([AWS Documentation][6])

---

# 37.750 Validate the secret

Mumbai:

```bash
aws secretsmanager describe-secret \
  --region ap-south-1 \
  --secret-id prod/payments/app
```

Singapore:

```bash
aws secretsmanager describe-secret \
  --region ap-southeast-1 \
  --secret-id prod/payments/app
```

Your Singapore application must consume the **local Region replica**, not make its successful startup depend on the unavailable primary Region. ([AWS Documentation][6])

---

# 37.751 S3 Cross-Region Replication

Suppose payments produce:

```text
receipts
settlement reports
customer exports
```

Create:

```text
Mumbai bucket
→ Singapore bucket
```

Both buckets need versioning for standard S3 live replication. S3 CRR is asynchronous, while S3 Replication Time Control is available when a predictable replication SLA is required. ([AWS Documentation][7])

---

# 37.752 S3 buckets

```hcl
resource "aws_s3_bucket" "primary" {
  bucket = var.primary_bucket_name
}

resource "aws_s3_bucket" "dr" {
  provider = aws.dr
  bucket   = var.dr_bucket_name
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

---

# 37.753 Replication role

Conceptually:

```hcl
resource "aws_iam_role" "s3_replication" {
  name = "payments-s3-cross-region-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

Then grant:

```text
read source versions
+
replicate into destination
```

Only the required bucket resources should be included.

---

# 37.754 Replication configuration

Representative structure:

```hcl
resource "aws_s3_bucket_replication_configuration" "dr" {
  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.dr
  ]

  role   = aws_iam_role.s3_replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-to-singapore"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD"
    }
  }
}
```

HashiCorp's current provider manages S3 replication through `aws_s3_bucket_replication_configuration`. S3 live replication does not retroactively copy pre-existing objects; existing datasets require a separate replication workflow such as Batch Replication. ([Terraform Registry][8])

---

# 37.755 KMS warning

If you upgrade the S3 design to customer-managed KMS encryption—which is common for stricter environments—the replication role must have the appropriate source decrypt and destination encrypt permissions, and cross-account KMS replication specifically needs a customer-managed destination key. ([AWS Documentation][9])

Mental model:

```text
S3 CRR
=
S3 permissions
+
destination bucket
+
versioning
+
KMS permissions if applicable
```

---

# 37.756 Aurora Global Database

Now the heart of the data layer.

Architecture:

```text
GLOBAL CLUSTER
payments-global

          │
          ├── Mumbai cluster
          │      PRIMARY
          │      WRITER
          │
          └── Singapore cluster
                 SECONDARY
                 READ-ORIENTED
```

AWS documents Aurora Global Database as one primary cluster with secondary Regions and supports managed cross-Region failover for disaster recovery. ([AWS Documentation][10])

---

# 37.757 Global cluster Terraform

```hcl
resource "aws_rds_global_cluster" "payments" {
  global_cluster_identifier = "payments-global"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_engine_version

  storage_encrypted = true
}
```

The current Terraform AWS provider manages Aurora global databases using `aws_rds_global_cluster`. ([Terraform Registry][4])

---

# 37.758 Primary Aurora cluster

```hcl
resource "aws_rds_cluster" "primary" {
  cluster_identifier = "payments-mumbai"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_engine_version

  global_cluster_identifier =
    aws_rds_global_cluster.payments.id

  db_subnet_group_name =
    module.primary_vpc.db_subnet_group_name

  vpc_security_group_ids = [
    aws_security_group.primary_db.id
  ]

  master_username = var.db_master_username
  master_password = var.db_master_password

  backup_retention_period = 7
  storage_encrypted       = true

  deletion_protection = true
}
```

Use stronger secret provisioning for real production rather than casually passing the master password through shell history or an unprotected tfvars file.

---

# 37.759 Primary DB instances

```hcl
resource "aws_rds_cluster_instance" "primary" {
  count = 2

  identifier = "payments-mumbai-${count.index + 1}"

  cluster_identifier =
    aws_rds_cluster.primary.id

  instance_class = var.primary_db_instance_class

  engine         = aws_rds_cluster.primary.engine
  engine_version = aws_rds_cluster.primary.engine_version
}
```

Why two?

Because Multi-Region DR doesn't replace:

```text
intra-Region HA.
```

---

# 37.760 Singapore Aurora cluster

```hcl
resource "aws_rds_cluster" "dr" {
  provider = aws.dr

  cluster_identifier = "payments-singapore"

  engine         = "aurora-postgresql"
  engine_version = var.aurora_engine_version

  global_cluster_identifier =
    aws_rds_global_cluster.payments.id

  db_subnet_group_name =
    module.dr_vpc.db_subnet_group_name

  vpc_security_group_ids = [
    aws_security_group.dr_db.id
  ]

  storage_encrypted = true

  depends_on = [
    aws_rds_cluster_instance.primary
  ]
}
```

Then Singapore reader capacity:

```hcl
resource "aws_rds_cluster_instance" "dr" {
  provider = aws.dr

  count = 1

  identifier = "payments-singapore-${count.index + 1}"

  cluster_identifier =
    aws_rds_cluster.dr.id

  instance_class = var.dr_db_instance_class

  engine         = aws_rds_cluster.dr.engine
  engine_version = aws_rds_cluster.dr.engine_version
}
```

This illustrates the primary/secondary global-database relationship supported by the provider and Aurora service. ([Terraform Registry][11])

---

# 37.761 DR database capacity decision

Normal:

```text
Mumbai:
2 larger DB instances

Singapore:
1 smaller DB instance
```

This saves standby resources.

But then:

```text
Singapore promotion
+
database/application scaling
```

becomes part of RTO.

You can instead run more Singapore DB capacity all the time.

That costs more but shortens the amount of emergency scaling required.

This is exactly the:

```text
cost
↔
recovery speed
```

trade-off we've studied throughout Lesson 37.

---

# 37.762 ECS application stack

Use the same module twice.

Primary:

```hcl
module "primary_app" {
  source = "../../modules/ecs"

  vpc_id = module.primary_vpc.vpc_id

  private_subnet_ids =
    module.primary_vpc.private_app_subnet_ids

  public_subnet_ids =
    module.primary_vpc.public_subnet_ids

  desired_count = 6
  max_capacity  = 20

  app_name = "payments"

  image_tag = var.release_version
}
```

DR:

```hcl
module "dr_app" {
  source = "../../modules/ecs"

  providers = {
    aws = aws.dr
  }

  vpc_id = module.dr_vpc.vpc_id

  private_subnet_ids =
    module.dr_vpc.private_app_subnet_ids

  public_subnet_ids =
    module.dr_vpc.public_subnet_ids

  desired_count = 1
  max_capacity  = 20

  app_name = "payments"

  image_tag = var.release_version
}
```

The important DR property:

```text
PRIMARY

desired = 6
max     = 20


DR NORMAL

desired = 1
max     = 20
```

Singapore is small but capable of scaling toward production requirements.

---

# 37.763 The app must use Region-local dependencies

Mumbai application:

```text
ECR Mumbai
Secret Mumbai
ALB Mumbai
DB Mumbai
S3 Mumbai
```

Singapore:

```text
ECR Singapore
Secret Singapore
ALB Singapore
DB Singapore
S3 Singapore
```

Do **not** accidentally configure:

```text
Singapore ECS
     │
     ▼
Mumbai Secret
```

or:

```text
Singapore ECS
     │
     ▼
Mumbai S3
```

because that recreates a hidden dependency on the Region you're trying to survive.

---

# 37.764 Health endpoint

Your application should expose something like:

```text
GET /health/live
```

for process health.

And:

```text
GET /health/ready
```

for traffic readiness.

Regional recovery validation might go deeper:

```text
GET /dr-readiness
```

checking safe critical dependencies such as:

```text
application initialized

database reachable

critical configuration present
```

but avoid making the Region unhealthy just because an optional analytics system is temporarily unavailable.

---

# 37.765 Route 53 failover records

Primary:

```hcl
resource "aws_route53_record" "payments_primary" {
  zone_id = var.route53_zone_id
  name    = "payments.${var.domain_name}"
  type    = "A"

  set_identifier = "mumbai-primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = module.primary_app.alb_dns_name
    zone_id                = module.primary_app.alb_zone_id
    evaluate_target_health = true
  }
}
```

Secondary:

```hcl
resource "aws_route53_record" "payments_dr" {
  zone_id = var.route53_zone_id
  name    = "payments.${var.domain_name}"
  type    = "A"

  set_identifier = "singapore-secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.dr_app.alb_dns_name
    zone_id                = module.dr_app.alb_zone_id
    evaluate_target_health = true
  }
}
```

Route 53 supports `PRIMARY` and `SECONDARY` failover records, and alias records targeting an ALB can use `Evaluate Target Health` so Route 53 considers the ALB target-group health. The Terraform provider supports the failover routing policy on `aws_route53_record`. ([AWS Documentation][12])

---

# 37.766 Important: Route 53 alone isn't our recovery orchestrator

For a static site, health-driven automatic DNS failover may be enough.

For:

```text
Aurora writer
+
financial transactions
```

we want controlled sequencing:

```text
DB
 ↓
capacity
 ↓
validation
 ↓
traffic
```

So Route 53 is:

```text
traffic mechanism
```

while ARC is:

```text
recovery workflow/control
```

ARC Region Switch supports execution blocks for Aurora Global Database recovery, ECS scaling, routing controls, custom Lambda actions, and manual approval. ([AWS Documentation][13])

---

# 37.767 AWS Backup layer

Replication is not backup.

We still want:

```text
periodic historical recovery points
+
cross-Region copies
```

Create primary vault:

```hcl
resource "aws_backup_vault" "primary" {
  name = "payments-primary-backups"
}
```

Singapore vault:

```hcl
resource "aws_backup_vault" "dr" {
  provider = aws.dr
  name     = "payments-dr-backups"
}
```

AWS Backup supports cross-Region backup copies for supported resource types. ([AWS Documentation][14])

---

# 37.768 Backup plan

```hcl
resource "aws_backup_plan" "payments" {
  name = "payments-critical"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.primary.name

    schedule = "cron(0 1 * * ? *)"

    lifecycle {
      delete_after = 35
    }

    copy_action {
      destination_vault_arn =
        aws_backup_vault.dr.arn

      lifecycle {
        delete_after = 90
      }
    }
  }
}
```

Then select protected resources through:

```text
ARN assignment
```

or an appropriate tag-based backup policy.

Cross-Region copy actions are supported by AWS Backup for compatible protected resources; feature support still depends on resource type. ([AWS Documentation][14])

---

# 37.769 Backup immutability

For stronger ransomware protection, evaluate:

```text
Backup Vault Lock
```

and possibly:

```text
logically air-gapped vault
```

in a dedicated backup account.

Compliance-mode Vault Lock becomes immutable after its grace period and cannot then be removed even by normal account ownership controls or AWS, so treat it as a carefully reviewed production control—not a casual lab experiment. ([AWS Documentation][15])

---

# 37.770 Aurora PITR nuance

A very important advanced detail:

AWS Backup continuous backups for Aurora use Aurora's own continuous-backup data path and **cannot** use Vault Lock or logically air-gapped-vault protection in the same way. For immutable backup-vault protection, AWS directs you toward periodic snapshot backups. ([AWS Documentation][16])

So a mature database strategy may include:

```text
Aurora continuous/PITR
       │
       └── fast recent recovery


Periodic AWS Backup snapshots
       │
       └── immutable/cross-Region
           historical recovery
```

Again:

```text
one backup mechanism
doesn't solve every failure class.
```

---

# 37.771 ARC Region Switch

Current Terraform AWS Provider exposes:

```text
aws_arcregionswitch_plan
```

for ARC Region Switch plans. ARC itself uses plans containing workflows, steps, and execution blocks. ([Terraform Registry][17])

For this capstone, encode the recovery semantics as:

```text
WORKFLOW:
Mumbai → Singapore

STEP 1
Aurora Global Database failover

STEP 2
Scale Singapore ECS

STEP 3
Lambda smoke test

STEP 4
Manual approval

STEP 5
Routing control / DNS shift

STEP 6
Post-recovery checks
```

---

# 37.772 Why I would separate ARC from the core first apply

Because ARC Region Switch is evolving quickly and its supported execution blocks have expanded during 2026.

My production workflow would therefore be:

```text
Terraform core infrastructure
      ↓
validate
      ↓
replication verified
      ↓
application healthy
      ↓
then add ARC recovery plan
      ↓
run plan evaluation
      ↓
game-day test
```

rather than:

```text
one enormous Terraform apply
creates everything
and we assume the recovery plan works.
```

AWS currently documents ARC Region Switch execution blocks for ECS scaling, Aurora recovery, routing controls, manual approval, Lambda and other recovery actions. ([AWS Documentation][13])

---

# 37.773 ARC workflow

Conceptual recovery workflow:

```text
              CLOUDWATCH INCIDENT SIGNAL
                        │
                        ▼
                ARC REGION SWITCH
                        │
                        ▼

                  STEP 1 — DATA

           Aurora Global Database
             Failover to Singapore
                        │
                        ▼

                STEP 2 — CAPACITY

                   ECS service
                   1 → 6+
                        │
                        ▼

               STEP 3 — VALIDATE

                     Lambda
                 smoke transaction
                        │
                        ▼

               STEP 4 — APPROVAL

                Incident Commander
                   APPROVE?
                        │
                        ▼

                STEP 5 — TRAFFIC

                Routing Control
                        │
                        ▼
                    Route 53
                        │
                        ▼
                    Singapore
```

That is exactly the ordering problem ARC Region Switch is designed to orchestrate. ([AWS Documentation][18])

---

# 37.774 Manual approval placement

Why approval immediately before traffic?

Because by then:

```text
Singapore DB writer      ✓
Singapore compute        ✓
smoke test               ✓
```

The human decision becomes:

> "Do we now expose customers to this recovered system?"

ARC's manual-approval block pauses plan execution until an authorized user approves or declines. ([AWS Documentation][19])

---

# 37.775 Routing Control option

For more controlled production failover, combine ARC Region Switch with ARC Routing Control.

Conceptually:

```text
Mumbai control
ON

Singapore control
OFF
```

then:

```text
Mumbai
OFF

Singapore
ON
```

The Terraform provider currently has resources for ARC Recovery Control Config routing controls, control panels and safety rules. ([Terraform Registry][20])

---

# 37.776 Safety invariant

Create a rule conceptually equivalent to:

```text
AT LEAST ONE REGION
MUST REMAIN ON
```

Allowed:

```text
Mumbai ON
Singapore OFF
```

Allowed:

```text
Mumbai OFF
Singapore ON
```

Potentially allowed depending on application:

```text
Mumbai ON
Singapore ON
```

Reject:

```text
Mumbai OFF
Singapore OFF
```

That's exactly the type of global outage a safety rule is intended to prevent.

---

# 37.777 CloudWatch monitoring

Create Region-local dashboards plus a global recovery dashboard.

Monitor:

```text
APPLICATION
───────────
ALB 5xx
ALB latency
healthy targets
ECS running tasks


DATABASE
────────
Aurora health
connections
CPU
replication state/lag


REPLICATION
───────────
S3 replication failures
ECR availability
secret replication status


BUSINESS
────────
payment success
transaction latency
orders/min


DR
──
Singapore health
Singapore capacity
```

S3 can emit replication failure notifications when replication metrics are enabled, and S3 RTC adds threshold-oriented replication metrics/events for workloads that need that feature. ([AWS Documentation][21])

---

# 37.778 Synthetic recovery test

Create:

```text
POST /dr-test-payment
```

using a dedicated safe test tenant.

Include:

```text
unique transaction ID
+
idempotency key
```

For example:

```text
dr-20260814-001
```

Expected:

```text
HTTP 200

database record exists exactly once

correct Region identifier returned
```

Never use a recovery test that charges an actual customer.

---

# 37.779 Application response should expose Region for testing

For example:

```json
{
  "status": "healthy",
  "region": "ap-south-1",
  "release": "v42"
}
```

Then after failover:

```json
{
  "status": "healthy",
  "region": "ap-southeast-1",
  "release": "v42"
}
```

This makes recovery validation much easier.

---

# 37.780 Terraform execution order

First:

```bash
terraform fmt -recursive
```

Then:

```bash
terraform init
```

Then:

```bash
terraform validate
```

Then:

```bash
terraform plan \
  -out=prod.plan
```

Review carefully.

Do **not** automatically run:

```bash
terraform apply
```

against this complete architecture simply because the plan is syntactically valid.

This capstone includes persistent and/or managed resources such as Aurora, ALBs, compute, backup storage and DR services, so deploy it only in an account where cost and cleanup are understood.

---

# 37.781 Suggested implementation waves

Use:

```text
WAVE 1
Network


WAVE 2
Security


WAVE 3
ECR + artifacts


WAVE 4
Secrets


WAVE 5
S3 replication


WAVE 6
Aurora Global Database


WAVE 7
Primary + DR application stacks


WAVE 8
Route 53


WAVE 9
Backup


WAVE 10
Monitoring


WAVE 11
ARC


WAVE 12
Game day
```

Why?

Because if Wave 5 fails:

```text
you debug S3
```

not:

```text
which of 180 new resources broke?
```

---

# 37.782 Validation — network

Check VPCs:

```bash
aws ec2 describe-vpcs \
  --region ap-south-1
```

and:

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-1
```

Verify:

```text
Mumbai VPC
10.64/16

Singapore VPC
10.80/16
```

Then verify:

```text
subnets
route tables
NAT/egress
security groups
```

---

# 37.783 Validation — application

Mumbai:

```bash
curl -v https://<mumbai-alb>/health/ready
```

Singapore:

```bash
curl -v https://<singapore-alb>/health/ready
```

Expected:

```text
both HTTP 200
```

Singapore should be functional **before** failover.

---

# 37.784 Validation — Route 53

```bash
dig payments.example.com
```

or:

```bash
nslookup payments.example.com
```

Normal:

```text
response
→ Mumbai ALB path
```

Do not intentionally break production DNS just to test casually.

Use a dedicated:

```text
dr-test.example.com
```

hostname for early exercises.

---

# 37.785 Validation — Aurora

Inspect global database:

```bash
aws rds describe-global-clusters \
  --region ap-south-1
```

Verify:

```text
global cluster exists

Mumbai is writer-side primary

Singapore attached as secondary

replication healthy
```

Aurora Global Database supports managed cross-Region failover specifically for moving the primary role to a secondary Region during DR. ([AWS Documentation][1])

---

# 37.786 Validation — ECR

Push:

```text
prod-payments:dr-test
```

then confirm:

```text
Mumbai ECR ✓

Singapore ECR ✓
```

ECR cross-Region replication should create the matching destination repository/image according to the configured rule. ([AWS Documentation][3])

---

# 37.787 Validation — S3

Upload:

```bash
echo "DR TEST" > test.txt

aws s3 cp test.txt \
  s3://PRIMARY_BUCKET/dr-test/test.txt
```

Then check Singapore:

```bash
aws s3api head-object \
  --bucket DR_BUCKET \
  --key dr-test/test.txt \
  --region ap-southeast-1
```

Remember that standard CRR is asynchronous. If your business needs a supported SLA around replication time, evaluate S3 RTC, which AWS documents as replicating 99.99% of new objects within 15 minutes. ([AWS Documentation][7])

---

# 37.788 Validation — Secrets

Confirm:

```text
same logical secret
available locally
in both Regions
```

Do not print the secret value into:

```text
terminal logs

CI logs

Slack

Terraform output
```

just to prove it exists.

Validate metadata/access safely.

---

# 37.789 Validation — backups

Check:

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name payments-primary-backups \
  --region ap-south-1
```

Then Singapore:

```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name payments-dr-backups \
  --region ap-southeast-1
```

Backup existence alone isn't enough; AWS Backup also supports scheduled restore-testing plans to prove recovery points can actually be restored. ([AWS Documentation][22])

---

# 37.790 Pre-failover checklist

Before any controlled game day:

```text
Primary healthy                       ✓

Secondary healthy                     ✓

Aurora replication healthy            ✓

DR data sufficiently current          ✓

ECR image available Singapore         ✓

Secret available Singapore            ✓

Singapore ACM certificate valid       ✓

Singapore ECS health                  ✓

Singapore max capacity sufficient     ✓

S3 replication healthy                ✓

Backups healthy                       ✓

CloudWatch alarms working             ✓

ARC plan evaluated                    ✓

Rollback/failback runbook ready       ✓

Stop conditions ready                 ✓
```

If several of these are red:

```text
don't start the regional game day.
```

---

# 37.791 Controlled failover runbook

Now the major exercise.

### T0 — declare test

Record:

```text
START_TIME
```

Example:

```text
14:00:00 IST
```

---

# 37.792 Step 1 — simulate regional application failure

For an early game day, don't literally destroy the AWS Region.

Instead isolate:

```text
Mumbai application traffic
```

or use a bounded FIS/traffic-control experiment.

AWS FIS provides controlled experiment templates with targets, actions and CloudWatch stop conditions; use a bounded blast radius rather than destructive improvisation. ([AWS Documentation][23])

---

# 37.793 Step 2 — detect

Monitoring should identify:

```text
Mumbai critical service unhealthy
```

Record:

```text
DETECTION_TIME
```

Example:

```text
14:01:05
```

Detection took:

```text
1m05s
```

---

# 37.794 Step 3 — incident declaration

Incident Commander decides:

```text
execute regional recovery
```

Record:

```text
DECLARATION_TIME
```

This time counts toward the business RTO.

---

# 37.795 Step 4 — data recovery

ARC workflow performs Aurora Global Database recovery toward:

```text
ap-southeast-1
```

For an unplanned outage, AWS recommends managed failover when available. ([AWS Documentation][1])

Conceptually:

```text
Mumbai Writer
      X
      │
      ▼
Singapore Secondary
      │
      ▼
Singapore Primary Writer
```

---

# 37.796 Verify writer

Do not continue only because an API says:

```text
SUCCESS
```

Actually verify:

```text
connection
+
write
+
read-back
```

Safe example:

```sql
INSERT INTO dr_validation
(id, created_at, region)
VALUES
('dr-test-001', NOW(), 'ap-southeast-1');
```

Then:

```sql
SELECT *
FROM dr_validation
WHERE id='dr-test-001';
```

Expected:

```text
one record
```

---

# 37.797 Step 5 — scale DR ECS

Singapore:

```text
desired count:

1
↓
6
```

ARC currently supports an ECS service-scaling execution block as part of Region Switch recovery workflows. ([AWS Documentation][24])

Wait until:

```text
desired = running

ALB targets healthy
```

---

# 37.798 Step 6 — smoke test

Run:

```bash
curl -fsS \
  https://<singapore-test-endpoint>/health/ready
```

Then:

```text
test login

test DB read

test safe DB write

test S3 access

test secret access
```

For a payment service also send:

```text
one synthetic idempotent transaction
```

and verify:

```text
exactly one business effect.
```

---

# 37.799 Step 7 — manual approval

ARC pauses:

```text
PENDING_APPROVAL
```

Incident Commander reviews:

```text
DB writer             ✓

ECS capacity          ✓

ALB healthy           ✓

smoke test            ✓

business test         ✓
```

Then:

```text
APPROVE
```

ARC's manual approval execution block explicitly pauses plan execution until an authorized approval or decline occurs. ([AWS Documentation][19])

---

# 37.800 Step 8 — traffic shift

Now:

```text
Mumbai
OFF

Singapore
ON
```

or:

```text
Route 53 primary unhealthy/disabled
secondary chosen
```

depending on your final ARC/Route 53 design.

ARC's routing-control block is designed to participate in DNS failover as part of a Region Switch plan. ([AWS Documentation][25])

---

# 37.801 Verify externally

From an independent client:

```bash
dig payments.example.com
```

Then:

```bash
curl \
  https://payments.example.com/region
```

Expected:

```json
{
  "region": "ap-southeast-1"
}
```

---

# 37.802 Measure actual RTO

Suppose:

```text
Fault:
14:00:00

First successful
Singapore payment:
14:11:42
```

Then:

```text
Actual RTO
≈ 11m42s
```

Target:

```text
15m
```

Result:

```text
PASS
```

But record every stage.

---

# 37.803 Break RTO into components

Example:

| Stage                   |       Time |
| ----------------------- | ---------: |
| Detection               |      1m05s |
| Human declaration       |      1m30s |
| Aurora failover         |      3m10s |
| ECS scaling             |      2m20s |
| Validation              |      1m40s |
| Approval                |        30s |
| Traffic/client recovery |      1m27s |
| **Total**               | **11m42s** |

Now you can optimize scientifically.

---

# 37.804 RPO measurement

Before failure continuously write controlled markers:

```text
14:00:00  tx-001
14:00:05  tx-002
14:00:10  tx-003
14:00:15  tx-004
14:00:20  tx-005
14:00:25  tx-006
```

Incident:

```text
14:00:27
```

After failover, latest record present:

```text
tx-005
14:00:20
```

Approximate observed loss:

```text
7 seconds
```

Measured RPO:

```text
~7 sec
```

This is far more meaningful than saying:

```text
"Aurora Global is fast."
```

Aurora failover can lose transactions that were not yet replicated, so actual recovery testing should measure this explicitly. ([AWS Documentation][2])

---

# 37.805 Validate duplicate prevention

During the failure:

```text
Payment request:
idempotency_key=pay-dr-1001
```

Send once to Mumbai.

Cause timeout.

Retry against Singapore.

Expected:

```text
payment count = 1
```

not:

```text
payment count = 2
```

This validates the idempotency principles from Part 5.

---

# 37.806 Run under DR for a while

Don't immediately fail back.

Let Singapore operate.

Observe:

```text
ALB 5xx

latency

ECS CPU/memory

Aurora CPU/connections

business transactions

S3 operations

queues

third-party dependencies
```

The goal is to prove:

```text
Singapore isn't merely alive.

Singapore can operate production.
```

---

# 37.807 Failback is a separate workflow

Now Mumbai comes back.

Do **not** simply:

```text
Route 53 → Mumbai
```

because Singapore is now authoritative and has newer writes.

Instead:

```text
Singapore PRIMARY
      │
      ▼
Mumbai reintroduced
as secondary
      │
      ▼
replication catches up
      │
      ▼
validate Mumbai
      │
      ▼
planned switchover
```

Aurora managed failover/switchover tooling is built specifically around maintaining or restoring the global-cluster topology across Regional role changes. ([AWS Documentation][1])

---

# 37.808 Failback sequence

```text
1. Keep customers on Singapore.

2. Restore Mumbai application infrastructure.

3. Verify Mumbai artifacts/secrets/config.

4. Restore/rejoin Aurora topology.

5. Wait for data synchronization.

6. Scale Mumbai application.

7. Run Mumbai smoke tests.

8. Verify certificates/dependencies.

9. Obtain failback approval.

10. Perform graceful Aurora switchover
    if Mumbai should again be primary.

11. Shift traffic gradually/controlled.

12. Monitor.

13. Reduce Singapore back to
    warm-standby capacity.
```

Planned Aurora switchovers are distinct from unplanned failovers and can be used when both Regions are healthy. ([AWS Documentation][1])

---

# 37.809 Why switchover for failback?

At failback time:

```text
Singapore healthy
Mumbai healthy
```

This is no longer:

```text
DISASTER
```

It's a controlled transition.

So use:

```text
graceful synchronization
+
planned role switch
```

rather than unnecessarily performing an emergency-style recovery.

---

# 37.810 FIS experiment #1 — one ECS/EC2 failure

Hypothesis:

```text
Loss of one compute unit
must not impact customer availability.
```

Monitor:

```text
ALB target health

5xx

replacement time

business success
```

FIS experiment templates support target/action/stop-condition definitions and can be used for bounded resilience tests. ([AWS Documentation][23])

---

# 37.811 FIS experiment #2 — application impairment

Hypothesis:

```text
Primary regional application
can be declared unhealthy

without damaging
the recovery environment.
```

Use a dedicated test hostname and controlled target scope.

Never make your first chaos experiment:

```text
destroy entire production database.
```

---

# 37.812 Stop condition

Example:

```text
CloudWatch Alarm

Payments5xx > 5%
```

Then:

```text
FIS
STOP
```

AWS FIS stop conditions can use CloudWatch alarms to terminate an experiment when the defined safety boundary is crossed. ([AWS Documentation][26])

---

# 37.813 Restore test

Even though Aurora Global Database exists, test:

```text
historical restore
```

separately.

Example:

```text
Backup
   ↓
AWS Backup Restore Testing
   ↓
temporary DB
   ↓
schema validation
   ↓
critical data validation
   ↓
application validation
```

AWS Backup restore-testing plans can periodically select recovery points and start restoration jobs, with AWS inferring much of the necessary restore metadata for supported resources. ([AWS Documentation][22])

---

# 37.814 Why this matters

Regional replication protects:

```text
Mumbai disappearing
```

But it does not save you from:

```text
DELETE FROM payments;
```

that successfully replicates.

For that:

```text
backup
PITR
historical recovery
```

remain mandatory.

---

# 37.815 Failure drill matrix

| Failure                    | Expected recovery                     |
| -------------------------- | ------------------------------------- |
| One ECS task               | ECS replaces it                       |
| One EC2                    | ASG replaces it                       |
| One AZ                     | Multi-AZ / Zonal Shift                |
| DB instance                | Aurora Regional HA                    |
| Mumbai app failure         | Regional traffic recovery             |
| Mumbai Region disaster     | ARC Region Switch to Singapore        |
| Aurora primary loss        | Managed Global DB failover            |
| ECR Mumbai unavailable     | Singapore ECR already populated       |
| Secret primary unavailable | Singapore replica used                |
| S3 Mumbai unavailable      | Singapore bucket used                 |
| Logical DB corruption      | Backup/PITR restore                   |
| Bad global deployment      | rollback/progressive release controls |

This is the complete resilience hierarchy.

---

# 37.816 Security review

Before production sign-off verify:

```text
IAM least privilege

ARC execution role scoped

FIS roles scoped

Backup account isolated

Vault access restricted

S3 buckets private

database private

Secrets Manager policies reviewed

KMS policies reviewed

CloudTrail enabled

Route 53 changes auditable

Terraform state protected
```

Cross-account/Region recovery only works safely when IAM and encryption-policy dependencies have also been designed; AWS explicitly requires relevant permissions for replication and ARC execution blocks. ([AWS Documentation][27])

---

# 37.817 Terraform state architecture

Do not put this entire enterprise architecture into one giant state if teams/lifecycles differ.

A stronger structure could be:

```text
state/
├── network-primary
├── network-dr
├── data-global
├── compute-primary
├── compute-dr
├── backup
├── dns
└── recovery-control
```

Or fewer states if your team is small.

The goal:

```text
ownership boundary

blast-radius control

clear dependencies

safe deployments
```

not:

```text
maximum number of state files.
```

---

# 37.818 Pipeline

Production delivery:

```text
Git push
   │
   ▼
CI
   │
   ├── terraform fmt
   ├── validate
   ├── security/policy checks
   └── plan
   │
   ▼
approval
   │
   ▼
apply
   │
   ▼
application build
   │
   ▼
ECR Mumbai
   │
   ▼
ECR replication
   │
   ▼
Primary deployment
   │
   ▼
validate
   │
   ▼
DR deployment/update
   │
   ▼
DR smoke test
   │
   ▼
recovery readiness checks
```

That keeps standby architecture synchronized with normal engineering releases.

---

# 37.819 Progressive release rule

Do not release:

```text
bad version 47
```

to:

```text
Mumbai
+
Singapore
```

simultaneously.

Prefer controlled waves:

```text
canary
 ↓
one Region
 ↓
validation
 ↓
second Region
```

while keeping database schema changes backward-compatible during the deployment window.

Otherwise Multi-Region infrastructure still shares a single:

```text
software failure domain.
```

---

# 37.820 Cost guardrail

This exact capstone contains services that can produce ongoing charges.

For learning, I would use:

```text
terraform plan
```

as the default exercise.

If you deploy, tag everything:

```text
Project=payments-dr-capstone
Owner=<your-name>
Expires=<date>
```

and destroy what isn't deliberately persistent.

Be especially careful with:

```text
Aurora clusters
ALBs
NAT Gateways
ECS/EC2
backup storage
cross-Region transfer
Route 53/ARC resources
FIS experiments
CloudWatch logs
```

No need to keep a full production DR architecture running simply to remember the lesson.

---

# 37.821 Cleanup

For a temporary lab, application traffic should first be stopped safely.

Then:

```bash
terraform plan -destroy
```

Review it.

Then:

```bash
terraform destroy
```

But important:

```text
deletion protection
```

on production-style resources may deliberately prevent destruction.

Do **not** casually disable protections in a real production account.

For an ephemeral training environment, use separate lab settings rather than weakening production definitions.

---

# 37.822 Post-destroy checks

Don't trust:

```text
Destroy complete!
```

alone.

Inspect:

```text
RDS/Aurora

ECS/EC2

ALBs

NAT Gateways

ECR repositories if intentionally temporary

S3 buckets

AWS Backup vault contents

CloudWatch log groups

Route 53 test records

FIS templates

ARC test resources
```

Some persistent data resources may intentionally outlive a normal compute destroy.

---

# 37.823 Production acceptance checklist

A system is **not DR-ready** because Terraform applied.

I'd require evidence that:

```text
Architecture
────────────
Multi-AZ primary                     ✓
Multi-AZ recovery                    ✓
non-overlapping CIDRs                ✓


Application
───────────
same release available both Regions  ✓
DR app continuously testable         ✓
no primary-Region hard dependency    ✓


Data
────
Aurora replication healthy           ✓
writer promotion tested              ✓
RPO measured                         ✓
backup restore tested                ✓


Traffic
───────
Route 53 configuration verified      ✓
traffic switch tested                ✓


Security
────────
secrets available                    ✓
certificates available               ✓
IAM/KMS recovery rights tested       ✓


Operations
──────────
ARC workflow tested                  ✓
RTO measured                         ✓
failback tested                      ✓
runbooks current                     ✓


Resilience
──────────
component failure tested             ✓
AZ failure tested                    ✓
Regional game day completed          ✓
```

Only then can we say:

```text
we have evidence of recovery capability.
```

---

# 37.824 What this architecture protects against

### EC2/task failure

```text
ECS/Auto Scaling
```

### Availability Zone problem

```text
Multi-AZ
```

### Regional application failure

```text
Singapore Warm Standby
```

### Regional database failure

```text
Aurora Global Database
```

### Primary ECR loss

```text
ECR replication
```

### Primary secret service dependency

```text
Secrets Manager replica
```

### Primary object-data access loss

```text
S3 CRR
```

### Logical corruption

```text
Backup/PITR
```

### Manual failover complexity

```text
ARC Region Switch
```

### Unknown resilience weakness

```text
FIS / Game Days
```

Different mechanisms address different failure classes; there is no single "DR service."

---

# 37.825 What it does NOT automatically protect against

Even this architecture doesn't magically solve:

```text
bad application logic

bad deployment everywhere

stolen credentials

misconfigured IAM

malicious DB write

global third-party outage

bad DNS change

business logic duplication

uncontrolled failback

application-level data corruption
```

Multi-Region architecture reduces particular infrastructure and Regional failure risks.

It does not eliminate engineering.

---

# 37.826 Senior-level packet + recovery walkthrough

Interview:

> **Explain what happens when the Mumbai Region becomes unavailable.**

A strong answer:

```text
1. Monitoring detects loss of the
   primary application's critical service.

2. The incident is classified as
   requiring Regional recovery.

3. ARC executes the predefined
   Mumbai → Singapore recovery plan.

4. The Aurora Global Database
   recovery operation moves write
   authority to Singapore.

5. The application verifies the
   Singapore database is writable.

6. Singapore ECS capacity scales
   from warm-standby size toward
   production requirements.

7. Application smoke tests confirm
   critical dependencies.

8. An approval gate can be used
   before exposing users.

9. ARC routing controls / Route 53
   move new traffic to Singapore.

10. Monitoring validates error rate,
    latency, capacity and business
    transaction success.

11. Actual RTO is measured from the
    incident start until successful
    customer transactions.

12. Actual RPO is measured by checking
    the last committed transaction
    available after recovery.

13. Mumbai is later rebuilt/rejoined.

14. Data catches up.

15. A planned switchover and controlled
    traffic return can restore Mumbai
    as primary if desired.

16. Singapore returns to warm-standby
    capacity.
```

That's a production answer—not a certification buzzword answer.

---

# 37.827 Resume-ready capstone statement

A strong résumé version:

> **Designed a production-oriented AWS Multi-Region disaster-recovery architecture across `ap-south-1` and `ap-southeast-1` using Terraform, Multi-AZ VPCs, ALB/ECS warm standby, Aurora Global Database, ECR and Secrets Manager cross-Region replication, S3 CRR, Route 53 failover, AWS Backup, Amazon Application Recovery Controller, CloudWatch, and AWS Fault Injection Service; implemented and validated controlled failover/failback workflows with measured RTO/RPO and application-level recovery testing.**

That describes actual architectural understanding rather than:

> "Worked with AWS."

---

# 37.828 Capstone mental map

Reconstruct this from memory:

```text
                          CUSTOMERS
                              │
                              ▼
                         GLOBAL TRAFFIC
                              │
                    Route 53 / ARC Control
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼

        PRIMARY REGION                    DR REGION
          MUMBAI                          SINGAPORE

         Multi-AZ                          Multi-AZ
             │                                │
            ALB                              ALB
             │                                │
          ECS full                          ECS warm
             │                                │
             └───────────┬────────────────────┘
                         │
                         ▼
                Aurora Global Database
                  Primary → Secondary

             ECR ──────────────────→ ECR

          Secrets ─────────────────→ Secrets

             S3 ───────────────────→ S3

          Backups ─────────────────→ DR Vault

                         │
                         ▼
                 ARC REGION SWITCH

                    Data first
                        ↓
                    Scale DR
                        ↓
                    Validate
                        ↓
                    Approve
                        ↓
                 Shift traffic
                        ↓
                  Measure RTO
                        ↓
                  Measure RPO
                        ↓
                    Failback
```

---

# 37.829 The twelve capstone rules

```text
1.
Multi-AZ protects a Region internally.
Multi-Region protects against
larger failure scopes.


2.
Warm Standby means the DR
application already works,
but at reduced capacity.


3.
Artifacts must already exist
in the recovery Region.


4.
Secrets must be Region-local
during a Regional outage.


5.
Replication does not replace backup.


6.
Aurora Global Database maintains
clear writer authority.


7.
Data recovery must happen before
customer traffic is shifted.


8.
Route 53 routes users.
ARC orchestrates recovery.


9.
Terraform creates desired infrastructure.
Runtime tests prove resilience.


10.
RTO must be measured,
not assumed.


11.
RPO must be measured,
not inferred from a service name.


12.
DR is incomplete until failback
has also been exercised.
```

---

# ✅ Lesson 37 — Part 9 Complete

We have now completed the **full production Multi-Region DR capstone**.

Lesson progress:

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
Application Recovery Controller     ✓

Part 8
DR Automation / Testing / Chaos     ✓

Part 9
Production Multi-Region Capstone    ✓

Part 10
FINAL REVISION + SAA/DOP +
INTERVIEW MASTERCLASS               NEXT
```

We are now at approximately **95% of Lesson 37**.

# Next — Lesson 37, Part 10

## Final Revision + Architecture Decision Matrix + SAA/DOP/Interview Mastery

The final part will compress this entire lesson into the mental models you need to retain permanently:

```text
HA vs DR

RTO vs RPO

Backup & Restore
vs
Pilot Light
vs
Warm Standby
vs
Active/Active

Multi-AZ
vs
Multi-Region

Route 53
vs
Global Accelerator
vs
ARC

Aurora Global Database
vs
RDS Replica
vs
DynamoDB Global Tables
vs
Aurora DSQL

MREC
vs
MRSC

Replication
vs
Backup

Failover
vs
Failback

Zonal Shift
vs
Zonal Autoshift
vs
Region Switch

ARC Routing Control
vs
Region Switch

FIS
vs
Game Days
vs
Restore Testing
vs
Resilience Hub
```

Then we'll do **architecture scenarios, exam traps, senior DevOps/SRE interview questions, troubleshooting drills, service-selection decisions, and the final one-page never-forget map**, and **Lesson 37 will be officially complete**.

[1]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html?utm_source=chatgpt.com "Using switchover or failover in Amazon Aurora Global Database"
[2]: https://docs.aws.amazon.com/r53recovery/latest/dg/aurora-global-database-block.html?utm_source=chatgpt.com "Amazon Aurora Global Database execution block"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html?utm_source=chatgpt.com "Private image replication in Amazon ECR"
[4]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_global_cluster?utm_source=chatgpt.com "aws_rds_global_cluster | Resources | hashicorp/aws | Terraform"
[5]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_replication_configuration?utm_source=chatgpt.com "aws_ecr_replication_configuration | Resources | hashicorp/aws"
[6]: https://docs.aws.amazon.com/secretsmanager/latest/userguide/replicate-secrets.html?utm_source=chatgpt.com "Replicate AWS Secrets Manager secrets across Regions"
[7]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html?utm_source=chatgpt.com "Replicating objects within and across Regions"
[8]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration?utm_source=chatgpt.com "aws_s3_bucket_replication_conf..."
[9]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-config-for-kms-objects.html?utm_source=chatgpt.com "Replicating encrypted objects (SSE-S3, SSE-KMS, DSSE ..."
[10]: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html?utm_source=chatgpt.com "Using Amazon Aurora Global Database"
[11]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster?utm_source=chatgpt.com "aws_rds_cluster | Resources | hashicorp/aws | Terraform"
[12]: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-failover-alias.html?utm_source=chatgpt.com "Values specific for failover alias records - Amazon Route 53"
[13]: https://docs.aws.amazon.com/r53recovery/latest/dg/working-with-rs-execution-blocks.html?utm_source=chatgpt.com "Add execution blocks"
[14]: https://docs.aws.amazon.com/aws-backup/latest/devguide/cross-region-backup.html?utm_source=chatgpt.com "Creating backup copies across AWS Regions"
[15]: https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html?utm_source=chatgpt.com "AWS Backup Vault Lock - AWS Documentation"
[16]: https://docs.aws.amazon.com/aws-backup/latest/devguide/point-in-time-recovery.html?utm_source=chatgpt.com "Continuous backups and point-in-time recovery (PITR)"
[17]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/arcregionswitch_plan?utm_source=chatgpt.com "aws_arcregionswitch_plan - Terraform Registry"
[18]: https://docs.aws.amazon.com/r53recovery/latest/dg/region-switch.html?utm_source=chatgpt.com "Region switch in ARC"
[19]: https://docs.aws.amazon.com/r53recovery/latest/dg/manual-approval-block.html?utm_source=chatgpt.com "Manual approval execution block"
[20]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53recoverycontrolconfig_routing_control?utm_source=chatgpt.com "aws_route53recoverycontrolconfi..."
[21]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-metrics-events.html?utm_source=chatgpt.com "Receiving replication failure events with Amazon S3 ..."
[22]: https://docs.aws.amazon.com/aws-backup/latest/devguide/restore-testing.html?utm_source=chatgpt.com "Restore testing - AWS Backup"
[23]: https://docs.aws.amazon.com/fis/latest/userguide/create.html?utm_source=chatgpt.com "Create a multi-account experiment template"
[24]: https://docs.aws.amazon.com/r53recovery/latest/dg/ecs-service-scaling-block.html?utm_source=chatgpt.com "Amazon ECS service scaling execution block"
[25]: https://docs.aws.amazon.com/r53recovery/latest/dg/arc-routing-controls-block.html?utm_source=chatgpt.com "ARC routing control execution block"
[26]: https://docs.aws.amazon.com/fis/latest/userguide/multi-account-prerequisites.html?utm_source=chatgpt.com "Prerequisites for multi-account experiments"
[27]: https://docs.aws.amazon.com/r53recovery/latest/dg/security_iam_region_switch_execution_blocks.html?utm_source=chatgpt.com "Execution block permissions"
