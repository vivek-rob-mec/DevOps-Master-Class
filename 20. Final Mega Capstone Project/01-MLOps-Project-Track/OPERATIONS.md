# Local operations and recovery

## Identify the state before changing it

Each project's `state/application.db` stores its domain records. `state/releases/ID/` contains model, dataset, split, evaluation, and release files. `state/active.json` selects the current release. Maintenance also has `state/central.db`. The track's shared `state/telemetry.db` belongs to all native projects.

Native `STATE_DIR` and `TELEMETRY_DB` environment variables override these paths. Inspect them before a lab. Compose uses separate named volumes and container paths. Never assume a native command changes container state.

## Service fails readiness

Read `/readyz`, the terminal/container log, and the release metadata. Typical causes: no active release, absent model, modified dataset/evaluation evidence, corrupted artifact, or incompatible scikit-learn runtime. Run `train`, inspect the report, and explicitly `promote --release ID`. Do not bypass the checksum or eligibility check.

## Restore an earlier model

Stop new promotions, identify a retained eligible release, record its source/schema/policy, then run `rollback --release ID` using the project interpreter. Read `/report` and verify its ID. Send a new business request and inspect its release reference.

M1 publishes forecasts separately from activating models; run its explicit forecast command after rollback if new forecasts are required. Risk decisions and issued sensor predictions are immutable historical records; replaying the same IDs intentionally returns the earlier result. Use fresh IDs to test a newly selected model.

## Back up or reset the lab

Stop the project's API and training processes before copying its whole state directory so the model pointer and SQLite records form a coherent lab snapshot. Stop all native writers before copying shared telemetry. Preserve the databases and any SQLite WAL/SHM files present together; for live database backups use SQLite's backup API instead of copying only the main `.db` file.

Restore into a new directory and set `STATE_DIR` to it. Verify active checksums and a business read before using the copy. A new empty state directory is the preferred way to repeat a clean lab without deleting previous evidence. Record the corresponding `TELEMETRY_DB` setting as well.

Container `docker compose down` stops the lab and preserves state. Removing volumes is a separate deliberate data-deletion action. The telemetry volume may be shared by other running projects.

## AIOps investigation

Check sample count, window times, fixture markers, and detector release. Examine the cited source events. A recent deployment may be correlated with an incident while a database or load change is responsible. Approve/reject the proposal only after inspection; the application never executes remediation.

If no incident appears, check whether at least five samples arrived within 60 seconds and whether AIOps reads the same telemetry database as the producer. Missing telemetry is not proof of health. If many healthy services alert, investigate baseline mismatch before expanding automatic actions.

## Portfolio evidence

Record the exact failure, hypothesis, observation, recovery action, verification, and limitation. Keep simulated edge outages and fault telemetry clearly labeled. Do not claim a restore, container deployment, cloud failover, or business outcome that has not been performed.
