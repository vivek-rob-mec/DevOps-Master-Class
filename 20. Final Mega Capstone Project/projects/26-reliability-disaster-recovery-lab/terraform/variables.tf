variable "project_name" {
  type    = string
  default = "reliability-lab"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "primary_region" {
  type    = string
  default = "us-east-1"
}
variable "secondary_region" {
  type    = string
  default = "us-west-2"
}
variable "tags" {
  type    = map(string)
  default = { Owner = "replace-with-owner", CostCenter = "replace", ManagedBy = "Terraform" }
}
