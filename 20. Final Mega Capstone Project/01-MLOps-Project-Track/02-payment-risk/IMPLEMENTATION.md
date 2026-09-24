# Implemented v1 and target design

| Concern | Implemented behavior |
|---|---|
| Data | 1,800 synthetic events; event/arrival time, entity, currency, amount, delayed outcome availability |
| Features | Shared offline/online function: log amount, counts over prior windows, mean amount, relative amount; future/late information excluded by cutoff |
| Training | StandardScaler/LogisticRegression pipeline fitted on mature training rows only |
| Evaluation | Chronological validation/holdout; average precision baseline comparison; validation review threshold; coverage and unknown-label accounting |
| Serving | Persistent idempotent decisions; conflicting event reuse rejected; scores explicitly identify learned versus heuristic method |
| Labels | Delayed availability; identical duplicate accepted; conflicting corrections rejected rather than silently overwritten |
| Concurrency | SQLite `BEGIN IMMEDIATE` serializes a short local inference/write transaction; concurrent identical requests get one persisted result |
| Release | Entire pipeline/method/threshold bundle selected by immutable release ID; old decisions retain their original result |
| Frontend | Risk Desk: simulated payment form, searchable latest-200 ledger, score/feature evidence, review queue filter, analyst reviews, delayed labels, active model comparison |
| Analyst reviews | Persistent immutable per-event review; `escalate` or `clear`, self-entered reviewer and rationale; canonical request hash and unique target prevent duplicate or conflicting finalization |
| Feedback UI | Unknown, pending, and matured outcomes distinguished; pending fraud value withheld from dashboard reads; review decision never automatically becomes a label |
| Degraded read path | Ledger remains readable if model evidence is unavailable; affected evidence panel reports the failure and new scoring is disabled by UI |

The broad LLD proposes leased reservations for distributed/remote inference. V1 deliberately uses a single local API process and bounded local inference inside one SQLite transaction. It makes no network calls inside that transaction. This is suitable for the small lab, not a scaling recipe for a payment processor.

Deferred: authenticated tenant isolation, dedicated feature-store/cache, label-correction history, shadow/canary routing, real payments, production latency qualification, and external fraud feeds. The outcome endpoint reports label maturity/coverage, not a full unbiased production accuracy estimate.

Delivered UI and backend files live in `frontend/` and `app.py`; shared styles/rendering and review transactions live in `../mlops_common/web/` and `../mlops_common/operations.py`. Serving uses one process and additive SQLite table creation. Foreign browser Origin writes are rejected, but reviewer labels are not authenticated identities. The API accepts synthetic label submissions; it does not verify an external fraud investigation.

Training still uses the fixed generator, not automatic retraining on analyst labels. The model was evaluated on synthetic USD amounts; accepting EUR/INR payloads does not establish cross-currency model validity. Queue search/filtering covers the latest 200 displayed events; headline counts cover the whole local ledger.

Synthetic full outcomes support offline evaluation; real review labels can be selection-biased. An amount heuristic is not a calibrated fraud probability. No customer is blocked and no money is moved.
