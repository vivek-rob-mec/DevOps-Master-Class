provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.tags, { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" })
  }
}
resource "random_id" "suffix" {
  byte_length = 4
}
locals {
  bucket_name = lower("${var.project_name}-${var.environment}-${random_id.suffix.hex}")
}
resource "aws_kms_key" "data" {
  description             = "Data lake encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
resource "aws_s3_bucket" "lake" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
}
resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    id     = "noncurrent-retention"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
resource "aws_glue_catalog_database" "analytics" {
  name = replace("${var.project_name}_${var.environment}", "-", "_")
}
