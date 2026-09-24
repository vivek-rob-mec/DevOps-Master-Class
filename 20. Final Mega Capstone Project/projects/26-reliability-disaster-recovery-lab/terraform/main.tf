provider "aws" { region = var.primary_region }
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}
resource "random_id" "suffix" { byte_length = 4 }
locals { bucket_name = "${var.project_name}-${var.environment}-dr-${random_id.suffix.hex}" }
resource "aws_s3_bucket" "primary" {
  bucket        = "${local.bucket_name}-primary"
  force_destroy = false
  tags          = var.tags
}
resource "aws_s3_bucket" "secondary" {
  provider      = aws.secondary
  bucket        = "${local.bucket_name}-secondary"
  force_destroy = false
  tags          = var.tags
}
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_public_access_block" "secondary" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.secondary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
