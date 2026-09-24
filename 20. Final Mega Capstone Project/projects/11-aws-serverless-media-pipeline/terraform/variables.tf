variable "project_name" {
  type    = string
  default = "media-pipeline"
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

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = { Owner = "replace-with-owner", CostCenter = "replace-with-cost-center" }
}
