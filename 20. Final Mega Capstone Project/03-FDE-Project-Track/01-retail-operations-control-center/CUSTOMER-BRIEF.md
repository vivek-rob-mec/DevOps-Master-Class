# Customer brief: a retail replenishment pilot

This is a fictional customer engagement with synthetic data. The following are explicit learning assumptions, not findings from real customer interviews.

## Problem and users

A regional retailer receives daily sales exports and a separate inventory sheet. Its planner manually combines them to estimate next week's purchases. When someone questions a recommendation, the team cannot reliably reconstruct which export, stock position, or forecast was used. Service reliability and platform cost are later concerns, but neither is useful until a complete customer workflow exists.

- **Planner:** imports a snapshot, checks projected demand, and approves or defers a recommendation.
- **Operations lead:** needs traceable decisions and an explanation when a job is delayed.
- **Customer IT:** owns exports, deployment, data quality, and recovery.
- **Field engineer:** translates the workflow into contracts, implements it, validates it with the customer, and documents handoff.

## Discovery questions and provisional answers

| Question to validate with a real customer | Pilot assumption | Consequence if wrong |
| --- | --- | --- |
| Do exports contain sales or unconstrained demand? | Observed sales | Stockouts can hide demand; forecasts must disclose this |
| Is inventory a current value or an end-of-day snapshot? | End of the final sales day | Recommendations are invalid if the dates do not align |
| Are zero-sales days included? | Yes, explicitly | Missing days fail validation rather than silently becoming zeros |
| Are transfers and inbound purchase orders included? | No | Planner must consider them before reviewing |
| What is the decision window? | Seven days, one warehouse | Multi-location allocation and supplier lead times require a revised design |
| Who may approve? | Named local lab reviewer | Real deployment needs identity, roles, and auditable authorization |
| Can an approved recommendation send an order? | No | Review records are evidence, not order execution |
| What infrastructure is available? | One 16 GB laptop; no cloud budget | Local API, worker, and SQLite first |

## Milestone 1 acceptance criteria

| ID | Demonstration | Evidence |
| --- | --- | --- |
| AC1 | Publish complete daily sales and matching inventory as one immutable snapshot | Import tests; UI snapshot ID |
| AC2 | Invalid rows leave the previously published snapshot unchanged | Parameterized atomic-import tests |
| AC3 | An identical retry does not duplicate work; a changed request using the same ID conflicts | Concurrency and receipt tests |
| AC4 | A separate worker completes a forecast; abandoned work can be reclaimed | Browser worker exercise and lease tests |
| AC5 | Planner sees forecast, inventory, safety buffer, recommendation, and backtest error | Browser evidence and exact fixture assertions |
| AC6 | Review retains original evidence; newer imports block decisions from stale browsers | Review tests and browser stale-import exercise |
| AC7 | Restarting the application retains published work and reviews | Database reopen test; walkthrough |
| AC8 | A second learner can explain and operate the workflow | Customer demo and learning-loop exercise; user acceptance still pending |

Technical checks do not establish customer value. A real pilot should separately measure planner time per review, review adoption, stockout rate, and inventory holding costs against an agreed baseline. Record definitions, observation periods, confounders, and who signs off. No savings or stockout improvement is claimed by this lab.

## Change request exercise

The customer adds: "We now have two warehouses and units arriving tomorrow." Before editing code, explain why adding two UI fields is insufficient. Revise the inventory identity, as-of rules, inbound order contract, replenishment policy, review target, acceptance tests, and migration plan. Capture the scope and tradeoff in a short decision record.
