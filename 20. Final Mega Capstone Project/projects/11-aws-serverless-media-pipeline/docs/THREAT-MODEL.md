# Serverless Media Pipeline - Threat Model

Protect API identity, object references and contents, job records, queue messages, logs, IAM roles, artifacts, and Terraform state. Test broken object authorization, forged bucket/key, injection, oversized bodies, replay, duplicate delivery, queue poisoning, SSRF-like downstream processing, archive bombs, malicious media parsers, secret leakage, excessive concurrency/cost, public bucket policy, and audit tampering. Require authentication and resource authorization before exposing the template beyond an isolated lab.
