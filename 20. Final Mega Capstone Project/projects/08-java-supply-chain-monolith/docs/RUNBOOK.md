# Java Supply Chain Modular Monolith - Runbook

Namespace `supplychain-java`; local URL `http://localhost:8088`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n supplychain-java get deploy,pod,svc,ingress
kubectl -n supplychain-java get events --sort-by=.lastTimestamp
kubectl -n supplychain-java logs deployment/supplychain-app --tail=200
kubectl -n supplychain-java rollout undo deployment/supplychain-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
