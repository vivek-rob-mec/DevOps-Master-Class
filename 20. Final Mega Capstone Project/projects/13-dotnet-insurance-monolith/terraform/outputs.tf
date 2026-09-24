output "cluster_name" {
  value = module.eks.cluster_name
}
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
output "ecr_urls" {
  value = { for name, repo in aws_ecr_repository.workload : name => repo.repository_url }
}
output "postgres_endpoint" {
  value     = try(aws_db_instance.app[0].address, null)
  sensitive = true
}
output "postgres_secret_arn" {
  value     = try(aws_db_instance.app[0].master_user_secret[0].secret_arn, null)
  sensitive = true
}
