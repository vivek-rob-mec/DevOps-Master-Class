variable "project_name" {
  type    = string
  default = "internal-developer-platform"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.70.0.0/16"
}
