# AIOps LLD: Windows, incidents, and review state

Status: implemented local contracts.

## Records

The shared `events` table stores integer ID, wall-clock timestamp, service, kind, latency in milliseconds, error indicator, queue depth, and JSON context. API middleware excludes health/probe scraping from traffic features. It logs path/status rather than request bodies.

Window features are `[mean_latency_ms, mean_error_indicator, max_queue_depth]`, grouped by service for the preceding 60 seconds. Require at least five HTTP/fixture samples. Release events are correlated separately and do not contribute request latency samples. Each snapshot includes first/last source-event IDs, release-event IDs, sample count, and `contains_fixture`.

New snapshots additionally store `window_start`, `window_end`, the full `source_events` list, and `release_event_snapshots` with parsed context. New incidents record `created_at`; first review finalization records `reviewed_at`. Nullable timestamp columns are added to an older `incidents` table inside a serialized schema-upgrade transaction. Old evidence remains unchanged: no source details or timestamps are reconstructed as if they had originally been saved.

The incident store is `state/application.db`. It also contains `analysis_runs(id,started,completed,detector_release,window_count,incident_ids)` for successfully completed analyses. Each Analyze request creates a run; findings with unchanged event boundaries and detector release reuse the existing incident. A successful run can evaluate zero windows and return zero incident IDs.

Fit an 80-tree Isolation Forest on 300 independent normal fixture windows, with fixed random seed and contamination 0.03. Evaluate on 100 independent healthy windows and 60 fault windows. The static comparator triggers at latency >=100 ms, error fraction >=0.1, or backlog >=20. These are demonstration constants, not measured production thresholds.

An alert is considered when either detector signals. The incident ID hashes service, event boundaries, and detector release. Persist evidence/proposal JSON and a `pending` state with a uniqueness constraint. The same analysis window is idempotent. Adjacent windows are intentionally not merged in v1.

## API and review transitions

- `GET /`, `/assets/*`, `/shared/*`: same-process dashboard and local web assets.
- `GET /v1/desk`: service observation states, sample provenance, incident counters, latest 100 incidents, latest ten completed runs, and active detector evidence. An unavailable model is represented explicitly while the ledger remains readable.
- `GET /v1/incidents/{id}`: one retained incident, original detector evidence, timestamps, and `source_snapshots_available`; unknown ID returns 404.
- `POST /v1/fixtures`: `{request_id,service,scenario}`; fixed ten-sample replay with `simulated: true`, source IDs, and original replay time. Services are the three MLOps service names; scenarios are `healthy`, `latency_error`, and `backlog`.

- `GET /v1/windows`: current feature/evidence snapshots.
- `POST /v1/analyze`: analyze and persist current findings; model absence/corruption returns 503.
- `GET /v1/incidents`: latest 100 retained incidents with proposals and review metadata.
- `POST /v1/incidents/{id}/review`: require reviewer, rationale, and `approved` or `rejected`. Unknown or conflicting finalized review returns 409. An identical repeated review is idempotent.

State transitions are `pending -> approved` or `pending -> rejected`. There is no `executing` transition. Both results return `executed: false`. Reviewer identity is a local demo field; authenticated review is a production extension.

Reviews trim strings, require a 1–100 character reviewer and a 5–500 character rationale, and reject extra fields. `BEGIN IMMEDIATE` serializes finalization; an identical repeat returns the original outcome and preserves its timestamp. Different data for a finalized incident returns 409. Foreign browser Origin writes return 403 through the common dashboard middleware; this is not an identity layer.

### Replay transaction

`aiops_fixture_runs(id TEXT PRIMARY KEY,payload_hash TEXT,response TEXT)` lives in the shared telemetry database so the replay receipt and its events commit together. A request ID has 8–80 letters/digits/underscore/hyphen. Inside `BEGIN IMMEDIATE`, return an identical request's stored receipt, reject a conflicting payload with 409, or insert all samples and the receipt atomically. `latency_error` also inserts one clearly simulated release marker. A duplicate replay after 60 seconds retains its old timestamp; prepare a new replay for fresh observations.

Fixture vectors are `[20,0,2]` for healthy, `[250,1,2]` for latency/errors, and `[20,0,35]` for backlog. They are mixed with other samples already in that service's window. The fixture action does not invoke detection automatically; Analyze is a separate action.

### Display semantics

HTTP queue values are unmeasured placeholders; fixture queues are simulated. Service cards disclose HTTP and fixture sample counts. Filter/search operates over the latest 100 listed incidents; totals cover the full local ledger. The detail view shows up to 200 stored event snapshots and discloses their total. Changed windows may create additional incidents; no grouping/suppression is implemented.

User-entered names, reasons, and event contexts are rendered as text. Late selection responses are discarded. Controls are disabled during writes/refresh and finalized review fields show the saved values. Missing/corrupt original detector evidence does not erase stored incident observations.

## Hypothesis rules

A recent release plus elevated latency/errors suggests inspecting a release regression. Backlog suggests consumer delay or disconnection. Errors also suggest checking dependencies, readiness, and artifact integrity. With no corroborating signals, report an unusual distribution or baseline mismatch. Return multiple plausible explanations instead of inventing certainty.

## Failure tests

Verify no findings before enough evidence exists, non-overwriting reviews, reproducible detector evaluation, duplicate analysis, explicit fixture tagging, and integration with actual M1 HTTP 503 responses. Missing telemetry is not tested as proof of availability. Historical incidents remain available even if the current time window has no samples.
