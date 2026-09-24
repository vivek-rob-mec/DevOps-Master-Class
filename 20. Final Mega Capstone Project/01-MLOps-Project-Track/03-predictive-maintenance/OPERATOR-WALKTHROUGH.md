# Learn edge ML by operating Fleet Desk

Use the [README](README.md) to start http://127.0.0.1:8213. Read the [delivered HLD](HLD.md#delivered-local-system) and [implemented LLD contracts](LLD.md#implemented-fleet-desk-contracts) before changing inputs.

## What, why, and how

| Responsibility | What it does | Why it matters | Implementation |
|---|---|---|---|
| Fleet browser | Shows units, sample history, remaining-life estimates, and reviews | Operators need the context and limits of a prediction | `frontend/index.html`, `frontend/app.js` |
| Window builder | Requires five consecutive readings from one site/equipment pair | Missing readings make the expected features unavailable | `features()` and `Project.ingest()` |
| Local model | Estimates remaining cycles using an on-disk release | Inference should not depend on a central upload for each reading | Verified release files plus model selection policy |
| Edge ledger and spool | Saves accepted readings and queues uploads atomically | Acknowledgement must mean the sample is durably retained | `sensors` and `spool` in `state/application.db` |
| Central adapter | Commits before acknowledging, deduplicates retries | Losing an acknowledgement must not duplicate central data | `Project.accept_batch()`, `Project.flush()`, `state/central.db` |
| Inspection review | Preserves an operator decision and the exact latest prediction | New readings must not silently change the basis of an old review | `operator_reviews`; stale sequence checked inside a write transaction |

The central database is a second file on this laptop. This teaches delivery semantics, not physical site independence or authenticated networking. Inspection reviews remain in the local database; the existing upload stream carries sensor events and predictions.

## Exercise 1: warmup and gaps

1. Enter a fresh equipment ID. Send sequences 1–5 using explicit next-sequence preparation. Before each click, predict whether inference is possible.
2. Explain why sequence 5 is the first estimate for this example. If observations started at sequence 101 instead, inference would begin at 105 after the fifth consecutive sample.
3. Skip sequence 6 and submit 7. The last five samples contain a gap, so remaining life becomes unavailable.
4. Continue 8, 9, 10, 11. Predict why the valid window returns at 11. Expand the sensor table to verify actual stored readings.
5. Use the same equipment ID under a different site. Show that its history starts separately.

Do not interpret arbitrary combinations of age, temperature, and vibration as realistic degradation. The model learned coherent synthetic trajectories. Extreme sensor values at an implausibly young age need not trigger the same result as a late-life trajectory.

## Exercise 2: distinguish a prediction from a warning

Read the policy: a remaining-life estimate at or below 20 cycles must persist for three consecutive predictions under the same release before an inspection advisory appears. Five samples produce the first estimate; a new unit therefore needs at least seven samples for this three-estimate warning.

The browser verification script replays the final seven readings of a saved synthetic trajectory to demonstrate this policy. Inspect those inputs in `state/releases/ID/dataset.json`; the tests create their own disposable state.

Draw the five-sample feature window and three-prediction warning window. Explain why these are different windows. Remaining cycles are not hours, and the chart provides point estimates, not confidence intervals.

## Exercise 3: review a changing machine

Open the same unit in two tabs when it has a prediction. In tab A, prepare and submit the next reading. In tab B, try saving an inspection review based on its old sequence. The API returns 409. Refresh and review the latest evidence.

Record a review, then submit another reading. Show that the saved review still contains the older sequence and release. The newer sample can receive its own review; the old one cannot be rewritten. Saving `inspect` does not stop equipment or dispatch a technician.

## Exercise 4: commit, acknowledge, replay

1. Note the accepted sample count, queued rows, and central rows.
2. Upload up to 100 rows. Explain why local spool removal happens after central commit/acknowledgement.
3. Run `run.py exercise`. It commits centrally, deliberately loses the acknowledgement, then retries the same data. Show that central rows do not duplicate.
4. Read the full-spool test. Explain why accepting another sample without space to enqueue it would be a false acknowledgement.
5. Restart the API and show that both database files retain their records.

State what survives if the central adapter fails, and what fails if the edge database itself cannot persist. A row limit of 1,000 is not a measured disk-byte quota or a guarantee against disk failure.

## Retain and compare

- **Next day:** draw sensor → window → model → spool → central from memory.
- **Day 3:** predict warmup/gap recovery and reproduce a stale-review conflict.
- **Day 7:** explain crashes before local commit, after local commit, and after central commit but before acknowledgement.
- **Day 14:** explain why entire equipment units are held out during evaluation, then compare this system with the payment-risk application.

| Project | Decision cadence | Critical consistency problem |
|---|---|---|
| Demand Desk | Published batch | Complete forecasts and inventory revisions |
| Risk Desk | Per payment event | Idempotent decisions and delayed labels |
| Fleet Desk | Per sensor reading | Consecutive history and durable acknowledgement |

Completion evidence: a window diagram, gap recovery, one persisted inspection review, replay row counts, and a two-minute explanation. Next, use [AIOps](../04-aiops-incident-triage/README.md) to investigate the real HTTP/release telemetry these applications already emit.
