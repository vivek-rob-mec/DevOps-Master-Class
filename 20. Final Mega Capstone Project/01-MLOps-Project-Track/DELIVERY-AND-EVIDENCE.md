# Shared implementation and evidence contract

Status: acceptance guide for the implemented local projects and their production extensions. Executed checks are recorded in [VERIFICATION.md](VERIFICATION.md); each project's implementation map identifies the delivered scope. Synthetic benchmark evidence is not a measured business outcome.

## HLD and LLD responsibilities

An HLD explains actors, scope, important requirements, component responsibilities, trust/failure boundaries, data flows, scale assumptions, alternatives, and tradeoffs. An LLD specifies actual schemas, API behavior, state transitions, feature calculations, retry/idempotency rules, deployment parameters, and testable failure behavior. Keep both synchronized with implementation.

## Build in vertical slices

1. **Understand:** a one-page business problem, decision being supported, non-ML baseline, correctness rules, and data limitations.
2. **Data:** reproducible ingestion, validation, provenance/checksum, labels and availability times, deterministic fixtures, and split definitions.
3. **Baseline:** a simple method with time/entity-aware evaluation and a locked final holdout.
4. **Model:** a bounded candidate experiment, fit transforms on training data only, record hyperparameters and seeds, and compare meaningful slices.
5. **Application:** one complete prediction-to-user-decision journey, validation, explicit uncertainty/fallback, and durable audit records.
6. **Delivery:** containerize, test, scan, publish immutable artifacts, approve a complete release bundle, and verify the running version.
7. **Operations:** telemetry, data/quality monitors, controlled failure, recovery, and a tested compatibility plan.
8. **Defense:** reproducible evidence, an architecture decision, a rejected hypothesis, and a delayed closed-note reconstruction.

Progress through one project's slices before beginning another full project. Add tools only when an identified responsibility needs them.

## Release bundle

For the production extension, the proposed `release.json` schema contains: `release_id`, `source_sha`, `application_image_digest`, `dataset_manifest_sha256`, `split_manifest_sha256`, `feature_schema_version`, `preprocessor_sha256`, `model_sha256`, `policy_version`, `evaluation_report_sha256`, `created_at`, and `approval_record_id`. Local v1 records source/dependency/data/split/model/metrics SHA-256 values, the feature schema, embedded policy, runtime versions, eligibility, and release ID. Its joblib bundle contains the estimator/preprocessor; external image digests, signatures, and approval authorities are not fabricated.

For a baseline implementation without a learned model, identify the baseline algorithm and its configuration digest instead. Record package locks, dependency manifests, training hardware/runtime, and seeds. Deterministic splits are required; byte-identical training results depend on the algorithm/runtime and must be tested rather than assumed.

Never load a mutable registry alias independently on each request. Resolve an approved release to immutable artifacts during deployment, verify checksums and compatibility, and expose the loaded release ID. Checksums detect corruption; trusted source and signature verification establish authenticity. Only load model artifacts from the trusted training/release path, especially formats that can execute code when deserialized.

Roll back preprocessing, model, decision policy, and compatible application configuration together. A database migration is a separate compatibility concern. Preserve earlier artifacts for the declared rollback window.

## Required evidence

| Evidence | Question it answers |
|---|---|
| Problem and baseline | What decision are we improving, and compared with what? |
| Dataset and split manifests | Which observations were used, and what information existed at prediction time? |
| Evaluation and slice report | Where does the candidate improve or regress, and how uncertain is that result? |
| Contract and failure tests | What happens with missing, stale, duplicate, malformed, or out-of-order input? |
| Deployment record | Which application, feature, model, and policy versions actually ran? |
| Operational report | Were latency, freshness, memory, and availability measured under stated conditions? |
| Recovery timeline | Can we restore a known-good compatible release and verify the user journey? |
| Business-policy simulation | What assumptions turn model outputs into an estimated operational benefit? |
| Limitations | What remains simulated, unmeasured, or unsupported by the data? |

Use `evidence/<run-id>/` for sanitized output: environment/resource inventory, exact commands, dataset manifest, evaluation JSON, test output, plots, release record, incident timeline, and a concise findings report. Label **target**, **measured result**, and **not measured** separately.

## Monitoring rules

Monitor service health, data validity/freshness, prediction distribution, and outcomes separately. Drift is a signal to investigate, not proof of reduced accuracy. Outcome labels may arrive late; compute quality only on explicitly defined matured cohorts and report missing-label rates. Do not automatically promote a retrained model merely because drift was detected.

Candidate thresholds are hypotheses established on validation data. Keep the final holdout out of threshold tuning and repeated model selection. Operational targets must specify hardware, payload, concurrency, duration, and measurement method. A health check is not a model-quality check.

## Resource and learning constraints

Use capped datasets, CPU baselines, serial training, and small local services first. Optional cloud and distributed infrastructure remain later milestones. Retain local command equivalents so a cloud outage or lack of budget does not stop fundamental learning.

After each slice, explain what, why, how, failure behavior, and recovery without the solution open. Revisit a changed scenario after a delay. Memorizing the tool names is not the completion gate.
