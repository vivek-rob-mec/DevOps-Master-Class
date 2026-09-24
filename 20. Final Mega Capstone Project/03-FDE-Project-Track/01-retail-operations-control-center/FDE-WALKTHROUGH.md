# FDE walkthrough: from customer export to decision

Read [CUSTOMER-BRIEF.md](CUSTOMER-BRIEF.md) first. For every exercise, write your predicted result before running it, then capture the actual result and explain any difference.

## 1. Start with the customer

Explain the problem in two sentences without naming a technology. List the planner, IT owner, and acceptance criteria. Draw the [HLD](HLD.md) from memory. Explain why this first milestone uses two processes but only one application/database boundary.

Use the [README startup commands](README.md#run-locally-on-windows) to start only the API initially. Open http://127.0.0.1:8216. The empty dashboard should not invent healthy services, forecasts, or business savings.

## 2. Connect and validate

Click **Load simulated ERP export**. Inspect the headers and a few rows. The endpoint supplies fixture CSVs, just as an adapter could supply a customer export, but no real ERP is connected.

Predict: how many sales rows should 3 products × 35 days contain? Publish the snapshot. Confirm 3 / 35 and a through-date of 2026-09-04. Copy the snapshot hash into your learning log.

Click **Validate and publish snapshot** again without edits. Confirm the same snapshot remains current. Explain why a content hash and a request ID solve different problems: the former identifies parsed data; the latter identifies a retried operation.

Remove an interior day's row, then publish. Expect rejection and the previous snapshot to remain current. Reload the sample to recover. Repeat with a duplicate row and a negative quantity. Do not turn missing days into zeros without a customer contract.

## 3. Observe the queue

Click **Queue forecast** while the worker is stopped. Refresh and confirm `queued`. Approval stays disabled. Restart the API and refresh again: the queued work remains because it lives in SQLite.

In a second terminal, process exactly one job:

```powershell
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' app.py worker --once
```

Refresh and confirm `succeeded` with one attempt. For continuous processing, run `app.py worker` without `--once`.

Read `claim` and `finish` in `app.py`. Explain why computation occurs outside a write transaction and why a token alone is insufficient without checking lease expiry. Use the focused failure tests to observe deterministic crash recovery rather than trying to stop a calculation that completes almost instantly:

```powershell
& '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' -m pytest tests -q -k 'worker or crashed'
```

The tests use disposable state. They do not kill your live worker or corrupt its database.

## 4. Explain the forecast

For Coffee, the final observed week is `14,16,18,20,22,24,26`: total 140. The same-weekday baseline repeats those values for the next seven days.

`max(0, 140 + 10 - 35) = 115 suggested units`

The previous week's values are each one unit lower, so the seven-day backtest MAE is 1. Explain why that does not prove the next week will have MAE 1, and why observed sales may understate demand during stockouts.

Inventory represents the end of the final sales day. The UI labels the bundled data as historical. This is a replay exercise, not a current purchasing instruction. Inspect the full daily output through `/v1/desk` → `current_job.result.items`.

## 5. Make and preserve a decision

Choose Coffee, enter your name, and explain whether incoming deliveries or promotions might change the recommendation. Approve or defer, then save. Reload the page. The ledger and saved form values should remain. Approval does not send an order.

Change `COFFEE,35,10` to `COFFEE,45,10` in a newly loaded inventory export. Publish and forecast again. Predict 105 suggested units. The previous review must still contain 115 because it records the original evidence.

## 6. Reproduce a stale browser

Use two tabs on the same successful snapshot. In tab A, choose an unreviewed product. In tab B, load the sample, change inventory, and publish. Without refreshing A, try saving its review. Expect a superseded-snapshot conflict. Refresh A, queue/process the current forecast, and make a new decision using that result.

Explain why a UI-only disabled button cannot enforce this rule: another tab or direct API client can change the state between display and submission.

## 7. Inspect persistence and rehearse a backup

Read the database with Python's SQLite module. These queries are read-only:

```powershell
@'
import sqlite3
with sqlite3.connect('state/retail.db') as db:
    print('Batches:', db.execute('SELECT count(*) FROM batches').fetchone()[0])
    print('Jobs:', db.execute('SELECT state,attempts FROM jobs').fetchall())
    print('Reviews:', db.execute('SELECT count(*) FROM reviews').fetchone()[0])
'@ | & '../../01-MLOps-Project-Track/.venv/Scripts/python.exe' -
```

For a backup exercise, create a new backup file through SQLite's backup API. Do not copy only a live `retail.db` while ignoring its WAL. Restore into a separate directory, set `STATE_DIR` to that directory, start a second API on port 8316, and compare snapshot IDs, job states, and reviews. Keep the original database untouched. This is a learner exercise; a production backup/restore service is not implemented or claimed as verified.

## 8. Customer handoff demo

Give a five-minute demo: state the customer problem, load data, explain a recommendation, show one rejection/recovery case, and name the remaining limitations. Have another learner operate it using only the README. Record which steps required your help; improve those instructions before claiming successful handoff.

Deliverables: a completed acceptance table, a screenshot of your review, a failed-import example, a revised diagram, and a one-page decision record for adding a second warehouse. Continue with [LEARNING-LOOP.md](LEARNING-LOOP.md).
