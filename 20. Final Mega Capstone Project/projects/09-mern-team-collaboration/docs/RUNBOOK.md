# MERN Team Collaboration Platform - Runbook

Namespace `collaboration-mern`; local URL `http://localhost:8089`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n collaboration-mern get deploy,pod,svc,ingress
kubectl -n collaboration-mern get events --sort-by=.lastTimestamp
kubectl -n collaboration-mern logs deployment/collaboration-api --tail=200
kubectl -n collaboration-mern rollout undo deployment/collaboration-api
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
