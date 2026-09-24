variable "project_name" {
  type    = string
  default = "energy-trading"
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Use dev, qa, or prod."
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}
variable "kubernetes_version" {
  type        = string
  default     = "1.36"
  description = "Verify current regional EKS support before apply."
}
variable "cluster_endpoint_public_access" {
  type    = bool
  default = false
}
variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}
variable "workloads" {
  type = list(string)
  default = [
    "app",
  ]
}
variable "create_postgres" {
  type    = bool
  default = true
}
variable "postgres_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "tags" {
  type    = map(string)
  default = { Owner = "replace-with-owner", CostCenter = "replace-with-cost-center" }
}
