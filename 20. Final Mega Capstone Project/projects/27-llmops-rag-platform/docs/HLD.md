# High-level design

The policy gateway is the only user-facing inference boundary. It authenticates/authorizes tenants, filters retrieval, bounds context and records non-sensitive telemetry. Qdrant stores tenant-scoped vectors. KServe manages vLLM serving. Model, prompt, embedding, vector schema and evaluation dataset form one immutable release with independent promotion evidence.
