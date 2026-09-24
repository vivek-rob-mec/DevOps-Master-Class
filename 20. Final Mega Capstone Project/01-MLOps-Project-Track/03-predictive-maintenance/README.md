# Fleet Desk: full-stack predictive-maintenance learning project

Read [HLD.md](HLD.md), [LLD.md](LLD.md), [IMPLEMENTATION.md](IMPLEMENTATION.md), and [LAB.md](LAB.md). Shared installation: [QUICKSTART.md](../QUICKSTART.md).

```powershell
..\.venv\Scripts\python.exe run.py demo
..\.venv\Scripts\python.exe run.py serve
```

Open **http://127.0.0.1:8213** for the working Fleet Desk dashboard. It includes site/equipment search, a remaining-life chart and sensor table, sensor submission, finalized inspection reviews, spool upload status, and model comparisons. The demo generates 50 synthetic equipment histories, holds out complete units, trains a CPU regressor against an age baseline, and sends ten sample sensor readings into the local edge ledger.

HTML/CSS/JavaScript are served by the same FastAPI process. `state/application.db` persists edge readings, predictions, queued uploads, and reviews. `state/central.db` persists acknowledged uploads. No Node build, cloud account, or second physical device is required.

## First browser workflow

1. Enter a new equipment ID and submit sequence 1. Use **Use next sequence for selected unit**, then submit again until five consecutive readings exist. Warmup depends on sample count, not whether the first sequence happens to be 1.
2. Inspect the remaining-life estimate and exact sensor values. Submission keeps the fields unchanged so an immediate retry retrieves the original response safely.
3. Record an inspection recommendation or deferral with a rationale. The review stores the latest sample and prediction; it does not dispatch a technician or control machinery.
4. Upload queued readings using **Upload up to 100 queued records**. Compare local queue and central row counts before and after.
5. Restart the API and verify readings and reviews persist. Skip a sequence on a new reading to see inference withheld until five consecutive readings are available again.

The API explorer remains at http://127.0.0.1:8213/docs. Follow [OPERATOR-WALKTHROUGH.md](OPERATOR-WALKTHROUGH.md) for the design explanation and repeatable exercises.

`GET /v1/equipment/M-000/health-estimate` shows the latest sample. `POST /v1/sensor-events` accepts:

```json
{"site":"lab","equipment":"learner-device","sequence":1,"temperature":50,"vibration":3}
```

Send sequences 1 through 5. Until five consecutive readings exist, the response states `insufficient_history`. A duplicate sequence with the same payload returns the original result; a conflicting duplicate is rejected. Gaps withhold predictions until the window is consecutive again.

Each acknowledged event and prediction enters a durable SQLite upload spool. `POST /v1/spool/flush` commits a batch into the simulated central database before removing local records. Central and edge are separate SQLite databases on the same host, not separate physical devices.

```powershell
..\.venv\Scripts\python.exe run.py exercise
```

This injects a lost acknowledgement after the central commit, retries, and proves no duplicate central rows were created. The test suite additionally covers complete disconnection and spool-capacity backpressure. An approved model already on disk remains usable without a central connection.

Use `train` then `promote --release ID` to stage and activate a model, or `rollback --release ID` to restore an earlier compatible artifact. Issued predictions are immutable; newly arriving samples use the current release. The default data is a deterministic simulator, not NASA data or physical machinery.

For containers: `docker compose up --build -d`. Default host port: **8213**.

## Verify the workflow

From the parent track folder:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
# Optional browser checks; installed Microsoft Edge required.
.\.venv\Scripts\python.exe -m pip install -r requirements-browser.txt
.\.venv\Scripts\python.exe scripts/smoke_operator_ui.py
```

The browser script verifies both operator desks with disposable data. Keep the sibling `mlops_common` package, including its web assets, when copying this project. Container definitions include these files, but execution status is documented separately in [VERIFICATION.md](../VERIFICATION.md).
