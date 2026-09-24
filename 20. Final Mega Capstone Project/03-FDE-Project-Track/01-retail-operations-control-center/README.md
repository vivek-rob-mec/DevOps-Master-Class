# Retail Operations Control Center

A working local FDE capstone: a retail planner imports customer sales and inventory, runs a forecast through a persistent worker, and records a replenishment review. The application preserves the source snapshot and the recommendation behind each decision.

**Milestone 1 is implemented.** The frontend, backend, SQLite database, worker, synthetic ERP export, and review ledger work together. Forecasts use an explicit same-weekday baseline on the imported data. There is no connection to Demand Desk, Incident Desk, Cost Desk, a real ERP, or a purchasing system yet. Those integrations are subsequent milestones, not implied by this dashboard.

## Learn before running

1. [Customer brief](CUSTOMER-BRIEF.md): problem, people, assumptions, and acceptance criteria.
2. [HLD](HLD.md): boundaries, data flow, deployment, and tradeoffs.
3. [LLD](LLD.md): contracts, tables, state transitions, and concurrency.
4. [Implementation map](IMPLEMENTATION.md): what the code does and why.
5. [Hands-on walkthrough](FDE-WALKTHROUGH.md): predict, run, inspect, break, recover.
6. [Learning loop](LEARNING-LOOP.md): recall and transfer exercises.
7. [Verification](VERIFICATION.md): evidence and practical limits.

## Run locally on Windows

Open PowerShell in this project directory. Reuse the previously prepared MLOps environment:

```powershell
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' app.py serve
```

In a second terminal in the same project directory:

```powershell
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' app.py worker
```

Open **http://127.0.0.1:8216**. Load the simulated ERP export, publish it, queue a forecast, and refresh. The UI deliberately does not auto-refresh over an operator's input. Stop each process with Ctrl+C. State remains in `state/retail.db`.

For a separate environment instead:

```powershell
py -3.14 -m venv .venv
.venv/Scripts/python.exe -m pip install -r requirements.lock
.venv/Scripts/python.exe app.py serve
# Second terminal:
.venv/Scripts/python.exe app.py worker
```

`app.py demo` publishes the bundled synthetic snapshot and processes queued work without needing a running worker. `app.py worker --once` claims at most one eligible job, useful for observing state transitions. Demo uses fixed request IDs: rerunning it does not roll back a later import. Use the UI to deliberately republish the sample.

The fixture contains 105 sales rows: three products, 35 days from 2026-08-01 through 2026-09-04. It is a historical lab replay. The Coffee result is 140 forecast units, 35 on hand, a safety buffer of 10, and **115 suggested units**. The seven-day backtest MAE is 1 unit for each product.

## Verify

```powershell
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' -m pytest tests -q
# Optional browser dependencies; Microsoft Edge must be installed:
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' -m pip install -r requirements-browser.txt
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' scripts/smoke_ui.py
```

The browser script uses a temporary database and separate HTTP and worker processes. It never modifies the demo database. Screenshots and its report are written under gitignored `evidence/`.

## Containers

```powershell
docker compose up --build -d
docker compose logs -f api worker
docker compose down
```

API and worker share one local named volume. `down` preserves it; `down -v` deletes the lab data, so use that only when intentionally resetting. The API binds host loopback. Containers use a non-root user, read-only application files, dropped capabilities, and memory limits. Container execution has not been verified here.

## Scope

Single customer, single warehouse, integer units, seven-day planning horizon, and inventory declared as of the final sales date. The baseline is not a trained ML model. Approval records a human decision and always returns `executed: false`. No authentication, tenant isolation, cloud infrastructure, multi-host database, model registry integration, or automatic purchasing is implemented. The origin check reduces accidental browser cross-origin writes; it is not authentication. Keep this learning service on loopback.

Next milestone: add a customer-input inference contract to Demand Desk and a bounded-timeout adapter here. Preserve baseline fallback provenance and test the service-unavailable path before connecting AIOps and FinOps.
