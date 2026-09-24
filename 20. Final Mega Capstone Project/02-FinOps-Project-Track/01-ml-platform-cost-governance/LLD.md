# LLD: exact imports, allocation, budgets, and reviews

## Data contracts

Cost rows have unique `cost_id`, canonical ISO date, provider, service, team, category, amount, and currency. Allowed provider labels are `aws`, `azure`, `gcp`, `onprem`. Categories are `compute`, `storage`, `network`, `credit`. Credit amounts are nonpositive; other categories are nonnegative.

| Service | Direct team | Successful unit |
|---|---|---|
| demand-forecasting | retail | forecasts |
| payment-risk | risk | transactions |
| predictive-maintenance | operations | sensor_readings |
| aiops-triage | platform | reviewed_incidents |

`shared-platform` charges use team `shared`; missing ownership uses team `unallocated`, with service `unattributed` or a catalog service. Direct team/service pairs must match the catalog. Shared costs are allocated to teams; unallocated costs are not silently spread over known owners.

Usage is unique by `(date,service)` and must include all four services for every covered day. `successful_units` is a nonnegative integer, at most 1,000,000,000 per row. Its unit must match the service catalog. Separate rows across provider cost lines do not create extra denominators.

CSV headers and order are exact; malformed counts, duplicate keys, wrong units, mixed currencies, invalid dates, and missing usage rows reject the whole import. Both files are limited to 1,000 rows; request strings are capped at 500,000 cost CSV characters and 300,000 usage CSV characters. `through_day` must be valid for the declared month. The API's `data_kind` accepts only `synthetic` and defaults to it; this declaration is not independent proof of data origin.

## SQLite records

| Table | Fields |
|---|---|
| batches | `id PK, snapshot JSON, created` |
| current_batch | `slot PK, id` |
| imports | `id PK, payload_hash, response JSON` |
| policies | `revision PK, weights JSON, created` |
| budgets | `period,currency,team,amount,revision`; composite PK period/currency/team |
| reviews | `id PK,payload_hash,snapshot JSON,created` |

Snapshot ID is SHA-256 of canonical validated/sorted data and period/currency/coverage metadata. Import receipts key the caller's request ID. Validation precedes the write transaction. `BEGIN IMMEDIATE` then checks the receipt, inserts the immutable batch if needed, updates the active pointer, and writes the receipt in one commit. An identical receipt retry returns its earlier response without changing the active pointer; conflicting reuse returns 409.

## Arithmetic

Amounts use plain decimal input, with six fractional digits maximum. Decimal parsing converts to integer micro-units: `1.000003 -> 1000003`. A row's magnitude is limited to 1,000,000 currency units and absolute snapshot charges to 10,000,000. This also keeps bounded dashboard integer totals inside JavaScript's exact integer range.

For each shared charge, multiply the absolute micro-unit amount by each team's basis-point weight. Divide by 10,000, retaining integer floors and remainders. Distribute the remaining micro-units in descending remainder order, breaking ties by team name, then restore the charge's sign. The allocated shares sum exactly to the original positive charge or credit.

Weights must sum to 10,000. The initial policy is retail 4,000; risk 3,000; operations 2,000; platform 1,000. New policies append a revision after checking the caller's expected current revision. Earlier versions remain stored.

```text
net_total = sum(all signed cost rows)
net_total = sum(team allocated totals) + unallocated
coverage = assigned positive charges / all positive charges
projected_month = observed_net * calendar_days_in_month / declared_covered_days
budget_variance = projected_team_cost - saved_team_budget
cost_per_successful_unit = allocated_team_cost / service_successful_units
```

Coverage excludes credits from both numerator and denominator and is undefined when positive charges are zero. Unit cost is undefined for zero successful units, returned as JSON null. Unit cost is a decimal string rounded to eight places. Projections use Decimal round-half-up to integer micro-units; separately rounded team projections need not sum to the independently rounded total projection.

The simple forecast implicitly repeats the observed cost mix, including any one-off credits. Its limitation must be considered before using the estimate for planning. Billing completeness is an importer assertion; required usage rows do not prove billing-source completeness.

## API and concurrency

| Route | Contract |
|---|---|
| `GET /v1/desk` | Active snapshot, policy, costs, usage ratios, scoped budgets, daily/provider totals, latest 30 reviews; empty batch is valid |
| `GET /v1/sample` | Deterministic synthetic CSV payload |
| `POST /v1/imports` | `{request_id,period,currency,through_day,cost_csv,usage_csv,data_kind?}`; invalid input 422, conflicting retry 409 |
| `POST /v1/policy` | `{revision,retail,risk,operations,platform}` integer basis points; wrong total 422, stale revision 409 |
| `POST /v1/budgets` | `{batch_id,team,amount_micro,revision}`; stale batch/revision 409; missing budget starts revision 0 |
| `GET /v1/scenario?team=retail&reduction_percent=20` | Current computed hypothesis for 0–50% compute reduction |
| `POST /v1/reviews` | `{request_id,batch_id,policy_revision,team,reduction_percent,decision,reviewer,reason}` |
| `/healthz`, `/readyz` | Process health and database/schema access; a billing snapshot is not required for readiness |

Budgets use integers from 0 to 1,000,000,000,000 micro-units. Currency and period come from the current batch, not caller-supplied scope. Browser budget input converts decimal text with BigInt before submitting an exact safe integer. Reviews accept `approved` or `rejected`, reviewer 1–80 trimmed characters, and rationale 5–1,000 trimmed characters. Extra fields are rejected.

Scenario monthly savings = observed allocated compute cost × assumed reduction fraction × month days / covered days. The server recomputes this; user-supplied savings are rejected as an extra field. Review finalization checks active batch and policy, then persists the request, computed scenario, currency, source IDs, timestamp, and assumptions. Same request/payload returns the original saved review even after active data changes; different reuse returns 409. Multiple distinct scenario reviews are permitted.

`executed=false` and `measured_savings=false` are persisted in the scenario. An approval is a hypothesis review, not an infrastructure action. Foreign browser Origin POST requests are rejected. There is no production identity or authorization layer.
