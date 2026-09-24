# Run the complete local MLOps and AIOps suite

The four applications use real scikit-learn estimators, FastAPI services, persistent SQLite state, immutable local releases, and deterministic synthetic datasets. They require no paid API, GPU, cloud account, or public dataset download. Dependencies require internet access for the initial installation.

## 1. Install once

Use Python **3.14**, matching the verified environment and container runtime. Open PowerShell in `20. Final Mega Capstone Project/01-MLOps-Project-Track`:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.lock
```

The virtual environment has already been created and populated in the current workspace. You can start with the next step here. On a fresh checkout, install first. On Linux/macOS, use `python3.14` to create the environment and `.venv/bin/python` for subsequent commands.

## 2. Train, evaluate, and exercise each project

```powershell
.\.venv\Scripts\python.exe scripts/run_suite.py
.\.venv\Scripts\python.exe -m pytest tests -q
.\.venv\Scripts\python.exe scripts/smoke_live.py
```

The suite runs sequentially to fit the laptop. It writes reports under `evidence/` and persistent project data under each project's `state/`. `smoke_live.py` briefly starts each actual HTTP server on an available loopback port, tests its business endpoint, and stops it. No cluster or external account is changed.

The learned candidate must earn selection. M1 compares against seasonal-naive forecasts, with a final holdout rejection gate. M2 compares against its amount-based rule. A rejected candidate leaves the baseline selected. The model's score and the application's reliability are separate outcomes.

## 3. Work through one project in depth

| Folder | Start command from this track folder | API console |
|---|---|---|
| `01-demand-forecasting` | `.\.venv\Scripts\python.exe 01-demand-forecasting/run.py serve` | http://127.0.0.1:8211/docs |
| `02-payment-risk` | `.\.venv\Scripts\python.exe 02-payment-risk/run.py serve` | http://127.0.0.1:8212/docs |
| `03-predictive-maintenance` | `.\.venv\Scripts\python.exe 03-predictive-maintenance/run.py serve` | http://127.0.0.1:8213/docs |
| `04-aiops-incident-triage` | `.\.venv\Scripts\python.exe 04-aiops-incident-triage/run.py serve` | http://127.0.0.1:8214/docs |

Run only the services needed for the current experiment. Full dashboards are available at http://127.0.0.1:8211 (Demand Desk), http://127.0.0.1:8212 (Risk Desk), http://127.0.0.1:8213 (Fleet Desk), and http://127.0.0.1:8214 (Incident Desk). Each provides release/evaluation output at `/report`, health/readiness routes, and Prometheus-format counters at `/metrics`. Stop a native server with Ctrl+C.

For optional real browser verification, install `requirements-browser.txt` into the same virtual environment and run `scripts/smoke_planner_ui.py`, `scripts/smoke_operator_ui.py`, and `scripts/smoke_aiops_ui.py`. These use installed Microsoft Edge and disposable databases, preserving your working project state. They write screenshots and JSON results to `evidence/`; Playwright is not a production/container dependency.

The individual README, HLD, LLD, implementation map, and lab file explain the project. Source files are inside their respective project folders. Keep the `mlops_common` sibling package and `requirements.lock` when copying a project: shared release/telemetry behavior is intentionally implemented once.

## 4. Understand the commands before using them

| Command | Effect |
|---|---|
| `train` | Generate the deterministic dataset, train/evaluate, and write a new immutable release; leaves active state unchanged |
| `promote --release ID` | Verify artifact/evidence checksums and eligibility, then update the active model pointer |
| `rollback --release ID` | Restore a retained eligible release using the same verification; does not undo business/database state |
| `demo` | Train, select an eligible candidate or baseline, activate it, and create the project's sample business state |
| `serve` | Serve existing state; it does not train implicitly |
| `report` | Print the active release and its evaluation |
| `exercise` | Run the project's bounded failure/recovery demonstration |

For example, run `python run.py train` from a project folder using the virtual environment's interpreter, inspect the returned ID, and then run `python run.py promote --release ID`. Exact interpreter paths are shown above. To publish forecasts after a separate M1 promotion, call its `Project().forecast()` method as shown in that project's README; changing the model pointer alone intentionally does not rewrite forecasts already published.

## 5. Containers

Docker Engine/Desktop must be running in Linux-container mode. From the track folder:

```powershell
docker compose -f 01-demand-forecasting/compose.yaml up --build -d
docker compose -f 01-demand-forecasting/compose.yaml logs -f
```

Replace the folder for another project. A one-shot `prepare` service runs the demo and exits; the API starts after it succeeds. Both use non-root, read-only containers with bounded memory/CPU and a persistent named state volume. The API is bound to host loopback. Recreating `prepare` can produce a new local release; this is a lab convenience, not the production model promotion workflow.

All four Compose projects share the named `mlops-track-telemetry` volume. Native processes share the track's `state/telemetry.db`. Native and container telemetry are separate by default. Do not expect an AIOps container to automatically see native telemetry.

Stop a container project with `docker compose -f FOLDER/compose.yaml down`. This preserves model/database volumes. Do not delete shared telemetry or state while another project uses it. For a clean native lab without deleting data, set `STATE_DIR` to a new empty directory, then run `demo` again.

## 6. CI and production boundaries

The supplied `.github/workflows/verify.yaml` tests on Linux, runs demos and live HTTP checks, and builds/starts each restricted container. It assumes **this track folder is the Git repository root**. Nested GitHub workflows inside the course folder do not execute automatically. Copy the track contents into a dedicated repository, or deliberately adapt the workflow paths at the course repository root.

These are complete local teaching applications, with a documented subset of the broader production designs. They use synthetic data and a local trust boundary. Authentication, multi-tenant authorization, TLS, external registries, signed provenance, high availability, production database migration, managed cloud services, and real-device integration are extensions listed explicitly in `IMPLEMENTATION.md` files. No security scanner or cloud deployment is implied by a successful unit test. Use Project 34's delivery pattern and Project 22's trust controls when moving beyond the local lab.

Do not expose these APIs beyond your lab network: reviewer names and simulated labels are supplied by the caller, and there is no production identity layer. Only load artifacts produced by the trusted local training path; joblib deserialization is not safe for arbitrary downloads.

See [VERIFICATION.md](VERIFICATION.md) for executed checks and current limitations.
