# Low-level design

Bootstrap state creates the folder/projects and is administered separately from workload state. Workload state enables APIs, VPC-native ranges, Cloud NAT, regional private GKE, CMEK, Binary Authorization, managed Prometheus, Pub/Sub and secretless workload identity. Production should use remote state, Shared VPC host/service projects, private service access and explicit organization policies.
