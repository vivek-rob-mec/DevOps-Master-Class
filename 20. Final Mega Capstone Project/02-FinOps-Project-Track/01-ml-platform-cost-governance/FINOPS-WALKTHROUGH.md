# Learn FinOps by operating Cost Desk

Start with the [README](README.md) and open http://127.0.0.1:8215. Keep the [HLD](HLD.md) and [LLD](LLD.md) beside the application.

## What, why, and how

| Component | What it does | Why it matters | Implementation |
|---|---|---|---|
| Import validator | Checks both billing and usage inputs before publication | Partial or mismatched data can mislead every downstream metric | `validate_snapshot`, `Project.ingest` in `app.py` |
| Billing snapshot | Preserves a complete input version | A saved decision needs an identifiable cost basis | `batches`, `imports`, `current_batch` |
| Allocation policy | Distributes shared costs without losing micro-units | Owners need a reconciled showback, not unexplained rounding loss | `split_money`, `policies` |
| Budget and forecast | Compares a declared plan with an extrapolated estimate | A budget is a decision; a forecast is an expectation under assumptions | `Project.budget`, `Project.calculate` |
| Usage denominator | Counts successful work independently from billing lines | More cost rows must not pretend to be more business value | Separate usage CSV and service catalog |
| Scenario review | Saves a hypothesis and checks needed before action | Estimated savings and realized outcomes are different evidence | `Project.scenario`, `Project.review` |

## Exercise 1: reconcile before optimizing

Open the bundled cost CSV. Add positive charges and the negative credit: the result is USD 325.750042. Find USD 7.00 of unallocated cost. Confirm that the four team totals plus this bucket equal the complete net total.

Calculate the allocation of one shared charge, USD 2.000003, under 40%/30%/20%/10% weights. Convert it to 2,000,003 micro-units first. Explain how largest remainders distribute the final micro-units and why the same process works for a credit with its sign restored.

Change the policy to 25% per team, expressed as 2,500 basis points each. Team totals change; provider totals and the total bill do not. Explain why spreading unallocated costs without an ownership decision would hide a data-quality problem.

## Exercise 2: budget is not forecast

Set a retail budget of 100.000001. Reload the browser and show that the exact value persists. Calculate the retail month-end forecast using its current allocated total × 31 / 14. Compare it with the budget and explain the variance sign.

Discuss what would make the linear forecast wrong: missing billing days, rising workload, one-time credits, changing rates, commitments, or a seasonal event. Required usage rows do not prove cost-export completeness. The forecast's precision does not make its assumptions more reliable.

Open two tabs with the same budget revision. Save a new budget in the first tab, then try saving from the second. It receives 409 instead of overwriting the newer plan. Refresh and reassess. Repeat with an allocation-policy change.

## Exercise 3: use a meaningful denominator

Find the demand-forecasting service's 15,050 successful forecasts. Divide its allocated cost by this count. Explain why this count comes from usage rows, not the number of cost lines or a sum repeated for every provider.

In a copy of the sample usage file, set every demand-forecasting count to zero while retaining the rows. Import both files as a new complete snapshot. The unit cost becomes undefined, not zero and not infinity. Reload the original sample to restore the fixture through an explicit new publication.

Explain why a payment transaction and a reviewed incident are different units. A lower cost per request is useful only if the definition of success and service quality remain meaningful.

## Exercise 4: challenge an optimization hypothesis

Calculate a 20% compute reduction for retail. The bundled fixture has USD 52.50 of observed direct compute cost, so the hypothetical monthly savings are `52.50 × 0.20 × 31 / 14 = USD 23.25`.

Record an approval or rejection with checks needed: throughput, latency, forecast quality, queue recovery, implementation effort, and rate/commitment assumptions. Saving approval does not change resources. A cost estimate cannot establish realized savings.

Calculate a preview in tab A. Change the allocation policy in tab B, then try saving tab A's review. Its stale basis is rejected. Refresh and calculate again. A previously saved review remains unchanged and can be traced to its old billing snapshot and policy revision.

## Exercise 5: prove ingestion recovery

Change a CSV header or repeat a usage row. Attempt publication and inspect the validation error. The current billing ID and totals must remain unchanged. Explain why validation happens before the transaction that changes the active pointer.

Repeat an unchanged successful import and observe its stable billing ID. The automated tests also retry an older import after a newer currency snapshot is active, proving that a delayed retry cannot roll the active view backward.

Never combine USD and EUR values by adding them directly. A real consolidated view requires an explicit FX source, date, conversion policy, and audit trail; this project deliberately enforces one currency per snapshot.

## Retain the concepts

- **Tomorrow:** draw CSV → validation → immutable snapshot → allocation → budget/unit metrics → reviewed scenario from memory.
- **Day 3:** calculate a signed shared charge and explain a budget revision conflict.
- **Day 7:** break an import, recover, and explain why unknown cost ownership and zero successful work are separate problems.
- **Day 14:** explain estimated versus actual cost, forecast versus budget, and hypothetical versus measured savings without opening notes.

Deliver a reconciliation calculation, one scope-aware budget, a zero-denominator example, one rejected import, a reviewed savings hypothesis, and a two-minute explanation. Then take one completed application into an FDE-style customer pilot: discover the requirement, integrate a source, agree on acceptance evidence, and prepare handover.
