# Threat model

Threats: malicious pull requests, poisoned actions, mutable tags, compromised scanners/builders, dependency confusion, registry overwrite, credential exfiltration, forged provenance, signing-identity misuse, policy bypass, and vulnerable exceptions. Controls: SHA-pinned actions, read-only untrusted jobs, isolated publishing, OIDC short-lived identity, digest-only signing/deployment, SBOM and provenance retention, independent verification, fail-closed admission, protected environments, two-person exceptions, and periodic trust-root rotation drills.
