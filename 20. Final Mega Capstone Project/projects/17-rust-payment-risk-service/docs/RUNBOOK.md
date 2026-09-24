# Rust Payment Risk and Transactional Outbox Service - Runbook

Namespace `payment-risk-rust`; local URL `http://localhost:8097`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n payment-risk-rust get deploy,pod,svc,ingress
kubectl -n payment-risk-rust get events --sort-by=.lastTimestamp
kubectl -n payment-risk-rust logs deployment/payment-risk-app --tail=200
kubectl -n payment-risk-rust rollout undo deployment/payment-risk-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
