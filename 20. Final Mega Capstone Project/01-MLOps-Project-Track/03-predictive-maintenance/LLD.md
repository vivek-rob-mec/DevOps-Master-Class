# M3 LLD: Sensor windows, spool protocol, model activation, and evaluation

Status: target specification with a runnable local edge/central simulation. See [IMPLEMENTATION.md](IMPLEMENTATION.md) for actual v1 contracts and deferred physical/network integrations.

## Core records

| Record | Fields and constraints |
|---|---|
| `sensor_event` | site, equipment ID, sequence/cycle, event and arrival times, operating settings, sensor schema, values, quality flags; unique `(site, equipment, sequence)` |
| `window_snapshot` | equipment, end sequence, length, valid-sample count, schema, trailing feature values, history watermark |
| `prediction` | window reference, estimated remaining cycles or null, uncertainty when supported, quality/degraded state, release ID, timestamp |
| `inspection_advisory` | equipment, triggering predictions, policy version, severity, acknowledgment, resolution history |
| `upload_spool` | batch ID, payload checksum, event range, attempts, last error, acknowledgement state |
| `edge_release` | release ID, model/preprocessor checksums, feature schema, test-vector checksum, signature metadata, allowed device/runtime compatibility, activation state |

The dataset's sensor positions require a source-specific feature dictionary. Do not invent physical measurement units when they are not documented. Version the dictionary with the feature schema.

## Windowing and prediction

For each equipment unit, maintain a bounded ordered trailing window ending at the current event. No centered windows or future rows are allowed. Decide a warmup length using training/validation experiments and record it in the release. Before enough valid samples exist, return `insufficient_history` rather than a normal prediction.

A repeated sequence with an identical hash is a duplicate; a different payload is a conflict requiring quarantine. Record gaps and out-of-order arrivals. Late data may update future windows under a declared policy but must not silently rewrite an issued advisory. Imputation parameters are fit on training units only, with explicit missingness indicators and a maximum gap beyond which inference is withheld.

Candidate features include current operating settings, trailing sensor mean/variation/slope, and observed cycle age. Equipment IDs identify histories and split boundaries; they are not predictive features. Store the exact window and release reference needed to reproduce each scored example.

## Training and evaluation

Separate complete training, validation, and holdout equipment units. Construct windows after assigning units to splits. Fit preprocessing on training units only. Use observed training end-of-life to construct remaining-cycle labels; future failure time is a target, never an input feature.

If using official benchmark train/test partitions, use the training partition for model selection with held-out training units. Keep official test targets untouched until final evaluation. Document any remaining-life cap and report its effect; do not silently choose a cap after examining holdout errors.

Compare the age/population baseline and a bounded regression model using per-unit and aggregate MAE/RMSE. Evaluate at the declared prediction point, including the last observed test cycle where applicable. Do not count highly overlapping windows as independent machines when summarizing uncertainty.

For an inspection threshold, choose a prediction rule and persistence requirement on validation data. Report event-level warnings, false alerts, missed events, and lead cycles; repeated warnings for one degradation episode must not inflate success. Synthetic maintenance-policy penalties are separate from measured prediction error and from real operational savings.

## Implemented Fleet Desk contracts

| Route | Delivered behavior |
|---|---|
| `GET /`, `/assets/*`, `/shared/*` | Same-process HTML/JavaScript/CSS frontend |
| `GET /v1/fleet` | Latest sample/prediction for each site/equipment pair, edge/spool/central counts, latest 30 inspection reviews, active model evidence |
| `GET /v1/equipment-history?site=...&equipment=...` | Latest 60 readings, original predictions, review of the latest sequence, original release evidence; unknown pair 404 |
| `GET /v1/equipment/{equipment}/health-estimate?site=lab` | Latest prediction for that site; backwards-compatible default `lab` |
| `POST /v1/sensor-events` | Existing sequence validation and inference; accepted sample persisted with spool record; conflicting/out-of-order sequence 409; full spool 507 |
| `POST /v1/inspection-reviews` | `{request_id,site,equipment,sequence,decision,reviewer,notes}`; decision `inspect` or `defer`; immutable review, `executed=false` |
| `POST /v1/spool/flush` | Upload and acknowledge at most 100 records through the local central adapter; returns acknowledged count |

New additive table: `operator_reviews(request_id TEXT PK,target TEXT UNIQUE,payload_hash TEXT,created REAL,snapshot TEXT)` in the edge application database. Target is the hash of `[site,equipment,sequence]`. Snapshot includes the request, latest sensor event, original prediction/release, review timestamp, and no-execution flag.

Review writes use `BEGIN IMMEDIATE`. First return an identical retry or reject a conflicting request/previously finalized target. Then require that the requested sequence is still latest and its state is `predicted`; a stale sequence or warmup/gap state returns 409. Unknown equipment returns 404. Finally persist the event/prediction snapshot and commit. Retries of an already saved review return it even after later samples arrive.

Reviewer/rationale limits match Risk Desk: trimmed 1–80 and 1–1,000 characters; extra fields rejected. Foreign browser Origin writes return 403, but this local lab has no authenticated device/operator identity. Reviews are local records; they are not uploaded by the sensor spool protocol.

The browser uses explicit sequence advancement so retries do not invent a new sample. Site/equipment history uses query parameters, preserving identifiers without conflating sites. A generation counter discards late selection responses. The chart breaks at gaps, null predictions, or model changes; no imputation or confidence bands are invented by the UI.

## Broader target APIs and upload protocol

- Edge `POST /v1/sensor-events`: validate schema/order and persist before acknowledging ingestion. Return duplicate/conflict explicitly.
- Edge `GET /v1/equipment/{id}/health-estimate`: most recent prediction, units, freshness, release ID, window coverage, and degraded state.
- Central `POST /v1/telemetry-batches`: authenticate site/device, verify batch checksum, deduplicate events, and commit before returning acknowledgement.
- Administrative release interface: stage an approved manifest; activation requires compatibility and self-test checks. Normal telemetry clients cannot publish or activate a model.

Use SQLite for the initial durable edge spool. Central ingestion can begin with PostgreSQL. Delete local queued data only after a durable central acknowledgement. Retried batches must not duplicate central events. If an acknowledgement is lost after commit, replay returns the existing committed result.

Bound spool bytes and record high-water alerts. At capacity, use an explicit backpressure or shedding policy with loss counters and priority rules; do not claim lossless operation beyond available storage. Retry with bounded exponential backoff and jitter. Test a crash before/after local persistence and central acknowledgement.

## Model activation state machine

`downloaded -> integrity_checked -> compatibility_checked -> self_tested -> staged -> active`

Failures move the candidate to `rejected`, leaving the active release untouched. Download into a temporary location, validate sizes/checksums/signature, run fixed test vectors, and switch a version pointer atomically only after all checks pass. Preserve the prior approved model/preprocessor pair. Concurrent predictions finish on the release they started with.

An operator-authorized rollback selects a retained approved release. Record actor, reason, old/new release, and successful post-activation test. Do not fetch an unversioned `latest` artifact during a disconnected restart. Certificate or credential expiry does not justify bypassing authentication; uploads remain blocked and observable until identity is repaired.

## Failure matrix and acceptance

Test sensor omissions, wrong schemas, sequence gaps, conflicting duplicates, missing warmup, link loss, full spool, corrupt model, incompatible feature schema, interrupted activation, and process restart. Prove that each has an explicit state, a bounded resource response, and a recovery check.

Archive unit split manifests, window leakage tests, baseline/candidate errors, policy calibration, activation logs, local/central row counts after replay, buffer sizing assumptions, and recovery timing. Benchmark results cannot be presented as validated maintenance guidance for actual machinery.
