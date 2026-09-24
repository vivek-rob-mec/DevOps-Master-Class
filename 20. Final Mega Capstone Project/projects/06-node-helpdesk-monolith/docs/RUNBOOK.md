# Node.js Helpdesk Modular Monolith - Runbook

Namespace `helpdesk-node`; local URL `http://localhost:8086`.

1. Capture user symptom, UTC start, environment, scope, and recent change.
2. Check `/health` and one real journey.
3. Inspect rollout, replicas, restarts, events, saturation, and dependencies.
4. Correlate metrics, logs, traces, audit, and change marker with one request ID.
5. Use the smallest reversible containment and record every action.

```bash
kubectl -n helpdesk-node get deploy,pod,svc,ingress
kubectl -n helpdesk-node get events --sort-by=.lastTimestamp
kubectl -n helpdesk-node logs deployment/helpdesk-app --tail=200
kubectl -n helpdesk-node rollout undo deployment/helpdesk-app
```

Rollback does not reverse incompatible schemas or external effects. Restore into isolation, verify integrity/access/replay, reconcile uncertain work, then prove the critical journey before traffic.
