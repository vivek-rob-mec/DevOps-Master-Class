# Module 12 — Terraform, Ansible, and IaC

# Lesson 12.10 — S3 and CloudFront with Terraform

In Lesson 12.9, you built:

```text id="recap-12-9"
Application Load Balancer
ALB security group
Target Group
HTTP listener
Target group attachments
ALB-to-EC2 security group rule
Target health validation
502/503 troubleshooting
```

Now we add **S3 and CloudFront**.

CloudFront can serve content from origins such as S3 buckets and HTTP origins like an ALB. For private S3 origins, AWS recommends **Origin Access Control**, or OAC, so users access S3 objects through CloudFront instead of directly from the bucket. CloudFront also supports custom origins, including HTTP origins such as load balancers. ([AWS Documentation][1])

---

# 1. Goal

Build a production-style CDN layer with Terraform.

You will create:

```text id="goal"
private S3 assets bucket
S3 versioning
S3 encryption
S3 public access block
S3 ownership controls
sample static index object
CloudFront Origin Access Control
CloudFront distribution
S3 origin
ALB origin
cache behavior
viewer HTTP to HTTPS redirect
SPA-style custom error response
S3 bucket policy allowing only CloudFront distribution access
CloudFront validation scripts
CloudFront 403 troubleshooting runbooks
cleanup and cost-safety scripts
```

Architecture:

```text id="architecture"
Viewer
  ↓
CloudFront Distribution
  ├── default origin: ALB
  │     ↓
  │   Application Load Balancer
  │     ↓
  │   EC2 nginx /health
  │
  └── ordered behavior /assets/*
        ↓
      Private S3 bucket via OAC
```

This gives you both real-world patterns:

```text id="origin-patterns"
Static assets:
  CloudFront -> private S3 via OAC

Dynamic app:
  CloudFront -> ALB custom origin
```

---

# 2. Cost Warning

This lesson can create:

```text id="cost"
S3 bucket
S3 objects
CloudFront distribution
ALB from previous lesson
EC2 from previous lesson
public IPv4 from previous lesson
```

CloudFront has a free tier for many accounts but still can generate charges depending on requests, data transfer, invalidations, logs, and region usage. Keep this lab small and clean up when finished.

---

# 3. What You Will Learn

```text id="lesson-map"
12.10.1   S3 private bucket mental model
12.10.2   CloudFront mental model
12.10.3   S3 origin vs ALB origin
12.10.4   Origin Access Control
12.10.5   OAC vs old OAI
12.10.6   bucket policy for CloudFront
12.10.7   default cache behavior
12.10.8   ordered cache behavior
12.10.9   viewer_protocol_policy
12.10.10  allowed_methods vs cached_methods
12.10.11  SPA custom error response
12.10.12  ACM us-east-1 reminder
12.10.13  CloudFront deployment delay
12.10.14  CloudFront 403 troubleshooting
12.10.15  S3 AccessDenied debugging
12.10.16  ALB origin debugging
12.10.17  validation and cleanup
```

Terraform has separate AWS provider resources for `aws_cloudfront_distribution` and `aws_cloudfront_origin_access_control`; OAC is used by CloudFront distributions with S3 origins. ([Terraform Registry][2])

---

# 4. Never Confuse These

## S3 Website Endpoint vs S3 REST Endpoint

```text id="s3-endpoints"
S3 website endpoint:
  public website-hosting style endpoint
  does not support OAC in the same private-origin way

S3 REST/regional endpoint:
  bucket_regional_domain_name
  correct for private S3 origin with OAC
```

For this lesson:

```text id="course-choice"
CloudFront -> S3 regional domain name -> private bucket
```

---

## OAC vs OAI

```text id="oac-vs-oai"
OAC:
  newer recommended CloudFront access control for S3 origins

OAI:
  older origin access identity pattern
```

AWS CloudFront docs describe both OAC and OAI for authenticated requests to S3 origins, and recommend OAC for current S3 private-origin setups. ([AWS Documentation][1])

---

## CloudFront Distribution vs Origin

```text id="distribution-vs-origin"
CloudFront distribution:
  edge-facing CDN configuration

Origin:
  backend source CloudFront fetches content from
```

Example:

```text id="origins"
Origin 1:
  ALB DNS name

Origin 2:
  S3 bucket regional domain name
```

---

## Default Behavior vs Ordered Behavior

```text id="behavior"
default_cache_behavior:
  fallback behavior for requests that do not match ordered behaviors

ordered_cache_behavior:
  specific path patterns checked before default behavior
```

Example:

```text id="behavior-example"
/assets/* -> S3 origin
everything else -> ALB origin
```

---

## Viewer Protocol vs Origin Protocol

```text id="viewer-origin-protocol"
viewer_protocol_policy:
  viewer -> CloudFront

origin_protocol_policy:
  CloudFront -> ALB or custom origin
```

Example:

```text id="protocol-example"
viewer_protocol_policy = redirect-to-https
origin_protocol_policy = http-only for dev ALB origin
```

---

## ACM Region Rule

```text id="acm-rule"
CloudFront custom domain certificate:
  ACM certificate must be in us-east-1

ALB regional certificate:
  ACM certificate must be in the ALB region, here ap-south-1
```

For this lesson, we use the default CloudFront domain to avoid certificate/domain complexity.

---

# 5. Create Lesson Folder

```bash id="create-folder"
cd ~/devops-masterclass

mkdir -p 12-terraform-ansible-iac/12.10-s3-cloudfront/{notes,scripts,runbooks,reports,assets}
```

Check:

```bash id="tree-folder"
tree -L 3 12-terraform-ansible-iac/12.10-s3-cloudfront
```

---

# 6. Create S3 + CloudFront Mental Model Notes

```bash id="mental-note"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/notes/s3-cloudfront-mental-model.md
```

Paste:

```markdown id="mental-note-content"
# S3 and CloudFront Mental Model

## S3 private bucket

S3 stores static files such as:

- images
- CSS
- JavaScript
- downloads
- static HTML

For production, keep buckets private and expose content through CloudFront.

## CloudFront

CloudFront is AWS's CDN.

It caches content at edge locations and forwards cache misses to origins.

## Origin

An origin is where CloudFront fetches content.

Examples:

- S3 bucket regional domain
- Application Load Balancer DNS name
- custom HTTP server

## OAC

Origin Access Control lets CloudFront authenticate to S3.

Viewer -> CloudFront -> private S3

Users should not access the S3 bucket directly.

## This lesson design

Default path:
  CloudFront -> ALB

/assets/* path:
  CloudFront -> private S3 bucket

## Golden rule

CloudFront 403 usually means origin access, bucket policy, object key, host header, protocol, or behavior mismatch.
```

---

# 7. Create Never-Forget Notes

```bash id="never-note"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/notes/never-confuse-cloudfront-points.md
```

Paste:

````markdown id="never-note-content"
# Never Forget — S3 and CloudFront

## 1. Private S3 needs bucket policy

OAC alone is not enough.
The S3 bucket policy must allow the CloudFront distribution to read objects.

## 2. Use S3 regional domain for private S3 origin

Use:

```text
bucket_regional_domain_name
````

not the website endpoint.

## 3. CloudFront deployment takes time

Distribution status must become:

```text
Deployed
```

## 4. 403 does not always mean IAM user denied

CloudFront 403 can mean:

* missing S3 object
* S3 bucket policy denies CloudFront
* wrong origin domain
* wrong behavior path
* wrong Host header
* OAC not attached
* object encrypted with inaccessible KMS key
* origin blocks request

## 5. CloudFront default certificate is enough for default domain

For custom domain, use ACM certificate in us-east-1.

## 6. ALB origin must be reachable by CloudFront

For dev:

```text
CloudFront -> ALB HTTP :80
```

## 7. S3 origin and ALB origin behave differently

S3 origin:
object storage

ALB origin:
dynamic HTTP application origin

## 8. invalidation is not deletion

Invalidation removes cached objects from CloudFront edge caches.
It does not delete origin objects.

## 9. Do not make S3 public just to fix CloudFront

Fix OAC and bucket policy instead.

## 10. CloudFront is global

Many regional AWS resources live in ap-south-1.
CloudFront is a global service.

````

---

# 8. Create Sample Asset Files

```bash id="asset-files"
cd ~/devops-masterclass

cat > 12-terraform-ansible-iac/12.10-s3-cloudfront/assets/index.html <<'EOF'
<!doctype html>
<html>
  <head>
    <title>DevOps Masterclass CloudFront</title>
  </head>
  <body>
    <h1>CloudFront + S3 asset origin is working</h1>
    <p>This object is stored in private S3 and served through CloudFront.</p>
  </body>
</html>
EOF

cat > 12-terraform-ansible-iac/12.10-s3-cloudfront/assets/health.json <<'EOF'
{
  "status": "healthy",
  "origin": "s3",
  "managed_by": "terraform",
  "lesson": "12.10-s3-cloudfront"
}
EOF
````

---

# 9. Upgrade Storage Module to Real S3

From Module 12 root:

```bash id="cd-module-root"
cd ~/devops-masterclass/12-terraform-ansible-iac
```

Update `modules/storage/versions.tf`:

```bash id="storage-versions"
cat > modules/storage/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
```

Update `modules/storage/variables.tf`:

```bash id="storage-vars"
cat > modules/storage/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
  nullable    = false
}

variable "environment" {
  description = "Environment name."
  type        = string
  nullable    = false
}

variable "enable_versioning" {
  description = "Whether bucket versioning should be enabled."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Whether S3 bucket force_destroy should be allowed."
  type        = bool
  default     = false
}

variable "assets_path" {
  description = "Local path containing static asset files."
  type        = string
  nullable    = false
}

variable "bucket_name_override" {
  description = "Optional globally unique assets bucket name override."
  type        = string
  default     = ""
}
EOF
```

Update `modules/storage/main.tf`:

```bash id="storage-main"
cat > modules/storage/main.tf <<'EOF'
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_suffix = data.aws_caller_identity.current.account_id
  region_suffix  = data.aws_region.current.name

  generated_assets_bucket_name = lower("${var.name_prefix}-assets-${local.account_suffix}-${local.region_suffix}")

  assets_bucket_name = var.bucket_name_override != "" ? var.bucket_name_override : local.generated_assets_bucket_name

  asset_files = fileset(var.assets_path, "**/*")
}

resource "aws_s3_bucket" "assets" {
  bucket        = local.assets_bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.common_tags,
    {
      Name      = local.assets_bucket_name
      Component = "storage"
      Purpose   = "cloudfront-assets"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
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

resource "aws_s3_object" "assets" {
  for_each = local.asset_files

  bucket = aws_s3_bucket.assets.id
  key    = "assets/${each.value}"
  source = "${var.assets_path}/${each.value}"
  etag   = filemd5("${var.assets_path}/${each.value}")

  content_type = lookup(
    {
      html = "text/html"
      json = "application/json"
      css  = "text/css"
      js   = "application/javascript"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
      txt  = "text/plain"
    },
    lower(regex("[^.]+$", each.value)),
    "binary/octet-stream"
  )

  tags = merge(
    var.common_tags,
    {
      Component = "storage"
    }
  )

  depends_on = [
    aws_s3_bucket_ownership_controls.assets,
    aws_s3_bucket_public_access_block.assets
  ]
}

resource "terraform_data" "storage_contract" {
  input = {
    assets_bucket_name                 = aws_s3_bucket.assets.bucket
    assets_bucket_arn                  = aws_s3_bucket.assets.arn
    assets_bucket_regional_domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    versioning_enabled                 = var.enable_versioning
    force_destroy                      = var.force_destroy
    block_public_access                = true
    encryption                         = "AES256"
    uploaded_asset_keys                = [for key in keys(aws_s3_object.assets) : "assets/${key}"]
    tags                               = var.common_tags
  }
}
EOF
```

Update `modules/storage/outputs.tf`:

```bash id="storage-outputs"
cat > modules/storage/outputs.tf <<'EOF'
output "contract" {
  description = "Storage module contract."
  value       = terraform_data.storage_contract.output
}

output "assets_bucket_name" {
  description = "Assets S3 bucket name."
  value       = aws_s3_bucket.assets.bucket
}

output "assets_bucket_arn" {
  description = "Assets S3 bucket ARN."
  value       = aws_s3_bucket.assets.arn
}

output "assets_bucket_regional_domain_name" {
  description = "Regional S3 bucket domain name for CloudFront private S3 origin."
  value       = aws_s3_bucket.assets.bucket_regional_domain_name
}

output "uploaded_asset_keys" {
  description = "Uploaded asset object keys."
  value       = [for key in keys(aws_s3_object.assets) : "assets/${key}"]
}
EOF
```

Update README:

````bash id="storage-readme"
cat > modules/storage/README.md <<'EOF'
# Storage Module

## Purpose

Creates a private S3 bucket for CloudFront static assets.

## Resources

- aws_s3_bucket
- aws_s3_bucket_public_access_block
- aws_s3_bucket_ownership_controls
- aws_s3_bucket_versioning
- aws_s3_bucket_server_side_encryption_configuration
- aws_s3_object

## CloudFront origin

Use:

```text
assets_bucket_regional_domain_name
````

for the CloudFront S3 origin.

## Security

The bucket blocks public access.
CloudFront access is granted later through a bucket policy using OAC and the distribution ARN.

## Inputs

* name_prefix
* common_tags
* environment
* enable_versioning
* force_destroy
* assets_path
* bucket_name_override

## Outputs

* assets_bucket_name
* assets_bucket_arn
* assets_bucket_regional_domain_name
* uploaded_asset_keys
* contract
  EOF

````

---

# 10. Upgrade CDN Module to Real CloudFront

Update `modules/cdn/versions.tf`:

```bash id="cdn-versions"
cat > modules/cdn/versions.tf <<'EOF'
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
EOF
````

Update `modules/cdn/variables.tf`:

```bash id="cdn-vars"
cat > modules/cdn/variables.tf <<'EOF'
variable "name_prefix" {
  description = "Common naming prefix."
  type        = string
  nullable    = false
}

variable "common_tags" {
  description = "Common tags."
  type        = map(string)
  nullable    = false
}

variable "enable_cloudfront" {
  description = "Whether CloudFront should be enabled."
  type        = bool
  default     = false
}

variable "s3_origin_domain_name" {
  description = "S3 bucket regional domain name."
  type        = string
  nullable    = false
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN for OAC bucket policy."
  type        = string
  nullable    = false
}

variable "s3_bucket_name" {
  description = "S3 bucket name for bucket policy."
  type        = string
  nullable    = false
}

variable "alb_origin_domain_name" {
  description = "ALB DNS name for custom origin."
  type        = string
  nullable    = false
}

variable "default_origin_type" {
  description = "Default CloudFront origin type."
  type        = string
  default     = "alb"

  validation {
    condition     = contains(["alb", "s3"], var.default_origin_type)
    error_message = "default_origin_type must be alb or s3."
  }
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "default_root_object" {
  description = "Default root object."
  type        = string
  default     = "assets/index.html"
}

variable "comment" {
  description = "CloudFront distribution comment."
  type        = string
  default     = "DevOps Masterclass CloudFront distribution"
}
EOF
```

Update `modules/cdn/main.tf`:

```bash id="cdn-main"
cat > modules/cdn/main.tf <<'EOF'
locals {
  s3_origin_id  = "${var.name_prefix}-s3-origin"
  alb_origin_id = "${var.name_prefix}-alb-origin"

  default_target_origin_id = var.default_origin_type == "s3" ? local.s3_origin_id : local.alb_origin_id
}

resource "aws_cloudfront_origin_access_control" "s3" {
  count = var.enable_cloudfront ? 1 : 0

  name                              = "${var.name_prefix}-s3-oac"
  description                       = "OAC for ${var.name_prefix} private S3 assets bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.comment
  default_root_object = var.default_root_object
  price_class         = var.price_class

  origin {
    domain_name              = var.s3_origin_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.s3[0].id
  }

  origin {
    domain_name = var.alb_origin_domain_name
    origin_id   = local.alb_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = local.default_target_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    compress = true

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }

      headers = ["Host", "CloudFront-Forwarded-Proto"]
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/assets/*"
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/assets/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/assets/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.name_prefix}-cloudfront"
      Component = "cdn"
    }
  )
}

data "aws_iam_policy_document" "allow_cloudfront_s3_read" {
  count = var.enable_cloudfront ? 1 : 0

  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]

    resources = ["${var.s3_bucket_arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_s3_read" {
  count = var.enable_cloudfront ? 1 : 0

  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.allow_cloudfront_s3_read[0].json
}

resource "terraform_data" "cdn_contract" {
  input = {
    enabled                  = var.enable_cloudfront
    distribution_id          = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].id : null
    distribution_arn         = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].arn : null
    distribution_domain_name = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
    hosted_zone_id           = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].hosted_zone_id : null
    status                   = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].status : null
    s3_origin_id             = local.s3_origin_id
    alb_origin_id            = local.alb_origin_id
    default_origin_type      = var.default_origin_type
    default_root_object      = var.default_root_object
    price_class              = var.price_class
  }
}
EOF
```

Important:

```text id="distribution-note"
CloudFront distribution creation can take several minutes.
Do not assume it is ready until Status is Deployed.
```

CloudFront OAC makes it possible to block public access to the S3 origin while allowing viewers to access files only through CloudFront; the bucket policy must grant CloudFront service-principal access scoped to the distribution ARN. ([AWS Documentation][3])

Update `modules/cdn/outputs.tf`:

```bash id="cdn-outputs"
cat > modules/cdn/outputs.tf <<'EOF'
output "contract" {
  description = "CDN module contract."
  value       = terraform_data.cdn_contract.output
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].id : null
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].arn : null
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].domain_name : null
}

output "hosted_zone_id" {
  description = "CloudFront hosted zone ID."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].hosted_zone_id : null
}

output "status" {
  description = "CloudFront distribution status."
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.this[0].status : null
}
EOF
```

Update README:

````bash id="cdn-readme"
cat > modules/cdn/README.md <<'EOF'
# CDN Module

## Purpose

Creates a CloudFront distribution with:

- private S3 origin through OAC
- ALB custom origin
- default behavior
- ordered /assets/* behavior
- default CloudFront certificate
- S3 bucket policy allowing distribution access

## Origins

S3 origin:

```text
/assets/*
````

ALB origin:

```text id="360rpt"
default behavior
```

## OAC

Origin Access Control is used for private S3 access.

## Custom domain

This lesson uses the default CloudFront domain.

For custom domains:

* create ACM certificate in us-east-1 for CloudFront
* add aliases to distribution
* point Route 53/domain DNS to CloudFront

## Outputs

* distribution_id
* distribution_arn
* distribution_domain_name
* hosted_zone_id
* status
* contract
  EOF

````

---

# 11. Update Environment Root Composition

Update all environment `main.tf` files to pass real storage outputs into CDN.

```bash id="root-main-update"
cat > /tmp/module12_10_main.tf <<'EOF'
module "networking" {
  source = "../../modules/networking"

  name_prefix    = local.name_prefix
  common_tags    = local.common_tags
  network_config = var.network_config
}

module "security_group" {
  source = "../../modules/security-group"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  vpc_id                = module.networking.vpc_id
  allowed_ingress_ports = var.allowed_ingress_ports
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  allow_all_egress      = true
}

module "storage" {
  source = "../../modules/storage"

  name_prefix       = local.name_prefix
  common_tags       = local.common_tags
  environment       = local.normalized_env
  enable_versioning = true
  force_destroy     = local.normalized_env == "prod" ? false : true
  assets_path       = "${path.root}/../../12.10-s3-cloudfront/assets"
}

module "iam" {
  source = "../../modules/iam"

  name_prefix      = local.name_prefix
  common_tags      = local.common_tags
  enable_ssm       = var.compute_config.enable_ssm
  app_bucket_names = [module.storage.assets_bucket_name]
}

module "compute" {
  source = "../../modules/compute"

  name_prefix                 = local.name_prefix
  common_tags                 = local.common_tags
  environment                 = local.normalized_env
  project_name                = local.normalized_project
  compute_config              = var.compute_config
  public_subnet_ids           = module.networking.public_subnet_ids
  private_subnet_ids          = module.networking.private_subnet_ids
  security_group_id           = module.security_group.security_group_id
  instance_profile_name       = module.iam.instance_profile_name
  use_public_subnet_for_dev   = local.normalized_env == "dev" ? true : false
  associate_public_ip_address = local.normalized_env == "dev" ? true : false
  user_data_template_path     = "${path.root}/../../12.8-ec2-security-groups/user-data/app-bootstrap.sh.tftpl"
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  target_instance_ids = module.compute.instance_ids
  app_port            = 80
  enable_alb          = var.feature_flags.enable_alb
  health_check_path   = "/health"
  allowed_http_cidrs  = ["0.0.0.0/0"]
  internal            = false
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_to_ec2_http" {
  count = var.feature_flags.enable_alb ? 1 : 0

  security_group_id            = module.security_group.security_group_id
  referenced_security_group_id = module.load_balancer.alb_security_group_id
  description                  = "Allow HTTP from ALB security group to EC2"
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.name_prefix}-allow-alb-to-ec2-http"
      Component = "load-balancer"
      Direction = "ingress"
    }
  )
}

module "cdn" {
  source = "../../modules/cdn"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  enable_cloudfront     = var.feature_flags.enable_cloudfront
  s3_origin_domain_name = module.storage.assets_bucket_regional_domain_name
  s3_bucket_arn         = module.storage.assets_bucket_arn
  s3_bucket_name        = module.storage.assets_bucket_name
  alb_origin_domain_name = module.load_balancer.alb_dns_name
  default_origin_type   = "alb"
  default_root_object   = "assets/index.html"
  price_class           = "PriceClass_100"
  comment               = "DevOps Masterclass ${local.normalized_env} CloudFront distribution"
}

resource "terraform_data" "environment_contract" {
  input = {
    project_name = local.normalized_project
    environment  = local.normalized_env
    aws_region   = var.aws_region
    name_prefix  = local.name_prefix
    tags         = local.common_tags
  }
}

resource "terraform_data" "module_composition_contract" {
  input = {
    dependency_flow = [
      "networking -> security_group",
      "networking -> compute",
      "security_group -> compute",
      "iam -> compute",
      "compute -> load_balancer",
      "load_balancer -> ec2 security group ingress rule",
      "storage -> cdn s3 origin",
      "load_balancer -> cdn alb origin",
      "cdn -> s3 bucket policy",
      "storage -> iam",
    ]

    vpc_id                     = module.networking.vpc_id
    ec2_security_group_id      = module.security_group.security_group_id
    alb_security_group_id      = module.load_balancer.alb_security_group_id
    instance_ids               = module.compute.instance_ids
    public_ips                 = module.compute.public_ips
    private_ips                = module.compute.private_ips
    alb_dns_name               = module.load_balancer.alb_dns_name
    target_group_arn           = module.load_balancer.target_group_arn
    assets_bucket_name         = module.storage.assets_bucket_name
    cloudfront_domain_name     = module.cdn.distribution_domain_name
    cloudfront_distribution_id = module.cdn.distribution_id
    instance_profile_name      = module.iam.instance_profile_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_10_main.tf environments/$env/main.tf
done
````

---

# 12. Enable CloudFront in Dev tfvars

Your earlier dev config had CloudFront disabled. Enable it for this lesson:

```bash id="enable-dev-cloudfront"
python3 - <<'PY'
from pathlib import Path
p = Path("environments/dev/terraform.tfvars.example")
s = p.read_text()
s = s.replace("enable_cloudfront = false", "enable_cloudfront = true")
p.write_text(s)
PY
```

For staging/prod, keep as-is unless you intentionally want to test them later.

---

# 13. Update Environment Outputs

```bash id="outputs-update"
cat > /tmp/module12_10_outputs.tf <<'EOF'
output "environment_contract" {
  description = "Environment metadata and tagging contract."
  value       = terraform_data.environment_contract.output
}

output "module_composition_contract" {
  description = "Shows how module outputs are chained through the root module."
  value       = terraform_data.module_composition_contract.output
}

output "name_prefix" {
  description = "Common naming prefix."
  value       = local.name_prefix
}

output "networking_contract" {
  description = "Networking module contract."
  value       = module.networking.contract
}

output "security_group_contract" {
  description = "EC2 security group contract."
  value       = module.security_group.security_group_contract
}

output "compute_contract" {
  description = "Compute module contract."
  value       = module.compute.contract
}

output "iam_contract" {
  description = "IAM module contract."
  value       = module.iam.contract
}

output "storage_contract" {
  description = "Storage module contract."
  value       = module.storage.contract
}

output "load_balancer_contract" {
  description = "Load balancer module contract."
  value       = module.load_balancer.contract
}

output "cdn_contract" {
  description = "CDN module contract."
  value       = module.cdn.contract
}

output "assets_bucket_name" {
  description = "Private S3 assets bucket name."
  value       = module.storage.assets_bucket_name
}

output "assets_bucket_regional_domain_name" {
  description = "S3 regional domain name used by CloudFront."
  value       = module.storage.assets_bucket_regional_domain_name
}

output "uploaded_asset_keys" {
  description = "Uploaded S3 asset keys."
  value       = module.storage.uploaded_asset_keys
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = module.load_balancer.alb_dns_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.cdn.distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cdn.distribution_domain_name
}

output "cloudfront_distribution_status" {
  description = "CloudFront distribution deployment status."
  value       = module.cdn.status
}

output "future_ansible_inventory_contract" {
  description = "Future handoff contract for Ansible inventory generation."
  value = {
    environment                    = local.normalized_env
    instance_names                 = module.compute.instance_names
    instance_ids                   = module.compute.instance_ids
    public_ips                     = module.compute.public_ips
    private_ips                    = module.compute.private_ips
    app_port                       = module.compute.app_port
    instance_role_name             = module.iam.instance_role_name
    ec2_security_group_id          = module.security_group.security_group_id
    alb_dns_name                   = module.load_balancer.alb_dns_name
    target_group_arn               = module.load_balancer.target_group_arn
    assets_bucket_name             = module.storage.assets_bucket_name
    cloudfront_distribution_domain = module.cdn.distribution_domain_name
  }
}
EOF

for env in dev staging prod; do
  cp /tmp/module12_10_outputs.tf environments/$env/outputs.tf
done
```

---

# 14. Plan Dev CloudFront

Check identity:

```bash id="aws-check"
cd ~/devops-masterclass

aws sts get-caller-identity
aws configure list

export AWS_REGION=ap-south-1
export AWS_DEFAULT_REGION=ap-south-1
```

Go to dev:

```bash id="cd-dev"
cd ~/devops-masterclass/12-terraform-ansible-iac/environments/dev
```

Initialize:

```bash id="dev-init"
terraform init -reconfigure \
  -backend-config=../../12.3-terraform-state-backend/backend-configs/dev.s3.hcl
```

Format and validate:

```bash id="dev-fmt"
terraform fmt -recursive
terraform validate
```

Plan:

```bash id="dev-plan"
terraform plan -var-file=terraform.tfvars.example -out=tfplan-12-10-dev
```

Review:

```bash id="dev-show"
terraform show tfplan-12-10-dev
```

Expected new resources:

```text id="expected-plan"
module.storage.aws_s3_bucket.assets
module.storage.aws_s3_bucket_public_access_block.assets
module.storage.aws_s3_bucket_ownership_controls.assets
module.storage.aws_s3_bucket_versioning.assets
module.storage.aws_s3_bucket_server_side_encryption_configuration.assets
module.storage.aws_s3_object.assets["index.html"]
module.storage.aws_s3_object.assets["health.json"]

module.cdn.aws_cloudfront_origin_access_control.s3[0]
module.cdn.aws_cloudfront_distribution.this[0]
module.cdn.aws_s3_bucket_policy.allow_cloudfront_s3_read[0]
```

---

# 15. Apply Dev CloudFront

```bash id="dev-apply"
terraform apply tfplan-12-10-dev
```

This may take several minutes because CloudFront distributions take time to deploy.

Store outputs:

```bash id="store-outputs"
CF_ID="$(terraform output -raw cloudfront_distribution_id)"
CF_DOMAIN="$(terraform output -raw cloudfront_distribution_domain_name)"
S3_BUCKET="$(terraform output -raw assets_bucket_name)"
ALB_DNS="$(terraform output -raw alb_dns_name)"

echo "CF_ID=$CF_ID"
echo "CF_DOMAIN=$CF_DOMAIN"
echo "S3_BUCKET=$S3_BUCKET"
echo "ALB_DNS=$ALB_DNS"
```

---

# 16. Wait for CloudFront Deployment

```bash id="wait-cloudfront"
aws cloudfront wait distribution-deployed --id "$CF_ID"
```

Check status:

```bash id="check-cf-status"
aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query 'Distribution.{Id:Id,Status:Status,DomainName:DomainName,Enabled:DistributionConfig.Enabled}' \
  --output table
```

Expected:

```text id="deployed"
Status = Deployed
Enabled = true
```

CloudFront configuration changes propagate globally and the distribution status changes to `Deployed` when propagation is complete. AWS CLI includes a `distribution-deployed` waiter for this lifecycle.

---

# 17. Validate S3 Is Private

Direct S3 access should fail unless you use authorized AWS credentials.

Try anonymous-style HTTP access:

```bash id="direct-s3-test"
curl -I "https://$S3_BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html"
```

Expected:

```text id="s3-private-expected"
HTTP 403 or access denied-style response
```

Check public access block:

```bash id="s3-public-block"
aws s3api get-public-access-block \
  --bucket "$S3_BUCKET"
```

Check bucket policy:

```bash id="s3-policy"
aws s3api get-bucket-policy \
  --bucket "$S3_BUCKET" \
  --query Policy \
  --output text | jq .
```

The S3 bucket policy should allow `cloudfront.amazonaws.com` to perform `s3:GetObject` only when the `AWS:SourceArn` matches your CloudFront distribution ARN.

---

# 18. Validate CloudFront S3 Origin

```bash id="cf-s3-curl"
curl -I "https://$CF_DOMAIN/assets/index.html"
curl "https://$CF_DOMAIN/assets/health.json"
```

Expected:

```text id="cf-s3-expected"
HTTP 200
health.json shows origin = s3
```

---

# 19. Validate CloudFront ALB Origin

The default behavior forwards to ALB.

```bash id="cf-alb-curl"
curl -I "https://$CF_DOMAIN/"
curl "https://$CF_DOMAIN/health"
curl "https://$CF_DOMAIN/metadata.json"
```

Expected:

```text id="cf-alb-expected"
HTTP 200
/health returns healthy
/metadata.json comes from EC2 nginx behind ALB
```

If `/metadata.json` fails but `/assets/health.json` works:

```text id="alb-origin-issue"
S3 origin is working.
ALB origin path needs debugging.
```

If `/assets/health.json` fails but `/health` works:

```text id="s3-origin-issue"
ALB origin is working.
S3/OAC/bucket policy/path behavior needs debugging.
```

---

# 20. Create CloudFront Validation Script

```bash id="validate-script"
cd ~/devops-masterclass

nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh
```

Paste:

```bash id="validate-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== CloudFront AWS Validation ====="
echo "Environment: $ENVIRONMENT"

CF_ID="$(terraform output -raw cloudfront_distribution_id)"
CF_DOMAIN="$(terraform output -raw cloudfront_distribution_domain_name)"
S3_BUCKET="$(terraform output -raw assets_bucket_name)"
ALB_DNS="$(terraform output -raw alb_dns_name)"

echo "CloudFront ID: $CF_ID"
echo "CloudFront domain: $CF_DOMAIN"
echo "S3 bucket: $S3_BUCKET"
echo "ALB DNS: $ALB_DNS"

echo
echo "CloudFront distribution:"
aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query 'Distribution.{Id:Id,Status:Status,DomainName:DomainName,Enabled:DistributionConfig.Enabled,Origins:DistributionConfig.Origins.Items[].DomainName}' \
  --output json

STATUS="$(aws cloudfront get-distribution --id "$CF_ID" --query 'Distribution.Status' --output text)"

if [ "$STATUS" != "Deployed" ]; then
  echo "CloudFront status is $STATUS. Waiting for Deployed..."
  aws cloudfront wait distribution-deployed --id "$CF_ID"
fi

echo
echo "S3 public access block:"
aws s3api get-public-access-block \
  --bucket "$S3_BUCKET"

echo
echo "S3 objects:"
aws s3 ls "s3://$S3_BUCKET/assets/" --recursive

echo
echo "Direct S3 HTTP check should usually fail for private bucket:"
set +e
curl -I "https://$S3_BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html"
set -e

echo
echo "CloudFront S3 origin checks:"
curl -fsSI "https://$CF_DOMAIN/assets/index.html"
curl -fsS "https://$CF_DOMAIN/assets/health.json" | jq .

echo
echo "CloudFront ALB origin checks:"
curl -fsSI "https://$CF_DOMAIN/"
curl -fsS "https://$CF_DOMAIN/health"

echo
echo "CloudFront validation completed."
```

Make executable:

```bash id="chmod-validate"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh
```

Run:

```bash id="run-validate"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh
```

---

# 21. Create CloudFront Plan Script

```bash id="plan-script"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/plan-cloudfront.sh
```

Paste:

```bash id="plan-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"
BACKEND_CONFIG="../../12.3-terraform-state-backend/backend-configs/$ENVIRONMENT.s3.hcl"
REPORT_DIR="../../12.10-s3-cloudfront/reports"

mkdir -p "$BASE/12.10-s3-cloudfront/reports"

cd "$ENV_DIR"

echo "===== Terraform CloudFront Plan ====="
echo "Environment: $ENVIRONMENT"
echo "Current workspace: $(terraform workspace show 2>/dev/null || echo not-initialized)"

terraform init -reconfigure -backend-config="$BACKEND_CONFIG"
terraform fmt -recursive
terraform validate

terraform plan -var-file=terraform.tfvars.example -out="tfplan-12-10-$ENVIRONMENT"
terraform show -no-color "tfplan-12-10-$ENVIRONMENT" > "$REPORT_DIR/$ENVIRONMENT-cloudfront-plan.txt"

echo
echo "Plan saved:"
echo "$BASE/12.10-s3-cloudfront/reports/$ENVIRONMENT-cloudfront-plan.txt"
echo
echo "Apply manually from $ENV_DIR with:"
echo "terraform apply tfplan-12-10-$ENVIRONMENT"
```

Make executable:

```bash id="chmod-plan"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/plan-cloudfront.sh
```

Run:

```bash id="run-plan"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/plan-cloudfront.sh
```

---

# 22. Create CloudFront Debug Script

```bash id="debug-script"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/debug-cloudfront.sh
```

Paste:

```bash id="debug-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== CloudFront Debug ====="
echo "Environment: $ENVIRONMENT"

CF_ID="$(terraform output -raw cloudfront_distribution_id)"
CF_DOMAIN="$(terraform output -raw cloudfront_distribution_domain_name)"
S3_BUCKET="$(terraform output -raw assets_bucket_name)"
ALB_DNS="$(terraform output -raw alb_dns_name)"

echo "CF_ID=$CF_ID"
echo "CF_DOMAIN=$CF_DOMAIN"
echo "S3_BUCKET=$S3_BUCKET"
echo "ALB_DNS=$ALB_DNS"

echo
echo "Distribution config summary:"
aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'DistributionConfig.{Enabled:Enabled,DefaultRootObject:DefaultRootObject,Origins:Origins.Items[].{Id:Id,DomainName:DomainName},DefaultTarget:DefaultCacheBehavior.TargetOriginId,Ordered:CacheBehaviors.Items[].{PathPattern:PathPattern,TargetOriginId:TargetOriginId},ViewerCertificate:ViewerCertificate}' \
  --output json

echo
echo "Bucket policy:"
aws s3api get-bucket-policy \
  --bucket "$S3_BUCKET" \
  --query Policy \
  --output text | jq . || true

echo
echo "Bucket public access block:"
aws s3api get-public-access-block --bucket "$S3_BUCKET" || true

echo
echo "Bucket objects:"
aws s3 ls "s3://$S3_BUCKET/assets/" --recursive || true

echo
echo "Origin direct checks:"
echo "S3 direct:"
curl -I "https://$S3_BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html" || true

echo
echo "ALB direct:"
curl -I "http://$ALB_DNS/health" || true

echo
echo "CloudFront checks:"
curl -Iv "https://$CF_DOMAIN/assets/index.html" || true
curl -Iv "https://$CF_DOMAIN/health" || true

echo
echo "Debug hints:"
cat <<'EOF'
For S3-origin 403:
  - confirm object key exists
  - confirm behavior path /assets/* points to S3 origin
  - confirm OAC is attached to S3 origin
  - confirm bucket policy allows cloudfront.amazonaws.com with correct SourceArn
  - confirm S3 public access block is not being bypassed by public policy attempts
  - confirm using bucket_regional_domain_name, not website endpoint

For ALB-origin 502/503/504:
  - confirm ALB DNS works directly
  - confirm target group has healthy targets
  - confirm EC2 SG allows ALB SG
  - confirm origin_protocol_policy matches ALB listener
  - confirm Host/header forwarding is not breaking app routing

For CloudFront not updated:
  - wait until Distribution.Status = Deployed
  - invalidate cache if object changed
EOF
```

Make executable:

```bash id="chmod-debug"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/debug-cloudfront.sh
```

Run:

```bash id="run-debug"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/debug-cloudfront.sh
```

---

# 23. Create CloudFront Invalidation Script

Invalidation removes cached paths from CloudFront edge caches. It does not delete the origin object.

```bash id="invalidation-script"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/create-invalidation.sh
```

Paste:

```bash id="invalidation-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
PATHS="${PATHS:-/assets/*}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

CF_ID="$(terraform output -raw cloudfront_distribution_id)"

echo "===== CloudFront Invalidation ====="
echo "Environment: $ENVIRONMENT"
echo "Distribution: $CF_ID"
echo "Paths: $PATHS"

aws cloudfront create-invalidation \
  --distribution-id "$CF_ID" \
  --paths $PATHS
```

Make executable:

```bash id="chmod-invalidation"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/create-invalidation.sh
```

Run after asset changes:

```bash id="run-invalidation"
ENVIRONMENT=dev PATHS="/assets/*" \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/create-invalidation.sh
```

---

# 24. Create CloudFront Summary Script

```bash id="summary-script"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cloudfront-summary.sh
```

Paste:

```bash id="summary-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Invalid ENVIRONMENT=$ENVIRONMENT. Use dev, staging, or prod."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/$ENVIRONMENT"

cd "$ENV_DIR"

echo "===== CloudFront Terraform Summary ====="
echo "Environment: $ENVIRONMENT"

terraform output assets_bucket_name
terraform output assets_bucket_regional_domain_name
terraform output uploaded_asset_keys
terraform output alb_dns_name
terraform output cloudfront_distribution_id
terraform output cloudfront_distribution_domain_name
terraform output cloudfront_distribution_status
terraform output cdn_contract
terraform output module_composition_contract

echo
echo "State addresses:"
terraform state list | grep -E 'module.storage|module.cdn|aws_s3|aws_cloudfront' | sort || true
```

Make executable:

```bash id="chmod-summary"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cloudfront-summary.sh
```

Run:

```bash id="run-summary"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cloudfront-summary.sh
```

---

# 25. Create Lesson Validation Script

This validates Terraform configuration but does not automatically create CloudFront.

```bash id="lesson-validation"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-lesson-12-10.sh
```

Paste:

```bash id="lesson-validation-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Validate Lesson 12.10 ====="

BASE="12-terraform-ansible-iac"
LESSON="$BASE/12.10-s3-cloudfront"

test -d "$LESSON/notes"
test -d "$LESSON/scripts"
test -d "$LESSON/runbooks"
test -d "$LESSON/reports"
test -d "$LESSON/assets"

test -f "$LESSON/notes/s3-cloudfront-mental-model.md"
test -f "$LESSON/notes/never-confuse-cloudfront-points.md"
test -f "$LESSON/assets/index.html"
test -f "$LESSON/assets/health.json"

test -x "$LESSON/scripts/validate-cloudfront-aws.sh"
test -x "$LESSON/scripts/plan-cloudfront.sh"
test -x "$LESSON/scripts/debug-cloudfront.sh"
test -x "$LESSON/scripts/create-invalidation.sh"
test -x "$LESSON/scripts/cloudfront-summary.sh"

test -f "$BASE/modules/storage/main.tf"
test -f "$BASE/modules/storage/variables.tf"
test -f "$BASE/modules/storage/outputs.tf"

test -f "$BASE/modules/cdn/main.tf"
test -f "$BASE/modules/cdn/variables.tf"
test -f "$BASE/modules/cdn/outputs.tf"

grep -q 'resource "aws_s3_bucket" "assets"' "$BASE/modules/storage/main.tf"
grep -q 'resource "aws_s3_bucket_public_access_block" "assets"' "$BASE/modules/storage/main.tf"
grep -q 'resource "aws_s3_object" "assets"' "$BASE/modules/storage/main.tf"

grep -q 'resource "aws_cloudfront_origin_access_control" "s3"' "$BASE/modules/cdn/main.tf"
grep -q 'resource "aws_cloudfront_distribution" "this"' "$BASE/modules/cdn/main.tf"
grep -q 'resource "aws_s3_bucket_policy" "allow_cloudfront_s3_read"' "$BASE/modules/cdn/main.tf"
grep -q 'ordered_cache_behavior' "$BASE/modules/cdn/main.tf"
grep -q 'custom_error_response' "$BASE/modules/cdn/main.tf"

terraform version >/dev/null
aws sts get-caller-identity >/dev/null

for env in dev staging prod; do
  echo
  echo "===== Validating Terraform env: $env ====="

  pushd "$BASE/environments/$env" >/dev/null

  terraform init -backend=false >/dev/null
  terraform fmt -check -recursive
  terraform validate

  terraform plan \
    -var-file=terraform.tfvars.example \
    -out="tfplan-12-10-validation-$env" >/dev/null

  terraform show -no-color "tfplan-12-10-validation-$env" >/dev/null
  rm -f "tfplan-12-10-validation-$env"

  popd >/dev/null
done

echo
echo "Lesson 12.10 validation passed."
echo
echo "After applying dev, validate AWS resources with:"
echo "ENVIRONMENT=dev ./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh"
```

Make executable:

```bash id="chmod-lesson-validation"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-lesson-12-10.sh
```

Run:

```bash id="run-lesson-validation"
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-lesson-12-10.sh
```

---

# 26. Cleanup Scripts

## Local artifacts only

```bash id="local-cleanup"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-local.sh
```

Paste:

```bash id="local-cleanup-content"
#!/usr/bin/env bash
set -euo pipefail

echo "===== Cleanup Lesson 12.10 Local Artifacts ====="

BASE="12-terraform-ansible-iac"

find "$BASE" -name "tfplan" -delete
find "$BASE" -name "tfplan-*" -delete
find "$BASE" -name "*.tfplan" -delete

echo "Local Terraform plan artifacts cleaned."
echo "AWS resources were not destroyed."
```

Make executable:

```bash id="chmod-local-cleanup"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-local.sh
```

Run:

```bash id="run-local-cleanup"
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-local.sh
```

---

## Destroy full dev stack

This destroys CloudFront, S3, ALB, EC2, IAM, security groups, and VPC resources managed by the dev root module.

```bash id="destroy-script"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

Paste:

```bash id="destroy-content"
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"

if [ "$ENVIRONMENT" != "dev" ]; then
  echo "This cleanup script is intentionally limited to ENVIRONMENT=dev."
  echo "Refusing to destroy $ENVIRONMENT."
  exit 1
fi

BASE="12-terraform-ansible-iac"
ENV_DIR="$BASE/environments/dev"

cd "$ENV_DIR"

echo "===== Cleanup Lesson 12.10 Dev Resources ====="
echo "Current workspace: $(terraform workspace show)"

terraform plan -destroy -var-file=terraform.tfvars.example -out=tfplan-destroy-12-10-dev
terraform show tfplan-destroy-12-10-dev

echo
echo "This destroy plan may include CloudFront, S3, ALB, EC2, security groups, IAM, and VPC resources."
echo "CloudFront deletion can take several minutes."
echo
echo "Type DESTROY_DEV_CLOUDFRONT_STACK to continue:"
read -r CONFIRM

if [ "$CONFIRM" != "DESTROY_DEV_CLOUDFRONT_STACK" ]; then
  echo "Cleanup cancelled."
  rm -f tfplan-destroy-12-10-dev
  exit 0
fi

terraform apply tfplan-destroy-12-10-dev
rm -f tfplan-destroy-12-10-dev

echo "Dev CloudFront stack destroyed."
```

Make executable:

```bash id="chmod-destroy"
chmod +x 12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

Run only if finished:

```bash id="run-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

Recommended:

```text id="recommendation"
Keep resources if you are continuing immediately to IAM troubleshooting in 12.11.
Destroy if stopping to avoid ALB, EC2, public IPv4, and CloudFront costs.
```

---

# 27. CloudFront Troubleshooting Runbook

```bash id="runbook"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/runbooks/cloudfront-troubleshooting-runbook.md
```

Paste:

````markdown id="runbook-content"
# CloudFront Troubleshooting Runbook

## 1. Check Terraform outputs

```bash
terraform output cloudfront_distribution_id
terraform output cloudfront_distribution_domain_name
terraform output assets_bucket_name
terraform output alb_dns_name
````

## 2. Check distribution status

```bash id="cf-status"
aws cloudfront get-distribution --id DISTRIBUTION_ID
```

Required:

```text id="deployed-required"
Status = Deployed
Enabled = true
```

## 3. Check behaviors and origins

```bash id="cf-config"
aws cloudfront get-distribution-config \
  --id DISTRIBUTION_ID \
  --query 'DistributionConfig.{Origins:Origins,DefaultCacheBehavior:DefaultCacheBehavior,CacheBehaviors:CacheBehaviors}'
```

Check:

* default behavior points to ALB origin
* /assets/* points to S3 origin
* S3 origin has OAC
* ALB origin protocol policy matches ALB listener

## 4. Check S3 direct access

```bash id="s3-direct"
curl -I https://BUCKET.s3.ap-south-1.amazonaws.com/assets/index.html
```

Private bucket should usually return 403 directly.

## 5. Check S3 object exists

```bash id="s3-objects"
aws s3 ls s3://BUCKET/assets/ --recursive
```

## 6. Check bucket policy

```bash id="bucket-policy"
aws s3api get-bucket-policy --bucket BUCKET --query Policy --output text | jq .
```

Required:

* Principal = cloudfront.amazonaws.com
* Action = s3:GetObject
* Resource = bucket ARN /*
* Condition AWS:SourceArn = CloudFront distribution ARN

## 7. Check ALB origin

```bash id="alb-direct"
curl -I http://ALB_DNS/health
```

If ALB direct fails, fix ALB/target group first.

## 8. Check CloudFront URLs

```bash id="cf-urls"
curl -Iv https://CLOUDFRONT_DOMAIN/assets/index.html
curl -Iv https://CLOUDFRONT_DOMAIN/health
```

## Common symptoms

### S3 path returns CloudFront 403

Likely causes:

* object key missing
* OAC missing
* bucket policy missing or wrong SourceArn
* wrong S3 origin domain
* /assets/* behavior not pointing to S3
* object encrypted with inaccessible KMS key

### ALB path returns 502

Likely causes:

* target returns broken response
* wrong origin protocol
* app closed connection
* target timeout

### ALB path returns 503

Likely causes:

* ALB has no healthy targets
* target group health check failing
* EC2 SG blocks ALB
* wrong health check path

### Direct S3 works publicly

Bad sign for this lab.

Fix:

* block public access
* remove public bucket policy
* use OAC policy only

### Updated object not visible

Fix:

```bash id="invalidation-example"
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/assets/*"
```

## Golden rule

Debug CloudFront by separating the problem:

1. Does origin work directly?
2. Does CloudFront behavior point to the right origin?
3. Does origin allow CloudFront?
4. Is CloudFront deployed?
5. Is cache hiding the latest result?

````id="runbook-end"

---

# 28. Production CloudFront Design Runbook

```bash id="prod-runbook"
nano 12-terraform-ansible-iac/12.10-s3-cloudfront/runbooks/production-cloudfront-design-runbook.md
````

Paste:

````markdown id="prod-runbook-content"
# Production CloudFront Design Runbook

## Common production pattern

```text
Viewer
  ↓
CloudFront
  ├── /assets/* -> private S3 via OAC
  └── default -> ALB origin
````

## S3 origin

Use:

* private bucket
* public access block
* ownership controls
* versioning
* encryption
* OAC
* bucket policy scoped to CloudFront distribution ARN

## ALB origin

Use:

* HTTPS in production
* origin custom headers if needed
* ALB security controls
* target group health checks
* WAF if required

## Certificates

CloudFront custom domain:

```text
ACM certificate in us-east-1
```

ALB HTTPS listener:

```text id="alb-acm"
ACM certificate in ALB region
```

## Cache behavior design

Static assets:

```text id="static-cache"
longer TTL
GET/HEAD/OPTIONS only
no cookies
no query strings unless needed
```

Dynamic app:

```text id="dynamic-cache"
short or zero TTL
forward needed headers/query/cookies
avoid caching personalized content incorrectly
```

## Security

Recommended:

* OAC for S3
* HTTPS viewer policy
* WAF for internet apps
* least-privilege bucket policy
* no public S3 bucket
* no direct EC2 exposure
* ALB security group controlled

## Golden rule

CloudFront is not just a cache.
It is part of production routing, security, TLS, performance, and origin protection.

````id="prod-runbook-end"

---

# 29. Common Errors and Fixes

## Error 1 — CloudFront 403 for S3 asset

Check:

```bash id="debug-s3-403"
aws s3 ls "s3://$S3_BUCKET/assets/" --recursive

aws s3api get-bucket-policy \
  --bucket "$S3_BUCKET" \
  --query Policy \
  --output text | jq .

aws cloudfront get-distribution-config \
  --id "$CF_ID" \
  --query 'DistributionConfig.Origins.Items'
````

Fix:

```text id="fix-s3-403"
Ensure object exists.
Ensure /assets/* behavior points to S3 origin.
Ensure OAC is attached.
Ensure bucket policy SourceArn matches distribution ARN.
Ensure origin domain is bucket_regional_domain_name.
```

---

## Error 2 — CloudFront 503 for ALB path

Check:

```bash id="debug-503"
curl -I "http://$ALB_DNS/health"

aws elbv2 describe-target-health \
  --target-group-arn "$TG_ARN"
```

Fix target health first.

---

## Error 3 — CloudFront distribution stuck `InProgress`

CloudFront global deployment can take time.

Check:

```bash id="debug-inprogress"
aws cloudfront get-distribution \
  --id "$CF_ID" \
  --query 'Distribution.Status'
```

Wait:

```bash id="wait-inprogress"
aws cloudfront wait distribution-deployed --id "$CF_ID"
```

---

## Error 4 — S3 bucket name already exists

S3 bucket names are globally unique.

Fix:

```text id="bucket-fix"
Use bucket_name_override with a unique lowercase name.
```

For this module, generated names include:

```text id="bucket-generated"
name_prefix + account ID + region
```

to reduce collision risk.

---

## Error 5 — Access denied applying bucket policy

Need permissions:

```text id="bucket-policy-permissions"
s3:GetBucketPolicy
s3:PutBucketPolicy
s3:DeleteBucketPolicy
```

Also need CloudFront permissions to create OAC and distribution.

---

## Error 6 — Terraform destroy takes long

CloudFront distributions must be disabled and propagated before deletion. Terraform handles this, but it can take several minutes.

---

# 30. Cost Safety

Check active resources:

```bash id="cost-check"
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,DomainName:DomainName,Status:Status,Enabled:Enabled}' \
  --output table

aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].{Name:LoadBalancerName,DNSName:DNSName,State:State.Code,Type:Type}' \
  --output table

aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=devops-masterclass" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

Destroy when done:

```bash id="cost-destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

---

# 31. Revision Checkpoint

You should now be able to answer:

```text id="revision"
What is CloudFront?
What is a CloudFront origin?
What is a default cache behavior?
What is an ordered cache behavior?
What is OAC?
How is OAC different from old OAI?
Why should S3 stay private?
Why does OAC still need a bucket policy?
Why use bucket_regional_domain_name for private S3 origin?
What path goes to S3 in this lesson?
What path goes to ALB in this lesson?
What does viewer_protocol_policy do?
What does origin_protocol_policy do?
Why does CloudFront custom domain ACM need us-east-1?
What causes CloudFront 403?
What causes CloudFront 502/503 from ALB origin?
How do you validate CloudFront with AWS CLI?
How do you invalidate cached content?
Why should you not make S3 public to fix CloudFront?
```

Strong interview answer:

```text id="interview-answer"
I built a Terraform CDN layer using CloudFront with two origins: a private S3 assets bucket using Origin Access Control and an Application Load Balancer as a custom HTTP origin. Static asset paths such as /assets/* are routed to S3, while the default behavior routes to the ALB-backed application. The S3 bucket is private, encrypted, versioned, blocked from public access, and only grants s3:GetObject to the CloudFront service principal when the request SourceArn matches the distribution ARN.

For CloudFront troubleshooting, I separate the problem by origin. If /assets/* fails, I check object keys, OAC attachment, bucket policy, S3 origin domain, and cache behavior path matching. If the default app path fails, I check ALB DNS directly, target group health, EC2 security groups, health check path, and origin protocol settings. I wait for CloudFront distribution status to become Deployed, use curl against both CloudFront and origins, and use invalidations only when cache needs to be refreshed.
```

Resume bullet:

```text id="resume-bullet"
Built a production-style Terraform CDN layer with private S3 static assets, S3 public access blocking, encryption, versioning, CloudFront Origin Access Control, S3 bucket policy scoped to CloudFront distribution ARN, dual-origin CloudFront distribution with /assets/* S3 behavior and default ALB origin behavior, HTTPS viewer redirects, SPA custom error responses, validation scripts, invalidation automation, 403/502/503 troubleshooting runbooks, and cost-safe cleanup workflows.
```

---

# 32. Commit Lesson 12.10

Clean local plans only:

```bash id="clean-before-commit"
cd ~/devops-masterclass

./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-local.sh
```

Validate Terraform config:

```bash id="validate-before-commit"
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-lesson-12-10.sh
```

If you applied dev CloudFront, validate AWS resources:

```bash id="validate-aws-before-commit"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/validate-cloudfront-aws.sh
```

Review:

```bash id="review-status"
git status

find 12-terraform-ansible-iac/12.10-s3-cloudfront -maxdepth 4 -type f | sort
find 12-terraform-ansible-iac/modules/{storage,cdn} -maxdepth 2 -type f | sort
```

Commit:

```bash id="commit"
git add 12-terraform-ansible-iac

git commit -m "feat: add S3 and CloudFront Terraform modules"

git push
```

---

# 33. Keep or Destroy?

Keep if continuing immediately:

```text id="keep"
Recommended if continuing to Lesson 12.11 IAM troubleshooting.
```

Destroy if stopping:

```bash id="destroy"
ENVIRONMENT=dev \
./12-terraform-ansible-iac/12.10-s3-cloudfront/scripts/cleanup-lesson-12-10-dev.sh
```

---

# 34. Next Lesson

```text id="next-lesson"
12.11 — IAM Troubleshooting with Terraform
```

We will go deep into:

```text id="next-topics"
IAM mental model
identity policy vs resource policy
trust policy vs permissions policy
iam:PassRole
AccessDenied debugging
encoded authorization failure message
least privilege
Terraform caller permissions
EC2 role permissions
S3 bucket policy troubleshooting
CloudFront OAC policy debugging
permission boundaries concept
policy simulator workflow
AWS CLI identity checks
real broken IAM scenarios
fix scripts and runbooks
```

[1]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html?utm_source=chatgpt.com "Restrict access to an Amazon S3 origin - Amazon CloudFront"
[2]: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control?utm_source=chatgpt.com "aws_cloudfront_origin_access_control | Resources | hashicorp/aws | Terraform | Terraform Registry"
[3]: https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_CreateOriginAccessControl.html?utm_source=chatgpt.com "CreateOriginAccessControl - Amazon CloudFront"
