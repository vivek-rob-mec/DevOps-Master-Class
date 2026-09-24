# Lab: distinguish a useful alert from a causal claim

1. **Design first.** Draw telemetry -> window features -> detector/rules -> incident -> review. Explain which signals are measured and which are unavailable. Identify why approval must not imply an unreviewed infrastructure action.
2. **Train and compare.** Run `..\.venv\Scripts\python.exe run.py demo`. Compare Isolation Forest and static-rule precision/recall/false alerts on the held-out fixtures. Explain how fitting on fault-labeled evaluation windows would contaminate the experiment.
3. **Replay a fault.** Run `run.py exercise`, then `run.py serve`. Inspect `/v1/windows` and `/v1/incidents`. Locate the fixture marker and referenced release-event IDs. Explain why the observed correlation suggests investigation but does not establish root cause.
4. **Observe live input.** Generate at least five business HTTP requests against a native MLOps API, then call `/v1/analyze` within 60 seconds. Inspect its window even if it causes no alert. The integration test `test_aiops_consumes_actual_http_telemetry` demonstrates actual 503 responses being detected without fixture telemetry.
5. **Review and retain.** Approve or reject a pending incident in `/docs`. Verify `executed: false`. Repeat the identical review, then attempt a conflicting review. Explain why an incident remains stored after the original window expires.
6. **Challenge the detector.** Explain how a different healthy service latency could trigger a false alert with the synthetic baseline. Propose a service-specific baseline, suppression policy, and evaluation dataset before adding them. Distinguish missing telemetry from a healthy service.

Deliver: rule/model comparison, one incident's evidence chain, competing hypotheses, rejected explanations, review evidence, and a plan to measure false alerts on real traffic. Delayed review: change one signal and predict which hypothesis is still supported.

Continue with [TRIAGE-WALKTHROUGH.md](TRIAGE-WALKTHROUGH.md) in the working Incident Desk dashboard. It adds labeled replay retries, source snapshots, observation states, live HTTP integration, review persistence, and recall checkpoints after 1, 3, 7, and 14 days.
