# Threat model

Threats include poisoned training data, feature leakage, malicious pickle artifacts, registry alias takeover, unauthorized promotion, model extraction, membership inference, sensitive-feature logging, dependency compromise, and unbounded inference input. Controls include dataset checksums/lineage, reviewed training code, isolated runners, safer serialization where supported, signed artifacts/images, RBAC and separation of duties, encrypted private stores, bounded inputs/rates, audit logs, privacy testing, and human review for consequential decisions.
