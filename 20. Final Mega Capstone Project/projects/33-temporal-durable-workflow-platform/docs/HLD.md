# High-level design

Temporal service owns durable history and task routing; workers own deterministic workflow and activity implementations. Activities call unreliable external systems through idempotency keys. Persistence and visibility databases are operated independently. Task queues isolate domains and versions, while metrics expose schedule-to-start latency, failures and backlog.
