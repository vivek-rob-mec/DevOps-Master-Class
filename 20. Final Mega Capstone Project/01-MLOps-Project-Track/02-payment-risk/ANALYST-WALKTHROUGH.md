# Learn online ML by operating Risk Desk

Start with the [README](README.md), then open http://127.0.0.1:8212. Keep the [HLD](HLD.md) and [implemented LLD contracts](LLD.md#implemented-risk-desk-contracts) beside the application.

## What you are building, why, and how

| Responsibility | What it does | Why it matters | Implementation |
|---|---|---|---|
| Browser | Submits a simulated payment and presents the analyst queue | A user needs context and a review workflow around a model score | `frontend/index.html`, `frontend/app.js` |
| Online feature builder | Reconstructs prior same-entity, same-currency activity available at the decision cutoff | Future or late-arriving information must not leak into past decisions | `features()` in `app.py` |
| Scoring API | Binds features, model, and threshold to one saved result | Retrying an event must not silently produce another decision | `Project.score()` and the `decisions` table |
| Analyst review | Saves a human decision and rationale against the scored event | Human judgment needs an auditable record independent of the ML prediction | `RiskReview`, `/v1/risk-reviews`, `operator_reviews` |
| Delayed label store | Records when an outcome becomes available | An unknown outcome is not a legitimate transaction | `Project.label()`, `labels`, `Project.outcomes()` |
| Release evidence | Separates the active model from the one used by an older event | A later promotion must not rewrite the explanation for a past decision | Original release in the detail panel; active evidence panel |

This is a local modular application: frontend and backend responsibilities share one deployment process. SQLite serializes short writes. Distributed inference reservations, production identity, external fraud feeds, and feature caches remain later extensions.

## Exercise 1: predict a rule score

1. Inspect the active method. If it is `amount_rule`, calculate `amount_minor / (amount_minor + 5000)` for 8000 minor units before submitting.
2. Score that simulated USD payment. Compare your result with the displayed score and the original release's threshold.
3. Explain why 0.6154 from this heuristic does **not** establish a 61.54% probability of fraud.
4. Read the saved feature vector. Which values are history counts? Which depend on amount? Explain why a different currency does not share the same amount history and why USD training does not validate EUR/INR scoring.

## Exercise 2: retries, conflicts, and human judgment

1. Submit the unchanged event again. Confirm the total scored-event count stays unchanged and the original release ID remains the same.
2. Change the amount while keeping the event ID. Observe 409. Explain why overwriting the earlier event would damage auditability.
3. Record `escalate` with a short rationale. Reload the page. Show that the analyst review survived.
4. Observe that the event's label is still unknown. A suspicious score and an analyst escalation are not observed fraud truth.
5. Try to review the finalized record from a second tab loaded before the first review. The API rejects a second finalization. Refresh to inspect the saved review.

## Exercise 3: learn the two clocks

Draw a line with event time, API receipt time, label availability time, and training cutoff.

Set a simulator label's availability a few minutes in the future. Save it and show that the UI says pending while matured-label coverage remains unchanged. Wait until the declared time, refresh, and show the transition to matured. Do not change the system clock. The automated tests use disposable fixtures for fast checks.

Explain why future availability is useful in a simulator, why a real label source needs trustworthy timestamps, and why review selection can bias observed labels. Label coverage is not accuracy. The UI does not automatically retrain the fixed synthetic training pipeline from these labels.

## Exercise 4: trace and recover

Use `run.py train`, inspect the new release, then `run.py promote --release ID`. Refresh the desk: the active evidence changes, while your existing event still points to its original release. Score a new ID and compare.

Run `run.py exercise` for the duplicate/conflict/delayed-feedback demonstration. Read `test_risk_review_concurrent_retry_finalization_and_restart` in `../tests/test_operator_desks.py`: explain the unique event target, request ID, canonical payload hash, and `BEGIN IMMEDIATE` transaction in your own words.

## Retain the concepts

- **Next day:** calculate a rule score and draw the decision/label timeline without notes.
- **Day 3:** reproduce duplicate and conflicting requests; explain their different responses.
- **Day 7:** reconstruct one saved feature vector and explain a late-arriving event's effect on later decisions.
- **Day 14:** demonstrate promotion without rewriting history, and explain when you would add a cache, authentication, or an external label feed.

Save one diagram, one hand calculation, one review screenshot, one pending-to-matured transition, and a two-minute explanation. Then move to [Fleet Desk](../03-predictive-maintenance/OPERATOR-WALKTHROUGH.md), where the central challenges change from delayed truth to sensor windows and durable delivery.
