# Release runbook

When a canary degrades, establish whether the cause is artifact, configuration, traffic, dependency or metric failure. Abort artifact rollout for code/config regressions; disable a flag for isolated feature behavior. Record which control restored service. Reconcile Git after emergency action so the controller does not reintroduce the fault.
