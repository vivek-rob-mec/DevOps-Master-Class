# Incident Desk: full-stack AIOps learning project

This project follows the three MLOps applications and reads their shared telemetry. It trains a real Isolation Forest on healthy fixture windows, compares it with static thresholds, records incidents, and proposes investigation steps. Human review is stored as evidence; approval never executes a command.

Read [HLD.md](HLD.md), [LLD.md](LLD.md), [IMPLEMENTATION.md](IMPLEMENTATION.md), and [LAB.md](LAB.md). Shared setup: [QUICKSTART.md](../QUICKSTART.md).

```powershell
..\.venv\Scripts\python.exe run.py demo
..\.venv\Scripts\python.exe run.py exercise
..\.venv\Scripts\python.exe run.py serve
```

Open **http://127.0.0.1:8214** for Incident Desk. It provides service-window cards, a searchable incident inbox, saved source-event evidence, competing hypotheses, human reviews, completed analysis history, and detector comparisons. The frontend uses local HTML/CSS/JavaScript served by FastAPI; SQLite persists incidents and reviews. There is no Node build or paid API dependency.

The `exercise` command above is optional: it writes labeled telemetry fixtures and demonstrates a review. You can instead use the dashboard's fixture form to build your first incident step by step. The API explorer remains at http://127.0.0.1:8214/docs.

## First browser workflow

1. Inspect **Current 60-second windows**. A service needs at least five HTTP/fixture samples to be eligible for analysis. No recent samples means insufficient observation, not healthy or down.
2. Choose a service and scenario under **Replay a labeled signal**, then select **Add labeled fixture**. This writes ten tagged samples without calling or changing that service. Retrying unchanged reuses the same replay; **Prepare a new replay** creates a distinct request.
3. Select **Analyze current windows**. Inspect the incident's threshold values, detector flags, competing hypotheses, and exact saved source events.
4. Approve or reject the investigation proposal with a rationale. Reload or restart the API: the review persists and cannot be overwritten. Approval does not execute a command or mark an outage resolved.
5. After the window expires, refresh. Current samples disappear while the incident evidence remains. New incidents preserve full event snapshots; older incidents explicitly identify missing historical details.

Follow [TRIAGE-WALKTHROUGH.md](TRIAGE-WALKTHROUGH.md) for the what/why/how explanation, live telemetry exercise, and recall checkpoints.

Real HTTP requests to the MLOps services automatically write telemetry. AIOps examines the last 60 seconds and requires at least five request/fixture records for a service. `/v1/windows` shows the exact features. `/v1/incidents` retains older findings after the window expires. Rerun the exercise to create fresh fixture evidence.

For `POST /v1/incidents/{id}/review`, use:

```json
{"decision":"approved","reviewer":"local-learner","reason":"Reviewed the evidence and will investigate manually."}
```

The response includes `executed: false`. A finalized review cannot be silently replaced. Hypotheses such as a release regression are correlations with referenced evidence, not proven root causes.

All native projects default to `../state/telemetry.db`; all Compose projects share `mlops-track-telemetry`. The two storage modes are separate. For containers: `docker compose up --build -d`. Default host port: **8214**.

The baseline is synthetic and shared across the demonstration services. Calibrating service-specific real baselines, suppression/grouping across adjacent incident windows, distributed telemetry ingestion, authentication, and an approved remediation executor are later extensions. Continue to the working [FinOps track](../../02-FinOps-Project-Track/README.md) next; the FDE track remains future work.

## Verify

From the parent track folder:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q
# Optional real browser verification; installed Microsoft Edge required.
.\.venv\Scripts\python.exe -m pip install -r requirements-browser.txt
.\.venv\Scripts\python.exe scripts/smoke_aiops_ui.py
```

The browser script uses disposable databases and a separate unprepared M1 API to generate actual HTTP 503 evidence. It does not alter your running applications. Results and desktop/mobile screenshots are saved in `../evidence/`. Keep the sibling `mlops_common` package when copying the project; its shared web assets are included by the Dockerfile. See [VERIFICATION.md](../VERIFICATION.md) for executed results and container limitations.
