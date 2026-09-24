# Threat model

Threats include malicious templates, source URL injection, repository-token theft, confused-deputy access, over-privileged Crossplane providers, GitOps repository compromise, unsafe policy exceptions, secret exposure in catalog annotations, and untrusted TechDocs content.

Controls include SSO, short-lived workload identity, allowlisted template actions and source hosts, protected branches, CODEOWNERS, signed commits/images, isolated runners, least-privilege AppProjects/providers, admission policies, network policy, audit logs, secret scanning, dependency review, and time-bounded exception records.
