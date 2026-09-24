# MongoDB operations contract

Compose runs one MongoDB node only for local learning. Production requires an intentionally operated replica set or managed service, private connectivity, TLS, workload identity/rotated credentials, least-privilege database roles, point-in-time recovery, tested restores, capacity alerts, index review, and a documented upgrade path.

Kubernetes manifests expect `MONGO_URI` from an approved external secret. They intentionally do not install a production database into the application namespace. Set Terraform `create_postgres = false`; integrate an approved MongoDB service through a separately reviewed infrastructure module.
