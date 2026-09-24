output "primary_backup_bucket" { value = aws_s3_bucket.primary.id }
output "secondary_backup_bucket" { value = aws_s3_bucket.secondary.id }
