# M1 LLD: Data, batch jobs, release, and evaluation

Status: target design with a runnable local v1. [IMPLEMENTATION.md](IMPLEMENTATION.md) maps implemented contracts and explicitly lists deferred endpoints and integrations.

## Records and invariants

| Record | Required fields and constraints |
|---|---|
| `sales_line` | `source_id`, `source_row`, `product_id`, `event_time`, `available_at`, `quantity`, `unit_price`, `currency`; unique source checksum/row identity; explicit returns policy |
| `dataset_snapshot` | `snapshot_id`, source checksums, row count, ingestion code SHA, timezone, filter rules, calendar policy, created time |
| `feature_row` | `product_id`, forecast origin, horizon, feature schema, history cutoff, snapshot ID; no input available after the origin |
| `forecast` | product, origin, target date, horizon, point forecast, optional quantiles, release ID, created time; unique `(product, origin, horizon, release)` |
| `recommendation` | forecast reference, inventory snapshot, lead-time scenario, policy version, suggested units, review status; no external ordering side effect |
| `batch_run` | deterministic run key, input snapshot, release, state, timestamps, validation report, output checksum |

Deduplicate ingestion retries by immutable source identity. Do not collapse different transaction lines merely because their amounts match. Normalize timestamps using a declared source timezone. Exclude direct customer identifiers from the forecasting features.

If the dataset has no real availability timestamps, declare an assumed ingestion delay for the experiment and test alternate delays. Do not present inferred timestamps as observed historical information. Zero-fill days only when the observation calendar supports that interpretation.

## Feature and split algorithm

At origin `t`, build lagged daily sales and rolling statistics from rows both occurring and available before the cutoff. Shift before computing rolling target summaries. Calendar features for future dates are permitted; realized future sales, unknown future promotions, and future inventory are not.

Reserve a final contiguous holdout period before experimentation. Use earlier rolling origins for tuning. Fit imputers, encoders, scalers, and product statistics separately on each training fold. Keep the product selection rule fixed using training data. New/sparse products use a declared fallback instead of failing silently.

Baseline: same weekday's previous observed sales, with an explicit fallback for insufficient history. Compare a bounded tree candidate on identical origins and horizons. Use MAE and aggregate WAPE; if actual demand sum is zero, report WAPE undefined and provide absolute error. Report product/horizon slices and coverage instead of only an aggregate. Add pinball loss and empirical coverage if quantile forecasts are implemented.

## Job state machine

`created -> validating -> featurizing -> forecasting -> staging_output -> published`

Any stage can transition to `failed`. Re-running the same snapshot/origin/release key returns the existing completed result or retries a failed attempt with attempt metadata. Publication updates a current-result pointer only after all expected products/horizons are validated and the output transaction commits. Readers see the previous complete batch during a failed publication.

## Implemented planner contracts

| Route | Contract |
|---|---|
| `GET /` and `/assets/*` | HTML dashboard and local JS/CSS assets |
| `GET /v1/planner` | Current batch, product totals, saved inventory, published-release evaluation, active release ID, five recent batches, latest 30 reviews |
| `GET /v1/products/{sku}/planning` | Same snapshot plus 28 observed days, seven forecasts/baselines with dates, and stock-based recommendation; unknown product 404 |
| `PUT /v1/inventory/{sku}` | `{on_hand, revision}`; strict integer count 0–1,000,000; missing inventory starts at revision 0; success returns incremented revision; stale revision 409 |
| `POST /v1/replenishment-reviews` | `{request_id, sku, batch_id, inventory_revision, decision, reviewer, notes}`; decisions `approved`/`deferred`; reviewer 1–80 characters, notes up to 1,000 |

No published batch returns an empty planner response, so the UI can explain how to prepare data. Missing/corrupt release evidence returns 503. Reviews cannot bypass server-side recommendation calculation by submitting their own quantity. Unknown fields and invalid payloads return 422. Foreign browser Origin headers on writes return 403; local reviewer names remain unauthenticated labels.

The original `GET /v1/forecasts/{sku}` and `GET /v1/recommendations/{sku}?inventory=20` remain available. The original recommendation route is a stateless scenario calculation; it does not save stock. `/readyz` checks the active release; the planner separately reports batch absence, freshness, and published-evidence availability.

### SQLite schema and transactions

`batches(id PK, release_id, origin, created)`, `forecasts(batch, sku, horizon, prediction, baseline; composite PK batch/sku/horizon)`, and `current_batch(slot PK, batch)` retain the existing batch protocol.

New tables are created additively with `CREATE TABLE IF NOT EXISTS`:

- `inventory(sku TEXT PK, on_hand INTEGER CHECK >= 0, revision INTEGER, updated_at REAL)`.
- `replenishment_reviews(request_id TEXT PK, request_hash TEXT, sku TEXT, created_at REAL, snapshot TEXT)`; snapshot JSON stores the complete request plus saved stock, forecast demand, recommended units, release ID, stale flag, and creation time.

The planner reads forecast and inventory data in one SQLite snapshot. It then verifies the immutable published-release artifacts. An inventory write uses `BEGIN IMMEDIATE`, compares the expected revision, writes the next revision, and commits. Readers can continue under WAL mode.

Review transaction sequence:

1. Acquire the SQLite write transaction and check `request_id`. The same canonical payload returns the existing snapshot; a different payload with that ID returns 409.
2. Check that the supplied batch is still current and the saved inventory revision still matches. Reject changed inputs with 409.
3. Verify published release evidence. Reject approval if the batch is over 86,400 seconds old; allow a recorded deferral.
4. Compute `max(0, ceil(sum(7 predictions)) + release buffer - saved on_hand)` on the server, insert one immutable review, and commit.

The frontend holds a retry ID for an unchanged failed submission, renders user-entered text with `textContent`, and disables submission during writes or unsaved stock edits. A generation counter discards late product responses. After reload, the database supplies the saved state. This is a local teaching application: no authenticated roles, distributed locks, background purchases, or cross-device session guarantees are implied.

## Broader target API contracts

These contracts describe later extensions; they do not supersede the implemented routes above.

- `GET /v1/forecasts/{product_id}?origin=YYYY-MM-DD`: values, units, horizons, release ID, creation time, and freshness status. Unknown product returns 404; invalid dates return 422.
- `GET /v1/recommendations/{product_id}`: advisory units plus the forecast, inventory, lead-time, and policy assumptions used.
- `POST /v1/recommendations/{id}/reviews`: a human review record with identity, decision, and rationale; repeated idempotency key with different payload returns 409.
- `/healthz`: process health. `/readyz`: valid loaded release and accessible forecast store; freshness is also surfaced to the planner, not hidden behind a generic health status.

A forecast request never initiates expensive training. Training and scheduled inference are explicit commands/jobs. Authentication and role checks are required before accepting multi-user reviews; local fixtures use a clearly identified demo user.

## Replenishment simulator

Use synthetic stock levels, delivery delays, and demand paths from a separate scenario fixture. A simple order-up-to policy can compute `max(0, target_stock - inventory_position)` under stated assumptions. Compare forecast-driven and baseline policies with the same starting stock, demand stream, lead times, and penalty weights.

Report unfilled units, holding units, service level, and penalty sensitivity. Historical sales alone cannot reveal censored demand or actual lost sales. Preserve that limitation in exported reports.

## Failure tests and release gate

Test duplicate files, malformed quantities, returns, missing days, schema changes, future-data leakage, delayed ingestion, zero-demand products, and failure immediately before publication. Verify old results remain readable and the freshness flag changes as expected.

Predeclare a non-regression rule on validation metrics and critical product slices; select thresholds before inspecting the final holdout. Promote only after reproducibility, schema compatibility, batch completeness, and application tests pass. A prediction-distribution shift opens an investigation; it does not trigger unreviewed model promotion.

Archive split manifests, per-origin errors, policy assumptions, artifact checksums, batch logs, and rollback evidence. All proposed metrics remain unmeasured until implementation is executed.
