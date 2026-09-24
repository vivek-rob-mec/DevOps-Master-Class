output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}
output "media_bucket" {
  value = aws_s3_bucket.media.id
}
output "jobs_table" {
  value = aws_dynamodb_table.jobs.name
}
output "work_queue_url" {
  value = aws_sqs_queue.work.url
}
output "dead_letter_queue_url" {
  value = aws_sqs_queue.dlq.url
}
