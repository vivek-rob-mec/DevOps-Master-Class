# Low-level design

Ingestion allowlists source hosts and stores document ID, tenant, version and source. Production adds content checksums, ACL projection, deletion tombstones and embedding revision. Query normalizes input, blocks obvious injection markers, filters vectors by tenant, bounds context, instructs cited answers and calls an OpenAI-compatible backend. These controls reduce risk but do not prove semantic safety; evaluation and human review remain mandatory.
