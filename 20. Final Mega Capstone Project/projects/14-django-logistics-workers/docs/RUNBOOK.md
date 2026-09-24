# Django Logistics and Background Jobs Platform - Runbook

Namespace `logistics-django`; local URL `http://localhost:8093`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n logistics-django get deploy,pod,svc,ingress
kubectl -n logistics-django get events --sort-by=.lastTimestamp
kubectl -n logistics-django logs deployment/logistics-web --tail=200
kubectl -n logistics-django rollout undo deployment/logistics-web
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
