variable "project_name" {
  type    = string
  default = "llmops-rag"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "tags" {
  type    = map(string)
  default = { Owner = "replace-with-owner", CostCenter = "replace", DataClass = "confidential" }
}
