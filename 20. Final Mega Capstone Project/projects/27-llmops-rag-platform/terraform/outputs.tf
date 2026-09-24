output "artifact_bucket" { value = aws_s3_bucket.artifacts.id }
output "gateway_repository" { value = aws_ecr_repository.gateway.repository_url }
