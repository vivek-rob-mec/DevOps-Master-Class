# Kotlin Reactive Energy Trading Service - Runbook

Namespace `energy-kotlin`; local URL `http://localhost:8098`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n energy-kotlin get deploy,pod,svc,ingress
kubectl -n energy-kotlin get events --sort-by=.lastTimestamp
kubectl -n energy-kotlin logs deployment/energy-trading-app --tail=200
kubectl -n energy-kotlin rollout undo deployment/energy-trading-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
