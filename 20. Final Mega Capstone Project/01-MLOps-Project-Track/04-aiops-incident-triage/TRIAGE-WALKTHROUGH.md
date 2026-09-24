# Learn AIOps by investigating Incident Desk

Start the application with [README.md](README.md), then open http://127.0.0.1:8214. Read the [HLD](HLD.md) and [LLD](LLD.md) beside the browser. The objective is to explain an incident's evidence and make a defensible review decision.

## What, why, and how

| Component | What it does | Why it exists | Where to inspect |
|---|---|---|---|
| Service middleware | Records actual HTTP latency and server-error indicators | Detection needs observations from running applications | `../mlops_common/runtime.py`, shared `events` table |
| Window builder | Computes per-service means and queue maximum over 60 seconds, with at least five samples | A detector needs a defined observation period and minimum coverage | `Project.telemetry()` and `Project.windows()` in `app.py` |
| Rules and ML | Compare explicit thresholds with an Isolation Forest trained on healthy fixtures | Complexity should be evaluated against an understandable baseline | `rule()`, `Project.train()`, detector evidence panel |
| Incident ledger | Saves the supporting events, detector version, and hypotheses | Later telemetry changes must not rewrite the basis of a human decision | `incidents`, `Project.analyze()` |
| Review | Finalizes approval or rejection with a rationale | Human judgment needs a durable record | `Project.review()`, review form |
| Labeled replay | Adds bounded simulated observations | You can reproduce detection behavior without breaking a working service | `Project.fixture()`, `aiops_fixture_runs` |

One FastAPI process serves the frontend and API. The shared telemetry database is separate from the AIOps incident database. The fixture receipt belongs in the telemetry database so writing its samples and recording its identity can be one transaction.

## Exercise 1: observation is not health

Open the dashboard before generating traffic. Explain why **No recent samples** does not mean healthy, down, or zero errors. Select Analyze with no eligible windows and inspect the completed run with zero findings.

Predict the three features for the latency/error fixture: 250 ms mean latency, error fraction 1, queue 2. Those are fixture values, not measurements from the named service. The static latency/error thresholds should trigger if that is the only sample set in the window.

Add the fixture, then Analyze. Compare your prediction with the evidence. If the actual vector differs, inspect the HTTP/fixture counts: windows combine existing observations with the new replay. Adding healthy samples does not delete faults.

## Exercise 2: trace an incident

Select an incident and explain:

1. Which service and event IDs supplied the samples?
2. Which thresholds crossed, and did the ML detector agree?
3. Does the release marker represent a real activation or a labeled fixture?
4. Which hypotheses fit the evidence, and what additional check would distinguish them?
5. Why is a release near an error spike insufficient to prove a release regression?

Expand the source snapshots. New incidents preserve these records even when the current window expires. Older incidents disclose when complete snapshots were never stored. Do not fill gaps in the evidence with invented details.

## Exercise 3: retry and review

Repeat Add labeled fixture without changing its fields or preparing a new replay. The same receipt is returned and sample counts do not increase. Repeat Analyze while the evidence boundaries stay unchanged: it returns the same incident ID, though another completed run is recorded.

Reject or approve the proposal with a reason that names an observation and a next check. Reload the page and verify the saved values. Try a conflicting review from another tab that was open before finalization. Explain the 409 response and why the original timestamp remains unchanged on an identical retry.

Neither approval nor rejection executes a command or resolves an outage. The application records a proposal review. A later production executor would require its own identity, authorization, rollback, and outcome checks.

## Exercise 4: connect real MLOps traffic

Start the forecasting API on port 8211 using its README. In PowerShell, send five read requests:

```powershell
1..5 | ForEach-Object { Invoke-RestMethod http://127.0.0.1:8211/report | Out-Null }
```

Within 60 seconds, refresh Incident Desk and Analyze. Find the forecasting window and inspect the HTTP sample count. Successful traffic need not create an incident; an alert against the synthetic baseline can also be a false alarm. Health/readiness probes are excluded, so repeatedly requesting `/healthz` is not a substitute for this exercise.

For a reproducible real-error demonstration, run `../scripts/smoke_aiops_ui.py` from the track root using the virtual environment. It creates a separate, disposable forecasting API with no model, receives actual HTTP 503 responses from `/report`, and proves the AIOps dashboard consumes those events. Your running applications and working data are not changed.

Native services must share the same `TELEMETRY_DB`. Defaults use the track's `state/telemetry.db`; Compose uses its named telemetry volume. Native and container telemetry are separate unless you deliberately configure them to share storage.

## Exercise 5: preserve and challenge evidence

Wait for the 60-second window to expire, refresh, and show that the incident remains. Compare the static rules' false-alert count with Isolation Forest on the fixed holdout. Explain why a more sophisticated model can be the weaker result.

Read the tests for missing/corrupt detector evidence, source removal, legacy schema migration, and concurrent fixture/review retries in `../tests/test_aiops_desk.py`. Explain why the ledger should remain inspectable during a detector outage. Do not delete your working telemetry or corrupt your working model to reproduce these tests; their fixtures are isolated.

## Retain the reasoning

- **Tomorrow:** draw HTTP events → window → detector/rules → incident → human review without notes.
- **Day 3:** calculate one fixture window and explain a retry's effect on its sample count.
- **Day 7:** trace one incident to source IDs, distinguish observation from hypothesis, and explain what evidence is missing.
- **Day 14:** compare batch MLOps, online scoring, edge inference, and AIOps; explain what each application's database must preserve.

Deliver one evidence diagram, one hand calculation, one saved review, one real-HTTP window, and a two-minute explanation. The next track is FinOps: measure resource usage and attribute costs while keeping local estimates separate from actual cloud bills.
