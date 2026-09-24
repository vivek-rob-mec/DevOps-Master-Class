# Low-level design

Bicep deploys at subscription scope into a dedicated resource group. The spoke VNet delegates a bounded AKS subnet. OIDC and Workload Identity exchange a Kubernetes service-account token for a user-assigned managed identity. Azure RBAC grants only Key Vault Secrets User. Separate system/user node pools, private endpoints, DNS links, egress firewall and backup vaults should be added for production.
