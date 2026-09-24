# AWS Masterclass — Lesson 22

## Build Phase 2 — Security Groups, Private S3 Bucket, CloudFront OAC Design, and ECR Repository

Today we extend the Terraform production capstone from Lesson 21.

We will add:

```text
1. Security groups for ALB, ECS tasks, and database
2. Private S3 bucket for static assets
3. CloudFront OAC bucket-policy design file
4. ECR repository for container images
5. ECR lifecycle policy
6. Terraform outputs and validation script
```

This phase is still low-cost. The S3 bucket and ECR repository may create tiny storage charges only if you upload objects/images. Security groups do not create cost by themselves.

Security groups can reference other security groups as traffic sources, which is the pattern we use for ALB → ECS and ECS → database access. ([AWS Documentation][1]) S3 Block Public Access should remain enabled for private buckets, and AWS states that new buckets do not allow public access by default. ([AWS Documentation][2]) ECR private repositories store Docker/OCI images and artifacts, and we will use ECR as the image registry for ECS later. ([AWS Documentation][3])

---

## Target architecture after today

```text
CloudFront later
  ↓
ALB security group
  ↓ port 3000
ECS task security group
  ↓ port 5432
Database security group

Private S3 bucket:
  static assets
  Block Public Access
  encryption
  versioning
  lifecycle cleanup

ECR:
  container image repository
  immutable tags
  scan on push
  lifecycle cleanup for untagged images
```

CloudFront OAC will be created in a later phase. For now, the Sged images

````

CloudFront OAC will be created in a later phase. For now, the S3 bucket stays private and has no public bucket policy. When CloudFront is created, we will add a bucket policy that :contentReference[oaicite:3]{index=3}nt distribution to read objects using `AWS:SourceArn`. citeturn998722search8

---

# Step 1 — Create new module folders

```bash
cd ~/aws-production-capstone

mkdir -p \
  modules/container-registry \
  docs/cloudfront
````

---

# Step 2 — Add new variables

Append these to `environments/dev/variables.tf`:

```bash
cat >> environments/dev/variables.tf <<'EOF'

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 3000
}

variable "db_port" {
  description = "Database port for PostgreSQL-style future DB access"
  type        = number
  default     = 5432
}
EOF
```

---

# Step 3 — Create security groups module

Create `modules/security-groups/variables.tf`:

```bash
cat > modules/security-groups/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "container_port" {
  description = "Application container port"
  type        = number
}

variable "db_port" {
  description = "Database port"
  type        = number
}
EOF
```

Create `modules/security-groups/main.tf`:

```bash
cat > modules/security-groups/main.tf <<'EOF'
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet for redirect/test"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound to application targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-alb-sg"
    Tier = "edge-alb"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.name_prefix}-ecs-tasks-sg"
  description = "ECS task security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Application traffic from ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound for app dependencies"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ecs-tasks-sg"
    Tier = "private-app"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.name_prefix}-database-sg"
  description = "Database security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Database traffic from ECS tasks only"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  tags = {
    Name = "${var.name_prefix}-database-sg"
    Tier = "private-db"
  }
}
EOF
```

Create `modules/security-groups/outputs.tf`:

```bash
cat > modules/security-groups/outputs.tf <<'EOF'
output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_tasks_sg_id" {
  value = aws_security_group.ecs_tasks.id
}

output "database_sg_id" {
  value = aws_security_group.database.id
}
EOF
```

---

# Step 4 — Create private S3 storage module

Create `modules/storage/variables.tf`:

```bash
cat > modules/storage/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform destroy to delete bucket contents. Use true only for dev/labs."
  type        = bool
  default     = false
}
EOF
```

Create `modules/storage/main.tf`:

```bash
cat > modules/storage/main.tf <<'EOF'
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  raw_bucket_name = "${var.name_prefix}-assets-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  bucket_name     = lower(substr(replace(local.raw_bucket_name, "_", "-"), 0, 63))
}

resource "aws_s3_bucket" "assets" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = local.bucket_name
    Tier = "static-assets"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  depends_on = [
    aws_s3_bucket_versioning.assets
  ]

  rule {
    id     = "cleanup-noncurrent-versions-and-multipart-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
EOF
```

Create `modules/storage/outputs.tf`:

```bash
cat > modules/storage/outputs.tf <<'EOF'
output "bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.assets.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.assets.bucket_regional_domain_name
}
EOF
```

---

# Step 5 — Create ECR module

E([AWS Documentation][4])dentify software vulnerabilities in container images. citeturn869916search12 We will also turn on tag immutability so a pushed tag cannot be silently overwritten; AWS documents that immutable repositories ret([AWS Documentation][5])tsException` if you try to push an existing tag again. citeturn998722search0

Create `modules/container-registry/variables.tf`:

```bash
cat > modules/container-registry/variables.tf <<'EOF'
variable "repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scan on push"
  type        = bool
  default     = true
}
EOF
```

Create `modules/container-registry/main.tf`:

```bash
cat > modules/container-registry/main.tf <<'EOF'
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.repository_name
    Tier = "container-registry"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
EOF
```

ECR lifecycle policies are used to exp([AWS Documentation][6])sitory rules, such as tag status, age, or image count. citeturn869916search2

Create `modules/container-registry/outputs.tf`:

```bash
cat > modules/container-registry/outputs.tf <<'EOF'
output "repository_name" {
  value = aws_ecr_repository.this.name
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.this.arn
}
EOF
```

---

# Step 6 — Update root `main.tf`

Replace `environments/dev/main.tf` with this:

```bash
cat > environments/dev/main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix    = local.name_prefix
  vpc_id         = module.networking.vpc_id
  container_port = var.container_port
  db_port        = var.db_port
}

module "storage" {
  source = "../../modules/storage"

  name_prefix   = local.name_prefix
  force_destroy = true
}

module "container_registry" {
  source = "../../modules/container-registry"

  repository_name      = "${local.name_prefix}-api"
  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
}
EOF
```

`force_destroy = true` is safe for this dev lab because it allows cleanup. Do not use that casually for production buckets.

---

# Step 7 — Update outputs

Replace `environments/dev/outputs.tf` with this:

```bash
cat > environments/dev/outputs.tf <<'EOF'
output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.networking.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.networking.private_db_subnet_ids
}

output "alb_sg_id" {
  value = module.security_groups.alb_sg_id
}

output "ecs_tasks_sg_id" {
  value = module.security_groups.ecs_tasks_sg_id
}

output "database_sg_id" {
  value = module.security_groups.database_sg_id
}

output "static_assets_bucket_name" {
  value = module.storage.bucket_name
}

output "static_assets_bucket_regional_domain_name" {
  value = module.storage.bucket_regional_domain_name
}

output "ecr_repository_name" {
  value = module.container_registry.repository_name
}

output "ecr_repository_url" {
  value = module.container_registry.repository_url
}
EOF
```

---

# Step 8 — Create CloudFront OAC design document

We cannot attach the final S3 bucket policy yet because the CloudFront distribution ID does not exist. This document records the exact future policy shape.

````bash
cat > docs/cloudfront/oac-s3-bucket-policy-template.md <<'EOF'
# CloudFront OAC S3 Bucket Policy Template

This bucket should remain private.

When the CloudFront distribution is created, attach a bucket policy like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT_ID:distribution/DISTRIBUTION_ID"
        }
      }
    }
  ]
}
````

## Important

* Do not make the bucket public.
* Keep S3 Block Public Access enabled.
* Use S3 REST regional domain as CloudFront origin.
* Use CloudFront Origin Access Control.
* Scope access to the exact CloudFront distribution ARN.
* Do not use the S3 static website endpoint for this private OAC pattern.
  EOF

````

---

# Step 9 — Terraform format, validate, and plan

```bash
cd ~/aws-production-capstone

terraform fmt -recursive

cd environments/dev

terraform init
terraform validate
terraform plan -out=tfplan
````

Expected new resources include:

```text
aws_security_group.alb
aws_security_group.ecs_tasks
aws_security_group.database
aws_s3_bucket.assets
aws_s3_bucket_public_access_block.assets
aws_s3_bucket_ownership_controls.assets
aws_s3_bucket_server_side_encryption_configuration.assets
aws_s3_bucket_versioning.assets
aws_s3_bucket_lifecycle_configuration.assets
aws_ecr_repository.this
aws_ecr_lifecycle_policy.this
```

---

# Step 10 — Optional apply

```bash
terraform apply tfplan
```

Show outputs:

```bash
terraform output
```

---

# Step 11 — Validate with AWS CLI

Set output variables:

```bash
ALB_SG_ID="$(terraform output -raw alb_sg_id)"
ECS_SG_ID="$(terraform output -raw ecs_tasks_sg_id)"
DB_SG_ID="$(terraform output -raw database_sg_id)"
BUCKET_NAME="$(terraform output -raw static_assets_bucket_name)"
ECR_REPO_NAME="$(terraform output -raw ecr_repository_name)"
```

Validate security groups:

```bash
aws ec2 describe-security-groups \
  --group-ids "$ALB_SG_ID" "$ECS_SG_ID" "$DB_SG_ID" \
  --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Description:Description,VpcId:VpcId}' \
  --output table
```

Validate S3 privacy controls:

```bash
aws s3api get-public-access-block \
  --bucket "$BUCKET_NAME"

aws s3api get-bucket-encryption \
  --bucket "$BUCKET_NAME"

aws s3api get-bucket-versioning \
  --bucket "$BUCKET_NAME"

aws s3api get-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME"
```

Validate ECR:

```bash
aws ecr describe-repositories \
  --repository-names "$ECR_REPO_NAME" \
  --query 'repositories[].{Name:repositoryName,Uri:repositoryUri,ScanOnPush:imageScanningConfiguration.scanOnPush,TagMutability:imageTagMutability,Encryption:encryptionConfiguration.encryptionType}' \
  --output table

aws ecr get-lifecycle-policy \
  --repository-name "$ECR_REPO_NAME" \
  --query 'lifecyclePolicyText' \
  --output text | jq .
```

---

# Step 12 — Create one validation script

Create `scripts/validate-phase-22.sh`:

```bash
cd ~/aws-production-capstone

cat > scripts/validate-phase-22.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../environments/dev"

echo "===== Terraform outputs ====="
terraform output

ALB_SG_ID="$(terraform output -raw alb_sg_id)"
ECS_SG_ID="$(terraform output -raw ecs_tasks_sg_id)"
DB_SG_ID="$(terraform output -raw database_sg_id)"
BUCKET_NAME="$(terraform output -raw static_assets_bucket_name)"
ECR_REPO_NAME="$(terraform output -raw ecr_repository_name)"

echo
echo "===== Security groups ====="
aws ec2 describe-security-groups \
  --group-ids "$ALB_SG_ID" "$ECS_SG_ID" "$DB_SG_ID" \
  --query 'SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}' \
  --output table

echo
echo "===== S3 public access block ====="
aws s3api get-public-access-block \
  --bucket "$BUCKET_NAME"

echo
echo "===== S3 encryption ====="
aws s3api get-bucket-encryption \
  --bucket "$BUCKET_NAME"

echo
echo "===== S3 versioning ====="
aws s3api get-bucket-versioning \
  --bucket "$BUCKET_NAME"

echo
echo "===== ECR repository ====="
aws ecr describe-repositories \
  --repository-names "$ECR_REPO_NAME" \
  --query 'repositories[].{Name:repositoryName,Uri:repositoryUri,ScanOnPush:imageScanningConfiguration.scanOnPush,TagMutability:imageTagMutability}' \
  --output table

echo
echo "Phase 22 validation completed."
EOF

chmod +x scripts/validate-phase-22.sh
```

Run:

```bash
./scripts/validate-phase-22.sh
```

---

# Common errors and fixes

## Error: `AccessDenied` on security groups

You need EC2 security group permissions:

```text
ec2:CreateSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:DescribeSecurityGroups
ec2:CreateTags
```

Start with:

```bash
aws sts get-caller-identity
aws configure list
```

---

## Error: `AccessDenied` on S3

You likely need:

```text
s3:CreateBucket
s3:PutBucketPublicAccessBlock
s3:PutBucketEncryption
s3:PutBucketVersioning
s3:PutLifecycleConfiguration
s3:GetBucket*
s3:DeleteBucket
```

Also check SCPs or permission boundaries if your identity has IAM restrictions.

---

## Error: `AccessDeniedException` on ECR

You likely need:

```text
ecr:CreateRepository
ecr:DescribeRepositories
ecr:PutLifecyclePolicy
ecr:GetLifecyclePolicy
ecr:TagResource
```

---

## Error: `ImageTagAlreadyExistsException` later

This is expected if you push the same tag twice to an immutable repository.

Fix:

```text
Use a new image tag for every build.
Example:
  commit SHA
  v1.0.1
  dev-20260725-001
```

Do not solve this by making production tags mutable unless you have a strong reason.

---

## Error: S3 bucket deletion fails

If you upload versioned objects later, deletion may fail if versions remain.

For this lab, `force_destroy = true` helps Terraform delete bucket objects during destroy. For production, keep `force_destroy = false` and use a controlled lifecycle/retention policy.

---

# Cleanup

To remove today’s resources:

```bash
cd ~/aws-production-capstone/environments/dev
terraform destroy
```

Validate cleanup:

```bash
aws ecr describe-repositories \
  --repository-names "$(terraform output -raw ecr_repository_name 2>/dev/null)" || true
```

If Terraform outputs are unavailable after destroy, search by prefix:

```bash
aws ecr describe-repositories \
  --query "repositories[?contains(repositoryName, 'aws-production-capstone-dev')].repositoryName" \
  --output table

aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'aws-production-capstone-dev-assets')].Name" \
  --output table
```

---

# What you built today

```text
Terraform modules:
  security-groups
  storage
  container-registry

AWS resources:
  ALB security group
  ECS task security group
  database security group
  private encrypted versioned S3 assets bucket
  S3 lifecycle cleanup
  ECR repository
  ECR lifecycle policy
  CloudFront OAC policy design document
```

Resume-ready takeaway:

```text
Extended a Terraform-based AWS production capstone with least-privilege security group chaining, a private encrypted S3 assets bucket prepared for CloudFront OAC, and an immutable ECR container registry with scan-on-push and lifecycle cleanup for production-ready ECS deployments.
```

# Next build phase

```text
Lesson 23 — Add ALB, target group, CS cluster foundation, CloudWatch log group, and task definition skeleton.
```

[1]: https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html?utm_source=chatgpt.com "Security group rules - Amazon Virtual Private Cloud"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html?utm_source=chatgpt.com "Blocking public access to your Amazon S3 storage - Amazon Simple Storage Service"
[3]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/Repositories.html?utm_source=chatgpt.com "Amazon ECR private repositories - Amazon ECR"
[4]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html?utm_source=chatgpt.com "Scan images for software vulnerabilities in Amazon ECR - Amazon ECR"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html?utm_source=chatgpt.com "Preventing image tags from being overwritten in Amazon ECR - Amazon ECR"
[6]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/lp_creation.html?utm_source=chatgpt.com "Creating a lifecycle policy for a repository in Amazon ECR - Amazon ECR"
