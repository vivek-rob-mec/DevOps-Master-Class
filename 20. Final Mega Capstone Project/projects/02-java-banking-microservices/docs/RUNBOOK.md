# Java Banking Microservices Platform - Runbook

Namespace `banking-java`; local URL `http://localhost:8082`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n banking-java get deploy,pod,svc,ingress
kubectl -n banking-java get events --sort-by=.lastTimestamp
kubectl -n banking-java logs deployment/banking-gateway --tail=200
kubectl -n banking-java rollout undo deployment/banking-gateway
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
