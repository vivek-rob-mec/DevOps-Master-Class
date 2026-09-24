# Low-level design

The trainer uses deterministic synthetic data, split seed, algorithm parameters, feature contract, metrics, and registry tags. A quality gate blocks weak ROC AUC. The serving API enforces exactly four finite numeric features and returns only a bounded decision. MLflow metadata lives in PostgreSQL and artifacts in object storage. The Rollout advances 10% then 50% only when Prometheus analysis succeeds.
