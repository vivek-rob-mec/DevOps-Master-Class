# Determinism and versioning

Workflow code must make the same decisions when replaying the same history. Do not read wall-clock time, random values, environment variables, network services or mutable global state directly in workflow code. Use Temporal APIs, activities and explicit versioning. Replay representative production histories before rollout and keep compatible workers until old executions complete or migrate.
