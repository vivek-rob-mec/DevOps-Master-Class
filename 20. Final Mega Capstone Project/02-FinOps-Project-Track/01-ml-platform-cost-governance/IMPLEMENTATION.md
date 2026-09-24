# Implemented local application and limits

| Concern | Delivered |
|---|---|
| UI | CSV files/text import, team showback, provider/daily totals, cost chart, usage ratios, budget editing, policy editing, savings scenarios and reviews |
| Backend | FastAPI, bounded schema validation, canonical snapshot identities, exact money arithmetic |
| Database | SQLite immutable snapshots/receipts, policy versions, currency/month/team budgets, saved scenario snapshots |
| Data | Deterministic 14-day synthetic fixture: 85 charges including a credit, shared costs, ownership gaps; 56 daily usage rows |
| Allocation | Fixed basis points, largest-remainder distribution per charge, signed credit handling, exact reconciliation |
| Forecast | Linear calendar-day run rate over importer-declared coverage |
| Unit economics | Allocated team cost divided by separate, complete daily successful-unit counts; zero denominator stays undefined |
| Optimization | Hypothetical proportional compute reduction with saved reviewer, rationale, assumptions, and source identity |
| Delivery | Standalone lockfile, Dockerfile, Compose, project-root GitHub Actions workflow, API tests and optional real Edge browser script |

No cloud provider or actual on-premises billing is connected. Provider labels and amounts are fabricated; unit counts are not measured from the earlier MLOps apps. This project neither scrapes machine resource usage nor calculates a real cloud invoice. The accepted input schema is a simplified lab schema, not certified FOCUS output.

Deferred: actual provider export adapters, FOCUS mapping/conformance tests, billed-versus-effective cost semantics, invoice reconciliation, tax/discount/commitment handling, FX conversion, incremental corrections, usage collectors, authenticated ownership, audited actor identity, shared-cost policy approval, lifecycle migrations/retention, pagination, and measured optimization outcomes.

No prices or exchange rates are represented as current market values. Projections are estimates based on declared coverage. Savings scenarios assume unchanged rates and workload quality, ignore implementation costs and commitments, and never invoke resizing or purchasing. Local UI tests establish software behavior, not production finance accuracy.
