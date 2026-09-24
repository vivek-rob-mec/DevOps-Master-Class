# High-level design

CloudNativePG reconciles PostgreSQL instances, roles and services. PgBouncer isolates applications from connection churn. WAL and base backups leave the cluster through the Barman plugin. Monitoring, migrations and restore evidence are separate control planes so a green operator status never substitutes for proven recoverability.
