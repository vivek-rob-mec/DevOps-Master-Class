# Python Commerce Microservices Platform - Runbook

Namespace `commerce-python`; local URL `http://localhost:8081`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n commerce-python get deploy,pod,svc,ingress
kubectl -n commerce-python get events --sort-by=.lastTimestamp
kubectl -n commerce-python logs deployment/commerce-gateway --tail=200
kubectl -n commerce-python rollout undo deployment/commerce-gateway
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
