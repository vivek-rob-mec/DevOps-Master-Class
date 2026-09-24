# Go Cloud-Native URL Shortener - Threat Model

Assets: identities, authorization, domain records, audit, credentials, keys, artifacts, infrastructure state, backups, and availability.

| Threat | Prevent | Detect | Respond |
|---|---|---|---|
| Credential theft | Short-lived identity, least privilege | Identity/audit anomaly | Revoke, rotate, contain |
| Broken authorization | Deny default, resource policy | Forbidden/audit review | Disable path, assess exposure |
| Injection | Typed bounds, parameterized queries, encoding | Validation/WAF | Block, patch, assess data |
| Supply chain | Pin, provenance, SBOM, signature | Scan | Quarantine, rollback, rotate identity |
| DoS | Rate/concurrency bounds and degradation | SLO/saturation | Shed, isolate, scale |
| Data leakage | Minimize, encrypt, redact, retention | Audit/unusual reads | Contain, revoke, notify |

Test object authorization, duplicates, oversized/malformed input, path traversal, injection, brute force, stale identity, secret leakage, dependency impersonation, and audit tampering in isolation.
