variable "organization_id" { type = string }
variable "billing_account" { type = string }
variable "prefix" {
  type    = string
  default = "masterclass"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "unique_suffix" {
  type        = string
  description = "Globally unique lowercase suffix."
}
variable "security_group" {
  type    = string
  default = "cloud-security@example.com"
}
variable "labels" {
  type    = map(string)
  default = { managed_by = "terraform", owner = "replace-with-owner", cost_center = "replace" }
}
