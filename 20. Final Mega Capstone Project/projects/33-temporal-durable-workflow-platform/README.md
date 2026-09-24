# Temporal Durable Workflow Platform

A distributed-systems capstone using Temporal 1.31, Python SDK workflows, activities, signals, queries, retries, timeouts, idempotency, saga compensation, history replay, worker versioning and production persistence operations.

```mermaid
sequenceDiagram
  participant API as Starter API
  participant T as Temporal Service
  participant W as Worker
  participant P as Payment
  participant I as Inventory
  API->>T: Start Fulfillment(orderId)
  T->>W: Schedule activity
  W->>P: Authorize payment (idempotency key)
  W->>I: Reserve inventory
  alt reservation fails
    W->>P: Compensate authorization
  end
  W-->>T: Durable result/history
```

## Outcomes

- Explain durable execution, event history and deterministic workflow code.
- Design activity retry, timeout, heartbeat and idempotency boundaries.
- Implement signals, queries, cancellation and saga compensation.
- Replay histories before deploying workflow-code changes.
- Operate Temporal persistence, visibility, worker queues and safe upgrades.

## Start

```powershell
docker compose config
python -m unittest discover -s tests -v
python scripts/replay.py history/fulfillment.json
kubectl kustomize k8s
```

For a live lab, copy `.env.example` to `.env`, start Compose, install the Python dependencies and run the worker/starter. The unit and replay exercises remain dependency-free so workflow design can be validated before infrastructure is available.
