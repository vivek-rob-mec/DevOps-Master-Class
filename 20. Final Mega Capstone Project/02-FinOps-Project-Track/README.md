# FinOps project track

Start with **[Cost Desk: ML platform cost governance](01-ml-platform-cost-governance/README.md)**, a working local frontend/API/SQLite application. It follows the [MLOps and AIOps track](../01-MLOps-Project-Track/README.md).

The project covers synthetic billing ingestion, shared-cost allocation, ownership gaps, monthly budgets, simple forecasting, workload unit economics, and reviewed optimization hypotheses. No cloud account, billing permission, paid API, or GPU is required.

Read the [HLD](01-ml-platform-cost-governance/HLD.md), [LLD](01-ml-platform-cost-governance/LLD.md), and [guided lab](01-ml-platform-cost-governance/FINOPS-WALKTHROUGH.md). Check [verification](01-ml-platform-cost-governance/VERIFICATION.md) for executed evidence.

This is an application for studying FinOps responsibilities. AWS/Azure/GCP/on-premises are labels in the bundled synthetic dataset, not connected accounts or deployments. The workload names mirror the earlier projects; usage counts are synthetic, not automatically collected from those applications. Actual cloud billing integration and local resource measurement remain explicit extensions.

The design is informed by the FinOps Foundation's [Allocation](https://www.finops.org/framework/capabilities/allocation/), [Forecasting](https://www.finops.org/framework/capabilities/forecasting/), [Budgeting](https://www.finops.org/framework/capabilities/budgeting/), and [Unit Economics](https://www.finops.org/framework/capabilities/unit-economics/) capabilities. Its concrete algorithms are documented lab choices, not universal industry mandates.

After operating this project, continue to the **[Forward Deployed Engineering track](../03-FDE-Project-Track/README.md)**. Its first working milestone covers customer discovery, a simulated ERP export, persistent forecast jobs, and a replenishment review UI. Connections to this Cost Desk and the earlier MLOps/AIOps services remain subsequent milestones.
