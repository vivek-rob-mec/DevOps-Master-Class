# Lab: online decisions, duplicate requests, and delayed truth

1. **Design first.** Draw transaction -> as-of features -> score -> policy -> decision ledger -> delayed label. Explain the difference between deciding now and knowing the outcome later.
2. **Inspect information availability.** Read `features` and `train`. Find the condition excluding labels unavailable at the training cutoff. Explain why adding future transaction history to an offline query would produce misleading evaluation.
3. **Train and compare.** Run `..\.venv\Scripts\python.exe run.py demo`. Read `/report` or `run.py report`. Identify the selected method, the rejected candidate if any, average precision, review rate, and the baseline. Explain why a heuristic score is not automatically a probability.
4. **Test the API.** Start `run.py serve`. Submit the README's example twice through `/docs`. Compare the identical decisions, then reuse its ID with a different amount. Explain how the database uniqueness and transaction boundary prevent two winning decisions.
5. **Delay feedback.** Run `run.py exercise`. Inspect `outcomes`: distinguish scored events, matured labels, and unknown outcomes. Explain why unknown events cannot be treated as legitimate negatives.
6. **Investigate failure.** In a fresh disposable state directory, serve without first creating a model and observe 503 readiness. Restore service by training and promoting through the CLI. Explain the caller's fallback policy; do not reinterpret an unavailable result as low risk.

Deliver: feature reconstruction for one event, a chronological split diagram, model/baseline report, duplicate/conflict evidence, a label-maturity example, and a reasoned operating-limit statement. Delayed review: change event arrival order and predict which future decision features change.

Continue through [ANALYST-WALKTHROUGH.md](ANALYST-WALKTHROUGH.md) in the working dashboard. It adds an immutable analyst review, a visible pending-to-matured label transition, promotion evidence, and recall checkpoints after 1, 3, 7, and 14 days.
