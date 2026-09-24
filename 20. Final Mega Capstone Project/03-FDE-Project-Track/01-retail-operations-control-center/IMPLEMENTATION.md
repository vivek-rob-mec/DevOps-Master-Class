# Implementation map

| Customer need | Code | Why it exists | Verification |
| --- | --- | --- | --- |
| Understand exports | `snapshot`, `rows`, `integer` in `app.py` | Reject ambiguous dates, quantities, SKU coverage, and missing observations | Invalid-import cases |
| Preserve an input version | `Project.ingest` | Publish sales and inventory together; retain immutable source values | Atomicity and duplicate-import tests |
| Retry after a lost response | `receipt`, `save_receipt` | Bind an operation/request ID to its original payload and response | Concurrent retry and changed-payload conflict tests |
| Keep work through restarts | `enqueue`, `claim` | Persist before calculation; claim with an ownership lease | Crash recovery and unique-claim tests |
| Reject abandoned worker results | `finish` | Check ownership and expiry at publication time | Stale-token and expired-token tests |
| Explain a recommendation | `forecast` | Versioned baseline, daily outputs, inventory formula, temporal backtest | Exact sample assertions and temporal-isolation test |
| Record a defensible decision | `review` | Require current evidence and save full result with human rationale | Staleness, expiry, and concurrent review tests |
| Keep history usable | `desk` | Consistent read; current job fetched separately from recent-history limit | Republished-old-snapshot test |
| Make the workflow usable | `frontend/` | Explicit forms, evidence, job states, and literal text rendering | Real Edge walkthrough |

## Reading order

Start at `forecast`: calculate the Coffee example by hand. Then read `snapshot` and list what would make the result misleading. Follow `ingest` → `enqueue` → `claim` → `finish` → `review` to trace a decision. Finally read the UI's `refresh` and form handlers to see how HTTP connects those operations.

## Contracts worth preserving when replacing components

- Replacing the baseline with a trained model must retain original input identity, model/release identity, evaluation provenance, and fallback reason.
- Replacing SQLite must preserve transaction boundaries and uniqueness; copying table names alone does not preserve correctness.
- Replacing the CSV adapter with a real ERP connector must define pagination, incremental watermarks, deletion/correction behavior, authentication, and schema drift.
- Sending a real order requires an outbox, downstream idempotency, authorization, and reconciliation. Do not add a purchase-order HTTP call inside the existing review transaction and assume retries remain safe.

## Known limits

No migration framework, authentication, pagination API, cancellation, failed-job replay endpoint, lease heartbeat, rate limiting, or production metrics pipeline is included in milestone 1. A deterministic failed job is retained for inspection. The 30-second lease and three-attempt budget are lab choices, not universal standards. Tests establish their local behavior, not suitability for every workload.
