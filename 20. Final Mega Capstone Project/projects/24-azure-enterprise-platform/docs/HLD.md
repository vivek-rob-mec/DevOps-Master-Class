# High-level design

The application landing zone inherits identity, policy, security and connectivity controls from a centrally managed Azure platform landing zone. AKS is private, zone-spread and identity-integrated. ACR, Key Vault and Log Analytics use private connectivity in production. GitOps owns Kubernetes desired state; Bicep owns Azure control-plane resources.
