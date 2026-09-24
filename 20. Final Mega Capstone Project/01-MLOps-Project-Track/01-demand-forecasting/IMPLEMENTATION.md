# Implemented v1 and target design

The complete local vertical slice is implemented in `app.py`; shared artifact/API/telemetry code is in `../mlops_common`. HLD/LLD remain the broader design reference. The following mapping takes precedence for claims about running v1 behavior.

| Concern | Implemented behavior |
|---|---|
| Data | Seeded in-process generator; 8 SKUs, 224 days; exact snapshot stored in every release |
| Features | Strict history cutoff; 28-day history, lag/mean/trend/calendar/horizon/product features |
| Evaluation | Chronological target-day train/validation/test partitions; all preprocessing derives from available history |
| Model | Bounded 40-tree regressor; seasonal-naive baseline; validation selection plus final holdout acceptance veto |
| Business simulation | One-day reset inventory policy with explicit zero-stock/immediate-delivery assumptions; forecast API also offers a separate 7-day advisory |
| Persistence | SQLite batch/forecast/current-pointer tables plus inventory and immutable replenishment reviews; additive table creation preserves existing forecasts |
| Frontend | Responsive Demand Desk dashboard in `frontend/`; product search, history/forecast SVG and data table, inventory form, review workflow, model comparison, recent batches, saved decisions |
| Serving | Same-origin FastAPI static frontend; planner reads, inventory writes, review writes, original forecast/recommendation routes, release report and OpenAPI console |
| Review consistency | Inventory revisions prevent lost updates; batch/revision checks prevent approving changed inputs; idempotent request IDs prevent duplicate retries; recommendation recomputed by the backend |
| Freshness | Batch over 24 hours is labeled stale; approval rejected, deferral allowed; model promotion never relabels previously published batch evidence |
| Release | Immutable joblib bundle, source/dependency/data/split/model/evaluation hashes, explicit local activation/rollback |
| Failure | Injected failure before publication preserves the complete previous batch |

The v1 uses one fixed chronological split, not multiple rolling backtest folds. Final holdout rejection selects the existing baseline; it does not initiate retuning. Independent datasets or nested temporal evaluation are needed for additional model-development rounds.

Deferred: public transaction-file ingestion/quarantine, real availability calendars, quantile models/calibration, external inventory data, MLflow/PostgreSQL migration, signed artifacts, authenticated users, and scheduled Kubernetes jobs. These are explicit extensions, not hidden background services.

The planner is a complete local UI/API/database workflow. Inventory is entered manually; review names are display labels. There is no purchase execution or multi-user authorization. Write requests with a foreign browser Origin are rejected, but this is not authentication. The read path verifies and loads the published release bundle; it never trains. This simple path is appropriate for the bounded local dataset, not a measured high-throughput serving design.

No claim of real retail savings follows from the synthetic inventory simulation. The holdout result may be worse than validation and may favor the baseline. Preserve both findings in the learning report.
