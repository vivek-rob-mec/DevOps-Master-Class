# Forward Deployed Engineering project track

Build a customer solution, explain the tradeoffs, and leave another person able to operate it. This track follows the [MLOps and AIOps applications](../01-MLOps-Project-Track/README.md) and [FinOps application](../02-FinOps-Project-Track/README.md).

Start with [Retail Operations Control Center](01-retail-operations-control-center/README.md). Milestone 1 is implemented: customer export → validated snapshot → durable forecast job → replenishment review. It includes a browser UI, FastAPI backend, SQLite database, separate worker, system designs, and failure exercises. No cloud account is required.

| Milestone | Customer outcome | Status |
| --- | --- | --- |
| 1. Deliver a complete workflow | A planner can import data and record an evidence-backed replenishment decision | Implemented locally |
| 2. Integrate a trained forecasting service | Customer data can be scored against a versioned model with an explicit data contract | Planned; current baseline is local |
| 3. Operational visibility | Service telemetry feeds Incident Desk; the customer sees unavailable or degraded dependencies | Planned |
| 4. Cost and value | Actual usage feeds Cost Desk; costs and business outcomes remain separately measured | Planned |
| 5. Customer handoff | Authentication, environment promotion, restore rehearsal, acceptance and onboarding | Local walkthrough implemented; production controls remain planned |

Read the customer brief before the architecture. Complete each milestone's acceptance checks before adding infrastructure. On a 16 GB laptop, run this API and worker first; start sibling applications only when implementing their integrations.

Use the [learning loop](01-retail-operations-control-center/LEARNING-LOOP.md) to predict behavior, test it, explain it, and repeat the exercise later without the guide.
