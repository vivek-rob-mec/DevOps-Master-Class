# TypeScript B2B SaaS Platform - Runbook

Namespace `saas-typescript`; local URL `http://localhost:8091`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n saas-typescript get deploy,pod,svc,ingress
kubectl -n saas-typescript get events --sort-by=.lastTimestamp
kubectl -n saas-typescript logs deployment/saas-api --tail=200
kubectl -n saas-typescript rollout undo deployment/saas-api
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
