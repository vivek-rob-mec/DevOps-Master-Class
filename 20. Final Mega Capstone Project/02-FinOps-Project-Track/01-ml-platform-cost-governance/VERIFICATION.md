# Executed verification

Verified locally on Windows on 2026-09-13 using the existing MLOps virtual environment: Python 3.14.6 and the runtime dependency versions pinned by this project's `requirements.lock`.

| Check | Result |
|---|---|
| `python -m pytest tests -q` | 26 passed; two existing Starlette/AnyIO deprecation warnings |
| `python scripts/smoke_ui.py` | Real headless Microsoft Edge passed complete CSV publication, retries, invalid policy, exact budget, scenario review, reload, literal user text, mobile layout, invalid-import preservation, and API error/recovery |
| Visual inspection | Desktop and mobile screenshots inspected |
| Native startup | Cost Desk served on port 8215 with 85 cost rows, 56 usage rows, and the reconciled USD 325.750042 total |
| Compose configuration | `docker compose config --quiet` passed; Docker emitted warnings about access to the user's config file |
| Dependency consistency | Every version in the standalone runtime lock matches the existing verification environment |

Contract tests cover exact shared-cost conservation including negative credits, independently reconciled totals, usage denominator integrity, concurrent import/review retries, old import retries preserving newer active data, complete rejection of invalid imports, policy/budget revision conflicts, currency/month budget isolation, undefined zero-usage ratios, saved scenario evidence after restart, and API boundaries.

The browser uses its own real API and disposable database. Screenshots are `evidence/cost-desk-desktop.png` and `evidence/cost-desk-mobile.png`; the machine-readable result is `evidence/browser.json`. Test data does not overwrite working budgets or reviews.

The browser also verified that a scenario preview is rejected if the allocation policy changed after the displayed view was loaded; refresh restores a consistent basis for review.

Container builds/startup, the GitHub Actions workflow, a fresh standalone dependency installation, cloud billing connections, production identity, FX conversion, resource measurement, and realized savings have not been verified. The configured CI is supplied for a repository rooted at this project folder; it has not run from the nested course workspace.
