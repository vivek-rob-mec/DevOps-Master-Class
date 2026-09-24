# Executed verification: local v1

Verified on the Windows workspace on 2026-09-12 using Python 3.14.6, scikit-learn 1.9.1, and the packages pinned in `requirements.lock`.

AIOps dashboard verification was completed on 2026-09-13 with the same environment. Earlier suite/container observations below retain their original scope; no cloud or container execution is implied by the new browser checks.

| Check | Observed result |
|---|---|
| `python -m pytest tests -q` | **57 passed** after adding Incident Desk; two dependency deprecation warnings |
| `python scripts/smoke_planner_ui.py` | Real headless Microsoft Edge passed product search, forecast rendering, inventory/review persistence, dirty-input guard, literal user text, mobile overflow, API error/recovery, stale-approval guard/deferral, and empty-state checks |
| `python scripts/smoke_operator_ui.py` | Real headless Edge passed Risk Desk scoring/retries/reviews/pending labels and Fleet Desk sensor warmup/warnings/reviews/uploads; both passed reload, search, mobile layout, API error/recovery, and empty-state checks |
| `python scripts/smoke_aiops_ui.py` | Real headless Edge passed fixture/incident deduplication, reviews/reload, search/filters, actual M1 HTTP 503 evidence, mobile layout, API recovery, retained evidence after telemetry expiry, and unavailable-detector behavior |
| `python scripts/run_suite.py` | All four training/demo commands and all four failure exercises passed |
| `python scripts/smoke_live.py` | All four actual loopback HTTP servers started, passed readiness/report/business checks, and stopped |
| Compose configuration | All four files passed `docker compose config --quiet` |
| Dependency consistency | Runtime packages use `requirements.lock`; optional Edge browser verification adds the separate `requirements-browser.txt` dependencies |

The tests cover artifact/evidence corruption, rejected releases, path validation, temporal leakage, batch atomicity, forecast freshness, concurrent idempotency, online/offline feature equality, late labels, sensor warmup/gaps, disconnected uploads, lost acknowledgements, spool backpressure, equipment-held-out splits, incident persistence, finalized reviews, and actual M1 API errors reaching AIOps.

Planner checks additionally cover additive schema upgrades, saved stock and decision snapshots surviving Project recreation, simultaneous inventory updates and review retries, stale batch/revision rejection, foreign browser Origin rejection, input limits, missing/corrupt evidence, and preserving published-release history/metrics after a different model is promoted. Browser checks run against a real temporary API/database; screenshots at `evidence/planner-desktop.png` and `evidence/planner-mobile.png` were visually inspected. The machine-readable browser result is `evidence/planner-browser.json`. Browser verification is optional and is not part of the existing container CI workflow.

Operator-desk checks cover concurrent review retries and finalization, concurrent conflicting labels, immutable review snapshots after restart, original decision releases after promotion, pending-label value/coverage handling, site-scoped equipment history, warmup/stale inspection rejection, spool/central counts, invalid input/foreign Origin rejection, additive schema creation, and readable ledgers when model evidence is corrupt. Browser results are in `evidence/operator-browser.json`; desktop/mobile screenshots use the `risk-desk-*` and `fleet-desk-*` prefixes. Screenshots were visually inspected. All new browser test data lives in disposable state directories, not the learner's application databases.

Incident Desk tests additionally cover no/insufficient telemetry, unmeasured HTTP queue disclosure, atomic concurrent fixture retries, finalized-review timestamps, source snapshots surviving telemetry removal, analysis history, original detector evidence after promotion, and additive legacy schema migration without invented timestamps. Browser evidence is in `evidence/aiops-browser.json` and `evidence/incident-desk-desktop.png` / `incident-desk-mobile.png`; both layouts were visually inspected. The real-HTTP browser scenario launches its own unprepared forecasting API and does not damage a working model or service.

## Model results on the fixed synthetic fixtures

| Project | Measured result | Interpretation |
|---|---|---|
| Forecasting | Candidate holdout MAE 1.5478; seasonal baseline MAE 1.4037 | Candidate passed validation but failed final acceptance; the baseline was selected |
| Payment risk | Selected amount-rule holdout average precision 0.8231; review rate 0.08 | Logistic candidate lost to the validation baseline and was not selected |
| Maintenance | Candidate held-out MAE 2.4013 cycles; age baseline MAE 15.7270 cycles | Candidate passed the equipment-held-out experiment on simulated histories |
| AIOps | Isolation Forest precision 0.9524, recall 1.0, 3 false alerts; rules precision/recall 1.0 with 0 false alerts | The simple thresholds performed better on these deliberately simple held-out fault fixtures |

These numbers describe the generated datasets and fixed evaluation procedures, not real business performance. Retaining the baseline or preferring rules can be the correct engineering outcome. Do not tune repeatedly against these final holdouts and then report them as untouched evidence.

`evidence/*-demo.json` contains full metrics and release metadata. `evidence/*-exercise.json` contains recovery results. `evidence/execution-summary.json` contains measured command durations. Runtime/source changes may alter measurements; rerun the suite and retain the corresponding artifacts.

## Remaining platform verification

Docker Engine was unavailable: the Docker CLI could parse Compose, but no daemon was listening. Container image builds, Linux container startup, and the GitHub Actions workflow have not been executed in this workspace. CI includes those checks once installed in a repository with a Docker-capable runner. Native tests do not establish container behavior.

The two test warnings come from Starlette's current HTTPX compatibility path and an AnyIO alias. Tests pass; the warnings are recorded rather than suppressed. Dependency upgrades should be reviewed and revalidated with the lockfile.

No production identity, external model registry, Kubernetes cluster, cloud account, physical edge device, private network link, or business dataset was exercised. These boundaries are documented in each `IMPLEMENTATION.md`.
