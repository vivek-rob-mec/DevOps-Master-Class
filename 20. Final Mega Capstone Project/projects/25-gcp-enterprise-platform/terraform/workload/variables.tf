variable "project_id" { type = string }
variable "prefix" {
  type    = string
  default = "masterclass"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "region" {
  type    = string
  default = "asia-south1"
}
variable "private_endpoint" {
  type    = bool
  default = true
}
variable "admin_cidr" {
  type    = string
  default = "10.0.0.0/8"
}
variable "labels" {
  type    = map(string)
  default = { managed_by = "terraform", owner = "replace-with-owner", cost_center = "replace" }
}
