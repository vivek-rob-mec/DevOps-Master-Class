# Go Cloud-Native URL Shortener - Runbook

Namespace `shortener-go`; local URL `http://localhost:8090`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n shortener-go get deploy,pod,svc,ingress
kubectl -n shortener-go get events --sort-by=.lastTimestamp
kubectl -n shortener-go logs deployment/shortener-app --tail=200
kubectl -n shortener-go rollout undo deployment/shortener-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
