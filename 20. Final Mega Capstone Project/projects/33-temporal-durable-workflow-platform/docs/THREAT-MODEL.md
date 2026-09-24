# Threat model

Threats include unauthorized workflow starts/signals, sensitive payloads in history, activity credential theft, replay-incompatible releases, task-queue impersonation and database tampering. Controls include mTLS/API authorization, payload encryption codecs, workload identity, namespace isolation, replay gates, least-privilege activity credentials and immutable audit retention.
