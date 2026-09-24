# Threat model

Threats include privilege escalation through CR fields, namespace takeover, unsafe finalizer deletion, API-server denial of service, malicious image replacement, RBAC expansion and status spoofing. Controls include structural schemas, domain validation, least-privilege RBAC, digest-pinned images, bounded concurrency/retries, deletion opt-in, admission policies, audit logging and a separate role for status updates.
