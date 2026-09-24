# High-level design

The organization hierarchy separates network, security and workload ownership. Projects inherit organization policy and centralized audit controls. Private regional GKE consumes Shared VPC patterns, Artifact Registry and KMS. Terraform controls cloud resources, while GitOps controls cluster workloads.
