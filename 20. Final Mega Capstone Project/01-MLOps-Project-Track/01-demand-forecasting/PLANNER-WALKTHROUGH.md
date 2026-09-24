# Build understanding by using Demand Desk

Start the project using [README.md](README.md), open http://127.0.0.1:8211, and keep [HLD.md](HLD.md) beside the browser. This lesson connects a visible user action to its system design.

## What, why, and how

| Component | What it does | Why it exists | Where to inspect |
|---|---|---|---|
| Frontend | Lists SKUs, draws forecasts, collects stock and review inputs | A planner needs a decision workflow, not just raw JSON | `frontend/index.html`, `styles.css`, `app.js` |
| API | Validates input, reads release evidence, calculates suggestions | The browser is not the authority for quantities or data consistency | `Project.api`, `planner`, `save_inventory`, `save_review` in `app.py` |
| SQLite | Retains batches, stock revisions, immutable decisions | Refreshing or restarting should not lose a planner's work | `state/application.db`; schema in LLD |
| Training job | Compares a bounded candidate with a seasonal baseline | Complexity must earn deployment through measured results | `Project.train` |
| Release artifacts | Preserve data, splits, model, policy, and evaluation | A forecast must be traceable to the exact evidence that produced it | `state/releases/RELEASE_ID/` |
| Batch pointer | Makes one complete forecast batch current | A failed write must not expose partial forecasts | `Project.forecast` and `current_batch` |

The frontend and backend are distinct responsibilities deployed in one process. A separate React service or microservice is not needed to learn these boundaries. SQLite is a real persistent relational database; PostgreSQL becomes a useful extension when studying concurrent users, managed operations, and database migrations.

## Exercise 1: follow one decision

1. Select `SKU-000`, expand daily forecast values, and sum the seven predictions. The headline rounds for display; calculate with the API values for an exact result.
2. Enter 20 units of stock and save. Before looking at the suggestion, calculate `max(0, ceil(total demand) + 2 - 20)`.
3. Open browser developer tools → Network. Save a review and inspect the POST payload. Explain why the request carries a batch ID and inventory revision but no authoritative order quantity.
4. Reload the page, then stop/restart the API. Show that stock and the review survive. Explain why JavaScript memory alone could not do this.
5. Change stock to a different quantity. Show that the old review still contains the previous stock snapshot. A past decision records what was known then.

## Exercise 2: reproduce a conflict

Open two tabs on the same SKU. Both initially read the same inventory revision. Save a new quantity in tab A, then try saving from tab B. Tab B receives 409 because its expected revision is old. Refresh it and reconsider the latest stock before retrying.

Explain the difference between preventing lost updates and preventing duplicate retries. The stock revision solves the former; the review request ID solves the latter. The automated tests include simultaneous requests, not only sequential happy paths.

## Exercise 3: distinguish a model from its published output

Use the README's `train` and `promote` commands without publishing another forecast. Refresh Demand Desk. It shows a model mismatch while retaining the published batch's history and evaluation. Now explicitly publish the forecast and refresh again.

Explain why an active model pointer, a published batch pointer, and an immutable review are three different records. A rollback changes the first; publishing changes the second; neither rewrites the third.

## Exercise 4: explain failure before adding infrastructure

Run `run.py exercise` and inspect the preserved batch. Read the stale-batch test in `../tests/test_forecast_planner.py`: approval is rejected after 24 hours, while deferral remains possible. The isolated browser smoke test also checks empty data, an API error, and recovery.

Do not change your system clock to test freshness. Test fixtures change only their disposable database timestamps. Re-running `demo` creates a fresh release/batch for normal learning; retrying an identical existing batch does not relabel it fresh.

## Remember through reconstruction

Keep one short learning note with: your prediction, the observed result, why they differed, and a diagram drawn from memory.

- **Tomorrow:** explain the browser → API → SQLite flow without opening code, then verify it.
- **After 3 days:** reproduce the two-tab conflict and explain the 409 response without notes.
- **After 7 days:** draw the release/batch/review relationships and calculate a recommendation for another SKU.
- **After 14 days:** explain why the baseline won, demonstrate failed-batch recovery, and identify the next production capability you would add and why.

Completion evidence: one screenshot, one saved review, one hand calculation, one conflict reproduction, one failed-batch result, and a two-minute explanation. These demonstrate a working local product; production identity, real retail ingestion, calibrated uncertainty, and cloud deployment remain separate milestones.
