# Migration standard

Prefer expand, migrate and contract. Every change needs owner, lock estimate, compatibility window, rollback and observability. Create large indexes concurrently. Avoid a single transaction for operations PostgreSQL forbids inside one. Destructive changes require a verified backup and proof that old application versions no longer depend on the schema.
