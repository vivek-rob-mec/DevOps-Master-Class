provider "google" {
  project = var.project_id
  region  = var.region
}

locals { services = toset(["artifactregistry.googleapis.com", "binaryauthorization.googleapis.com", "container.googleapis.com", "cloudkms.googleapis.com", "pubsub.googleapis.com", "secretmanager.googleapis.com", "compute.googleapis.com"]) }
resource "google_project_service" "platform" {
  for_each           = local.services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "platform" {
  name                    = "${var.prefix}-${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.platform]
}
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.prefix}-${var.environment}-gke"
  ip_cidr_range            = "10.80.0.0/20"
  region                   = var.region
  network                  = google_compute_network.platform.id
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.84.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.88.0.0/20"
  }
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
resource "google_compute_router" "platform" {
  name    = "${var.prefix}-${var.environment}-router"
  region  = var.region
  network = google_compute_network.platform.id
}
resource "google_compute_router_nat" "platform" {
  name                               = "${var.prefix}-${var.environment}-nat"
  router                             = google_compute_router.platform.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_kms_key_ring" "platform" {
  name       = "${var.prefix}-${var.environment}"
  location   = var.region
  depends_on = [google_project_service.platform]
}
resource "google_kms_crypto_key" "gke" {
  name            = "gke-secrets"
  key_ring        = google_kms_key_ring.platform.id
  rotation_period = "7776000s"
  lifecycle { prevent_destroy = true }
}
resource "google_artifact_registry_repository" "platform" {
  location               = var.region
  repository_id          = "${var.prefix}-${var.environment}"
  format                 = "DOCKER"
  description            = "Promoted signed workload images"
  cleanup_policy_dry_run = true
  depends_on             = [google_project_service.platform]
}
resource "google_pubsub_topic" "events" {
  name                       = "platform-events"
  message_retention_duration = "604800s"
  depends_on                 = [google_project_service.platform]
}
resource "google_secret_manager_secret" "sample" {
  secret_id = "sample-api-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.platform]
}

resource "google_container_cluster" "platform" {
  name                     = "${var.prefix}-${var.environment}-gke"
  location                 = var.region
  network                  = google_compute_network.platform.id
  subnetwork               = google_compute_subnetwork.gke.id
  networking_mode          = "VPC_NATIVE"
  datapath_provider        = "ADVANCED_DATAPATH"
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true
  release_channel { channel = "REGULAR" }
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  binary_authorization { evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE" }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.private_endpoint
    master_ipv4_cidr_block  = "172.20.0.0/28"
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "platform-admin"
    }
  }
  logging_config { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"] }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER", "STORAGE", "POD", "DEPLOYMENT", "STATEFULSET", "DAEMONSET", "HPA"]
    managed_prometheus { enabled = true }
  }
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }
  resource_labels = var.labels
  depends_on      = [google_project_service.platform]
}
resource "google_container_node_pool" "system" {
  name       = "system"
  location   = var.region
  cluster    = google_container_cluster.platform.name
  node_count = 1
  autoscaling {
    min_node_count  = 1
    max_node_count  = 3
    location_policy = "BALANCED"
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  node_config {
    machine_type    = "e2-standard-4"
    disk_type       = "pd-balanced"
    disk_size_gb    = 100
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    labels = { pool = "system" }
    workload_metadata_config { mode = "GKE_METADATA" }
  }
}
resource "google_service_account" "nodes" {
  account_id   = "gke-node"
  display_name = "Least privilege GKE node identity"
}
resource "google_project_iam_member" "node_roles" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/monitoring.viewer", "roles/artifactregistry.reader"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}
resource "google_service_account" "workload" {
  account_id   = "sample-api"
  display_name = "Sample workload identity"
}
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[sample/sample-api]"
}
resource "google_secret_manager_secret_iam_member" "sample" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.sample.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.workload.email}"
}
