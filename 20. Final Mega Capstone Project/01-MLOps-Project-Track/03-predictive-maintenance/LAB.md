# Lab: edge inference and reliable replay

1. **Design first.** Draw edge ledger/model/spool and central database as separate responsibilities. Explain which remain usable when the central adapter fails, and why two databases on one laptop are not independent physical sites.
2. **Check leakage.** Read training unit partitions and trailing-window features. Explain why rows from one equipment trajectory must not be randomly scattered across train and test, and why future failure time belongs only in the target.
3. **Train and serve.** Run `..\.venv\Scripts\python.exe run.py demo`, then `run.py serve`. Read `/report`; interpret per-unit error and warning lead cycles. Do not convert simulated cycles into hours without a justified mapping.
4. **Observe warmup.** Submit five sequential events for a new equipment ID in `/docs`. Predict when inference becomes possible. Send a conflicting duplicate and a sequence gap; explain each response and how valid coverage can recover.
5. **Lose an acknowledgement.** Run `run.py exercise`. Explain why the central rows already exist when the sender retries and why the duplicate does not create another central record. Inspect the tests for disconnection and full-spool backpressure.
6. **Defend model updates.** Explain what checksum validation protects and what it does not authenticate. Use an earlier eligible ID with `run.py rollback --release ID`; explain why old issued predictions retain their original IDs.

Deliver: split/window diagram, held-out error report, warmup/gap evidence, replay row counts, and a model-update runbook. Delayed review: describe a crash immediately before local commit, after local commit, and after central commit but before acknowledgement.

Continue through [OPERATOR-WALKTHROUGH.md](OPERATOR-WALKTHROUGH.md) in Fleet Desk. It adds site-scoped history, stale inspection-review conflicts, manual upload, and recall checkpoints after 1, 3, 7, and 14 days.
