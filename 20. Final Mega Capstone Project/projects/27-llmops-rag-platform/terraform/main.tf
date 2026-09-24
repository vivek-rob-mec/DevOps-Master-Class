provider "aws" { region = var.aws_region }
resource "random_id" "suffix" { byte_length = 4 }
resource "aws_kms_key" "artifacts" {
  description             = "LLM artifact, evaluation and vector-snapshot encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = var.tags
}
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-${var.environment}-${random_id.suffix.hex}"
  force_destroy = false
  tags          = var.tags
}
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.artifacts.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_ecr_repository" "gateway" {
  name                 = "${var.project_name}/gateway"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.artifacts.arn
  }
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}
