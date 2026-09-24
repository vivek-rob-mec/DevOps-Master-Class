# Verification record

Verified locally on Windows on 2026-09-14, using Python 3.14.6 and the existing MLOps virtual environment. Every installed package named in `requirements.lock` matched its locked version. A fresh-environment install was not performed.

## Executed checks

| Check | Result |
| --- | --- |
| `python -m pytest tests -q` | **22 passed**; two dependency deprecation warnings concerning Starlette/httpx and AnyIO |
| `python scripts/smoke_ui.py` | Passed against installed Microsoft Edge, real HTTP API, separate worker process, and temporary SQLite database |
| Desktop and mobile screenshots | Inspected; 390px viewport has no document-wide horizontal overflow; wide tables scroll within their panel |
| `python app.py demo` | Published 105 rows / three SKUs / 35 days and completed the baseline forecast |
| `docker compose config --quiet` | Parsed successfully; Docker reported that the user's config file was not readable in this environment |
| Local Markdown links | Checked, including the track and project entry points |

The backend suite exercises exact sample calculations, temporal isolation, concurrent imports/queue claims/reviews, changed-payload conflicts, atomic rejection of ten invalid CSV cases, old-import retry behavior, worker lease recovery and fencing, retry exhaustion, stale/expired reviews, persistence after reopening the database, API schemas/origin guard, and current-job retrieval beyond the recent-history limit.

The browser suite covers empty state, simulated ERP loading, publication and retry, queued-to-completed work, visible forecast evidence, saved review persistence, literal user text, responsive layout, invalid-import recovery, a stale decision after another client's import, and API error/recovery. It shuts down its isolated server through a local test-only file signal; no HTTP shutdown route is exposed. Screenshots and `evidence/browser.json` are generated artifacts and are gitignored.

## Not established by these checks

Container build/run, CI execution, fresh dependency installation, production load, live ERP integration, cloud deployment, model-service integration, AIOps/FinOps telemetry integration, production backup/restore, authentication, and real customer acceptance are unverified or unimplemented as described in the design. The documentation's backup/restore exercise is for the learner to execute; it is not reported as completed here.

Synthetic forecasts and the backtest do not establish reduced stockouts, saved planner time, or financial savings. The baseline is not a trained model. Review approval does not place orders.
