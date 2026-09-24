provider "aws" {
  region = var.aws_region
}
resource "random_id" "suffix" {
  byte_length = 4
}
locals {
  name = "${var.project_name}-${var.environment}"
}
resource "aws_kms_key" "models" {
  description             = "ML model artifact encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
resource "aws_s3_bucket" "models" {
  bucket        = "${local.name}-${random_id.suffix.hex}"
  force_destroy = false
}
resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.models.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}
resource "aws_ecr_repository" "inference" {
  name                 = "${local.name}-inference"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.models.arn
  }
}
