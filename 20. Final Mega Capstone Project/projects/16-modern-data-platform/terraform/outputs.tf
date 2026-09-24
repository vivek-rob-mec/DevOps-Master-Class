output "data_lake_bucket" {
  value = aws_s3_bucket.lake.id
}
output "catalog_database" {
  value = aws_glue_catalog_database.analytics.name
}
output "kms_key_arn" {
  value = aws_kms_key.data.arn
}
