# Implemented v1 and target design

| Concern | Implemented behavior |
|---|---|
| Data | 50 deterministic synthetic run-to-failure histories; arbitrary simulated sensor units |
| Split | Complete equipment units: 30 training, 10 validation, 10 test; future remaining life is only a target |
| Model | Trailing-five features; 40-tree regressor versus training-population age baseline |
| Evaluation | MAE/RMSE in cycles, per-unit errors, one first persistent inspection warning per held-out unit |
| Edge | SQLite sensor ledger and durable spool; five consecutive readings required; duplicate/conflict/order checks |
| Advisory | Three low remaining-life estimates with the same release before an inspection advisory |
| Central | A separate SQLite database; commit-before-ack, idempotent replay, conflict rejection |
| Backpressure | 1,000 queued-record limit; no acknowledgement when the spool cannot accept another record |
| Update | Verify artifact/metadata checksums and runtime compatibility before atomic active-pointer replacement; preserve earlier releases |
| Recovery | Lost acknowledgement after central commit, disconnection retention, and capacity behavior tested |
| Frontend | Fleet Desk: site/equipment search, latest prediction, 60-sample RUL trend/table, sensor input, local/central counts, manual upload, model comparison |
| Inspection reviews | Final immutable decision per `(site,equipment,sequence)`; requires a predicted latest sample, rejects stale sequence, retries return the saved snapshot |
| Site isolation | Fleet/history group by both site and equipment; health-estimate route supports `?site=...` while defaulting to `lab` |
| Degraded reads | Fleet and saved samples remain readable when evidence is unavailable; model panel shows the error explicitly |

Central ingestion is an in-process adapter over a separate durable database. The exercise injects transport failure at the adapter boundary; no physical network site is disconnected. Replace that adapter with a mutually authenticated HTTP/MQTT link in the next phase without changing acknowledgement semantics.

Deferred: NASA data ingestion, real equipment integration, signed manifests/test-vector activation, device identity rotation, model-expiry rules, byte-based disk quotas, physical site isolation, cloud storage, and automatic replay scheduling. V1's row-count bound is not a filesystem capacity guarantee.

Recorded predictions stay immutable after release changes. A rerun of the demo may return earlier responses for the same sample IDs by design; newly identified equipment/events use the newly active release. The failure exercise always creates fresh records.

The dashboard is a complete local frontend/API/database workflow. An inspection review records intent with a self-entered name and rationale; it performs no machine or scheduling action. Foreign browser Origin writes are rejected; this is not production authorization. Reviews remain local and are not added to the existing sensor upload protocol. The UI uses common assets and review helpers in `../mlops_common`.

The chart breaks at absent predictions, sequence gaps, and release changes. It does not display a confidence interval or convert cycles into hours. Manual readings can be outside the simulator's training distribution; extreme sensor values alone do not guarantee a warning. The warning-policy browser test uses a coherent late-life trajectory from the stored synthetic dataset.
