# Rails Subscription Billing Monolith - Runbook

Namespace `billing-rails`; local URL `http://localhost:8094`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n billing-rails get deploy,pod,svc,ingress
kubectl -n billing-rails get events --sort-by=.lastTimestamp
kubectl -n billing-rails logs deployment/billing-app --tail=200
kubectl -n billing-rails rollout undo deployment/billing-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
