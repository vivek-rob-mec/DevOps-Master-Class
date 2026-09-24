# Demand Desk: full-stack local forecasting project

Start with [HLD.md](HLD.md) and [LLD.md](LLD.md), then compare them with [IMPLEMENTATION.md](IMPLEMENTATION.md). Follow [LAB.md](LAB.md) as you execute the code. Shared installation is in [QUICKSTART.md](../QUICKSTART.md).

## Run

From this folder, after installing the track's virtual environment:

```powershell
..\.venv\Scripts\python.exe run.py demo
..\.venv\Scripts\python.exe run.py serve
```

Open http://127.0.0.1:8211 for **Demand Desk**, the working planner dashboard. The demo generates 8 products × 224 daily observations, fits a bounded random forest, evaluates a seasonal-naive baseline, and publishes 56 forecast rows in one transaction. Dates are synthetic and anchored to 2025-01-01.

The frontend uses HTML, CSS, JavaScript, and an SVG chart served by FastAPI. It needs no Node build, CDN, paid service, or second web server. SQLite stores forecasts, inventory, and review decisions. The API explorer remains at `/docs`.

## Use the application

1. Search for a SKU and select it. Inspect 28 observed days and the next 7 forecast days; expand the daily values table for exact numbers.
2. Enter the product's stock on hand and select **Save stock**. The recommendation uses the saved count; unsaved edits disable review submission.
3. Enter your reviewer name, select approve or defer, add a rationale, and select **Save review**. Reload the page or restart the API: the record and stock count persist.
4. Compare the baseline and candidate in **Model evidence**. Check the published batch and active release under **Trace this forecast**. A promotion without a new forecast batch shows a mismatch message.

Approval records a decision only; no supplier order is sent. Reviewer names are self-entered, not authenticated identities. Batches older than 24 hours can be deferred but cannot be approved. `demo` creates and publishes a new release to refresh the learning fixture while preserving stock and reviews. Retrying the exact same release/origin batch preserves its original publication timestamp.

See [PLANNER-WALKTHROUGH.md](PLANNER-WALKTHROUGH.md) for what each component does, why it exists, and a recall exercise.

`/v1/recommendations/SKU-000?inventory=20` returns advisory order units with its policy assumptions. No purchasing or external inventory mutation occurs.

The candidate must pass validation and a final held-out acceptance check. If it fails, the seasonal baseline remains the deployable method. The holdout is an acceptance veto; do not repeatedly retune against it. Metrics preserve the rejected candidate's result.

## Release and recovery

```powershell
..\.venv\Scripts\python.exe run.py train
..\.venv\Scripts\python.exe run.py promote --release RELEASE_ID
..\.venv\Scripts\python.exe -c "import sys; sys.path.insert(0,'..'); from app import Project; print(Project().forecast())"
..\.venv\Scripts\python.exe run.py exercise
```

Replace `RELEASE_ID` with a generated eligible ID. The separate forecast command is also required after rolling back the model if you want a new batch produced with the restored model. Previously published forecasts preserve their original release IDs.

`exercise` fails a batch immediately before publication and proves the previous complete batch remains visible. `/v1/forecasts` reports stale output after 24 hours. `report` displays dataset/split/model checksums, selection evidence, horizon errors, and the inventory-policy simulation.

For containers, run `docker compose up --build -d` here. The Docker build context is the parent track, so retain the shared package. Default host port: **8211**.

## Verify

From the parent track folder:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
# Optional real browser verification; requires installed Microsoft Edge.
.\.venv\Scripts\python.exe -m pip install -r requirements-browser.txt
.\.venv\Scripts\python.exe scripts/smoke_planner_ui.py
```

Browser checks use a disposable database and write desktop/mobile screenshots and a JSON result to `../evidence/`. The normal runtime lockfile and container do not include Playwright. See [verification evidence](../VERIFICATION.md) for executed results and container limitations.
