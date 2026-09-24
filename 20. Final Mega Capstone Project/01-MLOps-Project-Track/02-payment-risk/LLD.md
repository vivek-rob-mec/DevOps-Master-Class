# M2 LLD: Online features, idempotency, labels, and rollout

Status: target design with a runnable local v1. See [IMPLEMENTATION.md](IMPLEMENTATION.md) for implemented APIs and the local transaction model.

## Schemas

The records below describe the broader target. The exact delivered SQLite/API contracts are listed next.

| Record | Fields and invariant |
|---|---|
| `transaction_event` | tenant, event ID, entity ID, merchant ID, amount in integer minor units, currency, event time, received time, payload hash; unique `(tenant, event_id)` |
| `feature_snapshot` | event reference, feature schema, cutoff, values, missing/stale flags, history watermark, computation code SHA; immutable for a completed decision |
| `risk_decision` | event reference, probability or null, advisory outcome, reason codes, feature snapshot, release ID, policy version, latency, completion time |
| `label_event` | event reference, outcome, observed time, available time, source, revision; corrections preserve prior history |
| `review_case` | decision reference, queue state, reviewer identity, action, rationale, timestamps |
| `shadow_result` | event reference, candidate release, candidate score, actual serving release; never overwrites the serving decision |

Separate currencies when computing amount features; no implicit exchange-rate conversion. Synthetic identities remain consistent across streams. Validate finite numeric input, allowed currency, nonnegative amount, bounded identifiers, and a configurable future-clock-skew limit.

## Implemented Risk Desk contracts

| Route | Delivered behavior |
|---|---|
| `GET /`, `/assets/*`, `/shared/*` | Local HTML, project JavaScript, shared CSS/render helpers |
| `GET /v1/desk` | Whole-ledger counts, latest 200 decisions, latest 30 reviews, active release evidence; explicit unavailable model state |
| `GET /v1/risk-decisions/{event_id}` | Saved event, decision/features, label maturity, final review, verified evidence for the original decision release; unknown event 404 |
| `POST /v1/risk-decisions` | Validated transaction; same body/ID returns original decision, conflicting reuse 409; invalid/far-future timestamp 422; unavailable model 503 |
| `POST /v1/risk-reviews` | `{request_id,event_id,decision,reviewer,notes}`; decision `escalate` or `clear`; saves an immutable event/result snapshot with `executed=false` |
| `POST /v1/labels` | `{event_id,fraud,available_at}`; strictly boolean fraud; future availability permitted for the simulator; conflicting label 409 |
| `GET /v1/outcomes` | Count scored events and currently matured labels; unknown/pending are not negatives |

The review request ID is 8–80 ASCII letters/digits/underscore/hyphen. Reviewer is 1–80 trimmed characters; rationale is 1–1,000. Invalid and extra fields return 422. Foreign browser Origin writes return 403. These checks do not provide authentication or tenant isolation.

Existing tables: `decisions(event_id PK,payload_hash,event,features,response)` and `labels(event_id PK,fraud,available)`. JSON text preserves the saved event and response.

New additive table: `operator_reviews(request_id TEXT PK,target TEXT UNIQUE,payload_hash TEXT,created REAL,snapshot TEXT)`. For Risk Desk, target is the event ID. The shared helper in `mlops_common/operations.py` uses `BEGIN IMMEDIATE`: check request identity/hash, reject another final review of that target, read the scored event, insert the immutable review, commit. Same request/payload returns the stored review even after model promotion. An ID reused with different data or another review of a finalized event returns 409.

Label writes also serialize their read/compare/insert operation. A pending label's fraud value is withheld from dashboard responses until `available_at <= now`. No UI review auto-generates a label. The frontend renders untrusted names/notes as text and retains request identity across unchanged retries.

## Broader target scoring API and idempotency

`POST /v1/risk-decisions` receives an event and an idempotency key under authenticated tenant context. Return event ID, decision ID, advisory outcome, probability when available, reason codes, release ID, and feature freshness. Return 422 for invalid input, 409 for key/event reuse with a different payload, and 503 for required serving dependencies unavailable.

Reserve the event/key using a uniqueness constraint. For a duplicate completed request, return the persisted decision. For an in-progress duplicate, return a documented retryable response rather than execute another independent decision. Do not keep a database transaction open across an unbounded inference call. A reservation has an expiry/attempt lease; an abandoned attempt can be retried, while finalization compares the attempt token to prevent stale workers from overwriting the winner.

Bind model, preprocessing, and policy to one release for the whole attempt. Persist the feature snapshot and decision so a retry does not silently use a newer model or history. Where feature/decision persistence cannot complete, return an unavailable response rather than an unaudited success.

## Feature semantics

Examples: prior-event counts in 5-minute and 24-hour windows, prior amount summaries, and a terminal/entity history signal. Exclude the current event. Include only records visible by the decision cutoff and within the documented event-time window. Specify deterministic tie ordering and how late events affect subsequent decisions.

Use the same pure feature functions for offline replay and online serving. Offline replay must reproduce arrival order and availability cutoffs; merely querying all historical events by event time leaks late-arriving information. Save the history watermark used for each decision. Coordinate concurrent events for the same entity or explicitly define which committed snapshot is visible.

Start with indexed PostgreSQL queries and a bounded history window. A later cache is an optimization with measured freshness, not a new source of truth. Test online values against offline reconstruction of the same decision snapshot.

## Labels and model evaluation

At training cutoff `T`, include only outcomes with `available_at <= T`. Preserve unresolved events as unknown; never convert them to negatives. Reserve a later chronological holdout and an explicit feedback-delay gap. Fit preprocessing and threshold selection only on earlier training/validation periods.

Evaluate a rules baseline, a calibrated linear classifier, and a bounded tree candidate. Use PR-oriented ranking measures, recall at review budget, calibration, and entity/merchant/time slices. Define handling when a slice has no positive examples. Estimate variability across time blocks rather than treating correlated events as independent evidence.

Choose review thresholds on validation data under a stated reviewer-capacity budget. Evaluate delayed labels on matured cohorts, report coverage and selection bias, and distinguish simulated full ground truth from the partial labels exposed to the training pipeline.

## Release and recovery state

`candidate -> offline_passed -> shadow -> reviewed -> active -> retired`

A model may also become `rejected` or `rolled_back`. Registry status alone cannot change active serving state; deployment selects an immutable release. Shadow requests reuse the same immutable feature snapshot, preventing differences caused by feature timing from being attributed solely to the model.

Use a fixed replay set to test a candidate first. A local routing simulation can teach canary behavior, but is not evidence of a live production experiment. Require data quality, offline model, latency/error, and review-capacity checks before promotion. Abort conditions are declared before the run.

## Failure and acceptance cases

- Same event twice, including concurrent requests and conflicting payloads.
- Database loss after reservation and before finalization; lease recovery without two winning decisions.
- Missing, stale, late, and future-dated history; snapshot reconstruction matches the original result.
- Corrupt/incompatible model artifact; readiness remains false or explicit degraded mode is reported.
- Pattern shift with delayed labels; drift alerts must not claim immediately known accuracy loss.
- Failed candidate promotion; restore the complete earlier release and retain decision history.

Store replay seed, event/label manifests, split cutoffs, feature equality reports, latency distribution, ranking/calibration reports, review policy, and recovery timeline. Measured performance and business benefit remain pending.
