output "model_bucket" {
  value = aws_s3_bucket.models.id
}
output "inference_repository_url" {
  value = aws_ecr_repository.inference.repository_url
}
