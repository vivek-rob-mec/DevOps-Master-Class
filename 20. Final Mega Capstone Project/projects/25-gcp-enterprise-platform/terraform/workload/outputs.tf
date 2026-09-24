output "cluster_name" { value = google_container_cluster.platform.name }
output "registry" { value = google_artifact_registry_repository.platform.name }
output "workload_service_account" { value = google_service_account.workload.email }
output "configure_kubectl" { value = "gcloud container clusters get-credentials ${google_container_cluster.platform.name} --region ${var.region} --project ${var.project_id}" }
