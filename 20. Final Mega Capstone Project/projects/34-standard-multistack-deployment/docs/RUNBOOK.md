# Operations and recovery runbook

Service owner: assign before deployment. Release owner: assign per change. Record the incident channel, escalation contact, dashboard, and alert destination in your organization. No contact details or alerts are preconfigured here.

## Release success criteria

The GitOps revision is synced, the Deployment references the approved digest, every expected replica is ready, the actual HTTPS business check passes, and error/latency/resource signals stay within the predeclared acceptance limits. Sample staging acceptance targets are no HTTP failures in a 5-minute smoke exercise and p95 below 300 ms at 10 requests/second. Measure a baseline and replace these teaching targets for your workload.

For a real service, define a monthly availability SLO and latency objective with a precise request population. Collect request rate, error rate, duration, CPU/memory saturation, restart count, rollout progress, and dependency signals through project 20. Alert on sustained user impact and resource exhaustion with a named response owner. These samples emit logs and health responses; dashboards and telemetry collectors are platform integrations.

## Investigate a failed rollout

Use the affected namespace/stack; these commands use Python in staging:

```bash
kubectl -n standard-staging rollout status deployment/python-deployment-demo --timeout=60s
kubectl -n standard-staging get pods -l app.kubernetes.io/instance=python -o wide
kubectl -n standard-staging describe deployment python-deployment-demo
kubectl -n standard-staging get events --sort-by=.metadata.creationTimestamp
kubectl -n standard-staging logs deployment/python-deployment-demo --tail=100
```

Inspect individual pods and previous container logs for restarts. Sanitize evidence before sharing; never export secret values.

| Symptom | Investigate | Recovery direction |
|---|---|---|
| ImagePullBackOff | Exact digest, package permissions, pull Secret, node connectivity | Correct registry access or restore a known-good image reference |
| CrashLoopBackOff | Previous logs, exit status, startup command, required configuration, read-only file writes | Correct config/image; allow only necessary writable mounts |
| OOMKilled | Container memory and JVM/runtime sizing, load, bounded queues | Fix allocation behavior or raise measured resources through review |
| Running but not ready | Readiness path/port, initialization, dependencies, NetworkPolicy | Repair the failing dependency or config; do not remove the probe to hide failure |
| Pending pods | Scheduling events, requests, quotas, node capacity, affinity | Supply capacity or correct scheduling/resource assumptions |
| HTTPS unavailable while port-forward works | DNS, certificate, Gateway listeners, HTTPRoute conditions, policy | Repair the exposure path and verify externally |
| Rollout stuck with old pods | Startup/readiness failures, surge capacity, minReadySeconds | Preserve serving capacity; fix the candidate or revert |
| Argo CD OutOfSync | Repository revision, permissions, resource diff, admission rejection | Reconcile reviewed desired state and resolve admission errors |

## Roll back

1. Stop further promotions and record the failing Git revision, image digest, symptoms, and UTC timestamps.
2. Find the **environment promotion commit** that introduced the failing release. Identify the previous digest and confirm it still exists in the registry and works with the current database schema/configuration.
3. On a branch from current main, run `git revert PROMOTION_COMMIT_SHA`. Review the full diff, particularly if that commit touched multiple environments. If needed, prepare a scoped change restoring only the affected overlay's earlier image and configuration. Run `python scripts/validate.py` and submit the reviewed recovery PR.
4. Merge and sync the affected Argo CD Application. If auto-sync is enabled, monitor reconciliation; if manual, the release owner triggers it. The normal promotion script enforces forward progression, so rollback uses the reviewed Git revert.
5. Wait for rollout completion, compare all pod image identities, repeat the API and HTTPS checks, and confirm user-facing signals recover. Record recovery time and any unresolved impact.

Avoid treating `kubectl rollout undo` as the final recovery when GitOps owns the Deployment: reconciliation can restore the failing Git state. For an emergency intervention, coordinate temporary reconciliation suspension, record the change, update Git to the intended recovered state, and restore reconciliation after review.

Kubernetes' progress deadline reports a failed rollout; it does **not** automatically roll it back. Automatic metric-based rollback is an extension using project 31. The PDB restricts voluntary evictions; it does not prevent every outage or replace rollout health checks.

## Controlled exercises

In a disposable dev namespace, submit a deliberately nonexistent digest and observe image pull failure while the old healthy replica continues serving, provided sufficient capacity exists. Revert that promotion and prove recovery. In a second exercise, point readiness at a missing route and show that unhealthy pods receive no Service traffic. Record detection time, recovery time, and the limits of the test. Never run these experiments on production services.

For an application with persistence, additionally restore a backup into an isolated target, validate data and a user transaction, and record RPO/RTO. Container recreation does not test data recovery.

## Cleanup

Local: `docker compose down`. There are no local data volumes in this project. Cluster: remove the lab's Argo CD Application through the platform procedure before deleting its owned workloads, then confirm no reconciliation recreates them. The Application example has no cascade finalizer, so deleting it alone leaves workloads behind. Preserve shared namespaces, gateways, registry evidence, and resources owned by other projects. Infrastructure teardown belongs to its separate reviewed plan.
