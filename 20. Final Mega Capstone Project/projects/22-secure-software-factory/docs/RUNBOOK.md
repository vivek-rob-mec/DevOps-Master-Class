# Supply-chain incident runbook

1. Freeze promotion and revoke affected OIDC/KMS trust bindings.
2. Identify artifacts by digest, signer, builder, dependency and time window; never rely on tags.
3. Quarantine affected workloads with admission and registry policy. Preserve logs, bundles, SBOMs and provenance.
4. Rebuild from a reviewed source revision on a known-good builder with refreshed dependencies and trust roots.
5. Verify independently, deploy by digest, monitor, and document affected consumers plus notification obligations.
6. Re-enable publishing only after credential rotation, workflow review and a successful clean-room release rehearsal.
