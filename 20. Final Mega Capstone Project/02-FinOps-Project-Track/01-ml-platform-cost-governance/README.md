# Cost Desk: FinOps for an ML platform

A complete local learning application with a responsive frontend, FastAPI backend, persistent SQLite database, CSV validation, shared-cost allocation, budgets, unit economics, and reviewed savings hypotheses. Begin with [HLD.md](HLD.md), [LLD.md](LLD.md), then [FINOPS-WALKTHROUGH.md](FINOPS-WALKTHROUGH.md).

## Run in this workspace

Open PowerShell in this project folder. Reuse the already installed MLOps interpreter:

```powershell
..\..\01-MLOps-Project-Track\.venv\Scripts\python.exe app.py demo
..\..\01-MLOps-Project-Track\.venv\Scripts\python.exe app.py serve
```

Open **http://127.0.0.1:8215**. API explorer: http://127.0.0.1:8215/docs. Stop the server with Ctrl+C.

For a standalone checkout, install Python 3.14 and create a project-local environment:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.lock
.\.venv\Scripts\python.exe app.py demo
.\.venv\Scripts\python.exe app.py serve
```

No Node build, shared sibling package, or model training is required. Static frontend assets are included in this project. Using the existing sibling interpreter is a convenience, not a runtime code dependency.

## First workflow

1. Inspect the seeded August 2026 snapshot. It contains 85 cost rows and 56 service/day usage rows covering days 1–14, with a net total of **USD 325.750042**.
2. Change the shared allocation weights. They must total 10,000 basis points. Observe team totals change while the overall cost remains identical.
3. Set a budget for a team. Compare its linear month-end estimate with the saved budget. The budget is scoped to month, currency, and team.
4. Inspect cost per successful workload unit. A forecast, a payment decision, a sensor reading, and a reviewed incident are different units.
5. Calculate a hypothetical 20% compute-usage reduction. Record a review with the checks needed before any real action. The saved scenario records assumptions and estimates, not realized savings.
6. Load or edit the sample CSVs and publish a new snapshot. Invalid input rejects the entire import, preserving the previous active view.

`demo` publishes the bundled snapshot once using a stable import receipt. Repeating it preserves later active imports rather than rolling them back. To deliberately republish the sample, use the browser's **Load sample CSVs** and **Validate and publish snapshot** actions, which prepare a new import identity.

## Input data

Examples: [sample-costs.csv](data/sample-costs.csv) and [sample-usage.csv](data/sample-usage.csv). The UI accepts local files or pasted CSV text. Headers and column order are exact; each file supports up to 1,000 data rows.

- Costs: `cost_id,date,provider,service,team,category,amount,currency`.
- Usage: `date,service,successful_units,unit`.

All imported data is declared synthetic lab input. Each snapshot contains a single currency: USD, EUR, or INR. Currency values are not converted. Money is a plain decimal with at most six fractional digits, stored as integer micro-units. Negative values are permitted only for `credit` rows; credit amounts must be nonpositive. A row's magnitude cannot exceed 1,000,000 currency units; total absolute snapshot charges cannot exceed 10,000,000.

Usage must include exactly one row for every covered day and each catalog service, including explicit zero values. Missing usage cannot silently become zero. Cost-file completeness through the selected day is declared by the importer, not independently proven. This simplified schema is **not a certified FOCUS implementation**.

## Persistence and deployment

`state/costs.db` retains immutable snapshots, import receipts, allocation policy versions, scoped budgets, and scenario reviews. Set `STATE_DIR` to a different directory for an isolated lab. Restarting the API preserves saved data.

```powershell
docker compose up --build -d
docker compose logs -f
docker compose down
```

Compose prepares the sample and serves on port 8215 with a named state volume, non-root user, read-only filesystem, and resource limits. `down` preserves the volume. The 512 MB container limit is a configuration choice, not a measured application memory requirement.

The included `.github/workflows/verify.yaml` assumes **this project folder is the repository root**. Nested workflows in the course directory do not run automatically. It defines contract tests and container startup checks; execution has not been observed here.

## Verify

Using the existing interpreter from this folder:

```powershell
..\..\01-MLOps-Project-Track\.venv\Scripts\python.exe -m pytest tests -q
..\..\01-MLOps-Project-Track\.venv\Scripts\python.exe scripts/smoke_ui.py
```

For a fresh virtual environment, install `requirements-browser.txt` before the browser command; installed Microsoft Edge is required. Browser dependencies are optional and excluded from the container runtime. Tests use disposable state, preserving your saved budgets and reviews. See [VERIFICATION.md](VERIFICATION.md).

There are no connected cloud accounts, real invoices, provider rates, automatic rightsizing actions, authenticated identities, or measured savings. [IMPLEMENTATION.md](IMPLEMENTATION.md) lists the remaining production work.
