# PHP Inventory Management Modular Monolith - Runbook

Namespace `inventory-php`; local URL `http://localhost:8084`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n inventory-php get deploy,pod,svc,ingress
kubectl -n inventory-php get events --sort-by=.lastTimestamp
kubectl -n inventory-php logs deployment/inventory-app --tail=200
kubectl -n inventory-php rollout undo deployment/inventory-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
