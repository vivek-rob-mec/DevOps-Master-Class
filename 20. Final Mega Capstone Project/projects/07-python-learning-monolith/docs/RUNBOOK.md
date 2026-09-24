# Python Learning Management Modular Monolith - Runbook

Namespace `learning-python`; local URL `http://localhost:8087`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n learning-python get deploy,pod,svc,ingress
kubectl -n learning-python get events --sort-by=.lastTimestamp
kubectl -n learning-python logs deployment/learning-app --tail=200
kubectl -n learning-python rollout undo deployment/learning-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
