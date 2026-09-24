# Risk Desk: full-stack payment-risk learning project

Read [HLD.md](HLD.md), [LLD.md](LLD.md), [IMPLEMENTATION.md](IMPLEMENTATION.md), and [LAB.md](LAB.md). Install dependencies through [QUICKSTART.md](../QUICKSTART.md).

```powershell
..\.venv\Scripts\python.exe run.py demo
..\.venv\Scripts\python.exe run.py serve
```

Open **http://127.0.0.1:8212** for the working Risk Desk dashboard. It includes payment submission, a searchable decision ledger, original feature/release evidence, finalized analyst reviews, delayed simulator labels, and model comparisons. HTML/CSS/JavaScript are served by the same FastAPI process; SQLite persists decisions, labels, and reviews. No Node build or paid service is required.

### First browser workflow

1. Enter an event ID, entity ID, amount in minor units, currency, and event time. Select **Score payment**.
2. Retry unchanged to retrieve the same saved decision. Change the amount while keeping the ID to observe a conflict. Use **Prepare a new event ID** for a distinct transaction.
3. Select the ledger entry, inspect its score and saved features, then record an analyst review with a rationale. A review is final and does not label an event as fraud.
4. Record a simulator outcome with a future availability time. It remains pending and excluded from matured-label coverage until that time arrives; refresh after the deadline.
5. Restart the API and verify the ledger, review, and pending outcome persist.

Amounts are integer minor units: 5000 means 50.00 for the three supported lab currencies. The training fixture is USD only. EUR/INR submissions are unvalidated scenarios, with same-currency histories kept separate; there is no exchange-rate conversion or real payment processing.

Follow [ANALYST-WALKTHROUGH.md](ANALYST-WALKTHROUGH.md) for the what/why/how explanation and recall exercises. The API explorer remains at http://127.0.0.1:8212/docs. Submit this body to `POST /v1/risk-decisions`:

```json
{"event_id":"learner-1","entity_id":"customer-demo","amount_minor":5000,"currency":"USD","event_time":1700000200}
```

The returned score is advisory. `score_type` distinguishes a learned score from a heuristic rule; the latter is not a calibrated probability. Repeat the same body to receive the persisted decision. Change the amount while retaining the event ID to observe HTTP 409.

Submit a known event to `POST /v1/labels` with `event_id`, boolean `fraud`, and Unix timestamp `available_at`. `/v1/outcomes` counts only labels whose availability time has arrived; unknown outcomes are not negatives.

Training generates 1,800 timestamped events, computes causal history features, excludes labels unavailable at the training cutoff, and compares logistic regression against an amount rule using average precision. The default deterministic fixture rejects the weaker learned candidate. This is intended behavior, not a reason to bypass the gate.

```powershell
..\.venv\Scripts\python.exe run.py exercise
..\.venv\Scripts\python.exe run.py report
```

The exercise demonstrates idempotency, conflict rejection, and delayed feedback. Use `train`, then `promote --release ID`, or `rollback --release ID` for explicit model changes. Existing decisions remain immutable even after the active model changes.

For containers: `docker compose up --build -d`. Default host port: **8212**. The API uses local synthetic identities and has no production authentication or payment-provider integration.

## Verify the workflow

From the parent track folder:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
# Optional browser checks for both Risk Desk and Fleet Desk; installed Edge required.
.\.venv\Scripts\python.exe -m pip install -r requirements-browser.txt
.\.venv\Scripts\python.exe scripts/smoke_operator_ui.py
```

Browser tests use disposable databases and write results/screenshots into `../evidence/`. Keep the sibling `mlops_common` package when copying this project: it includes the shared dashboard assets and review transaction helper. See [VERIFICATION.md](../VERIFICATION.md) for what has actually been executed.
