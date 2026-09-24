# Node.js Booking Microservices Platform - Runbook

Namespace `booking-node`; local URL `http://localhost:8083`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n booking-node get deploy,pod,svc,ingress
kubectl -n booking-node get events --sort-by=.lastTimestamp
kubectl -n booking-node logs deployment/booking-gateway --tail=200
kubectl -n booking-node rollout undo deployment/booking-gateway
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
