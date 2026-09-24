# .NET Insurance Claims Modular Monolith - Runbook

Namespace `claims-dotnet`; local URL `http://localhost:8092`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n claims-dotnet get deploy,pod,svc,ingress
kubectl -n claims-dotnet get events --sort-by=.lastTimestamp
kubectl -n claims-dotnet logs deployment/claims-app --tail=200
kubectl -n claims-dotnet rollout undo deployment/claims-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
