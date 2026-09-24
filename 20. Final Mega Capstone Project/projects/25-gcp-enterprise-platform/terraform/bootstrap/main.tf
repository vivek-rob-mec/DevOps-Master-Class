provider "google" {}

resource "google_folder" "platform" {
  display_name = "${var.prefix}-${var.environment}-platform"
  parent       = "organizations/${var.organization_id}"
}

locals {
  projects = {
    network  = "${var.prefix}-${var.environment}-net-${var.unique_suffix}"
    security = "${var.prefix}-${var.environment}-sec-${var.unique_suffix}"
    workload = "${var.prefix}-${var.environment}-app-${var.unique_suffix}"
  }
  common_services = ["cloudresourcemanager.googleapis.com", "serviceusage.googleapis.com", "iam.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com"]
}

resource "google_project" "platform" {
  for_each            = local.projects
  name                = each.value
  project_id          = each.value
  folder_id           = google_folder.platform.name
  billing_account     = var.billing_account
  auto_create_network = false
  labels              = merge(var.labels, { purpose = each.key })
}

resource "google_project_service" "common" {
  for_each           = { for item in setproduct(keys(local.projects), local.common_services) : "${item[0]}:${item[1]}" => { project = item[0], service = item[1] } }
  project            = google_project.platform[each.value.project].project_id
  service            = each.value.service
  disable_on_destroy = false
}

resource "google_project_iam_member" "security_viewer" {
  for_each = google_project.platform
  project  = each.value.project_id
  role     = "roles/viewer"
  member   = "group:${var.security_group}"
}
